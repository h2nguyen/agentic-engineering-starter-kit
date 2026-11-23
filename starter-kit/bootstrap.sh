#!/usr/bin/env bash
# Agentic Engineering Starter Kit — initializer.
#
# Detects (or is told) which agentic coding tool the target repo uses and
# installs the kit's ready-to-use files to that tool's expected locations.
# Never overwrites an existing file; safe to re-run.
#
# Which tool: --tool if given; else the one tool whose files the target has;
# else it asks. A target with the files of several tools is asked about too —
# and with no terminal to ask at, the run fails before it writes anything.
#
# Usage:
#   ./bootstrap.sh [--tool claude|agents|cursor|copilot] [--target <repo-root>] [--with-meta]
#                  [--source-paths <glob>[,<glob>...]]
#                  [--with-coach-schedule] [--with-upgrade-notice]
#
# Tool mapping (guide § 3.10 — conventions move fast; your tool's docs win):
#   claude  → CLAUDE.md, .claude/rules/ (DEFAULT_RULES + shared-registries), .claude/settings.json, .claude/hooks/ (workspace-graph), .claude/skills/ (prompt-enhancer, semver, rule-load-check)
#   agents  → AGENTS.md, docs/agent-rules/          (AGENTS.md-convention tools)
#   cursor  → AGENTS.md, docs/agent-rules/          (note printed re .cursor/rules/*.mdc)
#   copilot → .github/copilot-instructions.md, docs/agent-rules/
#   all     → docs/DEBUGGING-KNOWLEDGE-BASE.md + its fragment directory,
#             changelog.d/, CHANGELOG.md, registries.json (INFERRED from what the
#             repo already has), .gitattributes (appended to if present),
#             registry.mk + Makefile (kept if present), .github/workflows/lint.yml,
#             scripts/ (python.sh, registry_tool.py, graph_tool.py, check-kb-shape.sh,
#             check-registry-*.sh, check-graph-links.sh, check-ci-lint-coverage.sh,
#             check-constitution.sh, feedback_tool.py), .agent-feedback-authors,
#             .starter-kit-version (first install only: the kit's release, its
#             commit and the tool — kit-status.sh reads it and checks it)
#   --with-meta (Level-4 opt-in, NOT part of a day-1 install): agent-coach
#             subagent + workspace-audit skill/command + workspace-graph skill
#             + workspace-changelog directory (Claude Code; others: that directory only)
#   --with-coach-schedule (opt-in, any tool): .github/workflows/agent-feedback.yml,
#             a weekly digest of the Agent-Feedback lines on an issue, plus the
#             coach's proposals there when an ANTHROPIC_API_KEY secret is set.
#             Asked at a terminal on a first install; never installed unasked.
#   --with-upgrade-notice (opt-in, any tool): .github/workflows/kit-upgrade-notice.yml,
#             which once a week lists the kit's release tags over the network and
#             opens an issue when one is newer than .starter-kit-version records.
#             Asked at a terminal on a first install; never installed unasked.
#
# Placeholder templates (rule, check script, skill, reviewer agent, command,
# SessionStart hook) install to docs/agent-templates/ — unloaded, and where a
# later session finds them.
#
# Load classes (Claude Code): a rule with a `paths:` header is loaded when a
# matching file is read or edited, any other rule into every session. The
# installer binds shared-registries to the registry files registries.json
# declares. --source-paths 'src/**,scripts/**' also binds
# comments-and-annotations and versioning-and-changelog, to those globs and to
# the kit files each is about; without it both load into every session — where
# a project's source is, is not something to guess. One glob per comma; write
# brace alternatives out. Only rules this run installs get a header.
#
# Declining something: list its path in <repo-root>/.starter-kit-declined, one
# per line, relative to the repository root, `# reason` after it. A listed file
# is not installed, and a listed directory covers everything beneath it — on
# the first run and on every later one. Without the list a re-run puts back
# whatever is missing, because it cannot tell "deleted on purpose" from "new".
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(pwd)"
TOOL=""
WITH_META=0
WITH_SCHEDULE=0
WITH_NOTICE=0
TARGET_GIVEN=0
SOURCE_PATHS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --tool)   TOOL="${2:?--tool needs a value}"; shift 2 ;;
    --target) TARGET="$(cd "${2:?--target needs a value}" && pwd)"; TARGET_GIVEN=1; shift 2 ;;
    --with-meta) WITH_META=1; shift ;;
    --with-coach-schedule) WITH_SCHEDULE=1; shift ;;
    --with-upgrade-notice) WITH_NOTICE=1; shift ;;
    --source-paths) SOURCE_PATHS="${2:?--source-paths needs a value, e.g. 'src/**,scripts/**'}"; shift 2 ;;
    -h|--help) sed -n '2,/^set -euo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
  esac
done

# With no --target the installer installs into the current directory, which
# is right when a project holds a copy of starter-kit/. It is wrong in the
# kit's own repository: that one carries the guide beside starter-kit/, and
# agent instructions of its own, so detection would succeed and the kit would
# be installed into itself.
if [ "$TARGET_GIVEN" -eq 0 ] && [ -f "$TARGET/AGENTIC-ENGINEERING-GUIDE.md" ] \
   && [ "$(cd "$TARGET" && pwd -P)" = "$(cd "$KIT_DIR/.." && pwd -P)" ]; then
  echo "ERROR: this is the starter kit's own repository, not a project to install into." >&2
  echo "Name the repository the kit should be installed into:" >&2
  echo "    $0 --target /path/to/your-repo" >&2
  exit 1
fi

# Every tool whose files the target already has: one line each, the tool's
# name and then what gave it away. Not the first match — a repository can
# carry the files of several tools, and which one the kit installs for is the
# adopter's decision, not the order of these lines.
detect_tools() {
  local found
  found=""
  [ -d "$TARGET/.claude" ] && found="$found .claude/"
  [ -f "$TARGET/CLAUDE.md" ] && found="$found CLAUDE.md"
  [ -n "$found" ] && echo "claude $found"
  found=""
  [ -d "$TARGET/.cursor" ] && found="$found .cursor/"
  [ -f "$TARGET/.cursorrules" ] && found="$found .cursorrules"
  [ -n "$found" ] && echo "cursor $found"
  # Cursor's layout keeps its constitution in AGENTS.md, so beside Cursor's
  # own files that file is Cursor's, not a second tool. This is also what
  # lets a re-run on a Cursor install detect Cursor again.
  if [ -z "$found" ] && [ -f "$TARGET/AGENTS.md" ]; then echo "agents  AGENTS.md"; fi
  [ -f "$TARGET/.github/copilot-instructions.md" ] && echo "copilot  .github/copilot-instructions.md"
  return 0
}

# Decided before anything is written: --tool, else the one tool detected, else
# a question. Several detected tools are a question too, and with nobody at a
# terminal to answer it the run ends here, with the repository as it was.
if [ -z "$TOOL" ]; then
  DETECTED="$(detect_tools)"
  CANDIDATES="$(printf '%s\n' "$DETECTED" | sed '/^$/d' | sed 's/ .*//' | tr '\n' '|' | sed 's/|$//')"
  case "$CANDIDATES" in
    "")
      if [ -t 0 ]; then
        printf "No agentic tool detected in %s.\nWhich tool will this repo use? [claude/agents/cursor/copilot]: " "$TARGET"
        read -r TOOL
      else
        echo "ERROR: no agentic tool detected and no --tool given." >&2
        echo "Re-run with: ./bootstrap.sh --tool claude|agents|cursor|copilot" >&2
        exit 1
      fi
      ;;
    *"|"*)
      if [ -t 0 ]; then
        printf "More than one agentic tool is set up in %s:\n" "$TARGET"
        printf '%s\n' "$DETECTED" | sed 's/^\([a-z]*\) *\(.*\)$/  \1 (\2)/'
        printf "Which one is primary — the one to install for? [%s]: " "$(printf '%s' "$CANDIDATES" | tr '|' '/')"
        read -r TOOL
      else
        {
          echo "ERROR: more than one agentic tool is set up in $TARGET, and no --tool was given:"
          printf '%s\n' "$DETECTED" | sed 's/^\([a-z]*\) *\(.*\)$/  \1 (\2)/'
          echo "The installer does not pick one for you. Name the primary tool; nothing was written:"
          echo "    $0 --tool $CANDIDATES --target $TARGET"
        } >&2
        exit 1
      fi
      ;;
    *)
      TOOL="$CANDIDATES"
      echo "Detected agentic tool: $TOOL"
      ;;
  esac
fi
case "$TOOL" in
  claude|agents|cursor|copilot) ;;
  *) echo "ERROR: unknown tool '$TOOL' (expected claude|agents|cursor|copilot)" >&2; exit 1 ;;
esac

# The globs go into a YAML header between double quotes. One that cannot be
# written there is refused here, before anything is installed: a header Claude
# Code cannot parse is ignored without a word, and the rule then loads into
# every session as if it had none. Only where the flag means something: on the
# other tools it is reported as ignored, and must not stop the install.
SOURCE_GLOBS=()
if [ -n "$SOURCE_PATHS" ] && [ "$TOOL" = claude ]; then
  refuse_glob() { # $1 = the glob, $2 = what is wrong with it
    echo "ERROR: --source-paths: '$1' $2" >&2
    echo "Give globs relative to the repository root, without quotes, backslashes or line" >&2
    echo "breaks, one per comma — a brace alternative such as src/**/*.{ts,tsx} written out as" >&2
    echo "two globs, a directory as src/**. Nothing was written." >&2
    exit 1
  }
  _rest="$SOURCE_PATHS,"
  while [ -n "$_rest" ]; do
    _glob="${_rest%%,*}"; _rest="${_rest#*,}"
    case "$_glob" in *$'\n'*|*$'\r'*) refuse_glob "$(printf '%s' "$_glob" | tr '\n\r' '  ')" "has a line break in it." ;; esac
    _glob="$(printf '%s' "$_glob" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s|^\./||')"
    [ -n "$_glob" ] || continue
    case "$_glob" in
      *'"'*|*'\'*|*'{'*|*'}'*|/*) refuse_glob "$_glob" "cannot go into a paths: header as it is." ;;
    esac
    # A bare directory name matches no file: the header would be valid and the
    # rule would never arrive, which nothing reports.
    if [ -d "$TARGET/$_glob" ]; then
      refuse_glob "$_glob" "names a directory, which matches no file. Write '${_glob%/}/**'."
    fi
    SOURCE_GLOBS+=("$_glob")
  done
fi

INSTALLED=()
SKIPPED=()
MAKEFILE_KEPT=0

# What the adopter declined. The installer adds whatever is missing, so a file
# deleted on purpose — a skill the organisation already ships, a suite the
# project does not run — would come back with every upgrade: nothing in the
# files says "deleted" apart from "not there yet". The list is the adopter's,
# states an intent and not a state, and is never written by the installer.
DECLINE_LIST=.starter-kit-declined
DECLINED=()
if [ -f "$TARGET/$DECLINE_LIST" ]; then
  while IFS= read -r _line || [ -n "$_line" ]; do
    _line="$(printf '%s' "${_line%%#*}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s|^\./||; s|/*$||')"
    if [ -n "$_line" ]; then DECLINED+=("$_line"); fi
  done < "$TARGET/$DECLINE_LIST"
fi
declined() { # $1 = target-relative path: is it listed, or inside a listed directory?
  local d
  # Guard on the count: bash 3.2 under `set -u` rejects an empty array.
  [ ${#DECLINED[@]} -gt 0 ] || return 1
  for d in "${DECLINED[@]}"; do
    case "$1" in "$d"|"$d"/*) return 0 ;; esac
  done
  return 1
}

# The weekly digest runs with nobody watching and posts to the issue tracker,
# so it is installed only when the adopter chooses it: the flag, or yes to this
# question. Asked at a terminal, on a first install, when the workflow is not
# already there and not declined; run from an agent there is nobody to ask, and
# it stays out unless the flag says otherwise.
SCHEDULE_WORKFLOW=.github/workflows/agent-feedback.yml
if [ "$WITH_SCHEDULE" -eq 0 ] && [ -t 0 ] && [ ! -e "$TARGET/$SCHEDULE_WORKFLOW" ] \
   && [ ! -f "$TARGET/scripts/registry_tool.py" ] && ! declined "$SCHEDULE_WORKFLOW"; then
  printf "Install a weekly agent-feedback digest (%s)? It posts the week's\nAgent-Feedback lines to an issue; with an ANTHROPIC_API_KEY secret it adds the coach's\nproposals. It never changes the repository. [y/N]: " "$SCHEDULE_WORKFLOW"
  read -r _answer || _answer=""
  case "$_answer" in y|Y|yes|YES|Yes|j|J|ja|Ja) WITH_SCHEDULE=1 ;; esac
fi

# The upgrade notice is the one thing here that uses the network: a scheduled
# workflow that lists the kit's release tags and opens an issue when one is
# newer than the record. The kit itself stays offline, so this is installed on
# the same terms as the digest: the flag, or yes to a question at a terminal.
NOTICE_WORKFLOW=.github/workflows/kit-upgrade-notice.yml
if [ "$WITH_NOTICE" -eq 0 ] && [ -t 0 ] && [ ! -e "$TARGET/$NOTICE_WORKFLOW" ] \
   && [ ! -f "$TARGET/scripts/registry_tool.py" ] && ! declined "$NOTICE_WORKFLOW"; then
  printf "Install a weekly check for a newer kit (%s)? It lists the kit's release\ntags over the network and opens an issue when one is newer than this install records.\nIt never changes the repository. [y/N]: " "$NOTICE_WORKFLOW"
  read -r _answer || _answer=""
  case "$_answer" in y|Y|yes|YES|Yes|j|J|ja|Ja) WITH_NOTICE=1 ;; esac
fi

install_file() { # $1 = kit-relative src, $2 = target-relative dst, $3 = "x" for executable
  local src="$KIT_DIR/$1" dst="$TARGET/$2"
  if [ -e "$dst" ]; then
    SKIPPED+=("$2 (already exists — left untouched)")
    return 1
  fi
  if declined "$2"; then
    SKIPPED+=("$2 (declined in $DECLINE_LIST)")
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
  if declined "$2"; then
    SKIPPED+=("$2/ (declined in $DECLINE_LIST)")
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
    elif declined "$2/$rel"; then
      SKIPPED+=("$2/$rel (declined in $DECLINE_LIST)")
    else
      mkdir -p "$(dirname "$dst/$rel")"
      cp "$file" "$dst/$rel"
      INSTALLED+=("$2/$rel")
      any=0
    fi
  # The suites that test this installer stay in the kit: a repository it
  # installs into has no bootstrap.sh for them to run.
  done < <(find "$src" -type f ! -name '*.pyc' ! -path '*/__pycache__/*' \
             ! -name 'test-bootstrap-rerun.sh' ! -name 'test-brownfield-adoption.sh' \
             ! -name 'test-upgrade.sh' ! -name 'test-graph-hooks.sh' \
             ! -name 'test-kit-status.sh')
  return $any
}

# One decision per tool — where the constitution goes and where rule files
# go — then one install line per rule. A new default rule is one entry in
# DEFAULT_RULES rather than one edit per tool arm; test-bootstrap-rerun.sh
# checks that every shipped rule lands for every tool.
case "$TOOL" in
  claude)        CONSTITUTION=CLAUDE.md;                       RULES_DIR=.claude/rules ;;
  agents|cursor) CONSTITUTION=AGENTS.md;                       RULES_DIR=docs/agent-rules ;;
  copilot)       CONSTITUTION=.github/copilot-instructions.md; RULES_DIR=docs/agent-rules ;;
esac
DEFAULT_RULES=(working-principles documentation comments-and-annotations versioning-and-changelog)
# The registry tool is the kit's own file and nothing else's, so finding it
# already here is what tells a re-run from a first install. An existing
# constitution does not: a repository can have one and never have seen the kit.
HAD_KIT=0
if [ -e "$TARGET/scripts/registry_tool.py" ]; then HAD_KIT=1; fi

# The constitution links its rules as .claude/rules/…; every other layout keeps
# them under docs/agent-rules/, so the links are rewritten on those tools.
if install_file constitution.md.template "$CONSTITUTION" && [ "$TOOL" != claude ]; then
  retarget_rule_links "$CONSTITUTION"
fi
# Was the comments rule here before this run? That, not the kit having been
# installed, is what decides about its project half below: the rule can be
# new to a repository that has had the kit for years, or has it in another
# tool's layout.
HAD_COMMENTS_RULE=0
if [ -e "$TARGET/$RULES_DIR/comments-and-annotations.md" ]; then HAD_COMMENTS_RULE=1; fi
# Which rules this run put in place. Only those may get a `paths:` header
# further down: a rule that was already here is the adopter's file.
RULES_NOW=" "
for rule in "${DEFAULT_RULES[@]}"; do
  if install_file "rules/$rule.md" "$RULES_DIR/$rule.md"; then RULES_NOW="$RULES_NOW$rule "; fi
done
installed_now() { case "$RULES_NOW" in *" $1 "*) return 0 ;; esac; return 1; }
# The project's half of the comments rule: what its pointers stand for here,
# and the markers this project's own tooling reads. A file of the project's,
# so that the rule itself stays the kit's and an upgrade can copy it. It is
# installed together with the rule that names it. Where the rule was already
# here, it is held back: that rule may have the adopter's rows inside it, and
# an unfilled template beside them would be loaded into every session and
# fail a `constitution` check the adopter chained into lint. The upgrade
# steps create the file there, as part of moving the rows.
if [ "$HAD_COMMENTS_RULE" -eq 1 ] && [ ! -e "$TARGET/$RULES_DIR/project-annotations.md" ] \
   && ! declined "$RULES_DIR/project-annotations.md"; then
  SKIPPED+=("$RULES_DIR/project-annotations.md (not added beside a comments rule that was already here — 'Upgrading an existing install', step 3, creates it)")
else
  install_file rules/project-annotations.md.template "$RULES_DIR/project-annotations.md" || true
fi
# A rule file is loaded into every session, so the two long ones keep only
# their imperative there and point at these for the worked examples and the
# gotcha write-ups. One location for every tool, outside the rules directory:
# read when the pointer is followed, never loaded by default.
install_tree rules/reference docs/rule-reference || true
if [ "$TOOL" = claude ]; then
  install_file skills/prompt-enhancer/SKILL.md .claude/skills/prompt-enhancer/SKILL.md || true
  install_dir skills/semver .claude/skills/semver || true
  install_file settings.json.template .claude/settings.json || true
  # What actually loads is decided by Claude Code, not by this script: a header
  # it cannot parse is ignored in silence, and a session already running keeps
  # the rules it started with. The check is a skill because it has to run
  # inside a new session, and it ships on day 1 because nothing else would
  # ever report either of those.
  install_file skills/rule-load-check/SKILL.md .claude/skills/rule-load-check/SKILL.md || true
  # The typed links, handed to the agent instead of looked up by it: who cites
  # the file it just edited, and — once — a link that broke before the turn
  # ends. Claude Code only; it is that tool's hook protocol. settings.json
  # registers it, and a settings.json that was already here is never edited,
  # so the closing message says which entries to add.
  install_file hooks/workspace-graph.py .claude/hooks/workspace-graph.py x || true
fi
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
if [ "$WITH_SCHEDULE" -eq 1 ]; then
  install_file ci/agent-feedback.yml.template "$SCHEDULE_WORKFLOW" || true
fi
if [ "$WITH_NOTICE" -eq 1 ]; then
  install_file ci/kit-upgrade-notice.yml.template "$NOTICE_WORKFLOW" || true
fi
RERUN="$HAD_KIT"
install_file scripts/registry_tool.py scripts/registry_tool.py x || true
# Everything the kit runs starts Python through this launcher, never by a
# fixed name: `python3` is not Python on every machine (Windows has `python`
# and `py`, and a Store alias called python3 that is neither).
install_file scripts/python.sh scripts/python.sh x || true

# Makefile: only install the template where none exists. An existing Makefile
# is never edited — but the registry targets ship in registry.mk precisely so
# that adopting them is one `include` line, and the coverage gate fails loudly
# until the umbrella target actually reaches them.
if ! install_file Makefile.template Makefile; then
  MAKEFILE_KEPT=1
fi

# .gitattributes is additive: later lines win for the same path, so appending
# the kit's block to an existing file is safe, and a marker keeps it idempotent.
# The template carries the same marker, so a fresh install is recognised on a
# re-run too.
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
elif [ ! -f "$TARGET/scripts/registry_tool.py" ]; then
  SKIPPED+=("registries.json (scripts/registry_tool.py, which writes it, is not installed)")
else
  ( cd "$TARGET" && "$KIT_DIR/scripts/python.sh" scripts/registry_tool.py init ) | sed 's/^/  init: /'
  INSTALLED+=("registries.json (inferred from the repository's existing conventions)")
fi
install_file scripts/check-kb-shape.sh scripts/check-kb-shape.sh x || true
install_file scripts/check-registry-drift.sh scripts/check-registry-drift.sh x || true
install_file scripts/check-registry-ids.sh scripts/check-registry-ids.sh x || true
install_file scripts/check-ci-lint-coverage.sh scripts/check-ci-lint-coverage.sh x || true
# The link gate and its tool. Tool-independent like the registry gates: a typed
# link is a line of text, and resolving it needs only the files on disk. It
# ships on day one for the reason the registries do — every link written while
# nothing resolves it is a citation nobody will know has gone stale.
install_file scripts/graph_tool.py scripts/graph_tool.py x || true
install_file scripts/check-graph-links.sh scripts/check-graph-links.sh x || true
# The constitution's own check: its links name files that exist, and no
# template placeholder is left in it. A command the next steps name
# (`make constitution`), not a prerequisite of `lint`: it would fail a
# constitution that passed before, and that is the adopter's call to make.
install_file scripts/check-constitution.sh scripts/check-constitution.sh x || true
# Feedback to an agent, written where the work is reviewed and naming the
# artifact by its token, and the collector that groups it for the next change
# to that artifact. Day 1, every tool: a correction nobody wrote down cannot
# be recovered later, so waiting for the signal means never seeing it. The
# authors list ships naming nobody — the adopter says whose feedback counts.
install_file scripts/feedback_tool.py scripts/feedback_tool.py x || true
install_file agent-feedback-authors.template .agent-feedback-authors || true
install_tree scripts/tests scripts/tests || true

# The templates a workspace grows from. They used to stay in the kit, and a
# later session never sees the kit: its first rule, check script, skill or
# reviewer was rebuilt from memory, each time without some required part — the
# litmus test, the incident link, the reviewer's cross-cutting checks. They go
# to one directory every tool layout has in common. Not the rules directory:
# on Claude Code everything in it is loaded into every session. And every name
# begins with an underscore or ends in .template, which is what tells the link
# gate these are scaffolding and their <placeholders> are not citations.
#
# The templates name rule files as .claude/rules/…, so on the other layouts
# the path is rewritten — in the run that installs the file and in no other.
# On a re-run the template is the adopter's, and a file the installer skipped
# is a file it does not modify.
install_template() { # $1 = kit-relative src, $2 = name under docs/agent-templates/
  if install_file "$1" "docs/agent-templates/$2" && [ "$TOOL" != claude ]; then
    retarget_rule_links "docs/agent-templates/$2"
  fi
  return 0
}
install_template rules/_rule-template.md _rule-template.md
install_template scripts/check-convention.sh.template check-convention.sh.template
install_template skills/_template/SKILL.md _skill-template.md
install_template agents/_agent-template.md _agent-template.md
if [ "$TOOL" = claude ]; then
  install_template commands/_command-template.md _command-template.md
  # The SessionStart skeleton is a template too. Installed and registered, it
  # ran in every session, checked nothing and printed "toolchain ready" into
  # the session's context. A project copies it when sessions need environment
  # setup (guide § 4.3); its header carries the settings.json entry to add.
  install_template hooks/session-start.sh.template session-start.sh.template
fi

# The changelog rule is only correct once the registry layer is present, so it
# ships alongside it rather than with the default rules above.
if install_file rules/shared-registries.md "$RULES_DIR/shared-registries.md"; then RULES_NOW="${RULES_NOW}shared-registries "; fi

# --- load classes (Claude Code) --------------------------------------------
# Claude Code loads a rule with a `paths:` header when a matching file is read
# or edited, and a rule without one into every session. Three of the five
# rules are about particular files, and loading them everywhere cost every
# session several hundred lines it had no use for. The header is written here
# and not into the kit's rule files: those are one text for four tools, the
# registry paths differ per repository, and the source paths are the adopter's
# to name. The constitution keeps a one-line form of every rule, which is what
# holds before a bound rule has arrived.
registry_paths() { # $1 = all | changelog: the fragment directories and artifacts registries.json declares
  [ -f "$TARGET/registries.json" ] || return 0
  "$KIT_DIR/scripts/python.sh" -B - "$TARGET/registries.json" "$1" <<'PY' || true
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        cfg = json.load(fh)
except (OSError, ValueError):
    sys.exit(0)
registries = cfg.get("registries") if isinstance(cfg, dict) else None
for registry in registries if isinstance(registries, list) else []:
    if not isinstance(registry, dict):
        continue
    if sys.argv[2] == "changelog" and registry.get("kind") != "changelog":
        continue
    for key, suffix in (("fragments", "/**"), ("output", "")):
        value = str(registry.get(key) or "").strip("/")
        # The same refusals as for --source-paths, silently: a path that
        # cannot be written into the header is left out of it.
        if value and not any(c in value for c in '"\\{}\n\r'):
            print(value + suffix)
PY
}
bind_rule() { # $1 = rule name, then its globs: write the header onto a rule this run installed
  # Seen globs are kept one per line: a glob may contain a space, and joined
  # by spaces "dir/**" would be found inside "src/my dir/**".
  local rule="$1" f="$TARGET/$RULES_DIR/$1.md" seen=$'\n' glob; shift
  {
    echo "---"; echo "paths:"
    for glob in "$@"; do
      case "$seen" in *$'\n'"$glob"$'\n'*) continue ;; esac
      seen="$seen$glob"$'\n'
      printf '  - "%s"\n' "$glob"
    done
    echo "---"; echo ""; cat "$f"
  } > "$f.tmp" && mv "$f.tmp" "$f"
  BOUND="$BOUND $rule"
}
BOUND=""
UNBOUND=""
if [ "$TOOL" = claude ]; then
  ALL_REGISTRY=(); CHANGELOG_REGISTRY=()
  while IFS= read -r _p; do [ -n "$_p" ] && ALL_REGISTRY+=("$_p"); done < <(registry_paths all)
  while IFS= read -r _p; do [ -n "$_p" ] && CHANGELOG_REGISTRY+=("$_p"); done < <(registry_paths changelog)
  # ${arr[@]+"${arr[@]}"}: bash 3.2 under `set -u` rejects an empty array.
  if installed_now shared-registries; then
    bind_rule shared-registries ${ALL_REGISTRY[@]+"${ALL_REGISTRY[@]}"} \
      registries.json registry.mk .gitattributes .registry-id-duplicate-allowlist
  fi
  if [ ${#SOURCE_GLOBS[@]} -gt 0 ]; then
    if installed_now comments-and-annotations; then
      bind_rule comments-and-annotations "${SOURCE_GLOBS[@]}" '.github/**' '.claude/hooks/**' Makefile registry.mk
    else
      UNBOUND="$UNBOUND comments-and-annotations"
    fi
    if installed_now versioning-and-changelog; then
      bind_rule versioning-and-changelog "${SOURCE_GLOBS[@]}" ${CHANGELOG_REGISTRY[@]+"${CHANGELOG_REGISTRY[@]}"}
    else
      UNBOUND="$UNBOUND versioning-and-changelog"
    fi
  fi
fi
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
      install_file skills/workspace-graph/SKILL.md .claude/skills/workspace-graph/SKILL.md || true
      install_file commands/ai-engineering-workspace-audit.md .claude/commands/ai-engineering-workspace-audit.md || true
      # One file per run, not one file every run inserts into at the same line.
      # An install that has the single file from an earlier kit keeps it as its archive.
      install_file workspace-changelog/README.md .claude/workspace-changelog/README.md || true
      ;;
    *)
      install_file workspace-changelog/README.md docs/workspace-changelog/README.md || true
      ;;
  esac
fi

# Which kit this is: the last release in the kit's changelog and, from a
# checkout, the commit. Read only from the kit's own checkout: a bare copy of
# starter-kit/ inside a project sits in that project's repository, and its
# HEAD is not the kit's.
KIT_RELEASE=""; KIT_COMMIT=""; KIT_DIRTY=0
_kit_root="$(cd "$KIT_DIR/.." && pwd -P)"
if [ -f "$_kit_root/AGENTIC-ENGINEERING-GUIDE.md" ]; then
  KIT_RELEASE="$(sed -n '/^## \[[0-9]/{s/^## \[\([^]]*\)\].*/\1/p;q;}' "$_kit_root/CHANGELOG.md" 2>/dev/null || true)"
fi
if [ -n "$KIT_RELEASE" ] && [ "$(git -C "$_kit_root" rev-parse --show-toplevel 2>/dev/null || true)" = "$_kit_root" ]; then
  KIT_COMMIT="$(git -C "$_kit_root" rev-parse HEAD 2>/dev/null || true)"
  if [ -n "$KIT_COMMIT" ] && [ -n "$(git -C "$_kit_root" status --porcelain -- starter-kit 2>/dev/null || true)" ]; then
    KIT_DIRTY=1
  fi
fi
kit_version() {
  local commit
  if [ -z "$KIT_RELEASE" ]; then
    echo "Kit: version not recorded — this starter-kit/ is a copy without the kit's CHANGELOG.md beside it."
    return 0
  fi
  commit="$(printf '%s' "$KIT_COMMIT" | cut -c1-7)"
  if [ "$KIT_DIRTY" -eq 1 ]; then commit="$commit, with uncommitted changes"; fi
  echo "Kit: last release $KIT_RELEASE${commit:+, at commit $commit}"
}

# The record of that, in the target (ADR-0024). Written here on a first
# install and by `kit-status.sh --record` when an upgrade is finished, and by
# nothing else: a re-run adds files and upgrades none, so it must not move the
# record, and an install that has no record is not given one that guesses. It
# is a claim; kit-status.sh checks it against the files every time it reads it.
VERSION_RECORD=.starter-kit-version
RECORD_NOTE=""
if [ -e "$TARGET/$VERSION_RECORD" ]; then
  SKIPPED+=("$VERSION_RECORD (already exists — left untouched)")
elif declined "$VERSION_RECORD"; then
  SKIPPED+=("$VERSION_RECORD (declined in $DECLINE_LIST)")
elif [ -z "$KIT_RELEASE" ]; then
  RECORD_NOTE=unknown-kit
elif [ "$HAD_KIT" -eq 1 ]; then
  RECORD_NOTE=existing-install
else
  {
    echo "# The starter kit this repository's agent workspace was last brought in line with."
    echo "# Written by the kit, not by hand: by bootstrap.sh on a first install, and by"
    echo "# \`kit-status.sh --record\` when an upgrade is finished. It is a claim, checked"
    echo "# against the files by:  make kit-status KIT=<path to a checkout of the kit>"
    echo "version: $KIT_RELEASE"
    echo "commit: ${KIT_COMMIT:-unknown}"
    echo "tool: $TOOL"
  } > "$TARGET/$VERSION_RECORD"
  INSTALLED+=("$VERSION_RECORD (kit $KIT_RELEASE${KIT_COMMIT:+, commit $(printf '%s' "$KIT_COMMIT" | cut -c1-7)}, tool $TOOL)")
fi

echo ""
echo "=== bootstrap: $TOOL → $TARGET ==="
kit_version
if [ ${#INSTALLED[@]} -gt 0 ]; then
  echo "Installed:"; printf '  + %s\n' "${INSTALLED[@]}"
fi
if [ ${#SKIPPED[@]} -gt 0 ]; then
  echo "Skipped:"; printf '  = %s\n' "${SKIPPED[@]}"
fi
echo ""
echo "Next steps:"
if [ "$RERUN" -eq 1 ]; then
  # A re-run is read by someone adding the Level-4 layer or moving to a newer
  # kit. The first-install steps are done, and repeating them hides the one
  # thing this reader needs to know.
  echo "  This repository already had the kit, so this run only ADDED what was missing"
  echo "  (the 'Installed' list above, if any). No file that was already here was changed —"
  echo "  not your rules, and not the kit's own scripts."
  echo "  1. To move those to this version of the kit, follow 'Upgrading an existing install'"
  echo "     in $KIT_DIR/README.md. Which kit this repository records, what this one"
  echo "     has that it lacks, and the changelog entries in between:"
  echo "         $KIT_DIR/kit-status.sh --target $TARGET"
  echo "  2. Run 'make lint'."
  if [ "$RECORD_NOTE" = existing-install ]; then
    echo "  $VERSION_RECORD was NOT written. This repository had the kit before this run, and"
    echo "  the run replaced none of its files, so a record naming this kit would be false. The"
    echo "  report above names the release the files match; the last upgrade step,"
    echo "  'kit-status.sh --record', writes the record once the files bear it out."
  fi
  if [ ${#INSTALLED[@]} -gt 0 ]; then
    echo "  If a path under 'Installed' is one you had deleted on purpose, this run could not"
    echo "  know: delete it again and add the path to $DECLINE_LIST at the repository root —"
    echo "  one per line, '# reason' after it; a directory covers everything beneath it. The"
    echo "  installer then leaves it out, on every later run."
  fi
else
  echo "  1. Fill in the constitution's <placeholders> (find them: grep -n '<' $CONSTITUTION)."
  echo "     The template shows example rows, commands and links. Keep what your project has,"
  echo "     and delete the rest: a command that does not run, a stack row with nothing in it,"
  echo "     a link to a rule file that was not installed. Run a command before you keep it."
  echo "     Then $RULES_DIR/project-annotations.md, the project's half of the comments rule:"
  echo "     every '<fill in: …>' in it — what the rule's pointers stand for here, and the markers"
  echo "     your own tooling reads out of comments. The rule itself is used as shipped; edit"
  echo "     nothing in it. ('make registry-list' prints the identifier shapes this repo declares;"
  echo "     see 'Adopting the comments-and-annotations rule' in $KIT_DIR/README.md.)"
  echo "  2. Optional: enable further generic skills — the catalog is $KIT_DIR/skills/common-catalog.md"
  echo "     (in the kit, not in this repository)."
  if [ "$TOOL" = claude ]; then
    echo "     A skill installed here that your team already has from elsewhere — an organisation"
    echo "     plugin, say — is a duplicate: delete the kit's copy and list its path in"
    echo "     $DECLINE_LIST ('# reason' after it), or a later run of this installer puts it back."
  fi
  if [ "$TOOL" != claude ]; then
    echo "     On $TOOL nothing loads a skill by itself: one you want becomes a playbook"
    echo "     document linked from $CONSTITUTION. Skipping this step leaves nothing broken."
  fi
  echo "  3. Run 'make constitution'. It fails, naming the line, for as long as $CONSTITUTION"
  echo "     links to a file that does not exist, or it or project-annotations.md still carries a"
  echo "     template <placeholder> — 'make lint' does not check either, so a green lint does not"
  echo "     mean step 1 is done."
  echo "     Then run 'make lint' — the registry gates, the knowledge-base shape check, the"
  echo "     typed-link gate and the CI-coverage check are already chained into it, and"
  echo "     the installed workflow invokes that same target so nothing can fall out of CI."
fi
if [ "$MAKEFILE_KEPT" -eq 1 ]; then
  # Capture before matching: `grep -q` exits at its first hit, and under
  # `pipefail` the SIGPIPE that kills `make` becomes the pipeline's status, so
  # a correctly chained lint target would be reported to the user as unchained.
  _dry_lint="$(make -n -C "$TARGET" lint 2>/dev/null || true)"
  # Every gate, not the first one: a Makefile that chained the gates of an
  # older kit reaches some of them, and the one it misses is the news.
  _unchained=""
  for _gate in registry-drift registry-ids kb-shape graph-links ci-lint-coverage; do
    if [ "${_dry_lint#*check-$_gate.sh}" = "$_dry_lint" ]; then _unchained="$_unchained $_gate"; fi
  done
  if [ -z "$_unchained" ]; then
    echo "     Your existing Makefile was left untouched, and 'make lint' already reaches every gate."
  else
    echo "     Your existing Makefile was left untouched, and its 'make lint' does not reach:$_unchained"
    echo "     Chain the gates in with two lines (registry.mk is installed next to it):"
    echo "         include registry.mk"
    echo "         lint: registry-drift registry-ids kb-shape graph-links ci-lint-coverage <your existing prerequisites>"
    echo "     Keep your own test target among the prerequisites. Those two lines are all"
    echo "     that is required. Optional: the kit's own suites are the target 'registry-test';"
    echo "     add it to the same line to run them with every lint, as the installed Makefile"
    echo "     does for a repository that had none."
    echo "     Until then 'make lint' passes without running them;"
    echo "     check-ci-lint-coverage.sh reports exactly that once it is chained in."
  fi
fi
if [ "$TOOL" = claude ] && ! grep -q 'workspace-graph.py' "$TARGET/.claude/settings.json" 2>/dev/null; then
  echo "     .claude/settings.json was left untouched, and it does not register the workspace-graph"
  echo "     hook (.claude/hooks/workspace-graph.py): the agent is not told what cites a file it"
  echo "     edits, nor held once when a typed link breaks. To switch that on, add these two entries"
  echo "     inside its \"hooks\" object (the whole file to compare with: $KIT_DIR/settings.json.template):"
  echo '         "PostToolUse": [{"matcher": "Edit|Write|MultiEdit", "hooks": [{"type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/scripts/python.sh \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/workspace-graph.py post-edit", "timeout": 20}]}],'
  echo '         "Stop": [{"hooks": [{"type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/scripts/python.sh \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/workspace-graph.py stop", "timeout": 30}]}]'
fi
for _kept in CHANGELOG.md docs/DEBUGGING-KNOWLEDGE-BASE.md; do
  # Guard on the count: under `set -u`, bash 3.2 (macOS) treats the expansion
  # of an EMPTY array as an unbound variable, and a fresh install skips nothing.
  # Only a file that was kept AND is still hand-maintained needs adopting. A
  # re-run keeps the files an earlier run generated, and those already carry
  # the generated region.
  if [ ${#SKIPPED[@]} -gt 0 ] && printf '%s\n' "${SKIPPED[@]}" | grep -q "^$_kept " \
     && ! grep -q 'BEGIN GENERATED:' "$TARGET/$_kept" 2>/dev/null; then
    _reg=changelog; [ "$_kept" = docs/DEBUGGING-KNOWLEDGE-BASE.md ] && _reg=debugging-kb
    echo "     Your existing $_kept was left untouched. Bring it into the layout with"
    echo "         ./scripts/python.sh scripts/registry_tool.py adopt --registry $_reg"
    echo "     — it moves the current entries into fragments losslessly, keeps every"
    echo "     identifier, and installs the generated region. The drift gate fails until then."
  fi
done
# An authors list with no entry makes the feedback channel inert, on a first
# install and on the re-run that brought the list in. Said while it is empty.
if [ -f "$TARGET/.agent-feedback-authors" ] \
   && ! grep -qv '^[[:space:]]*\(#.*\)\{0,1\}$' "$TARGET/.agent-feedback-authors"; then
  echo "     .agent-feedback-authors names nobody yet, so 'make agent-feedback' reads no one's"
  echo "     Agent-Feedback lines. List the commit emails and comment logins of the people whose"
  echo "     review you would accept for a rule change, one per line — ask, never infer them from"
  echo "     the history (the documentation rule, section 'Feedback to an agent')."
fi
if [ -f "$TARGET/$SCHEDULE_WORKFLOW" ]; then
  echo "     $SCHEDULE_WORKFLOW posts a weekly digest of the Agent-Feedback lines to an issue."
  echo "     GitHub runs it from the default branch only. For the coach's proposals on that issue,"
  echo "     add an ANTHROPIC_API_KEY repository secret and install the Claude GitHub App."
elif ! declined "$SCHEDULE_WORKFLOW"; then
  echo "     Optional: a weekly digest of the Agent-Feedback lines on an issue, with the coach's"
  echo "     proposals when an API key is set — re-run with --with-coach-schedule to add it."
fi
if [ -f "$TARGET/$NOTICE_WORKFLOW" ]; then
  echo "     $NOTICE_WORKFLOW checks once a week whether the kit has a release newer than"
  echo "     $VERSION_RECORD records, and opens an issue when it does. It lists tag names over"
  echo "     the network and runs none of the kit's code. GitHub runs it from the default branch only."
elif ! declined "$NOTICE_WORKFLOW"; then
  echo "     Optional: a weekly check for a newer kit, as an issue when there is one — re-run with"
  echo "     --with-upgrade-notice to add it. Offline, at any time: make kit-status KIT=<kit checkout>."
fi
if [ "$RERUN" -eq 0 ] && [ -f "$TARGET/$VERSION_RECORD" ] && [ ${#SKIPPED[@]} -gt 0 ]; then
  # Kit files that were here before the install stay the project's, and the
  # record does not make them the kit's: kit-status lists them as changed here.
  _kept_kit=""
  for _s in "${SKIPPED[@]}"; do
    case "$_s" in
      *"already exists"*)
        _p="${_s%% (*}"
        case "$_p" in
          scripts/*.py|scripts/check-*.sh|scripts/python.sh|scripts/tests/*|registry.mk|docs/agent-templates/*|docs/rule-reference/*|.claude/hooks/workspace-graph.py|.claude/skills/*|.claude/agents/agent-coach.md|.claude/commands/ai-engineering-workspace-audit.md|"$RULES_DIR"/*.md)
            [ "$_p" = "$RULES_DIR/project-annotations.md" ] || _kept_kit="$_kept_kit $_p" ;;
        esac ;;
    esac
  done
  if [ -n "$_kept_kit" ]; then
    echo "     $VERSION_RECORD names kit $KIT_RELEASE, but these kit files that were already here are"
    echo "     yours, not the kit's — 'kit-status.sh' lists them as changed here:"
    for _p in $_kept_kit; do echo "         $_p"; done
    echo "     Merge the kit's version into each by hand if you want it."
  fi
fi
if [ "$RECORD_NOTE" = unknown-kit ]; then
  echo "     $VERSION_RECORD was not written: this starter-kit/ is a copy without the kit's"
  echo "     CHANGELOG.md, so it cannot say which release it is. Install from a checkout of the kit"
  echo "     to get a record, or write one later with the kit's kit-status.sh --record."
fi
if [ "$KIT_DIRTY" -eq 1 ] && [ -z "$RECORD_NOTE" ] && [ "$RERUN" -eq 0 ]; then
  echo "     Note: the kit checkout has uncommitted changes under starter-kit/. $VERSION_RECORD names"
  echo "     its commit; 'make kit-status' will list the files that differ from that commit."
fi
if [ "$RERUN" -eq 0 ]; then
  echo "  4. Grow by signal: the templates for a new rule, check script, skill and"
  echo "     reviewer are in docs/agent-templates/ — copy one when the signal appears"
  echo "     (the documentation rule's table says which, and what each must carry)."
  echo "  5. See CI run. A workflow file is not a run, and no local check can tell. The installed"
  echo "     workflow starts on a pull request and on a push to main — not on a push of this"
  echo "     branch — so once the pull request is open, in THIS repository:"
  echo "         gh run list --workflow lint.yml --limit 5"
  echo "     must show a completed run that succeeded. None, or one that ends within seconds"
  echo "     before any step, checked nothing. Until a run was seen to succeed, the handoff says"
  echo "     that CI is not confirmed, and why."
  echo "     Then make 'lint' a required status check on the default branch, so that a pull"
  echo "     request CI did not check cannot be merged."
fi
if [ "$TOOL" = claude ] && [ -n "$BOUND" ]; then
  echo "  Load classes: a rule with a 'paths:' header loads when a matching file is read or"
  echo "  edited; every other rule loads into every session. Bound by this run:$BOUND."
  if [ ${#SOURCE_GLOBS[@]} -eq 0 ]; then
    echo "  comments-and-annotations and versioning-and-changelog load into every session, because"
    echo "  where this project's source is was not given. To bind them, add a 'paths:' header to"
    echo "  each ('Load classes' in $KIT_DIR/README.md shows it), or"
    echo "  on a first install pass --source-paths 'src/**,scripts/**'."
  fi
  echo "  To see what really loads, start a NEW session and run the rule-load-check skill: a"
  echo "  header Claude Code cannot parse is ignored in silence, and a session that is already"
  echo "  running has been seen to keep the rules it started with."
fi
if [ "$TOOL" = claude ] && [ -n "$UNBOUND" ]; then
  echo "  --source-paths bound nothing for:$UNBOUND. A rule that was not installed by this"
  echo "  run — it was already here, or it is declined — is yours, and the installer does not"
  echo "  write into it. To bind one, add the 'paths:' header by hand ('Load classes' in"
  echo "  $KIT_DIR/README.md shows it)."
fi
if [ "$TOOL" != claude ] && [ -n "$SOURCE_PATHS" ]; then
  echo "  Note ($TOOL): --source-paths was ignored. Only Claude Code loads a rule by path; here a"
  echo "  rule is read when the constitution links to it, so there is no load class to set."
fi
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
  echo "  playbook docs per guide § 3.10; only the workspace-changelog directory was installed."
fi
if [ "$WITH_META" -eq 0 ]; then
  echo "  Level-4 meta artifacts (agent-coach, workspace-audit, workspace-graph, workspace changelog) ship"
  echo "  in the kit but are NOT day-1 defaults — install them later with --with-meta"
  echo "  once the workspace has real mass (guide § 4.1 / § 5.2 / § 5.3)."
fi
