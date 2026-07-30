# CLAUDE.md - project constitution

<!--
ADOPTING THIS FILE
This is a reusable constitution for spec-driven, fully-traceable development.
Everything below is project-agnostic EXCEPT the two blocks marked FILL IN.
Fill those in, delete this comment, commit it at your repo root.
Claude reads this automatically at the start of every session.
-->

## Project
<!-- FILL IN: replace the three lines below. Keep it to a few sentences. -->
- **What this is:** one or two sentences describing the product and who it is for.
- **Current state:** greenfield / in development / maintained.
- **Anything unusual:** constraints, compliance needs, or hard non-functional limits.

## Stack and commands
<!-- FILL IN: Claude uses these instead of guessing. Wrong values here cause wrong commands. -->
- **Language / runtime:** e.g. TypeScript on Node 20, Python 3.12, Go 1.22
- **Install:** e.g. `npm ci`
- **Run tests (full suite):** e.g. `npm test`
- **Run a single test:** e.g. `npm test -- <pattern>`
- **Lint / format:** e.g. `npm run lint`
- **Dev server:** e.g. `npm run dev`

## Folder map
- `docs/00-idea.md`      - raw idea (the napkin sketch)
- `docs/01-prd.md`       - PRD; every requirement has a REQ-ID
- `docs/02-design.md`    - design + REQ-ID → component traceability table
- `docs/03-wireframe/`   - navigable HTML wireframe; elements carry data-req="REQ-00X"
- `docs/04-testplan.md`  - test cases; each TC-### maps to a REQ-ID
- `docs/plans/REQ-00X.md` - the approved implementation plan per REQ (what the loop enforces)
- `src/`                 - implementation
- `tests/`               - automated tests
- `.github/workflows/ci.yml` - full regression suite on every PR and every push to main

## ID scheme
- **REQ-00X** - a requirement. Born in the PRD. Permanent, never renumbered.
  Becomes its own GitHub Issue → branch → PR (one Issue per REQ-ID).
- **TC-###** - a test case. Always references exactly one REQ-ID.
- **BUG-00X** - a defect. Must get its own FAILING test before any fix.
- **#N** - the GitHub Issue number.

**One Issue per REQ-ID.**
Each REQ-ID gets its own GitHub Issue, so each branch and PR finishes exactly one requirement and its PR always uses `Closes #N` (the Issue auto-closes on merge).
Do not group REQ-IDs into a shared Issue unless two are genuinely inseparable (they share the same code change and cannot be tested apart).
**The REQ-ID number is NOT the Issue number.**
GitHub numbers Issues in creation order, so REQ-002 will not reliably be #2 (a bug Issue or an out-of-order creation shifts the numbers).
Before writing a PR, look up the Issue with `gh issue list --search "REQ-00X"` and use that number as `#N`.
Bug Issues are 1:1 too, so a bug fix uses `Fixes #N`.
Rare exception: if you ever do group two inseparable REQ-IDs in one Issue, a PR that finishes only one of them uses `Refs #N` (Issue stays open) and you close it when its last REQ merges.

The spine this enforces:
`Idea → REQ-ID → Design row → Wireframe tag → TC-ID → Issue # → branch → PR → merge`

## Loop rules
1. Every artifact is a reviewable diff. Docs are committed too, no exceptions.
2. Always tag commits with the REQ/BUG-ID and its Issue: `feat(REQ-00X): ... (#N)`
   (the number after `#` is the Issue that holds the REQ; look it up with
   `gh issue list --search "REQ-00X"`, do not assume it equals the REQ number).
3. Build loop exit condition = green test suite, not "it looks right."
4. Bug loop: reproduce END-TO-END first, then write a FAILING test, then localise, then fix.
   Reproduce the bug as closely as possible to how a real user experiences it.
   An E2E reproduction is what proves you found the real problem rather than a symptom.
   A bug with no failing test is hidden, not fixed.
5. Branch names: `feat/REQ-00X-short-name`, `fix/BUG-00X`.
6. Documentation conventions are binding: a README per directory, a header per file,
   and a doc block per function. See "Documentation conventions" below.
7. PR checklist: tests pass · docs regenerated · traceability intact.
8. Traceability must hold both ways: no REQ-ID without a test/design row,
   no component or scope without a REQ-ID.
9. Never weaken, skip, or delete a test to make a suite go green. Fix the cause.
10. Never work directly on `main`. Always a branch.

## Documentation conventions
Every directory, file, and function carries documentation that travels with the code and is committed as part of the same diff.
These are not optional polish; a change that omits them is incomplete.

- Every new directory has a `README.md` saying what the directory is for, in a sentence or two.
  Creating a directory without a README is unfinished work.
- Every source file starts with a top comment block: what the file does, plus the REQ-IDs it serves.
  This is the file header referenced in Loop rule 6.
- Every function carries a comment block stating three things: what it does, what it calls, and what calls it.
  Write callers and callees as `function_name:file_name:directory_name` so a reader can locate each one without searching.
- Keep the "what it does" and "what it calls" lines true at all times; they are cheap to maintain.
  The "called by" list is a back-reference and rots the moment a caller is renamed or moved.
  Fix it whenever you touch a caller, and prefer generating it from a tool (ctags / grep / an AST pass) over hand-maintaining it.
- Enforce all of the above through the test suite, not through review alone.
  Wire a doc-lint into the test command so a missing README, file header, or function block turns the suite RED.
  The loop's exit condition is a green suite, so a rule with no test behind it is a suggestion the loop can ignore.

## Test strategy
- Write tests FIRST, from the TC-### rows in `docs/04-testplan.md`.
  Never invent coverage that isn't traceable to a test case that's traceable to a REQ-ID.
- **Always run the FULL suite, never filtered to just the new tests.**
  A filtered run proves the new REQ works.
  Only the full run proves the earlier REQ-IDs still work.
- CI is the mechanical gate: `.github/workflows/ci.yml` runs the full suite on every
  pull request and every push to `main`.
  With branch protection on, an un-green PR cannot merge.
  The gate must never depend on someone remembering to check.
- A flaky test is treated as failing. Fix it or delete it, never retry around it.

## After every merged PR (non-negotiable)
1. `git checkout main && git pull`, then run the full suite locally.
   Red on main = revert first, diagnose second (`git revert -m 1 <merge-sha>`).
2. Confirm CI is green on `main`, not just on the branch that merged.
3. Re-run the traceability audit: every REQ-ID must still have at least one PASSING test.
   A REQ-ID drifting to zero passing tests is a regression in the SPEC.
   It is invisible to the test runner, and it is what makes traceability real
   rather than decorative.
4. Regenerate docs affected by the change (file headers, design rows).
5. Only when all four are clean, pick up the next Issue.

> The build loop's exit condition is a green branch.
> The project's exit condition is a green `main` with every REQ-ID still covered.
> These are different checks.

## Looping (bounded Ralph)
- Loop INSIDE an Issue; gate BETWEEN Issues. Plan review and PR review stay human.
- The loop's exit condition is a green test suite, never the agent's own judgement.
- Fresh context every iteration; state lives in the codebase, git, and PROMPT.md.
- The approved plan must be persisted to `docs/plans/REQ-00X.md` before looping; the loop
  injects it every pass so fresh contexts build the reviewed approach, not their own.
- Always cap iterations. Hitting the cap means the PLAN was wrong, so re-plan (update the
  plan file), don't just re-run.
- The loop runner refuses to run on `main`, and refuses without an approved plan file.

## Engineering standards
- When making technical decisions, do not give much weight to development cost.
  Prefer quality, simplicity, robustness, scalability, and long-term maintainability.
- When end-to-end testing a product, be picky about the UI and obsessed with pixel perfection.
- If something clearly looks off, even if unrelated to the current task, get it fixed
  along with your changes.
- Apply the same standard to engineering hygiene: fix lint issues, test failures, and
  test flakiness when you see them, even if you did not cause them.

## Writing and commit conventions
- Never use the em dash. Use a plain dash instead.
- When writing commit messages, NEVER auto-add your agent name as co-author.
- Never manually modify CHANGELOG.md or any file marked as auto-generated.
- When writing or substantially editing long Markdown files, put each full sentence on
  its own line.
  Preserve normal Markdown structure, but avoid wrapping multiple sentences onto one
  physical line.

## Model policy
Opus thinks (PRD, design, plan, bug localisation) · Sonnet builds (wireframe,
implementation, tests, fixes) · Haiku fetches (scaffolding, commits, PR bodies,
PRD→Issues). Switch with `/model opus|sonnet|haiku`.

<!-- Enrich this file with /init once code exists. -->
