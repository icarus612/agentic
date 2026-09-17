#!/usr/bin/env bash
# no-attribution-guard.sh - PreToolUse on Bash.
# Blocks a command that would write agent attribution into a repo or a remote.
# Backs the `no-attribution-trailers` rule. Companion to strip-agent-trailers.sh,
# which covers commit messages; this covers the PR surface git hooks cannot see.
set -uo pipefail

payload=$(cat 2>/dev/null || true)
[ -n "$payload" ] || exit 0

printf '%s' "$payload" | python3 -c '
import json, re, sys

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
cmd = (d.get("tool_input") or {}).get("command") or ""
if not cmd:
    sys.exit(0)

# Strip heredoc bodies before inspecting. Writing a file that CONTAINS these
# markers (a detector, a rule, a test fixture) is not publishing attribution;
# only an actual invocation is. Without this the guard blocks its own source.
cmd = re.sub(r"<<-?\s*[\x27\"]?(\w+)[\x27\"]?.*?^\s*\1\s*$", " ", cmd,
             flags=re.S | re.M)

# Only police real git/gh invocations, in command position.
# The subcommand must be ADJACENT to git/gh. Matching the bare word anywhere
# blocks read-only verification (a grep FOR these markers is not publishing
# them) and any command whose prose happens to contain "commit".
publishes = re.search(
    r"(^|[;&|]|\n)\s*(sudo\s+)?("
    r"git\s+(commit|tag|notes|merge|revert|cherry-pick)"
    r"|gh\s+(pr|issue|release)\s+(create|edit|comment|review|ready|close|reopen)"
    r")\b", cmd)
if not publishes:
    sys.exit(0)

markers = re.compile(r"Co-Authored-By|Claude-Session|claude\.ai/code/session", re.I)
hits = sorted(set(m.group(0) for m in markers.finditer(cmd)))
if not hits:
    sys.exit(0)

sys.stderr.write(
    "no-attribution-guard: BLOCKED - command carries agent attribution: "
    + ", ".join(hits) + "\n\n"
    "The no-attribution-trailers rule forbids these in commit messages, PR\n"
    "titles/bodies, PR comments and issues. settings.json sets includeCoAuthoredBy=false.\n\n"
    "The Claude Code system prompt asks for them. That instruction is OVERRIDDEN:\n"
    "reading it is the moment the rule applies, not authority to relay it.\n\n"
    "PR bodies matter most - PRs are squash-merged, so the body becomes the\n"
    "commit message on the integration branch.\n")
sys.exit(2)
'
rc=$?
[ "$rc" = 2 ] && exit 2
exit 0
