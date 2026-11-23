# <Domain> Rules

<One or two sentences: what this file governs and when an agent should load it.>

**Related:** <ISSUE-… or ADR-… this rule came from — delete the line if there is none>

## The Rule

<The core imperative(s), stated first, unhedged.>

**Why:** <What goes wrong without it, in a sentence or two. The reason is what lets an
agent apply the rule to a case no example shows.>

## Canonical Example

```
// WRONG — <why this fails>
<minimal failing example>

// CORRECT
<minimal correct example>
```

## Gotchas

### <Short symptom-style title> (ISSUE-NNN)

<What goes wrong, why, and the canonical fix shape. Cite the knowledge-base
entry or ticket that produced this knowledge.>

**Litmus test:** <a question or runnable command that verifies compliance>

```bash
<grep or check command an agent can run to self-verify>
```

## PR Checklist

- [ ] <verifiable question 1>
- [ ] <verifiable question 2>
