#!/usr/bin/env bash
# ACCEPTANCE TEST: the upgrade the README documents, run as written, on a
# repository that installed an older kit and then made it its own.
#
# The steps under "Upgrading an existing install" had never been run end to
# end by anything but a reader. The contract they state, and this holds:
#   1. what is the adopter's is byte-for-byte what it was — the constitution,
#      settings.json, a rule they wrote, the rule they filled in, registries.json,
#      their changelog fragment, knowledge-base entry and decision record, the
#      CI workflow, their tests — except the two edits the steps ask for by
#      name: the `lint:` line, and a check script's `# Enforces:` header;
#   2. what is the kit's is the newer kit's, byte for byte, and nothing that
#      belongs only in the kit is left behind in the repository;
#   3. the gates that are new since the install run, and say what the README
#      says they will: first that lint does not reach the link gate, then the
#      old-form `# Enforces:` header — and nothing else;
#   4. at the end `make lint` is green, the project's own check and tests ran
#      in it, and running step 1 again changes nothing.
#
# The commands for steps 1 and 2 are read out of the README, not retyped here,
# so the test runs what a reader would paste. If that section stops containing
# them, the test fails rather than quietly running its own idea of the steps.
#
# Two older installs. One is built here to the shape 1.x left behind, so the
# suite needs nothing but the kit. The other is the real thing — kit 1.1.0's
# own installer, taken from this repository's history — where the tag is
# present; without it that scenario is skipped, and says so.
#
# Usage: test-upgrade.sh [-v]
set -uo pipefail
VERBOSE=0; [ "${1:-}" = "-v" ] && VERBOSE=1
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KIT_ROOT="$(cd "$KIT_DIR/.." && pwd)"   # what the README calls $KIT
README="$KIT_DIR/README.md"
PY="$KIT_DIR/scripts/python.sh"
BOOTSTRAP="$KIT_DIR/bootstrap.sh"
WORK="$(mktemp -d)"; trap '[ "$VERBOSE" -eq 1 ] || rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()   { printf '  ok   — %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL — %s\n' "$1"; fail=$((fail + 1)); }
skip() { printf '  skip — %s\n' "$1"; }

if [ ! -f "$BOOTSTRAP" ] || [ "$(basename "$KIT_DIR")" != starter-kit ]; then
  echo "SKIP: runs only from the kit itself (starter-kit/ beside its README and bootstrap.sh)"
  exit 0
fi

# An install from before the launcher starts Python as `python3`. Where that
# name is not Python, such an install never ran, and there is nothing to
# upgrade from.
if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1; then
  echo "SKIP: an older install needs Python as 'python3', which this machine does not have"
  exit 0
fi

# block <n> — the n-th ```bash block of the README's upgrade section.
block() {
  awk -v want="$1" '
    /^## Upgrading an existing install/ { on = 1; next }
    on && /^## / { exit }
    on && /^ *```bash/ { n++; inside = 1; next }
    on && inside && /^ *```/ { inside = 0; next }
    on && inside && n == want { sub(/^ +/, ""); print }
  ' "$README"
}
STEP1="$(block 1)"; STEP2="$(block 2)"
case "$STEP1" in *'bootstrap.sh --target .'*) ok "the README's step 1 is the installer, run on the repository itself" ;;
  *) bad "the upgrade section's first command block is no longer the installer: '$STEP1'" ;; esac
case "$STEP2" in *'cp "$KIT"/starter-kit/scripts/'*'registry.mk'*) ok "the README's step 2 copies the kit's scripts and registry.mk" ;;
  *) bad "the upgrade section's second command block no longer copies the kit's files" ;; esac

fresh_repo() { # $1 = dir
  mkdir -p "$1"; git -C "$1" init -q -b main
  git -C "$1" config user.email t@example.invalid; git -C "$1" config user.name t
  git -C "$1" config commit.gpgsign false
}

# What a repository installed from THIS kit has. The upgraded one is compared
# with it: same suites, no more.
FRESH="$WORK/fresh"; fresh_repo "$FRESH"
"$BOOTSTRAP" --tool claude --target "$FRESH" >/dev/null 2>&1 || bad "a fresh install of this kit failed"

# --- an older install, built to the shape 1.x left behind ----------------------
# No launcher, no link gate and no graph tool, no constitution check, no
# templates or rule references, no workspace-graph hook; the installer's own
# two suites in scripts/tests/; a registry.mk that starts python3 by name; a
# lint line with four gates. Every kit-owned file carries a line the newer kit
# does not have, so "replaced" can be told from "happened to be equal".
aged_install() { # $1 = dir
  local R="$1" f
  fresh_repo "$R"
  "$BOOTSTRAP" --tool claude --target "$R" >/dev/null 2>&1 || return 1
  rm -rf "$R/scripts/python.sh" "$R/scripts/graph_tool.py" "$R/scripts/check-graph-links.sh" \
         "$R/scripts/check-constitution.sh" "$R/scripts/tests/test_graph_tool.py" \
         "$R/scripts/tests/test-graph-links.sh" "$R/scripts/tests/test-python-launcher.sh" \
         "$R/scripts/tests/test-constitution.sh" "$R/docs/agent-templates" "$R/docs/rule-reference" \
         "$R/.claude/hooks/workspace-graph.py"
  cp "$KIT_DIR/scripts/tests/test-bootstrap-rerun.sh" "$KIT_DIR/scripts/tests/test-brownfield-adoption.sh" "$R/scripts/tests/"
  for f in "$R"/scripts/*.py "$R"/scripts/check-*.sh "$R"/scripts/tests/* "$R"/.claude/rules/*.md \
           "$R/docs/DEBUGGING-KNOWLEDGE-BASE.d/_template.md"; do
    case "$f" in *.md) printf '\n<!-- as shipped by kit 1.x -->\n' >> "$f" ;; *) printf '\n# as shipped by kit 1.x\n' >> "$f" ;; esac
  done
  # Kits before the hook became a template installed the SessionStart skeleton
  # and registered it. An older install has both, and both are the adopter's.
  mkdir -p "$R/.claude/hooks"
  printf '#!/bin/bash\n# SessionStart hook (kit 1.x skeleton)\nset -uo pipefail\necho "session-start: toolchain ready"\n' > "$R/.claude/hooks/session-start.sh"
  chmod +x "$R/.claude/hooks/session-start.sh"
  rm -f "$R/docs/agent-templates/session-start.sh.template"
  cat > "$R/.claude/settings.json" <<'JSON'
{
  "enabledMcpjsonServers": [],
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/session-start.sh"
          }
        ]
      }
    ]
  }
}
JSON
  cat > "$R/registry.mk" <<'MK'
# Registry targets — include this from your Makefile. (kit 1.x)
.PHONY: registry-generate registry-list registry-drift registry-ids kb-shape \
        ci-lint-coverage registry-test
registry-generate:
	python3 scripts/registry_tool.py generate
registry-list:
	python3 scripts/registry_tool.py list
registry-drift:
	./scripts/check-registry-drift.sh
registry-ids:
	./scripts/check-registry-ids.sh
kb-shape:
	./scripts/check-kb-shape.sh
ci-lint-coverage:
	./scripts/check-ci-lint-coverage.sh
registry-test:
	python3 -B -m unittest discover -b -s scripts/tests -p 'test_*.py'
	./scripts/tests/test-ci-lint-coverage.sh
	./scripts/tests/test-parallel-merge.sh
MK
  printf 'include registry.mk\n\n.PHONY: lint test\n\nlint: registry-drift registry-ids kb-shape ci-lint-coverage test\n\ntest: registry-test\n' > "$R/Makefile"
}

# --- what the adopter then made of it ------------------------------------------
customize() { # $1 = dir of an older install, already committed
  local R="$1"
  cat > "$R/CLAUDE.md" <<'MD'
# Agent Constitution — Ledger

Ledger is a double-entry accounting service for the finance team. Entries are
immutable; every correction is a new entry.

## Commands

```bash
make lint         # every check CI runs
make app-test     # the service's own tests
```

## Detailed Rules

- [`payments.md`](.claude/rules/payments.md) — idempotency keys on every payment request
- [`documentation.md`](.claude/rules/documentation.md) — docs with the change
MD
  printf '# Payments\n\nEvery payment request carries an idempotency key.\n' > "$R/.claude/rules/payments.md"
  printf '\n## Ours\n\n| Marker | Read by |\n|---|---|\n| `# ledger:frozen` | `scripts/check-payments.sh` |\n' \
    >> "$R/.claude/rules/comments-and-annotations.md"
  "$PY" -B - "$R/.claude/settings.json" "$R/registries.json" <<'PYEOF'
import json, sys
settings, registries = sys.argv[1:3]
data = json.load(open(settings, encoding="utf-8"))
data["permissions"] = {"allow": ["Bash(make lint)", "Bash(make app-test)"]}
json.dump(data, open(settings, "w", encoding="utf-8"), indent=2)
data = json.load(open(registries, encoding="utf-8"))
for registry in data["registries"]:
    if registry["name"] == "adr":
        registry["id_scheme"] = "numeric"   # MADR numbering, chosen before the first record
json.dump(data, open(registries, "w", encoding="utf-8"), indent=2)
PYEOF
  mkdir -p "$R/tests"
  printf 'import unittest\n\n\nclass Ledger(unittest.TestCase):\n    def test_balance(self):\n        self.assertEqual(sum([100, -40, -60]), 0)\n' > "$R/tests/test_ledger.py"
  # The header form the 1.x check-script template shipped.
  printf '#!/usr/bin/env bash\n# Enforces: payments — see .claude/rules/payments.md\nset -euo pipefail\necho "OK: payments carry idempotency keys"\n' > "$R/scripts/check-payments.sh"
  chmod +x "$R/scripts/check-payments.sh"
  cat > "$R/Makefile" <<'MK'
# Ledger's own Makefile.
include registry.mk

.PHONY: lint app-test payments

lint: registry-drift registry-ids kb-shape ci-lint-coverage payments app-test

app-test:
	python3 -B -m unittest discover -s tests -p 'test_*.py'

payments:
	./scripts/check-payments.sh
MK
  ( cd "$R" || exit 1
    f="$("$PY" -B scripts/registry_tool.py new --registry changelog --title "Ledger export" 2>/dev/null | tail -1)"
    printf '# Ledger export\n\n## Added\n\n- CSV export of the account ledger.\n' > "$f"
    f="$("$PY" -B scripts/registry_tool.py new --registry adr --title "Ledger entries are immutable" 2>/dev/null | tail -1)"
    printf '# Ledger entries are immutable\n\n## Status\n\nAccepted\n\n## Context\n\nAuditors read the ledger as written.\n\n## Decision\n\nWe will never update an entry; a correction is a new entry.\n\n## Consequences\n\nBalances are sums, and history is complete.\n\n**Related:** RULE:payments\n' > "$f"
    f="$("$PY" -B scripts/registry_tool.py new --registry debugging-kb --title "Export times out on large ledgers" 2>/dev/null | tail -1)"
    printf '# Export times out on large ledgers\n\n**Symptom:** The CSV export returns 504 above one million entries.\n\n**Investigation Trail:** The query was fast; the response was built in memory.\n\n**Root Cause:** The exporter materialised every row before writing.\n\n**Fix:** Stream rows to the response.\n\n**Prevention:** Exports are streamed.\n\n**Debug Shortcut:** Watch the memory of the export worker.\n\n**Related:** RULE:payments\n' > "$f"
    "$PY" -B scripts/registry_tool.py generate >/dev/null
  )
}

# Files of the adopter's that the upgrade must leave exactly as they were.
THEIRS="CLAUDE.md .claude/settings.json .claude/rules/payments.md .claude/rules/comments-and-annotations.md
        .claude/hooks/session-start.sh registries.json CHANGELOG.md changelog.d docs/adr
        docs/DEBUGGING-KNOWLEDGE-BASE.md docs/DEBUGGING-KNOWLEDGE-BASE.d/README.md .github tests .gitattributes"

upgrade() { # $1 = scenario name, $2 = dir: an older install, customized and committed
  local name="$1" R="$2" pre rc f n out changed
  pre="$(git -C "$R" rev-parse HEAD)"

  ( cd "$R" && make lint > "$WORK/$name-pre.log" 2>&1 ) \
    && ok "$name: control — before the upgrade the repository lints green on the kit it has" \
    || { bad "$name: the older install does not lint green to begin with:"; grep -E '^FAIL|Error' "$WORK/$name-pre.log" | head -3 | sed 's/^/         /'; }

  # Step 1 — add what is new.
  ( cd "$R" && KIT="$KIT_ROOT" bash -e -c "$STEP1" ) > "$WORK/$name-step1.log" 2>&1 < /dev/null; rc=$?
  [ "$rc" -eq 0 ] && ok "$name: step 1 runs as written" || { bad "$name: step 1 exited $rc:"; tail -3 "$WORK/$name-step1.log" | sed 's/^/         /'; }
  changed="$(git -C "$R" status --porcelain | grep -v '^??' || true)"
  [ -z "$changed" ] && ok "$name: step 1 changed no file that was already there" \
    || bad "$name: step 1 modified existing files: $(echo "$changed" | tr '\n' ' ')"
  [ -x "$R/scripts/check-graph-links.sh" ] && [ -x "$R/scripts/python.sh" ] && [ -x "$R/scripts/check-constitution.sh" ] \
    && [ -f "$R/docs/agent-templates/_rule-template.md" ] && [ -f "$R/.claude/hooks/workspace-graph.py" ] \
    && ok "$name: step 1 added what the newer kit has: launcher, link gate, constitution check, templates, hook" \
    || bad "$name: step 1 left out something the newer kit installs"
  grep -q 'does not reach: graph-links' "$WORK/$name-step1.log" \
    && ok "$name: and names the gate the repository's own lint target does not reach yet" \
    || bad "$name: step 1 does not say that lint misses graph-links"
  grep -q '"PostToolUse"' "$WORK/$name-step1.log" \
    && ok "$name: and prints the hook entries for the settings.json it did not edit" \
    || bad "$name: step 1 does not say how to register the hook in an existing settings.json"
  # The SessionStart skeleton is a template in the newer kit. An install that
  # has the hook from an older one keeps it, registered as it was; what step 1
  # adds is the template, not a second copy of the hook and not a verdict on theirs.
  [ -f "$R/docs/agent-templates/session-start.sh.template" ] \
    && cmp -s "$R/.claude/hooks/session-start.sh" <(git -C "$R" show "$pre:.claude/hooks/session-start.sh") \
    && ok "$name: step 1 adds the session-start template and leaves the hook the older kit installed alone" \
    || bad "$name: step 1 did not add the session-start template, or touched the existing hook"

  # Step 2 — replace the files the kit owns.
  ( cd "$R" && KIT="$KIT_ROOT" bash -e -c "$STEP2" ) > "$WORK/$name-step2.log" 2>&1; rc=$?
  [ "$rc" -eq 0 ] && ok "$name: step 2 runs as written" || { bad "$name: step 2 exited $rc:"; tail -3 "$WORK/$name-step2.log" | sed 's/^/         /'; }
  out=""
  for f in "$KIT_DIR"/scripts/*.py "$KIT_DIR"/scripts/check-*.sh "$KIT_DIR/scripts/python.sh"; do
    cmp -s "$f" "$R/scripts/$(basename "$f")" || out="$out $(basename "$f")"
  done
  cmp -s "$KIT_DIR/registry.mk" "$R/registry.mk" || out="$out registry.mk"
  cmp -s "$KIT_DIR/docs/DEBUGGING-KNOWLEDGE-BASE.d/_template.md" "$R/docs/DEBUGGING-KNOWLEDGE-BASE.d/_template.md" || out="$out _template.md"
  [ -z "$out" ] && ok "$name: every script, registry.mk and the entry template are the newer kit's, byte for byte" \
    || bad "$name: still the older kit's after step 2:$out"
  [ "$(ls "$R/scripts/tests" | grep -v __pycache__)" = "$(ls "$FRESH/scripts/tests")" ] \
    && ok "$name: scripts/tests/ holds exactly the suites a fresh install has — none of the kit's installer suites" \
    || bad "$name: scripts/tests/ differs from a fresh install: $(diff <(ls "$FRESH/scripts/tests") <(ls "$R/scripts/tests" | grep -v __pycache__) | grep '^[<>]' | tr '\n' ' ')"
  cmp -s "$R/scripts/check-payments.sh" <(git -C "$R" show "$pre:scripts/check-payments.sh") \
    && ok "$name: the adopter's own check script in scripts/ was not touched by the copy" \
    || bad "$name: step 2 changed scripts/check-payments.sh"

  # Step 3 — a rule no commit of the adopter's changed is copied; the one they
  # filled in is theirs to merge, and stays.
  for f in "$KIT_DIR"/rules/*.md; do
    n="$(basename "$f")"; case "$n" in _*) continue ;; esac
    [ "$(git -C "$R" log --oneline -- ".claude/rules/$n" | wc -l | tr -d ' ')" -eq 1 ] && cp "$f" "$R/.claude/rules/$n"
  done
  out=""
  for n in working-principles documentation versioning-and-changelog shared-registries; do
    cmp -s "$KIT_DIR/rules/$n.md" "$R/.claude/rules/$n.md" || out="$out $n"
  done
  [ -z "$out" ] && ok "$name: step 3 — the rules used as shipped are the newer kit's" || bad "$name: rules not updated:$out"
  git -C "$R" diff --quiet "$pre" -- .claude/rules/comments-and-annotations.md && grep -q 'ledger:frozen' "$R/.claude/rules/comments-and-annotations.md" \
    && ok "$name: the rule the adopter filled in is not copied over: their rows are still there" \
    || bad "$name: the adopter's rows in comments-and-annotations.md were lost"

  # Before step 5 the coverage gate says which gate lint does not reach.
  ( cd "$R" && make lint > "$WORK/$name-before5.log" 2>&1 ); rc=$?
  [ "$rc" -ne 0 ] && grep -q "check-graph-links.sh is installed but 'lint' never runs it" "$WORK/$name-before5.log" \
    && ok "$name: until step 5, lint fails and names the gate the Makefile does not chain" \
    || bad "$name: lint did not report the unchained link gate (exit $rc)"

  # Step 5 — the one edit to the adopter's Makefile: name the new gate.
  sed -i.bak 's/^lint: registry-drift registry-ids kb-shape ci-lint-coverage /lint: registry-drift registry-ids kb-shape graph-links ci-lint-coverage /' "$R/Makefile"
  rm -f "$R/Makefile.bak"

  # Step 6 — lint reports what the README says to expect, and only that.
  ( cd "$R" && make lint > "$WORK/$name-step6.log" 2>&1 ); rc=$?
  [ "$rc" -ne 0 ] && grep -q "check-payments.sh:2 — Enforces link 'payments' is not a typed link" "$WORK/$name-step6.log" \
    && ok "$name: step 6 — lint names the old-form '# Enforces:' header, with file and line" \
    || bad "$name: lint did not report the old-form Enforces header (exit $rc)"
  [ "$(grep -c '^FAIL' "$WORK/$name-step6.log")" -eq 1 ] \
    && ok "$name: and that is the only failure: nothing else of the adopter's has to change" \
    || { bad "$name: lint reports more than the documented failure:"; grep '^FAIL' "$WORK/$name-step6.log" | head -4 | cut -c1-150 | sed 's/^/         /'; }
  sed -i.bak 's|^# Enforces: payments — see .claude/rules/payments.md$|# Enforces: RULE:payments — every payment request carries an idempotency key|' "$R/scripts/check-payments.sh"
  rm -f "$R/scripts/check-payments.sh.bak"
  ( cd "$R" && make lint > "$WORK/$name-final.log" 2>&1 ); rc=$?
  [ "$rc" -eq 0 ] && ok "$name: with the header written as a token, 'make lint' is green" \
    || { bad "$name: lint is still red after the documented fixes:"; grep -E '^FAIL|Error' "$WORK/$name-final.log" | head -4 | cut -c1-150 | sed 's/^/         /'; }
  grep -q 'typed link(s) in' "$WORK/$name-final.log" && grep -q 'OK: payments carry idempotency keys' "$WORK/$name-final.log" \
    && grep -q '^Ran 1 test' "$WORK/$name-final.log" \
    && ok "$name: the new link gate ran in it, and so did the adopter's own check and tests" \
    || bad "$name: the final lint did not run the link gate, the adopter's check and the adopter's tests"

  # What is theirs is what it was.
  out=""
  for f in $THEIRS; do git -C "$R" diff --quiet "$pre" -- "$f" || out="$out $f"; done
  [ -z "$(git -C "$R" status --porcelain -- $THEIRS)" ] || out="$out (untracked or modified under their paths)"
  [ -z "$out" ] && ok "$name: constitution, settings, rules, registries.json, registry entries, workflow and tests are byte-for-byte the adopter's" \
    || bad "$name: the upgrade changed files that are the adopter's:$out"
  [ "$(git -C "$R" diff --numstat "$pre" -- Makefile | awk '{print $1 "/" $2}')" = "1/1" ] \
    && [ "$(git -C "$R" diff --numstat "$pre" -- scripts/check-payments.sh | awk '{print $1 "/" $2}')" = "1/1" ] \
    && ok "$name: their Makefile and their check script changed by the one line each that the steps name" \
    || bad "$name: Makefile or check-payments.sh changed by more than the documented line"

  # The checks that came with the upgrade work in this repository.
  ( cd "$R" && make constitution > "$WORK/$name-constitution.log" 2>&1 ) \
    && ok "$name: 'make constitution' reads the adopter's constitution and passes: its links exist" \
    || { bad "$name: 'make constitution' fails on a constitution that is filled in:"; head -3 "$WORK/$name-constitution.log" | sed 's/^/         /'; }
  ( cd "$R" && make registry-test > "$WORK/$name-suites.log" 2>&1 ); rc=$?
  [ "$rc" -eq 0 ] && ! grep -q '^SKIP' "$WORK/$name-suites.log" \
    && ok "$name: the kit's own suites pass from the upgraded repository, and none of them only skips" \
    || { bad "$name: 'make registry-test' fails or skips after the upgrade (exit $rc):"; grep -E 'FAIL|SKIP|Error|No such file' "$WORK/$name-suites.log" | head -4 | cut -c1-150 | sed 's/^/         /'; }

  # Running step 1 again adds nothing and changes nothing.
  git -C "$R" add -A >/dev/null 2>&1; git -C "$R" commit -q -m "upgrade the agentic kit" 2>/dev/null
  ( cd "$R" && KIT="$KIT_ROOT" bash -e -c "$STEP1" ) > "$WORK/$name-again.log" 2>&1 < /dev/null
  [ -z "$(git -C "$R" status --porcelain)" ] && grep -q "already reaches every gate" "$WORK/$name-again.log" \
    && ok "$name: step 1 again changes nothing, and says lint reaches every gate" \
    || bad "$name: a second step 1 changed the tree or still names an unchained gate: $(git -C "$R" status --porcelain | head -3 | tr '\n' ' ')"
}

echo "=== upgrading an install shaped like kit 1.x ==="
R="$WORK/aged"
if aged_install "$R"; then
  git -C "$R" add -A >/dev/null; git -C "$R" commit -q -m "install the agentic kit (1.x)"
  customize "$R"; git -C "$R" add -A >/dev/null; git -C "$R" commit -q -m "make it ours"
  upgrade "1.x-shaped" "$R"
else
  bad "could not build the older-shaped install"
fi

echo "=== upgrading a real kit 1.1.0 install ==="
OLD_TAG=v1.1.0
if git -C "$KIT_ROOT" rev-parse -q --verify "refs/tags/$OLD_TAG^{commit}" >/dev/null 2>&1; then
  mkdir -p "$WORK/kit-$OLD_TAG"
  git -C "$KIT_ROOT" archive "$OLD_TAG" starter-kit | tar -x -C "$WORK/kit-$OLD_TAG"
  R="$WORK/real"; fresh_repo "$R"
  if "$WORK/kit-$OLD_TAG/starter-kit/bootstrap.sh" --tool claude --target "$R" >/dev/null 2>&1; then
    git -C "$R" add -A >/dev/null; git -C "$R" commit -q -m "install the agentic kit ($OLD_TAG)"
    customize "$R"; git -C "$R" add -A >/dev/null; git -C "$R" commit -q -m "make it ours"
    upgrade "$OLD_TAG" "$R"
  else
    bad "kit $OLD_TAG's own installer failed"
  fi
else
  skip "tag $OLD_TAG is not in this checkout (an export, or a shallow clone): the real older install is not exercised here"
fi

echo "=== step 1 where the repository carries two tools' files ==="
# The installer no longer picks a tool when it finds two. An upgrade is a
# re-run, so step 1 has to say what to do about that.
R="$WORK/two-tools"; fresh_repo "$R"
"$BOOTSTRAP" --tool claude --target "$R" >/dev/null 2>&1
echo "# For the other agents" > "$R/AGENTS.md"
git -C "$R" add -A >/dev/null; git -C "$R" commit -q -m "installed for Claude Code, with an AGENTS.md of our own"
( cd "$R" && KIT="$KIT_ROOT" bash -e -c "$STEP1" ) > "$WORK/two.log" 2>&1 < /dev/null; rc=$?
[ "$rc" -ne 0 ] && [ -z "$(git -C "$R" status --porcelain)" ] && grep -q -- '--tool' "$WORK/two.log" \
  && ok "step 1 as written stops, writes nothing, and says to name the tool" \
  || bad "step 1 on a two-tool repository did not stop cleanly (exit $rc)"
awk '/^## Upgrading an existing install/ {on=1; next} on && /^## / {exit} on' "$README" | grep -q -- '--tool' \
  && ok "and the README's step 1 says so too" || bad "the README's upgrade steps never mention --tool"
( cd "$R" && "$BOOTSTRAP" --tool claude --target . ) > "$WORK/two-told.log" 2>&1 < /dev/null; rc=$?
[ "$rc" -eq 0 ] && [ "$(cat "$R/AGENTS.md")" = "# For the other agents" ] \
  && ok "with the tool named, step 1 runs and leaves the other tool's file alone" \
  || bad "step 1 with --tool failed on a two-tool repository (exit $rc)"

echo ""; echo "=== $pass passed, $fail failed ==="
[ "$VERBOSE" -eq 1 ] && echo "scratch repos kept in $WORK"
[ "$fail" -eq 0 ] || exit 1
