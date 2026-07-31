#!/usr/bin/env bash
# loop.sh — bounded Ralph loop for ONE GitHub Issue.        VERSION: v3
# Usage:  bash loop.sh <issue-number> <REQ-ID> [max-iters]
#   e.g.  bash loop.sh 1 REQ-001   (one Issue per REQ-ID; the REQ number need not equal the Issue number)
#
# Loops inside an Issue; NEVER loops across a review gate.
#   - fresh context every iteration (that is the point — context rot past ~100-150k tokens)
#   - state lives in the codebase + git + PROMPT.md, not in conversation history
#   - EXIT CONDITION = green test suite, not the agent's opinion
#   - hard iteration cap so a wrong hypothesis can't burn your budget
#
# v2: requires an approved plan file (docs/plans/<REQ>.md) and enforces it every pass.
# v3: auto-detects the test command per stack (no more npm-in-a-Python-repo);
#     prints its VERSION so you can tell a stale copy from a current one.
#
# ONE-TIME per workspace: run `claude` interactively here once and accept the trust
# dialog, or the loop's `claude -p` calls run untrusted and ignore your permission
# allowlist (files may not get written). See the trust warning if you hit it.
#
# Run from the repo root, on a feature branch, in the git pane. Watch the test pane.
set -uo pipefail

LOOP_VERSION="v4"

# ---------- help / usage ----------
usage() {
  cat <<'HELP'
loop.sh — bounded Ralph loop for ONE GitHub Issue.        VERSION: v4

WHAT IT DOES
  Repeatedly runs Claude Code against a single Issue with a FRESH context each
  pass, feeding test failures back in, until the test suite is green or a hard
  iteration cap is hit. State lives in the codebase + git + PROMPT.md, never in
  chat history. The EXIT CONDITION is a green suite, not the agent's opinion.
  Prints per-iteration cost + token usage and a per-REQ total (needs jq; without
  jq it still runs, just without the numbers).

INVOCATION
  bash loop.sh <issue-number> <REQ-ID> [max-iters]
  bash loop.sh --help

  <issue-number>   GitHub Issue number, e.g. 1
  <REQ-ID>         Requirement id, e.g. REQ-001   (one Issue per REQ-ID; the
                   REQ number need not equal the Issue number)
  [max-iters]      Hard iteration cap (default: 8)

  Examples:
    bash loop.sh 1 REQ-001
    bash loop.sh 1 REQ-001 5
    TEST_CMD="pytest -q" bash loop.sh 1 REQ-001
    PLAN_FILE=docs/plans/REQ-001.md bash loop.sh 1 REQ-001

ENV OVERRIDES
  TEST_CMD    Force the test command (else auto-detected per stack:
              npm test / pytest / cargo test / go test ./...).
  PLAN_FILE   Path to the approved plan (default: docs/plans/<REQ>.md).

TELEMETRY
  Install jq to see cost/token usage:  apt install jq  (or: brew install jq)
  With jq present the loop prints, each pass, the call's cost, input/output and
  cache-read tokens, turn count, and wall time, plus a running per-REQ total that
  is summarised at the end (green or capped). Without jq the loop is unchanged
  except the numbers are omitted.

ONE-TIME SETUP (per machine / workspace)
  1. Install the Claude Code CLI and confirm it is on PATH:   command -v claude
  2. In THIS repo, run `claude` interactively once and ACCEPT the trust dialog.
     Otherwise the loop's `claude -p` calls run untrusted, ignore your
     permission allowlist, and files may silently not get written.
  3. Make sure your test runner works by hand once:
       - Python: source .venv/bin/activate && pytest
       - Node:   npm test
  4. Have `gh` (GitHub CLI) authenticated if you want to open the PR at the end.

BEFORE EVERY RUN (per Issue)
  1. Be inside the git repo, on a FEATURE branch (the loop refuses main/master):
       git checkout -b feat/REQ-001-short-name
  2. PREPARE + APPROVE A PLAN, and save it to docs/plans/<REQ>.md. The loop uses
     a fresh context each pass and cannot see a plan that only lives in a chat.
     Suggested prompt to generate the plan (run on a strong model, e.g. Opus):

       "Read docs/01-prd.md for REQ-001 and docs/04-testplan.md for its TC-###
        rows. Produce a concrete implementation plan for REQ-001: files to
        create/change, the approach, and how each TC row will be satisfied.
        Do NOT write code yet — output only the plan."

     Then review it and save the approved version:
       mkdir -p docs/plans
       $EDITOR docs/plans/REQ-001.md      # paste the approved plan
       git add docs/plans/REQ-001.md && git commit -m "plan(REQ-001): approved"

RECOMMENDED tmux LAYOUT (3 panes)
  Pane 1 — PLAN:  run `claude` (Opus) here to draft/re-plan the approach.
  Pane 2 — LOOP:  run the loop and WATCH it here:
                    bash loop.sh 1 REQ-001
  Pane 3 — TEST/GIT WATCH:  observe the suite and drive git afterwards:
                    watch -n2 'tail -20 .loop-test-out.txt 2>/dev/null'
                    # after LOOP COMPLETE:
                    git diff
                    git add -A
                    git commit -m "feat(REQ-001): ... (#1)"
                    git push -u origin $(git branch --show-current)
                    gh pr create --title "feat(REQ-001): ..." \
                                 --body  "Implements REQ-001. Closes #1"

  Quick setup:
    tmux new -s loop \; split-window -h \; split-window -v \; select-pane -t 0

WHEN IT STOPS
  Green   -> prints the exact git/gh commands to review, commit, push, and PR.
  At cap  -> usually the PLAN was wrong, not the code. Do NOT just re-run:
               git diff            # what it actually did
               cat FAILURES.txt    # the real failure
               re-plan REQ-001 in pane 1 (Opus)
               git checkout .      # discard, if the approach was wrong
HELP
}

case "${1:-}" in
  -h|--help|help|"") usage; exit 0 ;;
esac

ISSUE="${1:?ERROR : issue number required   (usage: bash loop.sh <issue#> <REQ-ID>, e.g. 1 REQ-001)}"
REQ="${2:?ERROR : REQ-ID required           (usage: bash loop.sh <issue#> <REQ-ID>, e.g. 1 REQ-001)}"
MAX_ITERS="${3:-8}"

ok()   { echo "    OK    : $*"; }
err()  { echo "    ERROR : $*" >&2; }
step() { echo ""; echo "==> $*"; }

# ---------- guardrails ----------
step "Preflight  (loop.sh $LOOP_VERSION)"
command -v claude >/dev/null 2>&1 || { err "claude CLI not found"; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { err "not inside a git repo"; exit 1; }

BRANCH="$(git branch --show-current)"
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  err "refusing to loop on '$BRANCH'. Create a branch first:"
  echo "            git checkout -b feat/${REQ}-short-name"
  exit 1
fi
ok "branch: $BRANCH"
ok "issue : #$ISSUE   requirement: $REQ"

# ---------- test command: explicit override, else auto-detect per stack ----------
# The old default was "npm test", which silently fails in non-Node repos.
# Set TEST_CMD=... to force one; otherwise we detect it from repo files.
if [ -n "${TEST_CMD:-}" ]; then
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
  echo "            Set it explicitly, e.g.:  TEST_CMD=\"pytest\" bash loop.sh $ISSUE $REQ"
  exit 1
fi

# Sanity: don't grind 8 iterations with a command that can't possibly work here.
case "$TEST_CMD" in
  npm*|yarn*|pnpm*) [ -f package.json ] || { err "TEST_CMD is '$TEST_CMD' but there is no package.json here. Wrong stack? Set TEST_CMD=..."; exit 1; } ;;
  pytest*)          command -v pytest >/dev/null 2>&1 || { err "pytest not found on PATH. Activate your venv: source .venv/bin/activate"; exit 1; } ;;
esac
ok "max iterations: $MAX_ITERS"

# ---------- token / cost telemetry ----------
# `claude -p --output-format json` returns per-call cost + token usage. We parse
# it with jq, print a line per iteration, and accumulate a per-REQ total. If jq
# is missing we degrade to plain mode (no numbers) rather than failing the run.
if command -v jq >/dev/null 2>&1; then
  HAVE_JQ=1; ok "usage : token/cost tracking ON (jq found)"
else
  HAVE_JQ=0; ok "usage : token/cost tracking OFF (install jq to enable: apt install jq)"
fi

# ---------- approved plan (the human-gated decisions) ----------
# The loop uses a FRESH context each pass, so it cannot see a plan that only
# lives in a chat session. Persist the approved plan to this file and the loop
# will bind every pass to it. Convention: docs/plans/<REQ>.md
PLAN_FILE="${PLAN_FILE:-docs/plans/${REQ}.md}"
if [ -f "$PLAN_FILE" ]; then
  ok "plan  : $PLAN_FILE (will be enforced every pass)"
  PLAN_BLOCK="$(cat "$PLAN_FILE")"
else
  err "no approved plan found at $PLAN_FILE"
  echo "            The loop would then re-derive its own approach each pass,"
  echo "            ignoring the plan you reviewed. Save the approved plan first:"
  echo "              mkdir -p docs/plans"
  echo "              # paste/redirect the approved plan into:"
  echo "              \$EDITOR $PLAN_FILE"
  echo "            then commit it and re-run. (Set PLAN_FILE=... to override the path.)"
  exit 1
fi

# ---------- the prompt, re-read fresh every iteration ----------
cat > PROMPT.md <<PROMPT
# Task — Issue #${ISSUE} / ${REQ}

Implement ${REQ} on branch ${BRANCH}.

## APPROVED PLAN — follow this exactly, do NOT invent a different approach
${PLAN_BLOCK}

Rules (from CLAUDE.md — these are binding):
1. Implement strictly per the APPROVED PLAN above. If the plan and your instinct
   disagree, the plan wins. If the plan is genuinely unworkable, STOP and leave a
   note in FAILURES.txt rather than silently changing the approach.
2. Read docs/01-prd.md for ${REQ} and docs/04-testplan.md for its TC-### rows.
3. Write the tests from those TC rows FIRST, then the implementation.
4. Follow CLAUDE.md > "Documentation conventions": a README in every new directory, a header on every file, and a doc block on every function (what it does, what it calls, who calls it).
5. Do NOT commit. Do NOT open a PR. Do NOT touch main. Implementation only.
6. If \`${TEST_CMD}\` is failing, read the failure output below and fix the CAUSE.
   Do not delete, skip, or weaken a test to make it pass.

Success = \`${TEST_CMD}\` exits clean with every TC row for ${REQ} covered,
built the way the APPROVED PLAN specifies.

## Current failures
See FAILURES.txt in the repo root (empty on the first pass).
PROMPT

: > FAILURES.txt
ok "wrote PROMPT.md"

# ---------- per-REQ running totals ----------
TOTAL_COST=0; TOTAL_IN=0; TOTAL_OUT=0; TOTAL_CR=0

# usage_summary <iterations-done> — printed in both the green and the cap blocks.
usage_summary() {
  local iters="$1"
  if [ "$HAVE_JQ" != 1 ]; then
    echo "  usage : token/cost totals unavailable (jq not installed)"
    return
  fi
  echo "  USAGE — ${REQ} over ${iters} iteration(s):"
  printf '    total cost : $%s\n'          "$TOTAL_COST"
  printf '    input      : %s tokens\n'    "$TOTAL_IN"
  printf '    output     : %s tokens\n'    "$TOTAL_OUT"
  printf '    cache read : %s tokens\n'    "$TOTAL_CR"
}

# ---------- the loop ----------
for i in $(seq 1 "$MAX_ITERS"); do
  step "Iteration $i/$MAX_ITERS  (fresh context)"

  ITER_START=$(date +%s)
  if [ "$HAVE_JQ" = 1 ]; then
    # JSON mode prints nothing until the pass ends, so the pane would look frozen.
    # Run claude in the background and show a heartbeat (spinner + elapsed) so you
    # can see it is alive and NOT hanging. The JSON lands in a temp file.
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
    cost=$(jq -r '.total_cost_usd            // 0' <<<"$RESP")
    tin=$( jq -r '.usage.input_tokens        // 0' <<<"$RESP")
    tout=$(jq -r '.usage.output_tokens       // 0' <<<"$RESP")
    tcr=$( jq -r '.usage.cache_read_input_tokens // 0' <<<"$RESP")
    turns=$(jq -r '.num_turns                // 0' <<<"$RESP")
    TOTAL_COST=$(awk -v a="$TOTAL_COST" -v b="$cost" 'BEGIN{printf "%.4f", a+b}')
    TOTAL_IN=$(( TOTAL_IN + tin )); TOTAL_OUT=$(( TOTAL_OUT + tout )); TOTAL_CR=$(( TOTAL_CR + tcr ))
  else
    claude -p "$(cat PROMPT.md)" --permission-mode acceptEdits \
      || { err "claude invocation failed on iteration $i"; exit 1; }
  fi
  ITER_SECS=$(( $(date +%s) - ITER_START ))

  if [ "$HAVE_JQ" = 1 ]; then
    ok "cost  : iter $i  \$$cost   in=$tin  out=$tout  cache_read=$tcr  turns=$turns  ${ITER_SECS}s"
    ok "run   : $REQ so far  \$$TOTAL_COST   in=$TOTAL_IN  out=$TOTAL_OUT  ($i iter)"
  else
    ok "iter $i took ${ITER_SECS}s"
  fi

  step "Iteration $i — running: $TEST_CMD"
  if $TEST_CMD > .loop-test-out.txt 2>&1; then
    tail -5 .loop-test-out.txt
    ok "SUITE GREEN on iteration $i"
    rm -f FAILURES.txt .loop-test-out.txt
    echo ""
    echo "=============================================="
    echo " LOOP COMPLETE — suite green after $i iteration(s)"
    echo "=============================================="
    usage_summary "$i"
    echo "----------------------------------------------"
    echo "  Review the diff, THEN (pane 3):"
    echo "    git diff"
    echo "    git add -A"
    echo "    git commit -m \"feat(${REQ}): ... (#${ISSUE})\""
    echo "    git push -u origin ${BRANCH}"
    echo "    gh pr create --title \"feat(${REQ}): ...\" \\"
    echo "                 --body  \"Implements ${REQ}. Closes #${ISSUE}\""
    echo "    # one Issue per REQ-ID, so this PR completes the Issue -> use 'Closes #${ISSUE}'."
    echo "    # (only if you deliberately grouped REQ-IDs would you use 'Refs #${ISSUE}' instead.)"
    exit 0
  fi

  tail -40 .loop-test-out.txt > FAILURES.txt
  err "tests RED after iteration $i — feeding failures back"
  tail -8 FAILURES.txt | sed 's/^/            /'
done

# ---------- hit the cap ----------
echo ""
echo "=============================================="
err "STOPPED at the ${MAX_ITERS}-iteration cap — suite still RED."
echo "=============================================="
usage_summary "$MAX_ITERS"
echo "----------------------------------------------"
echo "  This usually means the PLAN was wrong, not the code."
echo "  Do NOT just re-run the loop. Instead:"
echo "    1. git diff                 # read what it actually did"
echo "    2. cat FAILURES.txt         # read the real failure"
echo "    3. go back to pane 1 on Opus and re-plan ${REQ}"
echo "    4. git checkout .           # discard, if the approach was wrong"
exit 1

