---
name: registry-entry
description: >
  Write an entry into a shared append-only registry — a changelog bullet, a
  debugging knowledge-base entry, a decision record — as a fragment file rather
  than as an appended line. Use whenever a change needs a changelog bullet, a
  bug took more than about thirty minutes to diagnose, or a cross-file design
  decision needs recording; also when asked to "add a changelog entry", "write
  it up in the KB", "log this bug", or "write an ADR". Not for resolving merge
  conflicts in those files — that is registry-conflict-triage.
---

# Registry Entry

Authoring only. This skill writes the fragment, picks the category, and names
the file. It never resolves a merge and never renames an identifier.

## Phase 1 — Identify the registry

Read `registries.json` at the repository root. It declares every registry, its
fragment directory, and the identifier scheme in use. `registry_tool.py list`
prints the same thing in readable form.

If the change belongs to a registry that is not declared there, stop and say
so rather than appending to the artifact by hand — an undeclared registry is
outside every gate, so an entry written into it is unverified.

Which registry, by what happened:

| What happened | Registry | Category |
|---|---|---|
| A user- or operator-observable change | `changelog` | exactly one of Added / Changed / Deprecated / Removed / Fixed / Security |
| A bug that took >30 min to diagnose | the debugging knowledge base | — |
| A decision affecting multiple files or future choices | the decision records | — |

Internal refactors, test-only changes and formatting sweeps need no changelog
bullet. When genuinely unsure, write one: an extra `Changed` line is cheaper
than an unrecorded behaviour shift.

## Phase 2 — Create the fragment with the tool

```bash
python3 scripts/registry_tool.py new --registry changelog --category added \
  --title "Export endpoint for the account ledger (#1234)"

python3 scripts/registry_tool.py new --registry debugging-kb \
  --title "Cache warms before the config is loaded"
```

Use the tool rather than writing the file by hand. It derives the slug, applies
the project's identifier scheme, refuses a name that is already taken, and
fills in the fields the gate will require. Hand-naming a fragment is how a file
ends up outside the grammar the check enforces.

Then fill it in:

- **Changelog bullet** — the level-1 heading *is* the bullet. Write it for the
  operator reading it after a deploy: what changed, what they will observe,
  the ticket reference. Never a pasted commit message. One bullet per logical
  change, not per commit.
- **Knowledge-base entry** — fill every field the template carries. `Symptom`
  is what someone will search for, so phrase it as the observation, not the
  diagnosis. `Prevention` names the rule or check that now encodes the lesson;
  if neither exists yet, that is a signal worth raising rather than a field to
  leave vague.
- **Decision record** — Michael Nygard format: Status, Context, Decision,
  Consequences. Rejected options go inside Context, one line and its trade-off
  each, because they are part of the forces that made the decision necessary —
  not a separate section. Write the Decision in active voice: "We will …".

## Phase 3 — Generate and verify

```bash
make registry-generate      # assemble the artifacts
make lint                   # drift check + identifier gate + shape check
```

Commit the fragment **and** the regenerated artifact together. A fragment
without its regenerated artifact fails the drift check; an artifact edited
without its fragment fails it the other way.

## Failure modes

- **Editing the generated artifact directly.** The next generation overwrites
  it, and CI rejects it before that. Everything is authored in the fragment
  directory.
- **Reusing an identifier from a superseded entry.** Identifiers are stable and
  never reused, even when the entry they name is obsolete. Supersede by adding
  a new entry that references the old one.
- **Choosing the identifier by hand under the numeric scheme.** The allocator
  sees only the local checkout, which is already a weak guarantee; overriding
  it makes a collision likely rather than possible.
- **Writing several entries into one fragment.** One entry per file is what
  makes concurrent authorship safe; a fragment holding three entries conflicts
  exactly like the shared file it replaced.
- **A registry entry as the whole pull request.** The entry belongs in the same
  pull request as the change it describes — the author is the only person who
  knows what to write, and the knowledge decays within days.
