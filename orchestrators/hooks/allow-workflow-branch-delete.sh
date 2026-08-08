#!/usr/bin/env bash
# allow-workflow-branch-delete.sh — PreToolUse hook auto-allowing SAFE deletes
# of workflow branches that live in the project's workflows dir.
#
# SYNOPSIS  (wired as a PreToolUse hook on Bash, if-filtered to
#            "Bash(git branch -d:*)"; reads the tool-call JSON on stdin)
#
# DESCRIPTION
#   The dae pipeline deletes its own branches constantly (lane cleanup after
#   merge-back, post-merge closeout) and every delete prompts. This hook
#   removes the prompt for exactly that case and no other. It auto-allows
#   ONLY when ALL hold:
#     1. The command is a single, plain `git branch -d <branch>` (or
#        `--delete`) — no -D/--force, no flags, no chaining (&&, ;, |).
#     2. <branch> is in a workflow namespace: feature/ bug/ hotfix/ docs/ sync/.
#     3. The branch is physically tied to THIS project's workflows dir
#        (CLAUDE_WORKFLOWS_DIR chain via resolve-config.sh, default
#        .workflows, resolved against the MAIN repo root): its checkout in
#        `git worktree list` is under that dir, or — the lane-cleanup case,
#        where the worktree was already removed — the command itself runs
#        from inside that dir.
#   Anything else gets NO OPINION (exit 0, no output): the normal permission
#   flow — allow rules, ask rules, the prompt — proceeds untouched. This hook
#   never denies. `git branch -d` refusing unmerged branches remains the
#   safety backstop underneath.
#
# EXIT CODES
#   0 - always (either an explicit allow decision on stdout, or no opinion)
set -uo pipefail

input=$(cat 2>/dev/null || true)
[ -n "$input" ] || exit 0

# flat JSON field extraction, same style as scope-writes.sh (no jq dependency)
field() {
  printf '%s' "$input" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" \
    | head -1 | sed -E "s/^\"$1\"[[:space:]]*:[[:space:]]*\"//; s/\"$//" \
    | sed -E 's/\\(["\\/])/\1/g'
}

tool=$(field tool_name)
[ "$tool" = "Bash" ] || exit 0

cmd=$(field command)
[ -n "$cmd" ] || exit 0

# 1. single plain safe delete, one branch, nothing chained
case "$cmd" in
  *'&&'*|*';'*|*'|'*|*'$('*|*'`'*) exit 0 ;;
esac
branch=$(printf '%s' "$cmd" \
  | grep -oE '^git branch (-d|--delete) [A-Za-z0-9._/-]+$' \
  | awk '{print $NF}')
[ -n "$branch" ] || exit 0

# 2. workflow namespace only
case "$branch" in
  feature/*|bug/*|hotfix/*|docs/*|sync/*) : ;;
  *) exit 0 ;;
esac

# 3. tie to THIS project's workflows dir, resolved against the MAIN repo root
cwd=$(field cwd)
[ -n "$cwd" ] || cwd=$(pwd)
common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
main_root=$(dirname "$common")
wf_name=$("$(dirname "$0")/resolve-config.sh" CLAUDE_WORKFLOWS_DIR --default .workflows 2>/dev/null || echo .workflows)
case "$wf_name" in
  /*) wf_dir="$wf_name" ;;
  *)  wf_dir="$main_root/${wf_name#./}" ;;
esac
wf_dir="${wf_dir%/}"

allowed=0
# 3a. the branch's checkout lives under the workflows dir
wt_path=$(git -C "$cwd" worktree list --porcelain 2>/dev/null \
  | awk -v b="refs/heads/$branch" '/^worktree /{p=substr($0,10)} $0=="branch "b{print p; exit}')
if [ -n "$wt_path" ] && [[ "$wt_path" == "$wf_dir"/* ]]; then allowed=1; fi
# 3b. lane cleanup: worktree already removed, but we're operating from inside
#     the workflows dir (e.g. the run's parent worktree)
if [ "$allowed" = 0 ] && [ -z "$wt_path" ] && [[ "$cwd" == "$wf_dir"/* ]]; then allowed=1; fi

[ "$allowed" = 1 ] || exit 0

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"safe delete of workflow branch '$branch' tied to $wf_dir"}}
EOF
exit 0
