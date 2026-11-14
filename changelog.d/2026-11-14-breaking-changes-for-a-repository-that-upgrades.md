# Breaking changes for a repository that upgrades

## Added

- ADR-0008 says what makes a release of the kit MAJOR: a repository that passed `make lint` on the previous version and follows the upgrade steps fails it, or has to edit a file of its own. It also names what the kit treats as its public contract.

## Changed

- **Breaking — why this release is 2.0.0.** Moving an existing install to it needs changes to files of your own. A repository that stays on 1.x is not touched: the installer never overwrites a file. The changes marked Breaking below apply once you follow "Upgrading an existing install" in the kit README, and each one fails `make lint` with the file, the line and the fix.
- **Breaking:** a check script of yours whose header reads `# Enforces: <rule> — see <rule file>`, the form the 1.x template shipped, fails the new link gate. Name the rule as a token: `# Enforces: RULE:<name> — <what it checks>`.
- **Breaking:** a `Related:` line that names an artifact which does not exist passed every 1.x gate and now fails. Point it at the artifact's current name, or delete it.
- **Breaking:** if you keep your own Makefile, its `lint:` line must name `graph-links`. Until it does, `check-ci-lint-coverage.sh` fails and says so.
- Python 3.9 or newer is now a stated requirement, and `scripts/python.sh` checks it. Earlier versions named no minimum.
