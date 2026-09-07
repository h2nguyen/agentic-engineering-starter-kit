#!/usr/bin/env bash
# Enforces: every template the guide embeds is byte-identical to the kit file it
# names — see AGENTIC-ENGINEERING-GUIDE.md § 3 ("Templates are inline … and also
# shipped as files in starter-kit/") and § 5.4 (duplicated content drifts).
#
# Repository-only: it checks this repository's own guide, so bootstrap.sh does
# not install it and it is not part of the kit. That is also why it lives in
# scripts/ here rather than in starter-kit/scripts/.
#
# What counts as a template: a fenced block introduced by a bold lead-in that
# says "template" and names a kit file —
#     **Template** (starter kit: `rules/_rule-template.md`)
#     **`settings.json` template** (starter kit: `settings.json.template`)
# A lead-in that says something else, such as `**Minimal hook** (starter kit:
# …)`, marks an illustration: the gate lists it and never compares it.
#
# Usage: check-guide-templates.sh [guide] [kit-dir]
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

GUIDE="${1:-AGENTIC-ENGINEERING-GUIDE.md}"
KIT="${2:-starter-kit}"

python3 - "$GUIDE" "$KIT" <<'PY'
import difflib, pathlib, re, sys

guide_path, kit = sys.argv[1], pathlib.Path(sys.argv[2])
lines = pathlib.Path(guide_path).read_text(encoding="utf-8").splitlines()
LABEL = re.compile(r"\(starter kit: `([^`]+)`")
TEMPLATE = re.compile(r"^\*\*[^*]*[Tt]emplate[^*]*\*\*")
FENCE = re.compile(r"^(`{3,})")

fail = 0
checked = 0
illustrations = []
i = 0
while i < len(lines):
    m = LABEL.search(lines[i])
    if not m:
        i += 1
        continue
    path, label_line = m.group(1), i + 1
    j = i + 1
    while j < len(lines) and not FENCE.match(lines[j]):
        j += 1
    if j == len(lines):
        print(f"FAIL: {guide_path}:{label_line} — names {path} but no fenced block follows")
        fail = 1
        break
    fence = FENCE.match(lines[j]).group(1)
    k = j + 1
    while k < len(lines) and lines[k] != fence:
        k += 1
    block = lines[j + 1:k]
    if not TEMPLATE.match(lines[i]):
        illustrations.append((label_line, path))
        i = k + 1
        continue
    kit_file = kit / path
    if not kit_file.exists():
        print(f"FAIL: {guide_path}:{label_line} — names {kit_file}, which does not exist")
        fail = 1
        i = k + 1
        continue
    expected = kit_file.read_text(encoding="utf-8").splitlines()
    checked += 1
    if block != expected:
        fail = 1
        print(f"FAIL: {guide_path}:{j + 2} — the embedded copy of {kit_file} has drifted from the file:")
        diff = difflib.unified_diff(expected, block, str(kit_file), f"{guide_path} (embedded)", lineterm="")
        for d in list(diff)[:40]:
            print("    " + d)
    i = k + 1

for label_line, path in illustrations:
    print(f"note: {guide_path}:{label_line} cites {path} as an illustration, not a template — not compared")
if fail:
    print("")
    print("The kit file is canonical. Paste it into the fenced block (keep the fence lines),")
    print("or, if the guide deliberately shows an abridged form, change the lead-in so it")
    print("does not say 'template'. See AGENTIC-ENGINEERING-GUIDE.md § 3 and § 5.4.")
    sys.exit(1)
print(f"OK: {checked} embedded template(s) in {guide_path} match their kit files")
PY
