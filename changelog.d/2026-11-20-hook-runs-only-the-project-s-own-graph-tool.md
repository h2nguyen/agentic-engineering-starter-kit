# Hook runs only the project's own graph tool

## Security

- The workspace-graph hook (`.claude/hooks/workspace-graph.py`) no longer runs the
  `scripts/graph_tool.py` of whatever repository an edited file sits in. It judges only the
  repository it is installed in and that repository's worktrees; after an edit in any other
  checkout — a clone the agent was asked to read, a dependency's source — it stays silent and
  runs none of its code. Before, such an edit started that checkout's tool as a Python script.
  To pick up the fix, copy the hook from the kit (README, "Upgrading an existing install",
  step 2).
