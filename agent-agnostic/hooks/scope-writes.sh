#!/usr/bin/env bash
# scope-writes.sh — PreToolUse hook denying file writes outside the run's
# allowed write roots.
#
# SYNOPSIS  (wired as a PreToolUse hook; reads the tool-call JSON on stdin)
#   scope-writes.sh
#
# DESCRIPTION
#   Self-configuring: no env var, no invocation-time setup. On every
#   Write/Edit/NotebookEdit-shaped call the hook takes the write target
#   path and walks UP its ancestors looking for a marker. Two shapes of
#   marker exist:
#     - `.artifacts/progress-log.md` at the root of a dae run's PARENT
#       worktree (see the `find_parent_worktree` helper below).
#     - a lane child worktree (named `<parent-name>-l<n>`, a SIBLING of
#       its parent, never nested inside it) whose sibling parent carries
#       the marker above (see the `find_lane_root` helper below) — a
#       builder's own child worktree is never marked directly, per
#       run-artifacts' "a builder's child worktree never gets a run dir".
#   A directory with neither marker anywhere above it is INERT there
#   (exit 0 unconditionally) — a bare checkout, a run predating this
#   feature, or anything else with no run dir in its ancestry.
#
#   When a marker IS found, the hook resolves a role token (see the
#   `resolve_role` helper below: one of `orchestrator`/`planner`/`builder`/
#   `scratch` — `resolve_role` never returns empty for a marked, non-lane
#   root; a missing/unreadable/garbage token or a rejected `builder` claim
#   resolve structurally, on the same main_checkout signal `builder` itself
#   uses: to `orchestrator` when the marked root is a LINKED worktree (a
#   real dae parent), or to `scratch` when the marked root IS the main
#   checkout — a `ship: chat` run's scratch marker, or a `--worktree none`
#   run with a corrupted token — never to a separate permissive fallback)
#   and enforces a DIFFERENT rule per role (plus `documenter`, resolved
#   from `agent_type` rather than the marker — see below):
#     - `orchestrator` (including a missing/unreadable/garbage token in a
#       LINKED worktree parent, and a `builder` claim rejected because the
#       marked root isn't the main checkout): allowed only under the plans
#       root, and only for a path whose basename matches `*-review.md` or
#       is exactly `sync-report.md` (zero outside this run's own gate
#       reports). An unresolved role used to fall back to a permissive
#       plans+docs+artifacts allowance instead — that was itself the
#       escalation vector DP-2 exists to prevent, so it no longer happens.
#     - `planner`: allowed only inside the resolved plans root.
#     - `builder`: allowed EVERYWHERE except inside the plans root or the
#       docs root (both resolved relative to the marked worktree — for a
#       lane-root builder that is the child's own local project-plans/ and
#       docs/ paths, the ones that would collide with the real trees on
#       merge-back).
#     - `scratch` (a missing/unreadable/garbage token in the MAIN
#       CHECKOUT): allowed only under the marker root itself,
#       `<marked>/.artifacts` — a `ship: chat` run's own scratch tree
#       (resolve-scratch.sh's SCRATCHDIR) always lives under it, and
#       nothing outside it is legitimate for a main-checkout marker with
#       no recognized role.
#     - `documenter` (from `agent_type`, never a marker): the docs root
#       plus `plan.md` under the plans root; nothing else.
#   A write outside the applicable role's allowed scope is DENIED (exit 2;
#   stderr fed back to the model, naming the rule, the offending path, and
#   the specific allowed/denied root(s) for that role).
#
#   Hooks enforce, skills judge. Reads outside these roots are always
#   fine — this guards mutations only. Bash is NOT intercepted (a
#   PreToolUse hook cannot see inside a shell command).
#
#   The worktree + branch isolation backstop holds for a BUILDER: its
#   child worktree has no marker anywhere above it, so this hook never
#   engages there — but it does NOT hold for the ORCHESTRATOR, which runs
#   directly in the marked parent worktree with the whole product tree
#   underfoot. This hook is that backstop for the orchestrator's own
#   Write/Edit calls; `parent-tree-guard.sh` (a sibling hook, landing in
#   this same lane) is the analogous Bash-side backstop for orchestrator
#   shell commands.
#
#   Shared abstraction note. Four helpers below — `find_parent_worktree`
#   (the marker walk), `find_lane_root` (the lane-child structural walk),
#   `resolve_role` (role-token resolution), and `resolve_root_dir`
#   (plans/docs root resolution, fail-open) — are duplicated VERBATIM
#   into `parent-tree-guard.sh`. The duplication is deliberate: each hook
#   must run standalone, with no sourcing of a third file, so a broken or
#   missing sibling can never take both enforcement paths down at once.
#   The cost is that the four copies MUST be kept byte-identical — if
#   they drift, the Write/Edit side and the Bash side start disagreeing
#   about what counts as "the parent worktree", "a lane root", "the
#   current role", or "the plans/docs root", which is exactly the
#   split-brain this note exists to prevent. Change one, change all, in
#   the same commit.
#
#   `resolve_role` also rejects a `builder` token written directly into a
#   parent worktree's own marker (honoring it only when the marked root is
#   the main checkout, `--worktree none`'s only signal for builder-ness) —
#   a genuine builder in `new`/`resume` mode always lives in its own SIBLING
#   lane child instead, so a parent's own `builder` marker is only ever
#   forgery. That rejection resolves to `orchestrator`, unchanged — a
#   rejected `builder` claim only ever happens in a LINKED worktree parent,
#   the same main_checkout=0 case that keeps every other unresolved role at
#   `orchestrator` too. A missing/unreadable/garbage token, by contrast,
#   resolves structurally on the same main_checkout signal: `orchestrator`
#   in a linked worktree parent, `scratch` when the marked root IS the main
#   checkout — see `resolve_role`'s own doc-comment. `parent-tree-guard.sh`
#   additionally denies on the builder-forgery pattern directly (tamper
#   detection), independent of any other file change, since `.artifacts/`
#   is gitignored and invisible to a git-status scan.
#
# EXIT CODES
#   0 - allowed (no marker found above the write target / not a write
#       tool / no path in input / malformed or empty stdin)
#   2 - denied: write target outside the run's allowed write roots
set -uo pipefail

hookdir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# find_parent_worktree <start-path>
# Prints the marked parent worktree's absolute path and returns 0, or
# returns 1 with nothing printed. Pure string ascent (dirname), never `cd`,
# so it tolerates a <start-path> that does not exist yet (a new file being
# written) as well as one that does (a cwd).
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

# resolve_root_dir <VAR> <default> <marked-worktree> [--expect path]
# Prints an absolute, realpath -m'd path. Never fails the caller: on any
# resolve-config.sh error (rejected value, missing script, anything) it
# falls back to <default> joined the same way — fail OPEN, never deny
# because config resolution had a problem.
resolve_root_dir() {
  local var="$1" default="$2" root="$3"; shift 3
  local raw
  raw=$("$hookdir/resolve-config.sh" "$var" --default "$default" --root "$root" "$@" 2>/dev/null) || raw="$default"
  raw=$(printf '%s' "$raw" | sed -E 's/^\.?\///; s/\/+$//')
  realpath -m -- "$root/$raw" 2>/dev/null || printf '%s/%s' "$root" "$raw"
}

input=$(cat 2>/dev/null || true)
[ -n "$input" ] || exit 0

# tool_name, without jq (env block-style flat extraction, same as resolve-config.sh)
tool=$(printf '%s' "$input" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')
case "$tool" in
  Write | Edit | MultiEdit | NotebookEdit | \
    write_to_file | *:write_to_file | \
    replace_file_content | *:replace_file_content | \
    multi_replace_file_content | *:multi_replace_file_content) : ;;
  *) exit 0 ;;
esac

# target path: file_path (Write/Edit) or notebook_path (NotebookEdit) or TargetFile (Antigravity)
path=$(printf '%s' "$input" | grep -oE '"(file_path|notebook_path|TargetFile)"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')
[ -n "$path" ] || exit 0
path=$(realpath -m -- "$path" 2>/dev/null || printf '%s' "$path")

agent_type=$(printf '%s' "$input" | grep -oE '"agent_type"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')

# Fix A: agent_type == "builder" (harness-supplied) gates identity; cwd is
# only the lane selector once that holds -- cwd alone follows a plain `cd`.
cwd=$(printf '%s' "$input" | grep -oE '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')
if [ "$agent_type" = "builder" ] && [ -n "$cwd" ] && cwd_lane_root=$(find_lane_root "$cwd"); then
  cwd_base=$(basename -- "$cwd_lane_root")
  if [[ "$cwd_base" =~ ^(.+)-l([0-9]+)$ ]]; then
    lane_id="l${BASH_REMATCH[2]}"
    lane_parent=$(realpath -m -- "$(dirname -- "$cwd_lane_root")/${BASH_REMATCH[1]}" 2>/dev/null)
    if [ "$path" = "$lane_parent/.artifacts/contracts/$lane_id.md" ] || \
       [ "$path" = "$lane_parent/.artifacts/reports/$lane_id-exit.md" ]; then
      exit 0
    fi
  fi
fi

marked=""; is_lane=0
if marked=$(find_parent_worktree "$path"); then
  is_lane=0
elif marked=$(find_lane_root "$path"); then
  is_lane=1
else
  exit 0
fi
role=$(resolve_role "$marked" "$is_lane" "$agent_type")

case "$role" in
  builder)
    # Deny-list: everything is allowed except the plans/docs roots, which
    # would collide with the real trees on merge-back.
    plans_root=$(resolve_root_dir CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$marked")
    docs_root=$(resolve_root_dir CLAUDE_DOCS_DIR /docs "$marked" --expect path)
    plans_root="${plans_root%/}"
    docs_root="${docs_root%/}"
    if [ "$path" = "$plans_root" ] || [[ "$path" == "$plans_root"/* ]] || \
       [ "$path" = "$docs_root" ] || [[ "$path" == "$docs_root"/* ]]; then
      echo "scope-writes: DENIED — $tool to '$path' is inside a builder's excluded roots (this is the builder write-scope guard). Denied roots: '$plans_root', '$docs_root'. A lane builds product code only; plans/docs changes belong to the planner/orchestrator, not a lane — report the scope gap instead of working around it." >&2
      exit 2
    fi
    exit 0
    ;;
  planner)
    # Allow-list: the plans dir, plus (Fix B) the run dir's own explore-map.
    plans_root=$(resolve_root_dir CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$marked")
    plans_root="${plans_root%/}"
    artifacts_root=$(realpath -m -- "$marked/.artifacts" 2>/dev/null || printf '%s/.artifacts' "$marked")
    artifacts_root="${artifacts_root%/}"
    if [ "$(dirname -- "$path")" = "$artifacts_root" ] && [[ "$(basename -- "$path")" == explore-map-*.md ]]; then
      exit 0
    fi
    # (Fix C) Plus a committee's own claims/accepted/reverify files, below.
    committees_root=$(realpath -m -- "$marked/.artifacts/committees" 2>/dev/null || printf '%s/.artifacts/committees' "$marked")
    committees_root="${committees_root%/}"
    base=$(basename -- "$path")
    if [ "$(dirname -- "$(dirname -- "$path")")" = "$committees_root" ] && \
       { [ "$base" = "accepted.md" ] || [ "$base" = "reverify.md" ] || [[ "$base" =~ ^claims-c[0-9]+\.md$ ]]; }; then
      exit 0
    fi
    if [ "$path" = "$plans_root" ] || [[ "$path" == "$plans_root"/* ]]; then
      exit 0
    fi
    echo "scope-writes: DENIED — $tool to '$path' is outside the planner's allowed write scope (this is the planner write-scope guard). Allowed root: '$plans_root'. The planner writes only the plans dir; delegate other changes or report the scope gap instead of working around it." >&2
    exit 2
    ;;
  scratch)
    # Allow-list of exactly the marker root itself: <marked>/.artifacts —
    # the directory whose progress-log.md is what marks this root at all.
    # A `ship: chat` run's own scratch tree (resolve-scratch.sh's
    # SCRATCHDIR, always <marked>/.artifacts/reports/<slug>-<runid>/ for
    # an in-repo resolution) lives under it, and nothing outside it is
    # legitimate for a main-checkout marker with no recognized role.
    artifacts_root=$(realpath -m -- "$marked/.artifacts" 2>/dev/null || printf '%s/.artifacts' "$marked")
    artifacts_root="${artifacts_root%/}"
    if [ "$path" = "$artifacts_root" ] || [[ "$path" == "$artifacts_root"/* ]]; then
      exit 0
    fi
    echo "scope-writes: DENIED — $tool to '$path' is outside the scratch run's allowed write scope (this is the scratch write-scope guard). Allowed root: '$artifacts_root'. A ship:chat run writes only its own scratch tree; report the scope gap instead of working around it." >&2
    exit 2
    ;;
  documenter)
    # Allow-list: the full docs root, plus exactly plan.md under the plans
    # root (the active plan's own syllabus, ticked/annotated on close-out).
    docs_root=$(resolve_root_dir CLAUDE_DOCS_DIR /docs "$marked" --expect path)
    plans_root=$(resolve_root_dir CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$marked")
    docs_root="${docs_root%/}"
    plans_root="${plans_root%/}"
    base=$(basename -- "$path")
    if [ "$path" = "$docs_root" ] || [[ "$path" == "$docs_root"/* ]]; then
      exit 0
    fi
    if { [ "$path" = "$plans_root" ] || [[ "$path" == "$plans_root"/* ]]; } && [ "$base" = "plan.md" ]; then
      exit 0
    fi
    echo "scope-writes: DENIED — $tool to '$path' is outside the documenter's allowed write scope (this is the documenter write-scope guard). Allowed roots: '$docs_root' (full), and any 'plan.md' under '$plans_root'. A documenter records docs and ticks the plan syllabus, nothing else; report the scope gap instead of working around it." >&2
    exit 2
    ;;
  orchestrator|*)
    # Allow-list of exactly the run's own gate reports under the plans
    # root. This also covers the (now unreachable in practice, since
    # resolve_role never returns empty for a marked, non-lane root)
    # empty-role fallback — one rule, no separate permissive copy.
    # (Fix B) Plus the run dir's own explore-map file, below.
    plans_root=$(resolve_root_dir CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$marked")
    plans_root="${plans_root%/}"
    base=$(basename -- "$path")
    artifacts_root=$(realpath -m -- "$marked/.artifacts" 2>/dev/null || printf '%s/.artifacts' "$marked")
    artifacts_root="${artifacts_root%/}"
    if [ "$(dirname -- "$path")" = "$artifacts_root" ] && [[ "$base" == explore-map-*.md ]]; then
      exit 0
    fi
    # (Fix C) Plus a committee's own claims/accepted/reverify files, below.
    committees_root=$(realpath -m -- "$marked/.artifacts/committees" 2>/dev/null || printf '%s/.artifacts/committees' "$marked")
    committees_root="${committees_root%/}"
    if [ "$(dirname -- "$(dirname -- "$path")")" = "$committees_root" ] && \
       { [ "$base" = "accepted.md" ] || [ "$base" = "reverify.md" ] || [[ "$base" =~ ^claims-c[0-9]+\.md$ ]]; }; then
      exit 0
    fi
    if { [ "$path" = "$plans_root" ] || [[ "$path" == "$plans_root"/* ]]; } \
        && { [[ "$base" == *-review.md ]] || [ "$base" = "sync-report.md" ]; }; then
      exit 0
    fi
    echo "scope-writes: DENIED — $tool to '$path' is outside the orchestrator's allowed write scope (this is the orchestrator write-scope guard). Zero outside this run's own gate reports: '*-review.md' or 'sync-report.md' under '$plans_root'. Use progress-log.sh, plan-lifecycle.sh, or report-verdict.sh for the orchestrator's other artifact mutations instead of a direct write — the plan file's own syllabus is never the orchestrator's to touch, at any stage: that write belongs to the documenter agent at Record, via mark-syllabus.sh." >&2
    exit 2
    ;;
esac
