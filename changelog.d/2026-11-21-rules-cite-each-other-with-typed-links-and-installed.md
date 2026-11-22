# Rules cite each other with typed links, and installed files no longer say Copy to

## Changed

- Every rule the kit ships is now named by a typed link of another installed artifact, on all four tools. `working-principles`, `comments-and-annotations` and `versioning-and-changelog` were cited only in prose, so `make graph-impact NODE=RULE:<name>` answered "nothing", a rename passed `make lint`, and the Claude Code hook stayed silent after an edit. The rules carry `**Related:**` lines for the dependencies they already described in sentences, and the `registry-entry` and `registry-conflict-triage` skills name the versioning rule. You get them by copying the rules and skills in upgrade steps 2 and 3.
- If you deleted one of the kit's rules and copy a newer rule that names it, `make graph-links` fails on that `Related:` line and says which token resolves to nothing: remove the token from the line.

## Fixed

- The installed `Makefile`, `.gitattributes`, `.github/workflows/lint.yml` and `.registry-id-duplicate-allowlist` no longer open with "Copy to …", an instruction to put the file where it already is. The header now says where the file is installed, which is true in the kit and in your repository alike. These four files are yours after the install and are not replaced by an upgrade; to take the fix, edit the one line in each.
