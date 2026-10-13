#!/usr/bin/env bash
# Contract tests for agent-agnostic/hooks/lane-bind-on-launch.sh.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/agent-agnostic/hooks/lane-bind-on-launch.sh"

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
run_hook() {
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  printf '%s' "$1" | "$SCRIPT" >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

run_hook_empty() {
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  "$SCRIPT" </dev/null >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# build_payload <subagent_type> <prompt> <tool_response-json> [extra-top-level-json-object]
build_payload() {
  python3 -c '
import json, sys
subtype, prompt, resp = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
extra = json.loads(sys.argv[4]) if len(sys.argv) > 4 else {}
p = {
    "hook_event_name": "PostToolUse",
    "tool_name": "Agent",
    "tool_input": {"description": "lane", "prompt": prompt, "subagent_type": subtype},
    "tool_response": resp,
    "tool_use_id": "toolu_test",
    "cwd": "/tmp",
    "session_id": "sess_test",
}
p.update(extra)
print(json.dumps(p))
' "$@"
}

resp_obj() {
  python3 -c '
import json, sys
print(json.dumps({"isAsync": True, "status": "async_launched", "agentId": sys.argv[1], "description": "lane", "prompt": "p"}))
' "$1"
}

lane_prompt() {
  printf 'lane-id: %s\nrun-dir: %s\n\nBuild the lane.\n' "$1" "$2"
}

dir_listing() {
  find "$1" -mindepth 1 | sort
}

assert_inert() {
  local label="$1" run="$2" before="$3"
  local after
  after=$(dir_listing "$run")
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "expected exit 0, code=$CODE err=[$ERR]"
  elif [ -n "$OUT" ]; then
    fail "$label" "expected empty stdout, out=[$OUT]"
  elif [ -n "$ERR" ]; then
    fail "$label" "expected empty stderr, err=[$ERR]"
  elif [ "$before" != "$after" ]; then
    fail "$label" "run dir changed: before=[$before] after=[$after]"
  else
    pass "$label"
  fi
}

assert_bound() {
  local label="$1" run="$2" lane="$3" id="$4"
  local actual
  actual=$(cat "$run/lanes/$lane.agent" 2>/dev/null; printf x)
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "expected exit 0, code=$CODE err=[$ERR]"
  elif [ -n "$OUT" ] || [ -n "$ERR" ]; then
    fail "$label" "expected silence, out=[$OUT] err=[$ERR]"
  elif [ "$actual" != "$id"$'\n'"x" ]; then
    fail "$label" "binding content=[${actual%x}]"
  else
    pass "$label"
  fi
}

if bash -n "$SCRIPT" 2>/dev/null; then
  pass "00: bash -n lane-bind-on-launch.sh"
else
  fail "00: bash -n lane-bind-on-launch.sh" "syntax error or missing script"
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi

case01() {
  local run payload
  run=$(new_run_dir)
  payload=$(build_payload builder "$(lane_prompt l1 "$run")" "$(resp_obj ab0dc0b94f1af8740)")
  run_hook "$payload"
  assert_bound "01: happy path binds tool_response.agentId" "$run" l1 ab0dc0b94f1af8740
}
case01

case02() {
  local run payload
  run=$(new_run_dir)
  payload=$(build_payload builder "$(lane_prompt l2 "$run")" '"Async agent launched. agentId: abc123 (internal ID)"')
  run_hook "$payload"
  assert_bound "02: string tool_response 'agentId: abc123 ...' binds abc123" "$run" l2 abc123
}
case02

case03() {
  local run payload
  run=$(new_run_dir)
  payload=$(build_payload builder "$(lane_prompt l3 "$run")" '{"status":"async_launched","text":"launched agentId: zz99 ok"}')
  run_hook "$payload"
  local before after
  after=$(cat "$run/lanes/l3.agent" 2>/dev/null)
  if [ "$CODE" -eq 0 ] && [ -z "$ERR" ] && { [ "$after" = "zz99" ] || [ -z "$after" ]; }; then
    pass "03: object lacking agentId never errors or binds a wrong id (binds zz99 or stays inert)"
  else
    fail "03: object lacking agentId" "code=$CODE err=[$ERR] binding=[$after]"
  fi
}
case03

case04() {
  local run payload before
  for st in coder Explore general-purpose Builder builder-x ""; do
    run=$(new_run_dir)
    before=$(dir_listing "$run")
    payload=$(build_payload "$st" "$(lane_prompt l1 "$run")" "$(resp_obj abc123)")
    run_hook "$payload"
    assert_inert "04: subagent_type [$st] is inert" "$run" "$before"
  done
}
case04

case05() {
  local run payload before
  run=$(new_run_dir)
  before=$(dir_listing "$run")
  payload=$(build_payload builder $'run-dir: '"$run"$'\n\nno lane line' "$(resp_obj abc123)")
  run_hook "$payload"
  assert_inert "05a: missing lane-id line is inert" "$run" "$before"

  payload=$(build_payload builder $'lane-id: l1\n\nno run-dir line' "$(resp_obj abc123)")
  run_hook "$payload"
  assert_inert "05b: missing run-dir line is inert" "$run" "$before"

  payload=$(build_payload builder $'lane-id: l1\nrun-dir: relative/run\n' "$(resp_obj abc123)")
  run_hook "$payload"
  assert_inert "05c: relative run-dir is inert" "$run" "$before"

  payload=$(build_payload builder "$(lane_prompt lane1 "$run")" "$(resp_obj abc123)")
  run_hook "$payload"
  assert_inert "05d: malformed lane-id (lane1) is inert" "$run" "$before"

  payload=$(build_payload builder "$(lane_prompt L1 "$run")" "$(resp_obj abc123)")
  run_hook "$payload"
  assert_inert "05e: malformed lane-id (L1) is inert" "$run" "$before"

  payload=$(build_payload builder "$(lane_prompt l1 "$run") trailing" "$(resp_obj abc123)")
  run_hook "$payload"
  if [ "$CODE" -eq 0 ] && [ -z "$ERR" ]; then
    pass "05f: prompt with extra text exits 0 silently"
  else
    fail "05f: prompt with extra text exits 0 silently" "code=$CODE err=[$ERR]"
  fi
}
case05

case06() {
  local run payload before
  run=$(new_run_dir)
  before=$(dir_listing "$run")
  local run_main
  run_main=$(new_run_dir)
  payload=$(build_payload builder "$(lane_prompt l1 "$run_main")" "$(resp_obj abc123)" '{"agent_type":"claude"}')
  run_hook "$payload"
  assert_bound "06a: agent_type present without agent_id binds" "$run_main" l1 abc123

  payload=$(build_payload builder "$(lane_prompt l1 "$run")" "$(resp_obj abc123)" '{"agent_id":"a9999"}')
  run_hook "$payload"
  assert_inert "06b: payload carrying agent_id is inert" "$run" "$before"

  payload=$(build_payload builder "$(lane_prompt l1 "$run")" "$(resp_obj abc123)" '{"agent_id":"a9999","agent_type":"builder"}')
  run_hook "$payload"
  assert_inert "06c: payload carrying both is inert" "$run" "$before"
}
case06

case07() {
  local run payload before
  run=$(new_run_dir)
  before=$(dir_listing "$run")
  payload=$(build_payload builder "$(lane_prompt l1 "$run")" '"launched, no identifier here"')
  run_hook "$payload"
  assert_inert "07a: string tool_response without agentId is inert" "$run" "$before"

  payload=$(build_payload builder "$(lane_prompt l1 "$run")" '{"status":"async_launched"}')
  run_hook "$payload"
  assert_inert "07b: object tool_response without agentId is inert" "$run" "$before"

  payload=$(build_payload builder "$(lane_prompt l1 "$run")" '{"status":"async_launched","agentId":""}')
  run_hook "$payload"
  assert_inert "07c: empty agentId is inert" "$run" "$before"

  payload=$(build_payload builder "$(lane_prompt l1 "$run")" 'null')
  run_hook "$payload"
  assert_inert "07d: null tool_response is inert" "$run" "$before"
}
case07

case08() {
  local run payload before
  run=$(new_scratch)
  before=$(dir_listing "$run")
  payload=$(build_payload builder "$(lane_prompt l1 "$run")" "$(resp_obj abc123)")
  run_hook "$payload"
  assert_inert "08a: run-dir without progress-log.md is inert" "$run" "$before"

  echo "x" >"$run/progress-log.md"
  run_hook "$payload"
  assert_bound "08b: positive control, same payload with marker binds" "$run" l1 abc123
}
case08

case09() {
  local run before
  run=$(new_run_dir)
  before=$(dir_listing "$run")
  run_hook '{"tool_name": "Agent", "tool_input": {"subagent_type": "builder", "prompt": '
  assert_inert "09a: malformed (truncated) JSON is inert" "$run" "$before"

  run_hook 'not json at all {{{'
  assert_inert "09b: garbage stdin is inert" "$run" "$before"

  run_hook_empty
  assert_inert "09c: empty stdin is inert" "$run" "$before"

  run_hook '{}'
  assert_inert "09d: empty object is inert" "$run" "$before"

  run_hook '{"tool_name":"Agent","tool_input":"not-an-object","tool_response":{"agentId":"abc"}}'
  assert_inert "09e: tool_input not an object is inert" "$run" "$before"

  run_hook '[1,2,3]'
  assert_inert "09f: non-object top-level JSON is inert" "$run" "$before"
}
case09

case10() {
  local run payload
  run=$(new_run_dir)
  echo "blocker" >"$run/lanes"
  payload=$(build_payload builder "$(lane_prompt l1 "$run")" "$(resp_obj abc123)")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "10: lane-bind failure (lanes is a regular file) -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "lane-bind.sh"; then
    fail "10: stderr names lane-bind.sh" "err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "l1"; then
    fail "10: stderr names the lane" "err=[$ERR]"
    return
  fi
  pass "10: lane-bind failure -> exit 2, stderr names lane-bind.sh and l1"
}
case10

case11() {
  local run payload
  run=$(new_run_dir)
  payload=$(build_payload builder "$(lane_prompt l4 "$run")" "$(resp_obj 'bad/id here')")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "11: agentId rejected by lane-bind.sh -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "lane-bind.sh" || ! printf '%s\n' "$ERR" | grep -qF -- "l4"; then
    fail "11: stderr names lane-bind.sh and l4" "err=[$ERR]"
    return
  fi
  if [ -e "$run/lanes" ]; then
    fail "11: nothing written on rejected id" "lanes=[$(ls -A "$run/lanes")]"
    return
  fi
  pass "11: agentId rejected by lane-bind.sh -> exit 2, manual-bind message, nothing written"
}
case11

case12() {
  local run payload
  run=$(new_run_dir)
  payload=$(build_payload builder "$(lane_prompt l1 "$run")" "$(resp_obj first111)")
  run_hook "$payload"
  payload=$(build_payload builder "$(lane_prompt l1 "$run")" "$(resp_obj second222)")
  run_hook "$payload"
  assert_bound "12: second launch for the same lane rebinds to the new id" "$run" l1 second222
}
case12

case13() {
  local run payload prompt
  run=$(new_run_dir)
  prompt=$'You are the builder for this lane.\nRead the plan first.\n\nlane-id: l7\nrun-dir: '"$run"$'\n\nplan: /abs/plan.md\nThen get to work.\n'
  payload=$(build_payload builder "$prompt" "$(resp_obj surround77)")
  run_hook "$payload"
  assert_bound "13a: lines surrounded by other prompt text bind" "$run" l7 surround77

  run=$(new_run_dir)
  prompt=$'lane-id:\tl8  \nrun-dir:   '"$run"$'\t\nrest\n'
  payload=$(build_payload builder "$prompt" "$(resp_obj spaced88)")
  run_hook "$payload"
  assert_bound "13b: tab/space padding around values still binds" "$run" l8 spaced88

  run=$(new_run_dir)
  prompt=$'lane-id: l1\nrun-dir: '"$run"$'\nlane-id: l2\nrun-dir: /elsewhere\n'
  payload=$(build_payload builder "$prompt" "$(resp_obj firstwins)")
  run_hook "$payload"
  if [ -f "$run/lanes/l1.agent" ] && [ ! -e "$run/lanes/l2.agent" ]; then
    assert_bound "13c: first lane-id / run-dir match wins" "$run" l1 firstwins
  else
    fail "13c: first lane-id / run-dir match wins" "code=$CODE err=[$ERR] lanes=[$(ls -A "$run/lanes" 2>&1)]"
  fi
}
case13

case14() {
  local run payload
  run=$(new_run_dir)
  payload=$(build_payload builder "$(lane_prompt l1 "$run")" "$(resp_obj a1)")
  run_hook "$payload"
  payload=$(build_payload builder "$(lane_prompt l2 "$run")" "$(resp_obj a2)")
  run_hook "$payload"
  if [ "$(cat "$run/lanes/l1.agent" 2>/dev/null)" = "a1" ] && [ "$(cat "$run/lanes/l2.agent" 2>/dev/null)" = "a2" ]; then
    pass "14: separate lanes bind to their own launched ids"
  else
    fail "14: separate lanes bind to their own launched ids" "l1=[$(cat "$run/lanes/l1.agent" 2>&1)] l2=[$(cat "$run/lanes/l2.agent" 2>&1)]"
  fi
}
case14

echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ] || exit 1
exit 0
