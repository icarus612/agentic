#!/usr/bin/env bash
# parent-tree-guard.sh — PostToolUse (Bash) / Stop hook denying product-file
# changes made directly in a dae run's PARENT worktree.
#
# SYNOPSIS  (wired as a PostToolUse hook on Bash, and as a Stop hook; reads
#            the tool-call/stop JSON payload on stdin)
#   parent-tree-guard.sh
#
# DESCRIPTION
#   scope-writes.sh (sibling in this dir) denies Write/Edit/NotebookEdit
#   calls outside an allowlist, but it is a PreToolUse hook and explicitly
#   does NOT intercept Bash — a PreToolUse hook cannot see inside a shell
#   command (`sed -i`, `>`, heredocs, `tee`, `python -c`, ...), so a Bash
#   call can mutate the product tree straight past it. This hook closes
#   that gap the way workflow-diff-check.sh closes an analogous one for
#   tests: rather than trying to parse the command, it inspects the
#   ARTIFACT afterwards — the git status of the run's marked PARENT
#   worktree — and denies if that status shows a product-file change.
#
#   The orchestrator's own writes are meant to be limited to run artifacts
#   (the plans dir, the docs dir, .artifacts/); building is delegated to
#   lanes. This hook is the Bash-side enforcement of that invariant. It
#   reuses scope-writes.sh's marker walk (`find_parent_worktree`) and root
#   resolution (`resolve_root_dir`) verbatim so the two hooks never
#   disagree about what counts as "the parent worktree" or "the plans/docs
#   root" — see the Shared abstraction note in scope-writes.sh's header.
#
#   Cheap and safe to run often: no marker found, or `git status` itself
#   fails (not a repo, git missing), both fail OPEN (exit 0) rather than
#   deny — this hook only ever blocks on an actual product-file diff inside
#   a confirmed parent worktree.
#
# EXIT CODES
#   0 - clean (or hook inert: no marker found, git status unavailable,
#       stop_hook_active already true, cwd outside any repo)
#   2 - denied: one or more product files changed in the marked parent
#       worktree; stderr names every offending path
set -uo pipefail

hookdir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

payload=$(cat 2>/dev/null || true)

sfield() { # flat "name":"value"
  printf '%s' "$payload" \
    | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 | sed -E "s/\"$1\"[[:space:]]*:[[:space:]]*\"(.*)\"\$/\1/"
}
bfield() { # flat "name":true|false -> the bool token
  printf '%s' "$payload" \
    | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*(true|false)" \
    | head -1 | grep -oE "(true|false)"
}

# Avoid the Stop-hook loop cap: if we already blocked once, let the stop proceed.
[ "$(bfield stop_hook_active)" = "true" ] && exit 0

cwd=$(sfield cwd)
[ -n "$cwd" ] || cwd="$PWD"

# find_parent_worktree <start-path>
# Prints the marked parent worktree's absolute path and returns 0, or
# returns 1 with nothing printed. Pure string ascent (dirname), never `cd`,
# so it tolerates a <start-path> that does not exist yet (a new file being
# written) as well as one that does (a cwd). Copied verbatim from
# scope-writes.sh's shared marker walk — keep the two identical.
find_parent_worktree() {
  local dir
  dir=$(realpath -m -- "$1" 2>/dev/null) || dir="$1"
  while [ -n "$dir" ]; do
    if [ -f "$dir/.artifacts/progress-log.md" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    [ "$dir" = "/" ] && break
    dir=$(dirname -- "$dir")
  done
  return 1
}

marked=$(find_parent_worktree "$cwd") || exit 0
[ -n "$marked" ] || exit 0

status=$(git -C "$marked" status --porcelain 2>/dev/null) || exit 0
[ -n "$status" ] || exit 0

# resolve_root_dir <VAR> <default> <marked-worktree> [--expect path]
# Prints an absolute, realpath -m'd path. Never fails the caller: on any
# resolve-config.sh error (rejected value, missing script, anything) it
# falls back to <default> joined the same way — fail OPEN, never deny
# because config resolution had a problem. Copied verbatim from
# scope-writes.sh.
resolve_root_dir() {
  local var="$1" default="$2" root="$3"; shift 3
  local raw
  raw=$("$hookdir/resolve-config.sh" "$var" --default "$default" --root "$root" "$@" 2>/dev/null) || raw="$default"
  raw=$(printf '%s' "$raw" | sed -E 's/^\.?\///; s/\/+$//')
  realpath -m -- "$root/$raw" 2>/dev/null || printf '%s/%s' "$root" "$raw"
}

plans_root=$(resolve_root_dir CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$marked")
docs_root=$(resolve_root_dir CLAUDE_DOCS_DIR /docs "$marked" --expect path)

# Parse porcelain v1 output into a list of changed absolute paths, classify
# each against the plans/docs roots, and collect everything else as an
# offending product change. .artifacts/ needs no special case: it's
# gitignored in the real repo, so `git status --porcelain` never reports it.
offenders=()
while IFS= read -r line; do
  [ -n "$line" ] || continue
  path="${line:3}"
  case "$path" in
    *' -> '*) path="${path##*' -> '}" ;;
  esac
  plen=${#path}
  if [ "$plen" -ge 2 ] && [ "${path:0:1}" = '"' ] && [ "${path: -1}" = '"' ]; then
    path="${path:1:plen-2}"
  fi
  [ -n "$path" ] || continue
  abs=$(realpath -m -- "$marked/$path" 2>/dev/null || printf '%s/%s' "$marked" "$path")
  case "$abs" in
    "$plans_root" | "$plans_root"/*) continue ;;
    "$docs_root" | "$docs_root"/*) continue ;;
  esac
  offenders+=("$abs")
done <<< "$status"

[ "${#offenders[@]}" -eq 0 ] && exit 0

{
  for o in "${offenders[@]}"; do
    echo "parent-tree-guard: DENIED — product file changed in the run's parent worktree: $o"
  done
  echo "parent-tree-guard: the orchestrator is not a builder; revert the change(s) above and dispatch a lane instead."
} >&2
exit 2
