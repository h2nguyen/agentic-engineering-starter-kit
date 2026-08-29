# Versioning & Changelog Rules

Semantic Versioning 2.0.0 + Keep a Changelog. Project-agnostic defaults; adapt
component names and file locations to the project.

## Versioning (SemVer 2.0.0)

| Level | Triggered by | Reset |
|---|---|---|
| **MAJOR** (`X.y.z`) | backward-**incompatible** API change | `X+=1, Y:=0, Z:=0` |
| **MINOR** (`x.Y.z`) | backward-compatible **new functionality** | `Y+=1, Z:=0` |
| **PATCH** (`x.y.Z`) | backward-compatible **bug fixes only** | `Z+=1` |

- **New functionality is MINOR, never PATCH.** A new endpoint, setting, page,
  command, or optional parameter is MINOR — this is the single most common
  misclassification.
- **0.y.z carve-out:** while the major version is 0, breaking changes are
  permitted in MINOR; PATCH must still stay bug-fix-only. From 1.0.0 on,
  breaking changes require MAJOR.
- **Releases are immutable.** Never re-tag or edit a released version. A
  misversioned release is recovered by shipping the *next* version at the
  correct level and noting the misclassification in the changelog.
- **Declare intent, don't infer it.** Use Conventional Commits in commit
  subjects / PR titles (`fix:` → PATCH, `feat:` → MINOR, `feat!:` or a
  `BREAKING CHANGE:` footer → MAJOR) so tooling can verify the announced bump
  against the diff instead of guessing.

```text
// WRONG — new endpoint shipped as a patch
feat: add /api/export endpoint        → v1.4.1

// CORRECT — new functionality bumps MINOR
feat: add /api/export endpoint        → v1.5.0
```

## Changelog (Keep a Changelog)

- One `CHANGELOG.md` per released component: an `[Unreleased]` section on top,
  then one section per released version.
- **Every PR with a user-observable change adds an `[Unreleased]` bullet in the
  same PR.** The author of the change is the only one who knows what to write.
- **The bullet is a file, not a line.** Add it under `changelog.d/<category>/`
  and run `make registry-generate`; the `[Unreleased]` section is assembled
  from those files and must not be hand-edited. A conventional changelog
  re-emits all six category headings on every release, so two PRs adding an
  `### Added` bullet insert at the same line and always conflict — see the
  shared-registries rule for why this is a file-shape problem rather than a
  git-skill problem.

  ```bash
  python3 scripts/registry_tool.py new --registry changelog --category added \
    --title "Export endpoint for the account ledger (#1234)"
  ```
- Each bullet sits under exactly one of the six categories: **Added / Changed /
  Deprecated / Removed / Fixed / Security** — which is the directory it lives in.
- One bullet per logical change (not per commit), ticket linked, written for
  the operator who reads it after a deploy — never pasted commit messages.
- Releasing = `registry_tool.py release --registry changelog --version X.Y.Z`,
  which renders the current fragments as a dated section and deletes the ones
  it consumed. Released sections are immutable; errata go under a new
  `[Unreleased]` `Fixed` bullet. Consuming the *files* is what makes a release
  safe to run while other branches are open: a branch that added a bullet in
  parallel still holds its own file, so its bullet reappears under
  `[Unreleased]` instead of merging into a section that has moved.
- Internal refactors, test-only changes, and formatting sweeps need no bullet —
  when in doubt, add one anyway; an extra `Changed` line is cheaper than an
  unrecorded behaviour shift.

## Release checklist (generic shape — adapt to your pipeline)

1. Decide the bump level from the `[Unreleased]` content + declared commit intents.
2. Promote: `registry_tool.py release --registry changelog --version X.Y.Z`.
3. Bump the version literal(s) in one commit; tag on merge.
4. Build/publish from the tag.
5. Verify the deployed version reports the new number.

## Litmus tests

- *"Does this PR change what a user or operator observes?"* → it needs a
  changelog bullet.
- *"Is anything in this diff new functionality?"* → the next release is at
  least MINOR.
- *"Would `git diff` on a released changelog section ever be non-empty?"* → it
  must not; released sections are immutable.
