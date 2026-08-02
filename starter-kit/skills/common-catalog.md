# Common Skills Catalog

Generic skills worth enabling at **initial setup** — the sanctioned exception to
"don't write speculative skills" (guide § 3.4): these workflows recur in every
software project, so they have already earned their place before your repo
generates its first signal.

## How to adopt

- **Claude Code** — copy the skill directory into `.claude/skills/<name>/`.
  The **prompt-enhancer and semver skills ship in this kit**
  (`skills/prompt-enhancer/`, `skills/semver/`) and are installed automatically
  by `bootstrap.sh`.
- **Other tools** — convert the skill's SKILL.md into a playbook doc linked from
  your constitution (guide § 3.10); the phase structure carries over unchanged.

Entries marked *(ships in this kit)* are included here and installed by
bootstrap. If you are bootstrapping from the repository this kit ships in, most
other entries exist there under `.claude/skills/` and are project-agnostic
enough to copy verbatim. Otherwise, treat this catalog as the shopping list of
skills worth building or porting first.

## The catalog

| Skill | What it gives you | When to enable |
|---|---|---|
| **prompt-enhancer** *(ships in this kit)* | Rewrites rough user prompts into precise, context-rich ones — role framing, injected session context, output format, success criteria — before they hit an agent. Improves every other interaction. | Level 1 — installed by bootstrap on day one |
| **semver** *(ships in this kit)* | Rigorous Semantic Versioning 2.0.0 decisions: bump levels, the 0.y.z stance, pre-release identifiers, version validation, recovery from misversioned releases. Ships the full spec + decision-guide references, a validator script, and its own test suite. The kit's `rules/versioning-and-changelog.md` default carries the core rule; this skill adds the full decision depth. Canonical upstream: <https://github.com/h2nguyen/semver-skill> — check there for updates. | Level 1 — installed by bootstrap on day one |
| **architecture-docs (arc42)** | Structured architecture documentation over the 12 arc42 sections plus ADRs, optionally backed by an MCP server so the agent can update sections as callable tools. | Level 1–2 — as soon as design decisions are worth recording durably |
| **architecture-review (clean architecture)** | Layer-dependency, SOLID, and module-boundary checking as a repeatable review workflow, optionally backed by an analyzer MCP server. | Level 2–3 — once the codebase has layers worth guarding |
| **plan-first ticket execution (QRSPI)** | Questions → Research → Design → Structure → Plan → Implement phases for medium, large, or ambiguous tickets: blocking-vs-parked question triage, evidence-grounded research, design alternatives, plans published on the ticket. Working principle 5 is its distillation; the full skill automates it end-to-end. | Level 3 — when ticket-driven agent execution becomes routine |
| **release workflow** | The bump → changelog → tag → build → deploy checklist as a guarded procedure. The *shape* is generic; the content must be adapted to your pipeline before first use. | Level 2–3 — at your first repeatable release |
| **workspace audit** | The guide § 5.2 quick/full audit cadences packaged as an invocable skill, with knowledge-ledger preservation and human approval gates. | Level 4 — once the workspace has real mass |

Skills are opt-in context: an unused catalog entry costs nothing at runtime, but
every skill you enable should still be one you expect to invoke.

## Meta artifacts (Level 4 — in the kit, NOT day-1 defaults)

The self-improvement loop ships in the kit but is deliberately excluded from the
default install: the framework defers the meta layer until a workspace has real
mass (guide § 4.1). Install with `bootstrap.sh --with-meta` once that signal
appears (~10+ workspace files, or the first real drift incident):

| Artifact | What it gives you |
|---|---|
| `skills/ai-engineering-workspace-audit/` + `commands/ai-engineering-workspace-audit.md` | The guide § 5.2 audit cadences: quick read-only drift report (weekly) and full six-phase, approval-gated consolidation with knowledge ledger + lossless-first remediation ladder |
| `agents/agent-coach.md` | The guide § 5.3 meta-agent: OBSERVE → DIAGNOSE → PROPOSE → [HUMAN APPROVES] → APPLY → MEASURE over the other agents; propose-only by mandate |
| `WORKSPACE_CHANGELOG.md.template` | The per-run audit record, including the "deliberately NOT changed (with reasons)" list |

Together these are exactly the "resident improvement loop" the harmonize track
looks for (guide § 4.4 step 8) — a repo bootstrapped with `--with-meta` has it
out of the box.
