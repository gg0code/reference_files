# Spec-Driven Build Runbook

A copy-paste runbook for teaching the full traceability loop:

> **Idea → REQ-ID → Design row → Wireframe tag → TC-ID → Issue # → branch → PR → merge**
> **Bug → BUG-ID → failing test → Issue # → branch → PR → merge**

**Placeholders:** `<your app>` = your project's name, `REQ-00X` = a requirement ID,
`#N` = the GitHub Issue that holds it, `<short-name>` = a short slug for the work.
Substitute your own values wherever these appear. Pick a small first app
(5–6 requirements) so a full run fits in one session.

---

## Model policy (read once, then just switch with `/model`)

You have all three tiers. Rule of thumb: **Opus thinks, Sonnet builds, Haiku fetches.**

| Activity | Model | Why |
|---|---|---|
| Setup / scaffolding / renames | **Haiku 4.5** | Mechanical, no reasoning. Cheap and instant. |
| Interview → PRD (Step 2) | **Opus 4.8** | Needs sharp questions + clean requirement decomposition. |
| Design doc + traceability table (4–5) | **Opus 4.8** | The table is a bug-finder; reward deep reasoning here. |
| Wireframe HTML + `data-req` tags (7–8) | **Sonnet 5** | Front-end generation workhorse. |
| Test plan + coverage check (10) | **Sonnet 5** | Systematic, some reasoning; Opus only if coverage logic gets hairy. |
| PRD → GitHub Issues (11) | **Haiku 4.5** | Structured transform of an existing doc. |
| Build loop: **plan step** | **Opus 4.8** | Plan quality decides everything downstream. |
| Build loop: implement + tests | **Sonnet 5** | Default coding engine; fast iteration. |
| Commit messages / PR bodies | **Haiku 4.5** | Templated text. |
| Bug loop: reproduce + failing test | **Sonnet 5** | Straight coding. |
| Bug loop: **localise / call-map** | **Opus 4.8** | Hardest reasoning in the whole project. |
| Bug fix once localised | **Sonnet 5** | Mechanical once you know where. |

In Claude Code, switch anytime with `/model opus`, `/model sonnet`, `/model haiku`. Each prompt below is prefixed with the model to switch to. *(Fable 5 is a writing model — not used here.)*

---

## Phase 0 — Setup (before any writing)

### Where to launch WezTerm
Start it in the folder that will **hold** the project, not inside it (the project folder doesn't exist yet). On your machine that's your dev root, e.g.:

```bash
cd ~/lpro           # the "lpro" you saw in pane 3 — your projects root
```

### 0-prereq. One-time git config (do this before the first ever run)
Skipping this is the #1 cause of the `src refspec main does not match any` error later —
no identity means the first commit fails, which means no `main` branch exists to push.
```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
```
Verify: `git config --global --list | grep -E 'user|default'`

### 0a + 0b. Run the scaffold — folder + git + GitHub repo + tree + first commit
One command does all of it. Run it **from your projects root**, not inside the project:
```bash
cd ~/lpro
bash scaffold.sh myapp        # arg = app name; defaults to "myapp"
```

**What it does — 6 reported steps, in this order (the order is the point):**

| Step | Does | Fails loudly if |
|---|---|---|
| 0/6 Preflight | checks `git` exists + your identity is set | no git, or no `user.name`/`user.email` → **aborts** |
| 1/6 Folder + init | `mkdir`, `cd`, `git init -b main` | folder unusable, init fails |
| 2/6 Scaffold | `docs/03-wireframe src tests` + 4 doc files | tree can't be created |
| 3/6 CLAUDE.md | writes placeholder (keeps yours if present) | can't write |
| 4/6 **First commit** | `git add -A && git commit` | commit fails, or 0 commits exist |
| 5/6 **Branch check** | if branch is `master` (or anything else) → `git branch -M main` | rename fails |
| 6/6 Repo + push | `gh repo create … --remote=origin --push` | gh missing / not authed / name taken |

> **Why 4 before 6:** `gh repo create --push` (and any `git push`) needs a commit to exist.
> Creating the repo first is exactly what produces `src refspec main does not match any`.
> **Why step 5 exists:** older git silently gives you `master`; every `main` command then
> fails. The script detects it and renames, and *tells you it did*.

**Every line is prefixed so you can scan it:** `OK :` succeeded · `WARN :` non-fatal ·
`ERROR :` something didn't work, with the exact fix command underneath.

**Expected output (happy path):**
```
==============================================
 scaffold.sh — project: myapp
==============================================

==> Step 0/6  Preflight checks
    OK    : git found (2.34.1)
    OK    : git identity: GauRav <go2gauravgupta@gmail.com>

==> Step 1/6  Create project folder and initialise git
    OK    : folder ready: /home/gaurav/lpro/myapp
    OK    : git initialised with branch 'main'

==> Step 2/6  Build the folder scaffold
    OK    : created: docs/  docs/03-wireframe/  src/  tests/
    OK    : created docs/00-idea.md
    ... (01-prd, 02-design, 04-testplan)

==> Step 3/6  Seed CLAUDE.md
    OK    : wrote CLAUDE.md placeholder (replace it with the real constitution)

==> Step 4/6  First commit
    OK    : committed: chore: scaffold + CLAUDE.md seed
    OK    : commit count: 1

==> Step 5/6  Ensure branch is named 'main'
    OK    : branch is already 'main' — no rename needed

==> Step 6/6  Create the private GitHub repo and push
    OK    : GitHub repo created (private) and pushed to origin/main

==============================================
 SUMMARY
==============================================
  project folder : /home/gaurav/lpro/myapp
  branch         : main
  commits        : 1
  remote origin  : https://github.com/<user>/myapp.git

  tree:
    ./CLAUDE.md
    ./docs/00-idea.md   ./docs/01-prd.md   ./docs/02-design.md
    ./docs/03-wireframe ./docs/04-testplan.md
    ./src   ./tests

  Result: SUCCESS — all steps completed.
```

**If your branch was `master`, step 5 prints instead:**
```
==> Step 5/6  Ensure branch is named 'main'
    INFO  : current branch is 'master', renaming to 'main'...
    OK    : renamed branch 'master' -> 'main'
```

**The summary always tells you where you stand** — `Result: SUCCESS` or
`Result: COMPLETED WITH n WARNING(S)`, plus branch / commit count / remote at a glance.
If `remote origin : NOT SET`, step 6 didn't complete — read the `ERROR :` line above it.

**ERROR lines you may see, and what each means:**

| Message | Meaning | Fix |
|---|---|---|
| `ERROR : missing git identity` | script **aborted** before touching anything | do 0-prereq, re-run |
| `ERROR : git is not installed` | aborted | install git, re-run |
| `ERROR : gh CLI not found` | local repo is fine, nothing pushed | `git remote add origin <url>` then `git push -u origin main` |
| `ERROR : gh is installed but not authenticated` | local repo fine, nothing pushed | `gh auth login`, then `gh repo create myapp --private --source=. --remote=origin --push` |
| `ERROR : gh repo create failed` | repo name likely taken | re-run `gh repo create` with another name |
| `ERROR : could not rename '<x>' to 'main'` | branch is wrong | `git branch -M main` by hand |
| `ERROR : no commit exists` | a push would fail | `git add -A && git commit -m "chore: scaffold"` |

Re-running the script on an existing folder is safe: it keeps your files, warns that it's
reusing them, and still normalises the branch to `main`.

**If `git push` ever says `'origin' does not appear to be a git repository`:**
you have no remote (step 6 didn't complete — the summary will show `remote origin : NOT SET`).
Check with `git remote -v`; if empty use either
`gh repo create myapp --private --source=. --remote=origin --push` or
`git remote add origin <url> && git push -u origin main`.

**Sanity check before moving on** (all three should look right):
```bash
git log --oneline     # must show 1 commit — if empty, the push will fail
git branch            # must show main (if it says master: git branch -M main)
git remote -v         # must show origin
```

> Every artifact after this must be a reviewable diff — that's the whole point.

### 0c. Seed CLAUDE.md
scaffold.sh left a one-line placeholder. **Replace it** with the provided `CLAUDE.md`
(minimal constitution: purpose, folder map, ID scheme, loop rules), then commit:
```bash
git add CLAUDE.md && git commit -m "docs: seed CLAUDE.md constitution"
```
Enrich later with `/init` once code exists.

### 0d. Connect GitHub to Claude — now, not at Step 8
```bash
gh auth login        # if not already
```
Verify Claude Code can reach it: `gh issue list` should run clean. (Or install the GitHub MCP.) You want Issues creatable straight from the PRD.

### 0e. Launch the session
scaffold.sh already committed **and** pushed, so there's nothing left but tmux:
```bash
tmux new -s myapp
```

### tmux — the 4-pane layout you already have
Inside the session:
```
Ctrl-b %          # split vertical  → 2 panes
Ctrl-b "          # split the focused pane horizontal
Ctrl-b ← / →      # move focus, repeat " to get 4 panes
```
Name panes (nice for a class): `Ctrl-b :` then `select-pane -T claude`.

### 🔲 PANE MAP — which step runs where

| Pane | Name | Owns | Runs |
|---|---|---|---|
| **1** | `claude` | the driver | `claude` — **every prompt in this runbook goes here** |
| **2** | `testing` | the red/green signal | `npm test -- --watch` — never stops running |
| **3** | `git` | version control + GitHub | all `git` / `gh` commands, `scaffold.sh`, `loop.sh` |
| **4** | `frontend` | what it looks like | dev server, `open docs/03-wireframe/index.html` |

**Step → pane, at a glance** (panes referred to by name from here on):

| Step | Pane | Why |
|---|---|---|
| 0-prereq · git config | **git** | git pane owns all git |
| 0a+0b · `bash scaffold.sh` | **git** | it's git/gh work |
| 0c · replace CLAUDE.md + commit | **git** | commit |
| 0e · `tmux new` | — | creates the panes themselves |
| 0f · install RTK | **git**, then restart all | global install, all panes inherit |
| 0g · `/statusline` cost readout | **claude** | it's a Claude prompt, not a shell command |
| 0g · `ccusage blocks --live` | **frontend** | idle until the wireframe exists |
| 1 · write `00-idea.md` | **git** (editor) then commit | |
| 2 · Interview → PRD | **claude** | Claude prompt |
| 3 · ⬛ review PRD | **you** | read it, cut scope |
| 4–5 · Design + traceability | **claude** | Claude prompt |
| 6 · ⬛ review design | **you** | |
| 7–8 · Wireframe | **claude** to build, **frontend** to view | build in claude, open in frontend |
| 9 · ⬛ review wireframe | **frontend** | click through it |
| 10 · Test plan | **claude** | Claude prompt |
| 11 · PRD → Issues | **claude** drives · **git** verifies (`gh issue list`) | |
| **Phase 2** plan | **claude** | Opus plan |
| **Phase 2** implement | **claude** writes · **test** shows red→green | watch the test pane the whole time |
| **Phase 2** branch/commit/PR | **git** | |
| **Phase 3** failing test | **claude** writes · **test** must go RED | red in the test pane IS the proof |
| **Phase 3** localise (call-map) | **claude** | Opus |
| **Phase 3** fix | **claude** · **test** goes green | |

> The discipline this enforces: **claude proposes, test decides.** You never merge on
> "it looks right" — you merge when the test pane is green.

### 0f. Install RTK (Rust Token Killer) — do this once, before real work
RTK is a CLI proxy that compresses command output *before* it reaches Claude's context —
60–90% fewer tokens on `git`, `ls`, `grep`, test runners, etc. On a multi-hour session
like this one, that's the difference between finishing and hitting context limits.

Install it globally so **every pane** gets it (run in **pane 3**):
```bash
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
mkdir -p ~/.claude   # rtk init -g writes here; Claude Code may not have created it yet
rtk init -g          # installs a PreToolUse hook into Claude Code
```

> **If you see** `Failed to write RTK.md: /home/<user>/.claude/RTK.md ... No such file or
> directory (os error 2)` — that's the missing `~/.claude` directory. Run the `mkdir -p`
> above and re-run `rtk init -g`. It happens when RTK is installed before Claude Code has
> ever been run on the machine.

Then **restart Claude Code in pane 1** (and re-source your shell in the other panes) so the
hook loads. The hook rewrites Bash commands automatically — Claude runs `git status`, RTK
turns it into `rtk git status` at the proxy layer. Nothing in your workflow changes.

Verify:
```bash
rtk --version
ls -l ~/.claude/RTK.md                 # the config actually wrote
grep -i rtk ~/.claude/settings.json    # the hook actually registered
rtk git status                         # should print a compact status
```
Writing RTK.md and registering the hook are two separate things. If the `grep` returns
nothing, re-run `rtk init -g` now that `~/.claude` exists.
> Why it matters here: pane 2 streams test output continuously and pane 3 runs `git`/`gh`
> constantly — both are exactly the noisy, repetitive output RTK collapses. Install before
> Phase 1, not halfway through, or you pay full token price for the whole spec chain.

### 0g. Turn on the cost status line — see spend without asking for it

`/cost` is a Claude Code slash command, so it only works **inside pane 1** and only when you
type it. Panes 2–4 are plain shells with no Claude session to ask. A status line solves
this properly: the numbers sit under every prompt, permanently, with no command.

Run this **in pane 1** (it's a prompt to Claude, not a shell command):
```
/statusline show session cost, today's total cost, and the active model
```
Claude writes the script and wires it into `~/.claude/settings.json`. It persists across
sessions and projects, so this is a **once-per-machine** step like RTK.

Verify:
```bash
grep -A3 statusLine ~/.claude/settings.json    # run in pane 3
```

**Why "active model" is in there:** you switch models constantly in this workflow
(`/model opus` for planning, `/model sonnet` for building). The status line is what stops
you from accidentally grinding a whole build loop on Opus, or planning on Haiku.

**For the cross-pane view**, use `ccusage` — it reads Claude Code's local usage logs from
disk, so it needs no Claude session and runs from any pane:
```bash
npx ccusage@latest                    # daily / weekly / per-session breakdown
npx ccusage@latest blocks --live      # live monitor — park this in pane 4
```
Pane 4 is free during Phases 1 and 2 (you only need it to view the wireframe), so it makes
a good home for the live monitor.

> **Read the numbers as relative, not as an invoice.** On subscription plans the dollar
> figures are estimates against API pricing, not what you're actually billed. As a signal
> for "this session is getting expensive, time to `/compact`" they're reliable. As
> accounting they are not.

> Also available: the **session-health-diagnostic-advisor** skill, built for exactly this
> kind of long multi-phase build. Invoke it in pane 1 at the start and it tracks context
> bloat and tells you when to `/compact` or `/clear`, rather than you polling `/cost`.

---

## Phase 1 — Specification (the doc chain)

> **All spec docs commit straight to `main`.** No branch, no PR — branches and PRs start
> in Phase 2, once you're writing code against an Issue. The rule for each document:
> **generate it, pass its review gate, THEN commit and push the approved version.** That
> keeps `main` holding what you approved, not a draft you immediately gutted.
> Run every `git` command below in **pane 3**.

### Step 1 — Raw idea → `docs/00-idea.md`
Write the napkin sketch by hand, then (no gate — it's just the seed):
```bash
git add docs/00-idea.md
git commit -m "docs: capture raw idea"
git push
```
> Teachable moment #1: even the napkin sketch is version-controlled.

### Step 2 — Interview → PRD  · **`/model opus`**
```
Interview me to produce a PRD for <your app> (see docs/00-idea.md).
Ask me questions in small batches; do NOT write the PRD until I say "go".
When I say go, write docs/01-prd.md where EVERY requirement carries a stable
REQ-ID (REQ-001, REQ-002, …). REQ-IDs are permanent identifiers, never renumbered.
Group functional vs non-functional. No implementation detail — only what & why.
```
> A REQ-ID is **not** a PR. It lives in the spec, then becomes an Issue → branch → PR. One REQ-ID can span multiple PRs. Keep them separate or traceability collapses.

### Step 3 — ⬛ Review gate: PRD (you)
Read it. **Cut scope.** Cheapest place in the whole project to say no. Then commit the
trimmed, approved PRD:
```bash
git add docs/01-prd.md
git commit -m "docs: PRD with REQ-IDs (reviewed)"
git push
```
> Optional teaching variant: commit the raw draft first, then commit the trimmed version
> second, so the scope-cut shows up as a diff in git history.

### Step 4–5 — Design doc + traceability table  · **`/model opus`**
Supply the non-functional envelope up front:
```
Write docs/02-design.md from docs/01-prd.md.
Non-functional envelope: ~50 users, single-user local data, <100ms UI response,
<1k tasks, no auth (local only), deployed as a static + SQLite dev build.
The design MUST contain a traceability table with columns:
REQ-ID | how the design addresses it | owning component.
Flag any REQ-ID with no row (gap) and any component with no REQ-ID (scope creep).
```
> The table finds bugs before a line of code exists.

### Step 6 — ⬛ Review gate: Design (you)
Check the traceability table both ways: no REQ-ID without a row, no component without a
REQ-ID. Then commit the approved design:
```bash
git add docs/02-design.md
git commit -m "docs: design + traceability table (reviewed)"
git push
```

### Step 7–8 — Wireframe  · **`/model sonnet`**
```
Build docs/03-wireframe/index.html: a navigable, clickable, single-file HTML
wireframe covering the full happy path for <your app>.
Every screen/element that serves a requirement carries data-req="REQ-00X".
Add a "trace mode" toggle button that reveals a visible badge on each element
showing its REQ-ID. No backend — hardcode sample data.
```
> Hover the UI, see which requirement it serves. Better than a footnote.

### Step 9 — ⬛ Review gate: Wireframe (you)
Click through it in **pane 4**, toggle trace mode, confirm each screen carries its
`data-req`. Then commit the approved wireframe (it's a folder, so add the whole thing):
```bash
git add docs/03-wireframe/
git commit -m "docs: navigable wireframe with data-req tags (reviewed)"
git push
```

### Step 10 — Test plan  · **`/model sonnet`**
```
Write docs/04-testplan.md. One row per test case: TC-### | REQ-ID | steps |
expected. Every REQ-ID must have ≥1 test case. Flag any REQ-ID with zero
test cases as UNVERIFIABLE.
```
Then commit it (no gate — coverage is checked by the "UNVERIFIABLE" flags above):
```bash
git add docs/04-testplan.md
git commit -m "docs: test plan, TC-### mapped to REQ-IDs"
git push
```

### Step 11 — 🔴 PRD → GitHub Issues  · **`/model haiku`**
```
Read docs/01-prd.md. Create one GitHub Issue per REQ-ID — strictly one-to-one.
Do NOT group REQ-IDs into a shared Issue unless two are genuinely inseparable
(they share the same code change and cannot be tested apart). Title: "REQ-00X:
<short name>". Body: the requirement + its TC-IDs from docs/04-testplan.md.
Label each "requirement". Use gh issue create.
```
> The hinge of the class: the spec stops being a document and becomes a work queue.
> **One Issue per REQ-ID keeps everything downstream simple:** each branch and PR
> finishes exactly one REQ, so its PR always uses `Closes #N` — no "does this close
> the Issue or not?" bookkeeping. Group only in the rare inseparable case (see the
> note in Phase 2).

---

## Phase 2 — Build loop (repeat once per Issue)

**Exit condition = the test suite is GREEN. Not "it looks right." Green.**

### Pane names used below

The steps refer to panes by name, not number:
**claude** (driver) · **test** (the watcher) · **git** (version control) · **frontend** (run/view the app).

### First: set up the panes (once, when Phase 2 begins)

Do these in order. **test** and **frontend** keep running for the whole phase. The
`<test-watch>` command depends on your stack — fill in yours:

| Pane | Fire this once | Then |
|---|---|---|
| **claude** | `claude` is already running | you type every prompt here |
| **test** | `<test-watch>` (Python: `ptw .` · Node: `npm test -- --watch`) | **leave it running all day** |
| **git** | your shell, sitting on `main` | you type every git/gh command here |
| **frontend** | your run command, once code exists (Python API: `uvicorn src.main:app --reload`) | view the app; else park `ccusage blocks --live` here |

> **`test` is your traffic light.** Start the watcher once and never stop it. It re-runs your
> tests automatically every time a file is saved. From then on you never type in this pane —
> **you only look at it.** Red = not done, green = done. This is the only pane running
> "together" with the others; everything else is one step at a time.

### ℹ️ One Issue per REQ-ID → the PR keyword is always `Closes #N`

Because Step 11 creates **one Issue per REQ-ID**, each branch/PR finishes exactly one
requirement, so its PR body always uses `Closes #N` and the Issue auto-closes on merge.
There is no "does this complete the Issue or not?" decision to make.

Still look up the Issue number rather than guessing it: GitHub numbers Issues in creation
order, so `REQ-002` will **not** reliably be `#2` (a bug Issue or out-of-order creation
shifts the numbers). One cheap lookup in **git** removes all doubt:
```bash
gh issue list --search "REQ-00X"     # find the Issue # for this REQ, then use it as #N
```

> **The rare grouped exception.** If you ever put two genuinely inseparable REQ-IDs in one
> Issue, a PR that finishes only one of them uses `Refs #N` (Issue stays open) instead of
> `Closes #N`; the Issue closes only when its last REQ merges. Avoid this when you can — one
> REQ per Issue is why the default keyword is simply `Closes #N`.

### Then: the loop, one step at a time (top to bottom)

Below, `#N` = the Issue that contains your REQ (from the `gh issue list` lookup above).
`REQ-00X` / `#N` / `<short-name>` are placeholders — substitute your real REQ, its Issue,
and a short slug.

| Step | Pane | Model | Do exactly this |
|---|---|---|---|
| 1 | **git** | — | `git checkout main && git pull` |
| 2 | **git** | — | `git checkout -b feat/REQ-00X-<short-name>` |
| 3 | **claude** | **`/model opus`** | paste the **Plan** prompt (below). Ask for a plan, NO code |
| 4 | **you** | — | ⬛ **STOP. Read the plan. Approve or fix it.** Nothing proceeds until you say go |
| 5 | **claude** | **`/model sonnet`** | paste the **Implement** prompt (below). Claude writes tests + code |
| 6 | **test** | — | **nothing to type here** — the watcher is already running. Just watch: it flips RED as new tests land, then moves toward GREEN as the code catches up |
| 7 | **claude** + **test** | sonnet | if **test** is still RED: tell Claude the failure in **claude**, let it fix. **Repeat until test is GREEN** |
| 8 | **frontend** | — | if there's UI, open the run command and eyeball it. Be picky |
| 9 | **git** | — | `git add -A && git commit -m "feat(REQ-00X): <short-name> (#N)"` |
| 10 | **git** | — | `git push -u origin feat/REQ-00X-<short-name>` |
| 11 | **git** | — | `gh pr create` — body `Closes #N` (one REQ per Issue, so it completes the Issue) |
| 12 | **you** | — | ⬛ **STOP. Review the PR.** Checklist: tests pass · docs regenerated · traceability intact |
| 13 | **git** | — | `gh pr merge --squash --delete-branch` (the Issue auto-closes) |
| 14 | **git** | — | `git checkout main && git pull` — clean `main`, ready for the next Issue |

> **Two hard stops:** step 4 (plan) and step 12 (PR). You may loop as much as you like
> between them, but never cross either without a human "yes."
> **One hard signal:** step 7 ends only when the **test** pane is green.

**The three prompts (all pasted in pane 1):**

Plan — `/model opus`:
```
Issue #N / REQ-00X. Produce an implementation plan ONLY: files to touch,
functions, data shape, and which TC-IDs the tests will cover. No code yet.
```

Implement — `/model sonnet`:
```
Implement REQ-00X per the approved plan. Write the tests first from the TC rows,
then the code, until the suite is green. Add a file header to each new file:
purpose + the REQ-IDs it serves.
```

Commit + PR wording — `/model haiku` (optional — or just run steps 9–11 in the git pane):
```
First run `gh issue list --search "REQ-00X"` to find the Issue number N for this
REQ. Commit as "feat(REQ-00X): <short name> (#N)". Open a PR titled
"feat(REQ-00X): <short name>". PR body: "Implements REQ-00X." Add "Closes #N"
(one Issue per REQ, so this PR completes the Issue). Checklist: tests pass,
docs regenerated, traceability intact.
```

### 🛑 Pausing overnight, resuming tomorrow

State lives in **git + Issues + tests, not in the chat**, so you don't save the conversation.
You leave the repo speaking for itself.

**Before you stop (in `git`):**
```bash
git add -A
git commit -m "wip(REQ-00X): <one line on exactly where you stopped>"
git push
```
Optionally note the "why/next" in `CLAUDE.local.md` (personal, gitignored).

**Tomorrow — `git` first, then restart the watcher, then `claude`:**
```bash
# git pane:
git checkout feat/REQ-00X-<short-name>
# test pane: restart the watcher →  ptw .   (Node: npm test -- --watch)
```
Then in **claude** (start on `/model sonnet`):
```
Resuming. Before any code: run `git log --oneline -5`, `gh issue view <N>`, and the
test suite; read REQ-00X in docs/01-prd.md and its TC rows in docs/04-testplan.md.
Summarise what's done, what's left, and the next step. Do NOT write code until I approve.
```

---

## Phase 2b — Automate the grind with the LOOP (bounded Ralph)

Steps 5–7 are the repetitive part: implement, check pane 2, feed back the failure, repeat.
`loop.sh` automates exactly that inner grind — and nothing else. It never touches your two
human gates.

**What it is:** the **Ralph loop** (Geoffrey Huntley) runs the agent in a shell loop with a
**fresh context every pass** (quality degrades past ~100–150k tokens, so resetting keeps each
pass sharp). State survives in files + git, not in chat history. The twist for your workflow:
it's **bounded** — it exits on a **green suite**, not on the agent deciding it's done.

> ⚠️ **The catch fresh context creates:** each pass is a blank Claude that sees only files,
> not your chat. So the plan you approved in step 4 — which lives only in the claude session —
> is **invisible to the loop** unless you persist it to a file. Without that, the loop
> re-invents its own approach every run, quietly ignoring the plan you reviewed. The fix
> below is not optional; `loop.sh` refuses to run without it.

### Step 4b — persist the approved plan (do this between plan approval and looping)

Save the plan you just approved to `docs/plans/<REQ>.md`. Easiest is to have the claude
pane write it verbatim (the plan is already in its context):
```
(claude pane) Write the approved plan for REQ-00X verbatim to docs/plans/REQ-00X.md.
```
Then commit it (git pane):
```bash
git add docs/plans/REQ-00X.md
git commit -m "docs: approved plan for REQ-00X"
```
> This is a feature, not overhead: the plan becomes a version-controlled artifact next to
> the code it governs, so the approach you reviewed is auditable in the diff — the same
> discipline as REQ-IDs and TC-IDs. `loop.sh` injects this file into every pass under an
> "APPROVED PLAN — follow this exactly" heading, and the agent is told the plan wins over
> its own instinct.

**When to use the loop:** after step 4 (plan approved) **and** step 4b (plan saved),
instead of hand-running steps 5–7.

| Pane | Fire this |
|---|---|
| **git** | `bash loop.sh <N> REQ-00X` — e.g. `bash loop.sh 1 REQ-003` if Issue #1 holds REQ-003 (look up with `gh issue list --search "REQ-00X"`) |
| **test** | watch it go green (the loop runs the suite itself each pass) |
| **claude** | idle — the loop spawns its own fresh `claude` each pass |

Then resume the manual table at **step 8** (eyeball UI) → commit → PR.

**Guardrails (built into `loop.sh`, do not remove):**
- Never loops across a gate — plan review (step 4) and PR review (step 12) stay human.
- **Refuses to run without `docs/plans/<REQ>.md`** — no approved plan, no loop. (Override the
  path with `PLAN_FILE=...` if you keep plans elsewhere.)
- If the plan turns out unworkable mid-loop, the agent is told to STOP and write to
  FAILURES.txt rather than silently change approach — so a bad plan surfaces to you.
- Caps at 8 iterations. Hitting the cap means the **plan** was wrong: read the diff, re-plan
  on `/model opus`, update `docs/plans/<REQ>.md`, then re-run.
- Refuses to run on `main`. Branch first (steps 1–2).

> **Manual vs loop — same control, different mechanics.** Manual implement (steps 5–7 by
> hand) keeps the plan in the live claude session. The loop keeps the plan in a committed
> file. Either way *you* decide the approach; the loop just forces you to write it down first.

**Full example, start to finish (git pane):**
```bash
git checkout main && git pull
git checkout -b feat/REQ-00X-<short-name>
bash loop.sh <N> REQ-00X            # <N> = the GitHub Issue # holding this REQ
# → prints "OK : SUITE GREEN on iteration k" when implementation succeeds
git add -A
git commit -m "feat(REQ-00X): <short-name> (#N)"
git push -u origin feat/REQ-00X-<short-name>
gh pr create --title "feat(REQ-00X): <short-name>" --body "Implements REQ-00X. Closes #N"
gh pr merge <prnumber> --squash --delete-branch
git checkout main && git pull       # then run the FULL suite (Phase 2c)
```

---

## Phase 2c — 🔴 After EVERY merged PR (do not skip)

A green branch is not a green project. Run these four, in order, after every merge.

| Step | Pane | Model | Do this |
|---|---|---|---|
| 1 | **git** | — | `git checkout main && git pull` then run your **FULL** suite, no filters (Python: `pytest` · Node: `npm test`) |
| 2 | **git** | — | confirm CI is green on `main` (the GitHub check), not just locally |
| 3 | **claude** | **`/model opus`** | paste the **traceability audit** prompt (below) |
| 4 | **claude** + **git** | — | regenerate any docs the change touched (file headers, design rows), commit them |

> Red on `main` after a merge → **revert first, diagnose second:** `git revert -m 1 <merge-sha>`.
> Only when all four are clean do you start the next Issue.

Traceability audit — `/model opus`, pane 1:
```
Audit traceability: for every REQ-ID in docs/01-prd.md, list its TC-IDs from
docs/04-testplan.md and whether each currently PASSES. Flag any REQ-ID with zero
tests (UNVERIFIABLE) or any failing test. Output a markdown table.
```
> Why step 1 matters: a branch suite proves the new REQ works; only the full suite proves
> REQ-001 still works. A REQ-ID that drifts to zero passing tests is a regression in the
> *spec* — invisible to the test runner. That's the check that keeps traceability honest.

**One-time setup** so step 2 can't be forgotten — make CI the mechanical gate (pane 3):
```bash
# after CI has run once, turn on branch protection:
gh api -X PUT repos/:owner/:repo/branches/main/protection \
  -f required_status_checks[strict]=true \
  -f required_status_checks[contexts][]=test
```
Now an un-green PR literally cannot merge.

---

## Phase 3 — Bug loop (repeat once per bug)

Same shape as Phase 2, but the exit condition is sharper: **a test that was RED goes GREEN,
and the full suite stays GREEN.** A bug with no failing test isn't fixed — it's hidden.

### Setup (teaching only): plant bugs on a fixed branch

| Pane | Do this |
|---|---|
| **git** | `git checkout -b demo/bugs-injected main`, hand-edit `src/` to plant 1–2 bugs, commit, push |

The **test** watcher (`ptw .` / `npm test -- --watch`) and **frontend** stay running exactly as in Phase 2.

### The loop, one step at a time

Below, `BUG-00X` = the bug's ID, `#N` = the Issue you file for it, `<cause>` = a short slug.

| Step | Pane | Model | Do exactly this |
|---|---|---|---|
| 1 | **you** | — | observe the symptom as a real user would (in **frontend** if it's UI) |
| 2 | **git** | — | `gh issue create` with a **BUG-ID**: repro steps, expected vs actual |
| 3 | **git** | — | `git checkout main && git pull` then `git checkout -b fix/BUG-00X` |
| 4 | **claude** | **`/model sonnet`** | paste **Reproduce** prompt. Reproduce END-TO-END, write a FAILING test, NO fix yet |
| 5 | **test** | — | **nothing to type** — just watch: confirm the new test is **RED**. That red is your proof |
| 6 | **git** | — | commit the failing test alone: `git commit -am "test(BUG-00X): failing test for #N"` |
| 7 | **claude** | **`/model opus`** | paste **Localise** prompt — ask for the call-map + root-cause hypothesis. No patch yet |
| 8 | **claude** | **`/model sonnet`** | paste **Fix** prompt — minimal fix |
| 9 | **test** | — | **nothing to type** — just watch: the RED test goes GREEN and the whole suite stays GREEN |
| 10 | **git** | — | `git commit -am "fix(BUG-00X): <cause> (#N)"` then `git push -u origin fix/BUG-00X` |
| 11 | **git** | — | `gh pr create --title "fix(BUG-00X): <cause>" --body "Fixes #N (BUG-00X)."` |
| 12 | **you** | — | ⬛ **STOP. Review the PR**, then `gh pr merge --squash --delete-branch` |

> **Why two commits (step 6, then step 10):** the failing test lands on its own so the diff
> proves the bug existed before the fix. That's the most teachable artifact in the project.
> **Order that matters:** localise (step 7, Opus) comes AFTER the failing test, never before.

**The three prompts (all pasted in pane 1):**

Reproduce — `/model sonnet`:
```
BUG-00X: <symptom>. Expected <x>, actual <y>. Reproduce it end-to-end as a user
would, then write a FAILING test that captures exactly this bug. Do NOT fix
anything yet — show me the test go red.
```

Localise — `/model opus`:
```
The test is red. Give me the call-map: who calls the failing path, top-down, and
your single best hypothesis for the root cause. Don't patch yet.
```

Fix — `/model sonnet`:
```
Apply the minimal fix for BUG-00X. The failing test must go green and the full
suite must stay green. Do not weaken or skip any test.
```

---

## The one-line spine (put it on a slide)

```
Idea → REQ-ID → Design row → Wireframe tag → TC-ID → Issue # → branch → PR → merge
Bug  → BUG-ID → failing test → Issue # → branch → PR → merge
```

## ID scheme cheat-sheet
- **REQ-00X** — requirement, born in the PRD, permanent.
- **TC-###** — test case, always points at one REQ-ID.
- **BUG-00X** — defect, gets its own failing test before any fix.
- **#N** — GitHub Issue number (the work-queue handle). One Issue per REQ-ID.
- Commits always tagged with the REQ/BUG-ID and Issue number.
