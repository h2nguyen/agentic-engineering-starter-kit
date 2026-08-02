# Debugging Knowledge Base

Search here BEFORE investigating any bug. Add an entry AFTER resolving any
non-obvious bug (>30 min to diagnose). Entries are append-only: never rewrite
history, only add.

Graph-ready conventions — this file doubles as the substrate for a future
knowledge-graph layer (agentic graph engineering, guide § 5.6):

- Entry IDs are **stable and never reused**, even if an entry is superseded.
- Cross-reference other workspace artifacts with **typed links** on the
  optional `**Related:**` line: `ISSUE-NNN`, `ADR-NNN`, `RULE:<slug>`,
  `SKILL:<slug>`, `SCRIPT:<slug>`, `DOC:<slug>` — comma-separated.
- `scripts/check-kb-shape.sh` validates entry shape and link syntax; wire it
  into the lint target so the substrate cannot silently rot.

Entry format — copy the skeleton below, take the next free ISSUE number:

## ISSUE-001: <Short symptom-style title>

**Symptom:** What the developer/agent observes.

**Investigation Trail:** What was checked; what was misleading.

**Root Cause:** The actual reason.

**Fix:** What was changed.

**Prevention:** The design rule or pattern that avoids recurrence
(and which rule file / enforcement script now encodes it).

**Debug Shortcut:** The quick check to confirm this issue next time.

**Related:** RULE:working-principles
