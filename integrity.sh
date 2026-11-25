#!/usr/bin/env bash
# integrity.sh - did this branch weaken the checks that judge it?   VERSION: v2.1 (kit v3.14.1)
#
#   bash scripts/integrity.sh                     check the current branch (committed + uncommitted + untracked)
#   bash scripts/integrity.sh --list              only list the protected paths and patterns
#   bash scripts/integrity.sh --self-test         run the I5 suppression check on fixed cases (exit 1 on a wrong result)
#   bash scripts/integrity.sh --lock-state        print "<ID> <sha>" when this branch's tests are locked, else nothing
#   bash scripts/integrity.sh --lock-files        the test files the lock covers (added or changed by the branch up to the lock)
#   bash scripts/integrity.sh --is-locked-test P  exit 0 when path P is a test path and this branch's tests are locked
#   bash scripts/integrity.sh --is-test-path P    exit 0 when path P is a path the lock covers
#
# The builder writes the code AND could edit the things that judge the code. This script compares the
# branch with its merge-base on main and FAILS when, without an exception in the approved plan, it:
#   I1 changes a protected file: gate limits and tool config (pyproject.toml, package.json, tsconfig,
#      ruff/mypy/pytest/coverage/eslint config), lockfiles, the kit scripts, CI, .claude/, CLAUDE.md, RULES.md
#   I2 deletes or renames an existing test file
#   I3 removes test functions or assertions from an existing test file
#   I4 adds a skip / xfail / only marker to a test
#   I5 adds a lint or type suppression (# noqa, type: ignore, pragma: no cover, eslint-disable, @ts-ignore, nolint, #[allow])
#      (v2.1) Not checked: *.md, *.txt, *.html, and exactly integrity.sh and loop.sh, at scripts/ or the repo root
#      (SUPPRESS_EXEMPT_RE): this script's pattern list and loop.sh's prompt name the markers without using them.
#   I6 (v2) changes, deletes, renames or adds ANY test path (TEST_PATH_RE, conftest.py, fixtures/; not *.md) after the
#      plan's lock line "Tests locked: <sha>" (written by scripts/lock_tests.sh). A path whose content equals the
#      base branch's version came from main and is ignored. Only the user removes the lock line.
#
# Exceptions: the plan (docs/plans/<ID>.md) may hold a section
#     ## Allowed exceptions
#     - pyproject.toml: add httpx (approved dependency, 02-architecture.md section 6)
#     - tests/features/notes/test_service.py: replace TC-004 test (behaviour changed in REQ-007)
# A finding is allowed when its file path appears in that section. The plan is approved by a human,
# so every exception is a human decision, and the reviewer reads the section.
#
# Run by gate.sh (so loop.sh, autopilot.sh, pr.sh and CI all get it). Exit 1 on any unallowed finding.
# On main, or with no merge-base, there is nothing to compare: exit 0.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "integrity: not inside a git repo"; exit 0; }
cd "$ROOT" || exit 2

PROTECTED_RE='^(pyproject\.toml|setup\.cfg|pytest\.ini|tox\.ini|\.coveragerc|mypy\.ini|ruff\.toml|\.ruff\.toml|conftest\.py|uv\.lock|requirements[^/]*\.txt|package\.json|package-lock\.json|pnpm-lock\.yaml|yarn\.lock|tsconfig[^/]*\.json|\.eslintrc[^/]*|eslint\.config\.[a-z]+|jest\.config\.[a-z]+|vitest\.config\.[a-z]+|go\.mod|go\.sum|Cargo\.toml|Cargo\.lock|clippy\.toml|\.golangci\.ya?ml|\.doclintignore|\.gitleaks\.toml|CLAUDE\.md|docs/RULES\.md|scripts/[^/]+\.(sh|py)|\.github/.*|\.claude/.*|\.mcp\.json)$'
SKIP_RE='(@pytest\.mark\.(skip|xfail)|pytest\.skip\(|unittest\.skip|\.skip\(|\.only\(|\bxit\(|\bxdescribe\(|\bfit\(|\bfdescribe\(|t\.Skip\(|#\[ignore\])'
SUPPRESS_RE='(#[[:space:]]*noqa|type:[[:space:]]*ignore|pragma:[[:space:]]*no[[:space:]]*cover|eslint-disable|@ts-ignore|@ts-nocheck|@ts-expect-error|//[[:space:]]*nolint|#\[allow\(|#!\[allow\(|NOSONAR)'
SUPPRESS_EXEMPT_RE='^(scripts/)?(integrity|loop)\.sh$'   # I5: anchored at both ends; nothing else is exempt
TEST_PATH_RE='(^|/)(tests?|__tests__|spec)/|(^|/)test_[^/]*\.py$|_test\.(py|go)$|\.(test|spec)\.[jt]sx?$'
TEST_DEF_RE='^-[[:space:]]*(def test_|async def test_|func Test|#\[test\]|(it|test|describe)\(|assert|expect\(|self\.assert)'
LOCK_RE="${TEST_PATH_RE}|(^|/)conftest\.py\$|(^|/)fixtures?/"   # I6: what the lock freezes (minus *.md)
is_lock_path() { printf '%s' "$1" | grep -qE "$LOCK_RE" && ! printf '%s' "$1" | grep -qE '\.md$'; }
suppressions_added() {   # suppressions_added <path> <added lines>: print how many added lines hold a suppression (I5)
  if printf '%s' "$1" | grep -qE "$SUPPRESS_EXEMPT_RE"; then echo 0; return 0; fi
  case "$1" in *.md|*.txt|*.html) echo 0; return 0 ;; esac
  printf '%s\n' "$2" | grep -cE "$SUPPRESS_RE"
  return 0
}

if [ "${1:-}" = "--list" ]; then
  echo "Protected files (I1):    $PROTECTED_RE"
  echo "Skip markers (I4):       $SKIP_RE"
  echo "Suppressions (I5):       $SUPPRESS_RE"
  echo "  not checked for I5:    $SUPPRESS_EXEMPT_RE  and *.md, *.txt, *.html"
  echo "Locked test paths (I6):  $LOCK_RE  (not *.md)"
  exit 0
fi

if [ "${1:-}" = "--self-test" ]; then   # fixed cases for suppressions_added; needs no branch or plan
  ST_FAIL=0; ST_N=0
  st_case() {   # st_case <flag|pass> <path> <added line>
    local n; n="$(suppressions_added "$2" "+$3")"; ST_N=$((ST_N+1))
    if { [ "$1" = flag ] && [ "$n" -gt 0 ]; } || { [ "$1" = pass ] && [ "$n" -eq 0 ]; }; then
      echo "  ok    $1  $2"
    else
      echo "  FAIL  expected $1, got $n  $2: $3"; ST_FAIL=$((ST_FAIL+1))
    fi
  }
  st_exempt() {   # st_exempt <path> <line>: the line holds a marker, so only the exemption keeps it from being flagged
    if printf '%s\n' "$2" | grep -qE "$SUPPRESS_RE"; then st_case pass "$1" "$2"
    else ST_N=$((ST_N+1)); ST_FAIL=$((ST_FAIL+1)); echo "  FAIL  fixture holds no marker, so it proves nothing  $1"; fi
  }
  PATTERN_LINE="$(cat <<'EOF'
SUPPRESS_RE='(#[[:space:]]*noqa|type:[[:space:]]*ignore|pragma:[[:space:]]*no[[:space:]]*cover|eslint-disable|@ts-ignore|@ts-nocheck|@ts-expect-error|//[[:space:]]*nolint|#\[allow\(|#!\[allow\(|NOSONAR)'
EOF
)"
  HELP_LINE='   lockfiles, CI, scripts/*.sh, .claude/), or add # noqa, type: ignore or skip markers. scripts/integrity.sh'
  echo "integrity.sh v2.1 --self-test (I5 suppressions)"
  st_case flag src/app/plans.py     'width = layout(a, b)  # noqa: E501'
  st_case flag src/app/plans.py     'plan = load(raw)  # type: ignore[arg-type]'
  st_case flag tests/test_plans.py  'from app.plans import *  # noqa'
  st_case flag scripts/gate.sh      'echo ok  # noqa'
  st_case flag scripts/loop.sh.bak  "$HELP_LINE"
  st_case flag src/scripts/loop.sh  "$HELP_LINE"
  st_case flag scripts/integrity.py "$PATTERN_LINE"
  st_exempt scripts/integrity.sh    "$PATTERN_LINE"
  st_exempt integrity.sh            "$PATTERN_LINE"
  st_exempt scripts/loop.sh         "$HELP_LINE"
  st_exempt loop.sh                 "$HELP_LINE"
  st_exempt docs/RULES.md           'Never add `# noqa` or `type: ignore` to silence a check.'
  st_case pass src/app/plans.py     'return total'
  if [ "$ST_FAIL" -gt 0 ]; then echo "  RESULT: FAIL - $ST_FAIL of $ST_N case(s) wrong"; exit 1; fi
  echo "  RESULT: PASS - $ST_N case(s)"
  exit 0
fi

BRANCH="${GITHUB_HEAD_REF:-$(git branch --show-current 2>/dev/null)}"
ID="$(printf '%s' "$BRANCH" | grep -oE '(REQ|BUG)-[0-9]{3}' | head -1)"
PLAN="docs/plans/${ID:-none}.md"
ALLOWED=""; LOCK=""
# Read the COMMITTED plan, and only when it is approved: an uncommitted or draft edit to the plan
# (for example by the builder during a loop) grants nothing and removes no lock.
if [ -n "$ID" ] && git cat-file -e "HEAD:$PLAN" 2>/dev/null; then
  PLAN_TXT="$(git show "HEAD:$PLAN")"
  case "$(printf '%s\n' "$PLAN_TXT" | grep -m1 -v '^[[:space:]]*$')" in
    "Status: APPROVED"*)
      ALLOWED="$(printf '%s\n' "$PLAN_TXT" | awk '/^##[[:space:]]+Allowed exceptions/{on=1;next} /^##[[:space:]]/{on=0} on' | grep -vE '^[[:space:]]*(<!--|None\.?$)')"
      case "$BRANCH" in feat/*|fix/*)
        LOCK="$(printf '%s\n' "$PLAN_TXT" | sed -nE 's/^Tests locked:[[:space:]]*([0-9a-f]{7,40}).*/\1/p' | head -1)" ;;
      esac ;;
  esac
fi

case "${1:-}" in
  --lock-state) [ -n "$LOCK" ] && echo "$ID $LOCK"; exit 0 ;;
  --is-locked-test) [ -n "$LOCK" ] && is_lock_path "${2:-}"; exit $? ;;
  --is-test-path) is_lock_path "${2:-}"; exit $? ;;
  --lock-files)
    [ -n "$LOCK" ] || exit 0
    for ref in origin/main main origin/master master; do git rev-parse --verify -q "$ref" >/dev/null 2>&1 && { LB="$(git merge-base "$ref" "$LOCK" 2>/dev/null)"; break; }; done
    git diff --name-only "${LB:-$LOCK}" "$LOCK" 2>/dev/null | while IFS= read -r p; do is_lock_path "$p" && echo "$p"; done
    exit 0 ;;
esac

case "$BRANCH" in main|master|"") echo "integrity: on '${BRANCH:-detached}' - nothing to compare (PASS)"; exit 0 ;; esac
BASE=""
for ref in origin/main main origin/master master; do
  git rev-parse --verify -q "$ref" >/dev/null 2>&1 && { BASE="$ref"; break; }
done
[ -n "$BASE" ] || { echo "integrity: no main branch found - nothing to compare (PASS)"; exit 0; }
MB="$(git merge-base "$BASE" HEAD 2>/dev/null)" || { echo "integrity: no merge-base with $BASE (PASS)"; exit 0; }

allowed() { [ -n "$ALLOWED" ] && printf '%s\n' "$ALLOWED" | grep -qF -- "$1"; }
# Kit upgrades (new scripts, hooks, CI from the kit) run on a branch named chore/kit-<version>:
# protected-file changes (I1) are allowed there and listed; tests rules (I2-I5) still apply. The PR and your review decide.
KIT_BRANCH=0; case "$BRANCH" in chore/kit-*) KIT_BRANCH=1 ;; esac

FINDINGS=0; EXCEPTED=0; REPORT=""
flag() {   # flag <rule> <path> <what>
  if [ "$KIT_BRANCH" = 1 ] && [ "$1" = I1 ]; then
    EXCEPTED=$((EXCEPTED+1)); REPORT="${REPORT}    ALLOWED $1 $2: $3 (kit upgrade branch - review it in the PR)
"
  elif allowed "$2"; then
    EXCEPTED=$((EXCEPTED+1)); REPORT="${REPORT}    ALLOWED $1 $2: $3 (plan: Allowed exceptions)
"
  else
    FINDINGS=$((FINDINGS+1)); REPORT="${REPORT}    FAIL    $1 $2: $3
"
  fi
}

# Everything that differs from the merge-base: committed, staged, unstaged and untracked.
CHANGES="$(git diff --name-status -M "$MB" -- . 2>/dev/null)"
UNTRACKED="$(git ls-files --others --exclude-standard 2>/dev/null | grep -vE '^(PROMPT\.md|FAILURES\.txt|\.loop-.*)$')"
[ -n "$UNTRACKED" ] && CHANGES="${CHANGES}
$(printf '%s\n' "$UNTRACKED" | sed 's/^/A\t/')"

while IFS=$'\t' read -r st p1 p2; do
  [ -n "${st:-}" ] || continue
  path="${p2:-$p1}"
  # I1 protected files (the plan itself and review files are not protected)
  if printf '%s' "$p1" | grep -qE "$PROTECTED_RE"; then flag I1 "$p1" "protected file changed ($st)"
  elif [ -n "${p2:-}" ] && printf '%s' "$p2" | grep -qE "$PROTECTED_RE"; then flag I1 "$p2" "protected file changed ($st)"; fi
  # I2 existing test file deleted or renamed
  case "$st" in
    D*|R*) printf '%s' "$p1" | grep -qE "$TEST_PATH_RE" && flag I2 "$p1" "existing test file deleted or renamed" ;;
  esac
  # added lines only exist for A/M/R
  case "$st" in D*) continue ;; esac
  [ -f "$path" ] || continue
  if git cat-file -e "$MB:$path" 2>/dev/null; then
    diff_out="$(git diff -U0 "$MB" -- "$path" 2>/dev/null)"
  else
    diff_out="$(sed 's/^/+/' "$path")"
  fi
  added="$(printf '%s\n' "$diff_out" | grep -E '^\+' | grep -vE '^\+\+\+')"
  # I3 removed test definitions or assertions from an existing test file
  if printf '%s' "$path" | grep -qE "$TEST_PATH_RE" && git cat-file -e "$MB:$path" 2>/dev/null; then
    removed_n="$(printf '%s\n' "$diff_out" | grep -vE '^---' | grep -cE "$TEST_DEF_RE")"
    added_n="$(printf '%s\n' "$added" | sed 's/^+/-/' | grep -cE "$TEST_DEF_RE")"
    if [ "${removed_n:-0}" -gt "${added_n:-0}" ]; then
      flag I3 "$path" "$removed_n test/assert line(s) removed, $added_n added - tests got weaker"
    fi
  fi
  # I4 skip markers, I5 suppressions in added lines
  if printf '%s' "$path" | grep -qE "$TEST_PATH_RE"; then
    n="$(printf '%s\n' "$added" | grep -cE "$SKIP_RE")"
    [ "${n:-0}" -gt 0 ] && flag I4 "$path" "$n skip/xfail/only marker(s) added"
  fi
  n="$(suppressions_added "$path" "$added")"
  [ "${n:-0}" -gt 0 ] && flag I5 "$path" "$n lint/type suppression(s) added"
done <<< "$CHANGES"

# I6 tests locked: no test path may differ from the lock commit (committed, staged, unstaged or untracked)
same_as_base() {   # same_as_base <path>: the file (or its absence) matches the base branch, so the change came from main
  local want; want="$(git rev-parse -q --verify "$BASE:$1" 2>/dev/null)"
  if [ -f "$1" ]; then [ -n "$want" ] && [ "$(git hash-object "$1")" = "$want" ]; else [ -z "$want" ]; fi
}
if [ -n "$LOCK" ]; then
  if ! git cat-file -e "${LOCK}^{commit}" 2>/dev/null; then
    flag I6 "$PLAN" "lock sha $LOCK not found in this repo - the user re-locks (bash scripts/lock_tests.sh)"
  elif ! git merge-base --is-ancestor "$LOCK" HEAD 2>/dev/null; then
    flag I6 "$PLAN" "lock sha $LOCK is not an ancestor of HEAD (history rewritten?) - the user re-locks"
  else
    LOCK_CHANGES="$(git diff --name-status -M "$LOCK" -- . 2>/dev/null)"
    [ -n "$UNTRACKED" ] && LOCK_CHANGES="${LOCK_CHANGES}
$(printf '%s\n' "$UNTRACKED" | sed 's/^/A\t/')"
    while IFS=$'\t' read -r st p1 p2; do
      [ -n "${st:-}" ] || continue
      for p in "$p1" ${p2:+"$p2"}; do
        is_lock_path "$p" || continue
        same_as_base "$p" && continue
        flag I6 "$p" "test path changed after the lock at ${LOCK:0:7} ($st) - tests are locked"
      done
    done <<< "$LOCK_CHANGES"
  fi
fi

echo "integrity.sh v2.1 - branch $BRANCH vs $BASE ($(git rev-parse --short "$MB")) - plan: $([ -f "$PLAN" ] && echo "$PLAN" || echo none)${LOCK:+ - tests locked at ${LOCK:0:7}}"
[ -n "$REPORT" ] && printf '%s' "$REPORT"
if [ "$FINDINGS" -gt 0 ]; then
  echo "  RESULT: FAIL - $FINDINGS change(s) weaken or alter the checks."
  echo "  Fix the cause instead. If a change is truly needed, the USER adds the path with a reason under"
  echo "  '## Allowed exceptions' in $PLAN (a plan change, so it is approved again)."
  [ -n "$LOCK" ] && echo "  I6: a locked test that is wrong goes under 'Disputed' (FAILURES.txt or docs/tests/$ID.md); the user unlocks."
  exit 1
fi
echo "  RESULT: PASS ($EXCEPTED allowed by the plan)"
