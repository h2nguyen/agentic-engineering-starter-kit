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
| Bug fix that took >30 min to diagnose | Debugging-KB entry (ISSUE-NNN) + CHANGELOG `Fixed` bullet |
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

## ADR-lite format

One file per decision, `docs/adr/NNN-<slug>.md`, four sections:

1. **Context** — why a decision was needed
2. **Decision** — what was chosen
3. **Alternatives** — what was rejected, one line + trade-off each
4. **Consequences** — what becomes easier, what becomes harder

Accepted ADRs are immutable; changing course means a new ADR that supersedes
the old one by number.

## PR checklist

- [ ] Every behaviour change in this PR has its doc updated in this PR?
- [ ] Any >30-min bug got its knowledge-base entry?
- [ ] Any cross-file design choice got an ADR — not a long comment?
- [ ] No decision narrative or third-party references in shipped source?
