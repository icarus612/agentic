---
name: sync-status
description: DEPRECATED alias — reconciliation runs are now the dae orchestrator's sync workflow. /sync-status routes straight to /dae --type sync. This stub exists for one release of muscle memory, then disappears.
domain: universal
rules: []
model: haiku
model-fallback: [gemini-pro]
---

# sync-status (deprecated alias)

This entry point was consolidated: invoke the **`dae`** skill with `--type sync`, passing any other arguments (plan, ticket, `--ref` shipped-work reference) through unchanged. Do that now — read and follow the `dae` skill — and tell the user once, briefly, that `/sync-status` is now `/dae --type sync`.
