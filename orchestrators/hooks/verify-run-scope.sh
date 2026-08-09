#!/usr/bin/env bash
# verify-run-scope.sh — every product change in a run must be claimed by a
# builder exit report.
#
# SYNOPSIS
#   verify-run-scope.sh <parent-worktree> <base-branch> <run-dir> [--allow <prefix>[:<prefix>...]]
#
# DESCRIPTION
#   The run-level counterpart of verify-scope.sh (which checks ONE lane
#   against its report before merge-back). This checks the WHOLE run at the
#   PR gate: the parent branch's diff against the base, minus every file
#   claimed by a `reports/*-exit.md` "## Files touched" list, minus the
#   harness-owned paths (the plans dir and local docs dir, resolved via
#   resolve-config.sh; .gitignore; plus any --allow prefixes). Whatever
#   remains is an UNCLAIMED product change — code nobody's exit report owns,
#   which per the dae invariants means someone (usually the orchestrator)
#   edited the product directly instead of dispatching a builder. The
#   review-pr gate treats every UNCLAIMED line as a blocking finding.
#
#   Prompt discipline is not enforcement; this is the mechanical check that
#   makes the "orchestrator writes are harness-scoped" invariant auditable
#   after the fact, from artifacts alone.
#
# EXIT CODES
#   0 - all product changes claimed (or allowed)
#   1 - usage error, or one or more UNCLAIMED files
set -uo pipefail

err() { echo "verify-run-scope: $*" >&2; exit 1; }

wt="${1:-}"; base="${2:-}"; rundir="${3:-}"; shift 3 2>/dev/null || true
allow_extra=""
if [ "${1:-}" = "--allow" ]; then allow_extra="${2:-}"; fi
[ -n "$wt" ] && [ -n "$base" ] && [ -n "$rundir" ] \
  || err "usage: verify-run-scope.sh <parent-worktree> <base-branch> <run-dir> [--allow <prefix>[:...]]"
[ -d "$wt" ] || err "parent worktree not found: $wt"
[ -d "$rundir" ] || err "run dir not found: $rundir (expected <worktree>/.artifacts)"
git -C "$wt" rev-parse --verify -q "$base" >/dev/null || err "base branch '$base' does not exist"

hookdir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# --- harness-owned prefixes (repo-relative, no leading slash) ---------------
plans=$("$hookdir/resolve-config.sh" CLAUDE_PROJECT_PLANS_DIR --default /project-plans/ --root "$wt" 2>/dev/null || echo /project-plans/)
docs=$("$hookdir/resolve-config.sh" CLAUDE_DOCS_DIR --default /docs --root "$wt" 2>/dev/null || echo /docs)
allowed=".gitignore"
norm() { printf '%s' "$1" | sed -E 's/^\.?\///; s/\/+$//'; }
allowed="$allowed
$(norm "$plans")"
case "$docs" in
  http*|confluence:*) : ;;                # docs live off-repo — no local docs allowance
  *) allowed="$allowed
$(norm "$docs")" ;;
esac
if [ -n "$allow_extra" ]; then
  IFS=':' read -r -a extras <<< "$allow_extra"
  for e in "${extras[@]}"; do [ -n "$e" ] && allowed="$allowed
$(norm "$e")"; done
fi

# --- what actually changed (committed + staged + unstaged + untracked) ------
changed=$( { git -C "$wt" diff --name-only "$base"...HEAD;
             git -C "$wt" diff --name-only HEAD;
             git -C "$wt" diff --name-only --cached;
             git -C "$wt" ls-files --others --exclude-standard; } | sort -u | sed '/^$/d')

# --- what the exit reports claim -------------------------------------------
claimed=""
for r in "$rundir"/reports/*-exit.md; do
  [ -f "$r" ] || continue
  claimed="$claimed
$(awk '/^## Files touched/{f=1;next} /^## /{f=0} f' "$r" | grep -E '^\s*- \S' | sed -E 's/^\s*- //')"
done
claimed=$(printf '%s\n' "$claimed" | sed '/^$/d' | sort -u)
reports=$(ls "$rundir"/reports/*-exit.md 2>/dev/null | wc -l | tr -d ' ')

fail=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  printf '%s\n' "$claimed" | grep -qxF "$f" && continue
  ok=0
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    if [ "$f" = "$a" ] || [[ "$f" == "$a"/* ]]; then ok=1; break; fi
  done <<< "$allowed"
  [ "$ok" = 1 ] && continue
  echo "UNCLAIMED: $f"
  fail=1
done <<< "$changed"

total=$(printf '%s\n' "$changed" | sed '/^$/d' | wc -l | tr -d ' ')
if [ "$fail" = 0 ]; then
  echo "OK: all $total changed files claimed by $reports exit report(s) or harness-owned"
else
  echo "FAIL: unclaimed product changes above — no exit report owns them ($reports exit report(s) read)"
fi
exit "$fail"
