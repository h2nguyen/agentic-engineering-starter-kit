#!/usr/bin/env python3
"""Unit tests for evidence_tool.py, this repository's evidence generator.

Each test builds a scratch git repository with the few things the tool reads —
a Makefile, registries, a rule, an authors list, commits and merges — and
checks what the tool measures, and that `check` recomputes it.
"""

import contextlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import evidence_tool as et  # noqa: E402

LISTED = "maintainer@example.com"
STRANGER = "stranger@example.com"
DAY = 86400


class EvidenceTestCase(unittest.TestCase):
    def setUp(self):
        self.root = os.path.realpath(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        self.previous = os.getcwd()
        self.addCleanup(os.chdir, self.previous)
        os.chdir(self.root)
        self.clock = 1_700_000_000
        self.git("init", "-q", "-b", "main")
        self.git("config", "commit.gpgsign", "false")
        self.write("registries.json", json.dumps({"id_scheme": "slug", "id_width": 3, "registries": [
            {"name": "changelog", "kind": "changelog", "fragments": "changelog.d", "output": "CHANGELOG.md"}]}))
        self.write("Makefile", "lint: registry-drift graph-links test\n\ntest:\n\ttrue\n")
        self.write("AGENTS.md", "# Agents\n\nline\n")
        self.write("CLAUDE.md", "@AGENTS.md\n")
        self.write(".claude/rules/testing.md", "# Testing\n\nrule\n")
        self.write(".agent-feedback-authors", LISTED + "\n")
        self.write("docs/adr/adr-0001-a-decision.md", "# A decision\n")
        self.write("CHANGELOG.md", "# Changelog\n\n## [Unreleased]\n\n## [1.0.0] — 2026-01-01\n")
        self.write("changelog.d/README.md", "how\n")
        self.write("scripts/tests/test_thing.py", "def test_a():\n    pass\n\ndef test_b():\n    pass\n")
        self.commit("chore: scaffold")

    # -- helpers ---------------------------------------------------------

    def git(self, *args, email=LISTED):
        env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL=email, GIT_COMMITTER_NAME="t",
                   GIT_COMMITTER_EMAIL=email, GIT_AUTHOR_DATE=f"{self.clock} +0000",
                   GIT_COMMITTER_DATE=f"{self.clock} +0000")
        done = subprocess.run(["git", "-C", self.root, *args], env=env, capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stderr)
        return done.stdout.strip()

    def write(self, rel, text):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)

    def commit(self, message, email=LISTED, days=1):
        self.clock += days * DAY
        self.git("add", "-A", email=email)
        self.git("commit", "-q", "--allow-empty", "-m", message, email=email)
        return self.git("rev-parse", "HEAD")

    def merged_pr(self, number, title, files):
        self.git("checkout", "-q", "-b", f"pr-{number}")
        for rel, text in files.items():
            self.write(rel, text)
        self.commit(title)
        self.git("checkout", "-q", "main")
        self.clock += DAY
        self.git("merge", "-q", "--no-ff", f"pr-{number}", "-m", f"Merge pull request #{number} from x/y\n\n{title}")

    def run_tool(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = et.main(list(args))
        return code, out.getvalue() + err.getvalue()

    def measure(self):
        return et.measure(self.root, self.git("rev-parse", "HEAD"))

    def evidence(self):
        with open(os.path.join(self.root, "docs", "EVIDENCE.md"), encoding="utf-8") as fh:
            return fh.read()


class Measures(EvidenceTestCase):
    def test_the_tree_is_counted_as_it_is_at_the_commit(self):
        data = self.measure()
        self.assertEqual(data["gates"], ["registry-drift", "graph-links"])
        self.assertEqual(data["suites"], 1)
        self.assertEqual(data["python_tests"], 2)
        self.assertEqual(data["decision_records"], 1)
        self.assertEqual(data["releases"], 1)
        self.assertEqual(data["unreleased_fragments"], 0)
        # AGENTS.md (3) + CLAUDE.md (1) + the one rule (3)
        self.assertEqual(data["always_loaded_lines"], 7)

    def test_a_linked_rule_is_counted_from_gits_tree_not_from_the_file_system(self):
        # A link is a link in git's tree on every platform and under every
        # Python; what a checkout or an unpacked archive makes of it is not.
        self.write("kit/rules/security.md", "# Security\n\none\ntwo\n")
        os.makedirs(os.path.join(self.root, ".claude", "skills"), exist_ok=True)
        self.write("kit/skills/semver/SKILL.md", "# Semver\n")
        os.symlink("../../kit/rules/security.md", os.path.join(self.root, ".claude", "rules", "security.md"))
        os.symlink("../../kit/skills/semver", os.path.join(self.root, ".claude", "skills", "semver"))
        self.commit("feat: link a rule and a skill")
        data = self.measure()
        self.assertEqual(data["applied_by_reference"], 2)
        self.assertEqual(data["always_loaded_lines"], 7 + 4)   # the linked rule is read through its link
        links = et.links_at(self.root, self.git("rev-parse", "HEAD"))
        self.assertEqual(links[".claude/rules/security.md"], "kit/rules/security.md")

    def test_a_merged_pull_request_is_judged_by_what_it_carried(self):
        self.merged_pr(1, "fix(tool): a defect", {"changelog.d/2026-01-02-a.md": "# a\n",
                                                  "scripts/tests/test_more.py": "def test_c():\n    pass\n"})
        self.merged_pr(2, "feat: a feature with nothing beside it", {"src/app.py": "x = 1\n"})
        self.merged_pr(3, "docs: words only", {"README.md": "words\n"})
        data = self.measure()
        self.assertEqual(data["merged_prs"], 3)
        self.assertEqual(data["change_prs"], 2)            # feat and fix; docs is not a change to behaviour
        self.assertEqual(data["change_prs_with_fragment"], 1)
        self.assertEqual(data["change_prs_with_tests"], 1)

    def test_feedback_is_acted_on_when_its_artifact_changes_afterwards(self):
        self.commit("fix: x\n\nAgent-Feedback: RULE:testing — mocked the database, because the fake hid a bug")
        self.commit("fix: y\n\nAgent-Feedback: RULE:testing — never acted on")
        data = self.measure()
        self.assertEqual((data["feedback_points"], data["feedback_acted_on"]), (2, 0))
        self.write(".claude/rules/testing.md", "# Testing\n\nrule, sharpened\n")
        self.commit("docs(rule): say why", days=3)
        data = self.measure()
        self.assertEqual(data["feedback_points"], 2)
        self.assertEqual(data["feedback_acted_on"], 2)
        self.assertEqual(data["feedback_days_median"], 3.5)   # 4 days and 3 days after the two points

    def test_an_unlisted_authors_feedback_is_counted_and_never_quoted(self):
        self.commit("feat: z\n\nAgent-Feedback: RULE:testing — SECRET stranger text", email=STRANGER)
        data = self.measure()
        self.assertEqual((data["feedback_points"], data["feedback_excluded"]), (0, 1))
        self.assertEqual(self.run_tool("generate")[0], 0)
        self.assertNotIn("SECRET", self.evidence())

    def test_coach_cycles_are_read_from_the_workspace_changelog(self):
        self.write(".claude/workspace-changelog/README.md", "format\n")
        self.write(".claude/workspace-changelog/2026-01-03-setup.md", "# 2026-01-03 — setup\n")
        self.write(".claude/workspace-changelog/2026-01-09-coach-escapes.md",
                   "# 2026-01-09 — agent-coach cycle\n\n| 1 | abc | x | approved | — |\n| 2 | — | y | rejected | — |\n")
        self.commit("docs: workspace runs")
        data = self.measure()
        self.assertEqual((data["workspace_runs"], data["coach_cycles"]), (2, 1))
        self.assertEqual((data["proposals_approved"], data["proposals_rejected"]), (1, 1))


class GenerateAndCheck(EvidenceTestCase):
    def test_check_recomputes_what_generate_wrote(self):
        self.assertEqual(self.run_tool("generate")[0], 0)
        self.commit("docs: evidence")
        code, out = self.run_tool("check")
        self.assertEqual(code, 0, out)
        self.assertIn("OK:", out)

    def test_a_number_edited_by_hand_fails_the_check(self):
        self.run_tool("generate")
        text = self.evidence()
        self.assertIn("| Decision records | 1 |", text)
        self.write("docs/EVIDENCE.md", text.replace("| Decision records | 1 |", "| Decision records | 12 |"))
        self.commit("docs: a better-looking number")
        code, out = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("make evidence", out)
        # The failure shows the lines that differ: which number, and what it should be.
        self.assertIn("-| Decision records | 12 |", out)
        self.assertIn("+| Decision records | 1 |", out)

    def test_later_commits_leave_it_stale_but_true(self):
        self.run_tool("generate")
        self.commit("docs: evidence")
        self.write("docs/adr/adr-0002-another.md", "# Another\n")
        self.commit("docs: a second decision")
        code, out = self.run_tool("check")
        self.assertEqual(code, 0, out)
        self.assertIn("2 commit(s) behind", out)

    def test_evidence_computed_at_a_commit_that_is_not_in_the_history_fails(self):
        self.run_tool("generate")
        text = self.evidence()
        stamped = et.stamped_commit(text)
        self.write("docs/EVIDENCE.md", text.replace(stamped, "0" * 40))
        self.commit("docs: evidence from nowhere")
        code, out = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("not in this repository's history", out)

    def test_with_no_evidence_file_the_check_says_how_to_make_one(self):
        code, out = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("make evidence", out)


if __name__ == "__main__":
    unittest.main()
