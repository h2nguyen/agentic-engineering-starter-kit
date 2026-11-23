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
(+ the prompt-enhancer, semver, registry-entry and registry-conflict-triage
skills on Claude Code, and the hook that hands the typed links to the agent —
[below](#the-workspace-graph-hook-claude-code)) to that tool's locations, and
never overwrites existing files. Then: fill in the constitution's `<placeholders>` and the project rows of
the comments-and-annotations rule
([how](#adopting-the-comments-and-annotations-rule)), run `make constitution`
until it stops naming placeholders and links to files that do not exist, run
`make lint` to confirm the gates pass, enable further common skills from
`skills/common-catalog.md`, and commit.

## Contents → target locations (manual path)

| Kit file | Copy to (Claude Code shown; bootstrap maps other tools) | Then |
|---|---|---|
| `SETUP-PROMPT.md` | — (paste into an agent session at the target repo) | The agent drives the whole setup |
| `bootstrap.sh` | — (run it, don't copy it into the repo) | `--help` for options |
| `constitution.md.template` | `CLAUDE.md` / `AGENTS.md` / tool equivalent | Fill in every `<placeholder>` |
| `rules/working-principles.md` | `.claude/rules/working-principles.md` | Use as-is (project-agnostic, incl. plan-first/QRSPI) |
| `rules/documentation.md` | `.claude/rules/documentation.md` | Use as-is (docs-with-the-change, ADR format (Michael Nygard), where rationale lives) |
| `rules/comments-and-annotations.md` | `.claude/rules/comments-and-annotations.md` | Fill in the project half of its protected-shapes table and its four `<placeholders>` — see [Adopting the comments-and-annotations rule](#adopting-the-comments-and-annotations-rule) |
| `rules/reference/` | `docs/rule-reference/` | The worked examples of the comments rule and the gotchas of the registries rule — read on demand, never loaded. Same location for every tool |
| `rules/versioning-and-changelog.md` | `.claude/rules/versioning-and-changelog.md` | Use as-is (SemVer + Keep-a-Changelog discipline) |
| `rules/shared-registries.md` | `.claude/rules/shared-registries.md` | Use as-is (fragment layout, identifier schemes, merge behaviour) |
| `registries.json.template` | `registries.json` | Reference only — bootstrap runs `registry_tool.py init`, which writes the file from the conventions your repo already has |
| `registry.mk` | `registry.mk` | The registry and graph targets; `include registry.mk` from an existing Makefile and add the gates to your `lint` prerequisites |
| `gitattributes.template` | `.gitattributes` | Use as-is — built-in `merge=union` only, so nothing needs `git config`. An existing file gets the block appended under a marker, idempotently |
| `CHANGELOG.md.template` | `CHANGELOG.md` | Skip if you already have one — run `registry_tool.py adopt --registry changelog` on it instead |
| `changelog.d/` | `changelog.d/` | One fragment per change; categories are `## ` headings inside it |
| `docs/DEBUGGING-KNOWLEDGE-BASE.d/` | `docs/DEBUGGING-KNOWLEDGE-BASE.d/` | One file per entry — the authored source of the KB |
| `Makefile.template` | `Makefile` | Greenfield only — includes `registry.mk`. An existing Makefile is never touched; bootstrap prints the two lines to add, and says whether `make lint` reaches the gates yet (run it again after the edit to confirm) |
| `ci/lint.yml.template` | `.github/workflows/lint.yml` | Adapt the runner; keep the step that invokes the aggregate target |
| `ci/agent-feedback.yml.template` | `.github/workflows/agent-feedback.yml` | **Opt-in** — only with `bootstrap.sh --with-coach-schedule`, or a yes to the installer's question. Every Monday it posts the week's `Agent-Feedback:` lines as a digest on an issue labelled `agent-feedback`. With an `ANTHROPIC_API_KEY` secret and the Claude GitHub App, the coach's proposals follow on the same issue. It reads code and writes to issues only: no push, no branch, no pull request |
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
| `scripts/check-constitution.sh` | `scripts/check-constitution.sh` | `make constitution` — fails while the constitution links to a file that does not exist or still has a template `<placeholder>` in it. **Not** chained into `make lint`: run it after filling the constitution in and after editing it, or add `constitution` to your `lint:` line to hold it on every pull request ([below](#the-constitution-check)) |
| `scripts/tests/` | `scripts/tests/` | Unit tests, the coverage-gate and constitution-check tests, and the parallel-merge and typed-link acceptance tests — the target `registry-test`, which the installed Makefile chains into `make lint`; with a Makefile of your own, add `registry-test` to its `lint:` line to run them. The brownfield-adoption, bootstrap re-run, upgrade and hook suites test the installer and the Claude Code hook, so they stay in the kit |
| `skills/registry-entry/SKILL.md` | `.claude/skills/registry-entry/SKILL.md` | Authoring a registry entry (installed by bootstrap on Claude Code) |
| `skills/registry-conflict-triage/SKILL.md` | `.claude/skills/registry-conflict-triage/SKILL.md` | Escalation only — resolving a registry conflict |
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
| `WORKSPACE_CHANGELOG.md.template` | `.claude/WORKSPACE_CHANGELOG.md` | Audit-history skeleton — via `--with-meta` |
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
   know are non-negotiable. Then the project rows of the comments-and-annotations
   rule — next section.
3. Run `make constitution`. It lists, by line, every template placeholder
   still in the constitution and every link to a file that does not exist —
   the template links two example rules, `testing.md` and `security.md`, that
   no install has. It passes when step 2 is really done; `make lint` does not
   look at either.
4. Run `make lint`. All five gates should pass on a fresh install with no
   `git config` and no other setup — that is the check that the registry layer
   actually landed rather than merely being present.
5. Enable the generic skills worth having from day one — see
   [`skills/common-catalog.md`](skills/common-catalog.md) (semver decisions,
   architecture review, architecture docs).
6. Commit. The setup is live.
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

The kit does not record in your repository which version it was installed
from, and it does not need to: every step compares your files with the kit's,
whichever version you started from. For why a file changed, search the kit's
`CHANGELOG.md` for its name.

1. **Add what is new.** Pass `--with-meta` if your repository has the Level-4
   layer (`agent-coach`, the workspace-audit skill), and `--with-coach-schedule`
   to add the weekly feedback digest.
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
   rm -f scripts/tests/test-bootstrap-rerun.sh scripts/tests/test-brownfield-adoption.sh scripts/tests/test-upgrade.sh scripts/tests/test-graph-hooks.sh
   ```
   The last line removes the four suites that test the installer and the
   Claude Code hook; they stay in the kit and are not run from your
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
3. **Update the rule files — merge the one you filled in, copy the rest.**
   List the rules that differ from the kit's:
   ```bash
   diff -rq "$KIT"/starter-kit/rules .claude/rules | grep '^Files'
   diff -rq "$KIT"/starter-kit/rules/reference docs/rule-reference | grep '^Files'
   ```
   (`docs/agent-rules/` in place of `.claude/rules/` on the other tools.)
   - **`comments-and-annotations.md` is merged, never copied.** It carries
     your project's rows and pointers — the ones
     [Adopting the comments-and-annotations rule](#adopting-the-comments-and-annotations-rule)
     had you fill in. Take the kit's file, then put your second table and your
     pointers back; a copy would reset them to placeholders. Its reference
     file, `docs/rule-reference/comments-and-annotations.md`, carries the same
     pointers and gets the same values.
     ```bash
     diff -u .claude/rules/comments-and-annotations.md "$KIT"/starter-kit/rules/comments-and-annotations.md
     ```
     While you are there, re-read your own rows: they describe the project as
     it was on the day of the install.
   - **The other rules are used as shipped**, so for one that no commit of
     yours has changed, copying the kit's file is the whole merge. One you
     did change is merged by hand, the same way.
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
   ```
   (The last two on Claude Code only, and the hook only if your install has
   one: kits up to 3.0.1 installed and registered that skeleton, and it is
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

`scripts/tests/test-upgrade.sh` in the kit runs these steps as written
here — against an install shaped like 1.x and, where the kit's history has the
tag, against a real 1.1.0 install — and checks that what is yours comes out
byte for byte as it went in.

Commit the upgrade on its branch, like any other change. It needs no
changelog fragment — your changelog describes your project, not its agent
workspace — and, where you keep one, a line in the workspace changelog.

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
record of what is installed (the kit keeps none, ADR-0011 in its repository).

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
| `link '…' names a file that does not exist` or `unfilled placeholder '<…>'` (`make constitution`) | The constitution points at a rule that was never written — the template's `testing.md` and `security.md` are examples — or still has template text in it | Write the file, fix the link or delete the line; replace the placeholder or delete the row. Angle brackets that are meant to stay go in backticks |
| `CHANGELOG.md is out of date with changelog.d/` | A fragment was added, or the generated file was edited by hand | `make registry-generate`, and commit the result with the fragment |
| `still contains the template placeholder` | A fragment created by `registry_tool.py new` was not filled in | Fill in the fields, or delete the fragment |
| `… is named by date, and this registry numbers its records` | A fragment was named `YYYY-MM-DD-<slug>.md` where `registries.json` declares `"id_scheme": "numeric"`. At width 4 it would be read as record number `<year>` | Rename it to the numbered form the message shows; `registry_tool.py new --registry <name> --title "…"` allocates the number. If the records really are date-named and the declaration is wrong — an install made before this was fixed — set `"id_scheme": "slug"` for that registry |
| `duplicate identifier … claimed by 2 fragments` | Two branches took the same number | Rename the fragment that has not been merged yet. Never renumber one that has |
| `python3: command not found`, `Python was not found`, or `no Python 3.9 or newer found` | Python has another name on this machine, or is older than 3.9 | Nothing the kit runs or tells you to type names `python3`. A rule, skill or README installed from an older kit still may: run that command as `./scripts/python.sh scripts/…`, and take the newer file (upgrade steps 2 and 3). `./scripts/python.sh --which` prints the interpreter it found; `PYTHON=/path/to/python` names one |
| `these 'lint' sub-targets run in no workflow` | A check is in the Makefile and in no CI step the gate can read: only a `run:` step of a workflow that a push, pull request or merge queue triggers — or of a reusable workflow one of those calls by a local path — counts, in the repository root | Have that workflow run `make lint`, the aggregate target. The lines under "Read and not counted" say what was seen and why it did not count |

## The constitution check

`make constitution` reads the constitution — `CLAUDE.md`, `AGENTS.md` or
`.github/copilot-instructions.md`, whichever the repository has — and fails,
with the file and line, on two things:

| It reports | For instance |
|---|---|
| A relative Markdown link to a file or directory that does not exist | The template's `testing.md` and `security.md` lines, left in a project that never wrote those rules; a rule that was renamed without its index line |
| A template placeholder nobody filled in: `<…>` that opens with a letter and contains a space, outside code | `<Project Name>`, `<language, framework, versions>`, `<add one line per rule file …>` |

`make lint` checks neither. The typed-link gate resolves `Related:`,
`Enforces:` and `Hands off to:` lines, not ordinary links, so a constitution
can be committed half filled in with every gate green — which is what this
check was written after.

What it leaves alone, on purpose: anything inside a fenced block or
`backticks` (`--title "<symptom>"`, `RULE:<name>`), HTML tags and comments,
autolinks, a single word in angle brackets (`Option<T>`), web links — and
every file that is not the constitution. Rule files and `docs/rule-reference/`
are full of `<IDENTIFIER>` shapes that are the point of those documents.

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
| Add it to a repository installed before it existed | Re-run `bootstrap.sh`: it adds the hook file and prints the two entries to put in your `settings.json`, which it never edits |

Claude Code asks you to approve an edit to a file under `.claude/` — a rule,
for instance — before it happens; the hook runs after the edit, so it runs
after your approval. The other three tools get the same answer on demand, from
`./scripts/python.sh scripts/graph_tool.py note <file>`; a hook for them waits until their
hook formats are verified (ADR-0006 in the kit's repository).

## Adopting the comments-and-annotations rule

The rule installs as-is and is complete except for the rows only your project
can fill. Two things to do once, right after bootstrap:

1. **Fill the project half of its "Protected shapes" table.** The first table
   is already filled with the markers the kit's own tooling parses. For the
   second, grep your own tooling once for the tokens it reads out of comments
   and list each one — a marker is anything a linter, a build step, a test
   runner, a template engine or a CI script matches on:

   ```bash
   # once, from the repo root: which comment tokens does my tooling read?
   grep -rnoE 'noqa|eslint-disable|prettier-ignore|pragma|@ts-(ignore|expect-error)|<!-- *[a-zA-Z-]+ *-->' \
     --include='Makefile*' --include='*.mk' --include='*.toml' --include='*.cfg' --include='*.yml' \
     --include='*.yaml' --include='*.config.*' --include='.*rc*' --exclude-dir=.git . | sort -u
   ```

   Adapt the pattern and the file names to the tools you actually run; the
   point is the list, not the command. Every shape that turns up is configuration, not commentary,
   and goes into the table with the gate that reads it in the last column. The
   kit's own markers will be among the hits; they are in the first table
   already. **Nothing of your own turns up:** that is a valid answer for a
   project with no linter directives yet. The second table's rows are examples
   of kinds, so leave them, and add one line under the table saying so —
   "none yet; add a row when a tool starts reading a comment" — instead of
   inventing a marker.
2. **Resolve the pointers.** Four placeholders stay in the rule — and in its
   on-demand examples, `docs/rule-reference/comments-and-annotations.md` — on purpose,
   because their value belongs to the adopting project:

   | Placeholder | Fill with |
   |---|---|
   | `<DECISION-RECORD-ID>` | the identifier shape `registries.json` declares for decision records — `./scripts/python.sh scripts/registry_tool.py list` prints it (the date-slug form on a fresh install, MADR numbering where existing records are numbered) |
   | `<KB-ENTRY-ID>` | the identifier shape it declares for the debugging knowledge base |
   | `<TICKET-ID>` | your tracker's reference shape (an issue number, a ticket key). No tracker yet: use your hosting platform's issue-number shape (`#123`), so a TODO still names something that can exist |
   | `<tool-or-gate>` | the lint gate that parses your markers, and any gate that checks front-matter presence. None of your own yet: `make lint`, which runs the kit's gates |

   Write a shape exactly as `registry_tool.py list` prints it. The date-slug
   form ends in `<slug>`, and that angle-bracket token is part of the shape,
   not something left to fill.

   `<EVAL-RECORD-ID>` appears in the reference file's prompt-file example and survivors
   table: fill it with wherever your project records evaluation evidence for
   prompts, or leave it if you keep none. `<product>`, `<vendor>`,
   `<regulation>` and `<TIER>`, like the other angle-bracket tokens inside the
   examples, are illustrative and need no filling — so a leftover-placeholder
   grep for `<` will still hit this file after it is filled in; read the hits
   rather than counting them.

Nothing else in the file is project-specific. The rule is deliberately
ungated — its enforcement section says why — so there is no script to wire
into `make lint`.

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
