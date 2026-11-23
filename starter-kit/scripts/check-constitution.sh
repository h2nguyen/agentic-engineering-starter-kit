#!/usr/bin/env bash
# Enforces: RULE:documentation § What to update when — the constitution names
# only files that exist, and carries no template placeholder nobody filled in.
#
# Why this exists: a constitution was installed, filled in, and committed with
# two links to rule files that had never been written and one placeholder line
# from the template — and `make lint` was green. The typed-link gate resolves
# `Related:` / `Enforces:` / `Hands off to:` lines; it does not read ordinary
# Markdown links, and nothing read the placeholders. The file every session
# loads first was the one file no gate opened.
#
# Two checks, on the constitution and on the one file a project fills in
# beside its rules — project-annotations.md, the project's half of the
# comments-and-annotations rule — and on nothing else:
#   1. every relative Markdown link names a file or directory that exists;
#   2. no `<placeholder like this>` is left outside code.
# And a third, where .starter-kit-version records a tool other than Claude
# Code: every rule under docs/agent-rules/ is linked from the constitution.
# On those tools a rule is read because the constitution links it, and a
# constitution the project already had links none of the kit's rules.
#
# What counts as a placeholder is deliberately narrow, because a constitution
# is full of angle brackets that are meant to stay. Only `<…>` that opens with
# a letter and contains a space, outside fenced blocks and `code spans`, and
# is not an HTML tag or comment. So `--title "<symptom>"` in a fenced command,
# `RULE:<name>` in backticks, `<br>`, `Option<T>` and `<https://…>` all stay.
# A placeholder-like phrase you want to keep goes in backticks.
#
# The rules the kit ships and docs/rule-reference/ are never read: their
# `<IDENTIFIER>` shapes and WRONG/CORRECT examples are the point of those
# documents. project-annotations.md is read because it is not one of them: it
# starts as a template, like the constitution, and names the rule's pointers
# in backticks.
#
# Not chained into `lint` by the kit: run it when the constitution is filled
# in or edited (`make constitution`). To hold it on every pull request, add
# `constitution` to your `lint:` line — a decision that is yours, since it can
# fail a constitution that passed before.
#
# Usage: check-constitution.sh [file...]
#        default: CLAUDE.md, AGENTS.md and .github/copilot-instructions.md,
#        and project-annotations.md in .claude/rules/ or docs/agent-rules/ —
#        whichever exist
set -euo pipefail
# Python under whatever name this machine gives it; the fallback is for a
# repository that copied this check from a newer kit without the launcher.
PY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/python.sh"; [ -x "$PY" ] || PY=python3

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

"$PY" -B - "$@" <<'PY'
import os, re, sys
from urllib.parse import unquote

CONSTITUTIONS = ("CLAUDE.md", "AGENTS.md", ".github/copilot-instructions.md")
# The project's half of the comments rule, wherever this layout keeps rules.
PROJECT_FILES = (".claude/rules/project-annotations.md", "docs/agent-rules/project-annotations.md")
files = sys.argv[1:] or [f for f in CONSTITUTIONS + PROJECT_FILES if os.path.isfile(f)]
if not files:
    print("SKIP: no constitution found (CLAUDE.md, AGENTS.md, .github/copilot-instructions.md).")
    sys.exit(0)

HTML = set("""a abbr b blockquote br center code dd del details div dl dt em font h1 h2 h3 h4 h5 h6 hr i img ins
kbd li mark ol p picture pre s small source span strong sub summary sup table tbody td th thead tr u ul
video""".split())
FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
SPAN = re.compile(r"(`+)(?!`).+?(?<!`)\1(?!`)")
COMMENT = re.compile(r"<!--.*?-->", re.S)
INLINE_LINK = re.compile(r"\]\(\s*(<[^>\n]*>|[^)\s]+)(?:\s+(?:\"[^\"\n]*\"|'[^'\n]*'))?\s*\)")
REFERENCE = re.compile(r"^ {0,3}\[[^\]\n]+\]:\s*(<[^>\n]*>|\S+)", re.M)
PLACEHOLDER = re.compile(r"<([A-Za-z][^<>]{0,400}?)>", re.S)


def blank(match):
    """Same length, same line breaks, nothing left to match."""
    return re.sub(r"[^\n]", " ", match.group(0))


def prose(text):
    """The text with fenced blocks, code spans and HTML comments blanked out."""
    lines, fence = text.split("\n"), None
    for i, line in enumerate(lines):
        opener = FENCE.match(line)
        if fence is None and opener:
            fence = opener.group(1)[0] * 3
            lines[i] = ""
        elif fence is not None:
            if line.lstrip(" ").startswith(fence) and not line.strip(" `~"):
                fence = None
            lines[i] = ""
        else:
            lines[i] = SPAN.sub(blank, line)
    return COMMENT.sub(blank, "\n".join(lines))


def exists(target, constitution):
    """A link resolves from the constitution's directory or from the root."""
    path = unquote(target.strip("<>").split("#", 1)[0].split("?", 1)[0])
    if not path:
        return True
    return any(os.path.exists(os.path.normpath(os.path.join(base, path)))
               for base in (os.path.dirname(constitution), "."))


problems, links, linked = [], 0, set()
for constitution in files:
    try:
        text = open(constitution, encoding="utf-8").read()
    except (OSError, UnicodeDecodeError) as error:
        problems.append("%s — cannot be read (%s)." % (constitution, error.__class__.__name__))
        continue
    text = prose(text)
    line_of = lambda offset: text.count("\n", 0, offset) + 1
    found = []
    for pattern in (INLINE_LINK, REFERENCE):
        for match in pattern.finditer(text):
            target = match.group(1)
            if re.match(r"[A-Za-z][A-Za-z0-9+.-]*:", target.strip("<>")) or target.startswith("#"):
                continue  # a URL, a mail address, an anchor in this page
            links += 1
            path = unquote(target.strip("<>").split("#", 1)[0].split("?", 1)[0])
            for base in (os.path.dirname(constitution), "."):
                linked.add(os.path.normpath(os.path.join(base, path)))
            if not exists(target, constitution):
                found.append((line_of(match.start(1)),
                              "link '%s' names a file that does not exist" % target.strip("<>")))
    # A link's own path is judged as a link, above — not again as a placeholder.
    text = REFERENCE.sub(blank, INLINE_LINK.sub(blank, text))
    for match in PLACEHOLDER.finditer(text):
        inner = match.group(1)
        if not re.search(r"\s", inner) or re.search(r"\n[ \t]*\n", inner):
            continue  # one word — a tag, a generic, a key name — or two paragraphs
        if "=" in inner or inner.split()[0].lower().rstrip("/") in HTML:
            continue  # an HTML tag with attributes
        shown = " ".join(inner.split())
        shown = shown if len(shown) <= 70 else shown[:67] + "…"
        found.append((line_of(match.start()), "unfilled placeholder '<%s>'" % shown))
    problems += ["%s:%d — %s" % (constitution, line, what) for line, what in sorted(found)]


def recorded_tool():
    try:
        for line in open(".starter-kit-version", encoding="utf-8"):
            if line.startswith("tool:"):
                return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return None


RULES = "docs/agent-rules"
if not sys.argv[1:] and recorded_tool() in ("agents", "cursor", "copilot") and os.path.isdir(RULES):
    read_by = [f for f in files if f in CONSTITUTIONS and f != "CLAUDE.md"]
    for name in sorted(os.listdir(RULES)):
        rule = os.path.join(RULES, name)
        if name.endswith(".md") and not name.startswith("_") and os.path.normpath(rule) not in linked:
            problems.append("%s — no constitution links this rule (%s), so no session reads it"
                            % (rule, ", ".join(read_by) or "none found"))

if problems:
    for problem in problems:
        print("FAIL: " + problem)
    print("")
    print("%d problem(s) in %s." % (len(problems), ", ".join(files)))
    print("  A dead link: write the file, point the link at the one that exists, or delete")
    print("  the line — the template's example rules are examples, not files you were given.")
    print("  A placeholder: replace it with what this project has, or delete the row.")
    print("  Angle brackets that are meant to stay go in `backticks` or a fenced block.")
    print("  An unlinked rule: link it from the constitution, the way the kit's template")
    print("  indexes its rules — or delete the rule if the project does not want it.")
    sys.exit(1)
print("OK: %s — %d link(s) resolve, no unfilled placeholder" % (", ".join(files), links))
PY
