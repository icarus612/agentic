#!/usr/bin/env bash
# workflow-setup.sh — create an isolated git worktree for a dev-workflow run.
#
# SYNOPSIS
#   workflow-setup.sh [--name <name>] [--base <branch>] [--type <type>] [--reuse]
#
# DESCRIPTION
#   Invoked by orchestrator skills (dev-start, dev-map), NOT a hook. Worktrees
#   go in .workflows/, or in CLAUDE_WORKFLOWS_DIR if that env var is set (via
#   the project's .claude/settings.json env block). Makes sure the dir is
#   gitignored and creates a worktree on branch <type>/<name> off the base
#   branch, where <type> is one of feature (default), bug, or hotfix.
#   With --reuse, an existing <type>/<name> branch is not an error: the
#   worktree is created on that branch and the base branch is merged into it
#   so the run starts up to date (merge conflicts abort the setup cleanly).
#   Prints machine-readable WORKTREE/BRANCH/BASE/REUSED lines.
#
# EXIT CODES
#   0 - worktree created
#   1 - precondition failed (not a repo, base unresolvable, path exists,
#       branch exists without --reuse, merge conflict on --reuse)
set -uo pipefail

err() { echo "workflow-setup: $*" >&2; exit 1; }

# --- args ------------------------------------------------------------------
name=""
base=""
type="feature"
reuse=0
while [ $# -gt 0 ]; do
  case "$1" in
    --name) name="${2:-}"; shift 2 ;;
    --base) base="${2:-}"; shift 2 ;;
    --type) type="${2:-}"; shift 2 ;;
    --reuse) reuse=1; shift ;;
    *) err "unknown argument: $1 (usage: workflow-setup.sh [--name <name>] [--base <branch>] [--type <feature|bug|hotfix>] [--reuse])" ;;
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

reused=no
mkdir -p "$wfdir"
if git rev-parse --verify -q "$branch" >/dev/null; then
  [ "$reuse" = 1 ] || err "branch already exists: $branch (pick another --name, or pass --reuse to update it from the base branch)"
  git worktree add "$path" "$branch" >/dev/null || err "git worktree add failed (is '$branch' checked out elsewhere?)"
  if ! git -C "$path" merge --no-edit "$base" >/dev/null 2>&1; then
    git -C "$path" merge --abort >/dev/null 2>&1
    git worktree remove "$path" >/dev/null 2>&1
    err "merging '$base' into '$branch' hit conflicts — resolve them manually, then re-run"
  fi
  reused=yes
else
  git worktree add "$path" -b "$branch" "$base" >/dev/null || err "git worktree add failed"
fi

echo "WORKTREE: $(cd "$path" && pwd)"
echo "BRANCH: $branch"
echo "BASE: $base"
echo "REUSED: $reused"
echo "cd into the WORKTREE path above — all subsequent workflow phases run inside it."
