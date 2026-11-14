#!/usr/bin/env python3
"""Workspace-graph hook for Claude Code — the graph, handed to the agent.

The typed links between rules, scripts, skills and agents are only useful to
an agent that looks them up, and looking them up is a thing to remember. This
hook does the looking, at the two moments it matters, and speaks only when it
has something to say:

  post-edit   after Edit or Write (PostToolUse): if another artifact cites the
              file that was just edited, or the file now carries a link that
              resolves to nothing, the agent is told — who cites it, at which
              line. For every other file: nothing.
  stop        when the agent ends its turn (Stop): if a typed link no longer
              resolves, the turn is held once and the failure is handed back,
              so a rename done through the shell is caught before "done".

It is context, not a gate. `make lint` is the gate, and it runs with or
without this file. So the hook follows three rules:

  - Silent unless useful. No output, exit 0, is the normal case.
  - Each distinct thing once per session. Marks are kept in the temporary
    directory, never in the repository.
  - It never breaks a session. Input it cannot read, a repository without the
    graph tool, a tool that fails: all of them end silent with exit 0, and a
    turn already continued by a stop hook is always let go.

It reads the checkout the edited file is in (or, at stop, the session's
current directory) — not $CLAUDE_PROJECT_DIR, which in a worktree still names
the main checkout.

Registered in .claude/settings.json. To switch it off for a run, set
WORKSPACE_GRAPH_HOOK=off; to remove it, delete its two entries there. To see
why it stayed silent, set WORKSPACE_GRAPH_HOOK_DEBUG=1.

Stdlib only, like the tool it calls (scripts/graph_tool.py).
"""

import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time

TOOL = os.path.join("scripts", "graph_tool.py")
TOOL_TIMEOUT = 15          # seconds; the graph is rebuilt in well under one
MARKS_KEPT_FOR = 2 * 86400  # seconds; a session's marks outlive it by two days
REASON_LINES = 40


def debug(message):
    if os.environ.get("WORKSPACE_GRAPH_HOOK_DEBUG"):
        print(f"workspace-graph hook: {message}", file=sys.stderr)


def repository(start):
    """The checkout `start` is in, if it has the graph tool — else None."""
    try:
        found = subprocess.run(
            ["git", "-C", start, "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=TOOL_TIMEOUT,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        debug(f"git could not run in {start}: {exc}")
        return None
    root = found.stdout.strip()
    if found.returncode != 0 or not root:
        debug(f"{start} is not inside a git repository")
        return None
    if not os.path.isfile(os.path.join(root, TOOL)):
        debug(f"{root} has no {TOOL}")
        return None
    return root


def graph_tool(root, *argv):
    """Run the repository's own graph tool; no bytecode left in the repository."""
    return subprocess.run(
        [sys.executable, "-B", TOOL, *argv],
        cwd=root, capture_output=True, text=True, timeout=TOOL_TIMEOUT,
        env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"),
    )


def first_time(session, text):
    """False when exactly this was already said in this session.

    A rule edited five times is one note, not five; a broken link holds one
    turn, not every turn. Without a usable session id there is nothing to key
    on, and saying it again is the safe side.
    """
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,128}", session or ""):
        return True
    try:
        owner = os.getuid() if hasattr(os, "getuid") else 0
        marks = os.path.join(tempfile.gettempdir(), f"workspace-graph-hook-{owner}")
        os.makedirs(marks, mode=0o700, exist_ok=True)
        if hasattr(os, "getuid") and os.stat(marks).st_uid != owner:
            return True  # somebody else's directory: do not trust or write it
        now = time.time()
        for entry in os.scandir(marks):
            if entry.is_file() and now - entry.stat().st_mtime > MARKS_KEPT_FOR:
                os.unlink(entry.path)
        path = os.path.join(marks, session)
        digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
        if os.path.isfile(path):
            with open(path, encoding="utf-8") as fh:
                if digest in fh.read().split():
                    return False
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(digest + "\n")
    except OSError as exc:
        debug(f"could not keep marks: {exc}")
    return True


def post_edit(event):
    path = (event.get("tool_input") or {}).get("file_path")
    if not isinstance(path, str) or not path:
        return debug("no tool_input.file_path in the event")
    if not os.path.isabs(path):
        path = os.path.join(event.get("cwd") or os.getcwd(), path)
    root = repository(os.path.dirname(path))
    if root is None:
        return
    result = graph_tool(root, "note", path)
    note = result.stdout.strip()
    if result.returncode != 0 or not note:
        return debug(f"nothing to say about {path} (tool exit {result.returncode})")
    if not first_time(event.get("session_id"), note):
        return debug("already said in this session")
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": "Workspace graph — typed links for the file you just edited:\n" + note,
        }
    }))


def stop(event):
    if event.get("stop_hook_active"):
        return debug("this turn was already continued by a stop hook")
    root = repository(event.get("cwd") or os.getcwd())
    if root is None:
        return
    result = graph_tool(root, "check")
    failure = result.stderr.strip()
    # Only a link that does not resolve holds a turn. A configuration the tool
    # cannot read is the gate's to report: it names no file:line to go and fix.
    broken = [line for line in failure.splitlines() if re.match(r"FAIL: \S+:\d+ — ", line)]
    if result.returncode == 0 or not broken:
        return debug(f"nothing to hold the turn for (tool exit {result.returncode})")
    if not first_time(event.get("session_id"), failure):
        return debug("already said in this session")
    lines = failure.splitlines()
    if len(lines) > REASON_LINES:
        lines = lines[:REASON_LINES] + [f"… {len(lines) - REASON_LINES} more line(s): ./scripts/check-graph-links.sh"]
    print(json.dumps({
        "decision": "block",
        "reason": (
            "Workspace graph — a typed link no longer resolves:\n"
            + "\n".join(lines)
            + "\nIf this turn renamed or removed the artifact, update the citing lines now. "
            "If the break was already there or cannot be fixed in this task, say so to the "
            "user instead of fixing it silently. You will not be stopped for this again in this session."
        ),
    }))


def main():
    if os.environ.get("WORKSPACE_GRAPH_HOOK", "").lower() in ("off", "0", "false", "no"):
        return 0
    handler = {"post-edit": post_edit, "stop": stop}.get(sys.argv[1] if len(sys.argv) > 1 else "")
    try:
        event = json.load(sys.stdin)
        if handler is not None and isinstance(event, dict):
            handler(event)
    except Exception as exc:  # a context hook that fails must fail silent, never block
        debug(f"{type(exc).__name__}: {exc}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
