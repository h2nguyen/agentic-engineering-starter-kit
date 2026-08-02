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
