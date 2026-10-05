Status: TEMPLATE
<!-- Template v2.10. Drafted by Claude (Opus) from 00-idea.md, approved by the user. REQ-IDs are permanent and never renumbered. -->

# <Product name> - Product Requirements

## 1. Problem
<!-- From 00-idea.md, sharpened. Why now, what it costs today. -->

## 2. Users and roles
| Role | What they need from the product |
|---|---|
| <primary user> | |
| <secondary user> | |

## 3. Goals and success metrics
| Goal | Metric | Target |
|---|---|---|
| | | |

## 4. Requirements
Each requirement is testable and owns exactly one REQ-ID.
Priority uses MoSCoW: Must, Should, Could. Phase says when it is built (section 4a).
Write a deferrable edge case as its own REQ-ID (for example "bulk import reports invalid rows"), so it can sit in a later phase than the main flow.

| REQ-ID | Requirement | Priority | Phase | Acceptance criteria |
|---|---|---|---|---|
| REQ-001 | <what the user can do or what the system guarantees> | Must | P1 | <observable, testable condition> |
| REQ-002 | | | | |

## 4a. Release phases
Every REQ-ID in sections 4 and 5 belongs to exactly one phase. Each phase ends with something a real user can use, and could be released on its own.
The build scope (which phases or REQs to build now) is set in docs/TASKS.md, not here.

| Phase | Goal: at the end, a user can... | REQ-IDs | Exit criteria | Depends on |
|---|---|---|---|---|
| P1 | <the smallest end-to-end path that delivers the main value> | REQ-001 ... | <demonstrable outcome> | - |
| P2 | | | | P1 |
| P3 | | | | P2 |

How Claude proposes phases (the user adjusts):
- P1, walking skeleton: the one main journey end to end, happy path only, plus the security and data basics it cannot ship without. About 15 to 25 percent of the REQs.
- P2, complete core: the remaining Must requirements, the main error and edge cases, roles and permissions.
- P3 and later: Should requirements grouped by user goal (reporting, efficiency, secondary roles, integrations), one goal per phase.
- Last phase, hardening: performance at the stated scale, accessibility polish, admin tools, remaining edge cases.
- Could requirements go to "Later" (no phase) until promoted.
- Size: 5 to 12 REQs per phase. A REQ never depends on a REQ in a later phase. Non-functional REQs go in the first phase that needs them (for example security in P1).
- Rule of thumb: 20 to 30 REQs make 3 or 4 phases; 50 to 70 REQs make 5 to 7.

## 5. Non-functional requirements
| REQ-ID | Area | Requirement |
|---|---|---|
| REQ-0NN | Performance | e.g. page interactive in under 3 s on a mid-range phone |
| REQ-0NN | Security | e.g. no secrets in the frontend; all traffic over HTTPS |
| REQ-0NN | Accessibility | e.g. WCAG 2.1 AA |
| REQ-0NN | Privacy / compliance | |
| REQ-0NN | Reliability / offline | |
| REQ-0NN | Maintainability | e.g. a change to one feature touches only that feature's folder and its tests; every file passes the quality gate |
| REQ-0NN | Operability | e.g. errors are reported to the maintainer within minutes; a release can be rolled back in under 10 minutes |

## 6. User stories
- As a <role>, I can <action> so that <benefit>. (REQ-00X)

## 7. Out of scope
<!-- Explicit list. Anything not in section 4 or 5 is out of scope by default. -->
-

## 8. Assumptions and dependencies
-

## 9. Acceptance criteria for the release
<!-- The few checks that prove version 1 is done. These usually become the regression gate in CLAUDE.md. -->
-

## 10. Open questions
-

## Change log
| Date | Change | Approved by |
|---|---|---|
