#!/usr/bin/env bash
# plan-lifecycle.sh — move a plan through its states (proposal -> active ->
# completed) and check the plans dir's layout, all git-aware.
#
# SYNOPSIS
#   plan-lifecycle.sh <subcommand> [args] [--plans-dir <dir>] [--root <path>] [--dry-run]
#
#   locate <slug>                          state + path of a plan's spec of record
#   promote <proposal-file>                proposals/<slug>.md -> <slug>/plan.md
#   archive <plan-dir>                     <slug>/plan.md -> completed/<slug>.md, dir removed
#   supersede <plan-path> --by <successor> DELETE a plan that never shipped
#   reopen <completed-file>                completed/<slug>.md -> <slug>/plan.md
#   check [<path>]                         layout conformance of the plans dir (or one plan)
#
# DESCRIPTION
#   A "plan-id" is the full dated identifier <feature-slug>-MM-DD-YY (see
#   plan-format.md). Every <slug> in the subcommand table above means a
#   plan-id. The five known record kinds are exactly: story, plan-review,
#   code-review, pr-review, sync-report; plan.md is the spec of record and
#   is never called a "kind".
#
#   Flags may appear anywhere in the argument list, before or after the
#   subcommand's own positional args:
#     --plans-dir <dir>   use exactly this dir, no further normalization
#     --root <path>       repo root (default: `git rev-parse --show-toplevel`,
#                          else $PWD)
#     --dry-run           print what would happen; make zero mutations
#     --by <successor>    supersede only
#     --force-incomplete <reason>
#                         archive only; bypasses the completeness guard
#
#   Every destructive operation (git rm, plain rm, rmdir) refuses unless its
#   target resolves to the plans dir itself or a path under it. Moves and
#   removes prefer `git mv`/`git rm` when the path is tracked, falling back
#   to plain `mv`/`rm` otherwise. Nothing here ever runs `git commit`,
#   `git push`, or passes `--force`/`-f` to `git`/`rm` — this script mutates,
#   callers commit.
#
# EXIT CODES
#   0 - success (or, for `check`, zero layout violations)
#   1 - usage error, guard refusal, or (for `check`) one or more violations
set -uo pipefail

err() { echo "plan-lifecycle: $*" >&2; exit 1; }

hookdir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

KNOWN_KINDS="story plan-review code-review pr-review sync-report"
PLAN_ID_RE='^[A-Za-z0-9][A-Za-z0-9-]*-[0-9]{2}-[0-9]{2}-[0-9]{2}$'

# --- arg parsing: subcommand + positionals, flags anywhere ------------------
subcommand=""
positional=()
plans_dir_override=""
root_override=""
dry_run=0
by=""
force_incomplete_set=0
force_incomplete_reason=""

while [ $# -gt 0 ]; do
  case "$1" in
    --plans-dir) plans_dir_override="${2:-}"; shift 2 ;;
    --root) root_override="${2:-}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --by) by="${2:-}"; shift 2 ;;
    --force-incomplete) force_incomplete_set=1; force_incomplete_reason="${2:-}"; shift 2 ;;
    -*) err "unknown flag: $1" ;;
    *)
      if [ -z "$subcommand" ]; then subcommand="$1"; else positional+=("$1"); fi
      shift ;;
  esac
done

[ -n "$subcommand" ] || err "usage: plan-lifecycle.sh <subcommand> [args] [--plans-dir <dir>] [--root <path>] [--dry-run]"

# --- root + plans-dir resolution (verify-run-scope.sh's exact idiom) --------
if [ -n "$root_override" ]; then
  root="$root_override"
else
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root="$PWD"
fi

if [ -n "$plans_dir_override" ]; then
  plans_dir="$plans_dir_override"
else
  resolved=$("$hookdir/resolve-config.sh" CLAUDE_PROJECT_PLANS_DIR --default /project-plans/ --root "$root" 2>/dev/null) \
    || resolved="/project-plans/"
  rel=$(printf '%s' "$resolved" | sed -E 's#^\.?/##; s#/+$##')
  plans_dir="$root/$rel"
fi
proposals_dir="$plans_dir/proposals"
completed_dir="$plans_dir/completed"
plans_dir_abs=$(realpath -m -- "$plans_dir" 2>/dev/null || printf '%s' "$plans_dir")

# --- path-safety invariant (AC7) --------------------------------------------
require_under_plans_dir() { # <path>
  local abs
  abs=$(realpath -m -- "$1" 2>/dev/null || printf '%s' "$1")
  case "$abs" in
    "$plans_dir_abs"|"$plans_dir_abs"/*) : ;;
    *) err "refusing destructive operation outside plans dir: $1" ;;
  esac
}

# --- git-aware move/remove helper (shared, used everywhere) -----------------
is_tracked() { git -C "$root" ls-files --error-unmatch -- "$1" >/dev/null 2>&1; }

ensure_dir() { # <dir>
  if [ "$dry_run" = 1 ]; then echo "DRY-RUN: mkdir -p $1"; return 0; fi
  mkdir -p -- "$1" || err "mkdir failed: $1"
}

git_aware_mv() { # <src> <dst>
  if [ "$dry_run" = 1 ]; then echo "DRY-RUN: mv $1 -> $2"; return 0; fi
  if is_tracked "$1"; then
    git -C "$root" mv -- "$1" "$2" || err "git mv failed: $1 -> $2"
  else
    mv -- "$1" "$2" || err "mv failed: $1 -> $2"
  fi
}

git_aware_rm() { # <path> — single file
  require_under_plans_dir "$1"
  if [ "$dry_run" = 1 ]; then echo "DRY-RUN: rm $1"; return 0; fi
  if is_tracked "$1"; then
    git -C "$root" rm -q -- "$1" || err "git rm failed: $1"
  else
    rm -- "$1" || err "rm failed: $1"
  fi
}

git_aware_rm_dir() { # <dir> — whole tree (supersede only)
  require_under_plans_dir "$1"
  if [ "$dry_run" = 1 ]; then echo "DRY-RUN: rm -r $1"; return 0; fi
  local has_tracked
  has_tracked=$(git -C "$root" ls-files -- "$1")
  if [ -n "$has_tracked" ]; then
    git -C "$root" rm -q -r -- "$1" || err "git rm -r failed: $1"
  else
    rm -r -- "$1" || err "rm -r failed: $1"
  fi
}

remove_empty_dir() { # <dir> — plain rmdir, loudly fails if non-empty
  require_under_plans_dir "$1"
  if [ "$dry_run" = 1 ]; then echo "DRY-RUN: rmdir $1"; return 0; fi
  rmdir -- "$1" || err "rmdir failed (not empty?): $1"
}

insert_incomplete_note() { # <file> <reason> — insert after line 1
  local file="$1" reason="$2" tmp
  tmp=$(mktemp)
  { head -n1 "$file"; printf '> Archived incomplete: %s\n' "$reason"; tail -n +2 "$file"; } > "$tmp" \
    && mv -- "$tmp" "$file" || { [ -e "$tmp" ] && rm -- "$tmp"; err "failed to insert archived-incomplete note into $file"; }
}

# --- locate ------------------------------------------------------------------
cmd_locate() {
  local slug="${1:-}"
  [ -n "$slug" ] || err "usage: plan-lifecycle.sh locate <slug>"

  local states=() paths=()
  if [ -f "$proposals_dir/$slug.md" ]; then
    states+=("proposal"); paths+=("$proposals_dir/$slug.md")
  fi
  if [ -d "$plans_dir/$slug" ]; then
    if [ -f "$plans_dir/$slug/plan.md" ]; then
      states+=("active"); paths+=("$plans_dir/$slug/plan.md")
    else
      states+=("active"); paths+=("$plans_dir/$slug (no plan.md)")
    fi
  fi
  if [ -f "$completed_dir/$slug.md" ]; then
    states+=("completed"); paths+=("$completed_dir/$slug.md")
  fi

  case "${#states[@]}" in
    0) err "plan not found: $slug" ;;
    1) echo "${states[0]}: ${paths[0]}" ;;
    *) err "slug exists in multiple states: $slug" ;;
  esac
}

# --- promote -------------------------------------------------------------
cmd_promote() {
  local src="${1:-}"
  [ -n "$src" ] || err "usage: plan-lifecycle.sh promote <proposal-file>"
  [ -f "$src" ] || err "not a proposal file under proposals/: $src"

  local src_abs proposals_abs
  src_abs=$(realpath -m -- "$src" 2>/dev/null || printf '%s' "$src")
  proposals_abs=$(realpath -m -- "$proposals_dir" 2>/dev/null || printf '%s' "$proposals_dir")
  case "$src_abs" in
    "$proposals_abs"/*) : ;;
    *) err "not a proposal file under proposals/: $src" ;;
  esac

  local base plan_id dest_dir
  base=$(basename -- "$src")
  plan_id="${base%.md}"
  dest_dir="$plans_dir/$plan_id"
  [ -e "$dest_dir" ] && err "destination already exists: $dest_dir"

  ensure_dir "$dest_dir"
  git_aware_mv "$src" "$dest_dir/plan.md"

  local kind sib
  for kind in $KNOWN_KINDS; do
    sib="$proposals_dir/$plan_id.$kind.md"
    [ -f "$sib" ] && git_aware_mv "$sib" "$dest_dir/$kind.md"
  done

  local f fname mid
  for f in "$proposals_dir/$plan_id".*.md; do
    [ -e "$f" ] || continue
    fname=$(basename -- "$f")
    mid="${fname#"$plan_id".}"
    mid="${mid%.md}"
    case " $KNOWN_KINDS " in
      *" $mid "*) : ;;
      *) echo "plan-lifecycle: unrecognized sibling left in place: $f" >&2 ;;
    esac
  done

  [ "$dry_run" = 1 ] || echo "$dest_dir/plan.md"
}

# --- archive -------------------------------------------------------------
cmd_archive() {
  local plan_dir="${1:-}"
  [ -n "$plan_dir" ] || err "usage: plan-lifecycle.sh archive <plan-dir> [--force-incomplete <reason>]"
  [ -d "$plan_dir" ] && [ -f "$plan_dir/plan.md" ] || err "no plan.md in $plan_dir: nothing to archive"

  local plan_id dest
  plan_id=$(basename -- "$plan_dir")
  dest="$completed_dir/$plan_id.md"
  [ -e "$dest" ] && err "already archived: $dest exists"

  local entry name
  for entry in "$plan_dir"/*; do
    [ -e "$entry" ] || continue
    name=$(basename -- "$entry")
    case "$name" in
      plan.md|story.md|plan-review.md|code-review.md|pr-review.md|sync-report.md) : ;;
      *) err "unexpected entry in $plan_dir, refusing to remove: $name" ;;
    esac
  done

  if [ "$force_incomplete_set" = 1 ] && [ -z "$force_incomplete_reason" ]; then
    err "usage: --force-incomplete requires a non-empty reason"
  fi

  if [ "$force_incomplete_set" != 1 ]; then
    local checklines
    checklines=$(grep -E '^[[:space:]]+- \[[^]]*\][[:space:]]+[0-9]+\.[0-9]+:' "$plan_dir/plan.md" || true)
    if [ -n "$checklines" ]; then
      local unfinished
      unfinished=$(printf '%s\n' "$checklines" | grep -E '^[[:space:]]+- \[[[:space:]]*\][[:space:]]+[0-9]+\.[0-9]+:' || true)
      if [ -n "$unfinished" ]; then
        printf '%s\n' "$unfinished" >&2
        err "plan has unchecked subphases; use 'supersede' to remove it if it was abandoned, or finish the syllabus"
      fi

      local shipped dropped
      shipped=$(printf '%s\n' "$checklines" | grep -cE '^[[:space:]]+- \[(x|done)\][[:space:]]+[0-9]+\.[0-9]+:')
      dropped=$(printf '%s\n' "$checklines" | grep -E '^[[:space:]]+- \[dropped\][[:space:]]+[0-9]+\.[0-9]+:' || true)
      if [ "$shipped" -eq 0 ] && [ -n "$dropped" ]; then
        printf '%s\n' "$dropped" >&2
        err "plan shipped nothing (all subphases dropped); use 'supersede' to remove it"
      fi
    fi
  fi

  ensure_dir "$completed_dir"
  git_aware_mv "$plan_dir/plan.md" "$dest"

  if [ "$force_incomplete_set" = 1 ]; then
    if [ "$dry_run" = 1 ]; then
      echo "DRY-RUN: insert archived-incomplete note into $dest"
    else
      insert_incomplete_note "$dest" "$force_incomplete_reason"
    fi
  fi

  local removed=()
  for entry in "$plan_dir"/*; do
    [ -e "$entry" ] || continue
    name=$(basename -- "$entry")
    [ "$name" = "plan.md" ] && continue
    git_aware_rm "$entry"
    removed+=("$plan_dir/$name")
  done

  remove_empty_dir "$plan_dir"

  if [ "$dry_run" != 1 ]; then
    echo "archived: $plan_dir/plan.md -> $dest"
    if [ ${#removed[@]} -gt 0 ]; then
      local r
      for r in "${removed[@]}"; do echo "removed: $r"; done
    fi
  fi
}

# --- supersede -------------------------------------------------------------
cmd_supersede() {
  local target="${1:-}"
  [ -n "$target" ] || err "usage: plan-lifecycle.sh supersede <plan-path> --by <successor>"
  [ -n "$by" ] || err "usage: --by <successor> is required"
  [ -e "$target" ] || err "plan path not found: $target"

  local target_abs completed_abs
  target_abs=$(realpath -m -- "$target" 2>/dev/null || printf '%s' "$target")
  completed_abs=$(realpath -m -- "$completed_dir" 2>/dev/null || printf '%s' "$completed_dir")
  case "$target_abs" in
    "$completed_abs"|"$completed_abs"/*)
      err "cannot supersede a completed plan: use 'reopen', or leave it alone" ;;
  esac

  [ -f "$by" ] || err "successor not found: $by"

  local plan_id
  if [ -d "$target" ]; then
    plan_id=$(basename -- "$target")
  else
    plan_id=$(basename -- "$target"); plan_id="${plan_id%.md}"
  fi

  grep -qF -- "$plan_id" "$by" || err "successor $by does not mention $plan_id"

  if [ -d "$target" ]; then
    git_aware_rm_dir "$target"
  else
    git_aware_rm "$target"
  fi

  [ "$dry_run" = 1 ] || echo "deleted: $target (superseded by $by)"
}

# --- reopen -------------------------------------------------------------
cmd_reopen() {
  local src="${1:-}"
  [ -n "$src" ] || err "usage: plan-lifecycle.sh reopen <completed-file>"
  [ -f "$src" ] || err "not a completed file under completed/: $src"

  local src_abs completed_abs
  src_abs=$(realpath -m -- "$src" 2>/dev/null || printf '%s' "$src")
  completed_abs=$(realpath -m -- "$completed_dir" 2>/dev/null || printf '%s' "$completed_dir")
  case "$src_abs" in
    "$completed_abs"/*) : ;;
    *) err "not a completed file under completed/: $src" ;;
  esac

  local base plan_id dest_dir
  base=$(basename -- "$src")
  plan_id="${base%.md}"
  dest_dir="$plans_dir/$plan_id"
  [ -e "$dest_dir" ] && err "destination already exists: $dest_dir"

  ensure_dir "$dest_dir"
  git_aware_mv "$src" "$dest_dir/plan.md"

  [ "$dry_run" = 1 ] || echo "$dest_dir/plan.md"
}

# --- check -------------------------------------------------------------
fail=0
say_fail() { echo "FAIL: $*"; fail=1; }

check_root_entries() {
  local entry name
  for entry in "$plans_dir"/*; do
    [ -e "$entry" ] || continue
    name=$(basename -- "$entry")
    case "$name" in
      README.md) continue ;;
      .*) continue ;;
      proposals|completed) continue ;;
    esac
    if [ -d "$entry" ]; then
      printf '%s' "$name" | grep -qE "$PLAN_ID_RE" \
        || say_fail "entry at plans-dir root does not match <slug>-MM-DD-YY: $name"
    else
      say_fail "unexpected file at plans-dir root: $name"
    fi
  done
}

check_plan_dir_contents() { # <dir>
  local dir="$1" e n
  for e in "$dir"/*; do
    [ -e "$e" ] || continue
    n=$(basename -- "$e")
    case "$n" in
      plan.md|story.md|plan-review.md|code-review.md|pr-review.md|sync-report.md) : ;;
      *) say_fail "unexpected file in plan dir $dir: $n" ;;
    esac
  done
}

check_plan_dir_contents_all() {
  local entry name
  for entry in "$plans_dir"/*; do
    [ -d "$entry" ] || continue
    name=$(basename -- "$entry")
    case "$name" in proposals|completed) continue ;; esac
    printf '%s' "$name" | grep -qE "$PLAN_ID_RE" || continue
    check_plan_dir_contents "$entry"
  done
}

check_proposals_contents() {
  [ -d "$proposals_dir" ] || return 0
  local e n base pid matched kind
  for e in "$proposals_dir"/*; do
    [ -e "$e" ] || continue
    n=$(basename -- "$e")
    if [ -d "$e" ]; then
      say_fail "unexpected subdirectory in proposals/: $n"
      continue
    fi
    case "$n" in
      *.md) : ;;
      *) say_fail "unrecognized filename in proposals/: $n"; continue ;;
    esac
    base="${n%.md}"
    if printf '%s' "$base" | grep -qE "$PLAN_ID_RE"; then
      continue
    fi
    matched=0
    for kind in $KNOWN_KINDS; do
      case "$base" in
        *".$kind")
          pid="${base%.$kind}"
          printf '%s' "$pid" | grep -qE "$PLAN_ID_RE" && matched=1
          ;;
      esac
    done
    [ "$matched" = 1 ] || say_fail "unrecognized filename in proposals/: $n"
  done
}

check_completed_contents() {
  [ -d "$completed_dir" ] || return 0
  local e n base
  for e in "$completed_dir"/*; do
    [ -e "$e" ] || continue
    n=$(basename -- "$e")
    if [ -d "$e" ]; then
      say_fail "unexpected entry in completed/: $n"
      continue
    fi
    case "$n" in
      *.md) base="${n%.md}" ;;
      *) say_fail "unexpected entry in completed/: $n"; continue ;;
    esac
    printf '%s' "$base" | grep -qE "$PLAN_ID_RE" || say_fail "unexpected entry in completed/: $n"
  done
}

check_multi_state() {
  local proposals_ids="" root_ids="" completed_ids=""
  local e n base pid kind

  if [ -d "$proposals_dir" ]; then
    for e in "$proposals_dir"/*.md; do
      [ -e "$e" ] || continue
      n=$(basename -- "$e"); base="${n%.md}"
      pid="$base"
      if ! printf '%s' "$base" | grep -qE "$PLAN_ID_RE"; then
        for kind in $KNOWN_KINDS; do
          case "$base" in *".$kind") pid="${base%.$kind}" ;; esac
        done
      fi
      proposals_ids="$proposals_ids
$pid"
    done
  fi

  for e in "$plans_dir"/*; do
    [ -d "$e" ] || continue
    n=$(basename -- "$e")
    case "$n" in proposals|completed) continue ;; esac
    printf '%s' "$n" | grep -qE "$PLAN_ID_RE" || continue
    root_ids="$root_ids
$n"
  done

  if [ -d "$completed_dir" ]; then
    for e in "$completed_dir"/*.md; do
      [ -e "$e" ] || continue
      n=$(basename -- "$e")
      completed_ids="$completed_ids
${n%.md}"
    done
  fi

  local all_ids id states count
  all_ids=$(printf '%s\n%s\n%s\n' "$proposals_ids" "$root_ids" "$completed_ids" | sed '/^$/d' | sort -u)
  for id in $all_ids; do
    states=""
    printf '%s\n' "$proposals_ids" | grep -qxF "$id" && states="${states}proposals,"
    printf '%s\n' "$root_ids" | grep -qxF "$id" && states="${states}active,"
    printf '%s\n' "$completed_ids" | grep -qxF "$id" && states="${states}completed,"
    count=$(printf '%s' "$states" | tr -cd ',' | wc -c)
    if [ "$count" -gt 1 ]; then
      states=$(printf '%s' "${states%,}" | sed 's/,/, /g')
      say_fail "slug $id exists in multiple states: $states"
    fi
  done
}

check_full_scan() {
  check_root_entries
  check_plan_dir_contents_all
  check_proposals_contents
  check_completed_contents
  check_multi_state
}

cmd_check() {
  local path="${1:-}"
  fail=0

  if [ -z "$path" ]; then
    check_full_scan
    [ "$fail" -eq 0 ] && echo "OK: plans dir layout is conformant"
    return "$fail"
  fi

  [ -d "$path" ] || err "usage: check [<path>] — <path> must be a directory under the plans dir"
  local path_abs
  path_abs=$(realpath -m -- "$path" 2>/dev/null || printf '%s' "$path")

  if [ "$path_abs" = "$plans_dir_abs" ]; then
    check_full_scan
    [ "$fail" -eq 0 ] && echo "OK: plans dir layout is conformant"
    return "$fail"
  fi

  case "$path_abs" in
    "$plans_dir_abs"/*) : ;;
    *) err "usage: check <path> — <path> must be under the plans dir" ;;
  esac

  check_plan_dir_contents "$path"
  [ "$fail" -eq 0 ] && echo "OK: plan dir conformant: $path"
  return "$fail"
}

# --- dispatch -------------------------------------------------------------
case "$subcommand" in
  locate) cmd_locate "${positional[@]}" ;;
  promote) cmd_promote "${positional[@]}" ;;
  archive) cmd_archive "${positional[@]}" ;;
  supersede) cmd_supersede "${positional[@]}" ;;
  reopen) cmd_reopen "${positional[@]}" ;;
  check) cmd_check "${positional[@]}" ;;
  *) err "unknown subcommand: $subcommand" ;;
esac
