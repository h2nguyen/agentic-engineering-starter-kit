#!/usr/bin/env bash
# Agentic Engineering Starter Kit — compare an install's rules with this kit's,
# and take the kit's text for the ones you name.
#
# Step 3 of "Upgrading an existing install" (README.md). It stays in the kit,
# like bootstrap.sh: a repository the kit was installed into has no copy.
#
# Why not `diff` and `cp`: on Claude Code a rule may carry a `paths:` header —
# the installer writes one onto some rules, and an adopter may write one onto
# any. That header is the adopter's, and the kit's rule files have none. A
# file with a header never equals the kit's, so `diff -rq` reports it on every
# upgrade whether or not its text changed, and `cp` would take the header
# away. This compares and replaces the text UNDER the header.
#
# Usage:
#   upgrade-rules.sh [--target <repo-root>]                    list: same | differs | missing
#   upgrade-rules.sh [--target <repo-root>] --apply <rule>...  the kit's text, your header kept
#
# <rule> is a rule file's name without .md. Nothing is applied that you did not
# name: a rule one of your own commits changed is yours to merge by hand
# (`git log --oneline -- <file>` says whether one did). project-annotations.md
# is your file and is never listed.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(pwd)"
APPLY=0
NAMES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$(cd "${2:?--target needs a value}" && pwd)"; shift 2 ;;
    --apply)  APPLY=1; shift ;;
    -h|--help) sed -n '2,/^set -euo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
    *)  NAMES+=("${1%.md}"); shift ;;
  esac
done

if [ -d "$TARGET/.claude/rules" ]; then RULES_DIR=.claude/rules
elif [ -d "$TARGET/docs/agent-rules" ]; then RULES_DIR=docs/agent-rules
else
  echo "ERROR: no rules directory in $TARGET (.claude/rules/ or docs/agent-rules/)." >&2
  exit 1
fi

# The leading frontmatter block, delimiters included; nothing if there is none.
header() { awk 'NR==1 && $0!="---" {exit} {print} NR>1 && $0=="---" {exit}' "$1"; }
# The file without that block and without the one blank line that follows it.
text() {
  awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {fm=0; gap=1; next} fm {next}
       gap {gap=0; if ($0=="") next} {print}' "$1"
}
kit_rules() { ( cd "$KIT_DIR/rules" && ls *.md | grep -v '^_' | sed 's/\.md$//' ); }

if [ "$APPLY" -eq 0 ]; then
  if [ ${#NAMES[@]} -gt 0 ]; then
    echo "ERROR: to replace the text of ${NAMES[*]}, say --apply. Without it this only lists." >&2
    exit 1
  fi
  for rule in $(kit_rules); do
    f="$TARGET/$RULES_DIR/$rule.md"
    if [ ! -f "$f" ]; then
      printf 'missing  %s\n' "$rule"
    elif text "$f" | cmp -s - "$KIT_DIR/rules/$rule.md"; then
      printf 'same     %s\n' "$rule"
    else
      printf 'differs  %s\n' "$rule"
    fi
  done
  exit 0
fi

if [ ${#NAMES[@]} -eq 0 ]; then
  echo "ERROR: --apply needs the rules to replace, by name: --apply documentation shared-registries" >&2
  exit 1
fi
# Every name is checked before the first file is written.
for rule in "${NAMES[@]}"; do
  if [ ! -f "$KIT_DIR/rules/$rule.md" ] || [ "${rule#_}" != "$rule" ]; then
    echo "ERROR: the kit ships no rule named '$rule'. It ships: $(kit_rules | tr '\n' ' ')" >&2
    exit 1
  fi
  if [ ! -f "$TARGET/$RULES_DIR/$rule.md" ]; then
    echo "ERROR: $RULES_DIR/$rule.md is not installed here; bootstrap.sh adds a missing rule." >&2
    exit 1
  fi
done
for rule in "${NAMES[@]}"; do
  f="$TARGET/$RULES_DIR/$rule.md"
  if text "$f" | cmp -s - "$KIT_DIR/rules/$rule.md"; then
    printf 'same     %s (nothing to do)\n' "$rule"
    continue
  fi
  kept="$(header "$f")"
  {
    if [ -n "$kept" ]; then printf '%s\n\n' "$kept"; fi
    cat "$KIT_DIR/rules/$rule.md"
  } > "$f.tmp" && mv "$f.tmp" "$f"
  if [ -n "$kept" ]; then
    printf 'updated  %s (your header kept)\n' "$rule"
  else
    printf 'updated  %s\n' "$rule"
  fi
done
