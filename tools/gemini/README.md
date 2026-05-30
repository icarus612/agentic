# Gemini adapter

How to consume the generic content in [`../../agents/`](../../agents/) from
Google's Gemini CLI / agent. This is an **adapter** — content lives in `agents/`,
you copy it into place.

> **Method: copy-paste.** Same as the other adapters — no script, no symlinks.

## Instructions

Gemini reads a `GEMINI.md` instruction file. Combine `agents/global/AGENTS.md`
plus any `agents/stacks/<tech>/AGENTS.md` you need into the project's `GEMINI.md`.

## Skills

_TODO: verify Gemini's command/skill location and frontmatter format, then
document the copy-paste target here._

## Models

Each skill declares `model:` plus an ordered `model-fallback:` (see
[`../../agents/README.md`](../../agents/README.md#model-policy)). Gemini is the
**cross-vendor backstop** at the end of every chain: `begin`/`plan` resolve
opus → sonnet → `gemini-pro`, the rest sonnet → `gemini-pro`.

When adapting these skills for Gemini, map the chain to `gemini-pro` (the last
entry) — that is the model this tool runs. The Anthropic-tier `model:` value
(`opus`/`sonnet`) is the upstream preference; you fall through to `gemini-pro`
here because the Anthropic tiers aren't available in this tool.

_TODO: confirm Gemini's exact model identifier/alias and how to pin it per
skill, then record the precise value here._
