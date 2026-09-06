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

KIT := starter-kit

.PHONY: lint test registry-generate registry-list registry-drift registry-ids \
        ci-lint-coverage kit-smoke

## lint — everything CI runs.
lint: registry-drift registry-ids ci-lint-coverage test

## test — unit tests plus the parallel-merge acceptance test.
test:
	python3 -m unittest discover -s $(KIT)/scripts/tests -p 'test_*.py'
	$(KIT)/scripts/tests/test-ci-lint-coverage.sh
	$(KIT)/scripts/tests/test-parallel-merge.sh
	$(KIT)/scripts/tests/test-brownfield-adoption.sh

## registry-generate — rebuild CHANGELOG.md from changelog.d/.
registry-generate:
	python3 $(KIT)/scripts/registry_tool.py generate

## registry-list — show the declared registries and their entry counts.
registry-list:
	python3 $(KIT)/scripts/registry_tool.py list

## registry-drift — the generated artifacts match their fragments.
registry-drift:
	$(KIT)/scripts/check-registry-drift.sh

## registry-ids — identifiers are well-shaped and unique.
registry-ids:
	$(KIT)/scripts/check-registry-ids.sh

## ci-lint-coverage — every sub-target above actually runs in CI.
ci-lint-coverage:
	$(KIT)/scripts/check-ci-lint-coverage.sh

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
