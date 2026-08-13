# Antigravity Integration Project Plan (Hybrid)

This plan combines the best elements of both previous proposals to make the `agentic` repo install cleanly to both Claude Code and Antigravity, with zero logic changes to existing scripts or workflows.

## Phase 1: Skills + Rules

### 1.1 Update `orchestrators/hooks/sync-install.sh`
Add explicit `--agy` and `--claude` flags that dictate which config file (`hooks.json` vs `settings.json`) gets copied based on the target environment. Keep the sync loops isolated so one environment doesn't accidentally pollute the other.

*(Note: We will NOT modify the rule frontmatters. Antigravity will discover the `rules/` directory natively, preserving the "zero modifications" goal).*

## Phase 2: Agents & Documentation

### 2.1 The Inline `PreInvocation` Compatibility Shim
Instead of writing a custom bash script for platform detection, we will inject a system instruction natively via `hooks.json` on `PreInvocation`:
```json
"compatibility-shim": {
  "PreInvocation": [
    {
      "type": "command",
      "command": "echo '{\"injectSteps\": [{\"ephemeralMessage\": \"Compatibility Mode: You are running in Antigravity. When instructions tell you to use the `Agent` tool, you MUST use `define_subagent` and `invoke_subagent`. When instructions tell you to use the `Bash` tool, use `run_command`. Your $AGENT_HOME path is ~/.gemini/config.\"}]}'"
    }
  ]
}
```

### 2.2 Update `docs/conventions.md`
- Document the cross-platform model mapping (Opus → Pro, Sonnet → Inherit, Haiku → Flash_lite).
- Explain that consuming projects adopting Antigravity should create `.agents/GEMINI.md` referencing their existing `.claude/` tech layers, rather than trying to sync files.

## Phase 3: Hooks & Permissions (The Translation Layer)

### 3.1 Write `generic/hooks/agy-hook-adapter.sh`
A robust translation script using `jq` to bridge the I/O gap.
- Reads Antigravity's nested JSON (`toolCall.name`) and translates it into Claude Code's flat JSON format (`tool_name`).
- Synthesizes `"source": "startup"` when `invocationNum == 1` so the existing `worktree-reminder.sh` fires exactly once per session without spamming the context.
- Translates the exit codes and stdout back into Antigravity's expected JSON format.

### 3.2 Write `generic/hooks/agy-permissions.sh`
A dedicated `PreToolUse` hook for Antigravity that reads the incoming tool name and command, and returns `allow`, `deny`, or `ask` based on the exact rules codified in `settings.json`. This replaces Claude's declarative permissions block and prevents Antigravity from constantly prompting the user to approve safe commands.

### 3.3 Create `generic/settings/hooks.json`
A static JSON manifest wiring all existing hooks (`smart-lint.sh`, `worktree-reminder.sh`, etc.) through the `agy-hook-adapter.sh`, plus the new `agy-permissions.sh` hook and the inline platform shim.
