# Templates and rule references install on day 1, outside every load path

## Status

Accepted

## Context

Two kinds of file used to stay behind in the kit when it was installed.

**The templates** for a new rule, check script, skill, reviewer agent and
command. The installer's closing message said so: they "stay in the kit for
later", in keeping with grow-by-signal (guide § 4.5).

**The illustrations inside two rule files.** The comments-and-annotations rule
carried its worked examples and anti-pattern gallery, and the shared-registries
rule its eight gotcha write-ups, inline — 408 and 260 lines in files that
Claude Code loads into every session, against the kit's own budget of about
200 for an always-loaded file.

Applying the kit to a sample project with a small model, one task per fresh
session, showed what each costs.

A later session never sees the kit. Asked to add a rule and an enforcing
check, then a skill and a reviewer, the agents rebuilt each from the installed
examples, and each dropped something its template carries: one rule had no
litmus test and no link to the incident behind it, another no WRONG/CORRECT
pair, and the reviewer had no model tier and none of the cross-cutting checks
— which ADR-0003 names as the enforcement layer of the comments rule. The
signal the flywheel waits for does arrive here, but it arrives in a session
that cannot reach the thing it signals a need for.

The long rules were not read. One agent reported that it did not get through
either of them, and the kit's own audit skill flagged both in the first
repository it was run on. A budget the kit states and breaks in its own
defaults is the "rules without enforcement" anti-pattern the guide names.

Four options were weighed for the templates.

- **Leave them in the kit and say where it is.** A pointer to a directory the
  repository does not contain, which is the situation that failed.
- **Put the essentials in the documentation rule's table only.** That table
  now says what each artifact must carry, and it is always loaded. It cannot
  carry the reviewer template's cross-cutting checks without becoming them.
- **Install them into the tool's own directories.** `.claude/rules/` is loaded
  into every session, and a file in `.claude/skills/` is registered as a
  skill; a template there costs context or misfires.
- **Install them where nothing loads them.**

And three for the rules.

- **Raise the budget** to fit the files. The budget exists because every line
  is paid for in every session; the files are what is wrong.
- **Split each rule in two.** The total loaded stays the same, and a rule cut
  below a coherent topic is the fragmentation the audit skill warns against.
- **Move the illustrations and keep the rule.**

## Decision

We will install both kinds of file on day 1, for every tool, in locations no
tool loads by default.

**Templates** go to `docs/agent-templates/`. Each name begins with an
underscore or ends in `.template`, which is what tells the link gate they are
scaffolding and their placeholders are not citations. The documentation rule's
"what to update when" table says which to start from and what the result must
carry.

**Rule references** go to `docs/rule-reference/`. A rule keeps its imperative,
its litmus tests and the tables an adopter fills in, and names the reference
for the rest. The move is verbatim: no line is summarised away.

A repository-only gate holds every rule file the kit ships under a 250-line
ceiling. The target stays about 200; a number with a tilde cannot be gated, so
the gate sits above it.

## Consequences

**Easier.** A session that has never seen the kit can start a rule, a check or
a reviewer from the file that carries the required parts. The day-1
always-loaded set is 237 lines shorter. A rule that outgrows its budget fails
this repository's build instead of an adopter's audit.

**Harder.** The day-1 install is seven files larger, none of them loaded. The
comments rule's project pointers now appear in two files, and the adoption
note says so. An adopter who edits a rule and its reference separately can let
them drift; nothing checks that the reference still illustrates the rule.

**Accepted against § 4.5, knowingly.** These are day-1 artifacts with no
day-1 consumer. They cost nothing until read, and the alternative was tested:
the consumer arrives in a session that has no way to fetch them.

**Not done.** The comments rule still sits above its target, at 242 lines. What
remains is the rule itself; cutting further would split a coherent topic, and
the audit skill now says the anti-fragmentation guard wins that argument.

**Trigger to revisit.** If adopters' audits keep proposing to delete the
installed templates as unused, they become a `--with-templates` opt-in. If a
shipped rule reaches the ceiling again, its next illustration moves out before
the ceiling is raised.

**Related:** ADR-0003, ADR-0004
