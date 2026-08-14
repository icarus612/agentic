# Dual-Engine Antigravity Retrofit (Consolidated Plan)

## Phase syllabus

- Phase 1: Skills, Rules, and Sync
  - [x] 1.1 Update `sync-install.sh` to support explicit `--claude` and `--agy` install flags (lane 1)
  - [x] 1.2 Verify all 11 skill dirs copy cleanly to `~/.gemini/config/skills/` (lane 1, after: 1.1)
  - [x] 1.3 Verify all 10 rule files copy cleanly to `~/.gemini/config/rules/` (lane 1, after: 1.1)
  - [x] 1.4 Document project-level `.agents/` strategy in `docs/conventions.md` (lane 1)
- Phase 2: Agent Compatibility
  - [x] 2.1 Update `generic/settings/hooks.json` to inject an inline `PreInvocation` compatibility shim (lane 1)
  - [x] 2.2 Document cross-platform model mapping (`opus`→`pro`, `sonnet`→`inherit`) in `docs/conventions.md` (lane 1)
- Phase 3: Hooks & Permissions
  - [x] 3.1 Write `generic/hooks/agy-hook-adapter.sh` polyfill with `jq` JSON translation and `invocationNum` synthesis (lane 1)
  - [x] 3.2 Write `generic/hooks/agy-permissions.sh` to replicate `settings.json` allowlist for silent UX (lane 1)
  - [x] 3.3 Finalize `generic/settings/hooks.json` wiring all hooks through the adapter (lane 1, after: 3.1, 3.2, 2.1)
  - [x] 3.4 Add `hooks.json` copy logic to `sync-install.sh` Antigravity target (lane 1, after: 3.3, 1.1)
  - [x] 3.5 Test each hook through the adapter end-to-end (lane 1, after: 3.4)

## Goal & scope

**In scope:** Make the `agentic/` repo's skills, agents, hooks, and rules installable and functional under Google Antigravity alongside the existing Claude Code install path. Zero logic changes to existing scripts, prompts, or workflows — behavior remains byte-for-byte identical.

**Out of scope:**
- Rewriting existing bash hooks to natively speak both contracts.
- Antigravity plugin bundling (install remains flat files).
- Automated `.agents/` sync for project-level `tool-based/` layers.
- Building an Antigravity-native orchestrator.

## Conventions to enforce

- `domain:` remains the only classifier — no Antigravity-specific classifier added.
- Every existing skill and rule file stays valid for both platforms simultaneously without changes.
- The adapter polyfill (`agy-hook-adapter.sh`) must explicitly translate nested AGY JSON into the flat Claude JSON format that existing hooks parse.
- `sync-install.sh` must remain idempotent and verify target environments explicitly with `--claude` or `--agy` flags.
- If `jq` is missing, Antigravity hooks must gracefully degrade.

---

## Phase 1: Skills, Rules, and Sync

### 1.1 Add explicit install flags to `sync-install.sh`
**File scope:** `orchestrators/hooks/sync-install.sh`

Update the script to use explicit, isolated flags (`--claude` and `--agy`) to determine the copy destination. This prevents accidental cross-pollution between developer environments.

### 1.2 & 1.3 Verify skill and rule copies
**File scope:** manual test

Verify `~/.gemini/config/skills/` and `~/.gemini/config/rules/` mirror their Claude counterparts. (No edits needed to rule frontmatters; AGY discovers them automatically).

### 1.4 Document project-level strategy
**File scope:** `docs/conventions.md`

Document that consuming projects adopting Antigravity should create `.agents/GEMINI.md` referencing their existing `.claude/` tech layers.

---

## Phase 2: Agent Compatibility

### 2.1 The Inline `PreInvocation` Compatibility Shim
**File scope:** `generic/settings/hooks.json`

Instead of writing a custom bash script for platform detection, we will inject a system instruction natively via `hooks.json` on `PreInvocation`. The instruction will guide the LLM to use `define_subagent` instead of the `Agent` tool, and provide the model mapping logic.

### 2.2 Model mapping documentation
**File scope:** `docs/conventions.md`

Add a "Cross-platform model mapping" section documenting the translation matrix (Opus → Pro, Sonnet → Inherit, Haiku → Flash_lite).

---

## Phase 3: Hooks & Permissions

### 3.1 Write `agy-hook-adapter.sh`
**File scope:** `generic/hooks/agy-hook-adapter.sh` (new)

A robust translation script using `jq` to bridge the I/O gap:
- Reads Antigravity's nested JSON (e.g., `toolCall.name`) and translates it into Claude Code's flat JSON format (e.g., `tool_name`).
- Synthesizes `"source": "startup"` when `invocationNum == 1` so `worktree-reminder.sh` fires exactly once per session without spamming the context.
- Translates exit codes and stdout back into Antigravity's expected JSON structure.

### 3.2 Write `agy-permissions.sh`
**File scope:** `generic/hooks/agy-permissions.sh` (new)

A dedicated `PreToolUse` hook for Antigravity that parses the incoming tool name and command, and returns `allow`, `deny`, or `ask` based on the exact allowlist logic codified in `settings.json`. This suppresses Antigravity's native permission prompts for safe, automated lane cleanups and background tasks.

### 3.3 & 3.4 Wire up `hooks.json`
**File scope:** `generic/settings/hooks.json` & `orchestrators/hooks/sync-install.sh`

Create the static JSON manifest wiring all existing hooks through the adapter. Ensure `sync-install.sh` copies this file (instead of `settings.json`) when `--agy` is passed.
