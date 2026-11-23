#!/usr/bin/env bash
# Tests for check-constitution.sh.
#
# The check exists because a constitution was left with two links to rule
# files that were never written and one unfilled template placeholder, and
# `make lint` was green throughout: the typed-link gate reads link LINES, not
# ordinary Markdown links, and nothing read the placeholders at all.
#
# It has to fail on those two things and on nothing else. A constitution is
# full of angle brackets that are meant to stay — a command with an
# `<argument>`, a token shape like `RULE:<name>`, an HTML tag — and a check
# that flagged them would be switched off within a day. So most cases below
# are things it must leave alone.
#
# Usage: test-constitution.sh
set -uo pipefail

GATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/check-constitution.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
ok()  { printf '  ok   — %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL — %s\n' "$1"; fail=$((fail + 1)); }

# repo — a scratch repository with one rule file to link to; prints its path.
repo() {
  local dir; dir="$(mktemp -d "$WORK/case.XXXXXX")"
  git -C "$dir" init -q -b main
  mkdir -p "$dir/docs/agent-rules" "$dir/.github"
  echo "# Testing" > "$dir/docs/agent-rules/testing.md"
  echo "$dir"
}

# expect <name> <expected-exit> <constitution file> <content> [text the output must contain]
expect() {
  local name="$1" expected="$2" file="$3" content="$4" needle="${5:-}"
  local dir out actual; dir="$(repo)"
  printf '%b' "$content" > "$dir/$file"
  out="$( cd "$dir" && "$GATE" 2>&1 )"; actual=$?
  if [ "$actual" -ne "$expected" ]; then
    bad "$name (expected exit $expected, got $actual): $(printf '%s' "$out" | head -2 | tr '\n' ' ')"
  elif [ -n "$needle" ] && [[ "$out" != *"$needle"* ]]; then
    bad "$name (output does not say '$needle'): $(printf '%s' "$out" | head -2 | tr '\n' ' ')"
  else
    ok "$name"
  fi
}

echo "=== links ==="
expect "a link to a rule file that exists passes" 0 AGENTS.md \
  '# Project\n\n- [`testing.md`](docs/agent-rules/testing.md) — test conventions\n'
expect "a link to a rule file that was never written fails, with file and line" 1 AGENTS.md \
  '# Project\n\n- [`testing.md`](docs/agent-rules/testing.md) — tests\n- [`security.md`](docs/agent-rules/security.md) — secrets\n' \
  "AGENTS.md:4 — link 'docs/agent-rules/security.md' names a file that does not exist"
expect "a link with an anchor is checked against the file, not the anchor" 0 AGENTS.md \
  '# Project\n\nSee [the flake traps](docs/agent-rules/testing.md#known-flake-traps).\n'
expect "a link to a directory that exists passes" 0 AGENTS.md '# Project\n\nRules live in [docs/agent-rules](docs/agent-rules/).\n'
expect "web links, mail links and in-page anchors are not files and are not checked" 0 AGENTS.md \
  '# Project\n\n[site](https://example.invalid/x) · [mail](mailto:team@example.invalid) · [below](#commands)\n'
expect "a link shown inside a fenced example is not a link" 0 AGENTS.md \
  '# Project\n\n```markdown\n- [`absent.md`](docs/agent-rules/absent.md)\n```\n'
expect "a link shown inside a code span is not a link" 0 AGENTS.md \
  '# Project\n\nWrite it as `[name](docs/agent-rules/absent.md)`.\n'
expect "a reference-style link definition is checked too" 1 AGENTS.md \
  '# Project\n\nSee [the rule][sec].\n\n[sec]: docs/agent-rules/security.md\n' "AGENTS.md:5"
expect "a link with a title is checked by its path" 0 AGENTS.md \
  '# Project\n\n[tests](docs/agent-rules/testing.md "the testing rule")\n'
expect "a template link whose path still holds a placeholder fails as a dead link" 1 CLAUDE.md \
  '# Project\n\n| **Domain** | see [`.claude/rules/<domain>.md`](.claude/rules/<domain>.md) |\n' \
  "CLAUDE.md:3 — link '.claude/rules/<domain>.md' names a file that does not exist"
# Copilot's constitution sits in .github/ and names its rules from the root.
expect "in .github/copilot-instructions.md a link may be written from the repository root" 0 .github/copilot-instructions.md \
  '# Project\n\n- [`testing.md`](docs/agent-rules/testing.md)\n'
expect "and one that resolves from neither place fails" 1 .github/copilot-instructions.md \
  '# Project\n\n- [`security.md`](docs/agent-rules/security.md)\n' ".github/copilot-instructions.md:3"

echo "=== unfilled placeholders ==="
expect "a template placeholder left in a heading fails, with file and line" 1 AGENTS.md \
  '# Agent Constitution — <Project Name>\n\nText.\n' "AGENTS.md:1 — unfilled placeholder '<Project Name>'"
expect "a placeholder that runs over two lines is reported where it opens" 1 AGENTS.md \
  '# Project\n\n<One paragraph: what this system is, who uses it, the one or two domain\nconstraints that shape everything.>\n' "AGENTS.md:3"
expect "a placeholder in a table cell fails" 1 AGENTS.md \
  '# Project\n\n| Layer | Technology |\n|---|---|\n| Backend | <language, framework, versions> |\n' "AGENTS.md:5"
expect "a placeholder as a list item fails" 1 AGENTS.md \
  '# Project\n\n- <add one line per rule file as they accumulate — infrastructure and messaging earn one early>\n' "AGENTS.md:3"
out="$( dir="$(repo)"; printf '# <Project Name>\n\n| Backend | <language, framework, versions> |\n| **<Domain rule 1>** | <one-line imperative> |\n' > "$dir/AGENTS.md"; cd "$dir" && "$GATE" 2>&1 )"
[ "$(printf '%s\n' "$out" | grep -c '^FAIL: ')" -eq 4 ] \
  && ok "every placeholder is reported, two on one line included — not just the first" \
  || bad "expected 4 findings, got $(printf '%s\n' "$out" | grep -c '^FAIL: ')"

echo "=== angle brackets that are meant to stay ==="
expect "an argument inside a fenced command stays" 0 AGENTS.md \
  '# Project\n\n```bash\npython3 scripts/registry_tool.py new --registry debugging-kb --title "<symptom>"\n```\n'
expect "a token shape inside a code span stays" 0 AGENTS.md \
  '# Project\n\nName the rule (`RULE:<rule file name>`, `SCRIPT:<check script name>`).\n'
expect "a fence opened with tildes is a fence" 0 AGENTS.md '# Project\n\n~~~\n<Project Name>\n~~~\n'
expect "an HTML comment stays" 0 AGENTS.md '# Project\n\n<!-- keep this note for the next editor -->\n'
expect "an HTML tag stays, with or without attributes" 0 AGENTS.md \
  '# Project\n\n<details open>\n<summary>More</summary>\nText<br>more <img src="a.png" alt="a diagram">\n</details>\n'
expect "an autolink stays" 0 AGENTS.md '# Project\n\nDocs: <https://example.invalid/docs> — <team@example.invalid>\n'
expect "a comparison in prose is not a placeholder" 0 AGENTS.md '# Project\n\nKeep p95 < 200 ms and error rate > 0 visible.\n'
expect "a single word in angle brackets is not judged — only the dead link it sits in would be" 0 AGENTS.md \
  '# Project\n\nA generic like Option<T> or a key like <Enter> is prose.\n'

echo "=== scope ==="
# Rule files and their references are full of identifier shapes that are the
# point of the document. Only the constitution is read.
dir="$(repo)"
printf '# Project\n\n- [`testing.md`](docs/agent-rules/testing.md)\n' > "$dir/AGENTS.md"
mkdir -p "$dir/docs/rule-reference"
printf '# Comments\n\nPoint at <DECISION-RECORD-ID> or <KB-ENTRY-ID>, never at <a ticket story>.\n[gone](absent.md)\n' \
  | tee "$dir/docs/agent-rules/comments-and-annotations.md" > "$dir/docs/rule-reference/comments-and-annotations.md"
( cd "$dir" && "$GATE" >/dev/null 2>&1 ) \
  && ok "rule files and rule references are not read: their identifier shapes and examples stay" \
  || bad "the check read a file that is not the constitution"
# One file beside the rules IS read: project-annotations.md, the project's
# half of the comments rule. It is filled in by the project like the
# constitution, and used to be a table inside a kit rule that no check opened.
for rules in docs/agent-rules .claude/rules; do
  dir="$(repo)"; mkdir -p "$dir/$rules"
  printf '# Project\n' > "$dir/AGENTS.md"
  printf '# Project Annotations\n\n| In the rule | Here |\n|---|---|\n| `<TICKET-ID>` | <fill in: the shape of a tracker reference> |\n' \
    > "$dir/$rules/project-annotations.md"
  out="$( cd "$dir" && "$GATE" 2>&1 )"; rc=$?
  [ "$rc" -eq 1 ] && [[ "$out" == *"$rules/project-annotations.md:5 — unfilled placeholder '<fill in: the shape of a tracker reference>'"* ]] \
    && ok "$rules/project-annotations.md is read with the constitution: an unfilled row fails, with file and line" \
    || bad "an unfilled $rules/project-annotations.md was not reported (exit $rc): $(printf '%s' "$out" | head -1)"
  printf '# Project Annotations\n\n| In the rule | Here |\n|---|---|\n| `<TICKET-ID>` | `#123` |\n' > "$dir/$rules/project-annotations.md"
  out="$( cd "$dir" && "$GATE" 2>&1 )"; rc=$?
  [ "$rc" -eq 0 ] && [[ "$out" == *"project-annotations.md"* ]] \
    && ok "filled in, it passes — the pointer name in backticks is not a placeholder — and the OK line names the file" \
    || bad "a filled-in $rules/project-annotations.md fails or is not named (exit $rc): $(printf '%s' "$out" | head -1)"
done
dir="$(repo)"; printf '# <fill in: x y>\n' > "$dir/docs/agent-rules/project-annotations.md"
out="$( cd "$dir" && "$GATE" 2>&1 )"; rc=$?
[ "$rc" -eq 1 ] && ok "it is read in a repository whose constitution is missing, too" \
  || bad "project-annotations.md without a constitution: exit $rc, '$(printf '%s' "$out" | head -1)'"
dir="$(repo)"
printf '# Project\n' > "$dir/CLAUDE.md"; printf '# <Project Name>\n' > "$dir/AGENTS.md"
out="$( cd "$dir" && "$GATE" 2>&1 )"; rc=$?
[ "$rc" -eq 1 ] && [[ "$out" == *"AGENTS.md:1"* ]] \
  && ok "a repository with two constitutions has both read" || bad "only one of two constitutions was read (exit $rc)"
dir="$(repo)"
out="$( cd "$dir" && "$GATE" 2>&1 )"; rc=$?
[ "$rc" -eq 0 ] && [[ "$out" == SKIP* ]] \
  && ok "a repository with no constitution is skipped, and says so" || bad "no constitution: exit $rc, '$out'"
dir="$(repo)"; mkdir -p "$dir/docs"; printf '# <Project Name>\n' > "$dir/docs/PLAYBOOK.md"; printf '# Project\n' > "$dir/AGENTS.md"
out="$( cd "$dir" && "$GATE" docs/PLAYBOOK.md 2>&1 )"; rc=$?
[ "$rc" -eq 1 ] && [[ "$out" == *"docs/PLAYBOOK.md:1"* ]] \
  && ok "a file named as an argument is read instead" || bad "a file argument was ignored (exit $rc)"
dir="$(repo)"; mkdir -p "$dir/sub"; printf '# <Project Name>\n' > "$dir/AGENTS.md"
( cd "$dir/sub" && "$GATE" >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 1 ] && ok "run from a subdirectory, it still reads the repository's constitution" \
  || bad "run from a subdirectory it found nothing (exit $rc)"

echo ""
echo "=== $pass passed, $fail failed ==="
[ "$fail" -eq 0 ] || exit 1
