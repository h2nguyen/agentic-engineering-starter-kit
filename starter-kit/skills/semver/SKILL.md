---
name: semver
description: Apply Semantic Versioning 2.0.0 (semver.org) rigorously to any versioning question. Use this skill whenever the user asks about version bumps (MAJOR/MINOR/PATCH), whether a change is breaking, how to version a 0.y.z library, how to compare or order versions, how to interpret pre-release identifiers (alpha, beta, rc) or build metadata, how to validate a version string, how to update version fields in package.json / Cargo.toml / pyproject.toml / pom.xml / *.gemspec, how to write CHANGELOG entries aligned to a bump, or how to recover from a misversioned release. Also trigger on phrases like "is this a breaking change", "what version should I release", "is X version compatible with Y", "next version after Z", "validate this version", or any discussion of release planning where the version number is in question — even if the user does not say the word "semver".
---

# Semantic Versioning (SemVer 2.0.0)

This skill applies the official **Semantic Versioning 2.0.0** spec from
[semver.org](https://semver.org/) to real versioning decisions. The spec is
short, but its edge cases are subtle, and getting them wrong causes downstream
"dependency hell." This skill exists to make agent-driven versioning advice
verifiable against the spec, not vibes.

## When to use this skill

Use this skill whenever a version number is in play. Typical triggers:

- **Bump decisions**: "Is this a MAJOR, MINOR, or PATCH?" / "What version comes next?"
- **Change classification**: "Is this a breaking change?" / "Can I ship this as a patch?"
- **Validation**: "Is `1.0.0-alpha.beta+build.1` a valid SemVer?"
- **Comparison**: "Which is higher: `1.0.0-rc.11` or `1.0.0-rc.2`?"
- **Pre-release / build metadata**: anything involving `-alpha`, `-beta`, `-rc.N`, or `+sha.xxx`
- **0.y.z phase**: "We're at 0.7.3 and broke the API — what now?" / "When should I go to 1.0.0?"
- **Recovery**: "I accidentally shipped a breaking change in a patch release."
- **Release planning**: drafting CHANGELOG entries, package manifest bumps, ADRs around breaking changes.

Even casual phrasings ("should I call this 2.0?", "is this safe for users on 1.x?") are in scope.

## The spec in one paragraph

A SemVer version is `MAJOR.MINOR.PATCH`, optionally followed by `-PRE_RELEASE`
and/or `+BUILD_METADATA`. **MAJOR** is bumped for backward-incompatible API
changes, **MINOR** for backward-compatible additions (including marking
something deprecated), **PATCH** for backward-compatible bug fixes. Releases
are immutable — once published, a version cannot be edited; you must release a
new one. Versions starting with `0.y.z` are an exception: anything may change.
A precise public API is a prerequisite — without one, SemVer is meaningless.

The authoritative spec lives at `references/spec.md`. Read it whenever an
edge case feels uncertain — do not approximate from memory.

## Core decision flow (use this every time)

```
Question: What version comes after CURRENT after CHANGE_SET?

1. Is the current MAJOR 0?
   → Yes: see references/decision-guide.md §"0.y.z phase". The rules are
          looser; conventions matter more than the strict spec.
   → No:  continue.

2. Does ANY change in CHANGE_SET break the public API?
   (signatures removed, semantics altered, behavior incompatible with
   docs/contracts, fields removed from public types, error codes
   renumbered, file formats changed in non-backward-compatible ways…)
   → Yes: MAJOR bump. Reset MINOR and PATCH to 0.
          e.g. 2.4.7 → 3.0.0
   → No:  continue.

3. Does ANY change add new public-API functionality, or mark any
   public-API element as deprecated?
   → Yes: MINOR bump (REQUIRED by spec §7). Reset PATCH to 0.
          e.g. 2.4.7 → 2.5.0
   → No:  continue to step 4.
   (Spec §7 also says MINOR MAY be incremented when substantial new
   functionality is introduced in the *private* code; this is optional
   and a judgement call. If unsure, don't.)

4. Are all changes backward-compatible bug fixes (correcting incorrect
   behavior, with no API surface change)?
   → Yes: PATCH bump.
          e.g. 2.4.7 → 2.4.8
   → No:  the change set is empty or non-shipping; no version bump needed.
```

When in doubt at step 2 vs step 3, bias toward MAJOR. The cost of a wrong
MAJOR is annoyance; the cost of a wrong MINOR-that-was-actually-MAJOR is
breaking every dependent in the ecosystem.

## What counts as "breaking"

A change is breaking if a reasonable consumer of the documented public API
could observe a difference that requires them to change their code or
configuration. Concrete examples:

- Removing or renaming a public function, class, type, field, env var, CLI flag, or HTTP route.
- Changing a function signature (parameter count, types, order, required-ness).
- Tightening a precondition (rejecting input that used to be accepted).
- Loosening a postcondition (returning values consumers couldn't have anticipated, e.g. allowing `null` where it wasn't before).
- Changing wire format (JSON schema, protobuf field semantics, file headers).
- Raising a runtime requirement (minimum Node/Python/JVM version, OS, hardware).
- Changing default behavior in a way users would notice (default port, default algorithm, default encoding).
- Renaming or removing public exit codes, log formats consumers parse, or error codes.

Not breaking (typically MINOR or PATCH — see `references/decision-guide.md`):

- Adding a new optional parameter with a sensible default.
- Adding a new function/method/endpoint/CLI flag/config option alongside existing ones.
- Marking something `@deprecated` without removing it (this is MINOR, not PATCH — the spec is explicit on this).
- Performance improvements with identical observable behavior.
- Internal refactors with no public API surface change.

## How to perform a bump

Apply these resets — they are mandatory and a common source of bugs:

| Bump  | MAJOR     | MINOR     | PATCH     | Pre-release | Build metadata |
|-------|-----------|-----------|-----------|-------------|----------------|
| MAJOR | +1        | reset 0   | reset 0   | drop        | drop           |
| MINOR | unchanged | +1        | reset 0   | drop        | drop           |
| PATCH | unchanged | unchanged | +1        | drop        | drop           |

Going from `1.4.7-rc.2+build.91` to a final release is `1.4.7` — pre-release
and build metadata are dropped at GA. To bump while staying in pre-release,
work the pre-release identifier: `1.4.7-rc.2 → 1.4.7-rc.3` (no MAJOR/MINOR/PATCH change).

To **start** a pre-release when the current version is already published,
pre-release the *next* version: `1.4.7 → 1.5.0-rc.1` (or `1.4.8-rc.1`,
`2.0.0-rc.1`). A pre-release of the same core (`1.4.7-rc.1`) would sort
*below* the published `1.4.7` (§11.3) — a downgrade.

For deterministic operations (parse / validate / compare / bump), use the
bundled script:

```bash
python scripts/semver_tool.py validate 1.0.0-alpha.1+sha.abc
python scripts/semver_tool.py parse    1.0.0-alpha.1+sha.abc
python scripts/semver_tool.py compare  1.0.0-rc.2 1.0.0-rc.11
python scripts/semver_tool.py bump     2.4.7 minor       # → 2.5.0
python scripts/semver_tool.py bump     2.4.7 major       # → 3.0.0
python scripts/semver_tool.py bump     2.4.7 preminor rc # → 2.5.0-rc.1 (pre-release of the NEXT version)
python scripts/semver_tool.py bump     1.4.0-rc.2 prerelease  # → 1.4.0-rc.3
python scripts/semver_tool.py sort     1.0.0 1.0.0-rc.1 1.0.0-alpha 1.0.0-beta
```

Prefer the script over hand-calculating, especially for pre-release ordering
where the rules are non-obvious (numeric vs lexical, length-based tie-breaks).

## Pre-release and build metadata in one minute

- **Pre-release**: after a hyphen. Lower precedence than the same MAJOR.MINOR.PATCH
  without it. `1.0.0-alpha < 1.0.0`. Used to ship unstable previews of an
  upcoming version.
- **Build metadata**: after a plus. **Ignored for precedence.** `1.0.0+build.1`
  and `1.0.0+build.2` are equal-precedence. Used to embed commit SHAs, build
  numbers, build environment.
- Pre-release identifier ordering uses spec rule 11.4 (numeric identifiers
  compared numerically, alphanumeric lexically, numeric < alphanumeric, longer
  identifier list > shorter when all leading identifiers match).
- For a deep walkthrough with worked examples see `references/prerelease.md`
  and `references/precedence.md`.

## The 0.y.z initial-development phase

When `MAJOR == 0`, the public API is explicitly not stable. The spec says
"anything MAY change at any time." Common conventions on top of the spec
(documented further in `references/decision-guide.md`):

- Start initial development at `0.1.0` and bump MINOR for each subsequent
  release (spec FAQ).
- Treat MINOR (`0.Y.z`) bumps as "breaking allowed."
- Treat PATCH (`0.y.Z`) bumps as "should be backward compatible."
- Go to `1.0.0` when the API is stable, when production usage exists, or when
  you're "worrying a lot about backward compatibility" (FAQ quote).

## Validation regex (official, from the spec's FAQ)

The official ECMAScript-compatible regex:

```
^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$
```

`v1.2.3` is **not** a SemVer (spec FAQ) — the leading `v` is a tagging
convention (e.g. `git tag v1.2.3`); the SemVer inside it is `1.2.3`. When
asked to validate `v1.2.3`, the correct answer is "invalid as written, but
the underlying `1.2.3` is valid." The bundled `validate` command is strict
about this and prints that hint; the other commands strip a leading `v`
for convenience.

## Output conventions

When the answer is a decision (e.g. "MINOR → 2.5.0"), lead with the verdict
on the first line, then the rationale grounded in a specific spec rule, then
any ecosystem caveats. Example skeleton:

```
Verdict: MINOR bump → 2.5.0
Rationale: New optional parameter on a public function is a backward-
compatible API addition (spec §7). Patch resets to 0.
Caveats: For typed-ecosystem consumers, ensure published type stubs mark
the new parameter as optional — otherwise type-checkers will flag a
spurious break.
```

For deliverable documentation (CHANGELOG entries, ADRs about breaking
changes, release notes), match the conventions of the target repository.
If no convention exists, default to Markdown.

## Edge cases the spec answers (read before guessing)

- **Marked-as-deprecated → MINOR**, not PATCH. (§7)
- **Releases are immutable.** Never re-publish the same version. (§3)
- **Leading zeros forbidden.** `01.2.3` is invalid. (§2)
- **No upper bound** on identifier length, but be reasonable. (FAQ)
- **Build metadata doesn't affect precedence.** Two versions differing only
  in `+build...` are equal-precedence. (§10)
- **Numeric vs alphanumeric pre-release identifiers**: `1.0.0-alpha.2 <
  1.0.0-alpha.11` (numeric compare), but `1.0.0-2 < 1.0.0-alpha` (numeric
  always lower than alphanumeric). (§11.4)
- **Accidental breaking change in a patch**: do not mutate the release;
  ship a corrective release that restores compatibility, and consider
  whether to also bump MAJOR if the broken behavior is now load-bearing
  (FAQ).
- **Starting a pre-release after the version already shipped**:
  `1.4.7-rc.1` sorts *below* a published `1.4.7` (§11.3). Pre-release the
  next version instead: `bump 1.4.7 prepatch rc → 1.4.8-rc.1` (or
  `preminor`/`premajor`).

For every other edge case, consult `references/spec.md` and
`references/decision-guide.md` rather than reasoning from intuition.

## Reference files

Load these on demand when the question touches their domain:

- `references/spec.md` — full SemVer 2.0.0 spec verbatim. The source of truth.
- `references/decision-guide.md` — MAJOR/MINOR/PATCH worked examples, 0.y.z heuristics, ecosystem conventions, recovery procedures.
- `references/precedence.md` — full comparison algorithm with traceable examples.
- `references/prerelease.md` — pre-release identifier patterns (alpha/beta/rc, `0.1.2-alpha.1`, snapshot conventions) and build metadata patterns.
- `references/ecosystem.md` — how npm, Cargo, pip/PEP 440, Maven, Go modules diverge from strict SemVer in practice.
- `scripts/semver_tool.py` — deterministic CLI for parse/validate/compare/bump/sort.
