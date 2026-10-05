#!/usr/bin/env bash
# _lib.sh - shared helpers for the kit's Claude Code hooks (sourced, not registered).   Kit v2.13
# Hooks get one JSON object on stdin. Exit 0 = allow; exit 2 = block, and stderr is shown to Claude.

HOOK_INPUT="$(cat)"

# hook_get <python expression on d>: read a field from the hook input, e.g. hook_get 'd["tool_input"].get("command","")'
hook_get() { printf '%s' "$HOOK_INPUT" | python3 -c "import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
try: print($1 or '')
except Exception: print('')" 2>/dev/null; }

project_dir() { printf '%s' "${CLAUDE_PROJECT_DIR:-$(hook_get 'd.get("cwd","")')}"; }

# block <reason>: refuse the tool call and tell Claude why and what to do instead
block() { printf 'Blocked by the kit (.claude/hooks): %s\n' "$*" >&2; exit 2; }

# kit_event <kind> <message>: a line in .kit/events.jsonl for the dashboard
kit_event() {
  local dir m; dir="$(project_dir)"; [ -n "$dir" ] || return 0
  m="$(printf '%s' "$2" | tr -d '\n\r\t' | sed 's/\\/\\\\/g; s/"/\\"/g' | cut -c1-200)"
  mkdir -p "$dir/.kit" 2>/dev/null && printf '{"ts":"%s","src":"claude","kind":"%s","id":"","msg":"%s"}\n' \
    "$(date +%Y-%m-%dT%H:%M:%S%z)" "$1" "$m" >> "$dir/.kit/events.jsonl" 2>/dev/null || true
}
