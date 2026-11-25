#!/usr/bin/env bash
# guard-files.sh - PreToolUse hook for Read, Edit, Write, MultiEdit, NotebookEdit.   Kit v3.13
# Enforces four rules instead of only asking for them:
#   1. Secrets: never read or write .env files (.env.example is fine).          CLAUDE.md section 10
#   2. Never work on main: no code changes (src/, tests/, migrations/, scripts/) while main is checked out.
#      Docs stay editable on main for setup and `scope` (CLAUDE.md section 0 and 4).
#   3. The builder never edits what judges it: the hooks, settings, reviewer agent, gate/integrity/loop
#      scripts and CI workflows change only by the user's hand. To update the kit itself, start claude
#      with KIT_MAINTAINER=1 (the user's decision, never Claude's).
#   4. Locked tests (v3.13): on a feat/ or fix/ branch whose committed plan carries the lock line
#      (scripts/lock_tests.sh), no edit to test files (integrity.sh's test paths, conftest.py, fixtures/; not *.md),
#      no edit to that plan, and no edit that writes a lock line into any plan. Only the user unlocks.
# v3.12: fails closed (no Python or unreadable input = block); rule 3 added.
. "$(dirname "$0")/_lib.sh"
guard_require_input

tool="$(hook_get 'd.get("tool_name","")')"
file="$(hook_get 'd["tool_input"].get("file_path") or d["tool_input"].get("notebook_path","")')"
[ -n "$file" ] || exit 0
base="$(basename "$file")"

case "$base" in
  .env.example|.env.sample|.env.template) ;;
  .env|.env.*) block "$tool on $base: secret files are off limits. Ask the user to set the value, and read settings through src/app/config.py." ;;
esac

case "$tool" in Read) exit 0 ;; esac
dir="$(project_dir)"
f="$(printf '%s' "$file" | tr '\\' '/')"; d="$(printf '%s' "$dir" | tr '\\' '/')"
rel="${f#"$d"/}"

if [ "${KIT_MAINTAINER:-0}" != 1 ]; then
  case "$rel" in
    .claude/hooks/*|.claude/settings.json|.claude/agents/*|.github/workflows/*|\
    scripts/gate.sh|scripts/integrity.sh|scripts/doclint.sh|scripts/loop.sh|scripts/pr.sh|scripts/autopilot.sh|scripts/protect.sh|scripts/lock_tests.sh)
      block "$rel is part of the kit's checks (hooks, settings, reviewer, gate, CI). The builder never edits what judges it. If it truly needs a change, tell the user why; they edit it or restart claude with KIT_MAINTAINER=1." ;;
  esac
fi

# 4. locked tests and plans
case "$rel" in docs/plans/*)
  if [ "$(hook_get '__import__("re").search(r"(^|\n|\")Tests locked:[ \t]*[0-9a-f]{7}", json.dumps(d["tool_input"]).replace("\\n", "\n")) and "yes"')" = yes ]; then
    block "$rel: only the user locks tests, by running bash scripts/lock_tests.sh after reading docs/tests/<ID>.md."
  fi
  if git -C "$dir" show "HEAD:$rel" 2>/dev/null | grep -qE '^Tests locked:[[:space:]]*[0-9a-f]{7}'; then
    block "$rel carries the test lock, so it changes only by the user's hand. If a test is wrong, write it under Disputed in docs/tests/<ID>.md (or FAILURES.txt in a loop); the user unlocks it."
  fi ;;
esac
if [ -f "$dir/scripts/integrity.sh" ] && (cd "$dir" && bash scripts/integrity.sh --is-locked-test "$rel" >/dev/null 2>&1); then
  lid="$(cd "$dir" && bash scripts/integrity.sh --lock-state 2>/dev/null | awk '{print $1}')"
  block "tests for ${lid:-this branch} are locked. If a test is wrong, write it under Disputed; the user unlocks it."
fi

case "$rel" in
  src/*|tests/*|migrations/*|scripts/*)
    br="$(git -C "$dir" branch --show-current 2>/dev/null)"
    if [ "$br" = main ] || [ "$br" = master ]; then
      block "editing $rel on $br. Code changes happen on a feature branch: run 'bash scripts/start.sh' (next REQ) or 'bash scripts/start.sh bug \"symptom\"' first."
    fi ;;
esac
exit 0
