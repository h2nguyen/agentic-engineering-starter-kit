# Changelog fragments

One file per bullet, filed under the Keep a Changelog category it belongs to.
`make registry-generate` assembles them into the `[Unreleased]` section of
`../CHANGELOG.md`.

```bash
python3 scripts/registry_tool.py new --registry changelog --category added \
  --title "Export endpoint for the account ledger (#1234)"
```

The file's level-1 heading is the bullet text; anything after it becomes
indented continuation lines. Write it for the operator reading it after a
deploy, not as a pasted commit message.

## Why this is not just a section in CHANGELOG.md

A conventional changelog re-emits all six category headings on every release,
so every pull request adding an `### Added` bullet inserts at the same line
number. Two such pull requests do not *sometimes* conflict — they always do.
Category directories turn that into two different file paths, which git merges
without being asked.

It also fixes the release hazard. Promoting `[Unreleased]` into a version
section moves the anchor that concurrent branches were appending to; with a
plain text merge their bullet lands in a section that has moved, silently, and
no test notices a missing line. Here a release consumes the fragment files, so
a branch that added one in parallel still holds its own file: its bullet
reappears under `[Unreleased]` on the next generation instead of being lost.

## Releasing

```bash
python3 scripts/registry_tool.py release --registry changelog --version 1.5.0
```

Renders the current fragments as a dated version section, inserts it below
`[Unreleased]`, and deletes the fragments it consumed. Released sections are
immutable afterwards: errata go under a new `[Unreleased]` bullet.
