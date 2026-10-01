# Spec-Driven Build Kit - Adoption Guide

Kit version: v2.5 (2026-10-01).
This kit is a set of reusable reference files for spec-driven, fully traceable development with Claude Code.
This README explains what each file is, whether you edit it, and how a new project is created from it.

## What is in the kit

```
reference_files/
  readme.md                  this guide
  runbook.md                 step-by-step playbook: setup, spec chain, build loop, bug loop, release
  spec-driven-build-guide.html  the runbook as an interactive page: open in a browser
  scaffold.sh                creates a new project from the templates
  start.sh                   starts the next REQ or a BUG, shows status (copied into each project)
  pr.sh                      opens the PR after review, merges with after-merge checks (copied into each project)
  loop.sh                    bounded implement-and-test loop for one Issue (copied into each project)
  req_status.sh              REQ-ID ledger and CI traceability check (copied into each project)
  autopilot.sh               optional unattended runs over several REQs (copied into each project)
  templates/
    ci.template.yml          CI workflow, one block per stack (scaffold.sh activates one)
    project/                 everything a new project starts with
      CLAUDE.md              the project constitution (FIXED + FILL IN sections)
      .claude/agents/reviewer.md   the second agent: read-only code reviewer (Opus)
      .gitignore
      docs/                  00-idea, 01-prd, 02-architecture, 03-ui-design, 03-wireframe/,
                             04-testplan, 05-launch-checklist, RULES, TASKS, MEMORY, plans/, reviews/
      src/  tests/  scripts/ each with a README.md
  .bashrc  .tmux.conf  .wezterm.lua   your machine setup (not used by the scripts)
```

## Do I edit these files?

| File | Edit it? | How it varies per project |
|---|---|---|
| `scaffold.sh` | No | App name and stack are arguments |
| `start.sh`, `pr.sh` | No | Read the ID from the branch and the Issue from TASKS.md |
| `loop.sh` | No | Auto-detects the stack; ID and Issue come from the branch and TASKS.md |
| `req_status.sh` | No | Reads the project's own docs, git and Issues |
| `autopilot.sh` | No | Level, caps and REQs are settings and arguments |
| `runbook.md` | No | You substitute placeholders in the prompts you paste |
| `templates/ci.template.yml` | No | scaffold.sh activates the block for your stack |
| `templates/project/*` | Only to improve the kit | Each PROJECT copy is tailored through the `setup` flow |

Inside each new project, Claude tailors the copied files for you.
The first session finds every doc still marked `Status: TEMPLATE` and walks you through them in order, with your approval at each step.

## New project in five steps

1. One-time machine setup (below), once per machine.
2. From your projects root: `bash /path/to/reference_files/scaffold.sh <appname> <node|python|go|rust>`.
   It creates the folder, git repo, template docs, scripts, CI, first commit, and a private GitHub repo.
3. `cd <appname>`, start `claude`, accept the trust dialog, and type `setup`.
4. Follow the setup order Claude proposes: idea, PRD, architecture and UI design, test plan and TASKS, then proposed changes to RULES and the launch checklist.
   Each approved doc gets `Status: APPROVED - <date>` and is committed to `main`.
5. Follow `runbook.md` Phase 2 onwards: one Issue per REQ-ID, plan, loop, PR, post-merge checks, and finally the release audit.

## One-time machine setup

Do this once per machine, not once per project.

```bash
# identity and default branch (prevents "src refspec main does not match any")
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main

# GitHub CLI
gh auth login

# Claude Code CLI on PATH
command -v claude

# Optional but recommended
#   tmux, WezTerm (configs in this folder: .tmux.conf, .wezterm.lua)
#   jq                 cost and token telemetry in loop.sh
#   RTK                compresses command output before it reaches Claude (runbook.md 0f)
#   Node / Python      whatever your stacks need
```

On Windows, run the scripts from WSL or Git Bash; they are bash scripts.

## Two agents

The kit uses the minimum that gives independent checking: two agents.

| Agent | What it is | Does | Never does |
|---|---|---|---|
| **Builder** | Your main Claude session plus `scripts/loop.sh` | Plans, writes tests and code, fixes review findings | Approves its own work |
| **Reviewer** | `.claude/agents/reviewer.md`, Opus, fresh context, read-only tools | Reviews the branch diff against the plan, PRD, test plan and RULES; returns findings and a verdict | Edits any file |

You type `review` before every PR.
The report lands in `docs/reviews/<ID>.md` with `Verdict: APPROVE` or `Verdict: CHANGES REQUESTED` on line 1.
Critical or Major findings block the PR; the loop can fix them, then you review again (maximum 2 rounds).
Tests, CI and `req_status.sh` stay the deterministic tester, and you stay the final reviewer at the PR.
Add a third agent (for example a separate test writer) only when you see the builder writing tests its own code was bound to pass.

## Autopilot (optional, unattended)

`bash scripts/autopilot.sh` runs the build loop for several requirements while you are away.
The spec docs always stay human; autopilot refuses to start until setup is approved.

| Level | Command | Runs unattended | Still waits for you |
|---|---|---|---|
| 1 (default) | `bash scripts/autopilot.sh` | Branch, loop, commit, reviewer, fix rounds, push, PR, for REQs whose plan you approved | Plans, PR merges |
| 2 | `AUTOPILOT=plan,build bash scripts/autopilot.sh` | Also drafts plans; the reviewer agent approves them | PR merges |
| 3 | add `AUTO_MERGE=1` | Also waits for CI, merges, runs the after-merge checks, continues | Release |

Safety caps: `MAX_REQS=3`, `MAX_COST=10` (USD), `REVIEW_ROUNDS=2`, `STOP_ON_FAIL=1`.
Try `DRY_RUN=1` first: it shows what each REQ would go through and changes nothing.
Each run writes `.autopilot/<run-id>.md` with a "Needs you" list, plus a full log.
Needs jq and an authenticated gh; level 3 refuses to run without branch protection on main.

## How the pieces fit together

- **CLAUDE.md** sets the working loop, the ID scheme and the commands (`setup`, `next`, `status`, `audit`, `fix`, `release check`, `wrap up`).
- **docs/RULES.md** holds the detailed coding, documentation and engineering rules.
- **docs/TASKS.md** holds the build order; GitHub Issues hold the status.
- **docs/MEMORY.md** carries decisions and gotchas from one session to the next.
- **scripts/loop.sh** runs the implement-and-test grind for one Issue, but only against an APPROVED plan in `docs/plans/`, and feeds in review findings when a review asked for changes.
- **.claude/agents/reviewer.md** is the second agent; `review` runs it and saves its report to `docs/reviews/`.
- **scripts/req_status.sh** reports every REQ-ID's plan, review verdict, merge, Issue, PR and tests, and makes CI fail if a merged REQ has no tests.
- **docs/05-launch-checklist.md** is the release gate, driven by `audit` and `release check`.

## The policy these files share

Every file assumes **one GitHub Issue per REQ-ID**.
Each branch and PR then finishes exactly one requirement, so its PR uses `Closes #N` and the Issue auto-closes on merge.
Group two REQ-IDs into one Issue only if they share the same code change and cannot be tested apart; a PR finishing one of them then uses `Refs #N`.

```
Idea -> REQ-ID -> Architecture row -> Wireframe tag -> TC-ID -> Issue # -> branch -> PR -> merge
Bug  -> BUG-ID -> failing test -> Issue # -> branch -> PR -> merge
```

## Updating the kit

- Improve `templates/project/` when a project's MEMORY.md records a lesson under "Lessons for the template".
- Bump the version line in CLAUDE.md and the doc headers when you do.
- Existing projects are not updated automatically.
  To refresh a project's scripts: `cp reference_files/loop.sh reference_files/req_status.sh <project>/scripts/`.
  scaffold.sh warns when a project's scripts differ from the kit.

## Changes in v2.5

- No more typing REQ-IDs, Issue numbers or BUG-IDs.
  New `start.sh` (next REQ, `bug "symptom"`, `status`) and `pr.sh` (open PR after APPROVE, `merge` with after-merge checks).
- `loop.sh` v9 runs with no arguments on a REQ or BUG branch; `next` and `review` use the current branch's ID.
- Runbook Phases 2, 2b, 2c and 3 and the HTML guide use the ID-free commands; the guide only asks for app, stack, folders and GitHub user.

## Changes in v2.4

- New `autopilot.sh` (levels 1 to 3, cost and REQ caps, dry run, run report); scaffold.sh copies it into `scripts/`.
- CLAUDE.md section 8a; `.gitignore` ignores `.autopilot/`; runbook Phase 2d.

## Changes in v2.3

- New reviewer agent `templates/project/.claude/agents/reviewer.md` and `docs/reviews/`.
- CLAUDE.md: section 5a (builder and reviewer), `review` command, review step before every PR.
- RULES.md section 8 (review severities), plan template "Review focus", launch checklist A7.
- loop.sh v8 reads review findings; req_status.sh v3 adds the Review column; scaffold.sh v2.3.

## Removed in v2.2

- `ci.yml` (a filled-in Python copy) and `ci.yaml` were replaced by `templates/ci.template.yml`.
- The root `CLAUDE.md` moved to `templates/project/CLAUDE.md`.
- The reference to `spec-driven-build-setup-guide.md` was replaced by the one-time setup section above.
