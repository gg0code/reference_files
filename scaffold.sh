#!/usr/bin/env bash
# scaffold.sh - Phase 0 setup for a spec-driven project.          VERSION: v2.11
# Run from your projects root (e.g. ~/Projects), NOT inside a project folder.
#
#   bash /path/to/reference_files/scaffold.sh <app-name> [node|python|go|rust]
#
# What it does, in this order (the order is the point):
#   0 preflight -> 1 folder + git init -> 2 copy the project template
#   -> 3 tooling scripts + CI -> 4 FIRST COMMIT -> 5 normalise branch to main
#   -> 6 create the private GitHub repo and push
# Creating the repo before the first commit is what causes
# "src refspec main does not match any".
#
# Safe to re-run on an existing folder: files that already exist are KEPT, only
# missing ones are added. Re-run with a stack to add CI later:
#   bash scaffold.sh myapp python
#
# The kit layout it expects (next to this script):
#   templates/project/        CLAUDE.md, .claude/, .mcp.json, docs/ (incl. MCP.md), src/, tests/, scripts/README.md, .gitignore
#   templates/ci.template.yml CI workflow with one block per stack
#   templates/stacks/<stack>/ per-stack starter files (python: pyproject.toml with the gate settings)
#   start.sh, loop.sh, pr.sh, doclint.sh, gate.sh, req_status.sh, autopilot.sh, dashboard.py   copied into <app>/scripts/
#
# PREREQUISITE - once per machine, before this script:
#   git config --global user.name  "Your Name"
#   git config --global user.email "you@example.com"
#   git config --global init.defaultBranch main
#   gh auth login
#
# AFTER this script: cd <app>, start claude, type "setup". See runbook.md.
set -uo pipefail

APP="${1:-}"
STACK="${2:-}"
WARNINGS=0

if [ -z "$APP" ] || [ "$APP" = "-h" ] || [ "$APP" = "--help" ]; then
  sed -n '2,27p' "$0"
  exit 0
fi

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$KIT_DIR/templates/project"
CI_TPL="$KIT_DIR/templates/ci.template.yml"

# ---------- reporting helpers ----------
step() { echo ""; echo "==> $*"; }
ok()   { echo "    OK    : $*"; }
warn() { echo "    WARN  : $*"; WARNINGS=$((WARNINGS+1)); }
err()  { echo "    ERROR : $*" >&2; }
die()  { echo ""; echo "ERROR : $*" >&2; echo "Aborted. Nothing further was run." >&2; exit 1; }

trap 'err "unexpected failure at line $LINENO (command: $BASH_COMMAND)"; exit 1' ERR

echo "=============================================="
echo " scaffold.sh v2.11 - project: $APP${STACK:+  (stack: $STACK)}"
echo "=============================================="

# ---------- 0. Preflight ----------
step "Step 0/6  Preflight checks"
command -v git >/dev/null 2>&1 || die "git is not installed. Install git and re-run."
ok "git found ($(git --version | awk '{print $3}'))"

GIT_NAME="$(git config --global user.name  2>/dev/null || true)"
GIT_MAIL="$(git config --global user.email 2>/dev/null || true)"
if [ -z "$GIT_MAIL" ] || [ -z "$GIT_NAME" ]; then
  err "git identity not set - the first commit would fail."
  echo "            Fix with:"
  echo "              git config --global user.name  \"Your Name\""
  echo "              git config --global user.email \"you@example.com\""
  die "missing git identity"
fi
ok "git identity: $GIT_NAME <$GIT_MAIL>"

[ -d "$TPL" ]    || die "project template not found at $TPL (keep scaffold.sh inside the kit folder)"
[ -f "$CI_TPL" ] || die "CI template not found at $CI_TPL"
for s in start.sh loop.sh pr.sh doclint.sh gate.sh req_status.sh autopilot.sh dashboard.py; do
  [ -f "$KIT_DIR/$s" ] || die "kit script missing: $KIT_DIR/$s"
done
ok "kit found: $KIT_DIR"
if grep -l $'\r' "$KIT_DIR"/*.sh >/dev/null 2>&1; then
  die "the kit's scripts have Windows line endings (CRLF), usually from cloning with Windows git.
            Fix: sed -i 's/\r\$//' \"$KIT_DIR\"/*.sh   (better: re-clone the kit inside WSL; see readme 'Getting the kit')"
fi

case "$STACK" in
  ""|node|python|go|rust) ;;
  *) die "unknown stack '$STACK'. Use one of: node, python, go, rust (or leave it out)" ;;
esac

if [ -e "$APP" ]; then
  if [ -d "$APP/.git" ]; then
    warn "'$APP' already exists and is a git repo - reusing it (existing files are kept)."
  else
    warn "'$APP' already exists - reusing it (existing files are kept)."
  fi
fi

# ---------- 1. Folder + git init ----------
step "Step 1/6  Create project folder and initialise git"
mkdir -p "$APP" || die "could not create folder '$APP'"
cd "$APP"      || die "could not enter folder '$APP'"
ok "folder ready: $(pwd)"

if [ -d .git ]; then
  ok "git repo already initialised"
else
  if git init -q -b main 2>/dev/null; then
    ok "git initialised with branch 'main'"
  elif git init -q; then
    warn "your git is too old for 'init -b'; will rename the branch after the first commit"
  else
    die "git init failed"
  fi
fi

# ---------- 2. Project template ----------
step "Step 2/6  Copy the project template (CLAUDE.md + docs + folders)"
created=0; kept=0; kept_list=""
while IFS= read -r -d '' src; do
  rel="${src#"$TPL"/}"
  if [ -e "$rel" ]; then
    kept=$((kept+1))
    kept_list="${kept_list}    KEPT  : $rel
"
  else
    mkdir -p "$(dirname "$rel")" || die "could not create $(dirname "$rel")"
    cp "$src" "$rel"             || die "could not copy $rel"
    created=$((created+1))
  fi
done < <(find "$TPL" -type f -print0 | sort -z)
if [ "$kept" -gt 0 ] && [ "$created" -gt 0 ]; then printf '%s' "$kept_list"; fi
ok "template files: $created created, $kept kept (existing files are never overwritten)"
mkdir -p docs/plans || die "could not create docs/plans"
# generated per machine, never committed: graphify's map (docs/MCP.md) and the dashboard's event log (.kit/)
for ign in graphify-out/ .kit/; do
  if ! grep -qxF "$ign" .gitignore 2>/dev/null; then
    printf '\n%s\n' "$ign" >> .gitignore || die "could not update .gitignore"
    ok ".gitignore: added $ign"
  fi
done
[ -f .mcp.json ] && ok "MCP servers: .mcp.json (chrome-devtools, playwright, graphify; see docs/MCP.md)"
grep -q '@docs/MCP.md' CLAUDE.md 2>/dev/null || warn "CLAUDE.md does not load docs/MCP.md: add the line '@docs/MCP.md' to its section 0"

# ---------- 3. Tooling scripts + CI ----------
step "Step 3/6  Tooling scripts and CI"
mkdir -p scripts || die "could not create scripts/"
for s in start.sh loop.sh pr.sh doclint.sh gate.sh req_status.sh autopilot.sh dashboard.py; do
  if [ -f "scripts/$s" ]; then
    if cmp -s "$KIT_DIR/$s" "scripts/$s"; then
      ok "scripts/$s is current"
    else
      warn "scripts/$s differs from the kit version - kept yours. To update: cp \"$KIT_DIR/$s\" scripts/$s"
    fi
  else
    cp "$KIT_DIR/$s" "scripts/$s" || die "could not copy $s"
    ok "created scripts/$s"
  fi
  chmod +x "scripts/$s" 2>/dev/null || true
done

# per-stack starter files (never overwrite)
if [ -n "$STACK" ] && [ -d "$KIT_DIR/templates/stacks/$STACK" ]; then
  APP_SLUG="$(basename "$APP" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"
  while IFS= read -r -d '' src; do
    rel="${src#"$KIT_DIR/templates/stacks/$STACK"/}"
    if [ -e "$rel" ]; then ok "$rel already exists - kept"
    else
      mkdir -p "$(dirname "$rel")" && sed "s/__APP__/${APP_SLUG:-app}/g" "$src" > "$rel" || die "could not write $rel"
      ok "created $rel (stack '$STACK' starter)"
    fi
  done < <(find "$KIT_DIR/templates/stacks/$STACK" -type f -print0 | sort -z)
fi
if [ "$STACK" = python ] && [ -f pyproject.toml ] && [ ! -f uv.lock ]; then
  if command -v uv >/dev/null 2>&1; then
    uv lock -q && ok "uv.lock created (CI installs with 'uv sync --locked')" || warn "uv lock failed - run 'uv lock' before the first push"
  else
    warn "uv not installed - CI needs uv.lock. Install uv (curl -LsSf https://astral.sh/uv/install.sh | sh), then run: uv lock"
  fi
fi

CI_FILE=".github/workflows/ci.yml"
if [ -f "$CI_FILE" ]; then
  ok "$CI_FILE already exists - kept"
elif [ -z "$STACK" ]; then
  warn "no stack given - CI NOT created. Add it later by re-running from the projects root:"
  echo "              bash \"$KIT_DIR/scaffold.sh\" $APP <node|python|go|rust>"
else
  mkdir -p .github/workflows || die "could not create .github/workflows"
  sed -E "/#>>> STACK:${STACK}\$/,/#<<< STACK:${STACK}\$/ s/^([[:space:]]*)# /\1/" "$CI_TPL" > "$CI_FILE" \
    || die "could not write $CI_FILE"
  if grep -qE '^[[:space:]]*- name: Full regression suite' "$CI_FILE"; then
    ok "created $CI_FILE for stack '$STACK'"
  else
    err "$CI_FILE was written but the '$STACK' block did not activate - check it by hand"
    WARNINGS=$((WARNINGS+1))
  fi
fi

# ---------- 4. First commit ----------
step "Step 4/6  Commit"
git add -A || die "git add failed"
if git diff --cached --quiet; then
  warn "nothing new to commit - working tree already matches HEAD"
else
  git commit -qm "chore: scaffold from project template v2.11" || die "git commit failed"
  ok "committed: chore: scaffold from project template v2.11"
fi
COMMITS="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
[ "$COMMITS" -ge 1 ] || die "no commit exists - a push would fail with 'src refspec main does not match any'"
ok "commit count: $COMMITS"

# ---------- 5. Normalise branch name to main ----------
step "Step 5/6  Ensure branch is named 'main'"
CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || echo '')"
if [ -z "$CURRENT_BRANCH" ]; then
  err "could not determine the current branch name"
  warn "check manually with: git branch"
elif [ "$CURRENT_BRANCH" = "main" ]; then
  ok "branch is already 'main' - no rename needed"
else
  echo "    INFO  : current branch is '$CURRENT_BRANCH', renaming to 'main'..."
  if git branch -M main; then
    NEW_BRANCH="$(git branch --show-current)"
    if [ "$NEW_BRANCH" = "main" ]; then
      ok "renamed branch '$CURRENT_BRANCH' -> 'main'"
    else
      err "rename reported success but branch is '$NEW_BRANCH', expected 'main'"
    fi
  else
    err "could not rename '$CURRENT_BRANCH' to 'main'. Fix manually: git branch -M main"
  fi
fi

# ---------- 6. GitHub repo + push ----------
step "Step 6/6  Create the private GitHub repo and push"
if ! command -v gh >/dev/null 2>&1; then
  err "gh CLI not found - repo NOT created, nothing pushed."
  echo "            The local repo is fine. Finish it with:"
  echo "              git remote add origin https://github.com/<user>/$APP.git"
  echo "              git push -u origin main"
  WARNINGS=$((WARNINGS+1))
elif ! gh auth status >/dev/null 2>&1; then
  err "gh is installed but not authenticated - repo NOT created, nothing pushed."
  echo "            Finish it with:"
  echo "              gh auth login"
  echo "              gh repo create $APP --private --source=. --remote=origin --push"
  WARNINGS=$((WARNINGS+1))
elif git remote get-url origin >/dev/null 2>&1; then
  ok "remote 'origin' already set: $(git remote get-url origin)"
  if git push -u origin main 2>/dev/null; then
    ok "pushed to origin/main"
  else
    err "push failed. Check the remote URL with: git remote -v"
    WARNINGS=$((WARNINGS+1))
  fi
else
  if gh repo create "$APP" --private --source=. --remote=origin --push; then
    ok "GitHub repo created (private) and pushed to origin/main"
  else
    err "gh repo create failed - the repo name may already be taken."
    echo "            Try:  gh repo create <other-name> --private --source=. --remote=origin --push"
    WARNINGS=$((WARNINGS+1))
  fi
fi

# ---------- Summary ----------
trap - ERR
echo ""
echo "=============================================="
echo " SUMMARY"
echo "=============================================="
echo "  project folder : $(pwd)"
echo "  branch         : $(git branch --show-current 2>/dev/null || echo '?')"
echo "  commits        : $(git rev-list --count HEAD 2>/dev/null || echo 0)"
echo "  remote origin  : $(git remote get-url origin 2>/dev/null || echo 'NOT SET')"
echo "  CI             : $([ -f "$CI_FILE" ] && echo "$CI_FILE" || echo 'NOT SET (re-run with a stack)')"
echo ""
echo "  tree:"
find . -not -path './.git/*' -not -path './.git' -not -name '.' | sort | sed 's/^/    /'
echo ""
if [ "$WARNINGS" -eq 0 ]; then
  echo "  Result: SUCCESS - all steps completed."
else
  echo "  Result: COMPLETED WITH $WARNINGS WARNING(S) - see ERROR/WARN lines above."
fi
cat <<NEXT

  Next:
    1. cd $APP, then open the 4 tmux panes (runbook.md 0c)
    2. git pane:    bash scripts/start.sh check   # verifies the kit is installed and active
    3. claude pane: claude                        # accept the trust dialog and approve the project MCP servers once, then type: setup
                                                  # Claude lists any missing MCP prerequisite with its install command (docs/MCP.md)
    4. After CI has run once, turn on branch protection (runbook.md Phase 2c).
    5. Then, for each requirement: bash scripts/start.sh   (start.sh status shows where you are)
    6. Watch it all, on the computer or phone: python3 scripts/dashboard.py [--lan]   (runbook.md Phase 2e)
    Python stack - run the starter app once now:
       uv sync && cp .env.example .env    # then put a long random SECRET_KEY in .env
       uv run alembic upgrade head && uv run uvicorn app.main:app --app-dir src --reload   # http://localhost:8000

  Sanity check:
    git log --oneline    # >= 1 commit
    git branch           # main
    git remote -v        # origin
NEXT
