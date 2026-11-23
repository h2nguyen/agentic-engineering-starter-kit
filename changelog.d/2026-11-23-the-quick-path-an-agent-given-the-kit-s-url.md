# The quick path: an agent given the kit's URL

## Added

- The repository's README opens with a note for an AI agent given only the kit's URL ("apply this kit to my project"). It says to clone the kit outside the project, follow `AGENTS.md` in that clone, and fetch `SETUP-PROMPT.md` raw where `git clone` is blocked. `AGENTS.md` says how to get the kit before its first step. ADR-0025.
- `bootstrap.sh --alongside-existing`: installs beside a workspace the project already has, once the user has approved that through the Harmonize track. Existing files are still never overwritten.
- Off Claude Code, with `--alongside-existing`, the installer lists the rules the existing constitution does not link, so no session would read them.
- After a first install, the installer's next steps point an agent at `AGENTS.md`, section "Installing the kit into a project", for the steps the install still owes.

## Changed

- **Breaking — why this release is 4.0.0.** A first install into a repository with agent instructions, rules or skills of its own now stops before writing anything. These count: `CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `.github/copilot-instructions.md`, or files under `.claude/rules`, `.claude/skills`, `.claude/agents`, `.claude/commands`, `.cursor/rules`, `.github/instructions` or `docs/agent-rules`. The message names what it found and points at the Harmonize track. Add `--alongside-existing` to a command that installed into such a repository on 3.1.0. A fresh repository, one with only `.claude/settings.json`, and a re-run on an install of the kit are not affected.
- **Breaking:** `make constitution` fails on a rule under `docs/agent-rules/` that no constitution links, where `.starter-kit-version` records `agents`, `cursor` or `copilot`. On those tools a rule is read only through that link. A fresh install links every rule it installs; one made beside an `AGENTS.md` or `.github/copilot-instructions.md` of your own may not. Link each rule as the template indexes them, or delete the rule.
- `SETUP-PROMPT.md`, pasted into a project without the kit, now clones the kit outside the project and runs its installer. Only where the clone is not possible does it build from its appendix.

## Fixed

- The installer refuses to run from a copy of the kit's repository inside the project it installs into. Run from there, everything installed and linted green, and `git add -A` then committed the copy as an embedded repository. A copy of `starter-kit/` alone at the project's root still works.
