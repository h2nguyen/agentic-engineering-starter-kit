# The workspace changelog is one file per run

## Status

Accepted

## Context

The kit asks for a record of every run that changes a repository's agent
workspace: a setup or harmonize pass, a workspace audit, an agent-coach cycle.
The setup prompt's Harmonize track tells the installing agent to write one
("create the file if missing"), and `--with-meta` installed a skeleton for
it: a single `WORKSPACE_CHANGELOG.md`, "one entry per audit run or coach
cycle, newest first".

In the first project outside the kit's fixtures, the day of the setup
produced three pull requests that each had something to record. They did not
conflict only because two of them edited existing lines instead of adding an
entry at the top.

A file every run inserts into at one anchor is what the shared-registries
rule defines as the problem and tells adopters to remove: many pull requests,
a fixed anchor. The kit prescribed for its own record the shape it forbids
for a changelog. The record has no allocated identifier, so the worse half of
that defect — a duplicate identifier that merges cleanly — cannot happen
here; the conflict can.

Four shapes were weighed.

- **Keep the file and say "one entry per run, not per pull request".** That
  is what happened by accident, and two pull requests amending the same entry
  still meet on the same lines. The same holds for a file per run that later
  pull requests of the run edit: a first draft of this decision said so, and
  a review merged two such branches into a conflict.
- **`merge=union` on the file.** It needs a drift gate to be safe
  (`.gitattributes` says why), and there is nothing to regenerate this file
  from.
- **A declared registry with a generated artifact**, like the changelog. It
  brings an identifier scheme, a gate and a generator to a record that is
  written a few times a month and cited by nobody; and the Harmonize track
  writes its first entry before the meta layer is installed.
- **One file per run in a directory.**

## Decision

We will keep the workspace changelog as a directory with one file per run:
`.claude/workspace-changelog/` on Claude Code, `docs/workspace-changelog/` on
the other tools, files named `<YYYY-MM-DD>-<what>.md`. The dated files,
sorted, are the history. A file is written once, by the pull request that
adds it: a later pull request of the same run adds a file of its own, and
`<what>` is chosen so that no other branch would pick it — a bare
`coach-cycle` is a name two branches share.

`--with-meta` installs the directory's `README.md`, which states the naming,
the reason, and the entry format; the format gains a `Kit:` field for the
installer's version line. The single-file template is no longer shipped. The
directory is not a declared registry: it has no identifiers, no generated
artifact and no gate.

The audit skill, its command, the agent-coach, the setup prompt and the guide
write to and read from the directory.

A repository that has a single `WORKSPACE_CHANGELOG.md` keeps it. The
installer never overwrites or removes a file; the skill and the coach read it
as the archive and write nothing new into it.

## Consequences

**Easier.** Two runs recorded on two branches merge without a conflict; the
installer suite holds that, with the old shape as its control, and holds as a
second control that two edits of one entry do conflict. The record of
a setup can note which kit it came from.

**Harder.** The history is a directory listing instead of one page. Reading
"the last audit" means opening the newest file, and a repository in the
middle of the change has two places to look, which the README and the skill
both say.

**Existing installs.** Nothing is migrated and nothing fails. An install with
the meta layer picks up the directory at its next installer run and the new
wording when it copies the kit's skill and coach (upgrade step 2); until then
its skill keeps writing to the single file, as before.

**Not done.** No tool creates the entry file or checks that its name is
unused on other branches; the format is a block to copy and the naming is a
convention. A `new` command would mean declaring a registry, which was
weighed above. A repository that already keeps a workspace changelog of its
own keeps writing to it: the setup prompt records there and proposes this
layout, since an existing convention that works beats the kit's default.

**Trigger to revisit.** If entries start being cited from rules or decision
records, they need stable identifiers, and the directory becomes a declared
registry of the `documents` kind.

**Related:** ADR-0002, RULE:shared-registries, SKILL:ai-engineering-workspace-audit, AGENT:agent-coach
