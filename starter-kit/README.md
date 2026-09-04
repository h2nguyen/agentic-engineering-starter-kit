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

## Quick start (recommended)

```bash
cp -r starter-kit /path/to/your-repo/          # or clone/vendor it
cd /path/to/your-repo
./starter-kit/bootstrap.sh                     # detects your tool, or asks
./starter-kit/bootstrap.sh --tool claude       # or name it explicitly
./starter-kit/bootstrap.sh --with-meta         # later, at Level 4: + self-improvement loop
```

**Zero-copy alternative:** paste [`SETUP-PROMPT.md`](SETUP-PROMPT.md) into a
fresh session of your AI coding agent at the target repo's root — the prompt
drives the whole setup (detect tool → mine the repo → install → verify), uses
this kit when present, and carries fallback specs when it isn't. Repos that
**already have** an agentic workspace are routed to a harmonize track:
preserve-by-default, evidence-based keep/enhance/fix/relocate classification,
lossless-first remediation, approval-gated changes — existing working
conventions beat the blueprint's defaults (guide § 4.4).

`bootstrap.sh` detects which agentic tool the repo uses (`.claude`/`CLAUDE.md`,
`.cursor`, `.github/copilot-instructions.md`, `AGENTS.md`), asks when nothing is
detected, installs the constitution + the universal rule files (working
principles, documentation, versioning & changelog, shared registries) + the
knowledge-base and changelog skeletons in their fragment layout + the
`.gitattributes`, `Makefile` and CI workflow that make the registry gates run
(+ the prompt-enhancer, semver, registry-entry and registry-conflict-triage
skills on Claude Code) to that tool's locations, and never overwrites existing
files. Then: fill in the constitution's `<placeholders>`, run `make lint` to
confirm the gates pass, enable further common skills from
`skills/common-catalog.md`, and commit.

## Contents → target locations (manual path)

| Kit file | Copy to (Claude Code shown; bootstrap maps other tools) | Then |
|---|---|---|
| `SETUP-PROMPT.md` | — (paste into an agent session at the target repo) | The agent drives the whole setup |
| `bootstrap.sh` | — (run it, don't copy it into the repo) | `--help` for options |
| `constitution.md.template` | `CLAUDE.md` / `AGENTS.md` / tool equivalent | Fill in every `<placeholder>` |
| `rules/working-principles.md` | `.claude/rules/working-principles.md` | Use as-is (project-agnostic, incl. plan-first/QRSPI) |
| `rules/documentation.md` | `.claude/rules/documentation.md` | Use as-is (docs-with-the-change, ADR-lite, comment hygiene) |
| `rules/versioning-and-changelog.md` | `.claude/rules/versioning-and-changelog.md` | Use as-is (SemVer + Keep-a-Changelog discipline) |
| `rules/shared-registries.md` | `.claude/rules/shared-registries.md` | Use as-is (fragment layout, identifier schemes, merge behaviour) |
| `registries.json.template` | `registries.json` | Reference only — bootstrap runs `registry_tool.py init`, which writes the file from the conventions your repo already has |
| `registry.mk` | `registry.mk` | The registry targets; `include registry.mk` from an existing Makefile and add the gates to your `lint` prerequisites |
| `gitattributes.template` | `.gitattributes` | Use as-is — built-in `merge=union` only, so nothing needs `git config`. An existing file gets the block appended under a marker, idempotently |
| `CHANGELOG.md.template` | `CHANGELOG.md` | Skip if you already have one — run `registry_tool.py adopt --registry changelog` on it instead |
| `changelog.d/` | `changelog.d/` | One fragment per change; categories are `## ` headings inside it |
| `docs/DEBUGGING-KNOWLEDGE-BASE.d/` | `docs/DEBUGGING-KNOWLEDGE-BASE.d/` | One file per entry — the authored source of the KB |
| `Makefile.template` | `Makefile` | Greenfield only — includes `registry.mk`. An existing Makefile is never touched; bootstrap prints the two lines to add and verifies they took effect |
| `ci/lint.yml.template` | `.github/workflows/lint.yml` | Adapt the runner; keep the step that invokes the aggregate target |
| `registry-id-duplicate-allowlist.template` | `.registry-id-duplicate-allowlist` | Starts empty; entries name a filename **pair** |
| `ci-lint-coverage-allowlist.template` | `.ci-lint-coverage-allowlist` | Starts empty; shrink-only |
| `scripts/registry_tool.py` | `scripts/registry_tool.py` | Ready to run — `new` / `generate` / `check` / `release` / `adopt` (brownfield: moves an existing artifact into fragments) |
| `scripts/check-registry-drift.sh` | `scripts/check-registry-drift.sh` | Chained into `make lint`; the gate that makes `merge=union` safe |
| `scripts/check-registry-ids.sh` | `scripts/check-registry-ids.sh` | Chained into `make lint` |
| `scripts/check-ci-lint-coverage.sh` | `scripts/check-ci-lint-coverage.sh` | Chained into `make lint`; proves the other gates reach CI |
| `scripts/tests/` | `scripts/tests/` | Unit tests, the coverage-gate tests, the parallel-merge acceptance test, and the brownfield-adoption test (runs from the kit) — chained into `make lint` |
| `skills/registry-entry/SKILL.md` | `.claude/skills/registry-entry/SKILL.md` | Authoring a registry entry (installed by bootstrap on Claude Code) |
| `skills/registry-conflict-triage/SKILL.md` | `.claude/skills/registry-conflict-triage/SKILL.md` | Escalation only — resolving a registry conflict |
| `rules/_rule-template.md` | — (keep as template) | Copy per new domain rule file |
| `skills/common-catalog.md` | — (reference doc) | Enable the listed generic skills at setup |
| `skills/prompt-enhancer/SKILL.md` | `.claude/skills/prompt-enhancer/SKILL.md` | Ready-to-use helper skill (installed by bootstrap on Claude Code) |
| `skills/semver/` | `.claude/skills/semver/` | Ready-to-use SemVer decision skill incl. validator + tests (installed by bootstrap on Claude Code; upstream: h2nguyen/semver-skill) |
| `skills/_template/SKILL.md` | — (keep as template) | Copy to `.claude/skills/<name>/SKILL.md` per new skill |
| `agents/_agent-template.md` | — (keep as template) | Copy to `.claude/agents/<name>.md` per new agent |
| `agents/agent-coach.md` | `.claude/agents/agent-coach.md` | Level-4 meta-agent — installed via `bootstrap.sh --with-meta` |
| `skills/ai-engineering-workspace-audit/` | `.claude/skills/ai-engineering-workspace-audit/` | Level-4 audit skill — installed via `--with-meta` |
| `commands/ai-engineering-workspace-audit.md` | `.claude/commands/ai-engineering-workspace-audit.md` | Thin `/command` entry for the audit skill — via `--with-meta` |
| `WORKSPACE_CHANGELOG.md.template` | `.claude/WORKSPACE_CHANGELOG.md` | Audit-history skeleton — via `--with-meta` |
| `commands/_command-template.md` | — (keep as template) | Copy to `.claude/commands/<name>.md` per new command |
| `settings.json.template` | `.claude/settings.json` | Remove the hook entry if you don't need one yet |
| `hooks/session-start.sh.template` | `.claude/hooks/session-start.sh` | `chmod +x`; fill in toolchain steps |
| `scripts/check-kb-shape.sh` | `scripts/check-kb-shape.sh` | Ready to run; already chained into the installed `make lint` (guards the KB's graph-ready shape) |
| `scripts/check-convention.sh.template` | `scripts/check-<convention>.sh` | `chmod +x`; wire into your lint target |
| `docs/DEBUGGING-KNOWLEDGE-BASE.md` | `docs/DEBUGGING-KNOWLEDGE-BASE.md` | Generated — start empty; add the first entry at the first >30-min bug |

## Bootstrap order (Level 1 — guide § 4.2)

1. Run `bootstrap.sh` (or copy manually per the table above).
2. Fill in the constitution: identity, stack table (including the infrastructure,
   auth, and messaging/integration rows), commands, and the 3–5 rules you already
   know are non-negotiable.
3. Run `make lint`. All four gates should pass on a fresh install with no
   `git config` and no other setup — that is the check that the registry layer
   actually landed rather than merely being present.
4. Enable the generic skills worth having from day one — see
   [`skills/common-catalog.md`](skills/common-catalog.md) (semver decisions,
   architecture review, architecture docs).
5. Commit. The setup is live.
6. Grow by signal, not speculation: rules when you repeat an instruction, skills
   when you repeat a workflow, agents when you repeat a review comment,
   enforcement scripts when a documented rule gets violated anyway. See the
   guide § 4–§ 5.

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
- PR-only trunk: agents never commit to the default branch.
- Placeholders are written `<like-this>`; grep for `<` after filling in a template
  to catch leftovers.
