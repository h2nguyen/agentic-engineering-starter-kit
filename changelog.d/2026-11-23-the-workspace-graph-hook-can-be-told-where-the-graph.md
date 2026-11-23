# The workspace-graph hook can be told where the graph tool is

## Added

- The Claude Code hook `workspace-graph.py` takes `--tool <path>` after its event: `… workspace-graph.py post-edit --tool tools/kit/graph_tool.py`. It runs `scripts/graph_tool.py` as before when the option is absent. Use it in a repository that keeps the kit's scripts somewhere other than `scripts/`, where the hook found no tool and stayed silent. The path is relative to the checkout and must stay inside it: an absolute path, one that leaves the checkout, or a symbolic link that does, is refused in silence, so the hook still runs only the project's own file. You get the hook by copying it in upgrade step 2; an install that keeps the tool in `scripts/` needs no change.

## Changed

- The kit's own repository now runs on its kit: its rules, skills, `agent-coach` and hook are applied there by links into `starter-kit/`, held by a gate (ADR-0022). What that shows is in `docs/EVIDENCE.md`: numbers computed from the repository at a stamped commit and recomputed by its `make lint` (ADR-0023). Nothing changes in an installed project.
