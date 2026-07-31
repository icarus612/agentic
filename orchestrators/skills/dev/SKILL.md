---
name: dev
description: DEPRECATED alias — the dev workflow is now the dae orchestrator. /dev routes straight to /dae with the same arguments. This stub exists for one release of muscle memory, then disappears.
domain: universal
rules: []
model: haiku
model-fallback: [gemini-pro]
---

# dev (deprecated alias)

This entry point was renamed: invoke the **`dae`** skill instead, passing every flag and argument through unchanged (`/dev --worktree resume x` → `/dae --worktree resume x`). Do that now — read and follow the `dae` skill — and tell the user once, briefly, that `/dev` is now `/dae`.
