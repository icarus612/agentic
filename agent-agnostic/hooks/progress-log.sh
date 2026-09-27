#!/usr/bin/env bash
# progress-log.sh — the canonical way to (re)create and edit a run's
# progress-log.md.
#
# SYNOPSIS
#   progress-log.sh --init <run-dir> <name> <branch> <base>
#   progress-log.sh --set <run-dir> <section> <text...>
#   progress-log.sh --append <run-dir> <section> <text...>
#
# DESCRIPTION
#   Invoked by the dae orchestrator via Bash, NOT a hook — no hook-payload
#   JSON parsing here, same shape as mark-syllabus.sh. Scripting these edits
#   is what lets the orchestrator's write scope shrink to run artifacts: the
#   progress log is mutated only through this script.
#
#   <text...> is every argument after <section>, joined with a single space
#   (so `progress-log.sh --set <dir> Stage "Build." started` and
#   `progress-log.sh --set <dir> Stage "Build. started"` are equivalent).
#
#   --init  Creates <run-dir>/progress-log.md with a minimal seed (name,
#           branch, base, created timestamp, an empty "## State" section).
#           Never overwrites an existing file — exit 1 if the target already
#           exists.
#   --set   Finds the `##`-level heading whose text is a literal match for
#           <section>, and REPLACES the body between that heading and the
#           next `##` heading (or EOF) with <text...>. If no such heading
#           exists yet, a new `## <section>` heading is appended at the end
#           of the file with that body instead of erroring — sections grow
#           over a run's lifetime and the seed starts minimal.
#   --append  Same section-finding logic, but adds <text...> as a new line
#           at the END of that section's existing body, never replacing what
#           is already there. Creates the section (same fallback as --set)
#           if it does not exist yet.
#
#   Malformed args (wrong count, unknown flag, missing run-dir/file) are
#   always a usage error to stderr, exit 1 — never a silent no-op. --set and
#   --append against a run-dir with no progress-log.md yet also exit 1
#   (nothing to modify); only --init creates the file.
#
# EXIT CODES
#   0 - done (init created the file, or set/append edited it)
#   1 - usage error, target already exists (--init), or file missing (--set/--append)
set -uo pipefail

err() {
  echo "progress-log: $*" >&2
  exit 1
}

usage="usage: progress-log.sh --init <run-dir> <name> <branch> <base>
       progress-log.sh --set <run-dir> <section> <text...>
       progress-log.sh --append <run-dir> <section> <text...>"

mode="${1:-}"
[ -n "$mode" ] || err "$usage"
shift || true

case "$mode" in
  --init)
    [ "$#" -eq 4 ] || err "$usage"
    rundir="$1"; name="$2"; branch="$3"; base="$4"
    [ -n "$rundir" ] || err "$usage"
    [ -d "$rundir" ] || err "run dir not found: $rundir"
    logfile="$rundir/progress-log.md"
    [ -e "$logfile" ] && err "refusing to overwrite existing file: $logfile"
    {
      echo "# Run: $name"
      echo ""
      echo "- Branch: \`$branch\`"
      echo "- Base: \`$base\`"
      echo "- Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo ""
      echo "## State"
      echo ""
      echo "(not yet started)"
    } > "$logfile" || err "failed to write $logfile"
    ;;

  --set|--append)
    [ "$#" -ge 3 ] || err "$usage"
    rundir="$1"; section="$2"; shift 2
    text="$*"
    [ -n "$rundir" ] || err "$usage"
    [ -n "$section" ] || err "$usage"
    [ -n "$text" ] || err "$usage"
    logfile="$rundir/progress-log.md"
    [ -f "$logfile" ] || err "no progress-log.md at $rundir — --init must run first"

    tmp=$(mktemp) || err "mktemp failed"

    if [ "$mode" = "--set" ]; then
      awk -v section="$section" -v text="$text" '
        BEGIN { in_target = 0; found = 0 }
        $0 == "## " section {
          print $0
          print ""
          print text
          print ""
          in_target = 1
          found = 1
          next
        }
        in_target && /^## / {
          in_target = 0
        }
        in_target { next }
        { print $0 }
        END {
          if (!found) {
            print ""
            print "## " section
            print ""
            print text
          }
        }
      ' "$logfile" > "$tmp" || { rm -f "$tmp"; err "edit failed"; }
    else
      awk -v section="$section" -v text="$text" '
        BEGIN { in_target = 0; found = 0; appended = 0 }
        $0 == "## " section {
          print $0
          in_target = 1
          found = 1
          next
        }
        in_target && /^## / {
          if (!appended) {
            print text
            appended = 1
          }
          in_target = 0
          print $0
          next
        }
        { print $0 }
        END {
          if (found && in_target && !appended) {
            print text
          }
          if (!found) {
            print ""
            print "## " section
            print ""
            print text
          }
        }
      ' "$logfile" > "$tmp" || { rm -f "$tmp"; err "edit failed"; }
    fi

    mv "$tmp" "$logfile" || { rm -f "$tmp"; err "failed to update $logfile"; }
    ;;

  *)
    err "$usage"
    ;;
esac
