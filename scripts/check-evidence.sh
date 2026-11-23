#!/usr/bin/env bash
# Enforces: ADR-0023 — docs/EVIDENCE.md says what the repository says at the
# commit it is stamped with, and nothing typed by hand.
#
# Repository-only, like check-guide-templates.sh: it holds this repository's
# own evidence file, so bootstrap.sh does not install it.
#
# Why it exists: a page of numbers about how well a method works is the first
# thing a reader doubts and the easiest thing to embellish. Recomputing every
# number at the stamped commit, on every pull request, is what lets a reader
# take the file at its word — and reproduce it: `make evidence-check`.
#
# Usage: check-evidence.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT/starter-kit/scripts/python.sh" -B "$ROOT/scripts/evidence_tool.py" check
