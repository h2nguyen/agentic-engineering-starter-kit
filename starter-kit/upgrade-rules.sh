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
#   ... [--rules-dir <dir>]   where the rules are, relative to the target, when
#                             both .claude/rules/ and docs/agent-rules/ hold kit rules
#
# <rule> is the name of a rule the kit ships, without .md — a name, never a
# path. Nothing is applied that you did not name: a rule one of your own
# commits changed is yours to merge by hand (`git log --oneline -- <file>`
# says whether one did). project-annotations.md is your file and is never
# listed.
#
# A header is a block that opens with `---` on the first line and is closed by
# a later `---`. A first line `---` that is never closed is a thematic break,
# not a header. Line endings are compared as text: a rule checked out with
# CRLF is the same rule.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(pwd)"
APPLY=0
RULES_DIR=""
NAMES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$(cd "${2:?--target needs a value}" && pwd)"; shift 2 ;;
    --apply)  APPLY=1; shift ;;
    --rules-dir) RULES_DIR="${2:?--rules-dir needs a value}"; RULES_DIR="${RULES_DIR%/}"; shift 2 ;;
    -h|--help) sed -n '2,/^set -euo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
    *)  NAMES+=("${1%.md}"); shift ;;
  esac
done

kit_rules() { ( cd "$KIT_DIR/rules" && ls *.md | grep -v '^_' | sed 's/\.md$//' ); }
is_kit_rule() { kit_rules | grep -qxF -- "$1"; }
holds_kit_rules() { # $1 = directory relative to the target
  local rule
  for rule in $(kit_rules); do [ -f "$TARGET/$1/$rule.md" ] && return 0; done
  return 1
}
# Which rules directory. A repository can have both — one tool's layout beside
# a directory another tool or the adopter made — so the one meant is the one
# that holds rules the kit ships; if both do, the caller says which.
if [ -n "$RULES_DIR" ]; then
  if [ ! -d "$TARGET/$RULES_DIR" ]; then
    echo "ERROR: --rules-dir: $TARGET/$RULES_DIR is not a directory." >&2
    exit 1
  fi
else
  _found=""
  for _dir in .claude/rules docs/agent-rules; do
    if holds_kit_rules "$_dir"; then _found="$_found $_dir"; fi
  done
  case "$_found" in
    "")
      echo "ERROR: no rule the kit ships in $TARGET/.claude/rules/ or $TARGET/docs/agent-rules/." >&2
      echo "Is this the repository the kit was installed into? bootstrap.sh adds missing rules." >&2
      exit 1 ;;
    *" "*" "*)
      echo "ERROR: both$_found hold rules the kit ships. Say which to work on: --rules-dir <dir>" >&2
      exit 1 ;;
    *) RULES_DIR="${_found# }" ;;
  esac
fi

# Both read a file with its line endings normalised: `---\r` is `---`.
# The leading frontmatter block, delimiters included, as it is in the file;
# nothing if the first line is not `---` or the block is never closed.
header() {
  awk '{ line = $0; sub(/\r$/, "", line) }
       NR == 1 { if (line != "---") exit; buf = $0; next }
       { buf = buf "\n" $0; if (line == "---") { print buf; exit } }' "$1"
}
# The text: the file without that block and the one blank line after it, with
# LF line endings. A file with no closed block is all text.
text() {
  awk 'NR == FNR { line = $0; sub(/\r$/, "", line)
                   if (FNR == 1 && line != "---") nextfile_seen = 1
                   if (!nextfile_seen && FNR > 1 && line == "---" && !closed) closed = FNR
                   next }
       { sub(/\r$/, "") }
       closed && FNR <= closed { next }
       closed && FNR == closed + 1 && $0 == "" { next }
       { print }' "$1" "$1"
}
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
  # Against the list, not against the file system: `../../CLAUDE` is a path
  # that exists beside the kit's rules, and it is not a rule.
  if ! is_kit_rule "$rule"; then
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
