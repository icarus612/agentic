#!/usr/bin/env bash
# verify-run-scope.sh — every product change in a run must be claimed by a
# builder exit report.
#
# SYNOPSIS
#   verify-run-scope.sh <parent-worktree> <base-branch> <run-artifacts-dir> [--allow <prefix>[:<prefix>...]]
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
#   claims_from_report() below is the single definition of what counts as a
#   claim line: backticked paths, trailing annotations, trailing commas,
#   `./` prefixes, and absolute paths are all normalized to one repo-relative
#   token per bullet. validate-report.sh's own "## Files touched" line count
#   is deliberately left permissive and is NOT tightened to match this
#   parser's accepted formats — tightening it would retroactively invalidate
#   exit reports that already passed and fight the markdown builders
#   naturally write. This parser, not the validator, is the single place
#   that defines which claim-line shapes are accepted; a future change
#   should extend claims_from_report, never validate-report.sh's counter.
#
# EXIT CODES
#   0 - all product changes claimed (or allowed)
#   1 - usage error, or one or more UNCLAIMED files
set -uo pipefail

err() { echo "verify-run-scope: $*" >&2; exit 1; }

claims_from_report() {
  # $1 = exit-report file path, $2 = worktree root (for abs->relative conversion)
  # prints one repo-relative claimed path per line to stdout
  # prints "NOTE: ..." to stderr for any multi-backtick bullet
  local report="$1" root="$2"
  local resolved_root
  resolved_root=$(realpath -m -- "$root" 2>/dev/null || printf '%s' "$root")
  awk '/^## Files touched/{f=1;next} /^## /{f=0} f' "$report" \
    | grep -E '^[[:space:]]*[-*][[:space:]]+\S' \
    | while IFS= read -r line; do
        remainder=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*[-*][[:space:]]+//')
        backticks=$(printf '%s' "$remainder" | grep -oE '`[^`]+`')
        bt_count=$(printf '%s\n' "$backticks" | sed '/^$/d' | wc -l | tr -d ' ')
        if [ "$bt_count" -ge 1 ]; then
          token=$(printf '%s\n' "$backticks" | head -n1)
          token="${token#\`}"
          token="${token%\`}"
          if [ "$bt_count" -gt 1 ]; then
            echo "NOTE: ${report}: multiple backticked paths on one bullet, using first: ${remainder}" >&2
          fi
        else
          token=$(printf '%s' "$remainder" | awk '{print $1}')
          token="${token%,}"; token="${token%;}"; token="${token%:}"
        fi

        # normalization tail — shared by both extraction branches above
        tlen=${#token}
        if [ "$tlen" -ge 2 ]; then
          first_c="${token:0:1}"; last_c="${token: -1}"
          if { [ "$first_c" = "'" ] && [ "$last_c" = "'" ]; } || { [ "$first_c" = '"' ] && [ "$last_c" = '"' ]; }; then
            token="${token:1:tlen-2}"
          fi
        fi
        case "$token" in
          ./*) token="${token#./}" ;;
        esac
        case "$token" in
          /*)
            resolved_token=$(realpath -m -- "$token" 2>/dev/null || printf '%s' "$token")
            case "$resolved_token" in
              "$resolved_root") token="" ;;
              "$resolved_root"/*) token="${resolved_token#"$resolved_root"/}" ;;
              *) token="$resolved_token" ;;
            esac
            ;;
        esac

        [ -n "$token" ] || continue
        printf '%s\n' "$token"
      done
}

wt="${1:-}"; base="${2:-}"; rundir="${3:-}"; shift 3 2>/dev/null || true
allow_extra=""
if [ "${1:-}" = "--allow" ]; then allow_extra="${2:-}"; fi
[ -n "$wt" ] && [ -n "$base" ] && [ -n "$rundir" ] \
  || err "usage: verify-run-scope.sh <parent-worktree> <base-branch> <run-artifacts-dir> [--allow <prefix>[:...]]"
[ -d "$wt" ] || err "parent worktree not found: $wt"
[ -d "$rundir" ] || err "run-artifacts dir not found: $rundir"
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
$(claims_from_report "$r" "$wt")"
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
