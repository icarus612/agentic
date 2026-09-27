#!/usr/bin/env bash
# workflow-diff-check.test.sh: blind contract test (lane 7, Packet 2); conventions match tests/parent-tree-guard.test.sh.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/agent-agnostic/hooks/workflow-diff-check.sh"
SETTINGS="$REPO_ROOT/agent-specific/claude/settings.json"

TOTAL_PASS=0
TOTAL_FAIL=0
SCRATCH_DIRS=()

cleanup() {
  local d
  for d in "${SCRATCH_DIRS[@]:-}"; do
    [ -n "$d" ] && [ -d "$d" ] && rm -rf "$d"
  done
}
trap cleanup EXIT

pass() {
  echo "PASS: $1"
  TOTAL_PASS=$((TOTAL_PASS + 1))
}

fail() {
  echo "FAIL: $1 ($2)"
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
}

new_scratch() {
  local d
  d=$(mktemp -d)
  SCRATCH_DIRS+=("$d")
  printf '%s' "$d"
}

git_init_repo() {
  local dir="$1"
  git init -q -b main "$dir"
  git -C "$dir" config user.email "workflow-diff-check-test@example.com"
  git -C "$dir" config user.name "workflow-diff-check-test"
}

commit_all() {
  local dir="$1" msg="$2"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m "$msg" >/dev/null
}

# Fresh repo, baseline commit, no .artifacts/progress-log.md anywhere.
new_plain_repo() {
  local dir
  dir=$(new_scratch)
  git_init_repo "$dir"
  printf '# fixture repo\n' >"$dir/README.md"
  commit_all "$dir" "baseline"
  printf '%s' "$dir"
}

# Like new_plain_repo, plus an untracked .artifacts/progress-log.md marker.
new_marked_parent() {
  local dir
  dir=$(new_scratch)
  git_init_repo "$dir"
  printf '# fixture repo\n' >"$dir/README.md"
  printf '.artifacts/\n' >"$dir/.gitignore"
  commit_all "$dir" "baseline"
  mkdir -p "$dir/.artifacts"
  printf 'baseline progress\n' >"$dir/.artifacts/progress-log.md"
  printf '%s' "$dir"
}

# new_marked_parent plus a fake always-failing vitest and a changed *.js file.
new_failing_marked_parent() {
  local dir
  dir=$(new_marked_parent)
  mkdir -p "$dir/node_modules/.bin"
  cat >"$dir/node_modules/.bin/vitest" <<'EOF'
#!/usr/bin/env bash
echo "WORKFLOW-DIFF-CHECK-TEST-FAKE-VITEST-FAILURE-MARKER: 1 failed" >&2
exit 1
EOF
  chmod +x "$dir/node_modules/.bin/vitest"
  mkdir -p "$dir/src"
  printf 'console.log("changed");\n' >"$dir/src/app.js"
  printf '%s' "$dir"
}

# run_diff_check <cwd-dir> [stdin-json] -- defaults stdin to {"cwd": <cwd-dir>};
# never cd's into the fixture (the hook must resolve "cwd" from JSON, not $PWD).
OUT=""
ERR=""
CODE=0
run_diff_check() {
  local cwd_dir="$1" stdin_json="${2-}"
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  if [ -z "${2+x}" ]; then
    stdin_json=$(printf '{"cwd": "%s"}' "$cwd_dir")
  fi
  printf '%s' "$stdin_json" | "$SCRIPT" >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# Case 00: bash -n sanity precondition (script must at least parse)
SYN_ERR_FILE=$(mktemp)
if bash -n "$SCRIPT" 2>"$SYN_ERR_FILE"; then
  pass "00: bash -n workflow-diff-check.sh exits 0"
else
  fail "00: bash -n workflow-diff-check.sh exits 0" "syntax error (or file missing): $(cat "$SYN_ERR_FILE")"
  rm -f "$SYN_ERR_FILE"
  echo "sanity failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
rm -f "$SYN_ERR_FILE"

case01() {
  local label="01: plain unmarked repo with a broken changed .js file -> exit 0 (self-scope excludes it)"
  local dir
  dir=$(new_plain_repo)
  mkdir -p "$dir/src"
  printf 'function broken( {\n  console.log("no closing paren"\n' >"$dir/src/broken.js"
  run_diff_check "$dir"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case01

case02() {
  local label="02: marked parent worktree, nothing changed since baseline -> exit 0"
  local dir
  dir=$(new_marked_parent)
  run_diff_check "$dir"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case02

case03() {
  local label="03: lane-child fixture, cwd=child -> exit 0 (self-scope excludes lane children)"
  local base parent child
  base=$(new_scratch)
  parent="$base/run"
  mkdir -p "$parent"
  git_init_repo "$parent"
  printf '# fixture repo\n' >"$parent/README.md"
  printf '.artifacts/\n' >"$parent/.gitignore"
  commit_all "$parent" "baseline"
  mkdir -p "$parent/.artifacts"
  printf 'baseline progress\n' >"$parent/.artifacts/progress-log.md"

  child="$base/run-l1"
  mkdir -p "$child"
  git_init_repo "$child"
  printf '# fixture repo (lane child)\n' >"$child/README.md"
  commit_all "$child" "baseline"
  mkdir -p "$child/src"
  printf 'console.log("changed in child");\n' >"$child/src/app.js"

  run_diff_check "$child"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case03

case04() {
  local label="04: positive control -- marked parent, genuinely failing check reachable -> exit 2"
  local dir
  dir=$(new_failing_marked_parent)
  run_diff_check "$dir"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "WORKFLOW-DIFF-CHECK-TEST-FAKE-VITEST-FAILURE-MARKER"; then
    fail "$label -> stderr contains the fake vitest's output" "err=[$ERR]"
    return
  fi
  pass "$label"
}
case04

case05() {
  local label="05: stop_hook_active=true on a genuinely failing fixture -> exit 0 (pre-existing short-circuit still fires first)"
  local dir stdin_json
  dir=$(new_failing_marked_parent)
  stdin_json=$(printf '{"cwd": "%s", "stop_hook_active": true}' "$dir")
  run_diff_check "$dir" "$stdin_json"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case05

case06() {
  local label="06: agent-specific/claude/settings.json's Stop hooks block wires workflow-diff-check.sh"
  if [ ! -f "$SETTINGS" ]; then
    fail "$label (prereq: settings.json exists)" "not found at $SETTINGS"
    return
  fi

  local stop_block=""
  if command -v jq >/dev/null 2>&1; then
    stop_block=$(jq -c '.hooks.Stop' "$SETTINGS" 2>/dev/null)
  fi
  if [ -z "$stop_block" ] || [ "$stop_block" = "null" ]; then
    # jq unavailable or empty: fall back to a plain text extraction.
    stop_block=$(sed -n '/"Stop"[[:space:]]*:/,/\]/p' "$SETTINGS")
  fi

  if [ -z "$stop_block" ]; then
    fail "$label (prereq: a Stop hooks block is present at all)" "could not locate hooks.Stop in $SETTINGS"
    return
  fi
  if ! printf '%s\n' "$stop_block" | grep -qF '~/.claude/hooks/workflow-diff-check.sh'; then
    fail "$label" "Stop block did not contain the expected command: [$stop_block]"
    return
  fi
  pass "$label"
}
case06

echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
