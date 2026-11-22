# The SessionStart skeleton ships as a template and is not registered

## Status

Accepted

## Context

On Claude Code the installer put `hooks/session-start.sh.template` in place as
`.claude/hooks/session-start.sh` and registered it in `settings.json`. The
file is a skeleton: its three toolchain steps are comments. What it did in
every session was append the current `PATH` to `$CLAUDE_ENV_FILE` and print
"session-start: toolchain ready".

Three things are wrong with that as a default.

- **It reports a state it did not check.** Claude Code adds what a
  SessionStart hook prints to the session's context. An agent then starts
  with the sentence "toolchain ready" in front of it, from a script that
  verified no toolchain.
- **It is a day-1 artifact with no day-1 reason.** The guide names the signal
  for this hook — sessions that keep fighting their environment (§ 4.3) — and
  lists hooks among the things the handoff defers. No decision record argued
  that this one cannot wait for its signal, which is what the kit asks of
  every day-1 default (ADR-0002, ADR-0004). The setup prompt already told the
  installing agent it could remove the entry.
- **It was removed in the first install outside the kit's own fixtures**, by
  an adopter who then got the file back from the next installer run.

The skeleton itself is useful: the reasons a hook is needed, the two design
rules, and the append-once idiom are what a later session needs when the
signal does arrive. ADR-0005 put the kit's other skeletons where such a
session finds them and nothing loads them.

Three options were weighed.

- **Keep it registered and make it silent.** A hook that does nothing, runs in
  every session, and has to be read to learn that it does nothing.
- **An installer flag** to install and register it. It makes a choice at
  install time that belongs to the day the signal arrives, and a flag is not
  where a later session looks.
- **Ship it as a template.**

## Decision

We will install the skeleton as `docs/agent-templates/session-start.sh.template`
on Claude Code, beside the other templates, and register no SessionStart hook.
`settings.json.template` registers the workspace-graph hook only.

The template's header says when to use it, how to put it in place, and which
entry to add to `settings.json`. It prints nothing as shipped, and a third
design rule joins the two it had: print a state only after the step that
checked it.

## Consequences

**Easier.** A fresh install runs no hook that does nothing, and nothing claims
a checked toolchain. The skeleton is still one copy away.

**Harder.** A project that needs the hook on day 1 has two more steps than
before: copy the file and add the entry. The template spells both out.

**Existing installs are not changed.** The installer never overwrites a file,
so a repository that has the hook and its entry keeps both; they are the
adopter's to fill in, keep or remove. The upgrade steps say so. A re-run adds
the template to `docs/agent-templates/` and touches neither.

**Trigger to revisit.** If adopters regularly need environment setup from the
first session and miss the template, the installer's closing message names it;
the hook does not return as a default.

**Related:** ADR-0005, ADR-0002, ADR-0014
