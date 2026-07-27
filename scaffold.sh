#!/usr/bin/env bash
# scaffold.sh — Phase 0 setup for a spec-driven project.
# Run from your projects root (e.g. ~/lpro). Usage: bash scaffold.sh [app-name]
#
# Order matters: init -> scaffold -> COMMIT -> normalise branch -> create+push repo.
# Creating the repo before the first commit is what causes
# "src refspec main does not match any".
#
# ==========================================================================
#  GIT COMMANDS THIS SCRIPT RUNS FOR YOU — do NOT run these by hand
# ==========================================================================
#   mkdir -p <app> && cd <app>
#   git init -b main                    # falls back to: git init
#   mkdir -p docs/03-wireframe src tests
#   touch docs/00-idea.md docs/01-prd.md docs/02-design.md docs/04-testplan.md
#   touch CLAUDE.md                     # placeholder only
#   git add -A
#   git commit -m "chore: scaffold + CLAUDE.md seed"
#   git branch -M main                  # only if branch is not already main
#   gh repo create <app> --private --source=. --remote=origin --push
#
#  PREREQUISITE — run ONCE per machine, before this script:
#   git config --global user.name  "Your Name"
#   git config --global user.email "you@example.com"
#   git config --global init.defaultBranch main
#   gh auth login
#
#  AFTER this script, everything is manual. See RUNBOOK.md for the full loop.
#  One Issue per REQ-ID, so a PR that finishes its REQ uses "Closes #N":
#   Phase 1  git add docs/<file> && git commit -m "docs: ..." && git push
#            gh issue create --title "REQ-00X: ..." --label requirement
#   Phase 2  git checkout main && git pull
#            git checkout -b feat/REQ-00X-short-name
#            git add -A && git commit -m "feat(REQ-00X): ... (#N)"
#            git push -u origin feat/REQ-00X-short-name
#            gh pr create --title "..." --body "Closes #N. Implements REQ-00X."
#            gh pr merge --squash --delete-branch
#   Phase 3  git checkout -b fix/BUG-00X
#            git commit -m "test(BUG-00X): failing test reproducing bug (#N)"
#            git commit -m "fix(BUG-00X): ... (#N)"
#            gh pr create --body "Fixes #N (BUG-00X)."
# ==========================================================================
set -uo pipefail

APP="${1:-myapp}"
WARNINGS=0

# ---------- reporting helpers ----------
step() { echo ""; echo "==> $*"; }
ok()   { echo "    OK    : $*"; }
warn() { echo "    WARN  : $*"; WARNINGS=$((WARNINGS+1)); }
err()  { echo "    ERROR : $*" >&2; }
die()  { echo ""; echo "ERROR : $*" >&2; echo "Aborted. Nothing further was run." >&2; exit 1; }

trap 'err "unexpected failure at line $LINENO (command: $BASH_COMMAND)"; exit 1' ERR

echo "=============================================="
echo " scaffold.sh — project: $APP"
echo "=============================================="

# ---------- 0. Preflight ----------
step "Step 0/6  Preflight checks"
command -v git >/dev/null 2>&1 || die "git is not installed. Install git and re-run."
ok "git found ($(git --version | awk '{print $3}'))"

GIT_NAME="$(git config --global user.name  2>/dev/null || true)"
GIT_MAIL="$(git config --global user.email 2>/dev/null || true)"
if [ -z "$GIT_MAIL" ] || [ -z "$GIT_NAME" ]; then
  err "git identity not set — the first commit would fail."
  echo "            Fix with:"
  echo "              git config --global user.name  \"Your Name\""
  echo "              git config --global user.email \"you@example.com\""
  die "missing git identity"
fi
ok "git identity: $GIT_NAME <$GIT_MAIL>"

if [ -e "$APP" ]; then
  if [ -d "$APP/.git" ]; then
    warn "'$APP' already exists and is already a git repo — reusing it."
    warn "existing files are kept; the branch will still be normalised to 'main'."
  else
    warn "'$APP' already exists — reusing it (existing files are kept)."
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

# ---------- 2. Folder scaffold ----------
step "Step 2/6  Build the folder scaffold"
mkdir -p docs/03-wireframe src tests || die "could not create the folder tree"
ok "created: docs/  docs/03-wireframe/  src/  tests/"
for f in docs/00-idea.md docs/01-prd.md docs/02-design.md docs/04-testplan.md; do
  if [ -f "$f" ]; then ok "kept existing $f"; else touch "$f" && ok "created $f"; fi
done

# ---------- 3. CLAUDE.md ----------
step "Step 3/6  Seed CLAUDE.md"
if [ -f CLAUDE.md ]; then
  ok "CLAUDE.md already exists — left untouched"
else
  echo "# CLAUDE.md - replace with the provided seed" > CLAUDE.md \
    || die "could not write CLAUDE.md"
  ok "wrote CLAUDE.md placeholder (replace it with the real constitution)"
fi

# ---------- 4. First commit ----------
step "Step 4/6  First commit"
git add -A || die "git add failed"
if git diff --cached --quiet; then
  warn "nothing new to commit — working tree already matches HEAD"
else
  git commit -qm "chore: scaffold + CLAUDE.md seed" || die "git commit failed"
  ok "committed: chore: scaffold + CLAUDE.md seed"
fi
COMMITS="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
[ "$COMMITS" -ge 1 ] || die "no commit exists — a push would fail with 'src refspec main does not match any'"
ok "commit count: $COMMITS"

# ---------- 5. Normalise branch name to main ----------
step "Step 5/6  Ensure branch is named 'main'"
CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || echo '')"
if [ -z "$CURRENT_BRANCH" ]; then
  err "could not determine the current branch name"
  warn "check manually with: git branch"
elif [ "$CURRENT_BRANCH" = "main" ]; then
  ok "branch is already 'main' — no rename needed"
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
  err "gh CLI not found — repo NOT created, nothing pushed."
  echo "            The local repo is fine. Finish it with:"
  echo "              git remote add origin https://github.com/<user>/$APP.git"
  echo "              git push -u origin main"
  WARNINGS=$((WARNINGS+1))
elif ! gh auth status >/dev/null 2>&1; then
  err "gh is installed but not authenticated — repo NOT created, nothing pushed."
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
  fi
else
  if gh repo create "$APP" --private --source=. --remote=origin --push; then
    ok "GitHub repo created (private) and pushed to origin/main"
  else
    err "gh repo create failed — the repo name may already be taken."
    echo "            Try:  gh repo create <other-name> --private --source=. --remote=origin --push"
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
echo ""
echo "  tree:"
find . -not -path './.git/*' -not -name '.' | sort | sed 's/^/    /'
echo ""
if [ "$WARNINGS" -eq 0 ]; then
  echo "  Result: SUCCESS — all steps completed."
else
  echo "  Result: COMPLETED WITH $WARNINGS WARNING(S) — see ERROR/WARN lines above."
fi
cat <<'NEXT'

  Next:
    1. Replace the CLAUDE.md placeholder with the real constitution, then:
         git add CLAUDE.md && git commit -m "docs: seed CLAUDE.md constitution" && git push
    2. tmux new -s <app>     # then split into 4 panes

  Sanity check:
    git log --oneline    # >= 1 commit
    git branch           # main
    git remote -v        # origin
NEXT
