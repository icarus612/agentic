#!/usr/bin/env bash
# workflow-setup.sh — create an isolated git worktree for a dev-workflow run.
#
# SYNOPSIS
#   workflow-setup.sh [--name <name>] [--base <branch>] [--type <type>]
#
# DESCRIPTION
#   Invoked by the dev-start skill (step 0), NOT a hook. Worktrees go in
#   .workflows/, or in CLAUDE_WORKFLOWS_DIR if that env var is set (via the
#   project's .claude/settings.json env block). Makes sure the dir is
#   gitignored and creates a worktree on branch <type>/<name> off the base
#   branch, where <type> is one of feature (default), bug, or hotfix.
#   Prints machine-readable WORKTREE/BRANCH/BASE lines.
#
# EXIT CODES
#   0 - worktree created
#   1 - precondition failed (not a repo, base unresolvable, path/branch exists)
set -uo pipefail

err() { echo "workflow-setup: $*" >&2; exit 1; }

# --- args ------------------------------------------------------------------
name=""
base=""
type="feature"
while [ $# -gt 0 ]; do
  case "$1" in
    --name) name="${2:-}"; shift 2 ;;
    --base) base="${2:-}"; shift 2 ;;
    --type) type="${2:-}"; shift 2 ;;
    *) err "unknown argument: $1 (usage: workflow-setup.sh [--name <name>] [--base <branch>] [--type <feature|bug|hotfix>])" ;;
  esac
done

# --- branch type: feature (default) | bug | hotfix -------------------------
case "$type" in
  feature|bug|hotfix) : ;;
  *) err "invalid --type '$type' (must be one of: feature, bug, hotfix)" ;;
esac

# --- repo root -------------------------------------------------------------
root=$(git rev-parse --show-toplevel 2>/dev/null) || err "not inside a git repository"
cd "$root"

# --- workflows dir: .workflows, or CLAUDE_WORKFLOWS_DIR if set --------------
wfdir="${CLAUDE_WORKFLOWS_DIR:-.workflows}"
case "$wfdir" in
  /*) : ;;                      # absolute
  *)  wfdir="$root/$wfdir" ;;   # relative to repo root
esac

# --- name: slugify or generate a unique one --------------------------------
if [ -n "$name" ]; then
  name=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')
  [ -n "$name" ] || err "--name produced an empty slug"
else
  name="run-$(date +%Y%m%d-%H%M%S)-$$"
fi

# --- base branch: --base → main → repo default -----------------------------
if [ -z "$base" ]; then
  if git rev-parse --verify -q main >/dev/null; then
    base="main"
  else
    base=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
  fi
fi
[ -n "$base" ] || err "cannot resolve a base branch (no 'main', no origin/HEAD) — pass --base <branch>"
git rev-parse --verify -q "$base" >/dev/null || err "base branch '$base' does not exist"

# --- gitignore the workflows dir --------------------------------------------
case "$wfdir" in
  "$root"/*)
    rel="${wfdir#"$root"/}"
    if ! grep -qxF "$rel/" "$root/.gitignore" 2>/dev/null; then
      { echo ""; echo "# dev-workflow worktrees (workflow-setup.sh)"; echo "$rel/"; } >> "$root/.gitignore"
    fi
    ;;
esac

# --- create the worktree ----------------------------------------------------
path="$wfdir/$name"
branch="$type/$name"
[ -e "$path" ] && err "worktree path already exists: $path (pick another --name)"
git rev-parse --verify -q "$branch" >/dev/null && err "branch already exists: $branch (pick another --name)"

mkdir -p "$wfdir"
git worktree add "$path" -b "$branch" "$base" >/dev/null || err "git worktree add failed"

echo "WORKTREE: $(cd "$path" && pwd)"
echo "BRANCH: $branch"
echo "BASE: $base"
echo "cd into the WORKTREE path above — all subsequent workflow phases run inside it."
