# Fixes from the review of the kit's first adoption

Found adopting the kit in CIATA-io/pia, where each one had silently cost a check or a line of history.

## Changed

- A changelog fragment line the generator cannot render is now an error naming `file:line`: a `### Fixed` heading, an unindented second line of a bullet, a paragraph inside a section, an unclosed comment. All of these used to vanish from the changelog with every gate green. `* ` and `+ ` bullets are rendered as `- `; notes between the title and the first section stay allowed. Fragments that relied on the old silence fail `make lint` until fixed.
- `check-ci-lint-coverage.sh` counts a target only when a workflow really runs it: the `run:` of a step, read as shell, in a workflow a push, pull request, merge queue or `workflow_call` triggers, not switched off with `if: false`, in the repository root and not as `make -n`. A target named in a comment, an `echo`, a step name, `make -C other`, `cd other && make` or a `working-directory` no longer counts. Workflows without an `on:` trigger cover nothing.

## Fixed

- A release merged together with a branch that added a fragment in parallel could leave a copy of that bullet, or an `END GENERATED` marker, inside the released section while the drift check stayed green. The drift check and `generate` now fail on it, naming the line to delete, and on bullets written by hand under `[Unreleased]` outside the generated region; `release` refuses to run on such a changelog.
- `check-ci-lint-coverage.sh` no longer reports a covered target, or a reached registry gate, as missing when the workflow or the `make -n` output is large (SIGPIPE under `pipefail`).
- Slugs keep letters that have no Unicode decomposition: `Straße` → `strasse`, `Łódź` → `lodz` (they were dropped: `strae`).
- The `SessionStart` hook from `settings.json.template` runs from a project path with a space (it exited 127, silently), and `session-start.sh.template` appends its environment once instead of on every start.
