# Registry targets — include this from your Makefile.
#
#     include registry.mk
#     lint: registry-drift registry-ids kb-shape ci-lint-coverage <your targets>
#
# Shipped as a separate file so a repository that already has a Makefile can
# adopt the layer with one `include` line and one edit to its lint target,
# instead of merging targets by hand. Greenfield installs get the same file
# behind the kit's Makefile.template, so there is exactly one copy of these
# targets to maintain.
#
# If the umbrella lint target does not reach registry-drift and registry-ids,
# check-ci-lint-coverage.sh fails and says so — an installed gate that nothing
# runs is indistinguishable from no gate at all.

.PHONY: registry-generate registry-list registry-drift registry-ids kb-shape \
        ci-lint-coverage registry-test

## registry-generate — assemble every registry artifact from its fragments.
registry-generate:
	python3 scripts/registry_tool.py generate

## registry-list — show the declared registries and their entry counts.
registry-list:
	python3 scripts/registry_tool.py list

## registry-drift — the generated artifacts say what their fragments say.
registry-drift:
	./scripts/check-registry-drift.sh

## registry-ids — identifiers are well-shaped and unique.
registry-ids:
	./scripts/check-registry-ids.sh

## kb-shape — the assembled knowledge base parses as graph nodes.
kb-shape:
	./scripts/check-kb-shape.sh

## ci-lint-coverage — every lint sub-target actually runs in CI, and the
## registry gates are actually reached by lint.
ci-lint-coverage:
	./scripts/check-ci-lint-coverage.sh

## registry-test — the registry layer's own suites.
registry-test:
	python3 -m unittest discover -s scripts/tests -p 'test_*.py'
	./scripts/tests/test-ci-lint-coverage.sh
	./scripts/tests/test-parallel-merge.sh
	./scripts/tests/test-brownfield-adoption.sh
