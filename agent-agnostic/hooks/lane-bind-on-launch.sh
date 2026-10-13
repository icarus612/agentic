#!/usr/bin/env bash
# PostToolUse on Agent: binds the launched builder agentId to the lane named in its prompt. Fail-open.
set -uo pipefail

hookdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

payload=$(cat 2>/dev/null || true)
[ -n "$payload" ] || exit 0

fields=$(printf '%s' "$payload" | python3 -c '
import json, os, re, sys

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not isinstance(d, dict) or "agent_id" in d:
    sys.exit(0)
ti = d.get("tool_input")
if not isinstance(ti, dict) or ti.get("subagent_type") != "builder":
    sys.exit(0)
prompt = ti.get("prompt")
if not isinstance(prompt, str):
    sys.exit(0)
lane = re.search(r"^lane-id:[ \t]*(l[0-9]+)[ \t]*$", prompt, re.M)
run = re.search(r"^run-dir:[ \t]*(/\S+)[ \t]*$", prompt, re.M)
if not lane or not run:
    sys.exit(0)

resp = d.get("tool_response")
agent = ""
if isinstance(resp, dict) and isinstance(resp.get("agentId"), str):
    agent = resp["agentId"]
if not agent:
    text = resp if isinstance(resp, str) else json.dumps(resp) if resp is not None else ""
    m = re.search(r"agentId:\s*(\S+)", text)
    agent = m.group(1) if m else ""
if not agent:
    sys.exit(0)
if not os.path.isfile(os.path.join(run.group(1), "progress-log.md")):
    sys.exit(0)
print("\t".join([run.group(1), lane.group(1), agent]))
' 2>/dev/null) || exit 0
[ -n "$fields" ] || exit 0

IFS=$'\t' read -r rundir lane agent <<< "$fields"

if ! "$hookdir/lane-bind.sh" "$rundir" "$lane" "$agent" >/dev/null 2>&1; then
  echo "lane-bind-on-launch: could not record the binding for lane $lane (agentId: $agent)." >&2
  echo "Run manually: lane-bind.sh $rundir $lane <agentId>" >&2
  exit 2
fi
exit 0
