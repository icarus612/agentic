#!/usr/bin/env bash
# Records the agent id owning a lane at <run-dir>/lanes/<lane-id>.agent.

err() {
  echo "lane-bind: $*" >&2
  exit 1
}

[ "$#" -eq 3 ] || err "usage: lane-bind.sh <run-dir> <lane-id> <agent-id>"
rundir="$1"; lane="$2"; agent="$3"

[ -f "$rundir/progress-log.md" ] || err "no progress-log.md at $rundir"
[[ "$lane" =~ ^l[0-9]+$ ]] || err "bad lane id: $lane"
[[ "$agent" =~ ^[A-Za-z0-9_-]+$ ]] || err "bad agent id: $agent"

lanes="$rundir/lanes"
mkdir -p "$lanes" || err "cannot create $lanes"
tmp=$(mktemp "$lanes/.${lane}.XXXXXX") || err "mktemp failed in $lanes"
printf '%s\n' "$agent" > "$tmp" || { rm -f "$tmp"; err "failed to write binding"; }
mv -f "$tmp" "$lanes/$lane.agent" || { rm -f "$tmp"; err "failed to write $lanes/$lane.agent"; }
