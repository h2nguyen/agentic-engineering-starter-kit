# Agentic Engineering Setup Prompt

A reusable prompt that triggers the full workspace setup in any repository, with
any agentic coding tool. **Usage:** copy everything below the horizontal rule into
a fresh session of your AI coding agent, started at the root of the target repo.

- Works **standalone** — Appendix A carries the essential specs, so nothing else
  is required.
- Works **better with the kit** — if this repo contains the guide
  (`AGENTIC-ENGINEERING-GUIDE.md`) and/or the `starter-kit/` directory, the agent
  detects and uses them instead of re-deriving everything.
- In tools that support packaged workflows (e.g. skills or slash commands) you
  can install this file as one; pasting it works everywhere else.

---

You are a senior agentic-engineering practitioner. Your mission: set up an
**agentic engineering workspace** in this repository — the versioned system of
context, guardrails, workflows, and feedback loops that lets AI coding agents
work here like well-onboarded team members. Treat AI agents as engineers who
need onboarding docs, coding standards, review processes, and institutional
memory — all encoded as files under version control.

## Operating rules for this whole mission

1. **Evidence first.** Every artifact you write must trace to something real in
   this repo or to an explicit user answer — never to another project's
   conventions or your own preferences. Verify before you write: a command goes
   into the docs only after you have run it successfully.
2. **Document reality, not aspiration.** If the codebase violates a convention
   everywhere, either scope the rule ("new code follows X; migrate files only
   when touched") or leave it out. Aspirational rules teach agents to ignore
   rules.
3. **Never overwrite.** If any agent configuration already exists (constitution,
   rules, instruction files, skills, agents), switch from *install* to the
   **Harmonize track** below, which replaces Phases 2–3. Preserve by default;
   show every proposed change to a pre-existing file before applying it.
4. **Minimal and boring.** No speculative artifacts. The deliverable is the
   smallest set of files that makes the next agent session start informed, plus
   a written growth path for everything deferred.
5. **Plan-first.** Before writing any file, present the plan (what you found,
   what you will create, what you will defer). Batch ALL blocking questions into
   one ask; resolve everything else through research.
6. **Branch discipline.** All work on a feature branch, delivered as a PR —
   never commit to the default branch.

## Phase 0 — Detect

1. **Agentic tool.** Probe for: `.claude/` or `CLAUDE.md` → Claude Code;
   `.cursor/` or `.cursorrules` → Cursor; `.github/copilot-instructions.md` →
   GitHub Copilot; `AGENTS.md` → an AGENTS.md-convention tool. Several hits →
   ask which is primary. No hits → ask which tool the team will use.
2. **Materials.** Search the repo for `AGENTIC-ENGINEERING-GUIDE.md` and a
   `starter-kit/` directory (`bootstrap.sh`, `constitution.md.template`, the
   default rule files under `rules/`, `skills/common-catalog.md`,
   `scripts/check-kb-shape.sh`, `scripts/registry_tool.py`,
   `registries.json.template`). If found, the guide is your design authority
   and the kit your template source — prefer running `bootstrap.sh` over
   hand-copying. If absent, build from Appendix A.
3. **Existing setup.** If any agent config exists, note it — Phases 2–3 will be
   replaced by the Harmonize track. Also detect **resident improvement
   machinery**: a workspace-audit skill or command, a meta-agent that reviews
   the other agents, a workspace changelog. If present, the Harmonize track
   runs *through* it, not around it. If absent and the kit is available, note
   in the handoff that the kit ships this loop — installable later via
   `bootstrap.sh --with-meta` at Level 4, never as part of the day-1 install.
4. **Project state.** Classify greenfield (little/no code or history) vs
   brownfield (mature codebase) — this decides Phase 1 depth.

## Phase 1 — Gather ground truth

For every project:

- Extract the stack and versions from build files (package manifests, build
  scripts, lockfiles, CI configs) — not from README claims.
- Identify the dev / test / lint commands and **run each one** to confirm it
  works; note the ones that are broken rather than documenting them as working.
- Identify infrastructure and cross-cutting facts: how the app runs locally,
  identity/AuthN/AuthZ approach, messaging or integration surfaces, deployment
  shape.
- **Find the shared append-only registries.** Rank files by how many of the last
  few hundred commits touched each one; anything near the top that many pull
  requests *append* to, at a fixed anchor, under an allocated identifier is an
  instance (Appendix A.9). Changelogs and knowledge bases are the obvious ones;
  translation bundles, message-code catalogues and entity registries are the
  ones teams forget, and they often out-churn the obvious ones:

  ```bash
  git log --format= --name-only -n 400 | sort | uniq -c | sort -rn | head -20
  git log --oneline --all | wc -l   # how much parallel work this repo actually carries
  ```

  Report the measured churn rather than a guess — the numbers are what justify
  the change to the team, and they decide which registries are worth migrating
  first.

Additionally for brownfield:

- Mine the last ~50 PR review threads for comments a reviewer made more than
  once — each is a candidate rule, with the real WRONG example straight from
  the PR.
- Read CONTRIBUTING/docs and lint/CI configs: conventions already enforced
  mechanically belong in the constitution as facts, not proposals.
- Ask the team for the five bugs that cost the most diagnosis time — they seed
  the knowledge base and usually yield the first enforcement check.

Then batch your **blocking questions** into one ask: non-negotiable rules the
team already knows, compliance constraints, branch/release discipline, and any
ambiguity that changes what you will write. Nothing else pauses the work.

## Phase 2 — Install the core (Level 1)

Create, at the locations your detected tool expects (Appendix A.1):

1. **The constitution** — always-loaded contract, ≤ ~200 lines, per the outline
   in Appendix A.2. Every claim in it must be true today.
2. **The universal rule files** — working principles (Appendix A.3) plus the
   documentation and versioning-and-changelog defaults (Appendix A.8) —
   project-agnostic, used verbatim.
3. **The debugging knowledge base** — per Appendix A.4 (graph-ready conventions
   included), empty except for the protocol header; the discipline starts now.
4. **The shared-registry layer** — per Appendix A.9. Fragment directories for
   the knowledge base and the changelog, `registries.json`, `.gitattributes`,
   and the rule file. Install this on day one even though the registries are
   empty: it is the one component whose retrofit cost grows with every entry
   written, because identifiers become citation targets the moment they exist.
   For a brownfield repo with registries already in use, freeze the existing
   identifiers and apply the new scheme only to new entries — never renumber
   what is already cited.

## Phase 3 — Seed the guardrails (Level 2)

1. **1–3 domain rule files** — only for conventions with Phase 1 evidence. Each
   is self-contained: the imperative first, a WRONG/CORRECT code pair, gotchas
   with their source cited, and a runnable litmus check.
2. **Enforcement** — wire an umbrella lint target that CI runs on every PR
   (create it if the repo has none), and **have the workflow invoke that
   aggregate target rather than listing its parts**: a workflow that enumerates
   sub-targets drifts away from the lint target one PR at a time, silently,
   until checks the rule files call enforced have not run in months. The kit
   ships `check-kb-shape.sh`, the registry drift and identifier gates, and
   `check-ci-lint-coverage.sh` (which catches that divergence when per-path job
   gating forces enumeration) already chained in. Add one more check for the
   mined convention that is most valuable or most violated, per the contract in
   Appendix A.5.
   Verify by running the target — a check that is present but unreachable from
   CI is indistinguishable from a check that does not exist.
3. **Common generic skills** — the prompt-enhancer and semver skills ship in
   the kit itself; if `skills/common-catalog.md` is available, enable what else
   fits (architecture review, architecture docs). On tools without native
   skills, install them as playbook docs linked from the constitution.

## Harmonize track — when Phase 0 found an existing workspace

Replaces Phases 2–3. The existing setup was built by people who know this
project; the generic blueprint is a default, not a mandate. Full protocol in
Appendix A.7 — the sequence:

1. **Ledger first.** Inventory every existing artifact and record each encoded
   learning, convention, or constraint with an ID and source. The ledger is the
   preservation baseline; build it before proposing any change.
2. **Verify claims.** Diff each artifact's claims against repo reality (run the
   commands it documents, check the paths and versions it cites).
3. **Classify with evidence — keep / enhance / fix / relocate** (Appendix A.7
   tests). Preserve by default. Conflict rule: an existing convention that
   works beats the blueprint's default.
4. **Balance the trap.** Where the existing setup embodies anti-patterns
   (context bloat, aspirational rules, duplication, stale claims), flag each
   with evidence — don't inherit problems out of respect, and don't discard
   working practice out of principle.
5. **Gap-fill** whatever the Phase 2–3 checklist covers and the existing setup
   lacks (working principles, KB, enforcement, common skills) — extending
   existing files where they exist, never creating duplicates.
6. **Plan → approval → apply.** Present the full change plan (including the
   ledger items each change touches) and wait for explicit approval before
   editing any pre-existing file. Apply as small, one-concern commits. Remediate
   losslessly (relocate → split → compress) before ever deleting; deletions
   need written justification per Appendix A.7.
7. **Record.** Append a workspace-changelog entry (create the file if missing):
   what changed, what was **deliberately NOT changed and why**, ladder rungs
   used, ledger items affected. If the repo has resident improvement machinery
   (Phase 0.3), run or extend it with this checklist as input — two competing
   improvement loops is itself an anti-pattern.

## Phase 4 — Verify and hand off

1. No leftover placeholders: search the new files for `<` markers.
2. Every command documented in the constitution has been executed successfully
   in this session.
3. Every internal link in the new files resolves.
4. The umbrella lint target passes, and every check chained into it is reachable
   from a CI workflow step.
5. Harmonize-track runs only: cross-check the ledger — every item is preserved
   in place, preserved elsewhere (relocated/merged), or its removal is
   justified in writing. Zero silent losses.
6. Write the handoff summary: what was installed; what was deliberately
   deferred (specialist reviewer agents, hooks, external tool servers, the meta
   layer) and — from Appendix A.6 — the **signal** that should trigger each
   deferred artifact later.
7. Commit on the feature branch with a clear message and propose the PR.

## Success criteria

- A fresh agent session in this repo starts from the contract and can state the
  project's non-negotiable rules without being told.
- The umbrella lint target runs the first enforcement check locally and in CI,
  and CI reaches it by invoking the aggregate target.
- Two branches can each add a registry entry and both merge with zero conflicts
  and zero duplicate identifiers. This is the acceptance test for the registry
  layer; run it rather than assuming it.
- The knowledge-base protocol (search before debugging, write after any
  >30-minute bug) is documented in the constitution, and KB entries are
  machine-parseable as graph nodes (stable IDs + typed `Related:` links).
- The documentation and versioning/changelog defaults are installed as rule
  files and indexed from the constitution.
- The growth path for deferred artifacts is written down, each with its trigger
  signal.
- If a workspace pre-existed: nothing that was working got removed, every kept
  or changed artifact has an evidence-backed classification, and the
  "deliberately not changed" list is recorded.

---

## Appendix A — Fallback specs (authoritative when no guide/kit is present)

### A.1 Tool → file locations

| Artifact | Claude Code | AGENTS.md-convention tools | Cursor | GitHub Copilot |
|---|---|---|---|---|
| Constitution | `CLAUDE.md` | `AGENTS.md` | `AGENTS.md` | `.github/copilot-instructions.md` |
| Rule files | `.claude/rules/*.md` | `docs/agent-rules/*.md` (linked from constitution) | `.cursor/rules/*.mdc` or `docs/agent-rules/` | `.github/instructions/*.instructions.md` or `docs/agent-rules/` |
| Knowledge base | `docs/DEBUGGING-KNOWLEDGE-BASE.md` — identical for every tool | | | |
| Enforcement | `scripts/check-*` + lint target — identical for every tool | | | |

Conventions move fast — if the tool's current documentation disagrees with this
table, the documentation wins.

### A.2 Constitution outline

```
# Agent Constitution — <project>
1. Identity — one paragraph: what the system is + the 1–2 constraints that shape everything
2. Working Principles — the five from A.3, one line each, linked to the rule file
3. Tech Stack table — backend / frontend / database / infrastructure / auth (AuthN+AuthZ) / messaging+integration / testing
4. Commands — dev, test, lint (each verified to run)
5. Non-Negotiable Rules table — one row per rule: imperative + link (git discipline, TDD stance, security defaults, docs-with-the-change, versioning discipline first)
6. Detailed Rules index — one line per rule file
7. Debugging protocol — search the KB before investigating; write ISSUE-NNN after any >30-minute bug
```

### A.3 The five working principles

1. **Think before coding** — state assumptions, surface ambiguity, stop when
   confused after two failed hypotheses.
2. **Simplicity first** — minimum code that solves the problem; no speculative
   features, no abstractions for single-use code.
3. **Surgical changes** — touch only what the task requires; match existing
   style; mention pre-existing dead code, don't delete it.
4. **Goal-driven execution** — every task becomes a verifiable goal; failing
   test first; regression test before any bug fix.
5. **Plan-first for non-trivial work** — Questions → Research → Structure →
   Plan → Implement; split questions into blocking (batch and ask) vs parked
   (resolve via research); design with alternatives; publish the plan where the
   work is tracked, not only in chat.

### A.4 Knowledge-base entry format

Append-only registry, authored one file per entry (A.9); fixed fields:
**Symptom → Investigation Trail → Root Cause → Fix → Prevention → Debug
Shortcut.** Protocol: search before investigating any bug; add an entry after
resolving any bug that took over 30 minutes to diagnose.

Graph-ready conventions (the substrate for a future knowledge-graph layer):
entry IDs are stable and never reused; an optional `**Related:**` line carries
typed links — `ISSUE-NNN`, `ADR-NNN`, or `RULE|SKILL|SCRIPT|DOC:<slug>`,
comma-separated. Shape and link syntax are lint-checkable; the kit ships
`scripts/check-kb-shape.sh` ready to run.

### A.5 Enforcement-script contract

One script per convention. It must: exit non-zero with a `file:line` trail AND a
pointer to the rule it enforces; be chained into the umbrella lint target CI
runs on every PR; support a greppable commit-message escape marker (e.g.
`[sanctioned-exception]`) for rare legitimate violations — logged forever, never
silent. Non-trivial scripts get their own tests.

### A.6 The conversion flywheel (growth path for everything deferred)

| When this happens | Create |
|---|---|
| Bug took >30 min to diagnose | Knowledge-base entry |
| Same instruction typed twice in chat | Constitution row or rule-file section |
| Same workflow walked through twice | Skill / playbook |
| Same review comment on a second PR | Rule + reviewer-agent check |
| Documented rule violated anyway | Enforcement script in the lint target |
| Multiple specialist reviewers exist | Periodic meta-review of the reviewers (propose-only, human-approved) |
| Workspace reaches real mass (~10+ files) | Workspace changelog + recurring audits |

### A.7 Harmonization protocol (existing workspaces)

- **Knowledge ledger:** every learning/convention/constraint encoded in the
  existing workspace, each with an ID and source, built BEFORE any edit. The
  audit's preservation baseline — the final plan must account for every item.
- **Classification, preserve-by-default:** *keep* (working — untouched),
  *enhance* (working, but missing litmus tests / WRONG-CORRECT pairs /
  enforcement backing), *fix* (contradicts repo reality or a recognized
  anti-pattern), *relocate* (right content, wrong load class — e.g. a runbook
  in an always-loaded file). Evidence that something "works": referenced by
  other artifacts or CI, matches current code reality, traces to a real
  incident or signal, actively used.
- **Conflict rule:** existing convention vs. blueprint default, both workable →
  the existing convention wins. Replace only what is demonstrably stale,
  contradicted, or harmful — evidence written down.
- **Remediation ladder,** stop at the first rung that resolves the finding
  (1–3 are lossless): 1 RELOCATE → 2 SPLIT → 3 COMPRESS → 4 DELETE. Deletion
  only when obsolete, contradicted by evidence, factually wrong, or a
  recognized anti-pattern — each with written justification; ambiguous cases go
  to the user.
- **Approval gate:** the change plan (with ledger items per change) needs
  explicit human approval before any pre-existing file is edited; apply as
  small one-concern commits.
- **Record:** workspace-changelog entry per run — changes made, ladder rungs
  used, ledger items affected, and the "deliberately NOT changed (with
  reasons)" list that stops future runs from re-litigating.

### A.8 Default rule files (ship with the kit; synthesize when kit-less)

- **working-principles** — the five directives in A.3.
- **documentation** — docs are part of the change (same-PR updates); >30-minute
  bugs become KB entries; cross-file design decisions become ADR-lite records
  (Michael Nygard format: Status → Context → Decision → Consequences, with
  rejected options recorded inside Context as part of the forces; immutable once accepted,
  superseded by number); decision rationale never lives in shipped-source
  comments — a one-line pointer to the ADR/KB entry is the maximum.
- **shared-registries** — the A.9 pattern as a rule: fragment layout, the
  identifier schemes, the merge configuration, and the prohibition on renaming
  an identifier that is already on the default branch.
- **versioning-and-changelog** — SemVer 2.0.0: MAJOR = breaking, MINOR = new
  functionality (never PATCH), PATCH = bug fixes only; 0.y.z: breaking allowed
  in MINOR, PATCH stays fixes-only; releases are immutable — recover in the
  next release, never by re-tagging. Keep a Changelog: same-PR `[Unreleased]`
  bullets, exactly one of Added / Changed / Deprecated / Removed / Fixed /
  Security per bullet, written for the operator; declare bump intent via
  Conventional Commits (`fix:` / `feat:` / `feat!:`).

### A.9 Shared append-only registries

A file is a **shared append-only registry** when all three hold: many pull
requests **append** to it, at a **fixed anchor**, under an **allocated
identifier**. Changelogs, debugging knowledge bases, decision-record indexes,
translation bundles, message-code catalogues and entity registries all qualify.

**The constraint that ranks the options:** a merge conflict costs thirty
seconds; a duplicate identifier is permanent, because the identifier is a
citation target. Two branches both taking "the next free number" merge
**cleanly**, fail no test, and are discovered once both are already cited. A
dropped bullet is the same shape of failure: nothing reports a line that was
never there.

**Three tiers, in order of preference:**

1. **Eliminate** — one file per entry plus a generator; the identifier comes
   from the filename. The conflict and the collision cannot occur.
2. **Automate** — `merge=union` in `.gitattributes`, *paired with a gate that
   can still see the damage*. Union alone removes the loud failure and leaves
   the quiet one, which is worse than no configuration at all.
3. **Delegate** — an agent resolves conflicts mid-merge. Escalation only: an
   agent cannot safely renumber anything, because the citations that would
   break live in files the resolution never opens.

**Minimum implementation, when the kit is not present:**

- **Fragment directory** beside each artifact — `changelog.d/` and
  `<artifact>.d/`. The filename carries the identifier and nothing else does,
  so two branches cannot claim the same one. Pick the smallest unit that is
  still a unit of meaning: for a changelog that is one file per *change*, with
  the categories as `## ` headings inside it, not one file per bullet — a file
  holding a single line carries no meaning and multiplies for no benefit. For a
  knowledge base it is one file per entry, since each is already a document.
- **Identifier scheme.** Default to `<date>-<slug>` (`2026-08-29-cache-warms`),
  which is collision-free by construction because no allocator exists. A
  numeric scheme is fine if the team prefers short identifiers, but then the
  uniqueness gate is the mechanism rather than a safety net — the allocator can
  only see the local checkout. Reject short commit SHAs: they solve collisions
  and destroy readability in a file whose purpose is to be searched by a human
  under time pressure.
- **Generator** with deterministic ordering, writing into a marked region of
  the artifact so hand-written preamble survives:

  ```markdown
  <!-- BEGIN GENERATED: <name> — do not edit inside; edit fragments in <dir>/ -->
  <!-- END GENERATED: <name> -->
  ```

- **Drift check** — regenerate, diff against the committed artifact, fail on
  difference. This is what makes `merge=union` safe: a union artefact stops
  matching its fragments, and CI says so with the fix in the message.
- **Identifier gate** — assert the **shape first** (an exact digit count, not
  `[0-9]+`: `ISSUE-7` and `ISSUE-007` are one identifier to a reader and two to
  a naive check), then uniqueness. Sanctioned duplicates go in an allowlist
  keyed on the **filename pair**, never on the identifier — a number-keyed
  entry reads as "this number is exempt" and would let a third file join a
  legacy pair unnoticed.
- **Release promotion** consumes the fragment files. That is what makes a
  release safe while other branches are open: a branch that appended in
  parallel still holds its own file, so its entry reappears in the new
  unreleased section instead of merging into a section that has moved.
- **Never rename an identifier already on the default branch.** When the gate
  reports a collision, rename the fragment that has not landed. If both have
  landed, allowlist the pair.

**Two traps.** A check chained into the lint target but not into a CI workflow
step does not run, and nothing reports it — have CI invoke the aggregate target
so coverage is total by construction. And a **custom** merge driver named in
`.gitattributes` needs `git config` in every clone; when that is missing git
falls back silently. `union` is built in and needs nothing, which is why it is
the only driver worth putting in a file you expect other people to clone.

**Acceptance test:** two branches each add a registry entry; both merge with
zero conflicts and zero duplicate identifiers. Write it before the mechanism,
and keep a control case that reproduces the defect on the shape you replaced —
a test that cannot fail proves nothing.
