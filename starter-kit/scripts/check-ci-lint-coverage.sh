#!/usr/bin/env bash
# Enforces: every check chained into the umbrella lint target actually runs in
# CI — see the shared-registries rule file § "A Makefile target is not a CI step".
#
# The failure this prevents is not hypothetical and not loud. A repository
# gains checks by adding them to `make lint`, while its workflow enumerates
# sub-targets one `run:` step at a time. The two lists drift apart one pull
# request at a time, and nothing reports it: the checks still pass locally, the
# rule files still claim the conventions are enforced, and the gates that stop
# running are discovered only by the bug they were supposed to catch.
#
# The cheap fix is for CI to invoke the aggregate target — then coverage is
# total by construction and this script exits immediately. Enumerating is only
# worth it when jobs need per-path gating, and that is when this gate earns
# its place.
#
# Usage: check-ci-lint-coverage.sh [lint-target] [makefile]
#        default target: lint       default makefile: Makefile
set -euo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

TARGET="${1:-lint}"
MAKEFILE="${2:-Makefile}"
fail=0
ALLOWLIST=".ci-lint-coverage-allowlist"
WORKFLOW_DIR=".github/workflows"

if [ ! -f "$MAKEFILE" ]; then
  echo "SKIP: no $MAKEFILE — nothing to cross-check."
  exit 0
fi
if [ ! -d "$WORKFLOW_DIR" ]; then
  echo "SKIP: no $WORKFLOW_DIR — nothing to cross-check."
  exit 0
fi

# The kit's own gates must actually be reached by the umbrella target. On a
# brownfield repository the installer cannot edit an existing Makefile, so the
# scripts land in scripts/ while `make lint` keeps running only what it ran
# before — green, and checking nothing of the registry layer. `make -n lint`
# prints every command the target would run, transitively, which is the exact
# question: would the drift and identifier gates execute?
if [ -f registries.json ] && [ -f scripts/check-registry-drift.sh ]; then
  dry="$(make -n "$TARGET" -f "$MAKEFILE" 2>/dev/null || true)"
  for gate in check-registry-drift.sh check-registry-ids.sh; do
    if ! printf '%s\n' "$dry" | grep -q "$gate"; then
      echo "FAIL: scripts/$gate is installed but '$TARGET' never runs it."
      echo "  The gate exists and gates nothing. Chain it into the umbrella target:"
      echo "      include registry.mk"
      echo "      lint: registry-drift registry-ids kb-shape ci-lint-coverage <your existing prerequisites>"
      echo "  See the shared-registries rule § 'A Makefile target is not a CI step'."
      fail=1
    fi
  done
fi

# Prerequisites of the umbrella target, e.g. "lint: a b c" -> a b c
prereqs="$(sed -n "s/^${TARGET}:[[:space:]]*//p" "$MAKEFILE" | head -1 | tr ' ' '\n' | sed '/^$/d' || true)"
if [ -z "$prereqs" ]; then
  [ "$fail" -eq 0 ] && echo "OK: '$TARGET' has no sub-targets to cover."
  exit "$fail"
fi

workflows="$(find "$WORKFLOW_DIR" -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null || true)"
if [ -z "$workflows" ]; then
  echo "SKIP: no workflow files found."
  exit 0
fi

# Match against the workflows with full-line comments stripped. A workflow that
# merely MENTIONS the target in a comment — including the explanatory comment in
# the kit's own template — must not satisfy the gate: a check that passes on a
# comment is exactly the kind of gate that silently stops gating.
workflow_body() { sed 's/^[[:space:]]*#.*$//' $workflows; }

runs_target() { # $1 = make target name
  workflow_body | grep -qE "(^|[^a-zA-Z0-9_-])make[[:space:]]+([A-Za-z0-9_.=-]+[[:space:]]+)*$1([[:space:]]|\$)"
}

# The simple, total case: CI runs the aggregate, so nothing can fall out of it.
# Coverage of lint by CI says nothing about coverage of the registry gates BY
# lint, so a failure recorded above still wins here.
if runs_target "$TARGET"; then
  if [ "$fail" -eq 0 ]; then
    echo "OK: CI invokes 'make $TARGET' directly — every sub-target is covered by construction."
  fi
  exit "$fail"
fi

uncovered=()
for target in $prereqs; do
  if runs_target "$target"; then
    continue
  fi
  if [ -f "$ALLOWLIST" ] && grep -qxF "$target" <(sed 's/#.*//; s/[[:space:]]*$//' "$ALLOWLIST"); then
    echo "note: '$target' is allowlisted as intentionally not run in CI."
    continue
  fi
  uncovered+=("$target")
  fail=1
done

# Stale allowlist entries are drift in their own right: they claim an exemption
# for a target that no longer exists, and they make the list look larger than
# the debt it actually records.
if [ -f "$ALLOWLIST" ]; then
  while read -r entry; do
    [ -z "$entry" ] && continue
    if ! printf '%s\n' $prereqs | grep -qxF "$entry"; then
      echo "FAIL: $ALLOWLIST names '$entry', which is not a sub-target of '$TARGET' — remove the stale line."
      fail=1
    fi
  done < <(sed 's/#.*//; s/[[:space:]]*$//; /^$/d' "$ALLOWLIST")

  # Shrink-only: the allowlist records debt being paid down, never taken on.
  base="$(git merge-base HEAD origin/HEAD 2>/dev/null || git merge-base HEAD origin/main 2>/dev/null || true)"
  # Only compare when the allowlist already existed at the merge base. A branch
  # that INTRODUCES the file is not growing it — treating that as growth made it
  # impossible to add the file at all on a brownfield adoption.
  if [ -n "$base" ] && git cat-file -e "$base:$ALLOWLIST" 2>/dev/null; then
    before="$(git show "$base:$ALLOWLIST" 2>/dev/null | sed 's/#.*//; s/[[:space:]]*$//; /^$/d' | wc -l | tr -d ' ' || echo 0)"
    after="$(sed 's/#.*//; s/[[:space:]]*$//; /^$/d' "$ALLOWLIST" | wc -l | tr -d ' ')"
    if [ "$after" -gt "$before" ]; then
      echo "FAIL: $ALLOWLIST grew from $before to $after entries."
      echo "  The allowlist is shrink-only. Wire the new check into a workflow"
      echo "  instead of exempting it — an exemption added today is a gate that"
      echo "  silently stops running tomorrow."
      fail=1
    fi
  fi
fi

if [ "$fail" -ne 0 ]; then
  if [ ${#uncovered[@]} -gt 0 ]; then
    echo "FAIL: these '$TARGET' sub-targets run in no workflow:"
    printf '  %s\n' "${uncovered[@]}"
    echo ""
    echo "Fix by making CI invoke the aggregate target:"
    echo ""
    echo "    - run: make $TARGET"
    echo ""
    echo "or add each one as its own workflow step. Exempting it in $ALLOWLIST"
    echo "is the last resort, and needs a comment saying why."
  fi
  exit 1
fi
echo "OK: every '$TARGET' sub-target runs in CI"
