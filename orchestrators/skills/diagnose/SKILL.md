---
name: diagnose
description: DEPRECATED alias — root-cause investigation is now the dae orchestrator's diagnose workflow. /diagnose routes straight to /dae --type diagnose. This stub exists for one release of muscle memory, then disappears.
domain: universal
rules: []
model: haiku
model-fallback: [gemini-pro]
---

# diagnose (deprecated alias)

This entry point was consolidated: invoke the **`dae`** skill with `--type diagnose`, passing any other arguments (`--ref`, `--explore`) through unchanged. Do that now — read and follow the `dae` skill — and tell the user once, briefly, that `/diagnose` is now `/dae --type diagnose`.
