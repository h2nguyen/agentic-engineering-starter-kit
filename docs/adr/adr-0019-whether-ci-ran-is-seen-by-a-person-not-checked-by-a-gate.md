# Whether CI ran is seen by a person, not checked by a gate

## Status

Accepted

## Context

The kit's coverage gate, `check-ci-lint-coverage.sh`, exists because a check
chained into `make lint` and never invoked by a workflow does not run, and
nothing says so. ADR-0010 settled what the gate counts: only what it can read
in the workflow files.

In the first install outside the kit's fixtures the gate printed `OK: CI
invokes 'make lint' directly` in every lint, and it was right about what it
read. Every run of that workflow ended within seconds, before its first
step — a billing stop on the account. Four pull requests were merged that
way, on a default branch that required no check. The kit's maxim, "a Makefile
target is not a CI step", holds one stage further, and the kit did not say
so: its texts went on from "the workflow invokes the target" to "the check
runs in CI", in the gate's header, in `registry.mk`, in the guide and in the
contributor notes.

Three ways to close it were weighed.

- **A gate that asks the hosting platform.** It needs the network, a
  credential and one platform's API. The kit is Bash and the Python standard
  library with no network, on purpose: a lint that fails offline, or passes
  differently for a contributor without access, is worse than no gate. And a
  repository with no run yet — a fresh install — would be red by design.
- **Say nothing more, and rely on the adopter noticing.** That is what
  happened.
- **Say what the gate read, and make seeing a run a named step of the
  setup.**

## Decision

We will not gate on CI runs. The coverage gate keeps reading the workflow
files, and its success message says so and names the command that shows a
run. Every text that said a check "runs in CI" on the strength of that gate
says "is invoked by a CI workflow step".

Seeing a run is a step of the setup, in the installer's first-install
message, the setup prompt, the kit's `AGENTS.md`, both READMEs, the installed
workflow's header and the shared-registries rule with its reference:

- once the pull request is open — the installed workflow starts on a pull
  request and on a push to the default branch, not on the push of a feature
  branch — a run of the lint workflow completed with success;
- then `lint` is made a required status check on the default branch.

An agent that was not asked to push, or cannot see the runs, says "CI not
confirmed" and why. It never reports CI as green from a workflow file. The
required check is named separately: it needs rights an installing agent
often does not have.

## Consequences

**Easier.** The gate's message can no longer be read as a claim about runs.
A handoff states what was seen.

**Harder.** The step is done by whoever opens the pull request, and nothing
fails if they skip it. This is a rule deliberately left without a gate, and
the reason is the one above, not that nobody got round to it.

**Not covered.** Hosting platforms other than GitHub: the commands named are
`gh`'s, and the principle is the platform's own list of runs. A merge queue
needs the `merge_group` trigger before the check is required; the workflow's
header says so.

**Trigger to revisit.** If the kit ever ships something that already talks
to the hosting platform, a check of the last run on the default branch can
ride on it.

**Related:** ADR-0010, SCRIPT:check-ci-lint-coverage.sh, RULE:shared-registries
