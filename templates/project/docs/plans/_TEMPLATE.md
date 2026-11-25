Status: TEMPLATE
<!-- Template v3.14.1. Copy to docs/plans/<ID>.md and set line 1 to "Status: DRAFT". `next` does this for you.
     The user approves by changing line 1 to "Status: APPROVED - <date>". loop.sh refuses anything else.
     Keep it to one page: a plan the user cannot read in five minutes is too big; split the REQ. -->

# Plan: <ID> - <title> (#<Issue>)

Depends on: none
Risk: standard - <one-line reason>
Maximum loop iterations: 6
<!-- Risk tier (CLAUDE.md section 5). `next` proposes it; the user approves it with the plan.
     strict   : touches auth, payments, deleting data, a public API or routes, shared/, migrations, or adds a dependency.
     light    : copy, styling, or a refactor with no behaviour change. Nothing else.
     standard : everything else. A plan with no Risk line counts as standard.
     standard and strict: /tests writes the failing tests, the user reads docs/tests/<ID>.md and runs
     bash scripts/lock_tests.sh, which adds the lock line below Risk. After that no test file changes
     (integrity.sh I6), and loop.sh refuses to start without the lock. Only the user removes the lock line. -->

## Goal
<!-- One or two sentences: what the user can do when this is merged. Quote the acceptance criterion from 01-prd.md. -->

## TC-IDs covered
| TC-ID | What it proves | Test file (to create) |
|---|---|---|

## Approach
<!-- The simplest design that meets the acceptance criteria (RULES.md section 4). Plain steps, no code.
     Name the feature folder, and say what goes in routes.py, service.py and repository.py. -->
1.

## Files to create or change
| File | Layer | Change |
|---|---|---|
| `src/app/features/<area>/service.py` | business rules | |
| `tests/features/<area>/test_service.py` | unit tests | |

## Data and migrations
<!-- New tables or columns and the Alembic migration, or "none".
     For each migration: does it drop, rename or narrow a column? If yes, say how existing data survives,
     and plan a test that runs upgrade -> downgrade -> upgrade on a database holding sample rows (RULES.md section 5). -->
None.

## New dependencies
<!-- Each one must already be approved in 02-architecture.md section 6, or this plan asks for approval here.
     Give the exact package name, its home page and why the standard library or an existing dependency is not enough.
     Check the name yourself on the registry: agents can invent package names, and typosquats exist.
     A new dependency changes pyproject.toml / package.json and the lockfile: list both under Allowed exceptions. -->
None.

## Allowed exceptions
<!-- scripts/integrity.sh (inside the gate) fails if this branch changes protected files (gate config, lockfiles,
     CI, scripts, .claude/), deletes or thins existing tests, adds skip markers, or adds # noqa / type: ignore.
     List here ONLY the paths the user approves, one per line with the reason, e.g.
     - pyproject.toml: add httpx (approved dependency)
     - uv.lock: lockfile for httpx
     The builder never edits this section; the loop refuses a plan that changed during a run. -->
None.

## Risks
-

## Out of scope
-

## Review focus
<!-- What the reviewer agent should look at hardest (RULES.md section 8). -->
-
