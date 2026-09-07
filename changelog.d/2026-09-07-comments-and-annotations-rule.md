# Comments and annotations rule

## Added

- `rules/comments-and-annotations.md`: a domain-agnostic rule for self-explaining work products — structure before annotation (rename, extract, restructure), a one-line brevity standard for what survives, protected marker shapes that are never stripped, an audience litmus for where rationale lives, and an explicit no-sweeps scope. `bootstrap.sh` installs it for every tool, the constitution template indexes it, and the setup prompt's fallback specs carry it for kit-less installs. Its protected-shapes table arrives pre-filled with the markers the kit's own tooling parses (generated-region and category anchors, knowledge-base field labels, the `.gitattributes` block markers, enforcement-script headers and escape markers, decision-record headings) and leaves four `<placeholders>` for the adopting project; `starter-kit/README.md` documents how to fill them.
- The rule's reviewer bullets as cross-cutting checks in the agent template, and one pointer in the working-principles pre-PR litmus, so specialist reviewers and the pre-PR self-check inherit them.

## Changed

- The documentation rule's "decision rationale lives in ADRs, not in code comments" section now routes to the comments-and-annotations rule instead of carrying its own copy of the comment doctrine, so the doctrine has one home; its WRONG/CORRECT pair and audience litmus moved there.
