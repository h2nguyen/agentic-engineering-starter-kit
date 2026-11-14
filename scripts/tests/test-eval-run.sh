#!/usr/bin/env bash
# ACCEPTANCE TEST: scripts/eval-run.sh — the recorder an evaluation of the kit
# runs its commands through (CONTRIBUTING.md § Evaluating a change).
#
# The run that prompted it lost two things. A build command was dispatched
# with no working directory, ran in the kit's own checkout and wrote two files
# there; and the evidence kept afterwards was a summary of the commands, not
# their output. So the contract is:
#   1. no command runs without an explicit, absolute, existing working
#      directory — a missing one is refused, never defaulted;
#   2. every run leaves a record: command, cwd, start and end, exit status,
#      and stdout and stderr in files of their own;
#   3. a test that is meant to fail is labelled as one, and a meant-to-fail
#      test that passes is an error;
#   4. a directory named with --guard is compared before and after, and a
#      command that changed it is reported with the paths — whatever the
#      command's own exit status was.
# The control case for 4 is a run that writes only inside its own directory.
#
# What this does NOT test, because the tool does not do it: preventing the
# write. The guard reports a change after the fact; it is not a sandbox.
#
# Usage: test-eval-run.sh [-v]
set -uo pipefail
VERBOSE=0; [ "${1:-}" = "-v" ] && VERBOSE=1
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN="$ROOT/scripts/eval-run.sh"
PY="$ROOT/starter-kit/scripts/python.sh"
WORK="$(mktemp -d)"; trap '[ "$VERBOSE" -eq 1 ] || rm -rf "$WORK"' EXIT
WORK="$(cd "$WORK" && pwd -P)"
pass=0; fail=0
ok()  { printf '  ok   — %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL — %s\n' "$1"; fail=$((fail + 1)); }

# field <log dir> <record number, 1-based> <python expression over r>
field() {
  "$PY" -B -c '
import json, sys
records = [json.loads(line) for line in open(sys.argv[1] + "/commands.jsonl", encoding="utf-8")]
r = records[int(sys.argv[2]) - 1]
print(eval(sys.argv[3]))
' "$1" "$2" "$3"
}

TARGET="$WORK/target"; SOURCE="$WORK/source"; LOG="$WORK/log"
mkdir -p "$TARGET" "$SOURCE/sub"
echo original > "$SOURCE/kept.txt"; echo original > "$SOURCE/sub/edited.txt"

echo "=== a command needs an explicit working directory ==="
( cd "$SOURCE" && "$RUN" --log "$LOG" -- sh -c 'echo ran > marker.txt' ) > "$WORK/out" 2>&1; rc=$?
[ "$rc" -eq 64 ] && [ ! -e "$SOURCE/marker.txt" ] \
  && ok "with no --cwd the runner refuses and runs nothing" \
  || bad "with no --cwd the command ran in the caller's directory (exit $rc)"
grep -q -- '--cwd' "$WORK/out" && ok "and the refusal names --cwd" || bad "the refusal does not name --cwd"
( cd "$SOURCE" && "$RUN" --cwd . --log "$LOG" -- sh -c 'echo ran > marker.txt' ) > /dev/null 2>&1; rc=$?
[ "$rc" -eq 64 ] && [ ! -e "$SOURCE/marker.txt" ] \
  && ok "a relative --cwd is refused: it would resolve against wherever the runner was started" \
  || bad "a relative --cwd was accepted (exit $rc)"
"$RUN" --cwd "$WORK/absent" --log "$LOG" -- true > /dev/null 2>&1; rc=$?
[ "$rc" -eq 64 ] && ok "a --cwd that does not exist is refused" || bad "a missing --cwd was accepted (exit $rc)"
"$RUN" --cwd "$TARGET" -- true > /dev/null 2>&1; rc=$?
[ "$rc" -eq 64 ] && ok "a run with no --log is refused: an unrecorded run is not evidence" \
  || bad "a run with no --log was accepted (exit $rc)"
# Options glued into one word by a shell that does not split them (zsh, with
# an unquoted variable) arrive as the first word of the "command". Running
# that produced six records of a command that never started.
"$RUN" --cwd "$TARGET" --log "$LOG" "--guard $SOURCE --quiet" -- true > "$WORK/out" 2>&1; rc=$?
[ "$rc" -eq 64 ] && grep -q 'not a command' "$WORK/out" \
  && ok "a word that looks like an option where the command should start is refused, not run" \
  || bad "an option-shaped word was taken for the command (exit $rc)"
[ ! -e "$LOG/commands.jsonl" ] && ok "a refused run records nothing" || bad "a refused run left a record"

echo "=== every run leaves a complete record ==="
"$RUN" --cwd "$TARGET" --log "$LOG" --label "prints both streams" -- \
  sh -c 'pwd -P; echo to-stderr >&2; echo ran > made-here.txt' > "$WORK/out" 2> "$WORK/err"; rc=$?
[ "$rc" -eq 0 ] && ok "a passing command exits 0" || bad "a passing command exited $rc"
[ -f "$TARGET/made-here.txt" ] && [ ! -e "$SOURCE/made-here.txt" ] \
  && ok "the command ran in the directory --cwd names, not the caller's" \
  || bad "the command did not run in --cwd"
[ "$(field "$LOG" 1 'r["cwd"]')" = "$TARGET" ] && ok "the record carries the cwd" || bad "the record's cwd is wrong"
[ "$(field "$LOG" 1 'r["command"][0]')" = "sh" ] && [ "$(field "$LOG" 1 'len(r["command"])')" = "3" ] \
  && ok "and the command, argument by argument" || bad "the record's command is wrong"
[ "$(field "$LOG" 1 'r["exit_status"]')" = "0" ] && ok "and the exit status" || bad "the record's exit status is wrong"
[ "$(field "$LOG" 1 'r["label"]')" = "prints both streams" ] && ok "and the label" || bad "the record's label is wrong"
[ "$(field "$LOG" 1 'r["started_utc"] <= r["ended_utc"] and r["started_utc"].endswith("Z")')" = "True" ] \
  && ok "and when it started and ended, in UTC" || bad "the record's timestamps are missing or out of order"
out_file="$LOG/$(field "$LOG" 1 'r["stdout_file"]')"; err_file="$LOG/$(field "$LOG" 1 'r["stderr_file"]')"
[ "$(cat "$out_file")" = "$TARGET" ] && ok "stdout is kept in a file of its own" || bad "stdout was not captured"
[ "$(cat "$err_file")" = "to-stderr" ] && ok "and stderr in another" || bad "stderr was not captured"
grep -qx "$TARGET" "$WORK/out" && grep -qx "to-stderr" "$WORK/err" \
  && ok "and both still reach the terminal, each on its own stream" || bad "the output was swallowed"

"$RUN" --cwd "$TARGET" --log "$LOG" -- sh -c 'exit 3' > /dev/null 2>&1; rc=$?
[ "$rc" -eq 3 ] && [ "$(field "$LOG" 2 'r["exit_status"]')" = "3" ] && [ "$(field "$LOG" 2 'r["outcome"]')" = "fail" ] \
  && ok "a failing command keeps its exit status, in the record and as the runner's own" \
  || bad "a failing command's status was lost (runner exit $rc)"
[ "$(field "$LOG" 2 'r["seq"]')" = "2" ] && ok "records are numbered in the order they ran" || bad "the second record is not seq 2"

echo "=== a test that is meant to fail says so ==="
"$RUN" --cwd "$TARGET" --log "$LOG" --expect fail --label "negative: must be rejected" -- sh -c 'exit 1' > /dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && [ "$(field "$LOG" 3 'r["outcome"]')" = "expected-fail" ] && [ "$(field "$LOG" 3 'r["exit_status"]')" = "1" ] \
  && ok "an intended failure is recorded as expected-fail, with the real exit status, and the runner exits 0" \
  || bad "an intended failure was not labelled (runner exit $rc)"
"$RUN" --cwd "$TARGET" --log "$LOG" --expect fail -- true > /dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && [ "$(field "$LOG" 4 'r["outcome"]')" = "unexpected-pass" ] \
  && ok "a meant-to-fail test that passes is an error: unexpected-pass" \
  || bad "a meant-to-fail test that passed was accepted (runner exit $rc)"

echo "=== a guarded directory is compared before and after ==="
"$RUN" --cwd "$TARGET" --log "$LOG" --guard "$SOURCE" -- sh -c 'echo fine > inside-target.txt' > /dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && [ "$(field "$LOG" 5 'r["guards"][0]["unchanged"]')" = "True" ] \
  && ok "control: a command that writes only in its own directory leaves the guard unchanged" \
  || bad "a clean run was reported as a boundary violation (exit $rc)"
# The failure this exists for: the command exits 0 and has written somewhere
# it had no business writing.
"$RUN" --cwd "$TARGET" --log "$LOG" --guard "$SOURCE" -- \
  sh -c "echo stray > '$SOURCE/planner.py'; echo changed > '$SOURCE/sub/edited.txt'; rm '$SOURCE/kept.txt'" > "$WORK/out" 2>&1; rc=$?
[ "$rc" -eq 97 ] && ok "a command that changed a guarded directory fails the run (97), though it exited 0 itself" \
  || bad "a write into a guarded directory went unreported (exit $rc)"
[ "$(field "$LOG" 6 'r["exit_status"]')" = "0" ] && [ "$(field "$LOG" 6 'r["outcome"]')" = "boundary-violation" ] \
  && ok "the record keeps the command's own status and names the outcome" || bad "the violation's record is wrong"
[ "$(field "$LOG" 6 'sorted(r["guards"][0]["added"])')" = "['planner.py']" ] \
  && [ "$(field "$LOG" 6 'sorted(r["guards"][0]["modified"])')" = "['sub/edited.txt']" ] \
  && [ "$(field "$LOG" 6 'sorted(r["guards"][0]["removed"])')" = "['kept.txt']" ] \
  && ok "and lists what was added, modified and removed" || bad "the changed paths are not listed"
grep -q 'planner.py' "$WORK/out" && ok "and says so on the terminal" || bad "the violation is only in the log"
"$RUN" --cwd "$TARGET" --log "$LOG" --guard relative/dir -- true > /dev/null 2>&1; rc=$?
[ "$rc" -eq 64 ] && ok "a relative --guard is refused" || bad "a relative --guard was accepted (exit $rc)"

# A guarded git checkout: a commit or a branch switch changes no file the
# walk sees differently from an edit, so HEAD and the branch are recorded too.
G="$WORK/guarded-repo"; mkdir -p "$G"; git -C "$G" init -q -b main
git -C "$G" config user.email t@example.invalid; git -C "$G" config user.name t; git -C "$G" config commit.gpgsign false
echo one > "$G/file.txt"; git -C "$G" add -A; git -C "$G" commit -q -m one
"$RUN" --cwd "$TARGET" --log "$LOG" --guard "$G" -- git -C "$G" checkout -q -b other > /dev/null 2>&1; rc=$?
[ "$rc" -eq 97 ] && [ "$(field "$LOG" 7 'r["guards"][0]["git_before"]["branch"] + ">" + r["guards"][0]["git_after"]["branch"]')" = "main>other" ] \
  && ok "a branch switch in a guarded checkout is a change, though no file differs" \
  || bad "a branch switch in a guarded checkout went unreported (exit $rc)"

echo ""
echo "=== $pass passed, $fail failed ==="
[ "$fail" -eq 0 ] || exit 1
