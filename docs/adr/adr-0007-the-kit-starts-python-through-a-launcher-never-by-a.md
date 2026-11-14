# The kit starts Python through a launcher, never by a fixed name

## Status

Accepted

## Context

Every command the kit ran named its interpreter: `python3 scripts/…` in the
make targets, in five gates, in the installer, in the test suites and — since
ADR-0006 — in the two hook commands registered in `settings.json`.

`python3` is the name on macOS and Linux. It is not a safe name anywhere else.
On Windows, from Git Bash, Python installed from python.org answers to
`python` and to the `py` launcher, and `python3` is often a Store alias: a
file on PATH that runs, prints an invitation to install Python, and exits
non-zero. A review of the hook pull request raised exactly this.

How the failure shows depends on where the name is written. In a make target
it is loud: the target fails. In a hook it is silent. Claude Code treats a
hook that cannot start as a non-blocking error, so on such a machine the hook
of ADR-0006 would say nothing, forever, and nothing would say that it had
failed — the failure mode the guide warns about in § 3.7, introduced by the
kit's own default.

Four ways to stop naming the interpreter were weighed.

- **Call `python` instead.** It moves the problem: several Linux
  distributions ship no `python` at all.
- **Rely on the shebang** (`#!/usr/bin/env python3`) and run the files
  directly. It is the same fixed name, one line further in.
- **Detect once, at install time, and write the name into the files.** It
  makes the installed files machine-specific, and a repository is cloned onto
  machines the installer never saw.
- **A launcher that looks each time it is run.**

A detail decides how the launcher looks. Asking whether a name is on PATH is
not enough: the Store alias is on PATH. The name has to be run.

## Decision

Everything the kit runs itself starts Python through `scripts/python.sh`. The
launcher tries `python3`, `python` and `py -3`, in that order, and uses the
first that runs a line of Python 3.9 or newer. It is installed on day 1, for
every tool.

`PYTHON` names the interpreter outright. It is taken as given, so a path with
spaces works, and a `PYTHON` that does not run is an error: falling back to
some other interpreter in silence would hide the mistake.

The launcher sets UTF-8 mode unless the caller has set it. The tools print
arrows and dashes, and a Windows code page cannot encode an arrow.

A gate that finds no launcher beside it falls back to `python3`, so a
repository that copied a newer gate without the launcher behaves as it did
before.

Commands a person or an agent types are a different matter. The rules, the
constitution and the READMEs keep writing `python3 scripts/…`, because that
is what most readers will type, and say once that `./scripts/python.sh` stands
in for it. The commands the kit itself prints for copying use a make target or
the launcher.

## Consequences

**Easier.** A fresh install passes its whole lint, and its hook speaks, on a
machine where `python3` is not Python. `make lint PYTHON=…` picks an
interpreter without editing a file.

**Harder.** One more file on day 1. Every Python start costs one extra
interpreter launch for the probe, a few hundredths of a second; the hook now
starts three. A contributor has to remember not to write `python3` in
anything the kit runs — which a test now does for them: it installs the kit
on a machine where `python3` is a stand-in that records every call, runs the
full lint, and fails if the stand-in was asked for anything but the probe.

**What was tested, and what was not.** The launcher and a complete install
were run against a simulated machine: a directory first on PATH in which
`python3` is not Python and `python`, or only `py -3`, is. That reproduces
the names. It does not reproduce Windows: Git Bash's path translation, line
endings converted on checkout, and how Claude Code starts a hook there are
all untested, and the kit still needs `bash` and `make`, which Windows does
not have without Git Bash or WSL.

**Not done.** The typed commands in the documentation still say `python3`.
The bundled semver skill is a self-contained artifact with an upstream of its
own, and keeps the names it came with.

**Trigger to revisit.** The first report from a Windows machine: whatever it
shows goes into the simulated machine as a case. If readers on Windows keep
typing `python3` from the rules and failing, the documented commands move to
the launcher too.

**Related:** ADR-0006, ADR-0001
