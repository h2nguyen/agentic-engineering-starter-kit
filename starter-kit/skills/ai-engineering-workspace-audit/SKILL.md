---
name: ai-engineering-workspace-audit
description: >
  Audit, consolidate and upgrade the project's AI workspace — constitution/CLAUDE.md,
  rules, skills, subagents, commands, hooks, memory files — for agentic-engineering
  efficiency and effectiveness. Use this skill whenever the user invokes
  /ai-engineering-workspace-audit, asks to audit, reassess, revise, consolidate,
  clean up, harden or spring-clean the AI workspace, agent setup, rules, skills or
  subagents, mentions workspace drift, context bloat, an oversized CLAUDE.md, agent
  config feeling messy or outdated, or usage limits draining unusually fast — even
  if they don't say "audit" explicitly. Also use it for recurring workspace health
  checks (weekly quick check, per-milestone full audit). Two modes: "quick"
  (default; strictly read-only drift report) and "full" (six-phase audit with an
  approval-gated, lossless-first consolidation). Scope is the AI/agent
  configuration only — not application-code audits, security audits, or general
  refactoring. Never deletes learned knowledge without written justification.
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# AI Engineering Workspace Audit

Reassess, consolidate, and upgrade this project's AI workspace — constitution,
rules, skills, subagents, commands, hooks, memory files — so the agentic
engineering pattern runs more efficiently (leaner always-loaded context, right
model per task) and more effectively (clearer roles, verified outputs), without
losing accumulated project knowledge.

Act as a senior agentic-engineering architect and work plan-first. These files
govern every future agent session in this repo, so the audit itself must be the
most disciplined session of all: read before judging, plan before touching,
preserve before optimizing.

## Mode selection

Requested mode: `$ARGUMENTS`. If empty or unrecognized, run `quick` — it is
read-only and cheap, so it is always a safe default. Choose `full` only when
the user explicitly asked for it or clearly wants a complete
audit/consolidation.

| Mode    | Phases                   | Writes                    | Typical cadence                                |
|---------|--------------------------|---------------------------|------------------------------------------------|
| `quick` | 0–1 + drift report       | none (strictly read-only) | weekly                                         |
| `full`  | 0–5, gate before Phase 4 | after approval only       | per milestone, or when `quick` finds a blocker |

## Phase 0 — Inventory

1. Detect every agentic configuration artifact in this repo, adapting to the
   actual layout and tooling: constitution and always-loaded memory (e.g.
   `CLAUDE.md`, `CLAUDE.local.md`, auto-memory files), rules (`.claude/rules/*`),
   skills (`.claude/skills/*`), subagents (`.claude/agents/*`), commands
   (`.claude/commands/*`), hooks and settings (`.claude/settings*.json`),
   progress/memory docs.
2. Record for each file: purpose, load class (defined in Phase 1), approximate
   size (lines / estimated tokens), and its apparent rationale.
3. Build the knowledge ledger: every project-specific learning, decision,
   convention, or constraint encoded anywhere in these files, each with an ID
   and source. The ledger is the preservation baseline for the whole audit —
   anything not captured here risks being silently lost during consolidation.
   Example entry:
   `L-07: integration tests need a local Redis on port 6380 (CLAUDE.md §Testing)`
4. Check staleness: read `.claude/WORKSPACE_CHANGELOG.md` if present and note
   the date and scope of the last audit.
5. Protect the audit's own context: if the inventory means reading many or
   large files, delegate the bulk reading to a subagent and pull back only the
   structured inventory and ledger.

## Phase 1 — Assessment

Evaluate the workspace against current agentic-engineering practice. Cite
evidence (file + section) for every finding, assign a severity — blocker,
improvement, or nice-to-have — and name the remediation-ladder rung you would
apply (ladder defined in Phase 3). Example finding:
`[improvement] CLAUDE.md §Deploy — 45 lines of release runbook always loaded — rung 1: relocate to skills/release, leave a pointer`

**1. Context budgets by load class.** Budgets differ because load behavior
differs — a line in an always-loaded file is paid on every request, a line in
a skill only when it triggers:

- ALWAYS-LOADED (constitution, rules without path scoping, anything @-imported
  into them): strict — target ≤ ~200 lines each.
- ON-DEMAND (skills, path-scoped rules, commands, reference docs): relaxed —
  length is fine while the file covers one cohesive topic, loads only when
  genuinely relevant, and is structured for fast skimming (clear headings,
  essentials first).
- PER-INVOCATION (subagent bodies, i.e. their system prompts): budget by spawn
  frequency — frequently-spawned subagents get lean role prompts with detail
  in reference files they read on demand; rarely-used specialists may be
  richer.

Treat files over their class budget as candidates for the Phase 3 remediation
ladder, not for summarization — summarizing first is exactly how context and
hard-won guidance get destroyed. Also flag the inverse: multi-topic files
within budget that would still load cleaner after a topic split.

**2. Separation of concerns.** Constitution = durable principles; rules =
enforceable conventions; skills = repeatable procedures; subagents = isolated
roles with minimal tool grants; commands = entry points. Flag content in the
wrong layer, duplicates, and contradictions between files — duplicates drift
apart over time, and contradictions make agent behavior unpredictable.

**3. Model routing.** Each subagent should be pinned to the cheapest model
tier that does its job well (deep reasoning → strongest; routine execution →
mid; trivial/lookup → light). Blanket use of the strongest tier drains usage
limits without adding quality on routine work.

**4. Verification discipline.** Completed work should be proven with evidence
(test output, command results), ideally by a separate reviewer or verifier
agent — and reviewers should be scoped to correctness-relevant findings,
because an unscoped reviewer always finds something, which breeds
over-engineering.

**5. Lifecycle fit.** The workflow should cover research → plan → execute →
review → ship, with human approval gates at plan and merge.

### Quick mode ends here

Produce the drift report and stop. Quick mode earns its weekly cadence by
being read-only and cheap, so make no proposals and no changes beyond the
report. Use this exact structure:

```
# Workspace Drift Report — <project> — <date>
Last audit: <date + scope, or "none found">

## Inventory
| File | Load class | Lines | Budget check |

## Findings
- [severity] <file §section> — <issue> — <suggested rung>

## Verdict
Full audit warranted: <yes/no> — <one line why>
```

## Phase 2 — Gap analysis (full mode)

Propose new skills, rules, or subagents only where a recurring, demonstrated
need exists in this project — repeated manual steps, repeated mistakes,
unowned responsibilities. For each proposal give: name, one-line purpose,
trigger, model tier, and expected token cost vs. effort saved. Reject
proposals that add standing context cost without recurring benefit — every
addition is a permanent tax on future sessions, so it must pay rent.

## Phase 3 — Consolidation plan  ⛔ approval gate

Produce a prioritized change plan — merges, moves, splits, clarity rewrites,
deletions, additions — one line per change:
`- [priority] <relocate|split|compress|delete|merge|add> <target> — <reason> — ledger items: <IDs or none>`

**Remediation ladder** for oversized or multi-topic files. Apply in order and
stop at the first rung that resolves the finding — rungs 1–3 are lossless,
which is why deletion sits last:

1. RELOCATE — move detail out of always-loaded files into on-demand skills or
   reference docs, leaving a one-line pointer behind.
2. SPLIT — divide multi-topic files into single-topic files, each with a clear
   name, a description/trigger that makes it discoverable, and a
   cross-reference from its parent (progressive disclosure: lean entry file +
   linked reference files). Split along topic boundaries, never at an
   arbitrary line count.
3. COMPRESS — reword for brevity without dropping semantics.
4. DELETE — only under the deletion policy below.

Anti-fragmentation guard: never split below the level of a coherent topic. A
fragment that cannot be found, or that separates a guideline from the context
needed to apply it, is worse than a long file — merge such fragments back.

**Deletion policy.** The default posture is preserve: project learnings are
expensive to rediscover and cheap to keep. Remove content only when at least
one of these applies, each with written justification:
(a) obsolete — superseded by a newer decision or tooling;
(b) contradicted by evidence;
(c) factually wrong;
(d) a recognized anti-pattern.
Flag ambiguous cases for the user's decision instead of deleting. Merging and
rephrasing is allowed; dropping semantics is not.

Cross-check the finished plan against the Phase 0 ledger and list every ledger
item touched. Then stop and wait for explicit approval — these files steer
every future session, so edits proceed only on a human decision.

## Phase 4 — Apply (after approval)

Implement the approved plan in small, reviewable git commits — one concern per
commit, so any single change can be reverted without unwinding the rest.
Update all cross-references between files. Append to
`.claude/WORKSPACE_CHANGELOG.md` (create it if missing): date, mode, summary,
ladder rungs used, ledger items affected.

## Phase 5 — Verify

Show evidence rather than asserting success: always-loaded line/token count
before vs. after; duplicates merged; ledger check (every item preserved or its
removal justified); the share of findings resolved at rungs 1–2 vs. 3–4 (a
healthy audit resolves most findings losslessly); and a dry run of one
representative task confirming the workspace still behaves as intended.

## Guardrails

- Touch governance files only — an audit that also edits product code mixes
  concerns and makes the run hard to review and trust.
- Preserve the project's voice, language, and naming conventions.
- Where a best practice or tool behavior may have changed since training,
  verify against current official documentation before asserting it.
- Report context spend honestly; if the audit's own context degrades, pause
  and recommend a fresh session rather than pushing through.

## Cadence and model guidance

Run `quick` weekly on a mid-tier model — it exists to be cheap. Run `full` per
milestone or when `quick` reports a blocker, with the strongest reasoning tier
on Phases 1–3 (e.g. a plan-with-strong-model setup); Phase 4 execution can
drop a tier. The first `full` run on a project is the expensive one; later
runs should shrink — if they do not, that is itself a finding.
