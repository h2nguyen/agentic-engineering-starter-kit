# The workflows run their actions on Node 24

## Changed

- The workflows the installer puts in place — `.github/workflows/lint.yml`, and `agent-feedback.yml` with `--with-coach-schedule` — use `actions/checkout@v7` and `actions/setup-python@v7`. The versions they named before, `checkout@v4` and `setup-python@v5`, run on Node 20, which GitHub's runners have deprecated; both `v7` actions run on Node 24. Nothing else in the workflows changed.
- **Your existing install is not changed**: the installer never replaces a workflow, and the file is yours. To follow, change the two `uses:` lines in each workflow by hand. `checkout@v7` needs a runner of version 2.327.1 or newer, which GitHub-hosted runners have; check a self-hosted one first.
