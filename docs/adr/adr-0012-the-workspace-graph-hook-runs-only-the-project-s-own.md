# The workspace-graph hook runs only the project's own graph tool

## Status

Accepted

## Context

ADR-0006 has the hook read the checkout the edited file is in, not
`$CLAUDE_PROJECT_DIR`, because in a worktree that variable still names the main
checkout. It said nothing about which checkouts qualify. The hook therefore ran
the `scripts/graph_tool.py` of any git repository an edited file sat in: a clone
the agent was asked to read, a dependency's source, a repository someone else
prepared. That is a Python script nobody in the project reviewed, started by the
hook as the user, with its output handed to the agent as context.

The forces:

- **Worktrees must keep working.** They are why ADR-0006 rejected
  `$CLAUDE_PROJECT_DIR`, and the edited file's own checkout is still the one to
  judge.
- **The hook file is not always inside the project.** A shared `.claude/` is
  linked into several projects, or the hook is registered in the user's
  settings. A boundary drawn from the hook file's location silences it there.
- **git versions vary.** `rev-parse --path-format=absolute` exists from 2.31;
  older git echoes the unknown option and exits 0, so a fallback keyed on
  failure never fires.

Options weighed:

- **Judge only `$CLAUDE_PROJECT_DIR`.** Safe, and breaks worktrees again.
- **Keep any repository, warn the user.** The code has already run when the
  warning appears.
- **Admit the project's submodules.** Their content is pinned by the project,
  but the working tree of a submodule can be on any commit, and checking a
  superproject chain adds git calls to every edit for a case nobody has asked
  for yet.
- **Admit the repository the project belongs to, with all its worktrees.** The
  git common directory is shared by exactly those checkouts and by nothing else.

## Decision

We will run the graph tool only for a checkout whose `git rev-parse
--git-common-dir` resolves to the same directory as the project's. The project
is the one `$CLAUDE_PROJECT_DIR` names; without it, the repository the hook file
lies in. Every other checkout, a separate clone of the project and a submodule
included, is not judged: the hook stays silent and runs nothing. The common
directory is read without `--path-format`, relative to the directory git was
started in.

## Consequences

**Easier.** Editing files in a foreign checkout is safe again: nothing from it
runs. Worktrees, a shared `.claude/` and old git keep the hook working, and
`test-graph-hooks.sh` holds all of them, each with a control.

**Harder.** A submodule that carries the kit gets no notes and no stop hold
while the agent works in it from the superproject; its own `make lint` is still
the gate. If that becomes a signal, a new record decides how submodules are
admitted. The guide's advice on deriving a hook's root from the touched file
now carries the same boundary, so adopters' own hooks do not repeat the flaw.

**Related:** ADR-0006
