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
        if self.id_scheme == "slug":
            return re.compile(r"^(\d{4}-\d{2}-\d{2})-([a-z0-9]+(?:-[a-z0-9]+)*)$")
        return re.compile(r"^(\d{%d})-([a-z0-9]+(?:-[a-z0-9]+)*)$" % self.id_width)

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
        # Under the slug scheme the whole stem is the identifier (date AND
        # slug); under the numeric scheme only the number is, and the trailing
        # slug is a human-readable filename affordance that never appears in a
        # citation.
        core = stem if self.id_scheme == "slug" else match.group(1)
        return f"{self.id_prefix}-{core}" if self.id_prefix else core

    def _stem_hint(self) -> str:
        if self.id_scheme == "slug":
            return "YYYY-MM-DD-<lowercase-slug>.md"
        return f"<{self.id_width}-digit number>-<lowercase-slug>.md"


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
        blocks.append(block)
    return "\n\n".join(blocks)


def _render_changelog(reg: Registry, paths: list[str]) -> str:
    by_category: dict[str, list[str]] = {}
    for path in paths:
        for category, bullets in parse_changelog_fragment(reg, path).items():
            by_category.setdefault(category, []).extend(bullets)
    sections = []
    for category in reg.categories:
        bullets = by_category.get(category)
        if bullets:
            body = "\n".join(f"- {b}" for b in bullets)
            sections.append(f"### {category}\n\n{body}")
    return "\n\n".join(sections)


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
    for path in fragment_paths(reg):
        match = re.match(r"^(\d+)-", os.path.splitext(os.path.basename(path))[0])
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
        stem = f"{date}-{slug}"
    else:
        stem = f"{next_number(reg)}-{slug}"

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
