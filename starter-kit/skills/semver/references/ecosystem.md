# Ecosystem notes: where reality diverges from strict SemVer

SemVer 2.0.0 is the spec. Most package ecosystems implement *a dialect of
it*. Knowing the differences keeps you from giving advice that's
technically correct per the spec but wrong for the user's actual tooling.

## npm / Node.js

**Closest to the spec.** Adopts SemVer 2.0.0 directly. Pre-release and build
metadata both supported in `package.json` `version` and in range specifiers.

Quirks to know:

- **`^0.y.z` resolves to `>=0.y.z <0.(y+1).0`**, treating MINOR as the
  breaking boundary in 0.y.z (matches Convention A in `decision-guide.md`).
  For `>=1.0.0`, `^1.2.3` means `>=1.2.3 <2.0.0` as expected.
- **`^0.0.z` resolves to `>=0.0.z <0.0.(z+1)`** — only that exact patch
  is allowed. Each PATCH in `0.0.x` is treated as potentially breaking.
  (Cargo behaves identically for `^0.0.z`.)
- **`~1.2.3` resolves to `>=1.2.3 <1.3.0`**, treating PATCH as the boundary.
- **dist-tags** (`latest`, `next`, `alpha`, …) decouple "what's installed
  by default" from "what's the highest version." Publish pre-releases with
  `npm publish --tag next` so `npm install pkg` doesn't pick them up.
- **`npm version` command** auto-bumps and tags: `npm version major` →
  `2.0.0`, etc. Respects the resets in §7 and §8.
- npm ranges accept pre-release only if a pre-release matching the
  major/minor/patch is explicitly requested. So `^1.2.3` will NOT match
  `1.2.4-beta.1` by default — guard against this in release planning.

## Cargo (Rust)

Closely follows SemVer 2.0.0 with a few practical conventions:

- **`^0.y.z` (and bare `0.y.z`, since Cargo desugars it to `^0.y.z`)**
  resolves to `>=0.y.z <0.(y+1).0`. MINOR is the breaking boundary in
  the 0.y.z initial-development phase.
- **`^0.0.z`** resolves to `>=0.0.z <0.0.(z+1)` — only that exact patch
  is allowed. **npm's caret behaves identically for `^0.0.z`**; the two
  package managers are equivalent on this point.
- **Pre-release versions are explicitly opt-in**: `1.2.3-rc.1` will not
  be picked up by `^1.2.0`. You must reference `"1.2.3-rc.1"` (or a
  matching pre-release range) explicitly.

Cargo aligns closely with the spec; the main practical difference from
strict spec text is the 0.y.z convention (MINOR as the breaking boundary),
which the SemVer spec itself does not mandate but which Cargo, npm, and
most ecosystems adopt.

## pip / PEP 440 (Python)

**PEP 440 is a different versioning standard, not SemVer.** It's superficially
similar but the syntax for pre-releases differs:

- PEP 440 pre-releases: `1.0.0a1`, `1.0.0b2`, `1.0.0rc3` (no hyphen, no dot
  separator between the marker and the number).
- SemVer pre-releases: `1.0.0-alpha.1`, `1.0.0-beta.2`, `1.0.0-rc.3`.
- PEP 440 has additional concepts SemVer doesn't: `.devN` (developmental
  releases), `.postN` (post-releases for packaging fixes that don't change
  the source), `N!` epochs.
- PEP 440 normalizes case and separators aggressively — `1.0.0-RC1`,
  `1.0.0.rc1`, `1.0.0rc1` are all the same release.
- pip uses PEP 440. Some packaging tools (`hatchling`, `poetry`) accept a
  SemVer-style version and **transform** it to PEP 440 — e.g.
  `1.0.0-rc.1` becomes `1.0.0rc1`. Verify what your tool actually
  publishes.

If your Python project's `pyproject.toml` ` version` field uses dashes and
dots in pre-release identifiers, double-check what gets uploaded to PyPI.

## Maven (Java)

**Maven's versioning is NOT SemVer.** It has its own ordering algorithm with
`-SNAPSHOT` suffixes, qualifier tokens (`alpha`, `beta`, `milestone`, `rc`,
`snapshot`, `final`/`ga`, `sp`) that have special ordering, and dash-
vs-dot-separator significance.

Quirks:

- `1.0-SNAPSHOT` < `1.0-alpha-1` < `1.0-beta-1` < `1.0-rc-1` < `1.0` < `1.0-sp1`.
- `1.0.0` and `1.0` are treated as **equivalent** in Maven (trailing zeros
  collapsed). Surprising in a SemVer world.
- The qualifier ordering is special-cased; unknown qualifiers sort
  alphabetically and rank above any known qualifier.

When the user is in Maven-land, do not advise pure SemVer mechanics for
ordering. Refer them to the
[Maven version order documentation](https://maven.apache.org/pom.html#Dependency_Version_Requirement_Specification)
and bias toward conservative range specs.

## Go modules

Go modules **require** SemVer 2.0.0 with a `v` prefix for tags:
`git tag v1.2.3`. The leading `v` is required by Go tooling but is not
part of the SemVer string.

Special rules:

- **Major versions ≥ 2 require an import path change**: `github.com/foo/bar/v2`.
  This is enforced by `go mod`. Bumping a Go module to MAJOR is more
  invasive than in any other ecosystem.
- Pre-release versions follow SemVer, but Go's `+incompatible` build
  metadata is used for legacy modules that don't follow the path-versioning
  rule: `v2.0.0+incompatible`.
- Pseudo-versions like `v0.0.0-20240115153000-abcdef123456` encode commit
  time and SHA for unreleased commits. They sort correctly per SemVer.

## Docker image tags

Not formally SemVer, but conventions are SemVer-like:

- `image:1.2.3` — exact.
- `image:1.2` — latest patch on `1.2.x`.
- `image:1` — latest minor on `1.x.x`.
- `image:latest` — moving pointer, not a version.

No mechanical resolution like npm ranges; tags are static labels. When
advising on Docker tag strategy, recommend publishing all three (`1.2.3`,
`1.2`, `1`) on each release.

## Helm chart versions

Strict SemVer 2.0.0 (`chart.yaml: version`). `appVersion` is also SemVer
by convention but not enforced. Pre-releases supported.

## Summary: what to tell users

| Ecosystem  | Adherence to SemVer 2.0.0 | Notable divergence                                                          |
|------------|---------------------------|-----------------------------------------------------------------------------|
| npm        | High                      | dist-tags, pre-release opt-in, MAJOR=0 → MINOR-is-breaking by `^` semantics |
| Cargo      | High                      | Stricter 0.y.z; `^0.0.z` is fully pinned                                    |
| pip/PyPI   | **PEP 440, not SemVer**   | Different syntax for pre-releases; epochs, dev, post                        |
| Maven      | **Not SemVer**            | Qualifier-based ordering; `1.0 == 1.0.0`                                    |
| Go modules | High, with rules          | `v` prefix mandatory; major ≥2 requires path change                         |
| Docker     | Convention only           | No range resolution; tags are static labels                                 |
| Helm       | High                      | Same as SemVer 2.0.0                                                        |

When advising on a version question, first confirm the ecosystem. The spec
answer and the practical answer may differ.
