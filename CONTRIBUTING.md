# Contributing to the starter kit

For people changing the kit itself. To install it into a project, start at the
[README](README.md); an AI agent starts at [`AGENTS.md`](AGENTS.md).

## Two halves

| Path | What it is | Who reads it |
|---|---|---|
| `starter-kit/` | Everything the installer copies into another repository | Someone else's agent, in a repository you will never see |
| Everything else | The guide, this repository's decision records, changelog, `Makefile` and `scripts/` — the kit applied to itself | You |

A file the installer copies has to work without this repository around it.
That is the first thing to check about any change there. (`starter-kit/README.md`
and `bootstrap.sh` are read in the kit, so they may point at the guide.)

## Commands

Nothing to install: `git`, `make`, `bash` 3.2+ and Python 3.9+, under whatever
name your machine gives it — the make targets find it through
`starter-kit/scripts/python.sh`.

| Command | What it does |
|---|---|
| `make lint` | Everything CI runs: this repository's gates, the unit tests and the acceptance suites. About three minutes |
| `make kit-smoke` | Installs the kit into a throwaway repository and runs *its* `make lint` |
| `make registry-generate` | Rebuilds `CHANGELOG.md` from `changelog.d/` |
| `make graph-impact NODE=RULE:documentation` | What cites an artifact — run it before renaming or deleting one |
| `make graph-coverage` | Which shipped rules a script enforces and an agent reviews |
| `make agent-feedback` | Every `Agent-Feedback:` line in this repository's history, grouped by the kit artifact it names (ADR-0016) |

## Making a change

1. **Branch.** `feat/`, `fix/`, `docs/` or `chore/`. Never commit to `main`.
2. **Write the failing test first.** For a gate or a script, that is a case in
   its acceptance suite — and where the change closes a defect, a control case
   that reproduces the defect on the old shape, so the test cannot pass
   vacuously. Run it and watch it fail.

   | Suite | Covers |
   |---|---|
   | `starter-kit/scripts/tests/test_registry_tool.py`, `test_graph_tool.py`, `test_feedback_tool.py` | The three tools, unit level — for the feedback collector, that an unlisted author's text never reaches its report |
   | `test-parallel-merge.sh` | Two branches add registry entries and merge clean and green |
   | `test-graph-links.sh` | A typed link to nothing fails; a rename names every citer |
   | `test-python-launcher.sh` | `scripts/python.sh` finds Python as `python3`, `python` or `py -3`, and skips a name that is not Python |
   | `test-ci-lint-coverage.sh` | A gate CI never runs is detected: which workflows count, which directory a step runs in, which installed gates lint must reach |
   | `test-constitution.sh` | `check-constitution.sh`: a dead link and an unfilled placeholder fail; the angle brackets that belong in a constitution do not |
   | `test-bootstrap-rerun.sh` | The installer: all four tools, re-runs, what lands where, and which tool it installs for when it is not told |
   | `test-upgrade.sh` | The README's upgrade steps, run as written on an older install an adopter customized: theirs stays theirs, the kit's becomes the newer kit's, lint ends green. Also `upgrade-rules.sh`: a rule's text is compared and replaced under its `paths:` header |
   | `test-graph-hooks.sh` | The Claude Code hook: what it says after an edit and at the end of a turn, and that it is silent otherwise |
   | `test-brownfield-adoption.sh` | Installing into a repository that already has registries |
   | `scripts/tests/test-eval-run.sh` | `scripts/eval-run.sh`, this repository's evaluation recorder (below) |
| `scripts/tests/test-self-application.sh` | `check-self-application.sh`: a kit rule with no link here, a link that became a copy or points elsewhere, and a hook that cannot find the graph tool each fail |

3. **Make the change.**
4. **Add a changelog fragment**, written for the adopter — what they will
   observe after upgrading, not what you did:
   ```bash
   starter-kit/scripts/python.sh starter-kit/scripts/registry_tool.py new --registry changelog --title "<the change>"
   make registry-generate
   ```
5. **Record a decision** when the change is one — a new day-1 default, a rule
   deliberately left ungated, a rejected alternative worth remembering:
   ```bash
   starter-kit/scripts/python.sh starter-kit/scripts/registry_tool.py new --registry adr --title "<the decision>"
   ```
6. **Run `make lint` and `make kit-smoke`.** Commit with a Conventional Commits
   subject that says what is now true, and a body that says why.

## What the gates hold together

`make lint` fails when two things that must agree stop agreeing. Fix the
cause; none of these has a quiet override.

| Gate | Holds |
|---|---|
| `guide-templates` | Every template the guide embeds is byte-identical to its kit file. Change the kit file, then paste it into the guide |
| `graph-links` | Every `Related:`, `Enforces:` and `Hands off to:` line names an artifact that exists |
| `rule-budget` | Every rule file the kit ships stays under 250 lines; worked examples go to `starter-kit/rules/reference/` |
| `documented-commands` | No command the kit or this repository writes down for someone to type starts Python as `python3 …`; each goes through `scripts/python.sh` or a make target (ADR-0013) |
| `registry-drift`, `registry-ids` | `CHANGELOG.md` matches its fragments; identifiers are well-shaped and unique |
| `ci-lint-coverage` | Every check in `make lint` is invoked by a CI workflow step. It reads the workflow files; that a run completed is seen on the pull request, not here (ADR-0019) |
| `self-application` | Every rule, skill, agent and command the kit ships is linked under `.claude/`, never copied, and the workspace-graph hook is registered there with `--tool` (ADR-0022). The failure prints the `ln -s` to run |
| `constitution` | `AGENTS.md` and `CLAUDE.md` link only to files that exist. The kit ships this check unchained (ADR-0009); this repository chains it |

## Adding to what the installer ships

| You add | Also change |
|---|---|
| A default rule | If it is about particular files, its `bind_rule` line in `bootstrap.sh` and its row in the README's load-class table; `DEFAULT_RULES` in `bootstrap.sh`; the index and table in `constitution.md.template` (and the guide's embedded copy); the `starter-kit/README.md` table; its link under `.claude/rules/` (the `self-application` gate prints the command) |
| A gate | The script, with an `# Enforces: RULE:<name>` header; a target in `registry.mk`; the `lint:` line in `Makefile.template` and in this repository's `Makefile`; an install line in `bootstrap.sh`; the gate list in `check-ci-lint-coverage.sh` and in the installer's "does not reach" message; an acceptance test with a control case; the `starter-kit/README.md` table; the `lint:` line `test-upgrade.sh` edits in step 5. A gate that is on by default is a MAJOR release (ADR-0008) — ship it unchained first, as `constitution` was |
| A suite that needs `bootstrap.sh` | The `find` exclusions in `install_tree`, and the `rm -f` line of the README's upgrade step 2 — `test-upgrade.sh` fails when one is missing from either |
| A hook | The file under `starter-kit/hooks/`; its entry in `settings.json.template` and in the guide's embedded copy; an install line in `bootstrap.sh`, Claude Code only; a case for each thing it says and each way it stays silent in `test-graph-hooks.sh`; the README section. A hook that adds context never blocks, never edits and ends silent when it cannot run |
| A skill or agent | A self-contained directory or file — no path into the rest of the kit; an install line in `bootstrap.sh`; `skills/common-catalog.md`; the README tables; its link under `.claude/` (the `self-application` gate prints the command) |
| A template | The kit file and the guide's embedded copy, together |

Four invariants every such change keeps, each with a test behind it:

- **The installer never overwrites a file and is safe to re-run.** A re-run
  adds what is missing, except a path the adopter listed in
  `.starter-kit-declined` (ADR-0014), and except `project-annotations.md`
  beside a comments rule that was already there (ADR-0017).
- **Every artifact lands for all four tools**, or the installer says why not.
- **Bash and the Python standard library only.** No packages, no network.
- **Python is never started by a fixed name.** A make target, a gate, a test,
  a hook command, and a command written down in a rule, a skill or a README
  for someone to type: each goes through `scripts/python.sh`. `python3` is not
  Python on every machine, and `test-bootstrap-rerun.sh` runs a whole fresh
  install on a machine where it is not.
- **Nothing speculative.** An artifact ships on day 1 only when waiting for a
  signal would mean waiting for one that never comes; that argument goes in a
  decision record (see ADR-0002 and ADR-0004).

## Evaluating a change by applying the kit

The tests prove the mechanism. Whether an agent can *use* it is a different
question, and the cheapest way to answer it is to hand the kit to a small
model and watch where it guesses. The workspace-graph release was hardened
this way; the recipe:

1. Export the committed tree (`git archive HEAD`) into a scratch directory.
   Use a fresh copy and a fresh `git init` per experiment.
2. Give a small model one task at a time, in plain words, with the repository
   path and nothing else — no explanation of the kit. Start a fresh agent per
   task, so each begins from the repository alone, as a new session would.
   **Start it in the scratch directory, not in this checkout**, and where the
   tool that runs the agent takes a working directory per command, set it on
   every command.
3. After each task, run `make lint` yourself and read the diff. Ask the agent
   for every command it ran and every place it guessed; the guesses are the
   findings.
4. Classify each finding: kit defect, missing guidance, model limitation, or
   environment. Fix the first two here, test first, and rerun the task from a
   fresh copy.

Three things that distorted results until they were controlled for:
`PYTHONDONTWRITEBYTECODE` set in the shell hid bytecode the tools left behind;
the agent's session showed this repository's recent commit subjects, which
gave away one answer; and a scratch copy cloned from an earlier run carried
that run's finished branch.

### Running the commands, and keeping what they printed

A fourth was not a distortion but a breach. An agent told in prose to work
only in the scratch project ran its first build command with no working
directory. It inherited this checkout as its default and wrote two files into
it. And what the run left as evidence was a summary of the commands, not their
output. An instruction is not a boundary, and a summary is not a record.

So the commands **you** run in an evaluation — the independent tests, the
gates, the probes — go through `scripts/eval-run.sh`:

```bash
scripts/eval-run.sh --cwd /abs/scratch/project --log /abs/scratch/log \
    --guard "$PWD" --label "independent acceptance tests" -- \
    ./scripts/python.sh -B /abs/scratch/evaluator/test_acceptance.py .
```

| It does | So that |
|---|---|
| Refuses to run without `--cwd`, and refuses a relative or missing one | No command runs in "wherever the session happened to be" |
| Appends a record to `<log>/commands.jsonl` — command, cwd, start and end in UTC, exit status, outcome — and keeps stdout and stderr in a file each | The report can quote the output, and a reader can tell what was observed from what an agent said it did |
| `--expect fail` records `expected-fail`, and `unexpected-pass` if the command passes | A negative test is labelled as one, and a broken one is not mistaken for a pass |
| `--guard <dir>`: compares every file under the directory, and a checkout's HEAD and branch, before and after; a change fails the run with exit 97 and lists the paths | A stray write into this checkout is caught by the command that made it, not found at the end |

**What it does not do.** It does not stop a write: a guard reports that a
directory changed, after it changed. And it sees only the commands you pass
it — an agent's own tool calls go wherever the agent's harness sends them.
Keeping an agent out of this checkout is the harness's job: start it in the
scratch directory, give it no path here, and where the harness can confine a
session — a container, another user, a read-only mount — use that. Then guard
this checkout on your own commands anyway, record `git status --short` here
before the first task and after the last, and put both in the report. Say in
the report which of these you had: "guarded and found unchanged" is a
different claim from "isolated".

In the report, keep three things apart: what a command recorded here printed,
what an agent reported about itself, and what was inferred. Only the first is
an observation. Name the model and its settings exactly as they were run;
a single guided run with no baseline shows that the workflow can be followed,
not that the kit caused the result.

## Releasing

A release promotes `[Unreleased]` into a version section and consumes the
fragments. New functionality is a MINOR bump, a fix-only release a PATCH. A
release is MAJOR when a repository that passed `make lint` on the previous
version and follows the upgrade steps fails it, or has to edit a file of its
own — a gate that is on by default and can fail what passed before, a changed
format (ADR-0008). Mark each such bullet **Breaking** in its fragment, and
give the release commit a `BREAKING CHANGE:` footer.

```bash
git checkout -b release/<X.Y.Z>
starter-kit/scripts/python.sh starter-kit/scripts/registry_tool.py release --registry changelog --version <X.Y.Z>
make lint
```

Commit as `release: promote [Unreleased] to <X.Y.Z>`, open the pull request,
and tag the merge commit `v<X.Y.Z>`. A released section is immutable: an error in it is
corrected by a bullet under the next `[Unreleased]`, never by an edit.
