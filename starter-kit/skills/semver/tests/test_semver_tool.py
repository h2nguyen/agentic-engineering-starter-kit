"""
Test suite for semver_tool.py.

Every test references the spec section it covers. The single most important
test is `test_canonical_precedence_chain` — if that ever fails, the tool's
core algorithm is broken.

Run from the skill root:

    python -m unittest discover tests/
"""

import json
import os
import subprocess
import sys
import unittest
from functools import cmp_to_key

# Make the scripts/ directory importable.
HERE = os.path.dirname(os.path.abspath(__file__))
SKILL_ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(SKILL_ROOT, "scripts"))

import semver_tool as st  # noqa: E402


class TestValidation(unittest.TestCase):
    """§2, §9, §10 — syntax."""

    def test_valid_minimal(self):
        self.assertTrue(st.is_valid("0.0.0"))
        self.assertTrue(st.is_valid("1.2.3"))
        self.assertTrue(st.is_valid("10.20.30"))

    def test_valid_with_prerelease(self):
        # All spec examples from §9.
        for v in [
            "1.0.0-alpha",
            "1.0.0-alpha.1",
            "1.0.0-0.3.7",
            "1.0.0-x.7.z.92",
            "1.0.0-x-y-z.--",
        ]:
            self.assertTrue(st.is_valid(v), v)

    def test_valid_with_build(self):
        # All spec examples from §10.
        for v in [
            "1.0.0-alpha+001",
            "1.0.0+20130313144700",
            "1.0.0-beta+exp.sha.5114f85",
            "1.0.0+21AF26D3----117B344092BD",
        ]:
            self.assertTrue(st.is_valid(v), v)

    def test_invalid_leading_zero_in_core(self):
        # §2: no leading zeros in MAJOR/MINOR/PATCH.
        for v in ["01.0.0", "1.01.0", "1.0.01"]:
            self.assertFalse(st.is_valid(v), v)

    def test_invalid_leading_zero_in_prerelease_numeric(self):
        # §9: numeric identifiers MUST NOT include leading zeros.
        self.assertFalse(st.is_valid("1.0.0-01"))

    def test_invalid_empty_identifier(self):
        self.assertFalse(st.is_valid("1.0.0-"))
        self.assertFalse(st.is_valid("1.0.0+"))
        self.assertFalse(st.is_valid("1.0.0-alpha."))
        self.assertFalse(st.is_valid("1.0.0-alpha..1"))

    def test_invalid_shapes(self):
        # §2: exactly three dot-separated numeric elements.
        for v in ["1", "1.2", "1.2.3.4", " 1.2.3", "1.2.3 ", "1.2.x"]:
            self.assertFalse(st.is_valid(v), v)

    def test_invalid_identifier_characters(self):
        # §9: identifiers are [0-9A-Za-z-] only.
        self.assertFalse(st.is_valid("1.0.0-alpha_beta"))
        self.assertFalse(st.is_valid("1.0.0-alpha.01"))  # leading zero (§9)

    def test_build_metadata_may_have_leading_zeros(self):
        # §10 / BNF: build identifiers are <digits>, leading zeros allowed.
        self.assertTrue(st.is_valid("1.0.0+001"))

    def test_v_prefix_is_not_a_semver(self):
        # FAQ: `v1.2.3` is not a SemVer — validation is strict about this.
        self.assertFalse(st.is_valid("v1.2.3"))

    def test_v_prefix_stripped_for_operations(self):
        # But `parse` (used by compare/bump/sort) strips a leading `v`
        # for convenience, matching the git-tag convention.
        v = st.parse("v1.2.3")
        self.assertEqual((v.major, v.minor, v.patch), (1, 2, 3))


class TestParsing(unittest.TestCase):
    def test_components(self):
        v = st.parse("2.4.7-rc.2+build.91")
        self.assertEqual(v.major, 2)
        self.assertEqual(v.minor, 4)
        self.assertEqual(v.patch, 7)
        self.assertEqual(v.prerelease, ("rc", "2"))
        self.assertEqual(v.build, ("build", "91"))

    def test_no_prerelease_no_build(self):
        v = st.parse("1.2.3")
        self.assertEqual(v.prerelease, ())
        self.assertEqual(v.build, ())

    def test_roundtrip(self):
        for s in [
            "0.0.0",
            "1.0.0-alpha.beta",
            "2.4.7-rc.2+build.91",
            "1.0.0+21AF26D3----117B344092BD",
        ]:
            self.assertEqual(str(st.parse(s)), s)


class TestPrecedence(unittest.TestCase):
    """§11 — precedence rules."""

    def _cmp(self, a, b):
        return st.compare(st.parse(a), st.parse(b))

    def test_core_numeric_ordering(self):
        # §11.2: 1.0.0 < 2.0.0 < 2.1.0 < 2.1.1.
        self.assertEqual(self._cmp("1.0.0", "2.0.0"), -1)
        self.assertEqual(self._cmp("2.0.0", "2.1.0"), -1)
        self.assertEqual(self._cmp("2.1.0", "2.1.1"), -1)

    def test_double_digit_minor_outranks_single(self):
        # §2: 1.9.0 → 1.10.0 → 1.11.0 (numeric, not lexical).
        self.assertEqual(self._cmp("1.9.0", "1.10.0"), -1)
        self.assertEqual(self._cmp("1.10.0", "1.11.0"), -1)

    def test_prerelease_lower_than_normal(self):
        # §11.3: 1.0.0-alpha < 1.0.0.
        self.assertEqual(self._cmp("1.0.0-alpha", "1.0.0"), -1)
        self.assertEqual(self._cmp("1.0.0", "1.0.0-alpha"), 1)

    def test_numeric_lower_than_alphanumeric(self):
        # §11.4.3: 1.0.0-alpha.1 < 1.0.0-alpha.beta.
        self.assertEqual(self._cmp("1.0.0-alpha.1", "1.0.0-alpha.beta"), -1)
        # Also: 1.0.0-1 < 1.0.0-alpha (whole identifier numeric vs alpha).
        self.assertEqual(self._cmp("1.0.0-1", "1.0.0-alpha"), -1)

    def test_numeric_identifiers_compared_numerically(self):
        # §11.4.1: 1.0.0-beta.2 < 1.0.0-beta.11.
        self.assertEqual(self._cmp("1.0.0-beta.2", "1.0.0-beta.11"), -1)
        self.assertEqual(self._cmp("1.0.0-rc.2", "1.0.0-rc.11"), -1)

    def test_longer_prerelease_wins(self):
        # §11.4.4: 1.0.0-alpha < 1.0.0-alpha.1.
        self.assertEqual(self._cmp("1.0.0-alpha", "1.0.0-alpha.1"), -1)

    def test_build_metadata_ignored(self):
        # §10: differs only in build metadata → equal.
        self.assertEqual(self._cmp("1.0.0+a", "1.0.0+b"), 0)
        self.assertEqual(self._cmp("1.0.0+build.1", "1.0.0+build.999"), 0)
        self.assertEqual(
            self._cmp(
                "1.0.0-rc.1+sha.abc", "1.0.0-rc.1+sha.def"
            ),
            0,
        )

    def test_canonical_precedence_chain(self):
        """
        The single most important test in the suite. From §11.4 of the spec:
        1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta
                    < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0
        """
        ordered = [
            "1.0.0-alpha",
            "1.0.0-alpha.1",
            "1.0.0-alpha.beta",
            "1.0.0-beta",
            "1.0.0-beta.2",
            "1.0.0-beta.11",
            "1.0.0-rc.1",
            "1.0.0",
        ]
        shuffled = list(reversed(ordered))
        versions = [st.parse(v) for v in shuffled]
        versions.sort(key=cmp_to_key(st.compare))
        self.assertEqual([str(v) for v in versions], ordered)


class TestBump(unittest.TestCase):
    """§6, §7, §8 — increments and resets."""

    def test_major_resets_minor_and_patch(self):
        v = st.bump(st.parse("2.4.7"), "major")
        self.assertEqual(str(v), "3.0.0")

    def test_minor_resets_patch(self):
        v = st.bump(st.parse("2.4.7"), "minor")
        self.assertEqual(str(v), "2.5.0")

    def test_patch_increment(self):
        v = st.bump(st.parse("2.4.7"), "patch")
        self.assertEqual(str(v), "2.4.8")

    def test_bump_drops_prerelease_and_build(self):
        v = st.bump(st.parse("1.4.7-rc.2+build.91"), "major")
        self.assertEqual(str(v), "2.0.0")
        v = st.bump(st.parse("1.4.7-rc.2+build.91"), "minor")
        self.assertEqual(str(v), "1.5.0")
        v = st.bump(st.parse("1.4.7-rc.2+build.91"), "patch")
        self.assertEqual(str(v), "1.4.8")

    def test_release_strips_pre_and_build(self):
        v = st.bump(st.parse("1.0.0-rc.7+sha.abc"), "release")
        self.assertEqual(str(v), "1.0.0")

    def test_release_strips_build_only(self):
        v = st.bump(st.parse("1.2.3+sha.abc"), "release")
        self.assertEqual(str(v), "1.2.3")

    def test_release_on_full_release_errors(self):
        # §3 immutability: re-releasing an identical version is not allowed.
        with self.assertRaises(ValueError):
            st.bump(st.parse("1.2.3"), "release")

    def test_premajor_preminor_prepatch(self):
        # Pre-release of the NEXT version: core bumped with resets, -TAG.1.
        v = st.parse("1.4.7")
        self.assertEqual(str(st.bump(v, "premajor", "alpha")), "2.0.0-alpha.1")
        self.assertEqual(str(st.bump(v, "preminor", "alpha")), "1.5.0-alpha.1")
        self.assertEqual(str(st.bump(v, "prepatch", "rc")), "1.4.8-rc.1")

    def test_pre_kinds_drop_existing_pre_and_build(self):
        v = st.bump(st.parse("1.4.7-rc.2+build.91"), "premajor", "alpha")
        self.assertEqual(str(v), "2.0.0-alpha.1")

    def test_pre_kinds_require_tag(self):
        for kind in ("premajor", "preminor", "prepatch"):
            with self.assertRaises(ValueError):
                st.bump(st.parse("1.4.7"), kind)

    def test_prerelease_iterate_increments_trailing_number(self):
        v = st.bump(st.parse("1.0.0-rc.2"), "prerelease")
        self.assertEqual(str(v), "1.0.0-rc.3")

    def test_prerelease_iterate_same_tag(self):
        v = st.bump(st.parse("1.0.0-rc.2"), "prerelease", "rc")
        self.assertEqual(str(v), "1.0.0-rc.3")

    def test_prerelease_switch_lane(self):
        # alpha → beta starts fresh at .1.
        v = st.bump(st.parse("1.0.0-alpha.5"), "prerelease", "beta")
        self.assertEqual(str(v), "1.0.0-beta.1")

    def test_prerelease_start_fresh_from_no_prerelease(self):
        v = st.bump(st.parse("1.0.0"), "prerelease", "alpha")
        self.assertEqual(str(v), "1.0.0-alpha.1")

    def test_prerelease_without_tag_on_clean_version_errors(self):
        with self.assertRaises(ValueError):
            st.bump(st.parse("1.0.0"), "prerelease")

    def test_zero_minor_bump(self):
        # 0.y.z convention: minor is the breaking boundary.
        v = st.bump(st.parse("0.7.3"), "minor")
        self.assertEqual(str(v), "0.8.0")


class TestCLI(unittest.TestCase):
    """Smoke-test that the script runs as a CLI."""

    script = os.path.join(SKILL_ROOT, "scripts", "semver_tool.py")

    def _run(self, *args):
        return subprocess.run(
            [sys.executable, self.script, *args],
            capture_output=True,
            text=True,
        )

    def test_validate_valid(self):
        r = self._run("validate", "1.2.3")
        self.assertEqual(r.returncode, 0)

    def test_validate_invalid(self):
        r = self._run("validate", "01.2.3")
        self.assertEqual(r.returncode, 1)

    def test_validate_v_prefix_invalid_with_hint(self):
        # FAQ: `v1.2.3` is a tag convention, not a SemVer.
        r = self._run("validate", "v1.2.3")
        self.assertEqual(r.returncode, 1)
        self.assertIn("1.2.3", r.stderr)
        self.assertIn("tag", r.stderr.lower())

    def test_bump_premajor_cli(self):
        r = self._run("bump", "1.4.7", "premajor", "alpha")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout.strip(), "2.0.0-alpha.1")

    def test_bump_release_on_full_release_fails(self):
        r = self._run("bump", "1.2.3", "release")
        self.assertEqual(r.returncode, 1)
        self.assertIn("immutability", r.stderr.lower())

    def test_prerelease_downgrade_warns(self):
        # Starting a pre-release on a clean version sorts BELOW it (§11.3).
        r = self._run("bump", "1.0.0", "prerelease", "alpha")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout.strip(), "1.0.0-alpha.1")
        self.assertIn("warning", r.stderr.lower())
        # Lane switch backwards (rc → alpha) is also a downgrade.
        r = self._run("bump", "1.0.0-rc.1", "prerelease", "alpha")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout.strip(), "1.0.0-alpha.1")
        self.assertIn("warning", r.stderr.lower())

    def test_prerelease_forward_iteration_does_not_warn(self):
        r = self._run("bump", "1.0.0-rc.2", "prerelease")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout.strip(), "1.0.0-rc.3")
        self.assertNotIn("warning", r.stderr.lower())

    def test_parse_json(self):
        r = self._run("parse", "1.0.0-rc.2+sha.abc")
        self.assertEqual(r.returncode, 0)
        data = json.loads(r.stdout)
        self.assertEqual(data["major"], 1)
        self.assertEqual(data["prerelease"], ["rc", "2"])
        self.assertEqual(data["build"], ["sha", "abc"])

    def test_compare_machine_readable(self):
        r = self._run("compare", "1.0.0-rc.2", "1.0.0-rc.11")
        self.assertEqual(r.returncode, 0)
        # Last line is the machine-readable -1/0/1.
        self.assertEqual(r.stdout.strip().splitlines()[-1], "-1")

    def test_sort(self):
        r = self._run(
            "sort",
            "1.0.0",
            "1.0.0-rc.1",
            "1.0.0-alpha",
            "1.0.0-beta",
        )
        self.assertEqual(r.returncode, 0)
        lines = r.stdout.strip().splitlines()
        self.assertEqual(
            lines,
            ["1.0.0-alpha", "1.0.0-beta", "1.0.0-rc.1", "1.0.0"],
        )


if __name__ == "__main__":
    unittest.main()
