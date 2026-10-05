#!/usr/bin/env bash
# format-file.sh - PostToolUse hook for Edit, Write, MultiEdit.   Kit v2.13
# Formats each Python file Claude writes (ruff format + safe ruff fixes), so style never fails the gate.
# Never blocks: on any problem it does nothing; the gate still decides.
. "$(dirname "$0")/_lib.sh"

file="$(hook_get 'd["tool_input"].get("file_path","")')"
case "$file" in *.py) ;; *) exit 0 ;; esac
dir="$(project_dir)"
[ -f "$file" ] && [ -f "$dir/pyproject.toml" ] && grep -q '^\[tool.ruff' "$dir/pyproject.toml" || exit 0
command -v uv >/dev/null 2>&1 || exit 0
cd "$dir" || exit 0
timeout 20 uv run --quiet ruff format --quiet "$file" >/dev/null 2>&1
timeout 20 uv run --quiet ruff check --fix --quiet "$file" >/dev/null 2>&1
exit 0
