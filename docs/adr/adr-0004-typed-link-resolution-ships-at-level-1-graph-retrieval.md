# Typed-link resolution ships at Level 1; graph retrieval stays deferred

## Status

Accepted

## Context

The guide has described "agentic graph engineering" since its first version
(§ 5.6): every workspace artifact a node, every typed cross-reference an edge.
It prepared for that by convention — stable identifiers, a typed `Related:`
line, a shape check — and deferred all tooling under the anti-speculation rule
(§ 4.5) until a consumer existed. Two things have since put that deferral in
question.

**The convention checked syntax and left existence open.** `check-kb-shape.sh`
accepts any well-formed token. A knowledge-base entry whose `Related:` line
named a rule, a skill, a script and an entry that did not exist passed the
drift gate, the identifier gate and the shape check. The kit says so itself in
three places — the documentation rule, the conflict-triage skill and guide
§ 3.11 all state that nothing checks whether a citation still resolves — and
this repository has already paid for it once: widening decision-record numbers
from three digits to four left a citation in a released changelog section that
could only be corrected by an erratum. Outside the knowledge base the edges
were not typed at all: a check script named its rule in a sentence ("see the
shared-registries rule file"), and an agent named the rules it reviews nowhere
a tool could read.

**The term now means something else as well.** In current usage "graph
engineering" is orchestration topology: agents, loops, tools and human
checkpoints as nodes, hand-offs and shared state as edges. The kit covers that
only implicitly, as principle P5 and the prose of an agent's description. The
owner's requirement is that graph engineering — both meanings — be native to
every new setup, which conflicts with § 4.5 if taken as "ship the tooling".

ADR-0002 already says when a day-1 default may override the flywheel: the
defect is structural, the cost of retrofitting rises with adoption, and the
expensive failure is silent, so the signal the flywheel waits for never
arrives. That test separates the pieces of a graph layer cleanly. A dangling
link passes all three parts. A missing query passes none: it is a capability
nobody has yet asked for, and its absence corrupts nothing.

Six options were weighed.

- **Leave it to the flywheel.** § 5.1 names the trigger — mis-retrieval, or an
  impact-analysis need. Neither is the failure that matters here. A dangling
  link produces no signal at all, and every link written while nothing
  resolves it adds to a debt that only a full audit can find.
- **Widen the convention, add no resolution.** More token kinds and more link
  lines, still checked for shape only. It costs nothing and makes the silent
  failure larger, because there are more citations to go stale.
- **Ship an index, a query layer and retrieval integration on day 1.** A
  committed index is one more shared file every pull request rewrites — the
  defect ADR-0002 exists to remove. A hook or a tool server that injects graph
  context is tool-specific, which breaks the parity guide § 3.10 promises, and
  it has no consumer: a fresh repository has a dozen nodes and an empty
  knowledge base.
- **Ship an orchestration executor.** Running a hand-off is the agent tool's
  job, and a workflow that is agentic by nature is harmed by being forced down
  a fixed path. Declaring the edges that must not be skipped is enough to
  review and gate them.
- **Resolve citations inside prose as well.** The kit's own rule files cite
  illustrative identifiers (`ISSUE-042`, `ISSUE-178`) that name nothing, so a
  prose resolver would fail on the files it ships. Telling an example from a
  citation is a judgement, and ADR-0003 already draws that line: gate marker
  shapes, not intent.
- **Write the artifact locations into `registries.json` at install time.** It
  makes the layout explicit, and it leaves every repository bootstrapped
  earlier without the block. Defaults that already equal the installed
  locations need no configuration and behave the same in old and new
  repositories.

## Decision

We will make the graph **correct from commit one, and queried only where a
consumer exists**.

**Level 1, every supported tool.** Three typed link lines — `Related:`,
`Enforces:` and `Hands off to:` — over one token grammar that adds
`AGENT:<name>`, `COMMAND:<name>` and `HUMAN` to the existing kinds.
`scripts/graph_tool.py check`, behind `check-graph-links.sh`, resolves every
link on every pull request as a prerequisite of `make lint`. The same file
carries `impact`, because the gate's failure on a rename already *is* an
impact report and the reverse index costs nothing more, and `coverage`,
because `bootstrap.sh` never overwrites a file and so cannot add a subcommand
to a repository later.

**Both meanings, one substrate.** `Related` and `Enforces` are the knowledge
graph. `Hands off to` is the orchestration topology. The topology is declared
and gated, never executed by the kit.

**Level 4, with `--with-meta`.** The `workspace-graph` skill, and the wiring
that makes the agent-coach and the workspace audit read coverage and impact
from the graph instead of grepping for them. Those are the consumers the
queries have today, and that is where they install.

**Deferred, each with its signal** (guide § 5.6): graph-driven retrieval, on
mis-retrieval from a grown corpus; checks on the topology itself, on a
workspace with several agents; resolving citations in prose, on the first
stale one found in review; a stored index or a diagram export, on a slow gate
or a diagram drawn by hand twice.

**Nothing is stored.** The graph is rebuilt from the files on each run. The
tool's defaults are the locations the installer writes to, and a repository
that keeps a kind elsewhere declares it under `graph.nodes` in
`registries.json`.

**One escape, never silent.** An accepted decision record is immutable, so it
cannot follow a rule that is later retired. That pair goes in
`.graph-link-allowlist` with a mandatory reason; the gate reports it on every
run and fails once it is stale.

The guide keeps the term "agentic graph engineering" and now says it covers
both meanings. The mechanism gets a section of its own (§ 3.12), and § 5.6
keeps only what is still deferred.

## Consequences

**Easier.** A citation between artifacts cannot go stale unnoticed. An agent
can ask what cites a rule before it edits one, and gets a list with
`file:line` rather than a grep that misses prose pointers. The health
checklist's question — does every non-negotiable rule have all three
enforcement layers — has a command behind it. Every workflow that stops for a
human says so in a line a reviewer can list. The four tool layouts resolve the
same links, because a token names a file and not a path.

**Harder.** A typed link is a commitment: renaming a rule is now a change to
every file that cites it, in the same pull request. The day-1 install grows by
two scripts and two test files. A repository that copies a kit gate without
the rule it names gets a red build until it installs the rule — intended, as
the "enforcement without rules" anti-pattern made mechanical, but a cost for
piecemeal adoption. Check scripts written to the old header shape
(`# Enforces: <rule> — see <file>`) fail the gate until the header names the
rule as a token; the failure names the token to use.

**A green gate can be over-read.** It resolves typed links only. A citation in
a sentence, a source comment or a test name is as unchecked as before, and an
agent with no `Enforces` line appears in the coverage report as owning
nothing. The graph is exactly as complete as the discipline of writing the
lines, and the tool says so wherever it reports an empty result.

**Accepted against § 4.5, knowingly.** `coverage` ships in a day-1 file while
its regular readers arrive at Level 4. The alternative was a subcommand that
existing repositories could never receive.

**Not solved here.** Repositories bootstrapped before this change do not get
the gate by re-running the installer: it adds the two new scripts but leaves
their existing `registry.mk` and coverage check alone, so the gate is present
and unchained until someone adds `graph-links` to the lint target by hand.
That is the standing limit ADR-0001 records, not a new one, and the changelog
states the manual steps.

**Trigger to revisit.** If adopters report that most link-gate failures are
links to things that legitimately do not exist, the gate is checking the wrong
thing and becomes a report. If any deferred item's signal fires, it gets its
own record rather than an edit to this one.

**Related:** ADR-0002, ADR-0003, ADR-0001
