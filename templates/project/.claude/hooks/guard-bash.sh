#!/usr/bin/env bash
# guard-bash.sh - PreToolUse hook for Bash.   Kit v3.12
# Blocks the commands the kit's rules forbid when Claude runs them (builder, loop, reviewer):
# reading .env files, force-push and branch deletes, hard reset and git clean, skipping git hooks,
# loosening the gate, recursive deletes outside the project, pushes to main, writing code on main
# through the shell, and shell edits to the kit's own guard and gate files.
# v3.12: fails closed (no Python = block); catches refspec pushes (HEAD:main), split rm flags,
#        shell redirects into code on main, and plain 'git push' on main that would carry code.
# These are pattern checks, a safety net. Branch protection on GitHub (scripts/protect.sh) is the wall.
. "$(dirname "$0")/_lib.sh"
guard_require_input

cmd="$(hook_get 'd["tool_input"].get("command","")')"
[ -n "$cmd" ] || exit 0
dir="$(project_dir)"
br="$(git -C "$dir" branch --show-current 2>/dev/null)"
on_main=0; case "$br" in main|master) on_main=1 ;; esac
has() { printf '%s' "$cmd" | grep -qE -- "$1"; }

CODE_DIRS='(src|tests|migrations|scripts)/'
KIT_FILES='(\.claude/(hooks/|settings\.json|agents/)|scripts/(gate|integrity|doclint|loop|pr|autopilot|protect)\.sh|\.github/workflows/)'
EDIT_CMDS='(^|[[:space:];&|(])(tee|sed[[:space:]]+(-[a-zA-Z]*i|--in-place)|perl[[:space:]]+-[a-zA-Z]*i|cp|mv|rm|truncate|install|dd|patch|git[[:space:]]+apply)([[:space:]]|$)'
# writes_to <path-regex>: a redirect into that path, or an editing command in the same command line that names it
writes_to() {
  has ">{1,2}[[:space:]]*[\"']?(\./|[^[:space:]\"']*/)?$1" && return 0
  has "$EDIT_CMDS" && has "(^|[[:space:]/\"'=])$1" && return 0
  return 1
}

# 1. secrets
if has '(^|[[:space:]/"'"'"'=<])\.env(\.[A-Za-z0-9_-]+)?([[:space:]"'"'"';|&)]|$)' && ! has '\.env\.(example|sample|template)'; then
  block "this command touches a .env file. Secret values stay with the user; settings are read through the app's config."
fi

# 2. history rewriting and remote deletes
if has 'git[[:space:]]+push'; then
  has 'git[[:space:]]+push[^|;&]*[[:space:]](--force(-with-lease|-if-includes)?(=[^[:space:]]*)?|-[a-zA-Z]*f[a-zA-Z]*)([[:space:]]|$)' \
    && block "force-push rewrites shared history. Make a new commit instead."
  has 'git[[:space:]]+push[^|;&]*[[:space:]]\+[^[:space:]]' \
    && block "a '+' refspec is a force-push. Make a new commit instead."
  has 'git[[:space:]]+push[^|;&]*[[:space:]](--mirror|--all|--delete|-d|--prune)([[:space:]]|$)' \
    && block "this push can delete or overwrite remote branches. Push one feature branch: bash scripts/pr.sh"
  has 'git[[:space:]]+push[^|;&]*[[:space:]]:[^[:space:]]' \
    && block "':branch' deletes a remote branch. Ask the user."
  # 3. explicit pushes to main, including refspecs such as HEAD:main or refs/heads/main
  has 'git[[:space:]]+push[^|;&]*[[:space:]:/](main|master)([[:space:]]|$)' \
    && block "pushing to main. Changes reach main through a PR: bash scripts/pr.sh. (Setup docs and scope changes are pushed with plain 'git push' while on main.)"
  # 4. plain 'git push' on main is allowed for setup docs and scope only: refuse it when it would carry code
  if [ "$on_main" = 1 ]; then
    ahead="$(git -C "$dir" diff --name-only '@{u}..HEAD' 2>/dev/null || git -C "$dir" diff --name-only "origin/$br..HEAD" 2>/dev/null)"
    if printf '%s\n' "$ahead" | grep -qE "^$CODE_DIRS|^$KIT_FILES|^(pyproject\.toml|package\.json|uv\.lock|package-lock\.json)$"; then
      block "these commits on $br change code or kit files ($(printf '%s\n' "$ahead" | grep -E "^$CODE_DIRS|^$KIT_FILES|^(pyproject\.toml|package\.json|uv\.lock|package-lock\.json)$" | head -3 | paste -sd' ' -)). Only docs go straight to main. Tell the user; the code belongs on a branch (bash scripts/start.sh)."
    fi
  fi
fi
has 'git[[:space:]]+reset[^|;&]*--hard' \
  && block "git reset --hard throws work away. Use 'git stash' or a revert commit, or ask the user."
has 'git[[:space:]]+clean[^|;&]*[[:space:]]-[a-zA-Z]*f' \
  && block "git clean -f deletes untracked work for good. Delete specific files, or ask the user."
has 'git[[:space:]]+(branch[^|;&]*[[:space:]]-D|update-ref[^|;&]*[[:space:]]-d|filter-branch|filter-repo|replace)([[:space:]]|$)' \
  && block "this rewrites or deletes git refs. Ask the user."

# 5. skipping hooks and loosening the gate
has '--no-verify' && block "--no-verify skips the checks. Fix what the check reports instead."
has 'git[[:space:]]+commit[^|;&]*[[:space:]]-[a-zA-Z]*n[a-zA-Z]*([[:space:]]|$)' \
  && block "'git commit -n' skips the checks (--no-verify). Fix what the check reports instead."
has 'core\.hooksPath' && block "changing core.hooksPath disables the git hooks. Ask the user."
has '(^|[[:space:];&|])(GATE_SKIP|COV_MIN|NO_GATE|NO_DOCLINT|ALLOW_UNPROTECTED)=' \
  && block "this loosens the quality gate. Only the user may do that, with a written reason (CLAUDE.md section 10). Fix the cause."
has '(^|[[:space:];&|])(FORCE|YES)=1[^|;&]*scripts/pr\.sh' \
  && block "FORCE=1 / YES=1 on pr.sh skips the review or your confirmation. The user runs that themselves."
has '(^|[[:space:];&|])AUTO_MERGE=1' \
  && block "AUTO_MERGE=1 merges without a human. The user starts autopilot level 3 themselves."

# 6. recursive deletes outside the project (any flag order: rm -rf, rm -r -f, rm --recursive)
if has '(^|[[:space:];&|(])(sudo[[:space:]]+)?rm[[:space:]]'; then
  verdict="$(CMD="$cmd" PROJ="$dir" "$HOOK_PY" - <<'PY' 2>/dev/null
import os, posixpath, re, shlex
cmd, proj = os.environ["CMD"], os.environ.get("PROJ", "")
def norm(p):
    p = p.replace("\\", "/")
    m = re.match(r"^([A-Za-z]):/(.*)", p)            # C:/x -> /c/x (Git Bash) and /mnt/c/x (WSL) compare equal
    if m: p = "/" + m.group(1).lower() + "/" + m.group(2)
    p = re.sub(r"^/mnt/([a-z])/", r"/\1/", p)
    return posixpath.normpath(p).rstrip("/") or "/"
home = norm(os.environ.get("HOME") or os.path.expanduser("~"))
root = norm(proj) if proj else ""
bad = []
for seg in re.split(r"&&|\|\||[;|&\n]", cmd):
    try: toks = shlex.split(seg)
    except ValueError: toks = seg.split()
    while toks and toks[0] in ("sudo", "xargs", "command", "exec", "nohup"): toks = toks[1:]
    if not toks or os.path.basename(toks[0]) != "rm": continue
    flags = [t for t in toks[1:] if t.startswith("-")]
    if not any(t == "--recursive" or (not t.startswith("--") and re.search(r"[rR]", t)) for t in flags): continue
    for a in (t for t in toks[1:] if not t.startswith("-")):
        a = a.replace("$HOME", home).replace("${HOME}", home)
        if a.startswith("~"): a = home + a[1:]
        p = norm(a if a.startswith("/") or re.match(r"^[A-Za-z]:", a) else posixpath.join(root or ".", a))
        if not root or p == root or not (p + "/").startswith(root + "/"):
            bad.append(a)
print("BLOCK " + " ".join(bad) if bad else "OK")
PY
)"
  case "$verdict" in
    OK) ;;
    BLOCK*) block "recursive delete of '${verdict#BLOCK }' is outside the project (or the project itself). Delete specific paths inside the project only." ;;
    *) block "could not check this rm command safely. Delete specific files without -r, or ask the user." ;;
  esac
fi

# 7. shell writes to the kit's guard and gate files (any branch): the builder must not edit what judges it
if [ "${KIT_MAINTAINER:-0}" != 1 ] && writes_to "$KIT_FILES"; then
  block "this command changes the kit's guard, gate or CI files. Those change only by the user's hand (kit update)."
fi

# 8. shell writes to code on main (guard-files.sh covers Edit/Write; this covers sed -i, >, tee, cp, mv ...)
if [ "$on_main" = 1 ] && writes_to "$CODE_DIRS"; then
  block "this command changes code on $br. Code changes happen on a feature branch: run 'bash scripts/start.sh' (next REQ) or 'bash scripts/start.sh bug \"symptom\"' first."
fi
exit 0
