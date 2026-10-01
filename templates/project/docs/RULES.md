Status: TEMPLATE
<!-- Template v2.6. Mostly reusable. Claude PROPOSES project additions and removals as a list; the user approves each one. Never rewrite wholesale. -->

# Rules

These rules apply to every change.
CLAUDE.md holds the working loop; this file holds the detail.

## 1. Project-specific rules (FILL IN)
<!-- Domain rules that must never be broken, e.g. "prices are always stored in minor units", "the LLM never decides an outcome". -->
-

## 2. Coding rules
- Follow the stack in 02-architecture.md. No new library, CDN, service or network call without approval.
- Strict typing where the language supports it; no `any` or equivalent escape hatches.
- Prefer the existing component library and utilities before writing new ones.
- Keep files around 200 lines or fewer; split by responsibility when larger.
- Pure logic stays separate from UI, I/O and storage, so it can be unit tested.
- Validate all external input: forms, uploads, API responses, environment variables.
- Handle errors explicitly; never swallow an exception silently.
- No secrets in code. Configuration comes from environment variables listed in 02-architecture.md section 7.
- Wrap browser storage access in try/catch; the app must work without it.
- No dead code, commented-out blocks or debug logging in a merged PR.

## 3. Documentation conventions
Every directory, file and function carries documentation that travels with the code and is committed as part of the same diff.
These are not optional polish; a change that omits them is incomplete.

- Every new directory has a `README.md` saying what the directory is for, in a sentence or two.
  Creating a directory without a README is unfinished work.
- Every source file starts with a top comment block: what the file does, plus the REQ-IDs it serves.
- Every function carries a comment block stating three things: what it does, what it calls, and what calls it.
  Write callers and callees as `function_name:file_name:directory_name` so a reader can locate each one without searching.
- Keep the "what it does" and "what it calls" lines true at all times; they are cheap to maintain.
  The "called by" list is a back-reference and rots the moment a caller is renamed or moved.
  Fix it whenever you touch a caller, and prefer generating it from a tool (ctags, grep or an AST pass) over hand-maintaining it.
- Enforced by `scripts/doclint.sh`, not by review alone: rules D1 (README per folder), D2 (file header) and D3 (function doc block).
  `loop.sh`, `pr.sh merge` and CI run it in front of the tests, so a missing README, header or doc block turns the suite red.
  The loop's exit condition is a green suite, so a rule with no check behind it is a suggestion the loop can ignore.
- Test files need a header and a docstring or doc block per test (naming its TC-ID), but not the Calls / Called by lines.
- Generated or vendored files go in `.doclintignore` (one glob per line), with a comment saying why.

### Formats doclint accepts
The file header must contain a `REQ-IDs:` line within the first 25 lines (`REQ-IDs: none - <reason>` for shared utilities).
The function block must sit directly above the function (or be the Python docstring) and contain `Calls:` and `Called by:`.

Python:
```python
"""Password checks for the login flow.
REQ-IDs: REQ-001, REQ-004
"""

def verify_password(user, password):
    """Return True if the password matches the stored hash.

    Calls: hash_password:crypto.py:src/auth
    Called by: login:routes.py:src/api
    """
```

JavaScript / TypeScript:
```ts
// Session cookie helpers. REQ-IDs: REQ-002

/**
 * Create a signed session cookie for a user.
 * Calls: sign:crypto.ts:src/lib
 * Called by: login:routes.ts:src/api
 */
export function createSession(userId: string) { ... }
```

Go uses `//` lines and Rust `///` lines directly above `func` / `fn`; shell uses `#` lines above `name() {`.

## 4. Engineering standards
- When making technical decisions, do not give much weight to development cost.
  Prefer quality, simplicity, robustness, scalability and long-term maintainability.
- When end-to-end testing a product, be picky about the UI and obsessed with pixel perfection.
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
- **Minor:** readability, naming, small duplication, an optional edge-case test.
- Any Critical or Major finding blocks the PR. Minor findings are fixed if hygiene-sized, otherwise logged.
- At most 2 review rounds; a second CHANGES REQUESTED means re-plan.
- The builder never approves its own work, and the reviewer never edits code.

## 9. Never
- Weaken, skip or delete a test, or edit fixtures or expected data, to get a green suite.
- Work directly on `main`.
- Delete existing features or tests without asking.
- Modify CHANGELOG.md or any auto-generated file by hand.
- Present placeholder, mock or synthetic data as real.
