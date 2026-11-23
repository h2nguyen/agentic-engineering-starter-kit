#!/usr/bin/env bash
# Agentic Engineering Starter Kit — which kit a repository records, what is
# newer in this checkout, what changed in between, and whether the record
# still describes the files.
#
# It stays in the kit, like bootstrap.sh: a repository the kit was installed
# into has no copy. From the root of that repository:
#
#   "$KIT"/starter-kit/kit-status.sh                  the report
#   "$KIT"/starter-kit/kit-status.sh --record         record this kit — the last step of an upgrade
#   "$KIT"/starter-kit/kit-status.sh --record --as v3.0.1
#                                                     record the release an install already has
#   ... [--target <repo-root>] [--tool claude|agents|cursor|copilot]
#
# The record is .starter-kit-version at the root of the repository: the kit's
# release, its commit and the agent tool. bootstrap.sh writes it on a first
# install and never again; --record writes it when no file of the kit's is
# still the older kit's. Nothing else changes it, and every report checks it
# against the files, so an upgrade left half done shows as that.
#
# No network: "available" is the checkout this script is run from. Update the
# checkout to learn of a newer release.
set -euo pipefail
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1:-}" in
  -h|--help) sed -n '2,/^set -euo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
exec "$KIT_DIR/scripts/python.sh" -B "$KIT_DIR/kit_status.py" "$@"
