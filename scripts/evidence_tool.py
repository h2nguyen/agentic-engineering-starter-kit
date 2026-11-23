#!/usr/bin/env python3
"""Evidence generator — what this repository can show about running on its kit.

A kit that tells other projects how to work with agents should be able to show
what happened when its own repository worked that way. This tool computes that
from the repository and nothing else — its files at one commit and its git
history up to that commit — and writes docs/EVIDENCE.md.

Repository-only: it reads this repository's layout, so bootstrap.sh does not
install it.

The file is stamped with the commit it was computed at. `check` recomputes
every number at that same commit and fails if the file says anything else, so
a number cannot be edited by hand, and anyone with a clone can reproduce it.
Commits made after the stamp leave the file older, never wrong: it says what
was true at its commit, and the check reports how far behind it is.

Everything is measured in an export of the stamped commit, so the working
tree — and whatever is uncommitted in it — plays no part. Git writes the
export itself, and a symbolic link is read from git's tree, not from the file
system: what a checkout or an unpacked archive makes of a link differs between
platforms and between Python versions, and a number that depends on the
machine it is computed on cannot be recomputed by anyone else.

What it does not claim is in the file itself: one repository, no control
group. The numbers show that the loop runs here, not that the kit causes them.

Stdlib only; the feedback and graph tools it reuses are the kit's own.

  evidence_tool.py generate     write docs/EVIDENCE.md as of HEAD
  evidence_tool.py check        recompute at the stamped commit and compare
"""

from __future__ import annotations

import argparse
import difflib
import json
import os
import re
import statistics
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
KIT_SCRIPTS = os.path.join(os.path.dirname(HERE), "starter-kit", "scripts")
sys.dont_write_bytecode = True
for _path in (KIT_SCRIPTS,):
    if _path not in sys.path:
        sys.path.insert(0, _path)
import feedback_tool as ft  # noqa: E402
import graph_tool as gt  # noqa: E402

OUTPUT = os.path.join("docs", "EVIDENCE.md")
STAMP = re.compile(r"^<!-- evidence: as of ([0-9a-f]{40}) ")
MERGE_SUBJECT = re.compile(r"^Merge pull request #(\d+) ")
CHANGE_TITLE = re.compile(r"^(feat|fix)(\(|:|!)")
AGENT_TRAILER = re.compile(r"^Co-Authored-By:.*<noreply@anthropic\.com>\s*$", re.IGNORECASE | re.MULTILINE)
RULE_DIRS = (".claude/rules",)
WORKSPACE_LOG = ".claude/workspace-changelog"
DAY = 86400


class EvidenceError(Exception):
    """A failure the caller should see as one line."""


# --------------------------------------------------------------------------
# git
# --------------------------------------------------------------------------

def git(root: str, *args: str, check: bool = True) -> str:
    done = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True,
                          encoding="utf-8", errors="replace")
    if check and done.returncode != 0:
        raise EvidenceError(f"git {' '.join(args)} failed: {done.stderr.strip()}")
    return done.stdout


def export(root: str, commit: str, into: str) -> None:
    """The tree of `commit`, written into `into` by git: what was committed, nothing else.

    Through an index of its own, so neither the repository's index nor its
    working tree is touched.
    """
    with tempfile.TemporaryDirectory() as scratch:
        env = dict(os.environ, GIT_INDEX_FILE=os.path.join(scratch, "index"))
        for args in (["read-tree", commit],
                     ["checkout-index", "--all", "--force", f"--prefix={into.rstrip(os.sep)}{os.sep}"]):
            done = subprocess.run(["git", "-C", root, *args], env=env, capture_output=True, text=True,
                                  encoding="utf-8", errors="replace")
            if done.returncode != 0:
                raise EvidenceError(f"git {args[0]} {commit} failed: {done.stderr.strip()}")


def links_at(root: str, commit: str) -> dict[str, str]:
    """Every symbolic link in the tree of `commit`: its path → the path it points at."""
    links = {}
    for entry in git(root, "ls-tree", "-r", "-z", commit).split("\0"):
        meta, _, path = entry.partition("\t")
        fields = meta.split()
        if len(fields) == 3 and fields[0] == "120000":
            target = git(root, "cat-file", "-p", fields[2])
            links[path] = os.path.normpath(os.path.join(os.path.dirname(path), target)).replace(os.sep, "/")
    return links


# --------------------------------------------------------------------------
# what is measured
# --------------------------------------------------------------------------

def _read(path: str) -> str:
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""


def _lines(path: str) -> int:
    return len(_read(path).splitlines())


def _files(directory: str, keep) -> list[str]:
    if not os.path.isdir(directory):
        return []
    return sorted(name for name in os.listdir(directory) if keep(name))


def measure_tree(tree: str, links: dict[str, str]) -> dict:
    data: dict = {}
    lint = re.search(r"^lint:(.*)$", _read(os.path.join(tree, "Makefile")), re.MULTILINE)
    data["gates"] = [t for t in (lint.group(1).split() if lint else []) if t != "test"]

    suites, python_tests = 0, 0
    for directory in ("starter-kit/scripts/tests", "scripts/tests"):
        for name in _files(os.path.join(tree, directory), lambda n: n.startswith("test")):
            suites += 1
            if name.endswith(".py"):
                python_tests += len(re.findall(r"^\s*def test_", _read(os.path.join(tree, directory, name)), re.MULTILINE))
    data["suites"], data["python_tests"] = suites, python_tests

    data["decision_records"] = len(_files(os.path.join(tree, "docs", "adr"), lambda n: n.endswith(".md")))
    data["releases"] = len(re.findall(r"^## \[\d", _read(os.path.join(tree, "CHANGELOG.md")), re.MULTILINE))
    data["unreleased_fragments"] = len(_files(os.path.join(tree, "changelog.d"),
                                              lambda n: n.endswith(".md") and n != "README.md"))

    applied_under = tuple(f".claude/{kind}/" for kind in ("rules", "skills", "agents", "commands"))
    data["applied_by_reference"] = sum(
        1 for path in links if path.startswith(applied_under) and path.count("/") == 2)

    loaded = _lines(os.path.join(tree, "AGENTS.md")) + _lines(os.path.join(tree, "CLAUDE.md"))
    for directory in RULE_DIRS:
        for name in _files(os.path.join(tree, directory), lambda n: n.endswith(".md")):
            path = f"{directory}/{name}"
            loaded += _lines(os.path.join(tree, links.get(path, path)))   # a link is read through, by its target in git
    data["always_loaded_lines"] = loaded

    runs = _files(os.path.join(tree, WORKSPACE_LOG), lambda n: n.endswith(".md") and n != "README.md")
    cycles, approved, rejected = 0, 0, 0
    for name in runs:
        text = _read(os.path.join(tree, WORKSPACE_LOG, name))
        if "agent-coach cycle" in (text.splitlines() or [""])[0]:
            cycles += 1
            approved += len(re.findall(r"\|\s*approved\s*\|", text))
            rejected += len(re.findall(r"\|\s*rejected\s*\|", text))
    data["workspace_runs"], data["coach_cycles"] = len(runs), cycles
    data["proposals_approved"], data["proposals_rejected"] = approved, rejected
    data["digest_workflow"] = os.path.isfile(os.path.join(tree, ".github", "workflows", "agent-feedback.yml"))
    return data


def measure_history(root: str, commit: str) -> dict:
    data: dict = {}
    first, last = None, None
    commits, with_agent = 0, 0
    log = git(root, "log", "--no-merges", "--format=%ct%x1f%B%x1e", commit)
    for record in log.split("\x1e"):
        record = record.strip("\n")
        if not record:
            continue
        stamp, _, body = record.partition("\x1f")
        commits += 1
        with_agent += 1 if AGENT_TRAILER.search(body) else 0
        when = int(stamp)
        first = when if first is None else min(first, when)
        last = when if last is None else max(last, when)
    data["commits"], data["commits_with_agent"] = commits, with_agent
    data["days_of_history"] = round(((last or 0) - (first or 0)) / DAY)

    merged, change, with_fragment, with_tests = 0, 0, 0, 0
    for line in git(root, "log", "--first-parent", "--merges", "--format=%H%x1f%s", commit).splitlines():
        sha, _, subject = line.partition("\x1f")
        if not MERGE_SUBJECT.match(subject):
            continue
        merged += 1
        body = git(root, "log", "-1", "--format=%b", sha).strip().splitlines()
        title = body[0] if body else ""
        if not CHANGE_TITLE.match(title):
            continue
        change += 1
        added = git(root, "diff", "--name-only", "--diff-filter=A", f"{sha}^1", sha).splitlines()
        touched = git(root, "diff", "--name-only", f"{sha}^1", sha).splitlines()
        if any(p.startswith("changelog.d/") and not p.endswith("README.md") for p in added):
            with_fragment += 1
        if any("/tests/" in p for p in touched):
            with_tests += 1
    data["merged_prs"], data["change_prs"] = merged, change
    data["change_prs_with_fragment"], data["change_prs_with_tests"] = with_fragment, with_tests
    return data


def measure_feedback(root: str, commit: str, tree: str) -> dict:
    """The feedback loop: points from listed authors, and whether the artifact changed afterwards."""
    data = {"feedback_points": 0, "feedback_artifacts": 0, "feedback_unresolved": 0, "feedback_excluded": 0,
            "feedback_acted_on": 0, "feedback_days_median": None}
    config = os.path.join(tree, "registries.json")
    if not os.path.isfile(config):
        return data
    graph = gt.load_graph(config)
    authors = ft.load_authors(os.path.join(tree, ft.AUTHORS_FILE))
    report = ft.collect(graph, list(ft.from_git(root, commit, None)), authors)
    data["feedback_points"] = report["counts"]["accepted"]
    data["feedback_artifacts"] = len(report["targets"])
    data["feedback_unresolved"] = report["counts"]["unresolved"]
    data["feedback_excluded"] = report["counts"]["excluded"]

    days = []
    for group in report["targets"]:
        for item in group["items"]:
            shas = [ref[4:] for ref in item["refs"] if ref.startswith("git:")]
            if not shas:
                continue
            made = min((int(git(root, "log", "-1", "--format=%ct", sha)), sha) for sha in shas)
            when, sha = made
            # Changed in the commit that carries the point, or in one after it.
            same = git(root, "diff-tree", "--no-commit-id", "--name-only", "-r", sha, "--", group["path"]).strip()
            later = git(root, "log", "--format=%ct", "--ancestry-path", f"{sha}..{commit}", "--", group["path"]).split()
            if same:
                days.append(0.0)
            elif later:
                days.append((min(int(t) for t in later) - when) / DAY)
    data["feedback_acted_on"] = len(days)
    data["feedback_days_median"] = round(statistics.median(days), 1) if days else None
    return data


def measure(root: str, commit: str) -> dict:
    with tempfile.TemporaryDirectory() as tree:
        export(root, commit, tree)
        data = measure_tree(tree, links_at(root, commit))
        data.update(measure_feedback(root, commit, tree))
    data.update(measure_history(root, commit))
    data["commit"] = commit
    data["commit_date"] = git(root, "log", "-1", "--format=%cs", commit).strip()
    return data


# --------------------------------------------------------------------------
# the file
# --------------------------------------------------------------------------

def _share(part: int, whole: int) -> str:
    return f"{part} of {whole}" if whole else "none yet"


def render(d: dict) -> str:
    median = "—" if d["feedback_days_median"] is None else f"{d['feedback_days_median']:g} days"
    rows = lambda pairs: "\n".join(f"| {name} | {value} | {how} |" for name, value, how in pairs)  # noqa: E731
    head = "| Measure | Value | How it is counted |\n|---|---|---|\n"
    return f"""<!-- evidence: as of {d['commit']} — generated by scripts/evidence_tool.py; do not edit, run `make evidence` -->
# Evidence: this repository under its own kit

As of commit `{d['commit'][:7]}` ({d['commit_date']}). Every number here is
computed by `scripts/evidence_tool.py` from this repository alone: its files
at that commit and its git history up to it. `make lint` recomputes them at
that commit and fails if this file says anything else, so no number is typed
by hand, and anyone with a clone can reproduce them with `make evidence-check`.

## What this shows, and what it does not

This is one repository, measured against itself, with no control group. The
numbers show that the kit's loop runs here — gates hold, changes carry their
record, feedback reaches the artifact it names. They do not show that the kit
caused any of it, or what the same team would have done without it. A zero is
a zero: the feedback loop is new, and it says so below until it has turned.

Commits made after the one above are not counted. The file is then older, not
wrong; `make evidence` brings it up to date.

## Guardrails

{head}{rows([
    ("Gates in `make lint`", len(d["gates"]), "Prerequisites of the `lint:` target, the test target excepted: " + ", ".join(f"`{g}`" for g in d["gates"])),
    ("Test suites", d["suites"], "Files named `test*` in `starter-kit/scripts/tests/` and `scripts/tests/`"),
    ("Python test functions", d["python_tests"], "`def test_…` in those suites; the shell suites assert in loops and are counted as suites only"),
])}

Whether CI ran these is not in git: see the
[runs of the lint workflow](https://github.com/h2nguyen/agentic-engineering-starter-kit/actions/workflows/lint.yml).

## The record of change

{head}{rows([
    ("Decision records", d["decision_records"], "Files in `docs/adr/`"),
    ("Releases", d["releases"], "Version headings in `CHANGELOG.md`"),
    ("Changelog fragments not yet released", d["unreleased_fragments"], "Files in `changelog.d/`, its README excepted"),
    ("Pull requests merged", d["merged_prs"], "Merge commits on the first-parent line whose subject is `Merge pull request #N`"),
    ("Changes that carry a changelog fragment", _share(d["change_prs_with_fragment"], d["change_prs"]), "Of the merged pull requests titled `feat` or `fix`: those that add a file under `changelog.d/`"),
    ("Changes that touch a test suite", _share(d["change_prs_with_tests"], d["change_prs"]), "Of the same pull requests: those that change a file under a `tests/` directory"),
])}

## The kit applied to itself

{head}{rows([
    ("Kit artifacts applied by reference", d["applied_by_reference"], "Symbolic links under `.claude/rules`, `skills`, `agents` and `commands`, each into `starter-kit/` (ADR-0022)"),
    ("Lines loaded into every session", d["always_loaded_lines"], "`AGENTS.md`, `CLAUDE.md` and every rule under `.claude/rules/` — what the harness costs each session here"),
    ("Commits co-authored by an AI agent", _share(d["commits_with_agent"], d["commits"]), "Non-merge commits with a `Co-Authored-By` trailer of an agent, over " + str(d["days_of_history"]) + " days of history"),
])}

## The feedback loop

{head}{rows([
    ("Feedback points from listed authors", d["feedback_points"], "`Agent-Feedback:` lines in commit messages, as `make agent-feedback` reads them, by authors in `.agent-feedback-authors`"),
    ("Artifacts they name", d["feedback_artifacts"], "Distinct rules, skills, agents or commands"),
    ("Acted on", _share(d["feedback_acted_on"], d["feedback_points"]), "Points whose artifact was changed in the commit that carries the point, or in a later one"),
    ("Median time to that change", median, "From the commit that carries the point to the first later commit that changes the artifact"),
    ("Unresolved", d["feedback_unresolved"], "Points whose token names no artifact, or that say nothing"),
    ("Lines from authors not listed", d["feedback_excluded"], "Counted; their text is never read"),
    ("Workspace runs recorded", d["workspace_runs"], "Files in `.claude/workspace-changelog/`, its README excepted"),
    ("Coach cycles", d["coach_cycles"], "Of those, files headed `agent-coach cycle`"),
    ("Coach proposals approved / rejected", f"{d['proposals_approved']} / {d['proposals_rejected']}", "Rows marked so in those files"),
    ("Weekly digest workflow", "on" if d["digest_workflow"] else "off", "`.github/workflows/agent-feedback.yml` exists"),
])}
"""


def stamped_commit(text: str) -> str | None:
    hit = STAMP.match(text)
    return hit.group(1) if hit else None


# --------------------------------------------------------------------------
# commands
# --------------------------------------------------------------------------

def repository() -> str:
    done = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if done.returncode != 0:
        raise EvidenceError("not inside a git repository")
    return done.stdout.strip()


def cmd_generate(root: str) -> int:
    head = git(root, "rev-parse", "HEAD").strip()
    path = os.path.join(root, OUTPUT)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(render(measure(root, head)))
    print(f"wrote {OUTPUT} as of {head[:7]} — commit it; the commit that adds it is not counted in it")
    return 0


def cmd_check(root: str) -> int:
    path = os.path.join(root, OUTPUT)
    if not os.path.isfile(path):
        print(f"FAIL: {OUTPUT} does not exist. Create it:  make evidence", file=sys.stderr)
        return 1
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    commit = stamped_commit(text)
    if commit is None:
        print(f"FAIL: {OUTPUT} has no 'evidence: as of <commit>' stamp on its first line. "
              "It is generated, never written by hand:  make evidence", file=sys.stderr)
        return 1
    known = subprocess.run(["git", "-C", root, "cat-file", "-e", f"{commit}^{{commit}}"],
                           capture_output=True).returncode == 0
    ancestor = known and subprocess.run(["git", "-C", root, "merge-base", "--is-ancestor", commit, "HEAD"],
                                        capture_output=True).returncode == 0
    if not ancestor:
        if git(root, "rev-parse", "--is-shallow-repository").strip() == "true":
            print(f"OK: {OUTPUT} is stamped {commit[:7]}, which this shallow clone does not hold — "
                  "not verified here; CI, with the full history, verifies it")
            return 0
        print(f"FAIL: {OUTPUT} was computed at {commit[:7]}, which is not in this repository's history.\n"
              "      Evidence from a commit nobody can check is not evidence. Regenerate:  make evidence",
              file=sys.stderr)
        return 1
    expected = render(measure(root, commit))
    if expected != text:
        print(f"FAIL: {OUTPUT} does not say what the repository says at {commit[:7]}.\n"
              "      It is generated, never edited by hand — and a change to scripts/evidence_tool.py\n"
              "      changes what it measures. Regenerate and commit:  make evidence\n"
              "      The lines that differ (- the file, + the repository):", file=sys.stderr)
        diff = difflib.unified_diff(text.splitlines(), expected.splitlines(), lineterm="", n=0)
        for line in list(diff)[2:]:
            if not line.startswith("@@"):
                print("      " + line[:200], file=sys.stderr)
        return 1
    behind = git(root, "rev-list", "--count", f"{commit}..HEAD").strip()
    print(f"OK: {OUTPUT} reproduces at {commit[:7]}, {behind} commit(s) behind HEAD")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="evidence_tool.py", description=__doc__.splitlines()[0])
    parser.add_argument("command", choices=("generate", "check"))
    args = parser.parse_args(argv)
    try:
        root = repository()
        return cmd_generate(root) if args.command == "generate" else cmd_check(root)
    except (EvidenceError, ft.FeedbackError, gt.GraphError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
