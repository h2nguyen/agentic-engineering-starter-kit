# Documented commands start Python through the launcher

## Changed

- Every command the installed rules, skills and READMEs give you to type now starts Python the way the kit's own make targets do, as `./scripts/python.sh scripts/<tool> …`, or names the make target (`make registry-list`). Fourteen places said `python3 …` while the Makefile, the gates and the hook went through the launcher, and the one sentence that reconciled the two sat in the constitution template — which a repository that already had a constitution never received. ADR-0013 records the change; it supersedes one paragraph of ADR-0007.
- You get the rules and skills by copying them in upgrade steps 2 and 3. Four texts are yours after the install and are not replaced: `changelog.d/README.md`, `docs/DEBUGGING-KNOWLEDGE-BASE.d/README.md`, and the preamble above the generated region of `CHANGELOG.md` and of `docs/DEBUGGING-KNOWLEDGE-BASE.md`. Upgrade step 4 now lists them for comparing by hand. Nothing fails if you leave them: the old form still runs wherever it ran before.
- The constitution template no longer tells the reader to substitute the launcher for `python3` "here and in every rule"; it says that commands are written through the launcher. If your constitution carries the old sentence, it can go once the rules are updated.
- In the kit's repository: `make documented-commands` (`scripts/check-documented-commands.sh`), part of `make lint`, fails with file and line when a tracked file writes a command that starts Python by a fixed name.
