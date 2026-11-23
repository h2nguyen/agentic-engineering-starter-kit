---
name: rule-load-check
description: >
  Check which rule files Claude Code has really loaded, and when each one
  arrives: rules without a `paths:` header at session start, rules with one
  after a matching file is read. Use after adding, renaming or editing a rule
  or its `paths:` header, after installing or upgrading the agent workspace,
  or when asked "which rules are loaded", "is this rule in context", "check
  the load classes". Run it in a NEW session — a session that was already
  running has been seen to keep the rules it started with. Not for judging
  what a rule says; that is a review.
---

# Rule Load Check

Establishes, for every file in `.claude/rules/`, whether it was in context
when the session started or arrived later, and whether that is what its
header says. Done means a table with one row per rule and every row backed by
a quote that was compared with the file.

Nothing else reports this. A `paths:` header Claude Code cannot parse is
ignored without a message, and the rule then loads into every session. A
pattern that matches no file is a rule that never arrives. Neither turns a
gate red.

The method is evidence, not recall: for each rule you say is in context you
quote its last line, and only afterwards compare the quote with the file.

## Phase 0 — A new session

1. This check is only valid in a session that has done nothing yet. If this
   session has already read or edited project files, or a rule or header was
   changed while it was running, STOP: say so, and ask for the check to be
   run in a new session.
2. A subagent of a running session is not a new session. It has been observed
   to carry the rule set its parent started with.

## Phase 1 — Inventory, before touching anything

Before any Read, Edit or Write, and before any shell command that prints a
file:

1. List every rule file whose **full text** is in your context now. A rule
   you know only from its one line in the constitution is not in full.
2. For each, quote the last line of it that has at least four words, word
   for word. Do not open the file to do this. (A last line that is only a
   table rule or a heading could be guessed; a sentence cannot.)

## Phase 2 — What the headers say

List the headers with one command. It prints each rule's header, not its text:

```bash
for f in .claude/rules/*.md; do
  printf '%s: ' "$f"
  if [ "$(sed -n 1p "$f")" = "---" ]; then awk 'NR>1 && $0=="---" {exit} NR>1' "$f" | tr '\n' ' '
  else printf 'no header: every session'; fi
  echo
done
```

A rule with no header, or with a header that has no `paths:`, is expected in
the Phase 1 list. A rule with `paths:` is expected to be absent from it.

## Phase 3 — One access per load class

For each distinct `paths:` list:

1. Find one existing file that a pattern matches, by listing, not reading:

   ```bash
   git ls-files -co --exclude-standard ':(glob)<pattern>' | grep -v '^\.claude/rules/' | head -1
   ```

   `:(glob)` gives the pattern the meaning it has in the header — `*` stays
   inside one directory, `**` crosses them — and `-co` includes files that
   are not committed yet, which on the day of an install is all of them.
   Never pick a file under `.claude/rules/`: reading a rule file puts that
   rule in context and spoils its row.
2. Read that one file with the Read tool.
3. State which rules arrived with that access and were not in context before.
   For each, quote its last line of at least four words, word for word.

No file matches any pattern of a rule: record "no file to test with". That
rule's load class is unverified, and the pattern may be wrong.

Claude Code documents Read, Write and Edit of a matching file as triggers.
This check uses Read; say so in the report instead of claiming the others.

## Phase 4 — Compare the quotes, then report

1. Only now print the real last lines, and compare each with your quote:

   ```bash
   for f in .claude/rules/*.md; do printf '%s: %s\n' "$f" "$(awk 'NF >= 4 {l=$0} END {print l}' "$f")"; done
   ```

   A quote that does not match was reconstructed, not read from context.
   That row is "not verified", whatever you believed in Phase 1 or 3.
2. Report one row per rule:

   | Rule | Header | Expected | Observed | Quote matches |
   |---|---|---|---|---|
   | `<name>` | none, or its patterns | at start, or on a matching file | at start / after reading `<file>` / never | yes / no |

3. Name each finding by its kind:

   | Observed | It means |
   |---|---|
   | Has `paths:`, and was in context at start | The header was not parsed. Claude Code's documentation names `claude --debug` as the way to see the parse error |
   | Has no header, and was not in context at start | The file is not being loaded as a rule: check its location and extension |
   | Has `paths:`, and did not arrive on a matching file | No pattern matches that file. Patterns are relative to the repository root |
   | Arrived on a file its patterns do not match | Another pattern is wider than intended |

## Failure modes

- The session is not new → Phase 0: stop and say so.
- Tempted to fix a header on the spot → do not. An edit made now is not
  visible to this session. Propose the change, and re-run the check in
  another new session after it is made.
- A tool other than Claude Code → this check does not apply. There a rule is
  read when the constitution links to it, and there is no load class.

## Links

**Related:** RULE:documentation

**Hands off to:** HUMAN — a finding is repaired by editing a header, and the repair is confirmed by this check in another new session
