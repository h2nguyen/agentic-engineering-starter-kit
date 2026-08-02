# Agentic Engineering Starter Kit

Everything needed to set up **agentic engineering** in any software project —
the practice of treating AI coding agents as team members with versioned
conventions, guardrails, workflows, and feedback loops, so every agent session
starts with the accumulated knowledge of all previous ones.

Works with any agentic coding tool — Claude Code, `AGENTS.md`-convention tools,
Cursor, GitHub Copilot (guide § 3.10). Extracted from a mature production
repository (called *the reference project* throughout the guide) and fully
de-branded: its material is illustration, never prescription.

## Quick start — three entry points

1. **Agent-driven (recommended):** paste
   [`starter-kit/SETUP-PROMPT.md`](starter-kit/SETUP-PROMPT.md) into a fresh
   session of your AI coding agent at your repo's root. The agent detects your
   tool, mines your repo for ground truth, installs the setup, and verifies it —
   including a **harmonize track** for repos that already have agent
   configuration (preserve-by-default, evidence-based, approval-gated).
2. **Script:**
   ```bash
   ./starter-kit/bootstrap.sh --target <your-repo>     # day-1 defaults
   ./starter-kit/bootstrap.sh --with-meta ...          # + Level-4 self-improvement loop (later)
   ```
   Detects (or asks) which tool the repo uses, installs to that tool's expected
   locations, never overwrites, idempotent.
3. **Manual:** follow the file-to-target mapping table in
   [`starter-kit/README.md`](starter-kit/README.md).

Then read [`AGENTIC-ENGINEERING-GUIDE.md`](AGENTIC-ENGINEERING-GUIDE.md) — the
concepts, a measured reference anatomy, the generic blueprint with design rules
for every artifact type, the adoption playbook, and the maintenance flywheel.

## What's inside

| Path | What it is |
|---|---|
| [`AGENTIC-ENGINEERING-GUIDE.md`](AGENTIC-ENGINEERING-GUIDE.md) | The full guide: § 1 concepts → § 2 reference anatomy → § 3 blueprint → § 4 adoption → § 5 maintenance (+ § 5.6 agentic-graph-engineering outlook) |
| [`starter-kit/SETUP-PROMPT.md`](starter-kit/SETUP-PROMPT.md) | Self-contained prompt that makes an agent drive the whole setup — with fallback specs, so it works even without the rest of this kit |
| [`starter-kit/bootstrap.sh`](starter-kit/bootstrap.sh) | Tool-detecting installer; `--with-meta` adds the Level-4 loop |
| [`starter-kit/rules/`](starter-kit/rules/) | Ready-to-use rule defaults: working principles (incl. plan-first/QRSPI), documentation, versioning & changelog — plus a rule-file template |
| [`starter-kit/skills/`](starter-kit/skills/) | Shipped skills (prompt-enhancer, semver incl. validator + tests), the common-skills catalog, the workspace-audit skill (Level 4), and a skill template |
| [`starter-kit/agents/`](starter-kit/agents/) | Agent template + the agent-coach meta-agent (Level 4, propose-never-silently-change) |
| [`starter-kit/commands/`](starter-kit/commands/) | Slash-command template + the audit command entry point |
| [`starter-kit/scripts/`](starter-kit/scripts/) | `check-kb-shape.sh` (runnable knowledge-base lint) + enforcement-script template |
| [`starter-kit/docs/`](starter-kit/docs/) | Graph-ready debugging-knowledge-base skeleton |
| [`starter-kit/hooks/`](starter-kit/hooks/), `settings.json.template`, `WORKSPACE_CHANGELOG.md.template` | Session-bootstrap hook skeleton, tool settings, audit-history skeleton |
| [`docs/adr/`](docs/adr/) | Decision records for this project — starting with why the repo is canonical and a plugin is a future distribution channel |

## Design in one breath

Grow by signal, not speculation: a constitution + universal rules + an empty
knowledge base on day 1 (Level 1); enforcement scripts and domain rules as
violations appear (Level 2); skills and specialist reviewer agents as workflows
and review comments recur (Level 3); the self-improvement loop — workspace
audits + agent coach — once the workspace has real mass (Level 4,
`--with-meta`); knowledge-graph tooling only when a consumer exists (§ 5.6).
Every artifact ships de-branded and directly usable.

## Related

- [`h2nguyen/semver-skill`](https://github.com/h2nguyen/semver-skill) —
  canonical upstream of the vendored semver skill; check there for updates.
