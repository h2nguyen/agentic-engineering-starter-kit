#!/usr/bin/env bash
# ACCEPTANCE TEST: an install records the kit it came from, and kit-status.sh
# checks that record against the files (ADR-0024).
#
# What it holds:
#   1. a first install writes .starter-kit-version — release, commit, tool —
#      on all four tools, and a re-run never changes it;
#   2. `kit-status.sh` shows the recorded kit, the available one, the changelog
#      entries between them with the breaking ones first, and which of the
#      kit's files here are the older kit's, which were changed here;
#   3. the record changes only through an install and `--record`, and a
#      half-done upgrade cannot make it false: `--record` refuses while a file
#      is still the older kit's, and the report calls the state partial;
#   4. an install without a record is told so, with the release its files
#      match and the command that records it;
#   5. none of it uses the network; the opt-in notice workflow reads tag names
#      and nothing else.
#
# The kit it runs against is built here: this checkout's starter-kit/ committed
# as release 9.0.0, then changed and committed as 9.1.0. So the suite needs no
# tag of this repository's and no history.
#
# Usage: test-kit-status.sh [-v]
set -uo pipefail
VERBOSE=0; [ "${1:-}" = "-v" ] && VERBOSE=1
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KIT_ROOT="$(cd "$KIT_DIR/.." && pwd)"
WORK="$(mktemp -d)"; trap '[ "$VERBOSE" -eq 1 ] || rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()   { printf '  ok   — %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL — %s\n' "$1"; fail=$((fail + 1)); }
# grep -q leaves at its first hit, and under pipefail that fails the pipeline
# feeding it. This reads to the end.
q() { grep "$@" >/dev/null; }

if [ ! -f "$KIT_DIR/bootstrap.sh" ] || [ "$(basename "$KIT_DIR")" != starter-kit ]; then
  echo "SKIP: runs only from the kit itself (starter-kit/ beside its README and bootstrap.sh)"
  exit 0
fi

# Git may use no transport but local files: a fetch from anywhere else fails
# the command that tried it.
export GIT_ALLOW_PROTOCOL=file
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

fresh_repo() { # $1 = dir
  mkdir -p "$1"; git -C "$1" init -q -b main
  git -C "$1" config user.email t@example.invalid; git -C "$1" config user.name t
  git -C "$1" config commit.gpgsign false
}
commit_all() { git -C "$1" add -A >/dev/null 2>&1; git -C "$1" commit -q -m "$2" >/dev/null 2>&1; }

# --- a kit with two releases --------------------------------------------------
K="$WORK/kit"; fresh_repo "$K"
( cd "$KIT_ROOT" && tar -cf - --exclude=__pycache__ starter-kit AGENTIC-ENGINEERING-GUIDE.md ) | tar -xf - -C "$K"
cat > "$K/CHANGELOG.md" <<'MD'
# Changelog

## [Unreleased]

## [9.0.0] — 2026-01-01

### Added

- The first release of the test kit.
MD
commit_all "$K" "release 9.0.0"; git -C "$K" tag v9.0.0
V900="$(git -C "$K" rev-parse HEAD)"
# 9.1.0 changes a rule, a script and a skill, and says so in its changelog.
printf '\nA sentence release 9.1.0 added.\n' >> "$K/starter-kit/rules/working-principles.md"
printf '\n# release 9.1.0\n' >> "$K/starter-kit/scripts/check-registry-ids.sh"
printf '\n# release 9.1.0\n' >> "$K/starter-kit/scripts/graph_tool.py"
printf '\nA line release 9.1.0 added.\n' >> "$K/starter-kit/skills/semver/SKILL.md"
cat > "$K/CHANGELOG.md" <<'MD'
# Changelog

## [Unreleased]

## [9.1.0] — 2026-02-01

### Added

- A sentence in the working principles.

### Changed

- **Breaking:** the identifier gate reads one more line.
- The graph tool carries a comment.

### Fixed

- The semver skill says one more thing.

## [9.0.0] — 2026-01-01

### Added

- The first release of the test kit.
MD
commit_all "$K" "release 9.1.0"; git -C "$K" tag v9.1.0
V910="$(git -C "$K" rev-parse HEAD)"
# The same kit, checked out at the older release: what an adopter installed from.
K0="$WORK/kit-9.0.0"; git clone -q "$K" "$K0" 2>/dev/null; git -C "$K0" checkout -q v9.0.0 2>/dev/null
STATUS="$K/starter-kit/kit-status.sh"
RECORD=.starter-kit-version
field() { sed -n "s/^$2:[[:space:]]*//p" "$1/$RECORD" 2>/dev/null | head -1; }
# The lines of one class in the report: from its heading to the next one.
class() { printf '%s\n' "$1" | awk -v want="$2" '/^  [a-z]/ { on = (index($0, "  " want) == 1) } on && /^    /'; }

echo "=== a first install records the kit it came from, on every tool ==="
for tool in claude agents cursor copilot; do
  R="$WORK/first-$tool"; fresh_repo "$R"
  "$K0/starter-kit/bootstrap.sh" --tool "$tool" --target "$R" > "$WORK/first-$tool.log" 2>&1 < /dev/null
  [ "$(field "$R" version)" = 9.0.0 ] && [ "$(field "$R" commit)" = "$V900" ] && [ "$(field "$R" tool)" = "$tool" ] \
    && ok "$tool: $RECORD names release 9.0.0, the kit's commit and the tool" \
    || bad "$tool: $RECORD is missing or wrong: $(grep -v '^#' "$R/$RECORD" 2>/dev/null | tr '\n' ' ')"
done
R="$WORK/first-claude"; commit_all "$R" "install the kit"
q "$RECORD" "$WORK/first-claude.log" \
  && ok "the installer lists the record among what it installed" || bad "the installer's output never names $RECORD"
( cd "$R" && make lint > "$WORK/first-lint.log" 2>&1 ) \
  && ok "and the install lints green with the record in it" \
  || { bad "an install with a record fails its lint:"; grep -E '^FAIL|Error' "$WORK/first-lint.log" | head -3 | sed 's/^/         /'; }

echo "=== the report: recorded, available, what changed, which files differ ==="
out="$("$STATUS" --target "$R" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | q '^Recorded: *9\.0\.0' && printf '%s\n' "$out" | q '^Available: *9\.1\.0' \
  && ok "it names the recorded release and the available one" \
  || bad "the report (exit $rc) lacks the two versions: $(printf '%s' "$out" | head -4 | tr '\n' '|' | cut -c1-200)"
printf '%s\n' "$out" | q 'A sentence in the working principles' && printf '%s\n' "$out" | q 'The semver skill says one more thing' \
  && ! printf '%s\n' "$out" | q 'The first release of the test kit' \
  && ok "it prints the changelog entries after the recorded release, and none from it or before" \
  || bad "the changelog between the two releases is not what the report prints"
first_entry="$(printf '%s\n' "$out" | grep -n 'the identifier gate reads one more line' | head -1 | cut -d: -f1)"
added_entry="$(printf '%s\n' "$out" | grep -n 'A sentence in the working principles' | head -1 | cut -d: -f1)"
printf '%s\n' "$out" | grep 'the identifier gate reads one more line' | q 'BREAKING' \
  && [ -n "$first_entry" ] && [ -n "$added_entry" ] && [ "$first_entry" -lt "$added_entry" ] \
  && ok "a breaking entry is marked BREAKING and printed before the others" \
  || bad "the breaking entry is not marked, or not first"
older="$(class "$out" "older kit")"
for f in .claude/rules/working-principles.md scripts/check-registry-ids.sh scripts/graph_tool.py .claude/skills/semver/SKILL.md; do
  printf '%s\n' "$older" | q "    $f\$" || bad "the report does not list $f as the older kit's"
done
[ "$(printf '%s\n' "$older" | grep -c '^    ')" -eq 4 ] \
  && ok "it lists the four files release 9.1.0 changed as the older kit's, and no other" \
  || bad "the older-kit list has $(printf '%s\n' "$older" | grep -c '^    ') entries, not 4"
# A rule the installer gave a paths: header is the kit's text all the same.
head -1 "$R/.claude/rules/shared-registries.md" | q '^---$' && ! printf '%s\n' "$out" | q 'shared-registries' \
  && ok "a rule with a paths: header is compared by the text under it, and is not reported" \
  || bad "the rule with a header is reported as differing, or has no header to begin with"
out0="$("$K0/starter-kit/kit-status.sh" --target "$R" 2>&1)"
printf '%s\n' "$out0" | q -i 'up to date' && [ -z "$(class "$out0" "older kit")" ] \
  && ok "control — against the kit it was installed from, the same repository is up to date" \
  || bad "against its own kit the install is not reported up to date"

echo "=== a file the adopter changed is theirs, and said to be ==="
printf '\n# ours\n' >> "$R/scripts/check-kb-shape.sh"; commit_all "$R" "our change to a kit script"
out="$("$STATUS" --target "$R" 2>&1)"
class "$out" "changed here" | q '    scripts/check-kb-shape.sh$' \
  && ok "a kit file that matches neither kit is listed as changed here" \
  || bad "the adopter's change to a kit script is not listed as changed here"

echo "=== a half-done upgrade cannot make the record false ==="
"$K/starter-kit/bootstrap.sh" --target "$R" > "$WORK/rerun.log" 2>&1 < /dev/null
[ "$(field "$R" version)" = 9.0.0 ] && [ "$(field "$R" commit)" = "$V900" ] \
  && ok "a re-run of the newer installer leaves the record as it was" \
  || bad "a re-run changed the record to $(field "$R" version)"
cp "$K/starter-kit/scripts/graph_tool.py" "$R/scripts/graph_tool.py"
out="$("$STATUS" --target "$R" 2>&1)"
printf '%s\n' "$out" | q -i 'partial' \
  && ok "with one file copied, the report calls the upgrade partial" || bad "a partial upgrade is not named as one"
before="$(cat "$R/$RECORD")"
"$STATUS" --target "$R" --record > "$WORK/record-partial.log" 2>&1; rc=$?
[ "$rc" -ne 0 ] && [ "$(cat "$R/$RECORD")" = "$before" ] && q 'scripts/check-registry-ids.sh' "$WORK/record-partial.log" \
  && ok "--record refuses while files are still the older kit's, names them, and writes nothing" \
  || bad "--record on a partial upgrade exited $rc, or changed the record"
# Finish it: the remaining kit files, and the rule through upgrade-rules.sh.
cp "$K/starter-kit/scripts/check-registry-ids.sh" "$R/scripts/"
cp "$K/starter-kit/skills/semver/SKILL.md" "$R/.claude/skills/semver/SKILL.md"
"$K/starter-kit/upgrade-rules.sh" --target "$R" --apply working-principles >/dev/null 2>&1
"$STATUS" --target "$R" --record > "$WORK/record-done.log" 2>&1; rc=$?
[ "$rc" -eq 0 ] && [ "$(field "$R" version)" = 9.1.0 ] && [ "$(field "$R" commit)" = "$V910" ] && [ "$(field "$R" tool)" = claude ] \
  && ok "with every kit file brought over, --record writes release 9.1.0 and its commit" \
  || { bad "--record after a finished upgrade exited $rc:"; tail -4 "$WORK/record-done.log" | sed 's/^/         /'; }
q 'scripts/check-kb-shape.sh' "$WORK/record-done.log" \
  && ok "and says which file it accepted as changed here" || bad "--record does not name the file it accepted as the adopter's"
out="$("$STATUS" --target "$R" 2>&1)"
printf '%s\n' "$out" | q -i 'up to date' && ! printf '%s\n' "$out" | q 'A sentence in the working principles' \
  && ok "the report is then up to date, with no changelog left to read" || bad "after --record the report is not up to date"

echo "=== a record that the files contradict is reported ==="
R2="$WORK/claimed"; fresh_repo "$R2"
"$K0/starter-kit/bootstrap.sh" --tool agents --target "$R2" >/dev/null 2>&1 < /dev/null
printf 'version: 9.1.0\ncommit: %s\ntool: agents\n' "$V910" > "$R2/$RECORD"
out="$("$STATUS" --target "$R2" 2>&1)"
printf '%s\n' "$out" | q -i 'does not hold' && printf '%s\n' "$out" | q '9\.0\.0' \
  && ok "a record edited to name 9.1.0 over 9.0.0's files does not hold, and the report names the release they match" \
  || bad "a false record is not reported: $(printf '%s\n' "$out" | grep -i 'record' | head -3 | tr '\n' '|' | cut -c1-200)"

echo "=== an install without a record ==="
R3="$WORK/unrecorded"; fresh_repo "$R3"
"$K0/starter-kit/bootstrap.sh" --tool copilot --target "$R3" >/dev/null 2>&1 < /dev/null
git -C "$R3" rm -q --cached "$RECORD" >/dev/null 2>&1; mv "$R3/$RECORD" "$WORK/set-aside"
commit_all "$R3" "an install from before the record"
"$K/starter-kit/bootstrap.sh" --target "$R3" > "$WORK/unrecorded-rerun.log" 2>&1 < /dev/null
[ ! -e "$R3/$RECORD" ] && q 'kit-status.sh' "$WORK/unrecorded-rerun.log" \
  && ok "a re-run does not invent a record for an existing install, and names the command that writes one" \
  || bad "a re-run wrote a record into an existing install, or does not say how to get one"
out="$("$STATUS" --target "$R3" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | q -i 'no record' && printf '%s\n' "$out" | q 'v9\.0\.0' \
  && printf '%s\n' "$out" | q -- '--record --as v9.0.0' \
  && ok "the report says there is no record, names the release the files match, and the command that records it" \
  || bad "the report on an unrecorded install (exit $rc): $(printf '%s' "$out" | head -5 | tr '\n' '|' | cut -c1-220)"
printf '%s\n' "$out" | q 'A sentence in the working principles' \
  && ok "and still shows what changed since that release" || bad "an unrecorded install gets no changelog"
"$STATUS" --target "$R3" --record > "$WORK/unrecorded-record.log" 2>&1; rc=$?
[ "$rc" -ne 0 ] && [ ! -e "$R3/$RECORD" ] && q 'v9\.0\.0' "$WORK/unrecorded-record.log" \
  && ok "--record refuses to call it the available kit while its files match an older release" \
  || bad "--record on an unrecorded older install exited $rc, or wrote a record"
"$STATUS" --target "$R3" --record --as v9.0.0 > "$WORK/unrecorded-as.log" 2>&1; rc=$?
[ "$rc" -eq 0 ] && [ "$(field "$R3" version)" = 9.0.0 ] && [ "$(field "$R3" commit)" = "$V900" ] && [ "$(field "$R3" tool)" = copilot ] \
  && ok "--record --as v9.0.0 writes the record of the release it has, with the tool it found" \
  || { bad "--record --as v9.0.0 exited $rc:"; tail -3 "$WORK/unrecorded-as.log" | sed 's/^/         /'; }
out="$( cd "$R3" && make -s kit-status 2>&1 )"
printf '%s\n' "$out" | grep '^version: 9\.0\.0' >/dev/null \
  && ok "'make kit-status' without a kit prints the record" || bad "'make kit-status' does not print the record"
out="$( cd "$R3" && make -s kit-status KIT="$K" 2>&1 )"
printf '%s\n' "$out" | grep '^Available: *9\.1\.0' >/dev/null \
  && ok "'make kit-status KIT=<checkout>' runs the kit's report" || bad "'make kit-status KIT=…' does not run the report"

echo "=== every file the installer ships is classified ==="
for tool in claude agents; do
  R4="$WORK/all-$tool"; fresh_repo "$R4"
  "$K/starter-kit/bootstrap.sh" --tool "$tool" --with-meta --with-coach-schedule --with-upgrade-notice --target "$R4" >/dev/null 2>&1 < /dev/null
  out="$("$STATUS" --target "$R4" 2>&1)"
  ! printf '%s\n' "$out" | q -i 'unclassified' && printf '%s\n' "$out" | q -i 'up to date' \
    && ok "$tool: a full install has no file the report cannot place as the kit's or the project's" \
    || bad "$tool: unclassified files: $(printf '%s\n' "$out" | grep -i -A5 'unclassified' | tr '\n' ' ' | cut -c1-200)"
done

echo "=== no network ==="
[ -f "$KIT_DIR/kit_status.py" ] && ! grep -nE '^\s*(import|from)\s+(urllib|http|socket|ssl|ftplib|smtplib|requests)' "$KIT_DIR/kit_status.py" \
  && ok "the report's code imports nothing that opens a connection (and ran above with git confined to local files)" \
  || bad "kit_status.py is missing, or imports a network module"

echo "=== the upgrade notice is a workflow only an adopter who asked for it gets ==="
W=.github/workflows/kit-upgrade-notice.yml
[ ! -e "$WORK/first-claude/$W" ] && q 'with-upgrade-notice' "$WORK/first-claude.log" \
  && ok "without the flag no notice workflow is installed, and the next steps say how to add it" \
  || bad "the notice workflow was installed unasked, or the next steps never mention --with-upgrade-notice"
R5="$WORK/all-agents"
if [ -f "$R5/$W" ]; then
  ok "--with-upgrade-notice installs $W"
  ! q -E 'contents: write|pull-requests: write' "$R5/$W" && ! q -E 'git clone|curl |wget ' "$R5/$W" \
    && ok "it cannot push or open a pull request, and fetches no code: it lists tag names" \
    || bad "the notice workflow asks for write access to code, or downloads something"
  ( cd "$R5" && ./scripts/check-ci-lint-coverage.sh > "$WORK/notice-cov.log" 2>&1 ) \
    && ok "the CI-coverage gate passes beside it" || bad "the CI-coverage gate fails with the notice workflow installed"
  # The step that decides, run as the workflow would run it, against the test kit.
  "$KIT_DIR/scripts/python.sh" -B - "$R5/$W" > "$WORK/compare.sh" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"- name: Compare the record with the kit's releases\n(?:.*\n)*?\s+run: \|\n((?:(?: {10}.*)?\n)+)", text)
sys.stdout.write("".join(l[10:] if l.strip() else "\n" for l in m.group(1).splitlines(True)) if m else "exit 99\n")
PY
  notice() { ( cd "$1" && KIT_REPOSITORY="$K" GITHUB_OUTPUT="$WORK/gh-out" bash -e "$WORK/compare.sh" >/dev/null 2>&1 ); echo "$?:$(tr '\n' ' ' < "$WORK/gh-out")"; }
  : > "$WORK/gh-out"; r="$(notice "$WORK/unrecorded")"
  case "$r" in 0:*"newer=9.1.0"*) ok "its compare step finds release 9.1.0 for a repository that records 9.0.0" ;;
    *) bad "the compare step on a 9.0.0 record gave: $r" ;; esac
  : > "$WORK/gh-out"; r="$(notice "$WORK/first-claude")"
  case "$r" in 0:*"newer=9."*) bad "the compare step reports a newer release for a repository that records the newest: $r" ;;
    0:*) ok "control — and nothing for one that records 9.1.0" ;; *) bad "the compare step failed on an up-to-date record: $r" ;; esac
  mv "$R5/$RECORD" "$WORK/set-aside-2"; : > "$WORK/gh-out"; r="$(notice "$R5")"
  case "$r" in 0:*"newer="*) bad "the compare step reports a release for a repository with no record: $r" ;;
    0:*) ok "and nothing where there is no record to compare" ;; *) bad "the compare step failed without a record: $r" ;; esac
else
  bad "--with-upgrade-notice did not install $W"
fi

echo ""; echo "=== $pass passed, $fail failed ==="
[ "$VERBOSE" -eq 1 ] && echo "scratch repos kept in $WORK"
[ "$fail" -eq 0 ] || exit 1
