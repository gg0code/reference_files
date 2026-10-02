# reviews

One file per REQ or BUG: `<ID>.md`, written by the reviewer agent and saved verbatim by `review`.
Line 1 is the verdict (`Verdict: APPROVE - round N - <date>` or `Verdict: CHANGES REQUESTED - round N - <date>`); scripts read it.
After APPROVE, `explain` appends a `## Walkthrough` section for the human reader.
Plan reviews from autopilot level 2 are saved as `<ID>.plan.md`.
