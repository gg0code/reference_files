#!/usr/bin/env bash
# guard-bash.sh - PreToolUse hook for Bash.   Kit v2.13
# Blocks the commands the kit's rules forbid, whoever runs them (you, the builder, the loop):
# reading .env files, force-push, hard reset, skipping git hooks, deleting outside the project, pushing to main.
. "$(dirname "$0")/_lib.sh"

cmd="$(hook_get 'd["tool_input"].get("command","")')"
[ -n "$cmd" ] || exit 0

if printf '%s' "$cmd" | grep -qE '(^|[[:space:]/"'"'"'=])\.env(\.[A-Za-z0-9_-]+)?([[:space:]"'"'"';|&)]|$)' \
   && ! printf '%s' "$cmd" | grep -qE '\.env\.(example|sample|template)'; then
  block "this command touches a .env file. Secret values stay with the user; settings are read through the app's config."
fi
printf '%s' "$cmd" | grep -qE 'git[[:space:]]+push([^|;&]*)[[:space:]](--force|-f|--force-with-lease)([[:space:]]|$)' \
  && block "force-push rewrites shared history. Make a new commit instead."
printf '%s' "$cmd" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard' \
  && block "git reset --hard throws work away. Use 'git stash' or a revert commit, or ask the user."
printf '%s' "$cmd" | grep -qE -- '--no-verify' \
  && block "--no-verify skips the checks. Fix what the check reports instead."
printf '%s' "$cmd" | grep -qE 'rm[[:space:]]+-[a-zA-Z]*[rf][a-zA-Z]*[[:space:]]+(/|~|\$HOME|\.\.)([[:space:]/]|$)' \
  && block "recursive delete outside the project. Delete specific paths inside the project only."
printf '%s' "$cmd" | grep -qE 'git[[:space:]]+push[^|;&]*[[:space:]](origin[[:space:]]+)?(main|master)([[:space:]]|$)' \
  && block "pushing straight to main. Changes reach main through a PR: bash scripts/pr.sh. (Setup docs and scope changes are pushed with plain 'git push' while on main.)"
exit 0
