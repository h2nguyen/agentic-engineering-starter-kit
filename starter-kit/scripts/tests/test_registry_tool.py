#!/usr/bin/env python3
"""Unit tests for registry_tool.py.

Stdlib unittest, so they run anywhere python3 does:

    python3 -m unittest discover -s starter-kit/scripts/tests -p 'test_*.py'
"""

import json
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import registry_tool as rt  # noqa: E402


BASE_CONFIG = {
    "id_scheme": "slug",
    "id_width": 3,
    "rule_pointer": "the shared-registries rule file",
    "registries": [
        {
            "name": "kb",
            "kind": "entries",
            "id_prefix": "ISSUE",
            "fragments": "kb.d",
            "output": "KB.md",
            "required_fields": ["Symptom", "Fix"],
        },
        {
            "name": "changelog",
            "kind": "changelog",
            "fragments": "changelog.d",
            "output": "CHANGELOG.md",
            "categories": ["Added", "Fixed"],
        },
        {
            "name": "adr",
            "kind": "documents",
            "id_prefix": "ADR",
            "fragments": "adr",
            "required_headings": ["Context", "Decision"],
        },
    ],
}


class RegistryTestCase(unittest.TestCase):
    """A scratch repository laid out the way the kit installs one."""

    scheme = "slug"

    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        self.previous = os.getcwd()
        self.addCleanup(os.chdir, self.previous)

        config = json.loads(json.dumps(BASE_CONFIG))
        config["id_scheme"] = self.scheme
        self.write("registries.json", json.dumps(config))

        for path in ("kb.d", "adr", "changelog.d/added", "changelog.d/fixed"):
            os.makedirs(os.path.join(self.root, path), exist_ok=True)

        self.write(
            "KB.md",
            "# Knowledge Base\n\n"
            "<!-- BEGIN GENERATED: kb -->\n\n<!-- END GENERATED: kb -->\n",
        )
        self.write(
            "CHANGELOG.md",
            "# Changelog\n\n## [Unreleased]\n\n"
            "<!-- BEGIN GENERATED: changelog -->\n\n"
            "<!-- END GENERATED: changelog -->\n",
        )
        os.chdir(self.root)

    # -- helpers ----------------------------------------------------------

    def write(self, relative, text):
        path = os.path.join(self.root, relative)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(text)
        return path

    def read(self, relative):
        with open(os.path.join(self.root, relative), encoding="utf-8") as handle:
            return handle.read()

    def run_tool(self, *argv):
        """Invoke as CI does: a failure is an exit code, not an exception."""
        return rt.main(list(argv))

    def run_raw(self, *argv):
        """Invoke below main()'s error handling, to assert on the message."""
        args = rt.build_parser().parse_args(list(argv))
        return args.func(args)

    def entry(self, name, title="A title", extra=""):
        return self.write(
            f"kb.d/{name}",
            f"# {title}\n\n**Symptom:** something.\n\n**Fix:** something else.\n{extra}",
        )


class TestSlugify(unittest.TestCase):
    def test_lowercases_and_hyphenates(self):
        self.assertEqual(rt.slugify("Cache Warms Before Config"), "cache-warms-before-config")

    def test_strips_punctuation_and_accents(self):
        self.assertEqual(rt.slugify("Röt: 500 — retry!"), "rot-500-retry")

    def test_truncates_on_a_word_boundary(self):
        result = rt.slugify("alpha beta gamma delta epsilon zeta", limit=20)
        self.assertLessEqual(len(result), 20)
        self.assertFalse(result.endswith("-"))


class TestIdentifierDerivation(RegistryTestCase):
    def registry(self, name="kb"):
        args = rt.build_parser().parse_args(["check", "--registry", name])
        return rt.load_registries(args)[0][0]

    def test_slug_scheme_uses_the_whole_stem(self):
        path = self.entry("2026-08-29-cache-warms.md")
        self.assertEqual(
            self.registry().id_for(path), "ISSUE-2026-08-29-cache-warms"
        )

    def test_malformed_filename_is_rejected_with_a_pointer(self):
        path = self.entry("Not A Valid Name.md")
        with self.assertRaises(rt.RegistryError) as caught:
            self.registry().id_for(path)
        message = str(caught.exception)
        self.assertIn("malformed fragment name", message)
        self.assertIn("shared-registries", message)

    def test_uppercase_slug_is_rejected(self):
        path = self.entry("2026-08-29-Cache-Warms.md")
        with self.assertRaises(rt.RegistryError):
            self.registry().id_for(path)


class TestNumericIdentifiers(RegistryTestCase):
    scheme = "numeric"

    def registry(self):
        args = rt.build_parser().parse_args(["check", "--registry", "kb"])
        return rt.load_registries(args)[0][0]

    def test_numeric_scheme_drops_the_trailing_slug(self):
        path = self.entry("007-cache-warms.md")
        self.assertEqual(self.registry().id_for(path), "ISSUE-007")

    def test_wrong_width_is_rejected_before_uniqueness_is_tested(self):
        # The hazard this guards: ISSUE-7 and ISSUE-007 are the same identifier
        # to a reader and different ones to a naive uniqueness check.
        for name in ("7-cache-warms.md", "0007-cache-warms.md"):
            with self.subTest(name=name):
                path = self.entry(name)
                with self.assertRaises(rt.RegistryError):
                    self.registry().id_for(path)
                os.remove(path)

    def test_allocation_advances_past_the_highest_existing_number(self):
        self.entry("001-first.md")
        self.entry("014-fourteenth.md")
        self.assertEqual(rt.next_number(self.registry()), "015")


class TestGeneration(RegistryTestCase):
    def test_entries_are_ordered_deterministically(self):
        self.entry("2026-08-29-zebra.md", title="Zebra")
        self.entry("2026-01-02-alpha.md", title="Alpha")
        self.assertEqual(self.run_tool("generate"), 0)
        body = self.read("KB.md")
        self.assertLess(body.index("Alpha"), body.index("Zebra"))

    def test_generation_is_idempotent(self):
        self.entry("2026-08-29-one.md")
        self.run_tool("generate")
        once = self.read("KB.md")
        self.run_tool("generate")
        self.assertEqual(once, self.read("KB.md"))

    def test_content_outside_the_region_is_preserved(self):
        self.entry("2026-08-29-one.md")
        self.run_tool("generate")
        self.assertTrue(self.read("KB.md").startswith("# Knowledge Base"))

    def test_missing_region_markers_explain_the_fix(self):
        self.write("KB.md", "# Knowledge Base\n\nno markers here\n")
        self.entry("2026-08-29-one.md")
        with self.assertRaises(rt.RegistryError) as caught:
            self.run_raw("generate")
        self.assertIn("BEGIN GENERATED", str(caught.exception))

    def test_fragment_without_a_title_is_rejected(self):
        self.write("kb.d/2026-08-29-untitled.md", "**Symptom:** no heading.\n")
        with self.assertRaises(rt.RegistryError) as caught:
            self.run_raw("generate", "--registry", "kb")
        self.assertIn("no title", str(caught.exception))

    def test_scaffolding_files_are_not_entries(self):
        self.entry("_template.md")
        self.write("kb.d/README.md", "# Readme\n")
        self.assertEqual(self.run_tool("generate"), 0)
        self.assertNotIn("## ISSUE", self.read("KB.md"))

    def test_drift_check_fails_on_a_hand_edited_artifact(self):
        self.entry("2026-08-29-one.md")
        self.run_tool("generate")
        self.write("KB.md", self.read("KB.md").replace("A title", "Edited by hand"))
        self.assertEqual(self.run_tool("generate", "--check"), 1)

    def test_drift_check_passes_when_in_sync(self):
        self.entry("2026-08-29-one.md")
        self.run_tool("generate")
        self.assertEqual(self.run_tool("generate", "--check"), 0)


class TestChangelog(RegistryTestCase):
    def bullet(self, category, name, text="A bullet"):
        return self.write(f"changelog.d/{category}/{name}", f"# {text}\n")

    def test_only_categories_with_entries_are_emitted(self):
        self.bullet("added", "2026-08-29-one.md", "Adds a thing")
        self.run_tool("generate", "--registry", "changelog")
        body = self.read("CHANGELOG.md")
        self.assertIn("### Added", body)
        self.assertNotIn("### Fixed", body)

    def test_categories_keep_their_declared_order(self):
        self.bullet("fixed", "2026-08-29-f.md", "Fixes a thing")
        self.bullet("added", "2026-08-29-a.md", "Adds a thing")
        self.run_tool("generate", "--registry", "changelog")
        body = self.read("CHANGELOG.md")
        self.assertLess(body.index("### Added"), body.index("### Fixed"))

    def test_a_fragment_in_an_unknown_category_is_rejected(self):
        self.write("changelog.d/invented/2026-08-29-x.md", "# Nope\n")
        # An unknown directory is not scanned by the generator, so the gate is
        # what notices the bullet would silently never appear.
        self.assertEqual(self.run_tool("check", "--registry", "changelog"), 1)

    def test_release_promotes_and_consumes_the_fragments(self):
        self.bullet("added", "2026-08-20-one.md", "Adds a thing")
        self.run_tool("generate", "--registry", "changelog")
        self.assertEqual(
            self.run_tool(
                "release", "--registry", "changelog",
                "--version", "1.0.0", "--date", "2026-08-28",
            ),
            0,
        )
        body = self.read("CHANGELOG.md")
        self.assertIn("## [1.0.0] — 2026-08-28", body)
        self.assertIn("Adds a thing", body)
        self.assertEqual(os.listdir(os.path.join(self.root, "changelog.d/added")), [])

    def test_a_bullet_added_after_a_release_lands_in_unreleased(self):
        # The append-versus-promote hazard: a release moves the anchor a
        # concurrent branch was appending to. Because promotion consumes the
        # fragment files, the concurrent branch still holds its own file and
        # its bullet reappears under [Unreleased] instead of being absorbed
        # into the section that moved.
        self.bullet("added", "2026-08-20-released.md", "Shipped in 1.0.0")
        self.run_tool("generate", "--registry", "changelog")
        self.run_tool(
            "release", "--registry", "changelog",
            "--version", "1.0.0", "--date", "2026-08-28",
        )
        self.bullet("fixed", "2026-08-29-later.md", "Landed after the release")
        self.run_tool("generate", "--registry", "changelog")

        body = self.read("CHANGELOG.md")
        unreleased, released = body.split("## [1.0.0]", 1)
        self.assertIn("Landed after the release", unreleased)
        self.assertNotIn("Landed after the release", released)
        self.assertIn("Shipped in 1.0.0", released)

    def test_release_refuses_when_there_is_nothing_to_promote(self):
        with self.assertRaises(rt.RegistryError):
            self.run_raw("release", "--registry", "changelog", "--version", "1.0.0")


class TestUniquenessGate(RegistryTestCase):
    scheme = "numeric"

    def test_clean_tree_passes(self):
        self.entry("001-one.md")
        self.entry("002-two.md")
        self.assertEqual(self.run_tool("check", "--registry", "kb"), 0)

    def test_duplicate_identifiers_fail(self):
        self.entry("001-one.md")
        self.entry("001-also-one.md")
        self.assertEqual(self.run_tool("check", "--registry", "kb"), 1)

    def test_allowlisted_pair_passes(self):
        self.entry("001-one.md")
        self.entry("001-also-one.md")
        self.write(
            ".registry-id-duplicate-allowlist",
            "# legacy pair, both already cited\nkb.d/001-also-one.md kb.d/001-one.md\n",
        )
        self.assertEqual(self.run_tool("check", "--registry", "kb"), 0)

    def test_a_third_file_breaks_the_allowlisted_pair(self):
        # The reason the allowlist is keyed on the filename pair rather than on
        # the number: a number-keyed exemption would read as "skip 001" and let
        # this third file in unnoticed.
        self.entry("001-one.md")
        self.entry("001-also-one.md")
        self.entry("001-yet-another.md")
        self.write(
            ".registry-id-duplicate-allowlist",
            "kb.d/001-also-one.md kb.d/001-one.md\n",
        )
        self.assertEqual(self.run_tool("check", "--registry", "kb"), 1)

    def test_malformed_allowlist_line_is_rejected(self):
        self.write(".registry-id-duplicate-allowlist", "001\n")
        with self.assertRaises(rt.RegistryError):
            self.run_raw("check", "--registry", "kb")

    def test_missing_required_field_fails(self):
        self.write("kb.d/003-partial.md", "# Partial\n\n**Symptom:** only one field.\n")
        self.assertEqual(self.run_tool("check", "--registry", "kb"), 1)

    def test_missing_required_heading_fails(self):
        self.write("adr/001-a-decision.md", "# A decision\n\n## Context\n\nWhy.\n")
        self.assertEqual(self.run_tool("check", "--registry", "adr"), 1)

    def test_required_heading_matches_a_longer_wording(self):
        self.write(
            "adr/001-a-decision.md",
            "# A decision\n\n## Context\n\nWhy.\n\n## Decision made\n\nWhat.\n",
        )
        self.assertEqual(self.run_tool("check", "--registry", "adr"), 0)


class TestConfiguration(RegistryTestCase):
    def test_unknown_registry_names_the_declared_ones(self):
        with self.assertRaises(rt.RegistryError) as caught:
            self.run_raw("check", "--registry", "nope")
        self.assertIn("declared:", str(caught.exception))

    def test_unknown_scheme_is_rejected(self):
        config = json.loads(self.read("registries.json"))
        config["id_scheme"] = "roman-numerals"
        self.write("registries.json", json.dumps(config))
        with self.assertRaises(rt.RegistryError):
            self.run_raw("check")

    def test_per_registry_scheme_overrides_the_default(self):
        config = json.loads(self.read("registries.json"))
        config["registries"][0]["id_scheme"] = "numeric"
        self.write("registries.json", json.dumps(config))
        args = rt.build_parser().parse_args(["check", "--registry", "kb"])
        registries, _, _ = rt.load_registries(args)
        self.assertEqual(registries[0].id_scheme, "numeric")

    def test_config_is_found_from_a_subdirectory(self):
        nested = os.path.join(self.root, "a", "b")
        os.makedirs(nested, exist_ok=True)
        os.chdir(nested)
        self.assertEqual(self.run_tool("check"), 0)

    def test_missing_config_explains_where_to_get_one(self):
        os.remove(os.path.join(self.root, "registries.json"))
        os.chdir(tempfile.mkdtemp())
        with self.assertRaises(rt.RegistryError) as caught:
            self.run_raw("check")
        self.assertIn("registries.json.template", str(caught.exception))


class TestNewCommand(RegistryTestCase):
    def test_new_creates_a_fragment_with_the_required_fields(self):
        self.assertEqual(
            self.run_tool(
                "new", "--registry", "kb",
                "--title", "Cache warms before the config is loaded",
                "--date", "2026-08-29",
            ),
            0,
        )
        path = "kb.d/2026-08-29-cache-warms-before-the-config-is-loaded.md"
        body = self.read(path)
        self.assertIn("**Symptom:**", body)
        self.assertIn("**Fix:**", body)

    def test_new_refuses_to_clobber_an_existing_fragment(self):
        args = ("new", "--registry", "kb", "--title", "Same title", "--date", "2026-08-29")
        self.assertEqual(self.run_tool(*args), 0)
        with self.assertRaises(rt.RegistryError):
            self.run_raw(*args)

    def test_changelog_entry_requires_a_category(self):
        with self.assertRaises(rt.RegistryError):
            self.run_raw("new", "--registry", "changelog", "--title", "A bullet")

    def test_changelog_entry_rejects_an_unknown_category(self):
        with self.assertRaises(rt.RegistryError) as caught:
            self.run_raw(
                "new", "--registry", "changelog",
                "--category", "invented", "--title", "A bullet",
            )
        self.assertIn("Added", str(caught.exception))

    def test_bad_date_is_rejected(self):
        with self.assertRaises(rt.RegistryError):
            self.run_raw("new", "--registry", "kb", "--title", "X", "--date", "29-08-2026")

    def test_untitleable_input_asks_for_an_explicit_slug(self):
        with self.assertRaises(rt.RegistryError) as caught:
            self.run_raw("new", "--registry", "kb", "--title", "→ ←", "--date", "2026-08-29")
        self.assertIn("--slug", str(caught.exception))


if __name__ == "__main__":
    unittest.main(verbosity=2)
