#!/usr/bin/env bash
# Tests for check-ci-lint-coverage.sh.
#
# This gate exists to catch checks that are chained into the lint target but
# never invoked by CI. Its own failure mode is passing when it should not, and
# that failure is quiet — a green gate that gates nothing looks exactly like a
# green gate that works. So the cases below assert both directions, and the
# first one is here because the gate really did pass on a workflow that only
# mentioned the target inside a comment.
set -uo pipefail

GATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/check-ci-lint-coverage.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
ok()  { printf '  ok   — %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL — %s\n' "$1"; fail=$((fail + 1)); }

# scenario <name> <expected-exit> <makefile> <workflow> [allowlist]
scenario() {
  local name="$1" expected="$2" makefile="$3" workflow="$4" allowlist="${5:-}"
  local dir; dir="$(mktemp -d "$WORK/case.XXXXXX")"
  mkdir -p "$dir/.github/workflows"
  git -C "$dir" init -q -b main
  printf '%b' "$makefile"  > "$dir/Makefile"
  printf '%b' "$workflow"  > "$dir/.github/workflows/lint.yml"
  [ -n "$allowlist" ] && printf '%b' "$allowlist" > "$dir/.ci-lint-coverage-allowlist"

  local actual; ( cd "$dir" && "$GATE" >/dev/null 2>&1 ); actual=$?
  if [ "$actual" -eq "$expected" ]; then
    ok "$name"
  else
    bad "$name (expected exit $expected, got $actual)"
  fi
}

MAKEFILE='lint: alpha beta\nalpha:\n\t@true\nbeta:\n\t@true\n'
HEADER='name: lint\non: [pull_request]\njobs:\n  lint:\n    steps:\n'

scenario "a comment mentioning the target does not satisfy the gate" 1 \
  "$MAKEFILE" "${HEADER}      # this workflow used to run make lint\n      - run: echo nothing\n"

scenario "invoking the aggregate target covers every sub-target" 0 \
  "$MAKEFILE" "${HEADER}      # a comment that also says make lint\n      - run: make lint\n"

scenario "enumerating every sub-target individually passes" 0 \
  "$MAKEFILE" "${HEADER}      - run: make alpha\n      - run: make beta\n"

scenario "a sub-target missing from every workflow fails" 1 \
  "$MAKEFILE" "${HEADER}      - run: make alpha\n"

scenario "make flags before the target still count as invoking it" 0 \
  "$MAKEFILE" "${HEADER}      - run: make -C . lint\n"

scenario "a target that merely shares a prefix does not count" 1 \
  "$MAKEFILE" "${HEADER}      - run: make alpha\n      - run: make betamax\n"

scenario "an allowlisted sub-target is exempt" 0 \
  "$MAKEFILE" "${HEADER}      - run: make alpha\n" \
  "# beta runs in the nightly workflow instead\nbeta\n"

scenario "a stale allowlist entry naming no sub-target fails" 1 \
  "$MAKEFILE" "${HEADER}      - run: make alpha\n      - run: make beta\n" \
  "gamma\n"

scenario "an empty Makefile has no sub-targets to cover" 0 \
  "" "${HEADER}      - run: echo nothing\n"

# Mentions are not invocations. Each of these passed before the gate read only
# the `run:` value of a step, as shell.
scenario "a trailing shell comment naming the target does not count" 1 \
  "$MAKEFILE" "${HEADER}      - run: echo hi # make lint\n"

scenario "the target inside an echoed string does not count" 1 \
  "$MAKEFILE" "${HEADER}      - run: echo \"run make lint locally\"\n"

scenario "a step NAME that says make lint does not count" 1 \
  "$MAKEFILE" "${HEADER}      - name: make lint\n        run: echo nothing\n"

scenario "make -n (a dry run) does not run the target" 1 \
  "$MAKEFILE" "${HEADER}      - run: make -n lint\n"

scenario "make -C <another directory> runs another Makefile" 1 \
  "$MAKEFILE" "${HEADER}      - run: make -C sub lint\n"

scenario "make after cd elsewhere runs another Makefile" 1 \
  "$MAKEFILE" "${HEADER}      - run: cd sub && make lint\n"

scenario "a step with a working-directory runs another Makefile" 1 \
  "$MAKEFILE" "${HEADER}      - run: make lint\n        working-directory: sub\n"

scenario "a job switched off with if: false covers nothing" 1 \
  "$MAKEFILE" "name: lint\non: [pull_request]\njobs:\n  lint:\n    if: false\n    steps:\n      - run: make lint\n"

scenario "a workflow that only runs by hand gates no pull request" 1 \
  "$MAKEFILE" "name: lint\non:\n  workflow_dispatch:\njobs:\n  lint:\n    steps:\n      - run: make lint\n"

# What a real workflow looks like still counts.
scenario "a multi-line run block with flags and a push trigger counts" 0 \
  "$MAKEFILE" "name: lint\non:\n  pull_request:\n  push:\n    branches: [main]\njobs:\n  lint:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n      - name: Run every check\n        run: |\n          set -e\n          make -s -j4 lint  # all of it\n"

scenario "an env assignment before make still counts" 0 \
  "$MAKEFILE" "${HEADER}      - run: PYTHONDONTWRITEBYTECODE=1 make lint\n"

# Before the gate read the run values, `grep -q` under pipefail on a large
# workflow got SIGPIPE and reported a covered target as missing (red in a
# consuming project once its ci.yml grew).
big="${HEADER}      - run: make lint\n"
for i in $(seq 1 4000); do big="${big}      - run: echo filler step $i with enough text to make the file large\n"; done
scenario "a covered target in a large workflow is found" 0 "$MAKEFILE" "$big"

# The registry-gate reachability check had the same SIGPIPE: `make -n lint`
# printed a lot, grep -q stopped at the first match, and a reached gate read
# as "never runs it".
dir="$(mktemp -d "$WORK/case.XXXXXX")"; mkdir -p "$dir/.github/workflows" "$dir/scripts"; git -C "$dir" init -q -b main
printf '{"registries": []}\n' > "$dir/registries.json"
touch "$dir/scripts/check-registry-drift.sh" "$dir/scripts/check-registry-ids.sh"
{ printf 'lint:\n\t@./scripts/check-registry-drift.sh\n\t@./scripts/check-registry-ids.sh\n'
  for i in $(seq 1 20000); do printf '\t@echo filler line %s for a long dry run\n' "$i"; done
} > "$dir/Makefile"
printf "${HEADER}      - run: make lint\n" > "$dir/.github/workflows/lint.yml"
if ( cd "$dir" && "$GATE" >/dev/null 2>&1 ); then ok "a registry gate reached by a long lint recipe is found (no SIGPIPE)"
else bad "a registry gate reached by a long lint recipe was reported as never run"; fi

echo ""
echo "=== $pass passed, $fail failed ==="
[ "$fail" -eq 0 ] || exit 1
