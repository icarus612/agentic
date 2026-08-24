#!/usr/bin/env bash
# sync-install-settings-merge.test.sh
#
# SYNOPSIS
#   bash tests/sync-install-settings-merge.test.sh
#
# DESCRIPTION
#   Contract test for the settings.json unit of orchestrators/hooks/sync-install.sh.
#   That unit is MERGED rather than copied, because Claude Code writes to the
#   live file during normal use (`/model` persists "model"; "always allow"
#   appends to permissions.allow) and a whole-file copy clobbers it.
#
#   The documented contract:
#     - a key the SOURCE defines is authoritative (the repo wins)
#     - a key only the INSTALL has is PRESERVED at any depth
#     - permissions.allow is UNIONED: source first, then live-only, deduped
#     - --check reports drift as "the merge would change the install", never
#       as "the two files differ" (they differ by design)
#     - python3 absent => REFUSE, never fall back to a clobbering copy
#
#   Every fixture is a throwaway mktemp -d: a fake repo (git init, on main, not
#   a linked worktree, so the script's preconditions hold) and a fake install
#   home passed via --home. The real $HOME and ~/.claude are never touched.
#
# EXIT CODES
#   0  every case passed
#   1  at least one case failed

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/orchestrators/hooks/sync-install.sh"

PASS=0; FAIL=0; SCRATCH=()
cleanup() { local d; for d in "${SCRATCH[@]:-}"; do [ -n "$d" ] && rm -rf "$d"; done; }
trap cleanup EXIT

ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n       %s\n' "$1" "${2:-}"; }
check(){ [ "$2" = "$3" ] && ok "$1" || bad "$1" "expected '$3', got '$2'"; }

# --- fixture builders -------------------------------------------------------

# make_repo <source-json> -> prints repo path
make_repo() {
  local d; d=$(mktemp -d); SCRATCH+=("$d")
  mkdir -p "$d/agent-agnostic/rules" "$d/orchestrators/hooks" "$d/agent-specific/claude"
  printf '%s\n' "$1" > "$d/agent-specific/claude/settings.json"
  cp "$SCRIPT" "$d/orchestrators/hooks/sync-install.sh"
  git -C "$d" -c init.defaultBranch=main init -q
  git -C "$d" -c user.email=t@t -c user.name=t add -A >/dev/null 2>&1
  git -C "$d" -c user.email=t@t -c user.name=t commit -qm init >/dev/null 2>&1
  echo "$d"
}

# make_home <install-json-or-empty> -> prints home path
make_home() {
  local d; d=$(mktemp -d); SCRATCH+=("$d")
  [ -n "$1" ] && printf '%s\n' "$1" > "$d/settings.json"
  echo "$d"
}

run_sync()  { ( cd "$1" && bash orchestrators/hooks/sync-install.sh --claude --home "$2" --full 2>&1 ); }
run_check() { ( cd "$1" && bash orchestrators/hooks/sync-install.sh --claude --home "$2" --check 2>&1 ); }
jget()      { python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(eval(sys.argv[2]))" "$1" "$2"; }

SRC='{
  "permissions": { "allow": ["Bash(pnpm:*)", "Bash(git:*)"], "deny": ["Bash(rm:*)"] },
  "hooks": { "Stop": ["repo-stop"] },
  "tui": "repo-value"
}'
INST='{
  "model": "opus",
  "permissions": { "allow": ["Bash(pnpm:*)", "Bash(live-only:*)"], "deny": ["Bash(rm:*)"] },
  "hooks": { "Stop": ["repo-stop"], "LiveOnlyEvent": ["x"] },
  "tui": "stale-value",
  "liveOnlyToggle": true
}'

echo "settings.json merge contract"

# --- C1..C5: one sync, five assertions --------------------------------------
repo=$(make_repo "$SRC"); home=$(make_home "$INST")
out=$(run_sync "$repo" "$home")

case "$out" in *"MERGED (claude): settings.json"*) ok "reports MERGED, not SYNCED" ;;
  *) bad "reports MERGED, not SYNCED" "output was: $out" ;; esac

check "C1 install-only top-level key preserved (model)" \
      "$(jget "$home/settings.json" 'd.get("model")')" "opus"
check "C2 install-only top-level key preserved (liveOnlyToggle)" \
      "$(jget "$home/settings.json" 'd.get("liveOnlyToggle")')" "True"
check "C3 source wins on a conflicting scalar (tui)" \
      "$(jget "$home/settings.json" 'd["tui"]')" "repo-value"
check "C4 install-only NESTED key preserved (hooks.LiveOnlyEvent)" \
      "$(jget "$home/settings.json" '"LiveOnlyEvent" in d["hooks"]')" "True"
check "C5 permissions.allow unioned (source order, then live-only)" \
      "$(jget "$home/settings.json" 'd["permissions"]["allow"]')" \
      "['Bash(pnpm:*)', 'Bash(git:*)', 'Bash(live-only:*)']"

# --- C6: --check is merge-aware, not diff-aware -----------------------------
out=$(run_check "$repo" "$home")
case "$out" in *"STALE"*) bad "C6 --check clean after a sync" "reported STALE: $out" ;;
  *) ok "C6 --check clean after a sync (despite files differing by design)" ;; esac

# --- C7: --check DOES report real drift -------------------------------------
printf '%s\n' "${SRC/repo-value/changed-value}" > "$repo/agent-specific/claude/settings.json"
out=$(run_check "$repo" "$home")
case "$out" in *"STALE (claude): settings.json"*) ok "C7 --check reports drift when the source changes" ;;
  *) bad "C7 --check reports drift when the source changes" "output was: $out" ;; esac

# --- C8: no install file yet -> created from source alone -------------------
repo2=$(make_repo "$SRC"); home2=$(make_home "")
run_sync "$repo2" "$home2" >/dev/null
check "C8 absent install file is created from source" \
      "$(jget "$home2/settings.json" 'd["tui"]')" "repo-value"
check "C8 absent install file gains no phantom keys" \
      "$(jget "$home2/settings.json" '"model" in d')" "False"

# --- C9: python3 missing -> refuse, never clobber ---------------------------
repo3=$(make_repo "$SRC"); home3=$(make_home "$INST")
fakebin=$(mktemp -d); SCRATCH+=("$fakebin")
for t in bash env sh git diff mv rm find sort sed awk cut basename dirname mkdir \
         cp printf grep wc tr cat ls mktemp head tail rmdir readlink; do
  p=$(command -v "$t" 2>/dev/null) && ln -sf "$p" "$fakebin/$t"
done
out=$( cd "$repo3" && PATH="$fakebin" bash orchestrators/hooks/sync-install.sh --claude --home "$home3" --full 2>&1 )
case "$out" in *"REFUSING to sync settings.json"*) ok "C9 refuses when python3 is unavailable" ;;
  *) bad "C9 refuses when python3 is unavailable" "output was: $out" ;; esac
check "C9 live install untouched by the refusal" \
      "$(python3 -c "import json;print(json.load(open('$home3/settings.json'))['tui'])")" "stale-value"

echo
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" -eq 0 ]
