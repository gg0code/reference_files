#!/usr/bin/env bash
# autopilot.sh - unattended builder for several REQs in a row.        VERSION: v3
#
# Optional. The normal, attended flow (runbook.md Phase 2) is unchanged; this script
# only automates the steps between your human gates, at the level you choose.
#
#   bash scripts/autopilot.sh                     # next unticked REQs from docs/TASKS.md
#   bash scripts/autopilot.sh REQ-003 REQ-004     # exactly these
#   DRY_RUN=1 bash scripts/autopilot.sh           # show what it would do, change nothing
#
# LEVELS (what runs without you)
#   AUTOPILOT=build        (default, level 1) For each REQ whose plan YOU approved:
#                          branch -> loop -> commit -> reviewer agent -> fix rounds -> push -> PR.
#                          REQs without an approved plan are skipped and listed for you.
#   AUTOPILOT=plan,build   (level 2) Also drafts missing plans; the reviewer agent reviews the
#                          plan, and an agent-approved plan is marked as such in its Status line.
#   AUTO_MERGE=1           (level 3, add to either) Wait for CI, squash-merge, run the after-merge
#                          checks on main, then continue with the next REQ.
#
# SAFETY SETTINGS (environment)
#   MAX_REQS=3         stop after this many REQs
#   MAX_COST=10        stop before the next step once this many USD are spent (needs jq)
#   REVIEW_ROUNDS=2    reviewer rounds per REQ; still CHANGES REQUESTED after this = stop
#   STOP_ON_FAIL=1     stop the whole run at the first REQ that needs you (0 = skip to the next)
#   LOOP_ITERS=        override the loop's iteration cap (default: the plan's own cap)
#   NOTIFY_CMD=        command run with the final summary, e.g. NOTIFY_CMD="notify-send Autopilot"
#
# It never commits to main, never merges without a reviewer APPROVE (and green CI with
# AUTO_MERGE), never edits approved spec docs, and stops on anything it cannot decide.
# Every run writes .autopilot/<run-id>.md (report) and .autopilot/<run-id>.log (full log).
#
# One-time setup: run `claude` interactively in this repo once and accept the trust dialog.
# Requires: claude, git, gh (authenticated), jq.
# v2: every prompt starts with "NON-INTERACTIVE RUN" so Claude skips the MCP setup check (docs/MCP.md).
# v3: builds must pass scripts/gate.sh (docs, lint, format, types, tests) when it exists.
set -uo pipefail

AP_VERSION="v3"
AUTOPILOT="${AUTOPILOT:-build}"
AUTO_MERGE="${AUTO_MERGE:-0}"
MAX_REQS="${MAX_REQS:-3}"
MAX_COST="${MAX_COST:-10}"
REVIEW_ROUNDS="${REVIEW_ROUNDS:-2}"
STOP_ON_FAIL="${STOP_ON_FAIL:-1}"
LOOP_ITERS="${LOOP_ITERS:-}"
NOTIFY_CMD="${NOTIFY_CMD:-}"
DRY_RUN="${DRY_RUN:-0}"
PLAN_MODEL="${PLAN_MODEL:-opus}"
REVIEW_MODEL="${REVIEW_MODEL:-opus}"

case "${1:-}" in -h|--help) sed -n '2,33p' "$0"; exit 0 ;; esac

ok()   { echo "    OK    : $*"; }
info() { echo "    ..    : $*"; }
warn() { echo "    WARN  : $*"; }
err()  { echo "    ERROR : $*" >&2; }
step() { echo ""; echo "==> $*"; }

# ---------- build scope (docs/TASKS.md "Build scope:" line; no line or "all" = everything) ----------
scope_line() { grep -m1 -E '^Build scope:' docs/TASKS.md 2>/dev/null | sed -E 's/^Build scope:[[:space:]]*//; s/[[:space:]]*<!--.*//; s/[[:space:]]+$//'; }
scope_tokens() { scope_line | tr '[:lower:]' '[:upper:]' | sed -E 's/PHASE[[:space:]]*/P/g' | tr ',;' '  '; }
# req_phase REQ-00X: N of the "## Phase N" heading the REQ line sits under in docs/TASKS.md
req_phase() { awk -v id="$1" '/^##[[:space:]]+Phase[[:space:]]+[0-9]+/{match($0,/[0-9]+/); p=substr($0,RSTART,RLENGTH)} index($0, "] " id " ") && /- \[[ xX]\]/ {print p; exit}' docs/TASKS.md 2>/dev/null; }
in_scope() {   # in_scope REQ-00X: true if the build scope includes the REQ or its phase
  local s t p; s="$(scope_tokens)"
  [ -z "${s// /}" ] && return 0
  for t in $s; do [ "$t" = ALL ] || [ "$t" = "$1" ] && return 0; done
  p="$(req_phase "$1")"; [ -n "$p" ] || return 1
  for t in $s; do case "$t" in P[0-9]*) [ "${t#P}" = "$p" ] && return 0 ;; esac; done
  return 1
}
die()  { err "$*"; exit 1; }

# kit_event <kind> <id> <message> [extra-json]: one line in .kit/events.jsonl for the dashboard (scripts/dashboard.py)
kit_event() {
  local m; m="$(printf '%s' "${3:-}" | tr -d '\n\r\t' | sed 's/\\/\\\\/g; s/"/\\"/g')"
  mkdir -p .kit 2>/dev/null && printf '{"ts":"%s","src":"%s","kind":"%s","id":"%s","msg":"%s"%s}\n' \
    "$(date +%Y-%m-%dT%H:%M:%S%z)" "$(basename "$0" .sh)" "$1" "${2:-}" "$m" "${4:+,$4}" >> .kit/events.jsonl 2>/dev/null || true
}

PLAN_LEVEL=0; case ",$AUTOPILOT," in *,plan,*) PLAN_LEVEL=1 ;; esac
case ",$AUTOPILOT," in *,build,*) ;; *) die "AUTOPILOT must include 'build' (got '$AUTOPILOT')" ;; esac
for n in MAX_REQS REVIEW_ROUNDS; do
  case "${!n}" in ''|*[!0-9]*) die "$n must be a whole number" ;; esac
done

# ---------- preflight ----------
step "Preflight  (autopilot.sh $AP_VERSION)"
for c in claude git gh jq; do command -v "$c" >/dev/null 2>&1 || die "$c not found on PATH (autopilot needs claude, git, gh and jq)"; done
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repo"
cd "$ROOT" || die "cannot enter $ROOT"
gh auth status >/dev/null 2>&1 || die "gh is not authenticated: run gh auth login"
[ -f scripts/loop.sh ] || die "scripts/loop.sh missing (copy it from the kit)"
[ -f .claude/agents/reviewer.md ] || die ".claude/agents/reviewer.md missing (copy it from the kit's templates/project)"
for f in docs/01-prd.md docs/04-testplan.md docs/TASKS.md; do
  head -1 "$f" 2>/dev/null | grep -q '^Status: APPROVED' || die "$f is not APPROVED. Finish setup (type 'setup' in Claude) before using autopilot."
done
[ -z "$(git status --porcelain)" ] || die "working tree is not clean. Commit or stash first."

BASE_BRANCH="main"; git rev-parse --verify -q main >/dev/null || BASE_BRANCH="master"
START_BRANCH="$(git branch --show-current)"

TEST_CMD_SET="${TEST_CMD:+1}"
if [ -n "${TEST_CMD:-}" ]; then :
elif [ -f package.json ]; then TEST_CMD="npm test"
elif [ -f pyproject.toml ] || [ -f pytest.ini ] || [ -f requirements.txt ] || compgen -G "tests/test_*.py" >/dev/null 2>&1; then TEST_CMD="pytest"
elif [ -f Cargo.toml ]; then TEST_CMD="cargo test"
elif [ -f go.mod ]; then TEST_CMD="go test ./..."
else die "cannot detect the test command; set TEST_CMD=... (CLAUDE.md section 2)"; fi
TEST_LAST="${TEST_CMD##*&& }"; TEST_BIN="${TEST_LAST%% *}"   # the real test runner, for the reviewer's allowlist
if [ -f scripts/gate.sh ] && [ "${NO_GATE:-0}" != 1 ]; then
  [ -n "${TEST_CMD_SET:-}" ] && export GATE_TEST_CMD="$TEST_CMD"
  TEST_CMD="bash scripts/gate.sh"                              # docs, lint, format, types, tests (RULES.md section 2)
elif [ -z "${TEST_CMD_SET:-}" ] && [ -f scripts/doclint.sh ] && [ "${NO_DOCLINT:-0}" != 1 ]; then TEST_CMD="bash scripts/doclint.sh && $TEST_CMD"; fi

if [ "$AUTO_MERGE" = 1 ]; then
  if ! gh api "repos/{owner}/{repo}/branches/${BASE_BRANCH}/protection" >/dev/null 2>&1; then
    die "AUTO_MERGE=1 needs branch protection on ${BASE_BRANCH} (runbook.md Phase 2c). Not found."
  fi
fi
ok "repo $ROOT, base $BASE_BRANCH, tests '$TEST_CMD'"
ok "level: AUTOPILOT=$AUTOPILOT AUTO_MERGE=$AUTO_MERGE | caps: MAX_REQS=$MAX_REQS MAX_COST=\$$MAX_COST REVIEW_ROUNDS=$REVIEW_ROUNDS"

# ---------- run files ----------
RUN_ID="$(date +%Y%m%d-%H%M%S)"
mkdir -p .autopilot
LOG=".autopilot/${RUN_ID}.log"
REPORT=".autopilot/${RUN_ID}.md"
LOCK=".autopilot/lock"
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then die "another autopilot run is active (pid $(cat "$LOCK"))"; fi
echo $$ > "$LOCK"
# never commit run files, even if .gitignore lacks the entry (local-only exclude)
grep -qx '.autopilot/' .git/info/exclude 2>/dev/null || echo '.autopilot/' >> .git/info/exclude
export TEST_CMD
TOTAL_COST=0
ROWS=""
NEEDS_YOU=""
STOPPED=""
today() { date +%Y-%m-%d; }

add_cost() { TOTAL_COST=$(awk -v a="$TOTAL_COST" -v b="${1:-0}" 'BEGIN{printf "%.4f", a+b}'); }
over_budget() { awk -v a="$TOTAL_COST" -v m="$MAX_COST" 'BEGIN{exit !(a>=m)}'; }

# run_claude <label> <model> <out-file> <allowed-tools> <disallowed-tools> <system-append-file|-> <prompt>
run_claude() {
  local label="$1" model="$2" out="$3" allowed="$4" disallowed="$5" sysf="$6" prompt="$7"
  # NON-INTERACTIVE marker: Claude skips the session start and MCP setup checks (docs/MCP.md).
  local args=(-p "NON-INTERACTIVE RUN (scripts/autopilot.sh): skip the session start checks, including the MCP setup check in docs/MCP.md.

$prompt" --model "$model" --output-format json --permission-mode acceptEdits)
  [ -n "$allowed" ]    && args+=(--allowedTools "$allowed")
  [ -n "$disallowed" ] && args+=(--disallowedTools "$disallowed")
  [ "$sysf" != "-" ]   && args+=(--append-system-prompt "$(cat "$sysf")")
  info "claude [$label] on $model ..."
  local kid kmsg; kid="$(printf '%s' "$label" | grep -oE '(REQ|BUG)-[0-9]{3}' | head -1)"
  case "$label" in
    plan-review*) kmsg="Autopilot: the reviewer agent is checking the plan" ;;
    plan*)        kmsg="Autopilot: writing the plan" ;;
    review*)      kmsg="Autopilot: the reviewer agent is checking the code (round ${label##*r})" ;;
    *)            kmsg="Autopilot: $label" ;;
  esac
  kit_event autopilot "$kid" "$kmsg" "\"pid\":$$"
  if ! claude "${args[@]}" > .autopilot/resp.json 2>>"$LOG"; then
    err "claude [$label] failed (see $LOG)"; return 1
  fi
  local c iserr
  c="$(jq -r '.total_cost_usd // 0' .autopilot/resp.json 2>/dev/null)"; add_cost "${c:-0}"
  iserr="$(jq -r '.is_error // false' .autopilot/resp.json 2>/dev/null)"
  jq -r '.result // empty' .autopilot/resp.json > "$out" 2>/dev/null
  { echo "--- claude [$label] cost \$${c:-0}"; cat "$out"; } >> "$LOG"
  rm -f .autopilot/resp.json
  if [ "$iserr" = "true" ]; then err "claude [$label] reported an error (see $LOG)"; return 1; fi
  ok "claude [$label] done (\$${c:-0}, run total \$$TOTAL_COST)"
}

# verdict_of <file> -> APPROVE | CHANGES | NONE   (normalises so line 1 is the Verdict line)
normalise_verdict_file() {
  local f="$1" tmp
  tmp="$(mktemp)"
  awk 'found||/^Verdict: /{found=1; print}' "$f" > "$tmp"
  if [ -s "$tmp" ]; then mv "$tmp" "$f"; else rm -f "$tmp"; fi
}
verdict_of() {
  local l; l="$(head -1 "$1" 2>/dev/null)"
  case "$l" in "Verdict: APPROVE"*) echo APPROVE ;; "Verdict: CHANGES REQUESTED"*) echo CHANGES ;; *) echo NONE ;; esac
}

reviewer_sysprompt() {   # reviewer.md without its YAML front matter
  awk 'NR==1&&/^---$/{fm=1;next} fm&&/^---$/{fm=0;next} !fm' .claude/agents/reviewer.md > .autopilot/reviewer.sys.md
  echo .autopilot/reviewer.sys.md
}
RO_TOOLS="Read,Grep,Glob,Bash(git diff:*),Bash(git log:*),Bash(git show:*),Bash(git status:*),Bash(git merge-base:*),Bash(ls:*),Bash(cat:*),Bash(grep:*),Bash(gh issue view:*),Bash(${TEST_BIN}:*),Bash(bash scripts/doclint.sh:*),Bash(bash scripts/gate.sh:*),Bash(bash scripts/req_status.sh:*),Bash(bash scripts/start.sh status)"
RO_DENY="Edit,Write,NotebookEdit,Bash(git commit:*),Bash(git push:*),Bash(git checkout:*),Bash(git reset:*),Bash(rm:*)"

record() {  # record <req> <issue> <plan-by> <rounds> <verdict> <pr> <outcome> <reason>
  ROWS="${ROWS}| $1 | #$2 | $3 | $4 | $5 | $6 | $7 | $8 |
"
}
needs_you() { kit_event needs_you "$1" "Autopilot needs you: $2"; NEEDS_YOU="${NEEDS_YOU}- **$1**: $2
"; }

finish() {
  local code=$?
  rm -f "$LOCK"
  kit_event autopilot_end "" "Autopilot finished (cost \$$TOTAL_COST). Report: $REPORT" "\"pid\":$$,\"cost\":${TOTAL_COST:-0}"
  {
    echo "# Autopilot run ${RUN_ID}"
    echo ""
    echo "Settings: AUTOPILOT=$AUTOPILOT AUTO_MERGE=$AUTO_MERGE MAX_REQS=$MAX_REQS MAX_COST=\$$MAX_COST REVIEW_ROUNDS=$REVIEW_ROUNDS"
    echo "Total cost: \$$TOTAL_COST"
    [ -n "$STOPPED" ] && echo "Stopped early: $STOPPED"
    echo ""
    echo "| REQ | Issue | Plan approved by | Review rounds | Verdict | PR | Outcome | Notes |"
    echo "|---|---|---|---|---|---|---|---|"
    printf '%s' "${ROWS:-| - | - | - | - | - | - | nothing processed | - |
}"
    echo ""
    echo "## Needs you"
    printf '%s' "${NEEDS_YOU:-Nothing.
}"
    echo ""
    echo "Next: review open PRs (read docs/reviews/<REQ>.md first), then type 'wrap up' in Claude."
    echo "Full log: $LOG"
  } > "$REPORT"
  echo ""
  echo "=============================================="
  echo " AUTOPILOT FINISHED - report: $REPORT"
  echo "=============================================="
  cat "$REPORT"
  if [ -n "$NOTIFY_CMD" ]; then
    $NOTIFY_CMD "Autopilot ${RUN_ID}: \$$TOTAL_COST spent. ${STOPPED:-completed}. See $REPORT" >/dev/null 2>&1 || true
  fi
  exit "$code"
}
trap finish EXIT
kit_event autopilot_start "" "Autopilot started ($( [ "$AUTO_MERGE" = 1 ] && echo "level 3: builds and merges" || { [ "$PLAN_LEVEL" = 1 ] && echo "level 2: plans and builds" || echo "level 1: builds approved plans"; } ), up to $MAX_REQS feature(s), cost cap \$$MAX_COST)" "\"pid\":$$"

# ---------- choose REQs ----------
step "Choosing requirements"
declare -a QUEUE=()
declare -A ISSUE_OF=() TITLE_OF=()
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*-\ \[\ \]\ (REQ-[0-9]{3})\ \(#([0-9]+)\)\ *(.*)$ ]]; then
    r="${BASH_REMATCH[1]}"; ISSUE_OF[$r]="${BASH_REMATCH[2]}"; TITLE_OF[$r]="${BASH_REMATCH[3]}"
    if [ $# -eq 0 ]; then
      if in_scope "$r"; then QUEUE+=("$r"); else info "$r is outside the build scope ($(scope_line)) - skipped"; fi
    fi
  fi
done < docs/TASKS.md
if [ $# -gt 0 ]; then
  for r in "$@"; do
    [[ "$r" =~ ^REQ-[0-9]{3}$ ]] || die "not a REQ-ID: $r"
    if [ -z "${ISSUE_OF[$r]:-}" ]; then
      n="$(gh issue list --search "$r in:title" --state all --json number --jq '.[0].number' 2>/dev/null)"
      [ -n "$n" ] && [ "$n" != "null" ] || die "no Issue found for $r (TASKS.md or GitHub)"
      ISSUE_OF[$r]="$n"; TITLE_OF[$r]="$(gh issue view "$n" --json title --jq .title 2>/dev/null | sed "s/^$r: *//")"
    fi
    QUEUE+=("$r")
  done
fi
[ ${#QUEUE[@]} -gt 0 ] || { STOPPED="no unticked REQ inside the build scope ($(scope_line)) in docs/TASKS.md"; exit 0; }
QUEUE=("${QUEUE[@]:0:$MAX_REQS}")
ok "queue: ${QUEUE[*]}"

slug() { echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-30 | sed -E 's/-+$//'; }
base_ref() { git rev-parse --verify -q "origin/${BASE_BRANCH}" >/dev/null && echo "origin/${BASE_BRANCH}" || echo "${BASE_BRANCH}"; }
merged_on_base() { git log -E --oneline --grep="(feat|fix)\($1\)" "$(base_ref)" 2>/dev/null | grep -q . ; }

if [ "$DRY_RUN" = 1 ]; then
  step "DRY RUN - nothing will change"
  for r in "${QUEUE[@]}"; do
    p="docs/plans/$r.md"; ps="missing"
    [ -f "$p" ] && { head -1 "$p" | grep -q '^Status: APPROVED' && ps="approved" || ps="draft"; }
    act="build -> review -> PR"
    [ "$ps" != approved ] && { [ "$PLAN_LEVEL" = 1 ] && act="draft plan -> plan review -> $act" || act="SKIP (needs your approved plan)"; }
    if [ "$AUTO_MERGE" = 1 ] && { [ "$ps" = approved ] || [ "$PLAN_LEVEL" = 1 ]; }; then act="$act -> wait CI -> merge -> after-merge checks"; fi
    echo "    $r (#${ISSUE_OF[$r]}) plan: $ps  =>  $act"
  done
  STOPPED="dry run"
  exit 0
fi

git fetch -q origin 2>>"$LOG" || warn "git fetch failed; continuing with local refs"

# ---------- one REQ ----------
# returns 0 = done/PR open, 1 = needs you, 2 = skipped
process_req() {
  local req="$1" issue="${ISSUE_OF[$1]}" title="${TITLE_OF[$1]:-$1}"
  local branch; branch="feat/${req}-$(slug "$title")"
  local plan="docs/plans/${req}.md" review="docs/reviews/${req}.md" plan_by="you" rounds=0 verdict="-" pr="-" new_branch=0
  step "$req (#$issue) $title"

  if merged_on_base "$req" || [ "$(gh issue view "$issue" --json state --jq .state 2>/dev/null)" = "CLOSED" ]; then
    record "$req" "$issue" "-" 0 "-" "-" "skipped" "already merged or Issue closed"; return 2
  fi
  if over_budget; then STOPPED="cost cap \$$MAX_COST reached"; return 3; fi

  # branch (resume if it exists)
  git checkout -q "$BASE_BRANCH" && git pull -q --ff-only origin "$BASE_BRANCH" 2>>"$LOG"
  if git rev-parse --verify -q "$branch" >/dev/null; then git checkout -q "$branch"; info "resuming branch $branch"
  elif git rev-parse --verify -q "origin/$branch" >/dev/null; then git checkout -q -b "$branch" "origin/$branch"; info "resuming remote branch $branch"
  else git checkout -q -b "$branch"; new_branch=1; ok "branch $branch"; fi

  # dependency guard
  local dep
  for dep in $(grep -oiE '^Depends on:.*' "$plan" 2>/dev/null | grep -oE 'REQ-[0-9]{3}'); do
    if ! merged_on_base "$dep"; then
      git checkout -q "$BASE_BRANCH"; [ "$new_branch" = 1 ] && git branch -q -D "$branch" 2>/dev/null
      record "$req" "$issue" "-" 0 "-" "-" "skipped" "depends on $dep, not merged yet"; return 2
    fi
  done

  # ----- plan -----
  if ! { [ -f "$plan" ] && head -1 "$plan" | grep -q '^Status: APPROVED'; }; then
    if [ "$PLAN_LEVEL" != 1 ]; then
      git checkout -q "$BASE_BRANCH"
      [ "$new_branch" = 1 ] && git branch -q -D "$branch" 2>/dev/null
      record "$req" "$issue" "-" 0 "-" "-" "skipped" "no approved plan (level 1 builds only plans you approved)"
      needs_you "$req" "write and approve docs/plans/$req.md (type 'next' in Claude), or run with AUTOPILOT=plan,build"
      return 2
    fi
    local pr_round
    for pr_round in 1 2; do
      local extra=""
      [ -f "docs/reviews/${req}.plan.md" ] && [ "$(verdict_of "docs/reviews/${req}.plan.md")" = CHANGES ] && \
        extra=" A plan review asked for changes; address every finding in docs/reviews/${req}.plan.md."
      run_claude "plan ${req}" "$PLAN_MODEL" .autopilot/plan.out "Read,Grep,Glob,Write,Edit" "Bash" "-" \
"Issue #${issue} / ${req}. Write an implementation plan ONLY to ${plan}, starting from docs/plans/_TEMPLATE.md.
Read CLAUDE.md, docs/RULES.md, ${req} in docs/01-prd.md, its TC rows in docs/04-testplan.md and docs/02-architecture.md.
Fill: goal, TC-IDs covered, approach, files to create or change, risks, out of scope, review focus, and the iteration cap.
If it needs another REQ merged first, add a line 'Depends on: REQ-00X'.
Keep line 1 exactly 'Status: DRAFT'. Do not create or change any other file. No code.${extra}" || return 1
      local stray; stray="$(git status --porcelain --untracked-files=all | grep -vE " (${plan}|docs/reviews/${req}\.plan\.md)\$")"
      if [ -n "$stray" ]; then
        needs_you "$req" "the planner changed files other than the plan: $(echo "$stray" | tr '\n' ' ')"
        record "$req" "$issue" "-" 0 "-" "-" "NEEDS YOU" "planner touched other files"; return 1
      fi
      [ -f "$plan" ] || { needs_you "$req" "planner wrote no plan file"; record "$req" "$issue" "-" 0 "-" "-" "NEEDS YOU" "no plan"; return 1; }
      run_claude "plan-review ${req}" "$REVIEW_MODEL" "docs/reviews/${req}.plan.md" "$RO_TOOLS" "$RO_DENY" "$(reviewer_sysprompt)" \
"PLAN REVIEW MODE. Review the plan ${plan} for ${req} (#${issue}), not code.
Check it against ${req} in docs/01-prd.md, its TC rows in docs/04-testplan.md, docs/02-architecture.md and docs/RULES.md:
complete, every acceptance criterion and TC row covered, in scope, risks and review focus identified, sensible iteration cap.
Line 1 must be 'Verdict: APPROVE - plan round ${pr_round} - $(today)' or 'Verdict: CHANGES REQUESTED - plan round ${pr_round} - $(today)',
then a findings table (# | Severity | Section | Finding). Return only the report." || return 1
      normalise_verdict_file "docs/reviews/${req}.plan.md"
      if [ "$(verdict_of "docs/reviews/${req}.plan.md")" = APPROVE ]; then
        sed -i "1s/.*/Status: APPROVED - $(today) - by reviewer agent (autopilot ${RUN_ID})/" "$plan"
        plan_by="reviewer agent"
        break
      fi
    done
    git add "$plan" "docs/reviews/${req}.plan.md"
    git commit -qm "docs(${req}): plan + plan review (#${issue})" 2>>"$LOG"
    if [ "$plan_by" != "reviewer agent" ]; then
      needs_you "$req" "plan still CHANGES REQUESTED after 2 rounds: read docs/reviews/${req}.plan.md and approve or rewrite the plan"
      record "$req" "$issue" "-" 0 "-" "-" "NEEDS YOU" "plan not approved"; return 1
    fi
    ok "plan approved by reviewer agent"
  fi

  # ----- build + review rounds -----
  local r loop_out
  for r in $(seq 1 "$REVIEW_ROUNDS"); do
    if over_budget; then STOPPED="cost cap \$$MAX_COST reached"; record "$req" "$issue" "$plan_by" "$rounds" "$verdict" "-" "stopped" "cost cap"; return 3; fi
    # skip the loop on resume if the last commit is an APPROVE review
    if [ "$(verdict_of "$review")" = APPROVE ] && git log -1 --format=%s | grep -q "^docs(${req}): review round"; then
      verdict="APPROVE"; break
    fi
    loop_out=".autopilot/${RUN_ID}-${req}-loop${r}.txt"
    info "loop round $r"
    bash scripts/loop.sh "$issue" "$req" ${LOOP_ITERS:+"$LOOP_ITERS"} > "$loop_out" 2>&1
    local lc=$?
    add_cost "$(grep -oE 'total cost : \$[0-9.]+' "$loop_out" | tail -1 | grep -oE '[0-9.]+$')"
    cat "$loop_out" >> "$LOG"
    if [ $lc -ne 0 ]; then
      needs_you "$req" "loop stopped (cap or error) in round $r: read $loop_out and FAILURES.txt on branch $branch, then re-plan"
      record "$req" "$issue" "$plan_by" "$rounds" "$verdict" "-" "NEEDS YOU" "loop did not go green"; return 1
    fi
    if grep -q "Review findings the builder disputes" "$loop_out"; then
      git add -A; git commit -qm "fix(${req}): address review round $((r-1)) (#${issue})" 2>>"$LOG"
      needs_you "$req" "the builder disputes review findings: see $loop_out (section 'Disputed'), decide, then type 'review ${req}'"
      record "$req" "$issue" "$plan_by" "$rounds" "$verdict" "-" "NEEDS YOU" "disputed findings"; return 1
    fi
    git add -A
    if [ "$r" = 1 ] && [ "$verdict" = "-" ]; then
      git commit -qm "feat(${req}): ${title} (#${issue})" 2>>"$LOG" || info "nothing new to commit"
    else
      git commit -qm "fix(${req}): address review round $((r-1)) (#${issue})" 2>>"$LOG" || info "nothing new to commit"
    fi

    run_claude "review ${req} r$r" "$REVIEW_MODEL" "$review" "$RO_TOOLS" "$RO_DENY" "$(reviewer_sysprompt)" \
"Review ${req} (Issue #${issue}) on branch ${branch}. The plan is ${plan}. This is round ${r}.
Follow your instructions exactly and return only the report, starting with the Verdict line." || return 1
    normalise_verdict_file "$review"
    rounds=$r
    case "$(verdict_of "$review")" in
      APPROVE) verdict="APPROVE" ;;
      CHANGES) verdict="CHANGES REQUESTED" ;;
      *) needs_you "$req" "reviewer returned no Verdict line: see $review"; record "$req" "$issue" "$plan_by" "$rounds" "?" "-" "NEEDS YOU" "no verdict"; return 1 ;;
    esac
    git add "$review"; git commit -qm "docs(${req}): review round ${r} (#${issue})" 2>>"$LOG"
    ok "review round $r: $verdict"
    [ "$verdict" = APPROVE ] && break
  done
  if [ "$verdict" != APPROVE ]; then
    needs_you "$req" "still CHANGES REQUESTED after $REVIEW_ROUNDS rounds: the plan or requirement is wrong. Read $review, re-plan."
    record "$req" "$issue" "$plan_by" "$rounds" "$verdict" "-" "NEEDS YOU" "review not approved"; return 1
  fi

  # ----- push + PR -----
  git push -q -u origin "$branch" 2>>"$LOG" || { needs_you "$req" "git push failed (see $LOG)"; record "$req" "$issue" "$plan_by" "$rounds" "$verdict" "-" "NEEDS YOU" "push failed"; return 1; }
  pr="$(gh pr list --head "$branch" --state open --json number --jq '.[0].number' 2>/dev/null)"
  if [ -z "$pr" ] || [ "$pr" = "null" ]; then
    gh pr create --base "$BASE_BRANCH" --head "$branch" --title "feat(${req}): ${title}" --body "Implements ${req}. Closes #${issue}.

Review: docs/reviews/${req}.md (APPROVE, round ${rounds}).
Plan approved by: ${plan_by}.
Opened unattended by autopilot run ${RUN_ID}." >>"$LOG" 2>&1 || { needs_you "$req" "gh pr create failed"; record "$req" "$issue" "$plan_by" "$rounds" "$verdict" "-" "NEEDS YOU" "PR failed"; return 1; }
    pr="$(gh pr list --head "$branch" --state open --json number --jq '.[0].number' 2>/dev/null)"
  fi
  ok "PR #$pr open"

  if [ "$AUTO_MERGE" != 1 ]; then
    record "$req" "$issue" "$plan_by" "$rounds" "$verdict" "#$pr" "PR open" "waiting for your review"
    git checkout -q "$BASE_BRANCH"; return 0
  fi

  # ----- level 3: CI, merge, after-merge checks -----
  info "waiting for CI on PR #$pr"
  if ! gh pr checks "$pr" --watch --fail-fast >>"$LOG" 2>&1; then
    needs_you "$req" "CI failed on PR #$pr"; record "$req" "$issue" "$plan_by" "$rounds" "$verdict" "#$pr" "NEEDS YOU" "CI red"; return 1
  fi
  gh pr merge "$pr" --squash --delete-branch >>"$LOG" 2>&1 || { needs_you "$req" "merge of PR #$pr failed"; record "$req" "$issue" "$plan_by" "$rounds" "$verdict" "#$pr" "NEEDS YOU" "merge failed"; return 1; }
  git checkout -q "$BASE_BRANCH" && git pull -q --ff-only origin "$BASE_BRANCH" 2>>"$LOG"
  if ! bash -c "$TEST_CMD" >>"$LOG" 2>&1; then
    STOPPED="main is RED after merging ${req}"
    needs_you "$req" "MAIN IS RED after merging PR #$pr. Revert first: git revert -m 1 <merge-sha> on a branch + PR, then diagnose."
    record "$req" "$issue" "$plan_by" "$rounds" "$verdict" "#$pr" "MERGED, MAIN RED" "revert needed"; return 3
  fi
  if ! bash scripts/req_status.sh --strict >>"$LOG" 2>&1; then
    STOPPED="traceability check failed after ${req}"
    needs_you "$req" "req_status.sh --strict failed after merge: a merged REQ has no tests"
    record "$req" "$issue" "$plan_by" "$rounds" "$verdict" "#$pr" "MERGED, CHECK FAILED" "traceability"; return 3
  fi
  record "$req" "$issue" "$plan_by" "$rounds" "$verdict" "#$pr" "merged" "after-merge checks green"
  return 0
}

# ---------- main loop ----------
for req in "${QUEUE[@]}"; do
  process_req "$req"; rc=$?
  if [ $rc -eq 3 ]; then break; fi
  if [ $rc -eq 1 ]; then
    git checkout -q "$BASE_BRANCH" 2>/dev/null || true
    if [ "$STOP_ON_FAIL" = 1 ]; then STOPPED="${STOPPED:-$req needs you (STOP_ON_FAIL=1)}"; break; fi
  fi
done
git checkout -q "$START_BRANCH" 2>/dev/null || true
exit 0
