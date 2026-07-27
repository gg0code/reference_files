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

LOOP_VERSION="v3"

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
4. Every new file starts with a header: purpose + the REQ-IDs it serves.
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

# ---------- the loop ----------
for i in $(seq 1 "$MAX_ITERS"); do
  step "Iteration $i/$MAX_ITERS  (fresh context)"

  claude -p "$(cat PROMPT.md)" --permission-mode acceptEdits \
    || { err "claude invocation failed on iteration $i"; exit 1; }

  step "Iteration $i — running: $TEST_CMD"
  if $TEST_CMD > .loop-test-out.txt 2>&1; then
    tail -5 .loop-test-out.txt
    ok "SUITE GREEN on iteration $i"
    rm -f FAILURES.txt .loop-test-out.txt
    echo ""
    echo "=============================================="
    echo " LOOP COMPLETE — suite green after $i iteration(s)"
    echo "=============================================="
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
echo "  This usually means the PLAN was wrong, not the code."
echo "  Do NOT just re-run the loop. Instead:"
echo "    1. git diff                 # read what it actually did"
echo "    2. cat FAILURES.txt         # read the real failure"
echo "    3. go back to pane 1 on Opus and re-plan ${REQ}"
echo "    4. git checkout .           # discard, if the approach was wrong"
exit 1
