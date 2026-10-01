Status: TEMPLATE
<!-- Template v2.4. Drafted from 01-prd.md acceptance criteria, approved by the user. Tests are written FROM these rows, first. -->

# <Product name> - Test Plan

## 1. Strategy
- Unit tests for logic, integration tests for boundaries, end-to-end tests for user journeys.
- The full suite runs locally with the command in CLAUDE.md section 2 and in CI on every PR and push to main.
- The suite includes the doc-lint (RULES.md), so missing documentation turns it red.
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

## 5. Bug regression tests
Every BUG-00X gets a failing test before the fix; record it here.
| BUG-ID | Issue | TC-ID | Test file |
|---|---|---|---|

## 6. Traceability check
Every REQ-ID in 01-prd.md appears at least once in section 3 or 4, and each one has at least one PASSING test on main.
