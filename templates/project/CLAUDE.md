# CLAUDE.md - project constitution

<!--
Template v2.13 - 2026-10-05
Reusable constitution for spec-driven, fully traceable development.
Sections marked FIXED are the same in every project. Do not edit them per project.
Sections marked FILL IN are tailored per project, then approved by the user.
Detailed coding, documentation and engineering rules live in docs/RULES.md, not here.
-->

## 0. Session start check (FIXED)
At the start of every session, before any other work:
1. First session in a new project: run `bash scripts/start.sh check` and report anything marked FAIL.
   Check this file for `FILL IN` markers.
2. Check the first lines of every file in `docs/` for `Status: TEMPLATE` or `Status: DRAFT`.
3. Check that `.github/workflows/ci.yml` exists.
   If not, tell the user to re-run the kit's scaffold with a stack from the projects root, e.g. `bash scaffold.sh <app> python` (safe to re-run; it keeps existing files).
4. If anything is found, STOP and tell the user, as a table: file, current status, what it needs.
5. Then propose the setup order below and wait.
   Do not write application code until setup-order steps 1-4 below are APPROVED.

Setup order (each file is approved before the next is drafted).
If the user chooses the prototype-first route (runbook Phase 1, route B), steps 1 to 3 are preceded by: napkin idea (DRAFT), clickable prototype in `docs/prototype/` with `DECISIONS.md`, feedback rounds, tag `prototype-v1`, then `docs/00-idea.md` rewritten from the prototype and approved. The prototype is never reused as app code.
1. `docs/00-idea.md` - the user writes or dictates it.
2. `docs/01-prd.md` - drafted from the idea, REQ-IDs assigned.
3. `docs/02-architecture.md` and `docs/03-ui-design.md` - drafted from the PRD.
4. FILL IN sections of this file, `docs/04-testplan.md`, `docs/TASKS.md` (one "## Phase N - goal" section per PRD release phase, and a `Build scope:` line, P1 unless the user says otherwise).
5. `docs/RULES.md` and `docs/05-launch-checklist.md` - PROPOSE additions and removals only, as a list.
   Never rewrite them wholesale; the user approves each change.

When a file is approved, change its first line to `Status: APPROVED - <date>`.
After approval, any change to an APPROVED file is shown as a diff and needs approval again.

Where setup work is committed:
During setup (Phase 1, before the first REQ Issue is started), approved spec docs are committed directly to `main` as `docs: <what> (approved)`.
From the first REQ Issue onwards, every change, including doc changes, goes through a branch and a PR.

### 0a. MCP tools (FIXED)
@docs/MCP.md

In an interactive session, run the MCP setup check from `docs/MCP.md` section 1 together with the TEMPLATE/DRAFT check above, in the same message.
Say nothing about MCP when every server is connected.
Skip it in a NON-INTERACTIVE RUN (`loop.sh`, `autopilot.sh`) and when you are the reviewer agent.
While building or debugging, follow `docs/MCP.md` section 2.

## 1. Project (FILL IN)
- **What this is:** one or two sentences: the product and who it is for.
- **Current state:** greenfield / in development / maintained.
- **Anything unusual:** constraints, compliance, hard non-functional limits.
- **Red lines:** project-specific "never" rules (for example "never send user data to third-party APIs").

## 2. Stack and commands (FILL IN)
Claude uses these instead of guessing.
Wrong values here cause wrong commands.
- **Language / runtime:** e.g. TypeScript on Node 20, Python 3.12
- **Install:** e.g. `uv sync` (Python) or `npm ci`
- **Database migrations:** e.g. `uv run alembic upgrade head` (new one: `uv run alembic revision --autogenerate -m "..."`, then review it)
- **Full test suite:** `bash scripts/gate.sh` - the quality gate: doclint, lint, format, types, tests, service coverage.
  `bash scripts/gate.sh --full` adds the dependency audit and secrets scan (pr.sh merge, CI, release). loop.sh and autopilot run the gate automatically.
- **Single test:** e.g. `npm test -- <pattern>`
- **Lint / format:** e.g. `uv run ruff check --fix . && uv run ruff format .` (the gate checks; this fixes)
- **Dev server:** e.g. `uv run uvicorn app.main:app --app-dir src --reload` (Python starter, http://localhost:8000) or `npm run dev`
- **Regression gate:** the few behaviours that must never break, and the command that proves them.

## 3. Folder map (FIXED)
- `CLAUDE.md` - this file: how to work. Read every session.
- `docs/00-idea.md` - raw idea (the napkin sketch).
- `docs/01-prd.md` - PRD; every requirement has a REQ-ID; scope and out-of-scope.
- `docs/02-architecture.md` - stack, data model, data flow, REQ-ID to component traceability table.
- `docs/03-ui-design.md` - visual system: colours, type, components, states.
- `docs/03-wireframe/` - navigable HTML wireframe; elements carry `data-req="REQ-00X"`.
- `docs/04-testplan.md` - test cases; each TC-### maps to exactly one REQ-ID.
- `docs/05-launch-checklist.md` - release gate with evidence and an audit log.
- `docs/RULES.md` - coding, documentation, engineering and security rules.
- `docs/TASKS.md` - ordered roadmap: phases, REQ-IDs in build order, their Issue numbers, chores.
- `docs/MEMORY.md` - current status, dated decisions, gotchas, session log.
- `docs/MCP.md` - MCP setup check and when to use each server (section 0a). Kit file, not a spec doc.
- `docs/plans/REQ-00X.md` - approved implementation plan per REQ or BUG (what the loop enforces).
- `docs/diagrams/` - Archify diagrams: `<name>.json` (source, the one to edit) and `<name>.html` (open in a browser).
- `docs/reviews/REQ-00X.md` - the reviewer agent's report per REQ or BUG; first line is the verdict.
- `.claude/agents/reviewer.md` - the second agent: read-only code reviewer (section 5a).
- `docs/REQUIREMENTS_STATUS.md` - AUTO-GENERATED by `scripts/req_status.sh`. Never edit by hand.
- `src/` - implementation. `tests/` - automated tests. Python stack: a running starter app in `src/app/` (read `src/app/README.md` first) with a UI kit in `src/app/templates/macros/ui.html`; the `notes` feature is an example to copy, then delete.
- `scripts/`: `start.sh` (next REQ, `bug`, `status`, `check`), `loop.sh` (section 8), `pr.sh` (PR / `merge`), `gate.sh` (the quality gate, section 2), `dashboard.py` (live progress view for people, computer or phone), `doclint.sh` (RULES.md s3), `req_status.sh` (REQ ledger), `autopilot.sh` (section 8a).
- `pyproject.toml` (Python) - dependencies and the gate's limits (ruff, mypy, pytest). Limits change only with an approved decision.
- `.claude/settings.json` - shared permissions: pre-approves read-only git, gh, test and script commands (the reviewer needs them); denies force-push and reading `.env`; registers the hooks.
- `.claude/commands/` - one slash command per row of section 9 (`/next`, `/review`, `/scope P1 P2` ...). Each only points at its row here, so section 9 stays the single description.
- `.claude/hooks/` - scripts Claude Code runs automatically: `guard-files.sh` and `guard-bash.sh` block what section 10 forbids (code edits on main, `.env`, force-push, hard reset, `--no-verify`, deletes outside the project, pushes to main), `format-file.sh` formats each Python file Claude writes, `on-stop.sh` and `on-notify.sh` tell the dashboard when Claude is idle or waiting for you.
- `.claude/settings.local.json` - your personal overrides (gitignored).
  All of them read the current REQ or BUG from the branch name and its Issue number from `docs/TASKS.md`, so commands need no IDs.
- `.mcp.json` - MCP servers: chrome-devtools, playwright, graphify (free, local). Never put an API key in it.
- `.github/workflows/ci.yml` - full regression suite plus traceability check on every PR and push to main.
- `.gitignore` - already excludes the loop scratch files (`PROMPT.md`, `FAILURES.txt`, `.loop-*`), `CLAUDE.local.md`, `graphify-out/` (the generated codebase map) and `.kit/` (the dashboard's event log). Never commit them.

Read every session: this file, `RULES.md`, `TASKS.md`, `MEMORY.md`, `MCP.md` (loaded through section 0a).
Read when relevant: PRD (scope), architecture (code structure), UI design (anything visual), test plan (tests).

## 4. ID scheme (FIXED)
- **REQ-00X** - a requirement. Born in the PRD. Permanent, never renumbered. One GitHub Issue per REQ-ID.
- **TC-###** - a test case. Always references exactly one REQ-ID.
- **BUG-00X** - a defect. Gets its own Issue and a FAILING test before any fix.
- **#N** - the GitHub Issue number. It is NOT the REQ number.
  The scripts look it up from `docs/TASKS.md` (or GitHub); when writing a commit by hand, take it from the TASKS line.

PRs use `Closes #N` (REQ) or `Fixes #N` (bug).
Group two REQ-IDs in one Issue only if they share the same code change and cannot be tested apart; then a PR finishing one uses `Refs #N`.
Status lives in ONE place: the GitHub Issue (open or closed).
`TASKS.md` holds only the build order, the Issue numbers, and chores that have no Issue.

Release phases and build scope:
- Every REQ-ID belongs to one release phase (P1, P2, ...) in `docs/01-prd.md` section 4a; `TASKS.md` has one "## Phase N - goal" section per phase.
- The `Build scope:` line at the top of `TASKS.md` says what to build now: phases and/or single REQ-IDs, e.g. `Build scope: P1, P2, REQ-017`, or `all`.
- `start.sh`, `autopilot.sh` and the dashboard only pick REQs inside the scope. Never start, plan or build a REQ outside it unless the user names that REQ.
- Changing the scope is the one doc change allowed straight on `main` after setup: commit it alone as `docs(scope): build scope <new scope>`.
A REQ line in `TASKS.md` is ticked only when its Issue is closed; `wrap up` syncs the ticks from `gh issue list --state all`.

The spine this enforces:
`Idea → REQ-ID → Architecture row → Wireframe tag → TC-ID → Issue # → branch → PR → merge`

## 5. Working loop (FIXED)
1. Start: `bash scripts/start.sh` picks the next REQ in `docs/TASKS.md` and creates `feat/REQ-00X-short-name` (bugs: `bash scripts/start.sh bug "<symptom>"` files the Issue and creates `fix/BUG-00X`). Never work on `main`.
2. Plan: `next` drafts `docs/plans/<ID>.md` for the current branch (files, approach, tests, risks, review focus). Wait for approval.
3. Tests first, from the TC-### rows. Then implement (`bash scripts/loop.sh`) until the gate (`bash scripts/gate.sh`) is green.
   Put each change where the change map in `docs/02-architecture.md` section 3a says it belongs.
4. Commit: `feat(REQ-00X): <summary> (#N)`. Docs are committed in the same diff.
5. Review: the user types `review` (section 5a). Fix every Critical and Major finding, then review again.
6. Explain: after APPROVE, the user types `explain`. Append a walkthrough to `docs/reviews/<ID>.md` (section 9) and commit it as `docs(<ID>): walkthrough (#N)`.
   This is how the user learns the code as it grows; never skip it for a REQ.
7. PR: `bash scripts/pr.sh` refuses until the review verdict is APPROVE. PR checklist: gate green · regression gate green · review APPROVE · walkthrough written · docs and headers updated · traceability intact both ways.
8. After the user's PR review: `bash scripts/pr.sh merge` merges and runs section 7 steps 1 to 3; then the traceability audit and `wrap up`.
`bash scripts/start.sh status` shows at any time where the current branch stands and the next action.

Bug loop: reproduce END-TO-END as a user would, then write a FAILING test, then localise, then fix.
A bug with no failing test is hidden, not fixed.

## 5a. Two agents: builder and reviewer (FIXED)
- **Builder** = this session plus `scripts/loop.sh`. It plans, writes tests and code, and fixes findings.
- **Reviewer** = the `reviewer` subagent in `.claude/agents/reviewer.md`. Fresh context, Opus, read-only. It never edits files.
- On `review <ID>` (or `review` for the current branch): delegate to the `reviewer` subagent with the ID, the Issue number and the plan path.
  Save its report VERBATIM to `docs/reviews/<ID>.md` (never soften, drop or reword a finding), commit it as `docs(<ID>): review round N (#N)`, and show the user the verdict and the Critical and Major findings.
- The report's first line is `Verdict: APPROVE - round N - <date>` or `Verdict: CHANGES REQUESTED - round N - <date>`.
- CHANGES REQUESTED: fix the Critical and Major findings (by hand, or `bash scripts/loop.sh`, which reads the findings), commit `fix(<ID>): address review round N (#N)`, then `review` again.
  Minor findings are fixed now if they are hygiene-sized, otherwise logged as BUG Issues or TASKS chores.
- Maximum 2 review rounds. If round 2 is still CHANGES REQUESTED, stop: the plan or the requirement is wrong, so tell the user and re-plan.
- The builder never approves its own work. Only the reviewer's APPROVE plus the user's PR review lets code merge.

## 6. Test rules (FIXED)
- Exit condition is a green gate (`bash scripts/gate.sh`, which runs the FULL suite), never "it looks right" and never the agent's own judgement.
- Tests check behaviour seen from outside (responses, pages, service results), never private helpers, so refactors keep them green.
- Always run the full suite, not just the new tests. Only the full run proves earlier REQ-IDs still work.
- Never invent coverage that is not traceable to a TC-### and a REQ-ID.
- Never weaken, skip or delete a test, or edit fixtures, expected outputs or source data, to make a suite go green. Fix the cause.
- A flaky test is a failing test. Fix it or delete it with approval; never retry around it.
- CI with branch protection is the mechanical gate. It must never depend on someone remembering.

## 7. After every merged PR (FIXED, non-negotiable)
`bash scripts/pr.sh merge` does steps 1 to 3 after merging.
1. `git checkout main && git pull`, then run the full suite. Red on main: revert first (`git revert -m 1 <merge-sha>`), diagnose second.
2. Confirm CI is green on `main`, not just on the branch.
3. Traceability audit: every REQ-ID still has at least one PASSING test. A REQ at zero is a spec regression.
4. Regenerate affected docs (file headers, architecture rows).
5. Only then pick up the next Issue.

The build loop exits on a green branch.
The project exits on a green `main` with every REQ-ID still covered.

## 8. Looping - bounded Ralph (FIXED)
Run on a feature branch: `bash scripts/loop.sh [max-iters]` (ID and Issue come from the branch; `loop.sh <issue#> <ID>` also works).
- Loop INSIDE an Issue; gate BETWEEN Issues. Plan review and PR review stay human.
- The plan file's first line must be `Status: APPROVED - <date>`; the loop refuses DRAFT plans.
- The iteration cap comes from the command line, else from the plan's "Maximum loop iterations: N" line, else 8.
- Fresh context every iteration; state lives in the codebase, git, `docs/plans/` and PROMPT.md.
- The loop's exit condition is a green `bash scripts/gate.sh`, not just the tests.
- The loop injects the approved plan file every pass, so fresh contexts build the reviewed approach.
- Always cap iterations. Hitting the cap means the PLAN was wrong: re-plan, don't re-run.
- The loop runner refuses to run on `main` or without an approved plan file.

## 8a. Autopilot - optional unattended mode (FIXED)
`bash scripts/autopilot.sh` chains plan, loop, commit, reviewer, fix rounds, push and PR for several REQs from `docs/TASKS.md`.
- Level 1 `AUTOPILOT=build` (default): only REQs whose plan the user approved. Level 2 `AUTOPILOT=plan,build`: the reviewer agent may approve plans, marked "by reviewer agent" in the Status line. Level 3 adds `AUTO_MERGE=1`: merge after green CI, then the section 7 checks.
- The spec docs (00-04, RULES, checklist) are never written or approved by autopilot; it refuses to start until setup is APPROVED.
- It stops on anything it cannot decide (loop cap, 2 CHANGES REQUESTED rounds, disputed findings, red CI or main, cost cap) and lists it under "Needs you" in `.autopilot/<run>.md`.
- When the user returns: read that report, review the open PRs (review file first), then `wrap up`.

## 9. Commands (FIXED)
Each command is also a slash command (`.claude/commands/`): `/setup`, `/next`, `/review` ..., `release check` is `/release-check`, `wrap up` is `/wrap-up`.
The user may type either form; both mean the row below.

| User types | Claude does |
|---|---|
| `setup` | Run the section 0 check and continue the setup order |
| `next` | On `main`: run `bash scripts/start.sh` first. Then draft `docs/plans/<ID>.md` for the current branch's ID and wait for approval |
| `review [ID]` | ID defaults to the current branch's. Run the reviewer subagent on the branch diff, save its report to `docs/reviews/<ID>.md`, show the verdict (section 5a) |
| `status` | Run `bash scripts/req_status.sh`, then summarise it with MEMORY and open TASKS in 5 lines |
| `audit` | Go through `05-launch-checklist.md`, mark Pass / Fail / N/A with evidence, fix nothing, list Fails with blocking sections first |
| `fix <IDs>` | Fix only those checklist items, re-check with the same tool, show before and after |
| `release check` | Re-run blocking sections plus anything changed since the last audit; add an audit-log row |
| `mcp` | Re-run the MCP setup check (`docs/MCP.md` section 1) and list what is missing with its install command |
| `explain [ID]` | ID defaults to the current branch's. Append `## Walkthrough` to `docs/reviews/<ID>.md` in plain language for a returning developer: what the user can now do; the files changed and why each one; the path a request takes through them (route, service, repository); where to look if it breaks; anything surprising. Under one page. If the Archify skill is installed and the change adds a request path, also draw it with archify as `docs/diagrams/<ID>-flow.json` and `.html`, built only from calls you can point to in the code, and link it from the walkthrough. Commit it |
| `diagram <what>` | With the Archify skill: draw or update a diagram (architecture, data flow, a sequence for a REQ) in `docs/diagrams/` (JSON source + HTML), from the code and docs, every arrow traceable to a real call. Show the user the file to open. Without Archify: say how to install it (guide, machine setup) |
| `phases` | Show the release phases from `docs/01-prd.md` section 4a with progress (done / total per phase) and the current build scope; if asked, propose changes as a diff and wait |
| `scope <phases and REQ-IDs>` | e.g. `scope P1 P2 REQ-017`: on `main`, run `bash scripts/start.sh scope <...>` (sets the `Build scope:` line and commits it). Warn if a scoped REQ depends on one outside the scope |
| `wrap up` | Run `bash scripts/req_status.sh -o docs/REQUIREMENTS_STATUS.md`, sync TASKS ticks from closed Issues, update MEMORY, list uncommitted changes and open branches |

Evidence rule: an item with no evidence (test output, tool output, file:line, screenshot) counts as Fail.
Never mark Pass from reading code alone when a tool can check it.

## 10. Hard rules (FIXED - full detail in docs/RULES.md)
Several of these are enforced by `.claude/hooks/`: a blocked tool call explains why and what to do instead. Do what it says; never try to work around a hook.
- No new libraries, CDNs, external services or network calls without asking.
- The simplest design that meets the PRD wins. No abstraction, layer or service until a requirement needs it (RULES.md section 4).
- Never loosen the gate (limits in `pyproject.toml`, `GATE_SKIP`, `# noqa`, `# type: ignore`) to get green without the user's approval and a written reason.
- No secrets in code or frontend bundles; use env variables.
- Don't delete or weaken features, tests or checks without asking.
- Never claim something works without running it.
- The builder never reviews or approves its own work; the reviewer never edits code (section 5a).
- Unrelated fixes (decided rule):
  - **Fix now** if it is small hygiene: a lint error, a failing or flaky test, a typo, an obvious UI defect, under about 20 changed lines and with no behaviour change outside it.
    Put it in its own commit `chore(hygiene): <what> (#N)` on the same branch, and list it under "Also fixed" in the PR.
  - **Log, don't fix** anything bigger, or anything that changes behaviour, an API, a schema or another REQ's code.
    Open a `BUG-00X` Issue (or a chore line in `TASKS.md`) and mention it in the PR.
  - Never mix hygiene changes into the REQ commit itself.
- After 2 failed attempts at the same fix, stop, explain what you tried, and ask.
- If a requirement is ambiguous, ask one specific question rather than assume.
- If a doc conflicts with the code, stop and ask which is right.

## 11. Writing and commit conventions (FIXED)
- Never use the em dash. Use a plain dash.
- Never auto-add the agent name as co-author in commits.
- Never manually modify CHANGELOG.md or any file marked auto-generated.
- In long Markdown files, put each full sentence on its own line.

## 12. Model policy (FIXED)
Opus thinks (PRD, architecture, plans, bug localisation, code review - the reviewer agent pins Opus itself).
Sonnet builds (wireframe, implementation, tests, fixes).
Haiku fetches (scaffolding, commits, PR bodies, PRD to Issues).
Switch with `/model opus|sonnet|haiku`.

<!-- Enrich the FILL IN sections with /init once code exists. -->
