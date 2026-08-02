# Pre-release & build metadata patterns

Spec §9 and §10 define syntax. This file covers practical patterns: when
to use what, common naming conventions, how to iterate within pre-release,
how to combine with build metadata.

## Pre-release: syntax recap

After the patch, append `-` then dot-separated identifiers.

- Identifiers: `[0-9A-Za-z-]` only. No empty. Numeric identifiers must not
  have leading zeros (so `01` is invalid, `1` is fine).
- Pre-release versions have **lower precedence** than the same version
  without the pre-release: `1.0.0-alpha < 1.0.0`.

Valid examples from the spec:

```
1.0.0-alpha
1.0.0-alpha.1
1.0.0-0.3.7
1.0.0-x.7.z.92
1.0.0-x-y-z.--
```

## Standard pre-release names

Not in the spec, but conventional and respected by ecosystem tooling:

| Identifier | Meaning                                                                                       |
|------------|-----------------------------------------------------------------------------------------------|
| `alpha`    | Earliest, internal/dev preview. API may change.                                               |
| `beta`     | Feature-complete, but still finding bugs.                                                     |
| `rc.N`     | Release candidate. No new features, only bug fixes.                                           |
| `next`     | Bleeding-edge, typically auto-tagged from main branch.                                        |
| `canary`   | Per-commit pre-releases.                                                                      |
| `snapshot` | Java-world convention (often `-SNAPSHOT`, but note Maven SNAPSHOT is a non-SemVer construct). |

The spec doesn't require any of these — `1.0.0-foo.bar.42` is valid. But
your users and tooling will be happier with the common names.

## Iterating within pre-release

```
1.0.0-alpha
1.0.0-alpha.1
1.0.0-alpha.2
...
1.0.0-beta
1.0.0-beta.1
1.0.0-beta.2
...
1.0.0-rc.1
1.0.0-rc.2
...
1.0.0           ← GA
```

Each successive identifier sorts higher per §11.4. Note that `1.0.0-alpha`
< `1.0.0-alpha.1` (longer wins when prefix matches), so starting with
plain `alpha` and then `alpha.1` is correct — the bare name is the "zero"
iteration.

A common house style: skip the bare names and always use `.N`:

```
1.0.0-alpha.1, 1.0.0-alpha.2, ..., 1.0.0-beta.1, ..., 1.0.0-rc.1, ..., 1.0.0
```

## Numeric vs alphanumeric pre-release identifiers

Pure-numeric identifiers compare numerically (rule 11.4.1) so `alpha.2 <
alpha.11`. Identifiers containing any non-digit compare lexically
(rule 11.4.2), so `alpha10 < alpha2` if you didn't dot-separate. Always
prefer dotted numeric identifiers (`alpha.10`) over baked-in numbers
(`alpha10`) so ordering matches intuition.

Pure-numeric identifiers always rank lower than alphanumeric ones (rule
11.4.3), so `1.0.0-1 < 1.0.0-alpha`. This matters for date-coded
pre-releases like `1.0.0-20240115` — they sort lower than any named
pre-release.

## Build metadata: syntax recap

After patch (or pre-release), append `+` then dot-separated identifiers.

- Same character class as pre-release.
- **Ignored for precedence.** `1.0.0+a == 1.0.0+b == 1.0.0` in ordering.
- Used for: commit SHAs, build numbers, build environment, anything that
  identifies the build but should not affect compatibility.

Valid:

```
1.0.0-alpha+001
1.0.0+20130313144700
1.0.0-beta+exp.sha.5114f85
1.0.0+21AF26D3----117B344092BD
```

## Combining pre-release and build metadata

Order is always `MAJOR.MINOR.PATCH[-PRE][+BUILD]`. The `+BUILD` always comes
last.

```
1.0.0-rc.1+sha.abc123      ← valid
1.0.0+sha.abc123-rc.1      ← INVALID. The `-rc.1` would be part of build metadata.
```

## Recommended patterns

### Library publishing pre-releases

Use named tiers with dotted iterations:

```
2.0.0-alpha.1, 2.0.0-alpha.2, ..., 2.0.0-beta.1, ..., 2.0.0-rc.1, ..., 2.0.0
```

In npm: publish with `--tag alpha` / `--tag beta` / `--tag next` so
consumers don't accidentally install the unstable version.

### Starting a pre-release for the next version

When the current version is already published, a new pre-release must
target the *next* core version — `1.4.7-rc.1` would sort below the
published `1.4.7` (§11.3), which makes it a downgrade for any consumer:

```bash
python scripts/semver_tool.py bump 1.4.7 preminor rc    # → 1.5.0-rc.1
python scripts/semver_tool.py bump 1.4.7 prepatch rc    # → 1.4.8-rc.1
python scripts/semver_tool.py bump 1.4.7 premajor beta  # → 2.0.0-beta.1
```

Pick the core bump (`premajor` / `preminor` / `prepatch`) based on what the
upcoming release will contain, using the normal MAJOR/MINOR/PATCH decision
flow. The `prerelease` bump kind warns when it would produce a version that
does not sort above its input.

### CI auto-tagging per commit

Use build metadata for the commit identifier:

```
2.0.0-next+sha.7c4a9d2
2.0.0-next+sha.f013b1a
```

These are all the same precedence (rule §10). A package manager treating
them as the same is correct; the build metadata is just human-readable
provenance.

### Date-coded snapshots

```
2.0.0-snapshot.20240115.1
2.0.0-snapshot.20240116.1
```

Date-sorting works because `2024-01-15 < 2024-01-16` numerically. Avoid
the all-numeric form `2.0.0-20240115` because it ranks below `2.0.0-alpha`
(rule 11.4.3).

### GA release from rc

```
2.0.0-rc.7   → 2.0.0
```

Strip the pre-release. Do **not** bump the core version on GA — the core
was already chosen when you went into pre-release.

## Pre-releases during 0.y.z initial development

Pre-release versions are fully valid during the `0.y.z` initial-development
phase. `0.1.0-alpha.1`, `0.7.3-rc.1`, `0.0.1-beta` are all legal SemVer and
sort per the same precedence rules as their `≥1.0.0` counterparts.

This is rarely useful for short-lived 0.y.z prototypes (you can just bump
MINOR and break things), but two cases where it pays off:

- **Approaching `1.0.0`**: shipping `1.0.0-rc.1`, `1.0.0-rc.2`, … to
  exercise the stable API before the GA cut.
- **Stable 0.y.z lines with external users**: pre-releases let you stage
  changes (e.g. `0.8.0-beta.1`) without polluting `0.7.x` patch consumers
  who installed `^0.7.0`.

Tooling treatment matches the general case: npm and Cargo will only resolve
to a pre-release when the dependency specifier explicitly opts in.

## Anti-patterns

- **`1.0.0-final`**: looks reassuring, sorts below every other alphanumeric
  pre-release lexically. It's not "the final pre-release" in any ordering
  sense.
- **`1.0.0-FINAL`**: same problem, also case-confusing.
- **`v1.0.0-rc1`** in package.json: leading `v` is not part of SemVer; also
  `rc1` is one identifier, not `rc.1`. Prefer `1.0.0-rc.1`.
- **Stuffing semantically meaningful info into build metadata**: it's
  invisible to precedence. If consumers need to distinguish based on the
  info, it must be in the pre-release identifier.
- **Pre-release on a patch level for a stable line**: `1.4.7-hotfix.1`
  ranks BELOW `1.4.7`, so if `1.4.7` is already out, this is a downgrade.
  Use `1.4.8-rc.1` instead (`semver_tool.py bump 1.4.7 prepatch rc`).

## Quick checks

Use the bundled tool to verify any pre-release composition:

```bash
python scripts/semver_tool.py validate "1.0.0-alpha.beta+sha.abc"
python scripts/semver_tool.py parse    "1.0.0-alpha.beta+sha.abc"
python scripts/semver_tool.py compare  "1.0.0-alpha.beta" "1.0.0-beta"
```
