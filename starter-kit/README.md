# Agentic Engineering Starter Kit

Ready-to-copy templates for bootstrapping the agentic engineering setup described in
[`../AGENTIC-ENGINEERING-GUIDE.md`](../AGENTIC-ENGINEERING-GUIDE.md). The guide explains
*why* each artifact exists and how to grow the setup; this kit is the *what to copy*.

The kit is **tool-agnostic**: the templates' content works with any agentic coding
tool, and `bootstrap.sh` installs them to the file locations your tool expects
(Claude Code, `AGENTS.md`-convention tools, Cursor, GitHub Copilot — guide § 3.10).

> Nothing in this directory is auto-loaded by any agentic tool — it only
> becomes active once installed to the canonical paths in a target repo
> (via `bootstrap.sh` or manual copy).

## Requirements

`git`, `make`, `bash` 3.2 or newer, Python 3.9 or newer (standard library
only). No packages, no network access, no per-clone `git config`.

Python may be called `python3`, `python` or `py` on your machine. Everything
the kit runs itself — the make targets, the gates, the tests, the Claude Code
hook — starts it through `scripts/python.sh`, which tries those names in that
order and uses the first that really is Python 3.9 or newer. The commands this
page and the installed rules, skills and READMEs give you to type are written
the same way, as `./scripts/python.sh scripts/…`. `make lint PYTHON=/path/to/python`
names the interpreter yourself. On Windows, run the kit from Git Bash (with
`make` installed) or WSL.

## Quick start (recommended)

```bash
# from a checkout of this kit — nothing but the installed files lands in your repo
./starter-kit/bootstrap.sh --target /path/to/your-repo                 # detects your tool; asks if it finds none, or several
./starter-kit/bootstrap.sh --target /path/to/your-repo --tool claude   # or name it explicitly
./starter-kit/bootstrap.sh --target /path/to/your-repo --with-meta     # later, at Level 4: + self-improvement loop
```

The kit is an installer, not a dependency: nothing it installs refers back to
it, and the templates a workspace grows from are installed too
(`docs/agent-templates/`). If you copied `starter-kit/` into the repository to
run it from there, delete the copy afterwards instead of committing it. Keep a
checkout of the kit only for `--with-meta` and the common-skills catalog.

**Zero-copy alternative:** paste [`SETUP-PROMPT.md`](SETUP-PROMPT.md) into a
fresh session of your AI coding agent at the target repo's root — the prompt
drives the whole setup (detect tool → mine the repo → install → verify), uses
this kit when present, and carries fallback specs when it isn't. Repos that
**already have** an agentic workspace are routed to a harmonize track:
preserve-by-default, evidence-based keep/enhance/fix/relocate classification,
lossless-first remediation, approval-gated changes — existing working
conventions beat the blueprint's defaults (guide § 4.4).

`bootstrap.sh` detects which agentic tool the repo uses (`.claude`/`CLAUDE.md`,
`.cursor`, `.github/copilot-instructions.md`, `AGENTS.md`). When it finds none,
or the files of more than one, it asks which — and where there is no terminal
to ask at (an agent, CI) it stops before writing anything and says to pass
`--tool`. It never picks one of several for you. It then installs the constitution + the universal rule files (working
principles, documentation, comments & annotations, versioning & changelog,
shared registries) + the
knowledge-base and changelog skeletons in their fragment layout + the
`.gitattributes`, `Makefile` and CI workflow that make the registry gates and
the typed-link gate run
(+ the prompt-enhancer, semver, registry-entry, registry-conflict-triage and
rule-load-check skills on Claude Code, and the hook that hands the typed links to the agent —
[below](#the-workspace-graph-hook-claude-code)) to that tool's locations, and
never overwrites existing files. Then: fill in the constitution's `<placeholders>` and
`project-annotations.md`, the project's half of the comments-and-annotations rule
([how](#adopting-the-comments-and-annotations-rule)), run `make constitution`
until it stops naming placeholders and links to files that do not exist, run
`make lint` to confirm the gates pass, enable further common skills from
`skills/common-catalog.md`, and commit.

## Contents → target locations (manual path)

| Kit file | Copy to (Claude Code shown; bootstrap maps other tools) | Then |
|---|---|---|
| `SETUP-PROMPT.md` | — (paste into an agent session at the target repo) | The agent drives the whole setup |
| `bootstrap.sh` | — (run it, don't copy it into the repo) | `--help` for options |
| `upgrade-rules.sh` | — (run it from the kit, in upgrade step 3) | Lists the rules whose text differs from the kit's, and takes the kit's text for the ones you name, keeping a `paths:` header |
| `kit-status.sh` | — (run it from the kit, or through `make kit-status KIT=<checkout>`) | Which kit your repository records, what is newer, the changelog entries in between, which of the kit's files differ; `--record` is the last upgrade step — [Which kit is installed](#which-kit-is-installed) |
| — (written by the installer) | `.starter-kit-version` | The kit's release, its commit and the tool. First install only; you never edit it |
| `constitution.md.template` | `CLAUDE.md` / `AGENTS.md` / tool equivalent | Fill in every `<placeholder>` |
| `rules/working-principles.md` | `.claude/rules/working-principles.md` | Use as-is (project-agnostic, incl. plan-first/QRSPI) |
| `rules/documentation.md` | `.claude/rules/documentation.md` | Use as-is (docs-with-the-change, ADR format (Michael Nygard), where rationale lives) |
| `rules/comments-and-annotations.md` | `.claude/rules/comments-and-annotations.md` | Use as-is. Its pointers and your project's own marker shapes are resolved in the next file |
| `rules/project-annotations.md.template` | `.claude/rules/project-annotations.md` | Yours: fill in every `<fill in: …>` — see [Adopting the comments-and-annotations rule](#adopting-the-comments-and-annotations-rule). First installs only; an upgrade creates it in step 3 |
| `rules/reference/` | `docs/rule-reference/` | The worked examples of the comments rule and the gotchas of the registries rule — read on demand, never loaded. Same location for every tool |
| `rules/versioning-and-changelog.md` | `.claude/rules/versioning-and-changelog.md` | Use as-is (SemVer + Keep-a-Changelog discipline) |
| `rules/shared-registries.md` | `.claude/rules/shared-registries.md` | Use as-is (fragment layout, identifier schemes, merge behaviour). On Claude Code the installer binds it to the registry paths — [Load classes](#load-classes-of-the-rules-claude-code) |
| `registries.json.template` | `registries.json` | Reference only — bootstrap runs `registry_tool.py init`, which writes the file from the conventions your repo already has |
| `registry.mk` | `registry.mk` | The registry and graph targets; `include registry.mk` from an existing Makefile and add the gates to your `lint` prerequisites |
| `gitattributes.template` | `.gitattributes` | Use as-is — built-in `merge=union` only, so nothing needs `git config`. An existing file gets the block appended under a marker, idempotently |
| `CHANGELOG.md.template` | `CHANGELOG.md` | Skip if you already have one — run `registry_tool.py adopt --registry changelog` on it instead |
| `changelog.d/` | `changelog.d/` | One fragment per change; categories are `## ` headings inside it |
| `docs/DEBUGGING-KNOWLEDGE-BASE.d/` | `docs/DEBUGGING-KNOWLEDGE-BASE.d/` | One file per entry — the authored source of the KB |
| `Makefile.template` | `Makefile` | Greenfield only — includes `registry.mk`. An existing Makefile is never touched; bootstrap prints the two lines to add, and says whether `make lint` reaches the gates yet (run it again after the edit to confirm) |
| `ci/lint.yml.template` | `.github/workflows/lint.yml` | Adapt the runner; keep the step that invokes the aggregate target |
| `ci/agent-feedback.yml.template` | `.github/workflows/agent-feedback.yml` | **Opt-in** — only with `bootstrap.sh --with-coach-schedule`, or a yes to the installer's question. Every Monday it posts the week's `Agent-Feedback:` lines as a digest on an issue labelled `agent-feedback`. With an `ANTHROPIC_API_KEY` secret and the Claude GitHub App, the coach's proposals follow on the same issue. It reads code and writes to issues only: no push, no branch, no pull request |
| `ci/kit-upgrade-notice.yml.template` | `.github/workflows/kit-upgrade-notice.yml` | **Opt-in** — only with `bootstrap.sh --with-upgrade-notice`, or a yes to the installer's question. Every Monday it lists the kit's release tags and opens an issue labelled `kit-upgrade` when one is newer than `.starter-kit-version` records. The only part of the kit that uses the network; it downloads no code and writes to issues only |
| `registry-id-duplicate-allowlist.template` | `.registry-id-duplicate-allowlist` | Starts empty; entries name a filename **pair** |
| `ci-lint-coverage-allowlist.template` | `.ci-lint-coverage-allowlist` | Starts empty; shrink-only |
| `scripts/python.sh` | `scripts/python.sh` | Starts Python under whatever name the machine gives it (`python3`, `python`, `py -3`); every make target, gate, test and hook of the kit goes through it |
| `scripts/registry_tool.py` | `scripts/registry_tool.py` | Ready to run — `new` / `generate` / `check` / `release` / `adopt` (brownfield: moves an existing artifact into fragments) |
| `scripts/check-registry-drift.sh` | `scripts/check-registry-drift.sh` | Chained into `make lint`; the gate that makes `merge=union` safe |
| `scripts/check-registry-ids.sh` | `scripts/check-registry-ids.sh` | Chained into `make lint` |
| `scripts/check-ci-lint-coverage.sh` | `scripts/check-ci-lint-coverage.sh` | Chained into `make lint`; proves the other gates reach CI |
| `scripts/graph_tool.py` | `scripts/graph_tool.py` | Ready to run — `check` (the gate), `impact <KIND:name>` (what cites an artifact, and what it cites), `coverage` (which rules a script enforces and an agent reviews). Rebuilt from the files on every run, so there is nothing to regenerate |
| `scripts/feedback_tool.py` | `scripts/feedback_tool.py` | `make agent-feedback` — every `Agent-Feedback: <token> — <what and why>` line in the commit history (and, with `FROM=<file>`, in a JSON export of comments), grouped by the artifact it names, as JSON. A report for the next change to that artifact, never a gate. The convention is in the documentation rule § Feedback to an agent |
| `agent-feedback-authors.template` | `.agent-feedback-authors` | Whose feedback counts: one commit email or comment login per line. **Ships naming nobody**, and the installer says so until you fill it in — until then every line is counted, but no one's text reaches the report |
| `scripts/check-graph-links.sh` | `scripts/check-graph-links.sh` | Chained into `make lint`; fails when a typed link names an artifact that does not exist (guide § 3.12) |
| `scripts/check-constitution.sh` | `scripts/check-constitution.sh` | `make constitution` — fails while the constitution links to a file that does not exist, or it or `project-annotations.md` still has a template `<placeholder>` in it. **Not** chained into `make lint`: run it after filling the constitution in and after editing it, or add `constitution` to your `lint:` line to hold it on every pull request ([below](#the-constitution-check)) |
| `scripts/tests/` | `scripts/tests/` | Unit tests, the coverage-gate and constitution-check tests, and the parallel-merge and typed-link acceptance tests — the target `registry-test`, which the installed Makefile chains into `make lint`; with a Makefile of your own, add `registry-test` to its `lint:` line to run them. The brownfield-adoption, bootstrap re-run, upgrade, kit-status and hook suites test the installer, the upgrade and the Claude Code hook, so they stay in the kit |
| `skills/registry-entry/SKILL.md` | `.claude/skills/registry-entry/SKILL.md` | Authoring a registry entry (installed by bootstrap on Claude Code) |
| `skills/registry-conflict-triage/SKILL.md` | `.claude/skills/registry-conflict-triage/SKILL.md` | Escalation only — resolving a registry conflict |
| `skills/rule-load-check/SKILL.md` | `.claude/skills/rule-load-check/SKILL.md` | Which rules Claude Code really loaded, and when each arrives. Run it in a new session after installing, upgrading or editing a rule or its header |
| `rules/_rule-template.md` | `docs/agent-templates/_rule-template.md` | Template — copy per new domain rule file (installed by bootstrap; never loaded) |
| `skills/common-catalog.md` | — (reference doc) | Enable the listed generic skills at setup |
| `skills/prompt-enhancer/SKILL.md` | `.claude/skills/prompt-enhancer/SKILL.md` | Ready-to-use helper skill (installed by bootstrap on Claude Code) |
| `skills/semver/` | `.claude/skills/semver/` | Ready-to-use SemVer decision skill incl. validator + tests (installed by bootstrap on Claude Code; upstream: h2nguyen/semver-skill) |
| `skills/_template/SKILL.md` | `docs/agent-templates/_skill-template.md` | Template — copy to `.claude/skills/<name>/SKILL.md` per new skill, or use as a playbook skeleton on other tools |
| `agents/_agent-template.md` | `docs/agent-templates/_agent-template.md` | Template — copy to `.claude/agents/<name>.md` per new reviewer; it carries the cross-cutting checks every reviewer runs |
| `agents/agent-coach.md` | `.claude/agents/agent-coach.md` | Level-4 meta-agent — installed via `bootstrap.sh --with-meta` |
| `skills/ai-engineering-workspace-audit/` | `.claude/skills/ai-engineering-workspace-audit/` | Level-4 audit skill — installed via `--with-meta` |
| `commands/ai-engineering-workspace-audit.md` | `.claude/commands/ai-engineering-workspace-audit.md` | Thin `/command` entry for the audit skill — via `--with-meta` |
| `skills/workspace-graph/SKILL.md` | `.claude/skills/workspace-graph/SKILL.md` | Level-4 skill — impact-before-edit and coverage over the typed links, for the audit and the coach — via `--with-meta` |
| `workspace-changelog/README.md` | `.claude/workspace-changelog/README.md` | The workspace's own history, one file per setup pass, audit or coach cycle; the README has the entry format — via `--with-meta`. An install with a single `WORKSPACE_CHANGELOG.md` keeps it as the archive |
| `commands/_command-template.md` | `docs/agent-templates/_command-template.md` | Template — copy to `.claude/commands/<name>.md` per new command (Claude Code only) |
| `settings.json.template` | `.claude/settings.json` | Registers the workspace-graph hook for its two events ([below](#the-workspace-graph-hook-claude-code)) |
| `hooks/workspace-graph.py` | `.claude/hooks/workspace-graph.py` | Ready to use — after an edit it tells the agent who cites the file; at the end of a turn it holds the turn once if a typed link broke. See [The workspace-graph hook](#the-workspace-graph-hook-claude-code) |
| `hooks/session-start.sh.template` | `docs/agent-templates/session-start.sh.template` | Template (Claude Code) — nothing runs it. Copy it to `.claude/hooks/session-start.sh` when sessions need environment setup; its header has the steps and the `settings.json` entry |
| `scripts/check-kb-shape.sh` | `scripts/check-kb-shape.sh` | Ready to run; already chained into the installed `make lint` (guards the KB's graph-ready shape) |
| `scripts/check-convention.sh.template` | `docs/agent-templates/check-convention.sh.template` | Template — copy to `scripts/check-<convention>.sh`, `chmod +x`, wire into your lint target |
| `docs/DEBUGGING-KNOWLEDGE-BASE.md` | `docs/DEBUGGING-KNOWLEDGE-BASE.md` | Generated — start empty; add the first entry at the first >30-min bug |

## Bootstrap order (Level 1 — guide § 4.2)

1. Run `bootstrap.sh` (or copy manually per the table above).
2. Fill in the constitution: identity, stack table (including the infrastructure,
   auth, and messaging/integration rows), commands, and the 3–5 rules you already
   know are non-negotiable. Then `project-annotations.md`, the project's half
   of the comments-and-annotations rule —
   [how](#adopting-the-comments-and-annotations-rule).
3. Run `make constitution`. It lists, by line, every template placeholder
   still in the constitution or in `project-annotations.md`, and every link
   in the constitution to a file that does not exist —
   the template links two example rules, `testing.md` and `security.md`, that
   no install has. It passes when step 2 is really done; `make lint` does not
   look at either.
4. Run `make lint`. All five gates should pass on a fresh install with no
   `git config` and no other setup — that is the check that the registry layer
   actually landed rather than merely being present.
5. Enable the generic skills worth having from day one — see
   [`skills/common-catalog.md`](skills/common-catalog.md) (semver decisions,
   architecture review, architecture docs).
6. Commit. When the branch is pushed and its pull request is open, look at
   the run (`gh run list --workflow lint.yml --limit 5`): it has to complete
   with success. A workflow file is not a run — none at all, or one that ends
   within seconds before any step, checked nothing, and every local gate
   stays green meanwhile. Then make `lint` a required status check on the
   default branch. With both done, the setup is live.
7. Grow by signal, not speculation: rules when you repeat an instruction, skills
   when you repeat a workflow, agents when you repeat a review comment,
   enforcement scripts when a documented rule gets violated anyway. See the
   guide § 4–§ 5.

## Upgrading an existing install

`bootstrap.sh` never overwrites a file. Re-running it from a newer kit
therefore **adds** what is new and leaves every file you already have exactly
as it is — including the kit's own scripts. Moving to a newer kit is these
steps, in order, on a branch (`chore/upgrade-agentic-kit`, say), from the root
of your repository. `KIT` is a checkout of the newer kit.

Before you start, ask the newer kit what the upgrade is — which kit your
repository records, the changelog entries between that one and this one with
the breaking ones first, and which of the kit's files in your repository are
the older kit's and which you changed
([Which kit is installed](#which-kit-is-installed)). From the root of your
repository: `"$KIT"/starter-kit/kit-status.sh`.

The steps themselves do not depend on that answer: each compares your files
with the kit's, whichever version you started from.

1. **Add what is new.** Pass `--with-meta` if your repository has the Level-4
   layer (`agent-coach`, the workspace-audit skill) or keeps a workspace
   changelog, `--with-coach-schedule` to add the weekly feedback digest, and
   `--with-upgrade-notice` to add the weekly check for a newer kit.
   ```bash
   "$KIT"/starter-kit/bootstrap.sh --target .
   ```
   Its "Installed" list is what the newer kit added — and anything of the
   kit's you had deleted, which the installer cannot tell from new. Delete
   such a file again and list it in `.starter-kit-declined`
   ([Declining what the kit installs](#declining-what-the-kit-installs)), and
   it stays out from then on. Everything under "Skipped" was left as it was. If you keep your own Makefile, it also names
   any gate your `lint` target does not reach yet (step 5).

   If your repository carries the files of more than one agent tool — a
   `CLAUDE.md` beside an `AGENTS.md`, `.claude/` beside `.cursor/` — the
   installer stops before writing and lists them: add `--tool <the one this
   kit was installed for>` to the command. Earlier versions picked one
   silently.
2. **Replace the files the kit owns.** They hold nothing of your project, so
   copying is safe — unless you changed one yourself. The first command lists
   the commits that touched them; a file one of your own commits changed is
   merged by hand instead of copied.
   ```bash
   git log --oneline -- scripts registry.mk
   cp "$KIT"/starter-kit/scripts/*.py "$KIT"/starter-kit/scripts/check-*.sh "$KIT"/starter-kit/scripts/python.sh scripts/
   cp "$KIT"/starter-kit/scripts/tests/* scripts/tests/
   cp "$KIT"/starter-kit/registry.mk registry.mk
   cp "$KIT"/starter-kit/docs/DEBUGGING-KNOWLEDGE-BASE.d/_template.md docs/DEBUGGING-KNOWLEDGE-BASE.d/
   rm -f scripts/tests/test-bootstrap-rerun.sh scripts/tests/test-brownfield-adoption.sh scripts/tests/test-upgrade.sh scripts/tests/test-graph-hooks.sh scripts/tests/test-kit-status.sh
   ```
   The last line removes the five suites that test the installer, the upgrade
   and the Claude Code hook; they stay in the kit and are not run from your
   repository. Your own `check-*.sh` scripts and tests are not touched: only
   files the kit has are copied.

   The templates in `docs/agent-templates/` are the kit's too. To refresh
   them, delete the directory and run step 1 again — the installer puts them
   back, pointing at the rule location of your tool.

   On Claude Code, the kit's skills, its `agent-coach`, its audit command and
   the workspace-graph hook are also its own. List the ones that differ, then
   copy each one that no commit of yours has changed (`git log --oneline --
   <file>` again):
   ```bash
   diff -q "$KIT"/starter-kit/hooks/workspace-graph.py .claude/hooks/workspace-graph.py
   diff -rq "$KIT"/starter-kit/skills .claude/skills | grep '^Files'
   diff -q "$KIT"/starter-kit/agents/agent-coach.md .claude/agents/agent-coach.md
   diff -q "$KIT"/starter-kit/commands/ai-engineering-workspace-audit.md .claude/commands/ai-engineering-workspace-audit.md
   ```
3. **Update the rule files.** List the rules whose text differs from the
   kit's:
   ```bash
   "$KIT"/starter-kit/upgrade-rules.sh
   diff -rq "$KIT"/starter-kit/rules/reference docs/rule-reference | grep '^Files'
   ```
   `upgrade-rules.sh` finds your rules directory (`.claude/rules/`, or
   `docs/agent-rules/` on the other tools) and prints `same`, `differs` or
   `missing` for each rule the kit ships. On Claude Code a rule may carry a
   `paths:` header ([Load classes](#load-classes-of-the-rules-claude-code));
   the comparison is of the text under it, so a rule is not reported for a
   header you or the installer gave it, and taking the kit's text keeps it.
   (In the commands below, `docs/agent-rules/` takes the place of
   `.claude/rules/` on the other tools.)
   - **`comments-and-annotations.md`: move your rows out, once — or keep
     merging it by hand.** Kits up to 3.0.1 had you fill a table and four
     pointers inside this rule, so it could never be copied. Your half now
     has a file of its own, `project-annotations.md`, and the rule is used as
     shipped. The installer does not put that file beside a comments rule
     that was already there — unfilled, it would be loaded into every
     session.

     *The move.* If you already have a `project-annotations.md`, there is
     nothing to move: the file is yours and no step replaces it. Otherwise
     create it — the command does nothing where the file exists:
     ```bash
     [ -e .claude/rules/project-annotations.md ] || cp "$KIT"/starter-kit/rules/project-annotations.md.template .claude/rules/project-annotations.md
     ```
     Then look at what you had filled in:
     ```bash
     diff -u "$KIT"/starter-kit/rules/comments-and-annotations.md .claude/rules/comments-and-annotations.md
     ```
     Among the lines the kit itself changed, the diff shows your rows and
     pointer values: put each into `project-annotations.md`
     ([how](#adopting-the-comments-and-annotations-rule)), re-reading them as
     you go — they describe the project as it was on the day of the install.
     Then take the kit's rule
     (`"$KIT"/starter-kit/upgrade-rules.sh --apply comments-and-annotations`)
     and copy its reference file over
     `docs/rule-reference/comments-and-annotations.md`; if you had filled
     pointers into the reference, they are in your file now. Run
     `make constitution`: it names every `<fill in: …>` still open. From the
     next upgrade on, this rule is taken like the others. A line for
     `project-annotations.md` in your constitution's rule index helps a
     reader find it and is yours to add or leave: the rule names the file
     either way.

     *Not moving.* Your filled-in rule keeps working. Merge the kit's changes
     into it by hand, as before, at this upgrade and the next; `--apply`
     would reset your rows, which is why it replaces only rules you name.
   - **The other rules are used as shipped.** For each one that differs and
     that no commit of yours has changed (`git log --oneline -- <file>`),
     take the kit's text — naming them, because nothing is replaced that you
     did not name:
     ```bash
     "$KIT"/starter-kit/upgrade-rules.sh --apply <rule> [<rule>…]
     ```
     `<rule>` is a rule's name without `.md`, as the listing printed it. Leave
     out every rule you edited — `documentation` and
     `versioning-and-changelog` invite you to add your own locations — and
     merge those by hand: `--apply` replaces the whole text of a rule you
     name, and only git brings the old one back.
4. **Leave what is yours.** The constitution (`CLAUDE.md`, `AGENTS.md` or
   `.github/copilot-instructions.md`), `Makefile`, `registries.json`, the CI
   workflow, the workspace changelog, and every changelog fragment,
   knowledge-base entry and decision record are never replaced. Some of yours
   started as kit skeletons, and a fix to a skeleton reaches you only by
   hand — compare them and take what applies:
   ```bash
   diff -u changelog.d/README.md "$KIT"/starter-kit/changelog.d/README.md
   diff -u docs/DEBUGGING-KNOWLEDGE-BASE.d/README.md "$KIT"/starter-kit/docs/DEBUGGING-KNOWLEDGE-BASE.d/README.md
   diff -u .claude/hooks/session-start.sh "$KIT"/starter-kit/hooks/session-start.sh.template
   diff -u .claude/settings.json "$KIT"/starter-kit/settings.json.template
   diff -u .claude/workspace-changelog/README.md "$KIT"/starter-kit/workspace-changelog/README.md
   ```
   (The workspace-changelog README only with the Level-4 layer, and under
   `docs/` on the other tools. The two before it on Claude Code only, and the
   hook only if your install has one: kits up to 3.0.1 installed and registered that skeleton, and it is
   yours to keep, fill in or remove together with its `SessionStart` entry.
   Newer kits ship it as a template in `docs/agent-templates/` and register
   nothing.) Three more came from a kit template:
   the constitution, and the hand-written preamble above the generated region
   of `CHANGELOG.md` and of the knowledge base. A change to one of those is
   named in the kit's changelog.
5. **Chain any new gate into your lint target.** If you keep your own
   Makefile, its `lint:` line must name every gate the kit installed —
   `registry-drift registry-ids kb-shape graph-links ci-lint-coverage`. The
   coverage gate holds you to all five now; it used to check three, so a
   `lint:` line without `kb-shape` or `ci-lint-coverage` passed and no longer
   does. `constitution` is the one target `registry.mk` defines that is yours
   to add or leave ([The constitution check](#the-constitution-check)).
6. **Run `make lint` and fix what it reports.** Each failure names the file,
   the line and the fix. If your repository had no `scripts/graph_tool.py`
   before step 1, expect one kind: a check script whose header still reads
   `# Enforces: <rule> — see <file>` must name its rule as a token,
   `# Enforces: RULE:<name> — <what it checks>`.
7. **Record the kit you are now on.** The installer wrote
   `.starter-kit-version` on your first install and has not touched it since:
   step 1 adds files and upgrades none. This command does, once the files
   bear it out:
   ```bash
   "$KIT"/starter-kit/kit-status.sh --record
   ```
   It refuses, and names the files, while one of the kit's files is still the
   older kit's or is missing without being listed in `.starter-kit-declined`.
   The templates in `docs/agent-templates/` count too; step 2 says how to
   refresh them. A file you changed yourself is accepted and named, and stays listed as
   "changed here" in every later report. An install from before kit 3.1.0 has
   no record; this step gives it one.

`scripts/tests/test-upgrade.sh` in the kit runs these steps as written
here — against an install shaped like 1.x and, where the kit's history has the
tag, against a real 1.1.0 install — and checks that what is yours comes out
byte for byte as it went in.

Commit the upgrade on its branch, like any other change. It needs no
changelog fragment — your changelog describes your project, not its agent
workspace — and, where you keep one, a file in the workspace changelog.

## Which kit is installed

A first install writes `.starter-kit-version` at the root of your repository:

```text
version: 3.1.0
commit: 4f0c…        the kit commit the files came from
tool: claude
```

Two things write it: the installer, on a first install, and
`kit-status.sh --record`, as the last step of an upgrade. A re-run of the
installer never changes it, and you do not edit it. It is a claim, and the
report checks it against the files every time:

```bash
make kit-status                                   # what the record says
make kit-status KIT=../agentic-engineering-starter-kit   # the report, against that checkout
```

The second form runs the kit's `starter-kit/kit-status.sh`, which stays in the
kit like the installer. It rebuilds what the recorded kit and the kit in
`KIT` would each install, with each kit's own installer, and compares your
copies of the kit's files with both. It prints:

| Part | What it says |
|---|---|
| `Recorded` / `Available` | The release and commit your repository records, and the ones of the checkout in `KIT` |
| `Verdict` | Up to date; a newer kit is available; a **partial** upgrade — some files already the newer kit's, the record rightly still the older one; or the checkout is older than the record |
| What changed in between | The kit's changelog entries after the recorded release, per release: **BREAKING** entries first, then Added, Changed, Fixed |
| The kit's files | `older kit's` — untouched since the record, replaced by upgrade steps 2 and 3; `changed here` — neither kit's text, yours to merge or keep; `missing`, `declined`, `retired` |

It uses no network: "available" is whatever the checkout in `KIT` has, so
`git -C "$KIT" pull` is how it learns of a newer release.

**No record.** An install from before kit 3.1.0 has none. The report says so,
names the release whose files yours match best, and prints the command that
records it (`kit-status.sh --record --as v3.0.1`). Or finish an upgrade first:
step 7 records the kit you end up on.

**A record the files contradict** — edited by hand, or the files reverted —
is reported as one that does not hold, with the release the files match.

**Being told about a newer release.** `bootstrap.sh --with-upgrade-notice`
(or yes to the installer's question at a terminal) installs
`.github/workflows/kit-upgrade-notice.yml`. Once a week it lists the kit's
release tags over the network and, when one is newer than the record, opens an
issue labelled `kit-upgrade`. It downloads no code of the kit's and can write
to issues only. It is the one part of the kit that uses the network, so it is
never installed unasked; list its path in `.starter-kit-declined` and the
installer stops asking. If you install from a fork, set `KIT_REPOSITORY` in
the workflow.

## Load classes of the rules (Claude Code)

Claude Code loads a rule file with no header into every session. A rule whose
file opens with a `paths:` header is loaded when a file matching one of its
patterns is read or edited. Three of the kit's rules are about particular
files, so the installer writes that header — on Claude Code, and onto rules
it installs in that run, never onto a file that was already there:

| Rule | Loads | Bound to |
|---|---|---|
| `working-principles`, `documentation`, `project-annotations` | every session | — |
| `shared-registries` | on a registry file | every fragment directory and artifact `registries.json` declared when the rule was installed, and `registries.json`, `registry.mk`, `.gitattributes`, `.registry-id-duplicate-allowlist`. Add a line when you declare a new registry |
| `versioning-and-changelog` | with `--source-paths`: on source and changelog files. Without: every session | your source globs, and the changelog's fragment directory and artifact |
| `comments-and-annotations` | with `--source-paths`: on source and build files. Without: every session | your source globs, and `.github/**`, `.claude/hooks/**`, `Makefile`, `registry.mk` |

```bash
./starter-kit/bootstrap.sh --target /path/to/your-repo --tool claude --source-paths 'src/**,scripts/**'
```

Where a project's source is, the installer does not guess: without
`--source-paths` the last two load into every session. One glob per comma,
relative to the repository root; write a brace alternative out as two globs
and a directory as `src/**`. The flag binds rules the run installs: on a
re-run the rules are already yours, and the installer says which it left
unbound.

The header is yours once written. This is what one looks like — add it by
hand to bind a rule later, or to bring an existing install to these classes:

```markdown
---
paths:
  - "src/**"
  - "changelog.d/**"
  - "CHANGELOG.md"
---

# Versioning & Changelog Rules
```

Three things to know before relying on it:

- **A bound rule arrives after the first matching access**, not before it.
  What holds until then is the rule's one line in the constitution's
  Non-Negotiable Rules table, so keep that line for every rule you bind.
- **Binding the comments rule narrows when its full text is in context, not
  where it applies.** The rule covers documents and prompts as well as
  source. In a session that touches only documents the constitution's line is
  what the agent has; if your project's main work product is prose, bind the
  rule to those paths too, or leave it unbound.
- **A header Claude Code cannot parse is ignored without a message**, and the
  rule then loads into every session. A session that is already running has
  been seen to keep the rules it started with — observed, not documented by
  the tool. So check in a **new** session, with the
  `rule-load-check` skill: it lists what is in context before anything is
  read, reads one file per load class, and backs each claim with a quoted
  last line that is then compared with the file.

The other tools read a rule when the constitution links to it; there is no
load class to set, and `--source-paths` does nothing there.

## Declining what the kit installs

The installer adds whatever is missing. That is what makes a re-run an
upgrade step, and it is also why deleting a file of the kit's is not enough:
the next run cannot tell "deleted on purpose" from "new in this kit", and
puts it back. To keep something out, list its path in `.starter-kit-declined`
at the root of your repository — before the first install, or after deleting
the file:

```text
# one path per line, relative to the repository root; a reason after '#'
.claude/skills/semver/                   # the organisation plugin ships it
.claude/skills/prompt-enhancer/SKILL.md  # same
```

A listed file is not installed; a listed directory covers everything beneath
it. The installer reports each as "declined" under "Skipped", and never
writes to the list. The list is yours and states an intent — it is not a
record of what is installed: `.starter-kit-version` names the kit, not the files (ADR-0024 in the kit's repository).

One file is held back without being listed: `project-annotations.md`, where
the comments rule it belongs to was already in the repository. That rule may
carry your rows, and upgrade step 3 creates the file as part of moving them.

Declining a file that other installed files depend on is yours to reconcile:
a rule that a `Related:` line names makes `make graph-links` fail on that
line, and a gate script that `registry.mk` runs makes its target fail. Both
say which file is missing.

## Troubleshooting

| `make lint` says | What it means | Do this |
|---|---|---|
| `<file>:<line> — … link 'RULE:x' resolves to nothing` | A typed link names an artifact that was renamed, deleted or never written | Fix the citing line; the message lists the names that exist. `make graph-impact NODE=RULE:x` shows what cites an artifact *before* you rename it |
| `check-<gate>.sh is installed but 'lint' never runs it` | Your own Makefile does not chain a gate the kit installed. All five are held: `registry-drift`, `registry-ids`, `kb-shape`, `graph-links`, `ci-lint-coverage` | Add the target the message names to the `lint:` prerequisites |
| `more than one agentic tool is set up … no --tool was given` | The installer found the files of several agent tools and nobody to ask | Re-run with `--tool` naming the one to install for. Nothing was written |
| `link '…' names a file that does not exist` or `unfilled placeholder '<…>'` (`make constitution`) | The constitution points at a rule that was never written — the template's `testing.md` and `security.md` are examples — or it or `project-annotations.md` still has template text in it | Write the file, fix the link or delete the line; replace the placeholder or delete the row. Angle brackets that are meant to stay go in backticks |
| `CHANGELOG.md is out of date with changelog.d/` | A fragment was added, or the generated file was edited by hand | `make registry-generate`, and commit the result with the fragment |
| `still contains the template placeholder` | A fragment created by `registry_tool.py new` was not filled in | Fill in the fields, or delete the fragment |
| `… is named by date, and this registry numbers its records` | A fragment was named `YYYY-MM-DD-<slug>.md` where `registries.json` declares `"id_scheme": "numeric"`. At width 4 it would be read as record number `<year>` | Rename it to the numbered form the message shows; `registry_tool.py new --registry <name> --title "…"` allocates the number. If the records really are date-named and the declaration is wrong — an install made before this was fixed — set `"id_scheme": "slug"` for that registry |
| `duplicate identifier … claimed by 2 fragments` | Two branches took the same number | Rename the fragment that has not been merged yet. Never renumber one that has |
| `python3: command not found`, `Python was not found`, or `no Python 3.9 or newer found` | Python has another name on this machine, or is older than 3.9 | Nothing the kit runs or tells you to type names `python3`. A rule, skill or README installed from an older kit still may: run that command as `./scripts/python.sh scripts/…`, and take the newer file (upgrade steps 2 and 3). `./scripts/python.sh --which` prints the interpreter it found; `PYTHON=/path/to/python` names one |
| `these 'lint' sub-targets run in no workflow` | A check is in the Makefile and in no CI step the gate can read: only a `run:` step of a workflow that a push, pull request or merge queue triggers — or of a reusable workflow one of those calls by a local path — counts, in the repository root | Have that workflow run `make lint`, the aggregate target. The lines under "Read and not counted" say what was seen and why it did not count |

## The constitution check

`make constitution` reads the constitution — `CLAUDE.md`, `AGENTS.md` or
`.github/copilot-instructions.md`, whichever the repository has — and
`project-annotations.md` beside the rules, and fails, with the file and line,
on two things:

| It reports | For instance |
|---|---|
| A relative Markdown link to a file or directory that does not exist | The template's `testing.md` and `security.md` lines, left in a project that never wrote those rules; a rule that was renamed without its index line |
| A template placeholder nobody filled in: `<…>` that opens with a letter and contains a space, outside code | `<Project Name>`, `<language, framework, versions>`, `<add one line per rule file …>`, and every `<fill in: …>` of `project-annotations.md` |

`make lint` checks neither. The typed-link gate resolves `Related:`,
`Enforces:` and `Hands off to:` lines, not ordinary links, so a constitution
can be committed half filled in with every gate green — which is what this
check was written after.

What it leaves alone, on purpose: anything inside a fenced block or
`backticks` (`--title "<symptom>"`, `RULE:<name>`), HTML tags and comments,
autolinks, a single word in angle brackets (`Option<T>`), web links — and
every other file. The rules the kit ships and `docs/rule-reference/` are full
of `<IDENTIFIER>` shapes that are the point of those documents. The one file
read beside the constitution is `project-annotations.md`, because it starts as
a template the project fills in, like the constitution itself.

It ships **unchained**: `lint` does not run it. A check that is on by default
and can fail a constitution that passed yesterday is a breaking change for
every repository that upgrades, and whether to hold your constitution on
every pull request is your decision. To do so, add the target to your own
line — nothing else is needed:

```make
lint: registry-drift registry-ids kb-shape graph-links ci-lint-coverage constitution <your existing prerequisites>
```

Other files can be checked the same way by naming them:
`./scripts/check-constitution.sh docs/PLAYBOOK.md`.

## The workspace-graph hook (Claude Code)

The typed links are only useful to an agent that looks them up. On Claude Code
the kit does the looking, with one hook registered for two events in
`.claude/settings.json`:

| When | What the agent gets |
|---|---|
| After it edits a file (`Edit`, `Write`) | If another artifact cites the file, or the file now carries a link that resolves to nothing: the citing files and lines. For any other file: nothing |
| When it ends its turn | If a typed link no longer resolves — a rename done through the shell, say — the turn is held once and the failure is handed back, so the break is repaired or reported before "done" |

You do nothing, and mostly see nothing: the hook is silent unless it has
something to say, and it says each distinct thing once per session. It is
context, not a gate — `make lint` stays the gate, it never changes a file, and
when it cannot do its job it ends silent. It runs only the graph tool of your
own repository — the one `$CLAUDE_PROJECT_DIR` names: an edited file in a
worktree of it is judged by that worktree's graph, a file in any other
repository — a clone the agent was asked to look at, or a submodule — by
nothing. A submodule that carries the kit keeps its own `make lint` as the gate.

| To | Do this |
|---|---|
| Switch it off for one run | `WORKSPACE_GRAPH_HOOK=off` in the environment |
| Remove it | Delete the `PostToolUse` and `Stop` entries that name `workspace-graph.py` from `.claude/settings.json` |
| See why it said nothing | `WORKSPACE_GRAPH_HOOK_DEBUG=1`; the reason goes to the hook's stderr |
| Run it on a machine where Python is not `python3` | Nothing: both entries start it through `scripts/python.sh` |
| Use it where the kit's scripts are not in `scripts/` | Add `--tool <path to graph_tool.py>` after the event in both entries: `… workspace-graph.py post-edit --tool tools/kit/graph_tool.py`. The path is relative to the repository and must stay inside it |
| Add it to a repository installed before it existed | Re-run `bootstrap.sh`: it adds the hook file and prints the two entries to put in your `settings.json`, which it never edits |

Claude Code asks you to approve an edit to a file under `.claude/` — a rule,
for instance — before it happens; the hook runs after the edit, so it runs
after your approval. The other three tools get the same answer on demand, from
`./scripts/python.sh scripts/graph_tool.py note <file>`; a hook for them waits until their
hook formats are verified (ADR-0006 in the kit's repository).

## Adopting the comments-and-annotations rule

The rule is used as shipped: edit nothing in it. What only your project can
say about it goes into a file of your own beside it, `project-annotations.md`
(`.claude/rules/` on Claude Code, `docs/agent-rules/` on the other tools),
which the installer leaves as a template. Fill in every `<fill in: …>` once,
right after bootstrap; `make constitution` names the ones still open.

1. **The pointers.** The rule and its on-demand examples
   (`docs/rule-reference/comments-and-annotations.md`) name a decision record,
   a knowledge-base entry, a ticket and a gate by a pointer in angle brackets.
   The first table of `project-annotations.md` says what each one is here:

   | Pointer | Fill with |
   |---|---|
   | `<DECISION-RECORD-ID>` | the identifier shape `registries.json` declares for decision records — `make registry-list` prints it (the date-slug form on a fresh install, MADR numbering where existing records are numbered). No `adr` registry, because decisions are recorded elsewhere: say where, and how one is cited |
   | `<KB-ENTRY-ID>` | the identifier shape it declares for the debugging knowledge base |
   | `<TICKET-ID>` | your tracker's reference shape (an issue number, a ticket key). No tracker yet: use your hosting platform's issue-number shape (`#123`), so a TODO still names something that can exist |
   | `<tool-or-gate>` | the lint gate that parses your markers, and any gate that checks front-matter presence. None of your own yet: `make lint`, which runs the kit's gates |
   | `<EVAL-RECORD-ID>` | wherever your project records evaluation evidence for prompts, or "none" |

   Write a shape exactly as `make registry-list` prints it, in backticks. The
   date-slug form ends in `<slug>`, and that angle-bracket token is part of
   the shape, not something left to fill.
2. **The protected shapes of your project.** The rule's first table holds the
   markers the kit's own tooling parses, its second the kinds a project adds.
   Which of those your project has goes into the second table of
   `project-annotations.md`. Grep your own tooling once for the tokens it
   reads out of comments and list each one — a marker is anything a linter, a
   build step, a test runner, a template engine or a CI script matches on:

   ```bash
   # once, from the repo root: which comment tokens does my tooling read?
   grep -rnoE 'noqa|eslint-disable|prettier-ignore|pragma|@ts-(ignore|expect-error)|<!-- *[a-zA-Z-]+ *-->' \
     --include='Makefile*' --include='*.mk' --include='*.toml' --include='*.cfg' --include='*.yml' \
     --include='*.yaml' --include='*.config.*' --include='.*rc*' --exclude-dir=.git . | sort -u
   ```

   Adapt the pattern and the file names to the tools you actually run; the
   point is the list, not the command. Every shape that turns up is
   configuration, not commentary, and gets a row with the gate that reads it
   in the last column. The kit's own markers will be among the hits; they are
   in the rule already. **Nothing of your own turns up:** that is a valid
   answer for a project with no linter directives yet. Write the sentence the
   template offers — none yet, a row is added when a tool starts reading a
   comment — instead of inventing a marker.

The rule and its reference keep their angle-bracket tokens: the pointers are
notation that `project-annotations.md` resolves, and `<product>`, `<vendor>`,
`<regulation>` and `<TIER>` inside the examples are illustrative. A
leftover-placeholder grep for `<` therefore still hits both files; neither is
yours to clean. The rule is deliberately ungated — its enforcement section
says why — so there is no script to wire into `make lint`.

## Conventions the templates assume

- **Self-containment (load-bearing).** Every portable artifact — a skill
  directory with its own `references/`, `scripts/`, `tests/`; an agent or
  command as a single file — must be copyable on its own, with no path
  dependency on the rest of this kit. Inside a portable artifact, name a
  companion artifact rather than hard-coding its repository path.
  Target-*project* paths (where an artifact reads or writes in the adopting
  repo) stay explicit. This is what keeps a future plugin conversion
  mechanical — see `docs/adr/adr-0001-repo-canonical-plugin-as-future-channel.md`.
- An umbrella lint target (`make lint` or equivalent) that CI runs on every PR —
  every `check-*` script gets chained into it, **and CI invokes that aggregate
  target rather than re-listing its parts**. A workflow that enumerates
  sub-targets drifts away from the Makefile one PR at a time, silently, until
  checks the rule files call enforced have not run in months.
- **Files that many PRs append to are authored one entry per file.** Changelogs,
  knowledge bases, decision records and their kin conflict on every concurrent
  pair and hand two branches the same identifier without either noticing. The
  kit ships the fragment layout, its generator and its gates as day-1 defaults
  because retrofitting is cheap while the registries are empty and expensive
  once their identifiers are cited.
- **Artifacts cite each other with typed links, and the links are resolved.**
  A check script names the rule it enforces (`# Enforces: RULE:<name>`), a
  knowledge-base entry the rule that now prevents its bug (a `Related:` line),
  a skill what it hands work to (a `Hands off to:` line). A token names a
  file, not a path, so it holds in every tool layout. `make lint` fails on a
  link that names nothing, and `make graph-impact NODE=<KIND:name>` lists what
  cites an artifact before you rename, delete or rewrite it (guide § 3.12).
  On Claude Code a hook hands the agent that list after an edit, unasked.
- PR-only trunk: agents never commit to the default branch.
- Placeholders are written `<like-this>`; grep for `<` after filling in a template
  to catch leftovers.
