#!/usr/bin/env bash
# Tests for check-ci-lint-coverage.sh.
#
# This gate exists to catch checks that are chained into the lint target but
# never invoked by CI. Its own failure mode is passing when it should not, and
# that failure is quiet — a green gate that gates nothing looks exactly like a
# green gate that works. So the cases below assert both directions, and the
# first one is here because the gate really did pass on a workflow that only
# mentioned the target inside a comment.
set -uo pipefail

GATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/check-ci-lint-coverage.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
ok()  { printf '  ok   — %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL — %s\n' "$1"; fail=$((fail + 1)); }

# scenario <name> <expected-exit> <makefile> <workflow> [allowlist]
scenario() {
  local name="$1" expected="$2" makefile="$3" workflow="$4" allowlist="${5:-}"
  local dir; dir="$(mktemp -d "$WORK/case.XXXXXX")"
  mkdir -p "$dir/.github/workflows"
  git -C "$dir" init -q -b main
  printf '%b' "$makefile"  > "$dir/Makefile"
  printf '%b' "$workflow"  > "$dir/.github/workflows/lint.yml"
  [ -n "$allowlist" ] && printf '%b' "$allowlist" > "$dir/.ci-lint-coverage-allowlist"

  local actual; ( cd "$dir" && "$GATE" >/dev/null 2>&1 ); actual=$?
  if [ "$actual" -eq "$expected" ]; then
    ok "$name"
  else
    bad "$name (expected exit $expected, got $actual)"
  fi
}

MAKEFILE='lint: alpha beta\nalpha:\n\t@true\nbeta:\n\t@true\n'
HEADER='name: lint\non: [pull_request]\njobs:\n  lint:\n    steps:\n'

scenario "a comment mentioning the target does not satisfy the gate" 1 \
  "$MAKEFILE" "${HEADER}      # this workflow used to run make lint\n      - run: echo nothing\n"

scenario "invoking the aggregate target covers every sub-target" 0 \
  "$MAKEFILE" "${HEADER}      # a comment that also says make lint\n      - run: make lint\n"

# The gate reads the workflow FILE. Its "OK" stood in every lint run of a
# repository whose workflow had never completed a single run — each one ended
# after seconds, before any step. What a file says and what ran are different
# facts, and a message that reads as the second while checking the first is
# how four pull requests were merged unchecked.
dir="$(mktemp -d "$WORK/case.XXXXXX")"; mkdir -p "$dir/.github/workflows"; git -C "$dir" init -q -b main
printf '%b' "$MAKEFILE" > "$dir/Makefile"
printf '%b' "${HEADER}      - run: make lint\n" > "$dir/.github/workflows/lint.yml"
out="$( cd "$dir" && "$GATE" 2>&1 )"; rc=$?
if [ "$rc" -eq 0 ] && [[ "$out" == OK:* ]] && [[ "$out" == *"not that a run"* ]] && [[ "$out" == *"gh run list"* ]]; then
  ok "a passing gate says what it read — the workflow file — and how to see whether a run completed"
else
  bad "the OK line claims coverage without saying a run is not checked (exit $rc): $(printf '%s' "$out" | head -2 | tr '\n' ' ')"
fi

scenario "enumerating every sub-target individually passes" 0 \
  "$MAKEFILE" "${HEADER}      - run: make alpha\n      - run: make beta\n"
# The other way to pass says the same about itself, and no longer "runs in CI".
dir="$(mktemp -d "$WORK/case.XXXXXX")"; mkdir -p "$dir/.github/workflows"; git -C "$dir" init -q -b main
printf '%b' "$MAKEFILE" > "$dir/Makefile"
printf '%b' "${HEADER}      - run: make alpha\n      - run: make beta\n" > "$dir/.github/workflows/lint.yml"
out="$( cd "$dir" && "$GATE" 2>&1 )"; rc=$?
if [ "$rc" -eq 0 ] && [[ "$out" == *"is invoked by a CI workflow step"* ]] && [[ "$out" != *"runs in CI"* ]] && [[ "$out" == *"not that a run"* ]]; then
  ok "a gate that passes on enumerated steps says they are invoked by a workflow step, not that they ran"
else
  bad "the enumerated success path still claims the checks run in CI (exit $rc): $(printf '%s' "$out" | tail -2 | tr '\n' ' ')"
fi

scenario "a sub-target missing from every workflow fails" 1 \
  "$MAKEFILE" "${HEADER}      - run: make alpha\n"

scenario "make flags before the target still count as invoking it" 0 \
  "$MAKEFILE" "${HEADER}      - run: make -C . lint\n"

scenario "a target that merely shares a prefix does not count" 1 \
  "$MAKEFILE" "${HEADER}      - run: make alpha\n      - run: make betamax\n"

scenario "an allowlisted sub-target is exempt" 0 \
  "$MAKEFILE" "${HEADER}      - run: make alpha\n" \
  "# beta runs in the nightly workflow instead\nbeta\n"

scenario "a stale allowlist entry naming no sub-target fails" 1 \
  "$MAKEFILE" "${HEADER}      - run: make alpha\n      - run: make beta\n" \
  "gamma\n"

scenario "an empty Makefile has no sub-targets to cover" 0 \
  "" "${HEADER}      - run: echo nothing\n"

# Mentions are not invocations. Each of these passed before the gate read only
# the `run:` value of a step, as shell.
scenario "a trailing shell comment naming the target does not count" 1 \
  "$MAKEFILE" "${HEADER}      - run: echo hi # make lint\n"

scenario "the target inside an echoed string does not count" 1 \
  "$MAKEFILE" "${HEADER}      - run: echo \"run make lint locally\"\n"

scenario "a step NAME that says make lint does not count" 1 \
  "$MAKEFILE" "${HEADER}      - name: make lint\n        run: echo nothing\n"

scenario "make -n (a dry run) does not run the target" 1 \
  "$MAKEFILE" "${HEADER}      - run: make -n lint\n"

scenario "make -C <another directory> runs another Makefile" 1 \
  "$MAKEFILE" "${HEADER}      - run: make -C sub lint\n"

scenario "make after cd elsewhere runs another Makefile" 1 \
  "$MAKEFILE" "${HEADER}      - run: cd sub && make lint\n"

scenario "a step with a working-directory runs another Makefile" 1 \
  "$MAKEFILE" "${HEADER}      - run: make lint\n        working-directory: sub\n"

scenario "a job switched off with if: false covers nothing" 1 \
  "$MAKEFILE" "name: lint\non: [pull_request]\njobs:\n  lint:\n    if: false\n    steps:\n      - run: make lint\n"

scenario "a workflow that only runs by hand gates no pull request" 1 \
  "$MAKEFILE" "name: lint\non:\n  workflow_dispatch:\njobs:\n  lint:\n    steps:\n      - run: make lint\n"

# What a real workflow looks like still counts.
scenario "a multi-line run block with flags and a push trigger counts" 0 \
  "$MAKEFILE" "name: lint\non:\n  pull_request:\n  push:\n    branches: [main]\njobs:\n  lint:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n      - name: Run every check\n        run: |\n          set -e\n          make -s -j4 lint  # all of it\n"

scenario "an env assignment before make still counts" 0 \
  "$MAKEFILE" "${HEADER}      - run: PYTHONDONTWRITEBYTECODE=1 make lint\n"

# Before the gate read the run values, `grep -q` under pipefail on a large
# workflow got SIGPIPE and reported a covered target as missing (red in a
# consuming project once its ci.yml grew).
big="${HEADER}      - run: make lint\n"
for i in $(seq 1 4000); do big="${big}      - run: echo filler step $i with enough text to make the file large\n"; done
scenario "a covered target in a large workflow is found" 0 "$MAKEFILE" "$big"

# The registry-gate reachability check had the same SIGPIPE: `make -n lint`
# printed a lot, grep -q stopped at the first match, and a reached gate read
# as "never runs it".
dir="$(mktemp -d "$WORK/case.XXXXXX")"; mkdir -p "$dir/.github/workflows" "$dir/scripts"; git -C "$dir" init -q -b main
printf '{"registries": []}\n' > "$dir/registries.json"
touch "$dir/scripts/check-registry-drift.sh" "$dir/scripts/check-registry-ids.sh"
{ printf 'lint:\n\t@./scripts/check-registry-drift.sh\n\t@./scripts/check-registry-ids.sh\n'
  for i in $(seq 1 20000); do printf '\t@echo filler line %s for a long dry run\n' "$i"; done
} > "$dir/Makefile"
printf "${HEADER}      - run: make lint\n" > "$dir/.github/workflows/lint.yml"
if ( cd "$dir" && "$GATE" >/dev/null 2>&1 ); then ok "a registry gate reached by a long lint recipe is found (no SIGPIPE)"
else bad "a registry gate reached by a long lint recipe was reported as never run"; fi

# The link gate is held to the same standard — but only where it is installed.
# The case above has no check-graph-links.sh and passed: a repository that
# adopted the kit before the gate existed owes it nothing.
dir="$(mktemp -d "$WORK/case.XXXXXX")"; mkdir -p "$dir/.github/workflows" "$dir/scripts"; git -C "$dir" init -q -b main
printf '{"registries": []}\n' > "$dir/registries.json"
touch "$dir/scripts/check-registry-drift.sh" "$dir/scripts/check-registry-ids.sh" "$dir/scripts/check-graph-links.sh"
printf 'lint:\n\t@./scripts/check-registry-drift.sh\n\t@./scripts/check-registry-ids.sh\n' > "$dir/Makefile"
printf "${HEADER}      - run: make lint\n" > "$dir/.github/workflows/lint.yml"
if ( cd "$dir" && "$GATE" >/dev/null 2>&1 ); then bad "an installed link gate that lint never runs passed the coverage gate"
else ok "an installed link gate that lint never runs is reported (green-but-empty is detected)"; fi
printf 'lint:\n\t@./scripts/check-registry-drift.sh\n\t@./scripts/check-registry-ids.sh\n\t@./scripts/check-graph-links.sh\n' > "$dir/Makefile"
if ( cd "$dir" && "$GATE" >/dev/null 2>&1 ); then ok "once lint reaches the link gate the coverage gate is green"
else bad "a link gate that lint reaches was reported as never run"; fi

# --- workflow-level defaults -------------------------------------------------
# `defaults.run.working-directory` can be set for the whole workflow, for a
# job, and a step can name its own; the nearest one wins. The gate read the
# job's and the step's and not the workflow's, so a workflow that ran every
# step in another directory was credited with this Makefile.
WF='name: lint\non: [pull_request]\ndefaults:\n  run:\n    working-directory: %s\njobs:\n  lint:\n%s    steps:\n      - run: make lint\n%s'
JOBDIR='    defaults:\n      run:\n        working-directory: %s\n'
wf() { # $1 = workflow default dir, $2 = job default dir or "", $3 = step dir or ""
  local job="" step=""
  [ -n "$2" ] && job="$(printf "$JOBDIR" "$2")\n"
  [ -n "$3" ] && step="        working-directory: $3\n"
  printf "$WF" "$1" "$job" "$step"
}
scenario "a workflow-level working-directory elsewhere runs another Makefile" 1 "$MAKEFILE" "$(wf unrelated "" "")"
scenario "control: a workflow-level working-directory of . is this directory" 0 "$MAKEFILE" "$(wf . "" "")"
scenario "a job default of . overrides a workflow default elsewhere" 0 "$MAKEFILE" "$(wf unrelated . "")"
scenario "a step working-directory of . overrides a workflow default elsewhere" 0 "$MAKEFILE" "$(wf unrelated "" .)"
scenario "a step working-directory of . overrides a job default elsewhere" 0 "$MAKEFILE" "$(wf . unrelated .)"
scenario "a job default elsewhere overrides a workflow default of ." 1 "$MAKEFILE" "$(wf . unrelated "")"
scenario "a step working-directory elsewhere overrides job and workflow defaults of ." 1 "$MAKEFILE" "$(wf . . sub)"
scenario "a job default elsewhere, with no workflow default, runs another Makefile" 1 \
  "$MAKEFILE" "name: lint\non: [pull_request]\njobs:\n  lint:\n    defaults:\n      run:\n        working-directory: sub\n    steps:\n      - run: make lint\n"

# --- reusable workflows --------------------------------------------------------
# `on: workflow_call` makes a workflow callable; it does not make anything call
# it. The gate counted the trigger itself, so a reusable workflow no other
# workflow used was credited with every target it named. It counts now only
# when a workflow that a push, pull request or merge queue triggers reaches it
# through `uses: ./.github/workflows/<file>` — directly or through other
# reusable workflows.
#
# scenario_files <name> <expected-exit> <file>=<content>...
scenario_files() {
  local name="$1" expected="$2"; shift 2
  local dir pair; dir="$(mktemp -d "$WORK/case.XXXXXX")"
  mkdir -p "$dir/.github/workflows"
  git -C "$dir" init -q -b main
  printf '%b' "$MAKEFILE" > "$dir/Makefile"
  for pair in "$@"; do printf '%b' "${pair#*=}" > "$dir/.github/workflows/${pair%%=*}"; done
  local actual; ( cd "$dir" && "$GATE" >/dev/null 2>&1 ); actual=$?
  if [ "$actual" -eq "$expected" ]; then ok "$name"; else bad "$name (expected exit $expected, got $actual)"; fi
}
REUSABLE='name: reusable\non:\n  workflow_call:\njobs:\n  lint:\n    runs-on: ubuntu-latest\n    steps:\n      - run: make lint\n'
calls() { # $1 = trigger line(s), $2 = what the job uses, $3 = optional extra job lines
  printf 'name: caller\non:\n%s\njobs:\n  call:\n%s    uses: %s\n' "$1" "${3:-}" "$2"
}

scenario_files "a reusable workflow that nothing calls covers nothing" 1 \
  "lint.yml=$REUSABLE"
scenario_files "control: the same workflow, called from a pull-request workflow, covers the target" 0 \
  "lint.yml=$REUSABLE" "ci.yml=$(calls '  pull_request:' ./.github/workflows/lint.yml)"
scenario_files "a reusable workflow reached through a second reusable workflow covers the target" 0 \
  "lint.yml=$REUSABLE" \
  "middle.yaml=$(calls '  workflow_call:' ./.github/workflows/lint.yml)" \
  "ci.yml=$(calls '  push:' ./.github/workflows/middle.yaml)"
scenario_files "a reusable workflow called only from a workflow that runs by hand covers nothing" 1 \
  "lint.yml=$REUSABLE" "manual.yml=$(calls '  workflow_dispatch:' ./.github/workflows/lint.yml)"
scenario_files "a reusable workflow called only from a job switched off with if: false covers nothing" 1 \
  "lint.yml=$REUSABLE" "ci.yml=$(calls '  pull_request:' ./.github/workflows/lint.yml '    if: false\n')"
scenario_files "a reusable workflow called only by another uncalled reusable workflow covers nothing" 1 \
  "lint.yml=$REUSABLE" "middle.yml=$(calls '  workflow_call:' ./.github/workflows/lint.yml)"
# Two workflows that call each other and that nothing triggers: the walk has to
# end, and end at "covers nothing".
scenario_files "two reusable workflows that only call each other end the walk and cover nothing" 1 \
  "a.yml=name: a\non:\n  workflow_call:\njobs:\n  next:\n    uses: ./.github/workflows/b.yml\n" \
  "b.yml=name: b\non:\n  workflow_call:\njobs:\n  back:\n    uses: ./.github/workflows/a.yml\n  lint:\n    steps:\n      - run: make lint\n"
scenario_files "the same cycle, entered from a pull-request workflow, ends the walk and covers the target" 0 \
  "a.yml=name: a\non:\n  workflow_call:\njobs:\n  next:\n    uses: ./.github/workflows/b.yml\n" \
  "b.yml=name: b\non:\n  workflow_call:\njobs:\n  back:\n    uses: ./.github/workflows/a.yml\n  lint:\n    steps:\n      - run: make lint\n" \
  "ci.yml=$(calls '  pull_request:' ./.github/workflows/a.yml)"
scenario_files "a workflow that a pull request triggers and that is also callable counts on its own" 0 \
  "lint.yml=name: both\non:\n  pull_request:\n  workflow_call:\njobs:\n  lint:\n    steps:\n      - run: make lint\n"
# What the gate cannot read it does not credit. A workflow in another
# repository is not on disk; a `uses:` built from an expression names no file.
scenario_files "a call into another repository proves nothing about this one" 1 \
  "lint.yml=$REUSABLE" "ci.yml=$(calls '  pull_request:' octo-org/shared/.github/workflows/lint.yml@v1)"
scenario_files "a call whose path is an expression proves nothing" 1 \
  "lint.yml=$REUSABLE" "ci.yml=$(calls '  pull_request:' './.github/workflows/${{ vars.WORKFLOW }}')"
scenario_files "a call to a local workflow that is not callable (no workflow_call) covers nothing" 1 \
  "lint.yml=name: manual\non:\n  workflow_dispatch:\njobs:\n  lint:\n    steps:\n      - run: make lint\n" \
  "ci.yml=$(calls '  pull_request:' ./.github/workflows/lint.yml)"
scenario_files "a call to a local workflow file that does not exist covers nothing" 1 \
  "lint.yml=$REUSABLE" "ci.yml=$(calls '  pull_request:' ./.github/workflows/absent.yml)"
# The caller's defaults are the caller's: they do not follow the call.
scenario_files "a called workflow runs in its own directory, whatever default its caller sets" 0 \
  "lint.yml=$REUSABLE" \
  "ci.yml=name: caller\non:\n  pull_request:\ndefaults:\n  run:\n    working-directory: elsewhere\njobs:\n  call:\n    uses: ./.github/workflows/lint.yml\n"

# --- every installed gate is reached by lint -----------------------------------
# The reachability check named three of the five gates. Take `kb-shape` out of
# the lint line of a complete install and the coverage gate stayed green: the
# knowledge-base check was installed, described as enforced, and never run.
ALL_GATES="check-registry-drift.sh check-registry-ids.sh check-kb-shape.sh check-graph-links.sh check-ci-lint-coverage.sh"
installed() { # $1 = gate scripts present in scripts/, $2 = gate scripts the lint recipe runs
  local dir gate; dir="$(mktemp -d "$WORK/case.XXXXXX")"
  mkdir -p "$dir/.github/workflows" "$dir/scripts"; git -C "$dir" init -q -b main
  printf '{"registries": []}\n' > "$dir/registries.json"
  for gate in $1; do : > "$dir/scripts/$gate"; done
  { printf 'lint:\n'; for gate in $2; do printf '\t@./scripts/%s\n' "$gate"; done; } > "$dir/Makefile"
  printf "${HEADER}      - run: make lint\n" > "$dir/.github/workflows/lint.yml"
  ( cd "$dir" && "$GATE" 2>&1 )
}
out="$(installed "$ALL_GATES" "$ALL_GATES")" \
  && ok "control: a complete install whose lint runs all five gates passes" \
  || bad "a complete install was rejected: $out"
for missing in $ALL_GATES; do
  rest="$(printf '%s\n' $ALL_GATES | grep -vx "$missing" | tr '\n' ' ')"
  if out="$(installed "$ALL_GATES" "$rest")"; then
    bad "$missing is installed, lint never runs it, and the coverage gate passed"
  else
    case "$out" in
      *"scripts/$missing is installed but 'lint' never runs it"*) ok "$missing installed but not run by lint is reported, by name" ;;
      *) bad "$missing unchained failed the gate without naming it: $out" ;;
    esac
  fi
done
# Older installs. A gate the repository never received is not owed: each
# release added gates, and a repository is held to the ones it has.
out="$(installed "check-registry-drift.sh check-registry-ids.sh check-kb-shape.sh check-ci-lint-coverage.sh" \
                 "check-registry-drift.sh check-registry-ids.sh check-kb-shape.sh check-ci-lint-coverage.sh")" \
  && ok "a 1.x install — no link gate on disk — passes with the four gates it has" \
  || bad "a 1.x install was held to a gate it never received: $out"
if out="$(installed "check-registry-drift.sh check-registry-ids.sh check-kb-shape.sh check-ci-lint-coverage.sh" \
                    "check-registry-drift.sh check-registry-ids.sh check-ci-lint-coverage.sh")"; then
  bad "a 1.x install that has check-kb-shape.sh and never runs it passed"
else
  ok "a 1.x install is held to kb-shape too: every 1.x lint line named it"
fi
# 0.1.0 shipped the knowledge-base check and no registry layer. Without
# registries.json there is no layer to hold a lint target to.
dir="$(mktemp -d "$WORK/case.XXXXXX")"; mkdir -p "$dir/.github/workflows" "$dir/scripts"; git -C "$dir" init -q -b main
: > "$dir/scripts/check-kb-shape.sh"
printf 'lint:\n\t@echo project checks\n' > "$dir/Makefile"
printf "${HEADER}      - run: make lint\n" > "$dir/.github/workflows/lint.yml"
( cd "$dir" && "$GATE" >/dev/null 2>&1 ) \
  && ok "a 0.1.0 install — the knowledge-base check and no registry layer — is not held to it" \
  || bad "a repository with no registry layer was told to chain the registry gates"

echo ""
echo "=== $pass passed, $fail failed ==="
[ "$fail" -eq 0 ] || exit 1
