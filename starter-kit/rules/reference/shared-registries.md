# Shared Append-Only Registries — gotchas in full

The on-demand companion to the shared-registries rule. The rule lists each of
these in one line; this file carries the reasoning and the mechanics. It is
**not** loaded into every session — open it when a registry merge misbehaves,
when a gate's message points here, or before changing the merge configuration.

## Gotchas

### Union merge without a downstream gate is worse than no configuration

`merge=union` keeps both sides of a conflicting hunk instead of raising a
conflict. It removes the loud failure and leaves the quiet one — two branches
rewording the same line yield both wordings, and a duplicate identifier merges
cleanly with nothing raised. Ship it only where something downstream can still
see the damage. Here that is the drift check: a mangled generated file stops
matching its fragments, and CI says so. Remove the drift check and the union
entries in `.gitattributes` have to go with it.

The drift check compares what the artifact **says** — the same entries with
the same content, in any order — not its bytes. A union merge keeps both
branches' generated blocks in whichever order they arrived and drops the blank
line between them; that is not drift, and failing on it would demand a
regenerate commit after every concurrent merge, which is most of the friction
this layout exists to remove. Real corruption still fails: a changed body, a
missing entry, the same identifier twice with two bodies.

### Where union merge stops being safe

Git refines a conflict by diffing the two sides against each other and keeping
whatever they have in common. Two concurrently added entries that share **two
or more consecutive identical lines** are therefore interleaved — each keeps
its unique lines, the shared run appears once, and both entries are wrong. No
merge attribute prevents this. Three things contain it:

- every rendered entry ends with a line unique to it, and every changelog
  category is preceded by a stable anchor, so the common case has no shared
  run to find;
- the `check` gate refuses unfilled template placeholders, which is the usual
  way two entries acquire identical adjacent lines;
- the drift check catches the rest — loudly, never silently — and one
  regenerate restores the artifact.

So the guarantee is precise: a concurrent merge is never a *conflict* and never
*silent*. In the common case it is also green with nothing to do; in the rare
case above it costs one `make registry-generate` commit.

### A release moves the anchor other branches are appending to

Promoting `[Unreleased]` into a version section relocates the heading concurrent
branches were writing under. Under a plain text merge their bullet lands in a
section that has moved, and nothing fails. Promotion here consumes the fragment
*files*, so a branch that added one in parallel still holds its own file and its
bullet reappears under `[Unreleased]` on the next generation. Under `merge=union`
the merge can also leave a copy of that bullet — or a generated-region marker —
inside the new release section; regenerating cannot repair what lies outside the
region, so the drift check fails on it and names the line to delete. Never
hand-edit a released section otherwise: errata go under a new `[Unreleased]`
bullet.

### Assert the shape before asserting uniqueness

`ISSUE-7`, `ISSUE-07` and `ISSUE-007` are one identifier to a reader and three
to a check that only compares numbers. A width variant walks straight past a
uniqueness test and lands a duplicate that reads as unique. The shape assertion
has to run first or the uniqueness assertion buys nothing.

### Key the duplicate allowlist on the filename pair, not the identifier

An allowlist entry naming only the number reads as "this number is exempt", and
would let a *third* file join a legacy pair unnoticed — the exact drift the gate
exists to catch. Name both files, so the exemption says what it means.

### A Makefile target is not a CI step

A check that is chained into `make lint` but not into a workflow step does not
run. Where CI enumerates sub-targets one at a time, the two lists drift apart
one pull request at a time and nothing reports it: the checks still pass
locally, the rule files still describe the conventions as enforced, and a gate
that quietly stopped running is discovered only by the bug it should have
caught. Have CI invoke the aggregate target, or run `check-ci-lint-coverage.sh`
to catch the divergence. It counts only what a workflow really runs: the
`run:` of a step, read as shell, in a workflow a push or pull request triggers,
not switched off with `if: false`, in the repository root and not as `make -n`.
A target named in a comment, an `echo`, a step name or another directory's
Makefile covers nothing. A rules file claiming mechanical enforcement is only
as true as the workflow step behind it.

### A CI step is not a CI run

The coverage check reads the workflow files in the checkout. It cannot see
the hosting platform, so a workflow that is right on disk and has never
completed a run passes it on every lint. That happened: every run of a
repository's lint workflow ended within seconds, before its first step — a
billing stop — while the coverage check printed `OK` and four pull requests
were merged on a default branch that required no check. Each stage has its
own evidence: the Makefile says a check is chained, the workflow file says a
step invokes it, and only a completed run says it ran. Look at one on the
first pull request, and make the lint check a required status check on the
default branch, so that a pull request no run has checked cannot be merged.
Remember what starts a run: a workflow that triggers on pull requests and on
pushes to the default branch does nothing when a feature branch is pushed.

### Custom merge drivers do not travel with the repository

`merge=union` is built into git and needs nothing in any clone. A **custom**
driver named in `.gitattributes` needs `git config merge.<name>.driver` in
every clone, and when that is missing git falls back **silently** — the
repository looks configured and is not. The same applies to hooks: a hook
directory that is committed does nothing until `core.hooksPath` points at it.
Anything requiring per-clone setup ships with its bootstrap **and** a check that
verifies the setup actually took effect.

### Do not "simplify" the fragments back into one file

The indirection looks like ceremony from inside a single pull request, because
from there the shared file works fine. It stops working the moment a second
branch is open. Read this rule before proposing the collapse.
