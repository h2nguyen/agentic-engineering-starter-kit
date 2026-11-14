#!/usr/bin/env bash
# ACCEPTANCE TEST for typed-link resolution — the gate under the workspace graph.
#
# The contract this proves:
#
#   A typed link that names an artifact which does not exist fails the lint
#   target, naming the citing file and line. Renaming or deleting a cited
#   artifact fails the same way, and names every file that cites it.
#
# It starts with a CONTROL: the gates that existed before this one — drift,
# identifiers, knowledge-base shape — must all PASS on a link to nothing. That
# is the defect, reproduced. If a later change makes one of them catch it, the
# control stops measuring anything and says so, because a test that cannot fail
# proves nothing.
#
# The scratch repository is synthesized, so the test is the same whether it
# runs from the kit or from a repository the kit was installed into.
#
# Usage: test-graph-links.sh          # all scenarios
#        test-graph-links.sh -v       # keep the scratch repos, show gate output
set -uo pipefail

VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS="$KIT_DIR/scripts"
WORK="$(mktemp -d)"
trap '[ "$VERBOSE" -eq 1 ] || rm -rf "$WORK"' EXIT

pass=0
fail=0
ok()   { printf '  ok   — %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL — %s\n' "$1"; fail=$((fail + 1)); }
show() { [ "$VERBOSE" -eq 1 ] && printf '%s\n' "$1" | sed 's/^/         /'; return 0; }

# $1 = repo dir, $2 = where this layout keeps its rules
scaffold() {
  local repo="$1" rules="$2" f
  mkdir -p "$repo"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email "test@example.invalid"
  git -C "$repo" config user.name  "graph-acceptance-test"
  git -C "$repo" config commit.gpgsign false
  mkdir -p "$repo/scripts" "$repo/$rules" "$repo/docs/DEBUGGING-KNOWLEDGE-BASE.d" \
           "$repo/docs/adr" "$repo/changelog.d"
  for f in registry_tool.py graph_tool.py check-kb-shape.sh check-registry-drift.sh \
           check-registry-ids.sh check-graph-links.sh; do
    [ -f "$SCRIPTS/$f" ] && cp "$SCRIPTS/$f" "$repo/scripts/$f" && chmod +x "$repo/scripts/$f"
  done

  cat > "$repo/registries.json" <<'EOF'
{
  "id_scheme": "slug",
  "id_width": 3,
  "rule_pointer": "the shared-registries rule file",
  "registries": [
    {
      "name": "debugging-kb",
      "kind": "entries",
      "id_prefix": "ISSUE",
      "fragments": "docs/DEBUGGING-KNOWLEDGE-BASE.d",
      "output": "docs/DEBUGGING-KNOWLEDGE-BASE.md",
      "required_fields": ["Symptom", "Investigation Trail", "Root Cause", "Fix", "Prevention", "Debug Shortcut"]
    },
    {
      "name": "adr",
      "kind": "documents",
      "id_prefix": "ADR",
      "fragments": "docs/adr",
      "required_headings": ["Status", "Context", "Decision", "Consequences"]
    }
  ]
}
EOF

  cat > "$repo/docs/DEBUGGING-KNOWLEDGE-BASE.md" <<'EOF'
# Debugging Knowledge Base

<!-- BEGIN GENERATED: debugging-kb -->

<!-- END GENERATED: debugging-kb -->
EOF

  printf '# Testing Rules\n\nThe failing test comes first.\n' > "$repo/$rules/testing.md"
  # The copied gates cite the two rules they enforce, as they do once installed.
  printf '# Documentation Rules\n' > "$repo/$rules/documentation.md"
  printf '# Shared Append-Only Registry Rules\n' > "$repo/$rules/shared-registries.md"

  cat > "$repo/scripts/check-tests.sh" <<'EOF'
#!/usr/bin/env bash
# Enforces: RULE:testing § The Rule — every module has a test file.
echo "OK: tests present"
EOF
  ( cd "$repo" && python3 scripts/registry_tool.py generate >/dev/null )
  git -C "$repo" add -A && git -C "$repo" commit -q -m "seed"
}

# $1 = repo, $2 = slug, $3 = the value of the entry's Related line
write_entry() {
  cat > "$1/docs/DEBUGGING-KNOWLEDGE-BASE.d/2026-11-14-$2.md" <<EOF
# Entry $2

**Symptom:** The suite passes locally and fails in CI.

**Investigation Trail:** Compared the two environments.

**Root Cause:** A fixture depended on wall-clock time.

**Fix:** Froze the clock in the fixture.

**Prevention:** The testing rule now forbids wall-clock time in fixtures.

**Debug Shortcut:** grep the fixtures for "now(".

**Related:** $3
EOF
  ( cd "$1" && python3 scripts/registry_tool.py generate >/dev/null )
}

older_gates() { # the three gates that predate this one
  ( cd "$1" && ./scripts/check-registry-drift.sh >/dev/null 2>&1 \
            && ./scripts/check-registry-ids.sh   >/dev/null 2>&1 \
            && ./scripts/check-kb-shape.sh       >/dev/null 2>&1 )
}

graph_gate() { ( cd "$1" && ./scripts/check-graph-links.sh 2>&1 ); }

# ---------------------------------------------------------------------------
# CONTROL — a link to nothing passes everything that existed before.
# ---------------------------------------------------------------------------
control_dangling_link_is_silent() {
  local repo="$WORK/control"
  scaffold "$repo" .claude/rules
  rm -f "$repo/scripts/check-graph-links.sh" "$repo/scripts/graph_tool.py"
  write_entry "$repo" flaky-fixture "RULE:does-not-exist, SCRIPT:check-nothing.sh"
  if older_gates "$repo"; then
    ok "control: a link to a rule and a script that do not exist passes drift, identifiers and KB shape (defect reproduced)"
  else
    bad "control: an older gate now rejects the dangling link — this test no longer measures anything"
  fi
}

# ---------------------------------------------------------------------------
# THE CONTRACT
# ---------------------------------------------------------------------------
contract_dangling_link_is_loud() {
  local repo="$WORK/dangling" out
  scaffold "$repo" .claude/rules
  write_entry "$repo" flaky-fixture "RULE:does-not-exist"
  out="$(graph_gate "$repo")" && { bad "a link to a rule that does not exist passed the gate"; show "$out"; return; }
  ok "a link to a rule that does not exist fails the gate"
  case "$out" in
    *"docs/DEBUGGING-KNOWLEDGE-BASE.d/2026-11-14-flaky-fixture.md:15"*"RULE:does-not-exist"*)
      ok "the failure names the citing file, the line and the token" ;;
    *) bad "the failure does not name file:line and token"; show "$out" ;;
  esac

  write_entry "$repo" flaky-fixture "RULE:testing"
  out="$(graph_gate "$repo")" && ok "pointing the link at a rule that exists turns the gate green" \
    || { bad "a resolvable link was rejected"; show "$out"; }
}

contract_rename_names_every_citer() {
  local repo="$WORK/rename" out
  scaffold "$repo" .claude/rules
  mkdir -p "$repo/.claude/agents"
  cat > "$repo/.claude/agents/test-engineer.md" <<'EOF'
---
name: test-engineer
description: Reviews test changes.
tools: Read, Grep, Glob, Bash
model: sonnet
---

You review tests.

**Enforces:** RULE:testing

**Hands off to:** HUMAN — any finding marked BLOCKER
EOF
  write_entry "$repo" flaky-fixture "RULE:testing"
  out="$(graph_gate "$repo")" || { bad "the starting state should be green"; show "$out"; return; }

  # What an agent reads BEFORE the rename: the same reverse index the gate uses.
  out="$( cd "$repo" && python3 scripts/graph_tool.py impact RULE:testing 2>&1 )"
  case "$out" in
    *"scripts/check-tests.sh:2"*) ;; *) bad "impact does not list the enforcing script"; show "$out" ;;
  esac
  case "$out" in
    *".claude/agents/test-engineer.md:10"*"2026-11-14-flaky-fixture.md:15"*|*"2026-11-14-flaky-fixture.md:15"*".claude/agents/test-engineer.md:10"*)
      ok "impact lists the script, the agent and the entry that cite the rule, each with file:line" ;;
    *) bad "impact does not list every citer"; show "$out" ;;
  esac

  git -C "$repo" mv .claude/rules/testing.md .claude/rules/test-conventions.md
  out="$(graph_gate "$repo")" && { bad "renaming a cited rule passed the gate"; show "$out"; return; }
  local named=0
  for citer in "scripts/check-tests.sh:2" ".claude/agents/test-engineer.md:10" "2026-11-14-flaky-fixture.md:15"; do
    case "$out" in *"$citer"*) named=$((named + 1)) ;; esac
  done
  [ "$named" -eq 3 ] && ok "renaming a cited rule fails the gate and names all three citers" \
    || { bad "the rename named $named of 3 citers"; show "$out"; }
  case "$out" in
    *"test-conventions"*) ok "and it suggests the name the rule now has" ;;
    *) bad "no suggestion for the renamed rule"; show "$out" ;;
  esac
}

contract_handoff_is_typed() {
  local repo="$WORK/handoff" out
  scaffold "$repo" .claude/rules
  mkdir -p "$repo/.claude/skills/release" "$repo/.claude/agents"
  printf -- '---\nname: reviewer\ndescription: Reviews.\n---\n\nYou review.\n' > "$repo/.claude/agents/reviewer.md"
  cat > "$repo/.claude/skills/release/SKILL.md" <<'EOF'
---
name: release
description: Cuts a release.
---

# Release

**Hands off to:** AGENT:reviewer, SCRIPT:check-tests.sh, HUMAN — before the tag is pushed
EOF
  out="$(graph_gate "$repo")" && ok "a skill hands off to an agent, a script and a human gate" \
    || { bad "a well-formed hand-off was rejected"; show "$out"; }

  printf '\n**Hands off to:** RULE:testing\n' >> "$repo/.claude/skills/release/SKILL.md"
  out="$(graph_gate "$repo")" && { bad "a hand-off to a document passed the gate"; show "$out"; return; }
  ok "a hand-off to a rule is rejected — a document does not run next"
}

contract_examples_are_not_edges() {
  local repo="$WORK/examples" out
  scaffold "$repo" .claude/rules
  cat >> "$repo/.claude/rules/testing.md" <<'EOF'

An entry cites this rule on its Related line, for example:

```markdown
**Related:** RULE:<slug>, ISSUE-042
```

Inline, the same thing looks like `**Related:** RULE:not-a-link`.
EOF
  mkdir -p "$repo/.claude/skills/_template"
  printf '# <Skill>\n\n**Related:** RULE:<rule this implements>\n' > "$repo/.claude/skills/_template/SKILL.md"
  printf '#!/bin/bash\n# Enforces: RULE:<domain> — <rule name>\n' > "$repo/scripts/check-convention.sh.template"
  out="$(graph_gate "$repo")" && ok "fenced examples, inline mentions and underscore/.template scaffolding are not edges" \
    || { bad "an example or a template was read as a link"; show "$out"; }
}

contract_layout_without_claude() {
  local repo="$WORK/agents-layout" out
  scaffold "$repo" docs/agent-rules
  write_entry "$repo" flaky-fixture "RULE:testing"
  out="$(graph_gate "$repo")" && ok "the same links resolve where rules live in docs/agent-rules/" \
    || { bad "links did not resolve in the AGENTS.md layout"; show "$out"; }
}

contract_immutable_citer_is_allowlisted() {
  # An accepted decision record is immutable, so when the rule it cites is
  # retired the link cannot be repaired by editing the record. The escape is a
  # written pair with a reason — and it is never silent.
  local repo="$WORK/allowlist" out
  scaffold "$repo" .claude/rules
  cat > "$repo/docs/adr/2026-11-14-test-policy.md" <<'EOF'
# Test policy

## Status

Accepted

## Context

Fixtures were flaky.

## Decision

We will freeze the clock.

## Consequences

Fewer flakes.

**Related:** RULE:testing
EOF
  git -C "$repo" rm -q .claude/rules/testing.md
  rm -f "$repo/scripts/check-tests.sh"
  out="$(graph_gate "$repo")" && { bad "a record citing a retired rule passed the gate"; show "$out"; return; }

  printf 'docs/adr/2026-11-14-test-policy.md RULE:testing\n' > "$repo/.graph-link-allowlist"
  out="$(graph_gate "$repo")" && { bad "an allowlist entry without a reason was accepted"; show "$out"; }
  printf 'docs/adr/2026-11-14-test-policy.md RULE:testing  # accepted record; the rule was retired in 2026-11\n' > "$repo/.graph-link-allowlist"
  out="$(graph_gate "$repo")"
  if [ $? -eq 0 ]; then
    case "$out" in
      *note:*"RULE:testing"*) ok "an immutable record's link to a retired rule passes once allowlisted with a reason, and says so" ;;
      *) bad "the sanctioned exception was silent"; show "$out" ;;
    esac
  else
    bad "an allowlisted pair with a reason was rejected"; show "$out"
  fi

  printf '# Testing Rules\n' > "$repo/.claude/rules/testing.md"
  out="$(graph_gate "$repo")" && { bad "a stale allowlist entry was tolerated"; show "$out"; return; }
  ok "an allowlist entry for a link that resolves again is reported as stale"
}

echo "=== control: what the older gates let through (this MUST reproduce the defect) ==="
control_dangling_link_is_silent

echo ""
echo "=== contract: typed links resolve, or the gate says where they do not ==="
if [ ! -f "$SCRIPTS/graph_tool.py" ] || [ ! -f "$SCRIPTS/check-graph-links.sh" ]; then
  bad "graph_tool.py / check-graph-links.sh not found in $SCRIPTS — the mechanism does not exist yet"
else
  contract_dangling_link_is_loud
  contract_rename_names_every_citer
  contract_handoff_is_typed
  contract_examples_are_not_edges
  contract_layout_without_claude
  contract_immutable_citer_is_allowlisted
fi

echo ""
echo "=== $pass passed, $fail failed ==="
[ "$VERBOSE" -eq 1 ] && echo "scratch repos kept in $WORK"
[ "$fail" -eq 0 ] || exit 1
