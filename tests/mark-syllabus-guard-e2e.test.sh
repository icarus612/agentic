#!/usr/bin/env bash
# Runs the real mark-syllabus.sh against a real fixture plan.md, then checks the real parent-tree-guard.sh's verdict per identity.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARK_SYLLABUS="$REPO_ROOT/agent-agnostic/hooks/mark-syllabus.sh"
GUARD="$REPO_ROOT/agent-agnostic/hooks/parent-tree-guard.sh"
RESOLVE_CONFIG="$REPO_ROOT/agent-agnostic/hooks/resolve-config.sh"

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

pass() { echo "PASS: $1"; TOTAL_PASS=$((TOTAL_PASS + 1)); }
fail() { echo "FAIL: $1 ($2)"; TOTAL_FAIL=$((TOTAL_FAIL + 1)); }

new_scratch() {
  local d
  d=$(mktemp -d)
  SCRATCH_DIRS+=("$d")
  printf '%s' "$d"
}

git_init_repo() {
  local dir="$1"
  git -C "$dir" init -q
  git -C "$dir" config user.email "mark-syllabus-guard-e2e@example.com"
  git -C "$dir" config user.name "mark-syllabus-guard-e2e"
}

commit_all() {
  local dir="$1" msg="$2"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m "$msg" >/dev/null
}

resolved_plans_dir() {
  local root="$1" rel
  rel=$("$RESOLVE_CONFIG" CLAUDE_PROJECT_PLANS_DIR --default /project-plans/ --root "$root" 2>/dev/null)
  printf '%s' "${root%/}${rel}"
}

# Fresh scratch dir: git init'd, baseline commit, .artifacts/ gitignored,
# progress-log.md marker created untracked.
new_parent_worktree() {
  local dir
  dir=$(new_scratch)
  git_init_repo "$dir"
  printf '# fixture repo\n' >"$dir/README.md"
  printf '.artifacts/\n' >"$dir/.gitignore"
  commit_all "$dir" "baseline"
  mkdir -p "$dir/.artifacts"
  printf 'baseline progress\n' >"$dir/.artifacts/progress-log.md"
  printf '%s' "$dir"
}

# run_guard <cwd-dir> <stdin-json> -- sets OUT / ERR / CODE.
OUT=""; ERR=""; CODE=0
run_guard() {
  local cwd_dir="$1" stdin_json="$2"
  local out_f err_f
  out_f=$(mktemp); err_f=$(mktemp)
  ( cd "$cwd_dir" && printf '%s' "$stdin_json" | "$GUARD" ) >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f"); ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# Case 00: bash -n sanity precondition on both real scripts under test.
SYN_ERR_FILE=$(mktemp)
if bash -n "$MARK_SYLLABUS" 2>"$SYN_ERR_FILE" && bash -n "$GUARD" 2>>"$SYN_ERR_FILE"; then
  pass "00: bash -n mark-syllabus.sh && parent-tree-guard.sh exits 0"
else
  fail "00: bash -n mark-syllabus.sh && parent-tree-guard.sh exits 0" "syntax error: $(cat "$SYN_ERR_FILE")"
  rm -f "$SYN_ERR_FILE"
  echo "sanity failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
rm -f "$SYN_ERR_FILE"

# Shared fixture: one parent worktree, one committed real plan.md with two
# real syllabus checkbox lines.
WT=$(new_parent_worktree)
PLANS_DIR=$(resolved_plans_dir "$WT")
if [ -z "$PLANS_DIR" ]; then
  fail "prereq: resolve plans dir" "resolve-config.sh could not resolve CLAUDE_PROJECT_PLANS_DIR"
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
mkdir -p "$PLANS_DIR/e2e-plan-09-26-26"
PLAN_FILE="$PLANS_DIR/e2e-plan-09-26-26/plan.md"
cat >"$PLAN_FILE" <<'EOF'
## Phase syllabus
- [ ] Phase 1: Fixture phase
  - [ ] 1.1: First fixture subphase
  - [ ] 1.2: Second fixture subphase
EOF
commit_all "$WT" "add e2e fixture plan.md baseline"

# Case 01: the real script flips 1.1 -- verify the artifact, not just exit 0.
case01() {
  local label="01: real mark-syllabus.sh <plan> 1.1 x -> exit 0, only 1.1's line changes"
  local out code
  out=$("$MARK_SYLLABUS" "$PLAN_FILE" 1.1 x 2>&1)
  code=$?
  if [ "$code" -ne 0 ]; then
    fail "$label" "exit=$code out=[$out]"
    return
  fi
  if ! grep -qE '^\s+- \[x\] 1\.1:' "$PLAN_FILE"; then
    fail "$label" "1.1 line not flipped to [x] on disk; file now: $(cat "$PLAN_FILE")"
    return
  fi
  if ! grep -qE '^\s+- \[ \] 1\.2:' "$PLAN_FILE"; then
    fail "$label" "1.2 line was touched (should remain [ ]); file now: $(cat "$PLAN_FILE")"
    return
  fi
  pass "$label"
}
case01

# Case 02: the fix -- documenter identity, real diff -> allowed.
case02() {
  local label="02: agent_type=documenter, real mark-syllabus.sh diff on plan.md -> exit 0 (allowed)"
  local stdin_json
  stdin_json=$(printf '{"cwd": "%s", "tool_name": "Bash", "agent_type": "documenter"}' "$WT")
  run_guard "$WT" "$stdin_json"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case02

# Case 03: the closed defect, reproduced -- no agent_type, real diff -> denied.
case03() {
  local label="03: no agent_type (orchestrator), real mark-syllabus.sh diff on plan.md -> exit 2 (denied)"
  local stdin_json
  stdin_json=$(printf '{"cwd": "%s", "tool_name": "Bash"}' "$WT")
  run_guard "$WT" "$stdin_json"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s' "$ERR" | grep -q "plan.md\|$PLAN_FILE"; then
    fail "$label (stderr names the offending path)" "err=[$ERR]"
    return
  fi
  pass "$label"
}
case03

# Case 04: same, explicit agent_type=orchestrator -> denied.
case04() {
  local label="04: agent_type=orchestrator, real mark-syllabus.sh diff on plan.md -> exit 2 (denied)"
  local stdin_json
  stdin_json=$(printf '{"cwd": "%s", "tool_name": "Bash", "agent_type": "orchestrator"}' "$WT")
  run_guard "$WT" "$stdin_json"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case04

# Case 05: a second real call (dropped state) -- fix holds for every state.
case05() {
  local label="05: real mark-syllabus.sh <plan> 1.2 dropped -> exit 0 on disk, then documenter allowed / orchestrator denied"
  local out code stdin_json
  out=$("$MARK_SYLLABUS" "$PLAN_FILE" 1.2 dropped 2>&1)
  code=$?
  if [ "$code" -ne 0 ]; then
    fail "$label (script)" "exit=$code out=[$out]"
    return
  fi
  if ! grep -qE '^\s+- \[dropped\] 1\.2:' "$PLAN_FILE"; then
    fail "$label (on-disk edit)" "1.2 line not flipped to [dropped]; file now: $(cat "$PLAN_FILE")"
    return
  fi
  stdin_json=$(printf '{"cwd": "%s", "tool_name": "Bash", "agent_type": "documenter"}' "$WT")
  run_guard "$WT" "$stdin_json"
  if [ "$CODE" -ne 0 ]; then
    fail "$label (documenter allowed)" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  stdin_json=$(printf '{"cwd": "%s", "tool_name": "Bash"}' "$WT")
  run_guard "$WT" "$stdin_json"
  if [ "$CODE" -ne 2 ]; then
    fail "$label (orchestrator denied)" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case05

# Case 06: positive control -- an unrelated product-file change also denies.
case06() {
  local label="06: positive control -- unrelated product file change, no agent_type -> exit 2"
  local wt2 stdin_json
  wt2=$(new_parent_worktree)
  printf 'echo v1\n' >"$wt2/some-product-file.sh"
  commit_all "$wt2" "baseline product file"
  printf 'echo v2\n' >"$wt2/some-product-file.sh"
  stdin_json=$(printf '{"cwd": "%s", "tool_name": "Bash"}' "$wt2")
  run_guard "$wt2" "$stdin_json"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case06

echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
