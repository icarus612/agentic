#!/usr/bin/env bash
# report-verdict.sh — append a new, enum-enforced verdict round to a review report.
#
# SYNOPSIS
#   report-verdict.sh <report-file> <verdict> <next> <blocking> <non-blocking>
#
# DESCRIPTION
#   Invoked by the review gates (review-plan, review-code, review-pr) to open
#   a '## Round <n>' section: the ONLY way a verdict enters a report, so the
#   status vocabulary is enforced at write time, not by prose. Creates the
#   file (with a title line) if absent; round number is derived by counting
#   existing rounds. The reviewer appends its '### Findings' /
#   '### Open questions' sections after this header; validate-report.sh then
#   cross-checks the counts.
#
#   <verdict>  ready | tentative | rejected
#   <next>     proceed | impl-wrong | plan-wrong | map-wrong | needs-input
#   <blocking>, <non-blocking>  finding counts (non-negative integers)
#
#   Enforced here:
#     - ready/tentative  -> next must be 'proceed', blocking must be 0
#     - rejected         -> next must be a kickback code or 'needs-input';
#                           unless needs-input, blocking must be >= 1
#
# EXIT CODES
#   0 - round appended (prints the new round heading)
#   1 - usage error or contract violation (nothing written)
set -uo pipefail

err() { echo "report-verdict: $*" >&2; exit 1; }

file="${1:-}"; verdict="${2:-}"; next="${3:-}"; blocking="${4:-}"; nonblocking="${5:-}"
[ -n "$file" ] && [ -n "$verdict" ] && [ -n "$next" ] && [ -n "$blocking" ] && [ -n "$nonblocking" ] \
  || err "usage: report-verdict.sh <report-file> <verdict> <next> <blocking> <non-blocking>"

case "$verdict" in ready|tentative|rejected) : ;;
  *) err "invalid verdict '$verdict' (must be: ready | tentative | rejected)" ;; esac
case "$next" in proceed|impl-wrong|plan-wrong|map-wrong|needs-input) : ;;
  *) err "invalid next '$next' (must be: proceed | impl-wrong | plan-wrong | map-wrong | needs-input)" ;; esac
case "$blocking" in ''|*[!0-9]*) err "blocking must be a non-negative integer, got '$blocking'" ;; esac
case "$nonblocking" in ''|*[!0-9]*) err "non-blocking must be a non-negative integer, got '$nonblocking'" ;; esac

if [ "$verdict" != "rejected" ]; then
  [ "$next" = "proceed" ] || err "verdict '$verdict' requires next 'proceed', got '$next'"
  [ "$blocking" -eq 0 ] || err "verdict '$verdict' requires 0 blocking findings, got $blocking"
else
  [ "$next" != "proceed" ] || err "verdict 'rejected' requires a kickback code or 'needs-input', not 'proceed'"
  if [ "$next" != "needs-input" ]; then
    [ "$blocking" -ge 1 ] || err "verdict 'rejected' with next '$next' requires >= 1 blocking finding"
  fi
fi

if [ ! -f "$file" ]; then
  printf '# %s\n' "$(basename "$file" .md)" > "$file" || err "cannot create $file"
fi

round=$(( $(grep -cE '^## Round [0-9]+' "$file") + 1 ))
{
  printf '\n## Round %s — %s\n\n' "$round" "$(date +%m-%d-%y)"
  printf '```\nverdict: %s\nnext: %s\nblocking: %s\nnon-blocking: %s\n```\n' \
    "$verdict" "$next" "$blocking" "$nonblocking"
} >> "$file" || err "append failed"

echo "## Round $round — verdict: $verdict, next: $next"
