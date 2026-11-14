# An upgrade that makes adopters edit their own files is a MAJOR release

## Status

Accepted

## Context

The kit versions itself with Semantic Versioning and installs a rule that
tells adopters to do the same: from 1.0.0 on, a breaking change requires
MAJOR. Semantic Versioning only means something against a defined public
contract, and the kit had never said what its own is. `CONTRIBUTING.md` named
two cases — new functionality is MINOR, a fix-only release PATCH — and no
third.

The release after 1.1.0 forced the question. Most of it is additive: a link
gate, three queries, a hook, a launcher. But a repository that follows the
upgrade steps meets three things that fail a lint which passed before:

- a check script of its own whose header reads `# Enforces: <rule> — see
  <file>`, the form the 1.x template shipped, fails the new link gate;
- a `Related:` line naming an artifact that does not exist, which every 1.x
  gate accepted, fails it too;
- a Makefile of its own must add `graph-links` to its lint target, or the
  coverage gate fails.

Two readings were weighed.

- **MINOR.** No install is ever changed without its owner acting: the
  installer never overwrites a file, the upgrade is manual, and its steps are
  written down. Nothing resolves a version range against the kit.
- **MAJOR.** The number is read by a person deciding whether an upgrade can
  be taken as it is. For these three points it cannot. A linter that turns a
  new check on by default, and so reports more errors on unchanged input, is
  the same case, and the common policy for linters calls it major. And a kit
  that installs the rule "breaking requires MAJOR" and ships its own breaking
  change as MINOR states a rule it does not keep.

1.1.0 is no precedent for MINOR: it added a rule and a test, and no gate that
could fail existing content. The gates that changed what a repository must
look like arrived with 1.0.0.

## Decision

We will treat as the kit's public contract what an adopter's repository relies
on: the installer's options and its guarantees; the commands and exit statuses
of the installed tools; the formats the gates read — `registries.json`, the
fragment shape, the link lines, a check script's header; and the set of gates
the default lint target runs.

A release is **MAJOR** when a repository that passed `make lint` on the
previous version, and follows the documented upgrade steps, fails it — or has
to edit a file of its own for any other reason. A gate that is on by default
and can fail content that passed before is the usual cause.

A release is **MINOR** when it adds something and a passing repository still
passes: a new command, a new artifact, a gate that is opt-in or checks only
what is written from now on. **PATCH** is fixes alone.

Each breaking change is marked **Breaking** in its changelog bullet, and the
release commit carries a `BREAKING CHANGE:` footer.

The release after 1.1.0 is therefore 2.0.0.

## Consequences

**Easier.** The number answers the question an adopter has. The next release
has a test to apply instead of a habit to follow.

**Harder.** The kit will reach MAJOR versions faster than a library does: its
purpose is to add gates, and a default gate that can fail existing content is
MAJOR by this rule. A change that could have shipped quietly now needs either
a major release or a design that makes it opt-in first.

**Not covered.** Wording changes in rule files are merged by the adopter and
are not breaking in this sense, however much they ask of a reader.

**Trigger to revisit.** If major releases become frequent enough that the
number stops telling an adopter anything, new gates ship opt-in for one
release and become default in the next major, so that breaking changes are
batched.

**Related:** ADR-0004, ADR-0002
