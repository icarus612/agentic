#!/usr/bin/env bash
# verify-scope.sh — check a builder's reported files against its lane's real diff.
#
# SYNOPSIS
#   verify-scope.sh <worktree-path> <parent-branch> [<reported-file>...]
#   (reported files may also arrive on stdin, one per line)
#
# DESCRIPTION
#   Invoked by the dae orchestrator's dispatch loop before merging a lane's
#   child branch back into the parent. Computes what ACTUALLY changed in the
#   child worktree relative to the parent branch (committed, staged, and
#   untracked) and compares it to what the builder REPORTED touching:
#     UNREPORTED: <file>  - changed on disk but absent from the report -> FAIL
#     UNCHANGED:  <file>  - reported but shows no change -> warning only
#   Paths are compared repo-relative. An UNREPORTED file means the exit
#   report can't be trusted as a scope record — resolve before merge-back
#   (the merge itself is the second, physical check: a conflict against a
#   sibling lane is a mechanical scope violation).
#
# EXIT CODES
#   0 - report matches the diff (UNCHANGED warnings allowed)
#   1 - usage error, or one or more UNREPORTED files
set -uo pipefail

err() { echo "verify-scope: $*" >&2; exit 1; }

wt="${1:-}"; parent="${2:-}"; shift 2 2>/dev/null || true
[ -n "$wt" ] && [ -n "$parent" ] || err "usage: verify-scope.sh <worktree-path> <parent-branch> [<reported-file>...]"
[ -d "$wt" ] || err "worktree path not found: $wt"
git -C "$wt" rev-parse --verify -q "$parent" >/dev/null || err "parent branch '$parent' does not exist"

reported=$(printf '%s\n' "$@")
if [ ! -t 0 ]; then reported="$reported
$(cat)"; fi
reported=$(printf '%s\n' "$reported" | sed '/^$/d' | sort -u)

changed=$( { git -C "$wt" diff --name-only "$parent"...HEAD;
             git -C "$wt" diff --name-only HEAD;          # unstaged
             git -C "$wt" diff --name-only --cached;      # staged
             git -C "$wt" ls-files --others --exclude-standard; } | sort -u | sed '/^$/d')

fail=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  printf '%s\n' "$reported" | grep -qxF "$f" || { echo "UNREPORTED: $f"; fail=1; }
done <<< "$changed"

while IFS= read -r f; do
  [ -n "$f" ] || continue
  printf '%s\n' "$changed" | grep -qxF "$f" || echo "UNCHANGED: $f (reported but no diff)"
done <<< "$reported"

[ "$fail" = 0 ] && echo "OK: reported files match the lane diff ($(printf '%s\n' "$changed" | sed '/^$/d' | wc -l | tr -d ' ') changed)"
exit "$fail"
