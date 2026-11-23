# An install records its kit version, and kit-status shows what is newer

## Added

- A first install writes `.starter-kit-version` at the root of your repository: the kit's release, its commit and the agent tool, on all four tools. Nothing else used to record which kit an install came from. Only two things write the file: the installer on a first install, and `kit-status.sh --record` at the end of an upgrade. A re-run of the installer never changes it. ADR-0024 records the decision; it supersedes ADR-0011.
- `starter-kit/kit-status.sh`, in the kit: run from your repository it prints the kit your repository records, the kit in the checkout you run it from, the changelog entries between the two with the **Breaking** ones first, and each of the kit's files in your repository as current, the older kit's, changed here, missing, declined or retired. It checks the record against the files on every run: an upgrade left half done is reported as partial, and a record the files contradict as one that does not hold. It uses no network — update the checkout to learn of a newer release.
- `make kit-status` prints the record; `make kit-status KIT=<checkout of the kit>` runs that report. You get the target with `registry.mk` in upgrade step 2.
- Upgrade step 7, `kit-status.sh --record`, writes the record once the files bear it out. It refuses, naming the files, while one of the kit's files is still an older release's text or is missing without being listed in `.starter-kit-declined`. A file you changed yourself is accepted and named.
- An install from before this release has no record. The report says so, names the release its files match, and prints the command that records it: `kit-status.sh --record --as v3.0.1`. Nothing fails without a record.
- `bootstrap.sh --with-upgrade-notice` installs `.github/workflows/kit-upgrade-notice.yml`; the installer also asks at a terminal on a first install, and never installs it unasked. Once a week the workflow lists the kit's release tags and opens an issue labelled `kit-upgrade` when one is newer than your record. It is the only part of the kit that uses the network: it downloads no code and can write to issues only. To keep it out for good, list its path in `.starter-kit-declined`.

## Changed

- The upgrade steps start by asking `kit-status.sh` what the upgrade is, and end with step 7. The line of step 2 that removes the kit-only suites names one more, `test-kit-status.sh`.
- On a re-run, the installer says that it wrote no version record, and why: it replaced none of your files, so a record naming the newer kit would be false.
