# Declined artifacts stay out and the SessionStart skeleton is a template

## Added

- `.starter-kit-declined`: a list you write at the root of your repository, one path per line with an optional `# reason`. The installer leaves a listed file out, and a listed directory with everything beneath it — on a first install and on every re-run — and reports each under "Skipped" as declined. Until now a file of the kit's that you had deleted came back with the next run, because the installer adds whatever is missing and cannot tell "deleted on purpose" from "new in this kit". Use it for a skill your organisation already ships as a plugin, a suite you do not run, a template you do not want. The installer never creates or edits the list. See "Declining what the kit installs" in the kit README, and ADR-0014.
- The installer prints which kit it is, as a `Kit:` line: the last release in the kit's changelog and, from a checkout, the commit. Nothing in your repository records the kit an install came from (ADR-0011), so the handoff copies that line. A bare copy of `starter-kit/` inside a project says the version is not recorded.
- On Claude Code, `docs/agent-templates/session-start.sh.template`: the SessionStart hook skeleton, with the steps to put it in place and the `settings.json` entry in its header.

## Changed

- On Claude Code a fresh install no longer installs `.claude/hooks/session-start.sh` and no longer registers a `SessionStart` hook. The skeleton did nothing but append `PATH` to the session's environment file and print "session-start: toolchain ready" — into the session's context, about a toolchain it had not checked. It is a template now, for the day sessions need environment setup (ADR-0015).
- **Your existing install is not changed.** If you have the hook and its entry in `.claude/settings.json`, they stay: fill the hook in, keep it, or delete the file and the entry together. If you delete it, nothing puts it back — newer kits do not install it. Upgrade step 1 adds the template.
- A re-run of the installer that installed something says how to decline it, and the first-install steps on Claude Code say what to do about a skill you already have from elsewhere.

## Fixed

- The skeleton prints nothing as shipped. Its header gains a third design rule: what a SessionStart hook prints is read by the agent as fact, so print a state only after the step that checked it.
