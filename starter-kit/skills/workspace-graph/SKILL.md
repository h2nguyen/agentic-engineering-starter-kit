---
name: workspace-graph
description: >
  Answer questions about how the workspace's artifacts depend on each other,
  using the typed links between them — and keep those links true when an
  artifact changes. Use this skill whenever the user asks what cites, uses,
  enforces or reviews a rule, skill, agent, command, check script, decision
  record or knowledge-base entry; asks what breaks if one is renamed, deleted,
  split or rewritten ("impact analysis", "what depends on this"); asks which
  checks or rules exist because of an incident; asks which agent owns a rule,
  or which rules have no script or no reviewer ("coverage"); asks where the
  human approval gates are; or when `make lint` fails in the link gate
  (`check-graph-links.sh`, "resolves to nothing"). Also use it BEFORE
  renaming, moving, deleting or splitting any workspace artifact, even if the
  user did not ask for an impact check. Do NOT use it for dependencies between
  source files or packages — it reads the workspace's own artifacts, not the
  codebase — or for writing a knowledge-base entry or decision record (that
  is registry-entry).
---

# Workspace Graph

Every rule, skill, agent, command, check script, decision record and
knowledge-base entry is a node; every `Related`, `Enforces` and `Hands off to`
line is an edge. This skill reads that graph to answer a dependency question,
and keeps it true through a change. Done means: the question is answered with
a `file:line` trail, or the change has landed with every citer updated and the
link gate green.

The graph knows only typed links. A sentence that mentions an artifact is not
an edge, so every answer is a floor, not a census — say so when you report it.

## Phase 1 — Name the node

1. Identify the artifact as a token: `RULE:<file name without .md>`,
   `SKILL:<directory>`, `AGENT:<name>`, `COMMAND:<name>`,
   `SCRIPT:<file name>`, `DOC:<name>`, or an entry identifier (`ISSUE-…`,
   `ADR-…`). A path works too.
2. If unsure of the name, query with your best guess: an unknown node exits
   non-zero and suggests the closest real ones.

## Phase 2 — Read the graph

| Question | Command |
|---|---|
| What cites this, and what does it cite? | `make graph-impact NODE=<token>` |
| Which checks and rules exist because of this incident? | `make graph-impact NODE=ISSUE-…`, then the same on each rule it lists |
| Which rules have no script or no reviewer; which gates does no agent cite? | `make graph-coverage` |
| Where does work stop for a human? | `make graph-impact NODE=HUMAN` |
| Does every link still resolve? | `make graph-links` |

Report what the output says, with its `file:line` trail. Then search for the
artifact's name as plain text too — `grep -rn "<name>"` over the rule, skill,
agent and docs directories — and report prose mentions separately. They are
dependencies the graph cannot see.

## Phase 3 — Change with the graph

For a rename, a move, a delete, a split or a rewrite:

1. Run Phase 2 on the artifact **before** editing it. Its "Cited by" list is
   the change set: every line on it is edited in the same pull request.
2. Make the change. For a rename or a split, point each citer at the new
   token; for a delete, remove the link line or point it at the successor.
3. A rewrite that changes what a rule requires is a change to every script
   and agent on its `Enforces` list. Read each one against the new text.
4. The identifier of a knowledge-base entry or decision record that is
   already on the default branch is never renamed. Supersede it with a new
   entry that links the old one.

## Phase 4 — Verify

1. `make graph-links` passes.
2. `make graph-impact NODE=<new token>` lists the citers you expected, and
   the plain-text search no longer finds the old name — or finds only the
   mentions you chose to keep.
3. `make lint` passes.

## Failure modes

- **The gate says a link "resolves to nothing".** Fix the citing line, not
  the gate: point it at the artifact's current name (the message lists the
  real ones), or delete it if the artifact is gone.
- **The citing file is an accepted decision record.** It is immutable. Add
  the pair to `.graph-link-allowlist` as `<citing file> <token>  # reason`.
  No other kind of file qualifies, and an entry without a reason is rejected.
- **"This repository has no SKILL artifacts"** (or AGENT, COMMAND), on a tool
  without native skills. Declare where the playbooks live in
  `registries.json` — `"graph": {"nodes": {"SKILL": ["<glob>"]}}` — instead
  of dropping the link.
- **Coverage lists a rule with no script.** Not a defect and not a task: a
  script is earned when the rule is violated despite being documented. Report
  it, and propose nothing unless a violation is on record.
- **A hand-off to a rule or a document is rejected.** A document does not run
  next. Cite it with `Related` or `Enforces`, and hand off to the skill,
  agent, script or `HUMAN` that acts on it.
- If the Phase 3 change set alters what an agent or a skill is told to do,
  STOP and show the user the list before editing. Those files steer every
  later session.

## Links

**Related:** RULE:documentation, SCRIPT:graph_tool.py

**Hands off to:** SCRIPT:check-graph-links.sh — the exit check after any change

**Hands off to:** HUMAN — before a change set that alters what an agent or a skill is told to do
