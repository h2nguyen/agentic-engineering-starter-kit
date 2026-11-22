# Feedback to an agent is written down and collected by artifact

## Added

- An `Agent-Feedback: <token> — <what went wrong and why>` line, written in a commit message or a pull-request or issue comment, records a correction to the rule, skill, agent or command that caused it. The documentation rule describes it, and tells the agent to offer the line when you correct it. Corrections no longer end with the chat session they were made in.
- `make agent-feedback` (`scripts/feedback_tool.py collect`) reads those lines from the commit history, and from a JSON comment export with `FROM=<file>`, and prints one JSON report grouped by artifact. Tokens that name nothing are listed as unresolved. It is a report, not a gate, and runs offline on every tool. A fresh install gets it; an existing one gets it from upgrade steps 1 and 2.
- `.agent-feedback-authors`, at the repository root, lists whose feedback counts: one commit email or comment login per line. It is installed naming nobody, and the installer says so until you fill it in. Lines from anyone not listed are counted, with their author only if it is shaped like an email or a login and their target only if it resolves, but their text never reaches the report, because what reaches it can become an instruction every later session follows. Merge commits are skipped: their body is the pull request's text under the merger's identity.
- The `agent-coach` (`--with-meta`, Claude Code) reads the report when it observes, cites the feedback behind each proposal, and lists feedback on skills, rules and commands for you to act on.

## Changed

- `rules/documentation.md` has a new section, "Feedback to an agent", and a row in its "What to update when" table. You get it by copying the rule in upgrade step 3.
