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

Nothing to install: `git`, `make`, `bash` 3.2+ and `python3` 3.9+.

| Command | What it does |
|---|---|
| `make lint` | Everything CI runs: this repository's gates, the unit tests and the acceptance suites. About two minutes |
| `make kit-smoke` | Installs the kit into a throwaway repository and runs *its* `make lint` |
| `make registry-generate` | Rebuilds `CHANGELOG.md` from `changelog.d/` |
| `make graph-impact NODE=RULE:documentation` | What cites an artifact — run it before renaming or deleting one |
| `make graph-coverage` | Which shipped rules a script enforces and an agent reviews |

## Making a change

1. **Branch.** `feat/`, `fix/`, `docs/` or `chore/`. Never commit to `main`.
2. **Write the failing test first.** For a gate or a script, that is a case in
   its acceptance suite — and where the change closes a defect, a control case
   that reproduces the defect on the old shape, so the test cannot pass
   vacuously. Run it and watch it fail.

   | Suite | Covers |
   |---|---|
   | `starter-kit/scripts/tests/test_registry_tool.py`, `test_graph_tool.py` | The two tools, unit level |
   | `test-parallel-merge.sh` | Two branches add registry entries and merge clean and green |
   | `test-graph-links.sh` | A typed link to nothing fails; a rename names every citer |
   | `test-ci-lint-coverage.sh` | A gate CI never runs is detected |
   | `test-bootstrap-rerun.sh` | The installer: all four tools, re-runs, what lands where |
   | `test-graph-hooks.sh` | The Claude Code hook: what it says after an edit and at the end of a turn, and that it is silent otherwise |
   | `test-brownfield-adoption.sh` | Installing into a repository that already has registries |

3. **Make the change.**
4. **Add a changelog fragment**, written for the adopter — what they will
   observe after upgrading, not what you did:
   ```bash
   python3 starter-kit/scripts/registry_tool.py new --registry changelog --title "<the change>"
   make registry-generate
   ```
5. **Record a decision** when the change is one — a new day-1 default, a rule
   deliberately left ungated, a rejected alternative worth remembering:
   ```bash
   python3 starter-kit/scripts/registry_tool.py new --registry adr --title "<the decision>"
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
| `registry-drift`, `registry-ids` | `CHANGELOG.md` matches its fragments; identifiers are well-shaped and unique |
| `ci-lint-coverage` | Every check in `make lint` really runs in CI |

## Adding to what the installer ships

| You add | Also change |
|---|---|
| A default rule | `DEFAULT_RULES` in `bootstrap.sh`; the index and table in `constitution.md.template` (and the guide's embedded copy); the `starter-kit/README.md` table |
| A gate | The script, with an `# Enforces: RULE:<name>` header; a target in `registry.mk`; the `lint:` line in `Makefile.template` and in this repository's `Makefile`; an install line in `bootstrap.sh`; an acceptance test with a control case; the `starter-kit/README.md` table |
| A hook | The file under `starter-kit/hooks/`; its entry in `settings.json.template` and in the guide's embedded copy; an install line in `bootstrap.sh`, Claude Code only; a case for each thing it says and each way it stays silent in `test-graph-hooks.sh`; the README section. A hook that adds context never blocks, never edits and ends silent when it cannot run |
| A skill or agent | A self-contained directory or file — no path into the rest of the kit; an install line in `bootstrap.sh`; `skills/common-catalog.md`; the README tables |
| A template | The kit file and the guide's embedded copy, together |

Four invariants every such change keeps, each with a test behind it:

- **The installer never overwrites a file and is safe to re-run.**
- **Every artifact lands for all four tools**, or the installer says why not.
- **Bash and the Python standard library only.** No packages, no network.
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

## Releasing

A release promotes `[Unreleased]` into a version section and consumes the
fragments. New functionality is a MINOR bump, a fix-only release a PATCH.

```bash
git checkout -b release/<X.Y.Z>
python3 starter-kit/scripts/registry_tool.py release --registry changelog --version <X.Y.Z>
make lint
```

Commit as `release: promote [Unreleased] to <X.Y.Z>`, open the pull request,
and tag the merge commit `v<X.Y.Z>`. A released section is immutable: an error in it is
corrected by a bullet under the next `[Unreleased]`, never by an edit.
