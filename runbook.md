# Spec-Driven Build Runbook

Kit version: v2.10 (2026-10-03).
A copy-paste runbook for the full traceability loop:

> **Idea → REQ-ID → Architecture row → Wireframe tag → TC-ID → Issue # → branch → PR → merge**
> **Bug → BUG-ID → failing test → Issue # → branch → PR → merge**

**Placeholders:** `<your app>` = your project's name, `REQ-00X` = a requirement ID, `#N` = the GitHub Issue that holds it, `<short-name>` = a short slug for the work, `<kit>` = the path to `reference_files`.
Substitute your own values wherever these appear.
Pick a small first app (5 to 6 requirements) so a full run fits in one session.

**Phases:** 0 setup · 1 specification · 2 build loop (2b automated loop, 2c after every merge, 2d autopilot, 2e dashboard and phone) · 3 bug loop · 4 release.

**Development paths.** Phases 0 and 1 (setup and specification) are always done with you. Each requirement is then built along one of five paths, and you can switch between requirements:

| Path | How a REQ is built | You approve | Where |
|---|---|---|---|
| A Guided | Claude implements in chat with the Implement prompt, step by step; you run the gate | plan, each step, PR, merge | Phase 2, step 5 by hand |
| **B Assisted (default)** | `start.sh` → `next` → approve plan → `loop.sh` → `review` → `explain` → `pr.sh` → `pr.sh merge` | plan, PR, merge | Phase 2 |
| C Autopilot level 1 | you approve plans; autopilot builds, reviews and opens PRs unattended | plans, PRs, merges | Phase 2d |
| D Autopilot level 2 | autopilot drafts plans too; the reviewer agent approves them | PRs, merges | Phase 2d |
| E Autopilot level 3 | also merges after green CI and runs the after-merge checks | the release | Phase 2d |
| Bug path | `start.sh bug "symptom"`, failing test first, then fix with A or B | plan, PR, merge | Phase 3 |

Recommended: path B for the walking skeleton and the first 3 or 4 REQs, reading every walkthrough; path C for batches of similar REQs; D or E only once you trust the test suite.

**Two agents.** The **builder** is your main Claude session plus `scripts/loop.sh`: it plans, writes tests and code, and fixes findings.
The **reviewer** is a second, read-only agent (`.claude/agents/reviewer.md`, Opus, fresh context) that checks every branch before its PR and returns a verdict: APPROVE or CHANGES REQUESTED.
The builder never approves its own work; you still make the final merge decision.

---

## Model policy (read once, then switch with `/model`)

Rule of thumb: **Opus thinks, Sonnet builds, Haiku fetches.**

| Activity | Model | Why |
|---|---|---|
| Scaffolding, renames, commit messages, PR bodies | **Haiku** | Mechanical, cheap and instant |
| Interview → PRD | **Opus** | Sharp questions and clean requirement decomposition |
| Architecture + traceability table, UI design | **Opus** | The table is a bug-finder; reward deep reasoning |
| Wireframe HTML + `data-req` tags | **Sonnet** | Front-end generation workhorse |
| Test plan + coverage check | **Sonnet** | Systematic; Opus only if coverage logic gets hairy |
| PRD → GitHub Issues | **Haiku** | Structured transform of an existing doc |
| Build loop: **plan step** | **Opus** | Plan quality decides everything downstream |
| Build loop: implement + tests | **Sonnet** | Default coding engine |
| Bug loop: reproduce + failing test, fix | **Sonnet** | Straight coding |
| Bug loop: **localise / call-map** | **Opus** | Hardest reasoning in the project |
| Code review (reviewer agent) | **Opus** | Pinned in `.claude/agents/reviewer.md`; a fresh context that did not write the code |
| Release audit | **Sonnet** | Tool-driven checks; Opus for judgement calls |

Switch anytime with `/model opus`, `/model sonnet`, `/model haiku`.
Each prompt below names the model to switch to.

---

## Phase 0 - Setup (before any writing)

### Where to start
Open your terminal in the folder that will **hold** the project, not inside it (the project folder does not exist yet), for example `~/Projects`.

### 0-prereq. Get the kit and set up the machine (once)
1. Get the kit: clone its GitHub repo inside WSL, e.g. `git clone https://github.com/<owner>/reference_files.git ~/kits/reference_files` (details: `readme.md` > "Getting the kit").
   Every command below that says `reference_files/` means that folder.
2. Machine setup: `readme.md` > "One-time machine setup".
Skipping the git identity is the number one cause of `src refspec main does not match any`: with no identity the first commit fails, so no `main` branch exists to push.
Verify: `git config --global --list | grep -E 'user|default'`

### 0a. Run the scaffold
One command creates the folder, git repo, template docs, scripts, CI, first commit and the private GitHub repo.
Run it **from your projects root**:
```bash
cd ~/Projects
bash <kit>/scaffold.sh <your app> python      # stack: node | python | go | rust
```
Leaving out the stack skips CI; re-run later with a stack to add it (re-running is safe and keeps your files).

**What it does, 7 reported steps, in this order (the order is the point):**

| Step | Does | Fails loudly if |
|---|---|---|
| 0/6 Preflight | checks git, your identity, the kit templates and the stack name | anything missing → **aborts** before touching disk |
| 1/6 Folder + init | `mkdir`, `cd`, `git init -b main` | folder unusable, init fails |
| 2/6 Template | copies `templates/project/`: CLAUDE.md, `.gitignore`, all docs, `src/`, `tests/`, `scripts/` READMEs | copy fails |
| 3/6 Scripts + CI | copies `loop.sh` and `req_status.sh` to `scripts/`; writes `.github/workflows/ci.yml` for your stack | CI block did not activate |
| 4/6 **First commit** | `git add -A && git commit` | commit fails, or 0 commits exist |
| 5/6 **Branch check** | renames `master` (or anything else) to `main` | rename fails |
| 6/6 Repo + push | `gh repo create … --remote=origin --push` | gh missing, not authenticated, or name taken |

> **Why 4 before 6:** `gh repo create --push` needs a commit to exist.
> Creating the repo first is exactly what produces `src refspec main does not match any`.
> **Why step 5 exists:** older git silently gives you `master`; every `main` command then fails.

Every line is prefixed so you can scan it: `OK :` succeeded · `WARN :` non-fatal · `KEPT :` existing file left alone · `ERROR :` something did not work, with the fix command underneath.
The summary ends with `Result: SUCCESS` or `Result: COMPLETED WITH n WARNING(S)`, plus branch, commit count, remote, CI and the tree.

**ERROR lines you may see, and what each means:**

| Message | Meaning | Fix |
|---|---|---|
| `missing git identity` | **aborted** before touching anything | do 0-prereq, re-run |
| `project template not found` | scaffold.sh was moved out of the kit | run it from inside `reference_files/` by path |
| `unknown stack` | typo in the stack argument | use node, python, go or rust |
| `gh CLI not found` | local repo is fine, nothing pushed | `git remote add origin <url>` then `git push -u origin main` |
| `gh is installed but not authenticated` | local repo fine, nothing pushed | `gh auth login`, then `gh repo create <your app> --private --source=. --remote=origin --push` |
| `gh repo create failed` | repo name likely taken | re-run `gh repo create` with another name |
| `could not rename '<x>' to 'main'` | branch is wrong | `git branch -M main` by hand |
| `no commit exists` | a push would fail | `git add -A && git commit -m "chore: scaffold"` |

**Sanity check before moving on:**
```bash
git log --oneline     # at least 1 commit
git branch            # main
git remote -v         # origin
```

> Every artifact after this must be a reviewable diff.

### 0b. Connect GitHub to Claude
```bash
gh auth login        # if not already
gh issue list        # must run clean
```
You want Issues creatable straight from the PRD.

### 0c. Launch the session
WezTerm (`.wezterm.lua`) already opens WSL inside a tmux session called `main`, so do not run `tmux new` from there (that nests tmux).
Create a separate session for the project and switch to it:
```bash
cd <your app>
tmux new-session -d -s <your app> -c "$PWD" && tmux switch-client -t <your app>
```
Outside tmux (a plain shell), `tdev <your app>` from `.bashrc` does the same.

### tmux - the 4-pane layout (keys from the kit's `.tmux.conf`)
The prefix is **Ctrl-a**, not Ctrl-b.
```
Ctrl-a |          # split left/right → 2 panes
Ctrl-a -          # split the focused pane top/bottom → repeat to get 4 panes
Ctrl-h/j/k/l      # move between panes (no prefix; also works across nvim splits)
Ctrl-a H/J/K/L    # resize (hold to repeat) · Ctrl-a m zooms one pane
Ctrl-a T          # name the pane: claude, test, git, frontend
```
Or right-click a pane and pick its role from the menu (Claude, Development, Tests, Git, Logs); that names and colours it.

### PANE MAP - which step runs where

| Pane | Name | Owns | Runs |
|---|---|---|---|
| **1** | `claude` | the driver | `claude` - **every prompt in this runbook goes here** |
| **2** | `test` | the red/green signal | the test watcher - never stops running |
| **3** | `git` | version control + GitHub | all `git` / `gh` commands, `scripts/loop.sh`, `scripts/req_status.sh` |
| **4** | `frontend` | what it looks like | dev server, `docs/03-wireframe/index.html`, or `ccusage blocks --live` |

> The discipline: **claude proposes, test decides.** You never merge on "it looks right"; you merge when the test pane is green.

### 0d. First `claude` run
In the claude pane run `claude` and **accept the trust dialog** (needed once per repo, or `scripts/loop.sh` runs untrusted and may not write files).

### 0e. Install RTK (Rust Token Killer), once per machine
RTK compresses command output before it reaches Claude's context: 60 to 90 percent fewer tokens on `git`, `ls`, `grep` and test runners.
Run in the **git** pane:
```bash
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
mkdir -p ~/.claude   # rtk init -g writes here; Claude Code may not have created it yet
rtk init -g          # installs a PreToolUse hook into Claude Code
```
If you see `Failed to write RTK.md ... No such file or directory`, run the `mkdir -p` above and re-run `rtk init -g`.
Then restart Claude Code in pane 1 and re-source your shell in the other panes.
Verify:
```bash
rtk --version
ls -l ~/.claude/RTK.md
grep -i rtk ~/.claude/settings.json    # the hook actually registered
```

### 0f. Cost status line, once per machine
In the **claude** pane (a prompt to Claude, not a shell command):
```
/statusline show session cost, today's total cost, and the active model
```
Verify in the git pane: `grep -A3 statusLine ~/.claude/settings.json`.
"Active model" stops you from grinding a build loop on Opus or planning on Haiku.
For a cross-pane view, park `npx ccusage@latest blocks --live` in the frontend pane.
Read the numbers as relative signals, not as an invoice.

### 0g. Check the kit is active (first session in every new project)
Two checks: one for the files, one for Claude.

**Files and tools** (git pane):
```bash
bash scripts/start.sh check
```
It reports PASS / WARN / FAIL for: CLAUDE.md at the repo root, every doc in `docs/`, the reviewer agent, `.claude/settings.json`, all scripts, `.gitignore`, CI, the tools (git, claude, gh, jq, python3), the remote and branch protection, how many docs are still TEMPLATE or DRAFT, the doc-lint, and the MCP servers (0h).
Fix every FAIL before going on. WARN lines about TEMPLATE docs are expected until Phase 1 is done.

**Claude is reading them** (claude pane):
```
Which project files have you read this session, and what does section 0 of CLAUDE.md tell you to do?
```
Expect CLAUDE.md, `docs/RULES.md`, `docs/TASKS.md`, `docs/MEMORY.md` and `docs/MCP.md`, and a description of the TEMPLATE/DRAFT setup check and the MCP check.
If Claude does not mention them, it was started outside the project folder: quit, `cd` into the project, start `claude` again.

| What makes the kit work | Where it happens |
|---|---|
| Files copied into the project | `scaffold.sh` step 2/6 (template) and 3/6 (scripts, CI) |
| Claude loads `CLAUDE.md` | Automatically, every session, from the folder `claude` is started in |
| Claude reads RULES, TASKS, MEMORY | CLAUDE.md section 3 tells it to, every session |
| Setup check (TEMPLATE / DRAFT docs) | CLAUDE.md section 0, and typing `setup` |
| Reviewer agent available | `.claude/agents/reviewer.md`, its commands pre-approved in `.claude/settings.json` |
| File and function comments enforced | `scripts/doclint.sh`, run by loop.sh, pr.sh merge, CI and the reviewer |
| MCP servers and their check | `.mcp.json` (servers), `docs/MCP.md` (check and usage rules), loaded by CLAUDE.md section 0 |

### 0h. MCP tools (browser and codebase map)
Every project gets three free MCP servers in `.mcp.json`:

| Server | Gives Claude | Needs |
|---|---|---|
| `chrome-devtools` | Open the running app, read console and network errors, performance traces | Node.js 18+ |
| `playwright` | Click through user flows like a user (login, forms, checkout) | Node.js 18+ |
| `graphify` | A map of the codebase: callers, callees, impact of a change | uv, and the map built once with `/graphify .` |

Once per machine (git pane):
```bash
node --version                                   # v18 or newer, else install the LTS from nodejs.org
curl -LsSf https://astral.sh/uv/install.sh | sh  # uv, for graphify
uv tool install "graphifyy[mcp]" && graphify install   # adds the /graphify command
```
Once per project (claude pane): approve the project MCP servers when Claude asks (or via `/mcp`), then build the map with `/graphify .` and restart claude.
Graphify is optional while `src/` is small; the map in `graphify-out/` is gitignored and rebuilt per machine (`/graphify . --update` after big merges).

**How it is enforced.** CLAUDE.md section 0 loads `docs/MCP.md`.
At the start of each interactive session Claude checks which servers are connected and, only if something is missing, prints a ✅/❌ list with the exact install commands, then carries on.
`loop.sh` and `autopilot.sh` mark their prompts `NON-INTERACTIVE RUN`, so those runs skip the check.
`bash scripts/start.sh check` section 5 checks the same from the git pane: `.mcp.json`, no API keys in it, `docs/MCP.md`, the CLAUDE.md import, node, uv, the graphify map and `.gitignore`.

**Paid servers** (Firecrawl, Perplexity) are not in `.mcp.json`. Add them per user with `claude mcp add --scope local ...` (commands in `docs/MCP.md` section 3), so API keys never reach git.


### 0i. The quality gate (what "done" means)
`bash scripts/gate.sh` is the single definition of "the code is acceptable". loop.sh, autopilot.sh, `pr.sh merge` and CI all run it.

| Step | Checks | Python tool |
|---|---|---|
| doclint | README per folder, file headers, `Calls:` lines, files under 300 lines, `service.py` free of web and database imports | `scripts/doclint.sh` |
| lint | complexity 8, max 5 args, 8 branches, 40 statements, no `print`, no blind `except`, no commented-out code, security patterns | ruff |
| format | one formatting style | ruff format |
| types | strict type hints on everything in `src/` | mypy |
| tests + coverage | the full suite, and 85% of `service.py` | pytest, pytest-cov |
| audit, secrets (`--full`) | known-vulnerable dependencies, leaked keys | pip-audit, gitleaks |

For Python, the limits live in `pyproject.toml` (scaffold.sh creates it from `templates/stacks/python/`).
Run `uv sync` once after scaffolding so the tools are installed. To fix style problems automatically: `uv run ruff check --fix . && uv run ruff format .`
Never loosen a limit to get green; change one only through a decision in 02-architecture.md section 9.

---

## Phase 1 - Specification (the doc chain)

Two routes, chosen at the start of Phase 1 (the guide shows one at a time):
- **Route A, requirements first** (below): you know what the app should do. Idea, PRD, architecture and UI design, wireframe.
- **Route B, prototype first**: you are not sure yet how the app should work.
  1. Write a napkin idea in `docs/00-idea.md` (a few lines; line 1 stays `Status: DRAFT`).
  2. Claude (Sonnet) builds a clickable HTML prototype in `docs/prototype/`: every element works on mock data, each screen can show empty, loading and error states, a "PROTOTYPE - mock data" banner, and `docs/prototype/DECISIONS.md` with "Assumptions to confirm" and "Decisions".
  3. Click through it and give feedback in rounds ("screen: change, because why"); Claude updates the prototype and logs each change with its reason. Commit each round as `proto: round N`. Stop when a new user finds their way without help and no assumptions are left open.
  4. Freeze it: `git tag prototype-v1 && git push --tags`. It is never edited again and its code is never reused in the app.
  5. Claude (Opus) rewrites `docs/00-idea.md` from the prototype and the decision log, plus "Questions the prototype cannot answer" (permissions, data rules, errors, numbers, privacy, integrations). You approve it.
  6. Continue with the PRD below; the interview covers only those open questions, and every prototype screen and flow becomes requirements. The UI design takes its tokens and screens from the prototype, and the wireframe is the prototype with `data-req` tags.

Every doc in `docs/` starts with `Status: TEMPLATE` on line 1.
Claude refuses to write application code until the setup docs are `Status: APPROVED - <date>`.

> **During Phase 1, approved spec docs commit straight to `main`** (CLAUDE.md section 0).
> No branch, no PR; branches and PRs start in Phase 2.
> The rule for each doc: **generate it, pass its review gate, set its Status line to APPROVED, THEN commit and push.**
> Run every `git` command in the **git** pane.

### Step 0 - Start the setup flow  · **`/model sonnet`**
In the claude pane type:
```
setup
```
Claude lists every file still at TEMPLATE or DRAFT and proposes the order below.
Type `setup` again at any time to see where you are.

### Step 1 - Raw idea → `docs/00-idea.md`
Write the napkin sketch by hand (or dictate it to Claude), set line 1 to `Status: APPROVED - <date>`, then:
```bash
git add docs/00-idea.md && git commit -m "docs: raw idea (approved)" && git push
```

### Step 2 - Interview → PRD  · **`/model opus`**
```
Interview me to produce docs/01-prd.md for <your app> from docs/00-idea.md.
Ask questions in small batches; do NOT write the PRD until I say "go".
When I say go, fill the template in docs/01-prd.md. EVERY requirement carries a stable
REQ-ID (REQ-001, REQ-002, ...), permanent and never renumbered, with testable acceptance
criteria. Functional and non-functional separated. No implementation detail, only what and why.
Leave line 1 as "Status: DRAFT".
```
> A REQ-ID is **not** a PR.
> It lives in the spec, then becomes an Issue → branch → PR.

### Step 3 - ⬛ Review gate: PRD (you)
Read it. **Cut scope**: the cheapest place in the whole project to say no.
Set line 1 to `Status: APPROVED - <date>`, then:
```bash
git add docs/01-prd.md && git commit -m "docs: PRD with REQ-IDs (approved)" && git push
```

### Step 4 - Architecture + traceability table  · **`/model opus`**
```
Fill docs/02-architecture.md from docs/01-prd.md.
Non-functional envelope: <users, data volume, response time, auth, deployment, offline needs>.
Section 8 MUST be the traceability table: REQ-ID | component(s) | file(s) | notes.
Flag any REQ-ID with no row (gap) and any component with no REQ-ID (scope creep).
List every external dependency in section 6. Leave line 1 as "Status: DRAFT".
```

### Step 5 - UI design  · **`/model opus`**
```
Fill docs/03-ui-design.md from docs/01-prd.md: colour tokens (light and dark, WCAG AA),
typography, components, the empty/loading/error states, and section 9 listing every
screen with its REQ-IDs. Leave line 1 as "Status: DRAFT".
```

### Step 6 - ⬛ Review gate: architecture + UI design (you)
Check the traceability table both ways: no REQ-ID without a row, no component without a REQ-ID.
Approve both Status lines, then:
```bash
git add docs/02-architecture.md docs/03-ui-design.md
git commit -m "docs: architecture + UI design (approved)" && git push
```

### Step 7 - Wireframe  · **`/model sonnet`**
```
Build docs/03-wireframe/index.html: a navigable, clickable, single-file HTML wireframe
covering the full happy path for <your app>, following docs/03-ui-design.md.
Every screen or element that serves a requirement carries data-req="REQ-00X".
Add a "trace mode" toggle that shows a visible badge with each element's REQ-ID.
No backend; hardcode sample data.
```

### Step 8 - ⬛ Review gate: wireframe (you)
Click through it in the **frontend** pane, toggle trace mode, confirm each screen carries its `data-req`.
```bash
git add docs/03-wireframe/ && git commit -m "docs: wireframe with data-req tags (approved)" && git push
```

### Step 9 - Test plan + CLAUDE.md FILL IN  · **`/model sonnet`**
```
Fill docs/04-testplan.md: one row per test case TC-### | REQ-ID | type | steps | expected.
Every REQ-ID must have at least one test case; flag any with zero as UNVERIFIABLE.
Fill section 2 (regression gate) from the PRD's release acceptance criteria.
Then fill the FILL IN sections of CLAUDE.md (project, stack and commands, regression gate),
including the full test command with the doc-lint. Leave Status lines as DRAFT.
```
Review, approve, then:
```bash
git add docs/04-testplan.md CLAUDE.md && git commit -m "docs: test plan + CLAUDE.md filled (approved)" && git push
```

### Step 10 - RULES and launch checklist  · **`/model opus`**
```
Propose changes to docs/RULES.md (section 1 project rules) and docs/05-launch-checklist.md
for this project, as a numbered list of additions and removals with reasons.
Do not edit the files until I approve each item.
```
Approve item by item, let Claude apply them, set both Status lines to APPROVED, then commit and push.

### Step 11 - PRD → GitHub Issues + TASKS  · **`/model haiku`**
```
Read docs/01-prd.md. Create one GitHub Issue per REQ-ID, strictly one-to-one.
Do NOT group REQ-IDs unless two are inseparable (same code change, cannot be tested apart).
Title: "REQ-00X: <short name>". Body: the requirement + its TC-IDs from docs/04-testplan.md.
Label each "requirement". Use gh issue create.
Then fill docs/TASKS.md: phases in build order, each line "REQ-00X (#N) <title>" with the real
Issue number. Set its Status line to APPROVED.
```
```bash
gh issue list                       # verify
git add docs/TASKS.md && git commit -m "docs: TASKS with Issue numbers (approved)" && git push
```
> The hinge: the spec stops being a document and becomes a work queue.
> **One Issue per REQ-ID** means each branch and PR finishes exactly one REQ, so its PR always uses `Closes #N`.

### Step 12 - Close setup
Set `docs/MEMORY.md` line 1 to `Status: APPROVED - <date>` and add the first session-log line.
Type `setup` once more: Claude should report nothing left at TEMPLATE or DRAFT.
From here on, every change goes through a branch and a PR, starting with `bash scripts/start.sh`.

---

## Phase 2 - Build loop (repeat once per requirement)

**Exit condition = the FULL test suite is GREEN. Not "it looks right." Green.**

You never type a REQ-ID or an Issue number in this phase.
`scripts/start.sh` picks the next requirement from `docs/TASKS.md` and creates a branch whose name carries the ID (`feat/REQ-003-profile`).
From then on `loop.sh`, `pr.sh`, `next` and `review` read the ID from the branch name and the Issue number from the TASKS line.
Lost? `bash scripts/start.sh status` shows the current ID, Issue, plan, review, PR and the next action.

### First: set up the panes (once, when Phase 2 begins)

| Pane | Fire this once | Then |
|---|---|---|
| **claude** | `claude` is already running | you type every prompt here |
| **test** | the watcher (Python: `ptw .` · Node: `npm test -- --watch`) | **leave it running all day** |
| **git** | your shell, sitting on `main` | every script, git and gh command |
| **frontend** | your run command once code exists, else `ccusage blocks --live` | view the app |

> **`test` is your traffic light.** It re-runs the tests on every save. You never type in it; you only look at it.

### The loop, one step at a time

| Step | Pane | Model | Do exactly this |
|---|---|---|---|
| 1 | **git** | - | `bash scripts/start.sh` - picks the next unticked REQ, finds its Issue, creates the branch, prints what it chose |
| 2 | **claude** | **`/model opus`** | `next` - drafts `docs/plans/<REQ>.md` for the current branch. Plan only, NO code |
| 3 | **you** | - | ⬛ **STOP. Read the plan. Approve or fix it.** Then set its line 1 to `Status: APPROVED - <date>` |
| 4 | **git** | - | `git add docs/plans && git commit -m "docs: approved plan"` |
| 5 | **git** | **sonnet** | `bash scripts/loop.sh` (Phase 2b), or implement by hand with the **Implement** prompt |
| 6 | **test** | - | watch it go RED as tests land, then GREEN as code catches up |
| 7 | **frontend** | - | if there is UI, check it against 03-ui-design.md. Missing docs, lint, complexity, format or type errors already turned the loop red (the loop's exit condition is `bash scripts/gate.sh`) |
| 8 | **git** | - | `git add -A && git commit -m "feat: <summary>"` (the loop prints the exact message with the ID and Issue) |
| 9 | **claude** | reviewer (Opus) | `review` - the reviewer agent checks the branch; its report is saved to `docs/reviews/<REQ>.md` and committed |
| 10 | **git** | sonnet | **CHANGES REQUESTED?** `bash scripts/loop.sh` again (it reads the findings), commit, then `review` again. Maximum 2 rounds |
| 10b | **claude** | sonnet | after **APPROVE**: `explain` - Claude appends a plain-language walkthrough to the review file: files changed, the path a request takes, where to look if it breaks. Read it: this is how you learn your codebase |
| 11 | **git** | - | `bash scripts/pr.sh` - pushes and opens the PR (it refuses without an APPROVE, and warns without a walkthrough) |
| 12 | **you** | - | ⬛ **STOP. Review the PR.** Read the review report and walkthrough first, then the diff. If you cannot follow the diff, ask Claude to simplify it before merging |
| 13 | **git** | - | `bash scripts/pr.sh merge` - asks you to confirm, waits for CI, merges, runs the after-merge checks (Phase 2c) |
| 14 | **claude** | opus, then haiku | the traceability audit prompt (Phase 2c), then `wrap up`. Next requirement: back to step 1 |

> **Two hard stops:** step 3 (plan) and step 12 (PR). Loop as much as you like between them, but never cross either without a human "yes."
> **One agent gate:** `pr.sh` will not open a PR until the reviewer says APPROVE. Two CHANGES REQUESTED rounds in a row means the plan is wrong: re-plan, do not keep fixing.
> **One hard signal:** step 6 ends only when the **test** pane is green.

`start.sh` refuses to start new work while you are on an unfinished branch, so you cannot lose track of a half-done requirement (`FORCE=1` overrides).
To work on a specific requirement instead of the next one: `bash scripts/start.sh REQ-004`.

**Prompts (pasted in the claude pane):**

Plan - `/model opus` (or just type `next`):
```
Write an implementation plan ONLY for the REQ in the current branch name, to docs/plans/<REQ>.md,
starting from docs/plans/_TEMPLATE.md: goal, TC-IDs covered, approach, files to touch, risks,
review focus and the iteration cap. Keep line 1 as "Status: DRAFT". No code yet.
```

Implement by hand - `/model sonnet`:
```
Implement the REQ in the current branch name per its approved plan in docs/plans/. Write the tests
first from the TC rows, then the code, until the FULL suite is green. Follow docs/RULES.md
section 3 for file headers, function doc blocks and directory READMEs.
```

Review - typed in the claude pane (the reviewer runs on Opus by itself):
```
review
```
You should see the verdict line, the Critical and Major findings, and the report committed.
If a finding looks wrong to you, say so: you can overrule the reviewer, but write the reason in the PR body.

### Unrelated problems found on the way (CLAUDE.md section 10)
- **Small hygiene** (lint, failing or flaky test, typo, obvious UI defect, under about 20 lines, no behaviour change): fix in its own commit `chore(hygiene): <what>` on the same branch; list it in the PR.
- **Anything bigger:** `bash scripts/start.sh bug "symptom"` later, or add a chore line to `docs/TASKS.md`; do not fix it in this PR.

### Pausing overnight, resuming tomorrow
State lives in **git + Issues + tests + docs**, not in the chat.

**Before you stop:** type `wrap up` in the claude pane, then in the git pane:
```bash
git add -A && git commit -m "wip: exactly where I stopped" && git push
```

**Tomorrow:** restart the watcher in the test pane, then in the git pane:
```bash
bash scripts/start.sh status      # which REQ, plan, review and PR state, and the next action
```
and in the claude pane (start on `/model sonnet`):
```
Resuming. Before any code: run `bash scripts/start.sh status`, `git log --oneline -5`, `bash scripts/req_status.sh`
and the full test suite; read docs/MEMORY.md, the current REQ in docs/01-prd.md and its plan in docs/plans/.
Summarise what is done, what is left, and the next step. Do NOT write code until I approve.
```

---

## Phase 2b - Automate the grind with the LOOP (bounded Ralph)

Steps 5 and 6 are the repetitive part: implement, check the test pane, feed back the failure, repeat.
`scripts/loop.sh` automates exactly that inner grind and nothing else.
It never touches your human gates.

**What it is:** the Ralph loop (Geoffrey Huntley) runs the agent in a shell loop with a **fresh context every pass** (quality degrades past roughly 100 to 150k tokens).
State survives in files and git, not chat history.
It is **bounded**: it exits on a **green full suite**, not on the agent deciding it is done, and it stops at an iteration cap.

> **The catch fresh context creates:** each pass sees only files, not your chat.
> So the approved plan must live in `docs/plans/<REQ>.md` with line 1 `Status: APPROVED - <date>`.
> `loop.sh` refuses to run without that, and injects the plan into every pass under "APPROVED PLAN - follow this exactly".

| Pane | Fire this |
|---|---|
| **git** | `bash scripts/loop.sh` (cap from the plan's "Maximum loop iterations" line, else 8; `bash scripts/loop.sh 5` to override) |
| **test** | `watch -n2 'tail -20 .loop-test-out.txt 2>/dev/null'` |
| **claude** | idle; the loop spawns its own fresh `claude` each pass |

After a CHANGES REQUESTED review, run the same command again: the loop feeds the findings into every pass, and lists any finding the builder disputes for you to decide.

**Guardrails built into `loop.sh` (do not remove):**
- Refuses to run on `main`, without a plan file, or with a plan that is not `Status: APPROVED`.
- Refuses a REQ that is already merged or whose Issue is closed (override with `FORCE=1` after a revert).
- The agent may not commit, open PRs, or edit TASKS, MEMORY or approved spec docs.
- If the plan is unworkable, the agent writes why to `FAILURES.txt` instead of silently changing approach.
- Unrelated problems are listed under "Noticed" in `FAILURES.txt` and printed at the end, not fixed.
- **Hitting the cap means the plan was wrong**: read the diff, re-plan on Opus, update and re-approve the plan file, then re-run.

**Full example (git pane):**
```bash
bash scripts/start.sh                 # next REQ, branch created
# claude pane: next  → approve the plan (line 1), then:
git add docs/plans && git commit -m "docs: approved plan"
bash scripts/loop.sh                  # → "OK : SUITE GREEN on iteration k"
git add -A && git commit -m "feat(REQ-00X): <summary> (#N)"   # the loop prints this line filled in
# claude pane: review  → APPROVE (or loop again, commit, review again)
# claude pane: explain → walkthrough appended to docs/reviews/<ID>.md
bash scripts/pr.sh                    # push + PR
# review the PR on GitHub, then:
bash scripts/pr.sh merge              # CI, merge, after-merge checks
```

---

## Phase 2c - 🔴 After EVERY merged PR (do not skip)

A green branch is not a green project.
`bash scripts/pr.sh merge` already does steps 1 to 3; finish with 4 and 5.

| Step | Pane | Model | Do this |
|---|---|---|---|
| 1 | **git** | - | on `main`, the **FULL** suite, no filters (done by `pr.sh merge`) |
| 2 | **git** | - | CI status on `main` (shown by `pr.sh merge`; check GitHub again if it was still running) |
| 3 | **git** | - | `bash scripts/req_status.sh --strict` - every merged REQ-ID has tests (done by `pr.sh merge`) |
| 4 | **claude** | **`/model opus`** | paste the **traceability audit** prompt (below) |
| 5 | **claude** | **`/model haiku`** | `wrap up` - regenerates `docs/REQUIREMENTS_STATUS.md`, ticks TASKS from closed Issues, updates MEMORY |

> Red on `main` after a merge: `pr.sh merge` stops and prints the revert commands. **Revert first, diagnose second.**
> Only when all five are clean do you run `bash scripts/start.sh` for the next requirement.
> Doc updates after merge (file headers, architecture rows, MEMORY, TASKS) go through a small branch and PR, because `main` is protected.

Traceability audit - `/model opus`:
```
Audit traceability: for every REQ-ID in docs/01-prd.md, list its TC-IDs from
docs/04-testplan.md and whether each currently PASSES, plus its row in
docs/02-architecture.md section 8. Flag any REQ-ID with zero passing tests (UNVERIFIABLE),
any failing test, and any architecture row that no longer matches the code.
Output a markdown table.
```

**One-time setup so a red PR can never merge** (git pane, after CI has run once):
```bash
gh api -X PUT repos/:owner/:repo/branches/main/protection \
  -F required_status_checks[strict]=true \
  -f "required_status_checks[contexts][]=test" \
  -F enforce_admins=false \
  -F required_pull_request_reviews=null \
  -F restrictions=null
```
This is also the moment Phase 1's "commit straight to main" ends for good.

---

## Phase 2d - Autopilot (optional, unattended)

Use it when Phase 1 is approved and you want several requirements built while you are away.
It runs Phase 2 steps 1 to 11 for each REQ in `docs/TASKS.md` and stops at your gates, depending on the level.

| Level | Run in the git pane | You do before | You do after |
|---|---|---|---|
| 1 (default) | `bash scripts/autopilot.sh` | approve the plans (`start.sh` + `next`, steps 1 to 4) | review and merge the PRs, Phase 2c |
| 2 | `AUTOPILOT=plan,build bash scripts/autopilot.sh` | nothing | review and merge the PRs, Phase 2c |
| 3 | `AUTOPILOT=plan,build AUTO_MERGE=1 bash scripts/autopilot.sh` | branch protection on (Phase 2c) | read the report, `wrap up` |

Always start with a dry run, and keep the caps:
```bash
DRY_RUN=1 bash scripts/autopilot.sh                           # what would happen, nothing changes
MAX_REQS=2 MAX_COST=5 bash scripts/autopilot.sh                # level 1, two REQs, 5 USD at most
bash scripts/autopilot.sh REQ-004 REQ-005                      # exactly these REQs
NOTIFY_CMD="notify-send Autopilot" bash scripts/autopilot.sh   # desktop note when it ends
```

When you come back:
1. Read `.autopilot/<run-id>.md`: what finished, which PRs are open, what stopped and why ("Needs you").
2. For each open PR, read `docs/reviews/<REQ>.md` first, then the diff; merge, then Phase 2c.
3. Plans marked `by reviewer agent` deserve a quick read, since you did not approve them.
4. Type `wrap up`.

> Without `AUTO_MERGE`, each REQ is built from `main` on its own branch, so pick REQs that do not depend on each other.
> A plan line `Depends on: REQ-00X` makes autopilot skip a REQ until that one is merged.

---


## Phase 2e - Live dashboard and phone (optional)

A plain-language view of the whole build, for you and for people who do not read code.
It shows how many features are live, what is being built right now (attempt 3 of 6, checks failing or passing), every feature on a six-stop rail (Plan, Approved, Building, Checking, Your review, Live), what needs a person, recent activity, and the specification status.
It is styled in the ZeroZeta theme and works on a phone.

### Start it (frontend pane)
```bash
python3 scripts/dashboard.py              # this computer only: http://localhost:8765
python3 scripts/dashboard.py --lan        # also your phone: prints a phone address and a 6-digit PIN
python3 scripts/dashboard.py --read-only  # watch only, for sharing a screen with others
```
Python standard library only; nothing to install. Leave it running in the frontend pane.
The scripts (`start.sh`, `loop.sh`, `gate.sh`, `pr.sh`, `autopilot.sh`) write one plain-language line per step to `.kit/events.jsonl` (gitignored); the dashboard reads it with docs/TASKS.md, the plans, the reviews, git and GitHub.

### What the buttons do
| Button | Runs | Shown when |
|---|---|---|
| Read and approve | sets the plan's line 1 to `Status: APPROVED - <date> (dashboard)` and commits it, after you tick "I have read the plan" | a plan is DRAFT |
| Build / Fix and rebuild | `bash scripts/loop.sh` | plan approved, or the reviewer asked for changes |
| Open for review | `bash scripts/pr.sh` | reviewer APPROVE and walkthrough written |
| Merge | `YES=1 bash scripts/pr.sh merge`, after you confirm you read the review, walkthrough and changes | PR open |
| Start / Switch to it | `bash scripts/start.sh` / `bash scripts/start.sh REQ-00X` | nothing in progress / another feature checked out |
| Run the quality checks | `bash scripts/gate.sh` | always |
| Summarise progress | `claude -p --model haiku` writes a four-sentence summary for non-technical readers | always |

Steps that need Claude itself (`next`, `review`, `explain`, writing code) are listed under "Needs you" with the word to type.
The dashboard refuses to build, switch or merge while a build is running, and refuses plan or PR actions for a feature that is not checked out.

### On your phone
1. **At home, same Wi-Fi.** Start with `--lan`, open the printed address on the phone, enter the PIN, then "Add to Home Screen".
   Scripts run in WSL, which hides them from the network by default. Once per machine, in Windows:
   ```
   # C:\Users\<you>\.wslconfig
   [wsl2]
   networkingMode=mirrored
   ```
   Then in PowerShell (as administrator):
   ```powershell
   wsl --shutdown
   New-NetFirewallRule -DisplayName "Build dashboard 8765" -Direction Inbound -Protocol TCP -LocalPort 8765 -Action Allow
   Set-NetFirewallHyperVVMSetting -Name '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -DefaultInboundAction Allow
   ```
   Mirrored networking needs Windows 11 22H2 or later. Use the Windows Wi-Fi address (`ipconfig`) on the phone.
2. **Away from home (recommended).** Install Tailscale (free personal plan) on the PC and the phone and sign in to both with the same account.
   With mirrored networking on, open `http://<PC's Tailscale address>:8765`. The dashboard is never exposed to the internet.
3. **Talk to Claude from the phone.** Start Claude with `claude --remote-control` (or type `/rc` in a running session) and scan the QR code with the Claude app.
   The session keeps running on your PC; the phone is a window into it. Needs a Pro, Max, Team or Enterprise subscription login.
4. **Read the code changes** in the GitHub mobile app before you press Merge.

Security: the PIN is required for every phone request (5 wrong tries lock that device out for 15 minutes); sessions end when the dashboard stops.
Do not port-forward 8765 on your router. Use Tailscale instead.

---

## Phase 3 - Bug loop (repeat once per bug)

Same shape as Phase 2, with a sharper exit: **a test that was RED goes GREEN, and the full suite stays GREEN.**
A bug with no failing test is not fixed; it is hidden.
You never pick a BUG number: `start.sh bug` takes the next free one, files the Issue and creates `fix/BUG-00X`.

| Step | Pane | Model | Do exactly this |
|---|---|---|---|
| 1 | **you** | - | observe the symptom as a real user would (in **frontend** if it is UI) |
| 2 | **git** | - | `bash scripts/start.sh bug "login fails with an empty password"` - files the Issue, creates the branch; add the steps, expected and actual to the Issue |
| 3 | **claude** | **`/model sonnet`** | **Reproduce** prompt: reproduce END-TO-END, write a FAILING test, NO fix |
| 4 | **test** | - | confirm the new test is **RED**. That red is your proof |
| 5 | **git** | - | commit the failing test alone: `git commit -am "test: failing test for the bug"` |
| 6 | **claude** | **`/model opus`** | **Localise** prompt: call-map + root-cause hypothesis, no patch |
| 7 | **claude** | **`/model sonnet`** | **Fix** prompt (minimal fix), or `next` for a plan, approve it, then `bash scripts/loop.sh` |
| 8 | **test** | - | the RED test goes GREEN and the whole suite stays GREEN |
| 9 | **git** | - | `git commit -am "fix: <cause>"` |
| 10 | **claude** | reviewer (Opus) | `review`; fix findings and review again until **APPROVE** (maximum 2 rounds) |
| 11 | **git** | - | `bash scripts/pr.sh`, review the PR, then `bash scripts/pr.sh merge` |

> **Why two commits (step 5, then step 9):** the failing test lands on its own, so the history proves the bug existed before the fix.
> **Order that matters:** localise (step 6) comes AFTER the failing test, never before.
> Record the test in `docs/04-testplan.md` section 5 and any lesson in `docs/MEMORY.md`.

**Prompts:**

Reproduce - `/model sonnet`:
```
The bug in the current branch name: reproduce it end-to-end as a user would, using the steps in its
GitHub Issue, then write a FAILING test that captures exactly this bug. Do NOT fix anything yet;
show me the test go red.
```

Localise - `/model opus`:
```
The test is red. Give me the call-map: who calls the failing path, top-down, and your
single best hypothesis for the root cause. Don't patch yet.
```

Fix - `/model sonnet`:
```
Apply the minimal fix for the bug in the current branch name. The failing test must go green and
the full suite must stay green. Do not weaken or skip any test.
```

---

## Phase 4 - Release

Run when the Must requirements are merged and Phase 2c is clean.
`docs/05-launch-checklist.md` is the gate; sections A and B are blocking.

| Step | Pane | Model | Do this |
|---|---|---|---|
| 1 | **claude** | **`/model sonnet`** | `audit` - every item marked Pass / Fail / N/A with evidence; nothing is fixed |
| 2 | **you** | - | ⬛ read the Fails; decide which to fix now and which become Issues |
| 3 | **git** | - | `git checkout -b chore/release-fixes` |
| 4 | **claude** | sonnet | `fix A3, B1, D1` (the IDs you chose) - each re-checked with the same tool, before and after shown |
| 5 | **git** | - | commit, PR, merge, Phase 2c |
| 6 | **claude** | sonnet | `release check` - blocking sections re-run, audit-log row added |
| 7 | **git** | - | tag the release: `git tag v1.0.0 && git push --tags` |

> **No evidence means Fail.** "I read the code" does not count when Lighthouse, axe-core, Playwright, gitleaks or the test suite can check it.

---

## The one-line spine

```
Idea → REQ-ID → Architecture row → Wireframe tag → TC-ID → Issue # → branch → PR → merge
Bug  → BUG-ID → failing test → Issue # → branch → PR → merge
```

## ID scheme cheat-sheet
- **REQ-00X** - requirement, born in the PRD, permanent.
- **TC-###** - test case, always points at one REQ-ID.
- **BUG-00X** - defect, gets its own failing test before any fix.
- **#N** - GitHub Issue number. One Issue per REQ-ID.
- Commits always carry the REQ/BUG-ID and the Issue number: `feat(REQ-00X): ... (#N)`.

## Commands cheat-sheet (typed in the claude pane)

| Command | What happens |
|---|---|
| `setup` | Lists docs still at TEMPLATE or DRAFT and continues the setup order |
| `next` | Picks the next TASKS item and drafts its plan file |
| `review [ID]` | The read-only reviewer agent checks the branch; report saved to `docs/reviews/<ID>.md` |
| `status` | REQ ledger + MEMORY + open TASKS in 5 lines |
| `audit` | Launch checklist, evidence only, no fixes |
| `fix <IDs>` | Fixes only those checklist items and re-checks them |
| `release check` | Re-runs blocking sections, adds an audit-log row |
| `explain [ID]` | After APPROVE: plain-language walkthrough of the change, appended to the review file |
| `wrap up` | Regenerates the REQ ledger, syncs TASKS, updates MEMORY |
| `mcp` | Re-runs the MCP setup check (docs/MCP.md) and lists what is missing |
| `/mcp` | Claude Code's own panel: connection status of each MCP server, approve or reconnect |

## Scripts cheat-sheet (git pane; none of them needs an ID)

| Command | What happens |
|---|---|
| `bash scripts/start.sh` | Next unticked REQ from TASKS.md: finds its Issue, creates the branch |
| `bash scripts/start.sh REQ-004` | Start or resume that REQ |
| `bash scripts/start.sh bug "symptom"` | Next BUG-ID: files the Issue, creates `fix/BUG-00X` |
| `bash scripts/start.sh status` | Where am I: ID, Issue, plan, review, PR, next action |
| `bash scripts/start.sh check` | Is the kit installed and active here, MCP servers included: PASS / WARN / FAIL per item |
| `bash scripts/gate.sh` | The quality gate: doclint, lint, format, types, full tests, service coverage (`--full` adds dependency audit and secrets) |
| `bash scripts/doclint.sh` | README per folder, file headers, function doc blocks, file size, layers (`--changed`: this branch only) |
| `bash scripts/loop.sh` | Bounded implement-and-test loop for the current branch |
| `bash scripts/pr.sh` | Push and open the PR (needs a reviewer APPROVE) |
| `bash scripts/pr.sh merge` | After your PR review: CI, merge, after-merge checks |
| `bash scripts/req_status.sh` | Ledger of every REQ |
| `bash scripts/autopilot.sh` | Optional unattended runs (Phase 2d) |
| `python3 scripts/dashboard.py [--lan]` | Live dashboard on the computer, or also the phone with a PIN (Phase 2e) |
