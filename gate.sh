#!/usr/bin/env bash
# gate.sh - the one quality gate every change must pass.   VERSION: v1
#
#   bash scripts/gate.sh           fast gate: docs, lint, format, types, tests (+ service coverage for Python)
#   bash scripts/gate.sh --full    also dependency audit and secrets scan (pr.sh merge, CI, release)
#
# loop.sh, autopilot.sh, pr.sh merge and CI all run this script, so the rules in docs/RULES.md
# that have a tool behind them cannot be skipped by the loop. Every step runs even when an
# earlier one fails, so one run shows every problem. Exit 1 if any step fails.
#
# Settings (environment):
#   TEST_CMD="..."        replace the detected test step (other steps still run); GATE_TEST_CMD wins if set
#   GATE_SKIP="types ..." skip named steps: doclint lint format types tests coverage audit secrets
#                         (record the reason in docs/MEMORY.md; the reviewer treats a skip as a finding)
#   COV_MIN=85            Python: minimum coverage of service.py files (the business rules)
# Stacks: Python (pyproject.toml), Node (package.json), Go (go.mod), Rust (Cargo.toml).
set -uo pipefail

case "${1:-}" in -h|--help) sed -n '2,19p' "$0"; exit 0 ;; esac
FULL=0; [ "${1:-}" = "--full" ] && FULL=1
case "${TEST_CMD:-}" in *gate.sh*) TEST_CMD="" ;; esac   # never call ourselves (loop/autopilot export TEST_CMD)
[ -n "${GATE_TEST_CMD:-}" ] && TEST_CMD="$GATE_TEST_CMD"   # set by loop.sh / autopilot.sh from a user TEST_CMD
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 2

FAILS=0; WARNS=0; SUMMARY=""
OUT="$(mktemp)"; trap 'rm -f "$OUT"' EXIT
skipped() { case " ${GATE_SKIP:-} " in *" $1 "*) return 0 ;; esac; return 1; }
row() { SUMMARY="${SUMMARY}$(printf '    %-6s %-9s %s' "$1" "$2" "$3")
"; }

# run_step <name> <description> <command...>: run, record PASS/FAIL, show the tail on failure
run_step() {
  local name="$1" desc="$2"; shift 2
  if skipped "$name"; then row SKIP "$name" "$desc (GATE_SKIP)"; WARNS=$((WARNS+1)); return 0; fi
  echo "==> $name: $desc"
  if "$@" >"$OUT" 2>&1; then
    row PASS "$name" "$desc"
  else
    tail -40 "$OUT" | sed 's/^/    | /'
    row FAIL "$name" "$desc"; FAILS=$((FAILS+1))
  fi
}
# missing <name> <tool> <how to install>: a required tool is absent -> FAIL (the gate never passes silently)
missing() { echo "==> $1: '$2' not found. Install: $3"; row FAIL "$1" "'$2' not installed ($3)"; FAILS=$((FAILS+1)); }
note()    { row WARN "$1" "$2"; WARNS=$((WARNS+1)); }
have()    { command -v "$1" >/dev/null 2>&1; }

STACK=""
if   [ -f pyproject.toml ] || [ -f requirements.txt ]; then STACK=python
elif [ -f package.json ]; then STACK=node
elif [ -f go.mod ];       then STACK=go
elif [ -f Cargo.toml ];   then STACK=rust
fi
echo "gate.sh v1 - stack: ${STACK:-unknown} - mode: $([ $FULL = 1 ] && echo full || echo fast)"

# ---------- 1. documentation conventions (all stacks) ----------
if [ -f scripts/doclint.sh ]; then run_step doclint "README per folder, headers, doc blocks, file size, layers" bash scripts/doclint.sh
else note doclint "scripts/doclint.sh missing"; fi

# ---------- 2. stack steps ----------
py_files() { find src -name '*.py' -not -path '*/.venv/*' 2>/dev/null | grep -q .; }
case "$STACK" in
  python)
    RUN=""; if have uv && [ -f pyproject.toml ]; then RUN="uv run --quiet"; fi
    pyhave() { if [ -n "$RUN" ]; then $RUN which "$1" >/dev/null 2>&1; else have "$1"; fi; }
    if [ -n "$RUN" ]; then PY="$RUN python"; else PY="python3"; fi
    if pyhave ruff; then
      run_step lint   "complexity, unused code, prints, bare except, security" $RUN ruff check --output-format concise .
      run_step format "formatting (ruff format --check)" $RUN ruff format --check .
    else missing lint ruff "uv add --dev ruff"; fi
    if skipped types; then row SKIP types "type check (GATE_SKIP)"; WARNS=$((WARNS+1))
    elif ! py_files; then note types "no .py files in src/ yet - type check skipped"
    elif pyhave mypy; then run_step types "type check (mypy, strict)" $RUN mypy src
    else missing types mypy "uv add --dev mypy"; fi
    if [ -n "${TEST_CMD:-}" ]; then run_step tests "tests: $TEST_CMD" bash -c "$TEST_CMD"
    elif pyhave pytest; then
      if skipped tests; then row SKIP tests "full test suite (GATE_SKIP)"; WARNS=$((WARNS+1))
      else
        echo "==> tests: full test suite (pytest)"
        COV=0; $PY -c "import pytest_cov" >/dev/null 2>&1 && COV=1
        if [ "$COV" = 1 ]; then $RUN pytest --cov=src --cov-report= >"$OUT" 2>&1; rc=$?
        else $RUN pytest >"$OUT" 2>&1; rc=$?; fi
        if [ "$rc" = 0 ]; then row PASS tests "full test suite"
        elif [ "$rc" = 5 ]; then note tests "no tests collected yet"
        else tail -40 "$OUT" | sed 's/^/    | /'; row FAIL tests "full test suite"; FAILS=$((FAILS+1)); fi
        svc="$(find src \( -name 'service.py' -o -path '*/services/*.py' \) 2>/dev/null | grep -v __init__ | paste -sd, -)"
        if skipped coverage; then row SKIP coverage "service coverage (GATE_SKIP)"; WARNS=$((WARNS+1))
        elif [ -z "$svc" ]; then note coverage "no service.py files yet - coverage floor not checked"
        elif [ "$COV" = 0 ]; then missing coverage pytest-cov "uv add --dev pytest-cov"
        elif [ "$rc" = 0 ]; then
          run_step coverage "service.py coverage >= ${COV_MIN:-85}%" $RUN coverage report --include="$svc" --fail-under="${COV_MIN:-85}"
        fi
      fi
    else missing tests pytest "uv add --dev pytest pytest-cov"; fi
    if [ $FULL = 1 ]; then
      if pyhave pip-audit; then run_step audit "dependency vulnerabilities (pip-audit)" $RUN pip-audit --skip-editable
      else missing audit pip-audit "uv add --dev pip-audit"; fi
    fi
    ;;
  node)
    run_step lint   "lint (npm run lint, if defined)"       npm run --if-present lint
    run_step types  "type check (npm run typecheck, if defined)" npm run --if-present typecheck
    if [ -n "${TEST_CMD:-}" ]; then run_step tests "tests: $TEST_CMD" bash -c "$TEST_CMD"
    else run_step tests "full test suite (npm test)" npm test; fi
    [ $FULL = 1 ] && run_step audit "dependency vulnerabilities (npm audit, high+)" npm audit --audit-level=high
    ;;
  go)
    run_step format "formatting (gofmt)" bash -c '[ -z "$(gofmt -l .)" ] || { gofmt -l .; exit 1; }'
    run_step lint   "lint (go vet)" go vet ./...
    if [ -n "${TEST_CMD:-}" ]; then run_step tests "tests: $TEST_CMD" bash -c "$TEST_CMD"
    else run_step tests "full test suite (go test)" go test ./...; fi
    if [ $FULL = 1 ]; then
      if have govulncheck; then run_step audit "dependency vulnerabilities (govulncheck)" govulncheck ./...
      else missing audit govulncheck "go install golang.org/x/vuln/cmd/govulncheck@latest"; fi
    fi
    ;;
  rust)
    run_step format "formatting (cargo fmt --check)" cargo fmt --check
    run_step lint   "lint (cargo clippy -D warnings)" cargo clippy --all-targets -- -D warnings
    if [ -n "${TEST_CMD:-}" ]; then run_step tests "tests: $TEST_CMD" bash -c "$TEST_CMD"
    else run_step tests "full test suite (cargo test)" cargo test; fi
    if [ $FULL = 1 ]; then
      if have cargo-audit; then run_step audit "dependency vulnerabilities (cargo audit)" cargo audit
      else missing audit cargo-audit "cargo install cargo-audit"; fi
    fi
    ;;
  *)
    if [ -n "${TEST_CMD:-}" ]; then run_step tests "tests: $TEST_CMD" bash -c "$TEST_CMD"
    else note tests "no pyproject.toml, package.json, go.mod or Cargo.toml: set TEST_CMD"; fi
    ;;
esac

# ---------- 3. secrets (full mode, all stacks) ----------
if [ $FULL = 1 ]; then
  if have gitleaks; then run_step secrets "secrets in code and history (gitleaks)" gitleaks detect --no-banner --redact
  elif [ -n "${CI:-}" ]; then note secrets "gitleaks not on PATH here; the CI workflow runs its own gitleaks step"
  else note secrets "gitleaks not installed locally (CI still scans). Install: https://github.com/gitleaks/gitleaks#installing"; fi
fi

echo ""
echo "  GATE SUMMARY"
printf '%s' "$SUMMARY"
if [ "$FAILS" -gt 0 ]; then
  echo "  RESULT: FAIL ($FAILS failed, $WARNS warning) - fix the causes; never weaken a check (RULES.md section 9)"
  exit 1
fi
echo "  RESULT: PASS ($WARNS warning)"
