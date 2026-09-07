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
#      tool's rule location, with the constitution's rule links retargeted.
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

echo "=== every tool layout receives the constitution and every shipped rule ==="
# Templates (leading underscore) stay in the kit; everything else under rules/
# is a shipped rule and must land, whichever tool the repository uses.
expected_rules="$(cd "$KIT_DIR/rules" && ls *.md | grep -v '^_' | sort)"
for tool in claude agents cursor copilot; do
  R="$WORK/$tool"; fresh_repo "$R"
  "$BOOTSTRAP" --tool "$tool" --target "$R" >/dev/null 2>&1 || bad "$tool: bootstrap exited non-zero"
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
done

echo ""; echo "=== $pass passed, $fail failed ==="
[ "$VERBOSE" -eq 1 ] && echo "scratch repos kept in $WORK"
[ "$fail" -eq 0 ] || exit 1
