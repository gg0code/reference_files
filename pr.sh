#!/usr/bin/env bash
# pr.sh - open the PR for the current branch, or merge it and run the after-merge checks.   VERSION: v1
#
#   bash scripts/pr.sh           push and open the PR (refuses until docs/reviews/<ID>.md says APPROVE)
#   bash scripts/pr.sh merge     after YOUR review of the PR (asks you to confirm; YES=1 skips the question):
#                                wait for CI, squash-merge, then on main run the full suite, show CI on main,
#                                and run req_status.sh --strict
#
# The ID (REQ-00X / BUG-00X) comes from the branch name, the Issue number from docs/TASKS.md
# (or GitHub). FORCE=1 opens a PR without an APPROVE review and says so in the PR body.
set -uo pipefail

ok()   { echo "    OK    : $*"; }
info() { echo "    ..    : $*"; }
warn() { echo "    WARN  : $*"; }
err()  { echo "    ERROR : $*" >&2; }
die()  { err "$*"; exit 1; }

case "${1:-}" in -h|--help|help) sed -n '2,11p' "$0"; exit 0 ;; esac

command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 || die "gh is not installed or not authenticated (gh auth login)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repo"
cd "$ROOT" || die "cannot enter $ROOT"
BASE="main"; git rev-parse --verify -q main >/dev/null || BASE="master"

BRANCH="$(git branch --show-current)"
ID="$(echo "$BRANCH" | grep -oE '(REQ|BUG)-[0-9]{3}' | head -1)"
[ -n "$ID" ] || die "not on a REQ or BUG branch (you are on '$BRANCH'). Start work with: bash scripts/start.sh"
ISSUE="$(grep -E "^[[:space:]]*- \[[ x]\] $ID \(#[0-9]+\)" docs/TASKS.md 2>/dev/null | head -1 | sed -nE 's/.*\(#([0-9]+)\).*/\1/p')"
[ -n "$ISSUE" ] || ISSUE="$(gh issue list --search "$ID in:title" --state all --json number --jq '.[0].number // empty' 2>/dev/null)"
[ -n "$ISSUE" ] || die "no Issue number found for $ID (TASKS.md line or a GitHub Issue titled '$ID: ...')"
TITLE="$(grep -E "^[[:space:]]*- \[[ x]\] $ID \(#[0-9]+\)" docs/TASKS.md 2>/dev/null | head -1 | sed -nE 's/.*\(#[0-9]+\)[[:space:]]*(.*)$/\1/p')"
[ -n "$TITLE" ] || TITLE="$(gh issue view "$ISSUE" --json title --jq .title 2>/dev/null | sed -E "s/^$ID:[[:space:]]*//")"
case "$ID" in REQ-*) KIND="feat"; CLOSE="Implements $ID. Closes #$ISSUE." ;; *) KIND="fix"; CLOSE="Fixes #$ISSUE ($ID)." ;; esac
REVIEW="docs/reviews/$ID.md"

existing_pr() { gh pr list --head "$BRANCH" --state open --json number --jq '.[0].number // empty' 2>/dev/null; }

open_pr() {
  local dirty vl round note=""
  dirty="$(git status --porcelain | grep -vE ' (PROMPT\.md|FAILURES\.txt|\.loop-[^ ]*)$')"
  [ -z "$dirty" ] || die "uncommitted changes - commit them first:
$dirty"
  vl="$( [ -f "$REVIEW" ] && grep -m1 -v '^[[:space:]]*$' "$REVIEW")"
  case "$vl" in
    "Verdict: APPROVE"*) round="$(echo "$vl" | grep -oE 'round [0-9]+')"; ok "review: $vl" ;;
    *)
      if [ "${FORCE:-0}" = 1 ]; then
        warn "no APPROVE review ($REVIEW: ${vl:-missing}) - opening anyway because FORCE=1"
        note="WARNING: opened without a reviewer APPROVE (FORCE=1). Review file: ${vl:-missing}."
      else
        die "no reviewer APPROVE yet ($REVIEW: ${vl:-missing}). In the claude pane type: review"
      fi ;;
  esac
  local pr; pr="$(existing_pr)"
  git push -q -u origin "$BRANCH" || die "git push failed"
  if [ -n "$pr" ]; then ok "pushed; PR #$pr already open: $(gh pr view "$pr" --json url --jq .url)"; return 0; fi
  gh pr create --base "$BASE" --head "$BRANCH" --title "${KIND}(${ID}): ${TITLE}" --body "${CLOSE}

Review: ${REVIEW} (${vl:-none}${round:+, $round}).
${note}

Checklist:
- [ ] Full suite green locally and in CI
- [ ] Regression gate green
- [ ] Reviewer verdict APPROVE (read ${REVIEW} first)
- [ ] File headers, function doc blocks and READMEs present
- [ ] Architecture row and test plan still match the code
- [ ] Hygiene fixes in their own chore(hygiene) commits" || die "gh pr create failed"
  echo ""
  echo "  NEXT: review the PR on GitHub (review file first, then the diff)."
  echo "        When you are happy: bash scripts/pr.sh merge"
}

detect_test_cmd() {
  local t=""
  if [ -n "${TEST_CMD:-}" ]; then echo "$TEST_CMD"; return; fi
  if [ -f package.json ]; then t="npm test"
  elif [ -f pyproject.toml ] || [ -f pytest.ini ] || [ -f requirements.txt ] || compgen -G "tests/test_*.py" >/dev/null 2>&1; then t="pytest"
  elif [ -f Cargo.toml ]; then t="cargo test"
  elif [ -f go.mod ]; then t="go test ./..."
  fi
  if [ -n "$t" ] && [ -f scripts/doclint.sh ]; then t="bash scripts/doclint.sh && $t"; fi
  echo "$t"
}

merge_pr() {
  local pr ans tc
  pr="$(existing_pr)"; [ -n "$pr" ] || die "no open PR for $BRANCH. Open one with: bash scripts/pr.sh"
  if [ "${YES:-0}" != 1 ]; then
    [ -t 0 ] || die "merging needs your confirmation: run it in a terminal, or YES=1 bash scripts/pr.sh merge"
    read -r -p "    Have YOU reviewed PR #$pr (review file and diff)? Type yes to merge: " ans
    [ "$ans" = "yes" ] || die "not merged. Review the PR first."
  fi
  info "waiting for CI on PR #$pr ..."
  gh pr checks "$pr" --watch --fail-fast || die "CI is not green on PR #$pr - not merged"
  gh pr merge "$pr" --squash --delete-branch || die "merge failed"
  ok "PR #$pr merged; Issue #$ISSUE closes"
  git checkout -q "$BASE" && git pull -q --ff-only || die "could not update $BASE"

  echo ""; echo "==> After-merge checks on $BASE (CLAUDE.md section 7)"
  tc="$(detect_test_cmd)"
  if [ -z "$tc" ]; then warn "cannot detect the test command; set TEST_CMD=... and run the full suite yourself"
  elif bash -c "$tc" >/tmp/pr-sh-tests.$$ 2>&1; then ok "full suite green on $BASE ($tc)"; rm -f /tmp/pr-sh-tests.$$
  else
    tail -15 /tmp/pr-sh-tests.$$; rm -f /tmp/pr-sh-tests.$$
    err "MAIN IS RED after merging $ID. Revert first, diagnose second:"
    echo "        git checkout -b revert/$ID && git revert -m 1 \$(git log -1 --format=%H) && bash scripts/pr.sh"
    exit 1
  fi
  info "CI on $BASE: $(gh run list --branch "$BASE" --limit 1 --json status,conclusion --jq '.[0] | "\(.status) \(.conclusion)"' 2>/dev/null) (check again in a few minutes if still in progress)"
  if bash scripts/req_status.sh --strict >/dev/null 2>&1; then ok "traceability: every merged REQ has tests"
  else err "req_status.sh --strict failed: a merged REQ has no tests. Run: bash scripts/req_status.sh"; exit 1; fi
  echo ""
  echo "  NEXT (claude pane): paste the traceability audit prompt, then: wrap up"
  echo "  Then start the next requirement: bash scripts/start.sh"
}

case "${1:-}" in
  "")    open_pr ;;
  merge) merge_pr ;;
  *)     die "unknown argument '$1' (try --help)" ;;
esac
