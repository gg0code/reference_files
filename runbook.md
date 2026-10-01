# Spec-Driven Build Runbook

Kit version: v2.4 (2026-10-01).
A copy-paste runbook for the full traceability loop:

> **Idea → REQ-ID → Architecture row → Wireframe tag → TC-ID → Issue # → branch → PR → merge**
> **Bug → BUG-ID → failing test → Issue # → branch → PR → merge**

**Placeholders:** `<your app>` = your project's name, `REQ-00X` = a requirement ID, `#N` = the GitHub Issue that holds it, `<short-name>` = a short slug for the work, `<kit>` = the path to `reference_files`.
Substitute your own values wherever these appear.
Pick a small first app (5 to 6 requirements) so a full run fits in one session.

**Phases:** 0 setup · 1 specification · 2 build loop (2b automated loop, 2c after every merge, 2d autopilot) · 3 bug loop · 4 release.

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

### 0-prereq. One-time machine setup
See `readme.md` > "One-time machine setup".
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

---

## Phase 1 - Specification (the doc chain)

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
From here on, every change goes through a branch and a PR.

---

## Phase 2 - Build loop (repeat once per Issue)

**Exit condition = the FULL test suite is GREEN. Not "it looks right." Green.**

### First: set up the panes (once, when Phase 2 begins)

| Pane | Fire this once | Then |
|---|---|---|
| **claude** | `claude` is already running | you type every prompt here |
| **test** | the watcher (Python: `ptw .` · Node: `npm test -- --watch`) | **leave it running all day** |
| **git** | your shell, sitting on `main` | every git/gh command |
| **frontend** | your run command once code exists, else `ccusage blocks --live` | view the app |

> **`test` is your traffic light.** It re-runs the tests on every save. You never type in it; you only look at it.

### Find the Issue number
GitHub numbers Issues in creation order, so `REQ-002` will not reliably be `#2`.
`docs/TASKS.md` lists it, and one lookup removes all doubt:
```bash
gh issue list --search "REQ-00X in:title"
```

### The loop, one step at a time

| Step | Pane | Model | Do exactly this |
|---|---|---|---|
| 1 | **git** | - | `git checkout main && git pull` |
| 2 | **git** | - | `git checkout -b feat/REQ-00X-<short-name>` |
| 3 | **claude** | **`/model opus`** | type `next`, or paste the **Plan** prompt. Plan only, NO code |
| 4 | **you** | - | ⬛ **STOP. Read the plan. Approve or fix it.** Then set its line 1 to `Status: APPROVED - <date>` |
| 5 | **git** | - | `git add docs/plans/REQ-00X.md && git commit -m "docs(REQ-00X): approved plan (#N)"` |
| 6 | **claude** or **git** | **`/model sonnet`** | implement by hand (**Implement** prompt) **or** run the loop (Phase 2b) |
| 7 | **test** | - | watch it go RED as tests land, then GREEN as code catches up |
| 8 | **frontend** | - | if there is UI, eyeball it. Be picky |
| 9 | **git** | - | `git add -A && git commit -m "feat(REQ-00X): <short-name> (#N)"` |
| 10 | **claude** | reviewer (Opus) | type `review REQ-00X`. The reviewer agent checks the branch; its report is saved to `docs/reviews/REQ-00X.md` and committed |
| 11 | **claude** or **git** | sonnet | **CHANGES REQUESTED?** Fix the Critical and Major findings (by hand, or `bash scripts/loop.sh <N> REQ-00X`, which reads them), commit `fix(REQ-00X): address review round 1 (#N)`, then `review` again. Maximum 2 rounds |
| 12 | **git** | - | after **APPROVE**: `git push -u origin feat/REQ-00X-<short-name>` |
| 13 | **git** | - | `gh pr create` with body `Implements REQ-00X. Closes #N. Review: docs/reviews/REQ-00X.md (APPROVE)` |
| 14 | **you** | - | ⬛ **STOP. Review the PR.** Read the review report first, then the diff. Checklist: full suite green · regression gate green · review APPROVE · docs and headers updated · traceability intact · hygiene fixes in their own commits |
| 15 | **git** | - | `gh pr merge --squash --delete-branch` (the Issue auto-closes) |
| 16 | all | - | **Phase 2c**, then `wrap up` in the claude pane |

> **Two hard stops:** step 4 (plan) and step 14 (PR). Loop as much as you like between them, but never cross either without a human "yes."
> **One agent gate:** no PR until the reviewer says APPROVE (step 10). Two CHANGES REQUESTED rounds in a row means the plan is wrong: re-plan, do not keep fixing.
> **One hard signal:** step 7 ends only when the **test** pane is green.

**Prompts (pasted in pane 1):**

Plan - `/model opus`:
```
Issue #N / REQ-00X. Write an implementation plan ONLY to docs/plans/REQ-00X.md, starting
from docs/plans/_TEMPLATE.md: goal, TC-IDs covered, approach, files to touch, risks, and the
iteration cap. Keep line 1 as "Status: DRAFT". No code yet.
```

Implement - `/model sonnet`:
```
Implement REQ-00X per the approved plan in docs/plans/REQ-00X.md. Write the tests first from
the TC rows, then the code, until the FULL suite is green. Follow docs/RULES.md section 3 for
file headers, function doc blocks and directory READMEs.
```

Commit + PR wording - `/model haiku` (optional):
```
Run `gh issue list --search "REQ-00X in:title"` to find Issue N. Commit as
"feat(REQ-00X): <short name> (#N)". Open a PR titled "feat(REQ-00X): <short name>",
body "Implements REQ-00X. Closes #N", with the PR checklist and an "Also fixed" list of any
chore(hygiene) commits.
```

Review - typed in the claude pane (the reviewer runs on Opus by itself):
```
review REQ-00X
```
You should see the verdict line, the Critical and Major findings, and the report committed as `docs(REQ-00X): review round 1 (#N)`.
If a finding looks wrong to you, say so: you can overrule the reviewer, but write the reason in the PR body.

### Unrelated problems found on the way (CLAUDE.md section 10)
- **Small hygiene** (lint, failing or flaky test, typo, obvious UI defect, under about 20 lines, no behaviour change): fix in its own commit `chore(hygiene): <what> (#N)` on the same branch; list it in the PR.
- **Anything bigger:** open a `BUG-00X` Issue or add a chore line to `docs/TASKS.md`; do not fix it in this PR.

### Pausing overnight, resuming tomorrow
State lives in **git + Issues + tests + docs**, not in the chat.

**Before you stop:** type `wrap up` in the claude pane, then in the git pane:
```bash
git add -A
git commit -m "wip(REQ-00X): <one line on exactly where you stopped>"
git push
```
Personal notes can go in `CLAUDE.local.md` (gitignored).

**Tomorrow:** git pane `git checkout feat/REQ-00X-<short-name>`, restart the watcher in the test pane, then in claude (start on `/model sonnet`):
```
Resuming. Before any code: run `git log --oneline -5`, `gh issue view <N>`, `bash scripts/req_status.sh`
and the full test suite; read docs/MEMORY.md, REQ-00X in docs/01-prd.md and docs/plans/REQ-00X.md.
Summarise what is done, what is left, and the next step. Do NOT write code until I approve.
```

---

## Phase 2b - Automate the grind with the LOOP (bounded Ralph)

Steps 6 and 7 are the repetitive part: implement, check the test pane, feed back the failure, repeat.
`scripts/loop.sh` automates exactly that inner grind and nothing else.
It never touches your two human gates.

**What it is:** the Ralph loop (Geoffrey Huntley) runs the agent in a shell loop with a **fresh context every pass** (quality degrades past roughly 100 to 150k tokens).
State survives in files and git, not chat history.
It is **bounded**: it exits on a **green full suite**, not on the agent deciding it is done, and it stops at an iteration cap.

> **The catch fresh context creates:** each pass sees only files, not your chat.
> So the plan you approved must live in `docs/plans/REQ-00X.md` with line 1 `Status: APPROVED - <date>`.
> `loop.sh` refuses to run without that, and injects the plan into every pass under "APPROVED PLAN - follow this exactly".

**When to use it:** after step 5 (plan approved and committed), instead of hand-running steps 6 and 7.

| Pane | Fire this |
|---|---|
| **git** | `bash scripts/loop.sh <N> REQ-00X` (cap from the plan's "Maximum loop iterations" line, else 8) |
| **test** | `watch -n2 'tail -20 .loop-test-out.txt 2>/dev/null'` |
| **claude** | idle; the loop spawns its own fresh `claude` each pass |

Then resume the manual table at **step 8**.
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
git checkout main && git pull
git checkout -b feat/REQ-00X-<short-name>
git add docs/plans/REQ-00X.md && git commit -m "docs(REQ-00X): approved plan (#N)"
bash scripts/loop.sh <N> REQ-00X
# → "OK : SUITE GREEN on iteration k"
git add -A
git commit -m "feat(REQ-00X): <short-name> (#N)"
# claude pane: review REQ-00X   → APPROVE (or fix, re-run the loop, review again)
git push -u origin feat/REQ-00X-<short-name>
gh pr create --title "feat(REQ-00X): <short-name>" --body "Implements REQ-00X. Closes #N. Review: docs/reviews/REQ-00X.md (APPROVE)"
gh pr merge <pr-number> --squash --delete-branch
git checkout main && git pull       # then Phase 2c
```

---

## Phase 2c - 🔴 After EVERY merged PR (do not skip)

A green branch is not a green project.
Run these five, in order, after every merge.

| Step | Pane | Model | Do this |
|---|---|---|---|
| 1 | **git** | - | `git checkout main && git pull`, then the **FULL** suite, no filters |
| 2 | **git** | - | confirm CI is green on `main` (the GitHub check), not just on the branch |
| 3 | **git** | - | `bash scripts/req_status.sh --strict` - every merged REQ-ID has tests |
| 4 | **claude** | **`/model opus`** | paste the **traceability audit** prompt (below) |
| 5 | **claude** | **`/model haiku`** | `wrap up` - regenerates `docs/REQUIREMENTS_STATUS.md`, ticks TASKS from closed Issues, updates MEMORY |

> Red on `main` after a merge → **revert first, diagnose second:** `git revert -m 1 <merge-sha>`.
> Only when all five are clean do you start the next Issue.
> Doc updates after merge (file headers, architecture rows, MEMORY, TASKS) go through a small `docs/` branch and PR, because `main` is protected.

Traceability audit - `/model opus`:
```
Audit traceability: for every REQ-ID in docs/01-prd.md, list its TC-IDs from
docs/04-testplan.md and whether each currently PASSES, plus its row in
docs/02-architecture.md section 8. Flag any REQ-ID with zero passing tests (UNVERIFIABLE),
any failing test, and any architecture row that no longer matches the code.
Output a markdown table.
```

**One-time setup so step 2 cannot be forgotten** (git pane, after CI has run once):
```bash
gh api -X PUT repos/:owner/:repo/branches/main/protection \
  -F required_status_checks[strict]=true \
  -f "required_status_checks[contexts][]=test" \
  -F enforce_admins=false \
  -F required_pull_request_reviews=null \
  -F restrictions=null
```
Now an un-green PR cannot merge.
This is also the moment Phase 1's "commit straight to main" ends for good.

---

## Phase 2d - Autopilot (optional, unattended)

Use it when Phase 1 is approved and you want several requirements built while you are away.
It runs Phase 2 steps 1 to 13 for each REQ in `docs/TASKS.md` and stops at your gates, depending on the level.

| Level | Run in the git pane | You do before | You do after |
|---|---|---|---|
| 1 (default) | `bash scripts/autopilot.sh` | approve the plans (`next`, step 3 to 5) | review and merge the PRs, Phase 2c |
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

## Phase 3 - Bug loop (repeat once per bug)

Same shape as Phase 2, with a sharper exit: **a test that was RED goes GREEN, and the full suite stays GREEN.**
A bug with no failing test is not fixed; it is hidden.

### The loop, one step at a time

`BUG-00X` = the bug's ID, `#N` = the Issue you file for it, `<cause>` = a short slug.

| Step | Pane | Model | Do exactly this |
|---|---|---|---|
| 1 | **you** | - | observe the symptom as a real user would (in **frontend** if it is UI) |
| 2 | **git** | - | `gh issue create --title "BUG-00X: <symptom>" --label bug` with repro steps, expected vs actual |
| 3 | **git** | - | `git checkout main && git pull` then `git checkout -b fix/BUG-00X` |
| 4 | **claude** | **`/model sonnet`** | **Reproduce** prompt: reproduce END-TO-END, write a FAILING test, NO fix |
| 5 | **test** | - | confirm the new test is **RED**. That red is your proof |
| 6 | **git** | - | commit the failing test alone: `git commit -am "test(BUG-00X): failing test for #N"` |
| 7 | **claude** | **`/model opus`** | **Localise** prompt: call-map + root-cause hypothesis, no patch |
| 8 | **claude** | **`/model sonnet`** | **Fix** prompt (minimal fix), or save a plan to `docs/plans/BUG-00X.md`, approve it and run `bash scripts/loop.sh <N> BUG-00X` |
| 9 | **test** | - | the RED test goes GREEN and the whole suite stays GREEN |
| 10 | **git** | - | `git commit -am "fix(BUG-00X): <cause> (#N)"` |
| 11 | **claude** | reviewer (Opus) | `review BUG-00X`; fix findings and review again until **APPROVE** (maximum 2 rounds) |
| 12 | **git** | - | `git push -u origin fix/BUG-00X` then `gh pr create --title "fix(BUG-00X): <cause>" --body "Fixes #N (BUG-00X). Review: docs/reviews/BUG-00X.md (APPROVE)"` |
| 13 | **you** | - | ⬛ **STOP. Review the PR**, then `gh pr merge --squash --delete-branch`, then Phase 2c |

> **Why two commits (step 6, then step 10):** the failing test lands on its own, so the history proves the bug existed before the fix.
> **Order that matters:** localise (step 7) comes AFTER the failing test, never before.
> Record the test in `docs/04-testplan.md` section 5 and any lesson in `docs/MEMORY.md`.

**Prompts:**

Reproduce - `/model sonnet`:
```
BUG-00X: <symptom>. Expected <x>, actual <y>. Reproduce it end-to-end as a user would,
then write a FAILING test that captures exactly this bug. Do NOT fix anything yet;
show me the test go red.
```

Localise - `/model opus`:
```
The test is red. Give me the call-map: who calls the failing path, top-down, and your
single best hypothesis for the root cause. Don't patch yet.
```

Fix - `/model sonnet`:
```
Apply the minimal fix for BUG-00X. The failing test must go green and the full suite must
stay green. Do not weaken or skip any test.
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
| `wrap up` | Regenerates the REQ ledger, syncs TASKS, updates MEMORY |
