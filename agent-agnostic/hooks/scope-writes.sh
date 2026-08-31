#!/usr/bin/env bash
# scope-writes.sh — PreToolUse hook denying file writes outside the run's
# allowed write roots.
#
# SYNOPSIS  (wired as a PreToolUse hook; reads the tool-call JSON on stdin)
#   scope-writes.sh
#
# DESCRIPTION
#   Self-configuring: no env var, no invocation-time setup. On every
#   Write/Edit/NotebookEdit-shaped call the hook takes the write target
#   path and walks UP its ancestors looking for a marker file,
#   `.artifacts/progress-log.md`. That marker exists only at the root of a
#   dae run's PARENT worktree (see the `find_parent_worktree` helper
#   below) — a builder's child worktree, a bare checkout, or any other
#   directory with no run dir has no marker anywhere above it, and the
#   hook is INERT there (exit 0 unconditionally).
#
#   When a marker IS found, the write must land inside one of three roots,
#   all resolved relative to the marked worktree:
#     - <marked>/.artifacts               (the run dir itself)
#     - the resolved CLAUDE_PROJECT_PLANS_DIR (default /project-plans/)
#     - the resolved CLAUDE_DOCS_DIR      (default /docs)
#   A write outside all three is DENIED (exit 2; stderr fed back to the
#   model, naming the rule, the offending path, and all three roots).
#
#   Hooks enforce, skills judge. Reads outside these roots are always
#   fine — this guards mutations only. Bash is NOT intercepted (a
#   PreToolUse hook cannot see inside a shell command).
#
#   The worktree + branch isolation backstop holds for a BUILDER: its
#   child worktree has no marker anywhere above it, so this hook never
#   engages there — but it does NOT hold for the ORCHESTRATOR, which runs
#   directly in the marked parent worktree with the whole product tree
#   underfoot. This hook is that backstop for the orchestrator's own
#   Write/Edit calls; `parent-tree-guard.sh` (a sibling hook, landing in
#   this same lane) is the analogous Bash-side backstop for orchestrator
#   shell commands.
#
# EXIT CODES
#   0 - allowed (no marker found above the write target / not a write
#       tool / no path in input / malformed or empty stdin)
#   2 - denied: write target outside the run's allowed write roots
set -uo pipefail

hookdir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# find_parent_worktree <start-path>
# Prints the marked parent worktree's absolute path and returns 0, or
# returns 1 with nothing printed. Pure string ascent (dirname), never `cd`,
# so it tolerates a <start-path> that does not exist yet (a new file being
# written) as well as one that does (a cwd).
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

# resolve_root_dir <VAR> <default> <marked-worktree> [--expect path]
# Prints an absolute, realpath -m'd path. Never fails the caller: on any
# resolve-config.sh error (rejected value, missing script, anything) it
# falls back to <default> joined the same way — fail OPEN, never deny
# because config resolution had a problem.
resolve_root_dir() {
  local var="$1" default="$2" root="$3"; shift 3
  local raw
  raw=$("$hookdir/resolve-config.sh" "$var" --default "$default" --root "$root" "$@" 2>/dev/null) || raw="$default"
  raw=$(printf '%s' "$raw" | sed -E 's/^\.?\///; s/\/+$//')
  realpath -m -- "$root/$raw" 2>/dev/null || printf '%s/%s' "$root" "$raw"
}

input=$(cat 2>/dev/null || true)
[ -n "$input" ] || exit 0

# tool_name, without jq (env block-style flat extraction, same as resolve-config.sh)
tool=$(printf '%s' "$input" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')
case "$tool" in
  Write | Edit | MultiEdit | NotebookEdit | \
    write_to_file | *:write_to_file | \
    replace_file_content | *:replace_file_content | \
    multi_replace_file_content | *:multi_replace_file_content) : ;;
  *) exit 0 ;;
esac

# target path: file_path (Write/Edit) or notebook_path (NotebookEdit) or TargetFile (Antigravity)
path=$(printf '%s' "$input" | grep -oE '"(file_path|notebook_path|TargetFile)"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')
[ -n "$path" ] || exit 0
path=$(realpath -m -- "$path" 2>/dev/null || printf '%s' "$path")

marked=$(find_parent_worktree "$path") || exit 0

artifacts_root=$(realpath -m -- "$marked/.artifacts" 2>/dev/null || printf '%s/.artifacts' "$marked")
plans_root=$(resolve_root_dir CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$marked")
docs_root=$(resolve_root_dir CLAUDE_DOCS_DIR /docs "$marked" --expect path)

for entry in "$artifacts_root" "$plans_root" "$docs_root"; do
  entry="${entry%/}"
  if [ "$path" = "$entry" ] || [[ "$path" == "$entry"/* ]]; then
    exit 0
  fi
done

echo "scope-writes: DENIED — $tool to '$path' is outside the allowed write scope (this is the orchestrator write-scope guard). Allowed roots: '$artifacts_root', '$plans_root', '$docs_root'. This run's writes are limited to those paths; delegate other changes or report the scope gap instead of working around it." >&2
exit 2
