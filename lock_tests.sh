#!/usr/bin/env bash
# lock_tests.sh - lock this REQ's or BUG's tests after YOU have read docs/tests/<ID>.md.   VERSION: v1 (kit v3.13)
#
#   bash scripts/lock_tests.sh          lock the tests of the current feat/ or fix/ branch
#   bash scripts/lock_tests.sh <ID>     the same, and check the branch really is <ID>'s
#
# Run it yourself, in the git pane, after /tests committed the failing tests and you read the table.
# It writes "Tests locked: <sha> - <date>" under the Risk line of docs/plans/<ID>.md and commits that.
# From then on: the hooks block Claude's edits to test files, and integrity.sh I6 (inside the gate, so in
# loop.sh, pr.sh and CI) fails on any changed, deleted, renamed or new test path, unless the plan lists it
# under "Allowed exceptions". loop.sh refuses standard and strict plans without the lock.
#
# Unlock (only you): delete the lock line from the plan and commit it. Re-run /tests, read, lock again.
# Claude never runs this script: the hooks block it, because the lock stands for your reading.
set -uo pipefail

ok()   { echo "    OK    : $*"; }
info() { echo "    ..    : $*"; }
die()  { echo "    ERROR : $*" >&2; exit 1; }

# kit_event <kind> <id> <message>: one line in .kit/events.jsonl for the dashboard (scripts/dashboard.py)
kit_event() {
  local m; m="$(printf '%s' "${3:-}" | tr -d '\n\r\t' | sed 's/\\/\\\\/g; s/"/\\"/g')"
  mkdir -p .kit 2>/dev/null && printf '{"ts":"%s","src":"lock_tests","kind":"%s","id":"%s","msg":"%s"}\n' \
    "$(date +%Y-%m-%dT%H:%M:%S%z)" "$1" "${2:-}" "$m" >> .kit/events.jsonl 2>/dev/null || true
}

case "${1:-}" in -h|--help|help) sed -n '2,14p' "$0"; exit 0 ;; esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repo"
cd "$ROOT" || die "cannot enter $ROOT"
BRANCH="$(git branch --show-current)"
case "$BRANCH" in feat/*|fix/*) ;; *) die "run this on the feat/ or fix/ branch of the REQ or BUG (you are on '$BRANCH')" ;; esac
ID="$(printf '%s' "$BRANCH" | grep -oE '(REQ|BUG)-[0-9]{3}' | head -1)"
[ -n "$ID" ] || die "the branch name '$BRANCH' carries no REQ or BUG ID"
[ -z "${1:-}" ] || [ "$1" = "$ID" ] || die "you asked to lock $1, but this branch is $ID"
PLAN="docs/plans/$ID.md"; TABLE="docs/tests/$ID.md"
[ -f scripts/integrity.sh ] || die "scripts/integrity.sh missing: the lock needs it (copy it from the kit)"

# ---------- preconditions ----------
dirty="$(git status --porcelain | grep -vE ' (PROMPT\.md|FAILURES\.txt|\.loop-[^ ]*)$')"
[ -z "$dirty" ] || die "uncommitted changes - commit or stash them first, so the lock covers exactly what you read:
$dirty"
git cat-file -e "HEAD:$PLAN" 2>/dev/null || die "$PLAN is not committed"
case "$(grep -m1 -v '^[[:space:]]*$' "$PLAN")" in "Status: APPROVED"*) ;; *) die "$PLAN is not APPROVED: approve the plan first" ;; esac
RISK="$(sed -nE 's/^Risk:[[:space:]]*([A-Za-z]+).*/\1/p' "$PLAN" | head -1 | tr '[:upper:]' '[:lower:]')"
case "${RISK:-standard}" in
  light) die "$PLAN is Risk: light - light plans have no /tests step and no lock" ;;
  standard|strict) ;;
  *) die "$PLAN has an unknown Risk tier '$RISK' (light, standard or strict)" ;;
esac
OLD="$(sed -nE 's/^Tests locked:[[:space:]]*([0-9a-f]{7,40}).*/\1/p' "$PLAN" | head -1)"
[ -z "$OLD" ] || die "already locked at $OLD. To change the tests: delete that line in $PLAN, commit, re-run /tests, then lock again"
git cat-file -e "HEAD:$TABLE" 2>/dev/null || die "$TABLE is not committed: in the claude pane run /tests $ID first"

BASE=""; for ref in origin/main main origin/master master; do git rev-parse --verify -q "$ref" >/dev/null && { BASE="$ref"; break; }; done
[ -n "$BASE" ] || die "no main branch found"
MB="$(git merge-base "$BASE" HEAD)" || die "no merge-base with $BASE"
TESTS="$(git diff --name-only "$MB" HEAD | while IFS= read -r p; do bash scripts/integrity.sh --is-test-path "$p" && printf '%s\n' "$p"; done)"
[ -n "$TESTS" ] || die "this branch has no test files yet: in the claude pane run /tests $ID"
SRC="$(git diff --name-only "$MB" HEAD -- src)"
if [ -n "$SRC" ]; then
  if git log --format=%H -S 'Tests locked:' -- "$PLAN" | grep -q .; then
    info "re-lock: src/ already holds code from the earlier lock (allowed after an unlock)"
  else
    die "this branch already changes src/ before its tests were locked - tests come first:
$(printf '%s\n' "$SRC" | sed 's/^/            /')"
  fi
fi

# ---------- lock ----------
SHA="$(git rev-parse HEAD)"
echo ""
echo "  Locking these test files for $ID at ${SHA:0:7} (read $TABLE):"
git diff --stat "$MB" HEAD -- $TESTS | sed 's/^/    /'
LINE="Tests locked: $SHA - $(date +%Y-%m-%d) - read and locked by the user"
if grep -qE '^Risk:' "$PLAN"; then
  awk -v l="$LINE" '{print} /^Risk:/ && !done {print l; done=1}' "$PLAN" > "$PLAN.tmp" && mv "$PLAN.tmp" "$PLAN"
else
  awk -v l="$LINE" '{print} /^Depends on:/ && !done {print "Risk: standard - no Risk line (counts as standard)"; print l; done=1}' "$PLAN" > "$PLAN.tmp" && mv "$PLAN.tmp" "$PLAN"
  grep -q '^Tests locked:' "$PLAN" || { printf '\n%s\n' "$LINE" >> "$PLAN"; }
fi
ISSUE="$(grep -E "^[[:space:]]*- \[[ x]\] $ID \(#[0-9]+\)" docs/TASKS.md 2>/dev/null | head -1 | sed -nE 's/.*\(#([0-9]+)\).*/\1/p')"
git add "$PLAN" && git commit -q -m "docs($ID): lock tests at ${SHA:0:7}${ISSUE:+ (#$ISSUE)}" || die "git commit failed"
ok "locked: $PLAN now says '$LINE'"
kit_event tests_locked "$ID" "Tests read and locked by you: the code must now meet them"
echo ""
echo "  NEXT: bash scripts/loop.sh      (builds the code against the locked tests)"
