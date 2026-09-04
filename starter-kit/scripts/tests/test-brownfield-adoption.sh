#!/usr/bin/env bash
# ACCEPTANCE TEST: adopting the registry layer into a repository that ALREADY
# has an agentic workspace and populated registries, in the shapes real
# projects use.
#
# The contract:
#   1. bootstrap never modifies an existing file (append-only for .gitattributes);
#   2. registries.json is inferred to match the existing conventions, so the
#      identifier gate passes on existing records without renaming any of them;
#   3. adopt moves every existing entry/bullet into fragments with nothing lost
#      and every identifier preserved — including citations between them;
#   4. after the documented two-line Makefile edit, `make lint` is green and
#      actually runs the registry gates (a green lint that checks nothing must
#      be detected, not tolerated);
#   5. two branches can then each add entries and merge clean AND green.
#
# Usage: test-brownfield-adoption.sh [-v]
set -uo pipefail
VERBOSE=0; [ "${1:-}" = "-v" ] && VERBOSE=1
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"; trap '[ "$VERBOSE" -eq 1 ] || rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()  { printf '  ok   — %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL — %s\n' "$1"; fail=$((fail + 1)); }

# Where the kit's installable files live: the kit itself, or a repo it was
# installed into (then bootstrap.sh is not present and this test is skipped).
BOOTSTRAP="$KIT_DIR/bootstrap.sh"
if [ ! -f "$BOOTSTRAP" ]; then
  echo "SKIP: bootstrap.sh not found beside this test (only runs from the kit itself)"
  exit 0
fi

R="$WORK/brownfield"; mkdir -p "$R"
git -C "$R" init -q -b main
git -C "$R" config user.email t@example.invalid; git -C "$R" config user.name t; git -C "$R" config commit.gpgsign false
mkdir -p "$R/.claude/rules" "$R/docs/adr" "$R/.github/workflows"
printf '# Agent Constitution\n\nExisting. Do not overwrite.\n' > "$R/CLAUDE.md"
printf '# Testing Rules\n' > "$R/.claude/rules/testing.md"
cat > "$R/CHANGELOG.md" <<'EOF'
# Changelog

## Unreleased

- Ledger export endpoint (#41).
- Retry no longer swallows timeouts (#39).

## [1.2.0] - 2026-06-01

### Added

- Multi-tenant accounts.
EOF
cat > "$R/docs/DEBUGGING-KNOWLEDGE-BASE.md" <<'EOF'
# Debugging Knowledge Base

Search here before debugging.

## ISSUE-001: Cache warms before config

**Symptom:** Stale config after deploy.

**Investigation Trail:** Checked the loader order.

**Root Cause:** Warm-up ran first.

**Fix:** Reordered startup.

**Prevention:** Startup order is asserted in a test.

**Debug Shortcut:** grep for "warm" in startup logs.

**Related:** RULE:testing, ADR-0002

### ISSUE-002 - Retry swallows timeout

**Symptom:** Requests hang.

**Investigation Trail:** Traced the retry loop.

**Root Cause:** Timeout caught and retried.

**Fix:** Propagate the timeout.

**Prevention:** ADR-0002 records the retry policy.

**Debug Shortcut:** Look for repeated attempts in traces.
EOF
printf '# 1. Record architecture decisions\n\n## Status\nAccepted\n## Context\nWe need to.\n## Decision\nWe will.\n## Consequences\nSee adr-tools.\n' > "$R/docs/adr/0001-record-architecture-decisions.md"
printf '# 2. Retry policy\n\n## Status\nAccepted\n## Context\nTimeouts retried.\n## Decision\nPropagate.\n## Consequences\nFewer hangs.\n' > "$R/docs/adr/0002-retry-policy.md"
printf '.PHONY: lint fmt test\nlint: fmt test\nfmt:\n\t@echo fmt ok\ntest:\n\t@echo tests ok\n' > "$R/Makefile"
printf 'name: ci\non: [pull_request]\njobs:\n  ci:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n      - run: make lint\n' > "$R/.github/workflows/ci.yml"
printf '*.sh text eol=lf\n' > "$R/.gitattributes"
git -C "$R" add -A; git -C "$R" commit -q -m "existing brownfield repository"
before_sha="$(git -C "$R" rev-parse HEAD)"

echo "=== brownfield: existing workspace + populated registries ==="
"$BOOTSTRAP" --tool claude --target "$R" > "$WORK/bootstrap.log" 2>&1 || { bad "bootstrap exited non-zero"; cat "$WORK/bootstrap.log"; }

# 1. Nothing pre-existing was modified (only additions; .gitattributes appended).
modified="$(git -C "$R" status --short | grep -E '^ M|^M ' | grep -v '.gitattributes' || true)"
[ -z "$modified" ] && ok "bootstrap modified no existing file" || bad "bootstrap modified: $modified"
grep -q '^\*\.sh text eol=lf' "$R/.gitattributes" && grep -q 'merge=union' "$R/.gitattributes" \
  && ok "existing .gitattributes kept its own lines and gained the registry block" \
  || bad ".gitattributes was replaced or not extended"
"$BOOTSTRAP" --tool claude --target "$R" >/dev/null 2>&1
[ "$(grep -c '>>> starter-kit registries >>>' "$R/.gitattributes")" -eq 1 ] \
  && ok "re-running bootstrap does not append the block twice" || bad "gitattributes block duplicated on re-run"

# 2. The inferred config matches the conventions on disk.
cfg="$(python3 -c "import json;c=json.load(open('$R/registries.json'));a=[r for r in c['registries'] if r['name']=='adr'][0];k=[r for r in c['registries'] if r['name']=='debugging-kb'][0];print(a.get('filename_prefix',''),a['id_width'],a.get('id_scheme',c['id_scheme']),k.get('id_scheme',c['id_scheme']),k.get('id_width',c['id_width']))")"
[ "$cfg" = " 4 numeric numeric 3" ] \
  && ok "registries.json inferred adr-tools naming (no prefix, width 4) and a frozen numeric KB (width 3)" \
  || bad "inferred config was '$cfg' (expected ' 4 numeric numeric 3')"
( cd "$R" && ./scripts/check-registry-ids.sh >/dev/null 2>&1 ) \
  && ok "identifier gate passes on the existing 0001-/0002- records without renaming them" \
  || bad "identifier gate rejected existing adr-tools records"
[ -f "$R/docs/adr/0001-record-architecture-decisions.md" ] && ok "existing ADR filenames untouched" || bad "an ADR was renamed"

# 3. Adoption is lossless and identifier-preserving.
( cd "$R" && python3 scripts/registry_tool.py adopt --registry changelog --date 2026-09-03 >/dev/null 2>&1 ) || bad "adopt changelog failed"
( cd "$R" && python3 scripts/registry_tool.py adopt --registry debugging-kb >/dev/null 2>&1 ) || bad "adopt knowledge base failed"
for text in "Ledger export endpoint (#41)." "Retry no longer swallows timeouts (#39)." "Multi-tenant accounts."; do
  grep -qF "$text" "$R/CHANGELOG.md" || bad "changelog lost: $text"
done
grep -qF "Multi-tenant accounts." "$R/CHANGELOG.md" && grep -qF "(#41)" "$R/CHANGELOG.md" \
  && ok "every changelog bullet survives adoption; released section untouched"
awk '/## \[1\.2\.0\]/{f=1} f' "$R/CHANGELOG.md" | grep -q 'Multi-tenant' && ok "released [1.2.0] section still holds its own bullet" || bad "released section damaged"
ls "$R/docs/DEBUGGING-KNOWLEDGE-BASE.d/" | grep -q '^001-' && ls "$R/docs/DEBUGGING-KNOWLEDGE-BASE.d/" | grep -q '^002-' \
  && ok "both KB entries became fragments, numbered as before (### heading and ' - ' separator accepted)" \
  || bad "KB fragments missing: $(ls "$R/docs/DEBUGGING-KNOWLEDGE-BASE.d/")"
grep -q '^## ISSUE-001: Cache warms before config' "$R/docs/DEBUGGING-KNOWLEDGE-BASE.md" \
  && grep -q '^## ISSUE-002: Retry swallows timeout' "$R/docs/DEBUGGING-KNOWLEDGE-BASE.md" \
  && ok "regenerated KB carries ISSUE-001 and ISSUE-002 with their original identifiers" \
  || bad "KB identifiers changed or entries missing after adoption"
grep -q 'ADR-0002' "$R/docs/DEBUGGING-KNOWLEDGE-BASE.md" && ok "the KB's citation of ADR-0002 still resolves to the adr-tools record" || bad "cross-registry citation broken"
grep -q 'Search here before debugging.' "$R/docs/DEBUGGING-KNOWLEDGE-BASE.md" && ok "KB header prose preserved above the generated region" || bad "KB header lost"

# 4. A green lint that checks nothing is detected; the documented edit fixes it.
if ( cd "$R" && ./scripts/check-ci-lint-coverage.sh >/dev/null 2>&1 ); then
  bad "coverage gate passed while 'make lint' never runs the registry gates"
else
  ok "coverage gate FAILS while the registry gates are installed but unchained (green-but-empty lint is detected)"
fi
printf 'include registry.mk\n.PHONY: lint fmt test\nlint: registry-drift registry-ids kb-shape ci-lint-coverage fmt test\nfmt:\n\t@echo fmt ok\ntest:\n\t@echo tests ok\n' > "$R/Makefile"
git -C "$R" add -A >/dev/null; git -C "$R" commit -q -m "adopt the registry layer" 2>/dev/null
if ( cd "$R" && make lint >/dev/null 2>&1 ); then
  ok "after the two documented Makefile lines, 'make lint' is green"
else
  bad "'make lint' red after adoption:"; ( cd "$R" && make lint 2>&1 | grep -E '^FAIL' | head -5 | sed 's/^/         /' )
fi
( cd "$R" && make -n lint 2>/dev/null | grep -q check-registry-drift.sh ) && ok "and it really reaches the registry gates" || bad "lint still does not run the gates"

# 5. Parallel work is clean and green on the adopted repository.
git -C "$R" checkout -q -b feat-a
( cd "$R" && python3 scripts/registry_tool.py new --registry changelog --title "Feature A" --date 2026-09-04 >/dev/null 2>&1
  sed -i 's/^- <what an operator.*/- Feature A shipped./' changelog.d/2026-09-04-feature-a.md
  python3 scripts/registry_tool.py new --registry debugging-kb --title "Feature A bug" >/dev/null 2>&1
  sed -i 's/<fill in>/Specific to feature A./g' docs/DEBUGGING-KNOWLEDGE-BASE.d/003-feature-a-bug.md 2>/dev/null
  make registry-generate >/dev/null 2>&1 ); git -C "$R" add -A; git -C "$R" commit -q -m "feat a"
git -C "$R" checkout -q main; git -C "$R" checkout -q -b feat-b
( cd "$R" && python3 scripts/registry_tool.py new --registry changelog --title "Feature B" --date 2026-09-04 >/dev/null 2>&1
  sed -i 's/^- <what an operator.*/- Feature B shipped./' changelog.d/2026-09-04-feature-b.md
  make registry-generate >/dev/null 2>&1 ); git -C "$R" add -A; git -C "$R" commit -q -m "feat b"
git -C "$R" checkout -q feat-a
if git -C "$R" merge --no-edit -q feat-b >/dev/null 2>&1; then
  ok "two branches adding entries on the adopted repo merge with zero conflicts"
  ( cd "$R" && make lint >/dev/null 2>&1 ) && ok "and the merge is GREEN with no regenerate commit" || bad "merge needed a regenerate commit"
else
  bad "merge conflicted on the adopted repository"
fi

echo ""; echo "=== $pass passed, $fail failed ==="
[ "$VERBOSE" -eq 1 ] && echo "scratch repo kept in $R"
[ "$fail" -eq 0 ] || exit 1
