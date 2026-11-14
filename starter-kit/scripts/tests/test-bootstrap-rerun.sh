#!/usr/bin/env bash
# ACCEPTANCE TEST: bootstrap.sh is safe to re-run on a repository it created
# from scratch, and every tool layout receives the same rules.
#
# The contract:
#   1. a second run on a freshly bootstrapped repository changes nothing — no
#      file modified, no file added, and the .gitattributes registry block
#      present exactly once (test-brownfield-adoption.sh covers the case where
#      the block was appended to a file that already existed);
#   2. every tool layout gets the constitution and every shipped rule, at that
#      tool's rule location, with the constitution's rule links retargeted — and
#      the typed links the installed files carry resolve in that layout;
#   3. the installed SessionStart hook runs from a project path with a space
#      and appends its environment once, however often the session starts.
#
# Usage: test-bootstrap-rerun.sh [-v]
set -uo pipefail
VERBOSE=0; [ "${1:-}" = "-v" ] && VERBOSE=1
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"; trap '[ "$VERBOSE" -eq 1 ] || rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()  { printf '  ok   — %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL — %s\n' "$1"; fail=$((fail + 1)); }

# Runs from the kit itself; a repo it was installed into has no bootstrap.sh.
BOOTSTRAP="$KIT_DIR/bootstrap.sh"
if [ ! -f "$BOOTSTRAP" ]; then
  echo "SKIP: bootstrap.sh not found beside this test (only runs from the kit itself)"
  exit 0
fi

fresh_repo() { # $1 = dir
  mkdir -p "$1"; git -C "$1" init -q -b main
  git -C "$1" config user.email t@example.invalid; git -C "$1" config user.name t
  git -C "$1" config commit.gpgsign false
}

echo "=== greenfield: a second bootstrap run is a no-op ==="
R="$WORK/greenfield"; fresh_repo "$R"
"$BOOTSTRAP" --tool claude --target "$R" > "$WORK/run1.log" 2>&1 || { bad "first run exited non-zero"; cat "$WORK/run1.log"; }
git -C "$R" add -A >/dev/null; git -C "$R" commit -q -m "bootstrap" 2>/dev/null
"$BOOTSTRAP" --tool claude --target "$R" > "$WORK/run2.log" 2>&1 || { bad "second run exited non-zero"; cat "$WORK/run2.log"; }
changed="$(git -C "$R" status --short)"
[ -z "$changed" ] && ok "second run modified or added nothing" || bad "second run changed the tree: $(echo "$changed" | tr '\n' ' ')"
markers="$(grep -c '>>> starter-kit registries >>>' "$R/.gitattributes")"
[ "$markers" -eq 1 ] && ok ".gitattributes carries the registry block marker exactly once" || bad "marker present $markers times"
attrs="$(grep -c '^CHANGELOG.md .*merge=union' "$R/.gitattributes")"
[ "$attrs" -eq 1 ] && ok "and the CHANGELOG.md merge attribute exactly once" || bad "CHANGELOG.md attribute present $attrs times"
grep -q 'registry block already present' "$WORK/run2.log" \
  && ok "second run reports the block as already present" || bad "second run did not recognise its own block"
# A re-run is how the Level-4 layer and newer kit files arrive, so its output
# is read by someone whose repository is ALREADY in the fragment layout. The
# kept-file hint used to fire for any changelog or knowledge base it skipped,
# and told that reader to adopt files the kit itself had generated.
! grep -q 'adopt --registry' "$WORK/run2.log" \
  && ok "second run does not tell a repository already in the fragment layout to adopt" \
  || bad "second run tells an already-migrated repository to run adopt"

echo "=== the installed SessionStart hook runs, also from a path with a space ==="
# Hook commands run through `sh -c`. Unquoted, $CLAUDE_PROJECT_DIR splits at a
# space and the hook exits 127 — a non-blocking error, so it is silently gone.
R="$WORK/with space"; fresh_repo "$R"
"$BOOTSTRAP" --tool claude --target "$R" >/dev/null 2>&1 || bad "bootstrap into a path with a space exited non-zero"
cmd="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["hooks"]["SessionStart"][0]["hooks"][0]["command"])' "$R/.claude/settings.json")"
env_file="$WORK/claude-env"; : > "$env_file"
CLAUDE_PROJECT_DIR="$R" CLAUDE_ENV_FILE="$env_file" sh -c "$cmd" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "the hook command runs from a project path with a space" || bad "the hook command exited $rc from a path with a space"
CLAUDE_PROJECT_DIR="$R" CLAUDE_ENV_FILE="$env_file" sh -c "$cmd" >/dev/null 2>&1
lines="$(wc -l < "$env_file" | tr -d ' ')"
[ "$lines" -eq 1 ] && ok "a second SessionStart (resume, compaction) appends nothing new" || bad "the env file has $lines lines after two starts"

echo "=== every tool layout receives the constitution and every shipped rule ==="
# Templates (leading underscore) are not rules; everything else under rules/
# is a shipped rule and must land, whichever tool the repository uses.
expected_rules="$(cd "$KIT_DIR/rules" && ls *.md | grep -v '^_' | sort)"
for tool in claude agents cursor copilot; do
  R="$WORK/$tool"; fresh_repo "$R"
  "$BOOTSTRAP" --tool "$tool" --target "$R" > "$WORK/boot-$tool.out" 2> "$WORK/boot-$tool.err" || bad "$tool: bootstrap exited non-zero"
  # A fresh install skips nothing, and under `set -u` bash 3.2 (macOS) treats
  # the expansion of an EMPTY array as an unbound variable: the installer
  # printed that error twice and still exited 0.
  [ ! -s "$WORK/boot-$tool.err" ] && ok "$tool: a fresh install writes nothing to stderr" \
    || { bad "$tool: a fresh install wrote to stderr:"; head -3 "$WORK/boot-$tool.err" | cut -c1-160 | sed 's/^/         /'; }
  ! grep -q 'adopt --registry' "$WORK/boot-$tool.out" \
    && ok "$tool: a repository that had nothing is not told to adopt what it was just given" \
    || bad "$tool: a fresh install is told to run adopt on the template it just received"
  pointer="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["rule_pointer"])' "$R/registries.json")"
  [ -f "$R/$pointer" ] && ok "$tool: gate failures point at a rule file that exists ($pointer)" \
    || bad "$tool: registries.json points gate failures at $pointer, which is not there"
  case "$tool" in
    claude)  c="$R/CLAUDE.md";                        rules_dir="$R/.claude/rules" ;;
    copilot) c="$R/.github/copilot-instructions.md";  rules_dir="$R/docs/agent-rules" ;;
    *)       c="$R/AGENTS.md";                        rules_dir="$R/docs/agent-rules" ;;
  esac
  [ -f "$c" ] && ok "$tool: constitution at ${c#"$R"/}" || bad "$tool: no constitution at ${c#"$R"/}"
  installed="$(cd "$rules_dir" 2>/dev/null && ls *.md | sort)"
  [ "$installed" = "$expected_rules" ] \
    && ok "$tool: every shipped rule landed in ${rules_dir#"$R"/}" \
    || bad "$tool: ${rules_dir#"$R"/} holds: $(echo $installed)"
  if [ "$tool" = claude ]; then
    ! grep -q 'docs/agent-rules/' "$c" && ok "$tool: constitution links point at .claude/rules/" || bad "$tool: links retargeted by mistake"
  else
    ! grep -q '\.claude/rules/' "$c" && ok "$tool: constitution links retargeted to docs/agent-rules/" || bad "$tool: constitution still links .claude/rules/"
  fi
  # A later session never sees the kit. If the templates stay behind in it,
  # the first rule, check script, skill or reviewer that session writes is
  # rebuilt from memory — and each adopting agent dropped a different required
  # part (the litmus test, the incident link, the reviewer's cross-cutting
  # checks). They land where every tool layout can find them, out of the
  # always-loaded rules directory and out of the link gate's way.
  tdir="$R/docs/agent-templates"
  [ -f "$tdir/_rule-template.md" ] && [ -f "$tdir/check-convention.sh.template" ] \
    && [ -f "$tdir/_skill-template.md" ] && [ -f "$tdir/_agent-template.md" ] \
    && ok "$tool: the rule, check-script, skill and reviewer templates are in docs/agent-templates/" \
    || bad "$tool: templates missing from docs/agent-templates/: $(ls "$tdir" 2>/dev/null | tr '\n' ' ')"
  if [ "$tool" != claude ]; then
    ! grep -rq '\.claude/rules/' "$tdir" && ok "$tool: the templates point at docs/agent-rules/, where this layout keeps rules" \
      || bad "$tool: a template still points at .claude/rules/"
  fi
  # The gates cite the rules they enforce by token, not by path, so the same
  # header has to resolve whether the rules landed in .claude/rules/ or in
  # docs/agent-rules/. A link that only works for one tool is not tool-agnostic.
  if ( cd "$R" && ./scripts/check-graph-links.sh > "$WORK/links-$tool.log" 2>&1 ); then
    ok "$tool: every typed link the kit installs resolves in this layout"
  else
    bad "$tool: an installed typed link does not resolve:"; grep -E '^FAIL' "$WORK/links-$tool.log" | head -5 | sed 's/^/         /'
  fi
done

echo "=== the kit's own tools leave no bytecode behind in the repository ==="
# The installer ships no .gitignore, so a __pycache__ the tools create shows
# up as untracked files and rides into the next `git add -A`. A machine with
# PYTHONDONTWRITEBYTECODE set hides this, so it is unset here on purpose.
R="$WORK/claude"
unit="$(grep -m1 'unittest discover' "$R/registry.mk" | sed 's/^[[:space:]]*//')"
( cd "$R" && env -u PYTHONDONTWRITEBYTECODE make graph-links registry-ids >/dev/null 2>&1
  env -u PYTHONDONTWRITEBYTECODE sh -c "$unit" > "$WORK/unit.log" 2>&1
  env -u PYTHONDONTWRITEBYTECODE python3 scripts/graph_tool.py impact RULE:documentation >/dev/null 2>&1 )
left="$(find "$R" -name '__pycache__' -o -name '*.pyc' | grep -v '/.git/' | wc -l | tr -d ' ')"
[ "$left" -eq 0 ] && ok "the gates, the unit tests and a direct query leave no __pycache__ in the repository" \
  || bad "the kit's tools left $left bytecode path(s) in the repository"

# A green run must read as green. The unit tests exercise the gates' failure
# paths, and those used to print their FAIL lines straight into `make lint` —
# dozens of them on a passing run, which an agent scanning the output for
# "FAIL" reads as a broken build.
grep -q '^Ran [0-9]* tests' "$WORK/unit.log" && ! grep -q '^FAIL' "$WORK/unit.log" \
  && ok "a passing unit-test run prints no FAIL line" \
  || bad "a passing unit-test run prints $(grep -c '^FAIL' "$WORK/unit.log") FAIL line(s)"

echo "=== the Level-4 artifacts' links resolve once installed ==="
R="$WORK/meta"; fresh_repo "$R"
"$BOOTSTRAP" --tool claude --with-meta --target "$R" >/dev/null 2>&1 || bad "bootstrap --with-meta exited non-zero"
if ( cd "$R" && ./scripts/check-graph-links.sh > "$WORK/links-meta.log" 2>&1 ); then
  ok "agent-coach, the audit skill and command, and the workspace-graph skill cite only what was installed"
else
  bad "a Level-4 artifact cites something that was not installed:"; grep -E '^FAIL' "$WORK/links-meta.log" | head -5 | sed 's/^/         /'
fi
handoffs="$( cd "$R" && python3 scripts/graph_tool.py impact HUMAN 2>/dev/null | head -1 )"
case "$handoffs" in
  *"(0)"*|"") bad "the installed meta loop declares no human approval gate" ;;
  *) ok "the installed meta loop declares its human approval gates as hand-offs" ;;
esac

echo ""; echo "=== $pass passed, $fail failed ==="
[ "$VERBOSE" -eq 1 ] && echo "scratch repos kept in $WORK"
[ "$fail" -eq 0 ] || exit 1
