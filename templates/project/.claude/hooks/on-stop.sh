#!/usr/bin/env bash
# on-stop.sh - Stop hook: Claude has finished answering.   Kit v2.13
# Records it for the dashboard and the conductor ("Claude is idle"), so they know when the next step may start.
. "$(dirname "$0")/_lib.sh"
kit_event claude_idle "Claude finished and is waiting for the next instruction"
dir="$(project_dir)"; [ -n "$dir" ] && date +%s > "$dir/.kit/claude-idle" 2>/dev/null
exit 0
