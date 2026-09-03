# ADR-002: Shared append-only registries ship as a day-1 default, not a grown-by-signal artifact

## Status

Accepted

## Context

The kit's governing doctrine is **grow by signal, not speculation** (guide
§ 4.5, principle P6): every artifact must trace to something that actually
recurred in the adopting project. Applied literally, the fragment layout for
changelogs and knowledge bases would be a Level-2 or Level-3 artifact, added
after a team has felt the pain twice.

Three things argue against that placement.

**The defect class is structural, not incidental.** A file that many pull
requests append to, at a fixed anchor, under an allocated identifier, conflicts
on *every* concurrent pair. The kit shipped three such files by default — the
debugging knowledge base (one file, allocated `ISSUE-NNN`), the changelog
(all six Keep-a-Changelog headings always present, so every added bullet
inserts at the same line), and the decision records (one file per decision, but
an allocated number in the filename). The kit was distributing the defect, not
merely failing to solve it.

**The retrofit cost is not flat — it rises with adoption.** While a registry is
empty, converting it is a file move. Once entries exist and their identifiers
are cited from rule files, decision records, source comments and test names,
conversion has to preserve every one of those citations, and nothing in a
typical repository checks that a cited identifier still resolves. Waiting for
the signal means paying the expensive version of the fix.

**The failure the signal would announce is the loud one; the expensive failure
is silent.** A conflict reports itself. A duplicate identifier does not: two
branches both take the next free number, the merge succeeds, no test fails, and
the collision surfaces months later. So does a dropped changelog bullet. Waiting
for a signal works only where the failure generates one.

Contention also scales with parallelism rather than repository size, which is
what makes this specific to the kit's subject matter. One person opening one
pull request a week meets it monthly and calls it an annoyance. Several agents
opening several pull requests in an afternoon meet it constantly.

Six approaches were weighed.

- **Leave it to the flywheel (add it when a project hits the problem twice).**
  The expensive failure mode is silent, so it generates no signal — and by the
  time a signal does arrive, the identifiers are already cited and the cheap
  fix is gone.
- **Ship `merge=union` in `.gitattributes` and nothing else.** Insufficient
  and, alone, actively harmful: union merge removes the conflict and keeps the
  silent corruption, so it trades the loud failure for the quiet one. It is
  worth shipping only alongside a drift check that can still see the damage.
- **Ship a conflict-resolution skill instead of a file-layout change.** An
  agent resolving two colliding entries cannot safely renumber either, because
  the citations that would break live in files the resolution never opens.
  Deterministic allocation beats intelligent repair. The skill has a place, but
  as escalation for the residue rather than as the mechanism.
- **Number entries by timestamp inside the existing single file.** The
  precedent it borrows from — database migrations — does not conflict because
  there is *one file per migration*; the timestamp is only a sort key.
  Timestamps inside one shared file leave every conflict exactly as it was.
- **Use short commit SHAs as identifiers.** They solve collisions and destroy
  the searchability of a file whose entire purpose is to be scanned by a human
  under time pressure. A date-plus-slug identifier answers the collision
  problem and reads better than an allocated number.
- **Cover the knowledge base only, and document the rest.** The changelog is
  the higher-churn instance in most repositories, and a pattern stated but not
  applied to the kit's own defaults is the "rules without enforcement"
  anti-pattern the guide names (§ 5.4).

## Decision

**The shared-append-only-registry layer installs at Level 1, for every
supported tool**: fragment directories, `registries.json`, `.gitattributes`,
the generator, the drift and identifier gates, the CI-coverage gate, the lint
target and its workflow, the rule file, and the two skills.

The registries themselves stay empty. What ships on day one is the *shape* they
will be filled in, which is the part that is expensive to change later.

Identifier schemes are configurable, with `<prefix>-<date>-<slug>` as the
default and an allocated numeric scheme as the documented alternative. The
default needs no allocator and therefore cannot collide; the numeric scheme is
supported because short identifiers are genuinely easier to say and cite, and
the gate is what makes it survivable.

## Consequences

**Easier:** a repository scaffolded from the kit can have two branches each add
a registry entry and merge both with zero conflicts and zero duplicate
identifiers, from commit one. The generator is also the seam the deferred
knowledge-graph layer (guide § 5.6) will read from: fragments are already
one well-formed node per file.

**Harder:** the day-1 install is larger, and it introduces a generated-file
discipline — contributors must edit fragments rather than the artifact they
read. That indirection looks like ceremony from inside a single pull request,
which is why the rule file, the generated-region markers and the artifact
headers all state the reason in place rather than assuming anyone will look it
up.

**Also harder:** the kit now depends on `python3` for the generator, where it
previously needed only `bash` for `check-kb-shape.sh`. Accepted: the generator
does parsing, stable ordering and idempotent assembly, all of which bash does
badly, and the kit already vendors a Python tool with its own test suite.

**Deliberately not done:** no migration tooling for repositories with existing
numbered entries. The correct move there is to freeze the identifiers already
in use and apply the new scheme only to new entries — never to renumber what is
already cited — and that is a documented procedure rather than a script.

**Trigger to revisit:** if an adopting project reports that the fragment
indirection costs more than the contention it prevents — most plausibly a
single-maintainer repository with no parallel branches — the layer becomes a
`--with-registries` opt-in rather than a default.
