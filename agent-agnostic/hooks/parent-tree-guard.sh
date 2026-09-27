#!/usr/bin/env bash
# parent-tree-guard.sh — PostToolUse (Bash) / Stop hook denying product-file
# changes made directly in a dae run's PARENT worktree.
#
# SYNOPSIS  (wired as a PostToolUse hook on Bash, and as a Stop hook; reads
#            the tool-call/stop JSON payload on stdin)
#   parent-tree-guard.sh
#
# DESCRIPTION
#   scope-writes.sh (sibling in this dir) denies Write/Edit/NotebookEdit
#   calls outside an allowlist, but it is a PreToolUse hook and explicitly
#   does NOT intercept Bash — a PreToolUse hook cannot see inside a shell
#   command (`sed -i`, `>`, heredocs, `tee`, `python -c`, ...), so a Bash
#   call can mutate the product tree straight past it. This hook closes
#   that gap the way workflow-diff-check.sh closes an analogous one for
#   tests: rather than trying to parse the command, it inspects the
#   ARTIFACT afterwards — the git status of the run's marked PARENT
#   worktree — and denies if that status shows a product-file change.
#
#   The orchestrator's own writes are meant to be limited per its role —
#   see the per-role table below — with a missing/unreadable/garbage role
#   token resolving to `orchestrator` itself (the most restrictive real
#   role), never to a separate permissive fallback; building is delegated
#   to lanes. This hook is the Bash-side enforcement of that invariant. It
#   reuses scope-writes.sh's marker walk
#   (`find_parent_worktree`, `find_lane_root`), role resolution
#   (`resolve_role`), and root resolution (`resolve_root_dir`) verbatim so
#   the two hooks never disagree about what counts as "the parent
#   worktree", "a lane root", "the current role", or "the plans/docs root"
#   — see the Shared abstraction note in scope-writes.sh's header.
#
#   Role table (same roles/roots as scope-writes.sh, inverted for a
#   git-status offender check rather than a single-path allow/deny):
#     - `orchestrator` (including a missing/unreadable/garbage token in a
#       LINKED worktree parent, and a `builder` claim `resolve_role`
#       rejected): clean only if under plans_root AND its basename matches
#       `*-review.md` or is exactly `sync-report.md`; anything else is an
#       offender. `resolve_role` never returns empty for a marked,
#       non-lane root — an unresolved role used to fall back to a
#       permissive plans+docs+artifacts allowance instead; that was itself
#       the escalation vector DP-2 exists to prevent, so it no longer
#       happens.
#     - `builder`: a changed path is clean UNLESS it's under plans_root or
#       docs_root, in which case it's an offender (inverted from every
#       other role: a builder's own product changes in its own child
#       worktree are the entire point; only a plans/docs collision is the
#       offense).
#     - `planner`: clean only if under plans_root; anything else (docs,
#       product, everything) is an offender.
#     - `scratch` (a missing/unreadable/garbage token in the MAIN
#       CHECKOUT — a `ship: chat` run's scratch marker): clean only if
#       under `$marked/.artifacts`; anything else (a product file at the
#       marked root, for instance) is an offender — matching
#       scope-writes.sh's own scratch allow-list exactly.
#     - `documenter` (from `agent_type`, never a marker): clean under
#       docs_root, or exactly `plan.md` under plans_root; else an offender.
#
#   Cheap and safe to run often: no marker found, or `git status` itself
#   fails (not a repo, git missing), both fail OPEN (exit 0) rather than
#   deny — this hook only ever blocks on an actual product-file diff inside
#   a confirmed parent worktree.
#
#   Tamper detection (independent of the git-status offender scan above).
#   `.artifacts/` is gitignored, so a direct write of `builder` into a
#   PARENT worktree's own `dae-role` marker — role-escalation forgery,
#   since a genuine builder never runs there, only in its own sibling lane
#   child — is structurally invisible to `git status` and would otherwise
#   slip past every check below. This hook checks the raw marker content
#   directly, right after resolving the role and before the git-status
#   scan, and denies outright when it sees `resolve_role` having rejected
#   exactly that forged claim (raw file says `builder`, resolved role does
#   not). Because this hook runs as PostToolUse on every Bash call, it
#   fires on the very next invocation after the tampering command — often
#   the tampering command's own hook pass.
#
# EXIT CODES
#   0 - clean (or hook inert: no marker found, git status unavailable,
#       stop_hook_active already true, cwd outside any repo)
#   2 - denied: either (a) the parent worktree's own dae-role marker was
#       forged to contain 'builder' (tamper detection, checked first), or
#       (b) one or more product files changed in the marked parent
#       worktree; stderr names the offending marker or every offending path
set -uo pipefail

hookdir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

payload=$(cat 2>/dev/null || true)

sfield() { # flat "name":"value"
  printf '%s' "$payload" \
    | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 | sed -E "s/\"$1\"[[:space:]]*:[[:space:]]*\"(.*)\"\$/\1/"
}
bfield() { # flat "name":true|false -> the bool token
  printf '%s' "$payload" \
    | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*(true|false)" \
    | head -1 | grep -oE "(true|false)"
}

# Avoid the Stop-hook loop cap: if we already blocked once, let the stop proceed.
[ "$(bfield stop_hook_active)" = "true" ] && exit 0

cwd=$(sfield cwd)
[ -n "$cwd" ] || cwd="$PWD"
agent_type=$(sfield agent_type)

# find_parent_worktree <start-path>
# Prints the marked parent worktree's absolute path and returns 0, or
# returns 1 with nothing printed. Pure string ascent (dirname), never `cd`,
# so it tolerates a <start-path> that does not exist yet (a new file being
# written) as well as one that does (a cwd). Copied verbatim from
# scope-writes.sh's shared marker walk — keep the two identical.
find_parent_worktree() {
  local dir
  dir=$(realpath -m -- "$1" 2>/dev/null) || dir="$1"
  while [ -n "$dir" ]; do
    if [ -f "$dir/.artifacts/progress-log.md" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    [ "$dir" = "/" ] && break
    dir=$(dirname -- "$dir")
  done
  return 1
}

# find_lane_root <start-path>
# A lane's child worktree is named "<parent-name>-l<n>" and lives as a
# SIBLING of its parent (both directly under the workflows dir) — never
# nested inside it — so find_parent_worktree's ascent structurally cannot
# reach the parent's marker from inside a child. This walks the same way,
# testing each ancestor's BASENAME against the lane-suffix shape
# (`^(.+)-l[0-9]+$`) and, on a shape match, confirms legitimacy by checking
# the SIBLING directory (the captured group — the stripped name) for the
# real .artifacts/progress-log.md marker. On success it prints the CHILD's
# OWN matched ancestor directory (never the parent's path) — because a
# builder's plans/docs exclusion must resolve against paths that would
# actually collide with the real plans/docs trees on merge-back, which are
# the child's own local project-plans/docs paths, not the parent's.
# Prints the child root and returns 0, or returns 1 with nothing printed.
find_lane_root() {
  local dir base sib
  dir=$(realpath -m -- "$1" 2>/dev/null) || dir="$1"
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    base=$(basename -- "$dir")
    if [[ "$base" =~ ^(.+)-l[0-9]+$ ]]; then
      sib="$(dirname -- "$dir")/${BASH_REMATCH[1]}"
      if [ -f "$sib/.artifacts/progress-log.md" ]; then
        printf '%s\n' "$dir"
        return 0
      fi
    fi
    dir=$(dirname -- "$dir")
  done
  return 1
}

# resolve_role <marked-root> <is-lane: 0|1> [agent_type]
# `agent_type`, checked first, short-circuits to "documenter" — see below.
# Prints the role token for the given marked root. A lane root (is-lane=1,
# i.e. found via find_lane_root) is unconditionally "builder" — no file is
# ever consulted, matching run-artifacts' "a builder's child worktree never
# gets a run dir". Otherwise reads <marked-root>/.artifacts/dae-role.
# `orchestrator`/`planner` are honored from the file unconditionally, as
# always. `builder`, however, is honored ONLY when <marked-root> is itself
# the main checkout (`--worktree none`, which has no lane child to derive
# builder-ness from structurally, so the marker is that mode's only signal)
# — in a linked worktree parent (`new`/`resume`), a genuine builder always
# runs in its own SIBLING lane child (found via find_lane_root, is_lane=1,
# which never reads this file at all), so `builder` written into a
# *parent's own* marker is never legitimate, only ever forgery. Missing,
# unreadable, or unrecognized content, and a rejected `builder` claim, are
# unresolved and are resolved STRUCTURALLY on that same main_checkout
# signal: in a LINKED worktree parent (main_checkout=0) — always a real dae
# parent worktree — they resolve to `orchestrator`, exactly as before, the
# most restrictive real role a marked, non-lane root can hold. When the
# marked root IS the main checkout (main_checkout=1) they resolve to
# `scratch` instead: a main-checkout marker with no recognized role is a
# `ship: chat` run's scratch marker (resolve-scratch.sh deliberately never
# writes dae-role for one — an `orchestrator` marker there would wrongly
# restrict its own scratch-dir writes) or a `--worktree none` run with a
# corrupted token, never a genuine unresolved dae parent. `scratch` is
# never read from the file directly — writing the literal string `scratch`
# into dae-role still lands in this same `*)` bucket and is re-derived the
# same main_checkout-conditional way, so it cannot be forged from inside
# `.artifacts/`; only the marked root's actual git topology decides the
# outcome. resolve_role NEVER returns empty for is_lane=0 — this was
# itself the escalation vector DP-2 exists to prevent (an unresolved role
# used to fall back to a permissive plans+docs+artifacts allowance instead
# of denying), so both callers' `*)` catch-alls are consequently
# unreachable code from here on, retained only as a defensive backstop. A
# `git` failure while checking main-checkout-ness degrades to "not main
# checkout" (rejects `builder`, and routes an otherwise-unresolved role to
# `orchestrator` rather than `scratch`), never to an error — still
# fail-open, never fail-closed.
# Copied verbatim from scope-writes.sh — keep the two identical.
resolve_role() {
  local marked="$1" is_lane="$2" agent_type="${3:-}" raw gd gcd main_checkout=0
  # agent_type is harness-supplied (stdin); it can't be forged via dae-role.
  if [ "$agent_type" = "documenter" ]; then
    printf '%s\n' "documenter"
    return 0
  fi
  if [ "$is_lane" = 1 ]; then
    printf '%s\n' "builder"
    return 0
  fi
  raw=$(cat "$marked/.artifacts/dae-role" 2>/dev/null | tr -d '[:space:]') || raw=""
  gd=$(git -C "$marked" rev-parse --path-format=absolute --git-dir 2>/dev/null) || gd=""
  gcd=$(git -C "$marked" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || gcd=""
  [ -n "$gd" ] && [ "$gd" = "$gcd" ] && main_checkout=1
  case "$raw" in
    orchestrator|planner) printf '%s\n' "$raw" ;;
    builder)
      if [ "$main_checkout" = 1 ]; then
        printf '%s\n' "builder"
      else
        printf '%s\n' "orchestrator"
      fi
      ;;
    *)
      if [ "$main_checkout" = 1 ]; then
        printf '%s\n' "scratch"
      else
        printf '%s\n' "orchestrator"
      fi
      ;;
  esac
}

marked=""; is_lane=0
if marked=$(find_parent_worktree "$cwd"); then
  is_lane=0
elif marked=$(find_lane_root "$cwd"); then
  is_lane=1
else
  exit 0
fi
[ -n "$marked" ] || exit 0
role=$(resolve_role "$marked" "$is_lane" "$agent_type")

# Tamper detection: a 'builder' token forged directly into a PARENT
# worktree's own marker is denied outright, independent of whether any
# OTHER file also changed — .artifacts/ is gitignored, so the git-status
# offender scan below structurally cannot see a dae-role change on its
# own. See the header's "Tamper detection" note.
if [ "$is_lane" = 0 ]; then
  raw_role=$(cat "$marked/.artifacts/dae-role" 2>/dev/null | tr -d '[:space:]') || raw_role=""
  if [ "$raw_role" = "builder" ] && [ "$role" != "builder" ]; then
    echo "parent-tree-guard: DENIED — '$marked/.artifacts/dae-role' contains 'builder', which is not a legitimate role for this worktree. A parent worktree's genuine builder always runs in its own SIBLING lane child worktree, never via this file; 'builder' written directly into a parent's own marker is only ever forgery. This looks like a role-escalation attempt via direct write — revert the marker to its prior value ('orchestrator' or 'planner')." >&2
    exit 2
  fi
fi

status=$(git -C "$marked" status --porcelain 2>/dev/null) || exit 0
[ -n "$status" ] || exit 0

# resolve_root_dir <VAR> <default> <marked-worktree> [--expect path]
# Prints an absolute, realpath -m'd path. Never fails the caller: on any
# resolve-config.sh error (rejected value, missing script, anything) it
# falls back to <default> joined the same way — fail OPEN, never deny
# because config resolution had a problem. Copied verbatim from
# scope-writes.sh.
resolve_root_dir() {
  local var="$1" default="$2" root="$3"; shift 3
  local raw
  raw=$("$hookdir/resolve-config.sh" "$var" --default "$default" --root "$root" "$@" 2>/dev/null) || raw="$default"
  raw=$(printf '%s' "$raw" | sed -E 's/^\.?\///; s/\/+$//')
  realpath -m -- "$root/$raw" 2>/dev/null || printf '%s/%s' "$root" "$raw"
}

plans_root=$(resolve_root_dir CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$marked")
docs_root=$(resolve_root_dir CLAUDE_DOCS_DIR /docs "$marked" --expect path)
artifacts_root=$(realpath -m -- "$marked/.artifacts" 2>/dev/null || printf '%s/.artifacts' "$marked"); artifacts_root="${artifacts_root%/}"

# Parse porcelain v1 output into a list of changed absolute paths, classify
# each against the applicable role's rule (see the Role table above), and
# collect everything that fails classification as an offending change.
# .artifacts/ needs no special case: it's gitignored in the real repo, so
# `git status --porcelain` never reports it.
offenders=()
while IFS= read -r line; do
  [ -n "$line" ] || continue
  path="${line:3}"
  case "$path" in
    *' -> '*) path="${path##*' -> '}" ;;
  esac
  plen=${#path}
  if [ "$plen" -ge 2 ] && [ "${path:0:1}" = '"' ] && [ "${path: -1}" = '"' ]; then
    path="${path:1:plen-2}"
  fi
  [ -n "$path" ] || continue
  abs=$(realpath -m -- "$marked/$path" 2>/dev/null || printf '%s/%s' "$marked" "$path")
  case "$role" in
    builder)
      # Inverted: clean everywhere except a plans/docs collision.
      case "$abs" in
        "$plans_root" | "$plans_root"/* | "$docs_root" | "$docs_root"/*) : ;;
        *) continue ;;
      esac
      ;;
    planner)
      case "$abs" in
        "$plans_root" | "$plans_root"/*) continue ;;
      esac
      ;;
    scratch)
      case "$abs" in
        "$artifacts_root" | "$artifacts_root"/*) continue ;;
      esac
      ;;
    documenter)
      # Clean under docs_root ($abs is already realpath -m'd through any
      # symlink), or exactly plan.md under plans_root.
      case "$abs" in
        "$docs_root" | "$docs_root"/*) continue ;;
      esac
      if [[ "$abs" == "$plans_root"/* ]] && [ "$(basename -- "$abs")" = "plan.md" ]; then
        continue
      fi
      ;;
    orchestrator|*)
      # Also covers the (now unreachable in practice, since resolve_role
      # never returns empty for a marked, non-lane root) empty-role
      # fallback — one rule, no separate permissive copy.
      base=$(basename -- "$abs")
      case "$abs" in
        "$plans_root" | "$plans_root"/*)
          case "$base" in
            *-review.md | sync-report.md) continue ;;
          esac
          ;;
      esac
      ;;
  esac
  offenders+=("$abs")
done <<< "$status"

[ "${#offenders[@]}" -eq 0 ] && exit 0

{
  for o in "${offenders[@]}"; do
    echo "parent-tree-guard: DENIED — product file changed in the run's parent worktree: $o"
  done
  case "$role" in
    builder)
      echo "parent-tree-guard: a builder writes everywhere except the plans/docs roots (they collide with the real trees on merge-back); revert the change(s) above."
      ;;
    planner)
      echo "parent-tree-guard: the planner writes only the plans dir; revert the change(s) above."
      ;;
    scratch)
      # Reachable: the classification loop above only continues for a path
      # under $marked/.artifacts, so anything else (e.g. a product file at
      # the marked root) lands here.
      echo "parent-tree-guard: a scratch run writes only its own .artifacts directory; revert the change(s) above."
      ;;
    documenter)
      echo "parent-tree-guard: a documenter writes only the docs root, the plan's own plan.md, and symlinks into the docs root; revert the change(s) above."
      ;;
    orchestrator|*)
      echo "parent-tree-guard: the orchestrator writes only this run's own gate reports ('*-review.md' or 'sync-report.md' under the plans dir); revert the change(s) above."
      ;;
  esac
} >&2
exit 2
