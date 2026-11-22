# Feedback to an agent is recorded from day 1, and only listed authors reach the report

## Status

Accepted

## Context

The kit already has the back half of an improvement loop. The `agent-coach`
observes, diagnoses, proposes one minimal edit, waits for a person, applies,
and logs the cycle in the workspace changelog. The guide's flywheel (P6, § 5.1)
turns repeated signals into rules, skills and gates. What the loop has never
had is an input. The coach is told to find "escaped violations" and
"false positives" in git history and pull-request threads, in whatever words
reviewers happened to use. Nothing marks a sentence as feedback to an agent,
nothing says which artifact it is about, and the correction people make most
often, in a chat session, is gone when the session ends.

Warp's account of its self-improving agents ("How Warp builds self-improving
agents on Claude", claude.com, 26 August 2026) describes the missing half:
feedback written where people already work, a script bundled with the improver
that collects it into JSON, and an improver that proposes the smallest edit as
a pull request that a person merges. Its own advice adds three things: low
friction keeps the signal coming, feedback is sometimes wrong, and whose input
counts must be filtered. The article reports no measured result. It is a
pattern, not evidence.

The kit's "nothing speculative" test asks whether waiting for a signal means
waiting for one that never comes. Here it does: a correction that nobody wrote
down cannot be found later, so a project that waits for "enough feedback" to
adopt a channel has no way to see that it has any. The consumer, the coach,
arrives at Level 4. The record has to start before it.

A second force is trust. Text that reaches the report can become part of a
rule or a skill, and those are loaded into every later session. In an open
project anyone can comment on a pull request. Git authorship proves nothing
either: anyone can commit under any email. What a project does control is
which commits reach its default branch and who it lists.

Options weighed:

- **A new registry of feedback fragments** (`feedback.d/`). It has an identifier
  and a review step, but it is one more file per point, outside the review
  the point was made in. That is the friction Warp names as the thing that
  stops the signal.
- **Fetching pull-request comments from the code host.** That is where most
  review happens, but it needs the network and credentials, and the kit runs
  on Bash and the Python standard library only.
- **Trusting every author and leaving the filtering to the merge.** That is
  simpler, but the coach would read a stranger's text in full before any
  person had judged it. A merge is a later safeguard than that.
- **A marked line in the places review already happens, read offline, from
  listed authors only.**

## Decision

We will define one line, `Agent-Feedback: <typed-link token> — <what went
wrong and why>`, written at the start of a line in a commit message or a
comment. The documentation rule, which every tool loads, states it, and tells
the agent to offer the line when a person corrects it.

We will ship `scripts/feedback_tool.py collect` (`make agent-feedback`) on day 1
for all four tools. It reads the messages of the commits a revision reaches,
plus any JSON comment export the project's own tooling produced (`--from`),
resolves each token with the link gate's graph, and prints one JSON report
grouped by artifact. Tokens that name nothing are reported, not guessed.
Quoted and fenced lines are ignored, so a listed reviewer quoting a stranger
does not pass the stranger's words on. It is a report, not a gate.

We will ship `.agent-feedback-authors` naming nobody. Only the identities it
lists count, an email for commits and a login for exports. For every other
line the report gives the author and the target, in a shape that cannot carry
a sentence, and never the text.

The `agent-coach` reads the report in OBSERVE, cites the feedback items behind
each proposal, and lists feedback about artifacts other than agents for the
person to act on.

Deferred, each with its signal:

- **A scheduled improver that opens its own pull request.** It is unlike the
  background repair ADR-0006 rejected, because it only proposes, but it needs
  credentials the kit does not manage. It waits for an adopter whose feedback
  piles up faster than anyone runs the coach. When it comes, it is a new
  record, not an edit to ADR-0006.
- **An improver for skills and rules, on every tool.** It waits for `unresolved`
  and the coach's "other artifacts" list showing that feedback on them is not
  being acted on.
- **Golden cases per skill**, replayed before and after a proposal. They wait
  for a proposal that was merged and made things worse.

## Consequences

**Easier.** A correction lasts once it is a line in a commit message the agent
offered to write. Feedback arrives grouped by artifact and filtered by author,
so the coach starts from evidence instead of a search through history. The
same report works without the coach: a person can read it before editing a
rule.

**Harder.** One more line format to learn, and one more file at the root, empty
until the project fills it. Most review happens in pull-request comments, and
the collector reaches them only through an export the adopter builds. Until
then, only feedback that made it into a commit message is read.

**Not prevented.** A listed author's wrong feedback reaches the report. The
human review of the proposal is still the safeguard against that. The
allowlist decides whose text is read, not whether it is right.
