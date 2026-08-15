#!/usr/bin/env bash
# sync-install.sh — sync this repo's universal-domain content to the ~/.claude or ~/.gemini/config install.
#
# SYNOPSIS
#   sync-install.sh [<git-range>] [--full] [--check] [--home <dir>] [--agy] [--claude]
#
# DESCRIPTION
#   Invoked by the push-main skill (step 4) right after a push lands, NOT a hook.
#   Universal-domain content is everything under agent-agnostic/ and orchestrators/;
#   tool-based/ (tech-bound) and this repo's own .agent-specific/claude/ (project-scoped) are
#   never synced. Mapping, per the source-push-sync rule:
#
#     {generic,orchestrators}/skills/<name>/**  -> ~/.agent-specific/claude/skills/<name>/   (whole directory)
#     {generic,orchestrators}/hooks/<file>      -> ~/.agent-specific/claude/hooks/<file>
#     {generic,orchestrators}/rules/<name>.md   -> ~/.agent-specific/claude/rules/<name>.md
#     orchestrators/agents/<name>.md            -> ~/.agent-specific/claude/agents/<name>.md
#     orchestrators/agents/<dir>/**             -> ~/.agent-specific/claude/agents/<dir>/    (whole directory)
#     agent-specific/claude/settings.json                      -> ~/.agent-specific/claude/settings.json
#     agent-specific/antigravity/hooks.json                    -> ~/.gemini/config/hooks.json (if --agy)
#     agent-specific/antigravity/{rules,skills}/**             -> ~/.gemini/config/... (if --agy; never Claude)
#
#   settings.json is the one unit the INSTALL side also mutates: Claude Code
#   appends "always allow" grants to the live file. --check reports that as
#   STALE; fold wanted grants back into agent-specific/claude/settings.json before
#   the next push, or the sync will overwrite them.
#
#   Files named AGENTS.md and .gitkeep are repo documentation/scaffolding and
#   are skipped. Skill and agent directories sync as WHOLE directories (the
#   install must carry sibling files and scripts/, and must drop files the
#   source dropped). Deletions propagate: a file/dir deleted in the range is
#   removed from the install.
#
# MODES
#   (no mode)     FULL reconcile — same as --full. This is the default because
#                 the old default, 'HEAD~1..HEAD', silently synced only the last
#                 commit: make several commits, run the sync once, and every
#                 commit but the newest never landed. That is how 19 installed
#                 files went stale and plan-lifecycle.sh was never installed at
#                 all, with --check disagreeing with the sync the whole time.
#                 A full reconcile has no range to get wrong.
#   <git-range>   Sync only what changed in the range (e.g. 'abc123..HEAD').
#                 Opt-in only — never a default. Deletions in the range are
#                 propagated to the install; a full reconcile cannot express
#                 deletions, so this is the mode to use when removing files.
#   --full        Explicit form of the default: treat every universal source
#                 file as changed and mirror the whole tree into the install.
#                 Does not delete unattributable install files (see --check).
#   --check       Copy nothing. Diff every universal source file against the
#                 install and report drift (missing/stale files, plus orphaned
#                 install files that have no source counterpart). Exit 1 on
#                 any drift — this is the post-landing verification (7.3).
#   --agy         Sync hooks.json, rules, and skills to ~/.gemini/config instead of ~/.claude.
#   --claude      Sync settings.json, rules, and skills to ~/.claude.
#
# PRECONDITIONS
#   Run from the repo root, on main, not inside a linked worktree.
#
# EXIT CODES
#   0 - synced and verified (or --check clean)
#   1 - precondition failed, sync verification failed, or --check found drift
set -uo pipefail

err() { echo "sync-install: $*" >&2; exit 1; }

range=""; full=0; check=0; custom_home=""; agy=0; claude=0
while [ $# -gt 0 ]; do
  case "$1" in
    --full) full=1; shift ;;
    --check) check=1; shift ;;
    --home) custom_home="${2:-}"; shift 2 ;;
    --agy) agy=1; shift ;;
    --claude) claude=1; shift ;;
    -*) err "unknown flag: $1 (usage: sync-install.sh [<git-range>] [--full] [--check] [--home <dir>] [--agy] [--claude])" ;;
    *) [ -z "$range" ] || err "unexpected argument: $1"; range="$1"; shift ;;
  esac
done
[ "$full" = 1 ] && [ -n "$range" ] && err "--full and a <git-range> are mutually exclusive"

targets=()
if [ "$claude" = 1 ] || { [ "$claude" = 0 ] && [ "$agy" = 0 ]; }; then targets+=("claude"); fi
if [ "$agy" = 1 ] || { [ "$claude" = 0 ] && [ "$agy" = 0 ]; }; then targets+=("agy"); fi

# --- preconditions ----------------------------------------------------------
root=$(git rev-parse --show-toplevel 2>/dev/null) || err "not inside a git repository"
cd "$root"
[ -d "$root/agent-agnostic" ] && [ -d "$root/orchestrators" ] \
  || err "source dirs agent-agnostic/ and orchestrators/ not found — run from the agentic repo"
gitdir=$(git rev-parse --git-dir)
common=$(git rev-parse --git-common-dir)
[ "$gitdir" = "$common" ] || err "inside a linked worktree — sync only from the main checkout"
branch=$(git rev-parse --abbrev-ref HEAD)
[ "$branch" = "main" ] || err "on branch '$branch' — sync only from main"

global_drift=0
global_fail=0

for TARGET_MODE in "${targets[@]}"; do
  if [ "$TARGET_MODE" = "agy" ]; then
    claude_home="${custom_home:-$HOME/.gemini/config}"
  else
    claude_home="${custom_home:-$HOME/.claude}"
  fi
  mkdir -p "$claude_home"
  
  # --- path mapping -----------------------------------------------------------
  install_path() {
    local p="$1"
    case "$(basename "$p")" in AGENTS.md|.gitkeep) return 0 ;; esac
    case "$p" in
      agent-specific/antigravity/skills/*/*)                      [ "$TARGET_MODE" = "agy" ] && echo "skills/${p#*/skills/}" ;;
      agent-specific/antigravity/rules/*)                         [ "$TARGET_MODE" = "agy" ] && echo "rules/${p#*/rules/}" ;;
      agent-agnostic/skills/*/*|orchestrators/skills/*/*) echo "skills/${p#*/skills/}" ;;
      agent-agnostic/hooks/*|orchestrators/hooks/*)       echo "hooks/${p#*/hooks/}" ;;
      agent-agnostic/rules/*|orchestrators/rules/*)       echo "rules/${p#*/rules/}" ;;
      orchestrators/agents/*)                      echo "agents/${p#orchestrators/agents/}" ;;
      agent-specific/claude/settings.json)                        [ "$TARGET_MODE" = "claude" ] && echo "settings.json" ;;
      agent-specific/antigravity/hooks.json)                      [ "$TARGET_MODE" = "agy" ] && echo "hooks.json" ;;
    esac
  }

  unit_of() {
    local rel="$1"
    case "$rel" in
      skills/*/*) echo "skills/$(echo "$rel" | cut -d/ -f2)" ;;
      agents/*/*) echo "agents/$(echo "$rel" | cut -d/ -f2)" ;;
      *)          echo "$rel" ;;
    esac
  }

  source_of() {
    local unit="$1" cand
    for cand in "agent-agnostic/$unit" "orchestrators/$unit" \
                "agent-agnostic/${unit#skills/}" ; do :; done
    case "$unit" in
      skills/*) for cand in "agent-agnostic/$unit" "orchestrators/$unit" $([ "$TARGET_MODE" = "agy" ] && echo "agent-specific/antigravity/$unit"); do [ -e "$cand" ] && { echo "$cand"; return; }; done ;;
      hooks/*)  for cand in "agent-agnostic/$unit" "orchestrators/$unit"; do [ -e "$cand" ] && { echo "$cand"; return; }; done ;;
      rules/*)  for cand in "agent-agnostic/$unit" "orchestrators/$unit" $([ "$TARGET_MODE" = "agy" ] && echo "agent-specific/antigravity/$unit"); do [ -e "$cand" ] && { echo "$cand"; return; }; done ;;
      agents/*) cand="orchestrators/$unit"; [ -e "$cand" ] && echo "$cand" ;;
      settings.json) cand="agent-specific/claude/settings.json"; [ "$TARGET_MODE" = "claude" ] && [ -e "$cand" ] && echo "$cand" ;;
      hooks.json)    cand="agent-specific/antigravity/hooks.json"; [ "$TARGET_MODE" = "agy" ] && [ -e "$cand" ] && echo "$cand" ;;
    esac
  }

  fail=0
  sync_unit() {
    local unit="$1" src dest
    src=$(source_of "$unit")
    dest="$claude_home/$unit"
    if [ -z "$src" ]; then
      if [ -e "$dest" ]; then rm -rf "$dest"; echo "DELETED ($TARGET_MODE): $unit"; fi
      return
    fi
    mkdir -p "$(dirname "$dest")"
    if [ -d "$src" ]; then
      rm -rf "$dest"
      cp -R "$src" "$dest" || { echo "sync-install: copy failed for $unit ($TARGET_MODE)" >&2; fail=1; return; }
      diff -r "$src" "$dest" >/dev/null || { echo "sync-install: verify failed for $unit ($TARGET_MODE)" >&2; fail=1; return; }
    else
      cp "$src" "$dest" || { echo "sync-install: copy failed for $unit ($TARGET_MODE)" >&2; fail=1; return; }
      diff "$src" "$dest" >/dev/null || { echo "sync-install: verify failed for $unit ($TARGET_MODE)" >&2; fail=1; return; }
    fi
    echo "SYNCED ($TARGET_MODE): $unit"
  }

  all_source_files() {
    find agent-agnostic orchestrators agent-specific -type f ! -name AGENTS.md ! -name .gitkeep \
      \( -path '*/skills/*' -o -path '*/hooks/*' -o -path '*/rules/*' -o -path '*/agents/*' \
         -o -path 'agent-specific/claude/settings.json' -o -path 'agent-specific/antigravity/hooks.json' \) \
      2>/dev/null | sort
  }

  # --- --check: report drift, copy nothing ------------------------------------
  if [ "$check" = 1 ]; then
    drift=0
    while IFS= read -r p; do
      rel=$(install_path "$p"); [ -n "$rel" ] || continue
      if [ ! -f "$claude_home/$rel" ]; then echo "MISSING ($TARGET_MODE): $rel (source: $p)"; drift=1
      elif ! diff "$p" "$claude_home/$rel" >/dev/null; then echo "STALE ($TARGET_MODE): $rel (differs from $p)"; drift=1
      fi
    done < <(all_source_files)
    
    for area in skills hooks rules agents; do
      [ -d "$claude_home/$area" ] || continue
      while IFS= read -r f; do
        rel="${f#"$claude_home"/}"
        unit=$(unit_of "$rel")
        [ -n "$(source_of "$unit")" ] || { echo "ORPHAN ($TARGET_MODE): $rel (no source in repo)"; drift=1; }
      done < <(find "$claude_home/$area" -type f | sort)
    done
    [ "$drift" = 0 ] && echo "CHECK ($TARGET_MODE): clean — install matches source"
    [ "$drift" = 1 ] && global_drift=1
    continue
  fi

  # --- collect changed units --------------------------------------------------
  units=""
  if [ "$full" = 1 ] || [ -z "$range" ]; then
    while IFS= read -r p; do
      rel=$(install_path "$p"); [ -n "$rel" ] || continue
      units="$units$(unit_of "$rel")\n"
    done < <(all_source_files)
  else
    git rev-parse "${range%%..*}" >/dev/null 2>&1 || err "bad git range: $range"
    while IFS=$'\t' read -r _status p _rest; do
      [ -n "${p:-}" ] || continue
      # Renames report two paths; handle both old (delete side) and new.
      for q in "$p" "${_rest:-}"; do
        [ -n "$q" ] || continue
        rel=$(install_path "$q"); [ -n "$rel" ] || continue
        units="$units$(unit_of "$rel")\n"
      done
    done < <(git diff --name-status "$range" -- agent-agnostic orchestrators agent-specific)
  fi

  units=$(printf '%b' "$units" | sort -u | sed '/^$/d')
  if [ -z "$units" ]; then
    echo "sync-install ($TARGET_MODE): no universal-domain changes to sync"
    continue
  fi

  while IFS= read -r unit; do
    sync_unit "$unit"
  done <<< "$units"

  [ "$fail" = 0 ] || { err "one or more units failed to sync for target $TARGET_MODE"; global_fail=1; }
  echo "sync-install ($TARGET_MODE): done ($(echo "$units" | wc -l | tr -d ' ') unit(s))"
done

if [ "$check" = 1 ]; then
  exit "$global_drift"
fi

[ "$global_fail" = 0 ] || exit 1
exit 0
