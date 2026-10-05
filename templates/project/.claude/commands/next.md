---
description: Start or plan the next requirement inside the build scope
argument-hint: [REQ-ID]
---
Do the `next` command in CLAUDE.md section 9.
If the current branch is main: run `bash scripts/start.sh $ARGUMENTS` first (no argument = next REQ inside the build scope).
Then draft `docs/plans/<ID>.md` from `docs/plans/_TEMPLATE.md` for the current branch's ID, with line 1 `Status: DRAFT`, and wait for my approval.
