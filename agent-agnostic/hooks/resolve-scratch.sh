#!/usr/bin/env bash
# resolve-scratch.sh — resolve the report scratch dir for a ship: chat run.
#
# SYNOPSIS
#   resolve-scratch.sh --slug <slug> [--runid <id>] [--root <path>]
#
# DESCRIPTION
#   A `ship: chat` report run has no branch and no worktree, therefore no
#   run dir (agent-agnostic/skills/dae/report.md). Its explore map, committee
#   claim files, and report land in a scratch dir instead, resolved across
#   three rungs, first hit wins:
#     1. CLAUDE_SCRATCH_DIR, read via resolve-config.sh (the four-scope
#        settings chain), normalized to an absolute path.
#     2. Inside a git repo: <main-checkout-root>/.artifacts/reports/.
#     3. Otherwise: ${XDG_CACHE_HOME:-$HOME/.cache}/dae/reports/.
#   Every resolved path is suffixed <slug>-<runid>, where <runid> defaults
#   to a per-process-unique id ($(date +%Y%m%d-%H%M%S)-$$) so the same
#   question run twice concurrently, or the same question run from two
#   different repos, never collide on the same directory — the two live
#   bugs this script replaces prose with code to fix. --runid lets a test
#   pin an exact path; it is not for orchestrator use.
#   No jq dependency: the settings chain is read by resolve-config.sh,
#   which uses only awk/sed/grep against Claude Code's flat env block.
#
# EXIT CODES
#   0 - resolved and created (path on stdout; resolution source on stderr)
#   1 - bad usage, or the directory could not be created
set -uo pipefail

err() { echo "resolve-scratch: $*" >&2; exit 1; }

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}

slug_raw=""; have_slug=0
runid=""; have_runid=0
root=""

while [ $# -gt 0 ]; do
  case "$1" in
    --slug)
      [ $# -ge 2 ] || err "--slug requires a value"
      slug_raw="$2"; have_slug=1; shift 2 ;;
    --runid)
      [ $# -ge 2 ] || err "--runid requires a value"
      runid="$2"; have_runid=1; shift 2 ;;
    --root)
      [ $# -ge 2 ] || err "--root requires a value"
      root="$2"; shift 2 ;;
    -*) err "unknown flag: $1" ;;
    *) err "unexpected argument: $1 (usage: resolve-scratch.sh --slug <slug> [--runid <id>] [--root <path>])" ;;
  esac
done

[ "$have_slug" = 1 ] || err "--slug is required (usage: resolve-scratch.sh --slug <slug> [--runid <id>] [--root <path>])"
slug=$(slugify "$slug_raw")
[ -n "$slug" ] || err "--slug produced an empty slug"

if [ "$have_runid" = 1 ]; then
  [ -n "$runid" ] || err "--runid must not be empty"
  case "$runid" in
    */*) err "--runid must be a single path segment (no '/')" ;;
  esac
else
  runid="$(date +%Y%m%d-%H%M%S)-$$"
fi

hookdir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# --- is cwd inside a git repo, and if so its MAIN checkout root ------------
# --git-common-dir, not --show-toplevel: from inside a linked worktree,
# --show-toplevel returns the worktree, which would scatter scratch dirs
# into whichever worktree happened to be current. --git-common-dir always
# points at the main checkout's .git, regardless of which worktree is cwd.
in_repo=0; repo_root=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  in_repo=1
  repo_root=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
  repo_root="${repo_root%/}"
fi

# --- rung 1: the configured var --------------------------------------------
# No --default: an unresolvable var must fall through to rung 2/3, not
# error. resolve-config.sh prints its own "cannot resolve" line on stderr
# on failure, and a fall-through here is normal operation, so that stderr
# is suppressed rather than surfaced.
rc_args=(CLAUDE_SCRATCH_DIR)
[ -n "$root" ] && rc_args+=(--root "$root")

configured=""
if configured=$("$hookdir/resolve-config.sh" "${rc_args[@]}" 2>/dev/null) && [ -n "$configured" ]; then
  case "$configured" in
    "~/"*) configured="$HOME/${configured#\~/}" ;;
    /*) : ;;
    *)
      if [ "$in_repo" = 1 ]; then
        configured="$repo_root/$configured"
      else
        configured="$PWD/$configured"
      fi
      ;;
  esac
  base_dir="${configured%/}"
  source_phrase="configured var"
elif [ "$in_repo" = 1 ]; then
  # --- rung 2: inside a git repo ---
  base_dir="$repo_root/.artifacts/reports"
  source_phrase="git repo root"
else
  # --- rung 3: not a repo ---
  case "${XDG_CACHE_HOME:-}" in
    /*) cachedir="${XDG_CACHE_HOME%/}" ;;
    *) cachedir="$HOME/.cache" ;;
  esac
  base_dir="$cachedir/dae/reports"
  source_phrase="cache fallback"
fi

scratchdir="$base_dir/$slug-$runid"

mkdir -p "$scratchdir" || err "could not create scratch dir: $scratchdir"

echo "SCRATCHDIR: $scratchdir"
echo "RUNID: $runid"
echo "resolve-scratch: resolved via $source_phrase" >&2
