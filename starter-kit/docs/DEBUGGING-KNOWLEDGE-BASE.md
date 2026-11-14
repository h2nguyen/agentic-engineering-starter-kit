# Debugging Knowledge Base

Search here BEFORE investigating any bug. Add an entry AFTER resolving any
non-obvious bug (>30 min to diagnose).

**This file is generated.** Entries live one-per-file in
`docs/DEBUGGING-KNOWLEDGE-BASE.d/`; `make registry-generate` assembles them
here. Editing below the marker is wasted work — the next regeneration
overwrites it, and CI's drift check fails before that.

The indirection is not ceremony. One shared file means every pull request
appends at the same anchor, so every concurrent pair conflicts, and two
branches that both take "the next free number" produce a duplicate identifier
that merges *cleanly* and is never noticed. The conflict costs thirty seconds;
the duplicate is permanent, because the identifier is what other rules, ADRs
and code comments cite. One file per entry removes both.

Add an entry:

```bash
python3 scripts/registry_tool.py new --registry debugging-kb \
  --title "Cache warms before the config is loaded"
# → docs/DEBUGGING-KNOWLEDGE-BASE.d/2026-08-29-cache-warms-before-the-config.md
make registry-generate
```

Conventions — every entry is a node in the workspace graph, and its links are
checked:

- Entry identifiers are **stable and never reused**, even when an entry is
  superseded. They come from the fragment's filename and from nowhere else, so
  there is exactly one place they can drift from.
- Cross-reference other workspace artifacts with **typed links** on the
  optional `**Related:**` line: an entry identifier, `ADR-…`, `RULE:<slug>`,
  `SKILL:<slug>`, `AGENT:<slug>`, `COMMAND:<slug>`, `SCRIPT:<slug>`,
  `DOC:<slug>` — comma-separated. Name the rule or check script that now
  prevents the bug: that link is how the next reader gets from the incident to
  its guard, and from the guard back to why it exists.
- `scripts/check-kb-shape.sh` validates the assembled file; `registry_tool.py
  check` validates the fragments; `scripts/check-graph-links.sh` checks that
  every link names something that still exists. All three are wired into the
  lint target, so neither the shape nor the citations can silently rot.

<!-- BEGIN GENERATED: debugging-kb — do not edit inside this region. Add a file under docs/DEBUGGING-KNOWLEDGE-BASE.d/ and run `make registry-generate`. -->

<!-- END GENERATED: debugging-kb -->
