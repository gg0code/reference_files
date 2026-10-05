# diagrams

Architecture, data-flow and sequence diagrams made with the Archify skill (optional; guide machine setup).
For each diagram, commit both files with the same name:
- `<name>.json`: the typed source Claude writes and edits. This is the real diagram; change it, never the HTML.
- `<name>.html`: the rendered, interactive diagram (open it in a browser). Regenerated from the JSON.

Standard names: `architecture` (components, 02-architecture.md section 1), `data-flow` (section 5),
`<ID>-flow` (the request path of one REQ or BUG, from `explain`).
Every arrow must match a real call or data path in the code; the reviewer checks this (RULES.md section 3).
