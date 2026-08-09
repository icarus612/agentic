#!/usr/bin/env bash
# verify-scope.sh — check a builder's reported files against its lane's real diff.
#
# SYNOPSIS
#   verify-scope.sh <worktree-path> <parent-branch> [<reported-file>...]
#   verify-scope.sh <worktree-path> <parent-branch> --report <exit-report>
#   (reported files may also arrive on stdin, one per line)
#
# DESCRIPTION
#   Invoked by the dae orchestrator's dispatch loop before merging a lane's
#   child branch back into the parent. Computes what ACTUALLY changed in the
#   child worktree relative to the parent branch (committed, staged, and
#   untracked) and compares it to what the builder REPORTED touching:
#     UNREPORTED: <file>  - changed on disk but absent from the report -> FAIL
#     UNCHANGED:  <file>  - reported but shows no change -> warning only
#   Paths are compared repo-relative. An UNREPORTED file means the exit
#   report can't be trusted as a scope record — resolve before merge-back
#   (the merge itself is the second, physical check: a conflict against a
#   sibling lane is a mechanical scope violation).
#
#   The optional --report <exit-report> flag is an additive, exclusive input
#   mode: instead of reading reported files from argv/stdin, it reads the
#   report's "## Files touched" section through claims_from_report(), the
#   same accepted-format rules (backticked paths, trailing annotations,
#   trailing commas, `./` prefixes, absolute paths) used by
#   verify-run-scope.sh. When --report is given, argv/stdin are not also
#   read. When it is absent, the original argv/stdin behavior is unchanged.
#
# EXIT CODES
#   0 - report matches the diff (UNCHANGED warnings allowed)
#   1 - usage error, or one or more UNREPORTED files
set -uo pipefail

err() { echo "verify-scope: $*" >&2; exit 1; }

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

wt="${1:-}"; parent="${2:-}"; shift 2 2>/dev/null || true
[ -n "$wt" ] && [ -n "$parent" ] || err "usage: verify-scope.sh <worktree-path> <parent-branch> [<reported-file>...]"
[ -d "$wt" ] || err "worktree path not found: $wt"
git -C "$wt" rev-parse --verify -q "$parent" >/dev/null || err "parent branch '$parent' does not exist"

report_file=""
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --report)
      report_file="${2:-}"
      shift 2 2>/dev/null || shift $#
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done
if [ "${#args[@]}" -gt 0 ]; then set -- "${args[@]}"; else set --; fi

if [ -n "$report_file" ]; then
  [ -f "$report_file" ] || err "report file not found: $report_file"
  reported=$(claims_from_report "$report_file" "$wt")
else
  reported=$(printf '%s\n' "$@")
  if [ ! -t 0 ]; then reported="$reported
$(cat)"; fi
fi
reported=$(printf '%s\n' "$reported" | sed '/^$/d' | sort -u)

changed=$( { git -C "$wt" diff --name-only "$parent"...HEAD;
             git -C "$wt" diff --name-only HEAD;          # unstaged
             git -C "$wt" diff --name-only --cached;      # staged
             git -C "$wt" ls-files --others --exclude-standard; } | sort -u | sed '/^$/d')

fail=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  printf '%s\n' "$reported" | grep -qxF "$f" || { echo "UNREPORTED: $f"; fail=1; }
done <<< "$changed"

while IFS= read -r f; do
  [ -n "$f" ] || continue
  printf '%s\n' "$changed" | grep -qxF "$f" || echo "UNCHANGED: $f (reported but no diff)"
done <<< "$reported"

[ "$fail" = 0 ] && echo "OK: reported files match the lane diff ($(printf '%s\n' "$changed" | sed '/^$/d' | wc -l | tr -d ' ') changed)"
exit "$fail"
