#!/usr/bin/env python3
"""Agent feedback collector — what people told the agents, grouped by artifact.

A correction made to an agent in a chat session ends with the session. One
written where the work is reviewed survives, and it can reach the rule, skill
or agent that produced the mistake if it names that artifact:

    Agent-Feedback: SKILL:registry-entry — typed the date by hand; the tool derives it

One line per point, at the start of a line, in a commit message or in a
pull-request or issue comment. The target is a typed-link token, resolved by
the same graph the link gate builds. The rest says what went wrong and why.

This tool reads those lines and prints one JSON report, grouped by artifact,
for whoever proposes the next change to that artifact (the agent-coach, or a
person). It reports; it changes nothing, and it is not a gate.

Whose lines count is the adopter's list, `.agent-feedback-authors` at the
repository root: a commit author's email, or a login as a comment export names
it. Text from anyone else is left out of the report entirely, because whatever
reaches the report may become an instruction that every later agent session
follows. Of such a line the report keeps a count, the author if it is shaped
like an email or a login, the target only if it resolves, and a ref the tool
made itself. With no list, nobody's text is read.

Sources:
  git      the messages of the commits `--rev` reaches (default HEAD), merge
           commits excepted: a merge carries the pull request's title or
           description, written by whoever opened it, under the identity of
           whoever merged it. A commit's author is only as trustworthy as the
           review its metadata got; run it on the default branch.
  --from   a JSON file of comments your own tooling exported from the code
           host: a list of {"author", "body"} objects, each optionally with
           "url" (or "ref") and "date". The kit has no network access, so it
           does not fetch them itself.

A line is a line as a Markdown renderer sees one: only a newline ends it.
Lines inside fenced code blocks, indented code and quoted lines (`> …`) are
not feedback: a quote is someone else's words, and an example is not a point.

Stdlib only.

  feedback_tool.py collect [--rev REV] [--since DATE] [--no-git]
                           [--from FILE]... [--authors FILE] [--out FILE]
"""

from __future__ import annotations

import argparse
import codecs
import datetime
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
# Importing a sibling module would write scripts/__pycache__/ into the
# adopting repository, which gets no .gitignore from the kit.
sys.dont_write_bytecode = True
try:
    # One resolver for tokens: the link gate's. A second one here would accept
    # a name the gate rejects the first time a project moved a kind of artifact.
    import graph_tool as gt
except ImportError:  # pragma: no cover - reported by main()
    gt = None

AUTHORS_FILE = ".agent-feedback-authors"
SCHEMA = "agent-feedback/1"
# At the very start of the line: indented four spaces, Markdown reads it as code.
KEY_LINE = re.compile(r"^Agent-Feedback:(.*)$", re.IGNORECASE)
FENCE_OPEN = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
FENCE_CLOSE = re.compile(r"^ {0,3}(`{3,}|~{3,})[ \t]*$")
SEPARATOR = re.compile(r"^(?:—|–|--|-|:)\s*")
# What an excluded entry may still show of its author: an email or a login,
# no longer than either can be — an identifier, never a sentence.
IDENTITY = re.compile(r"^(?:[A-Za-z0-9._%+-]{1,64}@[A-Za-z0-9.-]{1,253}|[A-Za-z0-9][A-Za-z0-9-]{0,38})$")
COMMIT_PERSON = re.compile(rb"^(author|committer) [^<>]*<([^<>]*)> (\d+) ([+-])(\d\d)(\d\d)$")
MAX_TEXT = 2000
NOT_SHOWN = "(not shown)"


class FeedbackError(Exception):
    """A failure the caller should see as one line, not a traceback."""


# --------------------------------------------------------------------------
# parsing
# --------------------------------------------------------------------------

def _lines(body: str):
    # str.splitlines() also breaks at U+2028, form feed and other characters a
    # renderer shows inside one line — and a quote or a fence ends with its line.
    for line in body.split("\n"):
        yield line[:-1] if line.endswith("\r") else line


def feedback_lines(body: str):
    """(target, text) for every Agent-Feedback line in a message or comment."""
    fence = None  # (character, length) of the open fence, as CommonMark closes it
    for line in _lines(body):
        if fence is not None:
            close = FENCE_CLOSE.match(line)
            if close and close.group(1)[0] == fence[0] and len(close.group(1)) >= fence[1]:
                fence = None
            continue
        opened = FENCE_OPEN.match(line)
        if opened and not (opened.group(1)[0] == "`" and "`" in opened.group(2)):
            fence = (opened.group(1)[0], len(opened.group(1)))
            continue
        if line.lstrip().startswith(">"):
            continue
        hit = KEY_LINE.match(line)
        if not hit:
            continue
        parts = hit.group(1).split(None, 1)
        target = parts[0].strip("`").rstrip(",;:.").strip("`") if parts else ""
        rest = parts[1] if len(parts) > 1 else ""
        text = SEPARATOR.sub("", rest.strip()).strip()
        yield target, text[:MAX_TEXT]


def _identity(value: str) -> str:
    value = (value or "").strip()
    return value if IDENTITY.match(value) else NOT_SHOWN


# --------------------------------------------------------------------------
# sources
# --------------------------------------------------------------------------

def _git(root: str, *args: str, data: bytes | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", root, *args], input=data, capture_output=True)


def _parse_commit(raw: bytes):
    """(author email, commit date, message) of a raw commit object."""
    head, _, message = raw.partition(b"\n\n")
    email, date, encoding = "", "", "utf-8"
    for line in head.split(b"\n"):
        person = COMMIT_PERSON.match(line)
        if person:
            if person.group(1) == b"author":
                email = person.group(2).decode("utf-8", "replace")
            else:
                sign = 1 if person.group(4) == b"+" else -1
                zone = datetime.timezone(sign * datetime.timedelta(
                    hours=int(person.group(5)), minutes=int(person.group(6))))
                date = datetime.datetime.fromtimestamp(int(person.group(3)), zone).isoformat()
        elif line.startswith(b"encoding "):
            encoding = line[len(b"encoding "):].decode("ascii", "replace").strip()
    try:
        codecs.lookup(encoding)
    except LookupError:
        encoding = "utf-8"
    return email, date, message.decode(encoding, "replace")


def from_git(root: str, rev: str, since: str | None):
    """One message per non-merge commit `rev` reaches, newest first.

    Commits are read as objects, each length-prefixed by `git cat-file --batch`,
    never by splitting formatted output on a separator: a commit message can
    contain any separator byte, and with it a whole forged record.
    """
    for name, value in (("--rev", rev), ("--since", since or "")):
        if value.startswith("-"):
            raise FeedbackError(f"{name} {value!r} looks like an option; give a revision or a date")
    if _git(root, "rev-parse", "--is-inside-work-tree").returncode != 0:
        raise FeedbackError(f"{root} is not a git repository; pass --no-git to read only --from files")
    if rev == "HEAD" and _git(root, "rev-parse", "--verify", "-q", "HEAD").returncode != 0:
        return  # no commits yet: nothing anyone could have written
    args = ["rev-list", "--no-merges"] + ([f"--since={since}"] if since else []) + [rev, "--"]
    listed = _git(root, *args)
    if listed.returncode != 0:
        raise FeedbackError(f"git rev-list {rev} failed: {listed.stderr.decode('utf-8', 'replace').strip()}")
    shas = listed.stdout.decode("ascii", "replace").split()
    if not shas:
        return
    batch = _git(root, "cat-file", "--batch", data=("\n".join(shas) + "\n").encode("ascii"))
    if batch.returncode != 0:
        raise FeedbackError(f"git cat-file failed: {batch.stderr.decode('utf-8', 'replace').strip()}")
    out, pos = batch.stdout, 0
    for sha in shas:
        newline = out.index(b"\n", pos)
        header = out[pos:newline].split()
        if len(header) != 3 or header[0].decode("ascii", "replace") != sha or header[1] != b"commit":
            raise FeedbackError(f"git cat-file returned an unexpected object for {sha}")
        size = int(header[2])
        email, date, message = _parse_commit(out[newline + 1:newline + 1 + size])
        pos = newline + 1 + size + 1
        yield {"ref": f"git:{sha[:12]}", "excluded_ref": f"git:{sha[:12]}",
               "author": email, "date": date, "body": message}


def from_export(path: str):
    """The comments of an export file, in the order the file lists them."""
    try:
        with open(path, encoding="utf-8") as fh:
            items = json.load(fh)
    except (OSError, ValueError) as exc:
        raise FeedbackError(f"{path}: cannot read it as JSON ({exc})")
    if not isinstance(items, list):
        raise FeedbackError(f'{path}: expected a JSON list of {{"author", "body"}} objects')
    name = os.path.basename(path)
    for index, item in enumerate(items):
        if not isinstance(item, dict) or not isinstance(item.get("author"), str) \
                or not isinstance(item.get("body"), str):
            raise FeedbackError(f'{path}: item {index} needs a string "author" and a string "body"')
        own = f"{name}#{index}"
        link = next((v for v in (item.get("url"), item.get("ref")) if isinstance(v, str) and v.strip()), own)
        date = item.get("date") if isinstance(item.get("date"), str) else ""
        # The url is the comment's author's too: it is shown for a listed
        # author, and an excluded entry gets the ref this tool made itself.
        yield {"ref": link, "excluded_ref": own, "author": item["author"], "date": date, "body": item["body"]}


def load_authors(path: str) -> set[str] | None:
    """The listed identities, lowercased; None when there is no list."""
    if not os.path.isfile(path):
        return None
    listed = set()
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                identity = line.split("#", 1)[0].strip().lower()
                if identity:
                    listed.add(identity)
    except (OSError, UnicodeDecodeError) as exc:
        raise FeedbackError(f"{path}: cannot read it as UTF-8 text ({exc})")
    return listed


# --------------------------------------------------------------------------
# collect
# --------------------------------------------------------------------------

def resolve(graph, target: str):
    """(canonical token, path, None) or (None, None, why it is not a target)."""
    if not target:
        return None, None, "no target token after Agent-Feedback:"
    if target == gt.HUMAN:
        return None, None, "HUMAN is an approval, not an artifact"
    nodes = graph.find(target)
    if not nodes:
        return None, None, "names no artifact in this repository"
    if len(nodes) > 1:
        return None, None, "names %d artifacts: %s" % (len(nodes), ", ".join(n.path for n in nodes))
    return nodes[0].token, nodes[0].path, None


def collect(graph, messages, authors: set[str] | None) -> dict:
    groups: dict[str, dict] = {}
    unresolved, excluded, seen = [], [], {}
    for message in messages:
        author = message["author"].strip()
        trusted = authors is not None and author.lower() in authors
        for target, text in feedback_lines(message["body"]):
            if not trusted:
                token, _, problem = resolve(graph, target)
                excluded.append({"ref": message["excluded_ref"], "author": _identity(author),
                                 "target": token if problem is None else "(unresolved)"})
                continue
            key = (author.lower(), target, text)
            if key in seen:
                # One point, made again: the recurrence is the signal, so keep where.
                if message["ref"] not in seen[key]["refs"]:
                    seen[key]["refs"].append(message["ref"])
                continue
            item = {"refs": [message["ref"]], "author": author, "date": message["date"], "text": text}
            seen[key] = item
            token, path, problem = resolve(graph, target)
            if problem is None and not text:
                problem = "no text: say what went wrong, and why"
            if problem:
                item.update(target=target, reason=problem)
                unresolved.append(item)
                continue
            group = groups.setdefault(token, {"target": token, "path": path, "count": 0, "items": []})
            group["items"].append(item)
            group["count"] += 1
    ordered = sorted(groups.values(), key=lambda g: (-g["count"], g["target"]))
    return {
        "targets": ordered,
        "unresolved": unresolved,
        "excluded": excluded,
        "counts": {"accepted": sum(g["count"] for g in ordered),
                   "unresolved": len(unresolved), "excluded": len(excluded)},
    }


def cmd_collect(args) -> int:
    graph = gt.load_graph(args.config)
    root = graph.root
    authors_path = args.authors or os.path.join(root, AUTHORS_FILE)
    authors = load_authors(authors_path)

    messages, sources = [], []
    if not args.no_git:
        messages += list(from_git(root, args.rev, args.since))
        sources.append(f"git {args.rev}" + (f" since {args.since}" if args.since else ""))
    for path in args.sources:
        messages += list(from_export(path))
        sources.append(f"export {path}")

    report = {"schema": SCHEMA, "sources": sources}
    report["authors_file"] = os.path.relpath(authors_path, root) if authors is not None else None
    report["authors_listed"] = len(authors or ())
    report.update(collect(graph, messages, authors))

    text = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    if args.out:
        try:
            with open(args.out, "w", encoding="utf-8") as fh:
                fh.write(text)
        except OSError as exc:
            raise FeedbackError(f"cannot write {args.out}: {exc}")
    else:
        sys.stdout.write(text)

    counts = report["counts"]
    print(f"agent-feedback: {counts['accepted']} point(s) on {len(report['targets'])} artifact(s); "
          f"{counts['unresolved']} unresolved; {counts['excluded']} excluded", file=sys.stderr)
    if authors is None:
        print(f"agent-feedback: no {AUTHORS_FILE} at the repository root, so nobody's feedback was read. "
              "List the identities whose feedback counts, one per line.", file=sys.stderr)
    elif counts["excluded"]:
        print(f"agent-feedback: excluded lines are from authors not listed in {report['authors_file']}; "
              "their text is not in the report.", file=sys.stderr)
    return 0


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="feedback_tool.py",
        description="Collect Agent-Feedback lines into one report, grouped by the artifact they name.",
    )
    parser.add_argument("--config", help="path to registries.json (default: search upwards)")
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("collect", help="print the report as JSON")
    p.add_argument("--rev", default="HEAD", help="what git log reads (default HEAD), e.g. main or v1.2.0..main")
    p.add_argument("--since", help="only commits after this date, as git log --since takes it")
    p.add_argument("--no-git", action="store_true", help="read no commit messages, only --from files")
    p.add_argument("--from", dest="sources", action="append", default=[], metavar="FILE",
                   help='a JSON list of {"author", "body", "url"?, "date"?} comments; repeatable')
    p.add_argument("--authors", help=f"whose feedback counts (default: {AUTHORS_FILE} at the repository root)")
    p.add_argument("--out", help="write the report here instead of to stdout")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if gt is None:
        print("FAIL: graph_tool.py not found next to feedback_tool.py — they ship together; "
              "copy both from the starter kit's scripts/ directory.", file=sys.stderr)
        return 1
    try:
        return cmd_collect(args)
    except (FeedbackError, gt.GraphError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
