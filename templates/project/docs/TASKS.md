Status: TEMPLATE
<!-- Template v2.10. Build ORDER only. Status lives in the GitHub Issue. A REQ line is ticked only when its Issue is closed; `wrap up` syncs the ticks from `gh issue list --state all`. -->

# Tasks

Build scope: P1
<!-- What to build now. Phases (P1, P2, ...) and/or single REQ-IDs, comma separated, e.g. "Build scope: P1, P2, REQ-017, REQ-019".
     "all" builds everything. start.sh, autopilot.sh and the dashboard only pick REQs inside the scope.
     Change it with `scope <...>` inside Claude, or `bash scripts/start.sh scope P1 P2 REQ-017` on main. -->

How to read this file:
- `[ ]` open, `[x]` Issue closed (or chore done).
- REQ lines name the Issue: `REQ-001 (#N) short title`.
- Chores are work with no REQ-ID (tooling, docs, hygiene). They may have no Issue.
- Work top to bottom inside the build scope unless the user says otherwise.
- Phase headings match the release phases in docs/01-prd.md section 4a: "## Phase N - <goal>" holds the P<N> REQs.

## Setup
- [ ] 00-idea.md written and approved
- [ ] 01-prd.md approved; REQ-IDs created as GitHub Issues (one per REQ)
- [ ] 02-architecture.md and 03-ui-design.md approved
- [ ] 04-testplan.md approved; CLAUDE.md FILL IN sections completed
- [ ] RULES.md and 05-launch-checklist.md tailored (proposed changes approved)
- [ ] `bash scripts/start.sh check` passes; CI green once; branch protection on
- [ ] Wireframe in `docs/03-wireframe/` with `data-req` tags
- [ ] Walking skeleton (chore, before REQ-001). Python: the starter app already has config, logging, `GET /health`, error pages,
      security headers, CSRF, migrations, the UI kit and an example feature. Run it, set APP_NAME and the tokens, keep the gate
      and CI green, and deploy it once to the real host. Deployment problems found now cost minutes; at release they cost days.

## Phase 1 - <goal from 01-prd.md section 4a>
- [ ] REQ-001 (#N) <title>
- [ ] REQ-002 (#N) <title>

## Phase 2 - <goal>
- [ ] REQ-0NN (#N) <title>

## Phase 3 - <goal>
- [ ] REQ-0NN (#N) <title>

## Release (after any phase you ship, and at the end)
- [ ] `audit` against 05-launch-checklist.md
- [ ] Fix blocking Fails
- [ ] `release check` passed and logged

## Chores
- [ ] <chore>

## Backlog (Could / later)
-

## Open questions
-
