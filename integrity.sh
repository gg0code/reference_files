#!/usr/bin/env bash
# integrity.sh - did this branch weaken the checks that judge it?   VERSION: v1 (kit v3.12)
#
#   bash scripts/integrity.sh            check the current branch (committed + uncommitted + untracked)
#   bash scripts/integrity.sh --list     only list the protected paths and patterns
#
# The builder writes the code AND could edit the things that judge the code. This script compares the
# branch with its merge-base on main and FAILS when, without an exception in the approved plan, it:
#   I1 changes a protected file: gate limits and tool config (pyproject.toml, package.json, tsconfig,
#      ruff/mypy/pytest/coverage/eslint config), lockfiles, the kit scripts, CI, .claude/, CLAUDE.md, RULES.md
#   I2 deletes or renames an existing test file
#   I3 removes test functions or assertions from an existing test file
#   I4 adds a skip / xfail / only marker to a test
#   I5 adds a lint or type suppression (# noqa, type: ignore, pragma: no cover, eslint-disable, @ts-ignore, nolint, #[allow])
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
TEST_PATH_RE='(^|/)(tests?|__tests__|spec)/|(^|/)test_[^/]*\.py$|_test\.(py|go)$|\.(test|spec)\.[jt]sx?$'
TEST_DEF_RE='^-[[:space:]]*(def test_|async def test_|func Test|#\[test\]|(it|test|describe)\(|assert|expect\(|self\.assert)'

if [ "${1:-}" = "--list" ]; then
  echo "Protected files (I1):    $PROTECTED_RE"
  echo "Skip markers (I4):       $SKIP_RE"
  echo "Suppressions (I5):       $SUPPRESS_RE"
  exit 0
fi

BRANCH="${GITHUB_HEAD_REF:-$(git branch --show-current 2>/dev/null)}"
case "$BRANCH" in main|master|"") echo "integrity: on '${BRANCH:-detached}' - nothing to compare (PASS)"; exit 0 ;; esac
BASE=""
for ref in origin/main main origin/master master; do
  git rev-parse --verify -q "$ref" >/dev/null 2>&1 && { BASE="$ref"; break; }
done
[ -n "$BASE" ] || { echo "integrity: no main branch found - nothing to compare (PASS)"; exit 0; }
MB="$(git merge-base "$BASE" HEAD 2>/dev/null)" || { echo "integrity: no merge-base with $BASE (PASS)"; exit 0; }

ID="$(printf '%s' "$BRANCH" | grep -oE '(REQ|BUG)-[0-9]{3}' | head -1)"
PLAN="docs/plans/${ID:-none}.md"
ALLOWED=""
# Read the COMMITTED plan, and only when it is approved: an uncommitted or draft edit to the plan
# (for example by the builder during a loop) grants nothing.
if [ -n "$ID" ] && git cat-file -e "HEAD:$PLAN" 2>/dev/null; then
  PLAN_TXT="$(git show "HEAD:$PLAN")"
  case "$(printf '%s\n' "$PLAN_TXT" | grep -m1 -v '^[[:space:]]*$')" in
    "Status: APPROVED"*)
      ALLOWED="$(printf '%s\n' "$PLAN_TXT" | awk '/^##[[:space:]]+Allowed exceptions/{on=1;next} /^##[[:space:]]/{on=0} on' | grep -vE '^[[:space:]]*(<!--|None\.?$)')" ;;
  esac
fi
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
  case "$path" in *.md|*.txt|*.html) ;; *)
    n="$(printf '%s\n' "$added" | grep -cE "$SUPPRESS_RE")"
    [ "${n:-0}" -gt 0 ] && flag I5 "$path" "$n lint/type suppression(s) added"
  ;; esac
done <<< "$CHANGES"

echo "integrity.sh v1 - branch $BRANCH vs $BASE ($(git rev-parse --short "$MB")) - plan: $([ -f "$PLAN" ] && echo "$PLAN" || echo none)"
[ -n "$REPORT" ] && printf '%s' "$REPORT"
if [ "$FINDINGS" -gt 0 ]; then
  echo "  RESULT: FAIL - $FINDINGS change(s) weaken or alter the checks."
  echo "  Fix the cause instead. If a change is truly needed, the USER adds the path with a reason under"
  echo "  '## Allowed exceptions' in $PLAN (a plan change, so it is approved again)."
  exit 1
fi
echo "  RESULT: PASS ($EXCEPTED allowed by the plan)"
