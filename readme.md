# Spec-Driven Build Kit - Adoption Guide

Kit version: v2.9 (2026-10-02).
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
  doclint.sh                 enforces file headers, function doc blocks, folder READMEs, file size and layers (copied into each project)
  dashboard.py               live ZeroZeta dashboard: progress, needs-you, buttons; phone access with a PIN (copied into each project)
  gate.sh                    the quality gate: doclint, lint, format, types, tests, coverage; --full adds audits (copied into each project)
  loop.sh                    bounded implement-and-test loop for one Issue (copied into each project)
  req_status.sh              REQ-ID ledger and CI traceability check (copied into each project)
  autopilot.sh               optional unattended runs over several REQs (copied into each project)
  templates/
    ci.template.yml          CI workflow, one block per stack (scaffold.sh activates one); runs gate.sh --full
    stacks/python/           pyproject.toml with the gate limits (ruff, mypy strict, pytest, coverage)
    project/                 everything a new project starts with
      CLAUDE.md              the project constitution (FIXED + FILL IN sections)
      .claude/agents/reviewer.md   the second agent: read-only code reviewer (Opus)
      .claude/settings.json        pre-approved read-only commands (the reviewer runs without prompts)
      .mcp.json              MCP servers: chrome-devtools, playwright, graphify (free, local, no keys)
      .gitignore
      docs/                  00-idea, 01-prd, 02-architecture, 03-ui-design, 03-wireframe/,
                             04-testplan, 05-launch-checklist, RULES, TASKS, MEMORY, MCP, plans/, reviews/
      src/  tests/  scripts/ each with a README.md
  .bashrc  .tmux.conf  .wezterm.lua   optional terminal setup (four-pane layout; not used by the scripts)
  .gitattributes             keeps LF line endings so the bash scripts work after any clone
```

## Do I edit these files?

| File | Edit it? | How it varies per project |
|---|---|---|
| `scaffold.sh` | No | App name and stack are arguments |
| `start.sh`, `pr.sh` | No | Read the ID from the branch and the Issue from TASKS.md |
| `loop.sh` | No | Auto-detects the stack; ID and Issue come from the branch and TASKS.md |
| `dashboard.py` | No | Reads the project's TASKS, plans, reviews, git, GitHub and `.kit/events.jsonl` |
| `gate.sh` | No | Auto-detects the stack; limits live in each project's `pyproject.toml` |
| `templates/stacks/*` | Only to improve the kit | scaffold.sh copies them for the chosen stack |
| `req_status.sh` | No | Reads the project's own docs, git and Issues |
| `autopilot.sh` | No | Level, caps and REQs are settings and arguments |
| `runbook.md` | No | You substitute placeholders in the prompts you paste |
| `templates/ci.template.yml` | No | scaffold.sh activates the block for your stack |
| `templates/project/*` | Only to improve the kit | Each PROJECT copy is tailored through the `setup` flow |

Inside each new project, Claude tailors the copied files for you.
The first session finds every doc still marked `Status: TEMPLATE` and walks you through them in order, with your approval at each step.

## Getting the kit (once per machine)

Everything runs from a local copy of this kit: `scaffold.sh` copies `templates/` and the scripts into each new project, so the kit must be on your machine first.
The kit lives in its own GitHub repository. Clone it in a terminal: on Mac or Linux the normal Terminal; on Windows inside Ubuntu (WSL, installed with `wsl --install -d Ubuntu`), not with Windows Git, so the scripts keep their Unix line endings.
On Windows the kit runs in Ubuntu (WSL). CMD can be the window, but the kit's scripts are bash: type `wsl ~` in CMD first, then use the commands as written.
The guide (`spec-driven-build-guide.html`) asks for your computer type first, shows only the matching steps, and converts Windows folders such as `C:\Users\you\Desktop\Projects` to the form Ubuntu uses (`/mnt/c/Users/you/Desktop/Projects`).

```bash
mkdir -p ~/kits ~/projects
git clone https://github.com/<owner>/reference_files.git ~/kits/reference_files
git -C ~/kits/reference_files pull      # later: get kit updates
```

- Private kit: the owner adds you as a collaborator (repo Settings > Collaborators), and `gh auth login` lets `git clone` use your login.
- Received a zip instead: unzip it to `~/kits/reference_files` so that `~/kits/reference_files/scaffold.sh` exists.
- Keep projects in `~/projects` (Linux side): tests and builds are much faster there than under `/mnt/c`, and Windows editors still open them through `\\wsl$`.
- `.gitattributes` forces LF line endings, so even a Windows clone does not break the bash scripts.

### Publishing the kit (owner, once)
```bash
cd ~/kits/reference_files
git init -b main && git add -A && git commit -m "kit v2.9"
gh repo create reference_files --private --source=. --remote=origin --push
```
After each kit change: commit, `git push`, and tell users to `git pull`.

## New project in five steps

1. Get the kit (above) and do the one-time machine setup (below), once per machine.
2. From your projects root (`cd ~/projects`): `bash ~/kits/reference_files/scaffold.sh <appname> <node|python|go|rust>`.
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

# MCP servers in every project (.mcp.json; runbook.md 0h)
node --version                                   # 18+ for chrome-devtools and playwright
curl -LsSf https://astral.sh/uv/install.sh | sh  # uv, for graphify
uv tool install "graphifyy[mcp]" && graphify install
```

On Windows, run the scripts in Ubuntu (WSL); they are bash scripts.

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
- Users get a new kit version with `git -C ~/kits/reference_files pull`; new projects then use it.
- Existing projects are not updated automatically.
  To refresh a project's scripts: `cp reference_files/loop.sh reference_files/req_status.sh <project>/scripts/`.
  scaffold.sh warns when a project's scripts differ from the kit.
- To bring a v2.8 project up to v2.9 (dashboard), from the project root:
  ```bash
  cp <kit>/dashboard.py <kit>/loop.sh <kit>/gate.sh <kit>/pr.sh <kit>/start.sh <kit>/autopilot.sh scripts/
  grep -qxF '.kit/' .gitignore || echo '.kit/' >> .gitignore
  git add -A && git commit -m "chore(kit): live dashboard (kit v2.9)"
  python3 scripts/dashboard.py
  ```
- To bring a v2.7 project up to v2.8 (quality gate), from the project root (Python):
  ```bash
  cp <kit>/gate.sh <kit>/doclint.sh <kit>/loop.sh <kit>/pr.sh <kit>/autopilot.sh <kit>/start.sh scripts/
  # merge the [tool.*] sections and [dependency-groups] of <kit>/templates/stacks/python/pyproject.toml into pyproject.toml
  uv sync && bash scripts/gate.sh          # expect findings in existing code: fix them in chore(quality) commits
  ```
  Replace the test step in `.github/workflows/ci.yml` with `bash scripts/gate.sh --full`, and copy the v2.8 sections of CLAUDE.md, RULES.md and the docs you want.
- To bring a v2.6 project up to v2.7 (MCP), from the project root:
  ```bash
  cp <kit>/templates/project/.mcp.json .
  cp <kit>/templates/project/docs/MCP.md docs/
  cp <kit>/start.sh <kit>/loop.sh <kit>/autopilot.sh scripts/
  grep -qxF 'graphify-out/' .gitignore || echo 'graphify-out/' >> .gitignore
  ```
  Then copy section 0a and the `mcp` command row from `<kit>/templates/project/CLAUDE.md` into the project's CLAUDE.md (its FILL IN sections stay as they are), run `bash scripts/start.sh check` and commit as `chore(kit): MCP servers and check (kit v2.7)`.

## Changes in v2.9

Goal: anyone, including people who do not read code, can see and steer the build, from a computer or a phone.

- New `dashboard.py` (Python standard library only, ZeroZeta theme and logo): features live out of total, "Right now" with the build attempt, every feature on a six-stop rail (Plan, Approved, Building, Checking, Your review, Live), "Needs you", recent activity in plain language, specification status, and a Haiku-written summary for non-technical readers.
  Buttons: read and approve a plan, build, fix and rebuild, open for review, merge (after confirmation), start or switch a feature, run the checks, summarise. Writing code, `review` and `explain` stay in Claude.
- Phone access: `--lan` with a 6-digit PIN (lockout after 5 wrong tries), installable to the home screen; `--read-only` for observers. Runbook Phase 2e covers WSL mirrored networking, Tailscale for access away from home, and Claude Code Remote Control for talking to Claude from the phone.
- `loop.sh` v13, `gate.sh`, `pr.sh`, `start.sh` and `autopilot.sh` write plain-language progress events to `.kit/events.jsonl` (gitignored; scaffold.sh adds it to existing projects).
- `start.sh` resumes an existing branch for a REQ even if its name differs; `start.sh check` lists the dashboard.
- Guide: a "Dashboard and phone" section, tips and a reference row. Runbook: Phase 2e.

## Changes in v2.8

Goal: code a returning developer can read, and a change that has one obvious home.

- New `gate.sh`: one quality gate (doclint, ruff lint and format, mypy strict, full tests, 85% coverage of `service.py`; `--full` adds pip-audit and gitleaks).
  loop.sh v12, autopilot.sh v3, pr.sh v2 and CI run it, so the loop cannot finish complex, untyped or undocumented code.
- New `templates/stacks/python/pyproject.toml`: complexity 8, max 5 args, 8 branches, 40 statements, no `print`, no blind `except`, no commented-out code, strict typing. scaffold.sh v2.8 copies it and creates `uv.lock`.
- New `templates/ci.template.yml`: every stack runs `gate.sh --full`, then gitleaks, then `req_status.sh --strict`.
- doclint v2: `Called by:` is optional (it rots; use graphify or Find References), `Calls: none` for leaf functions, D4 file size (300 lines), D5 Python `service.py` imports no web, template or database library.
- RULES.md: simplicity first (design for the PRD's scale, no abstraction without a second use), layer rules, an "Enforced by the quality gate" table, wrong-layer and unreadable code are now Major findings, never loosen the gate.
- 02-architecture.md: default Python stack (FastAPI, Jinja2 + HTMX, SQLModel, Alembic), default feature-folder structure, section 3a change map, section 10 operations.
- 05-launch-checklist.md: new blocking section O (operations: config validation, /health, structured logs, error tracking, migrations, backups, deploy and rollback, lockfile), A9 change map, A10 no unexplained suppressions.
- 04-testplan.md: behaviour-level tests, service coverage floor, migration, startup-config and health checks. 01-prd.md: maintainability and operability NFR rows.
- TASKS.md: walking skeleton before REQ-001. MEMORY.md: 150-line cap with archiving.
- New complete `templates/project/.claude/agents/reviewer.md`: ordered steps (diff, plan and specs, `gate.sh`, `doclint --changed`, security greps, traceability, earlier findings), layer, readability and simplicity checks, and the exact report format scripts parse.
- New complete `templates/project/.claude/settings.json`: pre-approves read-only git and gh commands, the kit scripts (including `gate.sh`) and test runners; denies force-push, `reset --hard`, `rm -rf` and reading `.env` files.
- Complete project template set: `.gitignore` (kit scratch files, `graphify-out/`, `.env`, Python/Node/Go/Rust build output), `src/`, `tests/`, `scripts/` READMEs, `docs/plans/_TEMPLATE.md` (one-page plan with layers, migrations, dependencies, review focus), `docs/reviews/README.md`, `docs/03-wireframe/README.md`.
- Guide: the opening paragraph and a new "Start here" section compare the five development paths (guided, assisted, autopilot levels 1 to 3) plus the bug path, with a who-decides table; a new Tips section; `explain` and `mcp` in the reference. Runbook: the same path table at the top.
- CLAUDE.md: the gate is the full test suite; new working-loop step and command `explain` (walkthrough appended to the review file); pr.sh warns and `start.sh status` reminds when it is missing.

## Changes in v2.7

- New `templates/project/.mcp.json`: three free MCP servers in every project, chrome-devtools and playwright (Claude opens and tests the app in a browser) and graphify (a map of the codebase).
- New `templates/project/docs/MCP.md`: the MCP setup check and when to use each server.
  CLAUDE.md section 0 loads it with `@docs/MCP.md`, so at the start of each interactive session Claude lists any missing server with its install command; `mcp` re-runs the check.
- `templates/project/CLAUDE.md` v2.7: new section 0a loads `docs/MCP.md`; folder map lists `.mcp.json` and `docs/MCP.md`; new command `mcp`.
- `start.sh check` v3 has a section 5 for MCP: `.mcp.json` valid and free of API keys, `docs/MCP.md` present and imported, node 18+, uv, the graphify map, `.gitignore`.
- `loop.sh` v11 and `autopilot.sh` v2 mark their prompts `NON-INTERACTIVE RUN`, so unattended runs skip the check.
- `scaffold.sh` v2.7 adds `graphify-out/` to `.gitignore` and warns when CLAUDE.md does not load `docs/MCP.md`.
- Runbook 0h and the HTML guide (machine step "MCP prerequisites") describe the setup.
- Paid servers (Firecrawl, Perplexity) stay out of `.mcp.json`; `docs/MCP.md` gives `claude mcp add --scope local` commands so API keys never reach git.

## Changes in v2.6

- New `doclint.sh`: rules D1 (README per folder), D2 (file header with `REQ-IDs:`), D3 (function doc block with `Calls:` and `Called by:`), for Python, JS/TS, Go, Rust and shell.
  loop.sh, pr.sh merge, autopilot and CI run it in front of the tests; RULES.md section 3 shows the exact formats.
- New `start.sh check`: verifies the kit is installed and active in a project (runbook 0g, guide Phase 2).
- New `.claude/settings.json`: pre-approves the reviewer's read-only commands and denies force-push and `.env` reads.
- The reviewer agent now has an explicit, ordered list of commands to run, including doclint and security greps.
- Launch checklist A8: doclint passes on the whole codebase.

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
