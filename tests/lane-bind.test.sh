#!/usr/bin/env bash
# Contract tests for agent-agnostic/hooks/lane-bind.sh.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/agent-agnostic/hooks/lane-bind.sh"

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

new_run_dir() {
  local d
  d=$(new_scratch)
  echo "x" >"$d/progress-log.md"
  printf '%s' "$d"
}

OUT=""
ERR=""
CODE=0
run_bind() {
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  "$SCRIPT" "$@" >"$out_f" 2>"$err_f" </dev/null
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# exact_content <file> <expected-with-escapes-for-printf> -> 0 if byte-equal
exact_content() {
  local file="$1" expected="$2" actual want
  [ -f "$file" ] || return 1
  actual=$(cat "$file"; printf x)
  want=$(printf "$expected"; printf x)
  [ "$actual" = "$want" ]
}

# expect_rejected <label> <run-dir> <args...>: exit 1, stderr non-empty, no lanes/ dir
expect_rejected() {
  local label="$1" run="$2"
  shift 2
  run_bind "$@"
  if [ "$CODE" -ne 1 ]; then
    fail "$label" "expected exit 1, code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if [ -z "$ERR" ]; then
    fail "$label" "expected non-empty stderr"
    return
  fi
  if [ -e "$run/lanes" ]; then
    fail "$label" "lanes/ was created: $(ls -A "$run/lanes" 2>&1)"
    return
  fi
  pass "$label"
}

if bash -n "$SCRIPT" 2>/dev/null; then
  pass "00: bash -n lane-bind.sh"
else
  fail "00: bash -n lane-bind.sh" "syntax error or missing script"
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi

case01() {
  local label="01: valid bind writes exactly 'id\\n' and exits 0 silently"
  local run
  run=$(new_run_dir)
  run_bind "$run" l1 a1111111111111111
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "code=$CODE err=[$ERR]"
    return
  fi
  if ! exact_content "$run/lanes/l1.agent" 'a1111111111111111\n'; then
    fail "$label" "content=[$(cat "$run/lanes/l1.agent" 2>&1)]"
    return
  fi
  pass "$label"
}
case01

case02() {
  local label="02: no stray temp files left in lanes/ after bind"
  local run listing
  run=$(new_run_dir)
  run_bind "$run" l3 abc123
  listing=$(ls -A "$run/lanes" 2>&1)
  if [ "$CODE" -eq 0 ] && [ "$listing" = "l3.agent" ]; then
    pass "$label"
  else
    fail "$label" "code=$CODE listing=[$listing]"
  fi
}
case02

case03() {
  local label="03: rebind replaces the earlier binding, still only one file"
  local run listing
  run=$(new_run_dir)
  run_bind "$run" l1 first111
  run_bind "$run" l1 second222
  listing=$(ls -A "$run/lanes" 2>&1)
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "code=$CODE err=[$ERR]"
    return
  fi
  if ! exact_content "$run/lanes/l1.agent" 'second222\n'; then
    fail "$label" "content=[$(cat "$run/lanes/l1.agent" 2>&1)]"
    return
  fi
  if [ "$listing" != "l1.agent" ]; then
    fail "$label" "listing=[$listing]"
    return
  fi
  pass "$label"
}
case03

case04() {
  local label="04: different lanes bind independently"
  local run
  run=$(new_run_dir)
  run_bind "$run" l1 aaa
  run_bind "$run" l12 bbb
  if exact_content "$run/lanes/l1.agent" 'aaa\n' && exact_content "$run/lanes/l12.agent" 'bbb\n'; then
    pass "$label"
  else
    fail "$label" "l1=[$(cat "$run/lanes/l1.agent" 2>&1)] l12=[$(cat "$run/lanes/l12.agent" 2>&1)]"
  fi
}
case04

case05() {
  local label="05: agent ids with hyphen, underscore, mixed case accepted"
  local run id n=0
  run=$(new_run_dir)
  for id in A-b_C-9 _x -y Z; do
    n=$((n + 1))
    run_bind "$run" "l$n" "$id"
    if [ "$CODE" -ne 0 ] || [ "$(cat "$run/lanes/l$n.agent" 2>/dev/null)" != "$id" ]; then
      fail "$label" "id=[$id] code=$CODE err=[$ERR]"
      return
    fi
  done
  pass "$label"
}
case05

case06() {
  local run
  run=$(new_run_dir)
  expect_rejected "06a: zero args -> usage, exit 1, nothing written" "$run"
  expect_rejected "06b: one arg -> exit 1" "$run" "$run"
  expect_rejected "06c: two args -> exit 1" "$run" "$run" l1
  expect_rejected "06d: four args -> exit 1" "$run" "$run" l1 abc extra
}
case06

case07() {
  local run lane
  for lane in l L1 l1x 1 "" "l 1" "l1/../x" "l-1" "ll1"; do
    run=$(new_run_dir)
    expect_rejected "07: bad lane-id [$lane] -> exit 1, nothing written" "$run" "$run" "$lane" abc123
  done
}
case07

case08() {
  local run agent
  for agent in "a b" "a/b" "" "../x" "a.b" "a:b" "a;b"; do
    run=$(new_run_dir)
    expect_rejected "08: bad agent-id [$agent] -> exit 1, nothing written" "$run" "$run" l1 "$agent"
  done
}
case08

case09() {
  local run
  run=$(new_scratch)
  expect_rejected "09a: run-dir without progress-log.md -> exit 1, no lanes/" "$run" "$run" l1 abc123
  if [ -z "$(ls -A "$run")" ]; then
    pass "09a: run-dir left completely empty"
  else
    fail "09a: run-dir left completely empty" "listing=[$(ls -A "$run")]"
  fi

  run=$(new_scratch)
  mkdir "$run/progress-log.md"
  expect_rejected "09b: progress-log.md is a directory, not a file -> exit 1" "$run" "$run" l1 abc123

  expect_rejected "09c: nonexistent run-dir -> exit 1" "$run" "$run/does/not/exist" l1 abc123
}
case09

case10() {
  local label="10: failed bind leaves an existing binding untouched"
  local run
  run=$(new_run_dir)
  run_bind "$run" l1 keepme
  run_bind "$run" l1 "bad id"
  if [ "$CODE" -eq 1 ] && exact_content "$run/lanes/l1.agent" 'keepme\n'; then
    pass "$label"
  else
    fail "$label" "code=$CODE content=[$(cat "$run/lanes/l1.agent" 2>&1)]"
  fi
}
case10

case11() {
  local label="11: write failure (lanes is a regular file) -> exit 1, stderr non-empty"
  local run
  run=$(new_run_dir)
  echo "blocker" >"$run/lanes"
  run_bind "$run" l1 abc123
  if [ "$CODE" -eq 1 ] && [ -n "$ERR" ] && [ -f "$run/lanes" ]; then
    pass "$label"
  else
    fail "$label" "code=$CODE err=[$ERR]"
  fi
}
case11

echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ] || exit 1
exit 0
