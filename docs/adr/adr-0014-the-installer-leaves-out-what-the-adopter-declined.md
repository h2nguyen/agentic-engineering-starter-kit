# The installer leaves out what the adopter declined

## Status

Accepted

## Context

The installer never overwrites a file and adds whatever is missing. The second
half is what makes a re-run the first step of an upgrade: files that are new
in a kit arrive by running it again.

It also means the installer treats every absent file the same way. An adopter
who deleted two of the kit's skills, because their organisation ships the same
two as a plugin, and the SessionStart skeleton, because it did nothing, got all
three back from the next run. Run against a fresh install with those files
removed, the installer lists them under "Installed". From the files alone,
"deleted on purpose" and "new in this kit" are the same state.

The same adopter asked for two things: skills that can be deselected one by
one, and a manifest of what is installed with checksums.

ADR-0011 weighed a manifest and declined it: no upgrade step uses the installed
version, and a record of state goes stale after a partial upgrade or a hand
merge. Its trigger to revisit is "a migration that cannot be detected from the
files". A deliberate deletion is such a thing, but it is narrower than the
question a manifest answers. What is missing is not what was installed. It is
what the adopter does not want.

Four ways to carry that were weighed.

- **Flags on the installer** (`--without semver`). They hold for one run. The
  upgrade steps run the installer again, months later, from a command the
  README prints; whoever runs it has to remember every flag, and the run that
  forgets one fails silently by installing a file.
- **Detect what the adopter already has** — an organisation plugin that ships
  the same skill. Plugins belong to a user's machine, not to the repository.
  The install would differ from one clone to the next, which ADR-0007 rejected
  for the interpreter name for the same reason.
- **A manifest of installed files.** It would let the installer infer a
  deletion, at the cost ADR-0011 describes, and an inferred intent is a guess:
  a file lost in a bad merge would read as declined.
- **A list the adopter writes.**

## Decision

We will have the installer read `.starter-kit-declined` at the root of the
target: one path per line, relative to the repository root, with an optional
`# reason`. A listed file is not installed, and a listed directory covers
everything beneath it. This holds on a first install, when the list was
written beforehand, and on every later run.

The list is the adopter's. The installer never creates it and never writes to
it, and no first install puts one in place: it states an intent, not a state,
so it cannot go stale the way a manifest does. Each path it keeps out is
reported under "Skipped" as declined.

A file that exists is left alone whether or not it is listed. The list keeps
things out; it removes nothing.

A re-run that installed something says how to decline it, because that is the
moment the reader meets the problem. The first-install message says the same
about a duplicated skill, on Claude Code.

ADR-0011 stands. The installer prints which kit it is — the last release in
the kit's changelog and, from a checkout, the commit — so that the handoff can
record it; it writes that nowhere. A bare copy of `starter-kit/` inside a
project says the version is not recorded, and does not report the project's
own commit as the kit's.

## Consequences

**Easier.** Declining a skill, a suite or a template is one line that survives
every upgrade. The reason sits beside the path, where the next person looks.

**Harder.** One more file a repository may carry, and one more thing the
installer reads. A typo in the list declines nothing; the file it was meant to
keep out appears under "Installed", which is visible but not an error.

**Not prevented.** Declining a file that other installed files depend on. A
rule named by a `Related:` line makes the link gate fail on that line; a gate
script that `registry.mk` runs makes its target fail. Both name the missing
file. Declining `scripts/registry_tool.py` leaves no `registries.json`, and
the installer says so. The list is trusted, not checked.

**Not covered.** The two things the installer does not copy: the registry
block it appends to an existing `.gitattributes`, and `registries.json`, which
`registry_tool.py init` writes.

**Trigger to revisit.** An adopter who declines a file and later wants what a
newer kit made of it has to remember to look. If that is reported, a re-run
lists the declined paths whose kit file changed — which needs the comparison a
manifest would hold, and reopens ADR-0011.

**Related:** ADR-0011, ADR-0007
