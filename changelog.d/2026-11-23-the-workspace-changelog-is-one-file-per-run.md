# The workspace changelog is one file per run

## Changed

- The record of what changed in your agent workspace — a setup or harmonize pass, a workspace audit, an agent-coach cycle — is now a directory with one file per run: `.claude/workspace-changelog/<date>-<what>.md` on Claude Code, `docs/workspace-changelog/` on the other tools. It was a single `WORKSPACE_CHANGELOG.md` with the newest entry on top, which every run inserted into at the same line; two pull requests open at once conflicted on it, and a day of setup work is easily three. That is the shape the shared-registries rule tells you to remove from your changelog. ADR-0019 records the change.
- `bootstrap.sh --with-meta` installs the directory's `README.md` — naming, reason and entry format — and no longer the single-file skeleton. The entry format gains a `Kit:` field for the installer's version line.
- The workspace-audit skill, its command and the agent-coach read the directory and write each run as a new file in it. The setup prompt's Harmonize track records its run the same way, whether or not the meta layer is installed.
- **If you have a `WORKSPACE_CHANGELOG.md`, keep it.** Nothing migrates it and nothing fails: it is the archive, read for history and not written to. You get the directory at your next installer run with `--with-meta`, and the new wording when you copy the kit's skill, command and coach in upgrade step 2; until then they keep writing to the single file.

## Removed

- `starter-kit/WORKSPACE_CHANGELOG.md.template` from the kit. An installed `WORKSPACE_CHANGELOG.md` is yours and stays.
