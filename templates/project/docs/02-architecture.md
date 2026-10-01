Status: TEMPLATE
<!-- Template v2.5. Drafted by Claude (Opus) from 01-prd.md, approved by the user. Keep it current: regenerate affected rows after every merged PR. -->

# <Product name> - Architecture

## 1. Overview
<!-- Two or three sentences and, if useful, a simple box diagram (Mermaid or ASCII). -->

## 2. Stack
| Layer | Choice | Why |
|---|---|---|
| Language / runtime | | |
| Framework | | |
| UI / styling | | |
| Data store | | |
| Auth | | |
| Hosting / deployment | | |
| Testing | | |

## 3. Folder structure
```
src/
tests/
docs/
```
Every directory has a README.md (see RULES.md).

## 4. Data model
<!-- Entities, key fields, relationships. Table or Mermaid ER diagram. -->

## 5. Data flow
<!-- How a request or action moves through the system, step by step. -->

## 6. External dependencies
Every external service, library loaded from a CDN, or network call is listed here.
Adding one needs user approval (CLAUDE.md section 10).

| Dependency | Purpose | Network call? | Can it run offline? | Approved |
|---|---|---|---|---|

## 7. Configuration and environment
| Variable | Purpose | Where set | Secret? |
|---|---|---|---|

## 8. Traceability: REQ-ID to component
Both directions must hold: every REQ-ID has a row, and every component serves at least one REQ-ID.

| REQ-ID | Component(s) | File(s) / module(s) | Notes |
|---|---|---|---|
| REQ-001 | | | |

## 9. Key decisions
<!-- Short ADR-style entries. Longer history goes in MEMORY.md. -->
| Date | Decision | Alternatives considered | Reason |
|---|---|---|---|

## 10. Known limits and risks
-
