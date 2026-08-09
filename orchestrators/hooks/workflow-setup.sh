#!/usr/bin/env bash
# workflow-setup.sh — create an isolated git worktree for a dae-pipeline run.
#
# SYNOPSIS
#   workflow-setup.sh [--name <name>] [--base <branch>] [--type <type>] [--parent <branch>] [--reuse]
#
# DESCRIPTION
#   Invoked by orchestrator skills (the dae orchestrator and its workflows),
#   NOT a hook. Workflows dir and base branch both resolve via
#   resolve-config.sh (same dir), which checks CLAUDE_WORKFLOWS_DIR /
#   CLAUDE_BASE_BRANCH across project → global settings.json before falling
#   back to a local default (.workflows/, and a main/origin-HEAD git
#   heuristic respectively) — see the artifact-locations rule. Makes sure
#   the workflows dir is gitignored and creates a worktree on branch
#   <type>/<name> off the base branch, where <type> is one of feature
#   (default), bug, hotfix, docs, or sync.
#   For a PARENT worktree it also creates the run dir <worktree>/.artifacts/
#   (with contracts/ and reports/) and makes sure .gitignore carries an
#   .artifacts/ entry so it never reaches the product branch — see
#   run-artifacts. That entry must be COMMITTED to take effect inside a
#   worktree; if it is not yet committed on the start-point branch, a warning
#   says so. Child worktrees (--parent) get no run dir; they use the parent's.
#   With --parent <branch>, the worktree is cut off that branch instead of
#   the base branch — the parent/child scheme: an orchestrator's run
#   worktree sits on <type>/<name> off base, and each builder lane's child
#   worktree sits on <type>/<name>-l<n> off the parent (l<n> = the plan's
#   lane number; the BASE: output line then names the parent). The workflows
#   dir always resolves against the MAIN checkout, so children created from
#   inside the parent worktree land as its siblings, never nested in it.
#   With --reuse, an existing <type>/<name> branch is not an error: the
#   worktree is created on that branch and the start-point branch is merged
#   into it so the run starts up to date (merge conflicts abort the setup
#   cleanly).
#   Prints machine-readable WORKTREE/BRANCH/BASE/REUSED lines, plus RUNDIR
#   when a run dir was created (parent worktrees only).
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
parent=""
reuse=0
while [ $# -gt 0 ]; do
  case "$1" in
    --name) name="${2:-}"; shift 2 ;;
    --base) base="${2:-}"; shift 2 ;;
    --type) type="${2:-}"; shift 2 ;;
    --parent) parent="${2:-}"; shift 2 ;;
    --reuse) reuse=1; shift ;;
    *) err "unknown argument: $1 (usage: workflow-setup.sh [--name <name>] [--base <branch>] [--type <feature|bug|hotfix|docs|sync>] [--parent <branch>] [--reuse])" ;;
  esac
done
[ -n "$parent" ] && [ -n "$base" ] && err "--parent and --base are mutually exclusive (--parent IS the start point)"

# --- branch type: feature (default) | bug | hotfix | docs | sync -----------
case "$type" in
  feature|bug|hotfix|docs|sync) : ;;
  *) err "invalid --type '$type' (must be one of: feature, bug, hotfix, docs, sync)" ;;
esac

# --- repo root: the MAIN checkout, never the current worktree ---------------
# Inside a worktree, --show-toplevel returns the worktree — resolving the
# workflows dir against it would NEST a child inside its parent (and pollute
# the parent branch's .gitignore). The main checkout is dirname of the common
# git dir, from anywhere in the repo.
git rev-parse --git-dir >/dev/null 2>&1 || err "not inside a git repository"
root=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
cd "$root"

# --- workflows dir: resolve-config.sh (CLAUDE_WORKFLOWS_DIR chain, default .workflows) ---
hookdir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
wfdir=$("$hookdir/resolve-config.sh" CLAUDE_WORKFLOWS_DIR --default .workflows --root "$root") \
  || err "cannot resolve workflows dir"
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

# --- start point: --parent → --base → resolve-config.sh (CLAUDE_BASE_BRANCH chain) ---
if [ -n "$parent" ]; then
  base="$parent"
elif [ -z "$base" ]; then
  base=$("$hookdir/resolve-config.sh" CLAUDE_BASE_BRANCH --base-branch-default --root "$root") \
    || err "cannot resolve a base branch (no CLAUDE_BASE_BRANCH in settings, no 'main', no origin/HEAD) — pass --base <branch>"
fi
git rev-parse --verify -q "$base" >/dev/null || err "start-point branch '$base' does not exist"

# --- gitignore the workflows dir --------------------------------------------
case "$wfdir" in
  "$root"/*)
    rel="${wfdir#"$root"/}"
    if ! grep -qxF "$rel/" "$root/.gitignore" 2>/dev/null; then
      { echo ""; echo "# dae-pipeline worktrees (workflow-setup.sh)"; echo "$rel/"; } >> "$root/.gitignore"
    fi
    ;;
esac

# --- gitignore the run dir ---------------------------------------------------
# The run dir lives INSIDE the worktree (<worktree>/.artifacts/), so the
# workflows-dir entry above does not cover it: that entry hides the worktree
# from the MAIN checkout, while the run dir has to be ignored from within a
# CHECKOUT of the product branch.
#
# That means the entry must be COMMITTED to .gitignore — a worktree checks out
# a commit, and an uncommitted append is not in it (see the warning below).
# Deliberately NOT the common dir's info/exclude: that file is repo-global, so
# it would apply a branch-specific rule to every branch in the repo.
if ! grep -qxF ".artifacts/" "$root/.gitignore" 2>/dev/null; then
  { echo ""; echo "# dae-pipeline run dirs, inside each worktree (workflow-setup.sh)"; echo ".artifacts/"; } >> "$root/.gitignore"
fi

# The worktree below checks out "$base". If the entry is not committed THERE,
# the run dir will show as untracked inside the new worktree and can be swept
# into the product branch by a straggler commit. Warn loudly; do not commit to
# the start-point branch on the user's behalf.
if ! git show "$base:.gitignore" 2>/dev/null | grep -qxF ".artifacts/"; then
  echo "workflow-setup: WARNING — '.artifacts/' is not in .gitignore as committed on '$base'." >&2
  echo "workflow-setup:   The run dir will show as UNTRACKED inside the new worktree until" >&2
  echo "workflow-setup:   you commit it. The line has been added to $root/.gitignore —" >&2
  echo "workflow-setup:   commit that, then future worktrees inherit it automatically." >&2
fi

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

# --- create the run dir (parent worktrees only) ------------------------------
# Per the run-artifacts rule the run dir belongs to the PARENT worktree alone;
# a builder's child worktree (--parent) never gets one — it is handed the
# parent's paths for its contract and exit report.
rundir=""
if [ -z "$parent" ]; then
  rundir="$path/.artifacts"
  mkdir -p "$rundir/contracts" "$rundir/reports"
fi

echo "WORKTREE: $(cd "$path" && pwd)"
echo "BRANCH: $branch"
echo "BASE: $base"
echo "REUSED: $reused"
[ -n "$rundir" ] && echo "RUNDIR: $(cd "$rundir" && pwd)"
echo "cd into the WORKTREE path above — all subsequent workflow phases run inside it."
