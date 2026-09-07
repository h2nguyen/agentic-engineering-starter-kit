# Decision record for the ungated comments rule

## Added

- ADR-0003 records why the comments-and-annotations rule is enforced by review rather than by a check in the lint target, and what was weighed first: an annotation-density check, a marker-aware check, and deferring until the first violation. The rule already stated the conclusion inline; the record carries the rejected options and scopes the exception to judgement about annotation content, leaving marker *shape* gateable as `check-kb-shape.sh` and `check-registry-drift.sh` already gate it.
