# Shared Append-Only Registry Rules

Project-agnostic defaults for every file that many pull requests append to.
Adapt the paths; the mechanics carry over unchanged.

## The Rule

**A shared append-only registry is authored as one file per entry, never as
appended lines in a shared file.**

A file is a shared append-only registry when all three hold:

1. many pull requests **append** to it,
2. at a **fixed anchor** (the end of the file, or a heading that is always
   there), and
3. under an **allocated identifier** (the next free number).

Known instances: changelogs, debugging and incident knowledge bases, decision
records, translation bundles, message-code catalogues, entity registries. If a
file in this project matches the three tests above, it belongs to this rule
even when it is not named here.

Entries live in a fragment directory beside the artifact; a generator assembles
them; CI checks that the committed artifact still matches its fragments.

```bash
python3 scripts/registry_tool.py new --registry <name> --title "..."
make registry-generate
```

## Why — the constraint that ranks every option

> A merge conflict costs thirty seconds. **A duplicate identifier is permanent,
> because the identifier is a citation target.**

Rank every proposal against that sentence rather than against how annoying the
conflict is. Shared registries have two failure modes and only one of them is
loud:

| Failure | How it shows up | Cost |
|---|---|---|
| **Conflict** | git refuses the merge, someone resolves it | seconds, and it is *self-reporting* |
| **Duplicate identifier** | two branches both take the next free number; the merge is **clean**; nothing fails | permanent once anything cites it |
| **Silent loss** | a bullet or entry is dropped by a merge | no test fails; nobody notices a number that is not there |

The second and third are why this rule is mechanical rather than advisory. A
convention that depends on remembering to check cannot prevent a failure whose
defining property is that nobody looks.

Contention also scales with how the project works, not with how big it is. One
person opening one pull request a week meets this once a month; five agents
opening five pull requests in an afternoon meet it constantly. The cost of the
fragment layout is fixed; the cost of not having it grows with parallelism.

## The three tiers

| Tier | Mechanism | Property | When |
|---|---|---|---|
| **Eliminate** | one file per entry + generator; identifiers derived from the filename | the conflict and the collision **cannot occur** | the default — everything below is a fallback |
| **Automate** | `merge=union` in `.gitattributes` **+ a gate that can still see the damage** | the conflict resolves unattended; corruption is caught downstream | registries not migrated yet |
| **Delegate** | an agent resolves the conflict mid-merge | non-deterministic, unauditable, and it fires at the worst possible moment | escalation only, never routine |

Deterministic allocation beats intelligent repair. An agent resolving two
colliding entries **cannot safely renumber either of them**, because it cannot
see which identifiers are already cited in rule files, decision records, code
comments and test names — and a citation that silently stops resolving is worse
than the conflict it replaced. Tools are the right layer for anything that must
come out the same way every time.

## Canonical Example

```text
// WRONG — a bullet appended at a fixed anchor.
// Every concurrent pull request inserts at this same line, so every
// concurrent pair conflicts. Not sometimes: always.
CHANGELOG.md
  ## [Unreleased]
  ### Added
  - Export endpoint for the account ledger.     <- both branches insert here

// WRONG — an identifier allocated by reading the current tree.
// Two branches both see 177 as the highest and both write 178. The merge is
// clean. The duplicate is discovered months later, by which time both are cited.
docs/DEBUGGING-KNOWLEDGE-BASE.md
  ## ISSUE-178: ...                             <- from one branch
  ## ISSUE-178: ...                             <- from the other

// CORRECT — one file per entry; the path carries the identifier.
// Two branches add two different paths, which git merges without being asked,
// and neither branch had to ask what the next free number was.
changelog.d/2026-08-29-ledger-export.md
docs/DEBUGGING-KNOWLEDGE-BASE.d/2026-08-29-cache-warms-before-config.md
```

## Adopting in a repository that already has these files

Infer, then adopt, then verify — never impose:

1. `registry_tool.py init` writes `registries.json` **from what is on disk**. An
   `adr-tools` directory of `0001-title.md` files is declared numeric, width 4,
   no prefix; a knowledge base of `ISSUE-042` entries is declared numeric with
   its identifiers frozen. Existing records are never renamed to fit a
   convention; the convention is written to fit the records.
2. `registry_tool.py adopt --registry <name>` moves each existing artifact's
   entries into fragments, losslessly, and installs the generated region.
   Released changelog sections are left exactly as they are.
3. Chain the gates into the **existing** lint target — `include registry.mk`
   plus the gate names on the `lint` line — then confirm they are reached:
   `make -n lint | grep check-registry`. An installed gate the umbrella target
   never runs is green and checks nothing; `check-ci-lint-coverage.sh` reports
   that state instead of tolerating it.

AsciiDoc artifacts are outside the generator's grammar. Declare them out of
the layout (delete the registry from `registries.json`) rather than adopting
them halfway; `.gitattributes` still gives them `merge=union` as a stopgap.

## Choosing the granularity

The layout says *files, not line ranges*. It does not say how much goes in a
file, and that is a separate decision worth making deliberately.

**Pick the smallest unit that is still a unit of meaning.** For a changelog
that is one file per **change**, with a `## <category>` heading for each
category it touches — not one file per bullet. A file holding a single line
carries no meaning on its own, multiplies for no benefit, and turns one change
that spans three categories into three near-empty files. For a debugging
knowledge base the unit is the **entry**, because each entry is already a
document and its identifier is cited from elsewhere.

The guarantee is unaffected either way: what makes concurrent authorship safe
is that two branches write two different **paths**, and that holds whether a
file carries one bullet or six.

## Identifier schemes

Declared in `registries.json`; both are supported and the choice is per project.

- **`slug`** (default) — `ISSUE-2026-08-29-cache-warms-before-config`. The date
  and slug come from the author, so no allocator exists and no collision is
  possible. Longer, and it does not let you count entries at a glance; the
  generated index carries a display number for that if you want one.
- **`numeric`** — `ISSUE-042`. Short and familiar. The allocator reads only the
  local checkout, so parallel branches **will** be handed the same number: here
  the uniqueness gate is not a safety net, it is the mechanism. Set `id_width`
  to the exact digit count in use.

**Never renumber an identifier that is already on the default branch.** When
the gate reports a collision, rename the fragment that has *not* landed yet. If
both have landed and both are cited, record the pair in
`.registry-id-duplicate-allowlist` and move on — that is what the file is for.

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
bullet reappears under `[Unreleased]` on the next generation. Never hand-edit a
released section afterwards: errata go under a new `[Unreleased]` bullet.

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
to catch the divergence. A rules file claiming mechanical enforcement is only
as true as the workflow step behind it.

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

## PR Checklist

- [ ] Every registry entry in this PR is a new file under a fragment directory,
      not an appended line in a generated artifact?
- [ ] `make registry-generate` run, and the regenerated artifact committed?
- [ ] `make lint` passes locally — drift check, identifier gate, shape check?
- [ ] No identifier renamed that was already on the default branch?
- [ ] If a new registry was added: declared in `registries.json`, its fragment
      directory created, and its generated region marked in the artifact?
- [ ] Bringing an existing artifact under the layout: used
      `registry_tool.py adopt --registry <name>` rather than moving entries by
      hand, so nothing was dropped and no identifier changed?
