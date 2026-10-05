---
description: Set what to build now: phases and/or REQ-IDs
argument-hint: <P1 P2 REQ-017 ... | all>
---
Do the `scope` command in CLAUDE.md section 9 with: $ARGUMENTS
On main, run `bash scripts/start.sh scope $ARGUMENTS`. Before that, warn me if a REQ in the new scope depends on a REQ outside it (docs/01-prd.md section 4a).
