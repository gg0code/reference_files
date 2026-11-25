---
description: Start or plan the next requirement inside the build scope
argument-hint: [REQ-ID]
---
Do the `next` command in CLAUDE.md section 9.
If the current branch is main: run `bash scripts/start.sh $ARGUMENTS` first (no argument = next REQ inside the build scope).
Then draft `docs/plans/<ID>.md` from `docs/plans/_TEMPLATE.md` for the current branch's ID, with line 1 `Status: DRAFT`, and wait for my approval.
Propose the `Risk:` tier with a one-line reason, using the rules in the template: strict if it touches auth, payments, deleting data, a public API or routes, `shared/`, migrations, or adds a dependency; light only for copy, styling or a refactor with no behaviour change; otherwise standard.
When unsure between two tiers, propose the stricter one. Say in your reply which tier you chose and why, and that standard and strict need `/tests` and the lock before the loop.
