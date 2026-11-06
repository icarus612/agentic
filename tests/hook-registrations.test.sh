#!/usr/bin/env bash
# Contract test: hook registrations in agent-specific/claude/settings.json (timeouts, if-scoping, script syntax).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$REPO_ROOT/agent-specific/claude/settings.json"
HOOKS_DIR="$REPO_ROOT/agent-agnostic/hooks"
SMART_TEST="$HOOKS_DIR/smart-test.sh"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n       %s\n' "$1" "${2:-}"; }
check(){ [ "$2" = "$3" ] && ok "$1" || bad "$1" "expected '$3', got '$2'"; }

T=$'\t'
PRE_BASH="PreToolUse${T}Bash"
PRE_WRITE="PreToolUse${T}Write|Edit|MultiEdit|NotebookEdit"
POST_WRITE="PostToolUse${T}Write|Edit|MultiEdit"
POST_BASH="PostToolUse${T}Bash"
POST_AGENT="PostToolUse${T}Agent"
STOP="Stop${T}-"
H="~/.claude/hooks"

# group<TAB>command<TAB>timeout
TABLE="\
${PRE_BASH}${T}${H}/no-attribution-guard.sh${T}30
${PRE_BASH}${T}${H}/pr-ready-hygiene-guard.sh${T}120
${PRE_BASH}${T}${H}/allow-workflow-cleanup.sh${T}30
${PRE_BASH}${T}${H}/branch-squash-guard.sh${T}30
${PRE_BASH}${T}${H}/lane-artifact-shell-guard.sh${T}30
${PRE_WRITE}${T}${H}/branch-squash-guard.sh${T}30
${PRE_WRITE}${T}${H}/scope-writes.sh${T}30
${POST_WRITE}${T}${H}/smart-lint.sh${T}300
${POST_WRITE}${T}${H}/smart-test.sh${T}660
${POST_WRITE}${T}${H}/claude-install-drift.sh${T}30
${POST_WRITE}${T}${H}/parent-tree-guard.sh${T}60
${POST_BASH}${T}${H}/parent-tree-guard.sh${T}60
${POST_AGENT}${T}${H}/lane-bind-on-launch.sh${T}30
${STOP}${T}${H}/ntfy-notifier.sh notification${T}30
${STOP}${T}${H}/parent-tree-guard.sh${T}60
${STOP}${T}${H}/workflow-diff-check.sh${T}600"

# group<TAB>expected handler count
COUNTS="\
${PRE_BASH}${T}6
${PRE_WRITE}${T}2
${POST_WRITE}${T}4
${POST_BASH}${T}1
${POST_AGENT}${T}1
${STOP}${T}3"

echo "hook registrations contract"

# --- 1: settings.json parses ------------------------------------------------
if [ ! -f "$SETTINGS" ]; then
  bad "settings.json exists" "missing: $SETTINGS"
  echo
  echo "$PASS passed, $FAIL failed"
  exit 1
fi
if jq . "$SETTINGS" >/dev/null 2>&1; then ok "1 settings.json parses with jq"
else
  bad "1 settings.json parses with jq" "jq failed"
  echo
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

# event, matcher, command, timeout-kind, timeout, has-if, if
HANDLERS=$(jq -r '
  .hooks | to_entries[]
  | select(.key | IN("PreToolUse","PostToolUse","Stop"))
  | .key as $e | .value[] | (if (.matcher // "") == "" then "-" else .matcher end) as $m | .hooks[]
  | [ $e, $m, (.command // "-"),
      (if (.timeout|type) == "number" and (.timeout == (.timeout|floor)) then "int" else "notint" end),
      (.timeout | tostring),
      (has("if") | tostring),
      (.if // "-") ]
  | @tsv' "$SETTINGS")

sel() { awk -F'\t' -v e="$1" -v m="$2" -v c="$3" '$1==e && $2==m && $3==c' <<<"$HANDLERS"; }
sel_group() { awk -F'\t' -v e="$1" -v m="$2" '$1==e && $2==m' <<<"$HANDLERS"; }
count_lines() { [ -z "$1" ] && echo 0 || printf '%s\n' "$1" | wc -l | tr -d ' '; }

# --- 2: timeouts per (event, matcher, command) and per-group counts ----------
while IFS="$T" read -r ev mt cmd want; do
  rows=$(sel "$ev" "$mt" "$cmd")
  n=$(count_lines "$rows")
  label="2 [$ev/$mt] $cmd timeout=$want"
  if [ "$n" -lt 1 ]; then bad "$label" "no such handler"; continue; fi
  wrong=$(printf '%s\n' "$rows" | awk -F'\t' -v w="$want" '!($4=="int" && $5==w)')
  if [ -z "$wrong" ]; then ok "$label"; else bad "$label" "got: $(printf '%s\n' "$wrong" | cut -f4,5 | tr '\n' ';')"; fi
done <<<"$TABLE"

while IFS="$T" read -r ev mt want; do
  got=$(count_lines "$(sel_group "$ev" "$mt")")
  check "2 handler count [$ev/$mt]" "$got" "$want"
done <<<"$COUNTS"

total_want=$(awk -F'\t' '{s+=$3} END{print s}' <<<"$COUNTS")
check "2 no handlers outside the table groups" "$(count_lines "$HANDLERS")" "$total_want"

# --- 3: smart-test timeout covers modes x (test timeout + kill grace) --------
if [ ! -f "$SMART_TEST" ]; then
  bad "3 smart-test.sh exists" "missing: $SMART_TEST"
else
  t_def=$(grep -o 'CLAUDE_HOOKS_TEST_TIMEOUT:-[0-9]*' "$SMART_TEST" | head -1 | sed 's/.*:-//')
  g_def=$(grep -o 'CLAUDE_HOOKS_TEST_KILL_GRACE:-[0-9]*' "$SMART_TEST" | head -1 | sed 's/.*:-//')
  m_def=$(grep -o 'CLAUDE_HOOKS_TEST_MODES:-[A-Za-z,_-]*' "$SMART_TEST" | head -1 | sed 's/.*:-//')
  check "3 smart-test default TEST_TIMEOUT found" "$t_def" "300"
  check "3 smart-test default KILL_GRACE found" "$g_def" "3"
  check "3 smart-test default MODES found" "$m_def" "focused,package"
  if [ -n "$t_def" ] && [ -n "$g_def" ] && [ -n "$m_def" ]; then
    modes=$(awk -F, '{print NF}' <<<"$m_def")
    need=$((modes * (t_def + g_def)))
    st=$(sel_group PostToolUse "Write|Edit|MultiEdit" | awk -F'\t' '$3 ~ /smart-test\.sh$/ {print $5}' | head -1)
    if [ -n "$st" ] && [ "$st" -gt "$need" ] 2>/dev/null; then ok "3 smart-test timeout $st > $need"
    else bad "3 smart-test timeout $st > $need" "timeout must exceed modes($modes) x ($t_def + $g_def)"; fi
  fi
fi

# --- 4: no Stop handler has an if --------------------------------------------
stop_if=$(awk -F'\t' '$1=="Stop" && $6=="true"' <<<"$HANDLERS")
check "4 no Stop handler has an if" "$(count_lines "$stop_if")" "0"

# --- 5: unscoped rows are exactly one handler with no if ---------------------
unscoped() {
  local ev="$1" mt="$2" cmd="$3" rows n noif
  rows=$(sel "$ev" "$mt" "$cmd"); n=$(count_lines "$rows")
  noif=$(printf '%s\n' "$rows" | awk -F'\t' '$6=="false"' | grep -c .)
  if [ "$n" = "1" ] && [ "$noif" = "1" ]; then ok "5 unscoped [$ev/$mt] $cmd"
  else bad "5 unscoped [$ev/$mt] $cmd" "handlers=$n without-if=$noif"; fi
}
unscoped PreToolUse Bash "$H/no-attribution-guard.sh"
unscoped PreToolUse Bash "$H/pr-ready-hygiene-guard.sh"
unscoped PreToolUse Bash "$H/branch-squash-guard.sh"
unscoped PreToolUse Bash "$H/lane-artifact-shell-guard.sh"
unscoped PreToolUse "Write|Edit|MultiEdit|NotebookEdit" "$H/scope-writes.sh"
unscoped PreToolUse "Write|Edit|MultiEdit|NotebookEdit" "$H/branch-squash-guard.sh"
unscoped PostToolUse "Write|Edit|MultiEdit" "$H/smart-lint.sh"
unscoped PostToolUse "Write|Edit|MultiEdit" "$H/smart-test.sh"
unscoped PostToolUse "Write|Edit|MultiEdit" "$H/claude-install-drift.sh"
unscoped PostToolUse "Write|Edit|MultiEdit" "$H/parent-tree-guard.sh"
unscoped PostToolUse Bash "$H/parent-tree-guard.sh"
unscoped Stop - "$H/parent-tree-guard.sh"
unscoped PostToolUse Agent "$H/lane-bind-on-launch.sh"

# --- 6: allow-workflow-cleanup keeps exactly its two if values ---------------
cleanup_rows=$(sel PreToolUse Bash "$H/allow-workflow-cleanup.sh")
check "6 allow-workflow-cleanup handler count" "$(count_lines "$cleanup_rows")" "2"
check "6 allow-workflow-cleanup if values" \
      "$(printf '%s\n' "$cleanup_rows" | cut -f7 | sort | tr '\n' '|')" \
      "Bash(git branch:*)|Bash(git worktree remove:*)|"

# --- 7: global if inventory --------------------------------------------------
all_ifs=$(awk -F'\t' '$6=="true" {print $7}' <<<"$HANDLERS" | sort -u | tr '\n' '|')
check "7 the only if values are the two allow-workflow-cleanup ones" \
      "$all_ifs" "Bash(git branch:*)|Bash(git worktree remove:*)|"
bad_paths=$(awk -F'\t' '$6=="true" && $7 ~ /^Edit\(/ && $7 !~ /^Edit\((\/\/|~\/)/ {print $7}' <<<"$HANDLERS")
check "7 any Edit( path rule starts with // or ~/" "$bad_paths" ""

# --- 8: every referenced hook script exists and parses -----------------------
scripts=$(awk -F'\t' '{print $3}' <<<"$HANDLERS" | awk '{print $1}' | sort -u)
for s in $scripts; do
  rel="${s#"~/.claude/hooks/"}"
  f="$HOOKS_DIR/$rel"
  if [ ! -f "$f" ]; then bad "8 hook script exists: $rel" "missing: $f"; continue; fi
  ok "8 hook script exists: $rel"
  if err=$(bash -n "$f" 2>&1); then ok "8 bash -n: $rel"; else bad "8 bash -n: $rel" "$err"; fi
done

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
