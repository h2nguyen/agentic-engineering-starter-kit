#!/usr/bin/env bash
# ACCEPTANCE TEST: check-self-application.sh holds this repository to its own
# kit — every rule, skill, agent and command the kit ships for Claude Code is
# applied here by a link into starter-kit/, never by a copy, and the
# workspace-graph hook is registered from where the kit keeps it.
#
# The control cases are the ways self-application decays: a rule added to the
# kit and never linked here, a link replaced by a copy that then drifts, a link
# that points somewhere else, and a hook entry that cannot find the graph tool.
#
# Usage: test-self-application.sh [-v]
set -uo pipefail
VERBOSE=0; [ "${1:-}" = "-v" ] && VERBOSE=1
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="$ROOT/scripts/check-self-application.sh"
WORK="$(mktemp -d)"; trap '[ "$VERBOSE" -eq 1 ] || rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()  { printf '  ok   — %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL — %s\n' "$1"; fail=$((fail + 1)); }

if ! ln -s target "$WORK/probe" 2>/dev/null || [ ! -L "$WORK/probe" ]; then
  echo "  skip — this platform cannot create symbolic links, so the cases cannot be built here"
  exit 0
fi

R="$WORK/repo"; mkdir -p "$R"; git -C "$R" init -q -b main
git -C "$R" config user.email t@example.invalid; git -C "$R" config user.name t
git -C "$R" config commit.gpgsign false
mkdir -p "$R/starter-kit/rules" "$R/starter-kit/skills/semver" "$R/starter-kit/skills/_template" \
         "$R/starter-kit/agents" "$R/starter-kit/commands" "$R/starter-kit/hooks" "$R/starter-kit/scripts" \
         "$R/.claude/rules" "$R/.claude/skills" "$R/.claude/agents" "$R/.claude/commands"
echo "# Testing" > "$R/starter-kit/rules/testing.md"
echo "# template" > "$R/starter-kit/rules/_rule-template.md"
echo "# Semver" > "$R/starter-kit/skills/semver/SKILL.md"
echo "# template" > "$R/starter-kit/skills/_template/SKILL.md"
echo "# Coach" > "$R/starter-kit/agents/agent-coach.md"
echo "# template" > "$R/starter-kit/agents/_agent-template.md"
echo "# Audit" > "$R/starter-kit/commands/audit.md"
: > "$R/starter-kit/hooks/workspace-graph.py"; : > "$R/starter-kit/scripts/graph_tool.py"
ln -s ../../starter-kit/rules/testing.md "$R/.claude/rules/testing.md"
ln -s ../../starter-kit/skills/semver "$R/.claude/skills/semver"
ln -s ../../starter-kit/agents/agent-coach.md "$R/.claude/agents/agent-coach.md"
ln -s ../../starter-kit/commands/audit.md "$R/.claude/commands/audit.md"
echo "# Ours" > "$R/.claude/rules/project-annotations.md"
settings() { # $1 = text appended to both hook commands
  cat > "$R/.claude/settings.json" <<EOF
{"hooks": {
  "PostToolUse": [{"matcher": "Edit|Write", "hooks": [{"type": "command",
    "command": "\"\$CLAUDE_PROJECT_DIR\"/starter-kit/scripts/python.sh \"\$CLAUDE_PROJECT_DIR\"/starter-kit/hooks/workspace-graph.py post-edit$1"}]}],
  "Stop": [{"hooks": [{"type": "command",
    "command": "\"\$CLAUDE_PROJECT_DIR\"/starter-kit/scripts/python.sh \"\$CLAUDE_PROJECT_DIR\"/starter-kit/hooks/workspace-graph.py stop$1"}]}]
}}
EOF
}
settings " --tool starter-kit/scripts/graph_tool.py"
commit() { git -C "$R" add -A >/dev/null; git -C "$R" commit -q -m "$1" >/dev/null; }
gate() { ( cd "$R" && "$GATE" > "$WORK/out" 2>&1 ); }
commit "applied"

echo "=== applied by reference: the gate passes ==="
gate && grep -q '^OK:' "$WORK/out" && ok "every shipped artifact linked, the hook registered: OK" \
  || { bad "the gate fails on a repository that applies its kit:"; sed 's/^/         /' "$WORK/out"; }
grep -q 'project-annotations' "$WORK/out" && bad "a file of the project's own under .claude/ was reported" \
  || ok "a file of the project's own beside the links is left alone, and templates need no link"

echo "=== the ways it decays, each named ==="
echo "# Security" > "$R/starter-kit/rules/security.md"; commit "a new rule in the kit"
gate; rc=$?
[ "$rc" -ne 0 ] && grep -q 'FAIL: .claude/rules/security.md' "$WORK/out" \
  && ok "a rule added to the kit and not linked here fails, and the missing link is named" \
  || bad "a kit rule with no link passed (exit $rc)"
grep -q 'ln -s ../../starter-kit/rules/security.md .claude/rules/security.md' "$WORK/out" \
  && ok "and the failure prints the command that adds it" || bad "the failure does not say how to add the link"
ln -s ../../starter-kit/rules/security.md "$R/.claude/rules/security.md"; commit "linked"
gate && ok "linked, it passes again" || bad "the gate still fails after the link was added"

rm "$R/.claude/rules/testing.md"; cp "$R/starter-kit/rules/testing.md" "$R/.claude/rules/testing.md"; commit "a copy"
gate; rc=$?
[ "$rc" -ne 0 ] && grep -q 'FAIL: .claude/rules/testing.md.*copy' "$WORK/out" \
  && ok "a link replaced by a copy fails: a copy is what drifts" || bad "a copy passed as applied (exit $rc)"
rm "$R/.claude/rules/testing.md"; ln -s ../../starter-kit/rules/security.md "$R/.claude/rules/testing.md"; commit "wrong target"
gate; rc=$?
[ "$rc" -ne 0 ] && grep -q 'FAIL: .claude/rules/testing.md' "$WORK/out" \
  && ok "a link that points at another file fails" || bad "a link to the wrong file passed (exit $rc)"
rm "$R/.claude/rules/testing.md"; ln -s ../../starter-kit/rules/testing.md "$R/.claude/rules/testing.md"; commit "restored"

settings ""; commit "hook without --tool"
gate; rc=$?
[ "$rc" -ne 0 ] && grep -q 'FAIL: .claude/settings.json' "$WORK/out" \
  && ok "a hook entry that does not name the graph tool fails: it would stay silent here" \
  || bad "a hook that cannot find the graph tool passed (exit $rc)"
settings " --tool starter-kit/scripts/graph_tool.py"; commit "restored"
rm "$R/.claude/settings.json"; commit "no settings"
gate; rc=$?
[ "$rc" -ne 0 ] && grep -q 'FAIL: .claude/settings.json' "$WORK/out" \
  && ok "no settings file at all fails" || bad "a repository with no hook registered passed (exit $rc)"

echo ""
echo "=== $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]
