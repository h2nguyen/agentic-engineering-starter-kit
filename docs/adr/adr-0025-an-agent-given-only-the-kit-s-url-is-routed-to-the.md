# An agent given only the kit's URL is routed to the installer, which stops at an existing workspace

## Status

Accepted. Released as 4.0.0: the stop can fail a command that worked on
3.1.0 (ADR-0008).

**Related:** ADR-0001, ADR-0008, ADR-0009, ADR-0024

## Context

The kit documents three ways in: paste `SETUP-PROMPT.md`, run `bootstrap.sh`
from a checkout, or copy by hand. The way most adopters actually take is
none of these. They open a session in their own project and write one line,
"apply this kit to my project", with the repository's URL. `AGENTS.md` was
written for a session started in a checkout of the kit, and the setup prompt
looked for the kit only inside the target.

What such an agent can reach is not under the kit's control. No agent tool
loads the `AGENTS.md` of a repository it was only given the URL of. A fetched
page may reach the agent as a model's summary rather than its text. Several
sandboxes block `git clone` by default.

Two recorded runs of Claude Code (2.1.330, headless `claude -p`, default
permission mode, one run each) got only that one-line prompt. Both cloned the
kit outside the project, ran the installer and ended with `make constitution`
and `make lint` green. Neither read `AGENTS.md`. Neither asked which tool, whose
feedback counts or which opt-ins to install. In the target that already had a
`CLAUDE.md`, the agent rewrote that file without approval, against the
Harmonize track. Reproduced by hand, three gaps no gate saw:

- **A clone inside the target.** An agent that clones where it stands clones
  into the project. Everything installs and lints green, and `git add -A`
  commits the clone as an embedded repository nobody else can check out.
- **An existing workspace.** The installer kept every existing file and went
  on: the kit's constitution was not installed and nothing was reconciled.
  On `agents`, `cursor` and `copilot` a rule is read because the constitution
  links it, and the project's own constitution linked none of the kit's. Once
  `project-annotations.md` was filled in, `make constitution` was green.
- **The setup prompt.** Pasted into a project without the kit, it built
  everything by hand from its appendix and never reached the installer.

Options weighed:

- **Keep requiring the pasted prompt.** Nothing changes, and most adopters
  keep taking the path that is not covered.
- **A note at the top of the README and one source for both paths.** Cheap,
  and short enough to survive a summary. Still advice the agent can ignore.
- **Guards in the installer.** The agent reads the installer's output for
  certain, because it ran the installer. Stopping at an existing workspace
  changes what a command that worked on 3.1.0 does.
- **An agent plugin.** Covers one tool. It does not install files into the
  project, so the installer still has to run. ADR-0001 keeps it for later.
- **`llms.txt`**, or **`curl … | bash`**. No tool reads the first from a
  repository. The second needs the network, which the kit does not use, and
  runs a remote script unread.

## Decision

We will route an agent that arrives with only the URL to the same installer
and the same steps as every other path. The installer will catch what the
agent gets wrong anyway.

- The README opens with a note for agents: clone the kit outside the
  project, then follow `AGENTS.md` in that clone; without network, fetch
  `SETUP-PROMPT.md` raw. `AGENTS.md` says how to get the kit before its first
  step. `SETUP-PROMPT.md` clones the kit before falling back to its appendix.
- `bootstrap.sh` refuses to run from a copy of the kit's repository inside
  its target. A copy of `starter-kit/` alone at the target's root stays the
  documented copy-and-delete path.
- On a first install, `bootstrap.sh` stops before writing anything when the
  target has agent instructions, rules or skills of its own. It names them
  and points at the Harmonize track. `--alongside-existing` says the user
  approved installing beside them. A re-run on an install of the kit is
  never stopped.
- With that switch, off Claude Code, the installer lists the rules that the
  existing constitution does not link. `check-constitution.sh` fails on each
  rule under `docs/agent-rules/` that no constitution links, where
  `.starter-kit-version` records one of those tools.
- Once the installer has run, its next steps point an agent at `AGENTS.md`.

## Consequences

**Easier:** the one-line request reaches the installer and the steps behind
it. The two silent failures, an embedded clone and rules nobody reads, now
stop the run or fail a check, with the fix in the message.

**Harder:** a script or person that ran the installer into a repository with
its own `CLAUDE.md` or `AGENTS.md` has to add `--alongside-existing`. That is
the breaking change. An `agents`, `cursor` or `copilot` install beside a
constitution of its own fails `make constitution` until the rules are linked.

**Not solved:** what an agent does with the steps it reads. The runs show it
can skip the questions and edit a file without approval while every check
passes. Asking and approval are between the agent and the user, and no gate
sees them. Where `git clone` is blocked, the quick path degrades to the
pasted prompt's appendix.
