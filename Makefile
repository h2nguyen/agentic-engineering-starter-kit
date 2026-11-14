# Umbrella lint target for this repository.
#
# The kit's Makefile.template applied to the repository that ships it. It
# invokes the generator and gates from starter-kit/scripts/ directly rather
# than copying them to a top-level scripts/ directory: two copies of one script
# is the duplicated-and-drifting anti-pattern this project names in its own
# guide (§ 5.4), and dogfooding the shipped files is the point.
#
# CI invokes `make lint` — the aggregate target — so a check added here runs in
# CI the same day, with no second edit and no way to forget it.
#
# The top-level scripts/ directory holds gates that check this repository's
# own documents and are not part of the kit: check-guide-templates.sh keeps
# the guide's embedded templates identical to the kit files they name, and
# check-rule-budget.sh keeps the rule files the kit ships short enough to be
# loaded into every session.

KIT := starter-kit

.PHONY: lint test registry-generate registry-list registry-drift registry-ids \
        graph-links graph-impact graph-coverage ci-lint-coverage guide-templates \
        rule-budget kit-smoke

## lint — everything CI runs.
lint: registry-drift registry-ids graph-links ci-lint-coverage guide-templates rule-budget test

## test — unit tests plus the parallel-merge acceptance test.
test:
	$(KIT)/scripts/python.sh -B -m unittest discover -b -s $(KIT)/scripts/tests -p 'test_*.py'
	$(KIT)/scripts/tests/test-ci-lint-coverage.sh
	$(KIT)/scripts/tests/test-parallel-merge.sh
	$(KIT)/scripts/tests/test-graph-links.sh
	$(KIT)/scripts/tests/test-python-launcher.sh
	$(KIT)/scripts/tests/test-brownfield-adoption.sh
	$(KIT)/scripts/tests/test-bootstrap-rerun.sh
	$(KIT)/scripts/tests/test-graph-hooks.sh

## registry-generate — rebuild CHANGELOG.md from changelog.d/.
registry-generate:
	$(KIT)/scripts/python.sh $(KIT)/scripts/registry_tool.py generate

## registry-list — show the declared registries and their entry counts.
registry-list:
	$(KIT)/scripts/python.sh $(KIT)/scripts/registry_tool.py list

## registry-drift — the generated artifacts match their fragments.
registry-drift:
	$(KIT)/scripts/check-registry-drift.sh

## registry-ids — identifiers are well-shaped and unique.
registry-ids:
	$(KIT)/scripts/check-registry-ids.sh

## graph-links — every typed link in the kit's own files resolves. The node
## map in registries.json points the kinds at starter-kit/, so the shipped
## rules, skills, agents and scripts are checked as they will be once installed.
graph-links:
	$(KIT)/scripts/check-graph-links.sh

## graph-impact — what cites NODE, e.g. make graph-impact NODE=RULE:documentation
graph-impact:
	@if [ -z "$(NODE)" ]; then \
	  echo "Usage: make graph-impact NODE=<KIND:name>   e.g. NODE=RULE:documentation, NODE=ADR-0002, NODE=HUMAN, or a file path" >&2; \
	  exit 2; \
	fi
	@$(KIT)/scripts/python.sh $(KIT)/scripts/graph_tool.py impact $(NODE)

## graph-coverage — which shipped rules a script enforces and an agent reviews.
graph-coverage:
	@$(KIT)/scripts/python.sh $(KIT)/scripts/graph_tool.py coverage

## ci-lint-coverage — every sub-target above actually runs in CI.
ci-lint-coverage:
	$(KIT)/scripts/check-ci-lint-coverage.sh

## guide-templates — every template the guide embeds matches its kit file.
guide-templates:
	scripts/check-guide-templates.sh

## rule-budget — every rule file the kit ships stays under the line ceiling
## for an always-loaded file; worked examples live in rules/reference/.
rule-budget:
	scripts/check-rule-budget.sh

## kit-smoke — bootstrap into a throwaway repo and run its gates there.
kit-smoke:
	@set -e; d=$$(mktemp -d); \
	git init -q -b main $$d; \
	git -C $$d config user.email smoke@example.invalid; \
	git -C $$d config user.name smoke; \
	./$(KIT)/bootstrap.sh --tool claude --target $$d >/dev/null; \
	$(MAKE) -C $$d lint; \
	rm -rf $$d; \
	echo "OK: a freshly bootstrapped repo passes its own gates"
