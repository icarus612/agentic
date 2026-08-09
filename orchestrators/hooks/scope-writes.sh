#!/usr/bin/env bash
# scope-writes.sh — PreToolUse hook denying file writes outside an allowlisted path set.
#
# SYNOPSIS  (wired as a PreToolUse hook; reads the tool-call JSON on stdin)
#   CLAUDE_SCOPE_ALLOW="<path>[:<path>...]" scope-writes.sh
#
# DESCRIPTION
#   One config-driven mechanism, configured entirely through CLAUDE_SCOPE_ALLOW —
#   a colon-separated list of absolute paths (files or directory prefixes). When
#   set, any Write/Edit/NotebookEdit call targeting a path outside the list is
#   DENIED (exit 2; stderr is fed back to the model). When unset or empty the
#   hook is inert — it allows everything, so it can be wired unconditionally
#   and activated per-run.
#
#   Hooks enforce, skills judge. The two configurations this mechanism serves:
#
#   1. ORCHESTRATOR SCOPE (the live consumer): the dae orchestrator delegates
#      all building; its own writes are limited to run artifacts (and the plan
#      file until mark-syllabus.sh took over syllabus ticks). Example:
#        CLAUDE_SCOPE_ALLOW="/path/to/project-plans:/path/to/worktree/.artifacts"
#   2. BUILDER LANE SCOPE (documented, NOT wired): confine a builder to its
#      lane's file scope. Retired unneeded — per-builder worktree isolation
#      makes collisions physically impossible and merge-back is the scope
#      check; kept here as the config shape in case a shared-worktree mode
#      ever returns.
#
#   Reads outside the allowlist are always fine — this guards mutations only.
#   Bash is NOT intercepted (a PreToolUse hook cannot see inside a shell
#   command); the worktree + branch isolation is the backstop for that.
#
# EXIT CODES
#   0 - allowed (or hook inert / not a write tool / no path in input)
#   2 - denied: write target outside CLAUDE_SCOPE_ALLOW
set -uo pipefail

allow="${CLAUDE_SCOPE_ALLOW:-}"
[ -n "$allow" ] || exit 0

input=$(cat 2>/dev/null || true)
[ -n "$input" ] || exit 0

# tool_name, without jq (env block-style flat extraction, same as resolve-config.sh)
tool=$(printf '%s' "$input" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')
case "$tool" in
  Write|Edit|NotebookEdit) : ;;
  *) exit 0 ;;
esac

# target path: file_path (Write/Edit) or notebook_path (NotebookEdit)
path=$(printf '%s' "$input" | grep -oE '"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')
[ -n "$path" ] || exit 0
path=$(realpath -m -- "$path" 2>/dev/null || printf '%s' "$path")

IFS=':' read -r -a entries <<< "$allow"
for entry in "${entries[@]}"; do
  [ -n "$entry" ] || continue
  entry=$(realpath -m -- "$entry" 2>/dev/null || printf '%s' "$entry")
  entry="${entry%/}"
  if [ "$path" = "$entry" ] || [[ "$path" == "$entry"/* ]]; then
    exit 0
  fi
done

echo "scope-writes: DENIED — $tool to '$path' is outside the allowed write scope ($allow). This run's writes are limited to those paths; delegate other changes or report the scope gap instead of working around it." >&2
exit 2
