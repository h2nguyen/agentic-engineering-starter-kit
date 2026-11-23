# A weekly feedback digest, with the coach's proposals, opt-in at install

## Added

- `bootstrap.sh --with-coach-schedule` installs `.github/workflows/agent-feedback.yml`. The installer also asks at a terminal on a first install; run without a terminal it adds the workflow only with the flag. Every Monday, and by hand from the Actions tab, the workflow collects the last week's `Agent-Feedback:` lines and posts a digest on one open issue labelled `agent-feedback`. An empty week posts nothing.
- With an `ANTHROPIC_API_KEY` repository secret and the Claude GitHub App installed, the same run has the agent coach read that feedback and post its proposals as a comment on the issue. The job can read code and write to issues only: it never pushes, branches or opens a pull request. A person decides.
- To add it to an existing install, re-run the installer with `--with-coach-schedule` (upgrade step 1). To keep it out, list `.github/workflows/agent-feedback.yml` in `.starter-kit-declined`; the installer then stops asking.
- `make agent-feedback FORMAT=markdown` (`feedback_tool.py collect --format markdown`) prints the report as a digest a person reads. Like the JSON, it never contains an unlisted author's text. You get the target with `registry.mk` in upgrade step 2.
