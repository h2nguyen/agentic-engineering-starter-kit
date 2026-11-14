# Agent Instructions — Agentic Engineering Starter Kit

This repository is a kit that gets **installed into other repositories**. It
gives a project a constitution, rule files, a debugging knowledge base, a
changelog and decision-record layout, and the lint gates that keep them true,
for Claude Code, `AGENTS.md`-convention tools, Cursor and GitHub Copilot.

You are here for one of three jobs. Work out which before you do anything.

| You were asked to | Go to |
|---|---|
| Set up, install or add this kit in someone's project | [Installing the kit into a project](#installing-the-kit-into-a-project) |
| Move a project to a newer version of the kit | [`starter-kit/README.md` § Upgrading an existing install](starter-kit/README.md#upgrading-an-existing-install) |
| Fix, change or extend the kit itself | [Changing the kit](#changing-the-kit) |

If you were only asked a question about the kit, answer it from
[`README.md`](README.md) and [`AGENTIC-ENGINEERING-GUIDE.md`](AGENTIC-ENGINEERING-GUIDE.md)
and change nothing.

## Installing the kit into a project

The target is the user's project, never this repository. Every command below
that changes a file is run against the target.

1. **Know the target.** You need the path of the project's git repository. If
   the user did not give one, ask.
2. **Know the tool.** One of `claude`, `agents`, `cursor`, `copilot`. The
   installer detects it from what the target already has (`.claude/` or
   `CLAUDE.md`, `.cursor/`, `.github/copilot-instructions.md`, `AGENTS.md`).
   If the target has none of these and the user did not say, ask. Do not guess.
3. **Look before you install.** If the target already has agent instructions,
   rules or skills of its own, do not run the installer on your own judgement:
   follow the Harmonize track in
   [`starter-kit/SETUP-PROMPT.md`](starter-kit/SETUP-PROMPT.md), which
   preserves what works and needs the user's approval for every change to an
   existing file.
4. **Branch in the target.** Never work on its default branch.
   ```bash
   git -C /path/to/project checkout -b chore/agentic-workspace
   ```
5. **Run the installer from this repository.** It never overwrites a file.
   ```bash
   ./starter-kit/bootstrap.sh --target /path/to/project --tool <tool>
   ```
   Read what it prints: what it installed, what it skipped because it already
   existed, and the next steps for this particular project.
6. **Fill in what only the project can supply**, in the target:
   - the constitution's `<placeholders>` — the project in one paragraph, its
     stack, and its commands. Run a command before you write it down; leave
     out what does not exist;
   - the project rows of the comments-and-annotations rule —
     [how](starter-kit/README.md#adopting-the-comments-and-annotations-rule).
     `python3 scripts/registry_tool.py list` prints the identifier shapes.
7. **Do what the installer said it left to you.** If the project already had a
   Makefile, add the two lines it printed (`registry-test` on that line is
   optional). If it kept an existing changelog or knowledge base, run the
   `adopt` command it printed. If, on Claude Code, it kept an existing
   `.claude/settings.json`, show the user the two hook entries it printed and
   add them only with their approval: that file is theirs.
8. **Verify.** In the target, `make lint` must exit 0, with an `OK:` line for
   each gate and no `FAIL`. A failure names the file, the line and the fix;
   [Troubleshooting](starter-kit/README.md#troubleshooting) lists the common ones.
9. **Commit on the branch.** Do not push or open a pull request unless asked.
   Do not copy `starter-kit/` into the project; if a copy is there, leave it
   out of the commit. The install itself needs no changelog fragment: the
   project's changelog describes the project, not its agent workspace.
10. **Report** what was installed, what you filled in and what each fact came
    from, what you guessed and want confirmed, and what the kit deliberately
    defers until the project shows a need for it.

Stop and ask the user, instead of deciding yourself, when: the tool is
unknown; the target already has an agent workspace; a command you were going
to document does not run; or a step would overwrite or delete a file that was
there before you.

For a setup that also mines the project's history for its conventions, use
[`starter-kit/SETUP-PROMPT.md`](starter-kit/SETUP-PROMPT.md) as the
instructions of a session started at the project's root.

## Changing the kit

Read [`CONTRIBUTING.md`](CONTRIBUTING.md) first. It has the workflow, the test
suites and the checklist for adding anything the installer ships.

### Commands

```bash
make lint                                   # everything CI runs; must pass before any PR
make kit-smoke                              # install into a throwaway repo and run its lint
make registry-generate                      # rebuild CHANGELOG.md from changelog.d/
make graph-impact NODE=RULE:documentation   # what cites an artifact — before renaming or deleting it
```

### Non-negotiable rules

| Rule | Detail |
|---|---|
| **Git** | Never commit to `main`. Branch prefixes: `feat/`, `fix/`, `docs/`, `chore/` |
| **Test first** | A failing case in the acceptance suite before the change, with a control case where it closes a defect |
| **The installer** | Never overwrites a file; safe to re-run; every artifact lands for all four tools, or the installer says why not |
| **Dependencies** | Bash and the Python standard library. No packages, no network. Anything the kit runs starts Python through `scripts/python.sh`, never as `python3 …` |
| **What the installer copies stands alone** | An installed file is read in a repository that does not contain this one: no path into the kit, or into the rest of this repository. `starter-kit/README.md` and `bootstrap.sh` stay in the kit and may link to the guide |
| **Templates** | A template embedded in the guide is byte-identical to its kit file; change both together |
| **Links** | `Related:`, `Enforces:` and `Hands off to:` lines name artifacts that exist. Run `make graph-impact` before a rename |
| **Changelog** | A fragment per change via `registry_tool.py new --registry changelog`; never edit `CHANGELOG.md` by hand |
| **Decisions** | A decision record via `registry_tool.py new --registry adr`. An accepted record's decision is not edited; a new record supersedes it |
| **Rule files** | 250 lines at most; worked examples go to `starter-kit/rules/reference/` |
| **Nothing speculative** | An artifact ships on day 1 only when waiting for a signal means waiting for one that never comes, and a decision record says so |

### Where things are

| Path | What it is |
|---|---|
| [`starter-kit/`](starter-kit/) | Everything that gets installed, and `bootstrap.sh`, which installs it |
| [`AGENTIC-ENGINEERING-GUIDE.md`](AGENTIC-ENGINEERING-GUIDE.md) | The reasoning: concepts, blueprint, adoption playbook, maintenance |
| [`docs/adr/`](docs/adr/) | Why the kit is the way it is |
| [`changelog.d/`](changelog.d/), [`CHANGELOG.md`](CHANGELOG.md) | One fragment per change; the generated changelog |
| [`scripts/`](scripts/), [`Makefile`](Makefile), [`registries.json`](registries.json) | This repository's own gates — the kit applied to itself |
