# This repository applies the agent side of the kit to itself, by reference

## Status

Accepted

**Related:** ADR-0001, ADR-0012, ADR-0018

## Context

The kit has two halves. The gates, registries and typed links are plain files
and plain CI. The rules, skills, reviewer agent and hook are what an agent
working in a repository is given.

This repository applied the first half to itself from the start: `make lint`
runs the kit's own gates on the kit's own files, without copies. It never
applied the second half. An agent working here read `AGENTS.md` and nothing
else. It loaded none of the five rules the kit ships, had none of its skills,
and no hook told it what cites the file it had just edited. The method was
installed into every repository but the one that wrote it, so nothing here
showed whether the agent side works in daily use.

The installer refuses to install into this repository, deliberately: an
install is a set of copies, and two copies of one file drift (the Makefile's
header says so, citing guide § 5.4). Whatever applies the agent side here has
to do it without copies.

Options weighed:

- **Run the installer here after all**, and gate the copies against the kit.
  It is the most literal dogfooding, but it puts a second copy of every script
  and rule into the repository that ships them, and every kit change becomes
  two edits.
- **Import the rules from `CLAUDE.md`** with `@starter-kit/rules/…`. No copies,
  but it covers rules only, on one tool, and says nothing of skills, the agent
  or the hook.
- **Symbolic links under `.claude/`.** Claude Code reads rules, skills, agents
  and commands from there and follows links. Git stores a link as its target
  path, so there is one file and nothing to drift.
- **State it in prose and leave it.** That is the state this record ends.

Two things stood in the way of links. The hook runs `scripts/graph_tool.py`,
and here the tool is under `starter-kit/scripts/`, so the hook would have
stayed silent. And an installed rule names installed paths (`scripts/…`,
`docs/agent-templates/…`) that are elsewhere in this repository.

## Decision

We will apply the agent side of the kit to this repository by reference.

- Every rule, skill, agent and command the kit ships has a symbolic link of
  the same name under `.claude/`, pointing into `starter-kit/`. Templates,
  whose names begin with an underscore, are not linked.
- `.claude/settings.json` registers the workspace-graph hook from
  `starter-kit/hooks/`, through the kit's launcher. The hook gains `--tool
  <path>`, a path relative to the checkout that must stay inside it, so a
  project that keeps the graph tool elsewhere can name it. ADR-0012 holds: the
  hook still runs only the project's own file.
- What only the project can say is a file of its own:
  `.claude/rules/project-annotations.md`, and `.claude/workspace-changelog/`
  with one file per run.
- `AGENTS.md` lists the rules for tools that read no `.claude/`, and carries
  the one table that maps an installed path a rule names to where that thing
  is here.
- `scripts/check-self-application.sh`, chained into `make lint`, fails when a
  shipped artifact has no link, when a link has become a copy or points
  elsewhere, and when the hook is not registered with `--tool`. It reads the
  git index, where a link is a link on every platform.

Not applied, and why:

- **Load classes** (ADR-0018). The installer binds a rule to paths by writing
  a header into its copy. A link has no copy to write into, so all five rules
  load into every session here. The cost is counted in `docs/EVIDENCE.md`.
- **A debugging knowledge base.** Unchanged: a registry is declared when it
  exists.

## Consequences

**Easier.** A change to a rule is tried on the people and agents who wrote it
before it reaches an adopter. A rule that is wrong or too long is felt here
first. The feedback loop has something real to work on: an `Agent-Feedback:`
line about a rule now names a rule that was loaded when the mistake was made.

**Harder.** Every session here pays for all five rules, about 850 lines. A
checkout on a platform without symbolic links holds small text files in their
place: the gate still passes, because the index is right, but an agent tool on
that machine loads nothing useful from them. Adding a rule, skill, agent or
command to the kit is now one more step, the link, and the gate names it.

**Not shown by this.** That the links are there says the artifacts are
offered to the agent. Whether a session loads them is seen only in a new
session, with the `rule-load-check` skill; the session that adds a link cannot
see it take effect.
