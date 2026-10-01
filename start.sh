#!/usr/bin/env bash
# start.sh - start the next piece of work, or show where you are.      VERSION: v1
#
#   bash scripts/start.sh                    start the next unticked REQ in docs/TASKS.md
#   bash scripts/start.sh REQ-004            start (or resume) that REQ
#   bash scripts/start.sh bug "symptom"      file the next BUG-ID as an Issue and start fix/BUG-00X
#   bash scripts/start.sh status             where am I: ID, Issue, plan, review, PR, next action
#
# You never type an Issue number: it comes from the "REQ-00X (#N) title" line in
# docs/TASKS.md, or from GitHub. The branch name then carries the ID, so loop.sh,
# pr.sh and Claude's `next` / `review` all know which work you are on.
#
# Refuses to start new work while you are on an unfinished REQ/BUG branch (FORCE=1 overrides).
set -uo pipefail

ok()   { echo "    OK    : $*"; }
info() { echo "    ..    : $*"; }
warn() { echo "    WARN  : $*"; }
err()  { echo "    ERROR : $*" >&2; }
die()  { err "$*"; exit 1; }

case "${1:-}" in -h|--help|help) sed -n '2,13p' "$0"; exit 0 ;; esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repo"
cd "$ROOT" || die "cannot enter $ROOT"
HAVE_GH=0; command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && HAVE_GH=1
BASE="main"; git rev-parse --verify -q main >/dev/null || BASE="master"
base_ref() { git rev-parse --verify -q "origin/$BASE" >/dev/null && echo "origin/$BASE" || echo "$BASE"; }

current_id() { git branch --show-current | grep -oE '(REQ|BUG)-[0-9]{3}' | head -1; }
tasks_line() { grep -E "^[[:space:]]*- \[[ x]\] $1 \(#[0-9]+\)" docs/TASKS.md 2>/dev/null | head -1; }
issue_for() {
  local n; n="$(tasks_line "$1" | sed -nE 's/.*\(#([0-9]+)\).*/\1/p')"
  if [ -z "$n" ] && [ "$HAVE_GH" = 1 ]; then
    n="$(gh issue list --search "$1 in:title" --state all --json number --jq '.[0].number // empty' 2>/dev/null)"
  fi
  echo "$n"
}
title_for() {
  local t; t="$(tasks_line "$1" | sed -nE 's/.*\(#[0-9]+\)[[:space:]]*(.*)$/\1/p')"
  if [ -z "$t" ] && [ "$HAVE_GH" = 1 ] && [ -n "${2:-}" ]; then
    t="$(gh issue view "$2" --json title --jq .title 2>/dev/null | sed -E "s/^$1:[[:space:]]*//")"
  fi
  echo "${t:-$1}"
}
slug() { echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-30 | sed -E 's/-+$//'; }
merged() { git log -E --oneline --grep="(feat|fix)\($1\)" "$(base_ref)" 2>/dev/null | grep -q .; }
closed() { [ "$HAVE_GH" = 1 ] && [ -n "$2" ] && [ "$(gh issue view "$2" --json state --jq .state 2>/dev/null)" = "CLOSED" ]; }
first_line() { [ -f "$1" ] && grep -m1 -v '^[[:space:]]*$' "$1"; }

# ---------- status ----------
show_status() {
  local id br issue plan pl rv vl pr dirty nxt
  br="$(git branch --show-current)"; id="$(current_id)"
  echo ""
  echo "  branch : $br"
  if [ -z "$id" ]; then
    echo "  work   : none (not on a REQ or BUG branch)"
    echo "  next   : bash scripts/start.sh            (or: bash scripts/start.sh bug \"symptom\")"
    return 0
  fi
  issue="$(issue_for "$id")"
  plan="docs/plans/$id.md"; pl="$(first_line "$plan")"
  rv="docs/reviews/$id.md"; vl="$(first_line "$rv")"
  pr="-"; [ "$HAVE_GH" = 1 ] && pr="$(gh pr list --head "$br" --state all --json number,state --jq '.[0] | "#\(.number) (\(.state|ascii_downcase))"' 2>/dev/null)"
  [ -z "$pr" ] || [ "$pr" = "#null (null)" ] && pr="-"
  dirty="$(git status --porcelain | grep -cvE ' (PROMPT\.md|FAILURES\.txt)$')"
  echo "  work   : $id  Issue #${issue:-?}  $(title_for "$id" "$issue")"
  echo "  plan   : ${pl:-missing}"
  echo "  review : ${vl:-none yet}"
  echo "  PR     : $pr"
  echo "  files  : $dirty uncommitted"
  case "$pl" in
    "") nxt="claude pane: next          (drafts $plan)" ;;
    "Status: APPROVED"*)
      case "$vl" in
        "") if [ "$dirty" -gt 0 ]; then nxt="commit, then claude pane: review"; else nxt="bash scripts/loop.sh      (then commit, then: review)"; fi ;;
        "Verdict: CHANGES REQUESTED"*) nxt="bash scripts/loop.sh      (reads the findings), commit, then: review" ;;
        "Verdict: APPROVE"*)
          case "$pr" in
            -) nxt="bash scripts/pr.sh" ;;
            *open*) nxt="review the PR on GitHub, then: bash scripts/pr.sh merge" ;;
            *merged*) nxt="bash scripts/start.sh      (next REQ)" ;;
            *) nxt="bash scripts/pr.sh" ;;
          esac ;;
        *) nxt="claude pane: review" ;;
      esac ;;
    *) nxt="read $plan, then set line 1 to 'Status: APPROVED - $(date +%Y-%m-%d)' and commit it" ;;
  esac
  echo "  next   : $nxt"
}

guard_unfinished() {   # refuse to leave unfinished work unless FORCE=1
  local cur; cur="$(current_id)"
  [ -z "$cur" ] && return 0
  [ "$cur" = "${1:-}" ] && return 0
  merged "$cur" && return 0
  if [ "${FORCE:-0}" != 1 ]; then
    err "you are on $cur, which is not merged yet."
    show_status
    echo ""
    echo "    Finish it first, or start new work anyway with: FORCE=1 bash scripts/start.sh ..."
    exit 1
  fi
  warn "leaving unfinished $cur (FORCE=1)"
}

checkout_branch() {   # checkout_branch <name>
  local b="$1"
  [ -z "$(git status --porcelain | grep -vE ' (PROMPT\.md|FAILURES\.txt)$')" ] || die "uncommitted changes. Commit or stash them first."
  if [ "$(git branch --show-current)" = "$b" ]; then ok "already on $b"; return 0; fi
  git checkout -q "$BASE" || die "cannot switch to $BASE"
  git pull -q --ff-only 2>/dev/null || warn "could not pull $BASE (offline?) - continuing from the local copy"
  if git rev-parse --verify -q "$b" >/dev/null; then git checkout -q "$b"; ok "resumed branch $b"
  elif git rev-parse --verify -q "origin/$b" >/dev/null; then git checkout -q -b "$b" "origin/$b"; ok "resumed remote branch $b"
  else git checkout -q -b "$b"; ok "created branch $b from $BASE"; fi
}

start_req() {   # start_req [REQ-00X]
  local id="${1:-}" issue title
  head -1 docs/TASKS.md 2>/dev/null | grep -q '^Status: APPROVED' || warn "docs/TASKS.md is not APPROVED yet - finish setup first (type 'setup' in Claude)"
  if [ -z "$id" ]; then
    local line r n
    while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*-\ \[\ \]\ (REQ-[0-9]{3})\ \(#([0-9]+)\) ]] || continue
      r="${BASH_REMATCH[1]}"; n="${BASH_REMATCH[2]}"
      if merged "$r" || closed "$r" "$n"; then info "$r already done - skipping (tick it with 'wrap up')"; continue; fi
      id="$r"; break
    done < docs/TASKS.md
    [ -n "$id" ] || die "no unticked REQ line like '- [ ] REQ-001 (#12) title' left in docs/TASKS.md"
  fi
  [[ "$id" =~ ^REQ-[0-9]{3}$ ]] || die "not a REQ-ID: $id"
  issue="$(issue_for "$id")"
  [ -n "$issue" ] || die "no Issue number for $id: add '(#N)' to its line in docs/TASKS.md"
  title="$(title_for "$id" "$issue")"
  guard_unfinished "$id"
  checkout_branch "feat/${id}-$(slug "$title")"
  echo ""
  echo "  Working on $id  Issue #$issue  $title"
  show_status | sed -n '/next   :/p'
}

start_bug() {   # start_bug "symptom"
  local symptom="${1:-}" maxn n id url issue
  [ -n "$symptom" ] || die 'describe the bug: bash scripts/start.sh bug "login fails with an empty password"'
  [ "$HAVE_GH" = 1 ] || die "gh is needed to file the bug Issue (gh auth login)"
  guard_unfinished ""
  maxn="$( { gh issue list --search "BUG- in:title" --state all --limit 500 --json title --jq '.[].title' 2>/dev/null
             git log --all --oneline 2>/dev/null
             grep -rhoE 'BUG-[0-9]{3}' docs 2>/dev/null
           } | grep -oE 'BUG-[0-9]{3}' | sed 's/BUG-//' | sort -n | tail -1)"
  n=$((10#${maxn:-0} + 1)); id="$(printf 'BUG-%03d' "$n")"
  local body="Symptom: ${symptom}

Steps to reproduce:
1.

Expected:

Actual:

(Filed by scripts/start.sh. Fill in the steps before the failing test is written.)"
  url="$(gh issue create --title "${id}: ${symptom}" --label bug --body "$body" 2>/dev/null)" \
    || url="$(gh issue create --title "${id}: ${symptom}" --body "$body")" || die "gh issue create failed"
  issue="$(echo "$url" | grep -oE '[0-9]+$')"
  ok "filed $id as Issue #$issue: $url"
  checkout_branch "fix/${id}"
  echo ""
  echo "  Working on $id  Issue #$issue  $symptom"
  echo "  next   : add the steps to the Issue, then in the claude pane: reproduce $id end-to-end and write a FAILING test (runbook Phase 3)"
}

case "${1:-}" in
  "")              start_req "" ;;
  status|where)    show_status ;;
  bug)             shift; start_bug "$*" ;;
  REQ-*)           start_req "$1" ;;
  *)               die "unknown argument '$1' (try --help)" ;;
esac
