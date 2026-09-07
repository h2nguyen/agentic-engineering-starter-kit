# The comments-and-annotations rule is enforced by review, not by a gate

## Status

Accepted

## Context

The framework's third enforcement layer says a documented rule that gets
violated anyway earns a script in the lint target (guide § 1.2 principle P3,
§ 3.8), and the conversion flywheel repeats it as a standing instruction:
*documented rule violated anyway → enforcement script*. Every other rule the
kit ships has a mechanical backstop or can be given one. The shared-registries
rule has `check-registry-drift.sh` and `check-registry-ids.sh`; the
knowledge-base contract has `check-kb-shape.sh`; the claim that gates reach CI
has `check-ci-lint-coverage.sh`. The comments-and-annotations rule has none,
and the question this record settles is whether that is a gap to close later or
a boundary to state once.

What a gate would have to decide is the difficulty. Each of the rule's three
load-bearing judgments is about intent rather than shape:

- whether an annotation is step narration or a marker some tool parses,
- whether a surviving line states a constraint or restates the work beneath it,
- whether a deletion happened in an artifact the change already required.

Three options were weighed.

- **An annotation-density check** — count annotations per unit, fail above a
  threshold. It cannot separate a mandated `// GIVEN` from `// Step 4: Save`,
  so it pushes an author toward deleting whichever annotations are cheapest to
  delete. Those are frequently the protected shapes the same rule exists to
  keep, which makes this option worse than no gate rather than merely
  ineffective.
- **A marker-aware check** — allowlist the protected shapes, flag everything
  else. The allowlist is per project and per toolchain, so the kit cannot ship
  it filled in; an unfilled one degrades to the density check above. Even
  filled, it still cannot tell a one-line constraint from a one-line
  restatement, which is where most of the rule's value sits.
- **Defer, and gate at the first violation** — the flywheel's default answer.
  The trouble is that "deliberately ungated" and "not yet gated" are
  indistinguishable from inside a file. A rule left open because nobody got
  round to closing it keeps losing to the surrounding material, and a workspace
  audit reading the rule would file the absent gate as a finding on every run,
  forever.

Two adjacent invariants are already mechanical and stay that way:
`check-kb-shape.sh` asserts the knowledge base's field labels and typed links,
and `check-registry-drift.sh` asserts the generated-region markers. Both gate
**marker shapes**, which are configuration, rather than annotation density,
which is judgement. That distinction is the line this decision draws.

## Decision

We will enforce the comments-and-annotations rule through review, and we will
say so in writing rather than leave the absence to be inferred.

The rule's own PR checklist and the cross-cutting checks carried by
`agents/_agent-template.md` are its enforcement layer. No annotation-density or
annotation-shape check will be added to the umbrella lint target. The rule
states the same conclusion inline, in its "Enforcement: guidance-only,
deliberately" section, and points here for the alternatives that were weighed.

The exception is scoped to judgement about annotation content. A rule that
constrains a **marker's shape** remains gateable and should be gated, as
`check-kb-shape.sh` and `check-registry-drift.sh` already are.

If the premise stops holding, so does the decision: should a check appear that
can distinguish a mandated marker from narration without punishing the former,
this record is superseded and the rule gets its gate.

## Consequences

**Easier.** A workspace audit has a written answer for the missing gate and
stops re-opening it each run. Reviewers get an explicit contract, since the
rule's checklist and the agent template's cross-cutting checks are the
enforcement rather than a supplement to it. Contributors are not pushed to
delete protected annotations in order to satisfy a number.

**Harder.** The rule's compliance depends on people and on review agents, so it
degrades quietly wherever review is skipped, and nothing reports that. Drift
here surfaces as a slow return of narration rather than as a red build. The
rule's own scope limits the damage, since it applies only to artifacts a change
already touches and never authorises a sweep, but the weaker enforcement is a
real cost accepted knowingly rather than a cost avoided.

**A precedent, deliberately narrow.** This is the kit's first rule shipped
without a mechanical backstop, and the reasoning above is what keeps it from
becoming a general licence. "A gate is hard to write" is not the argument; "a
gate would push authors toward the wrong edit" is. A future rule claiming this
exemption has to make the second argument, not the first.
