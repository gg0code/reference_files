#!/usr/bin/env bash
# guard-files.sh - PreToolUse hook for Read, Edit, Write, MultiEdit, NotebookEdit.   Kit v2.13
# Enforces two rules instead of only asking for them:
#   1. Secrets: never read or write .env files (.env.example is fine).          CLAUDE.md section 10
#   2. Never work on main: no code changes (src/, tests/, migrations/, scripts/) while main is checked out.
#      Docs stay editable on main for setup and `scope` (CLAUDE.md section 0 and 4).
. "$(dirname "$0")/_lib.sh"

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
rel="${file#"$dir"/}"
case "$rel" in
  src/*|tests/*|migrations/*|scripts/*)
    br="$(git -C "$dir" branch --show-current 2>/dev/null)"
    if [ "$br" = main ] || [ "$br" = master ]; then
      block "editing $rel on $br. Code changes happen on a feature branch: run 'bash scripts/start.sh' (next REQ) or 'bash scripts/start.sh bug \"symptom\"' first."
    fi ;;
esac
exit 0
