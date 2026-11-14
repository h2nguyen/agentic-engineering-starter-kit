# The constitution check ships as a command, not as a default gate

## Status

Proposed

## Context

A small model was handed the kit and asked to install it into an empty
project and build something there. The installer's closing message told it to
delete the template's example rows and links that the project had no
counterpart for. It finished with `make lint` green and a constitution that
still linked `testing.md` and `security.md` — two example rules from the
template that were never written — and still carried the template's
`<add one line per rule file …>` line. A second fresh session then worked from
that constitution.

Nothing in the lint target could have said so. The typed-link gate resolves
`Related:`, `Enforces:` and `Hands off to:` lines; ordinary Markdown links are
out of its grammar by design (ADR-0004). No gate reads placeholders. The
constitution is the one file every session loads first, and it was the one
file nothing opened.

The instruction existed and was not followed, so more instruction is not the
repair. What was missing is something that fails. Three shapes were weighed.

- **A default gate, chained into the installed `lint`.** It would have caught
  this run. It is also red on every fresh install until the constitution is
  filled in, which changes what a first `make lint` means, and — for a
  repository that upgrades — it is a gate that is on by default and can fail a
  constitution that passed before: a dead link to a rule renamed last year, a
  phrase in angle brackets. ADR-0008 calls that a MAJOR release, and names the
  alternative: ship opt-in first.
- **Widening the link gate to every Markdown link in every file.** Far more
  than the finding asks for, breaking for the same reason, and it would have
  to learn every document's idea of an example.
- **A check that ships installed and unchained**, named by every instruction
  that says how to verify an install.

And two for what counts as a placeholder.

- **Any `<…>` in the files the installer wrote.** The comments-and-annotations
  rule and its reference are full of `<DECISION-RECORD-ID>` and WRONG/CORRECT
  examples that are the content; the constitution template itself keeps
  `--title "<symptom>"` and `RULE:<rule file name>` on purpose.
- **Only the constitution, and only prose.** `<…>` that opens with a letter
  and contains a space, outside fenced blocks, code spans, HTML tags and
  comments. Every placeholder the template ships has that shape; none of the
  angle brackets it means to keep does.

## Decision

We will ship `scripts/check-constitution.sh` and the target `constitution` in
`registry.mk`, installed for every tool on day 1 and **not** a prerequisite of
`lint`.

It reads the constitution only — `CLAUDE.md`, `AGENTS.md`,
`.github/copilot-instructions.md`, or files named as arguments — and fails,
with file and line, on a relative Markdown link to a path that does not exist
and on a placeholder in the narrow sense above. It never reads a rule file or
a rule reference.

The installer's next steps, this repository's `AGENTS.md`, the kit README, the
guide and the setup prompt all name `make constitution` as the check that
onboarding is finished, before `make lint`. An adopter who wants it on every
pull request adds the target to their own `lint:` line; the coverage gate does
not require it. This repository chains it into its own lint.

It ships on day 1 although it is not a default gate because its first use is
on day 1: a check that arrives after the constitution was filled in has
nothing left to catch of the half of it that is about placeholders.

## Consequences

**Easier.** "Is the install finished" has a command with an exit status. A
dead link in the constitution — the template's, or one left by a later
rename — is found by something other than the next reader.

**Harder.** It is a command someone has to run. An agent told only "run
`make lint` before you finish" will not run it, and the run that prompted
this was told exactly that. What changed is that the instructions an
installing agent reads now name it; that is a mitigation of the failure, not
a guarantee against it, and it has not been re-tested with the model that
failed.

**The definition of a placeholder is a heuristic.** A constitution that
writes `<some phrase>` in prose and means it has to put it in backticks. A
one-word placeholder is not flagged; the template has none outside a link.

**Trigger to revisit.** At the next MAJOR release, chain `constitution` into
the installed `lint` and add it to the gates the coverage gate requires — the
batching ADR-0008 describes. Sooner, if a second install is found committed
with placeholders after an agent was pointed at `make constitution`.

**Related:** ADR-0008, ADR-0004, SCRIPT:check-constitution.sh, RULE:documentation
