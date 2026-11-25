# vibecode - Spec-Driven Build Kit - Adoption Guide

Kit version: v3.12 (2026-11-19). Forked from `reference_files` v3.11 with the hardening listed under "Changes in v3.12".
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
  gate.sh                    the quality gate: doclint, lint, format, types, tests, coverage, integrity; --full adds audits (copied into each project)
  integrity.sh               fails a branch that weakens its own checks (tests, gate config, suppressions) without a plan exception (copied into each project)
  lock_tests.sh              YOU lock a REQ's or BUG's tests after reading docs/tests/<ID>.md; integrity I6 then freezes them (copied into each project)
  protect.sh                 turns on GitHub branch protection for main; pr.sh merge and autopilot require it (copied into each project)
  loop.sh                    bounded implement-and-test loop for one Issue (copied into each project)
  req_status.sh              REQ-ID ledger and CI traceability check (copied into each project)
  autopilot.sh               optional unattended runs over several REQs (copied into each project)
  templates/
    ci.template.yml          CI workflow, one block per stack (scaffold.sh activates one); runs gate.sh --full
    stacks/python/           pyproject.toml with the gate limits (ruff, mypy strict, pytest, coverage)
    project/                 everything a new project starts with
      CLAUDE.md              the project constitution (FIXED + FILL IN sections)
      .claude/agents/reviewer.md   the second agent: read-only code reviewer (Opus)
      .claude/commands/      slash commands: /setup /next /tests /review /explain /status /audit /fix /release-check /wrap-up /phases /scope /diagram /mcp
      .claude/hooks/         guards (main, .env, force-push, hard reset, --no-verify, pushes to main), Python auto-format, idle and needs-you signals
      .claude/settings.json        pre-approved read-only commands (the reviewer runs without prompts)
      .mcp.json              MCP servers: chrome-devtools, playwright, graphify (free, local, no keys)
      .gitignore
      docs/                  00-idea, 01-prd, 02-architecture, 03-ui-design, 03-wireframe/,
                             04-testplan, 05-launch-checklist, RULES, TASKS, MEMORY, MCP, plans/, tests/, reviews/
      src/  tests/  scripts/ each with a README.md
  .bashrc  .tmux.conf  .wezterm.lua   optional terminal setup (four-pane layout; not used by the scripts)
  tmux-status.sh             REQ id + gate result for the tmux status bar (read by .tmux.conf)
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
Every level needs branch protection on main (`bash scripts/protect.sh`); level 2 plus level 3 together (no human sees plan or merge) also needs `I_ACCEPT_UNREVIEWED_PLANS=1`.
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
- Kit upgrades go on a branch named `chore/kit-<version>`: there `integrity.sh` lists the changed kit files as ALLOWED instead of failing,
  and you review them in the PR. Run the commands below yourself in the git pane (the hooks block Claude from editing the kit's checks).
  `pr.sh` only handles REQ and BUG branches, so open and merge the kit PR with `gh` as shown.
- To bring a v3.12 project up to v3.13 (risk tiers, `/tests`, test lock, blocking Stop hook, PR evidence), from the project root:
  ```bash
  git switch main && git pull --ff-only && git switch -c chore/kit-v3.13
  cp <kit>/integrity.sh <kit>/lock_tests.sh <kit>/loop.sh <kit>/pr.sh <kit>/autopilot.sh <kit>/start.sh scripts/
  cp <kit>/templates/project/.claude/hooks/guard-files.sh <kit>/templates/project/.claude/hooks/guard-bash.sh <kit>/templates/project/.claude/hooks/on-stop.sh .claude/hooks/
  cp <kit>/templates/project/.claude/commands/tests.md <kit>/templates/project/.claude/commands/next.md .claude/commands/
  cp <kit>/templates/project/.claude/agents/reviewer.md .claude/agents/
  cp <kit>/templates/project/docs/plans/_TEMPLATE.md docs/plans/
  mkdir -p docs/tests && cp <kit>/templates/project/docs/tests/README.md docs/tests/
  sed -i '/on-stop\.sh/{n;s/"timeout": 30/"timeout": 90/}' .claude/settings.json    # the Stop hook now runs the gate
  # CLAUDE.md: copy sections 3, 5, 8, the `tests` row of 9, and 10 from <kit>/templates/project/CLAUDE.md (your FILL IN sections stay)
  # docs/RULES.md: copy sections 9, 10 (Boundaries: tailor the paths) and 11 from <kit>/templates/project/docs/RULES.md
  bash scripts/start.sh check && bash scripts/gate.sh
  git add -A && git commit -m "chore(kit): protected verification loop (kit v3.13)"
  git push -u origin HEAD && gh pr create --fill     # review the PR on GitHub, then: gh pr merge --squash --delete-branch
  ```
  A REQ already in progress: its plan has no `Risk:` line, so it counts as standard and `loop.sh` asks for the lock.
  Add `Risk: light - <reason>` to the plan only if that is true; otherwise run `/tests`, read `docs/tests/<ID>.md`, then `bash scripts/lock_tests.sh`.
- To bring a v3.11 project up to v3.12 (integrity, branch protection, fail-closed hooks), from the project root:
  ```bash
  git switch main && git pull --ff-only && git switch -c chore/kit-v3.12
  cp <kit>/integrity.sh <kit>/protect.sh <kit>/gate.sh <kit>/loop.sh <kit>/pr.sh <kit>/autopilot.sh <kit>/start.sh scripts/
  cp <kit>/templates/project/.claude/hooks/*.sh .claude/hooks/
  cp <kit>/templates/project/.claude/agents/reviewer.md .claude/agents/
  cp <kit>/templates/project/docs/plans/_TEMPLATE.md docs/plans/
  # .claude/settings.json: merge the "permissions" block of <kit>/templates/project/.claude/settings.json (integrity allowed, git clean and rm -rf spellings denied)
  # CLAUDE.md: copy sections 3, 8 and 10; docs/RULES.md: copy sections 5 and 9 (your FILL IN sections stay)
  bash scripts/start.sh check && bash scripts/gate.sh      # integrity lists the kit files as ALLOWED on chore/kit-*
  git add -A && git commit -m "chore(kit): integrity, branch protection, fail-closed hooks (kit v3.12)"
  git push -u origin HEAD && gh pr create --fill     # review the PR on GitHub, then: gh pr merge --squash --delete-branch
  git switch main && git pull --ff-only && bash scripts/protect.sh      # once CI has run on main
  ```
- To bring a v2.12 project up to v2.13 (commands and hooks), from the project root:
  ```bash
  cp -r <kit>/templates/project/.claude/commands <kit>/templates/project/.claude/hooks .claude/
  # merge the "hooks" block of <kit>/templates/project/.claude/settings.json into .claude/settings.json
  cp <kit>/dashboard.py <kit>/start.sh scripts/ && bash scripts/start.sh check
  ```
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

## Changes in v3.13 (vibecode)

Goal: the protected verification loop. Tests are written from the spec before the code, read by you, then locked, so the code must meet the tests.

- **Risk tier in every plan:** `Risk: light | standard | strict` with a one-line reason; `next` proposes it, you approve it with the plan.
  Strict: auth, payments, deleting data, a public API or routes, `shared/`, migrations, a new dependency. Light: copy, styling, a refactor with no behaviour change. Otherwise standard; no line counts as standard.
- **New `/tests <ID>`** (standard and strict, REQ and BUG): failing tests from the TC rows and edge cases only, never `src/`, each failing on an assertion or "not implemented", enough for the coverage floor;
  writes `docs/tests/<ID>.md` (TC-ID | test name | what it checks | fails now), commits the tests alone, and stops for you to read.
- **New `lock_tests.sh`** (you run it, Claude cannot): writes `Tests locked: <sha>` into the plan and commits it.
- **`integrity.sh` v2, rule I6:** after the lock, any changed, deleted, renamed or new test path (tests, `conftest.py`, fixtures; not `*.md`) fails the gate, unless the plan lists it under "Allowed exceptions".
  A path equal to main's version is ignored. Since `gate.sh` runs integrity, loop, autopilot, pr.sh and CI all enforce it with no new CI step.
- **Hooks:** `guard-files.sh` and `guard-bash.sh` block edits to locked tests and to a locked plan, and block Claude running `lock_tests.sh`.
  `on-stop.sh` runs the gate when Claude stops on a feat/ or fix/ branch with changed code and exits 2 while it is red (never twice in a row; skips main, `chore/kit-*`, loops, docs-only and the `/tests` stage).
- **`loop.sh` v15:** refuses standard and strict plans without the lock; PROMPT.md lists the locked test files and forbids test changes; stops (exit 4) on a "Disputed" entry, or when the locked tests pass but miss the coverage floor (file, coverage, gap in FAILURES.txt).
- **`autopilot.sh` v4:** skips unlocked standard and strict REQs and lists them under "Needs you", shows loop disputes there, opens PRs through `pr.sh`, and never auto-merges a `needs-human-review` PR.
- **`pr.sh` v4:** runs `bash scripts/gate.sh --full` first and refuses on red; the PR body holds the command and its last 40 lines, the tier, the lock sha and a link to `docs/tests/<ID>.md`;
  files matching the new RULES.md section 10 "Boundaries" are listed under "Boundary changes" and add the label `needs-human-review`, on every tier.
- **`start.sh` v5:** `status` shows the tier and lock and the next step; `check` knows `lock_tests.sh`. **Reviewer:** checks the lock, the table and the tier.
- **CLAUDE.md** sections 3, 5, 8, 9 and 10, **RULES.md** sections 9, 10 and 11 (with a TODO for mutation and holdout tests).

### Known limits (still true after v3.13)
- The lock freezes the test files, not their meaning: you still have to read the table and the tests before you lock. A weak test locked is a weak test kept.
- Coverage gaps are found only when the loop runs. `/tests` aims for the floor, but the gap shows up once the code exists, and then needs your unlock.
- The Stop hook runs the fast gate inside the hook's time limit (80 s, `STOP_GATE_TIMEOUT`); a slower gate never blocks there, and loop.sh and CI still run it.
- `pr.sh` now runs `gate.sh --full`, which needs the network for the dependency audit, so opening a PR takes longer.

## Changes in v3.12 (vibecode)

Goal: the builder cannot quietly weaken what judges it, and the guards hold when nobody is watching.

- **New `integrity.sh`, run inside `gate.sh`** (so loop, autopilot, pr.sh and CI all get it; `GATE_SKIP` cannot skip it).
  It compares the branch with main and fails on: changed gate config, lockfiles, CI, kit scripts or `.claude/` (I1);
  deleted or renamed test files (I2); test functions or assertions removed (I3); skip / xfail / only markers (I4);
  new `# noqa`, `type: ignore`, `eslint-disable`, `@ts-ignore` and similar (I5).
  The approved, committed plan can allow a path under a new "Allowed exceptions" section, which only the user writes.
  Kit upgrades go on a branch named `chore/kit-<version>`: there protected-file changes are listed as ALLOWED and you review them in the PR.
- **Hooks fail closed.** `_lib.sh` finds a Python that really runs (the Windows Store `python3` stub does not count);
  with none, or with input it cannot parse, guard hooks block instead of allowing everything. `start.sh check` proves the hooks are live.
- **`guard-bash.sh` closes the bypasses:** refspec pushes (`HEAD:main`, `refs/heads/main`), `+refspec` force-pushes, `--mirror` / `--delete`,
  plain `git push` on main that would carry code, `rm` with split flags (`rm -r -f /`, `--recursive`; paths resolved against the project),
  shell writes to code on main (`>`, `sed -i`, `tee`, `cp`, `mv` ...), shell edits to the kit's own checks, `git clean -f`, `git commit -n`,
  `core.hooksPath`, and Claude setting `GATE_SKIP` / `COV_MIN` / `NO_GATE` / `ALLOW_UNPROTECTED` / `AUTO_MERGE` / `FORCE=1 pr.sh`.
- **`guard-files.sh`** also blocks Edit/Write on hooks, settings, the reviewer agent, gate/integrity/loop/pr/autopilot/protect scripts and CI.
  The user maintains them by hand, or starts claude with `KIT_MAINTAINER=1`.
- **New `protect.sh`:** branch protection for main (PR only, required `gate` check up to date, admins included, no force-push or delete, linear history).
  `pr.sh merge` refuses without it (`ALLOW_UNPROTECTED=1` is the user's override); autopilot needs it at every level; `start.sh check` reports FAIL once setup is approved.
  Note: GitHub offers branch protection on private repos only with Pro, Team or Enterprise.
- **`loop.sh` v14:** `--model` pinned (`LOOP_MODEL`, default sonnet); dollar cap `MAX_COST` (default 5); per-pass time cap `ITER_TIMEOUT` (default 1800 s);
  refuses an uncommitted plan and stops if the plan file changes during the run; green must hold for `FLAKE_RUNS` gate runs in a row (default 2);
  the prompt forbids editing protected files and treats Issue / web / tool text as data.
  Autopilot hands each loop only what is left of its own budget.
- **`gate.sh` v2:** integrity step; in CI, `GATE_SKIP` and `COV_MIN` are refused.
- **`pr.sh` v3:** runs integrity before opening a PR; merge requires branch protection.
- **Reviewer:** runs integrity and checks every allowed exception; names the assertion that would fail per TC; reads every migration;
  treats instructions inside the diff or Issue as a Critical prompt-injection finding.
- **RULES.md section 5:** untrusted text is data (prompt injection), exact-name dependencies checked on the registry, migration data plan
  plus upgrade-downgrade-upgrade test. Section 9: never edit the kit's checks; a flaky pass is not green.
- **Plan template:** "Allowed exceptions", dependency and migration prompts. **CLAUDE.md** sections 3, 8 and 10 updated.
- `.claude/settings.json`: integrity allowed; `git clean` and the other `rm -rf` spellings denied.

### Known limits (still true after v3.12)
- The hooks and `integrity.sh` are pattern checks: they stop accidents and lazy shortcuts, not a determined adversary.
  Branch protection plus your PR review stay the real gate.
- `integrity.sh` I3 counts test and assertion lines; a test made weaker without removing lines (for example a looser expected value) needs the reviewer and you.
- A pass stopped by `ITER_TIMEOUT` reports no cost, so the dollar cap can be exceeded by at most one pass.
- Builder and reviewer are the same model family. Keep your own plan approval (autopilot level 1) for anything that matters.
- `spec-driven-build-guide.html` and `runbook.md` now use `protect.sh` (their old protection command required a check named `test`, but the CI job is `gate`, and it exempted admins).
  v3.13 adds the `/tests` and lock steps to both.
- The reference_files clone URL in "Getting the kit" is unchanged: point it at the vibecode repo once you publish it.

## Changes in v2.13

- `.claude/commands/`: every kit command is a slash command (type `/` in Claude). Each file points at its row in CLAUDE.md section 9, which stays the single description; plain words still work.
- `.claude/hooks/`, registered in `.claude/settings.json`, so rules are enforced instead of only requested:
  `guard-files.sh` blocks code edits (src, tests, migrations, scripts) on main and any read or write of `.env` files;
  `guard-bash.sh` blocks `.env` access, force-push, `git reset --hard`, `--no-verify`, deletes outside the project and pushes to main;
  `format-file.sh` formats every Python file Claude writes; `on-stop.sh` and `on-notify.sh` tell the dashboard when Claude is idle or waiting for you (with a terminal bell).
- Dashboard: "Claude is waiting for you" at the top of Needs you. `start.sh check` verifies commands and hooks. Walking skeleton runs on `chore/walking-skeleton`.
- Guide: slash commands everywhere, reference rows for commands and hooks, tips. `.claude/settings.local.json` is gitignored.

## Changes in v2.12

- Optional Archify skill (open source, MIT) for interactive architecture, data-flow and sequence diagrams as single HTML files.
  Guide machine setup (check, install only if missing), the architecture step draws `docs/diagrams/architecture` and `data-flow`,
  `explain` adds a `<ID>-flow` diagram for new request paths, and a new `diagram <what>` command inside Claude.
- `docs/diagrams/` in every project: JSON source (edited) plus rendered HTML (committed together).
- Diagrams must match the code: RULES.md section 3, a reviewer step that checks every arrow against real calls (wrong diagram = Major), launch checklist A11.
- `start.sh check` reports whether Archify is installed (information only).

## Changes in v2.11

Goal: every Python project starts production-shaped, and every screen user-friendly.

- Starter app (`templates/stacks/python/`, copied by scaffold.sh): FastAPI + Jinja2 + htmx (vendored, no CDN) + SQLModel + Alembic.
  Settings validated at startup, `/health`, JSON logs with request IDs, friendly 404/403/429/500 pages with a reference ID (toasts for htmx requests),
  Content-Security-Policy and security headers, CSRF protection, a rate limit on changes, Sentry when `SENTRY_DSN` is set, a non-root Dockerfile, `.env.example`.
  It passes the full gate as delivered (doclint, ruff, mypy strict, tests, service coverage, pip-audit).
- UI kit: `templates/macros/ui.html` (page_header, button, field, textarea, search, empty_state, alert, toast) and `static/css/app.css` (one TOKENS block for colours and type, light and dark, WCAG AA, 44px targets, reduced motion).
- Example feature `notes`: routes, service, repository, models, templates and tests, showing inline validation that keeps input, live search, empty states, and delete with Undo instead of "are you sure?". Works without JavaScript too.
- RULES.md section 6: build screens from the UI kit, plus eight user-friendliness rules the reviewer treats as Major. 03-ui-design.md section 5 maps to the kit. CLAUDE.md, TASKS (walking skeleton), the architecture template and the guide (new step "Run the starter app") updated.
- Not included yet: login. Which one depends on the PRD (company sign-in, email and password, social login); RULES.md requires a proven library, never hand-written auth.

## Changes in v2.10

- Release phases and build scope: the PRD assigns every REQ-ID to a phase (P1, P2, ...; section 4a, with guidance on how to phase), TASKS.md has one section per phase and a `Build scope:` line (e.g. `P1, P2, REQ-017`). `start.sh`, `autopilot.sh` and the dashboard only pick REQs inside the scope; `start.sh scope` shows progress per phase or sets the scope; inside Claude, `phases` and `scope ...`. The prototype route builds only the first rough phase in full.

- Specification route B, prototype first: napkin idea, clickable HTML prototype on mock data (`docs/prototype/` with a decision log), feedback rounds, freeze as `prototype-v1`, idea rewritten from it, then the PRD with a short interview. Guide (route chooser at the top of Phase 3), runbook Phase 1 and the CLAUDE.md setup order.
- Guide: Windows folders typed as `C:\...` and converted for Ubuntu, a CMD panel, check-before-install for Ubuntu, WezTerm and tmux, and an explicit "Type inside Claude" header on every Claude prompt.

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
