#!/usr/bin/env bash
# workflow-diff-check.sh — Stop/SubagentStop gate for dev-workflow worktrees.
#
# Simplified replacement for the record-changed.sh + test-changed.sh pair:
# the workflow runs on a dedicated worktree branch, so changed files come
# straight from git diff (committed since base + staged + unstaged) — no
# per-session state, no locking, no PostToolUse recorder.
#
# Wired via frontmatter hooks on the dev skill (Stop) and the
# builder agent (Stop → SubagentStop), so it only runs while the dev
# workflow is active.
#
# EXIT CODES
#   0 - checks passed, nothing changed, or nothing runnable (never blocks
#       for infrastructure reasons)
#   2 - test failures on changed files; stderr tells Claude what to fix
#
# No jq dependency; fields are grepped from the flat JSON payload.
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

cwd=$(sfield cwd)
{ [ -n "$cwd" ] && [ -d "$cwd" ]; } || cwd="$PWD"
cd "$cwd" || exit 0
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root"

# --- changed files: committed-since-base + staged + unstaged + untracked ---
base=""
if git rev-parse --verify -q origin/main >/dev/null; then base="origin/main"
elif git rev-parse --verify -q main >/dev/null; then base="main"; fi

mapfile -t changed < <(
  {
    if [ -n "$base" ]; then
      mb=$(git merge-base "$base" HEAD 2>/dev/null) && git diff --name-only "$mb" 2>/dev/null
    fi
    git diff --name-only
    git diff --name-only --cached
    git ls-files --others --exclude-standard
  } | sort -u | grep -v '^$'
)
[ ${#changed[@]} -eq 0 ] && exit 0

# Keep only files that still exist (renames/deletes drop out).
js=(); go=(); py=()
for f in "${changed[@]}"; do
  [ -f "$f" ] || continue
  case "$f" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.svelte) js+=("$f") ;;
    *.go)                                       go+=("$f") ;;
    *.py)                                       py+=("$f") ;;
  esac
done

fail=0
report=""
add_fail() { report+="── $1 ──"$'\n'"$2"$'\n'; fail=1; }

# ---- JavaScript / TypeScript: vitest related ------------------------------
if [ ${#js[@]} -gt 0 ] && [ -x "$root/node_modules/.bin/vitest" ]; then
  out=$("$root/node_modules/.bin/vitest" related --run "${js[@]}" 2>&1) \
    || add_fail "vitest ($root)" "$(printf '%s\n' "$out" | tail -30)"
fi
# No local vitest → nothing to run; stay silent (don't block the stop).

# ---- Go: go test on the packages of changed files -------------------------
if [ ${#go[@]} -gt 0 ] && command -v go >/dev/null 2>&1; then
  mapfile -t pkgs < <(printf '%s\n' "${go[@]}" | xargs -n1 dirname | sort -u | sed 's|^|./|')
  out=$(go test "${pkgs[@]}" 2>&1) \
    || add_fail "go test ($root)" "$(printf '%s\n' "$out" | tail -30)"
fi

# ---- Python: pytest on changed test files / dirs of changed sources -------
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
    out=$($pyrun -q "${targets[@]}" 2>&1) \
      || add_fail "pytest ($root)" "$(printf '%s\n' "$out" | tail -30)"
  fi
fi

if [ "$fail" -ne 0 ]; then
  {
    echo "Tests are failing on this workflow branch's changed files — fix before stopping:"
    echo
    printf '%s' "$report"
  } >&2
  exit 2
fi

exit 0
