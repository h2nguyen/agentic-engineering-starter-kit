# Shared append-only registry pattern

## Added

- ADR-0002 recording why the registry layer is a day-1 default rather than a grown-by-signal artifact
- `.gitattributes` template with `merge=union` on generated artifacts, both of its silent hazards documented inline, and a warning that custom merge drivers need per-clone configuration and fail silently without it
- Enforcement gates chained into a shipped `make lint` target and a CI workflow that invokes it: registry drift, identifier shape and uniqueness, and a coverage check proving every gate in the lint target actually runs in CI
- Two skills: `registry-entry` for authoring an entry, and `registry-conflict-triage` for the residue — the second prohibits renaming any identifier already on the default branch
- Test suites for the registry layer: unit tests for the generator and gates, plus a parallel-merge acceptance test that keeps control cases reproducing the defect on the shape being replaced
- `starter-kit/scripts/registry_tool.py`: creates fragments, assembles them into a marked region of the readable artifact, promotes a release, and gates identifier shape and uniqueness. Identifier schemes are configurable — `slug` (collision-free by construction) is the default, `numeric` is supported with the gate as its backstop
- Shared append-only registry pattern: fragment directories, a deterministic generator, and gates for changelogs, knowledge bases and decision records — so files many pull requests append to no longer conflict on every concurrent pair (guide § 3.11)

## Changed

- The debugging knowledge base and the changelog now ship in the fragment layout: entries and bullets are authored as files, and the readable artifact is generated. The rule files, constitution template, setup prompt and bootstrap installer were updated to match
- Decision records now use [Michael Nygard's format](https://github.com/architecture-decision-record/architecture-decision-record) — Status, Context, Decision, Consequences — replacing the previous four-section ADR-lite. Rejected options move into Context as part of the forces, where Nygard puts them. The identifier gate's `required_headings`, the documentation rule, the setup prompt and the authoring skill all follow, so the repository and the kit it ships prescribe the same format

## Fixed

- `check-kb-shape.sh` asserted identifier uniqueness against the pattern `ISSUE-[0-9]+`, which treats `ISSUE-7` and `ISSUE-007` as distinct — so a digit-width variant passed the uniqueness check. Shape is now asserted first, at an exact width, and mixing identifier schemes in one file is rejected

## Changed

- Changelog fragments are now **one file per change** rather than one per bullet, with the Keep a Changelog categories as `## ` headings inside the file. The six category directories are gone. The earlier granularity satisfied every merge guarantee but was still the wrong shape: a file held one line and no unit of meaning, a change spanning three categories became three near-empty files, and 2.5 KB of content occupied 56 KB once filesystem blocks were counted. Disjoint paths — the property that makes concurrent authorship safe — are unaffected. Knowledge-base entries stay one file per entry, since each is already a document whose identifier is cited elsewhere.

## Fixed

- Decision-record filenames now follow the MADR convention `adr-NNNN-short-title.md`, so `docs/adr/001-…` became `docs/adr/adr-0001-…`. Widening the number to four digits renumbered `ADR-001` to `ADR-0001` and `ADR-002` to `ADR-0002`; every live citation was updated in the same change. **Erratum:** the `[0.1.0]` section below refers to "ADR-001" and is immutable, so it is corrected here rather than edited — that record is now `ADR-0001`, at `docs/adr/adr-0001-repo-canonical-plugin-as-future-channel.md`.
