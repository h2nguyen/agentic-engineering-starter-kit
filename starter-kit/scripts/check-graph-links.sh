#!/usr/bin/env bash
# Enforces: RULE:documentation § Typed links — every typed link resolves to an
# artifact that exists.
#
# Why this exists: a link to a rule that was renamed, a script that was deleted
# or an entry that was never written reads exactly like a link that works. The
# shape check accepts it, because the token is well-formed; nothing else in the
# lint target opens the file it points at. So the citation goes stale silently,
# and it is found by the next reader who follows it — or by nobody.
#
# The same reverse index answers the question to ask BEFORE editing: what cites
# this? `graph_tool.py impact <KIND:name>` lists it.
#
# Sanctioned dangling links live in .graph-link-allowlist, keyed on the
# (citing file, token) PAIR with a mandatory reason. The legitimate case is an
# accepted decision record citing an artifact that was later RETIRED: the
# record cannot follow something that is gone. A RENAME is not that case — the
# token is updated in the record too, because a link line is a pointer.
#
# Usage: check-graph-links.sh
set -euo pipefail

# Resolve the tool relative to THIS script first: the gates and their tools
# always ship together, so that holds whether they were installed into a repo's
# scripts/ directory or are being run from the kit itself.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if [ -f "$HERE/graph_tool.py" ]; then
  TOOL="$HERE/graph_tool.py"
elif [ -f scripts/graph_tool.py ]; then
  TOOL="scripts/graph_tool.py"
else
  echo "FAIL: graph_tool.py not found next to $(basename "$0") or in scripts/"
  exit 1
fi

if [ ! -f registries.json ]; then
  echo "SKIP: no registries.json — no declared layout to resolve links against."
  exit 0
fi

if python3 "$TOOL" check; then
  exit 0
fi
SHOWN="${TOOL#"$(pwd)"/}"

echo ""
echo "A typed link names an artifact that is not there. Fix the CITING line:"
echo "point it at the artifact's current name, or delete it if the artifact is"
echo "gone. Never rename an identifier that is already on the default branch to"
echo "make a link resolve — other files cite it too."
echo ""
echo "See what cites an artifact before renaming or deleting it:"
echo ""
echo "    python3 $SHOWN impact <KIND:name>"
echo ""
echo "RENAMED? Update the token in every citer — an accepted decision record"
echo "included: a link line is a pointer, not part of what the record decided."
echo ""
echo "RETIRED, and the citing file is an accepted decision record? It cannot"
echo "follow. Record the pair in .graph-link-allowlist, with the reason:"
echo ""
echo "    <citing file> <token>  # why it cannot be repaired"
echo ""
exit 1
