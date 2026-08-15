#!/usr/bin/env bash
# Stop gate — runs tests for the files THIS session wrote (recorded by
# record-changed.sh). Exits 2 on failure so Claude is forced to fix.
#
# Parallel safety:
#   * State is keyed by session_id, so separate `claude` processes are isolated.
#   * The claim below is flock'd and truncates the list, so each recorded line
#     is tested exactly once even if sibling writers append concurrently.
#   * Wire to Stop (main agent) only — NOT SubagentStop — because SubagentStop
#     reports the *main* session_id, so a subagent finishing would otherwise
#     claim files a sibling is still editing. Stop = single consumer = no race.
#
# No jq dependency (jq is not on PATH); fields are grepped from the payload.
set -uo pipefail

payload=$(cat)

sfield() { # flat "name":"value"
  printf '%s' "$payload" \
    | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 | sed -E "s/\"$1\"[[:space:]]*:[[:space:]]*\"(.*)\"$/\1/"
}
bfield() { # flat "name":true|false -> the bool token
  printf '%s' "$payload" \
    | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*(true|false)" \
    | head -1 | grep -oE "(true|false)"
}

# Avoid the Stop-hook loop cap: if we already blocked once, let the stop proceed.
[ "$(bfield stop_hook_active)" = "true" ] && exit 0

sid=$(sfield session_id)
[ -n "$sid" ] || exit 0

dir="$HOME/.claude/state/test-changed"
state="$dir/$sid.list"
lock="$dir/$sid.lock"
[ -s "$state" ] || exit 0

# --- atomically claim the current list (snapshot + truncate) --------------
snap=$(mktemp "$dir/snap.XXXXXX")
( flock 9; cat "$state" >"$snap" 2>/dev/null; : >"$state" ) 9>"$lock"
[ -s "$snap" ] || { rm -f "$snap"; exit 0; }

mapfile -t claimed < <(sort -u "$snap")
rm -f "$snap"

# Keep only files that still exist (edits may have been reverted/deleted).
existing=()
for f in "${claimed[@]}"; do [ -f "$f" ] && existing+=("$f"); done
[ ${#existing[@]} -eq 0 ] && exit 0

# --- group files by git root, then by language ---------------------------
declare -A rootfiles
for f in "${existing[@]}"; do
  d=$(dirname "$f")
  root=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) || root="$d"
  rootfiles["$root"]+="$f"$'\n'
done

fail=0
report=""

add_fail() { report+="── $1 ──"$'\n'"$2"$'\n'; fail=1; }

for root in "${!rootfiles[@]}"; do
  mapfile -t files < <(printf '%s' "${rootfiles[$root]}" | grep -v '^$')

  js=(); go=(); py=()
  for f in "${files[@]}"; do
    case "$f" in
      *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.svelte) js+=("$f") ;;
      *.go)                                       go+=("$f") ;;
      *.py)                                       py+=("$f") ;;
    esac
  done

  # ---- JavaScript / TypeScript: vitest related --------------------------
  if [ ${#js[@]} -gt 0 ]; then
    vitest=""
    if [ -x "$root/node_modules/.bin/vitest" ]; then vitest="$root/node_modules/.bin/vitest"; fi
    if [ -n "$vitest" ]; then
      rel=(); for f in "${js[@]}"; do rel+=("$(realpath --relative-to="$root" "$f")"); done
      out=$(cd "$root" && "$vitest" related --run "${rel[@]}" 2>&1) \
        || add_fail "vitest ($root)" "$(printf '%s\n' "$out" | tail -30)"
    fi
    # No local vitest → nothing to run; stay silent (don't block the stop).
  fi

  # ---- Go: go test on the packages of changed files ---------------------
  if [ ${#go[@]} -gt 0 ] && command -v go >/dev/null 2>&1; then
    mapfile -t pkgs < <(printf '%s\n' "${go[@]}" | xargs -n1 dirname | sort -u)
    out=$(cd "$root" && go test "${pkgs[@]}" 2>&1) \
      || add_fail "go test ($root)" "$(printf '%s\n' "$out" | tail -30)"
  fi

  # ---- Python: pytest on changed test files / dirs of changed sources ---
  if [ ${#py[@]} -gt 0 ]; then
    pyrun=""
    if command -v pytest >/dev/null 2>&1; then pyrun="pytest"
    elif command -v python >/dev/null 2>&1 && python -m pytest --version >/dev/null 2>&1; then pyrun="python -m pytest"; fi
    if [ -n "$pyrun" ]; then
      targets=()
      for f in "${py[@]}"; do
        b=$(basename "$f")
        case "$b" in test_*.py|*_test.py) targets+=("$f") ;; *) targets+=("$(dirname "$f")") ;; esac
      done
      mapfile -t targets < <(printf '%s\n' "${targets[@]}" | sort -u)
      out=$(cd "$root" && $pyrun -q "${targets[@]}" 2>&1) \
        || add_fail "pytest ($root)" "$(printf '%s\n' "$out" | tail -30)"
    fi
  fi
done

if [ "$fail" -ne 0 ]; then
  {
    echo "Tests are failing on files changed this session — fix before stopping:"
    echo
    printf '%s' "$report"
  } >&2
  exit 2
fi

exit 0
