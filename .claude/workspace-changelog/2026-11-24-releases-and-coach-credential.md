# 2026-11-24 — full audit, continued (releases, and the coach's credential)

**Mode:** full. **Baseline:** `main@9e492a5`. **Branch:** `docs/workspace-run-followup`.
**Kit:** applied by reference from this checkout's `starter-kit/`, not installed (ADR-0022).

Follows `2026-11-23-version-record-and-open-points.md`. That file stands as it was written; what changed since is here.

## Headline result

The version record and the Node 24 workflows are on `main` and released as 3.1.0; 4.0.0 followed from another session; the coach now runs on a Claude subscription where there is no API key, released as 4.1.0. Two of the earlier follow-ups are closed: the actions are on Node 24, and the coach no longer needs an API key.

## Changes applied

| # | Pull request | Change | Ladder rung | Ledger items |
|---|---|---|---|---|
| 1 | #27 | `.starter-kit-version`, `kit-status.sh`, upgrade step 7, the opt-in upgrade notice, ADR-0024. A review before the merge found seven defects, fixed first test by test | — | — |
| 2 | #28 | `actions/checkout@v7` and `actions/setup-python@v7`, read from each action's `action.yml` | — | — |
| 3 | #29 | Release 3.1.0 | — | — |
| 4 | #31 | The coach runs on `ANTHROPIC_API_KEY`, else on `CLAUDE_CODE_OAUTH_TOKEN`; the action is passed the one credential chosen; ADR-0026 | — | — |
| 5 | #32 | Release 4.1.0 | — | — |

Releases 3.1.0 and 4.0.0 are tagged and published by hand. `v4.1.0` is not tagged at the time of writing: tag pushes from an agent session are refused with HTTP 403.

## Deliberately NOT changed (with reasons)

- **Load classes** — unchanged from the first file: no documented way to bind a linked rule to paths.
- **The improver for skills and rules, and golden cases per skill** (ADR-0016) — still waiting for their signals: feedback nobody acted on, and a merged proposal that had to be reverted.
- **The 3.1.0 changelog section** still carries the sentence that nothing in a repository records the kit; a later bullet in the same section supersedes it. Released sections are immutable; a correction belongs under the next `[Unreleased]`.
- **Co-authored-by trailers** of earlier commits that name a model: history is not rewritten.

## Follow-ups

- **The feedback loop has not turned.** First turn: a listed author's `Agent-Feedback:` line in a commit on `main`, then the "agent feedback" workflow by hand. The subscription path of the coach has not run on GitHub either: it takes a `CLAUDE_CODE_OAUTH_TOKEN` secret made with `claude setup-token`, and the Claude GitHub App on the repository.
- `lint` as a required status check on `main`: not readable from here, so not confirmed.
- The upgrade steps are run by a test on the Claude Code layout only; the version record is tested on all four tools.
- `kit-upgrade-notice.yml` has not run anywhere: both its steps are tested locally, against a local kit and a stand-in `gh`.
