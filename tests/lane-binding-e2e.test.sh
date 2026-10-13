#!/usr/bin/env bash
# End-to-end: captured launch payload -> lane-bind-on-launch.sh -> scope-writes.sh / shell guard.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$REPO_ROOT/agent-agnostic/hooks"
PASS=0; FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1 ($2)"; FAIL=$((FAIL + 1)); }
BASE=$(mktemp -d); trap 'rm -rf "$BASE"' EXIT
RUN="$BASE/run"; mkdir -p "$RUN/.artifacts"; echo x >"$RUN/.artifacts/progress-log.md"
ID=ab0dc0b94f1af8740

launch=$(python3 -c '
import json,sys
print(json.dumps({"hook_event_name":"PostToolUse","tool_name":"Agent",
 "tool_input":{"description":"d","prompt":"lane-id: l1\nrun-dir: %s/.artifacts\n\nwork" % sys.argv[1],"subagent_type":"builder"},
 "tool_response":{"isAsync":True,"status":"async_launched","agentId":sys.argv[2]}}))' "$RUN" "$ID")
printf '%s' "$launch" | "$H/lane-bind-on-launch.sh"; rc=$?
[ "$rc" = 0 ] && [ "$(cat "$RUN/.artifacts/lanes/l1.agent" 2>/dev/null)" = "$ID" ] \
  && pass "launch payload binds l1 to the launched id" || fail "bind" "rc=$rc"

w() { printf '{"tool_name":"%s","file_path":"%s","agent_type":"builder","agent_id":"%s","cwd":"%s"}' "$1" "$2" "$3" "$BASE"; }
for t in contracts/l1.md reports/l1-exit.md; do
  w Write "$RUN/.artifacts/$t" "$ID" | "$H/scope-writes.sh" 2>/dev/null; [ $? = 0 ] \
    && pass "bound builder Writes $t" || fail "write $t" "denied"
done
w Edit "$RUN/.artifacts/contracts/l1.md" "$ID" | "$H/scope-writes.sh" 2>/dev/null; [ $? = 0 ] \
  && pass "bound builder Edits contracts/l1.md" || fail "edit" "denied"
err=$(w Write "$RUN/.artifacts/contracts/l2.md" "$ID" | "$H/scope-writes.sh" 2>&1 >/dev/null); rc=$?
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "has no binding" \
  && pass "same builder denied on unbound l2" || fail "l2" "rc=$rc err=$err"
err=$(w Write "$RUN/.artifacts/contracts/l1.md" "azzzz" | "$H/scope-writes.sh" 2>&1 >/dev/null); rc=$?
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "bound to a different agent" \
  && pass "foreign agent denied on l1" || fail "foreign" "rc=$rc err=$err"

sh_payload() { python3 -c 'import json,sys; d={"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}
if sys.argv[2]=="sub": d["agent_type"]="builder"; d["agent_id"]="x"
print(json.dumps(d))' "$1" "$2"; }
err=$(sh_payload "cat > $RUN/.artifacts/reports/l1-exit.md <<'X'
body
X" sub | "$H/lane-artifact-shell-guard.sh" 2>&1 >/dev/null); rc=$?
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "Write tool" \
  && pass "heredoc write of the exit report denied" || fail "heredoc" "rc=$rc"
sh_payload "$H/lane-bind.sh $RUN/.artifacts l1 evil" sub | "$H/lane-artifact-shell-guard.sh" 2>/dev/null; [ $? = 2 ] \
  && pass "subagent lane-bind.sh denied" || fail "lane-bind sub" "allowed"
sh_payload "$H/lane-bind.sh $RUN/.artifacts l1 evil" main | "$H/lane-artifact-shell-guard.sh" 2>/dev/null; [ $? = 0 ] \
  && pass "main-session lane-bind.sh allowed" || fail "lane-bind main" "denied"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
