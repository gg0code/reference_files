Status: TEMPLATE
<!-- Template v2.8. Build ORDER only. Status lives in the GitHub Issue. A REQ line is ticked only when its Issue is closed; `wrap up` syncs the ticks from `gh issue list --state all`. -->

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
- [ ] `bash scripts/start.sh check` passes; CI green once; branch protection on
- [ ] Wireframe in `docs/03-wireframe/` with `data-req` tags
- [ ] Walking skeleton (chore, before REQ-001): the empty app with `config.py`, logging, `GET /health`, one feature folder shape,
      the gate green, CI green, and one deploy to the real host. Deployment problems found now cost minutes; at release they cost days.

## Phase 1 - Core (Must)
- [ ] REQ-001 (#N) <title>
- [ ] REQ-002 (#N) <title>

## Phase 2 - Should
- [ ] REQ-0NN (#N) <title>

## Phase 3 - Release
- [ ] `audit` against 05-launch-checklist.md
- [ ] Fix blocking Fails
- [ ] `release check` passed and logged

## Chores
- [ ] <chore>

## Backlog (Could / later)
-

## Open questions
-
