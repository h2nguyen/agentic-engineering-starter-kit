#!/usr/bin/env bash
# ACCEPTANCE TEST: bootstrap.sh is safe to re-run on a repository it created
# from scratch, and every tool layout receives the same rules.
#
# The contract:
#   1. a second run on a freshly bootstrapped repository changes nothing — no
#      file modified, no file added, and the .gitattributes registry block
#      present exactly once (test-brownfield-adoption.sh covers the case where
#      the block was appended to a file that already existed);
#   2. every tool layout gets the constitution and every shipped rule, at that
#      tool's rule location, with the constitution's rule links retargeted — and
#      the typed links the installed files carry resolve in that layout;
#   3. no hook is registered that does nothing: the SessionStart skeleton is a
#      template, and a registered hook command runs from a path with a space;
#   4. what the adopter declined in .starter-kit-declined stays out, on a first
#      install and on every re-run;
#   5. the installer says which kit it is, so the install can be recorded.
#
# Usage: test-bootstrap-rerun.sh [-v]
set -uo pipefail
VERBOSE=0; [ "${1:-}" = "-v" ] && VERBOSE=1
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PY="$KIT_DIR/scripts/python.sh"   # Python under whatever name this machine gives it
WORK="$(mktemp -d)"; trap '[ "$VERBOSE" -eq 1 ] || rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()  { printf '  ok   — %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL — %s\n' "$1"; fail=$((fail + 1)); }

# Runs from the kit itself; a repo it was installed into has no bootstrap.sh.
BOOTSTRAP="$KIT_DIR/bootstrap.sh"
if [ ! -f "$BOOTSTRAP" ]; then
  echo "SKIP: bootstrap.sh not found beside this test (only runs from the kit itself)"
  exit 0
fi

fresh_repo() { # $1 = dir
  mkdir -p "$1"; git -C "$1" init -q -b main
  git -C "$1" config user.email t@example.invalid; git -C "$1" config user.name t
  git -C "$1" config commit.gpgsign false
}

echo "=== greenfield: a second bootstrap run is a no-op ==="
R="$WORK/greenfield"; fresh_repo "$R"
"$BOOTSTRAP" --tool claude --target "$R" > "$WORK/run1.log" 2>&1 || { bad "first run exited non-zero"; cat "$WORK/run1.log"; }
git -C "$R" add -A >/dev/null; git -C "$R" commit -q -m "bootstrap" 2>/dev/null
"$BOOTSTRAP" --tool claude --target "$R" > "$WORK/run2.log" 2>&1 || { bad "second run exited non-zero"; cat "$WORK/run2.log"; }
changed="$(git -C "$R" status --short)"
[ -z "$changed" ] && ok "second run modified or added nothing" || bad "second run changed the tree: $(echo "$changed" | tr '\n' ' ')"
markers="$(grep -c '>>> starter-kit registries >>>' "$R/.gitattributes")"
[ "$markers" -eq 1 ] && ok ".gitattributes carries the registry block marker exactly once" || bad "marker present $markers times"
attrs="$(grep -c '^CHANGELOG.md .*merge=union' "$R/.gitattributes")"
[ "$attrs" -eq 1 ] && ok "and the CHANGELOG.md merge attribute exactly once" || bad "CHANGELOG.md attribute present $attrs times"
grep -q 'registry block already present' "$WORK/run2.log" \
  && ok "second run reports the block as already present" || bad "second run did not recognise its own block"
# A re-run is how the Level-4 layer and newer kit files arrive, so its output
# is read by someone whose repository is ALREADY in the fragment layout. The
# kept-file hint used to fire for any changelog or knowledge base it skipped,
# and told that reader to adopt files the kit itself had generated.
! grep -q 'adopt --registry' "$WORK/run2.log" \
  && ok "second run does not tell a repository already in the fragment layout to adopt" \
  || bad "second run tells an already-migrated repository to run adopt"

# A fresh install has to read as canonical. The changelog template used to ship
# an empty generated region, which is not what the generator writes for an
# empty registry, so the first `make lint` of a brand-new repository said its
# changelog was "non-canonical after a merge" — in a repository with no merge.
( cd "$R" && "$PY" scripts/registry_tool.py generate >/dev/null 2>&1 )
changed="$(git -C "$R" status --short)"
[ -z "$changed" ] && ok "regenerating a fresh install changes nothing" \
  || bad "the installed templates are not what the generator writes: $(echo "$changed" | tr '\n' ' ')"
git -C "$R" checkout -q -- . 2>/dev/null
drift="$( cd "$R" && ./scripts/check-registry-drift.sh 2>&1 )"
case "$drift" in
  *non-canonical*) bad "a fresh install's drift gate reports a merge that never happened" ;;
  *) ok "a fresh install's drift gate reports nothing to normalise" ;;
esac
# The catalog is in the kit, not in the repository installed into. With
# --target the two are different directories, and a relative path names a
# file the reader's repository does not have.
grep -q "$KIT_DIR/skills/common-catalog.md" "$WORK/run1.log" \
  && ok "the next steps name the skills catalog by a path that exists" \
  || bad "the next steps name the skills catalog by a path relative to nothing"
# init runs after the installer has put the changelog and the knowledge base
# in place, and used to describe them as things the repository "already" had.
! grep -qE 'already carries|knowledge base: present' "$WORK/run1.log" \
  && ok "a first install is not told its repository already had a changelog and a knowledge base" \
  || bad "init describes the files the installer just created as already present"
# What the first run says to do is done by the second. A re-run is read by
# someone upgrading, and it never updates a file — so it has to say that, and
# where the upgrade steps are, instead of repeating the first-install list.
grep -q 'Upgrading an existing install' "$WORK/run2.log" \
  && ok "a re-run says it updated nothing and points at the upgrade steps" \
  || bad "a re-run reads like a first install and never mentions upgrading"
! grep -q 'Upgrading an existing install' "$WORK/run1.log" \
  && ok "and a first install does not" || bad "a first install talks about upgrading"
! grep -q "Fill in the constitution" "$WORK/run2.log" \
  && ok "and a re-run does not repeat the first-install steps" \
  || bad "a re-run tells a repository that has the kit to fill in the constitution again"
# An agent filling in the constitution keeps whatever the template shows. The
# next steps have to say that an example with no counterpart is deleted.
grep -qi 'delete' "$WORK/run1.log" \
  && ok "the next steps say to delete template examples the project has no counterpart for" \
  || bad "the next steps never say what to do with an example the project lacks"

# An install that predates project-annotations.md has its rows and pointers
# inside the comments rule. A re-run that added the unfilled template would
# load placeholders into every session and fail a `constitution` check the
# adopter chained into lint — so the upgrade steps create the file, and a
# re-run does not.
rm -f "$R/.claude/rules/project-annotations.md"
"$BOOTSTRAP" --tool claude --target "$R" > "$WORK/run3.log" 2>&1
[ ! -e "$R/.claude/rules/project-annotations.md" ] \
  && grep -q 'project-annotations.md (not added beside a comments rule that was already here' "$WORK/run3.log" \
  && ok "a re-run does not add an unfilled project-annotations.md to an existing install, and says where the upgrade steps create it" \
  || bad "a re-run installed the project-annotations.md template into an existing install, or skipped it without saying why"
git -C "$R" checkout -q -- . 2>/dev/null
# The reason to hold the file back is the comments rule that was already
# there, with the adopter's rows in it — not the kit having been installed.
# Where the rule itself is new to the repository (an install from before the
# rule existed, a second tool layout, a repository that had the registry tool
# for another reason), it names project-annotations.md "beside this file",
# and a run that installed the rule without the file left a pointer to nothing.
rm -f "$R/.claude/rules/project-annotations.md" "$R/.claude/rules/comments-and-annotations.md"
"$BOOTSTRAP" --tool claude --target "$R" > "$WORK/run4.log" 2>&1
[ -f "$R/.claude/rules/comments-and-annotations.md" ] && [ -f "$R/.claude/rules/project-annotations.md" ] \
  && ok "where the comments rule is new to the repository too, a re-run installs its project half with it" \
  || bad "a re-run installed comments-and-annotations.md and held back the project-annotations.md it names"
git -C "$R" checkout -q -- . 2>/dev/null
T="$WORK/second-layout"; fresh_repo "$T"
"$BOOTSTRAP" --tool copilot --target "$T" >/dev/null 2>&1
"$BOOTSTRAP" --tool claude --target "$T" > "$WORK/second-layout.log" 2>&1
[ -f "$T/.claude/rules/comments-and-annotations.md" ] && [ -f "$T/.claude/rules/project-annotations.md" ] \
  && ( cd "$T" && ./scripts/check-constitution.sh CLAUDE.md 2>&1 | grep -q "project-annotations.md' names a file that does not exist" ); rc=$?
[ -f "$T/.claude/rules/project-annotations.md" ] && [ "$rc" -ne 0 ] \
  && ok "a second tool layout added to a repository that has the kit gets the rule and its project half, and its constitution links nothing that is missing" \
  || bad "adding --tool claude to a copilot install left .claude/rules/ without project-annotations.md"
# Declined is declined, and says so — not "an existing install".
rm -f "$R/.claude/rules/project-annotations.md"
printf '.claude/rules/project-annotations.md   # our markers are in the constitution\n' > "$R/.starter-kit-declined"
"$BOOTSTRAP" --tool claude --target "$R" > "$WORK/run5.log" 2>&1
grep -q 'project-annotations.md (declined in .starter-kit-declined)' "$WORK/run5.log" \
  && ok "a declined project-annotations.md is reported as declined" \
  || bad "a declined project-annotations.md is reported as: $(grep 'project-annotations.md (' "$WORK/run5.log" | head -1 | cut -c1-120)"
rm -f "$R/.starter-kit-declined"; git -C "$R" checkout -q -- . 2>/dev/null

echo "=== run without --target: a project is installed into, the kit's own repository is not ==="
# The kit's repository carries agent instructions of its own now, so tool
# detection succeeds there. Run from its root with no --target, the installer
# would install the kit into the kit. A project that merely holds a copy of
# starter-kit/ is the legitimate no-argument case and must keep working.
K="$WORK/kit-root"; mkdir -p "$K"; cp -R "$KIT_DIR" "$K/starter-kit"; : > "$K/AGENTIC-ENGINEERING-GUIDE.md"
( cd "$K" && ./starter-kit/bootstrap.sh --tool claude > "$WORK/self.log" 2>&1 ); rc=$?
[ "$rc" -ne 0 ] && [ ! -e "$K/CLAUDE.md" ] && [ ! -e "$K/registries.json" ] \
  && ok "run from the kit's own repository with no --target, the installer refuses and writes nothing" \
  || bad "the installer installed the kit into its own repository (exit $rc)"
grep -q -- '--target' "$WORK/self.log" && ok "and it says to name the repository to install into" \
  || bad "the refusal does not mention --target"
P="$WORK/copied-in"; fresh_repo "$P"; cp -R "$KIT_DIR" "$P/starter-kit"
( cd "$P" && ./starter-kit/bootstrap.sh --tool agents > "$WORK/copied-in.log" 2>&1 ); rc=$?
[ "$rc" -eq 0 ] && [ -f "$P/AGENTS.md" ] \
  && ok "a project holding a copy of starter-kit/ still installs with no --target" \
  || bad "the no-argument install into a project stopped working (exit $rc)"

echo "=== the SessionStart skeleton is a template, not a registered hook that does nothing ==="
# It used to be installed, registered and run in every session, where it
# checked nothing and printed "toolchain ready" — and what a SessionStart hook
# prints is added to the session's context. A project that needs environment
# setup copies the template; every other project has no such hook.
R="$WORK/with space"; fresh_repo "$R"
"$BOOTSTRAP" --tool claude --target "$R" >/dev/null 2>&1 || bad "bootstrap into a path with a space exited non-zero"
[ ! -e "$R/.claude/hooks/session-start.sh" ] && ! grep -q 'SessionStart' "$R/.claude/settings.json" \
  && ok "a fresh install has no session-start hook and registers none" \
  || bad "a fresh install still installs or registers the session-start skeleton"
T="$R/docs/agent-templates/session-start.sh.template"
[ -f "$T" ] && ok "the skeleton is in docs/agent-templates/, where a later session finds it" \
  || bad "no session-start template in docs/agent-templates/"
grep -q '"SessionStart"' "$T" 2>/dev/null \
  && ok "and it carries the settings.json entry that registers it" \
  || bad "the template does not say how to register the hook"
env_file="$WORK/claude-env"; : > "$env_file"
out="$(CLAUDE_ENV_FILE="$env_file" bash "$T" 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] \
  && ok "copied as it is, it runs and prints nothing: it reports no state it did not check" \
  || bad "the unfilled skeleton exits $rc and prints: $out"
CLAUDE_ENV_FILE="$env_file" bash "$T" >/dev/null 2>&1
lines="$(wc -l < "$env_file" | tr -d ' ')"
[ "$lines" -eq 1 ] && ok "a second SessionStart (resume, compaction) appends nothing new" || bad "the env file has $lines lines after two starts"
# Hook commands run through `sh -c`. Unquoted, $CLAUDE_PROJECT_DIR splits at a
# space and the hook exits 127 — a non-blocking error, so it is silently gone.
cmd="$("$PY" -c 'import json,sys; print(json.load(open(sys.argv[1]))["hooks"]["PostToolUse"][0]["hooks"][0]["command"])' "$R/.claude/settings.json")"
CLAUDE_PROJECT_DIR="$R" sh -c "$cmd" </dev/null >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "a registered hook command runs from a project path with a space" || bad "the hook command exited $rc from a path with a space"

echo "=== what the adopter declined stays out ==="
# The installer adds whatever is missing, so it could not tell a file the
# adopter deleted on purpose from one that is new in this kit: a skill removed
# because the organisation ships the same one came back with every upgrade.
R="$WORK/declined"; fresh_repo "$R"
"$BOOTSTRAP" --tool claude --target "$R" >/dev/null 2>&1
git -C "$R" add -A >/dev/null; git -C "$R" commit -q -m "bootstrap" 2>/dev/null
rm -rf "$R/.claude/skills/semver"
"$BOOTSTRAP" --tool claude --target "$R" > "$WORK/declined-control.log" 2>&1
[ -d "$R/.claude/skills/semver" ] && ok "control — with no decline list, a re-run puts a deleted skill back" \
  || bad "control: a re-run did not restore a deleted skill, so the cases below prove nothing"
grep -q '\.starter-kit-declined' "$WORK/declined-control.log" \
  && ok "and a re-run that installed something says how to keep it out" \
  || bad "a re-run that restored a deleted file never mentions .starter-kit-declined"
rm -rf "$R/.claude/skills/semver" "$R/.claude/skills/prompt-enhancer" "$R/scripts/tests/test-parallel-merge.sh"
printf '%s\n' '# the organisation plugin ships both skills' '.claude/skills/semver/' \
  '.claude/skills/prompt-enhancer/SKILL.md   # same' '' 'scripts/tests/test-parallel-merge.sh' > "$R/.starter-kit-declined"
list_before="$(cat "$R/.starter-kit-declined")"
"$BOOTSTRAP" --tool claude --target "$R" > "$WORK/declined.log" 2>&1 || bad "a re-run with a decline list exited non-zero"
[ ! -e "$R/.claude/skills/semver" ] && [ ! -e "$R/.claude/skills/prompt-enhancer/SKILL.md" ] \
  && [ ! -e "$R/scripts/tests/test-parallel-merge.sh" ] \
  && ok "listed, all three stay out: a directory, a file, and a file inside a directory the installer merges into" \
  || bad "a declined path was installed anyway: $(cd "$R" && ls -d .claude/skills/semver .claude/skills/prompt-enhancer/SKILL.md scripts/tests/test-parallel-merge.sh 2>/dev/null | tr '\n' ' ')"
[ "$(grep -c 'declined in \.starter-kit-declined' "$WORK/declined.log")" -eq 3 ] \
  && ok "and each is reported as declined" \
  || bad "the run does not report three declined paths: $(grep -c 'declined in' "$WORK/declined.log")"
[ "$(cat "$R/.starter-kit-declined")" = "$list_before" ] && ok "the installer does not edit the list" \
  || bad "the installer changed .starter-kit-declined"
R="$WORK/declined-first"; fresh_repo "$R"
printf '.claude/skills\n' > "$R/.starter-kit-declined"
"$BOOTSTRAP" --tool claude --target "$R" > "$WORK/declined-first.log" 2>&1
[ ! -e "$R/.claude/skills" ] && [ -f "$R/.claude/rules/documentation.md" ] \
  && ok "a list written before the first install is honoured, and a directory line covers everything beneath it" \
  || bad "a first install ignored the decline list: $(ls "$R/.claude/skills" 2>/dev/null | tr '\n' ' ')"
( cd "$R" && make lint > "$WORK/declined-first-lint.log" 2>&1 ) \
  && ok "and the install without the kit's skills lints green" \
  || { bad "an install with the skills declined fails its lint:"; grep -E '^FAIL|Error' "$WORK/declined-first-lint.log" | head -3 | sed 's/^/         /'; }

echo "=== the installer says which kit it is ==="
# Nothing in the repository records the kit an install came from (ADR-0011),
# so the one place the answer exists is the run itself: the handoff copies it.
released="$(sed -n 's/^## \[\([0-9][^]]*\)\].*/\1/p' "$KIT_DIR/../CHANGELOG.md" 2>/dev/null | head -1)"
if [ -n "$released" ]; then
  grep -q "^Kit: last release $released" "$WORK/run1.log" \
    && ok "run from a checkout of the kit, it names the last release ($released)" \
    || bad "the run does not say 'Kit: last release $released'"
else
  echo "  skip — no CHANGELOG.md beside starter-kit/ in this checkout"
fi
grep -q '^Kit: version not recorded' "$WORK/copied-in.log" \
  && ok "run from a bare copy of starter-kit/ inside a project, it says the version is not recorded — and does not report the project's commit as the kit's" \
  || bad "a copied-in starter-kit/ reports: $(grep '^Kit:' "$WORK/copied-in.log")"

echo "=== every tool layout receives the constitution and every shipped rule ==="
# Templates (leading underscore) are not rules; everything else under rules/
# is a shipped rule and must land, whichever tool the repository uses.
expected_rules="$(cd "$KIT_DIR/rules" && ls *.md | grep -v '^_' | sort)"
for tool in claude agents cursor copilot; do
  R="$WORK/$tool"; fresh_repo "$R"
  "$BOOTSTRAP" --tool "$tool" --target "$R" > "$WORK/boot-$tool.out" 2> "$WORK/boot-$tool.err" || bad "$tool: bootstrap exited non-zero"
  # A fresh install skips nothing, and under `set -u` bash 3.2 (macOS) treats
  # the expansion of an EMPTY array as an unbound variable: the installer
  # printed that error twice and still exited 0.
  [ ! -s "$WORK/boot-$tool.err" ] && ok "$tool: a fresh install writes nothing to stderr" \
    || { bad "$tool: a fresh install wrote to stderr:"; head -3 "$WORK/boot-$tool.err" | cut -c1-160 | sed 's/^/         /'; }
  ! grep -q 'adopt --registry' "$WORK/boot-$tool.out" \
    && ok "$tool: a repository that had nothing is not told to adopt what it was just given" \
    || bad "$tool: a fresh install is told to run adopt on the template it just received"
  pointer="$("$PY" -c 'import json,sys; print(json.load(open(sys.argv[1]))["rule_pointer"])' "$R/registries.json")"
  [ -f "$R/$pointer" ] && ok "$tool: gate failures point at a rule file that exists ($pointer)" \
    || bad "$tool: registries.json points gate failures at $pointer, which is not there"
  case "$tool" in
    claude)  c="$R/CLAUDE.md";                        rules_dir="$R/.claude/rules" ;;
    copilot) c="$R/.github/copilot-instructions.md";  rules_dir="$R/docs/agent-rules" ;;
    *)       c="$R/AGENTS.md";                        rules_dir="$R/docs/agent-rules" ;;
  esac
  [ -f "$c" ] && ok "$tool: constitution at ${c#"$R"/}" || bad "$tool: no constitution at ${c#"$R"/}"
  installed="$(cd "$rules_dir" 2>/dev/null && ls *.md | grep -v '^project-annotations\.md$' | sort)"
  [ "$installed" = "$expected_rules" ] \
    && ok "$tool: every shipped rule landed in ${rules_dir#"$R"/}" \
    || bad "$tool: ${rules_dir#"$R"/} holds: $(echo $installed)"
  # The comments rule used to be the one kit file a project had to edit: a
  # table to complete and four pointers to resolve, inside a rule that an
  # upgrade then could not copy and no check read. The project's half is a
  # file of its own now; the rule is the kit's, word for word.
  pa="$rules_dir/project-annotations.md"
  [ -f "$pa" ] && grep -q '^\*\*Related:\*\* RULE:comments-and-annotations' "$pa" \
    && ok "$tool: the project's half of the comments rule is its own file, ${pa#"$R"/}" \
    || bad "$tool: no project-annotations.md beside the rules, or it does not name the rule it completes"
  ! grep -qiE 'fill-in|complete the second table|testing\.md' "$rules_dir/comments-and-annotations.md" \
    && grep -q 'project-annotations\.md' "$rules_dir/comments-and-annotations.md" \
    && ok "$tool: the comments rule asks the project to edit nothing in it, and names the file that holds the project's half" \
    || bad "$tool: the comments rule still has a part to fill in, or names testing.md: $(grep -ciE 'fill-in|complete the second table|testing\.md' "$rules_dir/comments-and-annotations.md") line(s)"
  grep -qF "(${rules_dir#"$R"/}/project-annotations.md)" "$c" \
    && ok "$tool: the constitution's rule index links it, at this layout's path" || bad "$tool: the constitution does not link ${rules_dir#"$R"/}/project-annotations.md"
  # The documentation rule prescribed docs/adr/ and `--registry adr` whether
  # or not the repository keeps decision records there. A project that
  # records decisions elsewhere had to overrule it in its constitution.
  grep -q 'No `adr` registry' "$rules_dir/documentation.md" \
    && ok "$tool: the documentation rule says when its decision-record format applies, and what holds when it does not" \
    || bad "$tool: the documentation rule prescribes the adr registry unconditionally"
  if [ "$tool" = claude ]; then
    ! grep -q 'docs/agent-rules/' "$c" && ok "$tool: constitution links point at .claude/rules/" || bad "$tool: links retargeted by mistake"
  else
    ! grep -q '\.claude/rules/' "$c" && ok "$tool: constitution links retargeted to docs/agent-rules/" || bad "$tool: constitution still links .claude/rules/"
  fi
  # Two shipped rules keep only their imperative always-loaded and point at an
  # on-demand reference for the worked examples and the gotcha write-ups. A
  # pointer to a file that was not installed would send every reader nowhere.
  missing=""
  for ref in $(grep -rhoE 'docs/rule-reference/[a-z-]+\.md' "$rules_dir" | sort -u); do
    [ -f "$R/$ref" ] || missing="$missing $ref"
  done
  [ -n "$(ls "$R/docs/rule-reference" 2>/dev/null)" ] && [ -z "$missing" ] \
    && ok "$tool: every on-demand reference a rule points at is installed" \
    || bad "$tool: a rule points at a reference that is not installed:$missing"
  # Two of the kit's suites test the INSTALLER — this one and the brownfield
  # one. A repository the kit was installed into has no installer, so there
  # they could only print SKIP into every lint run, and four adopting agents
  # stopped to work out what that meant.
  [ ! -e "$R/scripts/tests/test-bootstrap-rerun.sh" ] && [ ! -e "$R/scripts/tests/test-brownfield-adoption.sh" ] \
    && ! grep -q 'test-bootstrap-rerun\|test-brownfield-adoption' "$R/registry.mk" \
    && ok "$tool: the installer's own suites stay in the kit, and lint does not try to run them" \
    || bad "$tool: a suite that can only SKIP outside the kit was installed"
  # A later session never sees the kit. If the templates stay behind in it,
  # the first rule, check script, skill or reviewer that session writes is
  # rebuilt from memory — and each adopting agent dropped a different required
  # part (the litmus test, the incident link, the reviewer's cross-cutting
  # checks). They land where every tool layout can find them, out of the
  # always-loaded rules directory and out of the link gate's way.
  tdir="$R/docs/agent-templates"
  [ -f "$tdir/_rule-template.md" ] && [ -f "$tdir/check-convention.sh.template" ] \
    && [ -f "$tdir/_skill-template.md" ] && [ -f "$tdir/_agent-template.md" ] \
    && ok "$tool: the rule, check-script, skill and reviewer templates are in docs/agent-templates/" \
    || bad "$tool: templates missing from docs/agent-templates/: $(ls "$tdir" 2>/dev/null | tr '\n' ' ')"
  # A rule, skill or reviewer that states only what to do is followed to the
  # letter and misapplied at the first case its examples do not show. Each
  # template asks for the reason, so the artifact copied from it carries one.
  nowhy=""
  for t in _rule-template.md _skill-template.md _agent-template.md; do
    grep -q '^\*\*Why:\*\*' "$tdir/$t" 2>/dev/null || nowhy="$nowhy $t"
  done
  [ -z "$nowhy" ] && ok "$tool: the rule, skill and reviewer templates each ask for the why" \
    || bad "$tool: templates with no **Why:** line:$nowhy"
  if [ "$tool" != claude ]; then
    ! grep -rq '\.claude/rules/' "$tdir" && ok "$tool: the templates point at docs/agent-rules/, where this layout keeps rules" \
      || bad "$tool: a template still points at .claude/rules/"
    # Retargeting belongs to the install. On a re-run the template is the
    # adopter's file, and the installer does not modify a file it skipped.
    printf '\nOurs: see .claude/rules/legacy.md\n' >> "$tdir/_rule-template.md"
    "$BOOTSTRAP" --tool "$tool" --target "$R" >/dev/null 2>&1
    grep -q '\.claude/rules/legacy\.md' "$tdir/_rule-template.md" \
      && ok "$tool: a re-run leaves a template the adopter edited exactly as it is" \
      || bad "$tool: a re-run rewrote a template that already existed"
    grep -v 'legacy\.md' "$tdir/_rule-template.md" > "$WORK/tpl" && cp "$WORK/tpl" "$tdir/_rule-template.md"
  fi
  # Feedback to an agent is written down from the first commit, whatever tool
  # the project uses, so the collector and the list of whose feedback counts
  # land in every layout — and a fresh install's list names nobody, so no
  # one's text is read until the adopter says whose is.
  [ -x "$R/scripts/feedback_tool.py" ] && [ -f "$R/.agent-feedback-authors" ] \
    && ok "$tool: the feedback collector and its authors list are installed" \
    || bad "$tool: scripts/feedback_tool.py or .agent-feedback-authors is missing"
  ( cd "$R" && make -s agent-feedback > "$WORK/feedback-$tool.json" 2> "$WORK/feedback-$tool.err" ) \
    && "$PY" -c 'import json,sys; r=json.load(open(sys.argv[1])); sys.exit(0 if r["authors_listed"] == 0 and r["counts"]["accepted"] == 0 else 1)' "$WORK/feedback-$tool.json" \
    && ok "$tool: 'make agent-feedback' runs on a fresh install and reads nobody's feedback" \
    || { bad "$tool: 'make agent-feedback' failed on a fresh install:"; head -3 "$WORK/feedback-$tool.err" | sed 's/^/         /'; }
  # The list ships naming nobody, so until it is filled in the channel is
  # inert — and nothing used to say so: the next steps have to.
  grep -q '\.agent-feedback-authors names nobody' "$WORK/boot-$tool.out" \
    && ok "$tool: the next steps say the authors list names nobody yet" \
    || bad "$tool: the next steps never mention filling in .agent-feedback-authors"
  # The gates cite the rules they enforce by token, not by path, so the same
  # header has to resolve whether the rules landed in .claude/rules/ or in
  # docs/agent-rules/. A link that only works for one tool is not tool-agnostic.
  if ( cd "$R" && ./scripts/check-graph-links.sh > "$WORK/links-$tool.log" 2>&1 ); then
    ok "$tool: every typed link the kit installs resolves in this layout"
  else
    bad "$tool: an installed typed link does not resolve:"; grep -E '^FAIL' "$WORK/links-$tool.log" | head -5 | sed 's/^/         /'
  fi
  # Resolving is half of it. A rule that no typed link names can be renamed or
  # deleted with the gate green and the hook silent, and three of the five
  # shipped rules were cited only in prose. Asked of each layout, because a
  # citer that is a Claude Code skill is not installed on the other three.
  uncited=""
  for rule in $expected_rules; do
    ( cd "$R" && "$PY" -B scripts/graph_tool.py impact "RULE:${rule%.md}" 2>&1 ) | grep -q '^Cited by (0)' \
      && uncited="$uncited ${rule%.md}"
  done
  [ -z "$uncited" ] && ok "$tool: every shipped rule is named by a typed link of another installed artifact" \
    || bad "$tool: no typed link names:$uncited"
  # A file the installer has put in place is at its destination. A header that
  # still says to copy it there is an instruction with nothing left to do —
  # read, in the installed Makefile and workflow, by every later session. The
  # templates in docs/agent-templates/ are the exception: they are for copying.
  stale="$(grep -rl 'Copy to' "$R" --exclude-dir=.git --exclude-dir=agent-templates 2>/dev/null | sed "s|^$R/||" | tr '\n' ' ')"
  [ -z "$stale" ] && ok "$tool: no installed file tells its reader to copy it to where it already is" \
    || bad "$tool: installed and still saying 'Copy to': $stale"
  # Installed is not onboarded. The link gate above is green on a constitution
  # that still has every template placeholder and two links to example rules
  # nobody wrote — which is how one was committed that way. The constitution
  # check is what reads it: every such line, in this layout's paths.
  ( cd "$R" && make constitution > "$WORK/constitution-$tool.log" 2>&1 ); rc=$?
  [ "$rc" -ne 0 ] && ok "$tool: 'make constitution' fails on a constitution nobody has filled in" \
    || bad "$tool: 'make constitution' passed on the untouched template"
  want="$(grep -c '<fill in:' "$KIT_DIR/rules/project-annotations.md.template")"
  got="$(grep -c "^FAIL: ${pa#"$R"/}:[0-9]* — unfilled placeholder '<fill in:" "$WORK/constitution-$tool.log")"
  [ "$want" -gt 0 ] && [ "$got" -eq "$want" ] \
    && ok "$tool: and reports every one of the $want placeholders of the project-annotations.md nobody has filled in" \
    || bad "$tool: 'make constitution' reports $got of the $want placeholders in project-annotations.md"
  unreported=""
  for n in $(awk '/^## Debugging/ {exit} /</ {print NR}' "$c"); do
    grep -q "^FAIL: ${c#"$R"/}:$n — " "$WORK/constitution-$tool.log" || unreported="$unreported $n"
  done
  [ -z "$unreported" ] && ok "$tool: every template line that opens a placeholder is reported by number" \
    || bad "$tool: template placeholder lines the check did not report:$unreported"
  grep -q "link '${rules_dir#"$R"/}/testing.md' names a file that does not exist" "$WORK/constitution-$tool.log" \
    && grep -q "link '${rules_dir#"$R"/}/security.md' names a file that does not exist" "$WORK/constitution-$tool.log" \
    && ok "$tool: and the two example rules the template links to, which no install has" \
    || bad "$tool: the links to testing.md and security.md were not reported"
  # What filling it in comes to, mechanically: every placeholder line and both
  # example links gone. The Debugging section keeps its angle brackets — a
  # command argument in a fence, two token shapes in backticks — and must pass.
  cp "$c" "$WORK/constitution-$tool.orig"; cp "$pa" "$WORK/annotations-$tool.orig"
  awk '/^## Debugging/ {keep=1} keep || !(/</ || /testing\.md/ || /security\.md/ || /^constraints that shape/)' \
    "$WORK/constitution-$tool.orig" > "$c"
  ( cd "$R" && make constitution > "$WORK/constitution-$tool.log" 2>&1 ); rc=$?
  [ "$rc" -ne 0 ] && ! grep -q "^FAIL: ${c#"$R"/}:" "$WORK/constitution-$tool.log" \
    && ok "$tool: with the constitution filled in, what is left to report is project-annotations.md alone" \
    || bad "$tool: a filled-in constitution beside an unfilled project-annotations.md: exit $rc"
  sed -E 's/<fill in: [^>]*>/`#123`/g' "$WORK/annotations-$tool.orig" > "$pa"
  ( cd "$R" && make constitution > "$WORK/constitution-$tool.log" 2>&1 ) \
    && grep -q '<symptom>' "$c" && grep -q '<DECISION-RECORD-ID>' "$pa" \
    && ok "$tool: with both filled in it passes, and the angle brackets that belong there stayed" \
    || { bad "$tool: a filled-in constitution and project-annotations.md still fail:"; grep -E '^FAIL' "$WORK/constitution-$tool.log" | head -3 | sed 's/^/         /'; }
  cp "$WORK/constitution-$tool.orig" "$c"; cp "$WORK/annotations-$tool.orig" "$pa"
done

echo "=== the kit's own tools leave no bytecode behind in the repository ==="
# The installer ships no .gitignore, so a __pycache__ the tools create shows
# up as untracked files and rides into the next `git add -A`. A machine with
# PYTHONDONTWRITEBYTECODE set hides this, so it is unset here on purpose.
R="$WORK/claude"
unit="$(grep -m1 'unittest discover' "$R/registry.mk" | sed 's/^[[:space:]]*//')"
( cd "$R" && env -u PYTHONDONTWRITEBYTECODE make graph-links registry-ids >/dev/null 2>&1
  env -u PYTHONDONTWRITEBYTECODE sh -c "$unit" > "$WORK/unit.log" 2>&1
  env -u PYTHONDONTWRITEBYTECODE "$PY" scripts/graph_tool.py impact RULE:documentation >/dev/null 2>&1 )
left="$(find "$R" -name '__pycache__' -o -name '*.pyc' | grep -v '/.git/' | wc -l | tr -d ' ')"
[ "$left" -eq 0 ] && ok "the gates, the unit tests and a direct query leave no __pycache__ in the repository" \
  || bad "the kit's tools left $left bytecode path(s) in the repository"

# A green run must read as green. The unit tests exercise the gates' failure
# paths, and those used to print their FAIL lines straight into `make lint` —
# dozens of them on a passing run, which an agent scanning the output for
# "FAIL" reads as a broken build.
grep -q '^Ran [0-9]* tests' "$WORK/unit.log" && ! grep -q '^FAIL' "$WORK/unit.log" \
  && ok "a passing unit-test run prints no FAIL line" \
  || bad "a passing unit-test run prints $(grep -c '^FAIL' "$WORK/unit.log") FAIL line(s)"

# `make graph-impact` with the variable forgotten used to hand the tool no
# argument, and the reader an argparse usage line that never mentions NODE.
out="$( cd "$R" && make graph-impact 2>&1 )"; rc=$?
case "$out" in
  *"NODE=RULE:"*) [ "$rc" -ne 0 ] && ok "'make graph-impact' without NODE says how to name one, and fails" \
                    || bad "'make graph-impact' without NODE exits 0" ;;
  *) bad "'make graph-impact' without NODE does not say to pass NODE=<KIND:name>" ;;
esac
# Capture before matching: under `pipefail`, `grep -q` leaving at its first
# hit kills `make` with SIGPIPE while it is still writing, and the pipeline
# then reports a command that answered correctly as one that failed. GNU Make
# 4 on Linux writes enough after the first line for that to happen every time.
out="$( cd "$R" && make graph-impact NODE=RULE:documentation 2>&1 )"
case "$out" in
  *"RULE:documentation — "*) ok "and with NODE it answers" ;;
  *) bad "'make graph-impact NODE=RULE:documentation' does not answer" ;;
esac

echo "=== a machine where Python is not called python3 ==="
# What Windows looks like from Git Bash: python3 is on PATH and is not Python
# (a Store alias), and the interpreter answers to `python`. Nothing the kit
# runs may reach for python3 by name: not the installer, not a make target,
# not a gate, not a test. One that does fails here.
REAL_PY="$("$KIT_DIR/scripts/python.sh" -c 'import sys; print(sys.executable)' 2>/dev/null)"
SHADOW="$WORK/not-python3"; mkdir -p "$SHADOW"
printf '#!/bin/sh\necho "python3-is-not-python: $*" >> "%s/reached.log"\nexit 49\n' "$WORK" > "$SHADOW/python3"
printf '#!/bin/sh\nexec "%s" "$@"\n' "$REAL_PY" > "$SHADOW/python"; chmod +x "$SHADOW/python3" "$SHADOW/python"
R="$WORK/other name"; fresh_repo "$R"
if ( unset PYTHON; PATH="$SHADOW:$PATH" "$BOOTSTRAP" --tool claude --target "$R" > "$WORK/other-install.log" 2>&1 ) && [ -f "$R/registries.json" ]; then
  ok "the installer runs, and writes registries.json, where Python is called python"
else
  bad "the installer failed where python3 is not Python:"; tail -4 "$WORK/other-install.log" | sed 's/^/         /'
fi
[ -x "$R/scripts/python.sh" ] && ok "scripts/python.sh is installed, executable" || bad "scripts/python.sh was not installed"
if ( cd "$R" && unset PYTHON && PATH="$SHADOW:$PATH" make lint > "$WORK/other-lint.log" 2>&1 ); then
  ok "'make lint' passes there — every gate and every suite of a fresh install"
else
  bad "'make lint' fails where python3 is not Python:"; grep -E "FAIL|Error|not found" "$WORK/other-lint.log" | head -6 | sed 's/^/         /'
fi
# The probe asks python3 one question (-c, a version check) and moves on. Any
# other call is something that named the interpreter itself.
named="$(grep -v 'sys.version_info' "$WORK/reached.log" 2>/dev/null | wc -l | tr -d ' ')"
[ "$named" -eq 0 ] && ok "and nothing in the kit called python3 by name" \
  || { bad "$named call(s) named python3 directly:"; grep -v 'sys.version_info' "$WORK/reached.log" | cut -c1-150 | sort | uniq -c | head -6 | sed 's/^/         /'; }

echo "=== which tool: named, detected, or asked for — never picked ==="
# A repository can carry the files of more than one agent tool. The installer
# used to take the first it looked for — Claude Code ahead of Cursor ahead of
# AGENTS.md — and install that layout without a word, where the guide says it
# asks. Now: --tool wins; one detected tool is used; more than one is a
# question, and where nobody can answer it the run ends before it writes.
tree() { ( cd "$1" && find . -path ./.git -prune -o -print | sort ); }
R="$WORK/several"; fresh_repo "$R"; mkdir -p "$R/.claude" "$R/.cursor"; echo "# ours" > "$R/AGENTS.md"
before="$(tree "$R")"
"$BOOTSTRAP" --target "$R" > "$WORK/several.log" 2>&1 < /dev/null; rc=$?
[ "$rc" -ne 0 ] && ok "several tools detected, no --tool, nobody to ask: the installer fails" \
  || bad "several tools detected and the installer picked one (exit 0): $(head -1 "$WORK/several.log")"
[ "$(tree "$R")" = "$before" ] && ok "and it has written nothing" \
  || bad "an ambiguous run changed the repository: $(tree "$R" | wc -l | tr -d ' ') paths, was $(echo "$before" | wc -l | tr -d ' ')"
grep -q -- '--tool' "$WORK/several.log" && grep -q 'claude' "$WORK/several.log" && grep -q 'cursor' "$WORK/several.log" \
  && ok "and it names the tools it found and the option that settles it" \
  || bad "the refusal does not name the detected tools and --tool"
! grep -q 'agents' "$WORK/several.log" \
  && ok "AGENTS.md beside .cursor/ is Cursor's own constitution, not a third tool" \
  || bad "AGENTS.md was counted as a separate tool beside Cursor"
"$BOOTSTRAP" --tool cursor --target "$R" > "$WORK/several-told.log" 2>&1 < /dev/null; rc=$?
[ "$rc" -eq 0 ] && [ -f "$R/docs/agent-rules/documentation.md" ] && [ ! -e "$R/CLAUDE.md" ] && [ ! -e "$R/.claude/rules" ] \
  && ok "control: the same repository with --tool cursor installs that layout and no other" \
  || bad "--tool did not settle an ambiguous repository (exit $rc)"
[ "$(cat "$R/AGENTS.md")" = "# ours" ] && ok "and the constitution that was there is still the adopter's" \
  || bad "the installer changed an AGENTS.md that already existed"

for case in "claude:CLAUDE.md:CLAUDE.md" "claude:.claude/:CLAUDE.md" "cursor:.cursor/:AGENTS.md" "cursor:.cursorrules:AGENTS.md" \
            "copilot:.github/copilot-instructions.md:.github/copilot-instructions.md" "agents:AGENTS.md:AGENTS.md"; do
  tool="${case%%:*}"; marker="${case#*:}"; marker="${marker%%:*}"; constitution="${case##*:}"
  R="$WORK/one-$tool-$(echo "$marker" | tr -c 'A-Za-z0-9\n' '_')"; fresh_repo "$R"
  case "$marker" in */) mkdir -p "$R/$marker" ;; *) mkdir -p "$(dirname "$R/$marker")"; echo "# ours" > "$R/$marker" ;; esac
  "$BOOTSTRAP" --target "$R" > "$WORK/one.log" 2>&1 < /dev/null; rc=$?
  [ "$rc" -eq 0 ] && grep -q "^Detected agentic tool: $tool\$" "$WORK/one.log" && [ -f "$R/$constitution" ] \
    && ok "one tool detected ($marker): $tool is used without asking" \
    || bad "a single $marker did not install for $tool (exit $rc): $(head -1 "$WORK/one.log")"
done
# The Cursor layout is .cursor/ beside an AGENTS.md the kit itself installed.
# A re-run with no --tool — the first step of an upgrade — must not call that two tools.
R="$WORK/one-cursor-_cursor_"
"$BOOTSTRAP" --target "$R" > "$WORK/one.log" 2>&1 < /dev/null; rc=$?
[ "$rc" -eq 0 ] && grep -q '^Detected agentic tool: cursor$' "$WORK/one.log" \
  && ok "a re-run on a Cursor install detects Cursor again" || bad "a re-run on a Cursor install was ambiguous (exit $rc)"

R="$WORK/claude-and-agents"; fresh_repo "$R"; echo "@AGENTS.md" > "$R/CLAUDE.md"; echo "# ours" > "$R/AGENTS.md"
before="$(tree "$R")"
"$BOOTSTRAP" --target "$R" > "$WORK/two.log" 2>&1 < /dev/null; rc=$?
[ "$rc" -ne 0 ] && [ "$(tree "$R")" = "$before" ] \
  && ok "CLAUDE.md beside AGENTS.md is two tools: the installer fails and writes nothing" \
  || bad "CLAUDE.md beside AGENTS.md was settled silently (exit $rc)"

R="$WORK/no-tool"; fresh_repo "$R"; before="$(tree "$R")"
"$BOOTSTRAP" --target "$R" > /dev/null 2>&1 < /dev/null; rc=$?
[ "$rc" -ne 0 ] && [ "$(tree "$R")" = "$before" ] \
  && ok "no tool detected, no --tool, nobody to ask: the installer fails and writes nothing" \
  || bad "a repository with no agent tool was installed into without a tool being named (exit $rc)"

# With a terminal there is someone to ask. A pseudo-terminal stands in for
# one; where the platform has none (Windows) the case is skipped, and says so.
R="$WORK/asked"; fresh_repo "$R"; mkdir -p "$R/.claude" "$R/.cursor"
"$PY" -B - "$BOOTSTRAP" "$R" cursor > "$WORK/asked.log" 2>&1 <<'PTY'
import os, sys
try:
    import pty
except ImportError:
    print("NO-PTY"); sys.exit(0)
bootstrap, target, answer = sys.argv[1:4]
pid, fd = pty.fork()
if pid == 0:
    os.execv(bootstrap, [bootstrap, "--target", target])
seen, answered = b"", False
while True:
    try:
        chunk = os.read(fd, 4096)
    except OSError:
        break
    if not chunk:
        break
    seen += chunk
    if not answered and b"]: " in seen:
        os.write(fd, answer.encode() + b"\n"); answered = True
status = os.waitpid(pid, 0)[1]
sys.stdout.write(seen.decode("utf-8", "replace"))
print("\nASKED=%s EXIT=%s" % (answered, os.WEXITSTATUS(status) if os.WIFEXITED(status) else "signal"))
PTY
if grep -q 'NO-PTY' "$WORK/asked.log"; then
  echo "  skip — no pseudo-terminal on this platform: the interactive question is not exercised here"
else
  grep -q 'ASKED=True EXIT=0' "$WORK/asked.log" && [ -f "$R/AGENTS.md" ] && [ ! -e "$R/CLAUDE.md" ] \
    && ok "at a terminal, several detected tools are a question, and the answer is the layout installed" \
    || { bad "at a terminal the installer did not ask, or did not install what was answered:"; tail -3 "$WORK/asked.log" | cut -c1-160 | sed 's/^/         /'; }
fi

echo "=== the Level-4 artifacts' links resolve once installed ==="
R="$WORK/meta"; fresh_repo "$R"
"$BOOTSTRAP" --tool claude --with-meta --target "$R" >/dev/null 2>&1 || bad "bootstrap --with-meta exited non-zero"
if ( cd "$R" && ./scripts/check-graph-links.sh > "$WORK/links-meta.log" 2>&1 ); then
  ok "agent-coach, the audit skill and command, and the workspace-graph skill cite only what was installed"
else
  bad "a Level-4 artifact cites something that was not installed:"; grep -E '^FAIL' "$WORK/links-meta.log" | head -5 | sed 's/^/         /'
fi
handoffs="$( cd "$R" && "$PY" scripts/graph_tool.py impact HUMAN 2>/dev/null | head -1 )"
case "$handoffs" in
  *"(0)"*|"") bad "the installed meta loop declares no human approval gate" ;;
  *) ok "the installed meta loop declares its human approval gates as hand-offs" ;;
esac

echo ""; echo "=== $pass passed, $fail failed ==="
[ "$VERBOSE" -eq 1 ] && echo "scratch repos kept in $WORK"
[ "$fail" -eq 0 ] || exit 1
