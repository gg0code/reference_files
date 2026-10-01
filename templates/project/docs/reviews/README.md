# docs/reviews

One review report per requirement or bug, named `REQ-00X.md` or `BUG-00X.md`.
Each is written by the read-only reviewer agent (`.claude/agents/reviewer.md`) and saved verbatim by the builder.
The first line is the verdict: `Verdict: APPROVE - round N - <date>` or `Verdict: CHANGES REQUESTED - round N - <date>`.
A new round overwrites the file; git history keeps every earlier round.
