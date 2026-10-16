#!/usr/bin/env bash
# Contract tests for agent-agnostic/hooks/lane-artifact-shell-guard.sh.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/agent-agnostic/hooks/lane-artifact-shell-guard.sh"

TOTAL_PASS=0
TOTAL_FAIL=0

pass() {
  echo "PASS: $1"
  TOTAL_PASS=$((TOTAL_PASS + 1))
}

fail() {
  echo "FAIL: $1 ($2)"
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
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

# payload <command> [subagent] -- Bash PreToolUse JSON via python3 json.dumps; cwd from $PAYLOAD_CWD (default /tmp)
payload() {
  python3 -c '
import json, os, sys
p = {"hook_event_name": "PreToolUse", "tool_name": "Bash",
     "cwd": os.environ.get("PAYLOAD_CWD", "/tmp"), "tool_input": {"command": sys.argv[1]}}
if len(sys.argv) > 2:
    p["agent_id"] = "ab0dc0b94f1af8740"
    p["agent_type"] = "builder"
print(json.dumps(p))
' "$@"
}

deny() {
  local label="$1" cmd="$2" target="$3" cwd="${4:-/tmp}"
  run_hook "$(PAYLOAD_CWD="$cwd" payload "$cmd")"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names target" "target=[$target] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "Write tool"; then
    fail "$label -> stderr says Write tool" "err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names target and Write tool"
}

allow() {
  local label="$1" cmd="$2" cwd="${3:-/tmp}"
  run_hook "$(PAYLOAD_CWD="$cwd" payload "$cmd")"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if [ -n "$ERR" ]; then
    fail "$label -> empty stderr" "err=[$ERR]"
    return
  fi
  pass "$label -> exit 0, empty stderr"
}

SYN_ERR_FILE=$(mktemp)
if bash -n "$SCRIPT" 2>"$SYN_ERR_FILE"; then
  pass "00: bash -n lane-artifact-shell-guard.sh exits 0"
else
  fail "00: bash -n lane-artifact-shell-guard.sh exits 0" "$(cat "$SYN_ERR_FILE")"
  rm -f "$SYN_ERR_FILE"
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
rm -f "$SYN_ERR_FILE"

C="/w/run/.artifacts/contracts/l5.md"
X="/w/run/.artifacts/reports/l5-exit.md"
L="/w/run/.artifacts/lanes/l5.agent"

# --- incident heredoc ---
INCIDENT=$'cd /w/about-us-page-l5 && cat > ../about-us-page/.artifacts/contracts/l5.md <<\'EOF\'\nbody\nEOF'
deny "01 incident heredoc (relative path, cd &&)" "$INCIDENT" ".artifacts/contracts/l5.md"
deny "01b heredoc with unquoted delimiter, absolute path" $'cat > '"$C"$' <<EOF\nbody\nEOF' "$C"
deny "01c heredoc, append redirect, exit report" $'cat >> '"$X"$' <<\'EOF\'\nbody\nEOF' "$X"

# --- output redirection ---
deny "02a > unquoted contract" "echo hi > $C" "$C"
deny "02b > double-quoted contract" "echo hi > \"$C\"" "$C"
deny "02c > single-quoted contract" "echo hi > '$C'" "$C"
deny "02d >> exit report" "echo hi >> $X" "$X"
deny "02e >| contract" "echo hi >| $C" "$C"
deny "02f &> contract" "echo hi &> $C" "$C"
deny "02g redirect after &&" "true && echo hi > $C" "$C"
deny "02h redirect after ;" "true; echo hi > $X" "$X"
deny "02i redirect after |" "echo hi | cat > $C" "$C"
deny "02j relative path" "echo hi > ../run/.artifacts/contracts/l12.md" ".artifacts/contracts/l12.md"
deny "02k redirect into lanes/" "echo a1 > $L" "$L"
deny "02l redirect into lanes/ nested" "echo a1 > /w/run/.artifacts/lanes/sub/x.txt" "/w/run/.artifacts/lanes/sub/x.txt"

# --- tee ---
deny "03a tee contract" "echo hi | tee $C" "$C"
deny "03b tee -a exit report" "echo hi | tee -a $X" "$X"
deny "03c tee with other file first" "echo hi | tee /tmp/other $C" "$C"
deny "03d tee into lanes/" "echo a1 | tee $L" "$L"

# --- cp / mv / install / ln / rsync destination ---
deny "04a cp dest contract" "cp /tmp/draft.md $C" "$C"
deny "04b mv dest exit report" "mv /tmp/draft.md $X" "$X"
deny "04c install dest contract" "install -m 644 /tmp/draft.md $C" "$C"
deny "04d ln -s dest contract" "ln -sf /tmp/draft.md $C" "$C"
deny "04e rsync dest contract" "rsync -a /tmp/draft.md $C" "$C"
deny "04f cp -f dest lanes/" "cp -f /tmp/a.agent $L" "$L"

# --- in-place edit tools ---
deny "05a sed -i contract" "sed -i 's/a/b/' $C" "$C"
deny "05b perl -i exit report" "perl -i -pe 's/a/b/' $X" "$X"
deny "05c perl -pi contract" "perl -pi -e 's/a/b/' $C" "$C"
deny "05d truncate contract" "truncate -s 0 $C" "$C"
deny "05e dd of= contract" "dd if=/tmp/x of=$C" "$C"

# --- lane-bind.sh by role ---
BIND="~/.claude/hooks/lane-bind.sh /w/run/.artifacts l5 ab0dc0b94f1af8740"
run_hook "$(payload "$BIND" subagent)"
if [ "$CODE" -ne 2 ]; then
  fail "06a lane-bind.sh from subagent payload -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
elif ! printf '%s\n' "$ERR" | grep -qF -- "lane-bind.sh"; then
  fail "06a stderr names lane-bind.sh" "err=[$ERR]"
elif ! printf '%s\n' "$ERR" | grep -qiE -- "main session|orchestrator"; then
  fail "06a stderr says only main session/orchestrator records bindings" "err=[$ERR]"
else
  pass "06a lane-bind.sh from subagent payload -> exit 2, stderr names lane-bind.sh and orchestrator"
fi

run_hook "$(payload "cd /w/run && ~/.claude/hooks/lane-bind.sh /w/run/.artifacts l5 ab0dc0b94f1af8740" subagent)"
if [ "$CODE" -ne 2 ]; then
  fail "06b lane-bind.sh in compound command from subagent -> exit 2" "code=$CODE err=[$ERR]"
elif ! printf '%s\n' "$ERR" | grep -qF -- "lane-bind.sh"; then
  fail "06b stderr names lane-bind.sh" "err=[$ERR]"
else
  pass "06b lane-bind.sh in compound command from subagent -> exit 2"
fi

allow "06c lane-bind.sh from main-session payload (control for 06a)" "$BIND"

run_hook "$(payload "~/.claude/hooks/lane-bind-on-launch.sh" subagent)"
if [ "$CODE" -eq 0 ] && [ -z "$ERR" ]; then
  pass "06d lane-bind-on-launch.sh from subagent payload is not lane-bind.sh -> exit 0, empty stderr"
else
  fail "06d lane-bind-on-launch.sh from subagent -> exit 0, empty stderr" "code=$CODE err=[$ERR]"
fi

run_hook "$(payload "cat $C" subagent)"
if [ "$CODE" -eq 0 ] && [ -z "$ERR" ]; then
  pass "06e read of T from subagent payload -> exit 0, empty stderr"
else
  fail "06e read of T from subagent -> exit 0, empty stderr" "code=$CODE err=[$ERR]"
fi

# --- allows: reads and mentions ---
allow "07a cat contract" "cat $C"
allow "07b validate-report.sh --kind exit" "validate-report.sh --kind exit $X"
allow "07c verify-scope.sh" "verify-scope.sh --lane l5 --run-dir /w/run/.artifacts"
allow "07d cp T as source" "cp $C /tmp/x"
allow "07e mv T as source" "mv $X /tmp/x"
allow "07f grep with quoted pattern naming a T" "grep -n 'contracts/l1.md' file"
allow "07g echo mentioning a T" 'echo "see contracts/l1.md"'
allow "07h heredoc BODY mentioning a redirect to a T" $'cat > /tmp/notes.txt <<\'EOF\'\necho x > /w/run/.artifacts/contracts/l5.md\nEOF'
allow "07i mkdir -p contracts dir" "mkdir -p /w/run/.artifacts/contracts"
allow "07j write to unrelated file" "echo hi > /tmp/unrelated.txt"
allow "07k tee unrelated file" "echo hi | tee /tmp/unrelated.txt"
allow "07l cp to unrelated destination" "cp /tmp/a /tmp/b"
allow "07m sed -i unrelated file" "sed -i 's/a/b/' /tmp/unrelated.txt"
allow "07n reading lanes/" "cat $L"
allow "07o ls run-dir" "ls /w/run/.artifacts/contracts"

# --- scratch-dir report paths with control ---
deny  "08a control: redirect into reports/l5-exit.md" "echo hi > $X" "$X"
allow "08b scratch report .artifacts/reports/<slug>-<runid>/report.md" "echo hi > /repo/.artifacts/reports/some-slug-abc123/report.md"
allow "08c scratch report .artifacts/reports/foo.md" "echo hi > /repo/.artifacts/reports/foo.md"
allow "08d scratch report via tee" "echo hi | tee /repo/.artifacts/reports/some-slug-abc123/report.md"
allow "08e scratch report via cp" "cp /tmp/r.md /repo/.artifacts/reports/some-slug-abc123/report.md"
allow "08f progress-log.md is not T" "echo hi >> /w/run/.artifacts/progress-log.md"
allow "08g lookalike contracts/l1.md.bak" "echo hi > /w/run/.artifacts/contracts/l1.md.bak"
allow "08h lookalike contracts/lx.md" "echo hi > /w/run/.artifacts/contracts/lx.md"

# --- degenerate payloads ---
run_hook_empty
if [ "$CODE" -eq 0 ] && [ -z "$ERR" ]; then
  pass "09a empty stdin -> exit 0, empty stderr"
else
  fail "09a empty stdin -> exit 0, empty stderr" "code=$CODE err=[$ERR]"
fi

run_hook ""
if [ "$CODE" -eq 0 ] && [ -z "$ERR" ]; then
  pass "09b empty payload -> exit 0, empty stderr"
else
  fail "09b empty payload -> exit 0, empty stderr" "code=$CODE err=[$ERR]"
fi

run_hook $'\x01\x02 not json at all {{{ [[[ ))) \xff\xfe'
if [ "$CODE" -eq 0 ] && [ -z "$ERR" ]; then
  pass "09c malformed JSON -> exit 0, empty stderr"
else
  fail "09c malformed JSON -> exit 0, empty stderr" "code=$CODE err=[$ERR]"
fi

run_hook '{"tool_name":"Bash","tool_input":{}}'
if [ "$CODE" -eq 0 ] && [ -z "$ERR" ]; then
  pass "09d missing command -> exit 0, empty stderr"
else
  fail "09d missing command -> exit 0, empty stderr" "code=$CODE err=[$ERR]"
fi

run_hook '{"tool_name":"Bash","tool_input":{"command":""}}'
if [ "$CODE" -eq 0 ] && [ -z "$ERR" ]; then
  pass "09e empty command -> exit 0, empty stderr"
else
  fail "09e empty command -> exit 0, empty stderr" "code=$CODE err=[$ERR]"
fi

run_hook '{"tool_name":"Bash"}'
if [ "$CODE" -eq 0 ] && [ -z "$ERR" ]; then
  pass "09f missing tool_input -> exit 0, empty stderr"
else
  fail "09f missing tool_input -> exit 0, empty stderr" "code=$CODE err=[$ERR]"
fi

deny "10a quoted var redirect" 'echo x > "$R/reports/l1-exit.md"' 'reports/l1-exit.md'
deny "10b braced var redirect" 'echo x > ${R}/contracts/l1.md' 'contracts/l1.md'
deny "10c tee var dest" 'echo x | tee $R/contracts/l1.md' 'contracts/l1.md'
deny "10d drill heredoc" $'R=/abs/run/.artifacts; cat > $R/reports/l1-exit.md <<\'EOF\'\nbody\nEOF' 'reports/l1-exit.md'
deny "10e command substitution dest" 'echo x > $(pwd)/contracts/l2.md' 'contracts/l2.md'
deny "10f backtick dest" 'echo x > `pwd`/reports/l2-exit.md' 'reports/l2-exit.md'
deny "10g tilde dest" 'echo x > ~/run/lanes/l1.agent' 'lanes/l1.agent'
deny "10h cp var dest" 'cp /tmp/a $R/contracts/l3.md' 'contracts/l3.md'
deny "10i dd var dest" 'dd if=/tmp/a of=$R/reports/l3-exit.md' 'reports/l3-exit.md'
allow "10j scratch report via var" 'echo x > $R/reports/my-slug-abc123/report.md'
allow "10k .bak via var" 'echo x > $R/reports/l1-exit.md.bak'
allow "10l git commit mention" 'git commit -m "mention $R/reports/l1-exit.md and ${R}/contracts/l1.md"'
allow "10m literal non-lane path no var" 'echo x > /tmp/reports/l1-exit.md'

RUN="/w/run/.artifacts"
deny "11a cd contracts && heredoc append" $'cd /w/run/.artifacts/contracts && cat >> l8.md <<\'EOF\'\nbody\nEOF' "/w/run/.artifacts/contracts/l8.md"
deny "11b cd .artifacts && printf >> contracts/l7.md" "cd $RUN && printf 'x' >> contracts/l7.md" "$RUN/contracts/l7.md"
deny "11c cd \$RUN/reports && echo > l2-exit.md" 'cd $RUN/reports && echo x > l2-exit.md' 'reports/l2-exit.md'
deny "11d pushd lanes && echo > l1.agent" "pushd $RUN/lanes && echo a > l1.agent" "$RUN/lanes/l1.agent"
deny "11e payload cwd contracts, heredoc append" $'cat >> l8.md <<EOF\nbody\nEOF' "$RUN/contracts/l8.md" "$RUN/contracts"
deny "11f payload cwd .artifacts, cp to contracts/l3.md" 'cp /tmp/x contracts/l3.md' "$RUN/contracts/l3.md" "$RUN"
deny "11g chained cds then tee" "cd $RUN && cd contracts && tee l4.md" "$RUN/contracts/l4.md"
deny "11h cd -P then dd of=" "cd -P $RUN/reports && dd if=/tmp/a of=l1-exit.md" "$RUN/reports/l1-exit.md"
deny "11i quoted var cd, relative tail" 'cd "$R" && cp /tmp/a contracts/l9.md' 'contracts/l9.md'
deny "11j cd ; sed -i" "cd $RUN/contracts; sed -i s/a/b/ l2.md" "$RUN/contracts/l2.md"
allow "11k cd contracts && read" "cd $RUN/contracts && cat l8.md"
allow "11l cd /tmp && lane-shaped basename" 'cd /tmp && echo x > l8.md'
allow "11m subshell cd does not leak" "(cd $RUN/contracts) ; echo x > l8.md"
allow "11n cd contracts, absolute /tmp dest" "cd $RUN/contracts && echo x > /tmp/l8.md"
allow "11o cd .artifacts, progress-log" "cd $RUN && echo x >> progress-log.md"
allow "11p cd contracts, .bak dest" "cd $RUN/contracts && echo x > l1.md.bak"

echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ] || exit 1
exit 0
