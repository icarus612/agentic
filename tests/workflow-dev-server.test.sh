#!/usr/bin/env bash
# workflow-dev-server.test.sh: blind contract test for agent-agnostic/hooks/workflow-dev-server.sh (Packet C).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/agent-agnostic/hooks/workflow-dev-server.sh"

TOTAL_PASS=0
TOTAL_FAIL=0
KILL_PIDS=()
MODE_FAILS=0

SCRATCH="$(mktemp -d)"
SCRATCH="$(cd "$SCRATCH" && pwd -P)"
export HOME="$SCRATCH/home"
export XDG_STATE_HOME="$SCRATCH/xdg"
mkdir -p "$HOME" "$XDG_STATE_HOME"
unset DISPLAY WAYLAND_DISPLAY
for v in $(compgen -v CLAUDE_DEV_SERVER_); do unset "$v"; done
REG="$XDG_STATE_HOME/dae/dev-servers"
K="CLAUDE_DEV_SERVER_"
SERVER_CMD='python3 -m http.server {port} --bind 127.0.0.1'

kill_group() {
  case "${1:-}" in '' | *[!0-9]*) return 0 ;; esac
  [ "$1" -gt 1 ] || return 0
  kill -KILL -- "-$1" 2>/dev/null
  kill -KILL "$1" 2>/dev/null
  return 0
}

cleanup() {
  local f p
  for f in "$SCRATCH"/case*/repo/.workflows/*/.artifacts/dev-server.pid; do
    [ -f "$f" ] || continue
    read -r p <"$f" 2>/dev/null
    kill_group "${p:-}"
  done
  for f in "$REG"/*.server; do
    [ -f "$f" ] || continue
    IFS=$'\t' read -r p _ <"$f" 2>/dev/null
    kill_group "${p:-}"
  done
  for p in "${KILL_PIDS[@]:-}"; do kill_group "$p"; done
  rm -rf "$SCRATCH"
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

eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected [$2] got [$3]"; fi; }
has() { case "$2" in *"$3"*) pass "$1" ;; *) fail "$1" "missing [$3] in [${2:0:300}]" ;; esac; }
hasi() {
  local h="${2,,}" n="${3,,}"
  case "$h" in *"$n"*) pass "$1" ;; *) fail "$1" "missing (ci) [$3] in [${2:0:300}]" ;; esac
}
lacks() { case "$2" in *"$3"*) fail "$1" "unexpected [$3]" ;; *) pass "$1" ;; esac; }
yes() {
  local name="$1"
  shift
  if "$@"; then pass "$name"; else fail "$name" "check failed: $*"; fi
}
no() {
  local name="$1"
  shift
  if "$@"; then fail "$name" "unexpected success: $*"; else pass "$name"; fi
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

count_glob() {
  local n=0 f
  for f in $1; do [ -e "$f" ] && n=$((n + 1)); done
  printf '%s' "$n"
}

port_open() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

wait_port() {
  local i
  for ((i = 0; i < 100; i++)); do
    port_open "$1" && return 0
    sleep 0.1
  done
  return 1
}

wait_file() {
  local i
  for ((i = 0; i < 100; i++)); do
    [ -e "$1" ] && return 0
    sleep 0.1
  done
  return 1
}

wait_lines() {
  local i
  for ((i = 0; i < 50; i++)); do
    [ -f "$1" ] && [ "$(wc -l <"$1")" -ge "$2" ] && return 0
    sleep 0.1
  done
  return 1
}

group_alive() { kill -0 -- "-$1" 2>/dev/null; }
proc_alive() { kill -0 "$1" 2>/dev/null; }

wait_dead() {
  local i
  for ((i = 0; i < 80; i++)); do
    group_alive "$1" || return 0
    sleep 0.1
  done
  return 1
}

group_members() { ps -eo pid=,pgid= | awk -v g="$1" '$2==g{n++} END{print n+0}'; }

jesc() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

setup_payload() {
  local wt="$1" br="$2" cmd="${3:-bash /opt/hooks/workflow-setup.sh --name demo --type feature}"
  printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"},"tool_response":{"stdout":"WORKTREE: %s\\nBRANCH: %s\\nBASE: main\\n"}}' \
    "$(jesc "$CREPO")" "$(jesc "$cmd")" "$wt" "$br"
}

idle_payload() {
  printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"ls"}}' "$(jesc "${1:-$CREPO}")"
}

remove_payload() {
  printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"}}' "$(jesc "$1")" "$(jesc "$2")"
}

# Runs the hook with stdin $1 and args; sets OUT, ERR, RC. Hook modes must exit 0.
run_hook() {
  local in="$1"
  shift
  printf '%s' "$in" >"$SCRATCH/in"
  bash "$HOOK" "$@" <"$SCRATCH/in" >"$SCRATCH/out" 2>"$SCRATCH/err"
  RC=$?
  OUT="$(<"$SCRATCH/out")"
  ERR="$(<"$SCRATCH/err")"
  case "${1:-}" in
    '' | --hook-pre-remove | --sweep)
      if [ "$RC" -ne 0 ]; then
        MODE_FAILS=$((MODE_FAILS + 1))
        echo "  note: hook mode rc=$RC args=$*"
      fi
      ;;
  esac
}

json_get() {
  printf '%s' "$OUT" | python3 -I -c 'import json,sys
d=json.load(sys.stdin)
for k in sys.argv[1:]:
    d=d[k]
print(d)' "$@" 2>/dev/null
}

CASE_N=0
CREPO="" CWT="" CNAME="" CBASE=0 CTYPE=feature SPID="" SURL="" SPORT=""

add_worktree() {
  CNAME="$1"
  CWT="$CREPO/.workflows/$1"
  git -C "$CREPO" worktree add -q -b "${2:-feature}/$1" "$CWT" >/dev/null 2>&1
}

write_cfg() {
  local out='' sep='' kv k v seen=' '
  local defaults=("${K}PORT_BASE=$CBASE" "${K}PORT_SPAN=100" "${K}READY_TIMEOUT=20" "${K}BROWSER=none")
  for kv in "$@" "${defaults[@]}"; do
    k="${kv%%=*}"
    v="${kv#*=}"
    case "$seen" in *" $k "*) continue ;; esac
    seen+="$k "
    [ -n "$v" ] || continue
    out+="$sep\"$k\":\"$v\""
    sep=,
  done
  mkdir -p "$CREPO/.claude"
  printf '{"env":{%s}}\n' "$out" >"$CREPO/.claude/settings.json"
}

new_case() {
  local name="$1"
  shift
  CASE_N=$((CASE_N + 1))
  CREPO="$SCRATCH/case$CASE_N/repo"
  mkdir -p "$CREPO"
  git init -q -b main "$CREPO"
  git -C "$CREPO" config user.email "dev-server-test@example.com"
  git -C "$CREPO" config user.name "dev-server-test"
  printf 'x\n' >"$CREPO/README.md"
  git -C "$CREPO" add README.md
  git -C "$CREPO" commit -q -m base
  CBASE=$((40000 + RANDOM % 9000))
  add_worktree "$name" "$CTYPE"
  write_cfg "$@"
}

reg_file_for() {
  local f w
  for f in "$REG"/*."${2:-server}"; do
    [ -f "$f" ] || continue
    IFS=$'\t' read -r w _ <"$f"
    if [ "${2:-server}" = server ]; then IFS=$'\t' read -r _ _ w _ <"$f"; fi
    [ "$w" = "$1" ] && {
      printf '%s' "$f"
      return 0
    }
  done
  return 1
}

load_server() {
  SPID=''
  SURL=''
  SPORT=''
  local rf
  read -r SPID <"$CWT/.artifacts/dev-server.pid" 2>/dev/null || true
  read -r SURL <"$CWT/.artifacts/dev-server.url" 2>/dev/null || true
  rf="$(reg_file_for "$CWT" server)" && IFS=$'\t' read -r _ _ _ SPORT <"$rf"
  return 0
}

start_srv() {
  run_hook "$(setup_payload "$CWT" "${CTYPE}/$CNAME")"
  wait_file "$CWT/.artifacts/dev-server.pid"
  load_server
  [ -n "$SPORT" ] && wait_port "$SPORT"
  return 0
}

spawn_sleep() {
  (cd "$1" && exec setsid sleep 300) &
  SPID=$!
  KILL_PIDS+=("$SPID")
  local i
  for ((i = 0; i < 30; i++)); do
    [ "$(ps -o comm= -p "$SPID" 2>/dev/null)" = sleep ] && break
    sleep 0.1
  done
}

write_bare_pid() {
  mkdir -p "$CWT/.artifacts"
  printf '%s\n' "$1" >"$CWT/.artifacts/dev-server.pid"
}

echo "== 2.1 config, inert gating, post-setup start =="

new_case u1
start_srv
eq "2.1a unconfigured exit 0" 0 "$RC"
eq "2.1a unconfigured stdout empty" "" "$OUT"
eq "2.1a no dev-server files" 0 "$(count_glob "$CWT/.artifacts/dev-server.*")"

new_case b1 "${K}CMD=$SERVER_CMD"
start_srv
SM="$(json_get systemMessage)"
CTXT="$(json_get hookSpecificOutput additionalContext)"
eq "2.1b exit 0" 0 "$RC"
eq "2.1b hookEventName" PostToolUse "$(json_get hookSpecificOutput hookEventName)"
has "2.1b systemMessage has URL" "$SM" "http://localhost:$SPORT"
has "2.1b context has URL" "$CTXT" "http://localhost:$SPORT"
has "2.1b context has pid" "$CTXT" "$SPID"
has "2.1b context has log path" "$CTXT" "$CWT/.artifacts/dev-server.log"
has "2.1b context has --stop with hook path" "$CTXT" "$HOOK"
has "2.1b context has --stop flag" "$CTXT" "--stop"
hasi "2.1b context tells agent to monitor log" "$CTXT" "monitor"
yes "2.1b port in range" test "$SPORT" -ge "$CBASE" -a "$SPORT" -lt $((CBASE + 100 + 40))
eq "2.1b pgid is pid" "$SPID" "$(trim "$(ps -o pgid= -p "$SPID")")"
PF2="$(sed -n 2p "$CWT/.artifacts/dev-server.pid")"
eq "2.1b pid file line 2 is lstart" "$(trim "$(ps -o lstart= -p "$SPID")")" "$(trim "$PF2")"
eq "2.1b url file" "http://localhost:$SPORT" "$SURL"
yes "2.1b log file exists" test -f "$CWT/.artifacts/dev-server.log"
yes "2.1b port bound" port_open "$SPORT"
RF="$(reg_file_for "$CWT" server)"
yes "2.1b/2.5 registry .server entry" test -n "$RF"
IFS=$'\t' read -r RP RS RW RPORT <"$RF"
eq "2.5 entry pid" "$SPID" "$RP"
eq "2.5 entry worktree" "$CWT" "$RW"
eq "2.5 entry port" "$SPORT" "$RPORT"
eq "2.2f no pending when READY_PATHS unset" "" "$(reg_file_for "$CWT" pending || true)"
FIRST_PID="$SPID"
FIRST_PORT="$SPORT"

run_hook "$(setup_payload "$CWT" "feature/$CNAME")"
hasi "2.1e second setup says already running" "$OUT" "already running"
read -r P2 <"$CWT/.artifacts/dev-server.pid"
eq "2.1e pid unchanged" "$FIRST_PID" "$P2"
eq "2.1e one registry entry for wt" 1 "$(grep -lF "$CWT" "$REG"/*.server 2>/dev/null | wc -l)"
eq "2.1e still one pid file value" 1 "$(count_glob "$CWT/.artifacts/dev-server.pid")"

run_hook "" --stop "$CWT"
yes "2.1f stopped" wait_dead "$FIRST_PID"
no "2.5 stop removes registry entry" reg_file_for "$CWT" server
no "2.1f stop removes pid file" test -e "$CWT/.artifacts/dev-server.pid"
no "2.1f stop removes url file" test -e "$CWT/.artifacts/dev-server.url"
start_srv
eq "2.1f same name same port after restart" "$FIRST_PORT" "$SPORT"

new_case c1 "${K}CMD=echo arg={port} env=\$PORT > portmark.txt; $SERVER_CMD" "${K}URL=http://127.0.0.1:{port}/app" "${K}READY_TIMEOUT=6"
start_srv
eq "2.1c url substituted" "http://127.0.0.1:$SPORT/app" "$SURL"
wait_file "$CWT/portmark.txt"
eq "2.1c {port} and \$PORT reach command" "arg=$SPORT env=$SPORT" "$(<"$CWT/portmark.txt")"

new_case c2 "${K}CMD=sleep 300" "${K}URL=http://127.0.0.1:{port}/app" "${K}READY_TIMEOUT=3"
T0=$SECONDS
start_srv
ELAPSED=$((SECONDS - T0))
yes "2.1c READY_TIMEOUT honored (bounded wait)" test "$ELAPSED" -ge 2 -a "$ELAPSED" -lt 20
has "2.1 bind failure message names the log" "$OUT" "dev-server.log"
eq "2.1 exit 0 on bind failure" 0 "$RC"
run_hook "" --stop "$CWT"

new_case c3 "${K}CMD=$SERVER_CMD" "${K}READY_TIMEOUT=9999"
start_srv
yes "2.1c oversized READY_TIMEOUT clamped, server starts" test -f "$CWT/.artifacts/dev-server.url"

CTYPE=docs
new_case d1 "${K}CMD=$SERVER_CMD"
start_srv
eq "2.1d docs/ branch exit 0" 0 "$RC"
eq "2.1d docs/ branch no pid file" 0 "$(count_glob "$CWT/.artifacts/dev-server.*")"
CTYPE=sync
new_case d2 "${K}CMD=$SERVER_CMD"
start_srv
eq "2.1d sync/ branch no pid file" 0 "$(count_glob "$CWT/.artifacts/dev-server.*")"
CTYPE=feature
new_case d3 "${K}CMD=$SERVER_CMD"
run_hook "$(setup_payload "$CWT" "feature/$CNAME" "bash /opt/hooks/workflow-setup.sh --name demo --parent")"
eq "2.1d --parent setup exit 0" 0 "$RC"
eq "2.1d --parent setup no pid file" 0 "$(count_glob "$CWT/.artifacts/dev-server.*")"
run_hook "$(setup_payload "$CWT" "feature/$CNAME" "echo hello")"
eq "2.1d payload without workflow-setup.sh no pid file" 0 "$(count_glob "$CWT/.artifacts/dev-server.*")"

echo "== 2.1g genericness =="
FORBID='pnpm|node_modules|vite|apps/website|strictPort|medusa'
yes "2.1g positive control for grep" bash -c 'printf "%s\n" "run pnpm dev" | grep -Eiq "$0"' "$FORBID"
no "2.1g hook names no stack-specific tokens" grep -Eiq "$FORBID" "$HOOK"

echo "== 2.2 queued start =="

new_case q1 "${K}CMD=$SERVER_CMD" "${K}READY_PATHS=ready.flag sub/dir/file.txt"
Q_WT="$CWT"
run_hook "$(setup_payload "$CWT" "feature/$CNAME")"
hasi "2.2a queued message" "$OUT" "queued"
eq "2.2a no pid file" 0 "$(count_glob "$CWT/.artifacts/dev-server.*")"
PEND="$(reg_file_for "$CWT" pending)"
yes "2.2a pending entry exists" test -n "$PEND"
IFS=$'\t' read -r PW PR <"$PEND"
eq "2.2a pending worktree field" "$CWT" "$PW"
has "2.2a pending ready paths field" "$PR" "ready.flag"

run_hook "$(idle_payload)"
eq "2.2b still pending, no server" 0 "$(count_glob "$CWT/.artifacts/dev-server.pid")"
yes "2.2b pending kept" test -f "$PEND"

touch "$CWT/ready.flag"
run_hook "$(idle_payload)"
eq "2.2c partial readiness does not start" 0 "$(count_glob "$CWT/.artifacts/dev-server.pid")"
yes "2.2c pending kept on partial" test -f "$PEND"

mkdir -p "$CWT/sub/dir"
touch "$CWT/sub/dir/file.txt"
run_hook "$(idle_payload)"
wait_file "$CWT/.artifacts/dev-server.pid"
load_server
yes "2.2b server started once ready" test -n "$SPID"
yes "2.2b port bound" wait_port "$SPORT"
no "2.2b pending removed" test -e "$PEND"
has "2.2b output names URL" "$OUT" "$SURL"

new_case q2 "${K}CMD=$SERVER_CMD" "${K}READY_PATHS=ready.flag"
run_hook "$(setup_payload "$CWT" "feature/$CNAME")"
PEND="$(reg_file_for "$CWT" pending)"
rm -rf "$CWT"
git -C "$CREPO" worktree prune
run_hook "$(idle_payload)"
eq "2.2d exit 0" 0 "$RC"
no "2.2d pending dropped when worktree gone" test -e "$PEND"

new_case q3 "${K}CMD=$SERVER_CMD" "${K}READY_PATHS=ready.flag"
W1="$CWT"
N1="$CNAME"
add_worktree q3b feature
W2="$CWT"
run_hook "$(setup_payload "$W1" "feature/$N1")"
run_hook "$(setup_payload "$W2" "feature/q3b")"
yes "2.2e both queued" test -n "$(reg_file_for "$W1" pending)" -a -n "$(reg_file_for "$W2" pending)"
touch "$W1/ready.flag" "$W2/ready.flag"
run_hook "$(idle_payload)"
eq "2.2e at most one start per call" 1 "$(count_glob "$W1/.artifacts/dev-server.pid $W2/.artifacts/dev-server.pid")"
run_hook "$(idle_payload)"
eq "2.2e second start on next call" 2 "$(count_glob "$W1/.artifacts/dev-server.pid $W2/.artifacts/dev-server.pid")"
for w in "$W1" "$W2"; do
  read -r P <"$w/.artifacts/dev-server.pid"
  KILL_PIDS+=("$P")
done

new_case q4 "${K}CMD=$SERVER_CMD" "${K}READY_PATHS=ready.flag"
run_hook "$(setup_payload "$CWT" "feature/$CNAME")"
PEND="$(reg_file_for "$CWT" pending)"
yes "2.2f queued before stop" test -n "$PEND"
run_hook "" --stop "$CWT"
no "2.2f --stop deletes pending" test -e "$PEND"

new_case q5 "${K}CMD=$SERVER_CMD" "${K}READY_PATHS=ready.flag"
run_hook "$(setup_payload "$CWT" "feature/$CNAME")"
PEND="$(reg_file_for "$CWT" pending)"
write_cfg
touch "$CWT/ready.flag"
run_hook "$(idle_payload)"
eq "2.2 config unset on ripe: exit 0" 0 "$RC"
no "2.2 config unset on ripe: pending dropped" test -e "$PEND"
eq "2.2 config unset on ripe: nothing started" 0 "$(count_glob "$CWT/.artifacts/dev-server.pid")"

echo "== 2.2f idle path harness =="

H="$SCRATCH/idle"
mkdir -p "$H/emptybin" "$H/xdg" "$H/cwd"
cp "$HOOK" "$H/hook.sh"
printf '#!/bin/bash\necho "$*" >> "%s/stub.log"\nexit 1\n' "$H" >"$H/resolve-config.sh"
chmod +x "$H/resolve-config.sh"

idle_run() {
  printf '%s' "$1" >"$H/in"
  shift
  : >"$H/stub.log"
  PATH="${IDLE_PATH:-$H/emptybin}" XDG_STATE_HOME="$H/xdg" /bin/bash "$H/hook.sh" "$@" <"$H/in" >"$H/out" 2>"$H/err"
  RC=$?
  OUT="$(<"$H/out")"
  ERR="$(<"$H/err")"
}

idle_run "$(printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"ls"}}' "$H/cwd")"
eq "2.2f idle PostToolUse exit 0" 0 "$RC"
eq "2.2f idle PostToolUse stdout empty" "" "$OUT"
lacks "2.2f idle PostToolUse no command not found" "$ERR" "command not found"
eq "2.2f idle PostToolUse stub log empty" 0 "$(wc -c <"$H/stub.log")"

for c in "ls -la" "git worktree list"; do
  idle_run "$(printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"}}' "$H/cwd" "$c")" --hook-pre-remove
  eq "2.2f idle pre-remove [$c] exit 0" 0 "$RC"
  eq "2.2f idle pre-remove [$c] stdout empty" "" "$OUT"
  lacks "2.2f idle pre-remove [$c] no command not found" "$ERR" "command not found"
  eq "2.2f idle pre-remove [$c] stub log empty" 0 "$(wc -c <"$H/stub.log")"
done

new_case h1 "${K}CMD=$SERVER_CMD"
mkdir -p "$H/gitbin"
printf '#!/bin/bash\nexec %s "$@"\n' "$(command -v git)" >"$H/gitbin/git"
chmod +x "$H/gitbin/git"
IDLE_PATH="$H/gitbin" idle_run "$(setup_payload "$CWT" "feature/$CNAME")"
if [ -s "$H/stub.log" ] || [[ "$ERR" == *"command not found"* ]]; then
  pass "2.2f positive control: setup payload exercises commands"
else
  fail "2.2f positive control: setup payload exercises commands" "no stub log line and no command not found"
fi

echo "== 2.3 one browser tab per worktree =="

mk_opener() {
  OPENER="$SCRATCH/opener$CASE_N.sh"
  OPLOG="$SCRATCH/opener$CASE_N.log"
  : >"$OPLOG"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s"\n' "$OPLOG" >"$OPENER"
  chmod +x "$OPENER"
}

CASE_N=$((CASE_N + 1))
mk_opener
new_case o1 "${K}CMD=$SERVER_CMD" "${K}BROWSER=$OPENER"
start_srv
yes "2.3a opener called" wait_lines "$OPLOG" 1
eq "2.3a opener argv is the URL" "$SURL" "$(sed -n 1p "$OPLOG")"
yes "2.3a opened marker" test -e "$CWT/.artifacts/dev-server.opened"
run_hook "" --stop "$CWT"
wait_dead "$SPID"
run_hook "" --start "$CWT"
wait_file "$CWT/.artifacts/dev-server.pid"
load_server
wait_port "$SPORT"
sleep 0.5
eq "2.3a second start opens nothing" 1 "$(wc -l <"$OPLOG")"
hasi "2.3a second start says tab already open" "$OUT$ERR" "tab already open"
run_hook "" --stop "$CWT"
wait_dead "$SPID"
run_hook "" --start "$CWT" --reopen
wait_file "$CWT/.artifacts/dev-server.pid"
load_server
wait_port "$SPORT"
yes "2.3b --reopen opens again" wait_lines "$OPLOG" 2

CASE_N=$((CASE_N + 1))
mk_opener
new_case o2 "${K}CMD=$SERVER_CMD" "${K}BROWSER=$OPENER"
run_hook "" --start "$CWT" --no-open
wait_file "$CWT/.artifacts/dev-server.pid"
load_server
wait_port "$SPORT"
sleep 0.5
eq "2.3c --no-open calls no opener" 0 "$(wc -c <"$OPLOG")"

CASE_N=$((CASE_N + 1))
mk_opener
new_case o3 "${K}CMD=$SERVER_CMD" "${K}BROWSER=none"
start_srv
sleep 0.5
eq "2.3c BROWSER=none calls no opener" 0 "$(wc -c <"$OPLOG")"
no "2.3c BROWSER=none leaves no marker" test -e "$CWT/.artifacts/dev-server.opened"

BIN="$SCRATCH/chrome-bin"
mkdir -p "$BIN"
CASE_N=$((CASE_N + 1))
mk_opener
cp "$OPENER" "$BIN/google-chrome"
OPLOG_D="$OPLOG"
new_case o4 "${K}CMD=$SERVER_CMD" "${K}BROWSER="
OLDPATH="$PATH"
export PATH="$BIN:$PATH"
start_srv
sleep 0.5
eq "2.3d default chain without DISPLAY opens nothing" 0 "$(wc -c <"$OPLOG_D")"
hasi "2.3d message says browser not opened" "$OUT" "not opened"
run_hook "" --stop "$CWT"
wait_dead "$SPID"
export DISPLAY=:99
rm -f "$CWT/.artifacts/dev-server.opened"
start_srv
yes "2.3d positive control: DISPLAY set uses default chain" wait_lines "$OPLOG_D" 1
unset DISPLAY
export PATH="$OLDPATH"

CASE_N=$((CASE_N + 1))
mk_opener
new_case o5 "${K}CMD=$SERVER_CMD" "${K}BROWSER=$OPENER"
start_srv
U1="$SURL"
add_worktree o5b feature
CTYPE=feature
start_srv
U2="$SURL"
yes "2.3e two worktrees open two tabs" wait_lines "$OPLOG" 2
eq "2.3e exactly two opens" 2 "$(wc -l <"$OPLOG")"
yes "2.3e distinct URLs" test "$U1" != "$U2"
eq "2.3e each URL opened once" 2 "$(grep -cxF -e "$U1" -e "$U2" "$OPLOG")"

echo "== 2.4 removal detection and guarded stop =="

new_case rmlink l0
LINK="$SCRATCH/link"
ln -s "$CREPO/.workflows" "$LINK"

RM_TABLE=(
  "absolute path|repo|std|git worktree remove @WT@|dead"
  "-C repo absolute|root|std|git -C @REPO@ worktree remove @WT@|dead"
  "-C repo relative path|root|std|git -C @REPO@ worktree remove .workflows/@N@|dead"
  "relative path with cwd repo|repo|std|git worktree remove .workflows/@N@|dead"
  "--force|repo|std|git worktree remove --force @WT@|dead"
  "-f -f|repo|std|git worktree remove -f -f @WT@|dead"
  "-C a -C b-relative|root|std|git -C @REPO@ -C .workflows worktree remove @N@|dead"
  "-c kv and quoted path|root|std|git -c core.x=y worktree remove '@WT@'|dead"
  "cd then remove|root|std|cd @REPO@ && git worktree remove .workflows/@N@|dead"
  "wrapper grandchild dies|repo|wrap|git worktree remove @WT@|dead"
  "worktree list is not removal|repo|std|git worktree list|alive"
  "echo of the words is not removal|repo|std|echo \"worktree remove\"|alive"
  "other path leaves server running|repo|std|git worktree remove @OTHER@|alive"
)

RMI=0
for row in "${RM_TABLE[@]}"; do
  RMI=$((RMI + 1))
  IFS='|' read -r label cwdk srv tmpl expect <<<"$row"
  if [ "$srv" = wrap ]; then
    new_case "rm$RMI" "${K}CMD=bash -c 'python3 -m http.server {port} --bind 127.0.0.1 & wait'"
  else
    new_case "rm$RMI" "${K}CMD=$SERVER_CMD"
  fi
  start_srv
  PG="$SPID"
  cmd="${tmpl//@WT@/$CWT}"
  cmd="${cmd//@REPO@/$CREPO}"
  cmd="${cmd//@N@/$CNAME}"
  cmd="${cmd//@OTHER@/$SCRATCH/not-a-worktree}"
  if [ "$cwdk" = repo ]; then cwd="$CREPO"; else cwd="/"; fi
  if [ "$srv" = wrap ]; then
    yes "2.4 [$label] wrapper group has >=2 members" test "$(group_members "$PG")" -ge 2
  fi
  run_hook "$(remove_payload "$cwd" "$cmd")" --hook-pre-remove
  eq "2.4 [$label] exit 0" 0 "$RC"
  if [ "$expect" = dead ]; then
    yes "2.4 [$label] whole group gone" wait_dead "$PG"
    no "2.4 [$label] pid file removed" test -e "$CWT/.artifacts/dev-server.pid"
    no "2.4 [$label] registry entry removed" reg_file_for "$CWT" server
    has "2.4 [$label] cleanup message" "$OUT" "dev-server cleanup"
  else
    yes "2.4 [$label] server still running" group_alive "$PG"
    eq "2.4 [$label] no output" "" "$OUT"
  fi
done

new_case g1 "${K}CMD=$SERVER_CMD"
spawn_sleep "$CWT"
write_bare_pid "$SPID"
run_hook "$(remove_payload "$CREPO" "git worktree remove $CWT")" --hook-pre-remove
yes "2.4 guard bare pid, cwd in worktree: stopped" wait_dead "$SPID"
no "2.4 guard bare pid stopped: pid file removed" test -e "$CWT/.artifacts/dev-server.pid"

new_case g2 "${K}CMD=$SERVER_CMD"
spawn_sleep "$SCRATCH"
write_bare_pid "$SPID"
run_hook "$(remove_payload "$CREPO" "git worktree remove $CWT")" --hook-pre-remove
eq "2.4 guard unrelated pid: exit 0" 0 "$RC"
yes "2.4 guard unrelated pid survives" proc_alive "$SPID"
no "2.4 guard unrelated pid: pid file removed" test -e "$CWT/.artifacts/dev-server.pid"
hasi "2.4 guard unrelated pid: message says could not be verified" "$OUT" "could not be verified"

new_case g3 "${K}CMD=$SERVER_CMD"
spawn_sleep "$CWT"
mkdir -p "$CWT/.artifacts"
printf '%s\nMon Jan  1 00:00:00 2001\n' "$SPID" >"$CWT/.artifacts/dev-server.pid"
run_hook "$(remove_payload "$CREPO" "git worktree remove $CWT")" --hook-pre-remove
eq "2.4 guard mismatched start time: exit 0" 0 "$RC"
yes "2.4 guard mismatched start time survives" proc_alive "$SPID"

new_case g4 "${K}CMD=$SERVER_CMD"
rm -f "$LINK"
ln -s "$CREPO/.workflows" "$LINK"
spawn_sleep "$CWT"
write_bare_pid "$SPID"
run_hook "$(remove_payload "/" "git worktree remove $LINK/$CNAME")" --hook-pre-remove
yes "2.4 guard symlinked parent path still stopped" wait_dead "$SPID"

echo "== 2.5 registry, orphan sweep, CLI =="

new_case s1 "${K}CMD=$SERVER_CMD"
start_srv
PG="$SPID"
RF="$(reg_file_for "$CWT" server)"
git -C "$CREPO" worktree remove --force "$CWT"
run_hook "$(idle_payload)"
yes "2.5a sweep kills orphan group (git worktree remove)" wait_dead "$PG"
no "2.5a registry entry gone" test -e "$RF"

new_case s2 "${K}CMD=$SERVER_CMD"
start_srv
PG="$SPID"
RF="$(reg_file_for "$CWT" server)"
rm -rf "$CWT"
run_hook "$(idle_payload)"
yes "2.5b sweep kills orphan group (rm -rf)" wait_dead "$PG"
no "2.5b registry entry gone" test -e "$RF"

new_case s3 "${K}CMD=$SERVER_CMD"
start_srv
PG="$SPID"
RF="$(reg_file_for "$CWT" server)"
run_hook "$(idle_payload)"
yes "2.5 sweep leaves live worktree server" group_alive "$PG"
yes "2.5 sweep keeps live registry entry" test -e "$RF"

mkdir -p "$REG"
spawn_sleep "$SCRATCH"
FORGED="$REG/forged-1.server"
printf '%s\t%s\t%s\t%s\n' "$SPID" "Mon Jan  1 00:00:00 2001" "$SCRATCH/gone-worktree" 45999 >"$FORGED"
run_hook "$(idle_payload "$SCRATCH")"
yes "2.5c forged entry: unrelated process survives" proc_alive "$SPID"
no "2.5c forged entry removed" test -e "$FORGED"

spawn_sleep "$SCRATCH"
printf '%s\t%s\t%s\t%s\n' "$SPID" "Mon Jan  1 00:00:00 2001" "$SCRATCH/gone-worktree" 45999 >"$FORGED"
run_hook "" --sweep
eq "2.5 --sweep exit 0" 0 "$RC"
yes "2.5 --sweep forged: process survives" proc_alive "$SPID"
no "2.5 --sweep forged entry removed" test -e "$FORGED"

new_case t1 "${K}CMD=$SERVER_CMD"
start_srv
PG1="$SPID"
W1="$CWT"
new_case t2 "${K}CMD=$SERVER_CMD"
start_srv
PG2="$SPID"
W2="$CWT"
RF1="$(reg_file_for "$W1" server)"
RF2="$(reg_file_for "$W2" server)"
rm -rf "$W2"
run_hook "" --stop-all
yes "2.5d --stop-all stops existing worktree server" wait_dead "$PG1"
yes "2.5d --stop-all stops deleted worktree server" wait_dead "$PG2"
no "2.5d entry 1 removed" test -e "$RF1"
no "2.5d entry 2 removed" test -e "$RF2"

new_case st1 "${K}CMD=$SERVER_CMD"
start_srv
PG="$SPID"
run_hook "" --status "$CWT"
ST_RUN="$OUT"
rm -f "$CREPO/.claude/settings.json"
run_hook "" --stop "$CWT"
yes "2.5 --stop needs no config" wait_dead "$PG"
run_hook "" --status "$CWT"
ST_STOP="$OUT"
yes "2.5e --status running is non-empty" test -n "$ST_RUN"
yes "2.5e --status not-running is non-empty" test -n "$ST_STOP"
yes "2.5e --status differs" test "$ST_RUN" != "$ST_STOP"
eq "2.5e --status running is one line" 1 "$(printf '%s\n' "$ST_RUN" | wc -l)"
eq "2.5e --status not running is one line" 1 "$(printf '%s\n' "$ST_STOP" | wc -l)"

new_case st2 "${K}CMD=$SERVER_CMD"
start_srv
PG="$SPID"
RF="$(reg_file_for "$CWT" server)"
rm -rf "$CWT"
write_cfg
run_hook "" --stop "$CWT"
yes "2.5 --stop works when worktree dir is gone" wait_dead "$PG"
no "2.5 --stop removes registry entry" test -e "$RF"

new_case n1
run_hook "" --start "$CWT"
eq "2.5f --start unconfigured exit 1" 1 "$RC"
has "2.5f --start unconfigured message" "$ERR" "dev server not configured (CLAUDE_DEV_SERVER_CMD unset)"
eq "2.5f --start unconfigured starts nothing" 0 "$(count_glob "$CWT/.artifacts/dev-server.pid")"

new_case n2 "${K}CMD=$SERVER_CMD"
run_hook "" --start "$CWT" --no-open
wait_file "$CWT/.artifacts/dev-server.pid"
load_server
yes "2.5f --start configured binds port" wait_port "$SPORT"

echo "== 2.6 refuse non-worktree dirs; opener marker only after success =="

mk_opener_rc() {
  OPENER="$SCRATCH/openerrc$CASE_N.sh"
  OPLOG="$SCRATCH/openerrc$CASE_N.log"
  : >"$OPLOG"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s"\n%s\n' "$OPLOG" "$1" >"$OPENER"
  chmod +x "$OPENER"
}

assert_refused() {
  local label="$1" dir="$2"
  run_hook "" --start "$dir"
  eq "$label exit 1" 1 "$RC"
  has "$label stderr" "$ERR" "is not a git worktree root"
  eq "$label stdout empty" "" "$OUT"
  no "$label no .artifacts" test -e "$dir/.artifacts"
  no "$label no server entry" reg_file_for "$dir" server
  no "$label no pending entry" reg_file_for "$dir" pending
  eq "$label opener log empty" 0 "$(wc -c <"$OPLOG")"
  no "$label nothing in port range" port_open "$CBASE"
}

CASE_N=$((CASE_N + 1))
mk_opener
new_case r1 "${K}CMD=$SERVER_CMD" "${K}BROWSER=$OPENER"
PLAIN="$SCRATCH/plain-dir"
mkdir -p "$PLAIN"
assert_refused "2.6a plain non-git dir" "$PLAIN"
mkdir -p "$CWT/sub"
assert_refused "2.6b subdirectory of worktree" "$CWT/sub"

run_hook "" --start "$CWT" --no-open
wait_file "$CWT/.artifacts/dev-server.pid"
load_server
wait_port "$SPORT"
run_hook "$(idle_payload)"
eq "2.6c hook exit 0" 0 "$RC"
sleep 0.3
yes "2.6c server survives sweep" group_alive "$SPID"
yes "2.6c registry entry kept" test -n "$(reg_file_for "$CWT" server)"
run_hook "" --stop "$CWT"
wait_dead "$SPID"

run_hook "$(setup_payload "$PLAIN" "feature/plain")"
eq "2.6d hook path exit 0" 0 "$RC"
eq "2.6d hook path stdout empty" "" "$OUT"
no "2.6d hook path no server entry" reg_file_for "$PLAIN" server
no "2.6d hook path no pending entry" reg_file_for "$PLAIN" pending
no "2.6d hook path no .artifacts" test -e "$PLAIN/.artifacts"

CASE_N=$((CASE_N + 1))
mk_opener_rc 'exit 1'
new_case r2 "${K}CMD=$SERVER_CMD" "${K}BROWSER=$OPENER"
run_hook "" --start "$CWT"
wait_file "$CWT/.artifacts/dev-server.pid"
load_server
wait_port "$SPORT"
eq "2.6e failing opener: start succeeds" 0 "$RC"
hasi "2.6e message says not opened" "$OUT" "not opened"
no "2.6e no opened marker" test -e "$CWT/.artifacts/dev-server.opened"
run_hook "" --stop "$CWT"
wait_dead "$SPID"
run_hook "" --start "$CWT"
wait_file "$CWT/.artifacts/dev-server.pid"
load_server
wait_port "$SPORT"
eq "2.6e second start calls opener again" 2 "$(wc -l <"$OPLOG")"
run_hook "" --stop "$CWT"
wait_dead "$SPID"

CASE_N=$((CASE_N + 1))
new_case r3 "${K}CMD=$SERVER_CMD" "${K}BROWSER=$SCRATCH/no-such-opener"
run_hook "" --start "$CWT"
wait_file "$CWT/.artifacts/dev-server.pid"
load_server
wait_port "$SPORT"
hasi "2.6f missing opener: message says not opened" "$OUT" "not opened"
no "2.6f missing opener: no marker" test -e "$CWT/.artifacts/dev-server.opened"
run_hook "" --stop "$CWT"
wait_dead "$SPID"

CASE_N=$((CASE_N + 1))
mk_opener_rc 'exit 0'
new_case r4 "${K}CMD=$SERVER_CMD" "${K}BROWSER=$OPENER"
run_hook "" --start "$CWT"
wait_file "$CWT/.artifacts/dev-server.pid"
load_server
wait_port "$SPORT"
yes "2.6g exit-0 opener: marker written" test -e "$CWT/.artifacts/dev-server.opened"
run_hook "" --stop "$CWT"
wait_dead "$SPID"
run_hook "" --start "$CWT"
wait_file "$CWT/.artifacts/dev-server.pid"
load_server
wait_port "$SPORT"
sleep 0.3
eq "2.6g exit-0 opener: second start does not call it" 1 "$(wc -l <"$OPLOG")"
run_hook "" --stop "$CWT"
wait_dead "$SPID"

CASE_N=$((CASE_N + 1))
mk_opener_rc "printf '%s\\n' \$\$ > $SCRATCH/opener-r5.pid; exec sleep 300"
new_case r5 "${K}CMD=$SERVER_CMD" "${K}BROWSER=$OPENER"
run_hook "" --start "$CWT"
wait_file "$CWT/.artifacts/dev-server.pid"
load_server
wait_port "$SPORT"
wait_file "$SCRATCH/opener-r5.pid"
read -r OPID <"$SCRATCH/opener-r5.pid"
KILL_PIDS+=("$OPID")
yes "2.6g long-lived opener: marker written" test -e "$CWT/.artifacts/dev-server.opened"
run_hook "" --stop "$CWT"
wait_dead "$SPID"
run_hook "" --start "$CWT"
wait_file "$CWT/.artifacts/dev-server.pid"
load_server
wait_port "$SPORT"
eq "2.6g long-lived opener: second start does not call it" 1 "$(wc -l <"$OPLOG")"

echo "== 2.5g every hook mode exits 0 =="

run_hook ''
eq "2.5g empty stdin exit 0" 0 "$RC"
run_hook 'not json at all'
eq "2.5g garbage stdin exit 0" 0 "$RC"
run_hook 'not json at all' --hook-pre-remove
eq "2.5g garbage pre-remove exit 0" 0 "$RC"
run_hook '{"tool_input":{"command":"git worktree remove"}}' --hook-pre-remove
eq "2.5g pre-remove without cwd or path exit 0" 0 "$RC"
run_hook '{"tool_input":{"command":"git worktree remove /nonexistent/zzz"}}' --hook-pre-remove
eq "2.5g pre-remove nonexistent path exit 0" 0 "$RC"
eq "2.5g no hook-mode invocation exited non-zero" 0 "$MODE_FAILS"

echo
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
