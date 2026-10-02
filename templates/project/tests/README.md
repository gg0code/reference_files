# tests

Automated tests, written from the TC-### rows in docs/04-testplan.md; each test names its TC-ID and REQ-ID.
`features/<area>/` mirrors `src/app/features/<area>/` (unit tests for service.py, integration tests for routes); `e2e/` holds Playwright user journeys.
Run everything with `bash scripts/gate.sh`.
