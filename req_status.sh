#!/usr/bin/env bash
# req-status.sh — generate a requirements implementation log for a spec-driven project.  VERSION: v1
#
# Scans the repo and produces a Markdown ledger of every REQ-ID: whether it has an
# approved plan, whether it is merged to the base branch, its GitHub Issue and PR,
# and which test cases (TC-IDs) exist for it. Project-agnostic — it relies only on
# the kit's conventions (docs/plans/<REQ>.md, feat(<REQ>) commits, TC-IDs in tests).
#
# Usage:
#   bash req-status.sh                 # print the log to stdout
#   bash req-status.sh -o docs/REQUIREMENTS_STATUS.md   # write to a file
#
# Needs: git. Uses gh if available (for Issue/PR state); degrades gracefully without it.
set -uo pipefail

OUT=""
[ "${1:-}" = "-o" ] && OUT="${2:?-o needs a path}"

# ---- locate base branch ----
BASE=""
for ref in origin/main origin/master main master; do
  git rev-parse --verify -q "$ref" >/dev/null 2>&1 && { BASE="$ref"; break; }
done

HAVE_GH=0
command -v gh >/dev/null 2>&1 && HAVE_GH=1

# ---- discover REQ-IDs (union of docs + commits) ----
reqs="$( { grep -rhoE 'REQ-[0-9]{3}' docs 2>/dev/null
           git log "$BASE" --oneline 2>/dev/null | grep -oE 'REQ-[0-9]{3}'
         } | sort -u )"

emit() { if [ -n "$OUT" ]; then printf '%s\n' "$*" >>"$OUT"; else printf '%s\n' "$*"; fi; }

[ -n "$OUT" ] && : > "$OUT"

total=0; done_n=0
rows=""

for req in $reqs; do
  total=$((total+1))

  # plan present?
  if [ -f "docs/plans/${req}.md" ]; then plan="yes"; else plan="—"; fi

  # merged to base? (feat|fix conventional commit)
  hit="$(git log -E --oneline --grep="(feat|fix)\(${req}\)" "$BASE" 2>/dev/null | head -1)"
  if [ -n "$hit" ]; then status="merged"; done_n=$((done_n+1)); else status="pending"; fi

  # Issue + PR via gh
  issue="—"; pr="—"
  if [ "$HAVE_GH" = 1 ]; then
    isn="$(gh issue list --search "$req" --state all --json number,state --jq '.[0] | "#\(.number) (\(.state|ascii_downcase))"' 2>/dev/null)"
    [ -n "$isn" ] && [ "$isn" != "#null (null)" ] && issue="$isn"
    prn="$(gh pr list --search "$req" --state all --json number,state --jq '.[0] | "#\(.number) (\(.state|ascii_downcase))"' 2>/dev/null)"
    [ -n "$prn" ] && [ "$prn" != "#null (null)" ] && pr="$prn"
  fi

  # test files referencing this REQ, and the TC-IDs implemented in them
  tfiles="$(grep -rl "$req" tests 2>/dev/null || true)"
  ntests=0; tcs="—"
  if [ -n "$tfiles" ]; then
    ntests="$(printf '%s\n' "$tfiles" | grep -c . )"
    tcids="$(grep -rhoE 'TC-[0-9]+' $tfiles 2>/dev/null | sort -u | paste -sd, - )"
    [ -n "$tcids" ] && tcs="$tcids"
  fi

  rows="${rows}| ${req} | ${plan} | ${status} | ${issue} | ${pr} | ${ntests} | ${tcs} |
"
done

# ---- write the report ----
emit "# Requirements Implementation Log"
emit ""
emit "Generated: $(date '+%Y-%m-%d %H:%M')  ·  Base: ${BASE:-<none>}  ·  gh: $([ $HAVE_GH = 1 ] && echo on || echo off)"
emit ""
emit "Summary: **${total} requirements** · **${done_n} merged** · **$((total-done_n)) pending**"
emit ""
emit "| REQ-ID | Plan | Status | Issue | PR | Test files | TC-IDs in tests |"
emit "|--------|------|--------|-------|----|-----------|-----------------|"
if [ -n "$OUT" ]; then printf '%s' "$rows" >>"$OUT"; else printf '%s' "$rows"; fi

[ -n "$OUT" ] && echo "wrote $OUT"
exit 0
