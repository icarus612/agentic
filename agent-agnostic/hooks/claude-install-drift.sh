#!/usr/bin/env bash
# claude-install-drift.sh — warn when the ~/.claude install and the agentic
# source drift apart.
#
# WHY
#   The agentic repo is the SOURCE; ~/.claude is an INSTALL produced from it by
#   agent-agnostic/hooks/sync-install.sh. Nothing enforces that direction, so two
#   mistakes are easy and both lose work silently:
#
#     1. Editing ~/.claude/hooks/foo.sh directly. It works immediately, so the
#        mistake is invisible — until the next sync-install.sh run overwrites it
#        from the source and the change is gone.
#     2. Editing agent-agnostic/hooks/foo.sh in the repo and not syncing. The source is
#        correct but the running install is stale, so the fix appears not to work.
#
# WHAT IT DOES
#   PostToolUse on Edit|Write|MultiEdit. Resolves the counterpart of the edited
#   file across the source/install boundary and, if the two differ, prints the
#   exact command to reconcile them. ADVISORY ONLY — exits 0 always. Editing the
#   install directly is legitimate while debugging; the point is that you should
#   not do it by accident.
#
#   Mapping mirrors sync-install.sh, which owns the real thing:
#     agent-agnostic/hooks/<f>   <-> ~/.claude/hooks/<f>
#     agent-agnostic/rules/<f>   <-> ~/.claude/rules/<f>
#     agent-agnostic/skills/<n>/ <-> ~/.claude/skills/<n>/
#     agent-agnostic/agents/<f>  <-> ~/.claude/agents/<f>
#
#   Never flagged: ~/.claude/settings.json and settings.local.json (user-owned,
#   deliberately not distributable — see the repo README), tool-based/ (tech-
#   bound, never synced), and the repo's own .claude/ (project-scoped).
#
# CONFIG
#   AGENTIC_REPO  path to the source checkout (default: $HOME/repos/agentic)
#   CLAUDE_HOME   path to the install        (default: $HOME/.claude)

set -uo pipefail

AGENTIC_REPO="${AGENTIC_REPO:-$HOME/repos/agentic}"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"

# Advisory hook: never block, never fail a tool call.
trap 'exit 0' ERR

[ -t 0 ] && exit 0
input=$(cat 2>/dev/null) || exit 0
[ -n "$input" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
echo "$input" | jq . >/dev/null 2>&1 || exit 0

file=$(echo "$input" | jq -r '(.tool_input.file_path // .arguments.TargetFile) // empty')
[ -n "$file" ] || exit 0

# Normalise without requiring the file to still exist.
abs() {
  local d b
  d=$(dirname "$1"); b=$(basename "$1")
  d=$(cd "$d" 2>/dev/null && pwd) || return 1
  printf '%s/%s' "$d" "$b"
}
file=$(abs "$file") || exit 0

note() {
  echo "" >&2
  echo "🔗 agentic/install drift — $1" >&2
  shift
  for line in "$@"; do echo "   $line" >&2; done
  echo "" >&2
}

# --- install -> source ------------------------------------------------------
case "$file" in
  "$CLAUDE_HOME"/settings.json|"$CLAUDE_HOME"/settings.local.json)
    exit 0 ;;                                   # user-owned, no counterpart
  "$CLAUDE_HOME"/hooks/*|"$CLAUDE_HOME"/rules/*|"$CLAUDE_HOME"/skills/*|"$CLAUDE_HOME"/agents/*)
    rel="${file#"$CLAUDE_HOME"/}"               # e.g. hooks/smart-lint.sh
    kind="${rel%%/*}"                           # hooks | rules | skills | agents
    rest="${rel#*/}"

    src=""
    for top in agent-agnostic; do
      cand="$AGENTIC_REPO/$top/$kind/$rest"
      [ -e "$cand" ] && { src="$cand"; break; }
    done

    if [ -z "$src" ]; then
      note "edited the INSTALL; no source counterpart found" \
        "edited: $file" \
        "The agentic repo is the source of truth. If this file should be" \
        "distributable, add it under $AGENTIC_REPO/agent-agnostic/$kind/ — otherwise" \
        "the next sync-install.sh run will not know about it."
      exit 0
    fi

    if ! diff -q "$src" "$file" >/dev/null 2>&1; then
      note "edited the INSTALL, which sync-install.sh will overwrite" \
        "install: $file" \
        "source:  $src" \
        "Port the change to the source, then re-sync:" \
        "  cp '$file' '$src' && (cd '$AGENTIC_REPO' && git add -A && git commit && git push)"
    fi
    exit 0 ;;
esac

# --- source -> install ------------------------------------------------------
case "$file" in
  "$AGENTIC_REPO"/tool-based/*|"$AGENTIC_REPO"/.claude/*)
    exit 0 ;;                                   # never synced
  "$AGENTIC_REPO"/agent-agnostic/*)
    rel="${file#"$AGENTIC_REPO"/}"              # e.g. agent-agnostic/hooks/smart-lint.sh
    rest="${rel#*/}"                            # hooks/smart-lint.sh
    kind="${rest%%/*}"

    case "$kind" in
      hooks|rules|skills|agents) ;;
      *) exit 0 ;;                              # AGENTS.md, docs, scaffolding
    esac
    [ "$(basename "$file")" = "AGENTS.md" ] && exit 0

    dest="$CLAUDE_HOME/$rest"
    if [ ! -e "$dest" ] || ! diff -q "$file" "$dest" >/dev/null 2>&1; then
      note "source edited; the running install is now stale" \
        "source:  $file" \
        "install: $dest" \
        "The install is what actually runs. After pushing, sync it:" \
        "  (cd '$AGENTIC_REPO' && ./agent-agnostic/hooks/sync-install.sh)" \
        "Verify with: sync-install.sh --check"
    fi
    exit 0 ;;
esac

exit 0
