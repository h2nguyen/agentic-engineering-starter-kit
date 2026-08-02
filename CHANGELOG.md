# Changelog

All notable changes to this project are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) — the same
conventions this kit ships as a default rule.

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [0.1.0] — 2026-08-02

### Added

- Initial import: the agentic engineering guide (concepts, reference anatomy,
  generic blueprint, adoption playbook, maintenance flywheel, graph-engineering
  outlook).
- Starter kit with three entry points: `SETUP-PROMPT.md` (agent-driven, incl.
  the harmonize track for repos that already have agent configuration),
  `bootstrap.sh` (tool-detecting installer, `--with-meta` for the Level-4
  loop), and manual copy.
- Day-1 rule defaults: working principles (incl. plan-first/QRSPI),
  documentation, versioning & changelog.
- Shipped skills: prompt-enhancer, semver (vendored from
  https://github.com/h2nguyen/semver-skill, with validator and test suite).
- Level-4 meta layer behind `--with-meta`: workspace-audit skill + command,
  agent-coach meta-agent, workspace-changelog skeleton.
- Graph-ready debugging knowledge base plus `check-kb-shape.sh`, a runnable
  lint check for entry shape and typed cross-links.
- Templates for constitution, rules, skills, agents, commands, enforcement
  scripts, session hook, and tool settings.
- ADR-001 recording why this repository is canonical and an agent plugin is a
  future distribution channel.
