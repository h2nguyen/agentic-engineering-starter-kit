# The coach runs on an API key, or else on a Claude subscription

## Status

Accepted. Supersedes the sentence of ADR-0021 that makes an API key the one way to run the coach. Everything else in ADR-0021 stands.

**Related:** ADR-0021, ADR-0008

## Context

ADR-0021 put the coach step of the weekly digest behind an `ANTHROPIC_API_KEY` secret: "which belong to the project", "a paid key". Most people who would use the kit work on a subscription — Claude Code on Pro or Max — and have no API key. For them the digest works and the coach step is skipped, so the half of the loop that turns evidence into proposals never runs. The template's comment told them to edit the workflow by hand, which is a file they own after the install and which nothing upgrades.

`claude-code-action` takes either credential: `anthropic_api_key`, or `claude_code_oauth_token`, which Pro, Max, Team and Enterprise users make with `claude setup-token`. It also reads both from the environment when an input is empty.

What to weigh:

- **Whose limit it spends.** The token belongs to the person who made it. The coach's runs count against that person's usage, and the coach stops when their access does. An API key belongs to the project.
- **What happens when both exist.** Passing both leaves it to the action which one wins. That is not something a workflow of ours should depend on.
- **Other tools' subscriptions.** The coach is an agent file run by `claude-code-action`. Codex, Cursor and Copilot have no equivalent action in this workflow, and no signal asks for one.

Options weighed:

- **Keep the API key only** (ADR-0021 as it stands). Cheapest to reason about; leaves the coach off for most adopters.
- **Subscription token only.** Simplest for individuals, and wrong for a team: the loop would hang on one person.
- **Pass both credentials and let the action choose.** Short, and unspecified.
- **The step chooses, the action gets one.** The API key where there is one; else the subscription token; else nothing, and the log says so.

## Decision

We will have the "Is the coach configured?" step choose the credential, in this order: the coach's file must exist; then `ANTHROPIC_API_KEY`; then `CLAUDE_CODE_OAUTH_TOKEN`. It writes `auth=api-key` or `auth=subscription` and says which in the log. With neither secret it skips the coach and names both.

The action step passes exactly the credential the step chose, and an empty string for the other.

The workflow's header says that the token is its maker's, that its usage limit is theirs, and that a team should prefer a key. The installer's messages and the README say the same in one sentence.

Nothing else changes: the job keeps `contents: read` and `issues: write`, the coach keeps its read-only tools, and it still proposes and never changes the repository.

This is a MINOR change (ADR-0008). An existing install keeps its workflow; the installer never replaces one.

## Consequences

**Easier.** An adopter on a subscription gets the coach with one secret and no edit to the workflow. The log says which credential ran.

**Harder.** The coach's cost now depends on who made the token. If that person's access ends or the token is revoked, the action step fails and the run is red: the digest was already posted, the proposals were not. Nothing hides that.

**Not covered.** Codex, Cursor and Copilot subscriptions. Whether a subscription may be used this way in an automated workflow is for Anthropic's terms to say and for the adopter to read; the kit does not decide it and does not assert it. The decision step is held by acceptance tests with every combination of the two secrets, and the action step by a check on the inputs it passes. The subscription path itself has not run on GitHub, because that takes a token only a person can make.

**Existing installs are not changed.** To take it, replace the "Is the coach configured?" and "Coach proposals" steps with the template's, or change the two inputs by hand.

**Trigger to revisit.** A request for another tool's subscription, with a runner that can execute the coach file; or a team whose coach stops each time a token's owner changes, which would make the API key the only default.
