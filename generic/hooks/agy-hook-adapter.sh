#!/bin/bash
# agy-hook-adapter.sh — translate a wrapped Claude Code hook's stdin/stdout/
# exit-code contract into Antigravity's hook contract, so the SAME hook
# script drives both engines (see the hooks.json wiring in this repo, where
# every AGY hook entry is "agy-hook-adapter.sh <claude-hook-path>").
#
# SYNOPSIS
#   agy-hook-adapter.sh <claude-hook-path>   (reads AGY's nested tool-call
#                                              JSON on stdin)
#
# DESCRIPTION
#   1. Translates AGY's nested {toolCall:{name,arguments}, invocationNum}
#      payload into Claude Code's flat {tool_name, arguments, source} shape
#      and feeds it to the wrapped Claude hook on stdin.
#   2. Reads the wrapped hook's stdout. If it carries a SessionStart-shaped
#      hookSpecificOutput.additionalContext (e.g. worktree-reminder.sh),
#      THAT text is the payload that matters, not the exit code — translate
#      it to Antigravity's context-injection form
#      {"injectSteps":[{"ephemeralMessage":"<text>"}]}, matching the
#      claude-compatibility-shim entry in generic/settings/hooks.json.
#      Before this fix, the wrapped hook's stdout was captured into `out`
#      and never used, so every Claude hook that communicates via stdout
#      JSON (not just exit code) was silently a no-op under Antigravity —
#      e.g. worktree-reminder.sh's reminder never reached the model.
#   3. Otherwise (no additionalContext — the common case, e.g.
#      allow-workflow-cleanup.sh, smart-lint.sh), map the wrapped hook's
#      exit code to AGY's decision contract: 0 allow, 1 deny, anything else
#      ask.
#
#   Decision key note: this script originally emitted {"directive": ...}.
#   This repo's own live ~/.gemini/config install had independently
#   hand-patched BOTH this file and agy-permissions.sh to emit
#   {"decision": ...} instead — found via `diff` against the repo source
#   while building this fix. Two independent live edits converging on the
#   same rename is strong evidence "directive" does not work against real
#   Antigravity and "decision" does; this version ships the verified key.
#   (agy-permissions.sh itself is untouched here — out of this change's
#   scope — but carries the identical "decision" drift plus a tool_name
#   match for "default_api:run_command" instead of "run_command"; flagged
#   in the build report for a human decision, not silently copied in.)
#
# EXIT CODES
#   Always 0 — AGY reads the decision from stdout JSON, not this wrapper's
#   own exit code.
set -uo pipefail

# Fallback if jq is not installed
if ! command -v jq >/dev/null 2>&1; then
    echo '{"decision": "allow", "error": "jq not installed, gracefully degrading"}'
    exit 0
fi

input=$(cat)
claude_hook="${1:-}"

if [ -z "$claude_hook" ] || [ ! -x "$claude_hook" ]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Translate AGY nested JSON to Claude flat JSON
translated=$(echo "$input" | jq -c '{
  tool_name: .toolCall.name,
  arguments: .toolCall.arguments
} + if .invocationNum == 1 then {source: "startup"} else {} end')

# Execute Claude hook with translated JSON
out=$(echo "$translated" | "$claude_hook")
exit_code=$?

# Context-injection hooks (SessionStart etc.) communicate via stdout JSON,
# not exit code — translate additionalContext to AGY's injectSteps form
# when present, regardless of the wrapped hook's exit code.
context=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
if [ -n "$context" ]; then
    jq -n -c --arg msg "$context" '{injectSteps: [{ephemeralMessage: $msg}]}'
    exit 0
fi

# Translate the exit code back to AGY's decision contract
if [ $exit_code -eq 0 ]; then
    echo '{"decision": "allow"}'
elif [ $exit_code -eq 1 ]; then
    echo '{"decision": "deny"}'
else
    echo '{"decision": "ask"}'
fi
