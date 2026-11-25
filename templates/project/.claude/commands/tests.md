---
description: Write the failing tests for a standard or strict plan, from the spec only, before any code
argument-hint: <ID>
---
Do the `tests` command in CLAUDE.md section 9 for ID `$ARGUMENTS` (empty = the current branch's ID).

1. Check first, and stop with the reason if any fails:
   - you are on the `feat/` or `fix/` branch for this ID;
   - `docs/plans/<ID>.md` is `Status: APPROVED` and committed;
   - its `Risk:` line is standard or strict (no line = standard). Light plans skip this command: say so and stop;
   - the plan has no lock line yet (`bash scripts/integrity.sh --lock-state` prints nothing). Locked tests are the user's to unlock.
2. Read only the spec: the plan, the REQ in `docs/01-prd.md` and its TC rows and edge cases in `docs/04-testplan.md`.
   For a BUG, also the Issue's steps to reproduce and the plan's repro steps: each test reproduces the bug as a user meets it.
   Do not read the code in `src/` to decide what a test expects: the spec decides.
3. Write the tests, one or more per TC row and edge case, in the test files the plan names.
   - Never create or change anything under `src/`, and no stubs. Test through the public seam (HTTP routes, the
     service functions the plan names). Where the thing does not exist yet, import it inside the test and turn the
     ImportError into a failure: `pytest.fail("not implemented: <module>.<name>")` (other stacks: the same idea).
   - Write enough tests to meet the coverage floor (`service.py` at 85% or more, COV_MIN) for the modules the plan
     will create or change. After the lock nobody adds tests, so a gap found later stops the loop.
   - Each test carries a doc block naming its TC-ID and REQ-ID (RULES.md section 3). No skip, xfail or only markers.
   - Give each test file a name no other test file has (`tests/features/<area>/test_<area>_service.py`, not a second
     `test_service.py`): the test folders have no `__init__.py`, so pytest stops on two files with the same name.
     After the lock a wrong name can only be fixed by the user unlocking, so get it right now.
4. Run the new tests (Python: `uv run pytest <files> -q -rfE`). Every new test must FAIL, and fail on an assertion or
   "not implemented", never on a syntax, import, collection or fixture error. If one errors, fix the test, not `src/`.
   Also run `bash scripts/doclint.sh tests` and the linter on the new files; both must be clean.
5. Write `docs/tests/<ID>.md`:
   ```
   # Tests for <ID> - <title>
   Plan: docs/plans/<ID>.md (Risk: <tier>)
   | TC-ID | Test name | What it checks | Fails now |
   |---|---|---|---|
   | TC-012 | test_title_required | Saving a note with an empty title shows "Give the note a title." | yes: AssertionError (status 404) |
   ```
   "What it checks" is one plain sentence a non-programmer can follow. "Fails now" quotes the real failure.
6. Commit the tests and the table alone (nothing else staged): `test(<ID>): failing tests from spec (#N)`.
7. Stop. Ask the user to read `docs/tests/<ID>.md` (and the tests, if they want) and, when happy, to run
   `bash scripts/lock_tests.sh` in the git pane. Never run `lock_tests.sh` yourself; the hooks block it.
