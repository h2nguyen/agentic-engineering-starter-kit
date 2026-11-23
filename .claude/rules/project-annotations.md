# Project Annotations

The project's half of the comments-and-annotations rule. That rule is the
kit's and is used as shipped; what only this project can say about it is here:
what the rule's pointers stand for, and which marker shapes this project's own
tooling reads. This file is the project's. A newer kit never replaces it.

**Related:** RULE:comments-and-annotations

## Pointers

The rule and its worked examples name a decision record, a knowledge-base
entry, a ticket and a gate by a pointer in angle brackets. Here is what each
one is in this project.

| Pointer | In this project |
|---|---|
| `<DECISION-RECORD-ID>` | `ADR-NNNN`, a file `docs/adr/adr-NNNN-short-title.md` (`make registry-list` prints the shape) |
| `<KB-ENTRY-ID>` | none — this repository ships the knowledge-base skeleton and keeps no knowledge base of its own |
| `<TICKET-ID>` | a GitHub issue or pull-request number, `#NNN` |
| `<tool-or-gate>` | `make lint`; the gate that reads a marker is named in the table below |
| `<EVAL-RECORD-ID>` | none kept — an evaluation's commands are recorded by `scripts/eval-run.sh` into a log directory the evaluator names, outside the repository |

## Protected shapes of this project

A marker is anything a linter, a build step, a test runner, a template engine
or a CI script matches on. One row per marker this project's own tooling reads
out of comments; the kit's own markers are in the rule already.

| Kind | Shape, with an example | Read by |
|---|---|---|
| Template lead-in in the guide | A bold line that says "template" and names a kit file, before a fenced block: `**Template** (starter kit: \`rules/_rule-template.md\`)` | `scripts/check-guide-templates.sh` — the block must match the kit file byte for byte |
| Evidence stamp | The first line of `docs/EVIDENCE.md`: `<!-- evidence: as of <40-digit commit> — … -->` | `scripts/evidence_tool.py check` (`make evidence-check`) — recomputes the file at that commit |
