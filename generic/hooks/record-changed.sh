#!/usr/bin/env bash
# PostToolUse recorder — appends files THIS session wrote to a per-session list.
# Paired with test-changed.sh (Stop gate). No jq dependency (jq is not on PATH here);
# fields are extracted from the flat JSON payload with grep/sed.
#
# Never blocks a tool call: always exits 0.
set -uo pipefail

payload=$(cat)

# --- extract flat string fields without jq -------------------------------
field() { # field <name> ; echoes first "name":"value" value, or empty
  printf '%s' "$payload" \
    | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 \
    | sed -E "s/\"$1\"[[:space:]]*:[[:space:]]*\"(.*)\"$/\1/"
}

sid=$(field session_id)
fp=$(field file_path)

[ -n "$sid" ] || exit 0
[ -n "$fp" ] || exit 0

# Don't track edits to the hook scripts themselves.
case "$fp" in
  */.claude/hooks/*) exit 0 ;;
esac

dir="$HOME/.claude/state/test-changed"
mkdir -p "$dir"
lock="$dir/$sid.lock"

# Serialize appends so concurrent writers (parallel subagents in the same
# session) never interleave a line.
( flock 9; printf '%s\n' "$fp" >> "$dir/$sid.list" ) 9>"$lock"

exit 0
