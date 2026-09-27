#!/usr/bin/env bash
# none-mode-marker.test.sh
#
# SYNOPSIS
#   bash tests/none-mode-marker.test.sh
#
# DESCRIPTION
#   Functional/e2e test for the dae Phase 11.1 fix (contracts/l5.md): --worktree
#   none seeds its progress-log.md/dae-role markers under <repo-root>/.artifacts/
#   instead of bare at <repo-root>/. Unlike the other tests/*.test.sh files this
#   is NOT a blind contract test written from prose alone -- it is the builder's
#   own e2e verification, run against the REAL scripts
#   (agent-agnostic/hooks/progress-log.sh, workflow-setup.sh --set-role,
#   scope-writes.sh), because the thing that matters is observed behavior: does
#   a none-mode run actually get write enforcement, end to end.
#
#   Case 01 is a positive control, not incidental: it reproduces the OLD
#   (pre-fix) bare-root seeding and shows scope-writes.sh is blind to it (every
#   write permissively allowed, marker or no marker). Without this case, case 02
#   denying a write could just as easily mean "the fixture is broken and
#   scope-writes.sh denies everything" -- case 01 proves the same hook, same
#   script, genuinely CAN allow, so case 02's denial is real enforcement, not an
#   artifact of a stuck-closed fixture. This is the exact failure mode
#   verify-dont-assume warns about: a bare deny/zero is not evidence by itself.
#
#   Case 02 seeds the NEW way (mkdir -p .artifacts/{contracts,reports}, then
#   progress-log.sh --init .artifacts, then dae-role under .artifacts/) and
#   round-trips the builder<->orchestrator flip via the REAL
#   `workflow-setup.sh --set-role` calls -- the exact call lane 4's live drill
#   found failing with "no run dir at <root>" against the old bare-root layout.
#   It asserts, in order: the previously-failing --set-role call now succeeds;
#   a product write is ALLOWED under the builder role; the restore --set-role
#   call succeeds; and a (different) product write is DENIED under the restored
#   orchestrator role -- the criterion the plan states verbatim ("assert
#   scope-writes.sh ... denies a product write under the builder->orchestrator
#   flip").
#
#   All fixtures are throwaway mktemp -d git repos. grep/awk output is asserted
#   on CONTENT, never on exit status alone (shell-discipline: grep may be ugrep,
#   awk may be mawk).
#
# EXIT CODES
#   0  every case passed
#   1  at least one case failed (or a bash -n sanity precondition failed)
#
# Runnable with no arguments from any working directory.

set -uo pipefail

# ---------------------------------------------------------------------------
# Locate the scripts under test relative to this file's own location.
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROGRESS_LOG="$REPO_ROOT/agent-agnostic/hooks/progress-log.sh"
WORKFLOW_SETUP="$REPO_ROOT/agent-agnostic/hooks/workflow-setup.sh"
SCOPE_WRITES="$REPO_ROOT/agent-agnostic/hooks/scope-writes.sh"

# ---------------------------------------------------------------------------
# Bookkeeping
# ---------------------------------------------------------------------------
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

# init_repo <dir> -- a minimal git repo with an initial commit, on branch
# "feature/nonemode" (so it is never mistaken for a base branch).
init_repo() {
  local repo="$1"
  git init -q -b "feature/nonemode" "$repo" || return 1
  git -C "$repo" config user.email "tester@example.com" || return 1
  git -C "$repo" config user.name "Tester" || return 1
  printf '# fixture repo\n' >"$repo/README.md" || return 1
  git -C "$repo" add -A || return 1
  git -C "$repo" commit -q -m "initial commit" || return 1
  return 0
}

# run_hook <stdin-content> -- invokes scope-writes.sh with the given JSON
# payload on stdin; sets HOOK_CODE.
HOOK_CODE=0
HOOK_ERR=""
run_hook() {
  local stdin_content="$1"
  local err_f
  err_f=$(mktemp)
  printf '%s' "$stdin_content" | "$SCOPE_WRITES" >/dev/null 2>"$err_f"
  HOOK_CODE=$?
  HOOK_ERR=$(cat "$err_f")
  rm -f "$err_f"
}

write_payload() {
  printf '{"tool_name": "Write", "file_path": "%s"}' "$1"
}

# ---------------------------------------------------------------------------
# Case 00: bash -n sanity precondition on every script this test drives
# ---------------------------------------------------------------------------
SYN_ERR_FILE=$(mktemp)
syn_ok=1
for s in "$PROGRESS_LOG" "$WORKFLOW_SETUP" "$SCOPE_WRITES"; do
  if ! bash -n "$s" 2>>"$SYN_ERR_FILE"; then
    syn_ok=0
  fi
done
if [ "$syn_ok" = 1 ]; then
  pass "00: bash -n clean on progress-log.sh, workflow-setup.sh, scope-writes.sh"
else
  fail "00: bash -n clean on progress-log.sh, workflow-setup.sh, scope-writes.sh" "$(cat "$SYN_ERR_FILE")"
  rm -f "$SYN_ERR_FILE"
  echo "sanity failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
rm -f "$SYN_ERR_FILE"

# ---------------------------------------------------------------------------
# Case 01 (positive control): the OLD bare-root seeding leaves
# scope-writes.sh permissively blind -- a product write is ALLOWED even
# though markers exist, because they are invisible to the hook's
# .artifacts/progress-log.md walk. This proves the fixture/hook pairing can
# genuinely distinguish allow from deny before case 02 leans on a deny.
# ---------------------------------------------------------------------------
case01() {
  local label="01 (positive control): bare-root markers (pre-fix layout) -> scope-writes.sh blind, write allowed"
  local repo target payload out
  repo=$(new_scratch)
  init_repo "$repo" || { fail "$label" "init_repo failed"; return; }

  # Old (buggy) none-mode seeding: progress-log.md and dae-role bare at the
  # repo root, no .artifacts/ wrapper.
  out=$("$PROGRESS_LOG" --init "$repo" nonemode "feature/nonemode" main 2>&1)
  if [ ! -f "$repo/progress-log.md" ]; then
    fail "$label (setup)" "progress-log.sh --init did not create $repo/progress-log.md: $out"
    return
  fi
  printf '%s\n' "orchestrator" >"$repo/dae-role"

  target="$repo/product-file.sh"
  payload=$(write_payload "$target")
  run_hook "$payload"
  if [ "$HOOK_CODE" -ne 0 ]; then
    fail "$label -> exit 0 (hook blind to bare-root marker)" "code=$HOOK_CODE err=[$HOOK_ERR]"
    return
  fi
  pass "$label -> exit 0"
}
case01

# ---------------------------------------------------------------------------
# Case 02 (the fix): NEW none-mode seeding under <repo-root>/.artifacts/,
# then the real builder<->orchestrator role-flip round trip via
# workflow-setup.sh --set-role, with scope-writes.sh enforcement checked at
# each step. This is the drill that failed for lane 4 (see l4-exit.md,
# Blocker 2) -- it must now pass in full.
# ---------------------------------------------------------------------------
case02() {
  local label="02: new .artifacts-rooted seeding + builder<->orchestrator flip round-trip"
  local repo rundir out target1 target2 payload role_content

  repo=$(new_scratch)
  init_repo "$repo" || { fail "$label" "init_repo failed"; return; }
  rundir="$repo/.artifacts"

  # --- New none-mode Setup sequence (the fix under test) -------------------
  mkdir -p "$rundir/contracts" "$rundir/reports" || { fail "$label (setup)" "mkdir -p .artifacts/{contracts,reports} failed"; return; }
  out=$("$PROGRESS_LOG" --init "$rundir" nonemode "feature/nonemode" main 2>&1)
  if [ ! -f "$rundir/progress-log.md" ]; then
    fail "$label -> progress-log.sh --init seeds .artifacts/progress-log.md" "out=[$out]"
    return
  fi
  printf '%s\n' "orchestrator" >"$rundir/dae-role"
  if [ ! -d "$rundir/contracts" ] || [ ! -d "$rundir/reports" ]; then
    fail "$label -> contracts/ and reports/ exist under .artifacts/" "rundir=[$rundir]"
    return
  fi
  pass "$label -> Setup seeds progress-log.md, dae-role, contracts/, reports/ all under .artifacts/"

  # --- Sanity: orchestrator role already denies a product write (before any
  # flip) now that the marker is where the hook can see it ------------------
  target1="$repo/pre-flip-product.sh"
  payload=$(write_payload "$target1")
  run_hook "$payload"
  if [ "$HOOK_CODE" -ne 2 ]; then
    fail "$label -> orchestrator role denies product write pre-flip" "code=$HOOK_CODE err=[$HOOK_ERR]"
    return
  fi
  pass "$label -> orchestrator role denies product write pre-flip (marker now visible to the hook)"

  # --- The call that failed for lane 4: --set-role builder against the
  # none-mode root, now .artifacts-rooted ------------------------------------
  out=$("$WORKFLOW_SETUP" --set-role builder --root "$repo" 2>&1)
  if [ $? -ne 0 ]; then
    fail "$label -> --set-role builder --root <repo-root> succeeds" "out=[$out]"
    return
  fi
  pass "$label -> --set-role builder --root <repo-root> succeeds (lane 4's failing drill now passes)"

  role_content=$(cat "$rundir/dae-role" 2>/dev/null | tr -d '[:space:]')
  if [ "$role_content" != "builder" ]; then
    fail "$label -> dae-role now reads 'builder'" "role_content=[$role_content]"
    return
  fi
  pass "$label -> dae-role file flipped to 'builder'"

  # --- Builder role: a product write is now ALLOWED -------------------------
  target1="$repo/builder-written-file.sh"
  payload=$(write_payload "$target1")
  run_hook "$payload"
  if [ "$HOOK_CODE" -ne 0 ]; then
    fail "$label -> builder role allows product write" "code=$HOOK_CODE err=[$HOOK_ERR]"
    return
  fi
  pass "$label -> builder role allows product write"

  # --- Restore: --set-role orchestrator --------------------------------------
  out=$("$WORKFLOW_SETUP" --set-role orchestrator --root "$repo" 2>&1)
  if [ $? -ne 0 ]; then
    fail "$label -> --set-role orchestrator --root <repo-root> succeeds (restore)" "out=[$out]"
    return
  fi
  pass "$label -> --set-role orchestrator --root <repo-root> succeeds (restore)"

  role_content=$(cat "$rundir/dae-role" 2>/dev/null | tr -d '[:space:]')
  if [ "$role_content" != "orchestrator" ]; then
    fail "$label -> dae-role restored to 'orchestrator'" "role_content=[$role_content]"
    return
  fi
  pass "$label -> dae-role file restored to 'orchestrator'"

  # --- THE criterion the plan states verbatim: a product write is DENIED
  # under the restored orchestrator role, post round-trip. -------------------
  target2="$repo/post-flip-product.sh"
  payload=$(write_payload "$target2")
  run_hook "$payload"
  if [ "$HOOK_CODE" -ne 2 ]; then
    fail "$label -> orchestrator role denies product write post-flip" "code=$HOOK_CODE err=[$HOOK_ERR]"
    return
  fi
  if ! printf '%s\n' "$HOOK_ERR" | grep -qF -- "$target2"; then
    fail "$label -> stderr names the offending path" "target=[$target2] err=[$HOOK_ERR]"
    return
  fi
  pass "$label -> orchestrator role denies product write post-flip, stderr names it (the enforcement-gap regression guard)"
}
case02

echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ]
