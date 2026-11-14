# Agentic Engineering Starter Kit

Everything needed to set up **agentic engineering** in any software project —
the practice of treating AI coding agents as team members with versioned
conventions, guardrails, workflows, and feedback loops, so every agent session
starts with the accumulated knowledge of all previous ones.

Works with any agentic coding tool — Claude Code, `AGENTS.md`-convention tools,
Cursor, GitHub Copilot (guide § 3.10). Extracted from a mature production
repository (called *the reference project* throughout the guide) and fully
de-branded: its material is illustration, never prescription.

## Requirements

`git`, `make`, `bash` 3.2 or newer and `python3` 3.9 or newer — standard
library only. Nothing to install, no network access, no per-clone `git config`.
The kit's own checks, and a fresh install for each of the four tools, pass in
a clean clone on macOS (system bash 3.2, GNU Make 3.81, Python 3.9) and on
Linux (Debian 12, bash 5.2, GNU Make 4.3, Python 3.9, as a non-root user with
networking off). Python 3.12 and 3.13 pass as well. The CI workflow the kit
installs runs on `ubuntu-latest`.

## Quick start — three entry points

1. **Agent-driven (recommended):** paste
   [`starter-kit/SETUP-PROMPT.md`](starter-kit/SETUP-PROMPT.md) into a fresh
   session of your AI coding agent at your repo's root. The agent detects your
   tool, mines your repo for ground truth, installs the setup, and verifies it —
   including a **harmonize track** for repos that already have agent
   configuration (preserve-by-default, evidence-based, approval-gated). Or
   point your agent at a checkout of this repository: [`AGENTS.md`](AGENTS.md)
   tells it how to install the kit into your project.
2. **Script.** From a checkout of this repository:
   ```bash
   ./starter-kit/bootstrap.sh --target /path/to/your-repo                 # detects your tool, or asks
   ./starter-kit/bootstrap.sh --target /path/to/your-repo --tool claude   # claude | agents | cursor | copilot
   ```
   It installs to that tool's expected locations, never overwrites a file and
   is safe to re-run. Nothing but the installed files lands in your repository.
3. **Manual.** Follow the file-to-target mapping table in
   [`starter-kit/README.md`](starter-kit/README.md).

## After installing

1. Fill in the constitution's `<placeholders>` and the project rows of the
   comments-and-annotations rule —
   [how](starter-kit/README.md#adopting-the-comments-and-annotations-rule).
2. Run `make lint`. A working install prints an `OK:` line for each of its five
   gates and no `FAIL`. If your repository already had a Makefile, the
   installer left it alone and printed the two lines to add.
3. Commit on a feature branch.

Later, once the workspace has real mass, `--with-meta` adds the Level-4
self-improvement loop. To move an existing install to a newer kit, see
[Upgrading an existing install](starter-kit/README.md#upgrading-an-existing-install).

## Who reads what

| You are | Start with |
|---|---|
| Installing the kit into a project | This page, then [`starter-kit/README.md`](starter-kit/README.md) |
| An AI agent asked to install the kit, or to change it | [`AGENTS.md`](AGENTS.md) |
| Changing the kit itself | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
| After the reasoning | [`AGENTIC-ENGINEERING-GUIDE.md`](AGENTIC-ENGINEERING-GUIDE.md) — concepts, a measured reference anatomy, the blueprint with design rules for every artifact type, the adoption playbook and the maintenance flywheel — and the decision records in [`docs/adr/`](docs/adr/) |

## What's inside

| Path | What it is |
|---|---|
| [`AGENTIC-ENGINEERING-GUIDE.md`](AGENTIC-ENGINEERING-GUIDE.md) | The full guide: § 1 concepts → § 2 reference anatomy → § 3 blueprint → § 4 adoption → § 5 maintenance (+ § 3.12 the workspace graph, and § 5.6 for what graph engineering still defers) |
| [`starter-kit/SETUP-PROMPT.md`](starter-kit/SETUP-PROMPT.md) | Self-contained prompt that makes an agent drive the whole setup — with fallback specs, so it works even without the rest of this kit |
| [`starter-kit/bootstrap.sh`](starter-kit/bootstrap.sh) | Tool-detecting installer; `--with-meta` adds the Level-4 loop |
| [`starter-kit/rules/`](starter-kit/rules/) | Ready-to-use rule defaults: working principles (incl. plan-first/QRSPI), documentation, comments & annotations, versioning & changelog, shared registries — plus a rule-file template, and `reference/` with the worked examples and gotchas the two long rules point at (read on demand, never loaded) |
| [`starter-kit/skills/`](starter-kit/skills/) | Shipped skills (prompt-enhancer, semver incl. validator + tests, registry-entry, registry-conflict-triage), the common-skills catalog, the workspace-audit and workspace-graph skills (Level 4), and a skill template |
| [`starter-kit/agents/`](starter-kit/agents/) | Agent template + the agent-coach meta-agent (Level 4, propose-never-silently-change) |
| [`starter-kit/commands/`](starter-kit/commands/) | Slash-command template + the audit command entry point |
| [`starter-kit/scripts/`](starter-kit/scripts/) | `registry_tool.py` (fragment generator + identifier gate), `graph_tool.py` (typed-link gate + impact and coverage queries) behind `check-graph-links.sh`, `check-kb-shape.sh`, the registry drift/identifier gates, the CI-coverage gate, tests + the parallel-merge and typed-link acceptance tests, and an enforcement-script template |
| [`starter-kit/docs/`](starter-kit/docs/), `changelog.d/`, `registries.json.template`, `gitattributes.template`, `Makefile.template`, `ci/` | The shared-append-only-registry layer: fragment directories, declaration, merge behaviour, lint target and CI workflow (guide § 3.11) |
| [`starter-kit/hooks/`](starter-kit/hooks/), `settings.json.template`, `WORKSPACE_CHANGELOG.md.template` | Session-bootstrap hook skeleton, tool settings, audit-history skeleton |
| [`docs/adr/`](docs/adr/) | Decision records for this project — starting with why the repo is canonical and a plugin is a future distribution channel |
| [`AGENTS.md`](AGENTS.md), [`CONTRIBUTING.md`](CONTRIBUTING.md) | How an agent installs or changes the kit; how a person changes it — tests, gates, changelog, release |

## Design in one breath

Grow by signal, not speculation: a constitution + universal rules + an empty
knowledge base on day 1 (Level 1); enforcement scripts and domain rules as
violations appear (Level 2); skills and specialist reviewer agents as workflows
and review comments recur (Level 3); the self-improvement loop — workspace
audits + agent coach — once the workspace has real mass (Level 4,
`--with-meta`); graph-driven retrieval only when a consumer exists (§ 5.6).
Every artifact ships de-branded and directly usable.

Two things are day-1 defaults rather than grown-by-signal artifacts, and
deliberately so. The first: files that many pull requests append to — changelogs,
knowledge bases, decision records — conflict on every concurrent pair and hand
two branches the same identifier without either noticing. The conflict is
loud and cheap; the duplicate identifier is silent and permanent, because
other files cite it. Retrofitting the fix costs nothing while those files are
empty and a great deal once their identifiers are in use, so the kit installs
it at commit one (guide § 3.11).

The second follows from the same argument. Artifacts cite each other — a check
script names the rule it enforces, a knowledge-base entry the rule that now
prevents its bug, a skill the reviewer it hands off to — and a citation to
something renamed or deleted reads exactly like one that works. A gate resolves
every such typed link from commit one, and the same index answers *what cites
this?* before an agent edits a rule (guide § 3.12).

## Related

- [`h2nguyen/semver-skill`](https://github.com/h2nguyen/semver-skill) —
  canonical upstream of the vendored semver skill; check there for updates.
