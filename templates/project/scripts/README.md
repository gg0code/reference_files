# scripts

Project tooling copied from the reference kit by scaffold.sh.
None of them needs a REQ-ID or Issue number: they read the ID from the branch name and the Issue number from `docs/TASKS.md`.
`start.sh` starts the next REQ (or `start.sh bug "symptom"`), `start.sh status` shows where you are and the next action, and `start.sh check` verifies the kit is installed and active.
`loop.sh` runs the bounded implement-and-test loop for the current branch.
`pr.sh` opens the PR once the reviewer approves; `pr.sh merge` merges after your review and runs the after-merge checks.
`doclint.sh` enforces the documentation conventions in docs/RULES.md section 3; `--changed` checks only this branch.
`req_status.sh` prints the REQ-ID ledger and, with `--strict`, fails if a merged REQ has no tests.
`autopilot.sh` (optional) runs several REQs unattended at the level you choose; see its `--help`.
Update them by copying newer versions from the kit, not by editing them here.
