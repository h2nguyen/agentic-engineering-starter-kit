# 2026-11-23 — setup

**Mode:** full. **Baseline:** `main@b5a5fe7`. **Branch:** `claude/busy-hopper-p43b4t`.
**Kit:** applied by reference from this checkout's `starter-kit/`, not installed (ADR-0022).

## Headline result

The agent side of the kit now runs in the kit's own repository: 14 artifacts
are linked under `.claude/` and the workspace-graph hook is registered. Lines
loaded into every session went from 179 (`AGENTS.md` and `CLAUDE.md`) to about
1,090, because all five rules now load. `docs/EVIDENCE.md` has the exact count.

## Changes applied

| # | Commit | Change | Ladder rung | Ledger items |
|---|---|---|---|---|
| 1 | `35426df` | The hook takes `--tool`, so it finds the graph tool under `starter-kit/scripts/` | — | — |
| 2 | `8012cc8` | Links for 5 rules, 7 skills, the `agent-coach` and the audit command; hook registered; `project-annotations.md` filled in; `self-application` gate | — | — |
| 3 | this pull request | `docs/EVIDENCE.md`, generated at a stamped commit and recomputed by `make lint` (ADR-0023) | — | — |

## Deliberately NOT changed (with reasons)

- **Load classes.** A rule is bound to paths by a header written into its
  installed copy. A link has no copy, so all five rules load into every
  session. Accepted for now; the cost is a line in `docs/EVIDENCE.md`.
- **No debugging knowledge base.** A registry is declared when it exists.
- **No copies of the kit's scripts under `scripts/`.** The Makefile runs them
  from `starter-kit/scripts/`; `AGENTS.md` maps the paths a rule names.
- **The installer still refuses this repository.** Applying by reference is
  what replaces an install here.

## Follow-ups

- Check in a new session, with the `rule-load-check` skill, that the linked
  rules and skills load. The session that added the links cannot see it.
- The coach step of the weekly digest has never run: it needs an
  `ANTHROPIC_API_KEY` secret and the Claude GitHub App on the repository.
- `actions/checkout@v4` and `actions/setup-python@v5` run on a deprecated
  Node version; raise them in the workflows and the kit's templates.
