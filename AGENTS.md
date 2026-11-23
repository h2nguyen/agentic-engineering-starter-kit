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
that changes a file is run against the target — with the target's path in the
command (`--target`, `git -C`, `make -C`), never by relying on the directory
you happen to be in. This repository is where a session installing the kit
usually starts, so a command that leaves the path out writes here.

**Started in the project, with only this kit's URL?** That is the usual
request: "apply this kit to my project" and a link. Get the kit first, into a
directory outside the project, and run everything below from that clone:

```bash
KIT="$(mktemp -d)/kit" && git clone --depth 1 https://github.com/h2nguyen/agentic-engineering-starter-kit "$KIT"
```

The project is then the directory you were started in: it is the target. Do
not work from the rendered README or a summary of it: read this file in the
clone. Never clone into the project; the installer refuses a kit inside its
target, because committed with the project it becomes an embedded repository.
Where `git clone` is not possible (no network, refused), fetch
`starter-kit/SETUP-PROMPT.md` from `raw.githubusercontent.com` and follow it
instead: it works without the kit.

1. **Know the target.** You need the path of the project's git repository. If
   the user did not give one, ask.
2. **Know the tool.** One of `claude`, `agents`, `cursor`, `copilot`. The
   installer detects it from what the target already has (`.claude/` or
   `CLAUDE.md`, `.cursor/`, `.github/copilot-instructions.md`, `AGENTS.md`).
   If the target has none of these, or the files of more than one, and the
   user did not say, ask. Do not guess: run from an agent, the installer has
   nobody to ask either, and it stops before writing until `--tool` names one.
   The tool you are running in is not the answer: a team may use another.
3. **Look before you install.** If the target already has agent instructions,
   rules or skills of its own, do not run the installer on your own judgement:
   follow the Harmonize track in
   [`starter-kit/SETUP-PROMPT.md`](starter-kit/SETUP-PROMPT.md), which
   preserves what works and needs the user's approval for every change to an
   existing file. The installer stops there too, before it writes anything,
   and names what it found. Add `--alongside-existing` only once the user has
   approved the plan that installs the kit beside those files.
4. **Branch in the target.** Never work on its default branch.
   ```bash
   git -C /path/to/project checkout -b chore/agentic-workspace
   ```
5. **Run the installer from this repository.** It never overwrites a file.
   ```bash
   ./starter-kit/bootstrap.sh --target /path/to/project --tool <tool>
   ```
   On Claude Code, add `--source-paths '<glob>,<glob>'` naming where the
   project's source is (`'src/**,scripts/**'`); ask the user if the
   repository does not make it evident. Without it two rules that are about
   source load into every session
   ([Load classes](starter-kit/README.md#load-classes-of-the-rules-claude-code)).
   Before you run it, ask the user whether they want the weekly feedback digest
   (a scheduled workflow that posts the week's `Agent-Feedback:` lines to an
   issue, with the coach's proposals when an API key is set). Add
   `--with-coach-schedule` only on a yes: run from you, the installer has
   nobody to ask, and leaves it out. Ask the same about the weekly check for
   a newer kit (`--with-upgrade-notice`): it opens an issue when the kit has a
   release newer than the install records, and is the one part of the kit that
   uses the network.
   Read what it prints: which kit it is (the `Kit:` line), what it installed,
   what it skipped because it already existed, and the next steps for this
   particular project.
6. **Fill in what only the project can supply**, in the target:
   - the constitution's `<placeholders>` — the project in one paragraph, its
     stack, and its commands. Run a command before you write it down; leave
     out what does not exist;
   - whose feedback counts, in `.agent-feedback-authors` — ask the user for
     the commit emails and logins; never infer them from the history;
   - `project-annotations.md` beside the rules, the project's half of the
     comments-and-annotations rule: every `<fill in: …>` in it —
     [how](starter-kit/README.md#adopting-the-comments-and-annotations-rule).
     The rule itself is used as shipped; edit nothing in it.
     In the target, `./scripts/python.sh scripts/registry_tool.py list` prints
     the identifier shapes.
7. **Do what the installer said it left to you.** If the project already had a
   Makefile, add the two lines it printed (`registry-test` on that line is
   optional). If it kept an existing changelog or knowledge base, run the
   `adopt` command it printed. If the project already records its decisions
   somewhere the installer could not see, delete the `adr` registry it
   declared from the target's `registries.json` and say in the constitution
   where decisions live; the documentation rule defers to that. If, on Claude Code, it kept an existing
   `.claude/settings.json`, show the user the two hook entries it printed and
   add them only with their approval: that file is theirs.
   If, on Claude Code, a skill it installed duplicates one the user already
   has from elsewhere — an organisation plugin, a user-level skill — say so,
   and with their approval delete the kit's copy and list its path in the
   target's `.starter-kit-declined`. A later run of the installer puts back
   what is missing and not listed there. (One file it holds back beside a
   comments rule that was already there: `project-annotations.md`.)
8. **Verify.** In the target, `make constitution` and then `make lint` must
   each exit 0. `make constitution` is the check on step 6: it names every
   template placeholder still in the constitution or in
   `project-annotations.md`, and every link to a file that does not exist — the template links two example rules, `testing.md`
   and `security.md`; delete the lines unless the project has those files.
   `make lint` does not check either, so it is not enough alone. It must show
   an `OK:` line for each gate and no `FAIL`. A failure names the file, the
   line and the fix;
   [Troubleshooting](starter-kit/README.md#troubleshooting) lists the common ones.
9. **Commit on the branch.** Do not push or open a pull request unless asked.
   If you are asked to push and open the pull request, look at the run that
   follows — the installed workflow starts on a pull request, not on the push
   of a branch. Ask for the target's runs, not this repository's, which has a
   workflow of the same name:
   ```bash
   gh run list --repo <owner>/<repo> --workflow lint.yml --limit 5
   ```
   It must show a completed run that succeeded. A workflow file is not a
   run, and no gate in `make lint` can tell the difference.
   Do not copy `starter-kit/` or clone the kit into the project; if a copy is
   there, leave it out of the commit. The install itself needs no changelog fragment: the
   project's changelog describes the project, not its agent workspace.
10. **Report** which kit was installed (the installer's `Kit:` line; the
    install records the same in `.starter-kit-version`, which is committed
    with it and never edited by hand), what was installed, what you filled in and
    what each fact came from, and what you guessed and want confirmed. Then:
    - what the kit deliberately defers until the project shows a need for it,
      each with a signal that someone or something will notice while the
      deferred artifact does not exist;
    - whether a CI run was seen to succeed, or that CI is not confirmed and
      why (nothing was pushed), and that the default branch needs `lint` as a
      required status check;
    - on Claude Code, which rules are bound to which paths, and that what
      really loads has to be checked in a new session with the
      `rule-load-check` skill: this session cannot see the rules it installed.

Stop and ask the user, instead of deciding yourself, when: the tool is
unknown, or the target has more than one; the target already has an agent workspace; a command you were going
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
make evidence                               # rewrite docs/EVIDENCE.md from the repository; never edit it by hand
starter-kit/kit-status.sh --target /abs/project   # which kit a project records, what is newer here, which of the kit's files differ
scripts/eval-run.sh --cwd /abs/dir --log /abs/log -- <command>   # run one command of an evaluation, recorded
```

### Non-negotiable rules

| Rule | Detail |
|---|---|
| **Git** | Never commit to `main`. Branch prefixes: `feat/`, `fix/`, `docs/`, `chore/` |
| **Test first** | A failing case in the acceptance suite before the change, with a control case where it closes a defect |
| **The installer** | On a first install, stops before writing at a workspace the target already has, until `--alongside-existing` (ADR-0025); never overwrites a file — `.starter-kit-version` included, which only a first install and `kit-status.sh --record` write (ADR-0024); safe to re-run; leaves out what the target's `.starter-kit-declined` lists; every artifact lands for all four tools, or the installer says why not |
| **Dependencies** | Bash and the Python standard library. No packages, no network. Anything the kit runs, and any command it writes down for someone to type, starts Python through `scripts/python.sh`, never as `python3 …` |
| **What the installer copies stands alone** | An installed file is read in a repository that does not contain this one: no path into the kit, or into the rest of this repository. `starter-kit/README.md` and `bootstrap.sh` stay in the kit and may link to the guide |
| **Templates** | A template embedded in the guide is byte-identical to its kit file; change both together |
| **Links** | `Related:`, `Enforces:` and `Hands off to:` lines name artifacts that exist. Run `make graph-impact` before a rename |
| **Changelog** | A fragment per change via `registry_tool.py new --registry changelog`; never edit `CHANGELOG.md` by hand |
| **Decisions** | A decision record via `registry_tool.py new --registry adr`. An accepted record's decision is not edited; a new record supersedes it |
| **Rule files** | 250 lines at most; worked examples go to `starter-kit/rules/reference/` |
| **Nothing speculative** | An artifact ships on day 1 only when waiting for a signal means waiting for one that never comes, and a decision record says so |

### The kit's rules apply here

This repository runs on its own kit (ADR-0022). On Claude Code the rules, the
skills, the `agent-coach` and the workspace-graph hook load from `.claude/`,
whose entries are links into `starter-kit/`. On any other tool, read the rules
where the kit keeps them:
[working principles](starter-kit/rules/working-principles.md),
[documentation](starter-kit/rules/documentation.md),
[comments and annotations](starter-kit/rules/comments-and-annotations.md) with
this repository's half in
[`project-annotations.md`](.claude/rules/project-annotations.md),
[versioning and changelog](starter-kit/rules/versioning-and-changelog.md) and
[shared registries](starter-kit/rules/shared-registries.md).

A rule names paths as an installed project has them. Here they are:

| A rule or skill says | In this repository |
|---|---|
| `./scripts/python.sh scripts/<tool>.py …` | `starter-kit/scripts/python.sh starter-kit/scripts/<tool>.py …` — the make targets are the same here: `make registry-generate`, `make graph-impact NODE=…`, `make agent-feedback` |
| `docs/agent-templates/<template>` | `starter-kit/rules/_rule-template.md`, `starter-kit/skills/_template/SKILL.md`, `starter-kit/agents/_agent-template.md`, `starter-kit/commands/_command-template.md`, `starter-kit/scripts/check-convention.sh.template` |
| `docs/rule-reference/` | `starter-kit/rules/reference/` |
| `.claude/rules/<rule>.md`, `.claude/skills/<skill>/` | The same path, which is a link: edit the kit's file under `starter-kit/` |
| The debugging knowledge base | None here; a registry is declared when it exists |

### Where things are

| Path | What it is |
|---|---|
| [`starter-kit/`](starter-kit/) | Everything that gets installed, and `bootstrap.sh`, which installs it |
| `.claude/` | The kit applied to this repository: links into `starter-kit/`, the hook's registration, and the two things that are this repository's own — `rules/project-annotations.md` and `workspace-changelog/` |
| [`AGENTIC-ENGINEERING-GUIDE.md`](AGENTIC-ENGINEERING-GUIDE.md) | The reasoning: concepts, blueprint, adoption playbook, maintenance |
| [`docs/adr/`](docs/adr/) | Why the kit is the way it is |
| [`changelog.d/`](changelog.d/), [`CHANGELOG.md`](CHANGELOG.md) | One fragment per change; the generated changelog |
| [`scripts/`](scripts/), [`Makefile`](Makefile), [`registries.json`](registries.json) | This repository's own gates — the kit applied to itself — and `eval-run.sh`, the recorder an evaluation runs its commands through |
