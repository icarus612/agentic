#!/usr/bin/env bash
# pr-ready-hygiene-guard.sh - PreToolUse on Bash.
# The draft->ready flip is the last moment before work becomes mergeable, so it is
# where the one end-of-lifecycle hygiene scan is enforced. Blocks the flip when the
# branch carries agent attribution or comment noise.
#
# This is deliberately a HARNESS hook, not a step inside push-pr: a skill step only
# runs when an agent follows the skill. This fires on the tool call itself, so no
# agent - orchestrator or subagent - can route around it by calling gh directly.
set -uo pipefail

payload=$(cat 2>/dev/null || true)
[ -n "$payload" ] || exit 0

cmd=$(printf '%s' "$payload" | python3 -c '
import json, sys
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
print((d.get("tool_input") or {}).get("command") or "")
' 2>/dev/null || true)
[ -n "$cmd" ] || exit 0

# Only the draft->ready transition.
printf '%s' "$cmd" | grep -qE '(^|[;&|]|\n)\s*(sudo\s+)?gh\s+pr\s+ready\b' || exit 0

BASE="${CLAUDE_BASE_BRANCH:-}"
if [ -z "$BASE" ] && [ -x "$HOME/.claude/hooks/resolve-config.sh" ]; then
  BASE=$("$HOME/.claude/hooks/resolve-config.sh" CLAUDE_BASE_BRANCH --base-branch-default 2>/dev/null | tail -n1)
fi
[ -n "$BASE" ] || BASE=$(git rev-parse --verify -q dev >/dev/null 2>&1 && echo dev || echo main)

SCAN="$HOME/.claude/hooks/check-diff-hygiene.sh"
[ -x "$SCAN" ] || exit 0

out=$("$SCAN" --base "$BASE" 2>&1); rc=$?
if [ "$rc" = 1 ]; then
  {
    echo "pr-ready-hygiene-guard: BLOCKED - refusing to flip this PR to ready."
    echo
    echo "$out"
    echo
    echo "Fix the branch and push again, then retry. Do not route around this by"
    echo "editing the PR in the web UI - the violations are in the branch."
  } >&2
  exit 2
fi
exit 0
