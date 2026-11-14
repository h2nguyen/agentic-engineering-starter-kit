# Documentation Rules

Documentation is a **first-class deliverable**: every feature, fix, and
architectural decision updates its documentation in the same PR — not "later".
These rules are project-agnostic defaults; add project-specific doc locations
as the project grows.

## What to update when

| Change | Update, in the same PR |
|---|---|
| New feature | Feature doc (or README section) + CHANGELOG `[Unreleased]` bullet |
| Behaviour or API change | The affected doc + CHANGELOG bullet |
| Bug fix that took >30 min to diagnose | Debugging-KB entry + CHANGELOG `Fixed` bullet — both as fragment files |
| Architectural decision (affects multiple files or future choices) | New ADR |
| New convention agents must follow | Rule file, started from `docs/agent-templates/_rule-template.md` — the imperative, a WRONG/CORRECT pair, a litmus test, and a `Related:` line citing the incident or decision behind it — + constitution index line |
| Documented rule violated anyway | Check script, started from `docs/agent-templates/check-convention.sh.template` — its header names the rule (`# Enforces: RULE:<name>`) — chained into the lint target. Then name the new rule or script on the `Related:` line of the incident that prompted it |
| Same workflow walked through twice, or the same review comment on a second PR | Skill (or playbook) from `_skill-template.md`, reviewer agent (or review checklist) from `_agent-template.md`, both in `docs/agent-templates/` |
| Renaming, deleting or rewriting a rule, skill, agent, command or script | Every artifact that cites it — `make graph-impact NODE=<KIND:name>` lists them |

The "same PR" clause is load-bearing: the author of the change is the only one
who knows what to write, and the knowledge decays within days.

## Decision rationale lives in ADRs, not in code comments

Not in the body of the artifact. An inline annotation states a constraint the
work cannot show — one line, plus a pointer to the durable home — and the
reasoning itself goes to an ADR (architectural or cross-cutting decision), a
knowledge-base entry (investigation, root cause) or the pull-request
description (per-change review context). Shipped source — templates, styles,
i18n bundles, anything that reaches a user's browser or a release artifact —
carries no decision narrative, third-party or competitor references, or
ticket-number stories at all. The doctrine behind this — the structural ladder
that comes before any annotation, the brevity standard, the WRONG/CORRECT pair,
the audience litmus, the protected marker shapes and the no-sweeps scope —
lives in `comments-and-annotations.md`; this rule only routes the rationale.

## ADR format (Michael Nygard)

One file per decision under `docs/adr/`. Create it with
`registry_tool.py new --registry adr --title "..."` so the filename matches the
convention declared in `registries.json` — the tool derives the name, and a
hand-typed one is how a file ends up outside the grammar the gate enforces.

Two naming conventions ship, and `registries.json` says which one this
repository uses — `python3 scripts/registry_tool.py list` prints the exact
shape. The **date-slug** style is what a fresh install declares:
`adr-<date>-<slug>.md`, publishing as `ADR-<date>-<slug>`; it needs no
allocator and therefore cannot collide. The **MADR** style is
`adr-NNNN-short-title.md` (`"id_scheme": "numeric"`, `id_width: 4`),
publishing as `ADR-0001`.

A numbered convention is the reason the identifier gate exists: the *file*
never conflicts, because two decisions are two paths, but two branches both
taking the next free number produce a duplicate that merges cleanly and is
caught by nothing until something cites it. See the shared-registries rule.

The four sections, in [Michael Nygard's
format](https://github.com/architecture-decision-record/architecture-decision-record):

1. **Status** — proposed / accepted / deprecated / superseded by ADR-X
2. **Context** — the forces at play: what made a decision necessary, and the
   options weighed against each other. Value-neutral; describe the tension
   rather than arguing for the outcome. Rejected options belong here, one line
   and its trade-off each — they are part of the forces, not a separate topic.
3. **Decision** — what was chosen, in active voice: "We will …"
4. **Consequences** — the resulting context once the decision is applied, good
   and bad alike. What becomes easier, what becomes harder.

Accepted ADRs are immutable; changing course means a new ADR that supersedes
the old one by identifier. **Never renumber an ADR that is already on the
default branch** — its identifier is cited from rule files, other ADRs, code
comments and knowledge-base entries, and only the citations written as typed
links (next section) are checked. The rest break silently.

## Typed links

A rule that came from an incident, a script that enforces a rule, a skill that
hands work to a reviewer: each is a dependency between two files, and one
written only as prose ("see the testing rule") breaks silently when the other
file is renamed. Write it as a **typed link** — a line that names the other
artifact by a stable token — and `make lint` checks that every token still
names something.

| Line | Says | May name |
|---|---|---|
| `**Related:**` | this artifact cites that one | any artifact |
| `**Enforces:**` | this script or reviewer holds that rule | a rule, a decision record, a document |
| `**Hands off to:**` | who or what runs next | a skill, an agent, a command, a script, or `HUMAN` |

Tokens are `RULE:<name>`, `SKILL:<name>`, `AGENT:<name>`, `COMMAND:<name>`,
`SCRIPT:<file name>`, `DOC:<name>`, and the identifiers of knowledge-base
entries and decision records exactly as `registries.json` declares them. The
name is the file's name without its extension (a skill's is its directory), so
a token survives a move between tool layouts and breaks only on a rename.
`HUMAN` is the approval a workflow waits for.

Several tokens are comma-separated. `Enforces` and `Hands off to` may add
` § <section>` after a token and end with ` — <note>`; `Related` is a plain
list. In a script the same lines are comments in the header block.

```text
WRONG   — nothing can check this, and nothing finds the script from the rule
# Enforces: the migration naming convention, see the database rule

CORRECT — the gate resolves RULE:database; the rule's impact lists this script
# Enforces: RULE:database § Migration names — one migration per file
```

Fenced examples and files whose name starts with an underscore are not read,
so templates and illustrations can show the syntax freely. A citation inside a
sentence (`see ISSUE-019`) is still welcome and still unchecked — put the one
that must not rot on a link line.

**Before renaming, deleting or rewriting** a rule, skill, agent, command or
script, ask what cites it, and change every citer in the same pull request:

```bash
make graph-impact NODE=RULE:<name>   # what cites this, with file:line
make graph-links                     # every typed link resolves (part of make lint)
```

**Litmus test:** does `make graph-links` pass, and does every check script and
reviewer agent added in this PR carry an `Enforces` line naming its rule?

An accepted ADR is immutable, so it cannot follow a rule that is later
retired. That one case goes in `.graph-link-allowlist` as
`<citing file> <token>  # reason`; the gate reports the exemption on every run
and fails once it is stale.

## PR checklist

- [ ] Every behaviour change in this PR has its doc updated in this PR?
- [ ] Any >30-min bug got its knowledge-base entry?
- [ ] Any cross-file design choice got an ADR — not a long comment?
- [ ] Anything renamed or deleted: every citer changed in this PR, and
      `make graph-links` green?
- [ ] No decision narrative or third-party references in shipped source?
