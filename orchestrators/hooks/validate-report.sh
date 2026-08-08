#!/usr/bin/env bash
# validate-report.sh — schema check for run-artifact report files.
#
# SYNOPSIS
#   validate-report.sh <report-file>              # review report (default kind)
#   validate-report.sh --kind exit <report-file>  # builder exit report
#
# DESCRIPTION
#   The caller-side half of the report contract (report-verdict.sh is the
#   writer-side half). A report that fails here is not a report — gates rerun,
#   callers refuse the hand-off.
#
#   Review reports (plan-review / code-review / pr-review):
#     1. At least one '## Round <n>' section.
#     2. The LAST round has a fenced header with valid enums:
#        verdict: ready|tentative|rejected
#        next:    proceed|impl-wrong|plan-wrong|map-wrong|needs-input
#     3. Cross-field rules: ready/tentative -> next=proceed, blocking=0;
#        rejected -> next != proceed; rejected without needs-input -> blocking>=1.
#     4. Header counts match the tagged finding lines in that round
#        ('- [blocking]' / '- [non-blocking]').
#     5. next=needs-input -> the round has a non-empty '### Open questions'.
#
#   Exit reports (--kind exit):
#     1. Fenced header with status: success|blocked|needs-input|failed.
#     2. A non-empty '## Files touched' section.
#     3. A non-empty '## Evidence' section.
#
# EXIT CODES
#   0 - valid (prints 'OK: ...')
#   1 - violations (one 'FAIL:' line each), or usage/read error
set -uo pipefail

kind="review"
if [ "${1:-}" = "--kind" ]; then kind="${2:-}"; shift 2; fi
file="${1:-}"
[ -n "$file" ] || { echo "usage: validate-report.sh [--kind review|exit] <report-file>" >&2; exit 1; }
[ -f "$file" ] || { echo "FAIL: report file not found: $file"; exit 1; }

fail=0
say_fail() { echo "FAIL: $*"; fail=1; }
header_val() { printf '%s\n' "$1" | grep -m1 -E "^$2:" | sed -E "s/^$2:[[:space:]]*//" ; }

case "$kind" in
review)
  last=$(grep -E '^## Round [0-9]+' "$file" | tail -1 | grep -oE 'Round [0-9]+' | awk '{print $2}')
  [ -n "$last" ] || { say_fail "no '## Round <n>' section found"; echo "$((fail))"; exit 1; }

  # the last round's text: from its heading to EOF
  round=$(awk -v r="^## Round ${last} " '$0 ~ r {f=1} f' "$file")
  hdr=$(printf '%s\n' "$round" | awk '/^```/{n++; next} n==1' )

  verdict=$(header_val "$hdr" verdict)
  next=$(header_val "$hdr" next)
  blocking=$(header_val "$hdr" blocking)
  nonblocking=$(header_val "$hdr" non-blocking)

  case "$verdict" in ready|tentative|rejected) : ;;
    *) say_fail "round $last: invalid or missing 'verdict: $verdict'" ;; esac
  case "$next" in proceed|impl-wrong|plan-wrong|map-wrong|needs-input) : ;;
    *) say_fail "round $last: invalid or missing 'next: $next'" ;; esac
  case "$blocking" in ''|*[!0-9]*) say_fail "round $last: invalid 'blocking: $blocking'"; blocking=-1 ;; esac
  case "$nonblocking" in ''|*[!0-9]*) say_fail "round $last: invalid 'non-blocking: $nonblocking'"; nonblocking=-1 ;; esac

  if [ "$fail" = 0 ]; then
    if [ "$verdict" != "rejected" ]; then
      [ "$next" = "proceed" ] || say_fail "round $last: verdict '$verdict' requires next 'proceed'"
      [ "$blocking" -eq 0 ] || say_fail "round $last: verdict '$verdict' requires blocking=0"
    else
      [ "$next" != "proceed" ] || say_fail "round $last: verdict 'rejected' cannot have next 'proceed'"
      if [ "$next" != "needs-input" ] && [ "$blocking" -lt 1 ]; then
        say_fail "round $last: verdict 'rejected' with next '$next' requires blocking>=1"
      fi
    fi
    b_count=$(printf '%s\n' "$round" | grep -cE '^\s*- \[blocking\]')
    n_count=$(printf '%s\n' "$round" | grep -cE '^\s*- \[non-blocking\]')
    [ "$b_count" -eq "$blocking" ] || say_fail "round $last: header says blocking=$blocking but $b_count '- [blocking]' finding lines found"
    [ "$n_count" -eq "$nonblocking" ] || say_fail "round $last: header says non-blocking=$nonblocking but $n_count '- [non-blocking]' finding lines found"
    if [ "$next" = "needs-input" ]; then
      q=$(printf '%s\n' "$round" | awk '/^### Open questions/{f=1;next} /^#/{f=0} f' | grep -cE '\S' || true)
      [ "$q" -ge 1 ] || say_fail "round $last: next 'needs-input' requires a non-empty '### Open questions' section"
    fi
  fi
  [ "$fail" = 0 ] && echo "OK: review report valid (round $last: verdict $verdict, next $next, $blocking blocking / $nonblocking non-blocking)"
  ;;
exit)
  hdr=$(awk '/^```/{n++; next} n==1' "$file")
  status=$(header_val "$hdr" status)
  case "$status" in success|blocked|needs-input|failed) : ;;
    *) say_fail "invalid or missing 'status: $status' (must be: success | blocked | needs-input | failed)" ;; esac
  files=$(awk '/^## Files touched/{f=1;next} /^## /{f=0} f' "$file" | grep -cE '^\s*- \S' || true)
  [ "$files" -ge 1 ] || say_fail "'## Files touched' section missing or empty"
  ev=$(awk '/^## Evidence/{f=1;next} /^## /{f=0} f' "$file" | grep -cE '\S' || true)
  [ "$ev" -ge 1 ] || say_fail "'## Evidence' section missing or empty"
  [ "$fail" = 0 ] && echo "OK: exit report valid (status $status, $files files)"
  ;;
*)
  echo "FAIL: unknown kind '$kind' (review | exit)"; fail=1 ;;
esac

exit "$fail"
