#!/usr/bin/env bash
# l6-role-escalation-e2e.test.sh
#
# SYNOPSIS
#   bash tests/l6-role-escalation-e2e.test.sh
#
# DESCRIPTION
#   Functional/e2e test for lane 6's fix to code-review.md round 1's two
#   blocking findings (contracts/l6.md). Unlike tests/scope-writes.test.sh and
#   tests/parent-tree-guard.test.sh (blind contract tests, packet-level), this
#   is the BUILDER'S OWN end-to-end verification, run against the REAL tool
#   chain -- workflow-setup.sh actually creating a real parent worktree AND a
#   real lane child worktree (via `git worktree add`, exactly as
#   build-dispatch.md does), then scope-writes.sh and parent-tree-guard.sh
#   run against that real topology -- because what matters is observed
#   end-to-end behavior, not an isolated fixture's fidelity to production.
#
#   Case 01-03 are the "three outcomes" drill the plan's Phase 10.1 names:
#   create a parent worktree, attempt a product write as each role, assert
#   the outcome. Case 04 is the literal escalation the code review
#   reproduced and this lane exists to close: seed role=orchestrator in the
#   REAL parent worktree, perform the exact Bash tamper
#   (`printf 'builder' > .artifacts/dae-role`, no hook, no script -- a bare
#   redirect, precisely what a compromised or careless orchestrator agent
#   would run), then assert BOTH (a) parent-tree-guard.sh denies on the very
#   next PostToolUse-Bash pass even with git status otherwise clean (tamper
#   detection -- .artifacts/ is gitignored, so a git-status-only check could
#   never see this), and (b) a subsequent scope-writes.sh Write-tool call to
#   a product path in the parent is STILL denied (the escalation itself no
#   longer succeeds). Case 05 confirms the real lane child is unaffected
#   throughout (builder role stays structurally derived, never read from any
#   marker file).
#
#   Cases 06-09 close a FURTHER gap the coordinator found in review, on top
#   of the two above: a rejected/garbage role in the marked parent must not
#   fall back to the OLD permissive plans+docs roots (that fallback was
#   itself an escalation -- an orchestrator forging any unrecognized token
#   could self-upgrade from "zero outside its own gate reports" to "the
#   whole plans dir and the whole docs tree"). Case 06 forges `builder`,
#   case 07 forges plain garbage, both assert plans root AND docs root are
#   now denied too (previously both were wrongly allowed). Case 08 is the
#   positive control: a GENUINE planner token still reaches the plans root
#   -- proving the fix closed the forged/garbage path, not the plans root
#   itself. Case 09 re-confirms the fully UNMARKED path (no
#   .artifacts/progress-log.md anywhere in the ancestry) is a completely
#   different code path, untouched, and stays fully permissive.
#
#   All fixtures are throwaway mktemp -d git repos; workflow-setup.sh is
#   invoked with HOME pinned to an empty scratch dir and --base main passed
#   explicitly, so neither the real repo, its real worktrees, nor the real
#   $HOME are ever touched. grep/awk output is asserted on CONTENT, never on
#   exit status alone (shell-discipline: grep may be ugrep, awk may be mawk).
#
# EXIT CODES
#   0  every case passed
#   1  at least one case failed (or a bash -n sanity precondition failed)
#
# Runnable with no arguments from any working directory.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW_SETUP="$REPO_ROOT/agent-agnostic/hooks/workflow-setup.sh"
SCOPE_WRITES="$REPO_ROOT/agent-agnostic/hooks/scope-writes.sh"
PARENT_TREE_GUARD="$REPO_ROOT/agent-agnostic/hooks/parent-tree-guard.sh"

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

# init_repo <dir> -- git init -b main, identity config, one commit with a
# committed .gitignore containing .artifacts/ (the real repo's own
# convention, per run-artifacts) and a tracked product file.
init_repo() {
  local repo="$1"
  git init -q -b main "$repo" || return 1
  git -C "$repo" config user.email "tester@example.com" || return 1
  git -C "$repo" config user.name "Tester" || return 1
  printf '# fixture repo\n' >"$repo/README.md" || return 1
  printf '.artifacts/\n' >"$repo/.gitignore" || return 1
  mkdir -p "$repo/src" || return 1
  printf 'echo baseline\n' >"$repo/src/app.js" || return 1
  git -C "$repo" add -A || return 1
  git -C "$repo" commit -q -m "initial commit" || return 1
  return 0
}

get_field() { printf '%s\n' "$1" | grep -m1 -- "^${2}" | sed "s/^${2}//"; }

run_setup() {
  local repo="$1" home="$2"; shift 2
  local out_f err_f
  out_f=$(mktemp); err_f=$(mktemp)
  ( cd "$repo" && HOME="$home" "$WORKFLOW_SETUP" "$@" ) </dev/null >"$out_f" 2>"$err_f"
  SETUP_CODE=$?
  SETUP_OUT=$(cat "$out_f"); SETUP_ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# write_payload <path> -- a minimal PreToolUse Write payload naming <path>.
write_payload() { printf '{"tool_name": "Write", "tool_input": {"file_path": "%s"}}' "$1"; }

run_scope_writes() {
  local stdin_content="$1"
  local out_f err_f
  out_f=$(mktemp); err_f=$(mktemp)
  printf '%s' "$stdin_content" | "$SCOPE_WRITES" >"$out_f" 2>"$err_f"
  SW_CODE=$?
  SW_OUT=$(cat "$out_f"); SW_ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

run_guard() {
  local cwd_dir="$1"
  local out_f err_f stdin_json
  out_f=$(mktemp); err_f=$(mktemp)
  stdin_json=$(printf '{"cwd": "%s", "tool_name": "Bash"}' "$cwd_dir")
  ( cd "$cwd_dir" && printf '%s' "$stdin_json" | "$PARENT_TREE_GUARD" ) >"$out_f" 2>"$err_f"
  PTG_CODE=$?
  PTG_OUT=$(cat "$out_f"); PTG_ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# ---------------------------------------------------------------------------
# Case 00: bash -n sanity precondition on this file itself is implicit
# (the harness already ran it to get here); sanity-check the three scripts
# under test parse.
# ---------------------------------------------------------------------------
for s in "$WORKFLOW_SETUP" "$SCOPE_WRITES" "$PARENT_TREE_GUARD"; do
  if ! bash -n "$s" 2>/tmp/l6e2e-synerr; then
    fail "00: bash -n $s" "syntax error: $(cat /tmp/l6e2e-synerr)"
    echo "sanity failed: nothing else can be trusted, stopping."
    echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
    exit 1
  fi
done
pass "00: bash -n sanity on workflow-setup.sh, scope-writes.sh, parent-tree-guard.sh"

# ---------------------------------------------------------------------------
# Shared setup: one real repo, one real parent worktree (workflow-setup.sh,
# not a hand-rolled fixture), one real lane child cut off it (--parent,
# exactly as build-dispatch.md does).
# ---------------------------------------------------------------------------
REPO=$(new_scratch)
HOME_DIR=$(new_scratch)
if ! init_repo "$REPO"; then
  fail "setup: init_repo" "could not build the base fixture repo"
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi

run_setup "$REPO" "$HOME_DIR" --name l6e2e --type bug --base main
if [ "$SETUP_CODE" -ne 0 ]; then
  fail "setup: workflow-setup.sh parent create" "code=$SETUP_CODE out=[$SETUP_OUT] err=[$SETUP_ERR]"
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
PARENT=$(get_field "$SETUP_OUT" "WORKTREE: ")
if [ -z "$PARENT" ] || [ ! -d "$PARENT/.artifacts" ]; then
  fail "setup: parent worktree has a run dir" "out=[$SETUP_OUT]"
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi

run_setup "$REPO" "$HOME_DIR" --name l6e2e-l1 --type bug --parent bug/l6e2e
if [ "$SETUP_CODE" -ne 0 ]; then
  fail "setup: workflow-setup.sh lane child create" "code=$SETUP_CODE out=[$SETUP_OUT] err=[$SETUP_ERR]"
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
LANE=$(get_field "$SETUP_OUT" "WORKTREE: ")
if [ -z "$LANE" ]; then
  fail "setup: lane child worktree created" "out=[$SETUP_OUT]"
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi

# Confirm the topology is what production actually uses: PARENT is a LINKED
# worktree (git-dir != git-common-dir), never a standalone main checkout --
# if this assumption is wrong, defect 1's fix would not even engage, and
# every later "still denied" assertion below would be meaningless.
PARENT_GD=$(git -C "$PARENT" rev-parse --path-format=absolute --git-dir 2>/dev/null)
PARENT_GCD=$(git -C "$PARENT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
if [ "$PARENT_GD" = "$PARENT_GCD" ]; then
  fail "setup: parent worktree is a LINKED worktree (git-dir != git-common-dir)" "gd=[$PARENT_GD] gcd=[$PARENT_GCD]"
else
  pass "setup: parent worktree is confirmed a real linked worktree, not a main checkout"
fi

# ---------------------------------------------------------------------------
# Case 01: orchestrator (default marker) -> product write in the PARENT
# denied. Phase 10.1's first of three outcomes.
# ---------------------------------------------------------------------------
case01() {
  local label="01: orchestrator role -> product write in parent denied"
  run_scope_writes "$(write_payload "$PARENT/src/app.js")"
  if [ "$SW_CODE" -ne 2 ]; then
    fail "$label" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
    return
  fi
  pass "$label"
}
case01

# ---------------------------------------------------------------------------
# Case 02: builder role, structurally derived in the REAL lane child (never
# read from any marker file there) -> product write in the LANE allowed.
# Second of the three outcomes.
# ---------------------------------------------------------------------------
case02() {
  local label="02: builder role (real lane child) -> product write in lane allowed"
  run_scope_writes "$(write_payload "$LANE/src/lane-written.js")"
  if [ "$SW_CODE" -ne 0 ]; then
    fail "$label" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
    return
  fi
  pass "$label"
}
case02

# ---------------------------------------------------------------------------
# Case 03: legitimate role flip (planner) via the REAL --set-role CLI ->
# product write in the parent still denied (planner's scope is plans-root
# only), a plans-root write allowed. Third of the three outcomes, and
# confirms the DP-1 mechanism this lane wires (defect 2) actually round-trips
# through the real script.
# ---------------------------------------------------------------------------
case03() {
  local label="03: --set-role planner (real CLI) -> plans write allowed, product write denied"
  local out
  out=$("$WORKFLOW_SETUP" --set-role planner --root "$PARENT" 2>&1)
  if [ $? -ne 0 ]; then
    fail "$label (prereq: --set-role planner)" "out=[$out]"
    return
  fi
  run_scope_writes "$(write_payload "$PARENT/src/app.js")"
  if [ "$SW_CODE" -ne 2 ]; then
    fail "$label -> product write still denied" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
  else
    pass "$label -> product write still denied"
  fi
  mkdir -p "$PARENT/project-plans"
  run_scope_writes "$(write_payload "$PARENT/project-plans/some-plan.md")"
  if [ "$SW_CODE" -ne 0 ]; then
    fail "$label -> plans-root write allowed" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
  else
    pass "$label -> plans-root write allowed"
  fi
  # Restore, per the DP-1 bracket obligation this lane wires into the docs.
  "$WORKFLOW_SETUP" --set-role orchestrator --root "$PARENT" >/dev/null 2>&1
}
case03

# ---------------------------------------------------------------------------
# Case 04: THE reproduction. Code-review round 1's blocking finding #1,
# performed end-to-end against the real parent worktree with the real hooks.
# ---------------------------------------------------------------------------
case04() {
  local label="04: code-review r1 escalation, real worktree"

  # Baseline: role is orchestrator (restored at the end of case03); confirm
  # clean git status so we know any denial below is not an artifact of some
  # stray change.
  local status_before
  status_before=$(git -C "$PARENT" status --porcelain 2>/dev/null)
  if [ -n "$status_before" ]; then
    fail "$label (prereq: clean git status before tamper)" "status=[$status_before]"
    return
  fi
  pass "$label -> git status clean before the tamper (prereq)"

  # THE tamper: the exact Bash write the code review used to defeat the
  # marker. No hook, no script -- a bare redirect.
  printf 'builder' >"$PARENT/.artifacts/dae-role"

  # git status must STILL be clean -- .artifacts/ is gitignored, so this is
  # structurally invisible to a git-status-based check, which is precisely
  # why parent-tree-guard.sh needed its own dedicated tamper check rather
  # than relying on the offender scan alone.
  local status_after
  status_after=$(git -C "$PARENT" status --porcelain 2>/dev/null)
  if [ -n "$status_after" ]; then
    fail "$label (prereq: git status still clean after the marker tamper)" "status=[$status_after]"
  else
    pass "$label -> git status still clean after the marker tamper (proves it's gitignore-invisible)"
  fi

  # (a) parent-tree-guard.sh must catch this on its very next PostToolUse
  # pass, independent of git status.
  run_guard "$PARENT"
  if [ "$PTG_CODE" -ne 2 ]; then
    fail "$label -> parent-tree-guard.sh denies the tampered marker" "code=$PTG_CODE out=[$PTG_OUT] err=[$PTG_ERR]"
  elif ! printf '%s\n' "$PTG_ERR" | grep -qi "builder"; then
    fail "$label -> parent-tree-guard.sh stderr names the forged token" "err=[$PTG_ERR]"
  else
    pass "$label -> parent-tree-guard.sh denies the tampered marker (tamper detection), stderr names it"
  fi

  # (b) the actual escalation: does the forged marker grant a product write
  # via scope-writes.sh? Must still be DENIED.
  run_scope_writes "$(write_payload "$PARENT/src/app.js")"
  if [ "$SW_CODE" -ne 2 ]; then
    fail "$label -> scope-writes.sh still denies the product write (the escalation itself)" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
  else
    pass "$label -> scope-writes.sh still denies the product write (the escalation itself)"
  fi

  # Recovery: restore the marker so later cases aren't affected.
  printf 'orchestrator\n' >"$PARENT/.artifacts/dae-role"
}
case04

# ---------------------------------------------------------------------------
# Case 05: the real lane child is unaffected by any of the above -- builder
# there is structurally derived (find_lane_root), never read from a marker,
# so nothing that happened to the parent's marker file touches it.
# ---------------------------------------------------------------------------
case05() {
  local label="05: real lane child unaffected -> product write in lane still allowed"
  run_scope_writes "$(write_payload "$LANE/src/lane-written-2.js")"
  if [ "$SW_CODE" -ne 0 ]; then
    fail "$label" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
    return
  fi
  pass "$label"
}
case05

# ---------------------------------------------------------------------------
# Case 06: coordinator-found follow-on gap. Forging the marker to `builder`
# in the parent is correctly refused (case04 already proves the product
# write stays denied) -- but the REJECTED role must not fall back to the
# OLD permissive plans+docs roots either. Assert both are now denied too.
# ---------------------------------------------------------------------------
case06() {
  local label="06: forged 'builder' in parent -> plans root AND docs root also denied"
  printf 'builder' >"$PARENT/.artifacts/dae-role"

  run_scope_writes "$(write_payload "$PARENT/project-plans/plan.md")"
  if [ "$SW_CODE" -ne 2 ]; then
    fail "$label -> plans root denied" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
  else
    pass "$label -> plans root denied"
  fi

  run_scope_writes "$(write_payload "$PARENT/docs/readme.md")"
  if [ "$SW_CODE" -ne 2 ]; then
    fail "$label -> docs root denied" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
  else
    pass "$label -> docs root denied"
  fi

  printf 'orchestrator\n' >"$PARENT/.artifacts/dae-role"
}
case06

# ---------------------------------------------------------------------------
# Case 07: same gap, plain garbage token instead of the specific 'builder'
# rejection -- garbage must not behave any differently.
# ---------------------------------------------------------------------------
case07() {
  local label="07: garbage token in parent -> plans root AND docs root also denied"
  printf 'xyz-garbage' >"$PARENT/.artifacts/dae-role"

  run_scope_writes "$(write_payload "$PARENT/project-plans/plan.md")"
  if [ "$SW_CODE" -ne 2 ]; then
    fail "$label -> plans root denied" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
  else
    pass "$label -> plans root denied"
  fi

  run_scope_writes "$(write_payload "$PARENT/docs/readme.md")"
  if [ "$SW_CODE" -ne 2 ]; then
    fail "$label -> docs root denied" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
  else
    pass "$label -> docs root denied"
  fi

  printf 'orchestrator\n' >"$PARENT/.artifacts/dae-role"
}
case07

# ---------------------------------------------------------------------------
# Case 08: positive control. A GENUINE planner token (set via the real
# --set-role CLI, not forged from a rejected state) still grants the plans
# root -- proving case06/07 closed the FORGED/garbage path into the plans
# root, not the plans root itself. Docs and product stay denied throughout
# (matches the coordinator's own drill: "planner: 2 0 2").
# ---------------------------------------------------------------------------
case08() {
  local label="08: genuine planner token -> plans allowed, docs+product denied (positive control)"
  local out
  out=$("$WORKFLOW_SETUP" --set-role planner --root "$PARENT" 2>&1)
  if [ $? -ne 0 ]; then
    fail "$label (prereq: --set-role planner)" "out=[$out]"
    return
  fi

  run_scope_writes "$(write_payload "$PARENT/src/app.js")"
  if [ "$SW_CODE" -ne 2 ]; then
    fail "$label -> product still denied" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
  else
    pass "$label -> product still denied"
  fi

  run_scope_writes "$(write_payload "$PARENT/docs/readme.md")"
  if [ "$SW_CODE" -ne 2 ]; then
    fail "$label -> docs still denied" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
  else
    pass "$label -> docs still denied"
  fi

  run_scope_writes "$(write_payload "$PARENT/project-plans/plan.md")"
  if [ "$SW_CODE" -ne 0 ]; then
    fail "$label -> plans root allowed (real planner reaches it)" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
  else
    pass "$label -> plans root allowed (real planner reaches it)"
  fi

  "$WORKFLOW_SETUP" --set-role orchestrator --root "$PARENT" >/dev/null 2>&1
}
case08

# ---------------------------------------------------------------------------
# Case 09: re-confirmation. A FULLY UNMARKED tree (no .artifacts/progress-
# log.md anywhere in its ancestry) must remain completely permissive,
# unconditionally -- a totally different code path from cases 06-08 (it
# exits 0 before resolve_role is ever called), and this addendum must not
# regress it into anything fail-closed.
# ---------------------------------------------------------------------------
case09() {
  local label="09: fully unmarked tree -> still fully permissive, unconditionally (fail-open re-check)"
  local unmarked
  unmarked=$(new_scratch)
  mkdir -p "$unmarked/src" "$unmarked/project-plans" "$unmarked/docs"
  for t in src/app.js project-plans/plan.md docs/readme.md; do
    run_scope_writes "$(write_payload "$unmarked/$t")"
    if [ "$SW_CODE" -ne 0 ]; then
      fail "$label -> $t allowed" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
    else
      pass "$label -> $t allowed"
    fi
  done
}
case09

# ---------------------------------------------------------------------------
# Cases 10-12: the coordinator's SECOND follow-on finding. A marked root
# whose role is unresolved now depends on git topology: a LINKED worktree
# parent still falls back to `orchestrator` (cases 06/07 above, unchanged);
# the MAIN CHECKOUT (no linked worktree -- a `--worktree none` run, or a
# `ship: chat` scratch marker) now falls back to `scratch`: allowed under
# that marked root, nowhere else. Verified here against the REAL
# resolve-scratch.sh tool (not a hand-rolled fixture), since that is the
# actual, real mechanism this closes a regression against.
# ---------------------------------------------------------------------------
RESOLVE_SCRATCH="$REPO_ROOT/agent-agnostic/hooks/resolve-scratch.sh"

# Case 10: a real chat-run scratch marker, made via the real resolve-scratch.sh
# CLI in a fresh throwaway repo (never a linked worktree) -- its own report
# write is allowed.
case10() {
  local label="10: real chat-run scratch marker (resolve-scratch.sh) -> its own report write allowed"
  local repo out scratchdir report_target
  repo=$(new_scratch)
  git init -q -b main "$repo" || { fail "$label (prereq: git init)" "could not init fixture repo"; return; }
  git -C "$repo" config user.email t@t.com
  git -C "$repo" config user.name T
  git -C "$repo" commit -q --allow-empty -m init || { fail "$label (prereq: initial commit)" "commit failed"; return; }

  out=$(cd "$repo" && "$RESOLVE_SCRATCH" --slug case10-scratch 2>&1)
  if [ $? -ne 0 ]; then
    fail "$label (prereq: resolve-scratch.sh)" "out=[$out]"
    return
  fi
  scratchdir=$(get_field "$out" "SCRATCHDIR: ")
  if [ -z "$scratchdir" ] || [ ! -d "$scratchdir" ]; then
    fail "$label (prereq: scratchdir resolved)" "out=[$out]"
    return
  fi
  if [ -f "$repo/.artifacts/dae-role" ]; then
    fail "$label (prereq: resolve-scratch.sh never writes dae-role)" "dae-role unexpectedly present"
    return
  fi
  pass "$label -> prereqs (scratchdir resolved, no dae-role written)"

  report_target="$scratchdir/report.md"
  run_scope_writes "$(write_payload "$report_target")"
  if [ "$SW_CODE" -ne 0 ]; then
    fail "$label -> report write allowed" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
    return
  fi
  pass "$label -> report write allowed"
}
case10

# Case 11: the scratch allowance from case10's fixture must not leak into a
# SEPARATE, unrelated fixture -- that one is governed entirely by its own
# marker state (here, a genuine orchestrator-marked main-checkout root; a
# product write there stays denied, exactly as case01 already proves for
# the ordinary parent-worktree case, done again here on an INDEPENDENT
# main-checkout fixture to show scratch's allowance is per-root, not global).
case11() {
  local label="11: scratch allowance does not leak into a separate, unrelated marked root"
  local repo
  repo=$(new_scratch)
  git init -q -b main "$repo" || { fail "$label (prereq: git init)" "could not init fixture repo"; return; }
  git -C "$repo" config user.email t@t.com
  git -C "$repo" config user.name T
  mkdir -p "$repo/src"
  printf 'x\n' >"$repo/src/app.js"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m init || { fail "$label (prereq: initial commit)" "commit failed"; return; }
  mkdir -p "$repo/.artifacts"
  echo x >"$repo/.artifacts/progress-log.md"
  printf 'orchestrator\n' >"$repo/.artifacts/dae-role"

  run_scope_writes "$(write_payload "$repo/src/app.js")"
  if [ "$SW_CODE" -ne 2 ]; then
    fail "$label -> unrelated fixture's own (orchestrator) rule still applies, product denied" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
    return
  fi
  pass "$label -> unrelated fixture's own (orchestrator) rule still applies, product denied"
}
case11

# Case 12: THE case the coordinator called "the one that matters most" --
# forging the literal string 'scratch' into a REAL LINKED WORKTREE parent's
# marker must NOT be honored (scratch is a computed value, never read from
# the file); the product write must stay denied, same as forging 'builder'
# (case06) or garbage (case07) already proved.
# ---------------------------------------------------------------------------
case12() {
  local label="12: forged 'scratch' in a real linked-worktree parent -> still denied (matters most)"
  printf 'scratch' >"$PARENT/.artifacts/dae-role"

  run_scope_writes "$(write_payload "$PARENT/src/app.js")"
  if [ "$SW_CODE" -ne 2 ]; then
    fail "$label -> product write denied" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
  else
    pass "$label -> product write denied"
  fi

  run_scope_writes "$(write_payload "$PARENT/project-plans/plan.md")"
  if [ "$SW_CODE" -ne 2 ]; then
    fail "$label -> plans root also denied (not treated as scratch's own root)" "code=$SW_CODE out=[$SW_OUT] err=[$SW_ERR]"
  else
    pass "$label -> plans root also denied (not treated as scratch's own root)"
  fi

  # parent-tree-guard.sh's dedicated proactive tamper check (A2) is scoped
  # specifically to a forged 'builder' claim -- 'scratch' is just another
  # garbage raw value to it (never matched as a literal case pattern, only
  # ever produced as resolve_role's OUTPUT), so it is caught the same way
  # Packet D's garbage-token cases are: via the ordinary git-status offender
  # scan, once there is an actual product change for it to classify under
  # the role it resolved to (orchestrator, since this is a linked worktree).
  printf 'echo tampered\n' >"$PARENT/src/app.js"
  run_guard "$PARENT"
  if [ "$PTG_CODE" -ne 2 ]; then
    fail "$label -> parent-tree-guard.sh denies the product change under the resolved (orchestrator) role" "code=$PTG_CODE out=[$PTG_OUT] err=[$PTG_ERR]"
  else
    pass "$label -> parent-tree-guard.sh denies the product change under the resolved (orchestrator) role"
  fi
  git -C "$PARENT" checkout -q -- src/app.js 2>/dev/null || printf 'x\n' >"$PARENT/src/app.js"

  printf 'orchestrator\n' >"$PARENT/.artifacts/dae-role"
}
case12

echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ]
