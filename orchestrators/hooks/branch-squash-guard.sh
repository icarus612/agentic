#!/usr/bin/env bash
# branch-squash-guard.sh — PreToolUse hook enforcing this user's two-mode
# branch policy (see push-policy):
#
#   MODE A — the repo has a 'dev' branch (the general/enterprise case):
#     - dev is the integration branch: branch FROM dev, PR INTO dev
#       remotely, always squash-merged.
#     - main is off-limits: never branch FROM main, never `git merge` INTO
#       main, never commit (or write-tool edit) directly on main, never
#       `git push` main — UNLESS CLAUDE_HOTFIX_MAIN_AUTHORIZED is set (see
#       below), an explicit, deliberate, per-hotfix opt-in, never implied.
#   MODE B — the repo has no 'dev' branch (this repo, daedalus-mono,
#     personal repos generally):
#     - main IS the integration branch: branch from main, squash-merge
#       locally, push main up. This is the original, simpler policy this
#       hook started as; it still applies verbatim when there is no dev.
#
#   Universal in BOTH modes, no exception, ever:
#     - never commit, or write-tool edit, directly on the integration
#       branch (dev in mode A, main in mode B)
#     - `git merge` into the integration branch, or an authorized hotfix
#       merge into main, must be --squash
#     - `gh pr merge` must be --squash
#     - force-push, in any form, is always denied
#
#   Mode is NOT a static config toggle — it is detected per invocation from
#   the target repo (see mode detection below), so the same installed hook
#   does the right thing in every repo it runs in.
#
# SYNOPSIS  (wired as a PreToolUse hook on Bash AND on the write tools
#            Write/Edit/MultiEdit/NotebookEdit for Claude Code; wired via
#            agy-hook-adapter.sh on run_command/write_to_file/
#            replace_file_content/multi_replace_file_content for
#            Antigravity. Reads the tool-call JSON on stdin.)
#
# MODE DETECTION
#   The integration branch is resolved via resolve-config.sh's
#   CLAUDE_BASE_BRANCH chain (--base-branch-default: dev if it exists
#   —local branch or origin/dev—, else main, else origin/HEAD's short
#   name), rooted at the MAIN repo (via --git-common-dir, so this behaves
#   the same whether invoked from the main checkout or a linked worktree).
#   Mode A is then simply: the resolved integration branch is NOT literally
#   "main", AND a branch actually named "main" exists in this repo (local
#   or origin/main) — i.e., main exists as a DISTINCT, separately-protected
#   branch. This also correctly covers an explicit CLAUDE_BASE_BRANCH
#   override (e.g. "develop") in a repo that also has a main branch.
#
# HOTFIX ESCAPE
#   CLAUDE_HOTFIX_MAIN_AUTHORIZED, resolved via the SAME resolve-config.sh
#   settings chain (never a bare inherited env var — see the
#   artifact-locations rule on why the process env is not a substitute),
#   defaulting to unset/0. Set it to 1/true/yes in a settings.local.json
#   env block for the duration of an authorized hotfix, then unset it — it
#   is deliberately a manual, visible, easy-to-forget-to-set toggle rather
#   than a standing permission, matching "the user explicitly authorized
#   it." When set, it lifts ONLY the four Mode-A main-specific prohibitions
#   (branch-from-main, merge-into-main, commit-on-main, push-main); it does
#   NOT lift force-push denial or the squash-required rule — an authorized
#   hotfix merge into main must still be --squash.
#
# DESCRIPTION
#   Conservative by design, matching this repo's other Bash-parsing
#   PreToolUse hooks (allow-workflow-cleanup.sh, scope-writes.sh): anything
#   this script cannot confidently reason about — command substitution, no
#   git repo, detached HEAD, an unresolvable base branch — gets NO OPINION
#   (exit 0) rather than a block. A wrongly-blocked command is worse than a
#   missed one here; the settings.json allow/deny/ask lists remain the real
#   backstop for Claude Code.
#
#   Chained commands (&&, ||, ;, |) are split on those operators (a plain
#   text split, not a real shell parser — same limitation as this repo's
#   other hooks) and each segment is checked independently.
#
#   Write-tool git context comes from the TARGET FILE's path, never from
#   the tool call's "cwd" — a session's shell cwd is unrelated to what path
#   a Write/Edit/write_to_file call targets. (An earlier version of this
#   hook used cwd for writes too and denied a legitimate write into an
#   unrelated feature-branch worktree because the session's shell happened
#   to be sitting on a DIFFERENT repo's main branch at the time — caught
#   live while building this hook, see the build report.) Shell commands
#   keep using cwd, since that IS the directory the command executes in.
#
#   KNOWN LIMITATION: `gh pr merge` cannot be checked against "is this PR
#   targeting main" from the command string alone (the target/base branch
#   isn't visible without hitting the GitHub API) — Mode A's main
#   protections apply only to local git operations (`git merge`, `git
#   push`, branch creation), not to `gh pr merge`. `gh pr merge` is still
#   always required to be --squash, in both modes, regardless of target.
#
# EXIT CODES
#   0 - allowed (or hook has no opinion)
#   2 - denied (stderr carries the reason, fed back to the model)
set -uo pipefail

input=$(cat 2>/dev/null || true)
[ -n "$input" ] || exit 0

# flat JSON field extraction, same style as allow-workflow-cleanup.sh /
# scope-writes.sh — no jq dependency. Works regardless of nesting depth
# (tool_input.command for Claude, arguments.command for the AGY-translated
# payload) since it just scans the whole payload text for the key.
field() {
  printf '%s' "$input" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" \
    | head -1 | sed -E "s/^\"$1\"[[:space:]]*:[[:space:]]*\"//; s/\"$//" \
    | sed -E 's/\\(["\\/])/\1/g'
}

deny() {
  echo "branch-squash-guard: DENIED — $1" >&2
  exit 2
}

tool=$(field tool_name)
[ -n "$tool" ] || exit 0

# ref_exists <root> <name> — true if <name> exists as a local branch or an
# origin-tracking branch (covers a worktree that hasn't locally checked out
# a branch that exists on the remote).
ref_exists() {
  git -C "$1" rev-parse --verify -q "refs/heads/$2" >/dev/null 2>&1 && return 0
  git -C "$1" rev-parse --verify -q "refs/remotes/origin/$2" >/dev/null 2>&1 && return 0
  return 1
}

# resolve_ctx <dir> — prints 4 lines (branch, integration-branch, mode_a
# 0/1, hotfix-authorized 0/1) for <dir>'s repo; returns non-zero (caller:
# no opinion) if branch/base can't be resolved.
resolve_ctx() {
  local dir="$1" common root branch base mode_a=0 hotfix=0 hv hookdir
  common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  root=$(dirname "$common")
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null) || return 1
  [ -n "$branch" ] && [ "$branch" != "HEAD" ] || return 1 # detached HEAD: no opinion
  hookdir=$(dirname "$0")
  base=$("$hookdir/resolve-config.sh" CLAUDE_BASE_BRANCH --base-branch-default --root "$root" 2>/dev/null) || return 1
  if [ "$base" != "main" ] && ref_exists "$root" main; then mode_a=1; fi
  hv=$("$hookdir/resolve-config.sh" CLAUDE_HOTFIX_MAIN_AUTHORIZED --default 0 --root "$root" 2>/dev/null)
  case "$hv" in 1 | [tT][rR][uU][eE] | [yY][eE][sS]) hotfix=1 ;; esac
  printf '%s\n%s\n%s\n%s\n' "$branch" "$base" "$mode_a" "$hotfix"
}

# merge_in_progress <dir> — true if <dir>'s worktree has a merge pending
# completion: SQUASH_MSG (a `git merge --squash` has staged changes, not
# yet committed — the "then git commit" half of the sanctioned squash-merge
# flow) or MERGE_HEAD (an ordinary merge mid-progress, e.g. an authorized
# Mode-A hotfix merge that hit conflicts). A commit made while either marker
# is present is COMPLETING that merge, not hand-authoring new work on the
# integration branch — the commit-on-integration-branch/commit-on-main
# denials below must not apply to it, or the "git merge --squash <branch>
# then git commit" flow push-policy.md itself documents dead-ends at its
# own second step.
#
# Resolved via `git rev-parse --path-format=absolute --git-path`, never a
# hand-built ".git/..." path: a worktree's ".git" is a FILE pointing
# elsewhere, and even where it's a real directory, SQUASH_MSG/MERGE_HEAD
# live in the per-worktree git-dir, not the shared common dir ($root, used
# elsewhere in this script for settings resolution) — building the path
# from $root would silently never match inside a worktree. <dir> here is
# always $cwd (the shell command's actual execution directory), which is
# the right context for a shell command exactly as established elsewhere
# in this file — this is NOT the write-tool cwd-vs-target-file case from
# an earlier round. --path-format=absolute is NOT optional: bare
# `--git-path` prints a path relative to THIS SCRIPT's own cwd, not to
# <dir> — caught live while building this fix (a manual `ls` against the
# bare relative output failed until absolute was added; the same silent
# mismatch would have made merge_in_progress() false-negative whenever the
# hook's own process cwd differs from <dir>, i.e. almost always).
merge_in_progress() {
  local dir="$1" p
  p=$(git -C "$dir" rev-parse --path-format=absolute --git-path SQUASH_MSG 2>/dev/null) && [ -f "$p" ] && return 0
  p=$(git -C "$dir" rev-parse --path-format=absolute --git-path MERGE_HEAD 2>/dev/null) && [ -f "$p" ] && return 0
  return 1
}

# --- write tools: no direct edits on the integration branch (either mode),
# and none on main specifically in Mode A unless hotfix-authorized ---------
case "$tool" in
  Write | Edit | MultiEdit | NotebookEdit | \
    write_to_file | *:write_to_file | \
    replace_file_content | *:replace_file_content | \
    multi_replace_file_content | *:multi_replace_file_content)
    target=$(field file_path)
    [ -n "$target" ] || target=$(field notebook_path)
    [ -n "$target" ] || target=$(field path)
    [ -n "$target" ] || target=$(field target_file)
    [ -n "$target" ] || exit 0 # can't locate the target — no opinion, never guess via cwd
    ctx=$(resolve_ctx "$(dirname "$target")") || exit 0
    { read -r branch; read -r base; read -r mode_a; read -r hotfix; } <<<"$ctx"
    if [ "$branch" = "$base" ]; then
      deny "file write to '$target' while its repo's HEAD is on the integration branch '$base' — branch first, commit and squash-merge back rather than editing '$base' directly."
    elif [ "$mode_a" = 1 ] && [ "$branch" = "main" ] && [ "$hotfix" != 1 ]; then
      deny "file write to '$target' while its repo's HEAD is on 'main' — this repo's integration branch is '$base', and main is off-limits unless an authorized hotfix (set CLAUDE_HOTFIX_MAIN_AUTHORIZED=1 to proceed)."
    fi
    exit 0
    ;;
esac

# --- shell commands: cwd IS the right context here (it's the directory the
# command actually executes in), unlike the write-tool case above -----------
case "$tool" in
  Bash | run_command | *:run_command) : ;;
  *) exit 0 ;;
esac

cwd=$(field cwd)
[ -n "$cwd" ] || cwd=$(pwd)
ctx=$(resolve_ctx "$cwd") || exit 0
{ read -r branch; read -r base; read -r mode_a; read -r hotfix; } <<<"$ctx"
on_base=0
[ "$branch" = "$base" ] && on_base=1
on_main_modeA=0
[ "$mode_a" = 1 ] && [ "$branch" = "main" ] && on_main_modeA=1

cmd=$(field command)
[ -n "$cmd" ] || exit 0

# command substitution can hide anything — no opinion rather than guess
case "$cmd" in
  *'$('* | *'`'*) exit 0 ;;
esac

# split on chain operators (plain text split, not a real shell parser)
segments=()
while IFS= read -r line; do
  segments+=("$line")
done < <(printf '%s\n' "$cmd" | sed -E 's/&&|\|\||;|\|/\n/g')

# branch_creation_start_point <tok...> — for a segment that creates a new
# branch (git checkout -b/-B, git switch -c/-C, git branch <name>, git
# worktree add ... -b/-B <name>), PRINTS the resolved start-point ref: the
# explicit one if given, else the CURRENT branch ($branch, a global set
# from resolve_ctx before the segment loop) — because with NO start-point
# argument, git cuts the new branch from HEAD, which is exactly the common,
# easy-to-miss way "branch from main" actually happens (HEAD already on
# main, plain `git checkout -b feature/x`, no explicit "main" anywhere in
# the command to grep for). Prints nothing and returns 1 if this segment
# doesn't create a branch at all (list/delete/rename forms, or a non-git
# command). git's own grammar fixes argument order for these forms, so
# fixed-position checks are safe; flags interleaved in unusual orders are a
# known, accepted gap — no opinion, not a false deny.
branch_creation_start_point() {
  local a=("$@") n="${#a[@]}"
  [ "${a[0]:-}" = "git" ] || return 1
  case "${a[1]:-}" in
    checkout | switch)
      case "${a[2]:-}" in
        -b | -B | -c | -C)
          if [ -n "${a[4]:-}" ]; then printf '%s\n' "${a[4]}"; else printf '%s\n' "$branch"; fi
          return 0
          ;;
      esac
      ;;
    branch)
      case "${a[2]:-}" in -*) return 1 ;; esac # delete/rename/list flags: not creation
      [ -n "${a[2]:-}" ] || return 1           # bare "git branch": lists, doesn't create
      if [ -n "${a[3]:-}" ]; then printf '%s\n' "${a[3]}"; else printf '%s\n' "$branch"; fi
      return 0
      ;;
    worktree)
      [ "$n" -ge 3 ] && [ "${a[2]:-}" = "add" ] || return 1
      case "${a[$((n - 2))]:-}" in
        -b | -B)
          # NAME is the very last token => no explicit start point given
          printf '%s\n' "$branch"
          return 0
          ;;
      esac
      local i has_bflag=0
      for ((i = 3; i < n; i++)); do
        case "${a[i]}" in -b | -B) has_bflag=1 ;; esac
      done
      [ "$has_bflag" = 1 ] || return 1 # no -b/-B at all: not creating a branch
      printf '%s\n' "${a[$((n - 1))]}"
      return 0
      ;;
  esac
  return 1
}

for raw in "${segments[@]}"; do
  # shellcheck disable=SC2206
  toks=($raw)
  [ "${#toks[@]}" -ge 1 ] || continue

  # force-push, any form — denied regardless of branch/mode/hotfix (defense
  # in depth; settings.json already denies this for Claude, but Antigravity
  # has no equivalent permission system, so this hook is its only backstop)
  if [ "${toks[0]:-}" = "git" ] && [ "${toks[1]:-}" = "push" ]; then
    for t in "${toks[@]:2}"; do
      case "$t" in
        --force | --force=* | --force-with-lease | --force-with-lease=* | --force-if-includes | --force-if-includes=*)
          deny "force-push in any form is never allowed ('${toks[*]}')."
          ;;
        -f) deny "force-push in any form is never allowed ('${toks[*]}')." ;;
        --*) : ;; # other long flags: not force
        -*) case "$t" in *f*) deny "force-push in any form is never allowed ('${toks[*]}')." ;; esac ;;
      esac
    done

    # Mode A: pushing main specifically is off-limits unless hotfix-authorized
    if [ "$mode_a" = 1 ] && [ "$hotfix" != 1 ]; then
      nonflag=()
      for t in "${toks[@]:2}"; do
        case "$t" in -*) : ;; *) nonflag+=("$t") ;; esac
      done
      push_touches_main=0
      if [ "${#nonflag[@]}" -le 1 ]; then
        [ "$branch" = "main" ] && push_touches_main=1
      else
        for t in "${nonflag[@]:1}"; do
          case "$t" in
            main | *:main) push_touches_main=1 ;;
          esac
        done
      fi
      if [ "$push_touches_main" = 1 ]; then
        deny "git push touching 'main' — this repo's integration branch is '$base', and main is off-limits unless an authorized hotfix (set CLAUDE_HOTFIX_MAIN_AUTHORIZED=1 to proceed) ('${toks[*]}')."
      fi
    fi
  fi

  # Mode A: branching FROM main is off-limits unless hotfix-authorized —
  # covers BOTH an explicit start-point of main/origin/main AND the
  # implicit case (no start-point given, HEAD already on main).
  if [ "$mode_a" = 1 ] && [ "$hotfix" != 1 ]; then
    sp=$(branch_creation_start_point "${toks[@]}") && case "$sp" in
      main | origin/main)
        deny "branching from 'main' — this repo's integration branch is '$base', and main is off-limits unless an authorized hotfix (set CLAUDE_HOTFIX_MAIN_AUTHORIZED=1 to proceed); branch from '$base' instead (e.g. 'git checkout -b <name> $base') ('${toks[*]}')."
        ;;
    esac
  fi

  if [ "${toks[0]:-}" = "git" ] && [ "${toks[1]:-}" = "commit" ]; then
    # A commit made while completing a merge (SQUASH_MSG/MERGE_HEAD present)
    # is NOT a hand-authored commit on the integration branch — it is the
    # second half of the sanctioned squash-merge flow (or, in Mode A, an
    # authorized hotfix merge's conflict-resolution commit). Applies
    # uniformly regardless of trailing flags (`-a`, `--amend`, etc.) — this
    # hook does not special-case those; whatever `git commit` variant
    # finishes an in-progress merge is treated the same as a plain commit.
    if ! merge_in_progress "$cwd"; then
      # commit while HEAD is on the integration branch — universal, no exception
      if [ "$on_base" = 1 ]; then
        deny "git commit while HEAD is on the integration branch '$base' — branch first, commit there, then squash-merge back."
      fi
      # commit while HEAD is on main, Mode A, not hotfix-authorized
      if [ "$on_main_modeA" = 1 ] && [ "$hotfix" != 1 ]; then
        deny "git commit while HEAD is on 'main' — this repo's integration branch is '$base', and main is off-limits unless an authorized hotfix (set CLAUDE_HOTFIX_MAIN_AUTHORIZED=1 to proceed)."
      fi
    fi
  fi

  if [ "${toks[0]:-}" = "git" ] && [ "${toks[1]:-}" = "merge" ]; then
    skip=0
    squashed=0
    for t in "${toks[@]:2}"; do
      case "$t" in
        --abort | --continue | --quit) skip=1 ;;
        --squash) squashed=1 ;;
      esac
    done
    if [ "$skip" = 0 ]; then
      if [ "$on_base" = 1 ]; then
        # merging into the integration branch — always requires squash
        [ "$squashed" = 1 ] || deny "non-squash merge into the integration branch '$base' ('${toks[*]}') — squash is universal for this user's repos; use 'git merge --squash <branch>' then commit."
      elif [ "$on_main_modeA" = 1 ]; then
        # merging into main, Mode A — off-limits unless hotfix-authorized,
        # and even then must still be squash
        if [ "$hotfix" != 1 ]; then
          deny "merge into 'main' — this repo's integration branch is '$base', and main is off-limits unless an authorized hotfix (set CLAUDE_HOTFIX_MAIN_AUTHORIZED=1 to proceed) ('${toks[*]}')."
        fi
        [ "$squashed" = 1 ] || deny "hotfix merge into 'main' ('${toks[*]}') must still be --squash — squash is universal for this user's repos, with no exception."
      fi
    fi
  fi

  # gh pr merge without --squash — denied regardless of branch/mode/hotfix
  # (squash is universal, no exception); target-branch awareness (is this
  # PR into main vs dev) is NOT checked — see the KNOWN LIMITATION note.
  if [ "${toks[0]:-}" = "gh" ] && [ "${toks[1]:-}" = "pr" ] && [ "${toks[2]:-}" = "merge" ]; then
    squashed=0
    for t in "${toks[@]:3}"; do
      case "$t" in
        --squash | --squash=*) squashed=1 ;;
      esac
    done
    if [ "$squashed" = 0 ]; then
      deny "gh pr merge without --squash ('${toks[*]}') — squash is universal for this user's repos; use 'gh pr merge --squash'."
    fi
  fi
done

exit 0
