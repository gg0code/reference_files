# docs/tests

One table per REQ or BUG on a standard or strict plan, named `REQ-00X.md` or `BUG-00X.md`, written by `/tests`.
Each row says, in one plain sentence, what a test checks, so the user can read the tests before they are locked.
The user reads it, then runs `bash scripts/lock_tests.sh`; after that the tests do not change (CLAUDE.md section 5).
A test the builder believes is wrong goes under `## Disputed` at the end of the table, never into the test file.
