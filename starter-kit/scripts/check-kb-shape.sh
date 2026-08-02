#!/usr/bin/env bash
# Enforces: debugging-knowledge-base entry shape + typed cross-link syntax —
# the graph-ready substrate contract (see the KB file's header conventions and
# the guide § 5.6). Ready to run as shipped; wire into the umbrella lint target.
#
# Usage: check-kb-shape.sh [kb-file]     default: docs/DEBUGGING-KNOWLEDGE-BASE.md
#
# Checks:
#   1. Every '## ' heading is a well-formed entry: '## ISSUE-NNN: <title>'
#   2. Entry IDs are unique (stable, never reused)
#   3. Every entry carries the six required fields
#   4. Every '**Related:**' line uses valid typed-link tokens:
#      ISSUE-NNN | ADR-NNN | RULE:<slug> | SKILL:<slug> | SCRIPT:<slug> | DOC:<slug>
set -euo pipefail

KB="${1:-docs/DEBUGGING-KNOWLEDGE-BASE.md}"
if [ ! -f "$KB" ]; then
  echo "FAIL: knowledge base not found at $KB"
  exit 1
fi
fail=0

# 1. Heading shape
while IFS=: read -r lineno rest; do
  if ! printf '%s' "$rest" | grep -qE '^## ISSUE-[0-9]+: .+'; then
    echo "FAIL: $KB:$lineno — malformed entry heading (expected '## ISSUE-NNN: <title>'): $rest"
    fail=1
  fi
done < <(grep -n '^## ' "$KB" || true)

# 2. Unique IDs
dups="$(grep -oE '^## ISSUE-[0-9]+' "$KB" | sort | uniq -d || true)"
if [ -n "$dups" ]; then
  echo "FAIL: $KB — duplicate entry IDs (IDs are stable and never reused):"
  printf '%s\n' "$dups"
  fail=1
fi

# 3. Required fields per entry
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
  /^## ISSUE-[0-9]+/ { flush(); id = $2; sub(/:$/, "", id); startline = NR; body = ""; next }
  { body = body "\n" $0 }
  END { flush(); exit bad }
' "$KB" || fail=1

# 4. Related-line token syntax
while IFS=: read -r lineno rest; do
  tokens="$(printf '%s' "$rest" | sed -E 's/^\*\*Related:\*\* *//')"
  IFS=',' read -ra toks <<< "$tokens"
  for t in "${toks[@]}"; do
    t="$(printf '%s' "$t" | sed -E 's/^ +| +$//g')"
    [ -z "$t" ] && continue
    if ! printf '%s' "$t" | grep -qE '^(ISSUE-[0-9]+|ADR-[0-9]+|(RULE|SKILL|SCRIPT|DOC):[A-Za-z0-9._/-]+)$'; then
      echo "FAIL: $KB:$lineno — invalid Related token '$t' (expected ISSUE-NNN, ADR-NNN, or RULE|SKILL|SCRIPT|DOC:<slug>)"
      fail=1
    fi
  done
done < <(grep -n '^\*\*Related:\*\*' "$KB" || true)

if [ "$fail" -ne 0 ]; then
  echo "Fix per the KB file's header conventions (graph-ready substrate)."
  exit 1
fi
echo "OK: knowledge-base shape valid ($KB)"
