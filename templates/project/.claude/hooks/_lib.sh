#!/usr/bin/env bash
# _lib.sh - shared helpers for the kit's Claude Code hooks (sourced, not registered).   Kit v3.12
# Hooks get one JSON object on stdin. Exit 0 = allow; exit 2 = block, and stderr is shown to Claude.
# v3.12: guard hooks FAIL CLOSED. If no working Python is found or the input cannot be parsed,
#        guard_require_input blocks the call instead of silently allowing everything.

HOOK_INPUT="$(cat)"

# A working Python: python3, then python. "Works" means it really runs code: on Windows, python3 can be
# the Microsoft Store stub, which exists on PATH but only prints a message.
HOOK_PY=""
for _py in python3 python; do
  if command -v "$_py" >/dev/null 2>&1 && [ "$("$_py" -c 'print(42)' 2>/dev/null | tr -d '\r')" = 42 ]; then HOOK_PY="$_py"; break; fi
done

# hook_get <python expression on d>: read a field from the hook input, e.g. hook_get 'd["tool_input"].get("command","")'
hook_get() {
  [ -n "$HOOK_PY" ] || return 0
  printf '%s' "$HOOK_INPUT" | "$HOOK_PY" -c "import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
try: print($1 or '')
except Exception: print('')" 2>/dev/null; }

project_dir() { printf '%s' "${CLAUDE_PROJECT_DIR:-$(hook_get 'd.get("cwd","")')}"; }

# block <reason>: refuse the tool call and tell Claude why and what to do instead
block() { printf 'Blocked by the kit (.claude/hooks): %s\n' "$*" >&2; exit 2; }

# guard_require_input: guards call this first. No Python or unreadable input = block (fail closed),
# because an empty command or path would otherwise pass every check.
guard_require_input() {
  [ -n "$HOOK_PY" ] || block "no working python3/python found, so the safety hooks cannot read this tool call. Tell the user: install Python 3 (on Windows run the kit inside WSL), then retry."
  local ok
  ok="$(printf '%s' "$HOOK_INPUT" | "$HOOK_PY" -c "import json,sys
try:
    d=json.load(sys.stdin); print('ok' if isinstance(d.get('tool_input'),dict) else 'bad')
except Exception: print('bad')" 2>/dev/null | tr -d '\r')"
  [ "$ok" = ok ] || block "the safety hook could not parse this tool call's input. Tell the user; do not retry the same call."
}

# kit_event <kind> <message>: a line in .kit/events.jsonl for the dashboard
kit_event() {
  local dir m; dir="$(project_dir)"; [ -n "$dir" ] || return 0
  m="$(printf '%s' "$2" | tr -d '\n\r\t' | sed 's/\\/\\\\/g; s/"/\\"/g' | cut -c1-200)"
  mkdir -p "$dir/.kit" 2>/dev/null && printf '{"ts":"%s","src":"claude","kind":"%s","id":"","msg":"%s"}\n' \
    "$(date +%Y-%m-%dT%H:%M:%S%z)" "$1" "$m" >> "$dir/.kit/events.jsonl" 2>/dev/null || true
}
