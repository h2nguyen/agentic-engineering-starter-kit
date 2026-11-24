# Changelog

All notable changes to this project are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) — the same
conventions this kit ships as a default rule.

The `[Unreleased]` section is generated from `changelog.d/`. Add a bullet by
creating a file there rather than editing this file:

```bash
starter-kit/scripts/python.sh starter-kit/scripts/registry_tool.py new --registry changelog \
  --category added --title "What an operator will observe"
make registry-generate
```

Released sections are immutable — errata go under a new `[Unreleased]` bullet.

## [Unreleased]

<!-- BEGIN GENERATED: changelog — do not edit inside this region. Add a file under changelog.d/ and run `make registry-generate`. -->

<!-- category: Added -->

<!-- category: Changed -->

<!-- category: Deprecated -->

<!-- category: Removed -->

<!-- category: Fixed -->

<!-- category: Security -->

<!-- END GENERATED: changelog -->

## [4.1.0] — 2026-11-23

<!-- category: Added -->
### Added

- The coach step of the weekly digest (`--with-coach-schedule`) runs on a `CLAUDE_CODE_OAUTH_TOKEN` repository secret when there is no `ANTHROPIC_API_KEY`. Make the token with `claude setup-token` on a Claude Pro, Max, Team or Enterprise plan and add it as a secret. The API key wins where both are set, and the log of the run says which credential the coach used. With neither secret, the coach is skipped and the log names both. Until now only an API key worked, so on a subscription the digest posted and the coach never ran. ADR-0026 records the decision.
- The token belongs to the person who made it: the coach's runs count against their usage, and it stops when their access does. For a team, prefer a key. This covers a Claude subscription only; a subscription of another tool does not run this coach.

<!-- category: Changed -->
### Changed

- The installer's question, its closing message and the kit README name both secrets. The comment in the workflow that said to swap the credential by hand is gone.
- **Your existing install is not changed**: the installer never replaces a workflow. To take it, copy the "Is the coach configured?" and "Coach proposals" steps from the kit's `ci/agent-feedback.yml.template`, or change the two inputs of the action by hand.

<!-- category: Deprecated -->

<!-- category: Removed -->

<!-- category: Fixed -->

<!-- category: Security -->

## [4.0.0] — 2026-11-23

<!-- category: Added -->
### Added

- The repository's README opens with a note for an AI agent given only the kit's URL ("apply this kit to my project"). It says to clone the kit outside the project, follow `AGENTS.md` in that clone, and fetch `SETUP-PROMPT.md` raw where `git clone` is blocked. `AGENTS.md` says how to get the kit before its first step. ADR-0025.
- `bootstrap.sh --alongside-existing`: installs beside a workspace the project already has, once the user has approved that through the Harmonize track. Existing files are still never overwritten.
- Off Claude Code, with `--alongside-existing`, the installer lists the rules the existing constitution does not link, so no session would read them.
- After a first install, the installer's next steps point an agent at `AGENTS.md`, section "Installing the kit into a project", for the steps the install still owes.

<!-- category: Changed -->
### Changed

- **Breaking — why this release is 4.0.0.** A first install into a repository with agent instructions, rules or skills of its own now stops before writing anything. These count: `CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `.github/copilot-instructions.md`, or files under `.claude/rules`, `.claude/skills`, `.claude/agents`, `.claude/commands`, `.cursor/rules`, `.github/instructions` or `docs/agent-rules`. The message names what it found and points at the Harmonize track. Add `--alongside-existing` to a command that installed into such a repository on 3.1.0. A fresh repository, one with only `.claude/settings.json`, and a re-run on an install of the kit are not affected.
- **Breaking:** `make constitution` fails on a rule under `docs/agent-rules/` that no constitution links, where `.starter-kit-version` records `agents`, `cursor` or `copilot`. On those tools a rule is read only through that link. A fresh install links every rule it installs; one made beside an `AGENTS.md` or `.github/copilot-instructions.md` of your own may not. Link each rule as the template indexes them, or delete the rule.
- `SETUP-PROMPT.md`, pasted into a project without the kit, now clones the kit outside the project and runs its installer. Only where the clone is not possible does it build from its appendix.

<!-- category: Deprecated -->

<!-- category: Removed -->

<!-- category: Fixed -->
### Fixed

- The installer refuses to run from a copy of the kit's repository inside the project it installs into. Run from there, everything installed and linted green, and `git add -A` then committed the copy as an embedded repository. A copy of `starter-kit/` alone at the project's root still works.

<!-- category: Security -->

## [3.1.0] — 2026-11-23

<!-- category: Added -->
### Added

- `.starter-kit-declined`: a list you write at the root of your repository, one path per line with an optional `# reason`. The installer leaves a listed file out, and a listed directory with everything beneath it — on a first install and on every re-run — and reports each under "Skipped" as declined. Until now a file of the kit's that you had deleted came back with the next run, because the installer adds whatever is missing and cannot tell "deleted on purpose" from "new in this kit". Use it for a skill your organisation already ships as a plugin, a suite you do not run, a template you do not want. The installer never creates or edits the list. See "Declining what the kit installs" in the kit README, and ADR-0014.
- The installer prints which kit it is, as a `Kit:` line: the last release in the kit's changelog and, from a checkout, the commit. Nothing in your repository records the kit an install came from (ADR-0011), so the handoff copies that line. A bare copy of `starter-kit/` inside a project says the version is not recorded.
- On Claude Code, `docs/agent-templates/session-start.sh.template`: the SessionStart hook skeleton, with the steps to put it in place and the `settings.json` entry in its header.
- An `Agent-Feedback: <token> — <what went wrong and why>` line, written in a commit message or a pull-request or issue comment, records a correction to the rule, skill, agent or command that caused it. The documentation rule describes it, and tells the agent to offer the line when you correct it. Corrections no longer end with the chat session they were made in.
- `make agent-feedback` (`scripts/feedback_tool.py collect`) reads those lines from the commit history, and from a JSON comment export with `FROM=<file>`, and prints one JSON report grouped by artifact. Tokens that name nothing are listed as unresolved. It is a report, not a gate, and runs offline on every tool. A fresh install gets it; an existing one gets it from upgrade steps 1 and 2.
- `.agent-feedback-authors`, at the repository root, lists whose feedback counts: one commit email or comment login per line. It is installed naming nobody, and the installer says so until you fill it in. Lines from anyone not listed are counted, with their author only if it is shaped like an email or a login and their target only if it resolves, but their text never reaches the report, because what reaches it can become an instruction every later session follows. Merge commits are skipped: their body is the pull request's text under the merger's identity.
- The `agent-coach` (`--with-meta`, Claude Code) reads the report when it observes, cites the feedback behind each proposal, and lists feedback on skills, rules and commands for you to act on.
- On Claude Code a first install binds the `shared-registries` rule to paths: it gets a `paths:` header naming every fragment directory and artifact `registries.json` declares, plus `registries.json`, `registry.mk`, `.gitattributes` and `.registry-id-duplicate-allowlist`, and is loaded when one of those files is read or edited instead of into every session. All five rules used to load at every session start — 788 lines on a fresh install of kit 3.0.1. The header lists what `registries.json` declared at install time: add a line when you declare a new registry.
- `bootstrap.sh --source-paths 'src/**,scripts/**'` also binds `versioning-and-changelog` and `comments-and-annotations`, to those globs and to the kit files each is about. With it, a fresh install loads the constitution, `working-principles`, `documentation` and `project-annotations` into every session. Without it those two rules load everywhere, and the installer says so: where your source is, it does not guess. A glob with a quote, a backslash, a brace or a line break, or one that names a directory, is refused before anything is written. On a re-run the flag binds nothing — the rules are yours by then — and the installer names the ones it left unbound. On the other three tools the flag does nothing and the installer says that too.
- The `rule-load-check` skill (Claude Code): which rules really loaded, and when each arrives. It runs in a **new** session, lists what is in context before anything is read, reads one file per load class, and backs every claim with a quoted last line that is then compared with the file. Use it after installing, upgrading, or editing a rule or its header — a header Claude Code cannot parse is ignored without a message, and a session that is already running has been seen to keep the rules it started with.
- `starter-kit/upgrade-rules.sh` in the kit, for upgrade step 3: it lists each rule as `same`, `differs` or `missing` by the text under its `paths:` header, and with `--apply <rule>…` takes the kit's text for the rules you name and keeps your header. It accepts only the names of rules the kit ships, reads a CRLF checkout as the same text, and takes `--rules-dir` where a repository has two rules directories. `diff -rq` reported every rule with a header on every upgrade, and `cp` would have removed the header.
- "Load classes of the rules (Claude Code)" in the kit README, with the header to add by hand. ADR-0018 records the decision.
- `project-annotations.md`, installed beside the rules together with the comments rule (`.claude/rules/` on Claude Code, `docs/agent-rules/` elsewhere): the project's half of the comments-and-annotations rule. It says what the rule's pointers — `<DECISION-RECORD-ID>`, `<KB-ENTRY-ID>`, `<TICKET-ID>`, `<tool-or-gate>`, `<EVAL-RECORD-ID>` — stand for in your project, and lists the marker shapes your own tooling reads. It is yours; no upgrade replaces it. The constitution template's rule index lists it. ADR-0017 records the change.
- `make constitution` reads `project-annotations.md` together with the constitution and names every `<fill in: …>` still open in it. A pointer left unresolved used to sit in a rule that no check read.
- `bootstrap.sh --with-coach-schedule` installs `.github/workflows/agent-feedback.yml`. The installer also asks at a terminal on a first install; run without a terminal it adds the workflow only with the flag. Every Monday, and by hand from the Actions tab, the workflow collects the last week's `Agent-Feedback:` lines and posts a digest on one open issue labelled `agent-feedback`. An empty week posts nothing.
- With an `ANTHROPIC_API_KEY` repository secret and the Claude GitHub App installed, the same run has the agent coach read that feedback and post its proposals as a comment on the issue. The job can read code and write to issues only: it never pushes, branches or opens a pull request. A person decides.
- To add it to an existing install, re-run the installer with `--with-coach-schedule` (upgrade step 1). To keep it out, list `.github/workflows/agent-feedback.yml` in `.starter-kit-declined`; the installer then stops asking.
- `make agent-feedback FORMAT=markdown` (`feedback_tool.py collect --format markdown`) prints the report as a digest a person reads. Like the JSON, it never contains an unlisted author's text. You get the target with `registry.mk` in upgrade step 2.
- A first install writes `.starter-kit-version` at the root of your repository: the kit's release, its commit and the agent tool, on all four tools. Nothing else used to record which kit an install came from. Only two things write the file: the installer on a first install, and `kit-status.sh --record` at the end of an upgrade. A re-run of the installer never changes it. ADR-0024 records the decision; it supersedes ADR-0011.
- `starter-kit/kit-status.sh`, in the kit: run from your repository it prints the kit your repository records, the kit in the checkout you run it from, the changelog entries between the two with the **Breaking** ones first, and each of the kit's files in your repository as current, the older kit's, changed here, missing, declined or retired. It checks the record against the files on every run: an upgrade left half done is reported as partial, and a record the files contradict as one that does not hold. It uses no network — update the checkout to learn of a newer release.
- `make kit-status` prints the record; `make kit-status KIT=<checkout of the kit>` runs that report. You get the target with `registry.mk` in upgrade step 2.
- Upgrade step 7, `kit-status.sh --record`, writes the record once the files bear it out. It refuses, naming the files, while one of the kit's files is still an older release's text or is missing without being listed in `.starter-kit-declined`. A file you changed yourself is accepted and named.
- A first install into a repository that already had some of the kit's files records the kit all the same, names those files as yours, and the report lists them as changed here. A checkout with CRLF line endings is compared by its text.
- An install from before this release has no record. The report says so, names the release its files match, and prints the command that records it: `kit-status.sh --record --as v3.0.1`. Nothing fails without a record.
- `bootstrap.sh --with-upgrade-notice` installs `.github/workflows/kit-upgrade-notice.yml`; the installer also asks at a terminal on a first install, and never installs it unasked. Once a week the workflow lists the kit's release tags and opens an issue labelled `kit-upgrade` when one is newer than your record. It is the only part of the kit that uses the network: it downloads no code and can write to issues only. To keep it out for good, list its path in `.starter-kit-declined`.
- The Claude Code hook `workspace-graph.py` takes `--tool <path>` after its event: `… workspace-graph.py post-edit --tool tools/kit/graph_tool.py`. It runs `scripts/graph_tool.py` as before when the option is absent. Use it in a repository that keeps the kit's scripts somewhere other than `scripts/`, where the hook found no tool and stayed silent. The path is relative to the checkout and must stay inside it: an absolute path, one that leaves the checkout, or a symbolic link that does, is refused in silence, so the hook still runs only the project's own file. You get the hook by copying it in upgrade step 2; an install that keeps the tool in `scripts/` needs no change.

<!-- category: Changed -->
### Changed

- Every rule the kit ships is now named by a typed link of another installed artifact, on all four tools. `working-principles`, `comments-and-annotations` and `versioning-and-changelog` were cited only in prose, so `make graph-impact NODE=RULE:<name>` answered "nothing", a rename passed `make lint`, and the Claude Code hook stayed silent after an edit. The rules carry `**Related:**` lines for the dependencies they already described in sentences, and the `registry-entry` and `registry-conflict-triage` skills name the versioning rule. You get them by copying the rules and skills in upgrade steps 2 and 3.
- If you deleted one of the kit's rules and copy a newer rule that names it, `make graph-links` fails on that `Related:` line and says which token resolves to nothing: remove the token from the line.
- On Claude Code a fresh install no longer installs `.claude/hooks/session-start.sh` and no longer registers a `SessionStart` hook. The skeleton did nothing but append `PATH` to the session's environment file and print "session-start: toolchain ready" — into the session's context, about a toolchain it had not checked. It is a template now, for the day sessions need environment setup (ADR-0015).
- **Your existing install is not changed.** If you have the hook and its entry in `.claude/settings.json`, they stay: fill the hook in, keep it, or delete the file and the entry together. If you delete it, nothing puts it back — newer kits do not install it. Upgrade step 1 adds the template.
- A re-run of the installer that installed something says how to decline it, and the first-install steps on Claude Code say what to do about a skill you already have from elsewhere.
- Every command the installed rules, skills and READMEs give you to type now starts Python the way the kit's own make targets do, as `./scripts/python.sh scripts/<tool> …`, or names the make target (`make registry-list`). Fourteen places said `python3 …` while the Makefile, the gates and the hook went through the launcher, and the one sentence that reconciled the two sat in the constitution template — which a repository that already had a constitution never received. ADR-0013 records the change; it supersedes one paragraph of ADR-0007.
- You get the rules and skills by copying them in upgrade steps 2 and 3. Four texts are yours after the install and are not replaced: `changelog.d/README.md`, `docs/DEBUGGING-KNOWLEDGE-BASE.d/README.md`, and the preamble above the generated region of `CHANGELOG.md` and of `docs/DEBUGGING-KNOWLEDGE-BASE.md`. Upgrade step 4 now lists them for comparing by hand. Nothing fails if you leave them: the old form still runs wherever it ran before.
- The constitution template no longer tells the reader to substitute the launcher for `python3` "here and in every rule"; it says that commands are written through the launcher. If your constitution carries the old sentence, it can go once the rules are updated.
- In the kit's repository: `make documented-commands` (`scripts/check-documented-commands.sh`), part of `make lint`, fails with file and line when a tracked file writes a command that starts Python by a fixed name.
- `rules/documentation.md` has a new section, "Feedback to an agent", and a row in its "What to update when" table. You get it by copying the rule in upgrade step 3.
- **Your existing install is not changed**: the installer writes a header only onto a rule it installs in that run. To bring an install to these load classes, add the header shown in the README to the three rules, keep each rule's line in your constitution's Non-Negotiable Rules table — it is what holds before a bound rule arrives — and run `rule-load-check` in a new session.
- Upgrade step 3 uses `upgrade-rules.sh` instead of `diff -rq` and `cp`.
- The documentation rule's row for a new convention says to check a new or changed rule from a fresh session.
- The guide's load-class table counts a rule file as always loaded only when it has no path scope.
- The comments-and-annotations rule and its reference are used as shipped: nothing in them is filled in. The heading "Protected shapes (project fill-in)" is "Protected shapes", the instruction to complete the second table is gone, and the pointers are notation that `project-annotations.md` resolves. The two mentions of `testing.md`, a file no install has, now read "the project's testing rule, where it has one".
- **If you filled in the rule on an older kit, you can move your rows once** — upgrade step 3 says how: create `project-annotations.md` from the kit's template (the command does nothing where the file exists), move your second table and your pointer values into it, then copy the kit's rule over yours. From then on the rule is copied like the other four. The move is your choice: until you make it, your filled-in rule keeps working and is merged by hand at each upgrade, as before, and a line for the new file in your constitution's index is yours to add or leave. The installer does not put the template beside a comments rule that was already there: unfilled, it would be loaded into every session and would fail a `constitution` check you chained into your lint.
- The documentation rule's "ADR format" section applies where `registries.json` declares an `adr` registry, and says so. With none declared — because your project records its decisions somewhere else — the constitution says where, and the rest of the section does not apply. The rule used to prescribe `docs/adr/` and `--registry adr` unconditionally, and a project with its own decision register had to overrule an installed rule in its constitution.
- `registry_tool.py init` still declares an `adr` registry when it finds no decision records; its note now says what to do when decisions live elsewhere in a form it cannot see. The setup prompt's Harmonize track and the kit's `AGENTS.md` name that case.
- `check-ci-lint-coverage.sh` says what it read. Its `OK:` line is followed by "(Read from the workflow files — not that a run completed. In this repository, 'gh run list --limit 5' shows whether one did.)". The gate reads the workflow files in your checkout and cannot see the hosting platform: it reported `OK` in every lint of a repository whose CI runs all ended within seconds, before their first step, while pull requests were merged unchecked. Its second success message now reads "every 'lint' sub-target is invoked by a CI workflow step" instead of "runs in CI". Exit codes are unchanged. You get this by copying the kit's scripts and `registry.mk` in upgrade step 2.
- The installer's first-install steps end with a step 5: once the pull request is open — the installed workflow starts on a pull request and on a push to `main`, not on the push of a feature branch — `gh run list --workflow lint.yml --limit 5` must show a completed run that succeeded; until one was seen, the handoff says that CI is not confirmed, and why. Then make `lint` a required status check on the default branch.
- The setup prompt, the kit's `AGENTS.md` and both READMEs name the confirmed run as the end of a setup, and the required check as a separate step. Where the installing agent was not asked to push, the handoff says "CI not confirmed", never "CI green" from a workflow file. The kit's `AGENTS.md` asks for the target's runs by repository, because the kit's own workflow has the same name.
- The shared-registries rule gains "A CI step is not a CI run" beside "A Makefile target is not a CI step", with its write-up in the rule reference; both arrive through upgrade step 3. ADR-0019 records why this is a named step and not a gate: the kit has no network.
- The installed workflow's header carries the same note, and says to add `merge_group:` before making the check required with a merge queue. That file is yours after the install and no upgrade step replaces it: copy the note if you want it.
- The setup prompt and the guide give a test for anything deferred "until a signal": would the signal be noticed while the deferred artifact does not exist? "Add the check when the rule is violated" fails it when the check is the only thing that would notice. The handoff names the observer — a reviewer's checklist line, the recurring audit, a command that fails — or the artifact is not deferred.
- The upgrade steps start by asking `kit-status.sh` what the upgrade is, and end with step 7. The line of step 2 that removes the kit-only suites names one more, `test-kit-status.sh`.
- On a re-run, the installer says that it wrote no version record, and why: it replaced none of your files, so a record naming the newer kit would be false.
- The rule, skill and reviewer-agent templates in `docs/agent-templates/` each carry a `**Why:**` line. A rule, workflow or review mandate stated without its reason is followed to the letter and misapplied at the first case its examples do not show. With the reason, the next correction can sharpen a principle instead of adding one more special case. The templates are yours after the install: to take the new line, delete `docs/agent-templates/` and re-run the installer (upgrade step 2), or add the line by hand.
- `rules/documentation.md` lists "its why" among the parts a new rule file carries. You get it by copying the rule in upgrade step 3.
- The guide's P6 and its flywheel table (§ 5.1) now say what to do with memory an agent tool writes on its own. Treat it as an inbox. A note that holds a second time is promoted into a rule, skill or knowledge-base entry by pull request, and the note is deleted.
- The workflows the installer puts in place — `.github/workflows/lint.yml`, and `agent-feedback.yml` with `--with-coach-schedule` — use `actions/checkout@v7` and `actions/setup-python@v7`. The versions they named before, `checkout@v4` and `setup-python@v5`, run on Node 20, which GitHub's runners have deprecated; both `v7` actions run on Node 24. Nothing else in the workflows changed.
- **Your existing install is not changed**: the installer never replaces a workflow, and the file is yours. To follow, change the two `uses:` lines in each workflow by hand. `checkout@v7` needs a runner of version 2.327.1 or newer, which GitHub-hosted runners have; check a self-hosted one first.
- The record of what changed in your agent workspace — a setup or harmonize pass, a workspace audit, an agent-coach cycle — is now a directory with one file per run: `.claude/workspace-changelog/<date>-<what>.md` on Claude Code, `docs/workspace-changelog/` on the other tools. It was a single `WORKSPACE_CHANGELOG.md` with the newest entry on top, which every run inserted into at the same line; two pull requests open at once conflicted on it, and a day of setup work is easily three. That is the shape the shared-registries rule tells you to remove from your changelog. ADR-0020 records the change.
- `bootstrap.sh --with-meta` installs the directory's `README.md` — naming, reason and entry format — and no longer the single-file skeleton. The entry format gains a `Kit:` field for the installer's version line.
- The workspace-audit skill, its command and the agent-coach read the directory and write each run as a new file in it. The setup prompt's Harmonize track records its run the same way, whether or not the meta layer is installed.
- A file is written once: a later pull request of the same run adds a file of its own, under a name no other branch would choose. Two edits of one entry conflict like two entries in one file.
- **If you have a `WORKSPACE_CHANGELOG.md`, keep it.** Nothing migrates it and nothing fails: it is the archive, read for history and not written to. You get the directory at your next installer run with `--with-meta`, and the new wording when you copy the kit's skill, command and coach in upgrade step 2; until then they keep writing to the single file.
- The kit's own repository now runs on its kit: its rules, skills, `agent-coach` and hook are applied there by links into `starter-kit/`, held by a gate (ADR-0022). What that shows is in `docs/EVIDENCE.md`: numbers computed from the repository at a stamped commit and recomputed by its `make lint` (ADR-0023). Nothing changes in an installed project.

<!-- category: Deprecated -->

<!-- category: Removed -->
### Removed

- `starter-kit/WORKSPACE_CHANGELOG.md.template` from the kit. An installed `WORKSPACE_CHANGELOG.md` is yours and stays.

<!-- category: Fixed -->
### Fixed

- The installed `Makefile`, `.gitattributes`, `.github/workflows/lint.yml` and `.registry-id-duplicate-allowlist` no longer open with "Copy to …", an instruction to put the file where it already is. The header now says where the file is installed, which is true in the kit and in your repository alike. These four files are yours after the install and are not replaced by an upgrade; to take the fix, edit the one line in each.
- The skeleton prints nothing as shipped. Its header gains a third design rule: what a SessionStart hook prints is read by the agent as fact, so print a state only after the step that checked it.
- Asking `registry_tool.py` for a registry that is not declared says that `registries.json` declares no registry of that name, lists the ones it does, and points at the constitution. It used to say "unknown registry".

<!-- category: Security -->

## [3.0.1] — 2026-11-20

<!-- category: Added -->

<!-- category: Changed -->

<!-- category: Deprecated -->

<!-- category: Removed -->

<!-- category: Fixed -->

<!-- category: Security -->
### Security

- The workspace-graph hook (`.claude/hooks/workspace-graph.py`) no longer runs the
  `scripts/graph_tool.py` of whatever repository an edited file sits in. It judges only the
  project's repository — the one `$CLAUDE_PROJECT_DIR` names — and its worktrees; after an
  edit in any other checkout (a clone the agent was asked to read, a dependency's source, a
  submodule) it stays silent and runs none of its code. Before, such an edit started that
  checkout's tool as a Python script. A submodule that carries the kit keeps its own
  `make lint` as the gate (ADR-0012). To pick up the fix, copy the hook from the kit (README,
  "Upgrading an existing install", step 2).

## [3.0.0] — 2026-11-14

<!-- category: Added -->
### Added

- `make constitution` (`scripts/check-constitution.sh`), installed for every tool. It fails, with file and line, while the constitution links to a file that does not exist or still carries a template placeholder — the template's `testing.md` and `security.md` example lines, `<Project Name>`, an unfilled stack row. `make lint` checks neither, so a constitution could be committed half filled in with every gate green. Angle brackets that belong in a constitution are left alone: anything in a fenced block or backticks, HTML tags and comments, a single word such as `Option<T>`. Rule files and `docs/rule-reference/` are never read.
- The check is **not** part of `make lint`: add `constitution` to your own `lint:` line to hold it on every pull request. The installer's next steps, the kit's `AGENTS.md`, the README and the setup prompt now name it as the check that onboarding is finished. ADR-0009 records why it ships unchained.
- `scripts/tests/test-constitution.sh`, run by `registry-test`.
- "The constitution check" in the kit README, and Troubleshooting rows for its two messages, for the installer's several-tools message and for any installed gate that lint does not reach.
- In the kit's repository: `starter-kit/scripts/tests/test-upgrade.sh` runs the README's upgrade steps as written — the commands of steps 1 and 2 are read out of the README — on an install shaped like 1.x and, where the tag is present, on a real 1.1.0 install, each customized as an adopter would. It checks that the constitution, `settings.json`, your rules, `registries.json`, registry entries, workflow and tests come out byte for byte as they went in, that the kit's files become the newer kit's, and that lint ends green. ADR-0011 records this, and why the kit still writes no version manifest into your repository.
- In the kit's repository: `scripts/eval-run.sh`, for evaluating a change by applying the kit. It refuses a command with no explicit working directory, records command, directory, start, end, exit status and output, labels a test that is meant to fail, and reports — after the fact — a command that changed a directory it was told to guard. `CONTRIBUTING.md` says what it does and does not isolate.

<!-- category: Changed -->
### Changed

- **Breaking — why this release is 3.0.0.** The coverage gate passed in three cases where CI did not run `make lint`, or `make lint` did not run a gate. Closing them can fail a repository that passed on 2.0.0, and each is repaired in a file of your own — a workflow, or your `lint:` line — which ADR-0008 makes a major release. A fresh install is not affected, and neither is a repository whose `make lint` runs from a push or pull-request workflow in the repository root with all five gates chained. A repository that stays on 2.0.0 is not touched: the installer never overwrites a file. The three changes are marked Breaking below, and each fails `make lint` with the fix.
- **Breaking:** `check-ci-lint-coverage.sh` no longer counts a reusable workflow (`on: workflow_call`) that nothing calls. It counts one only when a workflow that a push, pull request or merge queue triggers reaches it through `uses: ./.github/workflows/<file>`, directly or through other reusable workflows. If your `make lint` runs only in a reusable workflow, call it from a workflow with one of those triggers.
- **Breaking:** the coverage gate now reads a workflow-level `defaults.run.working-directory`. A workflow that runs its steps in another directory no longer covers the root Makefile; a job default or a step's own `working-directory` of `.` still does. The nearest setting wins: step, job, workflow, root.
- **Breaking:** the coverage gate requires `lint` to reach every gate the kit installed — `registry-drift`, `registry-ids`, `kb-shape`, `graph-links`, `ci-lint-coverage` — where it checked three. If you keep your own Makefile and its `lint:` line leaves out `kb-shape` or `ci-lint-coverage`, add it; the failure names the target. A repository installed before a gate existed, with no such script, is not held to it.
- A workflow in another repository (`owner/repo/…@ref`) and a `uses:` that is not a literal local path are never counted as coverage: the gate cannot read them. If your lint runs there, list the targets in `.ci-lint-coverage-allowlist` with the reason.
- When the coverage gate fails, it lists what it read and did not count — an uncalled reusable workflow, a call it could not follow — under "Read and not counted". Its header now states what "covered" means: a step that is not visibly switched off names the target. That is evidence CI runs it, not proof.
- `bootstrap.sh` no longer chooses between tools. When the target has the files of more than one — `CLAUDE.md` beside `AGENTS.md`, `.claude/` beside `.cursor/` — it asks which is primary, and with no terminal to ask at it stops before writing anything and lists them. Pass `--tool`. Earlier versions installed for the first it looked for (Claude Code, then Cursor, then Copilot, then `AGENTS.md`) without saying so. `AGENTS.md` beside `.cursor/` is still Cursor alone: that is where the Cursor layout keeps its constitution.
- Upgrade step 1 in the kit README says to add `--tool` in a repository with two tools' files, and step 5 names the five gates the coverage gate now holds.

<!-- category: Deprecated -->

<!-- category: Removed -->

<!-- category: Fixed -->
### Fixed

- `registry_tool.py init` — and so `bootstrap.sh`, which runs it — declared a directory of date-named decision records (`2026-03-02-use-postgres.md`, `adr-2026-03-02-…`) as numbered at width 4, reading the year as the number. Every record of one year was then the same identifier, `ADR-2026`, and the identifier gate failed on a repository the installer had just said it preserved. Such records are now declared date-slug with the filename prefix they have. If an earlier install left you with `"id_scheme": "numeric"` on date-named records, set it to `"slug"`.
- In a registry that numbers its records at width 4, a file named by date passed every gate as record `<year>` — `adr-2026-11-14-x.md` was `ADR-2026` — and the next `registry_tool.py new` allocated `2027`. The identifier gate now refuses a date-named file in a numbered registry and says what to rename it to, and the allocator no longer counts a year as a number. A record that really is number 2026 (`adr-2026-a-decision.md`) is unaffected.
- Upgrade step 2 in the kit README left `scripts/tests/test-graph-hooks.sh` in your repository: its `cp` copied every suite and its `rm` removed only two of the ones that stay in the kit. The line now removes all four. If you upgraded to 2.0.0 by those steps, delete the file; nothing runs it.
- The kit's own `AGENTS.md` linked to `changelog.d/`, a directory that does not exist in a checkout once a release has consumed its fragments. The directory now keeps a README.

<!-- category: Security -->

## [2.0.0] — 2026-11-14

<!-- category: Added -->
### Added

- ADR-0003 records why the comments-and-annotations rule is enforced by review rather than by a check in the lint target, and what was weighed first: an annotation-density check, a marker-aware check, and deferring until the first violation. The rule already stated the conclusion inline; the record carries the rejected options and scopes the exception to judgement about annotation content, leaving marker *shape* gateable as `check-kb-shape.sh` and `check-registry-drift.sh` already gate it.
- ADR-0008 says what makes a release of the kit MAJOR: a repository that passed `make lint` on the previous version and follows the upgrade steps fails it, or has to edit a file of its own. It also names what the kit treats as its public contract.
- `scripts/python.sh`, installed for every tool: it starts Python under whatever name the machine gives it. It tries `python3`, `python` and `py -3`, and uses the first that really runs Python 3.9 or newer — on Windows `python3` can be a Store alias that is on PATH and is not Python. `./scripts/python.sh --which` prints the interpreter it found.
- `make lint PYTHON=/path/to/python`, or `PYTHON=…` in the environment, names the interpreter yourself. A `PYTHON` that does not run is an error, not a fallback to another interpreter.
- ADR-0007 records why the interpreter is found each time it is started rather than named or detected once at install time, and that the Windows path was tested against a simulated machine and not on Windows itself.
- On Claude Code, the agent is told what cites a file right after it edits it. A new hook, `.claude/hooks/workspace-graph.py`, runs after every `Edit` and `Write`: when the file is cited by another artifact, or now carries a typed link that resolves to nothing, the citing files and lines are added to the agent's context. For any other file it says nothing, and it says each distinct thing once per session.
- When the agent ends its turn with a typed link that no longer resolves — after a rename done through the shell, for instance — the same hook holds the turn once and hands the failure back, so the break is repaired or reported before "done" instead of found in CI. A turn is never held twice for the same failure.
- The hook is context, not a gate: `make lint` is unchanged and still the gate. It never changes a file, leaves nothing in the repository, and ends silent whenever it cannot do its job. Set `WORKSPACE_GRAPH_HOOK=off` to switch it off for a run, or delete its two entries from `.claude/settings.json` to remove it; `WORKSPACE_GRAPH_HOOK_DEBUG=1` makes it say why it stayed silent.
- A fresh Claude Code install registers the hook in `.claude/settings.json`. In a repository that already has a `settings.json`, re-running `bootstrap.sh` adds the hook file and prints the two entries to add; the installer does not edit the file.
- `scripts/graph_tool.py note <path>…`, for every tool: what the editor of a file should be told — who cites it, and any link in it that resolves to nothing — and nothing at all otherwise. It is what the hook calls, and what a hook for another agent tool would call.
- ADR-0006 records why the graph is handed to the agent by a hook, why that hook is on by default for Claude Code only, and what was and was not observed in real sessions.
- `make lint` fails when a typed link names an artifact that does not exist. The new `scripts/check-graph-links.sh`, installed for every tool, resolves each `Related:`, `Enforces:` and `Hands off to:` line against the files on disk and reports the citing `file:line`, the names that do exist, and the fix. A code fence that is never closed is reported too, when link lines below it would otherwise be skipped as code. Until now a link to a renamed rule, a deleted script or an entry that was never written passed the drift gate, the identifier gate and the knowledge-base shape check alike.
- `scripts/graph_tool.py impact <KIND:name>` (also `make graph-impact NODE=…`) lists what cites an artifact and what it cites, each with `file:line`. Run it before renaming, deleting or rewriting a rule, skill, agent, command or script: its "Cited by" list is the change set. `impact HUMAN` lists every approval gate the workspace declares. `make graph-impact` with no `NODE` prints how to name one.
- `scripts/graph_tool.py coverage` (also `make graph-coverage`) reports which rules a script enforces and an agent reviews, and which gates no agent cites. It is a report for audits and the health checklist, never a gate.
- Two link lines and two artifact kinds join the existing `Related:` line. `Enforces:` says a script or a reviewer holds a rule; `Hands off to:` says who or what runs next, including `HUMAN` for an approval gate; `AGENT:<name>` and `COMMAND:<name>` are valid tokens. Together they describe both the knowledge graph over the workspace and its orchestration topology — guide § 3.12, and the new "Typed links" section of the documentation rule.
- The kit's own artifacts carry the links: the four shipped gates name the rule they enforce, the registry skills the rule and tool they use, the agent-coach, the audit skill and the conflict-triage skill the human gate they stop at, and the audit command the skill it delegates to. A fresh install therefore has a graph to resolve on day one.
- `workspace-graph` skill, installed by `bootstrap.sh --with-meta`: impact-before-edit and coverage as a procedure. The agent-coach and the workspace-audit skill now read coverage holes and citers from the graph where the repository ships the tool.
- `.graph-link-allowlist`, created on first need: the one sanctioned dangling link — an immutable decision record citing a rule that was later retired — as `<citing file> <token>  # reason`. The reason is mandatory, the exemption is reported on every run, and a stale entry fails the gate.
- An optional `graph.nodes` block in `registries.json` declares where a repository keeps a kind of artifact when that is not where the installer puts it — playbook docs standing in for skills on a tool without native ones, for instance.
- `scripts/tests/test-graph-links.sh`, the acceptance test, with a control case that requires the three older gates to pass on a dangling link; `scripts/tests/test_graph_tool.py`, the unit tests. Both run in `make lint`.
- ADR-0004 records why link resolution is a day-1 default while graph-driven retrieval, topology checks and a stored index stay deferred, and what was weighed first.
- `bootstrap.sh` installs the templates a workspace grows from — a new rule, check script, skill, reviewer agent and (on Claude Code) command — to `docs/agent-templates/`, for every tool. They are never loaded into a session and the link gate reads them as scaffolding. Until now they stayed in the kit, where a later session could not find them.
- The documentation rule's "what to update when" table says which template to start from and what each artifact must carry, including two links that are easy to leave out: a new rule cites the incident behind it, and the incident's entry names the rule or check that now prevents it.
- `docs/rule-reference/`, installed for every tool: the worked examples of the comments-and-annotations rule and the gotcha write-ups of the shared-registries rule. They are read when a rule points at them and are never loaded by default.
- `AGENTS.md` at the root of the kit's repository, and a `CLAUDE.md` that imports it. An agent pointed at a checkout of the kit learns from it how to install the kit into a project step by step, when to stop and ask, and what the rules are for changing the kit itself.
- `CONTRIBUTING.md` for people changing the kit: the workflow, the test suites, what each gate holds together, the checklist for adding anything the installer ships, and the release procedure.
- `starter-kit/README.md` gains Requirements, **Upgrading an existing install** and a Troubleshooting table that maps each `make lint` failure to its fix. The upgrade steps say which files the kit owns and are copied, which one rule is merged because it carries your fill-ins, and which files are yours and never replaced, with a command for each that lists what differs — so they work from whichever version a repository was installed from.
- ADR-0005 records why the templates and the rule references install on day 1 although nothing reads them that day.

<!-- category: Changed -->
### Changed

- A changelog fragment line the generator cannot render is now an error naming `file:line`: a `### Fixed` heading, an unindented second line of a bullet, a paragraph inside a section, an unclosed comment. All of these used to vanish from the changelog with every gate green. `* ` and `+ ` bullets are rendered as `- `; notes between the title and the first section stay allowed. Fragments that relied on the old silence fail `make lint` until fixed.
- `check-ci-lint-coverage.sh` counts a target only when a workflow really runs it: the `run:` of a step, read as shell, in a workflow a push, pull request, merge queue or `workflow_call` triggers, not switched off with `if: false`, in the repository root and not as `make -n`. A target named in a comment, an `echo`, a step name, `make -C other`, `cd other && make` or a `working-directory` no longer counts. Workflows without an `on:` trigger cover nothing.
- **Breaking — why this release is 2.0.0.** Moving an existing install to it needs changes to files of your own. A repository that stays on 1.x is not touched: the installer never overwrites a file. The changes marked Breaking below apply once you follow "Upgrading an existing install" in the kit README, and each one fails `make lint` with the file, the line and the fix.
- **Breaking:** a check script of yours whose header reads `# Enforces: <rule> — see <rule file>`, the form the 1.x template shipped, fails the new link gate. Name the rule as a token: `# Enforces: RULE:<name> — <what it checks>`.
- **Breaking:** a `Related:` line that names an artifact which does not exist passed every 1.x gate and now fails. Point it at the artifact's current name, or delete it.
- **Breaking:** if you keep your own Makefile, its `lint:` line must name `graph-links`. Until it does, `check-ci-lint-coverage.sh` fails and says so.
- Python 3.9 or newer is now a stated requirement, and `scripts/python.sh` checks it. Earlier versions named no minimum.
- Everything the kit runs itself starts Python through the launcher: the make targets in `registry.mk`, the five gates, the installer, the test suites, and the two Claude Code hook entries in `.claude/settings.json`. On macOS and Linux nothing changes in what you see. On an upgrade, re-running `bootstrap.sh` adds `scripts/python.sh`; a gate copied without it falls back to `python3`, as before.
- The tools' output is UTF-8 on every platform, so an arrow or a dash in a message cannot fail on a Windows code page.
- Commands the kit prints for you to copy no longer name `python3`: the link gate and the edit note point at `make graph-impact NODE=…`, and the installer at `make registry-list` and `./scripts/python.sh scripts/registry_tool.py adopt …`. The commands in the rules and READMEs still read `python3 scripts/…`; the constitution and the README say that `./scripts/python.sh` stands in for it where Python has another name.
- The umbrella lint target has a new prerequisite, `graph-links` (`Makefile.template`, `registry.mk`). A repository that keeps its own Makefile adds it to its `lint:` line; `check-ci-lint-coverage.sh` fails while `scripts/check-graph-links.sh` is installed and lint does not reach it.
- Upgrading a repository bootstrapped from an earlier version is manual, because `bootstrap.sh` never overwrites a file: re-running it adds `graph_tool.py`, `check-graph-links.sh` and the new tests, and leaves the existing `registry.mk` and `check-ci-lint-coverage.sh` as they were — so the gate is installed and nothing runs it. Copy those two files from the kit as well and add `graph-links` to the `lint:` line.
- A check script names its rule as a typed link: `# Enforces: RULE:<name> § <section> — <what it checks>` replaces `# Enforces: <rule> — see <rule file> § <section>` in the four shipped gates and in `check-convention.sh.template`. A script still carrying the old header fails the link gate, and the failure names the token to write.
- The knowledge-base shape check accepts `AGENT:` and `COMMAND:` tokens on a `Related:` line.
- The rule, skill, agent and command templates carry link lines to fill in; a placeholder left unfilled fails the link gate once the template is copied.
- Guide § 5.6 now lists only what graph engineering still defers, each with its signal, and says the term covers both orchestration topology and the knowledge graph; the mechanism moved to the new § 3.12. The statements in the documentation rule, the conflict-triage skill and guide § 3.11 that nothing checks whether a citation resolves now say what is checked — typed links — and what still is not: a citation inside a sentence, a source comment or a test name.
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

<!-- category: Deprecated -->

<!-- category: Removed -->

<!-- category: Fixed -->
### Fixed

- A release merged together with a branch that added a fragment in parallel could leave a copy of that bullet, or an `END GENERATED` marker, inside the released section while the drift check stayed green. The drift check and `generate` now fail on it, naming the line to delete, and on bullets written by hand under `[Unreleased]` outside the generated region; `release` refuses to run on such a changelog.
- `check-ci-lint-coverage.sh` no longer reports a covered target, or a reached registry gate, as missing when the workflow or the `make -n` output is large (SIGPIPE under `pipefail`).
- Slugs keep letters that have no Unicode decomposition: `Straße` → `strasse`, `Łódź` → `lodz` (they were dropped: `strae`).
- The `SessionStart` hook from `settings.json.template` runs from a project path with a space (it exited 127, silently), and `session-start.sh.template` appends its environment once instead of on every start.
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

<!-- category: Security -->

## [1.1.0] — 2026-09-07

<!-- category: Added -->
### Added

- `rules/comments-and-annotations.md`: a domain-agnostic rule for self-explaining work products — structure before annotation (rename, extract, restructure), a one-line brevity standard for what survives, protected marker shapes that are never stripped, an audience litmus for where rationale lives, and an explicit no-sweeps scope. `bootstrap.sh` installs it for every tool, the constitution template indexes it, and the setup prompt's fallback specs carry it for kit-less installs. Its protected-shapes table arrives pre-filled with the markers the kit's own tooling parses (generated-region and category anchors, knowledge-base field labels, the `.gitattributes` block markers, enforcement-script headers and escape markers, decision-record headings) and leaves four `<placeholders>` for the adopting project; `starter-kit/README.md` documents how to fill them.
- The rule's reviewer bullets as cross-cutting checks in the agent template, and one pointer in the working-principles pre-PR litmus, so specialist reviewers and the pre-PR self-check inherit them.
- `test-bootstrap-rerun.sh`: a second bootstrap run on a fresh repository changes nothing, and every tool layout receives the constitution and every shipped rule at its own rule location. Chained into the kit's `registry-test` target beside the brownfield-adoption test.
- `check-guide-templates.sh` (this repository only, not part of the kit): `make lint` now fails when a template the guide embeds drifts from the kit file it names; a block whose lead-in does not say "template" is listed as an illustration and never compared.

<!-- category: Changed -->
### Changed

- The documentation rule's "decision rationale lives in ADRs, not in code comments" section now routes to the comments-and-annotations rule instead of carrying its own copy of the comment doctrine, so the doctrine has one home; its WRONG/CORRECT pair and audience litmus moved there.
- `bootstrap.sh` decides the constitution path and the rules directory once per tool and installs the default rules from one list, so a new default rule is one edit rather than one per tool layout. Installed files, locations and order are unchanged.
- The constitution template's index line for the documentation rule says "ADR format (Michael Nygard)" instead of the retired "ADR-lite"; the kit README's row for that rule follows.

<!-- category: Deprecated -->

<!-- category: Removed -->

<!-- category: Fixed -->
### Fixed

- The two acceptance tests now pass on BSD/macOS sed. They used GNU's
  `sed -i 's/…/'`, which BSD sed reads as "backup suffix = the script", and both
  call sites in `test-parallel-merge.sh` sent stderr to `/dev/null` with
  `|| true`. The template placeholders were therefore never filled, the
  identifier gate rejected them exactly as designed, and the resulting failures
  read as defects in the mechanism under test rather than in the test's own
  setup: `test-parallel-merge.sh` reported 25 passed / 2 failed and
  `test-brownfield-adoption.sh` 15 passed / 2 failed. Both are now 27/0 and
  17/0. The replacement writes through a temp file rather than using `-i.bak`,
  so no backup file is left inside a fragment directory to be picked up as an
  entry.
- `bootstrap.sh` no longer tells a user with a correctly chained `lint` target
  that it "checks nothing of the registry layer". `make -n … | grep -q` exits at
  its first match, and under `set -o pipefail` the SIGPIPE that then kills `make`
  becomes the pipeline's status (141), so the check reported the opposite of
  what it had found. The same shape produced `test-brownfield-adoption.sh`'s
  "lint still does not run the gates" failure. Both now capture the output
  before matching it.
- `bootstrap.sh` no longer appends a second registry block to `.gitattributes` when re-run on a repository it bootstrapped from scratch: the template now carries the same marker lines the installer writes when it appends to an existing file, so both paths leave a file a re-run recognises. The fix travels with the template, so it covers installs made from this release onwards; a repository bootstrapped earlier has an unmarked `.gitattributes` and still gains a duplicate block on each re-run — delete the older copy by hand once, or add the two marker lines around it.
- The guide's embedded copies of the constitution, rule, agent, command, check-script and knowledge-base templates match the kit files again; the constitution copy had been missing the registry layer (the `make registry-generate` command, the Registries row and the shared-registries index line).

<!-- category: Security -->

## [1.0.0] — 2026-09-06

<!-- category: Added -->
### Added

- ADR-0002 recording why the registry layer is a day-1 default rather than a grown-by-signal artifact
- `.gitattributes` template with `merge=union` on generated artifacts, both of its silent hazards documented inline, and a warning that custom merge drivers need per-clone configuration and fail silently without it
- Enforcement gates chained into a shipped `make lint` target and a CI workflow that invokes it: registry drift, identifier shape and uniqueness, and a coverage check proving every gate in the lint target actually runs in CI
- Two skills: `registry-entry` for authoring an entry, and `registry-conflict-triage` for the residue — the second prohibits renaming any identifier already on the default branch
- Test suites for the registry layer: unit tests for the generator and gates, plus a parallel-merge acceptance test that keeps control cases reproducing the defect on the shape being replaced
- `starter-kit/scripts/registry_tool.py`: creates fragments, assembles them into a marked region of the readable artifact, promotes a release, and gates identifier shape and uniqueness. Identifier schemes are configurable — `slug` (collision-free by construction) is the default, `numeric` is supported with the gate as its backstop
- Shared append-only registry pattern: fragment directories, a deterministic generator, and gates for changelogs, knowledge bases and decision records — so files many pull requests append to no longer conflict on every concurrent pair (guide § 3.11)

<!-- category: Changed -->
### Changed

- The debugging knowledge base and the changelog now ship in the fragment layout: entries and bullets are authored as files, and the readable artifact is generated. The rule files, constitution template, setup prompt and bootstrap installer were updated to match
- Decision records now use [Michael Nygard's format](https://github.com/architecture-decision-record/architecture-decision-record) — Status, Context, Decision, Consequences — replacing the previous four-section ADR-lite. Rejected options move into Context as part of the forces, where Nygard puts them. The identifier gate's `required_headings`, the documentation rule, the setup prompt and the authoring skill all follow, so the repository and the kit it ships prescribe the same format
- Changelog fragments are now **one file per change** rather than one per bullet, with the Keep a Changelog categories as `## ` headings inside the file. The six category directories are gone. The earlier granularity satisfied every merge guarantee but was still the wrong shape: a file held one line and no unit of meaning, a change spanning three categories became three near-empty files, and 2.5 KB of content occupied 56 KB once filesystem blocks were counted. Disjoint paths — the property that makes concurrent authorship safe — are unaffected. Knowledge-base entries stay one file per entry, since each is already a document whose identifier is cited elsewhere.
- **First stable release.** The surface this kit ships — the fragment layouts, the `registries.json` schema, the `registry_tool.py` subcommands, and the generated-region markers — is now covered by Semantic Versioning: breaking changes to it require a major version, not a minor one. Repositories bootstrapped from 0.1.0 migrate with `registry_tool.py init` followed by `adopt` per registry, which infers the conventions already on disk rather than renaming anything already cited.

<!-- category: Deprecated -->

<!-- category: Removed -->

<!-- category: Fixed -->
### Fixed

- `check-kb-shape.sh` asserted identifier uniqueness against the pattern `ISSUE-[0-9]+`, which treats `ISSUE-7` and `ISSUE-007` as distinct — so a digit-width variant passed the uniqueness check. Shape is now asserted first, at an exact width, and mixing identifier schemes in one file is rejected
- Decision-record filenames now follow the MADR convention `adr-NNNN-short-title.md`, so `docs/adr/001-…` became `docs/adr/adr-0001-…`. Widening the number to four digits renumbered `ADR-001` to `ADR-0001` and `ADR-002` to `ADR-0002`; every live citation was updated in the same change. **Erratum:** the `[0.1.0]` section below refers to "ADR-001" and is immutable, so it is corrected here rather than edited — that record is now `ADR-0001`, at `docs/adr/adr-0001-repo-canonical-plugin-as-future-channel.md`.
- The drift check compares what a generated artifact *says* to its fragments — same entries, same content, any order — instead of comparing bytes. A union merge keeps both branches' blocks in arrival order and drops the blank line between them; byte-equality failed on every concurrent merge and demanded a regenerate commit each time, which was most of the friction the layout exists to remove. Real corruption still fails: a changed body, a missing entry, one identifier with two bodies.
- Union merge misfiled bullets when two branches each touched two changelog categories: git saw one contiguous change per branch and appended the second branch's whole block after the first's last section. Every category now carries a stable anchor line (an HTML comment, invisible when rendered), so each category is its own merge hunk and a bullet can only land under its own heading.
- Two concurrently added knowledge-base entries sharing two or more consecutive identical lines were interleaved by git's conflict refinement. Every rendered entry now ends with a line unique to it, and `check` refuses unfilled template placeholders — the usual way two entries acquire identical adjacent lines. The residual case is caught loudly by the drift check and documented as the boundary of what union merge can do.
- `.gitattributes` marked fragment directories `-merge`, which disables the text driver and forced a conflict whenever two branches edited *different* lines of the same entry. Now `merge=text`, the default, stated explicitly.
- `check-kb-shape.sh` hardcoded the identifier width while `registries.json` declared it, so a project on four-digit identifiers passed one gate and failed the other on the same file. The shell gate now reads `registries.json` when present.
- `registry_tool.py adopt --registry <name>` brings an existing hand-maintained `CHANGELOG.md` or knowledge base under the fragment layout losslessly; `bootstrap.sh` names that step instead of promising green gates on a brownfield install.
- Bootstrapping into a repository that already has an agentic workspace and populated registries now adopts rather than imposes. `registry_tool.py init` writes `registries.json` from the conventions on disk — an `adr-tools` directory of `0001-title.md` files, a knowledge base of `ISSUE-042` entries — so the identifier gate passes on existing records without renaming any. `adopt` accepts `## Unreleased` without brackets, files uncategorised bullets under Changed, and reads `###` entry headings with `-`/`—` separators. An existing `.gitattributes` gets the registry block appended under an idempotent marker; an existing `Makefile` is never edited, but the registry targets ship in `registry.mk` for a one-line include and bootstrap verifies the gates are reached. `check-ci-lint-coverage.sh` now fails when the registry gates are installed but the lint target never runs them — the previous behaviour was a green lint that checked nothing — and no longer rejects the commit that introduces the allowlist file. A brownfield acceptance test covers the whole sequence.

<!-- category: Security -->

## [0.1.0] — 2026-08-02

### Added

- Initial import: the agentic engineering guide (concepts, reference anatomy,
  generic blueprint, adoption playbook, maintenance flywheel, graph-engineering
  outlook).
- Starter kit with three entry points: `SETUP-PROMPT.md` (agent-driven, incl.
  the harmonize track for repos that already have agent configuration),
  `bootstrap.sh` (tool-detecting installer, `--with-meta` for the Level-4
  loop), and manual copy.
- Day-1 rule defaults: working principles (incl. plan-first/QRSPI),
  documentation, versioning & changelog.
- Shipped skills: prompt-enhancer, semver (vendored from
  https://github.com/h2nguyen/semver-skill, with validator and test suite).
- Level-4 meta layer behind `--with-meta`: workspace-audit skill + command,
  agent-coach meta-agent, workspace-changelog skeleton.
- Graph-ready debugging knowledge base plus `check-kb-shape.sh`, a runnable
  lint check for entry shape and typed cross-links.
- Templates for constitution, rules, skills, agents, commands, enforcement
  scripts, session hook, and tool settings.
- ADR-001 recording why this repository is canonical and an agent plugin is a
  future distribution channel.
