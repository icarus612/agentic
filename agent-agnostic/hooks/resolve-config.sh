#!/usr/bin/env bash
# resolve-config.sh — resolve one CLAUDE_* config var across settings scopes.
#
# SYNOPSIS
#   resolve-config.sh <VAR_NAME> [--default <value> | --base-branch-default] [--root <path>] [--expect path|publish-target]
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
#     1. <root>/.agents/settings.local.json (or .claude/)    env.<VAR_NAME>
#     2. <root>/.agents/settings.json (or .claude/)          env.<VAR_NAME>
#     3. ~/.claude/settings.json (or ~/.gemini/config/)      env.<VAR_NAME>
#     4. --default <value>, or (--base-branch-default) 'dev' globally.
#
#   No jq dependency, matching this repo's other hooks (record-changed.sh,
#   test-changed.sh, workflow-diff-check.sh) — the `env` block is Claude
#   Code's documented flat "KEY": "value" string-pair schema, so grep/sed
#   is enough without a JSON parser.
#
#   --expect path|publish-target validates the RESOLVED value (whichever
#   rung produced it — a settings file, --default, or --base-branch-default)
#   after resolution succeeds. It is purely additive: omit it and behavior
#   is unchanged. A value is treated as scheme-prefixed (a URL or a
#   `<scheme>:...` target, never a local path) iff it matches the anchored
#   ERE `^[A-Za-z][A-Za-z0-9+.-]+:` — note the scheme is two or more
#   characters, so a single-letter prefix such as a Windows drive letter
#   (`C:\Users\...`) is a path, not a scheme.
#     --expect path            reject a scheme-prefixed value; the local
#                               docs tree must be a filesystem path, and a
#                               Confluence-style location belongs in a
#                               separate publish-target var instead.
#     --expect publish-target  accept only an Atlassian wiki URL
#                               (https://<site>.atlassian.net/wiki/...) or a
#                               `<scheme>:<non-empty-tail>` value whose
#                               scheme is one of $PUBLISH_SCHEMES.
#   One documented ambiguity: a RELATIVE path whose first segment contains
#   a colon before any `/` (e.g. `do:cs/x`) is indistinguishable from a
#   scheme by shape alone and is read as a scheme, the same convention
#   scp/git use. Write such a path as `./do:cs/x`, or absolutely, to name
#   it as a path.
#
# EXIT CODES
#   0 - resolved (value on stdout; source noted on stderr)
#   1 - unresolvable, bad usage, or (with --expect) the resolved value does
#       not match the expected shape
set -uo pipefail

err() { echo "resolve-config: $*" >&2; exit 1; }

# --- --expect vocabulary and known publish schemes, held as data so error
#     messages are built from them rather than typed as literals -----------
EXPECT_VOCAB="path|publish-target"
PUBLISH_SCHEMES="confluence"      # space-separated; the error message is built from this

var=""; default=""; have_default=0; base_branch_mode=0; root=""; expect=""
while [ $# -gt 0 ]; do
  case "$1" in
    --default) default="${2:-}"; have_default=1; shift 2 ;;
    --base-branch-default) base_branch_mode=1; shift ;;
    --root) root="${2:-}"; shift 2 ;;
    --expect)
      if [ $# -lt 2 ]; then
        err "--expect requires a value (expected: $EXPECT_VOCAB)"
      fi
      expect="$2"; shift 2 ;;
    -*) err "unknown flag: $1" ;;
    *) [ -z "$var" ] || err "unexpected argument: $1 (usage: resolve-config.sh <VAR_NAME> [--default <value> | --base-branch-default] [--root <path>] [--expect path|publish-target])"; var="$1"; shift ;;
  esac
done
[ -n "$var" ] || err "usage: resolve-config.sh <VAR_NAME> [--default <value> | --base-branch-default] [--root <path>] [--expect path|publish-target]"
[ "$have_default" = 1 ] && [ "$base_branch_mode" = 1 ] && err "--default and --base-branch-default are mutually exclusive"
if [ -n "$expect" ] && [ "$expect" != "path" ] && [ "$expect" != "publish-target" ]; then
  err "unknown --expect value: $expect (expected: $EXPECT_VOCAB)"
fi

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

# --- scheme-vs-path discrimination, shared by both --expect arms -----------
is_scheme_prefixed() { # is_scheme_prefixed <value>
  [[ "$1" =~ ^[A-Za-z][A-Za-z0-9+.-]+: ]]
}

scheme_of() { # scheme_of <value> — prints the scheme; caller must have
              # already confirmed is_scheme_prefixed
  [[ "$1" =~ ^([A-Za-z][A-Za-z0-9+.-]+): ]] && printf '%s' "${BASH_REMATCH[1]}"
}

resolved=""; source=""
for f in "$root/.agents/settings.local.json" "$root/.claude/settings.local.json" \
         "$root/.agents/settings.json" "$root/.claude/settings.json" \
         "$HOME/.claude/settings.json" "$HOME/.gemini/config/settings.json"; do
  v=$(env_value_from "$f" "$var" 2>/dev/null) || continue
  if [ -n "$v" ]; then resolved="$v"; source="$f"; break; fi
done

if [ -z "$resolved" ]; then
  if [ "$base_branch_mode" = 1 ]; then
    resolved="dev"
    source="global default (dev)"
  elif [ "$have_default" = 1 ]; then
    resolved="$default"
    source="supplied default"
  fi
fi

[ -n "$resolved" ] || err "cannot resolve $var (no settings.local.json/settings.json/global settings.json value, and no usable default)"

if [ "$expect" = "path" ]; then
  if is_scheme_prefixed "$resolved"; then
    err "$var must be a local path; a Confluence location belongs in CLAUDE_DOCS_PUBLISH (got: '$resolved')"
  fi
elif [ "$expect" = "publish-target" ]; then
  ok=0
  if [[ "$resolved" =~ ^https://[A-Za-z0-9.-]+\.atlassian\.net/wiki/ ]]; then
    ok=1
  elif is_scheme_prefixed "$resolved"; then
    scheme=$(scheme_of "$resolved")
    tail="${resolved#*:}"
    if [ -n "$tail" ]; then
      for s in $PUBLISH_SCHEMES; do
        if [ "$scheme" = "$s" ]; then ok=1; break; fi
      done
    fi
  fi
  if [ "$ok" != 1 ]; then
    schemes_list=""
    for s in $PUBLISH_SCHEMES; do
      if [ -z "$schemes_list" ]; then schemes_list="$s:"; else schemes_list="$schemes_list, $s:"; fi
    done
    err "$var must name a known publish target: an Atlassian wiki URL (https://<site>.atlassian.net/wiki/...), or one of these schemes: $schemes_list (got: '$resolved')"
  fi
fi

echo "$resolved"
echo "resolve-config: $var resolved to '$resolved' (source: $source)" >&2
