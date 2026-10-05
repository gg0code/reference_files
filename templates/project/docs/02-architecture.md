Status: TEMPLATE
<!-- Template v2.8. Drafted by Claude (Opus) from 01-prd.md, approved by the user. Keep it current: regenerate affected rows after every merged PR. -->

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
| Migrations | | |
| Auth | | |
| Logging / error tracking | | |
| Hosting / deployment | | |
| Testing | | |
| Quality gate | `scripts/gate.sh` (doclint, lint, format, types, tests) | RULES.md section 2 |

Default for a Python web app, proposed unless the PRD needs something else (each row still needs the user's approval).
scaffold.sh with the python stack already installs this as a running starter app (src/app/README.md):
Python 3.12 with uv · FastAPI · Jinja2 templates + HTMX (no JavaScript build step) · Pydantic and pydantic-settings ·
SQLModel on SQLite to start, PostgreSQL when the PRD needs it · Alembic · stdlib logging as JSON (or structlog) · Sentry ·
Docker image on one managed host · pytest, pytest-cov, Playwright for end-to-end · ruff, mypy, pip-audit, gitleaks.
Choose a JavaScript framework only when a REQ needs interaction HTMX cannot give; record why in section 9.

## 3. Folder structure
One folder per feature area, the same shape in every feature, so a change has one obvious home.
Default for a Python web app (adapt the names to the stack; changing the shape needs a decision in section 9):
```
src/app/
  main.py              creates the app and wires features together; no business logic
  config.py            every setting, read from the environment and validated at startup (section 7)
  features/
    <area>/            one folder per feature area: a group of related REQ-IDs
      routes.py        HTTP in and out only: parse the request, call service, return the response
      service.py       business rules as plain typed functions; no web, template or database imports
      repository.py    the only code that reads or writes the database
      models.py        data shapes (Pydantic / SQLModel)
      templates/       HTML for this feature
  shared/              logging, errors, auth helpers: code used by two or more features
migrations/            Alembic migration files, one per schema change
tests/
  features/<area>/     mirrors src: test_service.py (unit), test_routes.py (integration)
  e2e/                 Playwright user journeys
docs/
```
Every directory has a README.md (see RULES.md).

### 3a. Change map: where to look
Fill in the feature areas once they exist. A returning developer uses this table first.

| If this changes or breaks | Look in |
|---|---|
| A business rule, calculation or decision | `features/<area>/service.py` and `tests/features/<area>/test_service.py` |
| What is stored or loaded | `features/<area>/repository.py`, `models.py`, plus a new file in `migrations/` |
| What a page or API returns, a form, a URL | `features/<area>/routes.py` and `features/<area>/templates/` |
| A setting, key, URL or limit | `config.py` and section 7 of this file |
| Logging, error pages, auth | `shared/` |
| A user journey across features | `tests/e2e/` |
| <area>: <what it does, REQ-IDs> | `features/<area>/` |

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
All settings are read in one place (`config.py`) and validated at startup: the app refuses to start with a missing or invalid value.

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

## 10. Operations
| Concern | How | Checklist |
|---|---|---|
| Health check | `GET /health` reports the app and database as up | O2 |
| Logs | structured, one request ID per request, no personal data | O3, B8 |
| Error tracking | | O4 |
| Migrations | | O5 |
| Backups and restore | | O6 |
| Deploy and rollback | one command each: | O7 |

## 11. Known limits and risks
-
