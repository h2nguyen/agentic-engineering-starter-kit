#!/usr/bin/env python3
"""Which kit an install records, what is newer, and whether the record holds.

Run through kit-status.sh, which finds Python. It stays in the kit, like
bootstrap.sh: the comparison needs the kit anyway, and the newer kit is the
one that knows what it ships.

    kit-status.sh [--target <repo>]                    the report
    kit-status.sh [--target <repo>] --record           record this kit, once an upgrade is finished
    kit-status.sh [--target <repo>] --record --as <ref>   record the release an install already has

The record is .starter-kit-version at the root of the target: the kit's last
release, its commit and the agent tool. It is a claim. The files are what is
true, so every run rebuilds what the recorded kit and this kit would install
— each with its own installer, into a scratch directory — and compares the
target's copies of the kit's files with both.

Standard library and git only. Nothing here opens a connection: "available"
is the checkout this script was run from.
"""
import argparse
import fnmatch
import io
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import textwrap

RECORD = ".starter-kit-version"
DECLINE_LIST = ".starter-kit-declined"
KIT_DIR = os.path.dirname(os.path.realpath(__file__))
KIT_ROOT = os.path.dirname(KIT_DIR)
TOOLS = ("claude", "agents", "cursor", "copilot")
MAX_RELEASES = 12
CATEGORIES = ("Added", "Changed", "Deprecated", "Removed", "Fixed", "Security")

RECORD_HEADER = """\
# The starter kit this repository's agent workspace was last brought in line with.
# Written by the kit, not by hand: by bootstrap.sh on a first install, and by
# `kit-status.sh --record` when an upgrade is finished. It is a claim, checked
# against the files by:  make kit-status KIT=<path to a checkout of the kit>
"""


def fail(message, code=2):
    print("ERROR: " + message, file=sys.stderr)
    sys.exit(code)


# --- the kit: its releases and its commits ------------------------------------

def git(*args):
    """git in the kit's checkout: (exit status, stdout as text)."""
    try:
        run = subprocess.run(("git", "-C", KIT_ROOT) + args, stdout=subprocess.PIPE,
                             stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL)
    except OSError:
        return 1, ""
    return run.returncode, run.stdout.decode("utf-8", "replace").strip()


def kit_is_checkout():
    """A bare copy of starter-kit/ inside a project sits in that project's
    repository: its commits are not the kit's."""
    code, top = git("rev-parse", "--show-toplevel")
    return code == 0 and os.path.realpath(top) == os.path.realpath(KIT_ROOT)


def version_key(version):
    numbers = re.findall(r"\d+", version.split("-")[0].split("+")[0])[:3]
    return tuple(int(n) for n in numbers) + (0,) * (3 - len(numbers))


def changelog_sections(text):
    """[(name, date, {category: [bullet, …]})] in file order; name is a
    version or "Unreleased". A bullet is a `- ` line and what continues it."""
    sections, entries, category, bullet = [], None, None, None
    for line in text.splitlines():
        heading = re.match(r"^## \[([^\]]+)\](?:\s*[—–-]\s*(.*))?$", line)
        if heading:
            entries, category, bullet = {}, None, None
            sections.append((heading.group(1), (heading.group(2) or "").strip(), entries))
            continue
        if entries is None:
            continue
        if line.startswith("### "):
            category, bullet = line[4:].strip(), None
            entries.setdefault(category, [])
        elif category and line.startswith("- "):
            entries[category].append(line[2:].strip())
            bullet = len(entries[category]) - 1
        elif category and bullet is not None and line.startswith("  ") and line.strip():
            entries[category][bullet] += " " + line.strip()
        elif not line.strip() or line.startswith("<!--"):
            bullet = None
    return sections


def last_release(text):
    for name, _date, _entries in changelog_sections(text):
        if re.match(r"\d", name):
            return name
    return ""


def is_breaking(bullet):
    return bool(re.match(r"\*\*Breaking\b", bullet, re.I))


# --- the target: its record, its tool, what it declined -----------------------

def read_record(target):
    path = os.path.join(target, RECORD)
    if not os.path.isfile(path):
        return None
    record = {}
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = re.match(r"^([a-z]+):\s*(.*?)\s*$", line)
            if match:
                record.setdefault(match.group(1), match.group(2))
    return record


def write_record(target, version, commit, tool):
    with open(os.path.join(target, RECORD), "w", encoding="utf-8", newline="\n") as handle:
        handle.write(RECORD_HEADER)
        handle.write("version: %s\ncommit: %s\ntool: %s\n" % (version, commit or "unknown", tool))


def detect_tools(target):
    """The tools whose files the target has — the installer's own reading."""
    exists = lambda rel: os.path.exists(os.path.join(target, rel))
    found = []
    if exists(".claude") or exists("CLAUDE.md"):
        found.append("claude")
    cursor = exists(".cursor") or exists(".cursorrules")
    if cursor:
        found.append("cursor")
    if not cursor and exists("AGENTS.md"):
        found.append("agents")
    if exists(".github/copilot-instructions.md"):
        found.append("copilot")
    return found


def declined_paths(target):
    path = os.path.join(target, DECLINE_LIST)
    listed = []
    if os.path.isfile(path):
        with open(path, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                line = line.split("#", 1)[0].strip()
                if line.startswith("./"):
                    line = line[2:]
                if line.rstrip("/"):
                    listed.append(line.rstrip("/"))
    return listed


def is_declined(rel, listed):
    return any(rel == entry or rel.startswith(entry + "/") for entry in listed)


# --- which installed files are the kit's ---------------------------------------

def rules_dir(tool):
    return ".claude/rules" if tool == "claude" else "docs/agent-rules"


def is_rule(rel, tool):
    return os.path.dirname(rel) == rules_dir(tool) and rel.endswith(".md")


def owned(rel, tool):
    """Files that hold nothing of the project: an upgrade replaces them."""
    if is_rule(rel, tool):
        return os.path.basename(rel) != "project-annotations.md"
    patterns = ("scripts/*.py", "scripts/check-*.sh", "scripts/python.sh", "scripts/tests/*",
                "registry.mk", "docs/DEBUGGING-KNOWLEDGE-BASE.d/_template.md",
                "docs/agent-templates/*", "docs/rule-reference/*",
                ".claude/hooks/workspace-graph.py", ".claude/skills/*",
                ".claude/agents/agent-coach.md",
                ".claude/commands/ai-engineering-workspace-audit.md")
    return any(fnmatch.fnmatchcase(rel, pattern) for pattern in patterns)


def yours(rel, tool):
    """Files that are the project's from the day of the install."""
    patterns = ("CLAUDE.md", "AGENTS.md", ".github/copilot-instructions.md", "Makefile",
                "registries.json", "CHANGELOG.md", "docs/DEBUGGING-KNOWLEDGE-BASE.md",
                "changelog.d/*", "docs/DEBUGGING-KNOWLEDGE-BASE.d/README.md", ".gitattributes",
                ".registry-id-duplicate-allowlist", ".ci-lint-coverage-allowlist",
                ".agent-feedback-authors", ".github/workflows/*", ".claude/settings.json",
                rules_dir(tool) + "/project-annotations.md",
                ".claude/workspace-changelog/*", "docs/workspace-changelog/*", RECORD)
    return any(fnmatch.fnmatchcase(rel, pattern) for pattern in patterns)


def has_meta_layer(target):
    return any(os.path.exists(os.path.join(target, rel)) for rel in (
        ".claude/agents/agent-coach.md", ".claude/skills/ai-engineering-workspace-audit",
        ".claude/skills/workspace-graph", ".claude/commands/ai-engineering-workspace-audit.md"))


# --- what a kit would install ---------------------------------------------------

class Workbench:
    """Scratch directory for reference installs, one per kit commit."""

    def __init__(self, tool, with_meta):
        self.tool, self.with_meta = tool, with_meta
        self.root = tempfile.mkdtemp(prefix="kit-status-")
        self.built = {}

    def close(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def _install(self, kit_dir, name):
        dest = os.path.join(self.root, "ref-" + name)
        flag_sets = [["--with-meta"], []] if self.with_meta else [[]]
        for flags in flag_sets:
            shutil.rmtree(dest, ignore_errors=True)
            os.makedirs(dest)
            subprocess.run(("git", "init", "-q", dest), stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL)
            try:
                run = subprocess.run(
                    [os.path.join(kit_dir, "bootstrap.sh"), "--tool", self.tool, "--target", dest] + flags,
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL)
            except OSError:
                continue
            if run.returncode == 0:
                return dest
        return None

    def working_tree(self):
        """What this checkout installs, as it is on disk."""
        if "tree" not in self.built:
            self.built["tree"] = self._install(KIT_DIR, "tree")
        return self.built["tree"]

    def commit(self, sha):
        """What the kit at that commit installed, with that kit's own installer."""
        if sha not in self.built:
            self.built[sha] = None
            code, _ = git("cat-file", "-e", sha + "^{commit}")
            if code == 0:
                export = os.path.join(self.root, "kit-" + sha[:12])
                try:
                    archive = subprocess.run(("git", "-C", KIT_ROOT, "archive", "--format=tar", sha, "starter-kit"),
                                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                             stdin=subprocess.DEVNULL)
                    if archive.returncode == 0:
                        os.makedirs(export)
                        with tarfile.open(fileobj=io.BytesIO(archive.stdout)) as tar:
                            try:
                                tar.extractall(export, filter="data")
                            except TypeError:  # Python before the filter argument
                                tar.extractall(export)
                        self.built[sha] = self._install(os.path.join(export, "starter-kit"), sha[:12])
                except (OSError, tarfile.TarError):
                    pass
        return self.built[sha]


def files_of(root):
    found = []
    for directory, names, files in os.walk(root):
        names[:] = [n for n in names if n not in (".git", "__pycache__")]
        for name in files:
            if not name.endswith(".pyc"):
                found.append(os.path.relpath(os.path.join(directory, name), root).replace(os.sep, "/"))
    return sorted(found)


def content(path, rule):
    """A file's text, with LF line endings: a checkout with CRLF (Git Bash)
    holds the same text. A rule is its text under its header: on Claude Code
    it may carry a `paths:` header the installer or the adopter wrote, which
    is not the kit's. A file with a NUL byte is compared as it is."""
    try:
        with open(path, "rb") as handle:
            data = handle.read()
    except OSError:
        return None
    if b"\0" in data:
        return data
    data = data.replace(b"\r\n", b"\n")
    if not rule:
        return data
    lines = data.split(b"\n")
    if lines and lines[0] == b"---" and b"---" in lines[1:]:
        lines = lines[lines.index(b"---", 1) + 1:]
        if lines and lines[0] == b"":
            lines = lines[1:]
    return b"\n".join(lines)


def same(target, reference, rel, tool):
    if reference is None:
        return False
    rule = is_rule(rel, tool)
    theirs = content(os.path.join(target, rel), rule)
    return theirs is not None and theirs == content(os.path.join(reference, rel), rule)


def owned_files(reference, tool):
    return [rel for rel in files_of(reference) if owned(rel, tool)]


def releases():
    """[(tag, commit)] newest first: the kit's version tags in this checkout."""
    code, out = git("for-each-ref", "--format=%(refname:short)", "refs/tags/v[0-9]*")
    tags = []
    for tag in out.splitlines() if code == 0 else []:
        code, commit = git("rev-parse", tag + "^{commit}")
        if code == 0 and re.match(r"^v\d+\.\d+\.\d+$", tag):
            tags.append((tag, commit))
    tags.sort(key=lambda pair: version_key(pair[0]), reverse=True)
    return tags[:MAX_RELEASES]


def closest_release(bench, target, tool):
    """(tag, commit, matching, compared) of the release the target's copies
    of the kit's files agree with most: files that are its text, less files
    it ships that are another text here. The newest wins a tie. Advisory —
    what may be recorded is decided file by file, by another_releases."""
    best, best_points = None, None
    for tag, commit in releases():
        reference = bench.commit(commit)
        if reference is None:
            continue
        present = [rel for rel in owned_files(reference, tool) if os.path.exists(os.path.join(target, rel))]
        matching = sum(1 for rel in present if same(target, reference, rel, tool))
        points = matching - (len(present) - matching)
        if present and (best_points is None or points > best_points):
            best, best_points = (tag, commit, matching, len(present)), points
    return best


def most_common(found):
    """The release most of those files are the text of; the newest on a tie."""
    tags = list(found.values())
    return max(sorted(set(tags), key=version_key), key=tags.count)


def another_releases(bench, target, tool, paths, skip=()):
    """{path: tag} for the files that are, byte for byte, what a release of
    the kit shipped: not changed here, only not upgraded. `skip` are commits
    whose text does not count — the kit being compared with."""
    found = {}
    for tag, commit in releases():
        if commit in skip:
            continue
        reference = bench.commit(commit)
        if reference is None:
            continue
        for rel in paths:
            if rel not in found and same(target, reference, rel, tool):
                found[rel] = tag
    return found


# --- the comparison ---------------------------------------------------------------

def classify(target, tool, available, recorded, listed, verifiable=True):
    """Every file of the kit's, in one class. Without the recorded kit to
    compare with (`verifiable` false), a file that is not this kit's cannot
    be told apart as older or the adopter's, and is said to differ."""
    classes = {"current": [], "older": [], "changed": [], "differs": [], "missing": [], "declined": [],
               "retired": [], "unclassified": [], "ahead": []}
    for rel in files_of(available):
        if not owned(rel, tool):
            if not yours(rel, tool):
                classes["unclassified"].append(rel)
            continue
        if not os.path.exists(os.path.join(target, rel)):
            classes["declined" if is_declined(rel, listed) else "missing"].append(rel)
        elif same(target, available, rel, tool):
            classes["current"].append(rel)
            # Already the available kit's where the recorded one had another text.
            if recorded and recorded != available and not same(target, recorded, rel, tool):
                classes["ahead"].append(rel)
        elif recorded and recorded != available and same(target, recorded, rel, tool):
            classes["older"].append(rel)
        elif not verifiable:
            classes["differs"].append(rel)
        else:
            classes["changed"].append(rel)
    if recorded and recorded != available:
        shipped = set(files_of(available))
        for rel in files_of(recorded):
            if owned(rel, tool) and rel not in shipped and os.path.exists(os.path.join(target, rel)):
                classes["retired"].append(rel)
    return classes


def describe(commit):
    """`3 commits after v3.0.1`, where the checkout can say."""
    code, out = git("describe", "--tags", "--match", "v[0-9]*", commit)
    match = re.match(r"^(v[\d.]+)-(\d+)-g[0-9a-f]+$", out) if code == 0 else None
    if match:
        return "%s commit%s after %s" % (match.group(2), "" if match.group(2) == "1" else "s", match.group(1))
    return "release " + out if code == 0 and out else ""


def print_changes(text, after, upto, unreleased):
    shown = False
    for name, date, entries in changelog_sections(text):
        if name == "Unreleased":
            if not unreleased or not any(entries.values()):
                continue
            title = "[Unreleased] — not in a release yet"
        elif version_key(after) < version_key(name) <= version_key(upto):
            title = "[%s]%s" % (name, " — " + date if date else "")
        else:
            continue
        if not shown:
            print("\nWhat changed in between (the kit's CHANGELOG.md):")
            shown = True
        print("\n  " + title)
        wrap = lambda prefix, bullet: print(textwrap.fill(
            bullet, width=100, initial_indent="      " + prefix, subsequent_indent="        ",
            break_long_words=False, break_on_hyphens=False))
        breaking = [b for bullets in entries.values() for b in bullets if is_breaking(b)]
        for bullet in breaking:
            wrap("! BREAKING — ", re.sub(r"^\*\*Breaking\b[^*]*\*\*\s*", "", bullet, flags=re.I) or bullet)
        ordered = [c for c in CATEGORIES if c in entries] + [c for c in entries if c not in CATEGORIES]
        for category in ordered:
            rest = [b for b in entries[category] if not is_breaking(b)]
            if rest:
                print("    %s:" % category)
                for bullet in rest:
                    wrap("- ", bullet)
    return shown


def list_class(title, note, paths):
    if paths:
        print("  %s (%d) — %s" % (title, len(paths), note))
        for rel in paths:
            print("    " + rel)


def resolve_tool(args, target, record):
    if args.tool:
        return args.tool
    if record and record.get("tool") in TOOLS:
        return record["tool"]
    found = detect_tools(target)
    if len(found) == 1:
        return found[0]
    if not found:
        fail("%s has no agent tool's files and no record: is this the repository the kit was installed "
             "into? Name the tool with --tool %s." % (target, "|".join(TOOLS)))
    fail("%s has the files of more than one agent tool (%s) and no record names the one the kit was "
         "installed for. Say which: --tool <tool>." % (target, ", ".join(found)))


def main():
    parser = argparse.ArgumentParser(prog="kit-status.sh", description=__doc__.split("\n\n")[0])
    parser.add_argument("--target", default=".", help="the repository the kit was installed into (default: here)")
    parser.add_argument("--tool", choices=TOOLS, help="the agent tool, where neither the record nor the files say")
    parser.add_argument("--record", action="store_true", help="write the record, if the files bear it out")
    parser.add_argument("--as", dest="ref", metavar="REF", help="with --record: a release tag or commit of the kit")
    args = parser.parse_args()
    if args.ref and not args.record:
        fail("--as says which kit to record; it goes with --record.")
    target = os.path.realpath(args.target)
    if not os.path.isdir(target):
        fail("%s is not a directory." % args.target)
    if os.path.realpath(target) == os.path.realpath(KIT_ROOT):
        fail("this is the starter kit's own repository, which applies the kit by reference and has no "
             "install to compare. Name a project: --target /path/to/your-repo")
    changelog_path = os.path.join(KIT_ROOT, "CHANGELOG.md")
    if not os.path.isfile(changelog_path):
        fail("%s is a copy of starter-kit/ without the kit's CHANGELOG.md beside it, so it cannot say "
             "which release it is. Run this from a checkout of the kit." % KIT_DIR)
    with open(changelog_path, encoding="utf-8") as handle:
        changelog = handle.read()

    record = read_record(target)
    tool = resolve_tool(args, target, record)
    checkout = kit_is_checkout()
    head = git("rev-parse", "HEAD")[1] if checkout else ""
    dirty = bool(checkout and git("status", "--porcelain", "--", "starter-kit")[1])
    available_version = last_release(changelog)
    listed = declined_paths(target)
    bench = Workbench(tool, tool == "claude" and has_meta_layer(target))
    try:
        available = bench.working_tree()
        if available is None:
            fail("this kit's installer could not build a reference install for --tool %s." % tool)
        if args.record:
            return record_it(args, target, tool, record, bench, available, available_version, head, dirty,
                             checkout, listed)
        return report(target, tool, record, bench, available, available_version, head, dirty, checkout,
                      listed, changelog)
    finally:
        bench.close()


def reference_for(bench, commit, head, dirty, available):
    """The reference install of a recorded commit, or None when this checkout
    does not have that commit."""
    if not commit or commit == "unknown":
        return None
    if commit == head:
        return available  # uncommitted changes in the kit are said in the report, not modelled
    return bench.commit(commit)


def report(target, tool, record, bench, available, available_version, head, dirty, checkout, listed, changelog):
    print("=== kit status: %s (%s) ===" % (target, tool))
    recorded, base_version, base_commit, guessed = None, "", "", None
    if record:
        base_version, base_commit = record.get("version", ""), record.get("commit", "")
        recorded = reference_for(bench, base_commit, head, dirty, available) if checkout else None
        where = describe(base_commit) if recorded else ""
        print("Recorded:  %s (commit %s%s) — from %s" % (
            base_version or "?", base_commit[:12] or "unknown", ", " + where if where else "", RECORD))
    else:
        print("Recorded:  no record — %s is not in this repository." % RECORD)
    print("Available: %s (%s) — %s" % (
        available_version or "?",
        ("commit " + head[:12] + (", " + describe(head) if describe(head) else "")
         + (", with uncommitted changes" if dirty else "")) if head else "not a git checkout", KIT_ROOT))

    classes = classify(target, tool, available, recorded, listed)

    # What the files themselves say. Asked where nothing vouches for them: no
    # record, or files that are neither the recorded kit's nor this one's.
    holds = True
    if record is None:
        guessed = closest_release(bench, target, tool) if checkout else None
        if guessed:
            base_version, base_commit = guessed[0].lstrip("v"), guessed[1]
            recorded = reference_for(bench, base_commit, head, dirty, available)
            classes = classify(target, tool, available, recorded, listed)
            print("\nNo record: an install from a kit that wrote none, or the file was removed. By its files,")
            print("this install is closest to release %s: %d of the %d files that release ships are its text here." % (
                guessed[0], guessed[2], guessed[3]))
            print("To record that, from the root of this repository:")
            print("    %s --record --as %s" % (os.path.join(KIT_DIR, "kit-status.sh"), guessed[0]))
            print("or finish the upgrade steps below and record this kit with --record alone.")
        else:
            print("\nNo record, and this kit has no release tags to compare the files with (not a git")
            print("checkout, or a shallow one). After the upgrade steps, --record writes the record.")
    elif recorded is None:
        holds = None
        classes = classify(target, tool, available, None, listed, verifiable=False)
        print("\nThe record cannot be checked here: commit %s is not in this kit checkout%s." % (
            base_commit[:12] or "unknown",
            "" if checkout else " (it is not a git checkout)"))
        print("Fetch the kit's history (git -C %s fetch --tags), or compare below with this kit alone." % KIT_ROOT)
    elif classes["changed"]:
        foreign = another_releases(bench, target, tool, classes["changed"], skip=(base_commit, head))
        if foreign:
            holds = False
            tags = sorted(set(foreign.values()), key=version_key, reverse=True)
            print("\nThe record does not hold: it names %s, but %d of the kit's files here are the text of" % (
                base_version, len(foreign)))
            print("another release (%s) — not changed here, only not that kit's. Either the files were" % ", ".join(tags))
            print("reverted or the record was edited. To record what the files are:")
            print("    %s --record --as %s" % (os.path.join(KIT_DIR, "kit-status.sh"), most_common(foreign)))
            for rel in sorted(foreign):
                print("    %s — %s" % (rel, foreign[rel]))
    differing = classes["older"] + classes["changed"] + classes["differs"]
    if dirty:
        print("\nNote: this kit checkout has uncommitted changes under starter-kit/. \"This kit\" below is the")
        print("checkout as it is on disk, not its commit.")

    same_kit = bool(base_commit) and base_commit == head
    older_kit = bool(base_version and available_version) and (
        version_key(available_version) < version_key(base_version)
        or (checkout and base_commit and base_commit != head
            and git("merge-base", "--is-ancestor", head, base_commit)[0] == 0))
    print("")
    if holds is False:
        print("Verdict: the record is not borne out by the files — see above. Nothing else here is reliable")
        print("until it is: the changelog below starts from the release the record names.")
    elif older_kit:
        print("Verdict: this kit checkout is OLDER than what the repository records. Update the checkout")
        print("(git -C %s pull), then run this again." % KIT_ROOT)
    elif (same_kit or (recorded is not None and not classes["ahead"] and base_version == available_version)) \
            and not classes["older"] and not classes["missing"] and not classes["differs"]:
        print("Verdict: up to date — this repository records the kit you are comparing with.")
    elif same_kit:
        print("Verdict: this repository records the kit you are comparing with, but not all of its files are")
        print("that kit's: see 'missing' and 'older kit's' below. The installer adds what is missing.")
    elif classes["ahead"] and classes["older"]:
        print("Verdict: PARTIAL upgrade — %d of the kit's files here are already this kit's, %d are still the" % (
            len(classes["ahead"]), len(classes["older"])))
        print("recorded kit's. The record still says %s, which is right until the upgrade is finished." % base_version)
    else:
        if base_version and base_version == available_version:
            print("Verdict: a newer kit is available — changes made after release %s, not in a release yet." % base_version)
        else:
            print("Verdict: a newer kit is available — %s → %s." % (base_version or "?", available_version or "?"))

    if not same_kit and not older_kit and base_version:
        code, tagged = git("describe", "--tags", "--exact-match", "--match", "v[0-9]*", base_commit) if base_commit else (1, "")
        shown = print_changes(changelog, base_version, available_version, unreleased=True)
        if shown and checkout and base_commit and code != 0 and record:
            print("\n  (The recorded commit is not a release: entries above that were merged before it are")
            print("  already in this install.)")

    print("\nThe kit's files in this repository, compared with this kit:")
    print("  current (%d)" % len(classes["current"]))
    list_class("older kit's", "as the recorded kit shipped them; the upgrade steps replace these", classes["older"])
    list_class("changed here", "neither kit's text: yours to merge by hand, or to keep", classes["changed"])
    list_class("differs", "not this kit's text; without the recorded kit, not known to be yours or older", classes["differs"])
    list_class("missing", "the installer adds these, unless you list them in " + DECLINE_LIST, classes["missing"])
    list_class("declined", "listed in " + DECLINE_LIST, classes["declined"])
    list_class("retired", "the recorded kit shipped these and this one does not", classes["retired"])
    list_class("unclassified", "a defect in the kit: tell its maintainers", classes["unclassified"])

    if not older_kit and (classes["missing"] or (not same_kit and (differing or holds is False or record is None))):
        print("\nNext: the steps under 'Upgrading an existing install' in %s," % os.path.join(KIT_DIR, "README.md"))
        print("then  %s --record  — it writes the record once no file is still the older kit's." % (
            os.path.join(KIT_DIR, "kit-status.sh")))
    return 0


def record_it(args, target, tool, record, bench, available, available_version, head, dirty, checkout, listed):
    if args.ref:
        if not checkout:
            fail("--as needs the kit's history, and %s is not a git checkout of the kit." % KIT_ROOT)
        code, commit = git("rev-parse", "--verify", "--quiet", args.ref + "^{commit}")
        if code != 0:
            fail("this kit checkout has no tag or commit named '%s'. Its releases: %s" % (
                args.ref, ", ".join(tag for tag, _ in releases()) or "none"))
        code, text = git("show", commit + ":CHANGELOG.md")
        version = last_release(text) if code == 0 else ""
        new = reference_for(bench, commit, head, dirty, available)
        if new is None or not version:
            fail("the kit at %s could not be rebuilt for --tool %s: its installer failed, or it has no "
                 "released version in its changelog." % (args.ref, tool))
    else:
        commit, version, new = head, available_version, available
        if not version:
            fail("this kit's CHANGELOG.md names no release.")
    classes = classify(target, tool, new, None, listed)
    label = "%s (commit %s)" % (version, commit[:12] if commit else "unknown")
    problems = False
    # A file that is not this kit's is either the adopter's own change or
    # simply another release's text. The kit's history tells the two apart.
    foreign = another_releases(bench, target, tool, classes["changed"], skip=(commit,)) if checkout else {}
    if foreign:
        problems = True
        print("Not recorded: %d of the kit's files here are the text of another release, not of" % len(foreign))
        print("%s. Bring them over (upgrade steps 2 and 3), or, to record the release" % label)
        print("most of them are:  %s --record --as %s" % (
            os.path.join(KIT_DIR, "kit-status.sh"), most_common(foreign)))
        for rel in sorted(foreign):
            print("    %s — %s" % (rel, foreign[rel]))
    if classes["missing"]:
        problems = True
        print("Not recorded: %s installs %d file(s) that are not here. Run its installer (step 1), or list" % (
            label, len(classes["missing"])))
        print("a path in %s if you left it out on purpose:" % DECLINE_LIST)
        for rel in classes["missing"]:
            print("    " + rel)
    if problems:
        return 1
    write_record(target, version, commit, tool)
    print("Recorded in %s: kit %s, tool %s." % (RECORD, label, tool))
    if dirty and not args.ref:
        print("Note: this kit checkout has uncommitted changes under starter-kit/; the record names the commit.")
    if classes["changed"]:
        print("Accepted as changed here — not the kit's text, and reported as such from now on:")
        for rel in classes["changed"]:
            print("    " + rel)
    if classes["declined"]:
        print("Left out, as %s says: %s" % (DECLINE_LIST, ", ".join(classes["declined"])))
    print("Commit %s with the upgrade." % RECORD)
    return 0


if __name__ == "__main__":
    sys.exit(main())
