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
#   adopt <source-plan-path> --run-dir <dir>
#                                           import an externally-planned plan into this run's
#                                           namespace, recording provenance in the plan
#                                           front-matter and the run's progress log
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
#     --run-dir <dir>     adopt only; REQUIRED; the run's gitignored run dir
#     --as <plan-id>      adopt only; destination plan-id (default: derived)
#     --gate-record <path>
#                         adopt only; use exactly this file as the gate-approval record
#     --assume-gated <reason>
#                         adopt only; bypasses the gate-approval refusal (human confirmed)
#     --explored-at <sha> adopt only; tree state the plan was written against
#     --anchors <list>    adopt only; comma-separated and/or repeatable
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
run_dir=""
as_plan_id=""
gate_record_path=""
assume_gated_set=0
assume_gated_reason=""
explored_at_override=""
anchors_flag_values=()

while [ $# -gt 0 ]; do
  case "$1" in
    --plans-dir) plans_dir_override="${2:-}"; shift 2 ;;
    --root) root_override="${2:-}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --by) by="${2:-}"; shift 2 ;;
    --force-incomplete) force_incomplete_set=1; force_incomplete_reason="${2:-}"; shift 2 ;;
    --run-dir) run_dir="${2:-}"; shift 2 ;;
    --as) as_plan_id="${2:-}"; shift 2 ;;
    --gate-record) gate_record_path="${2:-}"; shift 2 ;;
    --assume-gated) assume_gated_set=1; assume_gated_reason="${2:-}"; shift 2 ;;
    --explored-at) explored_at_override="${2:-}"; shift 2 ;;
    --anchors) anchors_flag_values+=("${2:-}"); shift 2 ;;
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

# --- adopt -------------------------------------------------------------
adopt_qualify_candidate() { # <file> -> prints "verdict\nnext\nround"; returns 1 if it does not qualify
  local file="$1"
  [ -f "$file" ] || return 1
  "$hookdir/validate-report.sh" "$file" >/dev/null 2>&1 || return 1
  local last round hdr verdict next
  last=$(grep -E '^## Round [0-9]+' "$file" | tail -1 | grep -oE 'Round [0-9]+' | awk '{print $2}')
  [ -n "$last" ] || return 1
  round=$(awk -v r="^## Round ${last} " '$0 ~ r {f=1} f' "$file")
  hdr=$(printf '%s\n' "$round" | awk '/^```/{n++; next} n==1')
  verdict=$(printf '%s\n' "$hdr" | grep -m1 -E '^verdict:' | sed -E 's/^verdict:[[:space:]]*//')
  next=$(printf '%s\n' "$hdr" | grep -m1 -E '^next:' | sed -E 's/^next:[[:space:]]*//')
  case "$verdict" in ready|tentative) : ;; *) return 1 ;; esac
  [ "$next" = "proceed" ] || return 1
  printf '%s\n%s\n%s\n' "$verdict" "$next" "$last"
}

adopt_front_matter_close_line() { # <file> -> prints closing '---' line number; returns 1 if no leading front matter
  local file="$1" n
  [ "$(sed -n '1p' -- "$file")" = "---" ] || return 1
  n=$(awk 'NR>1 && /^---$/{print NR; exit}' "$file")
  [ -n "$n" ] || return 1
  printf '%s\n' "$n"
}

adopt_extract_other_keys() { # reads source front-matter content on stdin; drops reserved top-level keys + their continuation lines
  awk '
    /^[A-Za-z_][A-Za-z0-9_.-]*:/ {
      key=$0; sub(/:.*$/, "", key)
      if (key=="adopted" || key=="source_plan" || key=="source_run" || key=="source_gate_verdict" || key=="explored_at" || key=="adopted_at" || key=="anchors") {
        cur_skip=1
      } else {
        cur_skip=0
      }
    }
    { if (!cur_skip) print }
  '
}

adopt_write_progress_log() { # <file> <section>
  local file="$1" section="$2" tmp
  if [ -f "$file" ] && grep -q '^## Plan provenance (adopted)$' "$file"; then
    tmp=$(mktemp)
    ADOPT_SECTION="$section" awk '
      BEGIN { section = ENVIRON["ADOPT_SECTION"] }
      /^## Plan provenance \(adopted\)$/ { print section; skipping=1; next }
      skipping && /^## / { skipping=0 }
      skipping { next }
      { print }
    ' "$file" > "$tmp" || { [ -e "$tmp" ] && rm -- "$tmp"; err "failed to update $file"; }
    mv -- "$tmp" "$file" || err "failed to update $file"
  elif [ -f "$file" ]; then
    tmp=$(mktemp)
    { cat -- "$file"; printf '\n%s\n' "$section"; } > "$tmp" || { [ -e "$tmp" ] && rm -- "$tmp"; err "failed to update $file"; }
    mv -- "$tmp" "$file" || err "failed to update $file"
  else
    { echo "# Progress log"; printf '\n%s\n' "$section"; } > "$file" || err "failed to create $file"
  fi
}

cmd_adopt() {
  local source="${1:-}"

  if [ -z "$source" ] || [ -z "$run_dir" ]; then
    err "usage: plan-lifecycle.sh adopt <source-plan-path> --run-dir <dir> [--as <plan-id>] [--gate-record <path>] [--assume-gated <reason>] [--explored-at <sha>] [--anchors <list>]"
  fi
  if [ "$assume_gated_set" = 1 ] && [ -z "$assume_gated_reason" ]; then
    err "usage: --assume-gated requires a non-empty reason"
  fi

  [ -f "$source" ] || err "source plan not found: $source"

  # --- step 3: plan ids ---
  local src_base source_plan_id
  src_base=$(basename -- "$source")
  if [ "$src_base" = "plan.md" ]; then
    source_plan_id=$(basename -- "$(dirname -- "$source")")
  else
    source_plan_id="${src_base%.md}"
  fi

  if ! printf '%s' "$source_plan_id" | grep -qE "$PLAN_ID_RE"; then
    [ -n "$as_plan_id" ] || err "cannot derive a plan-id from $source; pass --as <plan-id>"
  fi

  local today dest_plan_id
  today=$(date +%m-%d-%y)
  if [ -n "$as_plan_id" ]; then
    dest_plan_id="$as_plan_id"
  else
    local stripped
    stripped=$(printf '%s' "$source_plan_id" | sed -E 's/-[0-9]{2}-[0-9]{2}-[0-9]{2}$//')
    dest_plan_id="${stripped}-${today}"
  fi
  printf '%s' "$dest_plan_id" | grep -qE "$PLAN_ID_RE" || err "not a valid plan-id: $dest_plan_id"

  # --- step 4: destination ---
  local dest_dir
  dest_dir="$plans_dir/$dest_plan_id"
  [ -e "$dest_dir" ] && err "destination already exists: $dest_dir"

  # --- step 5: gate approval ---
  local src_dirname src_dirname_abs proposals_abs
  src_dirname=$(dirname -- "$source")
  src_dirname_abs=$(realpath -m -- "$src_dirname" 2>/dev/null || printf '%s' "$src_dirname")
  proposals_abs=$(realpath -m -- "$proposals_dir" 2>/dev/null || printf '%s' "$proposals_dir")

  local candidates=()
  if [ -n "$gate_record_path" ]; then
    candidates=("$gate_record_path")
  elif [ "$src_base" = "plan.md" ]; then
    candidates=("$src_dirname/plan-review.md" "$src_dirname/pr-review.md")
  elif [ "$src_dirname_abs" = "$proposals_abs" ]; then
    candidates=("$proposals_dir/$source_plan_id.plan-review.md")
  fi

  local source_gate_verdict="" gate_qualified=0
  local cand
  for cand in "${candidates[@]}"; do
    [ -n "$cand" ] || continue
    local result
    if result=$(adopt_qualify_candidate "$cand"); then
      local verdict next round cand_base
      verdict=$(printf '%s\n' "$result" | sed -n '1p')
      next=$(printf '%s\n' "$result" | sed -n '2p')
      round=$(printf '%s\n' "$result" | sed -n '3p')
      cand_base=$(basename -- "$cand")
      source_gate_verdict="$verdict/$next ($cand_base, round $round)"
      gate_qualified=1
      break
    fi
  done

  if [ "$gate_qualified" != 1 ]; then
    if [ "$assume_gated_set" != 1 ]; then
      err "no recorded gate approval for $source_plan_id; a human must confirm \"treat as approved?\" — re-run with --assume-gated <reason>"
    fi
    source_gate_verdict="none-on-record (confirmed: $assume_gated_reason)"
  fi

  # --- step 6: explored_at ---
  local explored_at
  if [ -n "$explored_at_override" ]; then
    explored_at="$explored_at_override"
  else
    explored_at=$(git -C "$root" log -1 --format=%H -- "$source" 2>/dev/null)
    if [ -z "$explored_at" ]; then
      explored_at="unknown"
      echo "plan-lifecycle: explored_at unknown; the staleness guard must treat this adoption as stale" >&2
    fi
  fi

  # --- source front matter, consumed once (used by steps 7 and 8) ---
  local has_fm=0 fm_close="" fm_content="" body=""
  if fm_close=$(adopt_front_matter_close_line "$source"); then
    has_fm=1
    fm_content=$(sed -n "2,$((fm_close-1))p" -- "$source")
    body=$(sed -n "$((fm_close+1)),\$p" -- "$source")
  else
    body=$(cat -- "$source")
  fi

  # --- step 7: anchors ---
  local anchors=()
  if [ ${#anchors_flag_values[@]} -gt 0 ]; then
    local av
    for av in "${anchors_flag_values[@]}"; do
      local adopt_parts=() part_raw trimmed
      IFS=',' read -ra adopt_parts <<< "$av"
      for part_raw in "${adopt_parts[@]}"; do
        trimmed=$(printf '%s' "$part_raw" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
        [ -n "$trimmed" ] && anchors+=("$trimmed")
      done
    done
  elif [ "$has_fm" = 1 ]; then
    local anchor_lines
    anchor_lines=$(printf '%s\n' "$fm_content" | awk '
      /^anchors:[[:space:]]*$/ { f=1; next }
      f && /^[[:space:]]+- / { print; next }
      f { exit }
    ')
    if [ -n "$anchor_lines" ]; then
      local aline aitem
      while IFS= read -r aline; do
        [ -n "$aline" ] || continue
        aitem=$(printf '%s' "$aline" | sed -E 's/^[[:space:]]*-[[:space:]]*//')
        anchors+=("$aitem")
      done <<< "$anchor_lines"
    fi
  fi

  # --- step 8a: destination plan ---
  ensure_dir "$dest_dir"
  if [ "$dry_run" = 1 ]; then
    echo "DRY-RUN: adopt $source -> $dest_dir/plan.md"
  else
    {
      echo "---"
      echo "adopted: true"
      echo "source_plan: $source"
      echo "source_run: $source_plan_id"
      echo "source_gate_verdict: $source_gate_verdict"
      echo "explored_at: $explored_at"
      echo "adopted_at: $today"
      if [ ${#anchors[@]} -gt 0 ]; then
        echo "anchors:"
        local a
        for a in "${anchors[@]}"; do
          echo "  - $a"
        done
      else
        echo "anchors: none"
      fi
      if [ "$has_fm" = 1 ] && [ -n "$fm_content" ]; then
        printf '%s\n' "$fm_content" | adopt_extract_other_keys
      fi
      echo "---"
      printf '%s\n' "$body"
    } > "$dest_dir/plan.md" || err "failed to write $dest_dir/plan.md"
  fi

  # --- step 8b: progress log ---
  local anchors_joined
  if [ ${#anchors[@]} -gt 0 ]; then
    anchors_joined=$(IFS=,; printf '%s' "${anchors[*]}")
  else
    anchors_joined="none"
  fi

  local changed_status="ok" changed_files="" changed_count=0
  if [ "$explored_at" = "unknown" ]; then
    changed_status="unknown"
  else
    if changed_files=$(git -C "$root" diff --name-only "$explored_at"..HEAD 2>/dev/null); then
      changed_status="ok"
    else
      changed_status="unknown"
    fi
  fi

  local changed_line changed_path_arr=()
  if [ "$changed_status" = "unknown" ]; then
    changed_line="- changed since explored_at: unknown (treat as stale)"
  else
    changed_count=$(printf '%s\n' "$changed_files" | grep -cE '.' || true)
    changed_line="- changed since explored_at: ${changed_count} file(s)"
    if [ "$changed_count" -gt 0 ]; then
      local pf
      if [ "$changed_count" -gt 50 ]; then
        while IFS= read -r pf; do
          changed_path_arr+=("  - $pf")
        done < <(printf '%s\n' "$changed_files" | head -n 50)
        local more=$((changed_count - 50))
        changed_path_arr+=("  - … and ${more} more")
      else
        while IFS= read -r pf; do
          changed_path_arr+=("  - $pf")
        done <<< "$changed_files"
      fi
    fi
  fi

  local prov_lines=(
    "## Plan provenance (adopted)"
    ""
    "- adopted plan: $dest_dir/plan.md"
    "- source plan: $source"
    "- source run: $source_plan_id"
    "- source gate verdict: $source_gate_verdict"
    "- explored_at: $explored_at"
    "- anchors: $anchors_joined"
    "$changed_line"
  )
  if [ ${#changed_path_arr[@]} -gt 0 ]; then
    prov_lines+=("${changed_path_arr[@]}")
  fi
  local provenance_section
  provenance_section=$(printf '%s\n' "${prov_lines[@]}")

  local progress_log="$run_dir/progress-log.md"
  if [ "$dry_run" = 1 ]; then
    echo "DRY-RUN: record provenance in $progress_log"
  else
    ensure_dir "$run_dir"
    adopt_write_progress_log "$progress_log" "$provenance_section"
  fi

  # --- step 9: output ---
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
  adopt) cmd_adopt "${positional[@]}" ;;
  *) err "unknown subcommand: $subcommand" ;;
esac
