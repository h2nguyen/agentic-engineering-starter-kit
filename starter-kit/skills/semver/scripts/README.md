# `semver_tool.py`

Deterministic operations on SemVer 2.0.0 versions. Pure Python stdlib, no
dependencies. Implements <https://semver.org/spec/v2.0.0.html> exactly,
using the official regex from the spec's FAQ.

## Commands

```bash
# Validate (strict: `v1.2.3` is NOT a SemVer per the spec FAQ)
python semver_tool.py validate 1.0.0-alpha.beta+sha.abc   # exit 0
python semver_tool.py validate 01.2.3                     # exit 1 (leading zero)
python semver_tool.py validate v1.2.3                     # exit 1, hints that the SemVer is `1.2.3`

# Parse to JSON
python semver_tool.py parse 2.4.7-rc.2+build.91
# {
#   "version": "2.4.7-rc.2+build.91",
#   "major": 2, "minor": 4, "patch": 7,
#   "prerelease": ["rc", "2"],
#   "build": ["build", "91"],
#   "is_stable": false,
#   "is_prerelease": true,
#   "is_initial_development": false
# }

# Compare (§11 rules, build metadata ignored per §10)
python semver_tool.py compare 1.0.0-rc.2 1.0.0-rc.11      # → 1.0.0-rc.2 < 1.0.0-rc.11 / -1
python semver_tool.py compare 1.0.0+a    1.0.0+b          # → 1.0.0+a == 1.0.0+b / 0

# Bump (with correct resets per §6/§7/§8)
python semver_tool.py bump 2.4.7 major                    # → 3.0.0
python semver_tool.py bump 2.4.7 minor                    # → 2.5.0
python semver_tool.py bump 2.4.7 patch                    # → 2.4.8
python semver_tool.py bump 1.4.7-rc.2+build.91 major      # → 2.0.0 (pre & build dropped)
python semver_tool.py bump 1.0.0-rc.2 prerelease          # → 1.0.0-rc.3
python semver_tool.py bump 1.0.0-alpha.5 prerelease beta  # → 1.0.0-beta.1 (switch lane)
python semver_tool.py bump 1.0.0-rc.7 release             # → 1.0.0 (finalize)
python semver_tool.py bump 1.2.3 release                  # exit 1: nothing to finalize (§3 immutability)

# Start a pre-release of the NEXT version (tag required)
python semver_tool.py bump 1.4.7 preminor rc              # → 1.5.0-rc.1
python semver_tool.py bump 1.4.7 prepatch rc              # → 1.4.8-rc.1
python semver_tool.py bump 1.4.7 premajor alpha           # → 2.0.0-alpha.1

# `prerelease` warns on stderr when the result does not sort above the
# input — e.g. starting a pre-release on an already-released version
# (1.0.0 → 1.0.0-alpha.1 sorts BELOW 1.0.0, §11.3) or switching to an
# earlier lane (rc → alpha). The version is still printed to stdout.

# Sort ascending precedence (the canonical spec §11.4 example):
python semver_tool.py sort 1.0.0 1.0.0-rc.1 1.0.0-beta.11 1.0.0-beta.2 \
                          1.0.0-beta 1.0.0-alpha.beta 1.0.0-alpha.1 1.0.0-alpha
# 1.0.0-alpha
# 1.0.0-alpha.1
# 1.0.0-alpha.beta
# 1.0.0-beta
# 1.0.0-beta.2
# 1.0.0-beta.11
# 1.0.0-rc.1
# 1.0.0
```

## When to use

Prefer the tool over hand-computing whenever:

- The version has a pre-release identifier (precedence rules are subtle).
- You need to apply resets correctly (minor bump → patch=0, etc.).
- You need to sort more than 2 versions.
- The user pastes a non-trivial version string and asks "is this valid?".

For pure narrative decisions (MAJOR vs MINOR vs PATCH judgment), the tool
can't help — that's a content question. Use `references/decision-guide.md`.

## Testing the tool

```bash
python -m unittest discover tests/
```

See `tests/test_semver_tool.py` for the test suite. It covers every spec
example plus regression cases.
