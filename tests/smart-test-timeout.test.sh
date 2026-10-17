#!/usr/bin/env bash
# Contract tests for smart-test.sh timeout watchdog and TERM->KILL escalation.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${SMART_TEST_SCRIPT:-$REPO_ROOT/agent-agnostic/hooks/smart-test.sh}"

TOTAL_PASS=0
TOTAL_FAIL=0
SCRATCH_DIRS=()
TOKENS=()
HOOK_PIDS=()

if command -v timeout >/dev/null 2>&1; then
  OUTER=(timeout -s KILL 40)
else
  OUTER=()
fi

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

reap() {
  pkill -KILL -f "^sleep $1\$" 2>/dev/null
  return 0
}

wait_for_token() {
  local i
  for i in $(seq 1 100); do
    token_alive "$1" && return 0
    sleep 0.1
  done
  return 1
}

# wait_for_token_gone <tok> <tenths>
wait_for_token_gone() {
  local i
  for i in $(seq 1 "${2:-50}"); do
    token_alive "$1" || return 0
    sleep 0.1
  done
  return 1
}

new_fixture() {
  local d
  d=$(mktemp -d)
  SCRATCH_DIRS+=("$d")
  mkdir -p "$d/packages/a/src"
  cat >"$d/package.json" <<'EOT'
{"name":"root","private":true,"scripts":{"test":"sh ./root-test.sh; turbo test"}}
EOT
  : >"$d/pnpm-lock.yaml"
  printf 'touch root-ran\n' >"$d/root-test.sh"
  cat >"$d/packages/a/package.json" <<'EOT'
{"name":"a","private":true,"scripts":{"test":"sh ./pkg-test.sh"}}
EOT
  printf '%s\n' "$1" >"$d/packages/a/pkg-test.sh"
  printf 'export const foo = 1\n' >"$d/packages/a/src/foo.ts"
  printf 'export const t = 1\n' >"$d/packages/a/src/foo.test.ts"
  printf '%s' "$d"
}

payload() {
  python3 -c '
import json, sys
print(json.dumps({"tool_name": "Edit", "file_path": sys.argv[1], "cwd": sys.argv[2]}))
' "$1" "$2"
}

CODE=0
ERR=""
ELAPSED=0
# run_hook <timeout-value> <fixture> <payload-file> <err-file>
run_hook() {
  local start end
  start=$(date +%s)
  (cd "$2" && CLAUDE_HOOKS_TEST_TIMEOUT="$1" CLAUDE_HOOKS_TEST_KILL_GRACE=1 \
    "${OUTER[@]}" bash "$SCRIPT" <"$3" >/dev/null 2>"$4")
  CODE=$?
  end=$(date +%s)
  ELAPSED=$((end - start))
  ERR=$(cat "$4")
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
  pl=$(mktemp); SCRATCH_DIRS+=("$pl"); errf=$(mktemp); SCRATCH_DIRS+=("$errf")

  timeout_case() {
    local name="$1" body_prefix="$2" tok fx
    tok=$(new_token)
    fx=$(new_fixture "${body_prefix}sleep $tok")
    payload "$fx/packages/a/src/foo.ts" "$fx" >"$pl"
    run_hook 2 "$fx" "$pl" "$errf"
    sleep 0.3
    local alive=0
    token_alive "$tok" && alive=1
    reap "$tok"
    if [ "$CODE" = "2" ] && [ "$ELAPSED" -le 15 ] && [ "$alive" = "0" ] \
      && printf '%s' "$ERR" | grep -Fq 'timed out after 2s'; then
      pass "$name"
    else
      fail "$name" "code=$CODE elapsed=${ELAPSED}s alive=$alive timedout_msg=$(printf '%s' "$ERR" | grep -Fq 'timed out after 2s' && echo yes || echo no)"
    fi
  }

  # 01
  timeout_case "01 timeout kills plain sleeping run, exit 2 with message" ""

  # 02
  tokc=$(new_token)
  sh -c "trap '' TERM; sleep $tokc" </dev/null >/dev/null 2>&1 &
  cpid=$!
  HOOK_PIDS+=("$cpid")
  control=0
  if wait_for_token "$tokc"; then
    kill -TERM "$cpid" 2>/dev/null
    pkill -TERM -f "^sleep $tokc\$" 2>/dev/null
    sleep 0.5
    token_alive "$tokc" && control=1
  fi
  reap "$tokc"
  kill -KILL "$cpid" 2>/dev/null
  wait "$cpid" 2>/dev/null
  if [ "$control" != "1" ]; then
    fail "02 timeout kills TERM-ignoring run" "positive control: body did not survive plain TERM"
  else
    timeout_case "02 timeout kills TERM-ignoring run" "trap '' TERM; "
  fi

  # 03
  tok=$(new_token)
  fx=$(new_fixture "trap '' TERM; sleep $tok")
  payload "$fx/packages/a/src/foo.ts" "$fx" >"$pl"
  (cd "$fx" && CLAUDE_HOOKS_TEST_TIMEOUT=0 CLAUDE_HOOKS_TEST_KILL_GRACE=1 exec bash "$SCRIPT" <"$pl" >/dev/null 2>"$errf") &
  hpid=$!
  HOOK_PIDS+=("$hpid")
  if wait_for_token "$tok"; then
    kill -TERM "$hpid" 2>/dev/null
    if wait_for_token_gone "$tok" 80; then
      pass "03 TERM to hook escalates to KILL after grace"
    else
      fail "03 TERM to hook escalates to KILL after grace" "sleep $tok survived 8s"
    fi
  else
    fail "03 TERM to hook escalates to KILL after grace" "positive control: sleep $tok never appeared"
  fi
  reap "$tok"
  kill -KILL "$hpid" 2>/dev/null
  wait "$hpid" 2>/dev/null

  # 04
  tok=$(new_token)
  fx=$(new_fixture "exit 0")
  payload "$fx/packages/a/src/foo.ts" "$fx" >"$pl"
  run_hook "$tok" "$fx" "$pl" "$errf"
  hook_code=$CODE
  survived=0
  token_alive "$tok" && survived=1
  reap "$tok"

  tok2=$(new_token)
  fx2=$(new_fixture "sleep 3")
  pl2=$(mktemp); SCRATCH_DIRS+=("$pl2")
  payload "$fx2/packages/a/src/foo.ts" "$fx2" >"$pl2"
  (cd "$fx2" && CLAUDE_HOOKS_TEST_TIMEOUT="$tok2" CLAUDE_HOOKS_TEST_KILL_GRACE=1 exec bash "$SCRIPT" <"$pl2" >/dev/null 2>/dev/null) &
  hpid=$!
  HOOK_PIDS+=("$hpid")
  if wait_for_token "$tok2"; then
    control=1
  else
    control=0
  fi
  wait "$hpid" 2>/dev/null
  reap "$tok2"
  if [ "$control" != "1" ]; then
    fail "04 no watchdog sleep survives hook return" "positive control: watchdog sleep $tok2 never observed during slow run"
  elif [ "$survived" = "0" ] && [ "$hook_code" = "0" ]; then
    pass "04 no watchdog sleep survives hook return"
  else
    fail "04 no watchdog sleep survives hook return" "survived=$survived code=$hook_code"
  fi

  # 05
  fx=$(new_fixture 'exit 1')
  payload "$fx/packages/a/src/foo.ts" "$fx" >"$pl"
  run_hook 2 "$fx" "$pl" "$errf"
  if [ "$CODE" = "2" ] && printf '%s' "$ERR" | grep -Eq 'Tests failed|Focused tests failed' \
    && ! printf '%s' "$ERR" | grep -Fq 'timed out'; then
    pass "05 failing body exits 2 with failure message, no timeout wording"
  else
    fail "05 failing body exits 2 with failure message, no timeout wording" "code=$CODE"
  fi

  # 06
  fx=$(new_fixture 'sleep 3')
  payload "$fx/packages/a/src/foo.ts" "$fx" >"$pl"
  run_hook 0 "$fx" "$pl" "$errf"
  if [ "$CODE" = "0" ] && ! printf '%s' "$ERR" | grep -Fq 'timed out'; then
    pass "06 TIMEOUT=0 disables the timeout"
  else
    fail "06 TIMEOUT=0 disables the timeout" "code=$CODE"
  fi
fi

echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ] || exit 1
exit 0
