# The coverage gate counts only what it can read

## Status

Accepted

## Context

`check-ci-lint-coverage.sh` answers one question: does CI run every check the
lint target chains? Its own failure is quiet — it passes when it should not,
and a green gate that gates nothing looks like one that works. A review found
three ways it did.

- It treated `on: workflow_call` as a trigger. A reusable workflow that no
  other workflow called, containing `make lint`, was full coverage.
- It read a step's and a job's `working-directory` and not the workflow's
  `defaults.run.working-directory`, so a workflow that ran every step in
  another directory was credited with this repository's Makefile.
- It checked that lint reaches three of the five gates the kit installs.
  Removing `kb-shape` from the lint line left it green.

The first forces a choice, because reachability is a property of the set of
workflows, not of one file.

- **Reject every reusable workflow.** Sound and simple, and it fails a
  repository whose pull-request workflow calls a local `lint.yml` — an
  ordinary arrangement, and one whose files the gate can read.
- **Follow calls, to wherever they lead.** A call into another repository
  names a file that is not on disk. Fetching it needs the network and
  credentials, and the kit has neither by rule.
- **Follow local calls, and credit nothing else.**

Behind it is a wider point the gate's header never stated. It reads text and
runs nothing. It cannot know that an `if:` is false at run time, that a
matrix is empty, that a path filter excludes every change, or what a script
that a step calls goes on to run. No amount of parsing closes that.

## Decision

We will make the gate one-sided: a form it cannot read is never counted as
coverage, and its header says what "covered" means.

A step's `run:` counts when its workflow is started by `push`, `pull_request`,
`pull_request_target` or `merge_group` — or is a reusable workflow reached
from such a workflow through `uses: ./.github/workflows/<file>`, directly or
through other reusable workflows that are themselves reached. The walk keeps
the set of workflows it has reached, which is also what ends it when two
workflows call each other.

Not counted, each with a line in the failure message saying what was seen: a
reusable workflow nothing reaches; a call into another repository; a `uses:`
that is not a literal local path; a call to a file that is missing, unreadable
or has no `workflow_call` trigger; a caller job switched off with `if: false`.

The working directory of a step is its own, else its job's default, else its
workflow's, else the repository root. A caller's defaults do not follow a
call.

Lint must reach every gate the kit has installed in the repository:
`registry-drift`, `registry-ids`, `kb-shape`, `graph-links`,
`ci-lint-coverage`. The two registry gates are always owed; each of the
others is owed where its script is present, so an install from before a gate
existed is not held to it. `constitution` is not in the list (ADR-0009).

## Consequences

**Easier.** The three false passes are closed, each with a failing case and a
control in `test-ci-lint-coverage.sh`. A failure says which workflow or call
was read and not counted, so the reader is not left to guess why a workflow
that plainly contains `make lint` did not satisfy the gate.

**Harder.** A repository that keeps its lint workflow in a shared repository
and calls it by `owner/repo/…@ref` fails the gate, correctly from the gate's
side and inconveniently from theirs. The way through is the allowlist, with
the reason written beside the entry — an explicit exemption instead of an
assumed pass.

**Breaking, by ADR-0008.** Three shapes that passed now fail, and each is
repaired in a file of the adopter's: a workflow nothing calls, a workflow-level
working directory elsewhere, and a `lint:` line of their own that leaves out
`kb-shape` or `ci-lint-coverage`. Every lint line the kit has ever printed
named both, so the last needs a Makefile that departed from all of them.

**Still not established.** That CI ran. The gate shows that a step which is
not visibly switched off names the target. Proof is the run itself.

**Related:** ADR-0008, ADR-0009, SCRIPT:check-ci-lint-coverage.sh, RULE:shared-registries
