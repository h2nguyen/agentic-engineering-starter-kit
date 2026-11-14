#!/usr/bin/env bash
# ACCEPTANCE TEST: on Claude Code the workspace graph reaches the agent without
# being asked for — after an edit, and when a turn ends.
#
# The contract:
#   1. after an edit to a file another artifact cites, the hook hands the agent
#      the citers; for every other file it says nothing at all;
#   2. each distinct thing is said once per session, not once per edit;
#   3. when a turn ends with a typed link that resolves to nothing, the hook
#      sends the failure back once — and never loops, never blocks twice;
#   4. a hook that cannot do its job is silent and exits 0: it adds context,
#      it is not a gate, and `make lint` is still the gate behind it;
#   5. it judges the checkout the edited file is in, and leaves nothing behind
#      in the repository.
#
# The control case is the reason the hook exists: rewriting a cited rule leaves
# every gate green, because the link still resolves. Nothing told the editor
# which script and which reviewer now hold a rule that says something else.
#
# Runs from the kit only — it installs into scratch repositories.
#
# Usage: test-graph-hooks.sh [-v]
set -uo pipefail
VERBOSE=0; [ "${1:-}" = "-v" ] && VERBOSE=1
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"; trap '[ "$VERBOSE" -eq 1 ] || rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()  { printf '  ok   — %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL — %s\n' "$1"; fail=$((fail + 1)); }

BOOTSTRAP="$KIT_DIR/bootstrap.sh"
PY="$KIT_DIR/scripts/python.sh"   # Python under whatever name this machine gives it
if [ ! -f "$BOOTSTRAP" ]; then
  echo "SKIP: bootstrap.sh not found beside this test (only runs from the kit itself)"
  exit 0
fi

# The hook keeps its "already said" marks in the temporary directory. Give it
# one of its own, so a run neither reads nor leaves marks in the real one.
export TMPDIR="$WORK/tmp"; mkdir -p "$TMPDIR"
unset WORKSPACE_GRAPH_HOOK WORKSPACE_GRAPH_HOOK_DEBUG

fresh_repo() { # $1 = dir
  mkdir -p "$1"; git -C "$1" init -q -b main
  git -C "$1" config user.email t@example.invalid; git -C "$1" config user.name t
  git -C "$1" config commit.gpgsign false
}
field() { # $1 = JSON text, $2 = dotted path → the value, or nothing
  printf '%s' "$1" | "$PY" -c '
import json, sys
try:
    value = json.load(sys.stdin)
    for key in sys.argv[1].split("."):
        value = value[key]
    print(value)
except Exception:
    pass' "$2"
}
# The hook is run the way Claude Code runs it: the command string registered
# in settings.json, through `sh -c`, with $CLAUDE_PROJECT_DIR set. Calling the
# file directly would test a command nobody registered.
registered() { # $1 = event (PostToolUse|Stop) → the command settings.json registers for it
  "$PY" -c 'import json, sys; print(json.load(open(sys.argv[1]))["hooks"][sys.argv[2]][0]["hooks"][0]["command"])' \
    "$R/.claude/settings.json" "$1" 2>/dev/null
}
run_hook() { # $1 = registered command; the event JSON on stdin
  CLAUDE_PROJECT_DIR="$R" sh -c "$1"
}
post_edit() { # $1 = session, $2 = file → the hook output in $OUT, its status in $RC
  OUT="$(printf '{"session_id":"%s","cwd":"%s","hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"%s"}}' \
           "$1" "$(dirname "$2")" "$2" | run_hook "$ON_EDIT" 2>"$WORK/err")"; RC=$?
}
stop() { # $1 = session, $2 = cwd, $3 = stop_hook_active (true|false)
  OUT="$(printf '{"session_id":"%s","cwd":"%s","hook_event_name":"Stop","stop_hook_active":%s}' \
           "$1" "$2" "$3" | run_hook "$ON_STOP" 2>"$WORK/err")"; RC=$?
}

echo "=== install: the hook lands for Claude Code, registered, and for no other tool ==="
# A path with a space, on purpose: hook commands run through `sh -c`.
R="$WORK/my project"; fresh_repo "$R"
"$BOOTSTRAP" --tool claude --target "$R" > "$WORK/install.log" 2>&1 || { bad "bootstrap exited non-zero"; cat "$WORK/install.log"; }
HOOK="$R/.claude/hooks/workspace-graph.py"
[ -x "$HOOK" ] && ok "the hook is installed and executable" || bad "no executable .claude/hooks/workspace-graph.py"
"$PY" -c 'import json,sys; json.load(open(sys.argv[1]))' "$R/.claude/settings.json" 2>/dev/null \
  && ok "the installed settings.json is valid JSON" || bad "settings.json does not parse"
settings="$(cat "$R/.claude/settings.json" 2>/dev/null)"
case "$settings" in
  *'\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/workspace-graph.py post-edit'*'\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/workspace-graph.py stop'*)
    ok "settings.json registers it after an edit and at the end of a turn, with the project path quoted" ;;
  *) bad "settings.json does not register both hook events with a quoted project path" ;;
esac
ON_EDIT="$(registered PostToolUse)"; ON_STOP="$(registered Stop)"
# `python3` is not Python everywhere: on Windows it can be a Store alias, and
# the interpreter is `python` or `py`. A hook registered by a fixed name fails
# there, and a hook fails where nobody is looking.
case "$ON_EDIT$ON_STOP" in
  *python3*|*"python "*) bad "a hook command names the interpreter itself instead of going through scripts/python.sh" ;;
  *scripts/python.sh*scripts/python.sh*) ok "both hook commands start Python through scripts/python.sh, not by a fixed name" ;;
  *) bad "the hook commands do not go through scripts/python.sh: $ON_EDIT" ;;
esac
matcher="$("$PY" -c 'import json,sys; print(json.load(open(sys.argv[1]))["hooks"]["PostToolUse"][0]["matcher"])' "$R/.claude/settings.json" 2>/dev/null)"
case "$matcher" in *Edit*Write*) ok "the edit hook matches the Edit and Write tools" ;; *) bad "the edit hook's matcher is '$matcher'" ;; esac
for tool in agents cursor copilot; do
  O="$WORK/$tool"; fresh_repo "$O"; "$BOOTSTRAP" --tool "$tool" --target "$O" >/dev/null 2>&1
  [ ! -e "$O/.claude" ] && ok "$tool: nothing of the hook is installed (no .claude/ on that layout)" \
    || bad "$tool: the installer created .claude/ on a layout that does not use it"
done

# A rule, the script that enforces it and the incident behind it.
mkdir -p "$R/scripts"
printf '# Testing Rules\n\nTest files sit beside their source.\n' > "$R/.claude/rules/testing.md"
printf '#!/usr/bin/env bash\n# Enforces: RULE:testing — test files sit beside their source\nexit 0\n' > "$R/scripts/check-tests.sh"
chmod +x "$R/scripts/check-tests.sh"
mkdir -p "$R/src"; printf 'print("hello")\n' > "$R/src/app.py"
git -C "$R" add -A >/dev/null; git -C "$R" commit -q -m "install the kit; add a rule and its check" 2>/dev/null

echo "=== control: rewriting a cited rule leaves every gate green (this MUST reproduce the defect) ==="
printf '# Testing Rules\n\nTest files live under tests/, never beside their source.\n' > "$R/.claude/rules/testing.md"
if ( cd "$R" && ./scripts/check-graph-links.sh >/dev/null 2>&1 && ./scripts/check-registry-ids.sh >/dev/null 2>&1 ); then
  ok "control: the rule now says the opposite of what its check enforces, and the gates pass (defect reproduced)"
else
  bad "control: a gate already catches a rewritten rule — the hook's premise is wrong"
fi

echo "=== after an edit: the citers reach the agent, once ==="
post_edit s1 "$R/.claude/rules/testing.md"
context="$(field "$OUT" hookSpecificOutput.additionalContext)"
[ "$RC" -eq 0 ] && [ "$(field "$OUT" hookSpecificOutput.hookEventName)" = "PostToolUse" ] \
  && ok "editing the cited rule returns context in the shape Claude Code adds to the conversation" \
  || bad "no PostToolUse context came back (rc=$RC): $OUT"
case "$context" in
  *RULE:testing*scripts/check-tests.sh:2*) ok "and it names the script that enforces the rule, with its line" ;;
  *) bad "the context does not name scripts/check-tests.sh:2 — got: $context" ;;
esac
post_edit s1 "$R/src/app.py"
[ "$RC" -eq 0 ] && [ -z "$OUT" ] && ok "editing a file nothing cites says nothing" || bad "an uncited file produced output: $OUT"
post_edit s1 "$R/.claude/rules/testing.md"
[ "$RC" -eq 0 ] && [ -z "$OUT" ] && ok "the same note is not repeated on the next edit in that session" \
  || bad "the note was repeated in the same session"
post_edit s2 "$R/.claude/rules/testing.md"
[ -n "$OUT" ] && ok "a new session is told again" || bad "a second session was told nothing"
printf '# Flaky clock\n\n**Related:** RULE:testing\n' > "$R/docs/DEBUGGING-KNOWLEDGE-BASE.d/2026-03-01-flaky-clock.md"
post_edit s1 "$R/.claude/rules/testing.md"
case "$(field "$OUT" hookSpecificOutput.additionalContext)" in
  *flaky-clock*) ok "when the citers change, the first session hears the new list" ;;
  *) bad "a changed list of citers was suppressed as already said" ;;
esac
rm -f "$R/docs/DEBUGGING-KNOWLEDGE-BASE.d/2026-03-01-flaky-clock.md"

printf '# Security Rules\n\n**Related:** RULE:gone\n' > "$R/.claude/rules/security.md"
post_edit s1 "$R/.claude/rules/security.md"
case "$(field "$OUT" hookSpecificOutput.additionalContext)" in
  *security.md:3*"resolves to nothing"*) ok "a link just written to nothing is reported at the edit, with its line" ;;
  *) bad "a dangling link in the edited file was not reported: $OUT" ;;
esac
rm -f "$R/.claude/rules/security.md"

echo "=== the checkout the file is in, not the one the session started in ==="
# In a Claude Code worktree $CLAUDE_PROJECT_DIR still names the main checkout.
# The hook that runs is the main checkout's; the graph it reads must be the
# one the edited file belongs to.
W="$WORK/worktree copy"; git clone -q "$R" "$W" 2>/dev/null
printf '#!/usr/bin/env bash\n# Enforces: RULE:testing — only in this checkout\nexit 0\n' > "$W/scripts/check-only-here.sh"
OUT="$(printf '{"session_id":"s3","cwd":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$R" "$W/.claude/rules/testing.md" \
        | run_hook "$ON_EDIT" 2>/dev/null)"
case "$(field "$OUT" hookSpecificOutput.additionalContext)" in
  *check-only-here.sh*) ok "the citers come from the edited file's own checkout" ;;
  *) bad "the hook read the session's checkout instead of the file's" ;;
esac

echo "=== when a turn ends: a link that broke comes back once ==="
git -C "$R" checkout -q -- . 2>/dev/null
stop s4 "$R" false
[ "$RC" -eq 0 ] && [ -z "$OUT" ] && ok "a turn that ends with every link resolving is not interrupted" \
  || bad "the stop hook spoke on a green workspace: $OUT"
git -C "$R" mv .claude/rules/testing.md .claude/rules/test-layout.md
stop s4 "$R/scripts" false
reason="$(field "$OUT" reason)"
[ "$RC" -eq 0 ] && [ "$(field "$OUT" decision)" = "block" ] \
  && ok "after a rename that breaks a link, the turn is held and the agent is told why" \
  || bad "a broken link did not hold the turn (rc=$RC): $OUT"
case "$reason" in
  *scripts/check-tests.sh:2*RULE:testing*) ok "the reason names the citing file, the line and the token" ;;
  *) bad "the reason does not name scripts/check-tests.sh:2 and RULE:testing — got: $reason" ;;
esac
stop s4 "$R" true
[ "$RC" -eq 0 ] && [ -z "$OUT" ] && ok "a turn already continued by a stop hook is let go (no loop)" \
  || bad "the hook blocked again while stop_hook_active was true"
stop s4 "$R" false
[ "$RC" -eq 0 ] && [ -z "$OUT" ] && ok "the same failure does not hold a second turn in that session" \
  || bad "the same failure blocked twice in one session"
stop s5 "$R" false
[ "$(field "$OUT" decision)" = "block" ] && ok "another session is told" || bad "a new session was not told about the broken link"
git -C "$R" mv .claude/rules/test-layout.md .claude/rules/testing.md

echo "=== a hook that cannot do its job is silent, and exits 0 ==="
OUT="$(printf 'this is not json' | run_hook "$ON_EDIT" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && [ -z "$OUT" ] && ok "input that is not JSON: silent" || bad "malformed input: rc=$RC out=$OUT"
OUT="$(: | run_hook "$ON_STOP" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && [ -z "$OUT" ] && ok "no input at all: silent" || bad "empty input: rc=$RC out=$OUT"
mkdir -p "$WORK/loose"; printf 'x\n' > "$WORK/loose/notes.md"
post_edit s6 "$WORK/loose/notes.md"
[ "$RC" -eq 0 ] && [ -z "$OUT" ] && [ ! -s "$WORK/err" ] && ok "a file outside any repository: silent" || bad "a file outside a repository: rc=$RC out=$OUT"
B="$WORK/no tool"; git clone -q "$R" "$B" 2>/dev/null; rm -f "$B/scripts/graph_tool.py"
post_edit s6 "$B/.claude/rules/testing.md"
[ "$RC" -eq 0 ] && [ -z "$OUT" ] && ok "a repository without the graph tool: silent after an edit" || bad "missing tool after an edit: rc=$RC out=$OUT"
stop s6 "$B" false
[ "$RC" -eq 0 ] && [ -z "$OUT" ] && ok "and silent when the turn ends" || bad "missing tool at stop: rc=$RC out=$OUT"
printf '{ this is not json' > "$B/registries.json"; cp "$R/scripts/graph_tool.py" "$B/scripts/graph_tool.py"
stop s6 "$B" false
[ "$RC" -eq 0 ] && [ -z "$OUT" ] && ok "a broken registries.json is the gate's to report, not a reason to hold a turn" \
  || bad "a config error held the turn: $OUT"
git -C "$R" mv .claude/rules/testing.md .claude/rules/test-layout.md
OUT="$(printf '{"session_id":"s7","cwd":"%s","stop_hook_active":false}' "$R" | WORKSPACE_GRAPH_HOOK=off run_hook "$ON_STOP" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && [ -z "$OUT" ] && ok "WORKSPACE_GRAPH_HOOK=off switches it off for a run" || bad "the off switch did not silence the hook"
git -C "$R" mv .claude/rules/test-layout.md .claude/rules/testing.md

echo "=== a machine where Python is not called python3 ==="
# What Windows looks like from Git Bash: python3 is on PATH and is not Python,
# and the interpreter answers to `python`.
REAL_PY="$("$PY" -c 'import sys; print(sys.executable)')"
SHADOW="$WORK/not-python3"; mkdir -p "$SHADOW"
printf '#!/bin/sh\necho "Python was not found; run without arguments to install from the Store" >&2\nexit 49\n' > "$SHADOW/python3"
printf '#!/bin/sh\nexec "%s" "$@"\n' "$REAL_PY" > "$SHADOW/python"; chmod +x "$SHADOW/python3" "$SHADOW/python"
event="$(printf '{"session_id":"s8","cwd":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$R" "$R/.claude/rules/testing.md")"
OUT="$(printf '%s' "$event" | ( unset PYTHON; PATH="$SHADOW:$PATH" CLAUDE_PROJECT_DIR="$R" sh -c "python3 \"\$CLAUDE_PROJECT_DIR\"/.claude/hooks/workspace-graph.py post-edit" ) 2>/dev/null)"
[ -z "$OUT" ] && ok "control: registered as 'python3 <hook>', the hook says nothing there — and nothing says it failed (defect reproduced)" \
  || bad "control: the fixed-name command worked on a machine where python3 is not Python"
OUT="$(printf '%s' "$event" | ( unset PYTHON; PATH="$SHADOW:$PATH" run_hook "$ON_EDIT" ) 2>"$WORK/err")"
case "$(field "$OUT" hookSpecificOutput.additionalContext)" in
  *scripts/check-tests.sh:2*) ok "as registered, the hook finds Python under its other name and the citers arrive" ;;
  *) bad "the registered hook command said nothing where Python is called python: $(cat "$WORK/err")" ;;
esac
git -C "$R" mv .claude/rules/testing.md .claude/rules/test-layout.md
OUT="$(printf '{"session_id":"s8","cwd":"%s","stop_hook_active":false}' "$R" | ( unset PYTHON; PATH="$SHADOW:$PATH" run_hook "$ON_STOP" ) 2>/dev/null)"
[ "$(field "$OUT" decision)" = "block" ] && ok "and a broken link still holds the turn there" || bad "the stop hook said nothing where Python is called python"
git -C "$R" mv .claude/rules/test-layout.md .claude/rules/testing.md

echo "=== nothing is left behind in the repository ==="
left="$(git -C "$R" status --short)"
[ -z "$left" ] && ok "after every case above the working tree is exactly as committed" \
  || bad "the hook left changes in the repository: $(echo "$left" | tr '\n' ' ')"
pyc="$(find "$R" -name '__pycache__' -o -name '*.pyc' | grep -v '/.git/' | wc -l | tr -d ' ')"
[ "$pyc" -eq 0 ] && ok "and no bytecode" || bad "the hook left $pyc bytecode path(s)"

echo "=== a repository whose settings predate the hook is told what to add ==="
"$PY" - "$R/.claude/settings.json" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
data["hooks"] = {"SessionStart": data["hooks"]["SessionStart"]}
json.dump(data, open(path, "w"), indent=2)
PY
before="$(cat "$R/.claude/settings.json")"
"$BOOTSTRAP" --tool claude --target "$R" > "$WORK/rerun.log" 2>&1
[ "$before" = "$(cat "$R/.claude/settings.json")" ] && ok "a re-run does not edit the existing settings.json" \
  || bad "the installer modified an existing settings.json"
grep -q 'workspace-graph.py post-edit' "$WORK/rerun.log" && grep -q 'workspace-graph.py stop' "$WORK/rerun.log" \
  && ok "and prints the two hook entries to add" || bad "the re-run does not say how to register the hook"
git -C "$R" checkout -q -- .claude/settings.json
"$BOOTSTRAP" --tool claude --target "$R" > "$WORK/rerun2.log" 2>&1
! grep -q 'workspace-graph.py post-edit' "$WORK/rerun2.log" \
  && ok "a repository that registers the hook is not told to" || bad "a registered hook is still reported as missing"

echo ""; echo "=== $pass passed, $fail failed ==="
[ "$VERBOSE" -eq 1 ] && echo "scratch repos kept in $WORK"
[ "$fail" -eq 0 ] || exit 1
