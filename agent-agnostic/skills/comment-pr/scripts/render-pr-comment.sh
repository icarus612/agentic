#!/usr/bin/env bash
# render-pr-comment.sh — render the LAST round of a review report as a GitHub
# PR comment body (markdown, on stdout).
#
# SYNOPSIS
#   render-pr-comment.sh <report-file>
#
# DESCRIPTION
#   The rendering half of the comment-pr skill's contract: the comment body is
#   generated from the report file, never hand-written, so what lands on the
#   PR is exactly what the report says. Refuses a report whose last round has
#   an invalid verdict header (run validate-report.sh first for full checks).
#
# EXIT CODES
#   0 - body printed to stdout
#   1 - usage error, or the report's last round is malformed
set -uo pipefail

err() { echo "render-pr-comment: $*" >&2; exit 1; }

file="${1:-}"
[ -n "$file" ] || err "usage: render-pr-comment.sh <report-file>"
[ -f "$file" ] || err "report file not found: $file"

last=$(grep -E '^## Round [0-9]+' "$file" | tail -1 | grep -oE 'Round [0-9]+' | awk '{print $2}')
[ -n "$last" ] || err "no '## Round <n>' section in $file"

round=$(awk -v r="^## Round ${last} " '$0 ~ r {f=1} f' "$file")
hdr=$(printf '%s\n' "$round" | awk '/^```/{n++; next} n==1')
get() { printf '%s\n' "$hdr" | grep -m1 -E "^$1:" | sed -E "s/^$1:[[:space:]]*//"; }

verdict=$(get verdict); next=$(get next)
blocking=$(get blocking); nonblocking=$(get non-blocking)

case "$verdict" in
  ready)     badge="✅ **READY** — mergeable as-is" ;;
  tentative) badge="🟡 **TENTATIVE** — mergeable; non-blocking fixes worth considering" ;;
  rejected)  badge="❌ **REJECTED** — blocking findings (route: \`$next\`)" ;;
  *) err "invalid verdict '$verdict' in round $last — fix the report (see validate-report.sh)" ;;
esac

date_line=$(grep -E "^## Round ${last} " "$file" | sed -E 's/^## Round [0-9]+ — //')

printf '## PR review — round %s (%s)\n\n%s\n\n' "$last" "$date_line" "$badge"
printf '**Findings:** %s blocking · %s non-blocking\n' "${blocking:-0}" "${nonblocking:-0}"

findings=$(printf '%s\n' "$round" | awk '/^### Findings/{f=1;next} /^###? /{f=0} f' | grep -E '^\s*- \[(blocking|non-blocking)\]' || true)
if [ -n "$findings" ]; then
  printf '\n| | Finding |\n|---|---|\n'
  while IFS= read -r line; do
    tag=$(printf '%s' "$line" | grep -oE '\[(blocking|non-blocking)\]' | head -1)
    body=$(printf '%s' "$line" | sed -E 's/^\s*- \[(blocking|non-blocking)\]\s*//' | sed 's/|/\\|/g')
    case "$tag" in
      "[blocking]") icon="🛑" ;;
      *) icon="💡" ;;
    esac
    printf '| %s | %s |\n' "$icon" "$body"
  done <<< "$findings"
fi

questions=$(printf '%s\n' "$round" | awk '/^### Open questions/{f=1;next} /^###? /{f=0} f' | grep -E '^\s*- ' || true)
if [ -n "$questions" ]; then
  printf '\n**Open questions**\n%s\n' "$questions"
fi

printf '\n---\n*Generated from the review report by the dae workflow (`review-pr` → `comment-pr`).*\n'
