#!/usr/bin/env bash
# ACCEPTANCE TEST for the shared append-only registry pattern.
#
# The contract this proves:
#
#   Two branches each add a registry entry, and BOTH merge with
#   zero conflicts and zero duplicate identifiers.
#
# It runs each scenario twice — once against the CONTROL shape (one shared
# file, fixed anchors, allocated numbers) and once against the FRAGMENT shape.
# The control case must fail, because a test that cannot fail proves nothing:
# if a future refactor makes the control merge cleanly, the test itself has
# stopped measuring anything and says so.
#
# Usage: test-parallel-merge.sh          # all scenarios
#        test-parallel-merge.sh -v       # keep the scratch repos and show diffs
set -uo pipefail

VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOL="$KIT_DIR/scripts/registry_tool.py"
WORK="$(mktemp -d)"
trap '[ "$VERBOSE" -eq 1 ] || rm -rf "$WORK"' EXIT

pass=0
fail=0

ok()   { printf '  ok   — %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL — %s\n' "$1"; fail=$((fail + 1)); }

git_init() { # $1 = repo dir
  mkdir -p "$1"
  git -C "$1" init -q -b main
  git -C "$1" config user.email "test@example.invalid"
  git -C "$1" config user.name  "registry-acceptance-test"
  git -C "$1" config commit.gpgsign false
}

commit_all() { # $1 = repo, $2 = message
  git -C "$1" add -A
  git -C "$1" commit -q -m "$2"
}

# Merges branch-b into branch-a's repo and reports "clean" or "conflict".
merge_result() { # $1 = repo, $2 = branch
  if git -C "$1" merge --no-edit -q "$2" >/dev/null 2>&1; then
    echo clean
  else
    echo conflict
    git -C "$1" merge --abort >/dev/null 2>&1 || true
  fi
}

# ---------------------------------------------------------------------------
# CONTROL — the shape this pattern replaces: one shared file, fixed anchors,
# numbers allocated by hand. Both hazards are reproduced here on purpose.
# ---------------------------------------------------------------------------
control_kb() {
  local repo="$WORK/control-kb"
  git_init "$repo"
  mkdir -p "$repo/docs"
  cat > "$repo/docs/KB.md" <<'EOF'
# Debugging Knowledge Base

## ISSUE-001: First recorded entry

**Symptom:** Something observable.
EOF
  commit_all "$repo" "seed"

  git -C "$repo" checkout -q -b branch-a
  cat >> "$repo/docs/KB.md" <<'EOF'

## ISSUE-002: Entry written by the first branch

**Symptom:** Something observable.
EOF
  commit_all "$repo" "kb: entry from branch-a"

  git -C "$repo" checkout -q main
  git -C "$repo" checkout -q -b branch-b
  cat >> "$repo/docs/KB.md" <<'EOF'

## ISSUE-002: Entry written by the second branch

**Symptom:** Something observable.
EOF
  commit_all "$repo" "kb: entry from branch-b"

  git -C "$repo" checkout -q branch-a
  local result; result="$(merge_result "$repo" branch-b)"
  if [ "$result" = "conflict" ]; then
    ok "control: shared-file KB conflicts on concurrent entries (defect reproduced)"
  else
    bad "control: shared-file KB merged cleanly — the test no longer measures anything"
  fi
}

control_kb_union() {
  # The union-merge stopgap, without a uniqueness gate: the conflict is gone
  # and BOTH branches' ISSUE-002 survive, silently. This is the downgrade the
  # pattern's documentation warns about.
  local repo="$WORK/control-union"
  git_init "$repo"
  mkdir -p "$repo/docs"
  printf 'docs/KB.md merge=union\n' > "$repo/.gitattributes"
  cat > "$repo/docs/KB.md" <<'EOF'
# Debugging Knowledge Base

## ISSUE-001: First recorded entry
EOF
  commit_all "$repo" "seed"

  git -C "$repo" checkout -q -b branch-a
  printf '\n## ISSUE-002: Entry written by the first branch\n' >> "$repo/docs/KB.md"
  commit_all "$repo" "kb: entry from branch-a"

  git -C "$repo" checkout -q main
  git -C "$repo" checkout -q -b branch-b
  printf '\n## ISSUE-002: Entry written by the second branch\n' >> "$repo/docs/KB.md"
  commit_all "$repo" "kb: entry from branch-b"

  git -C "$repo" checkout -q branch-a
  local result; result="$(merge_result "$repo" branch-b)"
  local dups; dups="$(grep -c '^## ISSUE-002:' "$repo/docs/KB.md" 2>/dev/null || echo 0)"
  if [ "$result" = "clean" ] && [ "$dups" -gt 1 ]; then
    ok "control: union merge hides a duplicate ID (silent collision reproduced)"
  else
    bad "control: union merge did not produce the documented silent collision (merge=$result dups=$dups)"
  fi
}

control_changelog() {
  local repo="$WORK/control-changelog"
  git_init "$repo"
  cat > "$repo/CHANGELOG.md" <<'EOF'
# Changelog

## [Unreleased]

### Added

### Changed

### Fixed
EOF
  commit_all "$repo" "seed"

  git -C "$repo" checkout -q -b branch-a
  perl -0pi -e 's/### Added\n/### Added\n\n- First branch adds an endpoint.\n/' "$repo/CHANGELOG.md"
  commit_all "$repo" "changelog: bullet from branch-a"

  git -C "$repo" checkout -q main
  git -C "$repo" checkout -q -b branch-b
  perl -0pi -e 's/### Added\n/### Added\n\n- Second branch adds a setting.\n/' "$repo/CHANGELOG.md"
  commit_all "$repo" "changelog: bullet from branch-b"

  git -C "$repo" checkout -q branch-a
  local result; result="$(merge_result "$repo" branch-b)"
  if [ "$result" = "conflict" ]; then
    ok "control: fixed-anchor CHANGELOG conflicts on concurrent bullets (defect reproduced)"
  else
    bad "control: fixed-anchor CHANGELOG merged cleanly — the test no longer measures anything"
  fi
}

# ---------------------------------------------------------------------------
# THE CONTRACT — the same scenarios against the fragment shape.
# ---------------------------------------------------------------------------
# The scratch repository is SYNTHESIZED rather than copied from whatever
# repository this test happens to live in. That keeps it identical whether it
# runs from the kit or from a repo the kit was installed into — and it keeps the
# assertions meaningful, since counting bullets only works against a changelog
# whose starting contents the test controls.
scaffold_fragment_repo() { # $1 = repo dir, $2 = id_scheme
  local repo="$1" scheme="$2"
  git_init "$repo"
  mkdir -p "$repo/scripts" "$repo/docs/DEBUGGING-KNOWLEDGE-BASE.d" "$repo/docs/adr"
  mkdir -p "$repo/changelog.d"
  cp "$TOOL" "$repo/scripts/registry_tool.py"

  cat > "$repo/registries.json" <<EOF
{
  "id_scheme": "$scheme",
  "id_width": 3,
  "regen_command": "make registry-generate",
  "rule_pointer": "the shared-registries rule file",
  "registries": [
    {
      "name": "debugging-kb",
      "kind": "entries",
      "id_prefix": "ISSUE",
      "fragments": "docs/DEBUGGING-KNOWLEDGE-BASE.d",
      "output": "docs/DEBUGGING-KNOWLEDGE-BASE.md",
      "required_fields": ["Symptom", "Root Cause", "Fix"]
    },
    {
      "name": "changelog",
      "kind": "changelog",
      "fragments": "changelog.d",
      "output": "CHANGELOG.md",
      "categories": ["Added", "Changed", "Deprecated", "Removed", "Fixed", "Security"]
    },
    {
      "name": "adr",
      "kind": "documents",
      "id_prefix": "ADR",
      "fragments": "docs/adr"
    }
  ]
}
EOF

  # Union merge on the generated artifacts is load-bearing here: without it the
  # two branches' regenerated files conflict, which is noise rather than signal.
  # The drift check at the end of each scenario is what keeps union honest.
  cat > "$repo/.gitattributes" <<'EOF'
CHANGELOG.md                        merge=union
docs/DEBUGGING-KNOWLEDGE-BASE.md    merge=union
changelog.d/**                      -merge
docs/DEBUGGING-KNOWLEDGE-BASE.d/**  -merge
EOF

  cat > "$repo/docs/DEBUGGING-KNOWLEDGE-BASE.md" <<'EOF'
# Debugging Knowledge Base

<!-- BEGIN GENERATED: debugging-kb -->

<!-- END GENERATED: debugging-kb -->
EOF

  cat > "$repo/CHANGELOG.md" <<'EOF'
# Changelog

## [Unreleased]

<!-- BEGIN GENERATED: changelog -->

<!-- END GENERATED: changelog -->
EOF

  ( cd "$repo" && python3 scripts/registry_tool.py generate >/dev/null )
  commit_all "$repo" "seed: registry scaffolding"
}

# Adds an entry on its own branch, in a way that mimics two people working in
# parallel: each branches from the same commit and never sees the other's work.
add_on_branch() { # $1 = repo, $2 = branch, $3... = registry_tool args
  local repo="$1" branch="$2"; shift 2
  git -C "$repo" checkout -q main
  git -C "$repo" checkout -q -b "$branch"
  ( cd "$repo" && python3 scripts/registry_tool.py "$@" >/dev/null 2>&1 )
  # Fill the template placeholders so the shape gate sees real content.
  find "$repo/docs/DEBUGGING-KNOWLEDGE-BASE.d" -name '*.md' ! -name '_*' \
    -exec sed -i 's/<fill in>/Recorded by the acceptance test./g' {} + 2>/dev/null || true
  find "$repo/changelog.d" -maxdepth 1 -name '*.md' ! -name 'README*' \
    -exec sed -i 's/^- <what an operator.*/- Recorded by the acceptance test./' {} + 2>/dev/null || true
  ( cd "$repo" && python3 scripts/registry_tool.py generate >/dev/null )
  commit_all "$repo" "registry: entry from $branch"
}

contract_kb() { # $1 = id_scheme
  local scheme="$1" repo="$WORK/fragment-kb-$1"
  scaffold_fragment_repo "$repo" "$scheme"

  add_on_branch "$repo" branch-a new --registry debugging-kb \
      --title "Cache warms before the config is loaded" --date 2026-08-29
  add_on_branch "$repo" branch-b new --registry debugging-kb \
      --title "Retry loop swallows the timeout error" --date 2026-08-29

  git -C "$repo" checkout -q branch-a
  local result; result="$(merge_result "$repo" branch-b)"
  if [ "$result" = "clean" ]; then
    ok "[$scheme] two branches add KB entries and merge with zero conflicts"
  else
    bad "[$scheme] KB entries conflicted on merge"
    [ "$VERBOSE" -eq 1 ] && git -C "$repo" diff
    return
  fi

  # Regenerating after the merge must pick up both entries and stay clean.
  ( cd "$repo" && python3 scripts/registry_tool.py generate >/dev/null )
  local entries; entries="$(grep -c '^## ISSUE-' "$repo/docs/DEBUGGING-KNOWLEDGE-BASE.md" || echo 0)"
  if [ "$entries" -eq 2 ]; then
    ok "[$scheme] both entries survive the merge (no silent loss)"
  else
    bad "[$scheme] expected 2 entries after merge, found $entries"
  fi

  # The two schemes make different promises here, and the difference IS the
  # argument for the default. Slug identifiers come from the author, so the
  # merged tree is clean and the gate has nothing to say. Numeric identifiers
  # come from an allocator that saw only its own branch, so both branches were
  # handed the same number and merged cleanly with it — the conflict is gone
  # but the collision is not, and the gate is the only thing standing between
  # that duplicate and the first rule or decision record that cites it.
  local gate="pass"
  ( cd "$repo" && python3 scripts/registry_tool.py check >/dev/null 2>&1 ) || gate="fail"
  if [ "$scheme" = "slug" ]; then
    if [ "$gate" = "pass" ]; then
      ok "[slug] identifiers are unique by construction — nothing for the gate to catch"
    else
      bad "[slug] the gate rejected a merge that should have been collision-free"
      [ "$VERBOSE" -eq 1 ] && ( cd "$repo" && python3 scripts/registry_tool.py check )
    fi
  else
    if [ "$gate" = "fail" ]; then
      ok "[numeric] the collision the allocator caused is caught by the gate"
    else
      bad "[numeric] duplicate identifier reached the merged tree undetected"
    fi
  fi

  # The generated artifact must match its fragments exactly — a merge that
  # silently corrupted the generated region has to be loud, not tolerated.
  if ( cd "$repo" && python3 scripts/registry_tool.py generate --check >/dev/null 2>&1 ); then
    ok "[$scheme] generated knowledge base is drift-free after the merge"
  else
    bad "[$scheme] drift check failed after the merge"
  fi
}

contract_no_round_trip_after_merge() {
  # "Stable for parallel developers" is only true if a clean merge is also a
  # GREEN merge. Union merge keeps both branches' generated blocks but not in
  # canonical order or spacing, so a byte-equality drift check would fail on
  # every concurrent pair and demand a regenerate commit each time. The check
  # therefore compares what the artifact SAYS. Entries here have distinct
  # bodies, as real ones do; the boundary where union merge stops being safe
  # is pinned separately below.
  local repo="$WORK/no-round-trip"
  scaffold_fragment_repo "$repo" slug
  add_on_branch "$repo" branch-a new --registry debugging-kb \
      --title "Zulu entry sorts last" --date 2026-08-29
  sed -i 's/^\*\*Symptom:\*\* .*/**Symptom:** Stale config is served for thirty seconds after a deploy./; s/^\*\*Fix:\*\* .*/**Fix:** Warm the cache after the config has loaded, not before./' \
      "$repo/docs/DEBUGGING-KNOWLEDGE-BASE.d/2026-08-29-zulu-entry-sorts-last.md"
  ( cd "$repo" && python3 scripts/registry_tool.py generate >/dev/null ); commit_all "$repo" "a: real body"
  add_on_branch "$repo" branch-b new --registry debugging-kb \
      --title "Alpha entry sorts first" --date 2026-08-29
  sed -i 's/^\*\*Symptom:\*\* .*/**Symptom:** A request hangs instead of failing fast on timeout./; s/^\*\*Fix:\*\* .*/**Fix:** Propagate the timeout error out of the retry loop./' \
      "$repo/docs/DEBUGGING-KNOWLEDGE-BASE.d/2026-08-29-alpha-entry-sorts-first.md"
  ( cd "$repo" && python3 scripts/registry_tool.py generate >/dev/null ); commit_all "$repo" "b: real body"
  add_on_branch "$repo" branch-c new --registry changelog --category added \
      --title "Zulu change" --date 2026-08-29
  cat > "$repo/changelog.d/2026-08-29-zulu-change.md" <<'EOF'
# Zulu change

## Added

- The zulu endpoint.

## Fixed

- The zulu leak.
EOF
  ( cd "$repo" && python3 scripts/registry_tool.py generate >/dev/null ); commit_all "$repo" "c: two categories"
  add_on_branch "$repo" branch-d new --registry changelog --category added \
      --title "Alpha change" --date 2026-08-29
  cat > "$repo/changelog.d/2026-08-29-alpha-change.md" <<'EOF'
# Alpha change

## Added

- The alpha endpoint.

## Fixed

- The alpha leak.
EOF
  ( cd "$repo" && python3 scripts/registry_tool.py generate >/dev/null ); commit_all "$repo" "d: two categories"

  git -C "$repo" checkout -q branch-a
  for b in branch-b branch-c branch-d; do
    [ "$(merge_result "$repo" $b)" = "clean" ] || { bad "[no-round-trip] merging $b conflicted"; return; }
  done

  # Deliberately NO regenerate. This is what CI sees on the merge commit.
  if ( cd "$repo" && python3 scripts/registry_tool.py generate --check >/dev/null 2>&1 ); then
    ok "[no-round-trip] four concurrent branches (KB + two-category changelog) merge GREEN with no regenerate commit"
  else
    bad "[no-round-trip] a clean merge still needs a follow-up regenerate commit before CI passes"
    [ "$VERBOSE" -eq 1 ] && ( cd "$repo" && python3 scripts/registry_tool.py generate --check )
  fi
  local misfiled; misfiled="$(awk '/### Fixed/{f=1} f && /endpoint\./' "$repo/CHANGELOG.md" | wc -l)"
  if [ "$misfiled" -eq 0 ]; then
    ok "[no-round-trip] no changelog bullet was filed under the wrong category by the merge"
  else
    bad "[no-round-trip] $misfiled bullet(s) misfiled under ### Fixed by the union merge"
  fi

  # A real corruption must still be caught: hand-edit an entry body.
  sed -i 's/thirty seconds/thirty minutes/' "$repo/docs/DEBUGGING-KNOWLEDGE-BASE.md"
  if ( cd "$repo" && python3 scripts/registry_tool.py generate --check >/dev/null 2>&1 ); then
    bad "[no-round-trip] a hand-edited entry body passed the drift check"
  else
    ok "[no-round-trip] a hand-edited entry body is still rejected"
  fi
}

contract_union_boundary_is_loud() {
  # Where union merge stops being safe: two concurrent entries that share two
  # or more CONSECUTIVE identical lines get interleaved by git's conflict
  # refinement. That cannot be prevented by a merge attribute. What the
  # design guarantees instead is that it is never SILENT: the semantic drift
  # check rejects the interleaved artifact, and a regenerate restores it.
  # (The `check` gate also refuses unfilled template placeholders, which is
  # the common way two entries end up with identical adjacent lines.)
  local repo="$WORK/union-boundary"
  scaffold_fragment_repo "$repo" slug
  for b in a b; do
    git -C "$repo" checkout -q main; git -C "$repo" checkout -q -b "branch-$b"
    mkdir -p "$repo/docs/DEBUGGING-KNOWLEDGE-BASE.d"   # git drops the dir once it is empty on main
    cat > "$repo/docs/DEBUGGING-KNOWLEDGE-BASE.d/2026-08-29-entry-$b.md" <<EOF
# Entry $b

**Symptom:** Unique to $b.

**Root Cause:** Identical boilerplate line one.

**Fix:** Identical boilerplate line two.
EOF
    ( cd "$repo" && python3 scripts/registry_tool.py generate >/dev/null ); commit_all "$repo" "$b"
  done
  git -C "$repo" checkout -q branch-a
  [ "$(merge_result "$repo" branch-b)" = "clean" ] || { bad "[union-boundary] unexpected conflict"; return; }
  if ( cd "$repo" && python3 scripts/registry_tool.py generate --check >/dev/null 2>&1 ); then
    bad "[union-boundary] an interleaved artifact passed the drift check (SILENT corruption)"
  else
    ok "[union-boundary] entries sharing 2+ identical consecutive lines: merge clean, drift check LOUD"
  fi
  ( cd "$repo" && python3 scripts/registry_tool.py generate >/dev/null 2>&1 \
      && python3 scripts/registry_tool.py generate --check >/dev/null 2>&1 ) \
    && ok "[union-boundary] one regenerate restores a drift-free artifact with both entries" \
    || bad "[union-boundary] regenerate did not recover"
}

contract_changelog() {
  local repo="$WORK/fragment-changelog"
  scaffold_fragment_repo "$repo" slug

  # Each branch writes ONE fragment covering its whole change, and both put a
  # bullet under the same category. The paths are still disjoint, so the same
  # category is no longer a shared anchor the way a heading in one file was.
  add_on_branch "$repo" branch-a new --registry changelog --category added \
      --title "Export endpoint for the account ledger" --date 2026-08-29
  add_on_branch "$repo" branch-b new --registry changelog --category added \
      --title "Configurable retry budget per integration" --date 2026-08-29

  git -C "$repo" checkout -q branch-a
  local result; result="$(merge_result "$repo" branch-b)"
  if [ "$result" = "clean" ]; then
    ok "[changelog] two branches add bullets to the SAME category with zero conflicts"
  else
    bad "[changelog] same-category bullets conflicted on merge"
    return
  fi

  ( cd "$repo" && python3 scripts/registry_tool.py generate >/dev/null )
  local bullets; bullets="$(grep -c '^- ' "$repo/CHANGELOG.md" || echo 0)"
  if [ "$bullets" -eq 2 ]; then
    ok "[changelog] both bullets survive the merge (no silent loss)"
  else
    bad "[changelog] expected 2 bullets after merge, found $bullets"
  fi
}

contract_one_fragment_many_categories() {
  # The reason this layout replaced one-file-per-bullet: a change that touches
  # several categories is ONE unit of work, and reads as one file rather than
  # three near-empty ones.
  local repo="$WORK/fragment-multi"
  scaffold_fragment_repo "$repo" slug

  git -C "$repo" checkout -q -b branch-multi
  ( cd "$repo" && python3 scripts/registry_tool.py new --registry changelog \
      --category added --title "Ledger export" --date 2026-08-29 >/dev/null 2>&1 )
  cat > "$repo/changelog.d/2026-08-29-ledger-export.md" <<'EOF'
# Ledger export

## Added

- Export endpoint for the account ledger.

## Fixed

- Retry loop no longer swallows the timeout error.
EOF
  ( cd "$repo" && python3 scripts/registry_tool.py generate >/dev/null )
  commit_all "$repo" "changelog: one fragment, two categories"

  local added fixed files
  added="$(grep -c 'Export endpoint' "$repo/CHANGELOG.md" || true)"
  fixed="$(grep -c 'swallows the timeout' "$repo/CHANGELOG.md" || true)"
  files="$(find "$repo/changelog.d" -maxdepth 1 -name '*.md' ! -name 'README*' | wc -l)"
  if [ "$added" -eq 1 ] && [ "$fixed" -eq 1 ] && [ "$files" -eq 1 ]; then
    ok "[changelog] one fragment feeds two categories (1 file, not 2)"
  else
    bad "[changelog] multi-category fragment wrong (added=$added fixed=$fixed files=$files)"
  fi
}

contract_append_vs_release() {
  # The hazard union merge cannot handle: one branch releases (promoting the
  # whole Unreleased block into a version section) while another appends to it.
  local repo="$WORK/fragment-release"
  scaffold_fragment_repo "$repo" slug

  add_on_branch "$repo" branch-append new --registry changelog --category fixed \
      --title "Timeout is no longer swallowed by the retry loop" --date 2026-08-29

  git -C "$repo" checkout -q main
  git -C "$repo" checkout -q -b branch-release
  ( cd "$repo" && python3 scripts/registry_tool.py new --registry changelog \
      --category added --title "Initial public interface" --date 2026-08-20 >/dev/null 2>&1
    sed -i 's/^- <what an operator.*/- Initial public interface./' \
      changelog.d/2026-08-20-initial-public-interface.md
    python3 scripts/registry_tool.py release --registry changelog \
      --version 1.0.0 --date 2026-08-28 >/dev/null )
  commit_all "$repo" "release: 1.0.0"

  local result; result="$(merge_result "$repo" branch-append)"
  if [ "$result" = "clean" ]; then
    ok "[release] a release promotion and a concurrent bullet merge with zero conflicts"
  else
    bad "[release] release promotion conflicted with a concurrent bullet"
    return
  fi

  ( cd "$repo" && python3 scripts/registry_tool.py generate >/dev/null )
  # The appended bullet must land in Unreleased, and the released section must
  # keep its own bullet. Losing either is the silent-loss failure mode.
  local unreleased released
  unreleased="$(awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' "$repo/CHANGELOG.md" | grep -c '^- ' || true)"
  released="$(awk '/^## \[1\.0\.0\]/{f=1;next} /^## \[/{f=0} f' "$repo/CHANGELOG.md" | grep -c '^- ' || true)"
  if [ "$unreleased" -eq 1 ] && [ "$released" -eq 1 ]; then
    ok "[release] the concurrent bullet lands in Unreleased; the released section is intact"
  else
    bad "[release] bullet placement wrong after merge (unreleased=$unreleased released=$released)"
    [ "$VERBOSE" -eq 1 ] && cat "$repo/CHANGELOG.md"
  fi
}

contract_adr_numbers() { # $1 = id_scheme
  # Decision records are already one file per decision, so the FILE never
  # conflicts under either scheme. What differs is the identifier: the numeric
  # scheme allocates by scanning the local checkout, so two branches open at
  # once are handed the same number and merge cleanly with it. That is the
  # silent collision, and catching it is the gate's entire job. The slug scheme
  # has nothing to catch, which is why it is the default.
  local scheme="$1" repo="$WORK/fragment-adr-$1"
  scaffold_fragment_repo "$repo" "$scheme"

  add_on_branch "$repo" branch-a new --registry adr \
      --title "Adopt an outbox for integration events" --date 2026-08-29
  add_on_branch "$repo" branch-b new --registry adr \
      --title "Pin the runtime image by digest" --date 2026-08-29

  git -C "$repo" checkout -q branch-a
  local result; result="$(merge_result "$repo" branch-b)"
  if [ "$result" = "clean" ]; then
    ok "[adr/$scheme] two concurrent decision records merge with zero conflicts"
  else
    bad "[adr/$scheme] concurrent decision records conflicted on merge"
    return
  fi

  local gate="pass"
  ( cd "$repo" && python3 scripts/registry_tool.py check --registry adr >/dev/null 2>&1 ) || gate="fail"

  if [ "$scheme" = "numeric" ]; then
    if [ "$gate" = "fail" ]; then
      ok "[adr/numeric] the collision the allocator caused is caught by the gate"
    else
      bad "[adr/numeric] duplicate number reached the merged tree undetected"
    fi
  else
    if [ "$gate" = "pass" ]; then
      ok "[adr/slug] no collision to catch — identifiers are unique by construction"
    else
      bad "[adr/slug] the gate rejected a merge that should have been collision-free"
      [ "$VERBOSE" -eq 1 ] && ( cd "$repo" && python3 scripts/registry_tool.py check --registry adr )
    fi
  fi
}

contract_gate_catches_duplicates() {
  # Prove the gate is not vacuous: hand-plant a duplicate ID and require a
  # non-zero exit. A gate that never fires is worse than no gate.
  local repo="$WORK/fragment-gate"
  scaffold_fragment_repo "$repo" numeric
  local d="$repo/docs/DEBUGGING-KNOWLEDGE-BASE.d"
  printf '# One title\n\n**Symptom:** a\n' > "$d/007-one-title.md"
  printf '# Another title\n\n**Symptom:** b\n' > "$d/007-another-title.md"
  if ( cd "$repo" && python3 scripts/registry_tool.py check >/dev/null 2>&1 ); then
    bad "[gate] duplicate numeric IDs passed the uniqueness check"
  else
    ok "[gate] duplicate numeric IDs are rejected"
  fi

  # A digit-count variant must not walk past the shape assertion.
  rm -f "$d/007-another-title.md"
  printf '# Padded variant\n\n**Symptom:** c\n' > "$d/0007-padded-variant.md"
  if ( cd "$repo" && python3 scripts/registry_tool.py check >/dev/null 2>&1 ); then
    bad "[gate] a wrong-width identifier passed the shape assertion"
  else
    ok "[gate] wrong-width identifiers are rejected before uniqueness is tested"
  fi
}

echo "=== control: the shape this pattern replaces (these MUST reproduce the defect) ==="
control_kb
control_kb_union
control_changelog

echo ""
echo "=== contract: fragments + generator ==="
if [ ! -f "$TOOL" ]; then
  bad "registry_tool.py not found at $TOOL — the mechanism does not exist yet"
else
  contract_kb slug
  contract_kb numeric
  contract_no_round_trip_after_merge
  contract_union_boundary_is_loud
  contract_changelog
  contract_one_fragment_many_categories
  contract_append_vs_release
  contract_adr_numbers slug
  contract_adr_numbers numeric
  contract_gate_catches_duplicates
fi

echo ""
echo "=== $pass passed, $fail failed ==="
[ "$VERBOSE" -eq 1 ] && echo "scratch repos kept in $WORK"
[ "$fail" -eq 0 ] || exit 1
