# Acceptance tests on BSD sed

## Fixed

- The two acceptance tests now pass on BSD/macOS sed. They used GNU's
  `sed -i 's/…/'`, which BSD sed reads as "backup suffix = the script", and both
  call sites in `test-parallel-merge.sh` sent stderr to `/dev/null` with
  `|| true`. The template placeholders were therefore never filled, the
  identifier gate rejected them exactly as designed, and the resulting failures
  read as defects in the mechanism under test rather than in the test's own
  setup: `test-parallel-merge.sh` reported 25 passed / 2 failed and
  `test-brownfield-adoption.sh` 15 passed / 2 failed. Both are now 27/0 and
  17/0. The replacement writes through a temp file rather than using `-i.bak`,
  so no backup file is left inside a fragment directory to be picked up as an
  entry.
- `bootstrap.sh` no longer tells a user with a correctly chained `lint` target
  that it "checks nothing of the registry layer". `make -n … | grep -q` exits at
  its first match, and under `set -o pipefail` the SIGPIPE that then kills `make`
  becomes the pipeline's status (141), so the check reported the opposite of
  what it had found. The same shape produced `test-brownfield-adoption.sh`'s
  "lint still does not run the gates" failure. Both now capture the output
  before matching it.
