---
name: registry-conflict-triage
description: >
  Resolve a merge conflict or a duplicate-identifier failure in a shared
  append-only registry — changelog, debugging knowledge base, decision records,
  translation bundles, message-code catalogues. Use when a merge or rebase
  conflicts in one of those files, when CI reports a duplicate identifier or a
  registry drift failure, or when asked to "fix the changelog conflict" or "sort
  out the KB merge". Escalation only: prefer registry-entry for authoring.
---

# Registry Conflict Triage

## The prohibition, first

**Never renumber or rename an identifier that is already on the default
branch.** Not to resolve a conflict, not to tidy a sequence, not when it looks
obviously wrong.

Identifiers are citation targets. Rule files, decision records, source
comments, test names and other registry entries refer to them by name, and
those citations live in places a conflict resolution does not look. Renaming one
breaks every citation pointing at it — and it breaks them *silently*, because
nothing checks that a cited identifier still resolves. That is strictly worse
than the conflict it was meant to fix.

When two entries genuinely collide and both have already landed: record the
pair in `.registry-id-duplicate-allowlist`, keyed on both filenames, and leave
both entries alone.

If resolving a conflict seems to require renumbering something already merged,
that is the signal to stop and hand it back, not to proceed carefully.

## Phase 1 — Classify before touching anything

```bash
git status --short                       # which files, and how they conflicted
python3 scripts/registry_tool.py check   # which identifiers are duplicated
python3 scripts/registry_tool.py generate --check   # what drifted, and how
```

| What you see | What it means | Where to go |
|---|---|---|
| Conflict in a **generated artifact** (`CHANGELOG.md`, the assembled KB) | noise — the artifact is derived, so no authored content is at stake | Phase 2 |
| Conflict in a **fragment file** | two branches edited the same entry | Phase 3 |
| **Duplicate identifier**, neither side merged | an allocator handed both branches the same number | Phase 3 |
| **Duplicate identifier**, both sides already on the default branch | too late to prevent; both may be cited | Phase 4 |
| Add/add conflict on the **same fragment path** | two branches wrote the same entry independently | Phase 3 |
| **Modify/delete** on a changelog fragment | one branch edited a bullet that a concurrent release already promoted and consumed | Phase 3 |

## Phase 2 — Conflicts in generated artifacts

Do not hand-resolve them. The artifact is derived from the fragments, so the
correct content is whatever the generator produces from the merged fragment
set:

```bash
git checkout --theirs CHANGELOG.md || git checkout --ours CHANGELOG.md
make registry-generate
git add CHANGELOG.md
```

Either side is a fine starting point because the region is overwritten. Then
confirm nothing was lost — the fragment count is the ground truth, and the
drift check is what proves the artifact matches it:

```bash
make lint
```

If a fragment is missing after the merge, recover it from its branch. Never
retype a lost entry from memory of the diff.

## Phase 3 — Conflicts where content is genuinely at stake

**Two branches edited the same fragment.** Both wordings are authored content.
Merge them by hand if they are compatible; if they contradict, do not pick —
say which two readings are in tension and hand it back. This is one of the few
places where an agent guessing is more expensive than an agent stopping.

**Duplicate identifier, neither side merged yet.** Rename the fragment on the
branch that has not landed, then regenerate:

```bash
git mv docs/DEBUGGING-KNOWLEDGE-BASE.d/007-mine.md \
       docs/DEBUGGING-KNOWLEDGE-BASE.d/008-mine.md
make registry-generate && make lint
```

Before renaming, confirm the identifier is not already cited:

```bash
grep -rn "ISSUE-007" --exclude-dir=.git .
```

Any hit outside the fragment itself means the identifier is in use — treat it
as landed and go to Phase 4.

**Modify/delete: an edit to a bullet the release already shipped.** The
fragment is gone because its bullet now lives in a released section, which is
immutable. Do not restore the fragment — that would ship the bullet twice.
Take the deletion, and if the edit still matters, record it as an erratum
under `[Unreleased]`, the mechanism the versioning rule prescribes:

```bash
git rm changelog.d/2026-08-20-the-feature.md
python3 scripts/registry_tool.py new --registry changelog --title "Erratum for 1.5.0"
```

**Same fragment path from both branches.** Two independent write-ups of one
event. Keep the fuller one, fold anything the other adds into it, and delete
the duplicate — content merged, not one side discarded unread.

## Phase 4 — Both already landed

Nothing can be renamed. Record the pair and move on:

```bash
echo "docs/adr/095-first-decision.md docs/adr/095-second-decision.md" \
  >> .registry-id-duplicate-allowlist
```

Both filenames, never the bare number — a number-keyed line reads as "this
number is exempt" and would let a third file join the pair unnoticed.

Then say plainly that a duplicate reached the default branch, and that the
identifier is now ambiguous in every future citation. That is a signal about the
allocation scheme, not a housekeeping detail: it is the argument for moving the
registry to the slug scheme, where the collision cannot happen.

## Phase 5 — Close the loop

After any resolution beyond Phase 2's mechanical regeneration:

1. `make lint` passes.
2. Every entry present before the merge is still present after it — count the
   fragments, do not eyeball the artifact.
3. If the conflict was caused by something the gates did not catch, that is a
   knowledge-base entry and possibly a new check. Recurrence is the signal.

## Failure modes

- **Resolving by picking one side of a generated file.** Whichever side you
  pick, the region is stale; regenerate instead.
- **Renumbering to make a sequence look tidy.** See the prohibition.
- **Retyping a lost entry from the diff.** Recover the file from its branch.
- **Treating a duplicate-identifier failure as a formatting complaint.** It is
  the one failure this whole pattern exists to prevent, and it is permanent
  once cited.
