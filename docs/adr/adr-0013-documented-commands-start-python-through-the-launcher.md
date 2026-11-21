# Documented commands start Python through the launcher too

## Status

Accepted

## Context

ADR-0007 put everything the kit runs behind `scripts/python.sh` and drew a
line at the commands a person or an agent types: the rules, the constitution
and the READMEs kept writing `python3 scripts/…`, "because that is what most
readers will type", and were to say once that the launcher stands in for it.
Its trigger to revisit was a reader on Windows failing on the documented form.

The first install into a project that was not the kit's own test fixture
showed the line in a different light. It went through the Harmonize track,
into a repository that already had a `CLAUDE.md`.

- **The sentence that says it once did not arrive.** It sits in the
  constitution template and in the kit's README. The installer never
  overwrites a constitution, and the README stays in the kit. In such an
  install no installed Markdown file mentions `python.sh` at all, while
  fourteen places in the installed rules, skills, READMEs and registry
  preambles say `python3 scripts/…`.
- **The reader is an agent.** It types what the page says. A person adapts a
  command to their machine; an agent that reads `python3` in a rule and
  `scripts/python.sh` in the Makefile has two conventions and no reason to
  prefer the one the kit means.
- **The kit reads as inconsistent with itself.** The hook's own header says
  it is "never" started "as `python3 …`"; the skill installed next to it
  starts the same tools that way. The adopter reported it as a defect.

Three ways to close it were weighed.

- **Move the sentence into a rule**, so every install receives it. It keeps
  two forms of every command and one sentence to reconcile them, in a file
  that is loaded into every session to say something a command could say by
  being written correctly.
- **Leave it, and wait for ADR-0007's trigger.** The trigger asks for a
  Windows reader. The finding is that the mitigation is missing on every
  machine, in the installs most likely to belong to an existing team.
- **Write the documented commands the way the kit runs them.**

## Decision

We will write every command the kit gives a reader to type through the
launcher — `./scripts/python.sh scripts/<tool> …` in a file the installer
ships, `starter-kit/scripts/python.sh starter-kit/scripts/<tool> …` in this
repository's own instructions — or as the make target that runs it, where one
exists.

This supersedes one paragraph of ADR-0007's decision, the one that begins
"Commands a person or an agent types are a different matter", and its "Not
done" note about the typed commands. The rest of ADR-0007 stands: the
launcher, its probe, `PYTHON`, and the fallback in a gate that finds no
launcher beside it.

A repository-only gate, `scripts/check-documented-commands.sh` (target
`documented-commands`, chained into this repository's `lint`), fails on
`python3`, optional flags and a path under `scripts/` in any tracked file. It
does not read decision records and released changelog sections, which are
immutable; changelog fragments, which may quote the old form; the test
suites, whose fixtures model older installs; and the bundled semver skill,
which has an upstream of its own and keeps the names it came with.

The constitution template keeps one sentence, now a statement and not an
instruction to translate: the launcher finds Python under whatever name the
machine gives it, and a command added to the constitution is written that way
too.

## Consequences

**Easier.** One form of every command, in what the kit runs and in what it
says. An install that kept its own constitution loses nothing, because
nothing depends on a sentence it never received. A contributor who writes
`python3 scripts/…` in a rule is told by a gate, with the line.

**Harder.** The commands are longer, and `./scripts/python.sh` in front of a
script is less familiar than `python3`. A reader in a directory other than
the repository root has to adjust the path, as they did before.

**Existing installs** keep the old form until they take the newer files:
the rules and skills arrive through upgrade steps 2 and 3. The READMEs inside
`changelog.d/` and the knowledge-base fragment directory, and the hand-written
preamble of `CHANGELOG.md` and of the knowledge base, are the adopter's after
the install and are compared by hand; upgrade step 4 now names them. Nothing
fails in a repository that does not: `python3 scripts/…` still runs wherever
it ran before.

**Not covered.** The gate reads this repository. It does not read a rule an
adopter writes, and the kit installs no such gate: whether a project's own
documentation names an interpreter is the project's decision.

**Trigger to revisit.** A make target for every documented command would
make the launcher invisible to the reader; that is worth doing if the long
form turns out to be mistyped, and not before.

**Related:** ADR-0007, SCRIPT:check-documented-commands.sh, SCRIPT:python.sh
