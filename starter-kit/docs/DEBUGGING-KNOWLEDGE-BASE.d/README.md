# Knowledge-base fragments

One file per entry. `make registry-generate` assembles them into
`../DEBUGGING-KNOWLEDGE-BASE.md`; that file is generated and must not be
hand-edited.

**Filenames carry the identifier, and nothing else does.** Under the default
slug scheme a file named `2026-08-29-cache-warms-before-config.md` publishes as
`ISSUE-2026-08-29-cache-warms-before-config`. Two branches cannot add the same
path without git raising an add/add conflict, so the identifier cannot silently
collide — which matters because it is a citation target: rules, decision
records and code comments refer to it by name, and renaming it after the fact
breaks every one of those references.

Create one with the tool rather than by hand — it derives the slug, applies the
project's identifier scheme, and fills in the required fields:

```bash
python3 scripts/registry_tool.py new --registry debugging-kb \
  --title "Retry loop swallows the timeout error"
```

`_template.md` and this README are ignored by the generator: files whose names
begin with an underscore, and README files, are scaffolding rather than
entries.
