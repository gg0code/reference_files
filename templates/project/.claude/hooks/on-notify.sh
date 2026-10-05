#!/usr/bin/env bash
# on-notify.sh - Notification hook: Claude needs you (a permission, or an answer).   Kit v2.13
# Rings the terminal bell and tells the dashboard, so you notice even in another pane or on your phone.
. "$(dirname "$0")/_lib.sh"
msg="$(hook_get 'd.get("message","")')"
kit_event claude_waiting "Claude needs you: ${msg:-a permission or an answer}"
{ printf '\a' > /dev/tty; } 2>/dev/null || true
exit 0
