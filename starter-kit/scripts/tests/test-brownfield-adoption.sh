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
PY="$KIT_DIR/scripts/python.sh"   # Python under whatever name this machine gives it
WORK="$(mktemp -d)"; trap '[ "$VERBOSE" -eq 1 ] || rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()  { printf '  ok   — %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL — %s\n' "$1"; fail=$((fail + 1)); }

# `sed -i` is not portable, and the failure is silent. GNU sed takes no argument
# after -i; BSD/macOS sed REQUIRES one, so `sed -i 's/x/y/' file` there reads the
# script as the backup suffix and the file path as the script:
#     sed: 1: "/var/folders/…": invalid command code f
# Writing through a temp file avoids -i altogether, behaves identically on both,
# and — unlike `-i.bak` — leaves no backup file that a fragment directory would
# then pick up as an entry.
sed_i() { # $1 = sed script, $2… = files
  local script="$1"; shift
  local f
  for f in "$@"; do
    if sed "$script" "$f" > "$f.sedtmp"; then
      mv "$f.sedtmp" "$f"
    else
      rm -f "$f.sedtmp"
      return 1
    fi
  done
}


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
# A workspace of the project's own: the Harmonize track has been followed and
# installing beside it approved, which is what --alongside-existing says.
"$BOOTSTRAP" --tool claude --alongside-existing --target "$R" > "$WORK/bootstrap.log" 2>&1 || { bad "bootstrap exited non-zero"; cat "$WORK/bootstrap.log"; }
# This repository had a constitution and no kit. It is a first install, and
# its reader needs the first-install steps — not to be told that the kit was
# already here and that the way forward is the upgrade procedure.
! grep -q 'Upgrading an existing install' "$WORK/bootstrap.log" && grep -q "Fill in the constitution" "$WORK/bootstrap.log" \
  && ok "a first install into a repository with its own constitution gets the first-install steps" \
  || bad "a first install into a repository with its own constitution is treated as a re-run of the kit"

# The hint that matters here: these two files are hand-maintained, were kept,
# and are exactly what `adopt` is for. (A re-run on generated files must NOT
# print it — test-bootstrap-rerun.sh holds that side.)
grep -q 'adopt --registry changelog' "$WORK/bootstrap.log" && grep -q 'adopt --registry debugging-kb' "$WORK/bootstrap.log" \
  && ok "bootstrap points the hand-maintained changelog and knowledge base at adopt" \
  || bad "bootstrap kept a hand-maintained registry and did not say how to adopt it"

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
cfg="$("$PY" -c "import json;c=json.load(open('$R/registries.json'));a=[r for r in c['registries'] if r['name']=='adr'][0];k=[r for r in c['registries'] if r['name']=='debugging-kb'][0];print(a.get('filename_prefix',''),a['id_width'],a.get('id_scheme',c['id_scheme']),k.get('id_scheme',c['id_scheme']),k.get('id_width',c['id_width']))")"
[ "$cfg" = " 4 numeric numeric 3" ] \
  && ok "registries.json inferred adr-tools naming (no prefix, width 4) and a frozen numeric KB (width 3)" \
  || bad "inferred config was '$cfg' (expected ' 4 numeric numeric 3')"
( cd "$R" && ./scripts/check-registry-ids.sh >/dev/null 2>&1 ) \
  && ok "identifier gate passes on the existing 0001-/0002- records without renaming them" \
  || bad "identifier gate rejected existing adr-tools records"
[ -f "$R/docs/adr/0001-record-architecture-decisions.md" ] && ok "existing ADR filenames untouched" || bad "an ADR was renamed"

# 3. Adoption is lossless and identifier-preserving.
( cd "$R" && "$PY" scripts/registry_tool.py adopt --registry changelog --date 2026-09-03 >/dev/null 2>&1 ) || bad "adopt changelog failed"
( cd "$R" && "$PY" scripts/registry_tool.py adopt --registry debugging-kb >/dev/null 2>&1 ) || bad "adopt knowledge base failed"
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
grep -q 'ADR-0002' "$R/docs/DEBUGGING-KNOWLEDGE-BASE.md" && ok "the KB's citation of ADR-0002 survives adoption" || bad "cross-registry citation broken"
# "Survives" is a string match. Whether the citation still NAMES something is
# the link gate's question: ADR-0002 must be the adr-tools record 0002-…, and
# RULE:testing the rule file that was here before the kit arrived.
( cd "$R" && ./scripts/check-graph-links.sh >/dev/null 2>&1 ) \
  && ok "and the link gate resolves it — ADR-0002 to the adr-tools record, RULE:testing to the existing rule" \
  || { bad "the link gate rejected citations that existed before adoption:"; ( cd "$R" && ./scripts/check-graph-links.sh 2>&1 | grep -E '^FAIL' | head -5 | sed 's/^/         /' ); }
grep -q 'Search here before debugging.' "$R/docs/DEBUGGING-KNOWLEDGE-BASE.md" && ok "KB header prose preserved above the generated region" || bad "KB header lost"

# 4. A green lint that checks nothing is detected; the documented edit fixes it.
if ( cd "$R" && ./scripts/check-ci-lint-coverage.sh >/dev/null 2>&1 ); then
  bad "coverage gate passed while 'make lint' never runs the registry gates"
else
  ok "coverage gate FAILS while the registry gates are installed but unchained (green-but-empty lint is detected)"
fi
printf 'include registry.mk\n.PHONY: lint fmt test\nlint: registry-drift registry-ids kb-shape graph-links ci-lint-coverage fmt test\nfmt:\n\t@echo fmt ok\ntest:\n\t@echo tests ok\n' > "$R/Makefile"
git -C "$R" add -A >/dev/null; git -C "$R" commit -q -m "adopt the registry layer" 2>/dev/null
if ( cd "$R" && make lint >/dev/null 2>&1 ); then
  ok "after the two documented Makefile lines, 'make lint' is green"
else
  bad "'make lint' red after adoption:"; ( cd "$R" && make lint 2>&1 | grep -E '^FAIL' | head -5 | sed 's/^/         /' )
fi
# Capture before matching. `grep -q` exits at its first hit, and under
# `pipefail` the SIGPIPE that then kills `make` becomes the pipeline's status
# (141) — so a lint target that DOES reach the gates is reported as one that
# does not. The producer here is large enough for that to happen every time.
_dry="$( cd "$R" && make -n lint 2>/dev/null || true )"
case "$_dry" in
  *check-registry-drift.sh*) ok "and it really reaches the registry gates" ;;
  *) bad "lint still does not run the gates" ;;
esac

# An upgrade is a re-run into a repository whose own Makefile predates a gate.
# The installer used to look for the drift gate alone and call the lint target
# verified, so the reader of a re-run was told all was chained when one gate
# was not. It names the gates lint does not reach.
printf 'include registry.mk\n.PHONY: lint fmt test\nlint: registry-drift registry-ids kb-shape ci-lint-coverage fmt test\nfmt:\n\t@echo fmt ok\ntest:\n\t@echo tests ok\n' > "$R/Makefile"
"$BOOTSTRAP" --tool claude --target "$R" > "$WORK/rerun-unchained.log" 2>&1
grep -q "does not reach: graph-links$" "$WORK/rerun-unchained.log" \
  && ok "a re-run names the one gate the repository's own lint target does not reach" \
  || bad "a re-run does not say that lint misses graph-links"
git -C "$R" checkout -q -- Makefile
"$BOOTSTRAP" --tool claude --target "$R" > "$WORK/rerun-chained.log" 2>&1
grep -q "already reaches every gate" "$WORK/rerun-chained.log" && ! grep -q 'include registry.mk' "$WORK/rerun-chained.log" \
  && ok "and says nothing is left to chain once lint reaches them all" \
  || bad "a re-run on a fully chained Makefile still prints the lines to add"

# 5. Parallel work is clean and green on the adopted repository.
git -C "$R" checkout -q -b feat-a
( cd "$R" && "$PY" scripts/registry_tool.py new --registry changelog --title "Feature A" --date 2026-09-04 >/dev/null 2>&1
  sed_i 's/^- <what an operator.*/- Feature A shipped./' changelog.d/2026-09-04-feature-a.md
  "$PY" scripts/registry_tool.py new --registry debugging-kb --title "Feature A bug" >/dev/null 2>&1
  sed_i 's/<fill in>/Specific to feature A./g' docs/DEBUGGING-KNOWLEDGE-BASE.d/003-feature-a-bug.md
  make registry-generate >/dev/null 2>&1 ); git -C "$R" add -A; git -C "$R" commit -q -m "feat a"
git -C "$R" checkout -q main; git -C "$R" checkout -q -b feat-b
( cd "$R" && "$PY" scripts/registry_tool.py new --registry changelog --title "Feature B" --date 2026-09-04 >/dev/null 2>&1
  sed_i 's/^- <what an operator.*/- Feature B shipped./' changelog.d/2026-09-04-feature-b.md
  make registry-generate >/dev/null 2>&1 ); git -C "$R" add -A; git -C "$R" commit -q -m "feat b"
git -C "$R" checkout -q feat-a
if git -C "$R" merge --no-edit -q feat-b >/dev/null 2>&1; then
  ok "two branches adding entries on the adopted repo merge with zero conflicts"
  ( cd "$R" && make lint >/dev/null 2>&1 ) && ok "and the merge is GREEN with no regenerate commit" || bad "merge needed a regenerate commit"
else
  bad "merge conflicted on the adopted repository"
fi

# 6. Decision records named by date — the kit's own default, and a common
# convention without it. The installer read the year as a four-digit number,
# declared the directory numbered, and said the existing identifiers were
# preserved; every record of one year was then the same identifier, ADR-2026.
D="$(dirname "$R")/dated"; mkdir -p "$D/docs/adr"; git -C "$D" init -q -b main
git -C "$D" config user.email t@example.invalid; git -C "$D" config user.name t; git -C "$D" config commit.gpgsign false
for name in 2026-03-02-use-postgres 2026-03-19-retry-policy 2026-07-01-outbox; do
  printf '# %s\n\n## Status\nAccepted\n## Context\nWhy.\n## Decision\nWe will.\n## Consequences\nThen.\n' "$name" > "$D/docs/adr/$name.md"
done
"$BOOTSTRAP" --tool agents --target "$D" > "$D.install.log" 2>&1 || bad "bootstrap into a repository with date-named records failed"
cfg="$("$PY" -c "import json;c=json.load(open('$D/registries.json'));a=[r for r in c['registries'] if r['name']=='adr'][0];print(a.get('id_scheme'),repr(a.get('filename_prefix')))")"
[ "$cfg" = "slug ''" ] && ok "date-named decision records are declared date-slug, with no filename prefix" \
  || bad "date-named records were declared as '$cfg' (expected \"slug ''\")"
( cd "$D" && ./scripts/check-registry-ids.sh >/dev/null 2>&1 ) \
  && ok "the identifier gate passes on them: three records in one year are three identifiers" \
  || bad "the identifier gate rejects date-named records: $( cd "$D" && ./scripts/check-registry-ids.sh 2>&1 | head -1 )"
( cd "$D" && "$PY" scripts/registry_tool.py list 2>/dev/null ) | grep -q 'ADR-YYYY-MM-DD' \
  && ok "and are cited by date and slug, not by year" || bad "the declared identifier shape is not ADR-YYYY-MM-DD-<slug>"
new="$( cd "$D" && "$PY" scripts/registry_tool.py new --registry adr --title "Fourth decision" --date 2026-09-04 2>/dev/null | tail -1 )"
[ "$new" = "docs/adr/2026-09-04-fourth-decision.md" ] && ok "a new record follows the convention that was there" \
  || bad "a new record was created as '$new'"
# The control: the same three files in a registry that IS numbered are refused
# by name, and the allocator does not count on from the year.
"$PY" -c "import json;p='$D/registries.json';c=json.load(open(p));a=[r for r in c['registries'] if r['name']=='adr'][0];a['id_scheme']='numeric';a['id_width']=4;json.dump(c,open(p,'w'),indent=2)"
out="$( cd "$D" && ./scripts/check-registry-ids.sh 2>&1 )" && bad "a numbered registry accepted date-named records" || {
  case "$out" in *"named by date"*) ok "in a registry that numbers its records, a date-named file is refused, and the message says why" ;;
    *) bad "date-named records failed the numbered registry without saying why: $(printf '%s' "$out" | head -1)" ;; esac; }

echo ""; echo "=== $pass passed, $fail failed ==="
[ "$VERBOSE" -eq 1 ] && echo "scratch repo kept in $R"
[ "$fail" -eq 0 ] || exit 1
