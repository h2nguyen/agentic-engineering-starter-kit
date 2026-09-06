#!/usr/bin/env bash
# Agentic Engineering Starter Kit — initializer.
#
# Detects (or is told) which agentic coding tool the target repo uses and
# installs the kit's ready-to-use files to that tool's expected locations.
# Never overwrites an existing file; safe to re-run.
#
# Usage:
#   ./bootstrap.sh [--tool claude|agents|cursor|copilot] [--target <repo-root>] [--with-meta]
#
# Tool mapping (guide § 3.10 — conventions move fast; your tool's docs win):
#   claude  → CLAUDE.md, .claude/rules/ (3 default rules), .claude/settings.json, .claude/hooks/, .claude/skills/ (prompt-enhancer, semver)
#   agents  → AGENTS.md, docs/agent-rules/          (AGENTS.md-convention tools)
#   cursor  → AGENTS.md, docs/agent-rules/          (note printed re .cursor/rules/*.mdc)
#   copilot → .github/copilot-instructions.md, docs/agent-rules/
#   all     → docs/DEBUGGING-KNOWLEDGE-BASE.md + its fragment directory,
#             changelog.d/, CHANGELOG.md, registries.json (INFERRED from what the
#             repo already has), .gitattributes (appended to if present),
#             registry.mk + Makefile (kept if present), .github/workflows/lint.yml,
#             scripts/ (registry_tool.py, check-kb-shape.sh, check-registry-*.sh,
#             check-ci-lint-coverage.sh)
#   --with-meta (Level-4 opt-in, NOT part of a day-1 install): agent-coach
#             subagent + workspace-audit skill/command + workspace-changelog
#             skeleton (Claude Code; other tools get the changelog only)
#
# Placeholder templates (_rule-template, skills/_template, agent, command, and
# the check-convention template) are NOT installed — they stay in the kit.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(pwd)"
TOOL=""
WITH_META=0

while [ $# -gt 0 ]; do
  case "$1" in
    --tool)   TOOL="${2:?--tool needs a value}"; shift 2 ;;
    --target) TARGET="$(cd "${2:?--target needs a value}" && pwd)"; shift 2 ;;
    --with-meta) WITH_META=1; shift ;;
    -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
  esac
done

detect_tool() {
  if [ -d "$TARGET/.claude" ] || [ -f "$TARGET/CLAUDE.md" ]; then echo claude; return; fi
  if [ -d "$TARGET/.cursor" ] || [ -f "$TARGET/.cursorrules" ]; then echo cursor; return; fi
  if [ -f "$TARGET/.github/copilot-instructions.md" ]; then echo copilot; return; fi
  if [ -f "$TARGET/AGENTS.md" ]; then echo agents; return; fi
  echo ""
}

if [ -z "$TOOL" ]; then
  TOOL="$(detect_tool)"
  [ -n "$TOOL" ] && echo "Detected agentic tool: $TOOL"
fi
if [ -z "$TOOL" ]; then
  if [ -t 0 ]; then
    printf "No agentic tool detected in %s.\nWhich tool will this repo use? [claude/agents/cursor/copilot]: " "$TARGET"
    read -r TOOL
  else
    echo "ERROR: no agentic tool detected and no --tool given." >&2
    echo "Re-run with: ./bootstrap.sh --tool claude|agents|cursor|copilot" >&2
    exit 1
  fi
fi
case "$TOOL" in
  claude|agents|cursor|copilot) ;;
  *) echo "ERROR: unknown tool '$TOOL' (expected claude|agents|cursor|copilot)" >&2; exit 1 ;;
esac

INSTALLED=()
SKIPPED=()
MAKEFILE_KEPT=0

install_file() { # $1 = kit-relative src, $2 = target-relative dst, $3 = "x" for executable
  local src="$KIT_DIR/$1" dst="$TARGET/$2"
  if [ -e "$dst" ]; then
    SKIPPED+=("$2 (already exists — left untouched)")
    return 1
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  if [ "${3:-}" = "x" ]; then chmod +x "$dst"; fi
  INSTALLED+=("$2")
  return 0
}

retarget_rule_links() { # $1 = target-relative file: rewrite .claude/rules/ links for non-claude layouts
  local f="$TARGET/$1"
  [ -f "$f" ] || return 0
  sed -i.bak 's|\.claude/rules/|docs/agent-rules/|g' "$f" && rm -f "$f.bak"
}

install_dir() { # $1 = kit-relative src dir, $2 = target-relative dst dir
  local src="$KIT_DIR/$1" dst="$TARGET/$2"
  if [ -e "$dst" ]; then
    SKIPPED+=("$2 (already exists — left untouched)")
    return 1
  fi
  mkdir -p "$(dirname "$dst")"
  cp -r "$src" "$dst"
  INSTALLED+=("$2/")
  return 0
}

install_tree() { # $1 = kit-relative src dir, $2 = target-relative dst dir
  # Unlike install_dir, this merges into an existing directory instead of
  # skipping it: a repo may already have docs/ or scripts/, and the fragment
  # skeleton still needs to land inside. Individual files are never overwritten.
  local src="$KIT_DIR/$1" dst="$TARGET/$2" rel
  [ -d "$src" ] || return 0
  local any=1
  while IFS= read -r file; do
    rel="${file#"$src"/}"
    if [ -e "$dst/$rel" ]; then
      SKIPPED+=("$2/$rel (already exists — left untouched)")
    else
      mkdir -p "$(dirname "$dst/$rel")"
      cp "$file" "$dst/$rel"
      INSTALLED+=("$2/$rel")
      any=0
    fi
  done < <(find "$src" -type f ! -name '*.pyc' ! -path '*/__pycache__/*')
  return $any
}

case "$TOOL" in
  claude)
    install_file constitution.md.template CLAUDE.md || true
    install_file rules/working-principles.md .claude/rules/working-principles.md || true
    install_file rules/documentation.md .claude/rules/documentation.md || true
    install_file rules/versioning-and-changelog.md .claude/rules/versioning-and-changelog.md || true
    install_file skills/prompt-enhancer/SKILL.md .claude/skills/prompt-enhancer/SKILL.md || true
    install_dir skills/semver .claude/skills/semver || true
    install_file settings.json.template .claude/settings.json || true
    install_file hooks/session-start.sh.template .claude/hooks/session-start.sh x || true
    ;;
  agents|cursor)
    if install_file constitution.md.template AGENTS.md; then retarget_rule_links AGENTS.md; fi
    install_file rules/working-principles.md docs/agent-rules/working-principles.md || true
    install_file rules/documentation.md docs/agent-rules/documentation.md || true
    install_file rules/versioning-and-changelog.md docs/agent-rules/versioning-and-changelog.md || true
    ;;
  copilot)
    if install_file constitution.md.template .github/copilot-instructions.md; then
      retarget_rule_links .github/copilot-instructions.md
    fi
    install_file rules/working-principles.md docs/agent-rules/working-principles.md || true
    install_file rules/documentation.md docs/agent-rules/documentation.md || true
    install_file rules/versioning-and-changelog.md docs/agent-rules/versioning-and-changelog.md || true
    ;;
esac
# --- shared append-only registries -----------------------------------------
# Tool-independent: this layer is git configuration, a generator and CI checks.
# It installs for every tool, and it is the reason a repo scaffolded from this
# kit can have two branches add registry entries and merge both cleanly from
# commit one, rather than discovering the problem once the registries are large
# and already cited.
install_file docs/DEBUGGING-KNOWLEDGE-BASE.md docs/DEBUGGING-KNOWLEDGE-BASE.md || true
install_tree docs/DEBUGGING-KNOWLEDGE-BASE.d docs/DEBUGGING-KNOWLEDGE-BASE.d || true
install_tree changelog.d changelog.d || true
install_file CHANGELOG.md.template CHANGELOG.md || true
install_file registry-id-duplicate-allowlist.template .registry-id-duplicate-allowlist || true
install_file ci-lint-coverage-allowlist.template .ci-lint-coverage-allowlist || true
install_file registry.mk registry.mk || true
install_file ci/lint.yml.template .github/workflows/lint.yml || true
install_file scripts/registry_tool.py scripts/registry_tool.py x || true

# Makefile: only install the template where none exists. An existing Makefile
# is never edited — but the registry targets ship in registry.mk precisely so
# that adopting them is one `include` line, and the coverage gate fails loudly
# until the umbrella target actually reaches them.
if ! install_file Makefile.template Makefile; then
  MAKEFILE_KEPT=1
fi

# .gitattributes is additive: later lines win for the same path, so appending
# the kit's block to an existing file is safe, and a marker keeps it idempotent.
if [ -f "$TARGET/.gitattributes" ]; then
  if ! grep -q '>>> starter-kit registries >>>' "$TARGET/.gitattributes"; then
    {
      printf '\n# >>> starter-kit registries >>>\n'
      grep -vE '^#|^$' "$KIT_DIR/gitattributes.template"
      printf '# <<< starter-kit registries <<<\n'
    } >> "$TARGET/.gitattributes"
    INSTALLED+=(".gitattributes (registry block appended to your existing file)")
  else
    SKIPPED+=(".gitattributes (registry block already present)")
  fi
else
  install_file gitattributes.template .gitattributes || true
fi

# registries.json is WRITTEN FROM WHAT EXISTS, not copied from a template. On a
# brownfield repository that means an adr-tools directory of 0001-title.md
# files is declared as numeric/width 4/no prefix, and a knowledge base full of
# ISSUE-042 entries keeps its identifiers frozen — instead of the identifier
# gate rejecting every existing record on day one.
if [ -e "$TARGET/registries.json" ]; then
  SKIPPED+=("registries.json (already exists — left untouched)")
else
  ( cd "$TARGET" && python3 scripts/registry_tool.py init ) | sed 's/^/  init: /'
  INSTALLED+=("registries.json (inferred from the repository's existing conventions)")
fi
install_file scripts/check-kb-shape.sh scripts/check-kb-shape.sh x || true
install_file scripts/check-registry-drift.sh scripts/check-registry-drift.sh x || true
install_file scripts/check-registry-ids.sh scripts/check-registry-ids.sh x || true
install_file scripts/check-ci-lint-coverage.sh scripts/check-ci-lint-coverage.sh x || true
install_tree scripts/tests scripts/tests || true

# The changelog rule is only correct once the registry layer is present, so it
# ships alongside it rather than with the tool-specific rule files above.
case "$TOOL" in
  claude) install_file rules/shared-registries.md .claude/rules/shared-registries.md || true ;;
  *)      install_file rules/shared-registries.md docs/agent-rules/shared-registries.md || true ;;
esac
if [ "$TOOL" = "claude" ]; then
  install_file skills/registry-entry/SKILL.md .claude/skills/registry-entry/SKILL.md || true
  install_file skills/registry-conflict-triage/SKILL.md .claude/skills/registry-conflict-triage/SKILL.md || true
fi

# One fragment per change lives directly in changelog.d/, so there are no
# category directories to pre-create — the categories are headings inside each
# file, and the tool creates the directory itself on first use.
[ -d "$TARGET/changelog.d" ] || mkdir -p "$TARGET/changelog.d"

if [ "$WITH_META" -eq 1 ]; then
  case "$TOOL" in
    claude)
      install_file agents/agent-coach.md .claude/agents/agent-coach.md || true
      install_dir skills/ai-engineering-workspace-audit .claude/skills/ai-engineering-workspace-audit || true
      install_file commands/ai-engineering-workspace-audit.md .claude/commands/ai-engineering-workspace-audit.md || true
      install_file WORKSPACE_CHANGELOG.md.template .claude/WORKSPACE_CHANGELOG.md || true
      ;;
    *)
      install_file WORKSPACE_CHANGELOG.md.template docs/WORKSPACE_CHANGELOG.md || true
      ;;
  esac
fi

echo ""
echo "=== bootstrap: $TOOL → $TARGET ==="
if [ ${#INSTALLED[@]} -gt 0 ]; then
  echo "Installed:"; printf '  + %s\n' "${INSTALLED[@]}"
fi
if [ ${#SKIPPED[@]} -gt 0 ]; then
  echo "Skipped:"; printf '  = %s\n' "${SKIPPED[@]}"
fi
echo ""
echo "Next steps:"
echo "  1. Fill in the constitution's <placeholders> (find them: grep -n '<' <constitution-file>)."
echo "  2. Enable common generic skills — see $(basename "$KIT_DIR")/skills/common-catalog.md."
echo "  3. Run 'make lint' — the registry gates, the knowledge-base shape check and"
echo "     the CI-coverage check are already chained into it, and the installed"
echo "     workflow invokes that same target so nothing can fall out of CI."
echo "     Merge the targets into your existing Makefile if you had one."
if [ "$MAKEFILE_KEPT" -eq 1 ]; then
  echo "     Your existing Makefile was left untouched. Chain the registry gates in"
  echo "     with two lines (registry.mk was installed next to it):"
  echo "         include registry.mk"
  echo "         lint: registry-drift registry-ids kb-shape ci-lint-coverage <your existing prerequisites>"
  if make -n -C "$TARGET" lint 2>/dev/null | grep -q check-registry-drift.sh; then
    echo "     (verified: 'make lint' already reaches the registry gates)"
  else
    echo "     Until then 'make lint' is green and checks nothing of the registry layer;"
    echo "     check-ci-lint-coverage.sh reports exactly that once it is chained in."
  fi
fi
for _kept in CHANGELOG.md docs/DEBUGGING-KNOWLEDGE-BASE.md; do
  if printf '%s\n' "${SKIPPED[@]}" | grep -q "^$_kept "; then
    _reg=changelog; [ "$_kept" = docs/DEBUGGING-KNOWLEDGE-BASE.md ] && _reg=debugging-kb
    echo "     Your existing $_kept was left untouched. Bring it into the layout with"
    echo "         python3 scripts/registry_tool.py adopt --registry $_reg"
    echo "     — it moves the current entries into fragments losslessly, keeps every"
    echo "     identifier, and installs the generated region. The drift gate fails until then."
  fi
done
echo "  4. Grow by signal: the placeholder templates (rules/_rule-template.md,"
echo "     skills/_template/, agents/, commands/) stay in the kit for later."
case "$TOOL" in
  cursor)
    echo "  Note (cursor): rules were installed to docs/agent-rules/ and linked from AGENTS.md."
    echo "  Cursor also supports scoped project rules in .cursor/rules/*.mdc — migrate there"
    echo "  if you want per-path triggers (frontmatter required; see Cursor's docs)."
    ;;
  agents|copilot)
    echo "  Note ($TOOL): native skills/subagents/hooks have no direct equivalent — the"
    echo "  concepts still apply as playbook docs and CI checks (guide § 3.10)."
    ;;
esac
if [ "$WITH_META" -eq 1 ] && [ "$TOOL" != "claude" ]; then
  echo "  Note ($TOOL): the meta subagent/skill are agent-tool-native — convert them to"
  echo "  playbook docs per guide § 3.10; only the workspace-changelog skeleton was installed."
fi
if [ "$WITH_META" -eq 0 ]; then
  echo "  Level-4 meta artifacts (agent-coach, workspace-audit, workspace changelog) ship"
  echo "  in the kit but are NOT day-1 defaults — install them later with --with-meta"
  echo "  once the workspace has real mass (guide § 4.1 / § 5.2 / § 5.3)."
fi
