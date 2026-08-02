# Decision guide: MAJOR vs MINOR vs PATCH

Use this when the spec rule is clear, but applying it to a real change set is
not. Each section walks an example, the reasoning, and the verdict tied to a
spec section.

## Table of contents

- [The "could a user notice?" test](#the-could-a-user-notice-test)
- [Worked examples](#worked-examples)
- [The 0.y.z initial-development phase](#the-0yz-initial-development-phase)
- [When to release 1.0.0](#when-to-release-100)
- [Deprecation procedure](#deprecation-procedure)
- [Recovery from a misversioned release](#recovery-from-a-misversioned-release)
- [Gray-area calls](#gray-area-calls)
- [Things that look like API changes but aren't](#things-that-look-like-api-changes-but-arent)

---

## The "could a user notice?" test

A change is breaking if a reasonable consumer of the **documented** public
API could observe a difference that would force them to change their code,
configuration, or runtime environment. Internal refactors with identical
external behavior are PATCH (or no bump). New surface, no removed surface,
no semantic change to existing surface → MINOR. Removed or altered surface
with observable consumer impact → MAJOR.

The word "documented" matters: behavior that wasn't part of the public
contract can sometimes be changed without a MAJOR, but only if you're
willing to defend that the consumer was relying on undocumented behavior.
That defense often loses in practice ("Hyrum's Law" — every observable
behavior of your system will be depended on). When in doubt, treat
widely observed behavior as part of the de-facto contract.

## Worked examples

### Example 1: New optional parameter

```
def parse_date(s):              →  def parse_date(s, tz="UTC"):
    ...
```

- Current version: `2.4.7`
- New public surface added (the `tz` parameter), default preserves existing
  behavior. No removed surface.
- Spec §7 (MINOR): "new, backward-compatible functionality is introduced to
  the public API."
- **Verdict: MINOR → 2.5.0**

Caveat for statically typed ecosystems: this is backward-compatible at the
type level too, **as long as the published type stubs mark the new parameter
as optional** (`tz?: string` in TypeScript, `tz: str = "UTC"` in `.pyi`
files). Stubs that incorrectly mark the parameter as required would create
a type-checker break for downstream consumers — that's a stub-authoring bug
to fix, not a SemVer reclassification. Verify the stubs before shipping.

### Example 2: Removed CLI flag

```
$ tool --legacy-mode foo    →   $ tool foo
```

The flag is gone. Any user invoking with `--legacy-mode` will get an error.

- Spec §8 (MAJOR): "backward incompatible changes are introduced to the
  public API."
- **Verdict: MAJOR**

### Example 3: Bug fix that changes the return value for previously undefined input

A function used to return `null` when given an empty string. The new
behavior is to raise a `ValueError`. Docs said "behavior is undefined for
empty input."

- Strictly per spec: undefined behavior changes are PATCH-eligible (§6).
- Pragmatic: if users were relying on the `null` (and they almost certainly
  were — it didn't crash), the change is breaking from their point of view.
- **Verdict: MINOR is the responsible call** — gate the new behavior behind
  a flag or warning, or **MAJOR** if you ship the change unconditionally.
  Hyrum's Law applies. PATCH would technically be defensible but rarely wise.

### Example 4: Marking a function as deprecated

```
def old_api(): ...              →   @deprecated
                                    def old_api(): ...
```

The function still works identically. Only a deprecation notice is added.

- Spec §7 explicitly: "It MUST be incremented if any public API functionality
  is marked as deprecated."
- **Verdict: MINOR**. Not PATCH — deprecation-as-PATCH is a frequent
  misclassification because the runtime behavior didn't change, but the
  spec is explicit that the deprecation marker itself is the API addition
  that triggers the bump.

### Example 5: Performance fix, no API surface change

A SQL query is rewritten; results are identical, query is 10× faster.

- Spec §6 (PATCH): backward-compatible bug fix that corrects "incorrect
  behavior" — performance regressions count as incorrect behavior in most
  codebases.
- **Verdict: PATCH**

### Example 6: Raising the minimum Node.js version from 18 to 20

Code is unchanged, but `engines.node` in `package.json` bumped from `>=18` to
`>=20`. Consumers on Node 18 cannot install.

- Consumer-observable break, even though no API surface changed.
- **Verdict: MAJOR**. Runtime requirements are part of the contract.

### Example 7: Renaming an internal helper used only inside the package

Module-private symbol gets renamed. Not exported. No public surface change.

- **Verdict: PATCH** (or no bump at all if no shipping change).

### Example 8: Adding a new error code / HTTP status to a public endpoint

`POST /orders` used to return only 200 and 400. Now also returns 409 on
conflict.

- Clients that branched only on 2xx/4xx are fine.
- Clients that switched on specific codes (e.g. "if 400, retry; else fail")
  may now fall through to "fail" on a 409.
- **Verdict: MINOR** if the new code is a meaningful subcase of a previously
  documented broad category (e.g. "may return 4xx on client errors").
  **MAJOR** if the new code replaces or partitions an existing one.

### Example 9: Pre-release iteration

Current: `1.4.0-rc.2`. Found a bug, fixing it before GA.

- Pre-release lane: bump the pre-release identifier, not the core version.
- **Verdict: `1.4.0-rc.3`**. Going to `1.4.0` would mean "ship the release"
  not "iterate within rc."

### Example 10: From last pre-release to GA

Current: `1.4.0-rc.7`. Ship the actual release.

- Drop the pre-release suffix.
- **Verdict: `1.4.0`**.

### Example 11: Switching JSON output to camelCase

Wire format changes. `{"user_name": "x"}` → `{"userName": "x"}`. Every
consumer parsing the response needs to update.

- **Verdict: MAJOR**, even if no code symbol changed.

### Example 12: Adding a new optional JSON field

`{"id": 1}` → `{"id": 1, "createdAt": "..."}`.

- Lenient parsers ignore the new field. Strict parsers (Pydantic models
  with `extra=Forbid`, protobuf with strict mode) reject it.
- **Verdict: MINOR** is the standard call. The rejection on strict parsers
  is generally treated as the parser's choice; document the addition
  prominently.

## The 0.y.z initial-development phase

Spec §4: when MAJOR == 0, **anything MAY change at any time**. The public
API is not stable.

The spec FAQ's starting point: begin initial development at `0.1.0` and
increment MINOR for each subsequent release.

In practice, two conventions dominate the ecosystem:

**Convention A (most common, "MINOR is breaking")**:
- `0.y.Z` → backward-compatible bug fixes (PATCH-like)
- `0.Y.z` → anything, including breaking changes (MAJOR-like)

This is what `cargo`, `npm` `^0.y.z`, and many language ecosystems assume.
`^0.2.3` resolves to `>=0.2.3 <0.3.0`, treating MINOR as the breaking
boundary.

**Convention B (rare, "strict SemVer applied to 0.y.z")**:
- Same rules as `≥1.0.0`. Mostly seen in projects that want to keep
  pre-1.0 a true incubator.

When advising, default to Convention A. If you're on `0.7.3` and the API
broke: **bump to `0.8.0`**, not `0.7.4`.

When you make a backward-compatible addition while staying in 0.y.z, you
have a choice — many projects bump MINOR here too (`0.7.3 → 0.8.0`) and
reserve PATCH for fixes. That's fine and matches Convention A.

## When to release 1.0.0

Spec FAQ — go to 1.0.0 when any of:

- Software is being used in production.
- You have a stable API users depend on.
- You're worrying about backward compatibility (the worrying itself is the
  signal).

Don't fetishize 0.y.z as "we're still iterating." Many widely used
packages live below 1.0.0 for years past the point where they should have
declared the API stable. The cost of delayed 1.0.0 is that consumers can't
distinguish your "I'll break things to clean up" releases from your
"I'll break things because the API was wrong" releases.

## Deprecation procedure

The spec is explicit: deprecation MUST trigger a MINOR bump. The recommended
flow is:

1. Update documentation to mark the symbol/endpoint/flag deprecated. Note
   the replacement and timeline if known.
2. Ship a MINOR release containing the deprecation marker (the `@deprecated`
   annotation, the warning log, the `Deprecation:` HTTP header).
3. Let at least one MINOR release "carry" the deprecation in production so
   consumers can migrate.
4. Remove the deprecated symbol in a subsequent MAJOR release.

Skipping step 3 — removing the symbol in the very next MAJOR after the
deprecation MINOR — is technically spec-compliant but bad practice for any
package with real consumers. Give people a release cycle to react.

## Recovery from a misversioned release

The spec is unambiguous: **never modify a published version.** Bad versions
are corrected by publishing new ones.

**Scenario A: Shipped a breaking change as PATCH.**
- Publish a follow-up PATCH that *restores* the old behavior, if you can.
  e.g. `1.4.7` (broken) → `1.4.8` (restored).
- If you cannot restore — the breaking change is desirable and you want to
  keep it — publish a MAJOR that documents the change properly:
  e.g. `1.4.7` (broken) → `1.4.8` (restored) → `2.0.0` (the change, done
  right). Yank or deprecate `1.4.7` in the registry if your ecosystem
  supports it (npm: `npm deprecate`, PyPI: yank).
- Communicate clearly: changelog entry, release notes, package-registry
  deprecation message.

**Scenario B: Shipped a feature as PATCH.**
- Publish a corrective MINOR with the same feature, properly versioned.
- Optionally deprecate or yank the wrong PATCH.

**Scenario C: Shipped with the wrong pre-release identifier.**
- Don't try to overwrite. Publish a new pre-release with a higher precedence
  identifier: `1.0.0-rc.2 → 1.0.0-rc.3` (if rc.2 was a mistake).

## Gray-area calls

### Bumping a transitive dependency

You upgrade an internal dependency from `lodash@4.x` to `lodash@5.x`. Your
public API is unchanged.

- If the dependency is not exposed in your public API (no `lodash` types
  appear in your function signatures, errors thrown, etc.): **PATCH or MINOR**
  depending on whether the upgrade is a "fix" or "feature improvement."
- If your public surface re-exports lodash types or passes lodash objects
  to consumer callbacks: a MAJOR in lodash is likely a MAJOR for you too.

### Documentation-only changes

- **Verdict**: no version bump needed. If your release process requires
  versioning every release, PATCH.

### Security fix that breaks consumers relying on the vulnerability

A buffer overflow CVE; the fix tightens input validation. Some users were
passing oversized inputs and getting "lucky."

- **Verdict**: ship as PATCH and call it out loudly. Security fixes are an
  acknowledged exception in most ecosystems; the alternative is leaving
  users vulnerable for a release cycle. Document in release notes.

### Behavior change behind a feature flag, flag default unchanged

Adds an opt-in setting. Default behavior is identical.

- **Verdict**: MINOR (new opt-in is a backward-compatible addition).

### Behavior change behind a feature flag, flag default flipped

Default behavior changes; old behavior available via flag.

- **Verdict**: MAJOR. The default is the contract.

## Things that look like API changes but aren't

- **Internal logging format changes**: PATCH, unless you've documented the
  log format as part of the public contract.
- **Memory/CPU footprint changes**: PATCH, unless documented as a guarantee.
- **Error message wording changes**: PATCH, unless consumers are documented
  to parse them (you should ship machine-readable error codes for this
  reason).
- **Build artifact reorganization** that doesn't change the public import
  paths: PATCH.
- **Test-only changes**: no bump.

When unsure, fall back to: what change must the consumer make to keep
working? If the answer is "none," it's not breaking.
