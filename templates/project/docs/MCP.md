# MCP tools: setup check and usage rules

Kit file (v2.8). Loaded by CLAUDE.md section 0 through `@docs/MCP.md`. Not a spec doc: no Status line, not tailored by `setup`.
Servers are defined in `.mcp.json` at the repo root: chrome-devtools, playwright, graphify (all free, run locally).

## 1. Setup check (once per interactive session)

**Skip this section entirely** when you are not in an interactive session with the user:
a `claude -p` run from `scripts/loop.sh` or `scripts/autopilot.sh` (their prompt says "NON-INTERACTIVE RUN"),
or when you are the reviewer agent or any other subagent.

Otherwise, before the first task of the session, and in the same message as the TEMPLATE/DRAFT setup check:

1. Look at your available tools:
   - chrome-devtools connected: tools named `mcp__chrome-devtools__*` exist
   - playwright connected: tools named `mcp__playwright__*` exist
   - graphify connected: tools named `mcp__graphify__*` exist
2. Only if one is missing, run:
   ```bash
   node --version                 # needs v18 or newer (chrome-devtools, playwright)
   uv --version                   # needed for graphify
   ls graphify-out/graph.json     # graphify's map of this project
   ```
3. If everything is connected, say nothing about MCP.
   If something is missing, show one short list (✅ / ❌ per server), then ONLY the fix commands
   for what is missing, from the table below. Then carry on with the user's request.
   If the user says "skip" or "later", do not mention MCP again this session.

| Problem | Fix (tell the user to run it in the git pane unless noted) |
|---|---|
| Node.js missing or older than v18 | Install the LTS version from https://nodejs.org, then reopen the terminal |
| Servers listed but not connected | claude pane: `/mcp`, approve the project servers (first run in a repo asks once) |
| `chrome-devtools` not in `/mcp` at all | `claude mcp add --scope project chrome-devtools -- npx -y chrome-devtools-mcp@latest` |
| `playwright` not in `/mcp` at all | `claude mcp add --scope project playwright -- npx @playwright/mcp@latest` |
| `uv` missing | macOS/Linux/WSL: `curl -LsSf https://astral.sh/uv/install.sh \| sh` · Windows PowerShell: `powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 \| iex"` |
| `/graphify` command missing | `uv tool install "graphifyy[mcp]"` then `graphify install`, then restart claude |
| `graphify-out/graph.json` missing | claude pane: `/graphify .` to build the project map, then restart claude |

When the user types `mcp`, run this check again right away, even if they said "skip" earlier.
After any fix the user restarts claude and checks with `/mcp`.
`bash scripts/start.sh check` (section 5) runs the same checks from the git pane.

Graphify is low priority while `src/` holds fewer than about 20 source files: mention it once as optional, never as a blocker.

## 2. When to use each server

- **chrome-devtools**: after changing UI or frontend code, open the running app (frontend pane dev server),
  read the console and network requests, and fix errors before you say the task is done.
  Use it for "why is this broken / slow" questions (performance trace).
- **playwright**: drive full user flows from the test plan (signup, login, forms, checkout).
  When a flow works by hand, offer to turn it into a test file under `tests/` carrying its REQ-ID and TC-ID,
  so it becomes part of the suite. A Playwright session is evidence, not a test: only tests in the suite count.
- **graphify**: before editing a function, file or API that other code may depend on, ask graphify for its
  callers and impact; prefer it to reading many files to learn how parts connect.
  Results describe the indexed graph only: an empty "callers" answer is not proof of no callers, confirm with Grep.
  After a merge that changed many files, suggest `/graphify . --update`.

Never claim a frontend change works without checking it in the browser when chrome-devtools or playwright is connected.
MCP tools never replace the kit's gates: the full test suite, doclint, the reviewer and CI still decide.

## 3. Optional paid servers (suggest only when the user asks for web research or scraping)

- Firecrawl: `claude mcp add --scope local firecrawl -e FIRECRAWL_API_KEY=<key> -- npx -y firecrawl-mcp`
- Perplexity: `claude mcp add --scope local perplexity -e PERPLEXITY_API_KEY=<key> -- npx -y @perplexity-ai/mcp-server`

Never write an API key into a committed file (`.mcp.json`, CLAUDE.md, docs). Use `--scope local` as above: it keeps the key in your own config. `--scope project` would write it into `.mcp.json`.
