#!/usr/bin/env bash
# Runs Python 3 under whatever name this machine gives it.
#
# Everything the kit runs itself — the make targets, the gates, the tests, the
# Claude Code hook — starts Python through this file, never by a fixed name.
#
# Why it exists: `python3` is the name on macOS and Linux and not a safe one
# anywhere else. On Windows (Git Bash) Python is usually `python`, or only the
# `py` launcher, and `python3` can be a Store alias: on PATH, runnable, and
# not Python. A command written as `python3 scripts/…` fails there, and where
# the command is a hook it fails where nobody is looking. So a name is used
# only after it has run a line of Python 3.9 or newer.
#
# Order: python3, python, `py -3`. Set PYTHON to name the interpreter yourself:
#
#     PYTHON=/opt/python3.12/bin/python3 make lint
#
# PYTHON is taken as given — a path may contain spaces — and one that does not
# work is an error rather than a quiet fallback to some other interpreter.
#
# Output is UTF-8 on every platform (PYTHONUTF8=1 unless you set it): the
# tools print arrows and dashes, which a Windows code page cannot encode.
#
# Usage: scripts/python.sh <script.py | -m module | -c code | -> [args...]
#        scripts/python.sh --which      print the interpreter it would use
#
# Builtins only, so it works on a PATH that has nothing else on it.
set -u

PROBE='import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)'

# Standard input is the caller's — often the program itself — so the probe
# must not read it.
is_python() { "$@" -c "$PROBE" </dev/null >/dev/null 2>&1; }

if [ -n "${PYTHON:-}" ]; then
  if ! is_python "$PYTHON"; then
    echo "FAIL: PYTHON=$PYTHON is not a working Python 3.9 or newer." >&2
    echo "      Unset PYTHON to let this script look for one (python3, python, py -3)," >&2
    echo "      or point it at an interpreter that runs." >&2
    exit 127
  fi
  interpreter=("$PYTHON")
elif is_python python3; then
  interpreter=(python3)
elif is_python python; then
  interpreter=(python)
elif is_python py -3; then
  interpreter=(py -3)
else
  echo "FAIL: no Python 3.9 or newer found. Tried, in this order: python3, python, py -3." >&2
  echo "      Install Python 3, or name the interpreter yourself:" >&2
  echo "          PYTHON=/path/to/python $0 ..." >&2
  exit 127
fi

if [ "${1:-}" = "--which" ]; then
  echo "${interpreter[*]}"
  exit 0
fi

export PYTHONUTF8="${PYTHONUTF8:-1}"
exec "${interpreter[@]}" "$@"
