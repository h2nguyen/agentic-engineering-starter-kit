# Precedence: how SemVer versions compare

Spec §11. This file walks the algorithm end-to-end with traces, because
pre-release ordering is the most error-prone part of SemVer.

## The algorithm in one block

```
compare(a, b):
    1. Compare a.major, b.major numerically. Done if differ.
    2. Compare a.minor, b.minor numerically. Done if differ.
    3. Compare a.patch, b.patch numerically. Done if differ.
    4. Build metadata is ignored. Always.
    5. If both have no pre-release: equal.
    6. If a has no pre-release but b does: a > b.
       If b has no pre-release but a does: b > a.
       (A normal release always outranks any pre-release of the same core.)
    7. Both have pre-release: compare identifier-by-identifier left to right:
       a. If both identifiers are numeric: compare numerically.
       b. If both are alphanumeric: compare lexically (ASCII).
       c. If one is numeric and the other alphanumeric:
          numeric has LOWER precedence (i.e. numeric < alphanumeric).
       d. If all identifiers in the shorter pre-release match the prefix of
          the longer, the longer has HIGHER precedence.
       e. Otherwise return the result of the first differing comparison.
```

The full ordering example from the spec:

```
1.0.0-alpha
  < 1.0.0-alpha.1
  < 1.0.0-alpha.beta
  < 1.0.0-beta
  < 1.0.0-beta.2
  < 1.0.0-beta.11
  < 1.0.0-rc.1
  < 1.0.0
```

## Worked traces

### Trace 1: `1.0.0-alpha` vs `1.0.0-alpha.1`

- major/minor/patch all equal: `1 == 1`, `0 == 0`, `0 == 0`. Continue to §11.4.
- pre-release identifiers:
  - left: `["alpha"]`
  - right: `["alpha", "1"]`
- compare position 0: `"alpha" == "alpha"` → continue.
- position 1: left has no more identifiers; right has `"1"`.
- Apply rule 11.4.4 (longer pre-release wins when all preceding match).
- **`1.0.0-alpha < 1.0.0-alpha.1`**.

### Trace 2: `1.0.0-alpha.1` vs `1.0.0-alpha.beta`

- pre-release identifiers:
  - left: `["alpha", "1"]`
  - right: `["alpha", "beta"]`
- position 0: equal.
- position 1: left is numeric (`1`), right is alphanumeric (`beta`).
- Rule 11.4.3: numeric identifiers have LOWER precedence than non-numeric.
- **`1.0.0-alpha.1 < 1.0.0-alpha.beta`**.

This is the rule people forget. "`1` should be less than `beta` only
because numeric < alphanumeric," NOT because `'1' < 'b'` lexically (which
is also true here, but it's the wrong reason and would mislead you on a
case like `1.0.0-alpha.9` vs `1.0.0-alpha.aa`).

### Trace 3: `1.0.0-beta.2` vs `1.0.0-beta.11`

- pre-release identifiers:
  - left: `["beta", "2"]`
  - right: `["beta", "11"]`
- position 0: equal.
- position 1: both are numeric. Rule 11.4.1: compare numerically.
- `2 < 11`.
- **`1.0.0-beta.2 < 1.0.0-beta.11`**.

This is the most common bug in naive lexical-sort implementations:
they sort `["1.0.0-beta.11", "1.0.0-beta.2"]` because `'1' < '2'`.
Always parse pre-release identifiers and apply rule 11.4 per identifier.

### Trace 4: `1.0.0-rc.1` vs `1.0.0`

- major/minor/patch equal.
- pre-release: left has `["rc", "1"]`; right has none.
- Rule 11.3: pre-release < normal.
- **`1.0.0-rc.1 < 1.0.0`**.

### Trace 5: Build metadata equality

`1.0.0+build.1` vs `1.0.0+build.999`:
- major/minor/patch equal. Build metadata ignored.
- No pre-release on either side.
- **They are equal-precedence.** A package manager that sees these as
  "the same" is correct per spec, even though the file contents differ.
- This is also why build metadata should never carry information that
  affects compatibility — it's invisible to dependency resolution.

### Trace 6: Pure numeric pre-release identifiers

`1.0.0-1` vs `1.0.0-alpha`:
- left identifiers: `["1"]` (numeric)
- right identifiers: `["alpha"]` (alphanumeric)
- Rule 11.4.3: numeric < alphanumeric.
- **`1.0.0-1 < 1.0.0-alpha`**.

So `1.0.0-1`, `1.0.0-2`, `1.0.0-3` is a valid (if unusual) pre-release
sequence, and all of them are LESS than `1.0.0-alpha`.

### Trace 7: Mixed alphanumeric inside an identifier

`1.0.0-alpha10` vs `1.0.0-alpha2`:
- These are both single identifiers (no dots).
- Both contain non-digits, so both are alphanumeric. Rule 11.4.2: lexical.
- `'a' == 'a'`, `'l' == 'l'`, ..., `'a' == 'a'`, then `'1'` vs `'2'`.
- `'1' < '2'` lexically.
- **`1.0.0-alpha10 < 1.0.0-alpha2`**.

This is why `alpha10` < `alpha2` if you bake the number into the identifier
instead of dotting it. Use `alpha.10` / `alpha.2` to get numeric compare.

## Common pitfalls

- **Sorting version strings lexicographically.** Wrong, see Trace 3. Always
  parse first.
- **Treating `1.0.0+sha.abc` and `1.0.0+sha.def` as different.** They are
  equal precedence per §10.
- **Treating `1.0.0-rc.11 < 1.0.0-rc.2`.** Wrong; numeric identifiers
  compare numerically.
- **Treating `v1.2.3` as a SemVer.** Strip the `v` first.
- **Allowing leading zeros.** `1.0.01` is invalid (§2), so is the
  pre-release identifier `01` (§9).
- **Comparing versions with different MAJOR via pre-release rules.** Don't —
  major/minor/patch dominate. `1.0.0-rc.1 > 0.9.9`.

## Use the script for non-trivial comparisons

```bash
python scripts/semver_tool.py compare "1.0.0-rc.2" "1.0.0-rc.11"
python scripts/semver_tool.py sort "1.0.0" "1.0.0-rc.1" "1.0.0-alpha" "1.0.0-beta"
```

The script implements §11 exactly. Trust it over hand-comparing for any
case involving pre-release identifiers.
