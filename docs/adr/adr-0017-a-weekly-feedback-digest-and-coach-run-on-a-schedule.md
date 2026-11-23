# A weekly feedback digest and coach run on a schedule, opt-in at install

## Status

Accepted

**Related:** ADR-0006, ADR-0016

## Context

ADR-0016 gave the improvement loop its input: `Agent-Feedback:` lines and
`make agent-feedback`. It deferred the scheduled improver until feedback piled
up faster than anyone ran the coach. It also said the scheduled improver would
need a new record, not an edit to ADR-0006. ADR-0006 had rejected "a scheduled
agent that repairs the workspace in the background", because it changes rules
with nobody watching and needs credentials the kit does not manage.

The maintainer asked for the schedule now, for this repository, and for it to
be a choice each adopting project makes when the kit is installed. A collector
that nobody runs is a loop that does not turn: the signal is there, and
nothing brings it to a person.

The forces:

- **Who changes what.** ADR-0006's objection is to a rule changed with nobody
  watching. A schedule that only *reports* and *proposes* does not do that. A
  schedule that pushes, even to a branch, starts to.
- **Credentials.** Collecting feedback needs none. Posting it needs the token
  every GitHub Actions run already has. Running the coach needs a model and a
  key, which belong to the project, and the action that runs it authenticates
  as the Claude GitHub App. Whether that action can open a pull request by
  itself on a schedule is not documented.
- **Consent.** A workflow that posts to a project's issue tracker every week
  is not something to install silently. Nor is it something an agent should
  switch on for someone because nobody was there to ask.
- **"Nothing speculative".** This is not a day-1 default: it is installed only
  when a person asks for it.

Options weighed:

- **Install it for everyone, disabled.** A file that does nothing until edited
  is the dead artifact the kit avoids. Enabling it is an edit to a file the
  adopter then owns.
- **Have the coach open a pull request.** It is closest to "the loop closes by
  itself". But it needs write access to contents and pull requests, relies on
  undocumented behaviour, and moves the proposal from a place people read into
  a diff that looks like a change already made.
- **Only post the digest, no coach.** This needs no credentials and gives a
  person the evidence. But the proposal step stays manual for everyone, even
  projects that have a key.
- **Post the digest, and when a key is configured, post the coach's proposals
  beside it.**

## Decision

We will ship `ci/agent-feedback.yml.template`. The installer puts it in place
as `.github/workflows/agent-feedback.yml` only when asked:

- with `--with-coach-schedule`; or
- by a yes to the question it asks at a terminal on a first install.

Run without a terminal, as from an agent, it installs the workflow only with
the flag, and the next steps say how to add it. An agent installing the kit
asks the user. A listed path in `.starter-kit-declined` keeps it out, and the
installer then does not ask.

Every Monday, and by hand at any time, the workflow:

1. collects the last seven days of feedback with `make agent-feedback`;
2. posts it as a Markdown digest (`--format markdown`) on one open issue
   labelled `agent-feedback`, and posts nothing for an empty week;
3. if an `ANTHROPIC_API_KEY` secret is set and the coach's file exists, runs
   one coach cycle with read-only tools and posts the proposals as a comment
   on the same issue.

The job holds `contents: read` and `issues: write` (and `id-token: write` for
the app's authentication) and nothing else. It cannot push, branch or open a
pull request. A person reads the proposals and makes the change, so the coach's
rule "propose, never silently change" holds on a schedule too.

This repository switches it on. The coach's instructions here are in the kit
(`starter-kit/agents/agent-coach.md`), and `.agent-feedback-authors` lists the
maintainer's commit email beside the login.

ADR-0006's rejection stands for what it rejected: nothing here changes a rule.
This record replaces only ADR-0016's deferral of the scheduled improver.

## Consequences

**Easier.** A project that chooses it sees each week's feedback, grouped by
artifact, without anyone remembering to run a command. With a key, the coach's
proposals arrive beside the evidence they cite. The digest needs no secret at
all.

**Harder.** It is GitHub-specific, as the installed lint workflow already is.
GitHub runs scheduled workflows from the default branch only, and pauses them
in a public repository after 60 days without activity. The coach step depends
on a third-party action that its own documentation still calls beta, on the
Claude GitHub App being installed, and on a paid key. Until a key is set it is
skipped, so in a repository without one only the digest has been exercised.

**Not prevented.** Wrong feedback from a listed author reaches the digest and
the coach. A person reading the proposal is still the safeguard. The coach's
output is model text posted to an issue. It is read, never executed.
