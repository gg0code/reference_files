#!/usr/bin/env bash
# doclint.sh - enforce the documentation conventions in docs/RULES.md section 3.   VERSION: v2
#
#   bash scripts/doclint.sh               lint src/ and tests/ (or DOCLINT_PATHS="src tests lib")
#   bash scripts/doclint.sh --changed     only files and folders changed on this branch vs main
#   bash scripts/doclint.sh src/app       lint just these paths
#
# Rules (exit 1 on any violation, so it can sit in front of the test command):
#   D1  every directory has a README.md
#   D2  every source file has a header in its first 25 lines containing "REQ-IDs:"
#   D3  every function has a doc block right above it (JS/TS/Go/Rust/shell) or a docstring (Python).
#       In source code the block must contain "Calls:" ("Calls: none" for leaf functions).
#       "Called by:" is optional (it goes stale; use graphify or Find References instead).
#       In test files (tests/ or test_* / *_test / *.test.* / *.spec.*) any doc block is enough.
#   D4  no source file over DOCLINT_MAX_LINES lines (default 300; RULES.md aims for about 200). Tests exempt.
#   D5  Python layers: a service.py (or services/*.py) imports no web, template or database library,
#       so business rules stay plain functions (RULES.md section 2, 02-architecture.md section 3).
# Supported: Python (AST), JavaScript/TypeScript, Go, Rust, shell (pattern based).
# Other file types get D1 and D2 only. Skip files with patterns in .doclintignore (one glob per line).
# Needs python3.
set -uo pipefail

case "${1:-}" in -h|--help) sed -n '2,21p' "$0"; exit 0 ;; esac
command -v python3 >/dev/null 2>&1 || { echo "ERROR : doclint needs python3" >&2; exit 2; }
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 2

CHANGED=""
if [ "${1:-}" = "--changed" ]; then
  shift
  BASE="$(git merge-base origin/main HEAD 2>/dev/null || git merge-base main HEAD 2>/dev/null || true)"
  if [ -n "$BASE" ]; then
    CHANGED="$( { git diff --name-only --diff-filter=ACMR "$BASE"; git ls-files --others --exclude-standard; } | sort -u)"
  fi
  [ -n "$CHANGED" ] || { echo "doclint: no changed files"; exit 0; }
fi
PATHS="${*:-${DOCLINT_PATHS:-src tests}}"

DOCLINT_CHANGED="$CHANGED" DOCLINT_PATHS_ARG="$PATHS" python3 - <<'PY'
import ast, fnmatch, os, re, sys

paths = [p for p in os.environ["DOCLINT_PATHS_ARG"].split() if os.path.exists(p)]
changed = [c for c in os.environ.get("DOCLINT_CHANGED", "").splitlines() if c]
ignore = []
if os.path.exists(".doclintignore"):
    ignore = [l.strip() for l in open(".doclintignore") if l.strip() and not l.startswith("#")]
SKIP_DIRS = {"__pycache__", "node_modules", ".pytest_cache", "dist", "build", "coverage", ".venv", "venv", "target", ".git"}
SRC_EXT = {".py", ".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs", ".go", ".rs", ".sh", ".java", ".kt", ".rb", ".php", ".cs", ".swift", ".c", ".h", ".cpp", ".hpp"}
problems = []

def ignored(p):
    return any(fnmatch.fnmatch(p, g) or fnmatch.fnmatch(os.path.basename(p), g) for g in ignore)

def is_test(p):
    b = os.path.basename(p)
    return p.startswith("tests/") or "/tests/" in p or b.startswith("test_") or re.search(r"(_test|\.test|\.spec)\.[a-z]+$", b) is not None

MAX_LINES = int(os.environ.get("DOCLINT_MAX_LINES", "300"))
# D5: libraries a business-rules module must not import (web, templates, database, HTTP clients)
LAYER_BANNED = set(os.environ.get("DOCLINT_SERVICE_BANNED",
    "fastapi starlette flask django jinja2 sqlalchemy sqlmodel alembic psycopg psycopg2 asyncpg sqlite3 pymongo redis requests httpx").split())

def need_calls(text):
    return re.search(r"(?im)^\s*(\*|//|///|#)?\s*calls:", text) is not None

def is_service(p):
    return p.endswith("/service.py") or p == "service.py" or "/services/" in p

def add(p, line, rule, msg):
    problems.append(f"{p}:{line}: {rule} {msg}")

# ----- collect files and dirs -----
files, dirs = [], set()
for root in paths:
    if os.path.isfile(root):
        files.append(root); continue
    for d, subdirs, names in os.walk(root):
        subdirs[:] = sorted(s for s in subdirs if s not in SKIP_DIRS and not s.startswith("."))
        dirs.add(d)
        for n in sorted(names):
            files.append(os.path.join(d, n))
files = [os.path.normpath(f) for f in files]
dirs = {os.path.normpath(d) for d in dirs}
if changed:
    cset = {os.path.normpath(c) for c in changed}
    files = [f for f in files if f in cset]
    dirs = {d for d in dirs if any(c == d or c.startswith(d + "/") for c in cset) and any(os.path.dirname(c) == d for c in cset)}

# ----- D1 README per directory -----
for d in sorted(dirs):
    if ignored(d):
        continue
    if not any(n.lower().startswith("readme") for n in os.listdir(d)):
        add(d, 0, "D1", "directory has no README.md")

# ----- D2 header, D3 function docs -----
JS_FN = re.compile(r"^\s*(export\s+)?(default\s+)?(async\s+)?function\s*\*?\s*([A-Za-z_$][\w$]*)\s*\(|^\s*(export\s+)?(const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*(async\s+)?(\([^)]*\)|[A-Za-z_$][\w$]*)\s*(:\s*[^=]+)?=>")
GO_FN = re.compile(r"^func\s+(\([^)]*\)\s*)?([A-Za-z_]\w*)\s*\(")
RS_FN = re.compile(r"^\s*(pub(\([^)]*\))?\s+)?(async\s+)?(unsafe\s+)?fn\s+([A-Za-z_]\w*)")
SH_FN = re.compile(r"^\s*(function\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{?")

def block_above(lines, i, style):
    """Return the comment block text directly above line i (0-based), or None."""
    j = i - 1
    if j < 0 or lines[j].strip() == "":
        return None                                # the block must touch the function line
    if style == "js":
        if j < 0 or not lines[j].strip().endswith("*/"):
            # allow decorators / export lines between? keep strict: block must touch the function
            return None
        k = j
        while k >= 0 and "/**" not in lines[k] and "/*" not in lines[k]:
            k -= 1
        return "\n".join(lines[max(k, 0):j + 1]) if k >= 0 else None
    prefix = {"go": "//", "rs": "///", "sh": "#"}[style]
    k = j
    while k >= 0 and lines[k].lstrip().startswith(prefix):
        k -= 1
    return "\n".join(lines[k + 1:j + 1]) if k < j else None

for f in files:
    ext = os.path.splitext(f)[1]
    if ext not in SRC_EXT or ignored(f):
        continue
    try:
        text = open(f, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    if not text.strip():
        continue                                   # empty files (e.g. __init__.py) are fine
    lines = text.splitlines()
    if not any("REQ-IDs:" in l for l in lines[:25]):
        add(f, 1, "D2", "file header missing a 'REQ-IDs:' line in the first 25 lines")
    test = is_test(f)
    if not test and len(lines) > MAX_LINES:
        add(f, MAX_LINES + 1, "D4", f"file has {len(lines)} lines (limit {MAX_LINES}); split it by responsibility")
    if ext == ".py":
        try:
            tree = ast.parse(text)
        except SyntaxError as e:
            add(f, e.lineno or 1, "D3", "cannot parse (syntax error)"); continue
        if is_service(f) and not test:
            for node in ast.walk(tree):
                mods = []
                if isinstance(node, ast.Import):
                    mods = [a.name for a in node.names]
                elif isinstance(node, ast.ImportFrom) and node.module and node.level == 0:
                    mods = [node.module]
                for m in mods:
                    if m.split(".")[0] in LAYER_BANNED:
                        add(f, node.lineno, "D5", f"service layer imports '{m}': move web, template and database code to routes.py / repository.py")
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                if node.name.startswith("__") and node.name.endswith("__") and node.name != "__init__":
                    continue
                doc = ast.get_docstring(node)
                if not doc:
                    add(f, node.lineno, "D3", f"function '{node.name}' has no docstring")
                elif not test and not need_calls(doc):
                    add(f, node.lineno, "D3", f"docstring of '{node.name}' needs a 'Calls:' line ('Calls: none' if it calls nothing of ours)")
        continue
    style, rx, name_group = None, None, None
    if ext in {".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs"}: style, rx = "js", JS_FN
    elif ext == ".go": style, rx = "go", GO_FN
    elif ext == ".rs": style, rx = "rs", RS_FN
    elif ext == ".sh": style, rx = "sh", SH_FN
    if not style:
        continue
    for i, line in enumerate(lines):
        m = rx.match(line)
        if not m:
            continue
        if style == "sh" and not re.search(r"\(\)\s*\{?\s*$|\(\)\s*\{", line):
            continue
        name = next((g for g in reversed(m.groups()) if g and re.fullmatch(r"[A-Za-z_$][\w$]*", g)
                     and g not in {"export", "default", "async", "function", "const", "let", "var", "pub", "unsafe"}), "?")
        block = block_above(lines, i, style)
        if not block:
            add(f, i + 1, "D3", f"function '{name}' has no doc block directly above it")
        elif not test and not need_calls(block):
            add(f, i + 1, "D3", f"doc block of '{name}' needs a 'Calls:' line ('Calls: none' if it calls nothing of ours)")

for p in problems:
    print(p)
n = len(problems)
scope = "changed files" if changed else " ".join(paths) or "(no paths found)"
if n:
    print(f"\ndoclint: {n} problem(s) in {scope}. Conventions: docs/RULES.md section 3.")
    sys.exit(1)
print(f"doclint: OK ({len(files)} files, {len(dirs)} folders in {scope})")
PY
