#!/usr/bin/env bash
# Per-worktree dev server hook; inert unless CLAUDE_DEV_SERVER_CMD resolves.
set -uo pipefail

case "${BASH_SOURCE[0]}" in
  /*) SELF=${BASH_SOURCE[0]} ;;
  *)  SELF="$PWD/${BASH_SOURCE[0]#./}" ;;
esac
HOOKDIR=${SELF%/*}
REG="${XDG_STATE_HOME:-${HOME:-}/.local/state}/dae/dev-servers"
PORT_PROBE_LIMIT=40
KILL_WAIT_TICKS=40
TICK=0.25

SYS=""
CTX=""
MAIN=""
L_PID=""
STOP_STATE=""
STOP_MSG=""

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  printf '%s' "$s"
}

emit() {
  printf '{"systemMessage": "%s", "hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "%s"}}\n' \
    "$(json_escape "$1")" "$(json_escape "$2")"
}

trim() {
  local s=$1
  s=${s#"${s%%[![:space:]]*}"}
  s=${s%"${s##*[![:space:]]}"}
  printf '%s' "$s"
}

norm() {
  local out
  out=$(realpath -m -- "$1" 2>/dev/null) || out=$1
  [ "$out" = / ] || out=${out%/}
  printf '%s' "${out:-/}"
}

unquote() {
  local s=$1
  case $s in
    \"*\") s=${s#\"}; s=${s%\"} ;;
    \'*\') s=${s#\'}; s=${s%\'} ;;
  esac
  printf '%s' "$s"
}

resolve_in() {
  local base=$1 p=$2
  case $p in
    '') p=$base ;;
    '~') p=${HOME:-} ;;
    '~/'*) p="${HOME:-}/${p#'~/'}" ;;
    /*) : ;;
    *) p="$base/$p" ;;
  esac
  norm "$p"
}

cfg() {
  local v
  v=$("$HOOKDIR/resolve-config.sh" "$1" --root "$MAIN" 2>/dev/null) || return 1
  [ -n "$v" ] || return 1
  printf '%s' "$v"
}

num_cfg() {
  local v
  v=$(cfg "$1") || v=$2
  case $v in '' | *[!0-9]*) v=$2 ;; esac
  printf '%s' "$((10#$v))"
}

port_busy() {
  (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null || return 1
  return 0
}

proc_start() {
  local s
  s=$(ps -o lstart= -p "$1" 2>/dev/null) || return 1
  s=$(trim "$s")
  [ -n "$s" ] || return 1
  printf '%s' "$s"
}

proc_cwd() {
  local c l
  if [ -d /proc/self ]; then
    c=$(readlink -f "/proc/$1/cwd" 2>/dev/null) || return 1
    [ -n "$c" ] || return 1
    printf '%s' "$c"
    return 0
  fi
  command -v lsof >/dev/null 2>&1 || return 1
  while IFS= read -r l; do
    case $l in n*) printf '%s' "${l#n}"; return 0 ;; esac
  done < <(lsof -a -p "$1" -d cwd -Fn 2>/dev/null)
  return 1
}

pid_is_ours() {
  local pid=$1 start=$2 wt=$3 startonly=${4:-0} live cwd root
  kill -0 "$pid" 2>/dev/null || return 1
  if [ -n "$start" ]; then
    live=$(proc_start "$pid") || return 1
    [ "$live" = "$start" ]
    return
  fi
  [ "$startonly" = 0 ] || return 1
  cwd=$(proc_cwd "$pid") || return 1
  root=$(norm "$wt")
  case $cwd in "$root" | "$root"/*) return 0 ;; esac
  return 1
}

kill_group() {
  local pid=$1 ticks=0
  kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
  while [ "$ticks" -lt "$KILL_WAIT_TICKS" ] && kill -0 "-$pid" 2>/dev/null; do
    sleep "$TICK"
    ticks=$((ticks + 1))
  done
  kill -0 "-$pid" 2>/dev/null && kill -KILL "-$pid" 2>/dev/null
  return 0
}

entry_wt() {
  local c
  if [ "$2" = server ]; then
    IFS=$'\t' read -r _ _ c _ < "$1"
  else
    IFS=$'\t' read -r c _ < "$1"
  fi
  printf '%s' "$c"
}

entry_key() {
  local sum
  read -r sum _ <<<"$(printf '%s' "$1" | cksum)"
  printf '%s-%s' "${1##*/}" "$sum"
}

drop_entries() {
  local wt=$1 kind=$2 f
  for f in "$REG/${wt##*/}"-*."$kind"; do
    [ -f "$f" ] || continue
    [ "$(entry_wt "$f" "$kind")" = "$wt" ] && rm -f "$f"
  done
}

find_server_entry() {
  local wt=$1 f
  for f in "$REG/${wt##*/}"-*.server; do
    [ -f "$f" ] || continue
    if [ "$(entry_wt "$f" server)" = "$wt" ]; then
      printf '%s' "$f"
      return 0
    fi
  done
  return 1
}

read_pidfile() {
  local pidfile="$1/.artifacts/dev-server.pid" a="" b=""
  P_PID="" P_START=""
  [ -f "$pidfile" ] || return 1
  { IFS= read -r a; IFS= read -r b; } < "$pidfile"
  a=$(trim "$a")
  case $a in '' | *[!0-9]*) return 1 ;; esac
  P_PID=$a
  P_START=$(trim "$b")
  return 0
}

live_server() {
  L_PID=""
  read_pidfile "$1" || return 1
  pid_is_ours "$P_PID" "$P_START" "$1" || return 1
  L_PID=$P_PID
}

stop_worktree() {
  local wt pid="" start="" f e_pid e_start
  wt=$(norm "$1")
  STOP_STATE=none
  STOP_MSG=""
  if read_pidfile "$wt"; then
    pid=$P_PID
    start=$P_START
  elif f=$(find_server_entry "$wt"); then
    IFS=$'\t' read -r e_pid e_start _ _ < "$f"
    pid=$e_pid
    [ "$e_start" = - ] || start=$e_start
  fi
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    if pid_is_ours "$pid" "$start" "$wt"; then
      kill_group "$pid"
      STOP_STATE=stopped
      STOP_MSG="stopped dev server (pid/pgid $pid) for $wt"
    else
      STOP_STATE=refused
      STOP_MSG="left pid $pid running for $wt: the pid could not be verified as this worktree's dev server"
    fi
  fi
  rm -f "$wt/.artifacts/dev-server.pid" "$wt/.artifacts/dev-server.url"
  drop_entries "$wt" server
  drop_entries "$wt" pending
}

sweep() {
  local f e_pid e_start e_wt
  for f in "$REG"/*.server; do
    [ -f "$f" ] || continue
    IFS=$'\t' read -r e_pid e_start e_wt _ < "$f"
    [ -e "$e_wt/.git" ] && continue
    [ "$e_start" = - ] && e_start=""
    if [ -n "$e_pid" ] && pid_is_ours "$e_pid" "$e_start" "$e_wt" 1; then
      kill_group "$e_pid"
    fi
    rm -f "$f"
  done
}

open_browser() {
  local rundir=$1 url=$2 mode=$3 marker="$1/dev-server.opened" opener="" c opid
  [ "$mode" != no ] || return 1
  opener=$(cfg CLAUDE_DEV_SERVER_BROWSER) || opener=""
  [ "$opener" != none ] || return 1
  if [ -f "$marker" ] && [ "$mode" != reopen ]; then
    return 2
  fi
  if [ -z "$opener" ]; then
    [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || return 1
    for c in google-chrome google-chrome-stable chromium; do
      if command -v "$c" >/dev/null 2>&1; then
        opener=$c
        break
      fi
    done
    [ -n "$opener" ] || return 1
  else
    command -v "$opener" >/dev/null 2>&1 || return 1
  fi
  setsid nohup "$opener" "$url" >/dev/null 2>&1 </dev/null &
  opid=$!
  sleep 0.2
  if ! kill -0 "$opid" 2>/dev/null; then
    wait "$opid" || return 1
  fi
  : > "$marker"
  return 0
}

start_server() {
  local wt=$1 open_mode=$2 ready_mode=$3
  local common cmd url_tpl url ready_paths p missing=0 rundir log pidfile pat='{port}'
  local pbase span timeout name hash port i pid start ticks rc sum
  SYS=""
  CTX=""
  [ -d "$wt" ] || return 3
  wt=$(norm "$wt")
  if [ ! -e "$wt/.git" ] || ! common=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    drop_entries "$wt" pending
    return 4
  fi
  MAIN=${common%/*}
  cmd=$(cfg CLAUDE_DEV_SERVER_CMD) || return 3

  rundir="$wt/.artifacts"
  log="$rundir/dev-server.log"
  pidfile="$rundir/dev-server.pid"
  name=${wt##*/}

  if live_server "$wt"; then
    url=""
    [ -f "$rundir/dev-server.url" ] && IFS= read -r url < "$rundir/dev-server.url"
    SYS="Dev server already running for $name: ${url:-see $log}"
    CTX="A dev server is ALREADY running for this worktree (pid $L_PID): ${url:-unknown}
Log: $log
Stop it with: $SELF --stop $wt"
    return 0
  fi

  if ! command -v setsid >/dev/null 2>&1; then
    SYS="Dev server for $name not started: setsid is not installed"
    CTX="The dev server was NOT started for $wt because the setsid command is not available on this host."
    return 1
  fi

  if [ "$ready_mode" = check ]; then
    ready_paths=$(cfg CLAUDE_DEV_SERVER_READY_PATHS) || ready_paths=""
    local -a paths=()
    read -ra paths <<<"$ready_paths"
    for p in ${paths[@]+"${paths[@]}"}; do
      [ -e "$wt/$p" ] || missing=1
    done
    if [ "$missing" = 1 ]; then
      mkdir -p "$REG" 2>/dev/null
      printf '%s\t%s\n' "$wt" "$ready_paths" > "$REG/$(entry_key "$wt").pending"
      SYS="Dev server queued for $name: starts once its prerequisites exist"
      CTX="The dev server is QUEUED for this worktree, not yet running: $wt is still missing one of: $ready_paths

It will start BY ITSELF on the first tool call after those paths exist. You do not need to do anything.

To start it immediately instead:
  $SELF --start $wt"
      return 0
    fi
  fi
  drop_entries "$wt" pending

  pbase=$(num_cfg CLAUDE_DEV_SERVER_PORT_BASE 5180)
  span=$(num_cfg CLAUDE_DEV_SERVER_PORT_SPAN 300)
  [ "$span" -ge 1 ] || span=1
  timeout=$(num_cfg CLAUDE_DEV_SERVER_READY_TIMEOUT 45)
  [ "$timeout" -le 80 ] || timeout=80
  read -r hash _ <<<"$(printf '%s' "$name" | cksum)"
  port=""
  for ((i = 0; i < PORT_PROBE_LIMIT; i++)); do
    p=$((pbase + hash % span + i))
    if ! port_busy "$p"; then
      port=$p
      break
    fi
  done
  if [ -z "$port" ]; then
    SYS="No free port for $name: dev server not started"
    CTX="The dev server was NOT started: no free port in $pbase-$((pbase + span + PORT_PROBE_LIMIT)).
Stop a dev server from another worktree and retry:
  $SELF --start $wt"
    return 1
  fi

  url_tpl=$(cfg CLAUDE_DEV_SERVER_URL) || url_tpl='http://localhost:{port}'
  url=${url_tpl//"$pat"/$port}
  cmd=${cmd//"$pat"/$port}

  mkdir -p "$rundir" 2>/dev/null
  : > "$log"
  rm -f "$rundir/dev-server.url"
  (
    cd "$wt" || exit 1
    export PORT=$port
    setsid nohup bash -c "$cmd" >> "$log" 2>&1 </dev/null &
    printf '%s\n' "$!" > "$pidfile"
  )
  read -r pid < "$pidfile"
  start=$(proc_start "$pid") || start=""
  printf '%s\n%s\n' "$pid" "$start" > "$pidfile"
  mkdir -p "$REG" 2>/dev/null
  sum=$(entry_key "$wt")
  printf '%s\t%s\t%s\t%s\n' "$pid" "${start:--}" "$wt" "$port" > "$REG/$sum.server"

  ticks=0
  while [ "$ticks" -lt $((timeout * 4)) ]; do
    port_busy "$port" && break
    kill -0 "$pid" 2>/dev/null || break
    sleep "$TICK"
    ticks=$((ticks + 1))
  done

  if ! port_busy "$port"; then
    kill -0 "$pid" 2>/dev/null || { rm -f "$pidfile" "$REG/$sum.server"; }
    SYS="Dev server for $name failed to start: see $log"
    CTX="The dev server for $wt did NOT bind port $port within ${timeout}s.
Read the log before continuing: $log
Retry after fixing:  $SELF --start $wt"
    return 1
  fi

  printf '%s\n' "$url" > "$rundir/dev-server.url"
  open_browser "$rundir" "$url" "$open_mode"
  rc=$?
  case $rc in
    0) SYS="Dev server up: $url" ;;
    2) SYS="Dev server up (tab already open): $url" ;;
    *) SYS="Dev server up (browser not opened): $url" ;;
  esac

  CTX="A dev server is now RUNNING for this workflow worktree.

  URL:      $url
  Port:     $port
  PID:      $pid (process group leader)
  Worktree: $wt
  Log:      $log

MONITOR THE LOG for the rest of this run: after any change that should show up in the browser, check it for compile, reload or runtime errors before reporting the change works:
  tail -n 40 $log
Treat errors in that log as blocking, exactly like a failed lint.

The port is derived from this worktree's name, so other worktrees' dev servers keep running alongside it.

It is stopped automatically when the worktree is removed. To stop it yourself:
  $SELF --stop $wt"
  return 0
}

check_pending() {
  local f wt paths p ripe
  local -a list=()
  for f in "$REG"/*.pending; do
    [ -f "$f" ] || continue
    IFS=$'\t' read -r wt paths < "$f"
    if [ ! -d "$wt" ]; then
      rm -f "$f"
      continue
    fi
    ripe=1
    read -ra list <<<"$paths"
    for p in ${list[@]+"${list[@]}"}; do
      [ -e "$wt/$p" ] || ripe=0
    done
    [ "$ripe" = 1 ] || continue
    rm -f "$f"
    start_server "$wt" auto skip
    case $? in
      3 | 4) continue ;;
      *) emit "$SYS" "$CTX"; exit 0 ;;
    esac
  done
}

json_field() {
  local s re="\"$1\"[[:space:]]*:[[:space:]]*\"(([^\"\\\\]|\\\\.)*)\""
  REPLY=""
  [[ $payload =~ $re ]] || return 1
  s=${BASH_REMATCH[1]}
  s=${s//\\\\/$'\001'}
  s=${s//\\\"/\"}
  s=${s//\\n/$'\n'}
  s=${s//\\t/$'\t'}
  s=${s//\\\//\/}
  s=${s//$'\001'/\\}
  REPLY=$s
}

hook_pre_remove() {
  local cmd cwd line eff t arg p i msgs="" target
  local -a tok=() targets=()
  case $payload in *worktree*) : ;; *) return 0 ;; esac
  case $payload in *remove*) : ;; *) return 0 ;; esac
  json_field command || return 0
  cmd=$REPLY
  case $cmd in *worktree*remove*) : ;; *) return 0 ;; esac
  json_field cwd
  cwd=$REPLY
  [ -n "$cwd" ] || cwd=$PWD

  cmd=${cmd//&&/$'\n'}
  cmd=${cmd//||/$'\n'}
  cmd=${cmd//|/$'\n'}
  cmd=${cmd//;/$'\n'}
  while IFS= read -r line; do
    tok=()
    read -ra tok <<<"$line"
    i=0
    while [[ ${tok[i]:-} =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; do i=$((i + 1)); done
    case ${tok[i]:-} in
      cd)
        arg=${tok[i + 1]:-}
        [ "$arg" = -- ] && arg=${tok[i + 2]:-}
        arg=$(unquote "$arg")
        [ -n "$arg" ] && cwd=$(resolve_in "$cwd" "$arg")
        continue
        ;;
      git | */git) : ;;
      *) continue ;;
    esac
    eff=$cwd
    i=$((i + 1))
    while :; do
      t=${tok[i]:-}
      case $t in
        -C)
          eff=$(resolve_in "$eff" "$(unquote "${tok[i + 1]:-}")")
          i=$((i + 2))
          ;;
        -c | --git-dir | --work-tree | --namespace | --super-prefix | --config-env) i=$((i + 2)) ;;
        -*) i=$((i + 1)) ;;
        *) break ;;
      esac
    done
    [ "${tok[i]:-}" = worktree ] && [ "${tok[i + 1]:-}" = remove ] || continue
    i=$((i + 2))
    while [[ ${tok[i]:-} == -* ]]; do i=$((i + 1)); done
    p=$(unquote "${tok[i]:-}")
    [ -n "$p" ] || continue
    targets+=("$(resolve_in "$eff" "$p")")
  done <<<"$cmd"

  for target in ${targets[@]+"${targets[@]}"}; do
    stop_worktree "$target"
    [ "$STOP_STATE" = none ] && continue
    msgs="${msgs:+$msgs; }$STOP_MSG"
  done
  [ -z "$msgs" ] || printf '{"systemMessage": "%s"}\n' "$(json_escape "dev-server cleanup: $msgs")"
  return 0
}

hook_post_tool() {
  local branch worktree
  local re_branch='BRANCH: ([^"\\]+)' re_wt='WORKTREE: ([^"\\]+)'
  sweep
  check_pending
  case $payload in *workflow-setup.sh*) : ;; *) return 0 ;; esac
  case $payload in *--parent*) return 0 ;; esac
  [[ $payload =~ $re_branch ]] || return 0
  branch=$(trim "${BASH_REMATCH[1]}")
  case ${branch%%/*} in feature | bug | hotfix) : ;; *) return 0 ;; esac
  [[ $payload =~ $re_wt ]] || return 0
  worktree=$(trim "${BASH_REMATCH[1]}")
  [ -d "$worktree" ] || return 0
  start_server "$worktree" auto check
  case $? in 3 | 4) : ;; *) emit "$SYS" "$CTX" ;; esac
  return 0
}

stop_all() {
  local f wt found=0
  for f in "$REG"/*.server; do
    [ -f "$f" ] || continue
    wt=$(entry_wt "$f" server)
    stop_worktree "$wt"
    found=1
    echo "${STOP_MSG:-no live dev server for $wt (registry entry removed)}"
  done
  [ "$found" = 1 ] || echo "no dev servers registered"
}

payload=""
case "${1:-}" in
  --start)
    [ -n "${2:-}" ] || { echo "usage: $0 --start <worktree> [--no-open|--reopen]" >&2; exit 1; }
    mode=auto
    case "${3:-}" in --no-open) mode=no ;; --reopen) mode=reopen ;; esac
    start_server "$2" "$mode" skip
    rc=$?
    if [ "$rc" -eq 4 ]; then
      echo "workflow-dev-server: $2 is not a git worktree root (no .git here, or not inside a git repository)" >&2
      exit 1
    fi
    if [ "$rc" -eq 3 ]; then
      echo "dev server not configured (CLAUDE_DEV_SERVER_CMD unset)" >&2
      exit 1
    fi
    printf '%s\n%s\n' "$SYS" "$CTX"
    exit "$rc"
    ;;
  --stop)
    [ -n "${2:-}" ] || { echo "usage: $0 --stop <worktree>" >&2; exit 1; }
    stop_worktree "$2"
    echo "${STOP_MSG:-no dev server running for $(norm "$2")}"
    exit 0
    ;;
  --status)
    [ -n "${2:-}" ] || { echo "usage: $0 --status <worktree>" >&2; exit 1; }
    wt=$(norm "$2")
    if live_server "$wt"; then
      url=""
      [ -f "$wt/.artifacts/dev-server.url" ] && IFS= read -r url < "$wt/.artifacts/dev-server.url"
      echo "running  pid=$L_PID  ${url:-unknown}  log=$wt/.artifacts/dev-server.log"
    else
      echo "not running for $wt"
    fi
    exit 0
    ;;
  --stop-all) stop_all; exit 0 ;;
  --sweep) sweep; exit 0 ;;
  --hook-pre-remove)
    IFS= read -r -d '' payload
    hook_pre_remove
    exit 0
    ;;
  *)
    IFS= read -r -d '' payload
    hook_post_tool
    exit 0
    ;;
esac
