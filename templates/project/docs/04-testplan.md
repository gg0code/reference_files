Status: TEMPLATE
<!-- Template v2.8. Drafted from 01-prd.md acceptance criteria, approved by the user. Tests are written FROM these rows, first. -->

# <Product name> - Test Plan

## 1. Strategy
- Unit tests for logic (`service.py`), integration tests for boundaries (routes and database), end-to-end tests for user journeys (Playwright).
- Tests check behaviour seen from outside: API responses, rendered pages, and the results of service functions.
  They never test private helpers or internal call order, so a refactor that keeps behaviour keeps the tests green.
- Each test is short and reads as a specification: arrange, act, assert, with the TC-ID in its docstring.
- Coverage floor: at least 85% of `service.py` code (the business rules), checked by `scripts/gate.sh`.
  There is no floor for the whole codebase; coverage is a hint, the TC rows are the requirement.
- The full suite runs locally with the command in CLAUDE.md section 2 and in CI on every PR and push to main.
- The suite runs inside the quality gate (`bash scripts/gate.sh`), so missing documentation, lint, format or type errors turn it red.
- Every TC-### maps to exactly one REQ-ID. No test exists without a TC-###.

## 2. Regression gate
<!-- The few behaviours that must never break. Mirror these in CLAUDE.md section 2. -->
| Gate | TC-IDs | Command |
|---|---|---|

## 3. Test cases
| TC-ID | REQ-ID | Type | Preconditions | Steps | Expected result | Automated in |
|---|---|---|---|---|---|---|
| TC-001 | REQ-001 | unit / integration / e2e | | | | `tests/...` |

## 4. Non-functional checks
| TC-ID | REQ-ID | Check | Tool | Pass threshold |
|---|---|---|---|---|
| TC-0NN | REQ-0NN | Accessibility | axe-core / Lighthouse | 0 serious violations |
| TC-0NN | REQ-0NN | Performance | Lighthouse | score at least 90 |
| TC-0NN | REQ-0NN | Responsive layout | Playwright screenshots 375 / 768 / 1280 | no horizontal scroll |
| TC-0NN | REQ-0NN | Secrets | gitleaks | 0 findings |
| TC-0NN | REQ-0NN | Migrations | `alembic upgrade head` then `alembic downgrade -1` on a copy of real data | both succeed, data intact |
| TC-0NN | REQ-0NN | Startup config | start the app with one required variable missing | refuses to start, names the variable |
| TC-0NN | REQ-0NN | Health | `GET /health` with the database up and down | 200 when up, 503 when down |

## 5. Bug regression tests
Every BUG-00X gets a failing test before the fix; record it here.
| BUG-ID | Issue | TC-ID | Test file |
|---|---|---|---|

## 6. Traceability check
Every REQ-ID in 01-prd.md appears at least once in section 3 or 4, and each one has at least one PASSING test on main.
