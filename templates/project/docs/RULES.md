Status: TEMPLATE
<!-- Template v2.8. Mostly reusable. Claude PROPOSES project additions and removals as a list; the user approves each one. Never rewrite wholesale. -->

# Rules

These rules apply to every change.
CLAUDE.md holds the working loop; this file holds the detail.

## 1. Project-specific rules (FILL IN)
<!-- Domain rules that must never be broken, e.g. "prices are always stored in minor units", "the LLM never decides an outcome". -->
-

## 2. Coding rules
- Follow the stack in 02-architecture.md. No new library, CDN, service or network call without approval.
- Strict typing where the language supports it; no `any`, untyped functions or `# type: ignore` without a comment saying why.
- Prefer the existing component library and utilities before writing new ones.
- Keep files around 200 lines or fewer; split by responsibility when larger. Hard limit 300 (doclint D4).
- Keep functions small and flat: at most about 40 statements, 5 parameters, 8 branches, complexity 8.
- Pure logic stays separate from UI, I/O and storage, so it can be unit tested.
- Follow the folder structure and change map in 02-architecture.md section 3. For the default Python layout:
  - `routes.py` handles HTTP in and out only: parse the request, call the service, return the response.
  - `service.py` holds the business rules as plain, typed functions. It never imports the web framework, templates or the database (doclint D5).
  - `repository.py` is the only place that reads or writes the database.
  - A feature folder does not import another feature's `repository.py`; it calls that feature's `service.py`.
- Readable beats clever: plain names that say what a thing is, early returns instead of deep nesting, no metaprogramming, no one-line tricks.
- Add an abstraction (base class, plugin system, generic helper) only when a second real use exists.
- Validate all external input: forms, uploads, API responses, environment variables.
- Handle errors explicitly; never swallow an exception silently.
- No secrets in code. Configuration comes from environment variables listed in 02-architecture.md section 7.
- Wrap browser storage access in try/catch; the app must work without it.
- No dead code, commented-out blocks or debug logging in a merged PR.
- Log through the logging module, never `print`; one structured line per event, with the request ID.

### Enforced by the quality gate
Each rule above that a tool can check is checked by `scripts/gate.sh`, which `loop.sh`, `autopilot.sh`, `pr.sh merge` and CI run.
A red gate means the work is not done.

| Rule | Check (Python stack) |
|---|---|
| Documentation, file size, service layer imports | `scripts/doclint.sh` (D1 to D5) |
| Complexity, function size, unused code, `print`, blind `except`, commented-out code, security patterns | `ruff check` (settings in `pyproject.toml`) |
| Formatting | `ruff format --check` |
| Strict typing | `mypy` (strict) on `src/` |
| Behaviour | the full test suite, plus at least 85% coverage of `service.py` files |
| Known-vulnerable dependencies (`--full`) | `pip-audit` |
| Secrets (`--full`, CI) | `gitleaks` |

Limits live in `pyproject.toml` and change only through an approved decision in 02-architecture.md section 9.

## 3. Documentation conventions
Every directory, file and function carries documentation that travels with the code and is committed as part of the same diff.
These are not optional polish; a change that omits them is incomplete.

- Every new directory has a `README.md` saying what the directory is for, in a sentence or two.
  Creating a directory without a README is unfinished work.
- Every source file starts with a top comment block: what the file does, plus the REQ-IDs it serves.
- Every function carries a comment block stating what it does and what of ours it calls.
  Write callees as `function_name:file_name:directory_name` so a reader can locate each one without searching.
  A function that calls nothing of ours says `Calls: none`.
- Keep the "what it does" and "Calls:" lines true at all times; they are cheap to maintain.
- "Called by:" is optional. It is a back-reference that rots the moment a caller is renamed or moved.
  To find callers, use graphify (`docs/MCP.md`) or the editor's Find References.
  If a block does carry a "Called by:" line, it must be correct: the reviewer checks it for every function in the diff.
- Enforced by `scripts/doclint.sh`, not by review alone: rules D1 (README per folder), D2 (file header), D3 (function doc block),
  D4 (file size) and D5 (Python service layer imports no web, template or database library).
  `loop.sh`, `pr.sh merge` and CI run it in front of the tests, so a missing README, header or doc block turns the suite red.
  The loop's exit condition is a green suite, so a rule with no check behind it is a suggestion the loop can ignore.
- Test files need a header and a docstring or doc block per test (naming its TC-ID), but no `Calls:` line.
- Generated or vendored files go in `.doclintignore` (one glob per line), with a comment saying why.

### Formats doclint accepts
The file header must contain a `REQ-IDs:` line within the first 25 lines (`REQ-IDs: none - <reason>` for shared utilities).
The function block must sit directly above the function (or be the Python docstring) and contain `Calls:`.

Python:
```python
"""Password checks for the login flow.
REQ-IDs: REQ-001, REQ-004
"""

def verify_password(user: User, password: str) -> bool:
    """Return True if the password matches the stored hash.

    Calls: hash_password:crypto.py:src/app/shared
    """


def normalise_email(email: str) -> str:
    """Return the email trimmed and lower-cased.

    Calls: none
    """
```

JavaScript / TypeScript:
```ts
// Session cookie helpers. REQ-IDs: REQ-002

/**
 * Create a signed session cookie for a user.
 * Calls: sign:crypto.ts:src/lib
 */
export function createSession(userId: string) { ... }
```

Go uses `//` lines and Rust `///` lines directly above `func` / `fn`; shell uses `#` lines above `name() {`.

## 4. Engineering standards
- Choose the simplest design that meets 01-prd.md, including its non-functional requirements.
  Design for the scale the PRD states, not beyond it: no caching layer, queue, extra service or plugin system until a requirement needs it.
- Prefer boring, well-known libraries and plain functions over clever code and new abstractions.
  The test of a design: a returning developer can find where a change goes in under a minute, using the change map in 02-architecture.md.
- Quality is not traded for speed: tests, types, documentation and the gate are never skipped to finish sooner.
- When end-to-end testing, match 03-ui-design.md exactly. Anything the design does not specify is not a finding.
- Unrelated problems you notice follow the rule in CLAUDE.md section 10:
  small hygiene fixes (lint, failing or flaky test, typo, obvious UI defect, under about 20 lines, no behaviour change) are fixed in their own `chore(hygiene)` commit on the same branch and listed in the PR;
  anything bigger is logged as a BUG Issue or a TASKS.md chore, not fixed in place.

## 5. Security and privacy
- Treat all input as untrusted; escape output; use parameterised queries.
- Least privilege for keys, roles and database access.
- Never log passwords, tokens or personal data.
- Never send user or project data to a third-party service that is not listed and approved in 02-architecture.md.
- Dependency updates with known vulnerabilities are fixed before release (05-launch-checklist.md B6).

## 6. UI rules
- Follow 03-ui-design.md: tokens only, no hard-coded colours.
- Mobile first; light and dark both supported where the design says so.
- Every screen has empty, loading and error states.
- Accessibility to WCAG AA is a requirement, not polish.

## 7. Working with the user
- Explain the plan before large changes: a new dependency, a schema change, more than about 5 files, or deleting code.
- Ask one specific question when a requirement is ambiguous.
- After 2 failed attempts at the same fix, stop and explain.
- Show evidence (command output, screenshots) instead of saying "done".

## 8. Review
Every REQ and BUG branch is reviewed by the read-only reviewer agent before its PR (CLAUDE.md section 5a).
- **Critical:** wrong behaviour, failing or weakened tests, a security problem, data loss, an unmet acceptance criterion.
- **Major:** a required test missing, a rule in this file broken, required documentation missing, traceability drift, an unapproved dependency or network call.
  Also Major, because maintainability is the product's long-term cost:
  logic in the wrong layer (business rules outside `service.py`, database access outside `repository.py`);
  a function a reader cannot follow without running it;
  an abstraction with only one user;
  a wrong `Called by:` line;
  a `GATE_SKIP`, `# noqa` or `# type: ignore` without a written reason.
- **Minor:** naming, small duplication, an optional edge-case test.
- Any Critical or Major finding blocks the PR. Minor findings are fixed if hygiene-sized, otherwise logged.
- At most 2 review rounds; a second CHANGES REQUESTED means re-plan.
- The builder never approves its own work, and the reviewer never edits code.

## 9. Never
- Weaken, skip or delete a test, or edit fixtures or expected data, to get a green suite.
- Loosen a gate limit, add `GATE_SKIP`, `# noqa` or `# type: ignore` to get a green gate, unless the user approved it and the reason is written next to it.
- Work directly on `main`.
- Delete existing features or tests without asking.
- Modify CHANGELOG.md or any auto-generated file by hand.
- Present placeholder, mock or synthetic data as real.
