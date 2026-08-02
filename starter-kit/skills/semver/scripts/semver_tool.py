#!/usr/bin/env python3
"""
semver_tool.py — deterministic operations on SemVer 2.0.0 versions.

Implements the official spec (https://semver.org/spec/v2.0.0.html) exactly.
Uses the official regex from the spec's FAQ with no shortcuts.

Subcommands:
    validate VERSION                 → exit 0 if valid SemVer, 1 otherwise.
                                       Strict: `v1.2.3` is NOT a SemVer (FAQ);
                                       the output hints at the underlying SemVer.
    parse VERSION                    → JSON breakdown of components.
    compare V1 V2                    → -1 / 0 / 1 per §11 precedence rules.
    bump VERSION (major|minor|patch) → next version, with resets per §7/§8.
    bump VERSION pre(major|minor|patch) TAG
                                     → bump core, then start `-TAG.1` — a
                                       pre-release of the NEXT version.
    bump VERSION prerelease [TAG]    → iterate a pre-release identifier.
                                       Warns if the result sorts at or below
                                       the input (precedence downgrade).
    bump VERSION release             → strip pre-release & build metadata.
                                       Errors if there is nothing to strip
                                       (re-releasing an identical version
                                       would violate §3 immutability).
    sort V1 V2 [V3 ...]              → newline-separated, ascending precedence.

`validate` is strict per the spec. The other commands strip a leading `v`
(git-tag convention) for convenience before operating.

Build metadata is preserved by `parse`. It is dropped by
`bump major|minor|patch|release` (a new release starts clean) and ignored
by `compare`/`sort` (per §10, build metadata does not affect precedence).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from typing import Optional


# Official regex from the semver.org spec FAQ, numbered capture groups.
# Compatible with ECMAScript, PCRE, Python, Go.
SEMVER_RE = re.compile(
    r"^"
    r"(0|[1-9]\d*)"
    r"\.(0|[1-9]\d*)"
    r"\.(0|[1-9]\d*)"
    r"(?:-("
    r"(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)"
    r"(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*"
    r"))?"
    r"(?:\+("
    r"[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*"
    r"))?"
    r"$"
)


@dataclass(frozen=True)
class Version:
    major: int
    minor: int
    patch: int
    prerelease: tuple[str, ...] = field(default_factory=tuple)
    build: tuple[str, ...] = field(default_factory=tuple)

    def __str__(self) -> str:
        core = f"{self.major}.{self.minor}.{self.patch}"
        if self.prerelease:
            core += "-" + ".".join(self.prerelease)
        if self.build:
            core += "+" + ".".join(self.build)
        return core


def strip_v_prefix(s: str) -> str:
    """`v1.2.3` is a common convention but not a SemVer (per FAQ). Strip it."""
    return s[1:] if s.startswith("v") and len(s) > 1 else s


def parse(version: str) -> Version:
    """Parse a SemVer string. Raises ValueError if invalid."""
    s = strip_v_prefix(version)
    m = SEMVER_RE.match(s)
    if not m:
        raise ValueError(f"Not a valid SemVer 2.0.0 version: {version!r}")
    major, minor, patch, pre, build = m.groups()
    return Version(
        major=int(major),
        minor=int(minor),
        patch=int(patch),
        prerelease=tuple(pre.split(".")) if pre else (),
        build=tuple(build.split(".")) if build else (),
    )


def is_valid(version: str) -> bool:
    """Strict validity per the spec: `v1.2.3` is NOT a valid SemVer (FAQ)."""
    return SEMVER_RE.match(version) is not None


def _compare_identifier(a: str, b: str) -> int:
    """Compare two pre-release identifiers per spec §11.4."""
    a_numeric = a.isdigit()
    b_numeric = b.isdigit()
    if a_numeric and b_numeric:
        # §11.4.1: pure numeric compared numerically.
        return (int(a) > int(b)) - (int(a) < int(b))
    if a_numeric and not b_numeric:
        # §11.4.3: numeric < alphanumeric.
        return -1
    if b_numeric and not a_numeric:
        return 1
    # §11.4.2: both alphanumeric, compare lexically (ASCII).
    return (a > b) - (a < b)


def _compare_prerelease(a: tuple[str, ...], b: tuple[str, ...]) -> int:
    """Compare pre-release identifier tuples per spec §11.3 & §11.4."""
    # §11.3: no pre-release outranks a pre-release.
    if not a and not b:
        return 0
    if not a:
        return 1   # `a` has no pre-release, `a` is the normal release.
    if not b:
        return -1
    # §11.4: identifier-by-identifier.
    for x, y in zip(a, b):
        c = _compare_identifier(x, y)
        if c != 0:
            return c
    # §11.4.4: all leading equal; longer wins.
    return (len(a) > len(b)) - (len(a) < len(b))


def compare(v1: Version, v2: Version) -> int:
    """Compare two Versions per spec §11. Build metadata ignored (§10)."""
    for attr in ("major", "minor", "patch"):
        a = getattr(v1, attr)
        b = getattr(v2, attr)
        if a != b:
            return -1 if a < b else 1
    return _compare_prerelease(v1.prerelease, v2.prerelease)


def bump(version: Version, kind: str, tag: Optional[str] = None) -> Version:
    """
    Bump a version.

    kind:
      'major'      → bump major, reset minor=0, patch=0, drop pre/build (§8).
      'minor'      → bump minor, reset patch=0, drop pre/build (§7).
      'patch'      → bump patch, drop pre/build (§6).
      'premajor'   → bump major, then start `-TAG.1`: a pre-release of the
      'preminor'     next major/minor/patch version. This is how to start a
      'prepatch'     pre-release when the current version is already
                     released — a pre-release of the SAME core would sort
                     below it (§11.3). `tag` is required.
      'release'    → drop pre-release and build (finalize a pre-release as
                     GA). Errors if there is nothing to drop: re-releasing
                     an identical version would violate §3 immutability.
      'prerelease' → iterate the pre-release. If `tag` is provided and
                     differs from the current pre-release prefix, switch
                     lanes (e.g. alpha → beta). Otherwise increment the
                     trailing numeric identifier, appending '.1' if needed.
    """
    if kind == "major":
        return Version(version.major + 1, 0, 0)
    if kind == "minor":
        return Version(version.major, version.minor + 1, 0)
    if kind == "patch":
        return Version(version.major, version.minor, version.patch + 1)
    if kind in ("premajor", "preminor", "prepatch"):
        if tag is None:
            raise ValueError(
                f"'{kind}' requires a pre-release tag (e.g. alpha, beta, rc): "
                f"the result is CORE-TAG.1."
            )
        core = {
            "premajor": (version.major + 1, 0, 0),
            "preminor": (version.major, version.minor + 1, 0),
            "prepatch": (version.major, version.minor, version.patch + 1),
        }[kind]
        return Version(*core, prerelease=(tag, "1"))
    if kind == "release":
        if not version.prerelease and not version.build:
            raise ValueError(
                f"{version} is already a full release - there is no "
                "pre-release or build metadata to strip. Re-releasing the "
                "same version would violate spec rule 3 (immutability)."
            )
        return Version(version.major, version.minor, version.patch)
    if kind == "prerelease":
        return _bump_prerelease(version, tag)
    raise ValueError(
        f"Unknown bump kind: {kind!r}. Expected one of: major, minor, patch, "
        "premajor, preminor, prepatch, release, prerelease."
    )


def _bump_prerelease(version: Version, tag: Optional[str]) -> Version:
    """
    Iterate the pre-release identifier.

    If `tag` is given:
      - If pre-release is empty or its first identifier differs from `tag`,
        start fresh: `1.2.3 → 1.2.3-{tag}.1`. The core version is NOT
        bumped — use premajor/preminor/prepatch to pre-release the NEXT
        version instead.
      - If the current first identifier matches `tag`, increment the
        trailing numeric, like below.

    If `tag` is not given:
      - If no pre-release: error (need a tag to start one).
      - If pre-release ends in a numeric identifier, increment it.
      - Otherwise append `.1`.
    """
    pre = version.prerelease
    if tag is not None:
        if not pre or pre[0] != tag:
            return Version(
                version.major, version.minor, version.patch, (tag, "1")
            )
        # Same tag: fall through to numeric increment below.

    if not pre:
        raise ValueError(
            "Cannot iterate pre-release on a version without one. "
            "Provide a tag (e.g. 'alpha', 'beta', 'rc') to start a pre-release."
        )

    pre_list = list(pre)
    # Find the last numeric identifier and increment it.
    for i in range(len(pre_list) - 1, -1, -1):
        if pre_list[i].isdigit():
            pre_list[i] = str(int(pre_list[i]) + 1)
            return Version(
                version.major,
                version.minor,
                version.patch,
                tuple(pre_list),
            )
    # No numeric identifier; append `.1`.
    pre_list.append("1")
    return Version(
        version.major, version.minor, version.patch, tuple(pre_list)
    )


# ─── CLI ──────────────────────────────────────────────────────────────────

def _cmd_validate(args: argparse.Namespace) -> int:
    if is_valid(args.version):
        print(f"{args.version}: VALID")
        return 0
    stripped = strip_v_prefix(args.version)
    if stripped != args.version and is_valid(stripped):
        print(
            f"{args.version}: INVALID - a leading 'v' is a tagging "
            f"convention, not part of the version (spec FAQ). "
            f"The SemVer is '{stripped}'.",
            file=sys.stderr,
        )
    else:
        print(f"{args.version}: INVALID", file=sys.stderr)
    return 1


def _cmd_parse(args: argparse.Namespace) -> int:
    try:
        v = parse(args.version)
    except ValueError as e:
        print(str(e), file=sys.stderr)
        return 1
    out = {
        "version": str(v),
        "major": v.major,
        "minor": v.minor,
        "patch": v.patch,
        "prerelease": list(v.prerelease) if v.prerelease else None,
        "build": list(v.build) if v.build else None,
        "is_stable": v.major >= 1 and not v.prerelease,
        "is_prerelease": bool(v.prerelease),
        "is_initial_development": v.major == 0,
    }
    if strip_v_prefix(args.version) != args.version:
        out["note"] = (
            "Leading 'v' stripped: it is a tagging convention, "
            "not part of the SemVer (spec FAQ)."
        )
    print(json.dumps(out, indent=2))
    return 0


def _cmd_compare(args: argparse.Namespace) -> int:
    try:
        v1 = parse(args.v1)
        v2 = parse(args.v2)
    except ValueError as e:
        print(str(e), file=sys.stderr)
        return 2
    result = compare(v1, v2)
    relation = {-1: "<", 0: "==", 1: ">"}[result]
    print(f"{v1} {relation} {v2}")
    print(result)  # Machine-readable: -1, 0, or 1.
    return 0


def _cmd_bump(args: argparse.Namespace) -> int:
    try:
        v = parse(args.version)
    except ValueError as e:
        print(str(e), file=sys.stderr)
        return 1
    try:
        bumped = bump(v, args.kind, args.tag)
    except ValueError as e:
        print(str(e), file=sys.stderr)
        return 1
    if args.kind == "prerelease" and compare(bumped, v) <= 0:
        if not v.prerelease:
            print(
                f"warning: {bumped} sorts BELOW {v} (spec 11.3: a "
                f"pre-release precedes its normal version). If {v} is "
                f"already published, use premajor/preminor/prepatch to "
                f"start a pre-release of the NEXT version instead.",
                file=sys.stderr,
            )
        else:
            print(
                f"warning: {bumped} does not sort above {v} - switching "
                f"to an earlier pre-release lane is a precedence "
                f"downgrade (spec 11.4).",
                file=sys.stderr,
            )
    print(str(bumped))
    return 0


def _cmd_sort(args: argparse.Namespace) -> int:
    try:
        versions = [parse(v) for v in args.versions]
    except ValueError as e:
        print(str(e), file=sys.stderr)
        return 1
    from functools import cmp_to_key

    versions.sort(key=cmp_to_key(compare))
    for v in versions:
        print(str(v))
    return 0


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Deterministic SemVer 2.0.0 operations.",
        epilog="See SKILL.md and references/ for spec interpretation.",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_validate = sub.add_parser("validate", help="Check if a version is valid SemVer.")
    p_validate.add_argument("version")
    p_validate.set_defaults(func=_cmd_validate)

    p_parse = sub.add_parser("parse", help="Parse a version into JSON components.")
    p_parse.add_argument("version")
    p_parse.set_defaults(func=_cmd_parse)

    p_compare = sub.add_parser("compare", help="Compare two versions (§11 rules).")
    p_compare.add_argument("v1")
    p_compare.add_argument("v2")
    p_compare.set_defaults(func=_cmd_compare)

    p_bump = sub.add_parser(
        "bump",
        help="Bump a version with proper resets (§7, §8).",
    )
    p_bump.add_argument("version")
    p_bump.add_argument(
        "kind",
        choices=[
            "major", "minor", "patch",
            "premajor", "preminor", "prepatch",
            "release", "prerelease",
        ],
        help=(
            "major/minor/patch: per spec §6-§8 with resets. "
            "premajor/preminor/prepatch: bump core, then start -TAG.1 "
            "(pre-release of the NEXT version; TAG required). "
            "release: drop pre-release & build (finalize). "
            "prerelease: iterate pre-release; provide TAG to start/switch."
        ),
    )
    p_bump.add_argument(
        "tag",
        nargs="?",
        default=None,
        help=(
            "Pre-release tag (alpha/beta/rc/etc.). Required for "
            "premajor/preminor/prepatch; optional for prerelease."
        ),
    )
    p_bump.set_defaults(func=_cmd_bump)

    p_sort = sub.add_parser("sort", help="Sort versions in ascending precedence.")
    p_sort.add_argument("versions", nargs="+")
    p_sort.set_defaults(func=_cmd_sort)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
