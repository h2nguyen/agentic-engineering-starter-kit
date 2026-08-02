# Working Principles

Five directives that govern HOW an AI agent works on this codebase — orthogonal to
the domain rules in the sibling files. These principles describe **process**; the
domain rule files describe **content**. When the two conflict, the domain rule wins —
but the principles below shape every prompt-to-PR loop.

## 1. Think Before Coding

> Don't assume. Don't hide confusion. Surface tradeoffs.

- **State assumptions explicitly.** When the task is ambiguous, name the assumption
  in chat before writing code. Don't pick one interpretation silently and ship it.
- **Present multiple interpretations.** If a request maps to two or three plausible
  designs, enumerate them with the trade-off in one sentence each and let the user
  redirect.
- **Push back when a simpler path exists.** If the user asks for an abstraction and a
  three-line literal would do, say so.
- **Stop when confused.** If a symptom doesn't match a known issue in the debugging
  knowledge base and the root cause isn't obvious after two reasonable hypotheses,
  ask the user before spelunking further.

## 2. Simplicity First

> Minimum code that solves the problem. Nothing speculative.

- **No speculative features.** If the task doesn't ask for it, don't build it — even
  if "we'll probably want this next sprint".
- **No abstractions for single-use code.** A service with one implementation, called
  from one place, is just an indirection. Inline it until a second caller appears.
- **No error handling for impossible scenarios.** Trust framework guarantees and
  internal invariants. Validate at system boundaries (controllers, external API
  clients, file parsers) — not at every internal method call.
- **Senior-engineer litmus.** Before opening the PR, re-read the diff and ask:
  *"Would a senior engineer call this overcomplicated?"* If yes, simplify first.

## 3. Surgical Changes

> Touch only what you must. Clean up only your own mess.

- **Don't improve adjacent code.** A bug fix in one service is not the moment to
  refactor a different one two files over, even with the same code smell. File a
  separate ticket if it really matters.
- **Don't refactor functioning code.** Working code without a test is scarier than
  working code with one — write the missing test, don't rewrite the implementation.
- **Match existing style.** Your new code follows the conventions of the surrounding
  file, even where you'd personally prefer otherwise.
- **Mention pre-existing dead code, don't delete it.** If you spot unused code your
  change didn't create, call it out in the PR description so the user can decide.
- **Remove only what your changes made unused.** If your refactor leaves an import
  dangling, remove it. If it was already dangling before you started, leave it.

## 4. Goal-Driven Execution

> Define success criteria. Loop until verified.

- **Transform tasks into verifiable goals.** "Make the list filter by date" →
  "given seed rows on Jan 15 and Apr 15, when the filter is set to thisMonth, then
  only the April row is visible". A goal you can write a test against is a goal you
  can finish.
- **Write the test first.** Red → Green → Refactor. Bug fixes ship with a regression
  test that was failing before the fix.
- **State the plan with checkpoints.** For any task with more than ~3 steps, write
  the plan in chat first, then execute, ticking off each step.
- **Declarative > imperative.** "The endpoint returns 201 with the uuid in the body"
  is a goal. "Add `status(201)` to the controller" is an instruction. Goals survive
  re-implementation; instructions don't.

## 5. Plan-First for Non-Trivial Work (QRSPI)

> Questions → Research → Structure → Plan → Implement. Front-load understanding; code last.

For any task that is medium-sized, ambiguous, architectural, or cross-cutting, run
explicit planning phases BEFORE the first line of production code — proportional to
the task: a quick mental pass for small fixes, explicit written phases for anything
bigger.

- **Questions first.** Surface every ambiguity, then split it: BLOCKING questions only
  the user can answer (stop and ask — batch them, don't trickle) vs. parked questions
  you can resolve yourself during research. Only blockers pause the work.
- **Research with evidence.** Resolve parked questions before designing: read the full
  ticket INCLUDING its comment thread (descriptions go stale — the most recent
  authoritative comment wins), follow linked tickets/PRs one hop deep, and search the
  codebase for prior art before inventing anything new.
- **Design with alternatives.** Propose your design plus at least one alternative with
  a one-line trade-off, and let the user redirect. Record significant decisions in a
  durable home (e.g. an ADR), not only in chat.
- **Structure before code.** Map the files/modules you expect to touch and where they
  sit in the architecture. A change map makes scope visible and reviewable before any
  of it is real.
- **Publish the plan where the work is tracked.** Put the checkpointed task list on the
  ticket/PR — not only in chat — so progress is observable and survives the session.
- **Then implement** under the normal quality gates: principles 1–4 apply unchanged,
  including TDD from principle 4.

## Litmus tests before opening a PR

- [ ] Did I state my assumptions in chat before coding the ambiguous parts?
- [ ] Does every changed line trace directly to the user's request?
- [ ] Would a senior engineer call any part of this overcomplicated?
- [ ] Did I avoid refactoring code that wasn't part of the task?
- [ ] Did I write the test before the implementation (or the regression test before
      the bug fix)?
- [ ] Can I describe success as a goal a test can verify?
- [ ] For non-trivial tasks: did I publish the plan (open questions, chosen design and
      its alternative, task list) where the work is tracked — not only in chat?

If any answer is "no", the loop isn't done — go back before pushing.
