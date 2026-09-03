# Changelog

All notable changes to this project are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) — the same
conventions this kit ships as a default rule.

The `[Unreleased]` section is generated from `changelog.d/`. Add a bullet by
creating a file there rather than editing this file:

```bash
python3 starter-kit/scripts/registry_tool.py new --registry changelog \
  --category added --title "What an operator will observe"
make registry-generate
```

Released sections are immutable — errata go under a new `[Unreleased]` bullet.

## [Unreleased]

<!-- BEGIN GENERATED: changelog — do not edit inside this region. Add a file under changelog.d/ and run `make registry-generate`. -->

<!-- category: Added -->
### Added

- ADR-0002 recording why the registry layer is a day-1 default rather than a grown-by-signal artifact
- `.gitattributes` template with `merge=union` on generated artifacts, both of its silent hazards documented inline, and a warning that custom merge drivers need per-clone configuration and fail silently without it
- Enforcement gates chained into a shipped `make lint` target and a CI workflow that invokes it: registry drift, identifier shape and uniqueness, and a coverage check proving every gate in the lint target actually runs in CI
- Two skills: `registry-entry` for authoring an entry, and `registry-conflict-triage` for the residue — the second prohibits renaming any identifier already on the default branch
- Test suites for the registry layer: unit tests for the generator and gates, plus a parallel-merge acceptance test that keeps control cases reproducing the defect on the shape being replaced
- `starter-kit/scripts/registry_tool.py`: creates fragments, assembles them into a marked region of the readable artifact, promotes a release, and gates identifier shape and uniqueness. Identifier schemes are configurable — `slug` (collision-free by construction) is the default, `numeric` is supported with the gate as its backstop
- Shared append-only registry pattern: fragment directories, a deterministic generator, and gates for changelogs, knowledge bases and decision records — so files many pull requests append to no longer conflict on every concurrent pair (guide § 3.11)

<!-- category: Changed -->
### Changed

- The debugging knowledge base and the changelog now ship in the fragment layout: entries and bullets are authored as files, and the readable artifact is generated. The rule files, constitution template, setup prompt and bootstrap installer were updated to match
- Decision records now use [Michael Nygard's format](https://github.com/architecture-decision-record/architecture-decision-record) — Status, Context, Decision, Consequences — replacing the previous four-section ADR-lite. Rejected options move into Context as part of the forces, where Nygard puts them. The identifier gate's `required_headings`, the documentation rule, the setup prompt and the authoring skill all follow, so the repository and the kit it ships prescribe the same format
- Changelog fragments are now **one file per change** rather than one per bullet, with the Keep a Changelog categories as `## ` headings inside the file. The six category directories are gone. The earlier granularity satisfied every merge guarantee but was still the wrong shape: a file held one line and no unit of meaning, a change spanning three categories became three near-empty files, and 2.5 KB of content occupied 56 KB once filesystem blocks were counted. Disjoint paths — the property that makes concurrent authorship safe — are unaffected. Knowledge-base entries stay one file per entry, since each is already a document whose identifier is cited elsewhere.

<!-- category: Deprecated -->

<!-- category: Removed -->

<!-- category: Fixed -->
### Fixed

- `check-kb-shape.sh` asserted identifier uniqueness against the pattern `ISSUE-[0-9]+`, which treats `ISSUE-7` and `ISSUE-007` as distinct — so a digit-width variant passed the uniqueness check. Shape is now asserted first, at an exact width, and mixing identifier schemes in one file is rejected
- Decision-record filenames now follow the MADR convention `adr-NNNN-short-title.md`, so `docs/adr/001-…` became `docs/adr/adr-0001-…`. Widening the number to four digits renumbered `ADR-001` to `ADR-0001` and `ADR-002` to `ADR-0002`; every live citation was updated in the same change. **Erratum:** the `[0.1.0]` section below refers to "ADR-001" and is immutable, so it is corrected here rather than edited — that record is now `ADR-0001`, at `docs/adr/adr-0001-repo-canonical-plugin-as-future-channel.md`.
- The drift check compares what a generated artifact *says* to its fragments — same entries, same content, any order — instead of comparing bytes. A union merge keeps both branches' blocks in arrival order and drops the blank line between them; byte-equality failed on every concurrent merge and demanded a regenerate commit each time, which was most of the friction the layout exists to remove. Real corruption still fails: a changed body, a missing entry, one identifier with two bodies.
- Union merge misfiled bullets when two branches each touched two changelog categories: git saw one contiguous change per branch and appended the second branch's whole block after the first's last section. Every category now carries a stable anchor line (an HTML comment, invisible when rendered), so each category is its own merge hunk and a bullet can only land under its own heading.
- Two concurrently added knowledge-base entries sharing two or more consecutive identical lines were interleaved by git's conflict refinement. Every rendered entry now ends with a line unique to it, and `check` refuses unfilled template placeholders — the usual way two entries acquire identical adjacent lines. The residual case is caught loudly by the drift check and documented as the boundary of what union merge can do.
- `.gitattributes` marked fragment directories `-merge`, which disables the text driver and forced a conflict whenever two branches edited *different* lines of the same entry. Now `merge=text`, the default, stated explicitly.
- `check-kb-shape.sh` hardcoded the identifier width while `registries.json` declared it, so a project on four-digit identifiers passed one gate and failed the other on the same file. The shell gate now reads `registries.json` when present.
- `registry_tool.py adopt --registry <name>` brings an existing hand-maintained `CHANGELOG.md` or knowledge base under the fragment layout losslessly; `bootstrap.sh` names that step instead of promising green gates on a brownfield install.

<!-- category: Security -->

<!-- END GENERATED: changelog -->

## [0.1.0] — 2026-08-02

### Added

- Initial import: the agentic engineering guide (concepts, reference anatomy,
  generic blueprint, adoption playbook, maintenance flywheel, graph-engineering
  outlook).
- Starter kit with three entry points: `SETUP-PROMPT.md` (agent-driven, incl.
  the harmonize track for repos that already have agent configuration),
  `bootstrap.sh` (tool-detecting installer, `--with-meta` for the Level-4
  loop), and manual copy.
- Day-1 rule defaults: working principles (incl. plan-first/QRSPI),
  documentation, versioning & changelog.
- Shipped skills: prompt-enhancer, semver (vendored from
  https://github.com/h2nguyen/semver-skill, with validator and test suite).
- Level-4 meta layer behind `--with-meta`: workspace-audit skill + command,
  agent-coach meta-agent, workspace-changelog skeleton.
- Graph-ready debugging knowledge base plus `check-kb-shape.sh`, a runnable
  lint check for entry shape and typed cross-links.
- Templates for constitution, rules, skills, agents, commands, enforcement
  scripts, session hook, and tool settings.
- ADR-001 recording why this repository is canonical and an agent plugin is a
  future distribution channel.
