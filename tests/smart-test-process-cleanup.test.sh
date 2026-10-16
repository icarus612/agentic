#!/usr/bin/env bash
# Contract tests for smart-test.sh owning-package scope and process containment.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${SMART_TEST_SCRIPT:-$REPO_ROOT/agent-agnostic/hooks/smart-test.sh}"

TOTAL_PASS=0
TOTAL_FAIL=0
SCRATCH_DIRS=()
TOKENS=()
HOOK_PIDS=()

pass() {
  echo "PASS: $1"
  TOTAL_PASS=$((TOTAL_PASS + 1))
}

fail() {
  echo "FAIL: $1 ($2)"
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
}

cleanup() {
  local t d p
  for p in "${HOOK_PIDS[@]:-}"; do
    [ -n "$p" ] && kill -KILL "$p" 2>/dev/null
  done
  for t in "${TOKENS[@]:-}"; do
    [ -n "$t" ] && pkill -KILL -f "^sleep $t\$" 2>/dev/null
  done
  for d in "${SCRATCH_DIRS[@]:-}"; do
    [ -n "$d" ] && [ -d "$d" ] && rm -rf "$d"
  done
  return 0
}
trap cleanup EXIT

new_token() {
  local t="7${RANDOM}${RANDOM}${RANDOM}"
  TOKENS+=("$t")
  printf '%s' "$t"
}

token_alive() {
  pgrep -f "^sleep $1\$" >/dev/null 2>&1
}

wait_for_token() {
  local i
  for i in $(seq 1 100); do
    token_alive "$1" && return 0
    sleep 0.1
  done
  return 1
}

wait_for_token_gone() {
  local i
  for i in $(seq 1 50); do
    token_alive "$1" || return 0
    sleep 0.1
  done
  return 1
}

# new_fixture <pkg-test-body> -- prints fixture root
new_fixture() {
  local d
  d=$(mktemp -d)
  SCRATCH_DIRS+=("$d")
  mkdir -p "$d/packages/a/src"
  cat >"$d/package.json" <<'EOF'
{"name":"root","private":true,"scripts":{"test":"sh ./root-test.sh; turbo test"}}
EOF
  : >"$d/pnpm-lock.yaml"
  printf 'touch root-ran\n' >"$d/root-test.sh"
  cat >"$d/packages/a/package.json" <<'EOF'
{"name":"a","private":true,"scripts":{"test":"sh ./pkg-test.sh"}}
EOF
  printf '%s\n' "$1" >"$d/packages/a/pkg-test.sh"
  printf 'export const foo = 1\n' >"$d/packages/a/src/foo.ts"
  printf 'export const t = 1\n' >"$d/packages/a/src/foo.test.ts"
  printf '%s' "$d"
}

# payload <file> <cwd>
payload() {
  python3 -c '
import json, sys
print(json.dumps({"tool_name": "Edit", "file_path": sys.argv[1], "cwd": sys.argv[2]}))
' "$1" "$2"
}

CODE=0
ERR=""
# run_hook <launch-dir> <payload-file> <err-file>
run_hook() {
  (cd "$1" && timeout 120 bash "$SCRIPT" <"$2" >/dev/null 2>"$3")
  CODE=$?
  ERR=$(cat "$3")
}

if ! command -v pnpm >/dev/null 2>&1; then
  if [ "${SMART_TEST_REQUIRE_PNPM:-0}" = "1" ]; then
    fail "pnpm availability" "pnpm not on PATH"
  else
    echo "SKIP: pnpm not on PATH"
  fi
  HAVE_PNPM=0
else
  HAVE_PNPM=1
fi

if [ "$HAVE_PNPM" = "1" ]; then
  # 01
  fx=$(new_fixture 'touch pkg-ran')
  pl=$(mktemp); SCRATCH_DIRS+=("$pl"); errf=$(mktemp); SCRATCH_DIRS+=("$errf")
  payload "$fx/packages/a/src/foo.ts" "$fx" >"$pl"
  run_hook "$fx" "$pl" "$errf"
  if [ -f "$fx/packages/a/pkg-ran" ] && [ ! -e "$fx/root-ran" ]; then
    pass "01 source edit runs owning package, not root"
  else
    fail "01 source edit runs owning package, not root" "pkg-ran=$([ -f "$fx/packages/a/pkg-ran" ] && echo yes || echo no) root-ran=$([ -e "$fx/root-ran" ] && echo yes || echo no) code=$CODE"
  fi

  # 02
  fx=$(new_fixture 'touch pkg-ran')
  other=$(mktemp -d); SCRATCH_DIRS+=("$other")
  payload "$fx/packages/a/src/foo.ts" "$other" >"$pl"
  run_hook "$other" "$pl" "$errf"
  if [ -f "$fx/packages/a/pkg-ran" ]; then
    pass "02 owning package found independent of cwd"
  else
    fail "02 owning package found independent of cwd" "pkg-ran absent code=$CODE"
  fi

  # 03
  tok=$(new_token)
  fx=$(new_fixture "sleep $tok & wait")
  payload "$fx/packages/a/src/foo.ts" "$fx" >"$pl"
  (cd "$fx" && exec bash "$SCRIPT" <"$pl" >/dev/null 2>"$errf") &
  hpid=$!
  HOOK_PIDS+=("$hpid")
  if wait_for_token "$tok"; then
    kill -TERM "$hpid" 2>/dev/null
    if wait_for_token_gone "$tok"; then
      pass "03 TERM to hook reaps runner descendants"
    else
      fail "03 TERM to hook reaps runner descendants" "sleep $tok survived"
    fi
  else
    fail "03 TERM to hook reaps runner descendants" "positive control: sleep $tok never appeared"
  fi
  kill -KILL "$hpid" 2>/dev/null
  wait "$hpid" 2>/dev/null

  # 04
  tok=$(new_token)
  fx=$(new_fixture "(sleep $tok &); exit 0")
  payload "$fx/packages/a/src/foo.ts" "$fx" >"$pl"
  run_hook "$fx" "$pl" "$errf"
  hook_code=$CODE
  if wait_for_token_gone "$tok"; then
    survived=0
  else
    survived=1
  fi
  pkill -KILL -f "^sleep $tok\$" 2>/dev/null
  wait_for_token_gone "$tok"
  tok2=$(new_token)
  (cd "$fx/packages/a" && sh -c "(sleep $tok2 &); exit 0" </dev/null >/dev/null 2>&1)
  if wait_for_token "$tok2"; then
    control=1
  else
    control=0
  fi
  pkill -KILL -f "^sleep $tok2\$" 2>/dev/null
  if [ "$control" != "1" ]; then
    fail "04 backgrounded leftover reaped after hook returns" "positive control: direct run left no process"
  elif [ "$survived" = "0" ] && [ "$hook_code" = "0" ]; then
    pass "04 backgrounded leftover reaped after hook returns"
  else
    fail "04 backgrounded leftover reaped after hook returns" "survived=$survived code=$hook_code"
  fi

  # 05
  fx=$(new_fixture 'exit 1')
  payload "$fx/packages/a/src/foo.ts" "$fx" >"$pl"
  run_hook "$fx" "$pl" "$errf"
  if [ "$CODE" = "2" ] && printf '%s' "$ERR" | grep -Eq 'Tests failed|Focused tests failed'; then
    pass "05 failing package tests exit 2 with failure message"
  else
    fail "05 failing package tests exit 2 with failure message" "code=$CODE"
  fi

  # 06
  fx=$(new_fixture 'touch pkg-ran')
  payload "$fx/packages/a/src/foo.test.ts" "$fx" >"$pl"
  run_hook "$fx" "$pl" "$errf"
  if [ -f "$fx/packages/a/pkg-ran" ] && [ ! -e "$fx/root-ran" ]; then
    pass "06 test-file edit runs owning package, not root"
  else
    fail "06 test-file edit runs owning package, not root" "pkg-ran=$([ -f "$fx/packages/a/pkg-ran" ] && echo yes || echo no) root-ran=$([ -e "$fx/root-ran" ] && echo yes || echo no) code=$CODE"
  fi
fi

echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ] || exit 1
exit 0
