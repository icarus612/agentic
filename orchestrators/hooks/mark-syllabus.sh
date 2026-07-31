#!/usr/bin/env bash
# mark-syllabus.sh — flip one subphase checkbox in a plan's syllabus.
#
# SYNOPSIS
#   mark-syllabus.sh <plan-file> <subphase-id> <state>
#
# DESCRIPTION
#   Invoked by the dae orchestrator's dispatch loop (build-dispatch.md), NOT
#   a hook. Scripting the tick is what lets the orchestrator's write scope
#   shrink to run artifacts: the plan file is mutated only through this
#   script. <state> is one of:
#     x        - [ ] -> [x]        (subphase finished as planned)
#     done     - [ ] -> [done]     (closed, shipped differently than planned)
#     dropped  - [ ] -> [dropped]  (closed without shipping)
#     open     - [*] -> [ ]        (reopen)
#   Only the syllabus checkbox line matching '<id>:' is touched; detail
#   blocks and annotations stay as they are.
#
# EXIT CODES
#   0 - flipped (prints the new line)
#   1 - usage error, file/ID not found, or ambiguous match
set -uo pipefail

err() { echo "mark-syllabus: $*" >&2; exit 1; }

plan="${1:-}"; id="${2:-}"; state="${3:-}"
[ -n "$plan" ] && [ -n "$id" ] && [ -n "$state" ] \
  || err "usage: mark-syllabus.sh <plan-file> <subphase-id> <x|done|dropped|open>"
[ -f "$plan" ] || err "plan file not found: $plan"

case "$state" in
  x) mark="x" ;;
  done) mark="done" ;;
  dropped) mark="dropped" ;;
  open) mark=" " ;;
  *) err "invalid state '$state' (must be one of: x, done, dropped, open)" ;;
esac

id_re=$(printf '%s' "$id" | sed 's/\./\\./g')
matches=$(grep -cE "^[[:space:]]+- \[[^]]*\] ${id_re}:" "$plan")
[ "$matches" -eq 1 ] || err "expected exactly 1 syllabus line for '$id:', found $matches in $plan"

tmp=$(mktemp)
sed -E "s/^([[:space:]]+- )\[[^]]*\]( ${id_re}:)/\1[${mark}]\2/" "$plan" > "$tmp" \
  && mv "$tmp" "$plan" || { rm -f "$tmp"; err "edit failed"; }

grep -E "^[[:space:]]+- \[[^]]*\] ${id_re}:" "$plan"
