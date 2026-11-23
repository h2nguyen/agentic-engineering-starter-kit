# The comments rule is used as shipped and the ADR section applies only with an adr registry

## Added

- `project-annotations.md`, installed beside the rules together with the comments rule (`.claude/rules/` on Claude Code, `docs/agent-rules/` elsewhere): the project's half of the comments-and-annotations rule. It says what the rule's pointers — `<DECISION-RECORD-ID>`, `<KB-ENTRY-ID>`, `<TICKET-ID>`, `<tool-or-gate>`, `<EVAL-RECORD-ID>` — stand for in your project, and lists the marker shapes your own tooling reads. It is yours; no upgrade replaces it. The constitution template's rule index lists it. ADR-0017 records the change.
- `make constitution` reads `project-annotations.md` together with the constitution and names every `<fill in: …>` still open in it. A pointer left unresolved used to sit in a rule that no check read.

## Changed

- The comments-and-annotations rule and its reference are used as shipped: nothing in them is filled in. The heading "Protected shapes (project fill-in)" is "Protected shapes", the instruction to complete the second table is gone, and the pointers are notation that `project-annotations.md` resolves. The two mentions of `testing.md`, a file no install has, now read "the project's testing rule, where it has one".
- **If you filled in the rule on an older kit, you can move your rows once** — upgrade step 3 says how: create `project-annotations.md` from the kit's template (the command does nothing where the file exists), move your second table and your pointer values into it, then copy the kit's rule over yours. From then on the rule is copied like the other four. The move is your choice: until you make it, your filled-in rule keeps working and is merged by hand at each upgrade, as before, and a line for the new file in your constitution's index is yours to add or leave. The installer does not put the template beside a comments rule that was already there: unfilled, it would be loaded into every session and would fail a `constitution` check you chained into your lint.
- The documentation rule's "ADR format" section applies where `registries.json` declares an `adr` registry, and says so. With none declared — because your project records its decisions somewhere else — the constitution says where, and the rest of the section does not apply. The rule used to prescribe `docs/adr/` and `--registry adr` unconditionally, and a project with its own decision register had to overrule an installed rule in its constitution.
- `registry_tool.py init` still declares an `adr` registry when it finds no decision records; its note now says what to do when decisions live elsewhere in a form it cannot see. The setup prompt's Harmonize track and the kit's `AGENTS.md` name that case.

## Fixed

- Asking `registry_tool.py` for a registry that is not declared says that `registries.json` declares no registry of that name, lists the ones it does, and points at the constitution. It used to say "unknown registry".
