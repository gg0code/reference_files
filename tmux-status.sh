#!/usr/bin/env sh
# tmux-status.sh - right side of the tmux status bar (called by .tmux.conf every few seconds)
#   prints:  REQ-014 · gate ✓ green ·
# REQ/BUG id comes from the branch of the focused pane's repo; the gate result is the last
# "gate" line gate.sh wrote to .kit/events.jsonl for that id. Prints nothing outside a git repo.
cd "${1:-.}" 2>/dev/null || exit 0
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
br="$(git branch --show-current 2>/dev/null)"
id="$(printf '%s' "$br" | grep -oE '(REQ|BUG)-[0-9]{3}' | head -1)"
ev="$root/.kit/events.jsonl"
last=""
if [ -f "$ev" ]; then
  if [ -n "$id" ]; then last="$(grep '"kind":"gate"' "$ev" | grep "\"id\":\"$id\"" | tail -1)"
  else last="$(grep '"kind":"gate"' "$ev" | tail -1)"; fi
fi
case "$last" in
  *'"ok":true'*)  gate="gate ✓ green" ;;
  *'"ok":false'*) gate="gate ✗ red" ;;
  *)              gate="gate – not run" ;;
esac
printf '%s · %s · ' "${id:-${br:-detached}}" "$gate"
