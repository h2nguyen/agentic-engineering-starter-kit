#!/usr/bin/env bash
# Enforces: DOC:AGENTIC-ENGINEERING-GUIDE § 3.3 — a rule file the kit ships is
# loaded into every session, so it stays under a line ceiling.
#
# Repository-only, like check-guide-templates.sh: it checks the rule files this
# kit ships, so bootstrap.sh does not install it and it lives in scripts/ here
# rather than in starter-kit/scripts/.
#
# Why it exists: two shipped rules had grown to 408 and 260 lines against the
# kit's own "~200 lines" budget for always-loaded files, and nothing said so.
# A small model applying the kit did not get through them, and the kit's own
# audit skill flagged them in the first repository it was run on. A budget that
# is only stated is the "rules without enforcement" anti-pattern the guide
# names (§ 5.4).
#
# The target is ~200 lines. This is the ceiling: a number with a tilde cannot
# be gated, so the gate sits above it and leaves the target to judgement.
#
# Usage: check-rule-budget.sh [ceiling]        default ceiling: 250 lines
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

CEILING="${1:-250}"
fail=0
checked=0

for f in starter-kit/rules/*.md starter-kit/constitution.md.template; do
  case "$(basename "$f")" in
    _*) continue ;;   # templates are copied, never loaded
  esac
  lines="$(wc -l < "$f" | tr -d ' ')"
  checked=$((checked + 1))
  if [ "$lines" -gt "$CEILING" ]; then
    echo "FAIL: $f:1 — $lines lines; an always-loaded file ships at $CEILING or fewer (target ~200)."
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Every line of a rule file is paid for in every session. Keep the imperative,"
  echo "the litmus tests and the tables an adopter fills in; MOVE the worked examples,"
  echo "anti-pattern galleries and gotcha write-ups to starter-kit/rules/reference/<rule>.md"
  echo "and leave a pointer. Move, never summarise: the reference file is read on demand,"
  echo "so nothing has to be lost. See AGENTIC-ENGINEERING-GUIDE.md § 3.3."
  exit 1
fi
echo "OK: $checked always-loaded file(s) the kit ships are within $CEILING lines"
