#!/usr/bin/env bash
# Enforces: ADR-0013 — a command the kit writes down for someone to type starts
# Python through scripts/python.sh, the way everything the kit runs does.
#
# Repository-only, like check-rule-budget.sh: it reads the texts this kit ships
# and this repository's own instructions, so bootstrap.sh does not install it
# and it lives in scripts/ here rather than in starter-kit/scripts/.
#
# Why it exists: the make targets, the gates and the hook went through the
# launcher while fourteen places in the installed rules, skills and READMEs
# told the reader to type `python3 scripts/…`. One sentence was meant to say
# that the launcher stands in for it; that sentence sat in the constitution
# template, which an install into a repository with a constitution of its own
# never receives. A convention that holds for what the kit runs and not for
# what it tells an agent to run is kept by whoever remembers it.
#
# What it reports: `python3`, optional flags, then a path under scripts/ — a
# concrete command. Prose about the name itself ("`python3 …`", "a Store alias
# called python3") is not a command and is left alone.
#
# What it does not read, and why:
#   docs/adr/, released changelog sections   immutable once accepted or released
#   changelog.d/<date>-…                     a fragment may quote the old form
#   starter-kit/scripts/tests/               fixtures that model an older install
#   starter-kit/skills/semver/               a bundled skill with an upstream of
#                                            its own; it keeps the names it came with
#
# Usage: check-documented-commands.sh
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

PATTERN='python3 +(-[A-Za-z]+ +)*(\./)?(starter-kit/)?scripts/[A-Za-z_]'
SELF="scripts/check-documented-commands.sh"

# Of CHANGELOG.md only the hand-written preamble is read: everything from the
# first version heading down is generated or released. (No comment inside the
# substitution: bash 3.2 reads an apostrophe there as an open quote.)
hits="$(
  git ls-files -co --exclude-standard -- . \
      ':!docs/adr/' ':!CHANGELOG.md' ':!changelog.d/[0-9]*' \
      ':!starter-kit/scripts/tests/' ':!starter-kit/skills/semver/' ":!$SELF" \
    | while IFS= read -r f; do
        [ -f "$f" ] || continue
        grep -nIE "$PATTERN" "$f" 2>/dev/null | sed "s|^|$f:|" || true
      done
  awk '/^## \[/ {exit} {print FILENAME ":" FNR ":" $0}' CHANGELOG.md | grep -E "$PATTERN" || true
)"

if [ -n "$hits" ]; then
  printf '%s\n' "$hits" | sed -E 's/^([^:]+:[0-9]+):(.*)$/FAIL: \1 — names the interpreter: \2/' | cut -c1-200
  echo ""
  echo "\`python3\` is not Python on every machine, and an agent types what the page says."
  echo "Write the command through the launcher — ./scripts/python.sh scripts/<tool> … in a"
  echo "file the installer ships, starter-kit/scripts/python.sh starter-kit/scripts/<tool> …"
  echo "in this repository's own instructions — or name the make target that runs it."
  echo "See docs/adr/ (ADR-0013)."
  exit 1
fi
echo "OK: no documented command starts Python by a fixed name"
