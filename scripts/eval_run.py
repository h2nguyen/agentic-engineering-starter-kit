#!/usr/bin/env python3
"""Run one command in a named directory and keep the evidence.

Started through scripts/eval-run.sh. Standard library only.

An evaluation of the kit hands commands to an agent or a script and afterwards
has to say what happened. Two things went wrong in the run that prompted this
file: a command was dispatched without a working directory, so it ran in the
kit's own checkout and wrote files there; and what was kept was a summary of
the commands, not their output. So this runner refuses a command that has no
explicit directory, records everything about the one it runs, and compares
any directory named with --guard before and after.

It is a recorder with a tripwire, not a sandbox: a command can still write
wherever the user can. A guard reports the change afterwards, with the paths.
"""

import argparse
import datetime
import hashlib
import json
import os
import subprocess
import sys

REFUSED = 64          # the runner was called wrongly; nothing ran
VIOLATION = 97        # the command changed a guarded directory

USAGE = """\
Usage: eval-run.sh --cwd <absolute dir> --log <dir> [options] -- <command> [args...]

  --cwd <dir>      where the command runs. Required, absolute, must exist.
  --log <dir>      where the record goes: commands.jsonl plus one .out and
                   one .err file per command. Required; created if missing.
  --guard <dir>    a directory the command must leave as it found it. Absolute;
                   may be given several times. A change fails the run (exit 97).
  --label <text>   what this command is for, in the record.
  --expect fail    this command is MEANT to fail (a negative test). The record
                   says expected-fail and the runner exits 0; if the command
                   passes instead, that is unexpected-pass and exit 1.
  --quiet          do not copy the command's output to the terminal.

Exit status: the command's own, except 64 (refused, nothing ran), 97 (a
guarded directory changed) and the --expect fail cases above.

A guard reports a change after it happened. It does not prevent one.
"""


def refuse(message):
    sys.stderr.write("eval-run: " + message + "\n\n" + USAGE)
    sys.exit(REFUSED)


def now():
    return datetime.datetime.now(datetime.timezone.utc)


def stamp(moment):
    return moment.strftime("%Y-%m-%dT%H:%M:%S.") + "%03dZ" % (moment.microsecond // 1000)


def snapshot(root):
    """Every file under root, by content — .git internals excepted."""
    files = {}
    for directory, names, filenames in os.walk(root):
        if ".git" in names:
            names.remove(".git")
        for name in filenames:
            path = os.path.join(directory, name)
            relative = os.path.relpath(path, root).replace(os.sep, "/")
            try:
                if os.path.islink(path):
                    files[relative] = "link:" + os.readlink(path)
                else:
                    digest = hashlib.sha256()
                    with open(path, "rb") as handle:
                        for chunk in iter(lambda: handle.read(1 << 20), b""):
                            digest.update(chunk)
                    files[relative] = digest.hexdigest()
            except OSError as error:
                files[relative] = "unreadable:" + error.__class__.__name__
    return files


def git_state(root):
    """HEAD, branch and status of a checkout; None where root is not one."""
    def git(*args):
        result = subprocess.run(["git", "-C", root] + list(args), capture_output=True, text=True)
        return result.stdout.strip() if result.returncode == 0 else None

    top = git("rev-parse", "--show-toplevel")
    if top is None or os.path.realpath(top) != os.path.realpath(root):
        return None
    return {
        "head": git("rev-parse", "HEAD"),
        "branch": git("rev-parse", "--abbrev-ref", "HEAD"),
        "status": (git("status", "--porcelain", "--untracked-files=all") or "").splitlines(),
    }


def main(argv):
    parser = argparse.ArgumentParser(add_help=False, usage=USAGE)
    parser.add_argument("--cwd")
    parser.add_argument("--log")
    parser.add_argument("--guard", action="append", default=[])
    parser.add_argument("--label", default="")
    parser.add_argument("--expect", choices=("pass", "fail"), default="pass")
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("-h", "--help", action="store_true")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    try:
        args = parser.parse_args(argv)
    except SystemExit:
        sys.exit(REFUSED)
    if args.help:
        sys.stdout.write(USAGE)
        return 0

    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        refuse("no command given after --")
    if not args.cwd:
        refuse("--cwd is required: a command with no named directory runs wherever the caller happens to be")
    if not os.path.isabs(args.cwd):
        refuse("--cwd must be an absolute path, got '%s'" % args.cwd)
    if not os.path.isdir(args.cwd):
        refuse("--cwd '%s' is not a directory" % args.cwd)
    if not args.log:
        refuse("--log is required: a run that is not recorded is not evidence")
    for guard in args.guard:
        if not os.path.isabs(guard):
            refuse("--guard must be an absolute path, got '%s'" % guard)
        if not os.path.isdir(guard):
            refuse("--guard '%s' is not a directory" % guard)

    log = os.path.abspath(args.log)
    os.makedirs(log, exist_ok=True)
    index = os.path.join(log, "commands.jsonl")
    seq = 1
    if os.path.exists(index):
        with open(index, encoding="utf-8") as handle:
            seq = sum(1 for line in handle if line.strip()) + 1
    out_name, err_name = "%04d.out" % seq, "%04d.err" % seq

    before = [(guard, snapshot(guard), git_state(guard)) for guard in args.guard]

    environment = dict(os.environ, PWD=args.cwd)
    started = now()
    try:
        with open(os.path.join(log, out_name), "wb") as out, open(os.path.join(log, err_name), "wb") as err:
            status = subprocess.run(command, cwd=args.cwd, env=environment, stdin=subprocess.DEVNULL,
                                    stdout=out, stderr=err).returncode
    except OSError as error:
        status = 127
        with open(os.path.join(log, err_name), "ab") as err:
            err.write(("eval-run: could not start %r: %s\n" % (command[0], error)).encode("utf-8"))
    ended = now()

    guards, violated = [], False
    for guard, files, git_before in before:
        after, git_after = snapshot(guard), git_state(guard)
        added = sorted(set(after) - set(files))
        removed = sorted(set(files) - set(after))
        modified = sorted(path for path in set(files) & set(after) if files[path] != after[path])
        unchanged = not (added or removed or modified) and git_before == git_after
        violated = violated or not unchanged
        guards.append({"path": guard, "unchanged": unchanged, "added": added, "removed": removed,
                       "modified": modified, "git_before": git_before, "git_after": git_after})

    if violated:
        outcome, exit_code = "boundary-violation", VIOLATION
    elif args.expect == "fail":
        outcome, exit_code = ("expected-fail", 0) if status != 0 else ("unexpected-pass", 1)
    else:
        outcome, exit_code = ("pass", 0) if status == 0 else ("fail", status)

    record = {
        "seq": seq, "label": args.label, "expect": args.expect, "command": command, "cwd": args.cwd,
        "started_utc": stamp(started), "ended_utc": stamp(ended),
        "duration_s": round((ended - started).total_seconds(), 3),
        "exit_status": status, "outcome": outcome,
        "stdout_file": out_name, "stderr_file": err_name, "guards": guards,
    }
    with open(index, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")

    if not args.quiet:
        for name, stream in ((out_name, sys.stdout), (err_name, sys.stderr)):
            with open(os.path.join(log, name), "rb") as handle:
                stream.buffer.write(handle.read())
            stream.flush()
    sys.stderr.write("eval-run: #%d %s (exit %d, %.1fs) in %s\n" % (seq, outcome, status, record["duration_s"], args.cwd))
    for guard in guards:
        if guard["unchanged"]:
            continue
        sys.stderr.write("eval-run: BOUNDARY VIOLATION — the command changed %s\n" % guard["path"])
        for kind in ("added", "modified", "removed"):
            for path in guard[kind]:
                sys.stderr.write("    %-9s %s\n" % (kind, path))
        if guard["git_before"] != guard["git_after"]:
            sys.stderr.write("    git       %s -> %s\n" % (
                json.dumps(guard["git_before"], sort_keys=True), json.dumps(guard["git_after"], sort_keys=True)))
    return exit_code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
