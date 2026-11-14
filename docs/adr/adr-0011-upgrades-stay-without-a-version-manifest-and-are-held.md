# Upgrades stay without a version manifest and are held by an acceptance test

## Status

Accepted

## Context

Moving an install to a newer kit is a list of steps in the kit README. The
kit records nowhere in the adopter's repository which version it was installed
from. A review asked two things: whether those steps had ever been run end to
end, and whether an installed-version manifest should exist.

They had not been run by anything but a reader. So they were: on an install
made by kit 1.1.0's own installer, taken from this repository's history, and
on one built to the shape 1.x left behind — each then customized the way an
adopter would, with a filled-in constitution, a `settings.json` of their own,
a rule they wrote, the rule they filled in, a Makefile, a numbered decision
record, a knowledge-base entry, a changelog fragment, a check script and
tests.

The steps held. Every file of the adopter's came out byte for byte as it went
in, except the two edits the steps name. Lint failed where the README says it
will and nowhere else, and ended green. Two defects turned up, both in the
steps themselves: step 2 copied a suite into the repository that belongs only
in the kit, and step 1 said nothing about a repository with the files of two
agent tools. Neither would have been prevented by knowing the installed
version.

What a manifest would add was weighed against that.

- **It would say which version is installed.** No step uses the answer. Each
  one compares the adopter's files with the kit's — `diff -rq`, `git log --
  <file>` — and that works from any starting version, including one edited
  since.
- **It would let a tool choose migration steps per version.** There is no
  such tool and one migration that needs it: none so far. The one format
  change to date, the `# Enforces:` header, is found by the gate that reads
  it, with the line and the fix.
- **It is one more file the kit writes into a repository** and must then keep
  true: stale after a partial upgrade, wrong after a hand merge, and a second
  source of truth beside the files it describes.

## Decision

We will keep upgrades manifest-free, and hold the documented steps with
`starter-kit/scripts/tests/test-upgrade.sh`, which runs in `make lint`.

The test reads the commands of steps 1 and 2 out of the README and runs them
as written, performs steps 3, 5 and 6 as an adopter would, and asserts what
the README promises: theirs stays theirs, the kit's becomes the newer kit's,
nothing kit-only is left behind, lint reports the documented failures and no
others, and a second step 1 changes nothing. It always runs against the
1.x-shaped install it builds, and against a real 1.1.0 install where the tag
is in the checkout.

## Consequences

**Easier.** A change to the installer, to a gate or to the upgrade section
that breaks an existing install fails a test here, before a release. Adding a
suite that must stay in the kit and forgetting the upgrade step's `rm` line is
one of those.

**Harder.** The suite is the slowest in the kit. And its older install is a
shape, not a census: an adopter who restructured further than the fixture is
not covered by it.

**Not covered.** The three tools other than Claude Code go through the same
steps with `docs/agent-rules/` for `.claude/rules/`; the test runs the Claude
Code layout only. Windows is not exercised.

**Trigger to revisit.** A migration that cannot be detected from the files —
the same content meaning different things in two versions — or a second
format change in one release. Either makes "which version was this" a
question the files cannot answer, and that is what a manifest is for.

**Related:** ADR-0008, ADR-0002
