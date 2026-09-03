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
| New convention agents must follow | Rule file + constitution index line |

The "same PR" clause is load-bearing: the author of the change is the only one
who knows what to write, and the knowledge decays within days.

## Decision rationale lives in ADRs, not in code comments

Shipped source — templates, styles, i18n bundles, anything that reaches a
user's browser or a release artifact — must not carry decision-history
narrative, third-party or competitor references, ticket-number stories, or
multi-paragraph rationale. A code comment states a constraint the code cannot
show: one line, plus a pointer to the durable home.

```text
// WRONG — decision narrative at the call site
// We evaluated three retry libraries and chose X because Y's maintainer ...
// (12 more lines)

// CORRECT — constraint + pointer
// Retries must be idempotent — see ADR-007
```

**Litmus before committing any comment:** read it as if a customer saw it via
*View Source*. Does it name a third party? Narrate a decision? Exceed three
lines? Reference a ticket by ID? Any yes → relocate to an ADR or the PR
description; leave at most a one-line pointer.

## ADR format (Michael Nygard)

One file per decision under `docs/adr/`, four sections. Create it with
`registry_tool.py new --registry adr --title "..."` so the filename matches the
project's identifier scheme — under the default that is
`docs/adr/<date>-<slug>.md`, publishing as `ADR-<date>-<slug>`.

A numbered filename (`NNN-<slug>.md`) is also supported and is the reason the
identifier gate exists: the *file* never conflicts, because two decisions are
two paths, but two branches both taking the next free number produce a
duplicate that merges cleanly and is caught by nothing until something cites
it. See the shared-registries rule.

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
comments and knowledge-base entries, and nothing checks that a citation still
resolves.

## PR checklist

- [ ] Every behaviour change in this PR has its doc updated in this PR?
- [ ] Any >30-min bug got its knowledge-base entry?
- [ ] Any cross-file design choice got an ADR — not a long comment?
- [ ] No decision narrative or third-party references in shipped source?
