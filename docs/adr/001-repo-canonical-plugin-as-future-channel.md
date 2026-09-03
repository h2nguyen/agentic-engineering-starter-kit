# ADR-001: The repository is canonical; an agent plugin is a future distribution channel

## Status

Accepted

## Context

This project ships two kinds of content with **opposite distribution needs**:

- **Portable tools** — the skills (semver, prompt-enhancer, workspace-audit),
  the agent-coach subagent, the audit command. Identical in every project,
  benefit from central versioning and one-command installation.
- **Project-resident scaffolding** — the constitution, rule files, the
  debugging knowledge base, enforcement scripts. These must be committed and
  PR-reviewed *inside the adopting repo*, become project-specific once filled
  in, accumulate project history, and are consumed by that project's CI.

Agentic coding tools (e.g. Claude Code) offer plugin systems that bundle
skills, agents, commands and hooks into an installable, centrally-updatable
unit. The question is whether this project should become such a plugin.

Three options were weighed:

- **Plugin-first (plugin is the primary artifact).** A plugin is tool-specific,
  which breaks the project's tool-agnostic commitment (guide
  § 3.10 — Claude Code, `AGENTS.md`-convention tools, Cursor, GitHub Copilot).
  It also cannot host the scaffolding: guardrails only bite when the rules and
  enforcement scripts live in the adopting repo and its CI runs them
  (guide § 1.2, principle P3).
- **Split the source of truth (skills in a plugin, scaffolding in the repo).**
  Two homes drift apart, and the guide's own anti-pattern table
  names duplicated-and-drifting content as a failure mode.
- **Build the plugin now, alongside the repo.** Runs against the project's
  own doctrine: no consumer exists yet, and speculative artifacts are
  maintenance load (guide § 4.5).

## Decision

**The repository stays canonical. A plugin is a future *distribution channel*
for the portable half only — never the home of the project.**

Concretely: installation paths remain (1) paste `SETUP-PROMPT.md` into an agent
session, (2) run `bootstrap.sh`, (3) manual copy. A plugin, if built later,
becomes a fourth path that ships the portable tools plus a setup command which
writes the project-resident scaffolding into the target repo.

## Consequences

**Easier:** the kit stays usable by any agentic tool; the scaffolding lands
where CI and code review can act on it; there is exactly one source of truth.

**Harder:** adopting the portable tools in a new project means vendoring or
re-running the installer rather than a single central install — accepted cost
until the trigger below fires.

**To keep conversion cheap**, two invariants hold from now on:

1. **Self-containment** — every portable artifact must be copyable on its own
   (a skill directory carries its own references/scripts/tests; an agent is a
   single file). Stated in `starter-kit/README.md`.
2. **Reference hygiene** — inside a portable artifact, prefer naming a
   companion artifact over hard-coding its repository path. Target-*project*
   paths (e.g. where the audit writes its changelog) stay explicit; they remain
   correct under any distribution model.

**Trigger to revisit** (build the plugin when either fires):

- the kit is adopted in **3 or more projects**, or
- a portable artifact is **re-vendored by hand a third time**.

At that point the seam above is already drawn, so conversion is mechanical.
