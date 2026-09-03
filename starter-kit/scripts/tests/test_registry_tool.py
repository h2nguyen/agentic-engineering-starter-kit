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

        for path in ("kb.d", "adr", "changelog.d"):
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
    """One fragment per change, with the categories it touches inside it."""

    def fragment(self, name, sections):
        lines = ["# A change", ""]
        for category, bullets in sections:
            lines.append(f"## {category}")
            lines.append("")
            lines.extend(f"- {b}" for b in bullets)
            lines.append("")
        return self.write(f"changelog.d/{name}", "\n".join(lines))

    def test_only_categories_with_entries_are_emitted(self):
        self.fragment("2026-08-29-one.md", [("Added", ["Adds a thing"])])
        self.run_tool("generate", "--registry", "changelog")
        body = self.read("CHANGELOG.md")
        self.assertIn("### Added", body)
        self.assertNotIn("### Fixed", body)

    def test_categories_keep_their_declared_order(self):
        self.fragment(
            "2026-08-29-one.md",
            [("Fixed", ["Fixes a thing"]), ("Added", ["Adds a thing"])],
        )
        self.run_tool("generate", "--registry", "changelog")
        body = self.read("CHANGELOG.md")
        self.assertLess(body.index("### Added"), body.index("### Fixed"))

    def test_one_fragment_can_span_several_categories(self):
        self.fragment(
            "2026-08-29-one.md",
            [("Added", ["Adds a thing"]), ("Fixed", ["Fixes a thing"])],
        )
        self.run_tool("generate", "--registry", "changelog")
        body = self.read("CHANGELOG.md")
        self.assertIn("Adds a thing", body)
        self.assertIn("Fixes a thing", body)

    def test_bullets_from_several_fragments_merge_under_one_category(self):
        self.fragment("2026-08-29-a.md", [("Added", ["From A"])])
        self.fragment("2026-08-30-b.md", [("Added", ["From B"])])
        self.run_tool("generate", "--registry", "changelog")
        body = self.read("CHANGELOG.md")
        self.assertEqual(body.count("### Added"), 1)
        self.assertLess(body.index("From A"), body.index("From B"))

    def test_unknown_category_heading_is_rejected(self):
        self.fragment("2026-08-29-one.md", [("Invented", ["Nope"])])
        self.assertEqual(self.run_tool("check", "--registry", "changelog"), 1)

    def test_bullet_before_any_heading_is_rejected(self):
        self.write("changelog.d/2026-08-29-one.md", "# A change\n\n- orphan bullet\n")
        self.assertEqual(self.run_tool("check", "--registry", "changelog"), 1)

    def test_fragment_with_no_bullets_is_rejected(self):
        self.write("changelog.d/2026-08-29-empty.md", "# A change\n\n## Added\n")
        self.assertEqual(self.run_tool("check", "--registry", "changelog"), 1)

    def test_a_fragment_nested_in_a_subdirectory_is_rejected(self):
        # The likely mistake for anyone who remembers the category-directory
        # layout. The generator never looks there, so the bullet would vanish
        # with no conflict and no error.
        self.write("changelog.d/added/2026-08-29-x.md", "# A change\n\n## Added\n\n- Nope\n")
        self.assertEqual(self.run_tool("check", "--registry", "changelog"), 1)

    def test_template_guidance_never_reaches_the_changelog(self):
        # The template carries an HTML comment telling the author which other
        # categories exist. It leaked into the rendered changelog as a bullet
        # continuation before the parser required continuations to be indented.
        self.write(
            "changelog.d/2026-08-29-one.md",
            "# A change\n\n## Added\n\n- A real bullet.\n"
            "<!-- One section per category this change touches. -->\n",
        )
        self.run_tool("generate", "--registry", "changelog")
        body = self.read("CHANGELOG.md")
        self.assertIn("A real bullet.", body)
        self.assertNotIn("<!-- One section", body)

    def test_indented_lines_still_continue_a_bullet(self):
        self.write(
            "changelog.d/2026-08-29-two.md",
            "# A change\n\n## Added\n\n- First line\n  continued here.\n",
        )
        self.run_tool("generate", "--registry", "changelog")
        self.assertIn("continued here.", self.read("CHANGELOG.md"))

    def test_release_promotes_and_consumes_the_fragments(self):
        self.fragment("2026-08-20-one.md", [("Added", ["Adds a thing"])])
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
        self.assertEqual(
            [f for f in os.listdir(os.path.join(self.root, "changelog.d"))
             if f.endswith(".md")],
            [],
        )

    def test_a_bullet_added_after_a_release_lands_in_unreleased(self):
        # The append-versus-promote hazard: a release moves the anchor a
        # concurrent branch was appending to. Because promotion consumes the
        # fragment files, the concurrent branch still holds its own file and
        # its bullet reappears under [Unreleased] instead of being absorbed
        # into the section that moved.
        self.fragment("2026-08-20-released.md", [("Added", ["Shipped in 1.0.0"])])
        self.run_tool("generate", "--registry", "changelog")
        self.run_tool(
            "release", "--registry", "changelog",
            "--version", "1.0.0", "--date", "2026-08-28",
        )
        self.fragment("2026-08-29-later.md", [("Fixed", ["Landed after the release"])])
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


class TestFilenamePrefix(RegistryTestCase):
    """The MADR convention: adr-NNNN-short-title.md.

    The prefix belongs to the filename only. The identifier still comes from
    id_prefix plus the number, so `adr-` never leaks into a citation.
    """

    scheme = "numeric"

    def setUp(self):
        super().setUp()
        config = json.loads(self.read("registries.json"))
        for registry in config["registries"]:
            if registry["name"] == "adr":
                registry["filename_prefix"] = "adr-"
                registry["id_width"] = 4
        self.write("registries.json", json.dumps(config))

    def registry(self):
        args = rt.build_parser().parse_args(["check", "--registry", "adr"])
        return rt.load_registries(args)[0][0]

    def adr(self, name, body="# A decision\n\n## Context\n\nWhy.\n\n## Decision\n\nWhat.\n"):
        return self.write(f"adr/{name}", body)

    def test_prefix_stays_out_of_the_identifier(self):
        path = self.adr("adr-0001-a-decision.md")
        self.assertEqual(self.registry().id_for(path), "ADR-0001")

    def test_a_filename_missing_the_prefix_is_rejected(self):
        path = self.adr("0001-a-decision.md")
        with self.assertRaises(rt.RegistryError) as caught:
            self.registry().id_for(path)
        self.assertIn("adr-", str(caught.exception))

    def test_wrong_width_is_still_rejected_under_a_prefix(self):
        path = self.adr("adr-001-a-decision.md")
        with self.assertRaises(rt.RegistryError):
            self.registry().id_for(path)

    def test_allocation_respects_the_prefix(self):
        self.adr("adr-0001-first.md")
        self.adr("adr-0014-fourteenth.md")
        self.assertEqual(rt.next_number(self.registry()), "0015")

    def test_new_writes_a_madr_filename(self):
        self.assertEqual(
            self.run_tool("new", "--registry", "adr", "--title", "Adopt an outbox"),
            0,
        )
        self.assertTrue(os.path.isfile(
            os.path.join(self.root, "adr/adr-0001-adopt-an-outbox.md")))

    def test_duplicate_numbers_are_still_caught_under_a_prefix(self):
        self.adr("adr-0001-one.md")
        self.adr("adr-0001-also-one.md")
        self.assertEqual(self.run_tool("check", "--registry", "adr"), 1)

    def test_prefix_works_with_the_slug_scheme_too(self):
        config = json.loads(self.read("registries.json"))
        for registry in config["registries"]:
            if registry["name"] == "adr":
                registry["id_scheme"] = "slug"
        self.write("registries.json", json.dumps(config))
        path = self.adr("adr-2026-08-29-a-decision.md")
        self.assertEqual(
            self.registry().id_for(path), "ADR-2026-08-29-a-decision"
        )


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

    def test_changelog_entry_does_not_require_a_category(self):
        # A change spans whatever categories it spans; the fragment seeds the
        # first one and the author adds the rest as headings.
        self.assertEqual(
            self.run_tool("new", "--registry", "changelog",
                          "--title", "A change", "--date", "2026-08-29"),
            0,
        )
        body = self.read("changelog.d/2026-08-29-a-change.md")
        self.assertIn("## Added", body)

    def test_changelog_fragment_is_flat_not_nested(self):
        self.run_tool("new", "--registry", "changelog", "--category", "fixed",
                      "--title", "A change", "--date", "2026-08-29")
        self.assertTrue(os.path.isfile(
            os.path.join(self.root, "changelog.d/2026-08-29-a-change.md")))
        self.assertIn("## Fixed", self.read("changelog.d/2026-08-29-a-change.md"))

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
