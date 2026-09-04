#!/usr/bin/env python3
"""Shared append-only registry tool — fragments in, generated artifact out.

A *shared append-only registry* is any file that (a) many pull requests append
to, (b) at a fixed anchor, (c) under an allocated identifier. Changelogs,
debugging knowledge bases, decision-record indexes, message-code catalogues and
translation bundles are all instances of the same shape, and they all fail the
same way once more than one branch is open at a time:

  * a **conflict** on every concurrent pair, which is loud and cheap; and
  * a **duplicate identifier**, which is silent, permanent once the identifier
    has been cited anywhere, and therefore the failure worth designing against.

This tool removes both by making the unit of authorship a *file* instead of a
*line range*: one fragment per entry, named so that two branches can never
claim the same path, assembled into the human-readable artifact by a
deterministic generator. Git merges disjoint file additions without help, so
the conflict cannot occur; the identifier is derived from the path, so the
collision cannot occur either — and where a project opts into hand-allocated
numbers, the `check` gate catches the collision before it is ever cited.

Stdlib only, no build step, no per-clone configuration. Run `--help` on any
subcommand for its options.

  registry_tool.py new       --registry <name> --title "..."  [--category ...]
  registry_tool.py generate  [--registry <name>] [--check]
  registry_tool.py check     [--registry <name>]
  registry_tool.py release   --registry <name> --version X.Y.Z
  registry_tool.py init      [--force]              (write registries.json from what exists)
  registry_tool.py adopt     --registry <name>      (brownfield: existing artifact -> fragments)
  registry_tool.py list
"""

from __future__ import annotations

import argparse
import datetime as _dt
import difflib
import json
import os
import re
import sys
import unicodedata

CONFIG_NAME = "registries.json"
ALLOWLIST_NAME = ".registry-id-duplicate-allowlist"

COMMENT_STYLES = {
    "html": ("<!-- ", " -->"),
    "hash": ("# ", ""),
    "slash": ("// ", ""),
}

DEFAULT_CATEGORIES = ["Added", "Changed", "Deprecated", "Removed", "Fixed", "Security"]

SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class RegistryError(Exception):
    """A failure the caller should see as a gate failure, not a traceback."""


# --------------------------------------------------------------------------
# configuration
# --------------------------------------------------------------------------

def find_config(explicit: str | None) -> tuple[dict, str]:
    """Locate registries.json by walking up from the working directory."""
    if explicit:
        path = os.path.abspath(explicit)
        if not os.path.isfile(path):
            raise RegistryError(f"config not found: {path}")
        with open(path, encoding="utf-8") as fh:
            return json.load(fh), os.path.dirname(path)

    here = os.getcwd()
    while True:
        candidate = os.path.join(here, CONFIG_NAME)
        if os.path.isfile(candidate):
            with open(candidate, encoding="utf-8") as fh:
                return json.load(fh), here
        parent = os.path.dirname(here)
        if parent == here:
            raise RegistryError(
                f"no {CONFIG_NAME} found in this directory or any parent.\n"
                f"Install one from the starter kit "
                f"(registries.json.template) at the repository root."
            )
        here = parent


class Registry:
    """One declared registry, with its defaults resolved."""

    def __init__(self, raw: dict, cfg: dict, root: str):
        self.root = root
        self.name = raw.get("name")
        if not self.name:
            raise RegistryError("every registry needs a \"name\"")
        self.kind = raw.get("kind", "entries")
        if self.kind not in ("entries", "changelog", "documents"):
            raise RegistryError(
                f"{self.name}: unknown kind {self.kind!r} "
                f"(expected entries, changelog or documents)"
            )
        self.id_prefix = raw.get("id_prefix", "")
        self.id_scheme = raw.get("id_scheme", cfg.get("id_scheme", "slug"))
        if self.id_scheme not in ("slug", "numeric"):
            raise RegistryError(
                f"{self.name}: unknown id_scheme {self.id_scheme!r} "
                f"(expected \"slug\" or \"numeric\")"
            )
        self.id_width = int(raw.get("id_width", cfg.get("id_width", 3)))
        # Literal text every fragment filename starts with, before the number
        # or date — e.g. "adr-" for the MADR convention adr-NNNN-short-title.md.
        # It is part of the filename only; it never appears in the identifier,
        # which already carries id_prefix.
        self.filename_prefix = raw.get("filename_prefix", "")
        self.fragments = raw.get("fragments")
        if not self.fragments:
            raise RegistryError(f"{self.name}: \"fragments\" directory is required")
        self.output = raw.get("output")
        self.categories = raw.get("categories", DEFAULT_CATEGORIES)
        self.required_fields = raw.get("required_fields", [])
        self.required_headings = raw.get("required_headings", [])
        self.comment = raw.get("comment", cfg.get("comment", "html"))
        if self.comment not in COMMENT_STYLES:
            raise RegistryError(
                f"{self.name}: unknown comment style {self.comment!r} "
                f"(expected one of {', '.join(sorted(COMMENT_STYLES))})"
            )
        self.regen_command = raw.get(
            "regen_command", cfg.get("regen_command", "make registry-generate")
        )
        self.rule_pointer = raw.get(
            "rule_pointer", cfg.get("rule_pointer", "the shared-registries rule file")
        )

    # -- paths ------------------------------------------------------------

    @property
    def fragments_dir(self) -> str:
        return os.path.join(self.root, self.fragments)

    @property
    def output_path(self) -> str | None:
        return os.path.join(self.root, self.output) if self.output else None

    def rel(self, path: str) -> str:
        return os.path.relpath(path, self.root)

    # -- identifiers ------------------------------------------------------

    @property
    def id_pattern(self) -> str:
        """Human-readable description of the identifier this registry expects."""
        if self.id_scheme == "slug":
            return f"{self.id_prefix}-YYYY-MM-DD-<slug>"
        return f"{self.id_prefix}-" + "N" * self.id_width

    def stem_regex(self) -> re.Pattern:
        head = re.escape(self.filename_prefix)
        if self.id_scheme == "slug":
            return re.compile(
                r"^%s(\d{4}-\d{2}-\d{2})-([a-z0-9]+(?:-[a-z0-9]+)*)$" % head
            )
        return re.compile(
            r"^%s(\d{%d})-([a-z0-9]+(?:-[a-z0-9]+)*)$" % (head, self.id_width)
        )

    def id_for(self, path: str) -> str:
        """Derive the identifier from the fragment filename.

        The filename is the *only* home of the identifier. Keeping it there is
        what makes collisions impossible under the slug scheme: two branches
        cannot add the same path without git raising an add/add conflict, which
        is loud. Storing the identifier a second time inside the fragment would
        reintroduce exactly the drift this design removes.
        """
        stem = os.path.splitext(os.path.basename(path))[0]
        match = self.stem_regex().match(stem)
        if not match:
            raise RegistryError(
                f"{self.rel(path)}:1 — malformed fragment name {stem!r}.\n"
                f"  Expected {self._stem_hint()} so the identifier reads "
                f"{self.id_pattern}.\n"
                f"  See {self.rule_pointer}."
            )
        # Under the slug scheme the identifier is the date AND slug; under the
        # numeric scheme only the number is, and the trailing slug is a
        # human-readable filename affordance that never appears in a citation.
        # Either way it comes from the captured groups, so a filename_prefix
        # stays out of the identifier.
        core = (
            f"{match.group(1)}-{match.group(2)}"
            if self.id_scheme == "slug"
            else match.group(1)
        )
        return f"{self.id_prefix}-{core}" if self.id_prefix else core

    def _stem_hint(self) -> str:
        head = self.filename_prefix
        if self.id_scheme == "slug":
            return f"{head}YYYY-MM-DD-<lowercase-slug>.md"
        return f"{head}<{self.id_width}-digit number>-<lowercase-slug>.md"


def load_registries(args) -> tuple[list[Registry], str, dict]:
    cfg, root = find_config(getattr(args, "config", None))
    declared = cfg.get("registries", [])
    if not declared:
        raise RegistryError(f"{CONFIG_NAME} declares no registries")
    registries = [Registry(raw, cfg, root) for raw in declared]
    wanted = getattr(args, "registry", None)
    if wanted:
        registries = [r for r in registries if r.name == wanted]
        if not registries:
            names = ", ".join(r.get("name", "?") for r in declared)
            raise RegistryError(f"unknown registry {wanted!r} (declared: {names})")
    return registries, root, cfg


# --------------------------------------------------------------------------
# fragment discovery and parsing
# --------------------------------------------------------------------------

def _is_fragment(name: str) -> bool:
    """Underscore-prefixed and README files are scaffolding, not entries."""
    if not name.endswith(".md"):
        return False
    return not name.startswith("_") and not name.upper().startswith("README")


def fragment_paths(reg: Registry) -> list[str]:
    base = reg.fragments_dir
    if not os.path.isdir(base):
        return []
    found = []
    for name in os.listdir(base):
        if _is_fragment(name):
            found.append(os.path.join(base, name))
    return sorted(found)


def stray_changelog_paths(reg: Registry) -> list[str]:
    """Fragments nested in a subdirectory, where the generator will not see them.

    `fragment_paths` reads the top level only. A file one directory deeper is
    never assembled and never reported — the bullet simply never appears, with
    no conflict and no error. That silent loss is worth a gate, and it is the
    likely shape of a mistake for anyone who remembers the old category-per-
    directory layout.
    """
    base = reg.fragments_dir
    if not os.path.isdir(base):
        return []
    stray = []
    for current, _directories, files in os.walk(base):
        if os.path.abspath(current) == os.path.abspath(base):
            continue
        for name in files:
            if _is_fragment(name):
                stray.append(os.path.join(current, name))
    return sorted(stray)


def parse_changelog_fragment(reg: Registry, path: str) -> dict[str, list[str]]:
    """Read one per-change fragment into {category: [bullet, ...]}.

    The file is a small readable document rather than a single line: a title
    naming the change, then one section per Keep a Changelog category it
    touches. That granularity is the point — a fragment is a unit of meaning
    ("what this change did"), not a line that happens to own an inode.
    """
    known = {c.lower(): c for c in reg.categories}
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()

    sections: dict[str, list[str]] = {}
    current: str | None = None
    bullets: list[str] = []

    def flush():
        if current and bullets:
            sections.setdefault(current, []).extend(bullets)

    for index, raw in enumerate(lines, start=1):
        if raw.startswith("# "):
            continue  # the title; readability only, never rendered
        if raw.startswith("## "):
            flush()
            bullets = []
            heading = raw[3:].strip()
            if heading.lower() not in known:
                raise RegistryError(
                    f"{reg.rel(path)}:{index} — unknown category "
                    f"'{heading}'.\n"
                    f"  Expected one of: {', '.join(reg.categories)}.\n"
                    f"  See {reg.rule_pointer}."
                )
            current = known[heading.lower()]
            continue
        if raw.lstrip().startswith("<!--"):
            continue  # authoring guidance in the template; never rendered
        if raw.startswith("- "):
            if current is None:
                raise RegistryError(
                    f"{reg.rel(path)}:{index} — bullet before any category "
                    f"heading; it would never reach the changelog.\n"
                    f"  Add a '## <category>' heading above it "
                    f"({', '.join(reg.categories)}).\n"
                    f"  See {reg.rule_pointer}."
                )
            bullets.append(raw[2:].rstrip())
        elif bullets and raw[:1].isspace() and raw.strip():
            # Only an INDENTED line continues the bullet above it. Anything
            # else — prose, a stray comment — is not swept into the changelog,
            # which is how the template's own guidance used to leak into it.
            bullets[-1] += "\n" + raw.rstrip()
    flush()
    return sections


def read_fragment(reg: Registry, path: str) -> tuple[str, str]:
    """Return (title, body). The first level-1 heading is the title."""
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    title = None
    body_start = 0
    for index, line in enumerate(lines):
        if line.startswith("# "):
            title = line[2:].strip()
            body_start = index + 1
            break
        if line.strip():
            break
    if not title:
        raise RegistryError(
            f"{reg.rel(path)}:1 — fragment has no title.\n"
            f"  The first line must be a level-1 heading: '# <title>'.\n"
            f"  See {reg.rule_pointer}."
        )
    return title, "\n".join(lines[body_start:]).strip("\n")


def sort_key(reg: Registry, path: str):
    stem = os.path.splitext(os.path.basename(path))[0]
    if reg.id_scheme == "numeric":
        match = reg.stem_regex().match(stem)
        return (int(match.group(1)), stem) if match else (10**9, stem)
    return (stem,)


# --------------------------------------------------------------------------
# rendering
# --------------------------------------------------------------------------

def markers(reg: Registry) -> tuple[str, str]:
    open_tag, close_tag = COMMENT_STYLES[reg.comment]
    begin = (
        f"{open_tag}BEGIN GENERATED: {reg.name} — do not edit inside this region. "
        f"Add a file under {reg.fragments}/ and run `{reg.regen_command}`.{close_tag}"
    )
    end = f"{open_tag}END GENERATED: {reg.name}{close_tag}"
    return begin, end


def render(reg: Registry) -> str:
    """Assemble the fragments into the body of the managed region."""
    paths = sorted(fragment_paths(reg), key=lambda p: sort_key(reg, p))
    if reg.kind == "changelog":
        return _render_changelog(reg, paths)
    blocks = []
    for path in paths:
        title, body = read_fragment(reg, path)
        entry_id = reg.id_for(path)
        block = f"## {entry_id}: {title}"
        if body:
            block += f"\n\n{body}"
        # A closing line unique to this entry. When two branches each add an
        # entry, git's union merge trims lines that are identical at the edges
        # of the conflict region — and template-driven entries routinely end
        # with the same line (a default **Related:** link, say). Without a
        # unique last line the two entries collapse into each other and one
        # loses its tail, silently. The heading already makes the first line
        # unique; this makes the last one unique too.
        block += f"\n\n<!-- end: {entry_id} -->"
        blocks.append(block)
    return "\n\n".join(blocks)


def _render_changelog(reg: Registry, paths: list[str]) -> str:
    by_category: dict[str, list[str]] = {}
    for path in paths:
        for category, bullets in parse_changelog_fragment(reg, path).items():
            by_category.setdefault(category, []).extend(bullets)
    sections = []
    for category in reg.categories:
        # Every category gets an anchor line, ALWAYS, even when empty — an
        # HTML comment, so nothing shows when rendered. It is merge context:
        # when two branches each add bullets to two categories, git sees one
        # contiguous change per branch and union merge appends the second
        # branch's whole block after the first branch's LAST section, filing
        # its earlier bullets under the wrong heading. With a stable anchor
        # between categories, each category is its own hunk and bullets can
        # only ever land under their own heading.
        block = f"<!-- category: {category} -->"
        bullets = by_category.get(category)
        if bullets:
            body = "\n".join(f"- {b}" for b in bullets)
            block += f"\n### {category}\n\n{body}"
        sections.append(block)
    return "\n\n".join(sections)


def extract_region(reg: Registry, text: str) -> str | None:
    """The lines between the BEGIN and END markers, or None if absent."""
    lines = text.splitlines()
    begin = end = None
    for index, line in enumerate(lines):
        if begin is None and f"BEGIN GENERATED: {reg.name}" in line:
            begin = index
        elif begin is not None and f"END GENERATED: {reg.name}" in line:
            end = index
            break
    if begin is None or end is None:
        return None
    return "\n".join(lines[begin + 1:end])


def _normalise(lines: list[str]) -> str:
    """Trailing whitespace and runs of blank lines carry no meaning."""
    out: list[str] = []
    for line in lines:
        line = line.rstrip()
        if not line and out and not out[-1]:
            continue
        out.append(line)
    while out and not out[0]:
        out.pop(0)
    while out and not out[-1]:
        out.pop()
    return "\n".join(out)


def canonical(reg: Registry, region: str) -> list[tuple[str, str]]:
    """What a generated region SAYS, independent of order and spacing.

    A union merge keeps both branches' generated blocks but not in canonical
    order, and it drops the blank line between them. Byte-equality would fail
    on every concurrent merge and demand a regenerate commit each time — a
    round-trip on every pair, which is most of the friction this whole layout
    exists to remove. So the drift check compares meaning: the same entries
    with the same content, in any order. Returned as a SORTED LIST rather than
    a dict so that a duplicated heading with two different bodies — the
    edit-versus-edit case union merge hides — shows up as two items and fails.
    """
    items: list[tuple[str, str]] = []
    if reg.kind == "changelog":
        category = None
        bullets: list[str] = []

        def flush():
            for bullet in bullets:
                items.append((category or "", _normalise(bullet.splitlines())))

        for line in region.splitlines():
            if line.startswith("<!-- category: "):
                continue
            if line.startswith("### "):
                flush()
                category, bullets = line[4:].strip(), []
            elif line.startswith("- "):
                bullets.append(line[2:])
            elif bullets and line[:1].isspace() and line.strip():
                bullets[-1] += "\n" + line
        flush()
    else:
        heading = None
        body: list[str] = []
        for line in region.splitlines():
            if line.startswith("<!-- end: "):
                continue
            if line.startswith("## "):
                if heading is not None:
                    items.append((heading, _normalise(body)))
                heading, body = line[3:].strip(), []
            elif heading is not None:
                body.append(line)
        if heading is not None:
            items.append((heading, _normalise(body)))
    return sorted(items)


def splice(reg: Registry, existing: str, body: str) -> str:
    """Replace the managed region of `existing` with `body`."""
    begin, end = markers(reg)
    lines = existing.splitlines()
    begin_index = end_index = None
    for index, line in enumerate(lines):
        if begin_index is None and f"BEGIN GENERATED: {reg.name}" in line:
            begin_index = index
        elif f"END GENERATED: {reg.name}" in line:
            end_index = index
            break
    if begin_index is None or end_index is None:
        raise RegistryError(
            f"{reg.rel(reg.output_path)}:1 — the generated region is missing.\n"
            f"  Add these two lines where the entries belong:\n"
            f"    {begin}\n    {end}\n"
            f"  See {reg.rule_pointer}."
        )
    inner = [begin] + ([""] + body.splitlines() + [""] if body else [""]) + [end]
    return "\n".join(lines[:begin_index] + inner + lines[end_index + 1:]) + "\n"


# --------------------------------------------------------------------------
# subcommands
# --------------------------------------------------------------------------

def slugify(text: str, limit: int = 56) -> str:
    normalized = unicodedata.normalize("NFKD", text)
    ascii_only = normalized.encode("ascii", "ignore").decode("ascii").lower()
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_only).strip("-")
    if len(slug) > limit:
        slug = slug[:limit].rsplit("-", 1)[0] or slug[:limit]
    return slug.strip("-")


def next_number(reg: Registry) -> str:
    """Allocate the next free number by scanning the working tree.

    This sees only the local checkout: two branches open at the same time will
    both be handed the same number. That race is intentional to leave visible —
    it is why the `check` gate exists, and why the slug scheme is the default.
    """
    highest = 0
    head = re.escape(reg.filename_prefix)
    for path in fragment_paths(reg):
        match = re.match(head + r"(\d+)-", os.path.splitext(os.path.basename(path))[0])
        if match:
            highest = max(highest, int(match.group(1)))
    return str(highest + 1).zfill(reg.id_width)


def fragment_template(reg: Registry, title: str, category: str | None = None) -> str:
    if reg.kind == "changelog":
        first = category or reg.categories[0]
        others = ", ".join(c for c in reg.categories if c != first)
        return (
            f"# {title}\n\n"
            f"## {first}\n\n"
            f"- <what an operator will observe after the deploy>\n\n"
            f"<!-- One section per category this change touches. Others "
            f"available: {others}. Delete this comment. -->\n"
        )
    lines = [f"# {title}", ""]
    for field in reg.required_fields:
        lines.append(f"**{field}:** <fill in>")
        lines.append("")
    for heading in reg.required_headings:
        lines.append(f"## {heading}")
        lines.append("")
        lines.append("<fill in>")
        lines.append("")
    return "\n".join(lines).rstrip("\n") + "\n"


def cmd_new(args) -> int:
    registries, _, _ = load_registries(args)
    reg = registries[0]
    if len(registries) > 1:
        raise RegistryError("--registry is required for `new`")

    slug = args.slug or slugify(args.title)
    if not slug or not SLUG_RE.match(slug):
        raise RegistryError(
            f"cannot derive a usable slug from {args.title!r}; pass --slug explicitly"
        )

    if reg.id_scheme == "slug":
        date = args.date or _dt.date.today().isoformat()
        if not DATE_RE.match(date):
            raise RegistryError(f"--date must be YYYY-MM-DD, got {date!r}")
        stem = f"{reg.filename_prefix}{date}-{slug}"
    else:
        stem = f"{reg.filename_prefix}{next_number(reg)}-{slug}"

    directory = reg.fragments_dir
    category = None
    if reg.kind == "changelog":
        # One fragment per change, holding every category that change touches.
        # --category only seeds the first section; the rest are added by hand,
        # because a change that spans categories is one unit of work and reads
        # better as one file than as three.
        if args.category:
            match = [c for c in reg.categories if c.lower() == args.category.lower()]
            if not match:
                raise RegistryError(
                    f"unknown category {args.category!r} "
                    f"(expected one of: {', '.join(reg.categories)})"
                )
            category = match[0]
        # Changelog entries are never cited by identifier, so they always use a
        # date-slug name regardless of the project's identifier scheme.
        date = args.date or _dt.date.today().isoformat()
        stem = f"{date}-{slug}"

    os.makedirs(directory, exist_ok=True)
    path = os.path.join(directory, f"{stem}.md")
    if os.path.exists(path):
        raise RegistryError(f"{reg.rel(path)} already exists — pick a different --slug")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(fragment_template(reg, args.title, category))

    print(reg.rel(path))
    if reg.kind != "changelog" and reg.id_prefix:
        print(f"identifier: {reg.id_for(path)}", file=sys.stderr)
    if reg.id_scheme == "numeric" and reg.kind != "changelog":
        print(
            "note: the number was allocated from this checkout only; a branch "
            "opened in parallel may claim the same one. `check` is the backstop.",
            file=sys.stderr,
        )
    return 0


def cmd_generate(args) -> int:
    registries, _, _ = load_registries(args)
    failures = 0
    for reg in registries:
        if not reg.output_path:
            continue  # one file per entry — nothing to assemble
        if not os.path.isfile(reg.output_path):
            raise RegistryError(
                f"{reg.rel(reg.output_path)} does not exist.\n"
                f"  Install it from the starter kit, or create it with the "
                f"generated-region markers in place."
            )
        with open(reg.output_path, encoding="utf-8") as fh:
            current = fh.read()
        updated = splice(reg, current, render(reg))
        if args.check:
            if current != updated:
                before = extract_region(reg, current)
                after = extract_region(reg, updated)
                if (
                    before is not None
                    and after is not None
                    and canonical(reg, before) == canonical(reg, after)
                    and current.replace(before, "", 1) == updated.replace(after, "", 1)
                ):
                    # Same entries, same content, same surroundings — only the
                    # order or spacing inside the region differs. That is what
                    # a union merge leaves behind, and it is not drift.
                    print(
                        f"OK: {reg.rel(reg.output_path)} matches its fragments "
                        f"(order/spacing is non-canonical after a merge; the "
                        f"next `{reg.regen_command}` will normalise it)"
                    )
                    continue
                failures += 1
                print(
                    f"FAIL: {reg.rel(reg.output_path)} is out of date with "
                    f"{reg.fragments}/",
                    file=sys.stderr,
                )
                diff = difflib.unified_diff(
                    current.splitlines(True),
                    updated.splitlines(True),
                    fromfile=f"{reg.rel(reg.output_path)} (committed)",
                    tofile=f"{reg.rel(reg.output_path)} (regenerated)",
                    n=2,
                )
                sys.stderr.writelines(diff)
                print(
                    f"  Run `{reg.regen_command}` and commit the result. "
                    f"See {reg.rule_pointer}.",
                    file=sys.stderr,
                )
        elif current != updated:
            with open(reg.output_path, "w", encoding="utf-8") as fh:
                fh.write(updated)
            print(f"regenerated {reg.rel(reg.output_path)}")
    if args.check and failures == 0:
        print("OK: every generated registry artifact matches its fragments")
    return 1 if failures else 0


def load_allowlist(root: str) -> set[frozenset]:
    """Sanctioned duplicate pairs, keyed on the FILENAME PAIR — never on the
    identifier. A number-keyed entry would read as "this number is exempt" and
    would silently tolerate a *third* file joining a legacy pair, which is the
    exact drift the gate exists to catch."""
    path = os.path.join(root, ALLOWLIST_NAME)
    pairs: set[frozenset] = set()
    if not os.path.isfile(path):
        return pairs
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            parts = line.split()
            if len(parts) != 2:
                raise RegistryError(
                    f"{ALLOWLIST_NAME}: each line must name exactly two "
                    f"fragment paths, got: {line}"
                )
            pairs.add(frozenset(parts))
    return pairs


def cmd_check(args) -> int:
    registries, root, _ = load_registries(args)
    allowlist = load_allowlist(root)
    failures = 0

    for reg in registries:
        paths = fragment_paths(reg)
        if reg.kind == "changelog":
            # Bullets carry no identifier; the path is the only key, and git
            # already guarantees paths are unique. What can go wrong instead is
            # placement: a fragment under a mistyped category directory is
            # never scanned by the generator, so the bullet simply never
            # appears — no conflict, no error, no missing-line symptom. That is
            # the silent loss this whole design exists to remove, so the gate
            # looks at every file under the tree, not only the ones the
            # generator would find.
            for path in paths:
                try:
                    read_fragment(reg, path)
                    sections = parse_changelog_fragment(reg, path)
                except RegistryError as exc:
                    failures += 1
                    print(f"FAIL: {exc}", file=sys.stderr)
                    continue
                if any("<what an operator" in b for bs in sections.values() for b in bs):
                    failures += 1
                    print(
                        f"FAIL: {reg.rel(path)}:1 — still contains the template "
                        f"placeholder bullet. Replace it with what changed. "
                        f"See {reg.rule_pointer}.",
                        file=sys.stderr,
                    )
                if not sections:
                    failures += 1
                    print(
                        f"FAIL: {reg.rel(path)}:1 — no bullets under any "
                        f"category, so this fragment contributes nothing.\n"
                        f"  Add '## <category>' with at least one '- ' bullet, "
                        f"or delete the file. See {reg.rule_pointer}.",
                        file=sys.stderr,
                    )
            for path in stray_changelog_paths(reg):
                failures += 1
                print(
                    f"FAIL: {reg.rel(path)}:1 — this fragment is nested in a "
                    f"subdirectory, where the generator never looks, so its "
                    f"bullets would silently never reach the changelog.\n"
                    f"  Move it directly into {reg.fragments}/ and put the "
                    f"category as a '## ' heading inside the file.\n"
                    f"  See {reg.rule_pointer}.",
                    file=sys.stderr,
                )
            continue

        # 1. SHAPE first. A digit-count variant (ISSUE-7 next to ISSUE-007)
        #    walks straight past a uniqueness test that only compares numbers,
        #    so the shape assertion has to come first or it buys nothing.
        seen: dict[str, list[str]] = {}
        for path in paths:
            try:
                entry_id = reg.id_for(path)
            except RegistryError as exc:
                failures += 1
                print(f"FAIL: {exc}", file=sys.stderr)
                continue
            seen.setdefault(entry_id, []).append(path)
            try:
                _, body = read_fragment(reg, path)
            except RegistryError as exc:
                failures += 1
                print(f"FAIL: {exc}", file=sys.stderr)
                continue
            if "<fill in>" in body:
                failures += 1
                print(
                    f"FAIL: {reg.rel(path)}:1 — still contains the template "
                    f"placeholder '<fill in>'. Complete or delete the field. "
                    f"See {reg.rule_pointer}.",
                    file=sys.stderr,
                )
            for field in reg.required_fields:
                if f"**{field}:**" not in body:
                    failures += 1
                    print(
                        f"FAIL: {reg.rel(path)}:1 — missing required field "
                        f"**{field}:**. See {reg.rule_pointer}.",
                        file=sys.stderr,
                    )
            for heading in reg.required_headings:
                if not re.search(rf"^##\s+{re.escape(heading)}", body, re.M):
                    failures += 1
                    print(
                        f"FAIL: {reg.rel(path)}:1 — missing required section "
                        f"'## {heading}'. See {reg.rule_pointer}.",
                        file=sys.stderr,
                    )

        # 2. Then uniqueness.
        for entry_id, owners in sorted(seen.items()):
            if len(owners) < 2:
                continue
            rels = sorted(reg.rel(p) for p in owners)
            if len(rels) == 2 and frozenset(rels) in allowlist:
                print(
                    f"note: {entry_id} is a sanctioned duplicate pair "
                    f"({', '.join(rels)})",
                    file=sys.stderr,
                )
                continue
            failures += 1
            print(
                f"FAIL: duplicate identifier {entry_id} claimed by "
                f"{len(rels)} fragments:",
                file=sys.stderr,
            )
            for rel in rels:
                print(f"  {rel}:1", file=sys.stderr)
            print(
                "  Identifiers are citation targets: renaming one after it has "
                "been cited breaks the citation.\n"
                "  Rename the fragment that has NOT been merged yet, then "
                f"regenerate. See {reg.rule_pointer}.",
                file=sys.stderr,
            )

    if failures == 0:
        print("OK: registry identifiers are well-shaped and unique")
    return 1 if failures else 0


def cmd_release(args) -> int:
    registries, _, _ = load_registries(args)
    if len(registries) != 1:
        raise RegistryError("--registry is required for `release`")
    reg = registries[0]
    if reg.kind != "changelog":
        raise RegistryError(f"`release` applies to changelog registries, not {reg.kind}")

    date = args.date or _dt.date.today().isoformat()
    if not DATE_RE.match(date):
        raise RegistryError(f"--date must be YYYY-MM-DD, got {date!r}")

    paths = sorted(fragment_paths(reg), key=lambda p: sort_key(reg, p))
    if not paths:
        raise RegistryError(
            f"{reg.fragments}/ holds no entries — there is nothing to release."
        )
    body = _render_changelog(reg, paths)

    with open(reg.output_path, encoding="utf-8") as fh:
        current = fh.read()
    lines = current.splitlines()
    end_index = next(
        (i for i, line in enumerate(lines) if f"END GENERATED: {reg.name}" in line),
        None,
    )
    if end_index is None:
        raise RegistryError(
            f"{reg.rel(reg.output_path)}:1 — generated region not found; "
            f"run `{reg.regen_command}` first."
        )

    section = [""] + f"## [{args.version}] — {date}".splitlines() + [""] + body.splitlines()
    updated = "\n".join(lines[: end_index + 1] + section + lines[end_index + 1:]) + "\n"
    with open(reg.output_path, "w", encoding="utf-8") as fh:
        fh.write(updated)

    # Promotion consumes the fragments. A branch that appended one in parallel
    # still holds its own file, so its bullet reappears under [Unreleased] on
    # the next generate instead of being merged into a section that moved.
    for path in paths:
        os.remove(path)

    with open(reg.output_path, encoding="utf-8") as fh:
        current = fh.read()
    with open(reg.output_path, "w", encoding="utf-8") as fh:
        fh.write(splice(reg, current, render(reg)))

    print(f"released {args.version} ({len(paths)} entries promoted)")
    return 0


def _infer_numbered_convention(paths: list[str]) -> tuple[str, int] | None:
    """From existing filenames, the (filename_prefix, id_width) they all share.

    Recognises the shapes real repositories use: adr-tools' 0001-title.md, the
    MADR-style adr-0001-title.md, ADR-001-title.md, and 001-title.md. Returns
    None when the files disagree with each other or none are numbered — the
    caller then keeps the default rather than guessing.
    """
    seen: set[tuple[str, int]] = set()
    for path in paths:
        stem = os.path.splitext(os.path.basename(path))[0]
        match = re.match(r"^([A-Za-z]+[-_])?(\d+)-", stem)
        if not match:
            return None
        seen.add((match.group(1) or "", len(match.group(2))))
    return next(iter(seen)) if len(seen) == 1 else None


def cmd_init(args) -> int:
    """Write registries.json to match what the repository ALREADY has.

    Greenfield gets the kit's defaults. Brownfield gets its own conventions
    back: an adr-tools directory of 0001-title.md files is declared as
    numeric, width 4, no prefix, so the identifier gate passes on day one
    instead of rejecting every existing record; a knowledge base full of
    ISSUE-042 entries is declared numeric at width 3, freezing the
    identifiers that are already cited. Document reality, not aspiration.
    """
    root = os.getcwd()
    target = os.path.join(root, CONFIG_NAME)
    if os.path.exists(target) and not args.force:
        print(f"{CONFIG_NAME} already exists — leaving it alone (use --force to rewrite)")
        return 0

    notes: list[str] = []
    registries: list[dict] = []

    # --- knowledge base ----------------------------------------------------
    kb_out = "docs/DEBUGGING-KNOWLEDGE-BASE.md"
    kb: dict = {
        "name": "debugging-kb", "kind": "entries", "id_prefix": "ISSUE",
        "fragments": "docs/DEBUGGING-KNOWLEDGE-BASE.d", "output": kb_out,
        "required_fields": ["Symptom", "Investigation Trail", "Root Cause",
                            "Fix", "Prevention", "Debug Shortcut"],
    }
    adoc = os.path.join(root, "docs/DEBUGGING-KNOWLEDGE-BASE.adoc")
    if os.path.isfile(os.path.join(root, kb_out)):
        with open(os.path.join(root, kb_out), encoding="utf-8") as fh:
            heads = re.findall(r"^#{2,3} ([A-Z]+)-(\d+)[:\s]", fh.read(), re.M)
        if heads:
            prefix = heads[0][0]
            widths = {len(n) for _, n in heads}
            if len(widths) == 1:
                kb["id_prefix"] = prefix
                kb["id_scheme"] = "numeric"
                kb["id_width"] = widths.pop()
                notes.append(
                    f"knowledge base: {len(heads)} existing {prefix}-NNN entries -> "
                    f"numeric scheme, width {kb['id_width']} (identifiers frozen; "
                    f"run `adopt --registry debugging-kb` to move them into fragments)"
                )
            else:
                notes.append(
                    f"knowledge base: existing entries use MIXED identifier widths "
                    f"{sorted(widths)} — left at the default; fix the headings, then re-run init --force"
                )
        else:
            notes.append("knowledge base: present, no entries yet -> slug scheme (default)")
    elif os.path.isfile(adoc):
        notes.append(
            "knowledge base: found docs/DEBUGGING-KNOWLEDGE-BASE.adoc — AsciiDoc is not "
            "supported by the generator; the registry is declared against the .md path "
            "and the .adoc file is left untouched. Convert, or leave it out of the layout."
        )
    else:
        notes.append("knowledge base: none found -> declared at the default path, slug scheme")
    registries.append(kb)

    # --- changelog ---------------------------------------------------------
    registries.append({
        "name": "changelog", "kind": "changelog", "fragments": "changelog.d",
        "output": "CHANGELOG.md",
        "categories": ["Added", "Changed", "Deprecated", "Removed", "Fixed", "Security"],
    })
    if os.path.isfile(os.path.join(root, "CHANGELOG.md")):
        notes.append("changelog: CHANGELOG.md exists -> run `adopt --registry changelog` to move its [Unreleased] bullets into a fragment")
    else:
        notes.append("changelog: none found -> install CHANGELOG.md.template, or let bootstrap do it")

    # --- decision records --------------------------------------------------
    adr_dir = next(
        (d for d in ("docs/adr", "docs/decisions", "doc/adr", "adr", "docs/architecture/decisions")
         if os.path.isdir(os.path.join(root, d))),
        "docs/adr",
    )
    adr: dict = {
        "name": "adr", "kind": "documents", "id_prefix": "ADR", "id_width": 4,
        "filename_prefix": "adr-", "fragments": adr_dir,
        "required_headings": ["Status", "Context", "Decision", "Consequences"],
    }
    existing = [
        os.path.join(root, adr_dir, n) for n in
        (os.listdir(os.path.join(root, adr_dir)) if os.path.isdir(os.path.join(root, adr_dir)) else [])
        if _is_fragment(n)
    ]
    if existing:
        inferred = _infer_numbered_convention(existing)
        if inferred:
            adr["filename_prefix"], adr["id_width"] = inferred
            adr["id_scheme"] = "numeric"
            shown = f"{inferred[0]}{'N' * inferred[1]}-<slug>.md"
            notes.append(
                f"decision records: {len(existing)} existing files in {adr_dir}/ named "
                f"{shown} -> numeric, width {inferred[1]}, filename_prefix "
                f"{inferred[0]!r} (existing names and identifiers preserved)"
            )
        else:
            notes.append(
                f"decision records: {len(existing)} files in {adr_dir}/ with no single "
                f"numbering convention — declared with the kit default; the identifier "
                f"gate will name each file that does not match"
            )
        # Which section headings do they actually use?
        with open(existing[0], encoding="utf-8") as fh:
            heads = [l[3:].strip() for l in fh.read().splitlines() if l.startswith("## ")]
        present = [h for h in adr["required_headings"] if any(x.lower().startswith(h.lower()) for x in heads)]
        if len(present) < len(adr["required_headings"]):
            missing = [h for h in adr["required_headings"] if h not in present]
            adr["required_headings"] = present
            notes.append(
                f"decision records: existing records lack {missing} sections — "
                f"required_headings relaxed to {present} so the gate matches reality; "
                f"tighten it once the records carry them"
            )
    else:
        notes.append(f"decision records: none found -> {adr_dir}/, MADR naming adr-NNNN-<slug>.md")
    registries.append(adr)

    scheme = "numeric" if any(r.get("id_scheme") == "numeric" for r in registries) else "slug"
    config = {
        "_readme": [
            "Written by `registry_tool.py init` from what this repository already had.",
            "Edit freely; re-run `init --force` to regenerate from the files on disk.",
            "See the shared-registries rule for what each field means.",
        ],
        "id_scheme": scheme,
        "id_width": 3,
        "regen_command": "make registry-generate",
        "rule_pointer": ".claude/rules/shared-registries.md",
        "registries": registries,
    }
    with open(target, "w", encoding="utf-8") as fh:
        json.dump(config, fh, indent=2)
        fh.write("\n")
    print(f"wrote {CONFIG_NAME}")
    for note in notes:
        print(f"  - {note}")
    return 0


def cmd_adopt(args) -> int:
    """Bring an existing hand-maintained artifact under the fragment layout.

    The brownfield case: a repository already has a CHANGELOG.md with bullets
    under [Unreleased], or a knowledge base full of entries, and no generated
    region. This moves the existing content into fragments, installs the
    markers, and regenerates — losslessly, and only once: if the markers are
    already present there is nothing to do.
    """
    registries, _, _ = load_registries(args)
    if len(registries) != 1:
        raise RegistryError("--registry is required for `adopt`")
    reg = registries[0]
    if not reg.output_path:
        raise RegistryError(f"{reg.name} has no output artifact to adopt")
    if not os.path.isfile(reg.output_path):
        raise RegistryError(f"{reg.rel(reg.output_path)} does not exist")

    with open(reg.output_path, encoding="utf-8") as fh:
        text = fh.read()
    if extract_region(reg, text) is not None:
        print(f"{reg.rel(reg.output_path)} already has a generated region — nothing to adopt")
        return 0

    begin, end = markers(reg)
    lines = text.splitlines()
    date = args.date or _dt.date.today().isoformat()
    os.makedirs(reg.fragments_dir, exist_ok=True)

    if reg.kind == "changelog":
        # Everything between "## [Unreleased]" and the next "## [" heading
        # becomes one migration fragment, category by category.
        unreleased = re.compile(r"^##\s+\[?unreleased\]?\s*$", re.I)
        start = next((i for i, l in enumerate(lines) if unreleased.match(l)), None)
        if start is None:
            raise RegistryError(
                f"{reg.rel(reg.output_path)}:1 — no '## [Unreleased]' (or '## Unreleased') "
                f"heading to adopt under"
            )
        if lines[start].strip() != "## [Unreleased]":
            lines[start] = "## [Unreleased]"
            print("normalised the heading to '## [Unreleased]' (Keep a Changelog form)")
        stop = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## [")), len(lines))
        section = lines[start + 1:stop]
        moved: list[str] = []
        category = None
        for line in section:
            if line.startswith("### "):
                category = line[4:].strip()
                moved.append(f"## {category}")
            elif line.startswith("- ") or (line[:1].isspace() and line.strip()):
                if category is None:
                    # Bullets with no category heading are common in changelogs
                    # that never used Keep a Changelog subsections. File them
                    # under a category THIS registry declares — Changed where it
                    # exists, else the first one — rather than failing, which
                    # would lose the adoption, or naming one the gate rejects.
                    category = "Changed" if "Changed" in reg.categories else reg.categories[0]
                    moved.append(f"## {category}")
                    print(
                        f"note: bullets under [Unreleased] had no '### Category' "
                        f"heading — filed under {category}; move them in the "
                        f"fragment if another category fits"
                    )
                moved.append(line)
            elif line.strip():
                moved.append(line)  # prose; kept verbatim inside the fragment
        fragment = os.path.join(reg.fragments_dir, f"{date}-migrated-from-changelog.md")
        if any(l.startswith("- ") for l in moved):
            with open(fragment, "w", encoding="utf-8") as fh:
                fh.write("# Migrated from CHANGELOG.md [Unreleased]\n\n" + "\n".join(moved).rstrip() + "\n")
            print(f"moved {sum(1 for l in moved if l.startswith('- '))} bullets into {reg.rel(fragment)}")
        lines[start + 1:stop] = ["", begin, "", end, ""]
    else:
        # Every "## <ID>: <title>" block becomes its own fragment; the prose
        # above the first entry stays in the artifact as its header.
        pattern = re.compile(
            rf"^#{{2,3}} {re.escape(reg.id_prefix)}-(\S+?)\s*(?::|—|-)\s+(.+)$"
        )
        heads = [i for i, l in enumerate(lines) if pattern.match(l)]
        if not heads:
            raise RegistryError(
                f"{reg.rel(reg.output_path)} — no '## {reg.id_prefix}-<id>: <title>' entries to adopt"
            )
        if reg.id_scheme == "slug":
            raise RegistryError(
                f"{reg.name} uses the slug scheme, but existing entries carry "
                f"allocated identifiers. Set id_scheme \"numeric\" for this "
                f"registry to FREEZE them (never renumber what is cited), then "
                f"re-run adopt."
            )
        count = 0
        for n, head in enumerate(heads):
            stop = heads[n + 1] if n + 1 < len(heads) else len(lines)
            match = pattern.match(lines[head])
            if not match:
                raise RegistryError(
                    f"{reg.rel(reg.output_path)}:{head + 1} — heading does not "
                    f"match '## {reg.id_prefix}-<id>: <title>': {lines[head]}"
                )
            number, title = match.group(1), match.group(2).strip()
            if not number.isdigit() or len(number) != reg.id_width:
                raise RegistryError(
                    f"{reg.rel(reg.output_path)}:{head + 1} — identifier "
                    f"{reg.id_prefix}-{number} is not {reg.id_width} digits; "
                    f"set id_width to match the existing entries"
                )
            body = _normalise(lines[head + 1:stop])
            slug = slugify(title) or "entry"
            fragment = os.path.join(reg.fragments_dir, f"{reg.filename_prefix}{number}-{slug}.md")
            if os.path.exists(fragment):
                raise RegistryError(f"{reg.rel(fragment)} already exists — adopt would overwrite it")
            with open(fragment, "w", encoding="utf-8") as fh:
                fh.write(f"# {title}\n\n{body}\n" if body else f"# {title}\n")
            count += 1
        lines[heads[0]:] = [begin, "", end]
        print(f"moved {count} entries into {reg.fragments}/")

    with open(reg.output_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines).rstrip("\n") + "\n")
    with open(reg.output_path, encoding="utf-8") as fh:
        current = fh.read()
    with open(reg.output_path, "w", encoding="utf-8") as fh:
        fh.write(splice(reg, current, render(reg)))
    print(f"installed the generated region in {reg.rel(reg.output_path)} and regenerated")
    return 0


def cmd_list(args) -> int:
    registries, root, _ = load_registries(args)
    print(f"registries declared in {os.path.join(root, CONFIG_NAME)}:")
    for reg in registries:
        count = len(fragment_paths(reg))
        target = reg.output or "(one file per entry — not assembled)"
        print(f"  {reg.name}")
        print(f"    kind       {reg.kind}")
        print(f"    scheme     {reg.id_scheme}  →  {reg.id_pattern}")
        print(f"    fragments  {reg.fragments}/  ({count} entries)")
        print(f"    output     {target}")
    return 0


# --------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="registry_tool.py",
        description=__doc__.split("\n\n")[0],
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--config", help=f"path to {CONFIG_NAME} (default: search upwards)")
    sub = parser.add_subparsers(dest="command", required=True)

    p_new = sub.add_parser("new", help="create a fragment for a new entry")
    p_new.add_argument("--registry", required=True)
    p_new.add_argument("--title", required=True)
    p_new.add_argument("--slug", help="override the slug derived from --title")
    p_new.add_argument("--category", help="changelog registries only")
    p_new.add_argument("--date", help="YYYY-MM-DD (default: today)")
    p_new.set_defaults(func=cmd_new)

    p_gen = sub.add_parser("generate", help="assemble fragments into the artifact")
    p_gen.add_argument("--registry")
    p_gen.add_argument(
        "--check",
        action="store_true",
        help="do not write; fail if the committed artifact differs (drift check)",
    )
    p_gen.set_defaults(func=cmd_generate)

    p_check = sub.add_parser("check", help="validate identifier shape and uniqueness")
    p_check.add_argument("--registry")
    p_check.set_defaults(func=cmd_check)

    p_rel = sub.add_parser("release", help="promote changelog entries into a version")
    p_rel.add_argument("--registry", required=True)
    p_rel.add_argument("--version", required=True)
    p_rel.add_argument("--date", help="YYYY-MM-DD (default: today)")
    p_rel.set_defaults(func=cmd_release)

    p_init = sub.add_parser(
        "init", help="write registries.json to match what the repository already has"
    )
    p_init.add_argument("--force", action="store_true", help="rewrite an existing config")
    p_init.set_defaults(func=cmd_init)

    p_adopt = sub.add_parser(
        "adopt", help="move an existing hand-maintained artifact into fragments"
    )
    p_adopt.add_argument("--registry", required=True)
    p_adopt.add_argument("--date", help="YYYY-MM-DD for the migration fragment (default: today)")
    p_adopt.set_defaults(func=cmd_adopt)

    p_list = sub.add_parser("list", help="show the declared registries")
    p_list.add_argument("--registry")
    p_list.set_defaults(func=cmd_list)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except RegistryError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
