#!/usr/bin/env bash
# ACCEPTANCE TEST: the kit's tools run on a machine where Python is not called
# `python3`.
#
# `python3` is the name on macOS and Linux. On Windows (Git Bash) Python is
# usually `python`, or only the `py` launcher — and `python3` can be a Store
# alias that is on PATH, runs, and is not Python. Every command the kit runs
# itself therefore goes through scripts/python.sh, which accepts a name only
# after it has run a line of Python 3.9 or newer.
#
# The contract:
#   1. python3, then python, then `py -3` — the first that really is Python;
#   2. a name that is on PATH and is not a usable Python is skipped, not trusted;
#   3. PYTHON names the interpreter outright, spaces in its path included, and
#      a PYTHON that does not work is an error, never a silent fallback;
#   4. arguments, standard input and the exit status pass through untouched;
#   5. with no Python at all, the failure says what was tried and what to set.
#
# The control case is the defect: on such a machine the command as the kit
# used to write it — `python3 <script>` — does not run.
#
# Usage: test-python-launcher.sh [-v]
set -uo pipefail
VERBOSE=0; [ "${1:-}" = "-v" ] && VERBOSE=1
LAUNCHER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/python.sh"
WORK="$(mktemp -d)"; trap '[ "$VERBOSE" -eq 1 ] || rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()  { printf '  ok   — %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL — %s\n' "$1"; fail=$((fail + 1)); }

if [ ! -f "$LAUNCHER" ]; then
  echo "  FAIL — scripts/python.sh is not installed beside the tests"
  echo ""; echo "=== 0 passed, 1 failed ==="; exit 1
fi

# The one real interpreter on this machine, by its full path, so the stand-ins
# below can hand over to it whatever they are called. Found through the
# launcher: this suite must not name an interpreter either.
REAL="$("$LAUNCHER" -c 'import sys; print(sys.executable)' 2>/dev/null)"
if [ -z "$REAL" ]; then
  echo "  FAIL — scripts/python.sh found no Python on this machine:"
  "$LAUNCHER" --which 2>&1 | sed 's/^/         /'
  echo ""; echo "=== 0 passed, 1 failed ==="; exit 1
fi

# A machine is a directory that comes first on PATH. `real <name>` puts a
# working Python there under that name; `stub <name>` puts something that is
# on PATH, runs, and is not Python — what a Windows Store alias is.
machine() { M="$WORK/$1"; mkdir -p "$M"; }
real() { printf '#!/bin/sh\nexec "%s" "$@"\n' "$REAL" > "$M/$1"; chmod +x "$M/$1"; }
stub() { printf '#!/bin/sh\necho "Python was not found; run without arguments to install from the Store" >&2\nexit 49\n' > "$M/$1"; chmod +x "$M/$1"; }
on() { ( unset PYTHON; PATH="$M:$PATH" "$@" ); }

echo "=== control: where python3 is not Python, the old command does not run (this MUST reproduce the defect) ==="
machine windows; stub python3; real python; stub py
if on python3 -c 'print("hello")' >/dev/null 2>&1; then
  bad "control: python3 ran — the stand-in machine is not standing in for anything"
else
  ok "control: 'python3 <script>' fails on a machine whose Python is called python (defect reproduced)"
fi

echo "=== contract: the first name that really is Python ==="
[ "$(on "$LAUNCHER" --which)" = "python" ] && ok "python3 is a stand-in that is not Python: it is skipped, and python is used" \
  || bad "expected python, got '$(on "$LAUNCHER" --which 2>&1)'"
[ "$(on "$LAUNCHER" -c 'print(6 * 7)')" = "42" ] && ok "and a script runs through it" || bad "a script did not run through the launcher"

machine launcher-only; stub python3; stub python
printf '#!/bin/sh\n[ "$1" = "-3" ] || { echo "py: expected -3" >&2; exit 2; }\nshift\nexec "%s" "$@"\n' "$REAL" > "$M/py"; chmod +x "$M/py"
[ "$(on "$LAUNCHER" --which)" = "py -3" ] && ok "only the py launcher is Python: it is called as 'py -3'" \
  || bad "expected 'py -3', got '$(on "$LAUNCHER" --which 2>&1)'"
[ "$(on "$LAUNCHER" -c 'print(6 * 7)')" = "42" ] && ok "and a script runs through it" || bad "a script did not run through 'py -3'"

machine posix; real python3; stub python
[ "$(on "$LAUNCHER" --which)" = "python3" ] && ok "python3 is Python: it is used, and nothing else is tried" \
  || bad "expected python3, got '$(on "$LAUNCHER" --which 2>&1)'"

machine too-old; real python
printf '#!/bin/sh\nexit 1\n' > "$M/python3"; chmod +x "$M/python3"   # what the version probe returns on an old Python
[ "$(on "$LAUNCHER" --which)" = "python" ] && ok "a python3 older than 3.9 is passed over for one that is new enough" \
  || bad "an interpreter that fails the version probe was accepted"

echo "=== contract: PYTHON names the interpreter ==="
mkdir -p "$WORK/my tools"; printf '#!/bin/sh\nexec "%s" "$@"\n' "$REAL" > "$WORK/my tools/python-here"; chmod +x "$WORK/my tools/python-here"
machine windows
[ "$(PYTHON="$WORK/my tools/python-here" PATH="$M:$PATH" "$LAUNCHER" -c 'print(6 * 7)')" = "42" ] \
  && ok "PYTHON is used as given, with a space in its path" || bad "PYTHON with a space in its path did not run"
out="$(PYTHON="$WORK/no-such-python" PATH="$M:$PATH" "$LAUNCHER" -c 'print(6 * 7)' 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && [ "$out" != "42" ] && ok "a PYTHON that does not work is an error, not a quiet fallback to another interpreter" \
  || bad "a broken PYTHON was ignored and another interpreter was used (rc=$rc, out=$out)"
case "$out" in *PYTHON*no-such-python*) ok "and the error names the value that failed" ;; *) bad "the error does not name the PYTHON that failed: $out" ;; esac

echo "=== contract: arguments, input and status pass through ==="
machine windows
[ "$(on "$LAUNCHER" -c 'import sys; print("|".join(sys.argv[1:]))' one "two words" '$three')" = 'one|two words|$three' ] \
  && ok "arguments arrive one for one, spaces and all" || bad "arguments were split or changed"
[ "$(printf 'print(6 * 7)\n' | on "$LAUNCHER" -)" = "42" ] && ok "a program on standard input is run" || bad "standard input did not reach Python"
on "$LAUNCHER" -c 'import sys; sys.exit(7)'; rc=$?
[ "$rc" -eq 7 ] && ok "the exit status is Python's own" || bad "exit status was $rc, not 7"
out="$(LC_ALL=C on "$LAUNCHER" -c 'print("a → b")' 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "a → b" ] && ok "output is UTF-8 whatever the locale, so an arrow in a message cannot crash a tool" \
  || bad "non-ASCII output failed under the C locale (rc=$rc): $out"

echo "=== contract: no Python at all says so ==="
machine none; stub python3; stub python; stub py
out="$( ( unset PYTHON; PATH="$M" "$BASH" "$LAUNCHER" -c 'print(1)' ) 2>&1 )"; rc=$?
[ "$rc" -eq 127 ] && ok "it fails with 127, the status of a command that is not there" || bad "exit status was $rc, not 127"
case "$out" in
  *python3*python*"py -3"*PYTHON=*) ok "and says which names it tried and that PYTHON names one outright" ;;
  *) bad "the failure does not say what was tried and what to set: $out" ;;
esac

echo ""; echo "=== $pass passed, $fail failed ==="
[ "$VERBOSE" -eq 1 ] && echo "scratch machines kept in $WORK"
[ "$fail" -eq 0 ] || exit 1
