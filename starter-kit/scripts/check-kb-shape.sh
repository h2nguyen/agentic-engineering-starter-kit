#!/usr/bin/env bash
# Enforces: debugging-knowledge-base entry shape + typed cross-link syntax —
# the graph-ready substrate contract (see the KB file's header conventions).
# Ready to run as shipped; wire into the umbrella lint target.
#
# This validates the ASSEMBLED file, which is what other tools and humans read.
# `registry_tool.py check` validates the fragments it is assembled from. Both
# are worth running: a repository that has not adopted the fragment layout yet
# still gets this one, and it is the check that notices when a merge has
# mangled the generated artifact into something unparseable.
#
# Usage: check-kb-shape.sh [kb-file]     default: docs/DEBUGGING-KNOWLEDGE-BASE.md
# Env:   KB_ID_PREFIX (default ISSUE)    KB_ID_WIDTH (default 3, numeric scheme)
#
# Checks:
#   1. Every '## ' heading is a well-formed entry heading
#   2. Identifiers use ONE scheme consistently across the file
#   3. Identifiers are unique (stable, never reused)
#   4. Every entry carries the six required fields
#   5. Every '**Related:**' line uses valid typed-link tokens
set -euo pipefail

KB="${1:-docs/DEBUGGING-KNOWLEDGE-BASE.md}"
PREFIX="${KB_ID_PREFIX:-ISSUE}"
WIDTH="${KB_ID_WIDTH:-3}"

if [ ! -f "$KB" ]; then
  echo "FAIL: knowledge base not found at $KB"
  exit 1
fi
fail=0

# Identifier grammars. The digit count is EXACT on purpose: a pattern of
# '[0-9]+' treats ISSUE-7, ISSUE-07 and ISSUE-007 as three different
# identifiers, so a width variant walks straight past the uniqueness test
# below and lands a duplicate that reads as unique. Shape is asserted first
# for the same reason — uniqueness over an unvalidated shape buys nothing.
SLUG_ID="${PREFIX}-[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9]+(-[a-z0-9]+)*"
NUM_ID="${PREFIX}-[0-9]{${WIDTH}}"
ANY_ID="(${SLUG_ID}|${NUM_ID})"

# 1. Heading shape
while IFS=: read -r lineno rest; do
  if ! printf '%s' "$rest" | grep -qE "^## ${ANY_ID}: .+"; then
    echo "FAIL: $KB:$lineno — malformed entry heading: $rest"
    echo "      Expected '## ${PREFIX}-YYYY-MM-DD-<slug>: <title>'"
    echo "            or '## ${PREFIX}-$(printf '%0*d' "$WIDTH" 0 | tr '0' 'N'): <title>'"
    fail=1
  fi
done < <(grep -n '^## ' "$KB" || true)

# 2. One scheme per file. A file that mixes them has drifted: the two grammars
#    sort differently and cite differently, and readers stop being able to tell
#    at a glance whether an identifier is complete.
slug_count="$(grep -cE "^## ${SLUG_ID}: " "$KB" || true)"
num_count="$(grep -cE "^## ${NUM_ID}: " "$KB" || true)"
if [ "$slug_count" -gt 0 ] && [ "$num_count" -gt 0 ]; then
  echo "FAIL: $KB — mixes both identifier schemes ($slug_count slug, $num_count numeric)."
  echo "      Pick the one declared in registries.json; migrating existing"
  echo "      entries means leaving already-cited identifiers alone and"
  echo "      applying the new scheme only to new entries."
  fail=1
fi

# 3. Unique identifiers
dups="$(grep -oE "^## ${ANY_ID}" "$KB" | sort | uniq -d || true)"
if [ -n "$dups" ]; then
  echo "FAIL: $KB — duplicate entry identifiers (identifiers are stable and never reused):"
  printf '%s\n' "$dups"
  echo "      Rename the entry that is not yet on the default branch. Never"
  echo "      renumber one that is: it is a citation target."
  fail=1
fi

# 4. Required fields per entry
awk -v kb="$KB" '
  function flush(   n, f, i) {
    if (id == "") return
    n = split("Symptom|Investigation Trail|Root Cause|Fix|Prevention|Debug Shortcut", f, "|")
    for (i = 1; i <= n; i++) {
      if (index(body, "**" f[i] ":**") == 0) {
        printf "FAIL: %s:%d — %s is missing required field **%s:**\n", kb, startline, id, f[i]
        bad = 1
      }
    }
  }
  /^## / { flush(); id = $2; sub(/:$/, "", id); startline = NR; body = ""; next }
  { body = body "\n" $0 }
  END { flush(); exit bad }
' "$KB" || fail=1

# 5. Related-line token syntax
TOKEN="(${SLUG_ID}|${NUM_ID}|ADR-[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9]+(-[a-z0-9]+)*|ADR-[0-9]{${WIDTH}}|(RULE|SKILL|SCRIPT|DOC):[A-Za-z0-9._/-]+)"
while IFS=: read -r lineno rest; do
  tokens="$(printf '%s' "$rest" | sed -E 's/^\*\*Related:\*\* *//')"
  IFS=',' read -ra toks <<< "$tokens"
  for t in "${toks[@]}"; do
    t="$(printf '%s' "$t" | sed -E 's/^ +| +$//g')"
    [ -z "$t" ] && continue
    if ! printf '%s' "$t" | grep -qE "^${TOKEN}$"; then
      echo "FAIL: $KB:$lineno — invalid Related token '$t'"
      echo "      Expected an entry or decision-record identifier, or RULE|SKILL|SCRIPT|DOC:<slug>"
      fail=1
    fi
  done
done < <(grep -n '^\*\*Related:\*\*' "$KB" || true)

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Entries are authored as fragments; fix the fragment and regenerate:"
  echo "    make registry-generate"
  exit 1
fi
echo "OK: knowledge-base shape valid ($KB)"
