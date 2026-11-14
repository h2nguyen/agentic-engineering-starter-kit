#!/usr/bin/env python3
"""Workspace graph tool — typed links in, resolved edges out.

Every artifact an agentic workspace keeps is a node: a rule, a skill, an agent,
a command, a check script, a document, a knowledge-base entry, a decision
record. A *typed link* is a line in one artifact that names another by a stable
token — `RULE:testing`, `SCRIPT:check-tests.sh`, `ISSUE-2026-08-29-cache-warms`,
`ADR-0002`. Three line labels carry them, and the label is the edge type:

  **Related:**       knowledge   — this artifact cites that one
  **Enforces:**      knowledge   — this script or reviewer holds that rule
  **Hands off to:**  orchestration — who or what runs next (a skill, an agent,
                                     a command, a script, or HUMAN)

In a script the same lines are comments in the header block: `# Enforces: …`.

The failure this tool exists for is silent. A link to an artifact that was
renamed, deleted or never written reads exactly like a link that works, and
nothing else in the lint target opens the file it points at. So `check` resolves
every token against what is actually on disk, and the same reverse index answers
the question an agent should ask before it edits a rule: what cites this?

Nothing is stored. The graph is rebuilt from the files on each run, so there is
no index to regenerate, to drift, or for two branches to conflict on.

Stdlib only. Reads `registries.json` for the identifier schemes and, when it
declares one, the optional `graph.nodes` map of kind → glob.

  graph_tool.py check                 (the gate: every typed link resolves)
  graph_tool.py impact <node|path>    (what cites this, and what it cites)
  graph_tool.py coverage              (which rules have a script and a reviewer)
  graph_tool.py note <path>...        (what an editor of this file should be told;
                                       silent when there is nothing to say)
"""

from __future__ import annotations

import argparse
import difflib
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
# Importing a sibling module would write scripts/__pycache__/ into the
# adopting repository, which gets no .gitignore from the kit — untracked files
# that ride into the next `git add -A`.
sys.dont_write_bytecode = True
try:
    # One source of truth for identifier grammar: the registry tool derives an
    # entry's identifier from its filename, and a second derivation here would
    # disagree with it the first time a project changed a width or a prefix.
    import registry_tool as rt
except ImportError:  # pragma: no cover - reported by main()
    rt = None

ALLOWLIST_NAME = ".graph-link-allowlist"
HUMAN = "HUMAN"
LABELS = ("Related", "Enforces", "Hands off to")

# Where each kind of artifact lives. Every layout the installer supports is
# listed, so the same defaults resolve in a Claude Code repository and in an
# AGENTS.md one; a glob that matches nothing costs nothing. A repository that
# keeps a kind somewhere else declares it under "graph": {"nodes": {...}} in
# registries.json — that entry replaces the default for that kind only.
# DOC is deliberately last: it is the catch-all, and a file a more specific
# kind has claimed is not also a document.
DEFAULT_NODES = {
    "RULE": [
        ".claude/rules/*.md",
        "docs/agent-rules/*.md",
        ".cursor/rules/*.mdc",
        ".github/instructions/*.instructions.md",
    ],
    "SKILL": [".claude/skills/*/SKILL.md"],
    "AGENT": [".claude/agents/*.md"],
    "COMMAND": [".claude/commands/*.md"],
    "SCRIPT": ["scripts/*"],
    "DOC": ["docs/**/*.md", "*.md", ".github/copilot-instructions.md"],
}

# A hand-off names who or what runs next. A rule, a document or a registry
# entry informs the work; it does not take it over.
NOT_A_HANDOFF_TARGET = ("RULE", "DOC")

MARKDOWN_EXTENSIONS = (".md", ".mdc", ".markdown")
PATH_TOKEN = re.compile(r"^([A-Z][A-Z0-9_]*):([A-Za-z0-9._/-]+)$")
_LABEL_ALT = "|".join(re.escape(label) for label in LABELS)
MARKDOWN_LINK = re.compile(r"^\*\*(%s):\*\*[ \t]*(.*)$" % _LABEL_ALT)
COMMENT_LINK = re.compile(r"^\s*(?:#|//)\s*(%s):[ \t]+(.*)$" % _LABEL_ALT)
FENCE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")
# " — why", " -- why", or a dash that ends the line because the sentence
# continues on the next comment line.
TRAILING_NOTE = re.compile(r"\s(?:—|–|--|-)(?:\s.*)?$")
SECTION_POINTER = re.compile(r"\s+§.*$")


class GraphError(Exception):
    """A failure the caller should see as a gate failure, not a traceback."""


class Node:
    """One artifact. `token` is how other artifacts cite it."""

    __slots__ = ("kind", "name", "path", "aliases", "is_entry")

    def __init__(self, kind: str, name: str, path: str, aliases=(), is_entry=False):
        self.kind = kind
        self.name = name
        self.path = path
        self.aliases = tuple(aliases) or (name,)
        self.is_entry = is_entry

    @property
    def token(self) -> str:
        return self.name if self.is_entry else f"{self.kind}:{self.name}"

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        return f"<Node {self.token} {self.path}>"


class Edge:
    """One resolved typed link. `targets` is empty only for HUMAN."""

    __slots__ = ("source", "label", "token", "targets", "path", "line")

    def __init__(self, source: Node, label: str, token: str, targets, path: str, line: int):
        self.source = source
        self.label = label
        self.token = token
        self.targets = list(targets)
        self.path = path
        self.line = line


class Problem:
    """One link the gate rejects. Only a *dangling* one can be allowlisted:
    a malformed token or a hand-off to a document is wrong wherever it sits."""

    __slots__ = ("path", "line", "label", "token", "lines", "dangling")

    def __init__(self, path, line, label, token, lines, dangling=False):
        self.path = path
        self.line = line
        self.label = label
        self.token = token
        self.lines = list(lines)
        self.dangling = dangling


# --------------------------------------------------------------------------
# nodes
# --------------------------------------------------------------------------

def _posix(path: str) -> str:
    return path.replace(os.sep, "/")


def _is_scaffolding(rel: str) -> bool:
    """Templates and tool droppings are not artifacts.

    The registry tool already treats an underscore-prefixed fragment as
    scaffolding; the same convention holds for every kind here, so a
    `_rule-template.md` or a `skills/_template/` full of `<placeholders>` is
    neither a node nor a source of links.
    """
    parts = rel.split("/")
    if any(part.startswith("_") for part in parts):
        return True
    name = parts[-1]
    return name.startswith(".") or name.endswith((".template", ".pyc", ".bak", ".sedtmp"))


def _strip_ext(name: str) -> str:
    stem, ext = os.path.splitext(name)
    return stem if stem and ext else name


def _compile_glob(pattern: str):
    """A glob as a regex that also says which part the wildcard matched.

    `glob.glob` finds the files; this recovers the *name* each file is cited
    by — the directory for `.claude/skills/*/SKILL.md`, the stem for
    `.claude/rules/*.md`, the path below the base for `docs/**/*.md`.
    """
    segments = pattern.split("/")
    regex, roles = "", []
    for index, segment in enumerate(segments):
        last = index == len(segments) - 1
        if segment == "**":
            regex += r"((?:[^/]+/)*)"
            roles.append("deep")
            continue
        for char in segment:
            if char == "*":
                regex += r"([^/]*)"
                roles.append("name" if last else "dir")
            elif char == "?":
                regex += r"[^/]"
            else:
                regex += re.escape(char)
        if not last:
            regex += "/"
    return re.compile("^" + regex + "$"), roles


def _names_for(rel: str, pattern: str) -> tuple[str, list[str]]:
    """The canonical name of a file under a glob, plus the names it answers to."""
    regex, roles = _compile_glob(pattern)
    match = regex.match(rel)
    base = os.path.basename(rel)
    if not match:  # pragma: no cover - glob and regex disagree only on odd names
        return _strip_ext(base), [_strip_ext(base), base]
    captured = dict()
    for role, value in zip(roles, match.groups()):
        captured.setdefault(role, []).append(value or "")
    if "name" in captured:
        star = captured["name"][0]
        deep = captured.get("deep", [""])[0]
        canonical = deep + star
        names = [canonical, star, _strip_ext(canonical), _strip_ext(star)]
    elif "dir" in captured:
        canonical = captured["dir"][-1]
        names = [canonical]
    else:
        canonical = _strip_ext(base)
        names = [canonical, base]
    seen, unique = set(), []
    for name in names:
        if name and name not in seen:
            seen.add(name)
            unique.append(name)
    return canonical, unique


class Graph:
    """The workspace as nodes and typed edges, rebuilt from disk on every run."""

    def __init__(self, root: str, cfg: dict):
        self.root = root
        self.cfg = cfg
        self.nodes: list[Node] = []
        self.by_path: dict[str, Node] = {}
        self.by_alias: dict[str, dict[str, list[Node]]] = {}
        self.entry_ids: dict[str, dict[str, Node]] = {}
        self.generated: set[str] = set()
        self.edges: list[Edge] = []
        self.problems: list[Problem] = []
        self.globs = self._node_globs()
        self._collect_entries()
        self._collect_files()
        self._scan()

    # -- configuration ----------------------------------------------------

    def _node_globs(self) -> dict[str, list[str]]:
        declared = (self.cfg.get("graph") or {}).get("nodes") or {}
        if not isinstance(declared, dict):
            raise GraphError('registries.json: "graph.nodes" must map a kind to a list of globs')
        globs: dict[str, list[str]] = {}
        order = [k for k in DEFAULT_NODES if k != "DOC"]
        order += [k for k in declared if k not in DEFAULT_NODES and not k.startswith("_")]
        order.append("DOC")
        for kind in order:
            value = declared.get(kind, DEFAULT_NODES.get(kind, []))
            if isinstance(value, str):
                value = [value]
            if not re.fullmatch(r"[A-Z][A-Z0-9_]*", kind) or kind == HUMAN:
                raise GraphError(
                    f'registries.json: graph.nodes kind {kind!r} must be UPPERCASE '
                    f"letters, digits or underscores, and not {HUMAN}"
                )
            globs[kind] = [str(v) for v in value]
        return globs

    # -- nodes ------------------------------------------------------------

    def _add(self, node: Node) -> None:
        self.nodes.append(node)
        self.by_path[node.path] = node
        if node.is_entry:
            self.entry_ids.setdefault(node.kind, {})[node.name] = node
        else:
            names = self.by_alias.setdefault(node.kind, {})
            for alias in node.aliases:
                names.setdefault(alias, []).append(node)

    def _collect_entries(self) -> None:
        """Knowledge-base entries and decision records, by their real identifiers."""
        for raw in self.cfg.get("registries", []) or []:
            try:
                reg = rt.Registry(raw, self.cfg, self.root)
            except rt.RegistryError as exc:
                raise GraphError(str(exc))
            if reg.output:
                # The assembled artifact repeats every entry's links. The
                # fragment is the authored source; reading both would count
                # each edge twice and blame a generated line for a dangling one.
                self.generated.add(_posix(reg.output))
            if reg.kind == "changelog" or not reg.id_prefix:
                continue
            self.entry_ids.setdefault(reg.id_prefix, {})
            for path in rt.fragment_paths(reg):
                try:
                    entry_id = reg.id_for(path)
                except rt.RegistryError:
                    continue  # the identifier gate names malformed fragments
                rel = _posix(os.path.relpath(path, self.root))
                if rel not in self.by_path:
                    self._add(Node(reg.id_prefix, entry_id, rel, is_entry=True))

    def _collect_files(self) -> None:
        for kind, patterns in self.globs.items():
            self.by_alias.setdefault(kind, {})
            for pattern in patterns:
                hits = glob.glob(os.path.join(glob.escape(self.root), pattern), recursive=True)
                for full in sorted(hits):
                    if not os.path.isfile(full):
                        continue
                    rel = _posix(os.path.relpath(full, self.root))
                    if rel in self.by_path or _is_scaffolding(rel):
                        continue
                    name, aliases = _names_for(rel, pattern)
                    self._add(Node(kind, name, rel, aliases))

    # -- links ------------------------------------------------------------

    def _scan(self) -> None:
        for node in list(self.nodes):
            if node.path in self.generated:
                continue
            try:
                with open(os.path.join(self.root, node.path), encoding="utf-8") as fh:
                    lines = fh.read().splitlines()
            except (OSError, UnicodeDecodeError):
                continue
            if node.path.lower().endswith(MARKDOWN_EXTENSIONS):
                found = self._markdown_links(node, lines)
            else:
                found = self._header_links(lines)
            for line_no, label, value in found:
                self._read_link(node, line_no, label, value)

    def _markdown_links(self, source: Node, lines: list[str]):
        """Link lines outside fenced code — an example is not a citation."""
        fence, opened_at, hidden = None, 0, 0
        for number, line in enumerate(lines, 1):
            opened = FENCE.match(line)
            if opened:
                marker = opened.group(1)
                if fence is None:
                    fence, opened_at, hidden = marker, number, 0
                elif marker[0] == fence[0] and len(marker) >= len(fence):
                    fence = None
                continue
            match = MARKDOWN_LINK.match(line)
            if fence is not None:
                hidden += 1 if match else 0
                continue
            if match:
                yield number, match.group(1), match.group(2)
        if fence is not None and hidden:
            # Everything below an unclosed fence reads as code, so the links
            # down there were skipped. Saying OK about a file that was only
            # half read is the silent failure this gate exists to prevent.
            self.problems.append(Problem(source.path, opened_at, "", "", [
                f"the code fence opened here is never closed, so {hidden} link line(s) "
                f"below it were read as code and not checked.",
                f"Close the fence with a line of {fence[0] * 3}.",
            ], False))

    @staticmethod
    def _header_links(lines: list[str]):
        """Link comments in a script's header block, and nowhere below it.

        The body of a script is full of text that only looks like a link — a
        here-document writing a fixture, a message echoing the expected shape.
        The header is the one place the enforcement-script contract puts them.
        """
        for number, line in enumerate(lines, 1):
            stripped = line.strip()
            if stripped and not stripped.startswith(("#", "//")):
                return
            match = COMMENT_LINK.match(line)
            if match:
                yield number, match.group(1), match.group(2)

    def _read_link(self, source: Node, line_no: int, label: str, value: str) -> None:
        raw = value
        value = value.strip()
        if label != "Related":
            # "Enforces" points into a rule and "Hands off to" carries a
            # condition, so both may say where and why. "Related" stays the
            # plain list the knowledge-base shape check already enforces.
            value = TRAILING_NOTE.sub("", value).strip()
        for item in value.split(","):
            item = item.strip()
            if label != "Related":
                item = SECTION_POINTER.sub("", item).strip()
            if item:
                self._resolve(source, line_no, label, item, raw)

    def _resolve(self, source: Node, line_no: int, label: str, token: str, raw: str = "") -> None:
        def reject(*lines, dangling=False):
            self.problems.append(Problem(source.path, line_no, label, token, lines, dangling))

        if "<" in token or ">" in token:
            return reject(
                f"{label} link {token!r} is an unfilled placeholder.",
                "Name the artifact, or delete the line if there is none.",
            )
        if token == HUMAN:
            if label != "Hands off to":
                return reject(
                    f"{HUMAN} is a hand-off target, not something a file can be {label.lower()} to.",
                    f"Write it on a '**Hands off to:**' line: the approval this work waits for.",
                )
            self.edges.append(Edge(source, label, token, [], source.path, line_no))
            return

        path_token = PATH_TOKEN.match(token)
        entry_kind = self._entry_kind(token)
        targets: list[Node] = []
        kind = ""
        if path_token and path_token.group(1) in self.globs:
            kind, name = path_token.group(1), path_token.group(2)
            targets = self.by_alias.get(kind, {}).get(name, [])
            if not targets:
                return reject(*self._missing_file(label, token, kind, name), dangling=True)
        elif entry_kind:
            kind = entry_kind
            hit = self.entry_ids[kind].get(token)
            if hit is None:
                return reject(*self._missing_entry(label, token, kind), dangling=True)
            targets = [hit]
        else:
            kinds = ", ".join(f"{k}:<name>" for k in self.globs)
            ids = ", ".join(f"{p}-…" for p in sorted(self.entry_ids)) or "none declared"
            lines = [
                f"{label} link {token!r} is not a typed link this repository knows.",
                f"Artifact links: {kinds}. Registry identifiers: {ids}."
                + (f" Hand-offs may also name {HUMAN}." if label == "Hands off to" else ""),
            ]
            if label == "Enforces":
                # The header shape the kit used to ship put the rule in a
                # sentence. Say what the typed form is — and, where the
                # sentence names a file this repository has, which token.
                lines.append(
                    "An Enforces line names the rule first: "
                    "'Enforces: RULE:<name> § <section> — <what it checks>'."
                )
                for node in self.nodes:
                    if not node.is_entry and node.path in raw:
                        lines.append(f"This line mentions {node.path} — that is {node.token}.")
            return reject(*lines)

        if label == "Hands off to" and (kind in NOT_A_HANDOFF_TARGET or targets[0].is_entry):
            return reject(
                f"a hand-off to {token} names a document, and a document does not run next.",
                f"Hand off to a skill, an agent, a command, a script or {HUMAN}; "
                f"cite {token} on a '**Related:**' or '**Enforces:**' line instead.",
            )
        self.edges.append(Edge(source, label, token, targets, source.path, line_no))

    def _entry_kind(self, token: str) -> str:
        """The registry a token belongs to: the longest declared prefix it starts with.

        Longest, not first: a prefix may itself contain a hyphen (BUG-REPORT),
        and reading the text before the first hyphen as the prefix made such a
        registry impossible to cite.
        """
        fits = [prefix for prefix in self.entry_ids if token.startswith(prefix + "-")]
        return max(fits, key=len) if fits else ""

    def _looked_in(self, kind: str) -> str:
        """The globs for a kind — only the ones this layout has, when it has any."""
        here = [g for g in self.globs[kind]
                if "*" in g and os.path.isdir(os.path.join(self.root, g.split("*")[0]))]
        return ", ".join(here or self.globs[kind])

    def _missing_file(self, label: str, token: str, kind: str, name: str) -> list[str]:
        known = sorted({n.name for n in self.nodes if n.kind == kind and not n.is_entry})
        looked = self._looked_in(kind)
        lines = [f"{label} link {token!r} resolves to nothing."]
        if not known:
            lines.append(f"This repository has no {kind} artifacts (looked in {looked}).")
            lines.append(
                f'If it keeps them elsewhere, declare where in registries.json: '
                f'"graph": {{"nodes": {{"{kind}": ["<glob>"]}}}}'
            )
            return lines
        lines.append(f"No {kind} named {name!r} in {looked}.")
        close = difflib.get_close_matches(name, known, n=2, cutoff=0.5)
        if close:
            lines.append("Did you mean " + " or ".join(f"{kind}:{c}" for c in close) + "?")
        shown = ", ".join(known[:12]) + (", …" if len(known) > 12 else "")
        lines.append(f"{kind} artifacts here: {shown}")
        return lines

    def _missing_entry(self, label: str, token: str, kind: str) -> list[str]:
        known = sorted(self.entry_ids[kind])
        lines = [f"{label} link {token!r} resolves to nothing: no {kind} entry has that identifier."]
        close = difflib.get_close_matches(token, known, n=2, cutoff=0.6)
        if close:
            lines.append("Did you mean " + " or ".join(close) + "?")
        elif not known:
            lines.append(f"This repository has no {kind} entries yet.")
        return lines

    # -- lookups ----------------------------------------------------------

    def at(self, path: str) -> Node | None:
        """The node a file path names, however the path reached the file.

        An editor may report a path through a symlinked directory — macOS hands
        out /var/… for what is /private/var/… on disk — while git and this tool
        see the physical one. Both spellings are the same file.
        """
        for full, root in ((os.path.abspath(path), self.root),
                           (os.path.realpath(path), os.path.realpath(self.root))):
            node = self.by_path.get(_posix(os.path.relpath(full, root)))
            if node is not None:
                return node
        return None

    def find(self, wanted: str) -> list[Node]:
        """A node by token, by any alias, or by the path of its file."""
        node = self.at(wanted)
        if node is not None:
            return [node]
        path_token = PATH_TOKEN.match(wanted)
        if path_token:
            return list(self.by_alias.get(path_token.group(1), {}).get(path_token.group(2), []))
        entry_kind = self._entry_kind(wanted)
        if entry_kind:
            hit = self.entry_ids[entry_kind].get(wanted)
            return [hit] if hit else []
        return []

    def inbound(self, node: Node) -> list[Edge]:
        return [e for e in self.edges if any(t is node for t in e.targets)]

    def outbound(self, node: Node) -> list[Edge]:
        return [e for e in self.edges if e.source is node]

    def rule_pointer(self) -> str:
        """Where the convention is written down — found through the graph itself."""
        hits = self.by_alias.get("RULE", {}).get("documentation", [])
        return f"{hits[0].path} § Typed links" if hits else "the documentation rule § Typed links"


# --------------------------------------------------------------------------
# allowlist
# --------------------------------------------------------------------------

def load_allowlist(root: str) -> tuple[dict, list[str]]:
    """Sanctioned dangling links, keyed on the (citing file, token) PAIR.

    The legitimate case is narrow: an accepted decision record is immutable, so
    when the rule it cites is retired the record cannot be edited to match.
    Keying on the pair rather than the token keeps the exemption that narrow —
    a token-keyed entry would excuse every future file that cites the same
    dead name. And an entry without a reason is a gate that stopped running
    with nobody knowing why, so the reason is part of the grammar.
    """
    path = os.path.join(root, ALLOWLIST_NAME)
    entries: dict[tuple[str, str], int] = {}
    errors: list[str] = []
    if not os.path.isfile(path):
        return entries, errors
    with open(path, encoding="utf-8") as fh:
        for number, raw in enumerate(fh.read().splitlines(), 1):
            text, _, reason = raw.partition("#")
            fields = text.split()
            if not fields:
                continue
            if len(fields) != 2:
                errors.append(
                    f"{ALLOWLIST_NAME}:{number} — expected '<citing file> <token>  # reason', "
                    f"found {len(fields)} field(s)."
                )
                continue
            if not reason.strip():
                errors.append(
                    f"{ALLOWLIST_NAME}:{number} — {fields[0]} {fields[1]} has no '# reason'. "
                    f"Say why the citing file cannot be repaired."
                )
                continue
            # ./docs/x.md and docs/x.md are the same file; the graph knows it
            # by the second spelling.
            entries[(_posix(os.path.normpath(fields[0])), fields[1])] = number
    return entries, errors


# --------------------------------------------------------------------------
# commands
# --------------------------------------------------------------------------

def cmd_check(graph: Graph, args) -> int:
    allowed, failures = load_allowlist(graph.root)
    failures = [f"FAIL: {line}" for line in failures]
    used: set[tuple[str, str]] = set()
    notes: list[str] = []
    for problem in sorted(graph.problems, key=lambda p: (p.path, p.line, p.token)):
        key = (problem.path, problem.token)
        if problem.dangling and key in allowed:
            used.add(key)
            notes.append(
                f"note: {problem.path}:{problem.line} cites {problem.token}, which no "
                f"longer resolves — sanctioned in {ALLOWLIST_NAME}:{allowed[key]}"
            )
            continue
        head, *rest = problem.lines
        failures.append(f"FAIL: {problem.path}:{problem.line} — {head}")
        failures.extend(f"      {line}" for line in rest)
    for key, number in sorted(allowed.items(), key=lambda item: item[1]):
        if key not in used:
            failures.append(
                f"FAIL: {ALLOWLIST_NAME}:{number} — {key[0]} {key[1]} is not a dangling link "
                f"any more. Remove the stale line: the list records debt, not history."
            )
    for note in notes:
        print(note, file=sys.stderr)
    if failures:
        print("\n".join(failures), file=sys.stderr)
        print(f"See {graph.rule_pointer()}.", file=sys.stderr)
        return 1
    files = len({edge.path for edge in graph.edges})
    if graph.edges:
        print(
            f"OK: {len(graph.edges)} typed link(s) in {files} file(s) resolve "
            f"({len(graph.nodes)} artifacts)"
        )
    else:
        print(f"OK: no typed links yet — nothing to resolve ({len(graph.nodes)} artifacts)")
    return 0


def _edge_rows(edges, other) -> list[str]:
    rows = []
    for edge in sorted(edges, key=lambda e: (LABELS.index(e.label), e.path, e.line)):
        rows.append(f"  {edge.label:<13} {other(edge):<44} {edge.path}:{edge.line}")
    return rows


def cmd_impact(graph: Graph, args) -> int:
    if args.node == HUMAN:
        gates = [e for e in graph.edges if e.token == HUMAN]
        print(f"{HUMAN} — the approval gates of this workspace ({len(gates)})")
        print("\n".join(_edge_rows(gates, lambda e: e.source.token)) or "  none declared")
        return 0
    nodes = graph.find(args.node)
    if not nodes:
        print(f"FAIL: {args.node!r} is not an artifact this repository has.", file=sys.stderr)
        tokens = sorted(n.token for n in graph.nodes)
        close = difflib.get_close_matches(args.node, tokens, n=3, cutoff=0.5)
        if close:
            print("      Did you mean " + ", ".join(close) + "?", file=sys.stderr)
        print(
            "      Name it as KIND:name (RULE:testing), by identifier (ADR-0002), or by path.",
            file=sys.stderr,
        )
        return 2
    for index, node in enumerate(nodes):
        if index:
            print("")
        cited_by = graph.inbound(node)
        cites = graph.outbound(node)
        print(f"{node.token} — {node.path}")
        print("")
        print(f"Cited by ({len(cited_by)}):")
        print("\n".join(_edge_rows(cited_by, lambda e: e.source.token)) or "  nothing")
        print("")
        print(f"Cites ({len(cites)}):")
        print("\n".join(_edge_rows(cites, lambda e: e.token)) or "  nothing")
        print("")
        if cited_by:
            print(
                "Renaming or deleting this artifact breaks every link under 'Cited by'.\n"
                "Change those lines in the same pull request, then run the link gate."
            )
        else:
            print(
                "No typed link points here. Prose mentions are not edges — search for\n"
                f"the name ({node.name}) as well before renaming or deleting it."
            )
    return 0


def cmd_coverage(graph: Graph, args) -> int:
    """Which rules a script enforces and an agent reviews — a report, never a gate.

    A rule with no script is not a defect: a script is earned when a documented
    rule is violated anyway, and a reviewer when the same comment recurs. What
    this answers is the question the health checklist asks by hand.
    """
    def kind_of(kind):
        return sorted((n for n in graph.nodes if n.kind == kind and not n.is_entry),
                      key=lambda n: n.name)

    rules, agents = kind_of("RULE"), kind_of("AGENT")
    handoffs = [e for e in graph.edges if e.label == "Hands off to"]
    print(
        f"Workspace graph — {len(graph.nodes)} artifacts, {len(graph.edges)} typed links "
        f"({len(handoffs)} hand-offs, {sum(1 for e in handoffs if e.token == HUMAN)} to {HUMAN})"
    )
    if graph.problems:
        print(f"  {len(graph.problems)} link(s) do not resolve — run the link gate first.")
    print("")

    def holders(rule, kind):
        return sorted({e.source.token for e in graph.inbound(rule)
                       if e.label == "Enforces" and e.source.kind == kind})

    print(f"Rules ({len(rules)}) — enforced by | reviewed by")
    unscripted, unreviewed = [], []
    for rule in rules:
        scripts, reviewers = holders(rule, "SCRIPT"), holders(rule, "AGENT")
        if not scripts:
            unscripted.append(rule.token)
        if not reviewers:
            unreviewed.append(rule.token)
        print(f"  {rule.token:<36} {', '.join(scripts) or '—'} | {', '.join(reviewers) or '—'}")
    print("")
    print(f"No script enforces ({len(unscripted)}): {', '.join(unscripted) or '—'}")
    if agents:
        print(f"No agent reviews ({len(unreviewed)}): {', '.join(unreviewed) or '—'}")
        gates = [n for n in kind_of("SCRIPT")
                 if any(e.label == "Enforces" for e in graph.outbound(n))]
        unowned = [g.token for g in gates if not any(e.source.kind == "AGENT" for e in graph.inbound(g))]
        print(f"Gates no agent cites ({len(unowned)}): {', '.join(unowned) or '—'}")
        silent = [a.token for a in agents if not graph.outbound(a)]
        print(f"Agents with no typed link ({len(silent)}): {', '.join(silent) or '—'}")
    else:
        print("No agents in this workspace yet — nothing to route between.")
    loose = [n.token for kind in ("RULE", "SKILL", "AGENT", "COMMAND") for n in kind_of(kind)
             if not graph.inbound(n) and not graph.outbound(n)]
    print(f"No typed link in or out ({len(loose)}): {', '.join(loose) or '—'}")
    print("")
    print(
        "Report only. A rule earns a script when it is violated despite being\n"
        "documented, and a reviewer when the same review comment recurs."
    )
    return 0


NOTE_CITERS_SHOWN = 8


def cmd_note(graph: Graph, args) -> int:
    """What whoever just edited a file should be told about it — or nothing.

    `impact` answers a question somebody asked. This answers one nobody did: it
    is what an editor hook prints after every edit, so it speaks only when the
    file is cited by another artifact or carries a link that resolves to
    nothing, and is silent for every other file. It never fails — a link that
    does not resolve is reported here and gated by `check`.
    """
    allowed, _ = load_allowlist(graph.root)
    blocks: list[str] = []
    for wanted in args.paths:
        node = graph.at(wanted)
        if node is None:
            continue
        lines: list[str] = []
        for problem in sorted(graph.problems, key=lambda p: (p.line, p.token)):
            if problem.path != node.path:
                continue
            if problem.dangling and (problem.path, problem.token) in allowed:
                continue  # sanctioned once, in the allowlist; not news on every edit
            head, *rest = problem.lines
            lines.append(f"{problem.path}:{problem.line} — {head}")
            lines.extend(f"  {line}" for line in rest)
        cited_by = [e for e in graph.inbound(node) if e.source is not node]
        if cited_by:
            files = len({e.path for e in cited_by})
            rows = _edge_rows(cited_by, lambda e: e.source.token)
            lines.append(f"{node.token} ({node.path}) is cited by {files} file(s):")
            lines.extend(rows[:NOTE_CITERS_SHOWN])
            if len(rows) > NOTE_CITERS_SHOWN:
                lines.append(
                    f"  … and {len(rows) - NOTE_CITERS_SHOWN} more — "
                    f"python3 scripts/graph_tool.py impact {node.token}"
                )
            lines.append(
                "If this edit renamed it, removed it or changed what it requires, "
                "update those files in the same change."
            )
        if lines:
            blocks.append("\n".join(lines))
    if blocks:
        print("\n\n".join(blocks))
    return 0


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="graph_tool.py",
        description="Resolve the typed links between workspace artifacts.",
    )
    parser.add_argument("--config", help="path to registries.json (default: search upwards)")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("check", help="every typed link resolves to an artifact that exists")
    p_impact = sub.add_parser("impact", help="what cites an artifact, and what it cites")
    p_impact.add_argument("node", help="KIND:name, a registry identifier, a file path, or HUMAN")
    sub.add_parser("coverage", help="which rules have an enforcing script and a reviewing agent")
    p_note = sub.add_parser("note", help="what an editor of these files should be told; silent when nothing")
    p_note.add_argument("paths", nargs="+", help="the files that were just edited")
    return parser


def load_graph(config: str | None = None) -> Graph:
    if rt is None:
        raise GraphError(
            "registry_tool.py not found next to graph_tool.py — the two ship together; "
            "copy both from the starter kit's scripts/ directory."
        )
    try:
        cfg, root = rt.find_config(config)
    except rt.RegistryError as exc:
        raise GraphError(str(exc))
    return Graph(root, cfg)


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        graph = load_graph(args.config)
    except GraphError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    commands = {"check": cmd_check, "impact": cmd_impact, "coverage": cmd_coverage, "note": cmd_note}
    return commands[args.command](graph, args)


if __name__ == "__main__":
    sys.exit(main())
