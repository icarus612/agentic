#!/bin/bash

# Fallback if jq is not installed
if ! command -v jq >/dev/null 2>&1; then
    echo '{"decision": "allow", "error": "jq not installed, gracefully degrading"}'
    exit 0
fi

input=$(cat)
claude_hook=$1

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

# Translate the exit codes (and optionally stdout) back to AGY JSON
if [ $exit_code -eq 0 ]; then
    echo '{"decision": "allow"}'
elif [ $exit_code -eq 1 ]; then
    echo '{"decision": "deny"}'
else
    echo '{"decision": "ask"}'
fi
