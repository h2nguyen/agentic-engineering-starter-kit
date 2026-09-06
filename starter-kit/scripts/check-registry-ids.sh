#!/usr/bin/env bash
# Enforces: registry identifiers are well-shaped and unique —
# see the shared-registries rule file.
#
# Why this exists even where identifiers cannot collide: a repository on the
# slug scheme gets uniqueness from the filesystem, but a repository on the
# numeric scheme allocates by scanning its own checkout, so two branches open
# at the same time can both claim the same number and merge cleanly. That is
# the failure worth catching — a conflict costs thirty seconds, whereas a
# duplicate identifier is permanent the moment anything cites it.
#
# Sanctioned duplicates live in .registry-id-duplicate-allowlist, keyed on the
# FILENAME PAIR rather than the identifier. Keying on the number would read as
# "this number is exempt" and would let a *third* file join a legacy pair
# unnoticed — the exact drift this gate exists to catch.
#
# Usage: check-registry-ids.sh [registry-name]
set -euo pipefail

# Resolve the generator relative to THIS script first: the gates and the tool
# always ship together, so that holds whether they were installed into a repo's
# scripts/ directory or are being run from the kit itself.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if [ -f "$HERE/registry_tool.py" ]; then
  TOOL="$HERE/registry_tool.py"
elif [ -f scripts/registry_tool.py ]; then
  TOOL="scripts/registry_tool.py"
else
  echo "FAIL: registry_tool.py not found next to $(basename "$0") or in scripts/"
  exit 1
fi

if [ ! -f registries.json ]; then
  echo "SKIP: no registries.json — nothing to check."
  exit 0
fi

ARGS=(check)
[ $# -gt 0 ] && ARGS+=(--registry "$1")

if python3 "$TOOL" "${ARGS[@]}"; then
  exit 0
fi

echo ""
echo "Rename the fragment that has NOT been merged yet, then regenerate."
echo "Never renumber an identifier that is already on the default branch:"
echo "rules, decision records and code comments cite it by name, and renaming"
echo "it breaks every one of those citations silently."
echo ""
exit 1
