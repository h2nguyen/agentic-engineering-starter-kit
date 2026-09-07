# Installer re-run and guide template gate

## Fixed

- `bootstrap.sh` no longer appends a second registry block to `.gitattributes` when re-run on a repository it bootstrapped from scratch: the template now carries the same marker lines the installer writes when it appends to an existing file, so both paths leave a file a re-run recognises.
- The guide's embedded copies of the constitution, rule, agent, command, check-script and knowledge-base templates match the kit files again; the constitution copy had been missing the registry layer (the `make registry-generate` command, the Registries row and the shared-registries index line).

## Added

- `test-bootstrap-rerun.sh`: a second bootstrap run on a fresh repository changes nothing, and every tool layout receives the constitution and every shipped rule at its own rule location. Chained into the kit's `registry-test` target beside the brownfield-adoption test.
- `check-guide-templates.sh` (this repository only, not part of the kit): `make lint` now fails when a template the guide embeds drifts from the kit file it names; a block whose lead-in does not say "template" is listed as an illustration and never compared.

## Changed

- `bootstrap.sh` decides the constitution path and the rules directory once per tool and installs the default rules from one list, so a new default rule is one edit rather than one per tool layout. Installed files, locations and order are unchanged.
- The constitution template's index line for the documentation rule says "ADR format (Michael Nygard)" instead of the retired "ADR-lite"; the kit README's row for that rule follows.
