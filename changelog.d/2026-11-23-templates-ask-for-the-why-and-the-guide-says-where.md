# Templates ask for the why, and the guide says where agent memory belongs

## Changed

- The rule, skill and reviewer-agent templates in `docs/agent-templates/` each carry a `**Why:**` line. A rule, workflow or review mandate stated without its reason is followed to the letter and misapplied at the first case its examples do not show. With the reason, the next correction can sharpen a principle instead of adding one more special case. The templates are yours after the install: to take the new line, delete `docs/agent-templates/` and re-run the installer (upgrade step 2), or add the line by hand.
- `rules/documentation.md` lists "its why" among the parts a new rule file carries. You get it by copying the rule in upgrade step 3.
- The guide's P6 and its flywheel table (§ 5.1) now say what to do with memory an agent tool writes on its own. Treat it as an inbox. A note that holds a second time is promoted into a rule, skill or knowledge-base entry by pull request, and the note is deleted.
