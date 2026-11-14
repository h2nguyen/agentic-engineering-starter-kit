# The kit runs where Python is not called python3

## Added

- `scripts/python.sh`, installed for every tool: it starts Python under whatever name the machine gives it. It tries `python3`, `python` and `py -3`, and uses the first that really runs Python 3.9 or newer — on Windows `python3` can be a Store alias that is on PATH and is not Python. `./scripts/python.sh --which` prints the interpreter it found.
- `make lint PYTHON=/path/to/python`, or `PYTHON=…` in the environment, names the interpreter yourself. A `PYTHON` that does not run is an error, not a fallback to another interpreter.
- ADR-0007 records why the interpreter is found each time it is started rather than named or detected once at install time, and that the Windows path was tested against a simulated machine and not on Windows itself.

## Changed

- Everything the kit runs itself starts Python through the launcher: the make targets in `registry.mk`, the five gates, the installer, the test suites, and the two Claude Code hook entries in `.claude/settings.json`. On macOS and Linux nothing changes in what you see. On an upgrade, re-running `bootstrap.sh` adds `scripts/python.sh`; a gate copied without it falls back to `python3`, as before.
- The tools' output is UTF-8 on every platform, so an arrow or a dash in a message cannot fail on a Windows code page.
- Commands the kit prints for you to copy no longer name `python3`: the link gate and the edit note point at `make graph-impact NODE=…`, and the installer at `make registry-list` and `./scripts/python.sh scripts/registry_tool.py adopt …`. The commands in the rules and READMEs still read `python3 scripts/…`; the constitution and the README say that `./scripts/python.sh` stands in for it where Python has another name.
