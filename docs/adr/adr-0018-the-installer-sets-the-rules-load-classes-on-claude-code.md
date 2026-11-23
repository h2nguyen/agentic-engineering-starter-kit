# The installer sets the rules' load classes on Claude Code

## Status

Accepted

## Context

Claude Code loads every file in `.claude/rules/` into every session unless
the file opens with a `paths:` header; with one, the rule is loaded when a
file matching a pattern is read, written or edited. The kit knew this — its
audit skill budgets "rules without path scoping" as always-loaded — and
shipped all five rules without a header. The guide's load-class table listed
"rules files" as always loaded, without qualification.

A fresh install therefore loaded 788 lines of rules at every session start.
In the first project outside the kit's fixtures, whose work is mostly concept
documents, about 540 of them — registries, versioning, annotations in source —
were relevant to almost no session, while the project's own rules were bound
to paths: the generic loaded always, the specific on demand. The adopter
added headers to three rules by hand and brought the always-loaded set from
887 lines to 351, with lint green.

What decides where the header can come from:

- **The header can only be in the file.** Claude Code documents no other
  place to assign paths. A rule with a header is no longer the kit's file
  byte for byte.
- **The kit's rule files are one text for four tools.** Elsewhere a rule is
  read when the constitution links to it; a YAML block at its top is noise
  there.
- **The paths are not the kit's to know.** The registry paths differ per
  repository — `init` writes `registries.json` from what the repository
  already has — and the source paths are the project's.
- **A header that cannot be parsed fails without a message**: the rule loads
  as if it had none. And a session that is already running keeps the rules it
  started with; the adopter saw a subagent of the session that changed a rule
  still working from the old set.

Options for the header:

- **Ship it in the kit's rule files.** Wrong for three tools, and wrong paths
  for every repository whose registries are not where a fresh install puts
  them.
- **A stub rule that carries the header and imports the kit's text from
  elsewhere.** Whether an import inside a rule file is followed when the rule
  triggers is not documented, and it would move every rule in every install.
- **Document it and let the adopter write it.** That is what happened; the
  default stayed wrong for everyone who did not.
- **The installer writes it**, for the rules it installs in that run.

And for the source paths:

- **Infer them** from the tracked files. A guess that decides when a rule is
  in context, in a repository the installer sees for a few seconds.
- **Ask.** Run by an agent, the installer has nobody to ask.
- **A flag**, and no binding without it.

## Decision

On Claude Code the installer writes a `paths:` header onto rules it installs
in that run. It never touches a rule that was already there.

- **`shared-registries`** is always bound: to every fragment directory and
  artifact `registries.json` declares, and to `registries.json`,
  `registry.mk`, `.gitattributes` and `.registry-id-duplicate-allowlist`.
- **`versioning-and-changelog`** and **`comments-and-annotations`** are bound
  only when `--source-paths` names the project's source globs: the first to
  those and the changelog's files, the second to those and `.github/**`,
  `.claude/hooks/**`, `Makefile`, `registry.mk`. Without the flag both load
  into every session, and the installer says so and how to bind them.
- **`working-principles`, `documentation` and `project-annotations`** load
  into every session.

A glob that cannot be written between double quotes is refused before
anything is installed. The kit's rule files stay without a header, and the
other three tools get none; `--source-paths` is reported as ignored there.

The header is the adopter's from then on. So the upgrade compares and
replaces the **text under it**: `starter-kit/upgrade-rules.sh`, which stays in
the kit like the installer, lists each rule as `same`, `differs` or `missing`
and takes the kit's text for the rules named to it, keeping the header. It
replaces `diff -rq` and `cp` in upgrade step 3.

The constitution keeps one line for every rule. A bound rule arrives after
the first matching access, and that line is what holds before it; the
installer suite asserts the line exists for each rule it binds.

**The check ships with the mechanism**, as the skill `rule-load-check`,
installed on day 1 on Claude Code. It runs in a new session: it lists the
rules in context before anything is read, reads one file per load class,
says what arrived, and quotes the last line of each rule it claims — a quote
that is then compared with the file. It is a day-1 artifact because the
failure it finds is silent: a header that does not parse, a pattern that
matches nothing, and a session judging rules it never reloaded all look like
a working install (ADR-0002's argument, and ADR-0004's).

## Consequences

**Easier.** A fresh install with `--source-paths` loads the constitution and
three rules into every session instead of five and a constitution; without
the flag, four. An upgrade no longer special-cases a rule for its header.

**Harder.** The installed rule differs from the kit's by its header, so
"is this the kit's text" needs the helper and a checkout of the kit. One more
flag, one more skill, one more script in the kit.

**The comments rule is narrower in context than in scope.** It applies to
documents and prompts as well as source; bound to source paths, its full text
is absent from a session that touches only documents, and the constitution's
line stands in. That is the adopter's choice, which is why it takes a flag,
and the README says to bind it to prose paths too where prose is the work.

**Not verified here.** Claude Code documents Read, Write and Edit as triggers
and does not say whether creating a new file under a pattern loads the rule
first; the check uses Read and says so. Nothing in `make lint` knows what a
session loaded — the kit runs no agent — so the check is a skill someone has
to run, and its evidence is the agent's own quotes.

**Existing installs are not changed.** Their rules load as before. The README
shows the header to add by hand.

**Trigger to revisit.** If the tool gains a documented way to assign paths
outside the file, the header leaves the rule and `upgrade-rules.sh` goes back
to being `cp`. If adopters keep installing without `--source-paths`, the
installer's closing message is not enough and the setup prompt asks for the
paths outright.

**Related:** ADR-0005, ADR-0002, ADR-0004, ADR-0011, ADR-0017, SKILL:rule-load-check, RULE:shared-registries
