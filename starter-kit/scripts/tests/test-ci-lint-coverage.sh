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
HEADER='name: lint\njobs:\n  lint:\n    steps:\n'

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

echo ""
echo "=== $pass passed, $fail failed ==="
[ "$fail" -eq 0 ] || exit 1
