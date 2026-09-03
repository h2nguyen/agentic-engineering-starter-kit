# Changelog fragments

**One file per change, not one per bullet.** A pull request adds a single file
here describing everything it changed, with one `## <category>` section per
Keep a Changelog category it touches. `make registry-generate` merges every
fragment into the `[Unreleased]` section of `../CHANGELOG.md`.

```bash
python3 scripts/registry_tool.py new --registry changelog \
  --title "Ledger export"
```

```markdown
# Ledger export

## Added

- `/api/export` endpoint for CSV extraction of the account ledger (#1234).

## Fixed

- Retry loop no longer swallows the timeout error (#1235).
```

The level-1 title names the change and is never rendered — it is there so the
directory is readable at a glance. Write the bullets for the operator reading
them after a deploy, not as pasted commit messages.

## Why a file per change rather than a section in CHANGELOG.md

A conventional changelog re-emits all six category headings on every release,
so every pull request adding an `### Added` bullet inserts at the same line.
Two such pull requests do not *sometimes* conflict — they always do. Separate
files are separate paths, and git merges those without being asked.

`merge=union` on `CHANGELOG.md` looks like a cheaper fix and is not: it removes
the conflict and keeps a worse failure. A bullet landing while a release is
being cut merges cleanly **into the released section** — a section that is
supposed to be immutable, now claiming a change it did not ship, with no
conflict and nothing failing.

Fragments fix that because a release consumes the *files*. A branch that added
one in parallel still holds its own file, so its bullet reappears under
`[Unreleased]` on the next generation instead of being absorbed into a section
that moved.

## Why per change rather than per bullet

An earlier version of this layout used one file per bullet, under a directory
per category. It worked, but a file held one line and no coherent unit of
meaning, and a change touching three categories became three near-empty files.
One file per change keeps every guarantee above — the paths are still
disjoint — while each file is a thing you can read: *what this change did*.

## Releasing

```bash
python3 scripts/registry_tool.py release --registry changelog --version 1.5.0
```

Renders the current fragments as a dated version section, inserts it below
`[Unreleased]`, and deletes the fragments it consumed. Released sections are
immutable afterwards: errata go under a new `[Unreleased]` bullet.
