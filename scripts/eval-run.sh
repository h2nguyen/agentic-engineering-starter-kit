#!/usr/bin/env bash
# Runs one command of an evaluation in a directory it is told, and records it:
# command, cwd, start, end, exit status, stdout and stderr. A directory named
# with --guard is compared before and after.
#
# Repository-only: it serves CONTRIBUTING.md § "Evaluating a change by applying
# the kit", so bootstrap.sh does not install it.
#
# Why it exists: an evaluation's build command was dispatched with no working
# directory, ran in this checkout and wrote two files into it; and the
# evidence that survived was a summary. Telling an agent in prose where to
# work did not bind where its commands ran.
#
# It is a recorder with a tripwire, not a sandbox. A guard reports that a
# directory changed, after it changed; it cannot stop the write. Isolation
# that prevents one — a container, a separate user, a read-only mount — is
# the job of whatever runs the agent.
#
# Usage: eval-run.sh --cwd <absolute dir> --log <dir> [--guard <dir>]...
#                    [--label <text>] [--expect fail] [--quiet] -- <command> [args...]
#        eval-run.sh --help
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT/starter-kit/scripts/python.sh" -B "$ROOT/scripts/eval_run.py" "$@"
