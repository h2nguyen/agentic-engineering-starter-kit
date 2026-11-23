# The weekly coach can run on a Claude subscription

## Added

- The coach step of the weekly digest (`--with-coach-schedule`) runs on a `CLAUDE_CODE_OAUTH_TOKEN` repository secret when there is no `ANTHROPIC_API_KEY`. Make the token with `claude setup-token` on a Claude Pro, Max, Team or Enterprise plan and add it as a secret. The API key wins where both are set, and the log of the run says which credential the coach used. With neither secret, the coach is skipped and the log names both. Until now only an API key worked, so on a subscription the digest posted and the coach never ran. ADR-0026 records the decision.
- The token belongs to the person who made it: the coach's runs count against their usage, and it stops when their access does. For a team, prefer a key. This covers a Claude subscription only; a subscription of another tool does not run this coach.

## Changed

- The installer's question, its closing message and the kit README name both secrets. The comment in the workflow that said to swap the credential by hand is gone.
- **Your existing install is not changed**: the installer never replaces a workflow. To take it, copy the "Is the coach configured?" and "Coach proposals" steps from the kit's `ci/agent-feedback.yml.template`, or change the two inputs of the action by hand.
