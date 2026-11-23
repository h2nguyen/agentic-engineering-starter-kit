# An install records the kit it was brought in line with, and the kit checks the record against the files

## Status

Accepted. Supersedes ADR-0011's decision to keep installs without a record of
their kit. ADR-0011's acceptance test of the upgrade steps stands, and is
extended here.

**Related:** ADR-0011, ADR-0014, ADR-0008, ADR-0021, ADR-0002

## Context

ADR-0011 declined an installed-version manifest. Its reasons: no upgrade step
used the answer; no migration needed it; and a recorded state is "stale after
a partial upgrade, wrong after a hand merge, and a second source of truth
beside the files it describes". ADR-0014 kept to that and had the installer
print a `Kit:` line for the handoff to copy.

Three things have changed since.

- **The answer now has a use.** The kit has six releases and a changelog
  assembled from fragments. Someone working in a project that installed the
  kit months ago cannot tell which release they are on, so they cannot tell
  whether a newer one exists, which changelog entries apply to them, or which
  of them are marked **Breaking**. The `Kit:` line is in a terminal that was
  closed, or in a handoff nobody kept.
- **A printed line is not a record.** It reaches the repository only if a
  person or an agent copies it, and nothing checks the copy.
- **ADR-0011's own trigger.** It named the case where "which version was
  this" is a question the files cannot answer. Read alone, the files cannot:
  two releases can ship the same file, and a file the adopter changed matches
  no release. With the kit's history beside them they mostly can, which is
  what makes a small record checkable instead of merely trusted.

ADR-0011's objection still holds for any record that is only written and
never checked. The design has to answer it, not set it aside.

Options weighed:

- **Stay without a record** (ADR-0011 as it is). Nothing can go stale. The
  reader's questions stay unanswered, and every upgrade starts with guessing.
- **A manifest of every installed file with its checksum.** It tells "changed
  here" from "older kit's" without the kit's history. It is also the thing
  ADR-0011 described: dozens of lines that every upgrade rewrites, wrong after
  any hand merge, and a second description of files that are already there.
- **No record; derive the release from the files each time**, by comparing
  them with what every tagged release installs. Nothing is stored, so nothing
  is stale. But it needs the kit's history on every run, cannot tell two
  releases that ship the same files apart, and cannot state an intent: "we
  brought this in line with 3.1.0 and kept our change to one script" looks
  the same as "we never finished".
- **A small record that is a claim, written at two moments only, and checked
  against the files every time it is read.**

Where the checking code lives was the second question. Installed in the
project, it would be the older kit's code judging a newer kit, and it would
need its own copy of the installer's knowledge of what goes where. Kept in
the kit, like `bootstrap.sh` and `upgrade-rules.sh`, it is always the newer
kit's, and it can ask each kit's own installer what that kit installs.

The third was how a project learns that a release exists. The kit runs on
Bash and the Python standard library, with no network. A comparison against a
checkout of the kit needs none, but someone has to update the checkout. A
scheduled workflow can look for itself — over the network, unattended, and
with a token for the project's issue tracker. Three shapes of it: the workflow
fetches the kit and runs its report (the kit's code, fetched weekly, running
with a token); the workflow downloads the changelog (data, but parsed by code
in the project that an upgrade must then keep current); or the workflow lists
tag names and nothing else.

## Decision

We will record, in `.starter-kit-version` at the root of the target, the kit
an install was brought in line with: the last release in the kit's changelog,
the kit's commit, and the agent tool. On every tool.

**Two things write it.** `bootstrap.sh`, on a first install. And
`kit-status.sh --record`, the last step of an upgrade. A re-run of the
installer never changes it — it adds files and upgrades none — and gives an
install that has no record none: a record naming the newer kit over files it
did not replace would be false on the day it was written. The installer
"never overwrites a file", and the record is no exception.

**The record is a claim, and the files are the truth.** `kit-status.sh`, in
the kit, rebuilds what the recorded kit and the kit it is run from would each
install — with each kit's own installer, into a scratch directory, for the
recorded tool — and compares the target's copies of the kit's files with both.
A rule is compared by the text under its `paths:` header. It reports:

- the recorded and the available release and commit, and a verdict: up to
  date, a newer kit available, a **partial** upgrade, or a checkout older
  than the record;
- the changelog entries after the recorded release, per release, with the
  entries marked **Breaking** first;
- each of the kit's files as current, the older kit's, changed here, missing,
  declined or retired.

This is the answer to ADR-0011's objection. A partial upgrade does not make
the record false, because nothing wrote to it; the report shows the state as
partial from the files. `--record` refuses while any of the kit's files here
is, byte for byte, what an older release shipped — it is told apart from a
file the adopter changed by comparing it with every tagged release — or while
a file the kit installs is missing and not listed in `.starter-kit-declined`.
A file the adopter changed is accepted, named, and reported as "changed here"
from then on. A record edited by hand, or files reverted under it, are
reported as a record that does not hold, with the release the files are.

**An install without a record** is told so. The report names the release its
files agree with most, shows the changelog since that release, and prints the
command that records it: `kit-status.sh --record --as <tag>`.

**Which files are the kit's** is one list, in `kit_status.py`: the scripts,
`registry.mk`, the entry template, the templates, the rule references, the
rules except `project-annotations.md`, and on Claude Code the hook, the
skills, the coach and the audit command. Everything else an install creates
is the project's. A file the installer ships that is on neither list is
reported as unclassified, and the acceptance suite fails on it, so a new
artifact cannot be shipped without being placed.

`make kit-status`, in `registry.mk`, is the entry in the project: without
`KIT` it prints the record, with `KIT=<checkout>` it runs that kit's report.

**No network in the kit.** "Available" is the checkout the report is run
from. The notice is opt-in, on ADR-0021's terms:
`bootstrap.sh --with-upgrade-notice`, or a yes at a terminal on a first
install, installs `.github/workflows/kit-upgrade-notice.yml`. Weekly, it
lists the kit's release tags with `git ls-remote` and, when one is newer than
the record, opens or updates one issue labelled `kit-upgrade` that names the
offline command. It downloads none of the kit's code, holds `contents: read`
and `issues: write`, and is never installed unasked.

The release that ships this is MINOR by ADR-0008: a repository that passed
`make lint` still passes after the upgrade steps and edits no file of its own.
The record is a new file, and step 7 is the only thing that creates it in an
existing install.

## Consequences

**Easier.** "Which kit is this, and what would an upgrade bring?" is one
command. The first upgrade step can be reading the breaking entries. An
upgrade has an end that something checks: the suite that runs the README's
steps found, on its first run with the record, that it had never performed
the second half of step 2, and that a real 1.1.0 install kept an old skill
through every step.

**Harder.** One more file at the root, and one more upgrade step. The report
needs a git checkout of the kit that contains the recorded commit; from an
export, or a shallow clone, it compares with the available kit alone and says
that the record could not be checked. It runs an installer per release it
compares with — about half a second each, the twelve newest at most — when
files match neither kit.

**Not prevented.** A file the adopter changed and never merged with the
kit's later changes is "changed here" before and after; the record accepts
it, and only a person reading the diff knows whether the merge was done. A
file kept at an older release's text on purpose blocks `--record` until it is
changed or brought over. A file that two releases ship identically is
attributed to the newer one. The record is not authenticated: it is as good
as the review of the commit that changes it.

**Not covered.** A kit installed from an export that is not a git checkout
records `commit: unknown`, and a bare copy of `starter-kit/` records nothing,
as before. The notice workflow is GitHub-specific and reads tags from one
URL; a project that installs from a fork edits it. Its first run can only be
seen in a repository that installed it (ADR-0019).

**Trigger to revisit.** If adopters ask which of *their* files an upgrade
touches before running it, the report can already say so. If they ask the
record to remember per-file decisions — "this script is ours, stop listing
it" — that is the manifest again, and belongs in `.starter-kit-declined`'s
shape: a list of intent the adopter writes, not state the kit keeps.
