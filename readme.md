# Spec-Driven Build Kit - Adoption Guide

This kit is a set of reusable reference files for spec-driven, fully-traceable development
with Claude Code. This README explains what each file is, whether you have to edit it for
your project, and exactly what to change.

## The short answer: only two files need editing

| File | Adopt by | Per-project editing? |
|---|---|---|
| `CLAUDE.md` | Edit, then commit at repo root | **Yes** - fill in 2 blocks |
| `ci.yaml` | Edit, then save as `.github/workflows/ci.yml` | **Yes** - pick your stack |
| `scaffold.sh` | Run once to create the project | No - takes the app name as an argument |
| `loop.sh` | Run per requirement | No - auto-detects your stack |
| `runbook.md` | Follow it | No - substitute placeholders in the prompts you paste |
| `spec-driven-build-setup-guide.md` | Follow it (one-time machine setup) | No |

Everything is designed to be project-agnostic. Where a value genuinely differs per project,
it is either a `FILL IN` block (CLAUDE.md), a clearly marked choose-one block (ci.yaml), a
command-line argument (scaffold.sh), or auto-detected (loop.sh).

---

## Recommended order for a new project

1. Do the one-time machine setup from `spec-driven-build-setup-guide.md`
   (install WezTerm, tmux, git, gh, Node/Python, Claude Code, RTK; set git identity; `gh auth login`).
   This is once per machine, not once per project.
2. `bash scaffold.sh <appname>` from your projects root - creates the folder, git repo,
   GitHub repo, doc tree, and first commit.
3. Replace the placeholder `CLAUDE.md` with this kit's `CLAUDE.md`, **fill in the 2 blocks**, commit.
4. Add `ci.yaml` as `.github/workflows/ci.yml`, **choose your stack block**, commit.
5. Follow `runbook.md` for the spec chain (Phase 1) and the build/bug loops (Phases 2-3),
   using `loop.sh` to automate the inner implement-test grind.

---

## File-by-file

### CLAUDE.md - EDIT (2 blocks), then commit at repo root

Claude Code reads this automatically at the start of every session; it is the project's
"constitution". Everything is project-agnostic **except** the two blocks marked `FILL IN`:

- **`## Project`** - one or two sentences on what the product is, its current state, and
  any hard constraints.
- **`## Stack and commands`** - the real commands for your stack (install, run full tests,
  run a single test, lint, dev server). Wrong values here make Claude run wrong commands, so
  this is the single most important edit.

Delete the top adoption comment once filled in. Leave everything else as-is - the ID scheme,
loop rules, test strategy, and post-merge checklist are meant to be identical across projects.

### ci.yaml - EDIT (choose stack), save as `.github/workflows/ci.yml`

This makes "tests pass" a mechanical merge gate. It ships with **Node active by default** and
commented blocks for **Python, Go, and Rust**. To adopt:

1. Uncomment the block for your stack; comment out (or delete) the Node block if that is not you.
2. Save the file at `.github/workflows/ci.yml` in your repo (note: `.yml`, and inside
   `.github/workflows/`).
3. Commit and push. After CI runs once, turn on branch protection so an un-green PR cannot merge
   (the command is in `runbook.md`, Phase 2c).

> Why this one needs a human choice: a single workflow cannot install and run every language's
> test suite sensibly. Picking one block is the only per-project decision.

### scaffold.sh - RUN as-is (no editing)

Creates a new project end to end: folder, `git init`, doc scaffold, first commit, private
GitHub repo, and push - in the order that avoids the `src refspec main does not match any` error.

- **Prerequisite, once per machine** (not per project): set your git identity and authenticate gh
  ```bash
  git config --global user.name  "Your Name"
  git config --global user.email "you@example.com"
  git config --global init.defaultBranch main
  gh auth login
  ```
- **Run** from your projects root (not inside a project folder):
  ```bash
  bash scaffold.sh <appname>      # defaults to "myapp" if omitted
  ```

The project name is an **argument**, so you never edit the script.

### loop.sh - RUN as-is (no editing)

The bounded "Ralph" loop that automates the implement -> test -> feed-back-failure grind for
one requirement, exiting on a green suite. It **auto-detects your stack** (package.json ->
`npm test`, Python files -> `pytest`, Cargo.toml -> `cargo test`, go.mod -> `go test ./...`).

- **Run** on a feature branch, after you have saved the approved plan to `docs/plans/<REQ>.md`:
  ```bash
  bash loop.sh <issue#> REQ-00X          # e.g. bash loop.sh 1 REQ-001
  ```
- **Override detection only if needed** (unusual stacks or custom runners):
  ```bash
  TEST_CMD="pytest -q" bash loop.sh 1 REQ-001
  ```
- **Override the plan path only if needed:**
  ```bash
  PLAN_FILE=path/to/plan.md bash loop.sh 1 REQ-001
  ```

No file editing - everything variable is an argument or an environment override.

### runbook.md - FOLLOW (no editing)

The step-by-step playbook: Phase 0 setup, Phase 1 spec chain (idea -> PRD -> design ->
wireframe -> test plan -> Issues), Phase 2 build loop, Phase 3 bug loop. You do not edit it;
you **substitute placeholders in the prompts you paste** into Claude:

- `<your app>` -> your project name
- `REQ-00X` -> the real requirement ID (REQ-001, REQ-002, ...)
- `#N` -> the GitHub Issue number (look it up with `gh issue list --search "REQ-00X"`)
- `<short-name>` -> a short slug for the branch/PR
- `BUG-00X` -> the real bug ID

### spec-driven-build-setup-guide.md - FOLLOW (one-time machine setup)

Chronological install-and-setup guide with commands for macOS, native Windows, and Windows via
WSL. Use it once per machine to get all the tools in place before your first project. Nothing to edit.

---

## The policy these files share

Every file assumes **one GitHub Issue per REQ-ID**. Because each branch and PR then finishes
exactly one requirement, its PR always uses `Closes #N` and the Issue auto-closes on merge -
no "does this complete the Issue?" bookkeeping. Group two REQ-IDs into one Issue only if they
are genuinely inseparable (share the same code change and cannot be tested apart); in that rare
case a PR that finishes just one of them uses `Refs #N` instead.

The spine, on one line:

```
Idea -> REQ-ID -> Design row -> Wireframe tag -> TC-ID -> Issue # -> branch -> PR -> merge
Bug  -> BUG-ID -> failing test -> Issue # -> branch -> PR -> merge
```
