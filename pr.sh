#!/usr/bin/env bash
# pr.sh - open the PR for the current branch, or merge it and run the after-merge checks.   VERSION: v4 (kit v3.13)
# v3: runs scripts/integrity.sh before opening a PR; merge refuses while main has no branch protection
#     (scripts/protect.sh) unless you set ALLOW_UNPROTECTED=1 yourself.
# v4: runs bash scripts/gate.sh --full before opening the PR and refuses when it is red (integrity runs inside it).
#     The PR body carries the evidence (the command, its last 40 lines, the lock sha, docs/tests/<ID>.md) and a
#     "Boundary changes" list from docs/RULES.md section 10; a boundary hit adds the label needs-human-review,
#     which autopilot never auto-merges. Re-running refreshes the body and label. PR_NOTE="..." adds a line.
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

# kit_event <kind> <id> <message> [extra-json]: one line in .kit/events.jsonl for the dashboard (scripts/dashboard.py)
kit_event() {
  local m; m="$(printf '%s' "${3:-}" | tr -d '\n\r\t' | sed 's/\\/\\\\/g; s/"/\\"/g')"
  mkdir -p .kit 2>/dev/null && printf '{"ts":"%s","src":"%s","kind":"%s","id":"%s","msg":"%s"%s}\n' \
    "$(date +%Y-%m-%dT%H:%M:%S%z)" "$(basename "$0" .sh)" "$1" "${2:-}" "$m" "${4:+,$4}" >> .kit/events.jsonl 2>/dev/null || true
}

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

# boundary_res: the extended regexes in docs/RULES.md "## 10. Boundaries" (the first `...` of each bullet)
boundary_res() {
  awk '/^##[[:space:]]+[0-9]*\.?[[:space:]]*Boundaries/{on=1;next} /^##[[:space:]]/{on=0} on && /^[[:space:]]*-[[:space:]]*`/' docs/RULES.md 2>/dev/null \
    | sed -nE 's/^[[:space:]]*-[[:space:]]*`([^`]+)`.*/\1/p'
}

open_pr() {
  local dirty vl round note="" gate_cmd="bash scripts/gate.sh --full" gate_out gate_tail lock risk mb boundary="" re url body pr
  dirty="$(git status --porcelain | grep -vE ' (PROMPT\.md|FAILURES\.txt|\.loop-[^ ]*)$')"
  [ -z "$dirty" ] || die "uncommitted changes - commit them first:
$dirty"
  vl="$( [ -f "$REVIEW" ] && grep -m1 -v '^[[:space:]]*$' "$REVIEW")"
  case "$vl" in
    "Verdict: APPROVE"*) round="$(echo "$vl" | grep -oE 'round [0-9]+')"; ok "review: $vl"
      grep -q '^## Walkthrough' "$REVIEW" || warn "no walkthrough in $REVIEW yet: in the claude pane type 'explain' (CLAUDE.md section 5 step 8)" ;;
    *)
      if [ "${FORCE:-0}" = 1 ]; then
        warn "no APPROVE review ($REVIEW: ${vl:-missing}) - opening anyway because FORCE=1"
        note="WARNING: opened without a reviewer APPROVE (FORCE=1). Review file: ${vl:-missing}."
      else
        die "no reviewer APPROVE yet ($REVIEW: ${vl:-missing}). In the claude pane type: review"
      fi ;;
  esac

  # evidence: the full gate (integrity included), run now on exactly what is pushed
  gate_out="$(mktemp)"
  if [ -f scripts/gate.sh ]; then
    info "running: $gate_cmd"
    if ! bash scripts/gate.sh --full >"$gate_out" 2>&1; then
      tail -40 "$gate_out"; rm -f "$gate_out"
      die "the gate is red ($gate_cmd) - fix it before opening the PR"
    fi
    ok "gate green: $gate_cmd"
  else
    gate_cmd="bash scripts/integrity.sh"
    bash scripts/integrity.sh >"$gate_out" 2>&1 || { cat "$gate_out"; rm -f "$gate_out"; die "integrity check failed: this branch weakens tests or the gate without a plan exception"; }
  fi
  gate_tail="$(tail -40 "$gate_out")"; rm -f "$gate_out"

  # lock and risk tier from the committed plan
  risk="$(git show "HEAD:docs/plans/$ID.md" 2>/dev/null | sed -nE 's/^Risk:[[:space:]]*([A-Za-z]+).*/\1/p' | head -1 | tr '[:upper:]' '[:lower:]')"
  lock="$(git show "HEAD:docs/plans/$ID.md" 2>/dev/null | sed -nE 's/^Tests locked:[[:space:]]*([0-9a-f]{7,40}).*/\1/p' | head -1)"

  # boundary changes (docs/RULES.md section 10)
  mb="$(git merge-base "$(git rev-parse --verify -q "origin/$BASE" >/dev/null && echo "origin/$BASE" || echo "$BASE")" HEAD)"
  while IFS= read -r re; do
    [ -n "$re" ] || continue
    boundary="${boundary}$(git diff --name-only "$mb" HEAD | grep -E -- "$re")
"
  done <<< "$(boundary_res)"
  boundary="$(printf '%s' "$boundary" | grep . | sort -u)"

  git push -q -u origin "$BRANCH" || die "git push failed"
  url="$(gh repo view --json url --jq .url 2>/dev/null)"
  body="${CLOSE}

Review: ${REVIEW} (${vl:-none}${round:+, $round}).
${note}${PR_NOTE:+
${PR_NOTE}}

## Evidence
- Risk tier: ${risk:-standard (no Risk line)}
- Tests locked: $( [ -n "$lock" ] && echo "\`$lock\` (read and locked by the user before the code)" || echo "no lock$( [ "${risk:-standard}" = light ] && echo " (light plan)")")
- Test table: $( [ -f "docs/tests/$ID.md" ] && echo "[docs/tests/$ID.md](${url}/blob/${BRANCH}/docs/tests/$ID.md)" || echo "none")
- Gate: \`${gate_cmd}\` green

<details><summary>Last 40 lines of <code>${gate_cmd}</code></summary>

\`\`\`
${gate_tail}
\`\`\`
</details>

## Boundary changes
$( [ -n "$boundary" ] && printf '%s\n' "$boundary" | sed 's/^/- `/; s/$/`/' && echo "" && echo "These match docs/RULES.md section 10 (Boundaries): label needs-human-review, never auto-merged.$( [ "${risk:-standard}" = light ] && echo " The plan says Risk: light - check the tier.")" || echo "None.")

Checklist:
- [ ] Quality gate green locally (bash scripts/gate.sh --full, above) and in CI
- [ ] Regression gate green
- [ ] Reviewer verdict APPROVE (read ${REVIEW} first, walkthrough at its end)
- [ ] Tests match docs/tests/${ID}.md and were not changed after the lock (integrity I6)
- [ ] File headers, function doc blocks and READMEs present
- [ ] Architecture row and test plan still match the code
- [ ] Hygiene fixes in their own chore(hygiene) commits"

  local label=()
  if [ -n "$boundary" ]; then
    gh label create needs-human-review --color B60205 --description "Changes boundary files (RULES.md section 10): a human reviews and merges" >/dev/null 2>&1 || true
    label=(--label needs-human-review)
    warn "boundary changes: $(printf '%s' "$boundary" | paste -sd' ' -) - label needs-human-review"
  fi
  pr="$(existing_pr)"
  if [ -n "$pr" ]; then
    gh pr edit "$pr" --body "$body" ${label[@]+"${label[@]/--label/--add-label}"} >/dev/null || warn "could not refresh the body of PR #$pr"
    ok "pushed; PR #$pr already open (body and label refreshed): $(gh pr view "$pr" --json url --jq .url)"; return 0
  fi
  gh pr create --base "$BASE" --head "$BRANCH" --title "${KIND}(${ID}): ${TITLE}" --body "$body" ${label[@]+"${label[@]}"} || die "gh pr create failed"
  echo ""
  kit_event pr_open "$ID" "Ready for your review: pull request opened for $TITLE"
  echo "  NEXT: review the PR on GitHub (review file first, then the diff)."
  echo "        When you are happy: bash scripts/pr.sh merge"
}

detect_test_cmd() {
  local t=""
  if [ -f scripts/gate.sh ] && [ "${NO_GATE:-0}" != 1 ]; then echo "bash scripts/gate.sh --full"; return; fi   # TEST_CMD becomes its test step
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
  if ! gh api "repos/{owner}/{repo}/branches/${BASE}/protection" >/dev/null 2>&1; then
    if [ "${ALLOW_UNPROTECTED:-0}" = 1 ]; then
      warn "$BASE has no branch protection - merging anyway because ALLOW_UNPROTECTED=1"
    else
      die "$BASE has no branch protection on GitHub, so nothing but this script stands between an agent and main.
            Turn it on: bash scripts/protect.sh   (or, knowingly: ALLOW_UNPROTECTED=1 bash scripts/pr.sh merge)"
    fi
  fi
  if [ "${YES:-0}" != 1 ]; then
    [ -t 0 ] || die "merging needs your confirmation: run it in a terminal, or YES=1 bash scripts/pr.sh merge"
    read -r -p "    Have YOU reviewed PR #$pr (review file and diff)? Type yes to merge: " ans
    [ "$ans" = "yes" ] || die "not merged. Review the PR first."
  fi
  info "waiting for CI on PR #$pr ..."
  gh pr checks "$pr" --watch --fail-fast || die "CI is not green on PR #$pr - not merged"
  gh pr merge "$pr" --squash --delete-branch || die "merge failed"
  ok "PR #$pr merged; Issue #$ISSUE closes"
  kit_event merged "$ID" "Live: $TITLE is merged into the main code"
  git checkout -q "$BASE" && git pull -q --ff-only || die "could not update $BASE"

  echo ""; echo "==> After-merge checks on $BASE (CLAUDE.md section 7)"
  tc="$(detect_test_cmd)"
  if [ -z "$tc" ]; then warn "cannot detect the test command; set TEST_CMD=... and run the full suite yourself"
  elif bash -c "$tc" >/tmp/pr-sh-tests.$$ 2>&1; then ok "full suite green on $BASE ($tc)"; rm -f /tmp/pr-sh-tests.$$
  else
    tail -15 /tmp/pr-sh-tests.$$; rm -f /tmp/pr-sh-tests.$$
    err "MAIN IS RED after merging $ID. Revert first, diagnose second:"
    kit_event main_red "$ID" "Problem: the main code fails its checks after merging $TITLE - revert needed"
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
