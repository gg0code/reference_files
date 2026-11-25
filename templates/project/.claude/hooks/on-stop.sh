#!/usr/bin/env bash
# on-stop.sh - Stop hook: Claude has finished answering.   Kit v3.13
# 1. Records it for the dashboard and the conductor ("Claude is idle"), so they know when the next step may start.
# 2. v3.13: on a feat/ or fix/ branch where src/ or tests/ changed since the last green gate, runs
#    bash scripts/gate.sh. Red = exit 2 with a short summary on stderr, so Claude keeps working.
#    Never blocks twice in a row (stop_hook_active), and skips: main, chore/kit-*, other branches,
#    KIT_LOOP=1 (loop.sh and autopilot run the gate themselves), docs-only changes, a standard or strict
#    plan whose tests are not locked yet (they are meant to be red), and a src/tests state it already blocked on.
#    State: .kit/stop-green-hash and .kit/stop-red-hash (the src/tests content hash).
. "$(dirname "$0")/_lib.sh"
kit_event claude_idle "Claude finished and is waiting for the next instruction"
dir="$(project_dir)"; [ -n "$dir" ] && date +%s > "$dir/.kit/claude-idle" 2>/dev/null

[ -n "$dir" ] && cd "$dir" 2>/dev/null || exit 0
[ "${KIT_LOOP:-0}" = 1 ] && exit 0
[ "$(hook_get 'd.get("stop_hook_active") is True and "yes"')" = yes ] && exit 0
br="$(git branch --show-current 2>/dev/null)"
case "$br" in feat/*|fix/*) ;; *) exit 0 ;; esac   # main, chore/kit-*, docs/ ... never block
[ -f scripts/gate.sh ] || exit 0

id="$(printf '%s' "$br" | grep -oE '(REQ|BUG)-[0-9]{3}' | head -1)"
plan="docs/plans/${id:-none}.md"
if [ -f "$plan" ]; then
  risk="$(sed -nE 's/^Risk:[[:space:]]*([A-Za-z]+).*/\1/p' "$plan" | head -1 | tr '[:upper:]' '[:lower:]')"
  if [ "${risk:-standard}" != light ] && ! grep -qE '^Tests locked:[[:space:]]*[0-9a-f]{7}' "$plan"; then
    exit 0   # /tests stage: failing tests are expected until the user locks them
  fi
fi

# docs-only: no src/ or tests/ change on the branch or in the working tree
base=""; for ref in origin/main main origin/master master; do git rev-parse --verify -q "$ref" >/dev/null && { base="$ref"; break; }; done
mb="$( [ -n "$base" ] && git merge-base "$base" HEAD 2>/dev/null)"
changed="$( { [ -n "$mb" ] && git diff --name-only "$mb" -- src tests; git ls-files -o --exclude-standard -- src tests; } 2>/dev/null)"
[ -n "$changed" ] || exit 0

hash="$( { git ls-files -s -- src tests; git diff HEAD -- src tests
           git ls-files -o --exclude-standard -z -- src tests | xargs -0r git hash-object --; } 2>/dev/null | git hash-object --stdin)"
mkdir -p .kit
[ "$hash" = "$(cat .kit/stop-green-hash 2>/dev/null)" ] && exit 0
[ "$hash" = "$(cat .kit/stop-red-hash 2>/dev/null)" ] && exit 0   # already told Claude about exactly this state

out="$(mktemp)"; trap 'rm -f "$out"' EXIT
TO=""; command -v timeout >/dev/null 2>&1 && TO="timeout ${STOP_GATE_TIMEOUT:-80}"
$TO bash scripts/gate.sh >"$out" 2>&1; rc=$?
if [ "$rc" = 0 ]; then echo "$hash" > .kit/stop-green-hash; rm -f .kit/stop-red-hash; exit 0; fi
[ "$rc" = 124 ] && exit 0   # gate too slow for a hook: never block on a timeout; loop.sh and CI still run it
echo "$hash" > .kit/stop-red-hash
{
  echo "Blocked by the kit (.claude/hooks/on-stop.sh): the quality gate is RED on $br, so this is not done yet."
  grep -E '^[[:space:]]+FAIL[[:space:]]' "$out" | head -8
  echo "First failure lines:"
  grep -E '^[[:space:]]+\|' "$out" | head -12
  echo "Fix the cause (never weaken a test or a check), then run: bash scripts/gate.sh"
} >&2
exit 2
