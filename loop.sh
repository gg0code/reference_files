#!/usr/bin/env bash
# loop.sh - bounded Ralph loop for ONE GitHub Issue.        VERSION: v11
# Usage:  bash scripts/loop.sh [max-iters]          (ID from the branch, Issue from docs/TASKS.md)
#         bash scripts/loop.sh <issue-number> <REQ-00X|BUG-00X> [max-iters]   (explicit form)
#
# Loops inside an Issue; NEVER loops across a review gate.
#   - fresh context every iteration (context quality degrades past ~100-150k tokens)
#   - state lives in the codebase + git + PROMPT.md, not in conversation history
#   - EXIT CONDITION = green FULL test suite, not the agent's opinion
#   - hard iteration cap so a wrong hypothesis cannot burn your budget
#
# History:
#   v2 requires a plan file (docs/plans/<ID>.md) and injects it every pass.
#   v3 auto-detects the test command per stack.
#   v6 cost/token telemetry, already-done guard, list of touched files.
#   v7 plan must be "Status: APPROVED"; cap read from the plan; works for BUG-IDs;
#      prompt points at docs/RULES.md and docs/MEMORY.md; runs from the repo root;
#      single version string everywhere.
#   v8 reads docs/reviews/<ID>.md: a CHANGES REQUESTED review is fed into every pass
#      so the loop fixes the reviewer's findings; on green it sends you to "review".
#   v9 no arguments needed: the ID comes from the branch name (feat/REQ-001-x, fix/BUG-002)
#      and the Issue number from docs/TASKS.md or GitHub.
#   v10 runs scripts/doclint.sh in front of the detected test command; TEST_CMD may use && (bash -c).
#   v11 marks the prompt NON-INTERACTIVE RUN so Claude skips the MCP setup check (docs/MCP.md).
set -uo pipefail

LOOP_VERSION="v11"

# ---------- help / usage ----------
usage() {
  cat <<HELP
loop.sh - bounded Ralph loop for ONE GitHub Issue.        VERSION: ${LOOP_VERSION}

WHAT IT DOES
  Repeatedly runs Claude Code against a single Issue with a FRESH context each
  pass, feeding test failures back in, until the full test suite is green or a
  hard iteration cap is hit. State lives in the codebase + git + PROMPT.md, never
  in chat history. The EXIT CONDITION is a green suite, not the agent's opinion.
  Prints per-iteration cost and token usage plus a per-ID total (needs jq; without
  jq it still runs, just without the numbers). At the end it lists every file it
  created or modified this run.

INVOCATION
  bash scripts/loop.sh                    on a branch made by start.sh: ID and Issue are found for you
  bash scripts/loop.sh 5                  same, with an iteration cap of 5
  bash scripts/loop.sh <issue#> <ID> [N]  explicit form (used by autopilot.sh)
  bash scripts/loop.sh --help

  [max-iters]      Hard cap. Default: the plan's "Maximum loop iterations: N" line, else 8.

  Examples:
    bash scripts/loop.sh
    TEST_CMD="pytest -q" bash scripts/loop.sh

ENV OVERRIDES
  TEST_CMD    Force the test command (else auto-detected per stack:
              npm test / pytest / cargo test / go test ./..., with
              "bash scripts/doclint.sh &&" in front when that script exists).
              It must run the FULL suite. "&&" chains are fine.
  PLAN_FILE   Path to the approved plan (default: docs/plans/<ID>.md).
  FORCE       FORCE=1 skips the "already done" guard (see below).

PLAN GATE
  The plan file's first line must be "Status: APPROVED - <date>".
  A DRAFT plan is refused: approve it first, then commit it.

REVIEW FINDINGS
  If docs/reviews/<ID>.md starts with "Verdict: CHANGES REQUESTED", its findings
  are injected into every pass and the loop fixes the Critical and Major ones.
  After a green run, type "review" in the claude pane for the next round.

ALREADY-DONE GUARD
  Before looping, the script checks whether <ID> is already finished (a
  feat/fix(<ID>) commit on the base branch, or a CLOSED GitHub Issue) and stops,
  so you do not re-implement it into duplicates or conflicts. Deliberately
  rebuilding it (e.g. after a revert)? Re-run with FORCE=1.

ONE-TIME SETUP (per machine / workspace)
  1. Claude Code CLI on PATH:   command -v claude
  2. In THIS repo, run "claude" interactively once and ACCEPT the trust dialog.
     Otherwise the loop's "claude -p" calls run untrusted, ignore your
     permission allowlist, and files may silently not get written.
  3. Your test runner works by hand once (Python: activate the venv, then pytest).
  4. Optional: jq for telemetry (apt install jq / brew install jq),
     gh authenticated for the done-guard and PRs.

BEFORE EVERY RUN (per Issue)
  1. On a FEATURE branch (the loop refuses main/master):
       bash scripts/start.sh                         (bugs: bash scripts/start.sh bug "symptom")
  2. Plan approved and saved to docs/plans/<ID>.md with first line
     "Status: APPROVED - <date>", then committed:
       git add docs/plans/REQ-001.md && git commit -m "docs(REQ-001): approved plan (#12)"

RECOMMENDED tmux PANES
  claude   : plan / re-plan on Opus
  git      : run this loop, then commit / push / PR
  test     : watch -n2 'tail -20 .loop-test-out.txt 2>/dev/null'

WHEN IT STOPS
  Green   -> prints the exact git/gh commands to review, commit, push and PR.
  At cap  -> usually the PLAN was wrong, not the code. Do NOT just re-run:
               git diff ; cat FAILURES.txt ; re-plan on Opus ; git checkout . if needed
HELP
}

case "${1:-}" in
  -h|--help|help) usage; exit 0 ;;
esac

ok()   { echo "    OK    : $*"; }
err()  { echo "    ERROR : $*" >&2; }
step() { echo ""; echo "==> $*"; }

if [ $# -ge 2 ]; then
  ISSUE="$1"; ID="$2"; CAP_ARG="${3:-}"
else
  CAP_ARG="${1:-}"
  _root="$(git rev-parse --show-toplevel 2>/dev/null)" || { err "not inside a git repo"; exit 1; }
  cd "$_root" || exit 1
  ID="$(git branch --show-current | grep -oE '(REQ|BUG)-[0-9]{3}' | head -1)"
  [ -n "$ID" ] || { err "not on a REQ or BUG branch ($(git branch --show-current)). Start work with: bash scripts/start.sh"; exit 1; }
  ISSUE="$(grep -E "^[[:space:]]*- \[[ x]\] $ID \(#[0-9]+\)" docs/TASKS.md 2>/dev/null | head -1 | sed -nE 's/.*\(#([0-9]+)\).*/\1/p')"
  if [ -z "$ISSUE" ] && command -v gh >/dev/null 2>&1; then
    ISSUE="$(gh issue list --search "$ID in:title" --state all --json number --jq '.[0].number // empty' 2>/dev/null)"
  fi
  [ -n "$ISSUE" ] || { err "no Issue number for $ID (docs/TASKS.md line '$ID (#N) ...' or a GitHub Issue titled '$ID: ...')"; exit 1; }
fi
case "$ISSUE" in ''|*[!0-9]*) err "Issue number must be numeric (got '$ISSUE')"; exit 1 ;; esac

case "$ID" in
  REQ-[0-9]*) KIND="feat"; WHAT="requirement" ;;
  BUG-[0-9]*) KIND="fix";  WHAT="bug" ;;
  *) err "ID must look like REQ-001 or BUG-001 (got '$ID')"; exit 1 ;;
esac

# ---------- guardrails ----------
step "Preflight  (loop.sh $LOOP_VERSION)"
command -v claude >/dev/null 2>&1 || { err "claude CLI not found"; exit 1; }
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { err "not inside a git repo"; exit 1; }
cd "$ROOT" || { err "cannot enter $ROOT"; exit 1; }
ok "repo  : $ROOT"

BRANCH="$(git branch --show-current)"
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  err "refusing to loop on '$BRANCH'. Create a branch first:"
  echo "            bash scripts/start.sh"
  exit 1
fi
ok "branch: $BRANCH"
ok "issue : #$ISSUE   $WHAT: $ID"

# ---------- already-done guard ----------
if [ "${FORCE:-0}" != 1 ]; then
  DONE_HINTS=""
  BASE=""
  for ref in origin/main origin/master main master; do
    git rev-parse --verify -q "$ref" >/dev/null 2>&1 && { BASE="$ref"; break; }
  done
  if [ -n "$BASE" ]; then
    HITS="$(git log -E --oneline --grep="(feat|fix)\(${ID}\)" "$BASE" 2>/dev/null)"
    [ -n "$HITS" ] && DONE_HINTS="${DONE_HINTS}
    - already merged on ${BASE}:
$(echo "$HITS" | sed 's/^/        /')"
  fi
  if command -v gh >/dev/null 2>&1; then
    ISTATE="$(gh issue view "$ISSUE" --json state --jq .state 2>/dev/null || true)"
    [ "$ISTATE" = "CLOSED" ] && DONE_HINTS="${DONE_HINTS}
    - GitHub Issue #${ISSUE} is CLOSED"
  fi
  if [ -n "$DONE_HINTS" ]; then
    err "${ID} looks ALREADY DONE:"
    printf '%s\n' "$DONE_HINTS"
    echo "    Re-running re-implements ${ID} and can create duplicates or conflicts."
    echo "    If you truly want to run it again:  FORCE=1 bash scripts/loop.sh"
    exit 1
  fi
  ok "not-done check: no prior ${ID} completion detected"
fi

# ---------- test command: explicit override, else auto-detect per stack ----------
if [ -n "${TEST_CMD:-}" ]; then
  TEST_CMD_FROM_ENV=1
  ok "tests : $TEST_CMD   (from TEST_CMD env)"
elif [ -f package.json ]; then
  TEST_CMD="npm test";        ok "tests : $TEST_CMD   (detected package.json)"
elif [ -f pyproject.toml ] || [ -f pytest.ini ] || [ -f setup.cfg ] \
     || [ -f requirements.txt ] || [ -f conftest.py ] \
     || compgen -G "tests/test_*.py" >/dev/null 2>&1 \
     || compgen -G "test_*.py" >/dev/null 2>&1; then
  TEST_CMD="pytest";          ok "tests : $TEST_CMD   (detected Python tests)"
elif [ -f Cargo.toml ]; then
  TEST_CMD="cargo test";      ok "tests : $TEST_CMD   (detected Cargo.toml)"
elif [ -f go.mod ]; then
  TEST_CMD="go test ./...";   ok "tests : $TEST_CMD   (detected go.mod)"
else
  err "could not detect a test command for this repo."
  echo "            Set it explicitly, e.g.:  TEST_CMD=\"pytest\" bash scripts/loop.sh"
  echo "            (use the 'Full test suite' command from CLAUDE.md section 2)"
  exit 1
fi

if [ -z "${TEST_CMD_FROM_ENV:-}" ] && [ -f scripts/doclint.sh ] && [ "${NO_DOCLINT:-0}" != 1 ]; then
  TEST_CMD="bash scripts/doclint.sh && $TEST_CMD"; ok "tests : $TEST_CMD   (doclint in front; NO_DOCLINT=1 to skip)"
fi
case "$TEST_CMD" in
  *npm\ *|*yarn\ *) [ -f package.json ] || { err "TEST_CMD is '$TEST_CMD' but there is no package.json here. Wrong stack? Set TEST_CMD=..."; exit 1; } ;;
  *pytest*)          command -v pytest >/dev/null 2>&1 || { err "pytest not found on PATH. Activate your venv: source .venv/bin/activate"; exit 1; } ;;
esac

# ---------- telemetry ----------
if command -v jq >/dev/null 2>&1; then
  HAVE_JQ=1; ok "usage : token/cost tracking ON (jq found)"
else
  HAVE_JQ=0; ok "usage : token/cost tracking OFF (install jq to enable)"
fi

# ---------- approved plan (the human-gated decisions) ----------
PLAN_FILE="${PLAN_FILE:-docs/plans/${ID}.md}"
if [ ! -f "$PLAN_FILE" ]; then
  err "no plan found at $PLAN_FILE"
  echo "            Each pass uses a fresh context and cannot see a plan that only lives in a chat."
  echo "            Save the approved plan (start from docs/plans/_TEMPLATE.md), set its first line to"
  echo "            'Status: APPROVED - <date>', commit it, and re-run."
  exit 1
fi
FIRST_LINE="$(grep -m1 -v '^[[:space:]]*$' "$PLAN_FILE")"
case "$FIRST_LINE" in
  "Status: APPROVED"*) ok "plan  : $PLAN_FILE ($FIRST_LINE) - enforced every pass" ;;
  *)
    err "plan $PLAN_FILE is not approved. First line is: '$FIRST_LINE'"
    echo "            Review it, change the first line to 'Status: APPROVED - <date>', commit, and re-run."
    exit 1 ;;
esac
PLAN_BLOCK="$(cat "$PLAN_FILE")"

# ---------- reviewer findings (second agent), if a review asked for changes ----------
REVIEW_FILE="docs/reviews/${ID}.md"
REVIEW_BLOCK=""
if [ -f "$REVIEW_FILE" ]; then
  RV_LINE="$(grep -m1 -v '^[[:space:]]*$' "$REVIEW_FILE")"
  case "$RV_LINE" in
    "Verdict: CHANGES REQUESTED"*)
      REVIEW_BLOCK="$(cat "$REVIEW_FILE")"
      ok "review: $REVIEW_FILE ($RV_LINE) - findings fed into every pass" ;;
    "Verdict: APPROVE"*)
      ok "review: $REVIEW_FILE is already APPROVE - any change now needs a fresh review round" ;;
    *)
      ok "review: $REVIEW_FILE has no verdict line - ignored" ;;
  esac
fi

# ---------- iteration cap: argument > plan file > default ----------
PLAN_CAP="$(grep -oiE 'Maximum loop iterations:[[:space:]]*[0-9]+' "$PLAN_FILE" | grep -oE '[0-9]+$' | head -1)"
if [ -n "$CAP_ARG" ]; then
  MAX_ITERS="$CAP_ARG"; ok "max iterations: $MAX_ITERS (from command line)"
elif [ -n "$PLAN_CAP" ]; then
  MAX_ITERS="$PLAN_CAP"; ok "max iterations: $MAX_ITERS (from plan file)"
else
  MAX_ITERS=8; ok "max iterations: $MAX_ITERS (default)"
fi
case "$MAX_ITERS" in ''|*[!0-9]*) err "max-iters must be a number (got '$MAX_ITERS')"; exit 1 ;; esac

# ---------- the prompt, re-read fresh every iteration ----------
if [ "$KIND" = feat ]; then
  TASK_LINES="2. Read ${ID} in docs/01-prd.md and its TC-### rows in docs/04-testplan.md.
3. Write the tests from those TC rows FIRST, then the implementation."
else
  TASK_LINES="2. Read the Issue #${ISSUE} description and the failing test that reproduces ${ID}
   (committed before this loop). Do not weaken or rewrite that test.
3. Apply the minimal fix described in the plan so the failing test passes and the full suite stays green."
fi

cat > PROMPT.md <<PROMPT
# Task - Issue #${ISSUE} / ${ID}

NON-INTERACTIVE RUN (scripts/loop.sh): skip the session start checks, including the MCP setup check
in docs/MCP.md. Nobody reads chat output here; only files and the test suite count.

Work on ${ID} on branch ${BRANCH}.

## APPROVED PLAN - follow this exactly, do NOT invent a different approach
${PLAN_BLOCK}

## Rules (binding; from CLAUDE.md and docs/RULES.md)
1. Implement strictly per the APPROVED PLAN above. If the plan and your instinct
   disagree, the plan wins. If the plan is unworkable, STOP and write why in
   FAILURES.txt rather than silently changing the approach.
${TASK_LINES}
4. Read docs/RULES.md (coding rules and section 3 "Documentation conventions": a README in
   every new directory, a header on every file, a doc block on every function) and the
   "Known issues and gotchas" in docs/MEMORY.md before editing.
5. The regression gate in CLAUDE.md section 2 must stay green.
6. Do NOT commit. Do NOT open a PR. Do NOT touch main.
   Do NOT edit docs/TASKS.md, docs/MEMORY.md or any spec doc whose first line is "Status: APPROVED".
7. Unrelated problems: do not fix them here. List them in FAILURES.txt under "Noticed".
8. If \`${TEST_CMD}\` is failing, read the failure output in FAILURES.txt and fix the CAUSE.
   Never delete, skip or weaken a test, or edit fixtures or expected data, to make it pass.

Success = \`${TEST_CMD}\` (the FULL suite) exits clean, built the way the APPROVED PLAN specifies${REVIEW_BLOCK:+,
and every Critical and Major finding in the REVIEW below is resolved}.
${REVIEW_BLOCK:+
## REVIEW FINDINGS TO FIX (from the reviewer agent; fix every Critical and Major item)
Fix the cause of each finding within the approved plan. Do not argue with a finding in code
comments; if you believe one is wrong, leave it unfixed and explain why in FAILURES.txt under "Disputed".
Do NOT edit ${REVIEW_FILE}.

${REVIEW_BLOCK}
}
## Current failures
See FAILURES.txt in the repo root (empty on the first pass).
PROMPT

: > FAILURES.txt
ok "wrote PROMPT.md"

# ---------- per-ID running totals ----------
TOTAL_COST=0; TOTAL_IN=0; TOTAL_OUT=0; TOTAL_CR=0

usage_summary() {
  local iters="$1"
  if [ "$HAVE_JQ" != 1 ]; then
    echo "  usage : token/cost totals unavailable (jq not installed)"
    return
  fi
  echo "  USAGE - ${ID} over ${iters} iteration(s):"
  printf '    total cost : $%s\n'          "$TOTAL_COST"
  printf '    input      : %s tokens\n'    "$TOTAL_IN"
  printf '    output     : %s tokens\n'    "$TOTAL_OUT"
  printf '    cache read : %s tokens\n'    "$TOTAL_CR"
}

# Everything the loop wrote or changed this run (it never commits), minus scratch files.
list_generated_files() {
  local rows
  rows=$(git status --porcelain=v1 --untracked-files=all 2>/dev/null \
         | grep -vE '[[:space:]](PROMPT\.md|FAILURES\.txt|\.loop-[^[:space:]]*)$')
  echo "  FILES touched this run (uncommitted vs last commit):"
  if [ -z "$rows" ]; then
    echo "    (none)"
    return 0
  fi
  echo "$rows" | awk '
    { code=substr($0,1,2); path=substr($0,4)
      if (code=="??")        tag="new     "
      else if (code ~ /D/)   tag="deleted "
      else if (code ~ /R/)   tag="renamed "
      else                   tag="modified"
      printf "    %s  %s\n", tag, path }'
  local n
  n=$(echo "$rows" | wc -l | tr -d ' ')
  echo "    ($n path(s) total - review with: git diff  and  git status)"
}

# ---------- the loop ----------
for i in $(seq 1 "$MAX_ITERS"); do
  step "Iteration $i/$MAX_ITERS  (fresh context)"

  ITER_START=$(date +%s)
  if [ "$HAVE_JQ" = 1 ]; then
    echo "    launching claude (fresh context) ..."
    claude -p "$(cat PROMPT.md)" --permission-mode acceptEdits --output-format json \
      > .loop-claude-resp.json 2> .loop-claude-err.txt &
    CPID=$!
    sp='|/-\'; sc=0
    while kill -0 "$CPID" 2>/dev/null; do
      el=$(( $(date +%s) - ITER_START ))
      if [ -t 1 ]; then
        printf '\r    working %s  %ds elapsed  (JSON mode is silent until the pass ends) ' \
          "${sp:$((sc%4)):1}" "$el"
      elif [ $((el % 15)) -eq 0 ]; then
        echo "    working... ${el}s elapsed"
      fi
      sc=$((sc+1)); sleep 1
    done
    [ -t 1 ] && printf '\r%*s\r' 90 ''
    wait "$CPID" \
      || { err "claude invocation failed on iteration $i"; tail -5 .loop-claude-err.txt | sed 's/^/            /'; exit 1; }
    RESP="$(cat .loop-claude-resp.json)"
    rm -f .loop-claude-resp.json .loop-claude-err.txt
    jq -r '.result // empty' <<<"$RESP"
    cost=$(jq -r '.total_cost_usd                // 0' <<<"$RESP")
    tin=$( jq -r '.usage.input_tokens            // 0' <<<"$RESP")
    tout=$(jq -r '.usage.output_tokens           // 0' <<<"$RESP")
    tcr=$( jq -r '.usage.cache_read_input_tokens // 0' <<<"$RESP")
    turns=$(jq -r '.num_turns                    // 0' <<<"$RESP")
    TOTAL_COST=$(awk -v a="$TOTAL_COST" -v b="$cost" 'BEGIN{printf "%.4f", a+b}')
    TOTAL_IN=$(( TOTAL_IN + tin )); TOTAL_OUT=$(( TOTAL_OUT + tout )); TOTAL_CR=$(( TOTAL_CR + tcr ))
  else
    claude -p "$(cat PROMPT.md)" --permission-mode acceptEdits \
      || { err "claude invocation failed on iteration $i"; exit 1; }
  fi
  ITER_SECS=$(( $(date +%s) - ITER_START ))

  if [ "$HAVE_JQ" = 1 ]; then
    ok "cost  : iter $i  \$$cost   in=$tin  out=$tout  cache_read=$tcr  turns=$turns  ${ITER_SECS}s"
    ok "run   : $ID so far  \$$TOTAL_COST   in=$TOTAL_IN  out=$TOTAL_OUT  ($i iter)"
  else
    ok "iter $i took ${ITER_SECS}s"
  fi

  step "Iteration $i - running: $TEST_CMD"
  if bash -c "$TEST_CMD" > .loop-test-out.txt 2>&1; then
    tail -5 .loop-test-out.txt
    ok "SUITE GREEN on iteration $i"
    NOTICED="$(grep -A50 -i '^Noticed' FAILURES.txt 2>/dev/null)"
    DISPUTED="$(grep -A30 -i '^Disputed' FAILURES.txt 2>/dev/null)"
    rm -f .loop-test-out.txt
    echo ""
    echo "=============================================="
    echo " LOOP COMPLETE - suite green after $i iteration(s)"
    echo "=============================================="
    usage_summary "$i"
    echo "----------------------------------------------"
    list_generated_files
    if [ -n "$NOTICED" ]; then
      echo "----------------------------------------------"
      echo "  Noticed during the loop (log as BUG Issues or hygiene commits, see CLAUDE.md section 10):"
      echo "$NOTICED" | sed 's/^/    /'
    fi
    rm -f FAILURES.txt
    if [ -n "$DISPUTED" ]; then
      echo "----------------------------------------------"
      echo "  Review findings the builder disputes (decide these yourself):"
      echo "$DISPUTED" | sed 's/^/    /'
    fi
    echo "----------------------------------------------"
    echo "  NEXT (two-agent flow, CLAUDE.md section 5a):"
    echo "    1. git pane:    git diff"
    if [ -n "$REVIEW_BLOCK" ]; then
      echo "                    git add -A && git commit -m \"fix(${ID}): address review round (#${ISSUE})\""
    else
      echo "                    git add -A && git commit -m \"${KIND}(${ID}): <summary> (#${ISSUE})\""
    fi
    echo "    2. claude pane: review              <- the reviewer agent checks the branch"
    echo "    3. APPROVE:     bash scripts/pr.sh"
    echo "       CHANGES:     bash scripts/loop.sh   (reads the findings), commit, review again"
    echo "  Where am I, any time: bash scripts/start.sh status"
    exit 0
  fi

  { tail -40 .loop-test-out.txt; grep -A50 -iE '^(Noticed|Disputed)' FAILURES.txt 2>/dev/null; } > .loop-failures.tmp
  mv .loop-failures.tmp FAILURES.txt
  err "tests RED after iteration $i - feeding failures back"
  tail -8 .loop-test-out.txt | sed 's/^/            /'
done

# ---------- hit the cap ----------
echo ""
echo "=============================================="
err "STOPPED at the ${MAX_ITERS}-iteration cap - suite still RED."
echo "=============================================="
usage_summary "$MAX_ITERS"
echo "----------------------------------------------"
list_generated_files
echo "----------------------------------------------"
echo "  This usually means the PLAN was wrong, not the code."
echo "  Do NOT just re-run the loop. Instead:"
echo "    1. git diff                 # read what it actually did"
echo "    2. cat FAILURES.txt         # read the real failure"
echo "    3. re-plan ${ID} on Opus and update ${PLAN_FILE} (approve again)"
echo "    4. git checkout .           # discard, if the approach was wrong"
exit 1
