# Agentic Engineering Setup Guide

A portable, self-contained guide to setting up **agentic engineering** — a repeatable process in which AI coding agents work inside an engineered system of context, guardrails, workflows, and feedback loops — in any new or existing software project.

It consolidates how the process works in one mature production repository — referred to below as **the reference project** — and distills it into a **generic blueprint** you can adopt anywhere. Reference-project material appears as *illustration*, never as prescription: its domain rules (architecture style, persistence patterns, regulatory compliance) are examples of *how to write* rules, not rules you should copy.

The guide is **agnostic to the agentic tool**: the concepts apply to any agentic coding system. File layouts are shown in Claude Code's conventions (what the reference project runs); §3.10 maps every artifact to other tools, and the starter kit's `bootstrap.sh` installs the templates for whichever tool your repo uses.

> **Companion:** [`starter-kit/`](starter-kit/) contains every template in this guide as a ready-to-copy file, plus `bootstrap.sh` — an initializer that detects (or asks) which agentic tool your repo uses and installs the templates to that tool's expected locations — and `SETUP-PROMPT.md`, a self-contained prompt that makes an agent drive the whole setup in any repo, kit or no kit. Copy the directory into a fresh repo and follow §4.

---

## How to use this guide

| You want to… | Read |
|---|---|
| Understand the concepts and why they work | §1 |
| See what a mature, battle-tested setup looks like | §2 |
| Get file templates and design rules for each artifact type | §3 (+ `starter-kit/`) |
| Bootstrap a new project or retrofit an existing one | §4 |
| Keep an existing setup healthy over time | §5 |

---

## 1. What agentic engineering is

### 1.1 Definition

**Agentic engineering** is the practice of treating AI coding agents as team members who need the same things human engineers need — onboarding docs, coding standards, review processes, CI gates, institutional memory — and encoding all of it **as versioned files in the repository** so that every agent session starts with the accumulated knowledge of every previous session.

The difference from "using an AI assistant" is systemic: an assistant answers the question you asked; an agentic engineering setup makes sure the *next hundred sessions* ask better questions, follow the same conventions, avoid known traps, and leave the system smarter than they found it.

Three properties define a working setup:

1. **Knowledge is in the repo, not in heads or chat history.** Conventions, gotchas, and decisions are files under version control, reviewed in PRs like code.
2. **Rules are enforced, not just stated.** Anything that matters has a mechanical check (CI script, drift check, architecture test) — because agents, like humans, drift from prose-only rules.
3. **The system learns.** Every resolved bug, repeated instruction, and review miss is converted into a durable artifact that prevents recurrence.

### 1.2 The seven core principles

#### P1 — Constitution, not documentation

One always-loaded file — `AGENTS.md` by the emerging cross-tool convention, `CLAUDE.md` in Claude Code, equivalents elsewhere (§3.10) — is the agent's **contract**: what this project is, the non-negotiable rules, the commands that matter, and pointers to everything else. It is *not* a README for humans — it is optimized for an agent's decision-making: tables over prose, imperative rules over background, links over inlining.

*Reference project:* its constitution is 184 lines. It states each non-negotiable rule in one table row ("NEVER expose `Long id` in API responses — always `UUID uuid`") and delegates every detail to a linked rule file.

#### P2 — Progressive disclosure: context is a budget

Every line in an always-loaded file is paid for on **every request**. A mature setup layers knowledge by load behavior:

| Load class | Artifacts | Cost | Budget discipline |
|---|---|---|---|
| **Always loaded** | Constitution, rules files, anything imported into them | Paid every request | Strict — keep each file lean; relocate runbooks out |
| **On demand** | Skills, skill `references/`, docs | Paid only when triggered | Generous — detail is cheap here |
| **Delegated** | Subagent instructions | Paid in a separate context | Isolated — a subagent can read 50 files without polluting the main session |

The practical move: when a chunk of always-loaded text is relevant to <5 % of sessions, move it into a skill or an on-demand doc and leave a one-line pointer.

*Reference project:* a workspace audit found a 1,095-line domain-data guide imported into the constitution yet relevant to ~0.5 % of commits. Converting it to a pointer (with its four safety-critical invariants distilled inline) cut always-loaded context by 20 % with zero knowledge loss.

#### P3 — Guardrails as code: the three enforcement layers

A rule that exists only as prose will eventually be violated — by an agent that never loaded it, or loaded it and prioritized something else. Robust setups enforce important rules three times:

| Layer | Mechanism | Catches |
|---|---|---|
| 1. **Stated** | Rule file / constitution | Violations at *write time* (agent reads the rule before coding) |
| 2. **Reviewed** | Specialist subagent / review checklist | Violations at *review time* |
| 3. **Enforced** | CI script / lint gate / architecture test | Violations *mechanically*, every PR, forever |

Layer 3 is what makes the system trustworthy: it doesn't depend on anyone (human or agent) remembering.

*Reference project:* its "never parse the JWT subject inline" rule exists as (1) a section in `rules/security.md`, (2) a check in the `security-auditor` agent, and (3) `scripts/check-jwt-sub-extraction.sh` wired into `make ci-lint`. The repo carries 37 such check scripts; `ci-lint` chains ~44 gate targets.

#### P4 — Verifiable goals: tests and litmus tests

Agents execute best against goals a machine can verify. Two instruments:

- **TDD as the default loop.** "Write the failing test first" turns a vague task into a binary goal. Bug fixes require a regression test that fails before the fix — which also proves the agent actually reproduced the bug.
- **Litmus tests inside rules.** A rule ends with a one-line check — often a runnable `grep` — that an agent (or reviewer) can execute to self-verify compliance. This converts judgment calls into lookups.

*Reference project:* its `rules/testing.md` ends E2E guidance with: *"Litmus test: does the row-text assertion target a row-scoped locator rather than `page.getByText(...)`?"* — and many rules embed the exact `grep` command that answers the question. For medium-or-larger tasks it extends goal-driven execution with a plan-first phase discipline (QRSPI: Questions → Research → Structure → Plan → Implement), distilled as working principle 5 in the starter kit's `rules/working-principles.md`.

#### P5 — Division of labor: specialist subagents

One generalist agent reviewing everything produces shallow reviews. Instead, define **specialist subagents**, each owning one review dimension with narrow tools and explicit instructions: what to detect, what to reject, what its domain's known traps are. The main agent (or a workflow) fans review work out to them.

Model tiering belongs here too: mechanical checks run on cheap/fast models, judgment-heavy reviews on strong ones.

*Reference project:* it runs 9 agents — `architecture-guard`, `security-auditor`, `code-reviewer`, `db-migration-expert`, `test-engineer`, `i18n-guard`, `release-manager`, `ux-designer-agent`, and the meta-agent `agent-coach` — with per-agent model pins (opus for security and coaching, sonnet for most, haiku for the i18n check that CI backstops anyway).

#### P6 — Compounding memory: the learning flywheel

The setup's long-term value comes from a conversion discipline — every recurring signal becomes a durable artifact:

| Signal | Convert into |
|---|---|
| Bug that took >30 min to diagnose | Debugging-KB entry (symptom → root cause → fix → prevention → shortcut) |
| Instruction you've typed twice in chat | A line in the constitution or a rule file |
| Workflow you've walked an agent through twice | A skill |
| Review comment made on two different PRs | A rule + a subagent check |
| Rule violated despite being documented | An enforcement script (layer 3) |

*Reference project:* its debugging knowledge base holds 160 ISSUE entries. Rules cite them (`see ISSUE-019`), agents check for them, and the constitution mandates: *"Before investigating any bug, search the KB first."* A repeated bug class costs the team once.

#### P7 — Human in the loop

Autonomy is bounded by review gates that keep humans in control of anything hard to reverse:

- **PR-only trunk** — agents never commit to `main`; every change passes human review.
- **Propose, never silently change** — meta-level agents (ones that edit *other agents' instructions* or consolidate the workspace) present diffs with evidence and apply only after explicit approval.
- **Approval-gated destruction** — audits and consolidations are lossless-first; deleting learned knowledge requires written justification.

*Reference project:* its `agent-coach` runs an explicit loop — `OBSERVE → DIAGNOSE → PROPOSE → [HUMAN APPROVES] → APPLY → MEASURE` — and treats an unapproved edit to another agent's file as a violation of its own mandate.

### 1.3 Artifact glossary

| Artifact | What it is | Load behavior | Home (Claude Code shown) |
|---|---|---|---|
| **Constitution** | The always-loaded project contract | Every session | `CLAUDE.md` |
| **Rule file** | Self-contained source of truth for one domain (testing, security, …) | Always/near-always loaded | `.claude/rules/*.md` |
| **Skill** | A packaged, multi-step workflow with trigger conditions; may bundle `references/` and `scripts/` | On demand (trigger-matched or `/name`) | `.claude/skills/<name>/SKILL.md` |
| **Subagent** | A specialist persona with its own instructions, tools, and model | Delegated (separate context) | `.claude/agents/<name>.md` |
| **Slash command** | A short prompt invoked as `/name`; best kept as a thin pointer to a skill | On demand | `.claude/commands/<name>.md` |
| **Hook** | A shell script run on harness events (session start, tool calls) | Event-driven | `.claude/hooks/` + `settings.json` |
| **MCP server** | An external tool server the agent can call (docs generators, analyzers) | On demand | `.mcp.json` |
| **Enforcement script** | A CI-wired check that mechanically enforces a convention | Every PR | `scripts/check-*.sh` + lint target |
| **Knowledge base** | Append-only log of diagnosed bugs in a fixed format | Searched on demand | `docs/…/DEBUGGING-KNOWLEDGE-BASE.*` |
| **Workspace changelog** | Audit history of the AI configuration itself | On demand | `.claude/WORKSPACE_CHANGELOG.md` |

Locations are shown in Claude Code's conventions; §3.10 maps each artifact to other agentic tools, and every artifact's *content* is tool-neutral.

---

## 2. Anatomy of a mature setup — the reference project

The reference project is a multi-tenant SaaS platform operating under a strict regulatory-compliance regime (JVM backend, SPA frontend, Python AI services). Its agentic workspace has grown over hundreds of PRs and one formal workspace audit. The numbers below are measured from the repo, not estimated.

### 2.1 Inventory at a glance

| Layer | Artifact(s) | Size | Problem it solves |
|---|---|---|---|
| Constitution | `CLAUDE.md` | 184 lines | One contract every session starts from |
| Rules | `.claude/rules/` — 16 files | ~4,200 lines | Domain detail without bloating the constitution |
| Skills | `.claude/skills/` — 9 skills | varies; some bundle `references/`, `scripts/`, `tests/` | Repeatable multi-step workflows |
| Agents | `.claude/agents/` — 9 agents | ~50–150 lines each | Specialist review + a meta-improvement loop |
| Commands | `.claude/commands/` — 6 commands | thin | Muscle-memory entry points (`/review`, `/new-entity`) |
| Hooks | 1 `SessionStart` hook | ~400 lines | Toolchain bootstrap so `make test` works in any session |
| MCP | `.mcp.json` — 2 servers | — | Architecture analysis + arc42 docs as callable tools |
| Enforcement | `scripts/check-*` — 37 scripts, ~44 `ci-lint` gates | — | Rules that cannot be silently violated |
| Knowledge base | `DEBUGGING-KNOWLEDGE-BASE.adoc` | 160 entries | Paying for each bug class only once |
| Meta | audit skill + `WORKSPACE_CHANGELOG.md` + `agent-coach` | — | The setup maintains itself |

### 2.2 Layer walkthrough

**L1 — The constitution (`CLAUDE.md`).** Structured as: one-paragraph project identity → 4 working principles (one line each, linked) → tech-stack table → command list → a **"Non-Negotiable Rules" table** (one row per rule, each linking to its rule file) → an index of rules, skills, agents, and MCP tools → debugging protocol. Nothing is explained at length; everything is stated and linked. The key structural idea: *the constitution is an index with teeth* — the rules it states inline are exactly the ones violated most expensively.

**L2 — Rule files (`.claude/rules/`).** Each file is declared "a self-contained source of truth for its domain, including gotchas, litmus tests, and reference impls." Sizes vary deliberately: `working-principles.md` (113 lines, process values) vs `testing.md` (693 lines, every known test-flake trap with canonical fixes). Three recurring internal patterns worth copying:

- **The canonical-example pair** — every abstract rule ships a WRONG/CORRECT code pair.
- **The litmus test** — a runnable check closing each major section.
- **The incident citation** — rules born from bugs cite their KB entry (`ISSUE-019`), so a doubting reader can trace the evidence.

**L3 — Skills (`.claude/skills/`).** Two species: **workflow skills** (`gh-ticket-workflow` drives a ticket from branch to merged PR through TDD phases and quality gates; `release-workflow` encodes the bump-tag-build-deploy pipeline) and **knowledge skills** (`semver` bundles the full spec plus decision guides as `references/`, loaded only when versioning questions arise). The `description` frontmatter field is load-bearing: it enumerates trigger phrasings so the skill fires even when the user doesn't name it. Larger skills push detail into `references/*.md` (progressive disclosure again) and ship executable helpers in `scripts/`.

**L4 — Agents (`.claude/agents/`).** Each is a Markdown file with YAML frontmatter (`name`, `description`, `tools`, `model`) and a body that reads like a specialist's employment contract: mandate, explicit violation lists to detect, output format. Review agents get read-only tools (`Read, Grep, Glob, Bash`); only `agent-coach` gets `Edit/Write` — plus `AskUserQuestion`, because its mandate *requires* human approval before applying anything.

**L5 — Commands (`.claude/commands/`).** `/review`, `/new-entity`, `/new-migration`, `/security-check` — checklist-style prompts with `allowed-tools` frontmatter and `$ARGUMENTS` interpolation. Lesson learned during the workspace audit: when a command and a skill covered the same workflow, the duplicated content drifted; the fix was making commands **thin pointers** into skills. Adopt that from day one.

**L6 — Hooks.** One `SessionStart` hook installs/detects the pinned JDK, Node, and Python deps; imports the egress-proxy CA; prepares MCP dependencies; starts Docker; and persists `PATH`/`JAVA_HOME` via the harness env file — asynchronously, so the session starts instantly. Problem solved: agent sessions run in non-interactive shells that skip profile files; without the hook, every session would rediscover a broken toolchain.

**L7 — MCP servers.** `clean-architecture-mcp` (layer-dependency and SOLID analysis) and `arc42-docs-mcp` (structured architecture-doc updates), declared in `.mcp.json` and enabled in `settings.json`. The constitution marks them "USE ACTIVELY", and the `/review` command hard-wires specific MCP calls as mandatory review steps — tools that are merely *available* get forgotten; tools that are *scripted into workflows* get used.

**L8 — Enforcement.** The signature move: **when a rule is violated despite documentation, write a script.** Examples of doc→script pairs: JPA entity registry rule → `check-jpa-entity-registry-drift.sh`; "never edit applied migrations" → `check-baseline-schema-freeze.sh` (with a commit-message escape marker for the one sanctioned case); "PR titles are Conventional Commits" → `check-pr-title.py`. Escape hatches are themselves designed: a greppable marker in a commit message (`[baseline-cutover]`, `[skip-changelog]`) — logged forever, never silent.

**L9 — Knowledge base.** 160 entries in one fixed format: *Symptom → Investigation Trail → Root Cause → Fix → Prevention → Debug Shortcut*. The constitution wires it into the debugging protocol in both directions: search before investigating; write after resolving anything non-obvious (>30 min).

**L10 — Meta.** Three artifacts make the workspace self-maintaining: the **`ai-engineering-workspace-audit` skill** (quick read-only drift report weekly; six-phase full audit per milestone, with a knowledge ledger built *before* any edit and human approval gating all writes); the **`WORKSPACE_CHANGELOG.md`** recording each audit's changes and — as importantly — its "deliberately NOT changed (with reasons)" list; and the **`agent-coach`** meta-agent (P7 above) that reviews the reviewers.

### 2.3 How one bug becomes system knowledge (worked example)

The reference project's ISSUE-019 shows the full flywheel:

1. **Incident** — bookings intermittently failed with duplicate-key violations. Diagnosis took hours: the ORM's soft-delete filter silently excluded deleted rows from a `MAX(sequence_number)` query feeding a unique constraint.
2. **KB entry** — ISSUE-019 recorded with symptom, root cause, and a debug shortcut.
3. **Rule** — `rules/jpa-entities.md` gained a CRITICAL section: "any query whose result feeds a unique constraint → always `nativeQuery = true`", with the WRONG/CORRECT pair.
4. **Test pattern** — `rules/testing.md` mandates a regression-guard shape: every such query gets an integration test that inserts a soft-deleted row first.
5. **Review layer** — the `/review` command checklist and the `db-migration-expert` agent both check for it.
6. **Constitution** — the rule's one-line summary sits in the Non-Negotiable Rules table, citing ISSUE-019.

Total cost: one incident. Recurrence probability: near zero — an agent writing a new query hits the rule at write time, the reviewer at review time, and the test pattern at CI time.

---

## 3. The generic blueprint

Everything in this section is project-agnostic. Templates are inline (so this guide is self-contained) and also shipped as files in `starter-kit/`.

### 3.1 Directory layout

Shown in Claude Code's conventions; §3.10 maps every path to other tools, and the starter kit's `bootstrap.sh` performs that mapping for you.

```
your-repo/
├── CLAUDE.md                        # constitution (always loaded)
├── .mcp.json                        # optional: MCP server declarations
├── .claude/
│   ├── settings.json                # hooks + enabled MCP servers
│   ├── rules/                       # self-contained domain rule files
│   │   ├── working-principles.md    #   process values (universal — see starter kit)
│   │   ├── testing.md               #   your test conventions + known traps
│   │   └── <domain>.md              #   one file per domain that accumulates rules
│   ├── skills/
│   │   └── <skill-name>/
│   │       ├── SKILL.md             #   workflow + trigger description
│   │       ├── references/          #   optional deep-dive docs (loaded on demand)
│   │       └── scripts/             #   optional executable helpers
│   ├── agents/
│   │   └── <agent-name>.md          # specialist subagent definitions
│   ├── commands/
│   │   └── <command>.md             # thin /command entry points
│   ├── hooks/
│   │   └── session-start.sh         # optional environment bootstrap
│   └── WORKSPACE_CHANGELOG.md       # audit history of this configuration
├── docs/
│   └── DEBUGGING-KNOWLEDGE-BASE.md  # ISSUE-NNN entries
└── scripts/
    └── check-<convention>.sh        # CI-wired enforcement checks
```

### 3.2 The constitution

**Design rules**

1. Target ≤ ~200 lines. If it grows past that, relocate detail into rule files or skills and leave pointers.
2. Structure: identity → working principles → stack/commands → non-negotiable rules table → artifact index → debugging protocol.
3. Every non-negotiable rule is one table row: the imperative + the link to its rule file. No explanations inline.
4. State facts an agent needs for decisions (ports, credentials locations, command names) — not narrative history.
5. It is versioned and PR-reviewed like code. Wrong constitution lines are bugs.

**Template** (starter kit: `constitution.md.template` — `bootstrap.sh` installs it under the filename your tool expects: `CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`, …)

````markdown
# Agent Constitution — <Project Name>

<One paragraph: what this system is, who uses it, the one or two domain
constraints that shape everything (compliance regime, multi-tenancy, …).>

## Working Principles

1. **Think before coding.** State assumptions; surface ambiguity before implementing.
2. **Simplicity first.** Minimum code that solves the problem; no speculative abstractions.
3. **Surgical changes.** Touch only what the task requires; match existing style.
4. **Goal-driven execution.** Every task becomes a verifiable goal; write the test first.
5. **Plan-first for non-trivial work.** Questions → Research → Structure → Plan → Implement; only blocking questions pause the work.

Full text + litmus tests: [`.claude/rules/working-principles.md`](.claude/rules/working-principles.md)

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | <language, framework, versions> |
| Frontend | <framework, versions> |
| Database | <engine, migration tool> |
| Infrastructure | <IaC, containers/orchestration, CI/CD> |
| Auth | <identity provider, AuthN/AuthZ model> |
| Messaging / Integration | <message bus, event streams, external APIs> |
| Testing | <frameworks per layer> |

## Commands

```bash
make dev          # start local stack
make test         # full test suite
make lint         # lint + enforcement checks (must pass before any PR)
```

## Non-Negotiable Rules

| Rule | Detail |
|---|---|
| **Git** | Never commit to main. Branch prefixes: feat/, fix/, chore/, docs/ |
| **TDD** | Failing test first. Bug fixes need a regression test before the fix. |
| **Security** | <e.g. every endpoint authenticated by default; secrets only via env/secret manager> — see rule file |
| **Documentation** | Docs are part of the change — updated in the same PR — see [`documentation.md`](.claude/rules/documentation.md) |
| **Versioning** | SemVer 2.0.0; new functionality = MINOR, never PATCH; changelog bullet in the same PR — see [`versioning-and-changelog.md`](.claude/rules/versioning-and-changelog.md) |
| **<Domain rule 1>** | <one-line imperative> — see [`.claude/rules/<domain>.md`](.claude/rules/<domain>.md) |
| **<Domain rule 2>** | <one-line imperative> — see rule file |

## Detailed Rules

- [`working-principles.md`](.claude/rules/working-principles.md) — process directives
- [`documentation.md`](.claude/rules/documentation.md) — docs-with-the-change, ADR-lite format, comment hygiene
- [`versioning-and-changelog.md`](.claude/rules/versioning-and-changelog.md) — SemVer levels, Keep-a-Changelog discipline
- [`testing.md`](.claude/rules/testing.md) — test conventions, known flake traps
- [`security.md`](.claude/rules/security.md) — AuthN/AuthZ defaults, secret handling, data classification
- <add one line per rule file as they accumulate — infrastructure, messaging/integration, and other cross-cutting concerns earn one early>

## Debugging

Before investigating any bug, search `docs/DEBUGGING-KNOWLEDGE-BASE.md` (ISSUE-001+).
After resolving a non-obvious bug (>30 min), add a new ISSUE-NNN entry:
Symptom → Investigation Trail → Root Cause → Fix → Prevention → Debug Shortcut.
````

### 3.3 Rule files

**Design rules**

1. **Self-contained source of truth**: everything about the domain — rules, gotchas, litmus tests, reference implementations — lives in one file. An agent loading it needs nothing else.
2. Every abstract rule ships a **WRONG/CORRECT code pair**.
3. Close major sections with a **litmus test** — ideally a runnable command.
4. Cite evidence: the KB entry, ticket, or ADR the rule came from.
5. Cross-reference sibling rule files rather than duplicating (duplicated rules drift).
6. Document reality, not aspiration. A rule the codebase itself violates everywhere trains agents to ignore rules; either fix the code or scope the rule ("new code follows X; migrate legacy files only when touched").
7. **Cross-cutting concerns earn a rule file early.** Security (AuthN/AuthZ defaults, secret handling, data classification), infrastructure & deployment, and messaging/integration contracts span modules — no single file teaches them by example, which is exactly where agents most need written rules. Testing and per-language conventions are the other early candidates.

**Template** (starter kit: `rules/_rule-template.md`)

````markdown
# <Domain> Rules

<One or two sentences: what this file governs and when an agent should load it.>

## The Rule

<The core imperative(s), stated first, unhedged.>

## Canonical Example

```<lang>
// WRONG — <why this fails>
<minimal failing example>

// CORRECT
<minimal correct example>
```

## Gotchas

### <Short symptom-style title> (ISSUE-NNN)

<What goes wrong, why, and the canonical fix shape. Cite the KB entry
or ticket that produced this knowledge.>

**Litmus test:** <a question or runnable command that verifies compliance>

```bash
<grep or check command an agent can run to self-verify>
```

## PR Checklist

- [ ] <verifiable question 1>
- [ ] <verifiable question 2>
````

### 3.4 Skills

**Design rules**

1. The `description` frontmatter is the **trigger contract** — enumerate the phrasings, slash command, and situations that should activate it, including negative scope ("do NOT use for …"). This field determines whether the skill fires at all.
2. The body is a numbered procedure with phases and explicit quality gates — written so an agent can follow it without improvising the order.
3. Push deep detail into `references/*.md` (loaded only when needed); ship executable helpers in `scripts/`.
4. Name the failure modes: what to do when a step fails, when to stop and ask.
5. A skill exists because a workflow *recurred*. Don't write speculative skills.
6. **Exception to rule 5 — seed from the commons.** A few skills are generic enough to enable at initial setup, before any recurrence in your repo: versioning/semver decisions, architecture review, architecture documentation, plan-first ticket execution. The starter kit's `skills/common-catalog.md` lists them with per-tool adoption notes.

**Template** (starter kit: `skills/_template/SKILL.md`)

```markdown
---
name: <skill-name>
description: >
  <What this skill does, in one sentence.> Use this skill whenever the user
  <invokes /<skill-name>, asks to <verb phrase>, mentions <trigger keywords>>
  — even if they don't name the skill. Do NOT use for <out-of-scope cases>.
---

# <Skill Title>

<One paragraph: the workflow this skill owns, and the end state that counts
as done.>

## Phase 1 — <Preparation>

1. <step>
2. <step — include the exact commands to run>

## Phase 2 — <Execution>

1. <step>
2. <step>

## Phase 3 — <Verification>

1. <the mechanical check that proves the workflow succeeded>
2. <what to do if it fails — retry rule, or stop-and-ask condition>

## Failure modes

- <known failure> → <recovery>
- If <ambiguous condition>, STOP and ask the user before proceeding.
```

### 3.5 Subagents

**Design rules**

1. One agent = one review dimension (architecture, security, tests, migrations…). Generalists produce shallow findings.
2. **Minimal tools.** Reviewers get read-only tools. Grant `Edit`/`Write` only to agents whose mandate is to change files — and pair it with an approval mechanism.
3. Pin the **model tier** to the task: strong models for judgment-heavy domains (security), cheap ones for mechanical checks a CI gate backstops anyway.
4. The body enumerates **concrete violations to detect** — greppable patterns, not vibes — and defines an output format (severity, file:line, rationale).
5. Keep agents aligned with the rule files they enforce; when a rule changes, its agent is part of the diff.

**Template** (starter kit: `agents/_agent-template.md`)

```markdown
---
name: <agent-name>
description: <What it enforces/reviews. When to use it — phrased so the main
  agent knows to delegate to it ("Use when reviewing X", "Use before any PR
  that touches Y").>
tools: Read, Grep, Glob, Bash
model: sonnet
---

You are the <Role Name> for <project>. Your job is to <mandate in one sentence>.

## Your Core Mandate

<The golden rule of this domain, stated once.>

## Violations to Detect and Reject

### <Category 1>
- <concrete, greppable violation pattern>
- <concrete violation pattern>

### <Category 2>
- <concrete violation pattern>

## Known Traps in This Domain

- <trap + the KB entry / rule section that documents it>

## Output Format

For each finding: **severity** (BLOCKER / IMPROVEMENT / NIT), `file:line`,
what rule is violated, and the minimal fix. If nothing is found, say so
explicitly — do not invent findings.
```

### 3.6 Slash commands

**Design rule:** commands are **thin pointers**. If a command and a skill share a workflow, the content lives in the skill and the command delegates — duplicated procedure text *will* drift (the reference project removed 280 lines of drifted duplication in one audit).

**Template** (starter kit: `commands/_command-template.md`)

```markdown
---
description: <one line shown in the command list>
allowed-tools: Read, Grep, Glob, Bash
argument-hint: "[optional args]"
---

<For a self-contained checklist command: the checklist, in execution order,
with runnable commands.>

<For a workflow command: one line —
"Invoke the <skill-name> skill with arguments: $ARGUMENTS">
```

### 3.7 Hooks & settings

Use a `SessionStart` hook when agent sessions need environment setup (toolchains, daemons, env vars) — agent shells are non-interactive and skip profile files. Keep hooks **idempotent** (re-runs are no-ops) and **degrading** (a blocked download warns and continues; the session still starts).

**`settings.json` template** (starter kit: `settings.json.template`)

```json
{
  "enabledMcpjsonServers": [],
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/session-start.sh"
          }
        ]
      }
    ]
  }
}
```

**Minimal hook** (starter kit: `hooks/session-start.sh.template`)

```bash
#!/bin/bash
# SessionStart hook — make sure every agent session has a working toolchain.
# Idempotent: each step no-ops when already satisfied.
# Degrading: failures warn and continue; the session still starts.
set -uo pipefail

# 1. Verify/install the pinned toolchain versions your build needs
# 2. Install dependencies if the lockfile changed (no-op otherwise)
# 3. Start local daemons your tests need (DB, docker, …)
# 4. Persist env vars for subsequent tool calls:
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=$PATH" >> "$CLAUDE_ENV_FILE"
fi
```

### 3.8 Enforcement scripts

**Design rules**

1. One script per convention; exit non-zero with a **`file:line` trail and a pointer to the rule** it enforces ("see `.claude/rules/database.md § Baseline Cutover`").
2. Wire every script into one umbrella lint target (`make lint` / `make ci-lint`) that CI runs on every PR.
3. Design the escape hatch: a greppable commit-message marker (`[sanctioned-exception]`) for the rare legitimate violation — logged in history forever, never silent.
4. Non-trivial check scripts get their own unit tests.

**Template** (starter kit: `scripts/check-convention.sh.template`)

```bash
#!/bin/bash
# Enforces: <rule name> — see .claude/rules/<domain>.md § <section>
# Escape: commit-message marker [<marker>] anywhere on the branch.
set -euo pipefail

violations=$(grep -rn "<forbidden-pattern>" <path-scope> || true)

if [ -n "$violations" ]; then
  # honor the sanctioned-exception marker if this repo defines one
  if git log origin/main..HEAD --format=%B 2>/dev/null | grep -q "\[<marker>\]"; then
    echo "WARN: <rule> violated but [<marker>] present — allowing."
    exit 0
  fi
  echo "FAIL: <rule name> violated:"
  echo "$violations"
  echo "Fix per .claude/rules/<domain>.md § <section>, or add [<marker>] to a commit message if sanctioned."
  exit 1
fi
echo "OK: <rule name>"
```

### 3.9 Debugging knowledge base

One append-only file, fixed entry format, numbered IDs. The format matters more than the storage medium (Markdown, AsciiDoc, wiki — anything greppable). Two design rules upgrade it from a log into a **substrate**:

- **Stable IDs + typed links.** Entry IDs are never reused, and entries cross-reference other artifacts with typed tokens (`ISSUE-NNN`, `ADR-NNN`, `RULE:<slug>`, `SKILL:<slug>`, `SCRIPT:<slug>`, `DOC:<slug>`) on an optional `Related:` line. This is what makes the KB graph-ready (§5.6) at near-zero extra writing cost.
- **Shape is enforced.** The starter kit ships `scripts/check-kb-shape.sh` — runnable as-is, no adaptation — validating heading shape, ID uniqueness, the six required fields, and link syntax. Wire it into the lint target; it doubles as the project's first working enforcement check on day one.

**Template** (starter kit: `docs/DEBUGGING-KNOWLEDGE-BASE.md`)

```markdown
# Debugging Knowledge Base

Search here BEFORE investigating any bug. Add an entry AFTER resolving any
non-obvious bug (>30 min to diagnose). Entries are append-only.

Graph-ready conventions: entry IDs are stable and never reused; cross-reference
other artifacts with typed links on the optional `**Related:**` line —
`ISSUE-NNN`, `ADR-NNN`, `RULE:<slug>`, `SKILL:<slug>`, `SCRIPT:<slug>`,
`DOC:<slug>`, comma-separated. `scripts/check-kb-shape.sh` validates shape and
link syntax.

## ISSUE-001: <Short symptom-style title>

**Symptom:** What the developer/agent observes.

**Investigation Trail:** What was checked; what was misleading.

**Root Cause:** The actual reason.

**Fix:** What was changed.

**Prevention:** The design rule or pattern that avoids recurrence
(and which rule file / enforcement script now encodes it).

**Debug Shortcut:** The quick check to confirm this issue next time.

**Related:** RULE:working-principles
```

### 3.10 Applying this with any agentic tool

The setup is a system of *concepts*; the tool determines only file names and locations. Concept mapping first:

| Concept | Claude Code form | Generic form |
|---|---|---|
| Constitution | `CLAUDE.md` | `AGENTS.md` (emerging cross-tool convention) or your tool's instruction file |
| Rules | `.claude/rules/` | Any always-loaded instruction set / system-prompt fragments |
| Skills | `.claude/skills/` | Prompt playbooks, workflow templates, tool-specific "custom instructions" |
| Subagents | `.claude/agents/` | Multi-agent frameworks' role definitions; separate reviewer bots |
| Enforcement | `make ci-lint` scripts | Plain CI — this layer has nothing agent-specific and works everywhere |
| Knowledge base | KB doc | Works verbatim with any tool (and helps humans just as much) |
| Hooks / MCP | harness-specific | Devcontainer setup scripts / tool plugins — same intent, different plumbing |

Concrete file locations for widely-used tools (conventions move fast — treat your tool's current docs as authoritative):

| Artifact | Claude Code | `AGENTS.md`-convention tools | Cursor | GitHub Copilot |
|---|---|---|---|---|
| Constitution | `CLAUDE.md` | `AGENTS.md` at repo root | `AGENTS.md` (also legacy `.cursorrules`) | `.github/copilot-instructions.md` |
| Rules | `.claude/rules/*.md` | `docs/agent-rules/*.md`, linked from `AGENTS.md` | `.cursor/rules/*.mdc` | `.github/instructions/*.instructions.md` |
| Skills / playbooks | `.claude/skills/` | playbook docs linked from `AGENTS.md` | rule files with scoped triggers | prompt files |
| Knowledge base | `docs/DEBUGGING-KNOWLEDGE-BASE.md` | same — plain doc, tool-independent | same | same |
| Enforcement scripts | `scripts/check-*` + lint target | same — plain CI, tool-independent | same | same |

The starter kit's **`bootstrap.sh`** encodes this mapping: it detects which tool your repo uses (or asks when ambiguous / told via `--tool`), then installs the constitution, the universal working-principles rule, and the knowledge-base skeleton to the right locations. Artifacts with no equivalent in the target tool (native skills, subagents, hooks) are skipped with a note naming the nearest substitute from the table above.

Two layers are 100 % portable regardless of tool — the enforcement scripts and the knowledge base. Build those first if you're unsure which agent tooling you'll standardize on; they also pay off for the humans on the team.

---

## 4. Adoption playbook

### 4.1 Maturity levels

Use this to locate yourself and pick the next step. Don't skip levels — each one generates the raw material (recurring signals) the next level formalizes.

| Level | You have | Value unlocked |
|---|---|---|
| **0** | Nothing — ad-hoc prompting | — |
| **1** | Constitution + working principles + debugging KB | Sessions start informed; bugs paid for once |
| **2** | Rule files + first enforcement scripts in CI | Conventions survive across sessions and agents |
| **3** | Skills for recurring workflows + specialist review agents | Whole workflows delegated; reviews get deep |
| **4** | Meta layer: workspace audits, changelog, agent-coach loop | The setup maintains and improves itself |

### 4.2 Greenfield path (new project)

**Day 1 — Level 1 (≈ 1–2 hours):**

1. Run `starter-kit/bootstrap.sh` from your repo root — it detects which agentic tool the repo uses (or asks), then installs the constitution, the universal rule files (working principles, documentation, versioning & changelog), the knowledge-base skeleton, and the ready-to-run KB-shape check to that tool's expected locations. Manual copy per the starter-kit README works too — or skip the copying entirely and paste `starter-kit/SETUP-PROMPT.md` into an agent session: the prompt drives the whole setup (detect → mine → install → verify) and carries its own fallback specs, so it also works in repos where the kit isn't present.
2. Fill in the constitution: identity paragraph, stack table — including the infrastructure, auth, and messaging/integration rows — the commands that exist so far, and the 3–5 rules you already know are non-negotiable (branch discipline, TDD stance, secret handling).
3. Enable the common generic skills worth having from day one — `starter-kit/skills/common-catalog.md` lists them with adoption notes; the prompt-enhancer and semver skills already ship in the kit, and architecture review / architecture docs are one copy away.
4. Commit. The setup is live: every agent session now starts from the contract.

**Week 1 — Level 2:**

5. Each time you correct the agent twice about the same thing → add the rule (constitution table row if short; new rule file if it needs examples).
6. Wire an umbrella `make lint` target into CI — the kit's `check-kb-shape.sh` is a working first entry; add your first mined `check-*.sh` when a documented rule gets violated anyway.
7. First >30-min bug → ISSUE-001 in the KB. Enforce the discipline from the start; the KB's value is compounding.

**Month 1 — Level 3:**

8. The first workflow you've walked an agent through twice (release process, scaffolding a module) → a skill.
9. The first review dimension where you keep making the same comments → a specialist agent with a violations list.
10. If sessions keep fighting the environment (missing toolchain, dead daemon) → a `SessionStart` hook.

**Later — Level 4:** once the workspace has real mass (≥ ~10 rule/skill/agent files), install the meta layer — the kit ships it: `bootstrap.sh --with-meta` adds the workspace-audit skill + command, the agent-coach meta-agent, and the workspace-changelog skeleton (§5.2–§5.3). Deliberately not part of the day-1 install.

### 4.3 Brownfield path (existing project)

The difference: the knowledge already exists — in heads, PR threads, and incident memory. Adoption is **mining**, not inventing.

1. **Bootstrap the constitution from reality.** Use your tool's init command (Claude Code: `/init`) to draft `CLAUDE.md` from the codebase, then correct it by hand. Document what the code *actually does* — including its warts, scoped honestly ("legacy modules use X; new code uses Y; migrate only files you touch").
2. **Mine the last ~50 PR review threads.** Every comment a reviewer made more than once is a rule file entry — with the real WRONG example straight from the PR.
3. **Mine incident memory.** Ask the team for the five bugs that cost the most time; write them as ISSUE-001…005. This seeds the KB *and* usually yields your first enforcement scripts.
4. **Promote existing checks.** Linter configs, custom CI greps, pre-commit hooks — you likely have Level-2 enforcement already. Chain everything into one `make lint` and reference it from the constitution.
5. **Start agents read-only.** Run specialist reviewers on a few PRs and tune their violation lists against real diffs before trusting their findings in workflow gates.
6. **Retrofit incrementally.** Never big-bang refactor the codebase to match new rules. Encode the target state as rules with a files-you-touch migration policy; the codebase converges over months.

### 4.4 Harmonizing with an existing workspace

The third starting state: the repo **already has** an agentic workspace — a constitution, some rules, maybe skills and agents — of unknown quality. The move is **harmonize, not replace**: the generic blueprint is a default, not a mandate, and a convention that is in use and working beats a textbook one. The reference project runs this discipline as its standing audit skill (§5.2); this track is that audit instantiated at setup time.

1. **Ledger before anything.** Inventory every existing artifact and build a knowledge ledger: each project-specific learning, convention, or constraint encoded anywhere, with an ID and source. The ledger is the preservation baseline — anything not captured risks being silently lost during consolidation.
2. **Classify with evidence, preserve by default.** For each existing artifact decide: **keep** (working — leave untouched), **enhance** (working but missing the blueprint's mechanics — litmus tests, WRONG/CORRECT pairs, enforcement backing), **fix** (contradicts current repo reality, or matches the §5.4 anti-pattern table), or **relocate** (right content, wrong load class). "Working" is evidence, not taste: referenced by other artifacts or CI, matches current code reality, traces to a real incident or signal, actively used by the team.
3. **Conflict rule.** Where an existing convention and the blueprint's default disagree and both are workable, **the existing convention wins**. Replace only what is demonstrably stale, contradicted, or harmful — with the evidence written down.
4. **The trap, balanced.** An entrenched setup can also entrench anti-patterns (context bloat, aspirational rules, duplication, stale claims). Don't inherit them out of respect for what exists: flag each against §5.4 with evidence, fix only with approval, and record what was **deliberately left alone and why** — that list is what stops the next audit from re-litigating settled decisions.
5. **Lossless first.** Remediate up the ladder — *relocate → split → compress → delete* — stopping at the first rung that resolves the finding; the first three are lossless. Deleting learned knowledge requires written justification (obsolete, contradicted by evidence, factually wrong, or a recognized anti-pattern); ambiguous cases go to the user, never silently to the bin.
6. **Gap-fill from the checklist.** Whatever Level 1–2 artifacts are missing (working principles, knowledge base, enforcement, …) get added per §4.2–§4.3 — extending what exists, never duplicating it.
7. **Approval gate.** Changes to a pre-existing workspace ship as a reviewed plan → explicit human approval → small one-concern commits. These files steer every future agent session, so they get the most disciplined treatment of all.
8. **Reuse the resident loop.** If the repo already has its own improvement machinery — a workspace-audit skill, a meta-agent, a workspace changelog — run or *extend it* with this checklist as input rather than working around it. Two competing improvement loops is itself an anti-pattern. (The kit ships this machinery too: a repo bootstrapped with `--with-meta` enters Level 4 with the loop already resident.)

### 4.5 What to defer

- **MCP servers** — until an external tool is genuinely called repeatedly. Wiring tools nobody invokes is pure maintenance load.
- **Meta layer** — audits of a five-file workspace are overhead; adopt at real mass.
- **Model tiering** — a default model everywhere is fine until cost or review depth becomes measurable.
- **Speculative anything** — every artifact must trace to a signal that actually recurred (P6). A skills directory full of guessed workflows is context bloat, not capability.

---

## 5. Maintenance & evolution

### 5.1 The conversion flywheel (the daily discipline)

The single habit that separates a living setup from a decorative one — run the P6 table relentlessly:

| When this happens | Do this, in the same PR / same day |
|---|---|
| Bug took >30 min | KB entry (next ISSUE-NNN) |
| You typed the same instruction a second time | Constitution row or rule-file section |
| You walked the agent through the same workflow a second time | Skill |
| Same review comment on a second PR | Rule + agent violations-list entry |
| Documented rule violated anyway | Enforcement script wired into lint |
| Rule file contradicted by current code reality | Fix the rule file — a stale rule is worse than no rule |
| Agents mis-retrieve from a grown KB/rules corpus, or an impact-analysis need appears | The knowledge-graph layer over the workspace (§5.6) — the conventions already make every artifact a well-formed node |

The "same PR" clause matters: the author of the fix is the only one who knows what to write, and the knowledge decays within days.

### 5.2 Workspace audits

The workspace itself accumulates drift: stale version numbers, rules referencing renamed files, commands duplicating skills, always-loaded bloat. Institutionalize two cadences (the reference project pioneered this as its `ai-engineering-workspace-audit` skill; a copy ships in the starter kit — `bootstrap.sh --with-meta`):

- **Quick (weekly / bi-weekly), strictly read-only:** inventory the artifacts, diff their claims against code reality, report drift. No writes.
- **Full (per milestone), approval-gated:** six phases — inventory → assessment against context budgets → remediation plan → **human approval gate** → apply → verify. Two hard safety rules: build a **knowledge ledger** (every learning encoded anywhere in the workspace, each with an ID) *before* touching anything — it is the preservation baseline; and be **lossless-first** — relocate and compress before deleting; deleting learned knowledge requires written justification.

Record every audit in `WORKSPACE_CHANGELOG.md`: what changed, what was **deliberately not changed and why**, and follow-ups. The not-changed list is what stops the next audit from re-litigating settled decisions.

### 5.3 The agent-coach loop (reviewing the reviewers)

Once you run multiple specialist agents, add a periodic meta-review — the `agent-coach` pattern (a de-branded copy ships in the starter kit via `--with-meta`):

```
OBSERVE → DIAGNOSE → PROPOSE → [HUMAN APPROVES] → APPLY → MEASURE → repeat
```

- **Observe:** per agent, collect rule-drift (instructions vs. current rule files), escaped violations (bugs its domain should have caught), false-positive patterns, and coverage holes (rules/gates no agent owns).
- **Diagnose:** scorecard per agent → *Ready / Needs refresh / Gap*.
- **Propose:** minimal diffs — one agent, one weakness, one edit — each citing concrete evidence. **No "could be nicer" edits.**
- **Approve → apply → measure:** the human is the reward signal; approved edits land as ordinary PR-reviewable commits; the next cycle checks whether they helped.

Guardrails: propose-never-silently-change, and prefer sharpening an existing agent over creating a new one (create only when a recurring task maps to a rule + gate no agent owns).

### 5.4 Anti-patterns

| Anti-pattern | Why it kills the setup | Countermeasure |
|---|---|---|
| **Context bloat** | Always-loaded lines relevant to 1 % of sessions tax 100 % of them | Load-class budgets; relocate to skills/references (§1.2 P2) |
| **Aspiration drift** | Rules describing a codebase that doesn't exist teach agents to ignore rules | Document reality; scope migrations ("files you touch") |
| **Rules without enforcement** | Prose-only rules get violated silently | Layer 3: every violated rule earns a script (§3.8) |
| **Enforcement without rules** | Cryptic CI failures with no rationale get worked around, not learned from | Scripts fail with a pointer to the rule they enforce |
| **Command/skill duplication** | Two copies of one workflow drift apart | Commands are thin pointers (§3.6) |
| **Silent knowledge deletion** | "Cleanup" that loses learned gotchas re-pays for old bugs | Knowledge ledger + lossless-first + written justification (§5.2) |
| **Copying another project's domain rules as universal** | Their constraints are not your constraints | Copy *structures* (this guide); write your own *content* |
| **Speculative artifacts** | Guessed skills/agents nobody triggers = maintenance load | Everything traces to a recurred signal (§4.5) |

### 5.5 Health checklist

Run quarterly (or as the quick-audit report):

- [ ] Constitution ≤ ~200 lines, and every claim in it is currently true?
- [ ] Every non-negotiable rule has all three enforcement layers (stated / reviewed / enforced)?
- [ ] Every enforcement script's failure message points to its rule?
- [ ] KB entry count growing (bugs are being converted, not just fixed)?
- [ ] No rule file contradicts current code reality (spot-check the three oldest)?
- [ ] No command duplicates a skill's body?
- [ ] Agents' violation lists match the current rule files they enforce?
- [ ] `WORKSPACE_CHANGELOG.md` has an entry newer than the last milestone?

### 5.6 The next level: agentic graph engineering

Everything in this guide produces *documents*; the next maturity level treats them as a **knowledge graph**. Every artifact — rule, KB entry, ADR, skill, enforcement script — is a node; every typed cross-reference (`ISSUE-NNN`, `ADR-NNN`, `RULE:<slug>`, …) is an edge. An agent that can traverse that graph gains capabilities flat files cannot give: *"which rules and checks exist because of this incident?"*, *"what does this rule invalidate if it changes?"*, targeted retrieval of exactly the relevant nodes instead of loading whole files, and impact analysis before edits.

The framework prepares for this **by convention, not by tooling**:

- **Stable, never-reused IDs** on every referenced artifact (`ISSUE-NNN`, `ADR-NNN`, rule/skill/script slugs)
- **Typed link syntax** wherever artifacts reference each other — the KB's `Related:` line is the anchor instance; rules citing `ISSUE-NNN` / `ADR-NNN` inline already conform
- **Shape enforcement** (`check-kb-shape.sh`) so the substrate cannot rot before it is ever consumed

The graph *tooling* — an index, a query layer, retrieval integration — is deliberately deferred per the anti-speculation rule (§4.5): build it when a consumer exists. Its trigger lives in the flywheel (§5.1): when the corpus reaches a mass where agents mis-retrieve, or an impact-analysis need actually appears, that is the signal. Until then the conventions cost near-zero — and every entry written today becomes a well-formed node on the day the graph layer lands.

---

## Closing note

None of this requires the scale of the reference project on day one. Its 160 KB entries, 37 check scripts, and 9 agents are the *output* of running the flywheel for a long time — not the entry ticket. The entry ticket is Level 1: a 50-line constitution, one universal rules file, and an empty knowledge base with a discipline attached. Everything else grows from signals your own project generates.

Copy the starter kit, run `bootstrap.sh`, fill in the blanks, and start converting.
