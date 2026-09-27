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

# --- chat-run marker: progress-log.md only, never dae-role -----------------
# In-repo resolutions (rung 1-configured-in-repo, or rung 2) additionally
# seed <repo_root>/.artifacts/progress-log.md, only if absent, so
# scope-writes.sh/parent-tree-guard.sh's find_parent_worktree sees this repo
# root as marked and land the run on the "absent role" fallback -- today's
# permissive 3-root allow (artifacts_root/plans_root/docs_root) -- which
# correctly covers this run's own writes under
# $repo_root/.artifacts/reports/<slug>-<runid>/. Idempotent by design: never
# overwrite, so concurrent/sequential chat runs against the same repo never
# stomp each other's log, and a repo root that happens to already be a real
# dae parent worktree never has its genuine progress log clobbered.
# Deliberately does NOT write .artifacts/dae-role: an "orchestrator" marker
# would, per scope-writes.sh's role table, restrict writes to ONLY
# *-review.md/sync-report.md under plans_root -- which would wrongly block
# this run's own scratch-dir writes. Leaving dae-role unset is correct, not
# an oversight. Rung 3 (outside any git repo) gets no marker at all -- there
# is no product tree to protect there. Failure to seed the marker is a
# courtesy miss, never fatal -- this script's job (resolving/creating
# scratchdir) is already done above.
if [ "$in_repo" = 1 ]; then
  marker_dir="$repo_root/.artifacts"
  marker_log="$marker_dir/progress-log.md"
  if [ ! -e "$marker_log" ]; then
    mkdir -p "$marker_dir" 2>/dev/null && {
      printf '%s\n' \
        "# Chat/report scratch marker" \
        "" \
        "(not a dae run; see .artifacts/reports/)" \
        > "$marker_log" 2>/dev/null
    } || true
  fi
fi

echo "SCRATCHDIR: $scratchdir"
echo "RUNID: $runid"
echo "resolve-scratch: resolved via $source_phrase" >&2
