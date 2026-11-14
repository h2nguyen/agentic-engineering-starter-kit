# Hardening from applying the kit with a small model

## Added

- `bootstrap.sh` installs the templates a workspace grows from — a new rule, check script, skill, reviewer agent and (on Claude Code) command — to `docs/agent-templates/`, for every tool. They are never loaded into a session and the link gate reads them as scaffolding. Until now they stayed in the kit, where a later session could not find them.
- The documentation rule's "what to update when" table says which template to start from and what each artifact must carry, including two links that are easy to leave out: a new rule cites the incident behind it, and the incident's entry names the rule or check that now prevents it.

## Changed

- The quick start runs the installer from a checkout of the kit with `--target`, so nothing but the installed files lands in your repository. The kit is an installer, not a dependency: a copy made inside the repository is deleted after the install, not committed.
- `init` writes `"id_scheme"` on the knowledge base and the decision records instead of leaving it inherited, and the top-level default stays `slug`.
- The knowledge-base template's `Related:` line is a placeholder to fill in or delete; an entry that copies it unfilled fails the link gate. It used to ship `RULE:working-principles`, which adopters kept as it was.
- A link line follows a rename even inside an accepted decision record — it is a pointer, not part of the decision. `.graph-link-allowlist` is for a record citing something that was retired. The documentation rule, the gate's failure message and the workspace-graph skill all say so.
- The setup prompt says who edits an existing Makefile (the adopter, not the installer), what to do with the SessionStart hook skeleton on Claude Code, and to leave the kit directory out of the commit; the README says what `<TICKET-ID>` is where there is no tracker.
- The kit's unit tests run with `python3 -B` and unittest's `-b`.

## Fixed

- `bootstrap.sh` printed `SKIPPED[@]: unbound variable` twice on every fresh install under bash 3.2 (macOS), and still exited 0.
- `registry_tool.py init` told a brand-new repository to run `adopt` on the changelog template it had just been given.
- `init` announced "MADR naming adr-NNNN" for decision records while the config it wrote produces `ADR-<date>-<slug>`.
- `init` gave a repository with numbered decision records and no knowledge base yet a numeric knowledge base, by deriving the top-level scheme from the registries.
- `init` wrote `rule_pointer` as `.claude/rules/shared-registries.md` for every tool, so on the layouts that keep rules in `docs/agent-rules/` every gate failure pointed at a file that was not there.
- The kit's tools left `scripts/__pycache__/` and `scripts/tests/__pycache__/` in the adopting repository, which gets no `.gitignore` from the kit.
- A passing `make lint` printed the unit tests' expected `FAIL` lines, and a stray `find` error from the parallel-merge test.
- Re-running `bootstrap.sh` — as `--with-meta` does — told a repository already in the fragment layout to run `adopt`.
- `registry_tool.py list` printed an identifier shape for the changelog, which has none.
