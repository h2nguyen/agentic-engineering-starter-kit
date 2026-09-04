#!/usr/bin/env bash
# Enforces: every generated registry artifact matches its fragments —
# see the shared-registries rule file.
#
# The gate that makes `merge=union` safe. Union merge resolves a conflicting
# hunk by keeping both sides silently; if that mangles a generated file, the
# committed file stops matching what the generator produces and this check says
# so, with the regeneration command in the failure message. Remove this from
# CI and the union entries in .gitattributes become a downgrade on having no
# merge configuration at all.
#
# Usage: check-registry-drift.sh [registry-name]
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
  echo "SKIP: no registries.json — nothing to drift-check."
  exit 0
fi

ARGS=(generate --check)
[ $# -gt 0 ] && ARGS+=(--registry "$1")

if python3 "$TOOL" "${ARGS[@]}"; then
  exit 0
fi

echo ""
echo "A generated registry artifact does not match its fragments."
echo "Either the file was hand-edited, or a merge rewrote it. Both are fixed"
echo "the same way — regenerate and commit the result:"
echo ""
echo "    make registry-generate"
echo ""
exit 1
