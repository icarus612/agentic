#!/usr/bin/env bash
# allow-workflow-cleanup.sh — PreToolUse hook auto-allowing the two SAFE
# cleanup commands the dae pipeline runs constantly, and nothing else.
#
# SYNOPSIS  (wired as PreToolUse hooks on Bash, if-filtered to
#            "Bash(git branch:*)" and "Bash(git worktree remove:*)";
#            reads the tool-call JSON on stdin)
#
# DESCRIPTION
#   Lane cleanup after merge-back deletes a branch and removes a worktree per
#   lane, and every one prompts. This hook removes the prompt for exactly the
#   provably-safe cases; anything else gets NO OPINION (exit 0, no output) so
#   the normal permission flow — allow rules, ask rules, the prompt —
#   proceeds untouched. It never denies.
#
#   Case 1 — `git branch -d <branch>` (or --delete): auto-allow when
#     - single plain command, no -D/--force, no flags, no chaining, AND
#     - <branch> is in a workflow namespace (feature/ bug/ hotfix/ docs/
#       sync/), AND
#     - it is tied to THIS project's workflows dir (CLAUDE_WORKFLOWS_DIR
#       chain via resolve-config.sh, default .workflows, resolved against
#       the MAIN repo root): its checkout in `git worktree list` is under
#       that dir, or — the lane-cleanup case, worktree already removed — the
#       command runs from inside that dir.
#     `git branch -d` refusing unmerged branches remains the backstop.
#
#   Case 2 — `git worktree remove <path>`: auto-allow when
#     - single plain command, NO --force, no other flags, no chaining, AND
#     - the path's basename ends in the lane suffix `-l<n>` (children only —
#       removing a run's PARENT worktree still prompts), AND
#     - the path resolves inside THIS project's workflows dir.
#     A dirty child refuses a plain remove on its own — that refusal is
#     information, and forcing past it always prompts.
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
case "$tool" in
  Bash | run_command | *:run_command) : ;;
  *) exit 0 ;;
esac
cmd=$(field command)
[ -n "$cmd" ] || cmd=$(field CommandLine)
[ -n "$cmd" ] || exit 0
case "$cmd" in
  *'&&'*|*';'*|*'|'*|*'$('*|*'`'*) exit 0 ;;
esac

cwd=$(field cwd)
[ -n "$cwd" ] || cwd=$(pwd)

# resolve the MAIN repo root and the workflows dir (shared by both cases)
wf_dir() {
  local common main_root wf_name
  common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  main_root=$(dirname "$common")
  wf_name=$("$(dirname "$0")/resolve-config.sh" CLAUDE_WORKFLOWS_DIR --default .workflows 2>/dev/null || echo .workflows)
  case "$wf_name" in
    /*) printf '%s' "${wf_name%/}" ;;
    *)  printf '%s' "$main_root/${wf_name#./}" ;;
  esac
}

allow() {
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"$1"}}
EOF
  exit 0
}

# --- case 1: safe delete of a workflow branch ------------------------------
branch=$(printf '%s' "$cmd" \
  | grep -oE '^git branch (-d|--delete) [A-Za-z0-9._/-]+$' \
  | awk '{print $NF}')
if [ -n "$branch" ]; then
  case "$branch" in
    feature/*|bug/*|hotfix/*|docs/*|sync/*) : ;;
    *) exit 0 ;;
  esac
  wfd=$(wf_dir) || exit 0
  wt_path=$(git -C "$cwd" worktree list --porcelain 2>/dev/null \
    | awk -v b="refs/heads/$branch" '/^worktree /{p=substr($0,10)} $0=="branch "b{print p; exit}')
  if [ -n "$wt_path" ] && [[ "$wt_path" == "$wfd"/* ]]; then
    allow "safe delete of workflow branch '$branch' tied to $wfd"
  fi
  if [ -z "$wt_path" ] && [[ "$cwd" == "$wfd"/* ]]; then
    allow "safe delete of workflow branch '$branch' tied to $wfd"
  fi
  exit 0
fi

# --- case 2: plain removal of a lane-child worktree (-l<n>) ----------------
wtarg=$(printf '%s' "$cmd" \
  | grep -oE '^git worktree remove [A-Za-z0-9._/~-]+$' \
  | sed -E 's/^git worktree remove //')
if [ -n "$wtarg" ]; then
  case "$wtarg" in
    /*) path="$wtarg" ;;
    *)  path="$cwd/$wtarg" ;;
  esac
  path=$(realpath -m -- "$path" 2>/dev/null || printf '%s' "$path")
  printf '%s' "$(basename "$path")" | grep -qE -- '-l[0-9]+$' || exit 0
  wfd=$(wf_dir) || exit 0
  if [[ "$path" == "$wfd"/* ]]; then
    allow "plain removal of lane-child worktree '$(basename "$path")' under $wfd"
  fi
fi

exit 0
