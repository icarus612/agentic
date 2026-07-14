#!/usr/bin/env bash
# resolve-config.sh — resolve one CLAUDE_* config var across settings scopes.
#
# SYNOPSIS
#   resolve-config.sh <VAR_NAME> [--default <value> | --base-branch-default] [--root <path>]
#
# DESCRIPTION
#   Claude Code's `env` block does NOT deep-merge across settings.json
#   scopes — a higher-precedence file's `env` block wholesale-replaces a
#   lower one, not per key (code.claude.com/docs/en/configuration.md). A
#   project settings.json that sets ANY env var can silently hide a
#   global-only value for a key it never mentions, so the inherited
#   process $VAR is not a reliable fallback chain. This script reads the
#   settings JSON files directly instead, in this order (first scope that
#   DEFINES the key wins):
#     1. <root>/.claude/settings.local.json   env.<VAR_NAME>
#     2. <root>/.claude/settings.json         env.<VAR_NAME>
#     3. ~/.claude/settings.json              env.<VAR_NAME>
#     4. --default <value>, or (--base-branch-default) a git heuristic:
#        'main' if it exists, else the short name of origin/HEAD.
#
#   No jq dependency, matching this repo's other hooks (record-changed.sh,
#   test-changed.sh, workflow-diff-check.sh) — the `env` block is Claude
#   Code's documented flat "KEY": "value" string-pair schema, so grep/sed
#   is enough without a JSON parser.
#
# EXIT CODES
#   0 - resolved (value on stdout; source noted on stderr)
#   1 - unresolvable, or bad usage
set -uo pipefail

err() { echo "resolve-config: $*" >&2; exit 1; }

var=""; default=""; have_default=0; base_branch_mode=0; root=""
while [ $# -gt 0 ]; do
  case "$1" in
    --default) default="${2:-}"; have_default=1; shift 2 ;;
    --base-branch-default) base_branch_mode=1; shift ;;
    --root) root="${2:-}"; shift 2 ;;
    -*) err "unknown flag: $1" ;;
    *) [ -z "$var" ] || err "unexpected argument: $1 (usage: resolve-config.sh <VAR_NAME> [--default <value> | --base-branch-default] [--root <path>])"; var="$1"; shift ;;
  esac
done
[ -n "$var" ] || err "usage: resolve-config.sh <VAR_NAME> [--default <value> | --base-branch-default] [--root <path>]"
[ "$have_default" = 1 ] && [ "$base_branch_mode" = 1 ] && err "--default and --base-branch-default are mutually exclusive"

[ -n "$root" ] || root=$(git rev-parse --show-toplevel 2>/dev/null) || root="$PWD"

# --- extract env.<key> from a settings JSON file, no jq --------------------
env_value_from() { # env_value_from <file> <key>
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  awk 'BEGIN{RS="}"} /"env"[ \t]*:[ \t]*\{/{print; exit}' "$file" \
    | grep -oE "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 \
    | sed -E "s/^\"$key\"[[:space:]]*:[[:space:]]*\"(.*)\"\$/\1/"
}

resolved=""; source=""
for f in "$root/.claude/settings.local.json" "$root/.claude/settings.json" "$HOME/.claude/settings.json"; do
  v=$(env_value_from "$f" "$var" 2>/dev/null) || continue
  if [ -n "$v" ]; then resolved="$v"; source="$f"; break; fi
done

if [ -z "$resolved" ]; then
  if [ "$base_branch_mode" = 1 ]; then
    if git -C "$root" rev-parse --verify -q main >/dev/null 2>&1; then
      resolved="main"
    else
      resolved=$(git -C "$root" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
    fi
    source="git heuristic (main, else origin/HEAD)"
  elif [ "$have_default" = 1 ]; then
    resolved="$default"
    source="supplied default"
  fi
fi

[ -n "$resolved" ] || err "cannot resolve $var (no settings.local.json/settings.json/global settings.json value, and no usable default)"

echo "$resolved"
echo "resolve-config: $var resolved to '$resolved' (source: $source)" >&2
