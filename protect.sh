#!/usr/bin/env bash
# protect.sh - turn on GitHub branch protection for main.   VERSION: v1 (kit v3.12)
#
#   bash scripts/protect.sh            apply protection (asks you to confirm; YES=1 skips the question)
#   bash scripts/protect.sh --show     show the current protection, change nothing
#
# Why: the kit's hooks are pattern checks on this machine - a safety net. Branch protection is enforced by
# GitHub for every client, every agent and every token, so it is the wall. With it on:
#   - main changes only through a PR whose CI check "gate" is green and up to date with main
#   - nobody (admins included) can force-push to main or delete it; history stays linear
#   - the PR needs no human approval count (a solo developer merges their own PR with pr.sh merge);
#     the reviewer agent's APPROVE and your own review stay the people-side of the gate
#
# Run it after setup is approved (spec docs are committed straight to main until then) and after CI has
# run once (GitHub only offers a check it has seen). Afterwards, scope changes also go through a PR.
# Private repos: branch protection needs GitHub Pro, Team or Enterprise. On a free plan, make the repo
# public or upgrade; until then start.sh check reports FAIL and autopilot will not run.
set -uo pipefail

ok()  { echo "    OK    : $*"; }
err() { echo "    ERROR : $*" >&2; }
die() { err "$*"; exit 1; }

case "${1:-}" in -h|--help) sed -n '2,18p' "$0"; exit 0 ;; esac
command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 || die "gh is not installed or not authenticated (gh auth login)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repo"
cd "$ROOT" || die "cannot enter $ROOT"
BASE="main"; git rev-parse --verify -q main >/dev/null || BASE="master"
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" || die "no GitHub repo for this folder (git remote -v)"
CHECK="${CHECK_NAME:-gate}"   # the job name in .github/workflows/ci.yml

if [ "${1:-}" = "--show" ]; then
  gh api "repos/$REPO/branches/$BASE/protection" 2>/dev/null \
    | python3 -m json.tool 2>/dev/null || echo "    no branch protection on $REPO $BASE"
  exit 0
fi

grep -qE "^[[:space:]]+${CHECK}:" .github/workflows/ci.yml 2>/dev/null \
  || die ".github/workflows/ci.yml has no job named '$CHECK' (set CHECK_NAME=<job> if you renamed it)"
if ! gh api "repos/$REPO/commits/$BASE/check-runs" --jq ".check_runs[].name" 2>/dev/null | grep -qxF "$CHECK"; then
  echo "    WARN  : GitHub has not seen a '$CHECK' check on $BASE yet. Push once and let CI run, or PRs may wait forever."
fi

echo "    Protect $REPO branch $BASE:"
echo "      - changes only through a PR; CI check '$CHECK' must pass and be up to date"
echo "      - applies to admins too; no force-push, no deletion; linear history; conversations resolved"
if [ "${YES:-0}" != 1 ]; then
  [ -t 0 ] || die "needs your confirmation: run it in a terminal, or YES=1 bash scripts/protect.sh"
  read -r -p "    Apply? Type yes: " ans; [ "$ans" = yes ] || die "nothing changed"
fi

body="$(cat <<JSON
{
  "required_status_checks": { "strict": true, "contexts": ["$CHECK"] },
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 0, "dismiss_stale_reviews": true },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
)"
if out="$(printf '%s' "$body" | gh api -X PUT "repos/$REPO/branches/$BASE/protection" --input - 2>&1)"; then
  ok "branch protection is on for $REPO $BASE"
  echo "    Check: bash scripts/protect.sh --show    or    bash scripts/start.sh check"
else
  err "GitHub refused: $(printf '%s' "$out" | head -3)"
  case "$out" in
    *"Upgrade to GitHub Pro"*|*"403"*) echo "            Private repos on a free plan cannot use branch protection: make the repo public or upgrade." ;;
  esac
  exit 1
fi
