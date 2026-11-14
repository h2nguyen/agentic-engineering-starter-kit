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

- ADR-0003 records why the comments-and-annotations rule is enforced by review rather than by a check in the lint target, and what was weighed first: an annotation-density check, a marker-aware check, and deferring until the first violation. The rule already stated the conclusion inline; the record carries the rejected options and scopes the exception to judgement about annotation content, leaving marker *shape* gateable as `check-kb-shape.sh` and `check-registry-drift.sh` already gate it.
- `make lint` fails when a typed link names an artifact that does not exist. The new `scripts/check-graph-links.sh`, installed for every tool, resolves each `Related:`, `Enforces:` and `Hands off to:` line against the files on disk and reports the citing `file:line`, the names that do exist, and the fix. A code fence that is never closed is reported too, when link lines below it would otherwise be skipped as code. Until now a link to a renamed rule, a deleted script or an entry that was never written passed the drift gate, the identifier gate and the knowledge-base shape check alike.
- `scripts/graph_tool.py impact <KIND:name>` (also `make graph-impact NODE=…`) lists what cites an artifact and what it cites, each with `file:line`. Run it before renaming, deleting or rewriting a rule, skill, agent, command or script: its "Cited by" list is the change set. `impact HUMAN` lists every approval gate the workspace declares. `make graph-impact` with no `NODE` prints how to name one.
- `scripts/graph_tool.py coverage` (also `make graph-coverage`) reports which rules a script enforces and an agent reviews, and which gates no agent cites. It is a report for audits and the health checklist, never a gate.
- Two link lines and two artifact kinds join the existing `Related:` line. `Enforces:` says a script or a reviewer holds a rule; `Hands off to:` says who or what runs next, including `HUMAN` for an approval gate; `AGENT:<name>` and `COMMAND:<name>` are valid tokens. Together they describe both the knowledge graph over the workspace and its orchestration topology — guide § 3.12, and the new "Typed links" section of the documentation rule.
- The kit's own artifacts carry the links: the four shipped gates name the rule they enforce, the registry skills the rule and tool they use, the agent-coach, the audit skill and the conflict-triage skill the human gate they stop at, and the audit command the skill it delegates to. A fresh install therefore has a graph to resolve on day one.
- `workspace-graph` skill, installed by `bootstrap.sh --with-meta`: impact-before-edit and coverage as a procedure. The agent-coach and the workspace-audit skill now read coverage holes and citers from the graph where the repository ships the tool.
- `.graph-link-allowlist`, created on first need: the one sanctioned dangling link — an immutable decision record citing a rule that was later retired — as `<citing file> <token>  # reason`. The reason is mandatory, the exemption is reported on every run, and a stale entry fails the gate.
- An optional `graph.nodes` block in `registries.json` declares where a repository keeps a kind of artifact when that is not where the installer puts it — playbook docs standing in for skills on a tool without native ones, for instance.
- `scripts/tests/test-graph-links.sh`, the acceptance test, with a control case that requires the three older gates to pass on a dangling link; `scripts/tests/test_graph_tool.py`, the unit tests. Both run in `make lint`.
- ADR-0004 records why link resolution is a day-1 default while graph-driven retrieval, topology checks and a stored index stay deferred, and what was weighed first.
- `bootstrap.sh` installs the templates a workspace grows from — a new rule, check script, skill, reviewer agent and (on Claude Code) command — to `docs/agent-templates/`, for every tool. They are never loaded into a session and the link gate reads them as scaffolding. Until now they stayed in the kit, where a later session could not find them.
- The documentation rule's "what to update when" table says which template to start from and what each artifact must carry, including two links that are easy to leave out: a new rule cites the incident behind it, and the incident's entry names the rule or check that now prevents it.
- `docs/rule-reference/`, installed for every tool: the worked examples of the comments-and-annotations rule and the gotcha write-ups of the shared-registries rule. They are read when a rule points at them and are never loaded by default.
- `AGENTS.md` at the root of the kit's repository, and a `CLAUDE.md` that imports it. An agent pointed at a checkout of the kit learns from it how to install the kit into a project step by step, when to stop and ask, and what the rules are for changing the kit itself.
- `CONTRIBUTING.md` for people changing the kit: the workflow, the test suites, what each gate holds together, the checklist for adding anything the installer ships, and the release procedure.
- `starter-kit/README.md` gains Requirements, **Upgrading an existing install** and a Troubleshooting table that maps each `make lint` failure to its fix. The upgrade steps say which files the kit owns and are copied, which one rule is merged because it carries your fill-ins, and which files are yours and never replaced, with a command for each that lists what differs — so they work from whichever version a repository was installed from.
- ADR-0005 records why the templates and the rule references install on day 1 although nothing reads them that day.

<!-- category: Changed -->
### Changed

- A changelog fragment line the generator cannot render is now an error naming `file:line`: a `### Fixed` heading, an unindented second line of a bullet, a paragraph inside a section, an unclosed comment. All of these used to vanish from the changelog with every gate green. `* ` and `+ ` bullets are rendered as `- `; notes between the title and the first section stay allowed. Fragments that relied on the old silence fail `make lint` until fixed.
- `check-ci-lint-coverage.sh` counts a target only when a workflow really runs it: the `run:` of a step, read as shell, in a workflow a push, pull request, merge queue or `workflow_call` triggers, not switched off with `if: false`, in the repository root and not as `make -n`. A target named in a comment, an `echo`, a step name, `make -C other`, `cd other && make` or a `working-directory` no longer counts. Workflows without an `on:` trigger cover nothing.
- The umbrella lint target has a new prerequisite, `graph-links` (`Makefile.template`, `registry.mk`). A repository that keeps its own Makefile adds it to its `lint:` line; `check-ci-lint-coverage.sh` fails while `scripts/check-graph-links.sh` is installed and lint does not reach it.
- Upgrading a repository bootstrapped from an earlier version is manual, because `bootstrap.sh` never overwrites a file: re-running it adds `graph_tool.py`, `check-graph-links.sh` and the new tests, and leaves the existing `registry.mk` and `check-ci-lint-coverage.sh` as they were — so the gate is installed and nothing runs it. Copy those two files from the kit as well and add `graph-links` to the `lint:` line.
- A check script names its rule as a typed link: `# Enforces: RULE:<name> § <section> — <what it checks>` replaces `# Enforces: <rule> — see <rule file> § <section>` in the four shipped gates and in `check-convention.sh.template`. A script still carrying the old header fails the link gate, and the failure names the token to write.
- The knowledge-base shape check accepts `AGENT:` and `COMMAND:` tokens on a `Related:` line.
- The rule, skill, agent and command templates carry link lines to fill in; a placeholder left unfilled fails the link gate once the template is copied.
- Guide § 5.6 now lists only what graph engineering still defers, each with its signal, and says the term covers both orchestration topology and the knowledge graph; the mechanism moved to the new § 3.12. The statements in the documentation rule, the conflict-triage skill and guide § 3.11 that nothing checks whether a citation resolves now say what is checked — typed links — and what still is not: a citation inside a sentence, a source comment or a test name.
- The quick start runs the installer from a checkout of the kit with `--target`, so nothing but the installed files lands in your repository. The kit is an installer, not a dependency: a copy made inside the repository is deleted after the install, not committed.
- `init` writes `"id_scheme"` on the knowledge base and the decision records instead of leaving it inherited, and the top-level default stays `slug`.
- The knowledge-base template's `Related:` line is a placeholder to fill in or delete; an entry that copies it unfilled fails the link gate. It used to ship `RULE:working-principles`, which adopters kept as it was.
- A link line follows a rename even inside an accepted decision record — it is a pointer, not part of the decision. `.graph-link-allowlist` is for a record citing something that was retired. The documentation rule, the gate's failure message and the workspace-graph skill all say so.
- The setup prompt says who edits an existing Makefile (the adopter, not the installer), what to do with the SessionStart hook skeleton on Claude Code, and to leave the kit directory out of the commit; the README says what `<TICKET-ID>` is where there is no tracker.
- The comments-and-annotations rule is 242 lines instead of 408, and the shared-registries rule 189 instead of 260. Nothing was deleted: the illustrations moved, verbatim, to `docs/rule-reference/`, and each rule names its reference. On an upgrade, merge these two rules rather than copying them — yours carries your project's fill-ins — and resolve the same pointers in the reference file.
- The agent-coach says where its proposal log is (the workspace changelog), and defines its "Gap" verdict and what counts as a rule change worth a cycle. The workspace-audit skill says which tool loads rule files always, where a relocated reference goes, that a coherent rule stays whole above its line target, how to prove a relocation lossless, and what the verification dry run is.
- Re-running `bootstrap.sh` in a repository that already has the kit says that it only added what was missing and changed no existing file, names the upgrade steps, and no longer repeats the first-install steps. Where the repository keeps its own Makefile, it names each gate the `lint` target does not reach — after an upgrade, the gate the newer kit added — instead of checking for the first gate alone. Its next steps tell a first install to delete the constitution template's example rows, commands and links that the project has no counterpart for, name the common-skills catalog by its full path in the kit, and say that `registry-test` is the target to add when a repository with its own Makefile wants the kit's suites in its lint.
- The typed-link table in the documentation rule says what the gate checks — a hand-off to a rule, a document or a registry entry is rejected — and that what an `Enforces` line names is a convention.
- The constitution template's `make graph-impact` example names `RULE:documentation`, which every install has, instead of a testing rule that is not installed.
- The command for finding your project's comment markers runs unchanged in zsh, and the adoption notes say what to write when it finds none. The README no longer asks for a `chmod +x` the installer has already done, and says when to keep the SessionStart hook entry.
- The kit's unit tests run with `python3 -B` and unittest's `-b`.
- The two suites that test the installer itself (`test-bootstrap-rerun.sh`, `test-brownfield-adoption.sh`) are no longer installed into your repository, where they could only print `SKIP` on every lint run. A repository that already has them can delete both and drop their two lines from `registry.mk`.

<!-- category: Deprecated -->

<!-- category: Removed -->

<!-- category: Fixed -->
### Fixed

- A release merged together with a branch that added a fragment in parallel could leave a copy of that bullet, or an `END GENERATED` marker, inside the released section while the drift check stayed green. The drift check and `generate` now fail on it, naming the line to delete, and on bullets written by hand under `[Unreleased]` outside the generated region; `release` refuses to run on such a changelog.
- `check-ci-lint-coverage.sh` no longer reports a covered target, or a reached registry gate, as missing when the workflow or the `make -n` output is large (SIGPIPE under `pipefail`).
- Slugs keep letters that have no Unicode decomposition: `Straße` → `strasse`, `Łódź` → `lodz` (they were dropped: `strae`).
- The `SessionStart` hook from `settings.json.template` runs from a project path with a space (it exited 127, silently), and `session-start.sh.template` appends its environment once instead of on every start.
- `bootstrap.sh` printed `SKIPPED[@]: unbound variable` twice on every fresh install under bash 3.2 (macOS), and still exited 0.
- `registry_tool.py init` told a brand-new repository to run `adopt` on the changelog template it had just been given.
- `init` announced "MADR naming adr-NNNN" for decision records while the config it wrote produces `ADR-<date>-<slug>`.
- `init` gave a repository with numbered decision records and no knowledge base yet a numeric knowledge base, by deriving the top-level scheme from the registries.
- `init` wrote `rule_pointer` as `.claude/rules/shared-registries.md` for every tool, so on the layouts that keep rules in `docs/agent-rules/` every gate failure pointed at a file that was not there.
- The kit's tools left `scripts/__pycache__/` and `scripts/tests/__pycache__/` in the adopting repository, which gets no `.gitignore` from the kit.
- A passing `make lint` printed the unit tests' expected `FAIL` lines, and a stray `find` error from the parallel-merge test.
- Re-running `bootstrap.sh` — as `--with-meta` does — told a repository already in the fragment layout to run `adopt`.
- `registry_tool.py list` printed an identifier shape for the changelog, which has none.
- On a fresh install, `init` described the changelog and the knowledge base the installer had just created as files the repository "already" had.
- The first `make lint` of a brand-new repository reported its changelog as "non-canonical after a merge". The installed `CHANGELOG.md` now carries the region the generator writes for an empty changelog. A repository installed earlier can run `make registry-generate` once.
- Run from the root of the kit's own repository with no `--target`, `bootstrap.sh` would install the kit into itself. It now refuses and says to name the repository to install into. A project that holds a copy of `starter-kit/` still installs with no argument.

<!-- category: Security -->

<!-- END GENERATED: changelog -->

## [1.1.0] — 2026-09-07

<!-- category: Added -->
### Added

- `rules/comments-and-annotations.md`: a domain-agnostic rule for self-explaining work products — structure before annotation (rename, extract, restructure), a one-line brevity standard for what survives, protected marker shapes that are never stripped, an audience litmus for where rationale lives, and an explicit no-sweeps scope. `bootstrap.sh` installs it for every tool, the constitution template indexes it, and the setup prompt's fallback specs carry it for kit-less installs. Its protected-shapes table arrives pre-filled with the markers the kit's own tooling parses (generated-region and category anchors, knowledge-base field labels, the `.gitattributes` block markers, enforcement-script headers and escape markers, decision-record headings) and leaves four `<placeholders>` for the adopting project; `starter-kit/README.md` documents how to fill them.
- The rule's reviewer bullets as cross-cutting checks in the agent template, and one pointer in the working-principles pre-PR litmus, so specialist reviewers and the pre-PR self-check inherit them.
- `test-bootstrap-rerun.sh`: a second bootstrap run on a fresh repository changes nothing, and every tool layout receives the constitution and every shipped rule at its own rule location. Chained into the kit's `registry-test` target beside the brownfield-adoption test.
- `check-guide-templates.sh` (this repository only, not part of the kit): `make lint` now fails when a template the guide embeds drifts from the kit file it names; a block whose lead-in does not say "template" is listed as an illustration and never compared.

<!-- category: Changed -->
### Changed

- The documentation rule's "decision rationale lives in ADRs, not in code comments" section now routes to the comments-and-annotations rule instead of carrying its own copy of the comment doctrine, so the doctrine has one home; its WRONG/CORRECT pair and audience litmus moved there.
- `bootstrap.sh` decides the constitution path and the rules directory once per tool and installs the default rules from one list, so a new default rule is one edit rather than one per tool layout. Installed files, locations and order are unchanged.
- The constitution template's index line for the documentation rule says "ADR format (Michael Nygard)" instead of the retired "ADR-lite"; the kit README's row for that rule follows.

<!-- category: Deprecated -->

<!-- category: Removed -->

<!-- category: Fixed -->
### Fixed

- The two acceptance tests now pass on BSD/macOS sed. They used GNU's
  `sed -i 's/…/'`, which BSD sed reads as "backup suffix = the script", and both
  call sites in `test-parallel-merge.sh` sent stderr to `/dev/null` with
  `|| true`. The template placeholders were therefore never filled, the
  identifier gate rejected them exactly as designed, and the resulting failures
  read as defects in the mechanism under test rather than in the test's own
  setup: `test-parallel-merge.sh` reported 25 passed / 2 failed and
  `test-brownfield-adoption.sh` 15 passed / 2 failed. Both are now 27/0 and
  17/0. The replacement writes through a temp file rather than using `-i.bak`,
  so no backup file is left inside a fragment directory to be picked up as an
  entry.
- `bootstrap.sh` no longer tells a user with a correctly chained `lint` target
  that it "checks nothing of the registry layer". `make -n … | grep -q` exits at
  its first match, and under `set -o pipefail` the SIGPIPE that then kills `make`
  becomes the pipeline's status (141), so the check reported the opposite of
  what it had found. The same shape produced `test-brownfield-adoption.sh`'s
  "lint still does not run the gates" failure. Both now capture the output
  before matching it.
- `bootstrap.sh` no longer appends a second registry block to `.gitattributes` when re-run on a repository it bootstrapped from scratch: the template now carries the same marker lines the installer writes when it appends to an existing file, so both paths leave a file a re-run recognises. The fix travels with the template, so it covers installs made from this release onwards; a repository bootstrapped earlier has an unmarked `.gitattributes` and still gains a duplicate block on each re-run — delete the older copy by hand once, or add the two marker lines around it.
- The guide's embedded copies of the constitution, rule, agent, command, check-script and knowledge-base templates match the kit files again; the constitution copy had been missing the registry layer (the `make registry-generate` command, the Registries row and the shared-registries index line).

<!-- category: Security -->

## [1.0.0] — 2026-09-06

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
- **First stable release.** The surface this kit ships — the fragment layouts, the `registries.json` schema, the `registry_tool.py` subcommands, and the generated-region markers — is now covered by Semantic Versioning: breaking changes to it require a major version, not a minor one. Repositories bootstrapped from 0.1.0 migrate with `registry_tool.py init` followed by `adopt` per registry, which infers the conventions already on disk rather than renaming anything already cited.

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
- Bootstrapping into a repository that already has an agentic workspace and populated registries now adopts rather than imposes. `registry_tool.py init` writes `registries.json` from the conventions on disk — an `adr-tools` directory of `0001-title.md` files, a knowledge base of `ISSUE-042` entries — so the identifier gate passes on existing records without renaming any. `adopt` accepts `## Unreleased` without brackets, files uncategorised bullets under Changed, and reads `###` entry headings with `-`/`—` separators. An existing `.gitattributes` gets the registry block appended under an idempotent marker; an existing `Makefile` is never edited, but the registry targets ship in `registry.mk` for a one-line include and bootstrap verifies the gates are reached. `check-ci-lint-coverage.sh` now fails when the registry gates are installed but the lint target never runs them — the previous behaviour was a green lint that checked nothing — and no longer rejects the commit that introduces the allowlist file. A brownfield acceptance test covers the whole sequence.

<!-- category: Security -->

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
