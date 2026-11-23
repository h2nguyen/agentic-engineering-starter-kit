# 2026-11-23 — full audit (version record, and the open points of the setup run)

**Mode:** full. **Baseline:** `main@d1d8383`. **Branch:** `feat/kit-version-record`.
**Kit:** applied by reference from this checkout's `starter-kit/`, not installed (ADR-0022).

Follows `2026-11-23-self-application-setup.md` and closes its three follow-ups.

## Headline result

The links added by the setup run load: a new session had all six rule files
in context at start, with every quoted last line matching its file, the seven
linked skills in its skill list and the `agent-coach` among its agents. An
install now records the kit it came from, and `kit-status.sh` checks that
record against the files (ADR-0024, which supersedes ADR-0011).

## Changes applied

| # | Commit | Change | Ladder rung | Ledger items |
|---|---|---|---|---|
| 1 | this pull request | `.starter-kit-version`, `kit-status.sh`, `make kit-status`, upgrade step 7, the opt-in notice workflow, ADR-0024 | — | — |
| 2 | this pull request | `test-upgrade.sh` performs the second half of upgrade step 2; it never had, and a real 1.1.0 install kept an old skill through every step | — | — |
| 3 | `chore/actions-node24` | `actions/checkout@v7` and `actions/setup-python@v7` in the workflows and the kit's templates. Read from the actions' own `action.yml` at each tag: `checkout` v4 is `node20`, v5 to v7 `node24`; `setup-python` v5 is `node20`, v6 and v7 `node24` | — | — |

## Rule load check, as run

Run first in the session, before any file was read. No rule has a `paths:`
header, so there was no load class to exercise.

| Rule | Header | Expected | Observed | Quote matches |
|---|---|---|---|---|
| `comments-and-annotations` | none | at start | at start | yes |
| `documentation` | none | at start | at start | yes |
| `project-annotations` | none | at start | at start | yes |
| `shared-registries` | none | at start | at start | yes |
| `versioning-and-changelog` | none | at start | at start | yes |
| `working-principles` | none | at start | at start | yes |

## Deliberately NOT changed (with reasons)

- **Load classes stay unapplied here.** A rule gets its paths from a header in
  its own file; Claude Code documents no other place. A link has no file of
  its own to carry one. Two ways without a copy were looked at, and neither
  is taken:
  - *A stub rule with a `paths:` header whose body imports the kit's file*
    (`@../../starter-kit/rules/<name>.md`). The documentation describes
    imports for `CLAUDE.md` and says nothing about imports inside a rule
    file. Not tried, because a result would not change the decision: the kit
    does not build on behaviour its tool does not document. To try it: on a
    branch, replace the link `.claude/rules/shared-registries.md` with such a
    stub bound to `changelog.d/**`; start a new session; run `rule-load-check`.
    The rule's last line must be absent at start and quotable after reading a
    file under `changelog.d/`. The `self-application` gate will fail on the
    stub, which is the point at which this becomes a decision record.
  - *A `CLAUDE.md` in a subdirectory that imports the rules.* Documented: it
    loads when a file under that directory is read, with its imports. But the
    trigger is a directory, not a pattern, and the three rules that could be
    bound are about `changelog.d/`, `docs/adr/` and every source file. Work
    here touches those in nearly every session — 107 file changes under the
    registry paths in 18 merged pull requests — so the lines saved would be
    saved only in sessions that change nothing.
  The cost stays visible as "Lines loaded into every session" in
  `docs/EVIDENCE.md`.
- **No improver for skills and rules on every tool, and no golden cases per
  skill** (deferred in ADR-0016). Their signals have not appeared:
  `make agent-feedback` reports 0 points and 0 unresolved, no coach cycle is
  recorded, and no proposal has been merged, so none can have made anything
  worse. They wait for: feedback on a skill or rule that the report shows
  nobody acted on; and a merged proposal that had to be reverted.
- **No feedback was written to move the numbers.** The loop's zeros are true.
- **ADR-0011 is not edited.** ADR-0024 states the supersession.
- **No gate for the action versions.** They were consistent before and after;
  a gate without a failure behind it is speculative.

## Follow-ups

- The feedback loop has never turned. The digest workflow ran once, by hand,
  on `main`: it collected, found nothing, and skipped posting and the coach.
  Its collect step was run here in a scratch project with one line from a
  listed author and reported `total=1`; posting and the coach need the
  repository. First turn: a listed author's `Agent-Feedback:` line in a
  commit on `main`, then the workflow by hand.
- The coach step needs an `ANTHROPIC_API_KEY` secret and the Claude GitHub
  App. Whether the secret is set cannot be read from a run that skipped the
  step that tests it.
- The upgrade steps are run by a test on the Claude Code layout only
  (ADR-0011, "Not covered"). The version record is tested on all four tools;
  the upgrade itself is not.
- `kit-upgrade-notice.yml` has not run anywhere: this repository has no
  install to watch. Its compare step is tested against a local kit; its issue
  step is not.
