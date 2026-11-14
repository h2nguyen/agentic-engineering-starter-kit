# The workspace graph reaches the agent through a hook

## Status

Accepted

## Context

ADR-0004 made typed-link resolution a day-1 gate and shipped two queries over
the resolved graph. Both queries are things somebody runs. The convention that
connects them to daily work is one sentence in the documentation rule: before
renaming, deleting or rewriting an artifact, ask what cites it. Nothing stands
behind that sentence at the moment of the edit.

Two things observed while applying the kit with a small model put it in
question.

**The agent did not ask.** With the rule loaded, an agent asked to rename a
rule renamed it, met the link gate, and silenced the gate with an allowlist
entry. The rule was reworded, and later runs did ask — in four real sessions
that renamed a cited script, the agent updated the citing entry every time.
That is a convention working. It is still a convention, and it worked once the
agent thought of it.

**The gate cannot see a rewrite.** Changing what a rule requires without
renaming it leaves every link resolving. The script that enforces the rule and
the reviewer that holds it now enforce something the rule no longer says, and
the drift gate, the identifier gate and the link gate all pass. The link gate
answers "does this name something"; nothing answered "who depends on what I
just changed".

The kit's maintainer also asked for the technique to act without being
invoked: an agent that is handed the graph, not one that must remember to
consult it.

Five ways to do that were weighed.

- **Leave it to the rule.** No new artifact. It depends on recall, and the
  rewrite case stays invisible.
- **A hook in the agent tool, after an edit and at the end of a turn.** The
  tool runs it; the agent does nothing. It exists on Claude Code, in a
  documented and stable form. Cursor and Copilot have hook mechanisms whose
  current formats were not verified.
- **A git pre-commit hook.** Tool-neutral, but it needs `core.hooksPath` or a
  file in `.git/hooks` per clone, and the kit promises an install with no
  per-clone configuration. It also fires at commit, after the edit is over.
- **Retrieval at prompt time** — matching the prompt against knowledge-base
  entries and loading the hits. This is the retrieval ADR-0004 deferred. It
  adds context to every prompt, and nothing here measured whether the hits
  would help.
- **A scheduled agent that repairs the workspace in the background.** It
  changes rules with nobody watching, which is what the coach and the audit
  are built not to do, and it needs credentials the kit does not manage.

On whether a hook is a day-1 default, ADR-0002's three-part test gives two
parts of three. The defect is structural: a convention with nothing behind it
when it matters. The failure is silent: the rewrite case turns nothing red.
The third part — retrofit cost that rises — does not hold: adding a hook later
costs the same in a large repository as in a small one. What does hold is that
the retrofit is never automatic. `settings.json` is installed once and never
overwritten, so every repository that gets the hook later registers it by
hand.

## Decision

We will hand the graph to the agent at the two moments it matters, and
nowhere else.

**A tool-neutral query, for every tool.** `graph_tool.py note <path>…` prints
what the editor of a file should be told: who cites it, and any link in it
that resolves to nothing. For a file that is neither, it prints nothing. It
never fails.

**A hook for Claude Code, on by default in a fresh install.**
`.claude/hooks/workspace-graph.py`, registered in `settings.json` for two
events:

- after `Edit` or `Write`, it calls `note` for the edited file and adds the
  result to the agent's context;
- when the agent ends its turn, it runs the link check and, if a link no
  longer resolves, holds the turn once and hands the failure back.

The hook is context, not a gate, and four rules keep it that way. It is silent
unless it has something to say. It says each distinct thing once per session.
It ends silent with exit 0 whenever it cannot do its job, and always lets go a
turn that a stop hook already continued. It never changes a file.

It reads the checkout the edited file is in, not `$CLAUDE_PROJECT_DIR`, which
in a worktree names the main checkout. Its per-session marks live in the
temporary directory, never in the repository.

**Not shipped.** A hook for the other tools, until their formats are verified;
`note` is what such a hook would call. Retrieval at prompt time stays deferred,
as ADR-0004 left it. Nothing in the kit changes a rule without approval.

## Consequences

**Easier.** An agent that edits a cited rule is told which script and which
reviewer hold it, at the edit. A rename done through the shell is caught
before the turn ends instead of in CI.

**Harder.** A fresh Claude Code install has one more file and two more hook
entries. Every edit starts a Python process, about a tenth of a second. A link
that was already broken when the session started holds one turn in that
session, though the agent did not break it. A hook that fails says nothing, by
design; `WORKSPACE_GRAPH_HOOK_DEBUG=1` makes it say why.

**What was observed, and what was not.** In real Claude Code sessions with a
small model, the note arrived as added context after an edit to a cited
script, and a turn that ended on a broken link was held once, after which the
agent reported the break to the user instead of finishing. In the four rename
sessions — two with the hook, two without — the agent repaired the citing
entry by itself each time, so the hook had nothing to say and no difference
was measured. Its value is shown for the case it forces, not yet for the
average case. Not exercised: an edit under `.claude/` in a non-interactive
session, which the tool refuses whatever the hook does; interactive sessions;
subagents.

**Accepted with two parts of the test, knowingly.** The argument for day 1 is
the silent rewrite and the manual retrofit, not a cost that grows.

**Trigger to revisit.** If adopters report the notes as noise or a held turn
as an obstacle, the hook moves behind an installer flag. If sessions show the
note delivered and the citers left stale, the wording changes or the note
moves before the edit. When another tool's hook format is verified, it gets a
hook that calls `note`.

**Related:** ADR-0004, ADR-0002
