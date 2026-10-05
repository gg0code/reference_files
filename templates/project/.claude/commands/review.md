---
description: Run the read-only reviewer agent on this branch
argument-hint: [ID]
---
Do the `review` command in CLAUDE.md section 9 and section 5a for ID `$ARGUMENTS` (empty = the current branch's ID): delegate to the `reviewer` subagent with the ID, the Issue number and the plan path, save its report VERBATIM to `docs/reviews/<ID>.md`, commit it, then show me the verdict and the Critical and Major findings.
