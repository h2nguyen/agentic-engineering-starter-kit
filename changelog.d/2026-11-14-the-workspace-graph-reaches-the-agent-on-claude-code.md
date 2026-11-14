# The workspace graph reaches the agent on Claude Code

## Added

- On Claude Code, the agent is told what cites a file right after it edits it. A new hook, `.claude/hooks/workspace-graph.py`, runs after every `Edit` and `Write`: when the file is cited by another artifact, or now carries a typed link that resolves to nothing, the citing files and lines are added to the agent's context. For any other file it says nothing, and it says each distinct thing once per session.
- When the agent ends its turn with a typed link that no longer resolves — after a rename done through the shell, for instance — the same hook holds the turn once and hands the failure back, so the break is repaired or reported before "done" instead of found in CI. A turn is never held twice for the same failure.
- The hook is context, not a gate: `make lint` is unchanged and still the gate. It never changes a file, leaves nothing in the repository, and ends silent whenever it cannot do its job. Set `WORKSPACE_GRAPH_HOOK=off` to switch it off for a run, or delete its two entries from `.claude/settings.json` to remove it; `WORKSPACE_GRAPH_HOOK_DEBUG=1` makes it say why it stayed silent.
- A fresh Claude Code install registers the hook in `.claude/settings.json`. In a repository that already has a `settings.json`, re-running `bootstrap.sh` adds the hook file and prints the two entries to add; the installer does not edit the file.
- `scripts/graph_tool.py note <path>…`, for every tool: what the editor of a file should be told — who cites it, and any link in it that resolves to nothing — and nothing at all otherwise. It is what the hook calls, and what a hook for another agent tool would call.
- ADR-0006 records why the graph is handed to the agent by a hook, why that hook is on by default for Claude Code only, and what was and was not observed in real sessions.
