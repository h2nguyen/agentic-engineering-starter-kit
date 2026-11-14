#!/usr/bin/env python3
"""Unit tests for graph_tool.py.

Stdlib unittest, so they run anywhere python3 does:

    python3 -m unittest discover -s starter-kit/scripts/tests -p 'test_*.py'

The acceptance test (test-graph-links.sh) proves the contract end to end
through the gate script; these pin the parsing and resolution rules it rests on.
"""

import contextlib
import io
import json
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import graph_tool as gt  # noqa: E402


BASE_CONFIG = {
    "id_scheme": "slug",
    "id_width": 3,
    "registries": [
        {
            "name": "debugging-kb",
            "kind": "entries",
            "id_prefix": "ISSUE",
            "fragments": "docs/kb.d",
            "output": "docs/KB.md",
        },
        {"name": "changelog", "kind": "changelog", "fragments": "changelog.d", "output": "CHANGELOG.md"},
        {
            "name": "adr",
            "kind": "documents",
            "id_prefix": "ADR",
            "id_scheme": "numeric",
            "id_width": 4,
            "filename_prefix": "adr-",
            "fragments": "docs/adr",
        },
    ],
}


class GraphTestCase(unittest.TestCase):
    """A scratch repository laid out the way the kit installs one."""

    def setUp(self):
        self.root = os.path.realpath(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        self.previous = os.getcwd()
        self.addCleanup(os.chdir, self.previous)
        os.chdir(self.root)
        self.config = json.loads(json.dumps(BASE_CONFIG))
        self.save_config()
        self.write(".claude/rules/testing.md", "# Testing Rules\n")
        self.write(".claude/rules/security.md", "# Security Rules\n")

    def save_config(self):
        self.write("registries.json", json.dumps(self.config))

    def write(self, rel, text):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
        return path

    def run_tool(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = gt.main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def graph(self):
        return gt.load_graph()


class NamesTest(unittest.TestCase):
    def test_a_rule_is_cited_by_its_stem(self):
        name, aliases = gt._names_for(".claude/rules/testing.md", ".claude/rules/*.md")
        self.assertEqual(name, "testing")
        self.assertIn("testing", aliases)

    def test_a_skill_is_cited_by_its_directory(self):
        name, aliases = gt._names_for(".claude/skills/semver/SKILL.md", ".claude/skills/*/SKILL.md")
        self.assertEqual((name, aliases), ("semver", ["semver"]))

    def test_a_script_keeps_its_extension_and_also_answers_without_it(self):
        name, aliases = gt._names_for("scripts/check-kb-shape.sh", "scripts/*")
        self.assertEqual(name, "check-kb-shape.sh")
        self.assertEqual(aliases, ["check-kb-shape.sh", "check-kb-shape"])

    def test_a_nested_document_is_cited_by_path_or_by_stem(self):
        name, aliases = gt._names_for("docs/arch/overview.md", "docs/**/*.md")
        self.assertEqual(name, "arch/overview")
        self.assertIn("overview", aliases)

    def test_a_suffix_after_the_wildcard_is_not_part_of_the_name(self):
        name, _ = gt._names_for(
            ".github/instructions/security.instructions.md",
            ".github/instructions/*.instructions.md",
        )
        self.assertEqual(name, "security")

    def test_a_pattern_without_a_wildcard_names_the_file(self):
        name, aliases = gt._names_for(".github/copilot-instructions.md", ".github/copilot-instructions.md")
        self.assertEqual(name, "copilot-instructions")
        self.assertIn("copilot-instructions.md", aliases)

    def test_templates_and_droppings_are_scaffolding(self):
        for rel in ("rules/_rule-template.md", "skills/_template/SKILL.md",
                    "scripts/check-convention.sh.template", "scripts/.DS_Store",
                    "scripts/__pycache__/x.pyc"):
            self.assertTrue(gt._is_scaffolding(rel), rel)
        self.assertFalse(gt._is_scaffolding(".claude/rules/testing.md"))


class ResolutionTest(GraphTestCase):
    def test_no_links_is_green_and_says_so(self):
        code, out, _ = self.run_tool("check")
        self.assertEqual(code, 0)
        self.assertIn("no typed links yet", out)

    def test_a_link_to_an_existing_rule_resolves(self):
        self.write(".claude/skills/release/SKILL.md", "# Release\n\n**Related:** RULE:testing\n")
        code, out, err = self.run_tool("check")
        self.assertEqual((code, err), (0, ""))
        self.assertIn("1 typed link(s) in 1 file(s) resolve", out)

    def test_a_dangling_link_names_file_line_and_the_real_names(self):
        self.write(".claude/skills/release/SKILL.md", "# Release\n\n**Related:** RULE:testng\n")
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn(".claude/skills/release/SKILL.md:3", err)
        self.assertIn("Did you mean RULE:testing?", err)
        self.assertIn("RULE artifacts here: security, testing", err)

    def test_a_kind_with_no_location_says_how_to_declare_one(self):
        shutil.rmtree(os.path.join(self.root, ".claude"))
        self.write("docs/agent-rules/testing.md", "# Testing Rules\n\n**Related:** SKILL:release\n")
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("has no SKILL artifacts", err)
        self.assertIn('"graph": {"nodes": {"SKILL": ["<glob>"]}}', err)

    def test_a_declared_location_replaces_the_default_for_that_kind_only(self):
        shutil.rmtree(os.path.join(self.root, ".claude"))
        self.write("docs/agent-rules/testing.md", "# Testing Rules\n\n**Related:** SKILL:release\n")
        self.write("docs/playbooks/release.md", "# Release playbook\n\n**Related:** RULE:testing\n")
        self.config["graph"] = {"nodes": {"SKILL": ["docs/playbooks/*.md"]}}
        self.save_config()
        code, out, err = self.run_tool("check")
        self.assertEqual((code, err), (0, ""))
        graph = self.graph()
        self.assertEqual(graph.by_path["docs/playbooks/release.md"].kind, "SKILL")
        self.assertEqual(graph.by_path["docs/agent-rules/testing.md"].kind, "RULE")

    def test_a_project_can_declare_a_kind_of_its_own(self):
        self.write(".claude/hooks/session-start.sh", "#!/bin/bash\n")
        self.write(".claude/rules/testing.md", "# Testing Rules\n\n**Related:** HOOK:session-start.sh\n")
        self.config["graph"] = {"nodes": {"HOOK": [".claude/hooks/*"]}}
        self.save_config()
        self.assertEqual(self.run_tool("check")[0], 0)

    def test_an_unknown_kind_is_not_a_link(self):
        self.write(".claude/rules/testing.md", "# Testing Rules\n\n**Related:** TICKET:1234\n")
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("is not a typed link this repository knows", err)

    def test_an_unfilled_placeholder_is_rejected(self):
        self.write(".claude/rules/testing.md", "# Testing Rules\n\n**Related:** RULE:<slug>\n")
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("unfilled placeholder", err)

    def test_a_file_a_specific_kind_claims_is_not_also_a_document(self):
        shutil.rmtree(os.path.join(self.root, ".claude"))
        self.write("docs/agent-rules/testing.md", "# Testing Rules\n")
        graph = self.graph()
        self.assertEqual(graph.by_path["docs/agent-rules/testing.md"].kind, "RULE")
        self.assertEqual(graph.find("DOC:agent-rules/testing"), [])


class EntryTest(GraphTestCase):
    def test_entries_and_decision_records_resolve_by_their_real_identifier(self):
        self.write("docs/kb.d/2026-08-29-cache-warms.md", "# Cache\n\n**Related:** ADR-0002, RULE:testing\n")
        self.write("docs/adr/adr-0002-retry-policy.md", "# Retry\n\n**Related:** ISSUE-2026-08-29-cache-warms\n")
        code, out, err = self.run_tool("check")
        self.assertEqual((code, err), (0, ""))
        self.assertIn("3 typed link(s) in 2 file(s)", out)

    def test_a_width_variant_does_not_resolve_and_the_real_identifier_is_suggested(self):
        self.write("docs/adr/adr-0002-retry-policy.md", "# Retry\n")
        self.write(".claude/rules/testing.md", "# Testing Rules\n\n**Related:** ADR-002\n")
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("no ADR entry has that identifier", err)
        self.assertIn("Did you mean ADR-0002?", err)

    def test_the_generated_artifact_is_a_node_but_not_a_source_of_links(self):
        self.write("docs/KB.md", "# KB\n\n## ISSUE-2026-08-29-gone: Gone\n\n**Related:** RULE:deleted\n")
        self.write(".claude/rules/testing.md", "# Testing Rules\n\n**Related:** DOC:KB\n")
        code, _, err = self.run_tool("check")
        self.assertEqual((code, err), (0, ""))

    def test_a_registry_prefix_with_a_hyphen_resolves(self):
        # The prefix used to be read as the text before the FIRST hyphen, so a
        # registry called BUG-REPORT could be declared and never cited.
        self.config["registries"].append(
            {"name": "bugs", "kind": "entries", "id_prefix": "BUG-REPORT", "fragments": "bugs.d"})
        self.save_config()
        self.write("bugs.d/2026-01-01-crash.md", "# Crash\n")
        self.write(".claude/rules/testing.md", "# Testing Rules\n\n**Related:** BUG-REPORT-2026-01-01-crash\n")
        code, _, err = self.run_tool("check")
        self.assertEqual((code, err), (0, ""))
        self.write(".claude/rules/testing.md", "# Testing Rules\n\n**Related:** BUG-REPORT-2026-01-01-gone\n")
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("no BUG-REPORT entry has that identifier", err)

    def test_changelog_fragments_are_not_entries(self):
        self.write("changelog.d/2026-08-29-thing.md", "# Thing\n\n**Related:** RULE:deleted\n")
        self.assertEqual(self.run_tool("check")[0], 0)


class LinkLineTest(GraphTestCase):
    def test_a_fenced_example_is_not_a_link(self):
        self.write(
            ".claude/rules/testing.md",
            "# Testing Rules\n\n````markdown\n```\n**Related:** RULE:nope\n```\n````\n\n"
            "~~~\n**Enforces:** RULE:nope\n~~~\n\nInline: `**Related:** RULE:nope`.\n",
        )
        code, out, err = self.run_tool("check")
        self.assertEqual((code, err), (0, ""))
        self.assertIn("no typed links yet", out)

    def test_an_unclosed_fence_is_reported_instead_of_hiding_what_follows(self):
        # Everything after an unclosed fence reads as code, so a dangling link
        # below it would never be looked at — and the gate would say OK.
        self.write(
            ".claude/rules/testing.md",
            "# Testing Rules\n\n```bash\nmake test\n\n**Related:** RULE:gone\n",
        )
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn(".claude/rules/testing.md:3", err)
        self.assertIn("never closed", err)

    def test_only_a_scripts_header_block_is_read(self):
        self.write(
            "scripts/check-tests.sh",
            "#!/usr/bin/env bash\n# Enforces: RULE:testing § The Rule — tests exist.\n"
            "set -e\ncat <<'EOF'\n# Enforces: RULE:nope\nEOF\n",
        )
        code, out, err = self.run_tool("check")
        self.assertEqual((code, err), (0, ""))
        self.assertIn("1 typed link(s)", out)

    def test_enforces_takes_a_section_and_a_note_per_line(self):
        self.write(
            "scripts/check-tests.sh",
            "#!/usr/bin/env bash\n"
            "# Enforces: RULE:testing § Fixtures, never clocks, RULE:security § Secrets —\n"
            "# the note runs on to the next line.\n",
        )
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1, "a comma inside a section pointer splits the item")
        self.assertIn("'never clocks'", err)
        self.write(
            "scripts/check-tests.sh",
            "#!/usr/bin/env bash\n# Enforces: RULE:testing § Fixtures, RULE:security § Secrets — why\n",
        )
        self.assertEqual(self.run_tool("check")[0], 0)
        graph = self.graph()
        self.assertEqual([e.token for e in graph.edges], ["RULE:testing", "RULE:security"])

    def test_the_old_prose_header_is_rejected_with_the_token_to_write(self):
        self.write(
            "scripts/check-tests.sh",
            "#!/bin/bash\n# Enforces: test naming — see .claude/rules/testing.md § Names\n",
        )
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("scripts/check-tests.sh:2", err)
        self.assertIn("An Enforces line names the rule first", err)
        self.assertIn("This line mentions .claude/rules/testing.md — that is RULE:testing.", err)

    def test_related_stays_a_plain_list(self):
        self.write(".claude/rules/testing.md", "# Testing Rules\n\n**Related:** RULE:security — because\n")
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("'RULE:security — because'", err)

    def test_an_empty_link_line_is_nothing(self):
        self.write(".claude/rules/testing.md", "# Testing Rules\n\n**Related:**\n")
        self.assertEqual(self.run_tool("check")[0], 0)


class HandoffTest(GraphTestCase):
    def setUp(self):
        super().setUp()
        self.write(".claude/agents/reviewer.md", "---\nname: reviewer\n---\n\n**Enforces:** RULE:testing\n")
        self.write("scripts/check-tests.sh", "#!/bin/bash\n# Enforces: RULE:testing\n")

    def test_a_handoff_names_what_runs_next(self):
        self.write(
            ".claude/commands/ship.md",
            "Ship it.\n\n**Hands off to:** SKILL:release\n",
        )
        self.write(
            ".claude/skills/release/SKILL.md",
            "# Release\n\n**Hands off to:** AGENT:reviewer, SCRIPT:check-tests.sh\n\n"
            "**Hands off to:** HUMAN — before the tag is pushed\n",
        )
        code, _, err = self.run_tool("check")
        self.assertEqual((code, err), (0, ""))

    def test_a_handoff_to_a_document_or_an_entry_is_rejected(self):
        self.write("docs/adr/adr-0002-retry-policy.md", "# Retry\n")
        for target in ("RULE:testing", "DOC:adr/README", "ADR-0002"):
            self.write("docs/adr/README.md", "# Decisions\n")
            self.write(".claude/skills/release/SKILL.md", f"# Release\n\n**Hands off to:** {target}\n")
            code, _, err = self.run_tool("check")
            self.assertEqual(code, 1, target)
            self.assertIn("a document does not run next", err)

    def test_human_is_only_a_handoff_target(self):
        self.write(".claude/rules/testing.md", "# Testing Rules\n\n**Related:** HUMAN\n")
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("HUMAN is a hand-off target", err)

    def test_impact_on_human_lists_the_approval_gates(self):
        self.write(".claude/agents/coach.md", "You coach.\n\n**Hands off to:** HUMAN — before any edit\n")
        code, out, _ = self.run_tool("impact", "HUMAN")
        self.assertEqual(code, 0)
        self.assertIn("approval gates of this workspace (1)", out)
        self.assertIn("AGENT:coach", out)


class AllowlistTest(GraphTestCase):
    def setUp(self):
        super().setUp()
        self.write("docs/adr/adr-0002-retry-policy.md", "# Retry\n\n**Related:** RULE:retired\n")

    def test_a_pair_with_a_reason_passes_and_is_not_silent(self):
        self.write(".graph-link-allowlist", "# header\ndocs/adr/adr-0002-retry-policy.md RULE:retired  # immutable record\n")
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 0)
        self.assertIn("note: docs/adr/adr-0002-retry-policy.md:3 cites RULE:retired", err)

    def test_a_path_written_with_a_leading_dot_slash_still_matches(self):
        self.write(".graph-link-allowlist", "./docs/adr/adr-0002-retry-policy.md RULE:retired  # immutable record\n")
        self.assertEqual(self.run_tool("check")[0], 0)

    def test_a_pair_without_a_reason_is_rejected(self):
        self.write(".graph-link-allowlist", "docs/adr/adr-0002-retry-policy.md RULE:retired\n")
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("has no '# reason'", err)

    def test_the_exemption_does_not_spread_to_another_file(self):
        self.write(".graph-link-allowlist", "docs/adr/adr-0002-retry-policy.md RULE:retired  # immutable record\n")
        self.write(".claude/rules/testing.md", "# Testing Rules\n\n**Related:** RULE:retired\n")
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn(".claude/rules/testing.md:3", err)

    def test_a_stale_entry_is_reported(self):
        self.write(".claude/rules/retired.md", "# Back again\n")
        self.write(".graph-link-allowlist", "docs/adr/adr-0002-retry-policy.md RULE:retired  # immutable record\n")
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("is not a dangling link any more", err)

    def test_only_a_dangling_link_can_be_allowlisted(self):
        self.write(".claude/skills/release/SKILL.md", "# Release\n\n**Hands off to:** RULE:testing\n")
        self.write(
            ".graph-link-allowlist",
            "docs/adr/adr-0002-retry-policy.md RULE:retired  # immutable record\n"
            ".claude/skills/release/SKILL.md RULE:testing  # trying to excuse a hand-off to a rule\n",
        )
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("a document does not run next", err)


class ReportTest(GraphTestCase):
    def setUp(self):
        super().setUp()
        self.write("scripts/check-tests.sh", "#!/bin/bash\n# Enforces: RULE:testing\n")
        self.write(".claude/agents/reviewer.md", "You review.\n\n**Enforces:** RULE:testing\n")
        self.write("docs/kb.d/2026-08-29-cache-warms.md", "# Cache\n\n**Related:** RULE:testing\n")

    def test_impact_lists_every_citer_with_its_line(self):
        code, out, _ = self.run_tool("impact", "RULE:testing")
        self.assertEqual(code, 0)
        self.assertIn("Cited by (3):", out)
        for citer in ("scripts/check-tests.sh:2", ".claude/agents/reviewer.md:3",
                      "docs/kb.d/2026-08-29-cache-warms.md:3"):
            self.assertIn(citer, out)

    def test_impact_accepts_a_path_and_an_entry_identifier(self):
        self.assertIn("RULE:testing —", self.run_tool("impact", ".claude/rules/testing.md")[1])
        code, out, _ = self.run_tool("impact", "ISSUE-2026-08-29-cache-warms")
        self.assertEqual(code, 0)
        self.assertIn("Cites (1):", out)

    def test_impact_says_when_nothing_typed_points_here(self):
        _, out, _ = self.run_tool("impact", "RULE:security")
        self.assertIn("Prose mentions are not edges", out)

    def test_impact_on_an_unknown_artifact_exits_2_with_a_suggestion(self):
        code, _, err = self.run_tool("impact", "RULE:testin")
        self.assertEqual(code, 2)
        self.assertIn("RULE:testing", err)

    def test_coverage_separates_the_enforced_from_the_merely_stated(self):
        code, out, _ = self.run_tool("coverage")
        self.assertEqual(code, 0)
        self.assertIn("No script enforces (1): RULE:security", out)
        self.assertIn("No agent reviews (1): RULE:security", out)
        self.assertIn("SCRIPT:check-tests.sh | AGENT:reviewer", out)
        self.assertIn("Gates no agent cites (1): SCRIPT:check-tests.sh", out)

    def test_coverage_without_agents_does_not_report_missing_reviewers(self):
        os.remove(os.path.join(self.root, ".claude/agents/reviewer.md"))
        _, out, _ = self.run_tool("coverage")
        self.assertIn("No agents in this workspace yet", out)
        self.assertNotIn("No agent reviews", out)


class NoteTest(GraphTestCase):
    """`note` is what an editor is told about the file it just changed.

    It is read by an agent in the middle of a task, on every edit, so it says
    nothing unless the file is cited or carries a link that does not resolve —
    and it never fails: reporting is the gate's job.
    """

    def cite_testing_rule(self):
        self.write("scripts/check-tests.sh", "#!/bin/sh\n# Enforces: RULE:testing — test files sit beside their source\n")
        self.write("docs/kb.d/2026-03-01-flaky-clock.md", "# Flaky clock\n\n**Related:** RULE:testing\n")

    def test_a_file_nothing_cites_says_nothing(self):
        self.assertEqual(self.run_tool("note", ".claude/rules/testing.md"), (0, "", ""))

    def test_a_file_that_is_not_an_artifact_says_nothing(self):
        self.write("src/app.py", "print('hello')\n")
        self.assertEqual(self.run_tool("note", "src/app.py"), (0, "", ""))
        self.assertEqual(self.run_tool("note", "src/never-written.py"), (0, "", ""))

    def test_the_citers_of_the_file_are_listed_with_their_lines(self):
        self.cite_testing_rule()
        code, out, err = self.run_tool("note", ".claude/rules/testing.md")
        self.assertEqual((code, err), (0, ""))
        self.assertIn("RULE:testing", out)
        self.assertIn("cited by 2 file(s)", out)
        self.assertIn("scripts/check-tests.sh:2", out)
        self.assertIn("docs/kb.d/2026-03-01-flaky-clock.md:3", out)
        self.assertIn("in the same change", out)

    def test_an_absolute_path_is_the_same_file(self):
        self.cite_testing_rule()
        relative = self.run_tool("note", ".claude/rules/testing.md")
        absolute = self.run_tool("note", os.path.join(self.root, ".claude/rules/testing.md"))
        self.assertEqual(relative, absolute)

    def test_a_path_through_a_symlinked_directory_is_the_same_file(self):
        # macOS hands out /var/… paths that are /private/var/… on disk, and an
        # editor reports the first while git and the tool see the second.
        self.cite_testing_rule()
        alias = self.root + "-alias"
        os.symlink(self.root, alias)
        self.addCleanup(os.unlink, alias)
        through_link = os.path.join(alias, ".claude/rules/testing.md")
        self.assertEqual(self.run_tool("note", through_link), self.run_tool("note", ".claude/rules/testing.md"))
        code, out, _ = self.run_tool("impact", through_link)
        self.assertEqual(code, 0)
        self.assertIn("RULE:testing — .claude/rules/testing.md", out)

    def test_a_link_in_the_file_that_resolves_to_nothing_is_reported_and_is_not_a_failure(self):
        self.write(".claude/rules/testing.md", "# Testing Rules\n\n**Related:** RULE:gone\n")
        code, out, err = self.run_tool("note", ".claude/rules/testing.md")
        self.assertEqual((code, err), (0, ""))
        self.assertIn(".claude/rules/testing.md:3", out)
        self.assertIn("resolves to nothing", out)

    def test_a_broken_link_in_another_file_is_not_this_files_news(self):
        self.write(".claude/rules/security.md", "# Security Rules\n\n**Related:** RULE:gone\n")
        self.assertEqual(self.run_tool("note", ".claude/rules/testing.md"), (0, "", ""))

    def test_a_sanctioned_link_is_not_repeated_on_every_edit(self):
        self.write("docs/adr/adr-0002-retry-policy.md", "# Retry policy\n\n**Related:** RULE:retired\n")
        self.write(".graph-link-allowlist", "docs/adr/adr-0002-retry-policy.md RULE:retired  # immutable record\n")
        self.assertEqual(self.run_tool("note", "docs/adr/adr-0002-retry-policy.md"), (0, "", ""))

    def test_a_long_list_is_cut_short_and_says_how_to_see_the_rest(self):
        for number in range(11):
            self.write(f"docs/kb.d/2026-03-{number + 1:02d}-case.md", "# Case\n\n**Related:** RULE:testing\n")
        code, out, _ = self.run_tool("note", ".claude/rules/testing.md")
        self.assertEqual(code, 0)
        self.assertIn("cited by 11 file(s)", out)
        self.assertEqual(out.count("docs/kb.d/"), 8)
        self.assertIn("3 more", out)
        self.assertIn("make graph-impact NODE=RULE:testing", out)

    def test_several_files_are_each_reported(self):
        self.cite_testing_rule()
        self.write(".claude/rules/security.md", "# Security Rules\n\n**Related:** RULE:gone\n")
        code, out, _ = self.run_tool("note", ".claude/rules/testing.md", ".claude/rules/security.md")
        self.assertEqual(code, 0)
        self.assertIn("cited by 2 file(s)", out)
        self.assertIn(".claude/rules/security.md:3", out)


class ConfigTest(GraphTestCase):
    def test_no_config_is_a_failure_that_says_what_is_missing(self):
        os.remove(os.path.join(self.root, "registries.json"))
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("registries.json", err)

    def test_a_malformed_kind_is_rejected(self):
        self.config["graph"] = {"nodes": {"hook": ["x/*"]}}
        self.save_config()
        code, _, err = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("must be UPPERCASE", err)

    def test_a_repository_with_no_registries_still_resolves_file_links(self):
        self.config["registries"] = []
        self.save_config()
        self.write(".claude/rules/testing.md", "# Testing Rules\n\n**Related:** RULE:security\n")
        self.assertEqual(self.run_tool("check")[0], 0)


if __name__ == "__main__":
    unittest.main()
