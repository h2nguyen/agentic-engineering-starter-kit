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
./scripts/python.sh scripts/registry_tool.py new --registry <name> --title "..."
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
  to the exact digit count in use. A file named by date in a numbered registry
  is refused: at width 4 its year would read as the number.

**Never renumber an identifier that is already on the default branch.** When
the gate reports a collision, rename the fragment that has *not* landed yet. If
both have landed and both are cited, record the pair in
`.registry-id-duplicate-allowlist` and move on — that is what the file is for.

## Gotchas

Each is written up, with its reasoning, in
`docs/rule-reference/shared-registries.md` — read on demand, not loaded into
every session. The one-line form:

- **Union merge without a downstream gate is worse than no configuration.** It
  removes the loud failure and keeps the silent one; the drift check is what
  makes it safe, and the two ship or go together.
- **Where union merge stops being safe.** Two concurrent entries sharing two or
  more consecutive identical lines are interleaved; the drift check says so and
  one `make registry-generate` restores them.
- **A release moves the anchor other branches are appending to.** Promotion
  consumes fragment files, so a parallel bullet reappears under `[Unreleased]`;
  never hand-edit a released section.
- **Assert the shape before asserting uniqueness.** `ISSUE-7` and `ISSUE-007`
  are one identifier to a reader and two to a number comparison.
- **Key the duplicate allowlist on the filename pair, not the identifier.** A
  number-keyed entry would let a third file join the pair unnoticed.
- **A Makefile target is not a CI step.** A check CI never invokes does not
  run; have CI call the aggregate target.
- **Custom merge drivers do not travel with the repository.** Anything needing
  per-clone setup ships with a check that the setup took effect.
- **Do not "simplify" the fragments back into one file.** It works until a
  second branch is open.

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
