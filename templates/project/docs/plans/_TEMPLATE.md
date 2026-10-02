Status: TEMPLATE
<!-- Template v2.8. Copy to docs/plans/<ID>.md and set line 1 to "Status: DRAFT". `next` does this for you.
     The user approves by changing line 1 to "Status: APPROVED - <date>". loop.sh refuses anything else.
     Keep it to one page: a plan the user cannot read in five minutes is too big; split the REQ. -->

# Plan: <ID> - <title> (#<Issue>)

Depends on: none
Maximum loop iterations: 6

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
<!-- New tables or columns and the Alembic migration, or "none". -->
None.

## New dependencies
<!-- Each one must already be approved in 02-architecture.md section 6, or this plan asks for approval here. -->
None.

## Risks
-

## Out of scope
-

## Review focus
<!-- What the reviewer agent should look at hardest (RULES.md section 8). -->
-
