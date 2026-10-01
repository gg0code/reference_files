Status: TEMPLATE
<!-- Template v2.4 (adds section 9: browser tools). Mostly reusable. Claude PROPOSES project additions and removals as a list; the user approves each one. Never rewrite wholesale. -->

# Rules

These rules apply to every change.
CLAUDE.md holds the working loop; this file holds the detail.

## 1. Project-specific rules (FILL IN)
<!-- Domain rules that must never be broken, e.g. "prices are always stored in minor units", "the LLM never decides an outcome". -->
-

## 2. Coding rules
- Follow the stack in 02-architecture.md. No new library, CDN, service or network call without approval.
  The dev-only test tooling in section 9 is pre-approved.
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
- Enforce all of the above through the test suite, not through review alone.
  Wire a doc-lint into the test command so a missing README, file header or function block turns the suite red.
  The loop's exit condition is a green suite, so a rule with no test behind it is a suggestion the loop can ignore.

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
- Every UI change is checked in a real browser at 1440, 1180, 768 and 375 px before review (section 9). Reading the code is not a UI check.
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

## 9. Browser tools and test tooling
Applies to projects with a browser UI. Write "N/A - no browser UI" under the heading otherwise.

### Setup (once per project)
Run from the repo root, then restart Claude Code and confirm both show as connected in `/mcp`:
```bash
claude mcp add --scope project playwright -- npx @playwright/mcp@latest
claude mcp add --scope project chrome-devtools -- npx chrome-devtools-mcp@latest
```
- `--scope project` writes `.mcp.json`. Commit it.
- Both servers need Node, even when the app's stack is not Node.
- Package names can change. If a command fails, check the current README of each project.

### Running a browser pass
- Start the dev server with the command in CLAUDE.md section 2 and use the Local URL from there. Stop the server afterwards.
- Never use `file://`.
- Before each pass, clear the app's browser storage (localStorage, sessionStorage, cookies, IndexedDB) and reload, so results do not depend on an earlier session.
- Sign in only with the test accounts named in CLAUDE.md section 2.
- Checks that need the preview URL (see "Local-run limits") are run there and marked as such in the evidence.

### Which tool for which check
| Tool | Use it for |
|---|---|
| Playwright MCP | Screenshots of every view at 1440, 1180, 768 and 375 px; no horizontal page scroll |
| Playwright MCP | Keyboard pass: Tab reaches every interactive element, focus is visible, dialogs trap focus and close with Esc |
| Playwright MCP | Emulated `prefers-reduced-motion: reduce`, light and dark colour schemes, print |
| Playwright MCP | Edge cases: unknown route, missing ID, empty and very long input, invalid form values, storage blocked |
| Playwright MCP | The main user flows from CLAUDE.md section 2, end to end |
| Chrome DevTools MCP | Network request list after visiting every view: every external host, every failed request |
| Chrome DevTools MCP | Console errors and warnings on each view |
| Chrome DevTools MCP | Performance trace of first load; transfer size; resource list |
| Chrome DevTools MCP | Storage keys and values after user actions |
| axe-core (through Playwright) or Lighthouse CLI | WCAG AA contrast and accessibility in light and dark; performance score |
| grep / gitleaks | Secrets and hard-coded URLs in source and built bundles |

### Evidence
- REQ and BUG work: `audit/screens/<ID>/<view>-<width>.png`.
- Audits and release checks: `audit/screens/<YYYY-MM-DD>/` and `audit/reports/<YYYY-MM-DD>/` (network list, console log, axe or Lighthouse JSON).
- Cite the file path as the evidence. A claim about the UI with no screenshot or tool output counts as Fail.

### Offline and degraded check
Block every external host found in the network list (Playwright route blocking).
Confirm the app still renders, the core flow still works, and the user sees a clear message for anything that degrades.
Record what degrades.

### Scripted browser tests
- Runner: `@playwright/test` for Node stacks, `pytest-playwright` for Python. Accessibility: the axe-core binding for the same runner.
- Tests live in `tests/e2e/`, carry the doc-lint file header like any source file, and every test title starts with its TC-###.
- They run inside the full suite and in CI. CI installs the browser first (e.g. `npx playwright install --with-deps chromium`).
- No fixed sleeps. Wait on a visible state. A flaky browser test is a failing test (CLAUDE.md section 6).

### Pre-approved dev-only tooling
Playwright (runner and MCP), Chrome DevTools MCP, axe-core bindings, Lighthouse CLI, gitleaks.
- They are dev dependencies only. The shipped app never loads, references or bundles them.
- axe-core is injected into the page during a test run, never added to the app as a script tag.
- Anything else still needs approval.

## 10. Never
- Weaken, skip or delete a test, or edit fixtures or expected data, to get a green suite.
- Work directly on `main`.
- Delete existing features or tests without asking.
- Modify CHANGELOG.md or any auto-generated file by hand.
- Present placeholder, mock or synthetic data as real.
- Mark a checklist item Pass, or call a UI change done, from reading code when a browser tool can check it.
- Point browser tools at production, at any site outside the CLAUDE.md section 2 URLs, or type real credentials into the app.
- Commit `test-results/`, `playwright-report/` or real user data in screenshots.
