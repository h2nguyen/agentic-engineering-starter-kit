# Hardening from applying the kit with a small model

## Added

- `bootstrap.sh` installs the templates a workspace grows from — a new rule, check script, skill, reviewer agent and (on Claude Code) command — to `docs/agent-templates/`, for every tool. They are never loaded into a session and the link gate reads them as scaffolding. Until now they stayed in the kit, where a later session could not find them.
- The documentation rule's "what to update when" table says which template to start from and what each artifact must carry, including two links that are easy to leave out: a new rule cites the incident behind it, and the incident's entry names the rule or check that now prevents it.

- `docs/rule-reference/`, installed for every tool: the worked examples of the comments-and-annotations rule and the gotcha write-ups of the shared-registries rule. They are read when a rule points at them and are never loaded by default.
- `AGENTS.md` at the root of the kit's repository, and a `CLAUDE.md` that imports it. An agent pointed at a checkout of the kit learns from it how to install the kit into a project step by step, when to stop and ask, and what the rules are for changing the kit itself.
- `CONTRIBUTING.md` for people changing the kit: the workflow, the test suites, what each gate holds together, the checklist for adding anything the installer ships, and the release procedure.
- `starter-kit/README.md` gains Requirements, **Upgrading an existing install** and a Troubleshooting table that maps each `make lint` failure to its fix. The upgrade steps say which files the kit owns and are copied, which one rule is merged because it carries your fill-ins, and which files are yours and never replaced, with a command for each that lists what differs — so they work from whichever version a repository was installed from.
- ADR-0005 records why the templates and the rule references install on day 1 although nothing reads them that day.

## Changed

- The quick start runs the installer from a checkout of the kit with `--target`, so nothing but the installed files lands in your repository. The kit is an installer, not a dependency: a copy made inside the repository is deleted after the install, not committed.
- `init` writes `"id_scheme"` on the knowledge base and the decision records instead of leaving it inherited, and the top-level default stays `slug`.
- The knowledge-base template's `Related:` line is a placeholder to fill in or delete; an entry that copies it unfilled fails the link gate. It used to ship `RULE:working-principles`, which adopters kept as it was.
- A link line follows a rename even inside an accepted decision record — it is a pointer, not part of the decision. `.graph-link-allowlist` is for a record citing something that was retired. The documentation rule, the gate's failure message and the workspace-graph skill all say so.
- The setup prompt says who edits an existing Makefile (the adopter, not the installer), what to do with the SessionStart hook skeleton on Claude Code, and to leave the kit directory out of the commit; the README says what `<TICKET-ID>` is where there is no tracker.
- The comments-and-annotations rule is 242 lines instead of 408, and the shared-registries rule 189 instead of 260. Nothing was deleted: the illustrations moved, verbatim, to `docs/rule-reference/`, and each rule names its reference. On an upgrade, merge these two rules rather than copying them — yours carries your project's fill-ins — and resolve the same pointers in the reference file.
- The agent-coach says where its proposal log is (the workspace changelog), and defines its "Gap" verdict and what counts as a rule change worth a cycle. The workspace-audit skill says which tool loads rule files always, where a relocated reference goes, that a coherent rule stays whole above its line target, how to prove a relocation lossless, and what the verification dry run is.
- Re-running `bootstrap.sh` in a repository that already has the kit says that it only added what was missing and changed no existing file, names the upgrade steps, and no longer repeats the first-install steps. Where the repository keeps its own Makefile, it names each gate the `lint` target does not reach — after an upgrade, the gate the newer kit added — instead of checking for the first gate alone. Its next steps tell a first install to delete the constitution template's example rows, commands and links that the project has no counterpart for, name the common-skills catalog by its full path in the kit, and say that `registry-test` is the target to add when a repository with its own Makefile wants the kit's suites in its lint.
- The typed-link table in the documentation rule says what the gate checks — a hand-off to a rule, a document or a registry entry is rejected — and that what an `Enforces` line names is a convention.
- The constitution template's `make graph-impact` example names `RULE:documentation`, which every install has, instead of a testing rule that is not installed.
- The command for finding your project's comment markers runs unchanged in zsh, and the adoption notes say what to write when it finds none. The README no longer asks for a `chmod +x` the installer has already done, and says when to keep the SessionStart hook entry.
- The kit's unit tests run with `python3 -B` and unittest's `-b`.
- The two suites that test the installer itself (`test-bootstrap-rerun.sh`, `test-brownfield-adoption.sh`) are no longer installed into your repository, where they could only print `SKIP` on every lint run. A repository that already has them can delete both and drop their two lines from `registry.mk`.

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
- On a fresh install, `init` described the changelog and the knowledge base the installer had just created as files the repository "already" had.
- The first `make lint` of a brand-new repository reported its changelog as "non-canonical after a merge". The installed `CHANGELOG.md` now carries the region the generator writes for an empty changelog. A repository installed earlier can run `make registry-generate` once.
- Run from the root of the kit's own repository with no `--target`, `bootstrap.sh` would install the kit into itself. It now refuses and says to name the repository to install into. A project that holds a copy of `starter-kit/` still installs with no argument.
