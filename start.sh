#!/usr/bin/env bash
# start.sh - start the next piece of work, or show where you are.      VERSION: v4
#
#   bash scripts/start.sh                    start the next unticked REQ in docs/TASKS.md
#   bash scripts/start.sh REQ-004            start (or resume) that REQ
#   bash scripts/start.sh bug "symptom"      file the next BUG-ID as an Issue and start fix/BUG-00X
#   bash scripts/start.sh status             where am I: ID, Issue, plan, review, PR, next action
#   bash scripts/start.sh check              is the kit installed and active in this project? (PASS/WARN/FAIL)
#                                            includes the MCP servers in .mcp.json (docs/MCP.md)
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

# kit_event <kind> <id> <message> [extra-json]: one line in .kit/events.jsonl for the dashboard (scripts/dashboard.py)
kit_event() {
  local m; m="$(printf '%s' "${3:-}" | tr -d '\n\r\t' | sed 's/\\/\\\\/g; s/"/\\"/g')"
  mkdir -p .kit 2>/dev/null && printf '{"ts":"%s","src":"%s","kind":"%s","id":"%s","msg":"%s"%s}\n' \
    "$(date +%Y-%m-%dT%H:%M:%S%z)" "$(basename "$0" .sh)" "$1" "${2:-}" "$m" "${4:+,$4}" >> .kit/events.jsonl 2>/dev/null || true
}

case "${1:-}" in -h|--help|help) sed -n '2,15p' "$0"; exit 0 ;; esac

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
            -) if grep -q '^## Walkthrough' "$rv" 2>/dev/null; then nxt="bash scripts/pr.sh"; else nxt="claude pane: explain     (walkthrough), then: bash scripts/pr.sh"; fi ;;
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

# ---------- check: MCP servers (called from kit_check; uses its pass/wrn/bad) ----------
mcp_check() {
  local v srv
  if [ ! -f .mcp.json ]; then
    wrn ".mcp.json missing: copy it from the kit's templates/project/ (re-running scaffold.sh adds it and keeps your files)"
    return 0
  fi
  if ! python3 -m json.tool .mcp.json >/dev/null 2>&1; then bad ".mcp.json is not valid JSON"; return 0; fi
  for srv in chrome-devtools playwright graphify; do
    python3 -c "import json,sys; sys.exit(0 if '$srv' in json.load(open('.mcp.json')).get('mcpServers',{}) else 1)" 2>/dev/null \
      && pass ".mcp.json defines $srv" || wrn ".mcp.json has no '$srv' server (see templates/project/.mcp.json)"
  done
  if python3 -c "import json,re,sys; t=json.dumps(json.load(open('.mcp.json'))); sys.exit(1 if re.search(r'(API_KEY|TOKEN)\"\s*:\s*\"(?!\\$\\{)[^\"]+',t) else 0)" 2>/dev/null; then :
  else bad ".mcp.json contains an API key or token - it is committed to git. Remove it; add that server with: claude mcp add --scope local ..."; fi
  if [ -f docs/MCP.md ]; then pass "docs/MCP.md (MCP setup check and usage rules)"; else wrn "docs/MCP.md missing: copy it from the kit's templates/project/docs/"; fi
  grep -q '@docs/MCP.md' CLAUDE.md 2>/dev/null && pass "CLAUDE.md loads docs/MCP.md" \
    || wrn "CLAUDE.md does not contain '@docs/MCP.md': Claude will not run the MCP check (add it to section 0)"
  if command -v node >/dev/null 2>&1; then
    v="$(node --version 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/')"
    if [ "${v:-0}" -ge 18 ] 2>/dev/null; then pass "node $(node --version) (chrome-devtools, playwright)"
    else wrn "node $(node --version) is older than v18: chrome-devtools and playwright need 18+ (https://nodejs.org)"; fi
  else wrn "node not found: chrome-devtools and playwright cannot start (install the LTS from https://nodejs.org)"; fi
  command -v npx >/dev/null 2>&1 || wrn "npx not found (it comes with node)"
  if command -v uv >/dev/null 2>&1; then pass "uv $(uv --version 2>/dev/null | awk '{print $2}') (graphify)"
  else wrn "uv not found: graphify cannot start. Install: curl -LsSf https://astral.sh/uv/install.sh | sh"; fi
  if [ -f graphify-out/graph.json ]; then pass "graphify map built (graphify-out/graph.json)"
  else wrn "graphify map not built yet: in the claude pane run /graphify .  (optional while the project is small)"; fi
  grep -qxF 'graphify-out/' .gitignore 2>/dev/null || wrn ".gitignore does not list graphify-out/"
  echo "    INFO  : connection itself can only be seen inside claude: type /mcp in the claude pane"
}

# ---------- check: is the kit installed and active? ----------
kit_check() {
  local fails=0 warns=0 f n=0 t a d st
  pass() { echo "    PASS  : $*"; }
  wrn()  { echo "    WARN  : $*"; warns=$((warns+1)); }
  bad()  { echo "    FAIL  : $*"; fails=$((fails+1)); }
  echo ""
  echo "==> 1. Files from the kit (copied by scaffold.sh)"
  if [ -f CLAUDE.md ] && grep -q '^## 0. Session start check' CLAUDE.md; then
    pass "CLAUDE.md at the repo root ($(grep -m1 -oE 'Template v[0-9.]+' CLAUDE.md || echo 'version unknown')) - Claude Code loads it every session"
  else bad "CLAUDE.md missing at the repo root or not the kit's version (start claude from THIS folder)"; fi
  for f in docs/00-idea.md docs/01-prd.md docs/02-architecture.md docs/03-ui-design.md docs/04-testplan.md \
           docs/05-launch-checklist.md docs/RULES.md docs/TASKS.md docs/MEMORY.md docs/plans/_TEMPLATE.md docs/reviews/README.md; do
    [ -f "$f" ] || { bad "$f missing"; n=$((${n:-0}+1)); }
  done
  [ "${n:-0}" -eq 0 ] && pass "docs/: 00-05, RULES, TASKS, MEMORY, plans/_TEMPLATE, reviews/ present"
  if [ -f .claude/agents/reviewer.md ] && grep -q '^name: reviewer' .claude/agents/reviewer.md; then pass ".claude/agents/reviewer.md (second agent)"
  else bad ".claude/agents/reviewer.md missing: copy it from the kit's templates/project/"; fi
  if [ -f .claude/settings.json ] && python3 -m json.tool .claude/settings.json >/dev/null 2>&1; then pass ".claude/settings.json (pre-approved read-only commands for the reviewer)"
  else wrn ".claude/settings.json missing or invalid JSON: the reviewer will ask permission for every command"; fi
  n=0
  for f in start.sh loop.sh pr.sh doclint.sh gate.sh req_status.sh autopilot.sh dashboard.py; do
    [ -f "scripts/$f" ] || { n=$((n+1)); if [ "$f" = autopilot.sh ] || [ "$f" = dashboard.py ]; then wrn "scripts/$f missing (optional)"; else bad "scripts/$f missing: copy it from the kit"; fi; }
  done
  [ "$n" -eq 0 ] && pass "scripts/: start, loop, pr, doclint, gate, req_status, autopilot, dashboard"
  if grep -l $'\r' scripts/*.sh >/dev/null 2>&1; then bad "scripts/*.sh have Windows line endings (CRLF). Fix: sed -i 's/\r\$//' scripts/*.sh"; fi
  for t in PROMPT.md FAILURES.txt .autopilot/ CLAUDE.local.md .kit/; do
    grep -qxF "$t" .gitignore 2>/dev/null || wrn ".gitignore does not list $t"
  done
  if [ -f .github/workflows/ci.yml ]; then pass ".github/workflows/ci.yml (CI)"; else bad "no CI: re-run the kit's scaffold.sh with a stack (it keeps your files)"; fi

  echo ""
  echo "==> 2. Tools"
  for t in git claude python3; do command -v "$t" >/dev/null 2>&1 && pass "$t" || bad "$t not found on PATH"; done
  if [ "$HAVE_GH" = 1 ]; then pass "gh (authenticated)"; else bad "gh missing or not authenticated (gh auth login)"; fi
  command -v jq >/dev/null 2>&1 && pass "jq" || wrn "jq not found: no cost numbers in loop.sh; autopilot will not run"
  git remote get-url origin >/dev/null 2>&1 && pass "git remote origin: $(git remote get-url origin)" || wrn "no git remote 'origin'"
  if [ "$HAVE_GH" = 1 ]; then
    gh api "repos/{owner}/{repo}/branches/${BASE}/protection" >/dev/null 2>&1 && pass "branch protection on ${BASE}" || wrn "no branch protection on ${BASE} yet (turn it on after CI has run once: runbook Phase 2c)"
  fi

  echo ""
  echo "==> 3. Setup status (CLAUDE.md section 0)"
  grep -q 'one or two sentences: the product and who it is for' CLAUDE.md 2>/dev/null && wrn "CLAUDE.md sections 1 and 2 (FILL IN) still hold the template examples (setup step 4)" || pass "CLAUDE.md FILL IN sections filled"
  a=0; d=0; t=0
  for f in docs/*.md; do
    st="$(head -1 "$f")"
    case "$st" in "Status: APPROVED"*) a=$((a+1)) ;; "Status: DRAFT"*) d=$((d+1)) ;; "Status: TEMPLATE"*) t=$((t+1)); echo "          template: $f" ;; esac
  done
  if [ "$t" -eq 0 ] && [ "$d" -eq 0 ]; then pass "docs: $a approved, none left at TEMPLATE or DRAFT"
  else wrn "docs: $a approved, $d draft, $t template - type 'setup' in the claude pane"; fi

  echo ""
  echo "==> 4. Documentation conventions and quality gate (docs/RULES.md sections 2 and 3)"
  if [ -f scripts/doclint.sh ]; then
    n="$(bash scripts/doclint.sh 2>&1 | tail -1)"
    case "$n" in *OK*) pass "$n" ;; *) wrn "$n  (run: bash scripts/doclint.sh)" ;; esac
  fi
  if [ -f pyproject.toml ]; then
    grep -q '^\[tool.ruff' pyproject.toml && grep -q '^\[tool.mypy' pyproject.toml \
      && pass "pyproject.toml carries the gate settings (ruff limits, mypy strict, pytest)" \
      || wrn "pyproject.toml has no [tool.ruff] / [tool.mypy]: copy them from the kit's templates/stacks/python/pyproject.toml"
    [ -f uv.lock ] && pass "uv.lock present (pinned dependencies)" || wrn "no uv.lock yet: run 'uv sync' (checklist O8)"
  fi
  [ -f scripts/gate.sh ] && echo "    INFO  : the full quality gate (tests included) runs with: bash scripts/gate.sh"

  echo ""
  echo "==> 5. MCP servers (.mcp.json, docs/MCP.md)"
  mcp_check

  echo ""
  echo "==> 6. Is Claude actually using the kit? (cannot be checked from a script)"
  echo "    In the claude pane, ask:"
  echo "      Which project files have you read this session, and what does section 0 of CLAUDE.md tell you to do?"
  echo "    Expect: CLAUDE.md, docs/RULES.md, docs/TASKS.md, docs/MEMORY.md, and the TEMPLATE/DRAFT setup check."
  echo "    If not: claude was started outside this folder. Quit it, cd $ROOT, start claude again."
  echo ""
  if [ "$fails" -gt 0 ]; then echo "  RESULT: $fails FAIL, $warns WARN - fix the FAIL lines first"; return 1; fi
  echo "  RESULT: kit installed ($warns WARN)"
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
  local existing; existing="$(git branch --format='%(refname:short)' --list "feat/${id}" "feat/${id}-*" | head -1)"
  [ -n "$existing" ] || existing="$(git branch -r --format='%(refname:short)' --list "origin/feat/${id}" "origin/feat/${id}-*" | head -1 | sed 's|^origin/||')"
  checkout_branch "${existing:-feat/${id}-$(slug "$title")}"   # resume an existing branch whatever its slug
  echo ""
  echo "  Working on $id  Issue #$issue  $title"
  kit_event start "$id" "Started work on: $title"
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
  kit_event bug "$id" "Bug reported and being fixed: $symptom"
  echo "  next   : add the steps to the Issue, then in the claude pane: reproduce $id end-to-end and write a FAILING test (runbook Phase 3)"
}

case "${1:-}" in
  "")              start_req "" ;;
  status|where)    show_status ;;
  check|doctor)    kit_check ;;
  bug)             shift; start_bug "$*" ;;
  REQ-*)           start_req "$1" ;;
  *)               die "unknown argument '$1' (try --help)" ;;
esac
