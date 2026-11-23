# The project's half of the comments rule is a file of its own

## Status

Accepted

## Context

Four of the five rules the kit ships are used as shipped. The fifth,
comments-and-annotations, carried a part the adopter fills in: the second half
of its protected-shapes table, and four pointers — `<DECISION-RECORD-ID>`,
`<KB-ENTRY-ID>`, `<TICKET-ID>`, `<tool-or-gate>` — to resolve in the rule and
again in its reference file. ADR-0005 kept "the tables an adopter fills in"
inside the rule when it moved the examples out.

The first install outside the kit's fixtures showed what that costs.

- **The rule stops being the kit's.** A filled-in file differs from the kit's
  from the day of the install — 21 lines in that project. The upgrade steps
  had a special case for it, "merged, never copied", and every later fix to
  the rule reaches such a project only by a hand merge.
- **Nothing reads the part that was filled in.** ADR-0009 gave the
  constitution a placeholder check and excluded rule files from it, because
  their angle-bracket shapes are content. So a pointer left unresolved in a
  rule that is loaded into every session was found by no gate.
- **The rule named a file no install has.** Two sentences pointed at
  `testing.md`, an example from the constitution template.

The same install showed a second assumption built into a rule. The project
already kept a decision register, in a form `registry_tool.py init` cannot
detect, and removed the `adr` registry from `registries.json`. The
documentation rule still said "One file per decision under `docs/adr/`" and
gave a command that then fails; the constitution had to state that a section
of an installed rule does not apply.

For the fill-in, three shapes were weighed.

- **Leave it and extend the placeholder check to the rule.** The check would
  have to tell `<DECISION-RECORD-ID>` left unresolved from the same token in
  an example that is meant to stay, and the rule would still differ from the
  kit's.
- **Put the project's rows into the constitution.** It is the project's file
  and it is checked. It is also the one file under a 200-line budget, and a
  table of marker shapes is rule detail.
- **A file of the project's, beside the rule.**

For the decision records, two.

- **Split the ADR section into a rule of its own, installed only when an
  `adr` registry is declared.** The installer decides once; a registry is
  added or removed later, and the rule would be present or absent by the
  history of the install rather than by what the repository declares. It is
  also one more file and one more index line for every install.
- **State the condition in the rule.**

## Decision

**The project's half is `project-annotations.md`**, in the rules directory of
each tool. It holds what the rule's pointers stand for in this project and
the marker shapes the project's own tooling reads. The installer leaves it as
a template together with the rule that names it; it is the project's from
then on, and no upgrade step replaces it.

The comments-and-annotations rule and its reference are used as shipped. Their
pointers stay, as notation that `project-annotations.md` resolves. The rule's
second table stays as the kinds of shape a project adds, and says where the
project's own are listed. The two mentions of `testing.md` name "the project's
testing rule, where it has one".

`make constitution` reads `project-annotations.md` together with the
constitution. This supersedes one sentence of ADR-0009 — "It never reads a
rule file or a rule reference" — for this one file, and for the reason that
sentence gives: the file starts as a template with `<fill in: …>`
placeholders in prose, and names the pointers in backticks. The rules the kit
ships and the rule references are still not read. This also supersedes the
part of ADR-0005 that keeps the adopter's tables inside the rule.

**Where the comments rule was already in the repository, a run of the
installer does not add the template.** That rule may have the adopter's rows
in it, and an unfilled file beside them would be loaded into every session
and would fail a `constitution` check the adopter chained into their lint.
Upgrade step 3 creates the file as part of moving the rows, with a command
that does nothing where the file exists. The test is the rule, not the kit:
a repository that has had the kit since before the rule existed, or has it in
another tool's layout, gets the rule and its project half in the same run —
keyed on "the kit is installed", a first review found three such shapes left
with a rule pointing at a file that was not there.

**The move is the adopter's choice.** A filled-in rule keeps working and can
be merged by hand at every upgrade, as before; the line for the new file in
the constitution's index is theirs to add or leave. Nothing in the upgrade
makes an adopter edit a file of their own, which is what would make this a
MAJOR change under ADR-0008.

**The documentation rule's ADR section applies where `registries.json`
declares an `adr` registry**, and says so in its first paragraph: with none
declared, the constitution says where decisions are recorded and the rest of
the section does not apply. `init` still declares the registry when it finds
no decision records — decision records remain a day-1 default (ADR-0002) —
and its note says what to do when they live elsewhere. Asking the tool for a
registry that is not declared says that, instead of "unknown registry".

## Consequences

**Easier.** All five rules are copied on upgrade. A forgotten pointer has a
check that reports it, and the check is the one onboarding already runs. A
project that records decisions elsewhere removes one registry and writes one
sentence; no rule needs overruling.

**Harder.** One more file on a first install, in the always-loaded set on
Claude Code — about thirty lines when filled in. An adopter on an older kit
who wants the rule copied from now on has a one-time move to make, by hand;
the upgrade steps describe it, and `test-upgrade.sh` runs the README's own
command for it, twice — the second time on the filled-in file. Until they
make it, their filled-in rule keeps working and keeps being a hand merge.

**Not checked.** That `project-annotations.md` is true: a pointer filled with
a shape the project does not use passes. And nothing links the rule to the
file by a typed link — in the kit's own repository the template is not an
artifact the link gate can resolve — so the rule names it in prose.

**Trigger to revisit.** A second rule that needs a project half: the file
then becomes the pattern, and its name the wrong one.

**Related:** ADR-0005, ADR-0009, ADR-0002, SCRIPT:check-constitution.sh, RULE:comments-and-annotations, RULE:documentation
