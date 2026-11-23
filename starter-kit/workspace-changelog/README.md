# Workspace changelog

The history of this repository's agent workspace — constitution, rules,
skills, agents, commands, hooks, settings — as one file per run: a setup or
harmonize pass, a workspace audit, an agent-coach cycle. It is the record that
stops the next run from re-litigating what an earlier one settled: the
"deliberately NOT changed" list is as load-bearing as the changes themselves.

## One file per run

Name each file `<YYYY-MM-DD>-<what>.md`, where `<what>` says what the run
was and is not shared with another branch: `2026-11-21-harmonize-setup.md`,
`2026-12-02-full-audit.md`, `2026-12-09-coach-reviewer-escapes.md`. The dated
files, sorted by name, are the history, oldest first; read the newest first.

Not one file with the newest entry on top. Every run would insert at the same
line, and two pull requests open at once then conflict on it — and a day of
setup work is easily three pull requests. Two files with different names
cannot conflict.

So a file is written once, by the pull request that adds it. A later pull
request that belongs to the same run adds a file of its own, with a `<what>`
that says what it adds (`2026-11-21-harmonize-setup-ci.md`), and names the
earlier file in its headline. Editing a file that another open pull request
may also be editing is the conflict again; so is a name two branches would
both choose, which is why a bare `coach-cycle` or `audit` is not enough.

A repository that still has a single `WORKSPACE_CHANGELOG.md` from an earlier
setup keeps it as the archive: read it for history, write nothing new into it.

## Entry format

Copy this into the new file. A coach cycle uses the same shape: its proposals
go in the changes table, with "approved" or "rejected" in place of the rung.

```markdown
# <YYYY-MM-DD> — <setup | harmonize | quick audit | full audit | agent-coach cycle>

**Mode:** <quick|full>. **Baseline:** `<branch@short-sha>`. **Branch:** `<working branch>`.
**Kit:** `<the installer's "Kit:" line — on a run that installed or upgraded the kit>`.

## Headline result

<One or two sentences: the most important outcome, with numbers where possible
(e.g. always-loaded lines before → after).>

## Changes applied

| # | Commit | Change | Ladder rung | Ledger items |
|---|---|---|---|---|

## Deliberately NOT changed (with reasons)

- <artifact / finding> — <why it was left alone>

## Follow-ups

- <anything outside the run's scope that needs a ticket or a later run>
```
