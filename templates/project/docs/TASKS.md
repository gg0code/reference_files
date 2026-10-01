Status: TEMPLATE
<!-- Template v2.4. Build ORDER only. Status lives in the GitHub Issue. A REQ line is ticked only when its Issue is closed; `wrap up` syncs the ticks from `gh issue list --state all`. -->

# Tasks

How to read this file:
- `[ ]` open, `[x]` Issue closed (or chore done).
- REQ lines name the Issue: `REQ-001 (#N) short title`.
- Chores are work with no REQ-ID (tooling, docs, hygiene). They may have no Issue.
- Work top to bottom unless the user says otherwise.

## Phase 0 - Setup
- [ ] 00-idea.md written and approved
- [ ] 01-prd.md approved; REQ-IDs created as GitHub Issues (one per REQ)
- [ ] 02-architecture.md and 03-ui-design.md approved
- [ ] 04-testplan.md approved; CLAUDE.md FILL IN sections completed
- [ ] RULES.md and 05-launch-checklist.md tailored (proposed changes approved)
- [ ] Repo, CI (`.github/workflows/ci.yml`), branch protection and doc-lint in place
- [ ] Wireframe in `docs/03-wireframe/` with `data-req` tags
- [ ] Browser UI only: Playwright MCP and Chrome DevTools MCP added with `--scope project` (RULES.md section 9); `.mcp.json` committed; both connected in `/mcp`
- [ ] Browser UI only: CLAUDE.md section 2 browser fields filled in (local URL, preview URL, views, flows, test accounts, local-run limits)
- [ ] Browser UI only: browser test runner and axe-core binding added as dev dependencies; `tests/e2e/` created with its README; `.gitignore` excludes `test-results/` and `playwright-report/`
- [ ] Browser UI only: CI installs Chromium and runs `tests/e2e/` as part of the full suite
- [ ] Browser UI only: PRD has non-functional REQ-IDs for responsive layout, accessibility and offline behaviour (or marks them out of scope)

## Phase 1 - Core (Must)
- [ ] REQ-001 (#N) <title>
- [ ] REQ-002 (#N) <title>

## Phase 2 - Should
- [ ] REQ-0NN (#N) <title>

## Phase 3 - Release
- [ ] `audit` against 05-launch-checklist.md, using the browser tools for every item they can check; evidence in `audit/`
- [ ] Offline and degraded check run and recorded (RULES.md section 9)
- [ ] Fix blocking Fails
- [ ] `release check` passed and logged

## Chores
- [ ] Turn any browser check done by hand twice into a `tests/e2e/` spec
- [ ] <chore>

## Backlog (Could / later)
-

## Open questions
-
