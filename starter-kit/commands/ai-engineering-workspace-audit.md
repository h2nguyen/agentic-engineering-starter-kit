---
description: Audit & consolidate the project's AI workspace — quick (read-only drift check) or full (six-phase gated consolidation)
argument-hint: "[quick|full]"
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
disable-model-invocation: true
---

# AI Engineering Workspace Audit — entry point

Run the AI-workspace audit in mode `$ARGUMENTS` (empty or unrecognized → `quick`, the always-safe read-only default).

This command is deliberately a thin, slash-only entry point (`disable-model-invocation: true` — it never auto-triggers). The canonical procedure lives in the companion `ai-engineering-workspace-audit` **skill**. Invoke that skill now with the requested mode and follow it exactly:

- `quick` — Phases 0–1 + drift report, strictly read-only (weekly cadence)
- `full` — Phases 0–5 with the ⛔ approval gate before Phase 4 writes (per milestone, or when `quick` finds a blocker)

Do not re-derive the phases, remediation ladder, or deletion policy here — on any conflict the skill file is canonical. Audit history: `.claude/WORKSPACE_CHANGELOG.md`.
