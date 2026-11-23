# The evidence file is generated at a stamped commit and recomputed by lint

## Status

Accepted

**Related:** ADR-0016, ADR-0019, ADR-0022

## Context

The kit tells other projects how to work with agents. Someone deciding whether
to adopt it can fairly ask what happened in the repository that wrote it, now
that the repository runs on its own kit (ADR-0022). Until now the answer was
prose in the guide about a reference project the reader cannot see.

A page of numbers about how well a method works has two problems. It is the
first thing a reader doubts, and the easiest thing to embellish, by intent or
by a stale copy. And most of what can honestly be counted in a repository
changes with every commit, so a file that must equal "the repository now" is
out of date in the commit that adds it.

Options weighed:

- **A hand-written page.** Readable, and unverifiable. It decays the day after
  it is written.
- **Numbers from the working tree, with a drift gate.** Works for what the
  files say. It cannot hold anything read from history, such as what merged
  pull requests carried or whether feedback was acted on: those change with
  the commit that records them.
- **Publish from CI only**, as a job summary. Always current, but it lives in
  run logs that expire, and nothing in the repository can be cited.
- **Compute everything at one stamped commit, and recompute at that commit.**

What to count was the other question. Outcome claims such as "fewer defects"
need a comparison this repository does not have. What it has is whether its
own rules were followed and whether its own loop turned.

## Decision

We will generate `docs/EVIDENCE.md` with `scripts/evidence_tool.py`
(`make evidence`). Its first line is a stamp naming the commit it was computed
at. Every number comes from an export of that commit and the history up to it,
never from the working tree.

`make lint` runs `evidence-check`, which recomputes the file at the stamped
commit and fails on any difference. A commit made after the stamp leaves the
file older, not wrong, and the check says how many commits behind it is. The
release procedure regenerates it, so a release publishes its own numbers. A
stamp that names a commit outside the history fails; in a shallow clone, which
cannot tell, the check passes with a note and CI verifies.

It counts four things:

- **Guardrails:** the gates in `make lint` and the test suites.
- **The record of change:** decision records, releases, and of the merged
  `feat` and `fix` pull requests, how many added a changelog fragment and how
  many changed a test suite.
- **The kit applied to itself:** artifacts linked under `.claude/`, the lines
  every session loads, and the share of commits co-authored by an agent.
- **The feedback loop:** points from listed authors, how many were followed by
  a change to the artifact they name and after how long, and the coach cycles
  recorded in the workspace changelog.

The file states its own limit: one repository, no control group. The numbers
show that the loop runs, not that the kit causes anything. A zero is printed
as a zero.

The tool is this repository's. It is not installed; an adopter who wants the
same for their project is a signal to ship it.

## Consequences

**Easier.** A reader can check every number with one command, and a reviewer
sees in the pull request when a number moves. The loop's own health becomes
visible: feedback that is never acted on shows as a ratio that does not rise.

**Harder.** A change to what the tool measures fails the check until the file
is regenerated, which is one more step in such a pull request. Between
releases the file trails the repository.

**Not shown.** Whether CI ran: that is not in git (ADR-0019), so the file
links to the workflow's runs. Whether a rule that was loaded was also
followed. And anything about quality that needs a comparison.
