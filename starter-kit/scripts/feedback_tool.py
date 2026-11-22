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
it. Text from anyone else is left out of the report entirely — only its author
and target are listed — because whatever reaches the report may become an
instruction that every later agent session follows. With no list, nobody's
text is read.

Sources:
  git      the messages of the commits `--rev` reaches (default HEAD). Run it on
           the default branch: a commit there has been through review.
  --from   a JSON file of comments your own tooling exported from the code
           host: a list of {"author", "body"} objects, each optionally with
           "url" (or "ref") and "date". The kit has no network access, so it
           does not fetch them itself.

Lines inside fenced code blocks, and quoted lines (`> …`), are not feedback: a
quote is someone else's words, and an example is not a point.

Stdlib only.

  feedback_tool.py collect [--rev REV] [--since DATE] [--no-git]
                           [--from FILE]... [--authors FILE] [--out FILE]
"""

from __future__ import annotations

import argparse
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
KEY_LINE = re.compile(r"^Agent-Feedback:[ \t]*(.*)$", re.IGNORECASE)
FENCE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")
SEPARATOR = re.compile(r"^(?:—|–|--|-|:)\s*")
# What an excluded entry may still show. Its text is withheld; its target and
# author are shown only in a shape that cannot carry a sentence.
SAFE_TOKEN = re.compile(r"^[A-Za-z0-9_:./@+-]{1,120}$")
# An export's url comes from the same author as the body, so an excluded
# entry's ref is held to the shape of a URL or a file#index: no spaces.
SAFE_REF = re.compile(r"^[A-Za-z0-9_:./@+#?=&%~-]{1,300}$")
MAX_TEXT = 2000
RECORD, FIELD = "\x1e", "\x1f"


class FeedbackError(Exception):
    """A failure the caller should see as one line, not a traceback."""


# --------------------------------------------------------------------------
# parsing
# --------------------------------------------------------------------------

def feedback_lines(body: str):
    """(target, text) for every Agent-Feedback line in a message or comment."""
    fence = None
    for line in body.splitlines():
        marker = FENCE.match(line)
        if marker:
            ticks = marker.group(1)
            if fence is None:
                fence = ticks[0]
            elif ticks[0] == fence:
                fence = None
            continue
        if fence is not None or line.lstrip().startswith(">"):
            continue
        hit = KEY_LINE.match(line)
        if not hit:
            continue
        value = hit.group(1).strip()
        target, _, rest = value.partition(" ")
        target = target.rstrip(",;:.")
        text = SEPARATOR.sub("", rest.strip()).strip()
        yield target, text[:MAX_TEXT]


def _safe(value: str, shape=SAFE_TOKEN) -> str:
    value = (value or "").strip()
    return value if shape.match(value) else "(not shown)"


# --------------------------------------------------------------------------
# sources
# --------------------------------------------------------------------------

def _git(root: str, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", root, *args], capture_output=True, text=True,
                          encoding="utf-8", errors="replace")


def from_git(root: str, rev: str, since: str | None):
    """One message per commit `rev` reaches, newest first."""
    if _git(root, "rev-parse", "--is-inside-work-tree").returncode != 0:
        raise FeedbackError(f"{root} is not a git repository; pass --no-git to read only --from files")
    if rev == "HEAD" and _git(root, "rev-parse", "--verify", "-q", "HEAD").returncode != 0:
        return  # no commits yet: nothing anyone could have written
    args = ["log", f"--format=%H{FIELD}%ae{FIELD}%cI{FIELD}%B{RECORD}"]
    if since:
        args.append(f"--since={since}")
    args += [rev, "--"]
    done = _git(root, *args)
    if done.returncode != 0:
        raise FeedbackError(f"git log {rev} failed: {done.stderr.strip()}")
    for record in done.stdout.split(RECORD):
        record = record.lstrip("\n")
        if not record:
            continue
        sha, email, date, body = (record.split(FIELD, 3) + ["", "", ""])[:4]
        yield {"ref": f"git:{sha[:12]}", "author": email, "date": date, "body": body}


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
        ref = item.get("url") or item.get("ref") or f"{name}#{index}"
        yield {"ref": str(ref), "author": item["author"], "date": str(item.get("date") or ""),
               "body": item["body"]}


def load_authors(path: str) -> set[str] | None:
    """The listed identities, lowercased; None when there is no list."""
    if not os.path.isfile(path):
        return None
    listed = set()
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            identity = line.split("#", 1)[0].strip().lower()
            if identity:
                listed.add(identity)
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
    unresolved, excluded, seen = [], [], set()
    for message in messages:
        author = message["author"].strip()
        trusted = authors is not None and author.lower() in authors
        for target, text in feedback_lines(message["body"]):
            if not trusted:
                excluded.append({"ref": _safe(message["ref"], SAFE_REF), "author": _safe(author),
                                 "target": _safe(target)})
                continue
            key = (author.lower(), target, text)
            if key in seen:
                continue
            seen.add(key)
            item = {"ref": message["ref"], "author": author, "date": message["date"], "text": text}
            token, path, problem = resolve(graph, target)
            if problem is None and not text:
                problem = "no text: say what went wrong, and why"
            if problem:
                unresolved.append(dict(item, target=target, reason=problem))
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
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(text)
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
