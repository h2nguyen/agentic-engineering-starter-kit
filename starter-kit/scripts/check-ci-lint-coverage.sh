#!/usr/bin/env bash
# Enforces: RULE:shared-registries § A Makefile target is not a CI step —
# every check chained into the umbrella lint target actually runs in CI.
#
# The failure this prevents is not hypothetical and not loud. A repository
# gains checks by adding them to `make lint`, while its workflow enumerates
# sub-targets one `run:` step at a time. The two lists drift apart one pull
# request at a time, and nothing reports it: the checks still pass locally, the
# rule files still claim the conventions are enforced, and the gates that stop
# running are discovered only by the bug they were supposed to catch.
#
# The cheap fix is for CI to invoke the aggregate target — then coverage is
# total by construction and this script exits immediately. Enumerating is only
# worth it when jobs need per-path gating, and that is when this gate earns
# its place.
#
# Usage: check-ci-lint-coverage.sh [lint-target] [makefile]
#        default target: lint       default makefile: Makefile
set -euo pipefail
# Python under whatever name this machine gives it; the fallback is for a
# repository that copied this gate from a newer kit without the launcher.
PYTHON_RUN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/python.sh"; [ -x "$PYTHON_RUN" ] || PYTHON_RUN=python3

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

TARGET="${1:-lint}"
MAKEFILE="${2:-Makefile}"
fail=0
ALLOWLIST=".ci-lint-coverage-allowlist"
WORKFLOW_DIR=".github/workflows"

if [ ! -f "$MAKEFILE" ]; then
  echo "SKIP: no $MAKEFILE — nothing to cross-check."
  exit 0
fi
if [ ! -d "$WORKFLOW_DIR" ]; then
  echo "SKIP: no $WORKFLOW_DIR — nothing to cross-check."
  exit 0
fi

# The kit's own gates must actually be reached by the umbrella target. On a
# brownfield repository the installer cannot edit an existing Makefile, so the
# scripts land in scripts/ while `make lint` keeps running only what it ran
# before — green, and checking nothing of the registry layer. `make -n lint`
# prints every command the target would run, transitively, which is the exact
# question: would every gate the kit installed here execute?
#
# All five, this one included. The list used to stop at three, and a lint
# line that dropped `kb-shape` left the knowledge-base check installed,
# described as enforced, and never run — with this gate green.
if [ -f registries.json ] && [ -f scripts/check-registry-drift.sh ]; then
  dry="$(make -n "$TARGET" -f "$MAKEFILE" 2>/dev/null || true)"
  for gate in check-registry-drift.sh check-registry-ids.sh check-kb-shape.sh check-graph-links.sh check-ci-lint-coverage.sh; do
    # The gates arrived over several releases, and a repository is held to the
    # ones it has: an install from before the link gate has no such file and
    # owes it nothing. The two registry gates came together and are always owed.
    case "$gate" in
      check-registry-drift.sh|check-registry-ids.sh) ;;
      *) [ -f "scripts/$gate" ] || continue ;;
    esac
    # A pattern match, not `printf | grep -q`: grep -q exits at the first match,
    # the writer gets SIGPIPE on a large dry run, and pipefail turned a gate that
    # IS reached into "never runs it".
    if [[ "$dry" != *"$gate"* ]]; then
      echo "FAIL: scripts/$gate is installed but '$TARGET' never runs it."
      _target="${gate#check-}"; _target="${_target%.sh}"
      echo "  The gate exists and gates nothing. Add '$_target' to the umbrella target:"
      echo "      include registry.mk"
      echo "      lint: registry-drift registry-ids kb-shape graph-links ci-lint-coverage <your existing prerequisites>"
      echo "  See the shared-registries rule § 'A Makefile target is not a CI step'."
      fail=1
    fi
  done
fi

# Prerequisites of the umbrella target, e.g. "lint: a b c" -> a b c
prereqs="$(sed -n "s/^${TARGET}:[[:space:]]*//p" "$MAKEFILE" | head -1 | tr ' ' '\n' | sed '/^$/d' || true)"
if [ -z "$prereqs" ]; then
  [ "$fail" -eq 0 ] && echo "OK: '$TARGET' has no sub-targets to cover."
  exit "$fail"
fi

workflows="$(find "$WORKFLOW_DIR" -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null || true)"
if [ -z "$workflows" ]; then
  echo "SKIP: no workflow files found."
  exit 0
fi

# The make targets CI really runs. Text that merely MENTIONS a target must not
# count — a check that passes on a comment is exactly the kind of gate that
# silently stops gating — and neither must a run that cannot reach this
# Makefile. So only the `run:` value of a step counts, read as shell, and only:
#   - in a workflow a push, pull request or merge queue triggers, never one
#     that only runs by hand or on a schedule;
#   - or in a reusable workflow (`on: workflow_call`) that such a workflow
#     reaches through `uses: ./.github/workflows/<file>`, directly or through
#     other reusable workflows. Being callable is not being called: a reusable
#     workflow that nothing reaches covers nothing;
#   - in a job and step that are not switched off with `if: false`;
#   - in this directory — the step's `working-directory`, else the job's
#     default, else the workflow's, else the root; no `cd elsewhere`,
#     `make -C dir` or `make -f other` — and for real, not `make -n`/`-q`/`-t`.
#
# What this can and cannot establish. It reads text and runs nothing. It
# cannot know that a job's `if:` turns out false at run time, that a matrix is
# empty, that a branch or path filter excludes every change, or what a script
# a step calls goes on to do. So it errs one way on purpose: a form it cannot
# read is never counted as coverage — a workflow in another repository
# (`owner/repo/…@ref`), a `uses:` built from an expression, a workflow that is
# not block-style YAML, a `make` reached through a wrapper script, a variable
# or `eval`. "Covered" means a step that is not visibly switched off names the
# target: evidence that CI runs it, not proof.
#
# A deliberately small YAML reader (block style, which is how workflows are
# written): the kit stays stdlib-only, and an unreadable workflow covers nothing.
# A function, not a here-document inside $(…), which bash 3.2 misparses.
list_ci_targets() {
"$PYTHON_RUN" - "$MAKEFILE" $workflows <<'PY'
import os, re, shlex, sys

makefile, files = sys.argv[1], sys.argv[2:]
AUTOMATIC = {"push", "pull_request", "pull_request_target", "merge_group"}
# The one form of call that names a file on disk. A local call takes no @ref.
LOCAL_CALL = re.compile(r"\./(\.github/workflows/[^/@\s${}]+\.ya?ml)")


def plain(text):
    text = text.strip()
    if len(text) > 1 and text[0] in "\"'" and text[-1] == text[0]:
        return text[1:-1]
    return re.sub(r"\s+#.*$", "", text).strip()


KEY = r"(\"[^\"]*\"|'[^']*'|[^\s:#\[{][^:#]*?)\s*:"


class Reader:
    def __init__(self, text):
        self.lines, self.i = text.splitlines(), 0

    def at(self):
        while self.i < len(self.lines) and (
            not self.lines[self.i].strip() or self.lines[self.i].lstrip().startswith("#")
        ):
            self.i += 1
        if self.i >= len(self.lines):
            return None, None
        line = self.lines[self.i]
        return len(line) - len(line.lstrip(" ")), line.lstrip(" ")

    def node(self, deeper_than):
        indent, text = self.at()
        if indent is None or indent <= deeper_than:
            return None
        return self.seq(indent) if text == "-" or text.startswith("- ") else self.mapping(indent)

    def mapping(self, indent):
        out = {}
        while True:
            here, text = self.at()
            if here is None or here < indent or text.startswith("- "):
                return out
            self.i += 1
            match = re.match(KEY + r"(?:\s+(.*))?$", text) if here == indent else None
            if match:
                out[match.group(1).strip("\"'")] = self.value(match.group(2) or "", indent)

    def value(self, rest, indent):
        rest = rest.strip()
        if re.fullmatch(r"[|>][+-]?\d*(\s+#.*)?", rest):
            block = []
            while self.i < len(self.lines):
                line = self.lines[self.i]
                if line.strip() and len(line) - len(line.lstrip(" ")) <= indent:
                    break
                block.append(line)
                self.i += 1
            return "\n".join(block)
        if rest and not rest.startswith("#"):
            if rest.startswith("[") and rest.endswith("]"):
                return [plain(x) for x in rest[1:-1].split(",") if x.strip()]
            return plain(rest)
        here, text = self.at()
        if here == indent and (text == "-" or text.startswith("- ")):
            return self.seq(indent)  # a list may sit at its key's indentation
        return self.node(indent)

    def seq(self, indent):
        out = []
        while True:
            here, text = self.at()
            if here != indent or not (text == "-" or text.startswith("- ")):
                return out
            content = text[1:].lstrip(" ")
            column = indent + len(text) - len(content)
            if re.match(KEY + r"(\s|$)", content):
                self.lines[self.i] = " " * column + content  # a mapping opens on the dash line
                out.append(self.mapping(column))
            else:
                self.i += 1
                out.append(plain(content) if content else self.node(indent))


def off(condition):
    return str(condition).strip().lower().replace(" ", "") in ("false", "${{false}}")


def same(path, expected):
    return os.path.normpath(path or ".") == os.path.normpath(expected)


def make_targets(args):
    """The targets one `make` invocation builds here — none if it cannot."""
    targets, i = [], 0
    while i < len(args):
        arg = args[i]
        if arg.startswith("--"):
            name, eq, val = arg.partition("=")
            if name in ("--dry-run", "--just-print", "--recon", "--question", "--touch"):
                return []
            if name in ("--directory", "--file", "--makefile", "--include-dir", "--old-file",
                        "--assume-old", "--what-if", "--new-file", "--assume-new", "--eval"):
                if not eq:
                    i += 1
                    val = args[i] if i < len(args) else ""
                if name == "--directory" and not same(val, "."):
                    return []
                if name in ("--file", "--makefile") and not same(val, makefile):
                    return []
        elif arg.startswith("-") and len(arg) > 1:
            for j, flag in enumerate(arg[1:], 1):
                if flag in "nqt":
                    return []
                if flag in "CfIoW":
                    val = arg[j + 1:]
                    if not val:
                        i += 1
                        val = args[i] if i < len(args) else ""
                    if (flag == "C" and not same(val, ".")) or (flag == "f" and not same(val, makefile)):
                        return []
                    break
                if flag in "jl":
                    if not arg[j + 1:] and i + 1 < len(args) and re.fullmatch(r"\d+(\.\d+)?", args[i + 1]):
                        i += 1
                    break
        elif "=" not in arg:
            targets.append(arg)
        i += 1
    return targets


def run_targets(script):
    try:
        # A line break ends a command like `;` does — after the newline, so a
        # trailing comment cannot swallow it; a backslash continues the line.
        text = re.sub(r"\\\n", " ", script).replace("\n", "\n;")
        lexer = shlex.shlex(text, posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        tokens = list(lexer)
    except ValueError:
        return []
    found, words, elsewhere = [], [], False
    for token in tokens + [";"]:
        if not set(token) <= set("&|;()"):
            words.append(token)
            continue
        while words and re.match(r"[A-Za-z_]\w*=", words[0]):
            words = words[1:]
        while words and words[0] in ("time", "env", "command", "exec"):
            words = words[1:]
        if words and words[0] == "cd":
            elsewhere = not (len(words) > 1 and same(words[1], "."))
        elif words and os.path.basename(words[0]) in ("make", "gmake") and not elsewhere:
            found += make_targets(words[1:])
        words = []
    return found


def triggers(workflow):
    on = workflow.get("on", workflow.get("true"))
    return {on} if isinstance(on, str) else set(on or [])


def working_directory(scope):
    """The `defaults.run.working-directory` a workflow or a job sets, if any."""
    defaults = scope.get("defaults") if isinstance(scope.get("defaults"), dict) else {}
    run = defaults.get("run") if isinstance(defaults.get("run"), dict) else {}
    return run.get("working-directory")


def active_jobs(workflow):
    jobs = workflow.get("jobs")
    for name, job in (jobs.items() if isinstance(jobs, dict) else []):
        if isinstance(job, dict) and not off(job.get("if", "")):
            yield name, job


workflows = {}
for path in files:
    try:
        workflow = Reader(open(path, encoding="utf-8").read()).node(-1)
    except (OSError, UnicodeDecodeError):
        continue
    if isinstance(workflow, dict):
        workflows[os.path.normpath(path)] = workflow

# Which workflows run without anyone asking: the ones an automatic trigger
# starts, and the reusable ones those reach. `reached` is also what ends the
# walk when two workflows call each other.
notes = []
reached = [path for path in sorted(workflows) if triggers(workflows[path]) & AUTOMATIC]
for path in reached:  # grows while it is walked
    for name, job in active_jobs(workflows[path]):
        uses = job.get("uses")
        if uses is None:
            continue
        match = LOCAL_CALL.fullmatch(str(uses).strip())
        callee = os.path.normpath(match.group(1)) if match else None
        if callee is None:
            notes.append("%s: job '%s' uses '%s', which is not a workflow file in this repository — "
                         "what it runs cannot be read and is not counted." % (path, name, uses))
        elif callee not in workflows:
            notes.append("%s: job '%s' calls %s, which is missing or unreadable." % (path, name, callee))
        elif "workflow_call" not in triggers(workflows[callee]):
            notes.append("%s: job '%s' calls %s, which has no 'workflow_call' trigger and cannot be called."
                         % (path, name, callee))
        elif callee not in reached:
            reached.append(callee)
for path in sorted(set(workflows) - set(reached)):
    if "workflow_call" in triggers(workflows[path]):
        notes.append("%s is a reusable workflow that no push, pull-request or merge-queue workflow calls — "
                     "its steps are not counted." % path)

covered = set()
for path in reached:
    workflow = workflows[path]
    for name, job in active_jobs(workflow):
        steps = job.get("steps")
        for step in (steps if isinstance(steps, list) else []):
            if not isinstance(step, dict) or "run" not in step or off(step.get("if", "")):
                continue
            # The nearest setting wins: step, then job, then workflow, then the root.
            where = next((d for d in (step.get("working-directory"), working_directory(job),
                                      working_directory(workflow)) if d is not None), ".")
            if not same(str(where), "."):
                continue
            covered.update(run_targets(str(step["run"])))
for target in sorted(covered):
    print("target\t" + target)
for note in notes:
    print("note\t" + note)
PY
}
ci_report="$(list_ci_targets)"
ci_targets="$(printf '%s\n' "$ci_report" | sed -n 's/^target[[:space:]]//p')"
ci_notes="$(printf '%s\n' "$ci_report" | sed -n 's/^note[[:space:]]//p')"

runs_target() { # $1 = make target name
  case $'\n'"$ci_targets"$'\n' in *$'\n'"$1"$'\n'*) return 0 ;; esac
  return 1
}

# The simple, total case: CI runs the aggregate, so nothing can fall out of it.
# Coverage of lint by CI says nothing about coverage of the registry gates BY
# lint, so a failure recorded above still wins here.
if runs_target "$TARGET"; then
  if [ "$fail" -eq 0 ]; then
    echo "OK: CI invokes 'make $TARGET' directly — every sub-target is covered by construction."
  fi
  exit "$fail"
fi

uncovered=()
for target in $prereqs; do
  if runs_target "$target"; then
    continue
  fi
  if [ -f "$ALLOWLIST" ] && grep -qxF "$target" <(sed 's/#.*//; s/[[:space:]]*$//' "$ALLOWLIST"); then
    echo "note: '$target' is allowlisted as intentionally not run in CI."
    continue
  fi
  uncovered+=("$target")
  fail=1
done

# Stale allowlist entries are drift in their own right: they claim an exemption
# for a target that no longer exists, and they make the list look larger than
# the debt it actually records.
if [ -f "$ALLOWLIST" ]; then
  while read -r entry; do
    [ -z "$entry" ] && continue
    if ! printf '%s\n' $prereqs | grep -qxF "$entry"; then
      echo "FAIL: $ALLOWLIST names '$entry', which is not a sub-target of '$TARGET' — remove the stale line."
      fail=1
    fi
  done < <(sed 's/#.*//; s/[[:space:]]*$//; /^$/d' "$ALLOWLIST")

  # Shrink-only: the allowlist records debt being paid down, never taken on.
  base="$(git merge-base HEAD origin/HEAD 2>/dev/null || git merge-base HEAD origin/main 2>/dev/null || true)"
  # Only compare when the allowlist already existed at the merge base. A branch
  # that INTRODUCES the file is not growing it — treating that as growth made it
  # impossible to add the file at all on a brownfield adoption.
  if [ -n "$base" ] && git cat-file -e "$base:$ALLOWLIST" 2>/dev/null; then
    before="$(git show "$base:$ALLOWLIST" 2>/dev/null | sed 's/#.*//; s/[[:space:]]*$//; /^$/d' | wc -l | tr -d ' ' || echo 0)"
    after="$(sed 's/#.*//; s/[[:space:]]*$//; /^$/d' "$ALLOWLIST" | wc -l | tr -d ' ')"
    if [ "$after" -gt "$before" ]; then
      echo "FAIL: $ALLOWLIST grew from $before to $after entries."
      echo "  The allowlist is shrink-only. Wire the new check into a workflow"
      echo "  instead of exempting it — an exemption added today is a gate that"
      echo "  silently stops running tomorrow."
      fail=1
    fi
  fi
fi

if [ "$fail" -ne 0 ]; then
  if [ ${#uncovered[@]} -gt 0 ]; then
    echo "FAIL: these '$TARGET' sub-targets run in no workflow:"
    printf '  %s\n' "${uncovered[@]}"
    echo ""
    echo "Fix by making CI invoke the aggregate target:"
    echo ""
    echo "    - run: make $TARGET"
    echo ""
    echo "or add each one as its own workflow step. Exempting it in $ALLOWLIST"
    echo "is the last resort, and needs a comment saying why."
    if [ -n "$ci_notes" ]; then
      echo ""
      echo "Read and not counted — possibly why:"
      printf '%s\n' "$ci_notes" | sed 's/^/  - /'
    fi
  fi
  exit 1
fi
echo "OK: every '$TARGET' sub-target runs in CI"
