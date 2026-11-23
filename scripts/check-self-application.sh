#!/usr/bin/env bash
# Enforces: ADR-0022 — this repository applies the agent side of its own kit,
# by a link into starter-kit/ and never by a copy.
#
# Repository-only, like check-guide-templates.sh: it holds the kit's own
# repository to the kit, so bootstrap.sh does not install it.
#
# Why it exists: the gates ran here on the kit's files from the start, but an
# agent working here loaded none of the rules the kit ships, had none of its
# skills, and no hook told it what cites the file it had edited. The kit was
# applied to every repository but its own. Self-application that is only
# stated decays the same way a rule does: a rule is added to the kit and never
# linked here, or a link becomes a copy and the copy drifts.
#
# What it holds:
#   - every rule, skill, agent and command the kit ships (templates, whose
#     names begin with an underscore, excepted) has a symbolic link of the same
#     name under .claude/, pointing at the kit's file;
#   - .claude/settings.json registers the workspace-graph hook for both of its
#     events, started through the kit's launcher, with --tool naming the graph
#     tool where this repository keeps it — without that the hook stays silent.
#
# It reads the index, not the file system: a link is mode 120000 there on
# every platform, including one whose checkout cannot hold symbolic links.
#
# Usage: check-self-application.sh
set -uo pipefail
# The launcher beside this script, found before the directory changes: the
# repository being checked is the current one, which in a test is a scratch one.
PY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/starter-kit/scripts/python.sh"
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
KIT=starter-kit
fail=0
checked=0
failure() { echo "FAIL: $1"; shift; for line in "$@"; do echo "      $line"; done; fail=$((fail + 1)); }

check_link() { # $1 = path under .claude/, $2 = the target a link there must hold, $3 = the kit's file
  local entry mode target
  checked=$((checked + 1))
  entry="$(git ls-files -s -- "$1" | head -1)"
  if [ -z "$entry" ]; then
    if [ -e "$1" ] || [ -L "$1" ]; then
      failure "$1 is not tracked." "Add it:  git add $1"
    else
      failure "$1 is missing — the kit ships $3, and this repository does not apply it." \
              "Add the link:  ln -s $2 $1 && git add $1"
    fi
    return
  fi
  mode="${entry%% *}"
  if [ "$mode" != 120000 ]; then
    failure "$1 is a copy of the kit's file, not a link to it. A copy is what drifts." \
            "Replace it:  git rm -rq --cached $1 && rm -rf $1 && ln -s $2 $1 && git add $1"
    return
  fi
  target="$(git cat-file -p ":$1")"
  if [ "$target" != "$2" ]; then
    failure "$1 links to '$target', not to the kit's $3." \
            "Fix it:  rm $1 && ln -s $2 $1 && git add $1"
  fi
}

for f in "$KIT"/rules/*.md "$KIT"/agents/*.md "$KIT"/commands/*.md; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"; kind="$(basename "$(dirname "$f")")"
  case "$name" in _*) continue ;; esac
  check_link ".claude/$kind/$name" "../../$KIT/$kind/$name" "$f"
done
for d in "$KIT"/skills/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  case "$name" in _*) continue ;; esac
  check_link ".claude/skills/$name" "../../$KIT/skills/$name" "$KIT/skills/$name/"
done

SETTINGS=.claude/settings.json
checked=$((checked + 1))
if [ ! -f "$SETTINGS" ]; then
  failure "$SETTINGS is missing — the workspace-graph hook is not registered here." \
          "Register $KIT/hooks/workspace-graph.py for PostToolUse and Stop, as $KIT/settings.json.template does," \
          "started through $KIT/scripts/python.sh and with:  --tool $KIT/scripts/graph_tool.py"
else
  problems="$("$PY" -B - "$SETTINGS" "$KIT" <<'PY'
import json, sys
path, kit = sys.argv[1], sys.argv[2]
try:
    hooks = json.load(open(path, encoding="utf-8")).get("hooks", {})
except (OSError, ValueError) as exc:
    print(f"cannot be read as JSON ({exc})"); sys.exit(0)
for event, mode in (("PostToolUse", "post-edit"), ("Stop", "stop")):
    commands = [h.get("command", "") for entry in hooks.get(event, []) for h in entry.get("hooks", [])]
    wanted = (f"/{kit}/scripts/python.sh", f"/{kit}/hooks/workspace-graph.py", f" {mode}",
              f"--tool {kit}/scripts/graph_tool.py")
    if not any(all(part in command for part in wanted) for command in commands):
        print(f"{event}: no command runs {kit}/hooks/workspace-graph.py {mode} through "
              f"{kit}/scripts/python.sh with --tool {kit}/scripts/graph_tool.py")
PY
)" || problems="the settings could not be checked: $PY did not run"
  if [ -n "$problems" ]; then
    failure "$SETTINGS does not register the workspace-graph hook as this repository needs it:" "$problems" \
            "Without --tool the hook looks for scripts/graph_tool.py, finds none here, and stays silent."
  fi
fi

if [ "$fail" -gt 0 ]; then
  echo ""
  echo "This repository runs on its own kit (ADR-0022). See CONTRIBUTING.md § Adding to what the installer ships."
  exit 1
fi
echo "OK: $checked artifact(s) of the kit are applied here by reference, and the workspace-graph hook is registered"
