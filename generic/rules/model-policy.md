---
name: model-policy
description: Each skill declares an Anthropic-first model with a gemini-pro fallback chain.
domain: universal
---

# Model policy
Each skill declares a `model:` (Anthropic-first) and an ordered `model-fallback:` ending in `gemini-pro`. Orchestration and planning skills resolve opus -> sonnet -> gemini-pro; everything else sonnet -> gemini-pro. Each tool honors what it supports (Claude Code reads the single `model:` value only).
