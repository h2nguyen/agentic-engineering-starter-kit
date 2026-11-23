# Registry targets — include this from your Makefile.
#
#     include registry.mk
#     lint: registry-drift registry-ids kb-shape graph-links ci-lint-coverage <your targets>
#
# Shipped as a separate file so a repository that already has a Makefile can
# adopt the layer with one `include` line and one edit to its lint target,
# instead of merging targets by hand. Greenfield installs get the same file
# behind the kit's Makefile.template, so there is exactly one copy of these
# targets to maintain.
#
# If the umbrella lint target does not reach every one of those five gates,
# check-ci-lint-coverage.sh fails and names the one it misses — an installed
# gate that nothing runs is indistinguishable from no gate at all.

# Python is started through scripts/python.sh, which finds it under whatever
# name this machine gives it (python3, python, py -3). To choose one yourself:
#     make lint PYTHON=/path/to/python

.PHONY: registry-generate registry-list registry-drift registry-ids kb-shape \
        graph-links graph-impact graph-coverage ci-lint-coverage constitution \
        agent-feedback registry-test

## registry-generate — assemble every registry artifact from its fragments.
registry-generate:
	./scripts/python.sh scripts/registry_tool.py generate

## registry-list — show the declared registries and their entry counts.
registry-list:
	./scripts/python.sh scripts/registry_tool.py list

## registry-drift — the generated artifacts say what their fragments say.
registry-drift:
	./scripts/check-registry-drift.sh

## registry-ids — identifiers are well-shaped and unique.
registry-ids:
	./scripts/check-registry-ids.sh

## kb-shape — the assembled knowledge base parses as graph nodes.
kb-shape:
	./scripts/check-kb-shape.sh

## graph-links — every typed link names an artifact that exists.
graph-links:
	./scripts/check-graph-links.sh

## graph-impact — what cites NODE. Run it BEFORE renaming, deleting or
## rewriting a rule, skill, agent, command or script:
##     make graph-impact NODE=RULE:testing
graph-impact:
	@if [ -z "$(NODE)" ]; then \
	  echo "Usage: make graph-impact NODE=<KIND:name>   e.g. NODE=RULE:documentation, NODE=ADR-0002, NODE=HUMAN, or a file path" >&2; \
	  exit 2; \
	fi
	@./scripts/python.sh scripts/graph_tool.py impact $(NODE)

## graph-coverage — which rules a script enforces and an agent reviews.
## A report for audits and the health checklist, never a gate.
graph-coverage:
	@./scripts/python.sh scripts/graph_tool.py coverage

## ci-lint-coverage — every lint sub-target actually runs in CI, and the
## registry and link gates are actually reached by lint.
ci-lint-coverage:
	./scripts/check-ci-lint-coverage.sh

## constitution — the constitution links only to files that exist and has no
## template placeholder left. Run it after filling the constitution in, and
## after editing it. Not a prerequisite of lint as shipped; to hold it on every
## pull request, add `constitution` to your lint line.
constitution:
	./scripts/check-constitution.sh

## agent-feedback — every Agent-Feedback line in the commit history, grouped
## by the artifact it names, as JSON — from the authors .agent-feedback-authors
## lists only. Input for the next change to that artifact; a report, never a gate.
##     make agent-feedback SINCE=2026-11-01
##     make agent-feedback FROM=pr-comments.json   (a comment export, as JSON)
##     make agent-feedback FORMAT=markdown          (a digest a person reads)
agent-feedback:
	@./scripts/python.sh scripts/feedback_tool.py collect $(if $(SINCE),--since "$(SINCE)") $(if $(FROM),--from "$(FROM)") $(if $(FORMAT),--format "$(FORMAT)")

## registry-test — the registry layer's own suites. -B: the kit installs no
## .gitignore, so its tools must not leave a __pycache__ in your repository.
## -b: the suites exercise the gates' failure paths, and a passing run must
## not print their FAIL lines into a green `make lint`.
registry-test:
	./scripts/python.sh -B -m unittest discover -b -s scripts/tests -p 'test_*.py'
	./scripts/tests/test-ci-lint-coverage.sh
	./scripts/tests/test-constitution.sh
	./scripts/tests/test-parallel-merge.sh
	./scripts/tests/test-graph-links.sh
	./scripts/tests/test-python-launcher.sh
