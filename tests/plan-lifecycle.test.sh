#!/usr/bin/env bash
# plan-lifecycle.test.sh
#
# SYNOPSIS
#   bash tests/plan-lifecycle.test.sh
#
# DESCRIPTION
#   Blind contract test for orchestrators/hooks/plan-lifecycle.sh, written from
#   the contract text alone (contracts/l2.md, Packet 1 + Packet 1t). Builds a
#   throwaway git-tracked fixture tree under mktemp, exercises every
#   subcommand's guards and success paths, and asserts on exit codes,
#   stdout/stderr contents, and filesystem/git state. Never reads the script
#   under test's source.
#
# EXIT CODES
#   0  every case passed
#   1  at least one case failed (or the bash -n sanity precondition failed)
#
# Runnable with no arguments from any working directory.

set -uo pipefail

# ---------------------------------------------------------------------------
# Locate the script under test relative to this file's own location.
# ---------------------------------------------------------------------------
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/orchestrators/hooks/plan-lifecycle.sh"

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

# run_script <args...> -- invokes $SCRIPT, sets globals OUT / ERR / CODE.
OUT=""
ERR=""
CODE=0
run_script() {
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  "$SCRIPT" "$@" >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# tree_fingerprint <dir> -- structure + content fingerprint for dry-run checks.
tree_fingerprint() {
  local dir="$1"
  { find "$dir" -mindepth 1 | LC_ALL=C sort; find "$dir" -type f -exec md5sum {} \; | LC_ALL=C sort; } | md5sum | awk '{print $1}'
}

new_scratch() {
  local d
  d=$(mktemp -d)
  SCRATCH_DIRS+=("$d")
  printf '%s' "$d"
}

# ---------------------------------------------------------------------------
# Fixture builders
# ---------------------------------------------------------------------------

# build_full_fixture <dir> -- the required fixture tree from the contract,
# git-init'd and committed so git mv/git rm are exercised for real.
build_full_fixture() {
  local dir="$1" pd
  pd="$dir/project-plans"
  mkdir -p "$pd/proposals" "$pd/completed"

  # promote-a + sibling
  cat >"$pd/proposals/promote-a-01-01-26.md" <<'EOF'
# Promote A Plan

## Phase syllabus
- [ ] Phase 1: Something
  - [ ] 1.1: First subphase
EOF
  cat >"$pd/proposals/promote-a-01-01-26.plan-review.md" <<'EOF'
# Plan review for Promote A

verdict: tentative
next: proceed

Some review text.
EOF

  # complete-b: all subphases checked
  mkdir -p "$pd/complete-b-01-01-26"
  cat >"$pd/complete-b-01-01-26/plan.md" <<'EOF'
# Complete B Plan

## Phase syllabus
- [x] Phase 1: Something
  - [x] 1.1: First subphase
  - [done] 1.2: Second subphase

## Phase 1: Something
Detail text.
EOF

  # incomplete-c: one unchecked subphase
  mkdir -p "$pd/incomplete-c-01-01-26"
  cat >"$pd/incomplete-c-01-01-26/plan.md" <<'EOF'
# Incomplete C Plan

## Phase syllabus
- [ ] Phase 1: Something
  - [x] 1.1: First subphase
  - [ ] 1.2: Second subphase

## Phase 1: Something
Detail text.
EOF

  # alldropped-d: every subphase dropped, zero shipped
  mkdir -p "$pd/alldropped-d-01-01-26"
  cat >"$pd/alldropped-d-01-01-26/plan.md" <<'EOF'
# All Dropped D Plan

## Phase syllabus
- [dropped] Phase 1: Something
  - [dropped] 1.1: First subphase
  - [dropped] 1.2: Second subphase

## Phase 1: Something
Detail text.
EOF

  # alldropped-with-one-e: same shape, one [x] among the drops
  mkdir -p "$pd/alldropped-with-one-e-01-01-26"
  cat >"$pd/alldropped-with-one-e-01-01-26/plan.md" <<'EOF'
# All Dropped With One E Plan

## Phase syllabus
- [dropped] Phase 1: Something
  - [dropped] 1.1: First subphase
  - [x] 1.2: Second subphase
  - [dropped] 1.3: Third subphase

## Phase 1: Something
Detail text.
EOF

  # diagnose-f: no syllabus checkbox lines at all
  mkdir -p "$pd/diagnose-f-01-01-26"
  cat >"$pd/diagnose-f-01-01-26/plan.md" <<'EOF'
# Diagnose F Report

## Findings
Prose only, no syllabus checkboxes here. This is a diagnose-shaped report.
EOF

  # completed/archived-g: pre-existing archived plan
  cat >"$pd/completed/archived-g-01-01-26.md" <<'EOF'
# Archived G Plan

## Phase syllabus
- [x] Phase 1: Something
  - [x] 1.1: First subphase

## Phase 1: Something
Detail text.
EOF

  # successor-names-h: mentions superseded-i-01-01-26
  cat >"$pd/proposals/successor-names-h-01-01-26.md" <<'EOF'
# Successor Names H

This plan supersedes superseded-i-01-01-26 with a new approach.
EOF

  # successor-silent-j: mentions no plan-id at all
  cat >"$pd/proposals/successor-silent-j-01-01-26.md" <<'EOF'
# Successor Silent J

This document does not mention any prior plan by name.
EOF

  # supersede targets
  cat >"$pd/proposals/superseded-i-01-01-26.md" <<'EOF'
# Superseded I Plan

This proposal is being superseded.
EOF
  cat >"$pd/proposals/superseded-k-01-01-26.md" <<'EOF'
# Superseded K Plan

This proposal's successor never names it.
EOF

  # layout violation #1: loose file at plans-dir root
  cat >"$pd/stray-notes.md" <<'EOF'
Stray notes that should not be here.
EOF

  # layout violation #2: plan-id-shaped dir with an unrecognized extra file
  mkdir -p "$pd/stray-plan-l-01-01-26"
  cat >"$pd/stray-plan-l-01-01-26/plan.md" <<'EOF'
# Stray Plan L

Just a plan.
EOF
  cat >"$pd/stray-plan-l-01-01-26/notes.txt" <<'EOF'
Unexpected extra file that does not belong in a plan dir.
EOF

  git -C "$dir" init -q
  git -C "$dir" config user.email "plan-lifecycle-test@example.com"
  git -C "$dir" config user.name "plan-lifecycle-test"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m fixture
}

# build_legacy_fixture <dir> -- flat legacy layout, no proposals/completed.
build_legacy_fixture() {
  local dir="$1" pd
  pd="$dir/project-plans"
  mkdir -p "$pd"
  cat >"$pd/legacy-a-01-01-26.md" <<'EOF'
# Legacy A Plan (flat layout)
EOF
  cat >"$pd/legacy-b-02-02-26.md" <<'EOF'
# Legacy B Plan (flat layout)
EOF
}

# build_clean_fixture <dir> -- fully conformant tree.
build_clean_fixture() {
  local dir="$1" pd
  pd="$dir/project-plans"
  mkdir -p "$pd/proposals" "$pd/completed" "$pd/good-plan-01-01-26"
  cat >"$pd/good-plan-01-01-26/plan.md" <<'EOF'
# Good Plan

## Phase syllabus
- [x] Phase 1: Something
  - [x] 1.1: First subphase

## Phase 1: Something
Detail text.
EOF
}

# build_dupe_fixture <dir> -- same plan-id present in both proposals/ and
# completed/ simultaneously (plan AC5, third layout-violation scenario).
build_dupe_fixture() {
  local dir="$1" pd
  pd="$dir/project-plans"
  mkdir -p "$pd/proposals" "$pd/completed"
  cat >"$pd/proposals/dupe-a-01-01-26.md" <<'EOF'
# Dupe A Plan (proposals copy)
EOF
  cat >"$pd/completed/dupe-a-01-01-26.md" <<'EOF'
# Dupe A Plan (completed copy)
EOF
}

# ---------------------------------------------------------------------------
# Case 1: bash -n sanity precondition
# ---------------------------------------------------------------------------
if bash -n "$SCRIPT" 2>/tmp/plan-lifecycle-syntax-err.$$; then
  pass "01: bash -n \$SCRIPT exits 0 (AC1)"
else
  syntax_err=$(cat /tmp/plan-lifecycle-syntax-err.$$ 2>/dev/null)
  rm -f /tmp/plan-lifecycle-syntax-err.$$
  fail "01: bash -n \$SCRIPT exits 0 (AC1)" "syntax error: $syntax_err"
  echo "01 failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
rm -f /tmp/plan-lifecycle-syntax-err.$$

# ---------------------------------------------------------------------------
# Main fixture tree: cases 2-14 run sequentially against the same tree,
# each case depending only on state left behind by the ones before it.
# ---------------------------------------------------------------------------
scratch=$(new_scratch)
plans_dir="$scratch/project-plans"
build_full_fixture "$scratch"

common_flags=(--root "$scratch" --plans-dir "$plans_dir")

# --- Case 02: promote with a .plan-review.md sibling (AC4) -----------------
run_script promote "$plans_dir/proposals/promote-a-01-01-26.md" "${common_flags[@]}"
expected_out="$plans_dir/promote-a-01-01-26/plan.md"
if [ "$CODE" -eq 0 ] \
   && [ "$OUT" = "$expected_out" ] \
   && [ -f "$plans_dir/promote-a-01-01-26/plan.md" ] \
   && [ -f "$plans_dir/promote-a-01-01-26/plan-review.md" ] \
   && [ ! -e "$plans_dir/proposals/promote-a-01-01-26.md" ] \
   && [ ! -e "$plans_dir/proposals/promote-a-01-01-26.plan-review.md" ]; then
  pass "02: promote with plan-review sibling moves both, prints exact path (AC4)"
else
  fail "02: promote with plan-review sibling moves both, prints exact path (AC4)" \
    "code=$CODE out=[$OUT] expected_out=[$expected_out] err=[$ERR]"
fi

# --- Case 03: promote again on the now-consumed source (guard) -------------
run_script promote "$plans_dir/proposals/promote-a-01-01-26.md" "${common_flags[@]}"
if [ "$CODE" -ne 0 ]; then
  pass "03: promote on an already-consumed source exits nonzero"
else
  fail "03: promote on an already-consumed source exits nonzero" "code=$CODE out=[$OUT]"
fi

# --- Case 04: archive a fully-shipped plan (AC1 baseline) ------------------
run_script archive "$plans_dir/complete-b-01-01-26" "${common_flags[@]}"
if [ "$CODE" -eq 0 ] \
   && [ -f "$plans_dir/completed/complete-b-01-01-26.md" ] \
   && [ ! -e "$plans_dir/complete-b-01-01-26" ]; then
  pass "04: archive a fully-shipped plan succeeds and moves plan.md to completed/"
else
  fail "04: archive a fully-shipped plan succeeds and moves plan.md to completed/" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# --- Case 05: archive refuses an unfinished plan (AC2) ----------------------
before_sum=$(md5sum "$plans_dir/incomplete-c-01-01-26/plan.md" | awk '{print $1}')
run_script archive "$plans_dir/incomplete-c-01-01-26" "${common_flags[@]}"
after_ok=0
if [ -f "$plans_dir/incomplete-c-01-01-26/plan.md" ]; then
  after_sum=$(md5sum "$plans_dir/incomplete-c-01-01-26/plan.md" | awk '{print $1}')
  [ "$before_sum" = "$after_sum" ] && after_ok=1
fi
if [ "$CODE" -ne 0 ] && printf '%s' "$ERR" | grep -q 'supersede' && [ "$after_ok" -eq 1 ]; then
  pass "05: archive refuses an unfinished plan, stderr names supersede, dir unchanged (AC2)"
else
  fail "05: archive refuses an unfinished plan, stderr names supersede, dir unchanged (AC2)" \
    "code=$CODE err=[$ERR] after_ok=$after_ok"
fi

# --- Case 06: archive refuses an all-dropped plan (AC2b, first half) -------
before_sum=$(md5sum "$plans_dir/alldropped-d-01-01-26/plan.md" | awk '{print $1}')
run_script archive "$plans_dir/alldropped-d-01-01-26" "${common_flags[@]}"
after_ok=0
if [ -f "$plans_dir/alldropped-d-01-01-26/plan.md" ]; then
  after_sum=$(md5sum "$plans_dir/alldropped-d-01-01-26/plan.md" | awk '{print $1}')
  [ "$before_sum" = "$after_sum" ] && after_ok=1
fi
if [ "$CODE" -ne 0 ] && printf '%s' "$ERR" | grep -q 'supersede' && [ "$after_ok" -eq 1 ]; then
  pass "06: archive refuses an all-dropped plan, stderr names supersede, dir unchanged (AC2b)"
else
  fail "06: archive refuses an all-dropped plan, stderr names supersede, dir unchanged (AC2b)" \
    "code=$CODE err=[$ERR] after_ok=$after_ok"
fi

# --- Case 07: archive succeeds when one subphase shipped among drops (AC2b, second half) ---
run_script archive "$plans_dir/alldropped-with-one-e-01-01-26" "${common_flags[@]}"
if [ "$CODE" -eq 0 ] && [ -f "$plans_dir/completed/alldropped-with-one-e-01-01-26.md" ]; then
  pass "07: archive succeeds when one subphase shipped among all-dropped plan (AC2b)"
else
  fail "07: archive succeeds when one subphase shipped among all-dropped plan (AC2b)" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# --- Case 08: --force-incomplete bypasses the completeness guard (AC3) -----
reason="known gap, ok to ship without X"
run_script archive "$plans_dir/incomplete-c-01-01-26" --force-incomplete "$reason" "${common_flags[@]}"
second_line=""
if [ -f "$plans_dir/completed/incomplete-c-01-01-26.md" ]; then
  second_line=$(sed -n '2p' "$plans_dir/completed/incomplete-c-01-01-26.md")
fi
if [ "$CODE" -eq 0 ] \
   && [ -f "$plans_dir/completed/incomplete-c-01-01-26.md" ] \
   && [ "$second_line" = "> Archived incomplete: $reason" ]; then
  pass "08: archive --force-incomplete succeeds, second line records the reason verbatim (AC3)"
else
  fail "08: archive --force-incomplete succeeds, second line records the reason verbatim (AC3)" \
    "code=$CODE second_line=[$second_line] err=[$ERR]"
fi

# --- Case 09: archive a diagnose-shaped plan with no syllabus lines --------
run_script archive "$plans_dir/diagnose-f-01-01-26" "${common_flags[@]}"
if [ "$CODE" -eq 0 ] && [ -f "$plans_dir/completed/diagnose-f-01-01-26.md" ]; then
  pass "09: archive a diagnose-shaped plan (no syllabus lines) skips completeness guard, succeeds"
else
  fail "09: archive a diagnose-shaped plan (no syllabus lines) skips completeness guard, succeeds" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# --- Case 10: supersede succeeds when successor names the plan-id (AC4b) ---
run_script supersede "$plans_dir/proposals/superseded-i-01-01-26.md" --by "$plans_dir/proposals/successor-names-h-01-01-26.md" "${common_flags[@]}"
superseded_dir_count=$(find "$scratch" -type d -name 'superseded' | wc -l | tr -d ' ')
if [ "$CODE" -eq 0 ] \
   && [ ! -e "$plans_dir/proposals/superseded-i-01-01-26.md" ] \
   && [ "$superseded_dir_count" -eq 0 ]; then
  pass "10: supersede deletes the target when the successor names its plan-id, no superseded/ dir (AC4b)"
else
  fail "10: supersede deletes the target when the successor names its plan-id, no superseded/ dir (AC4b)" \
    "code=$CODE err=[$ERR] superseded_dir_count=$superseded_dir_count"
fi

# --- Case 11: supersede refuses when the successor never names the plan-id (AC4b) ---
run_script supersede "$plans_dir/proposals/superseded-k-01-01-26.md" --by "$plans_dir/proposals/successor-silent-j-01-01-26.md" "${common_flags[@]}"
if [ "$CODE" -ne 0 ] && [ -f "$plans_dir/proposals/superseded-k-01-01-26.md" ]; then
  pass "11: supersede refuses when the successor never names the target plan-id, target intact (AC4b)"
else
  fail "11: supersede refuses when the successor never names the target plan-id, target intact (AC4b)" \
    "code=$CODE err=[$ERR]"
fi

# --- Case 12: supersede refuses a completed target ---------------------------
run_script supersede "$plans_dir/completed/archived-g-01-01-26.md" --by "$plans_dir/proposals/successor-names-h-01-01-26.md" "${common_flags[@]}"
if [ "$CODE" -ne 0 ] && [ -f "$plans_dir/completed/archived-g-01-01-26.md" ]; then
  pass "12: supersede refuses a target under completed/, file intact"
else
  fail "12: supersede refuses a target under completed/, file intact" \
    "code=$CODE err=[$ERR]"
fi

# --- Case 13: reopen a completed plan -----------------------------------------
run_script reopen "$plans_dir/completed/archived-g-01-01-26.md" "${common_flags[@]}"
if [ "$CODE" -eq 0 ] \
   && [ -f "$plans_dir/archived-g-01-01-26/plan.md" ] \
   && [ ! -e "$plans_dir/completed/archived-g-01-01-26.md" ]; then
  pass "13: reopen moves completed/<slug>.md back to <slug>/plan.md"
else
  fail "13: reopen moves completed/<slug>.md back to <slug>/plan.md" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# --- Case 14: check flags both surviving layout violations (AC5) -----------
run_script check "${common_flags[@]}"
if [ "$CODE" -ne 0 ] \
   && printf '%s\n' "$OUT" | grep '^FAIL:' | grep -q 'stray-notes.md' \
   && printf '%s\n' "$OUT" | grep '^FAIL:' | grep -q 'stray-plan-l-01-01-26' \
   && printf '%s\n' "$OUT" | grep '^FAIL:' | grep -q 'notes.txt'; then
  pass "14: check flags a loose root file and a stray file inside a plan dir (AC5)"
else
  fail "14: check flags a loose root file and a stray file inside a plan dir (AC5)" \
    "code=$CODE out=[$OUT]"
fi

# ---------------------------------------------------------------------------
# Case 15: legacy flat layout -- one FAIL per loose file, no advisory severity (AC5/D5)
# ---------------------------------------------------------------------------
legacy_scratch=$(new_scratch)
legacy_plans_dir="$legacy_scratch/project-plans"
build_legacy_fixture "$legacy_scratch"
run_script check --root "$legacy_scratch" --plans-dir "$legacy_plans_dir"
fail_count=$(printf '%s\n' "$OUT" | grep -c '^FAIL:' || true)
if [ "$CODE" -ne 0 ] && [ "$fail_count" -eq 2 ]; then
  pass "15: check on a flat legacy layout fails with one FAIL per loose file, no advisory severity (AC5/D5)"
else
  fail "15: check on a flat legacy layout fails with one FAIL per loose file, no advisory severity (AC5/D5)" \
    "code=$CODE fail_count=$fail_count out=[$OUT]"
fi

# ---------------------------------------------------------------------------
# Case 16: fully-conformant tree -- exit 0, OK line, zero FAIL lines
# ---------------------------------------------------------------------------
clean_scratch=$(new_scratch)
clean_plans_dir="$clean_scratch/project-plans"
build_clean_fixture "$clean_scratch"
run_script check --root "$clean_scratch" --plans-dir "$clean_plans_dir"
fail_count=$(printf '%s\n' "$OUT" | grep -c '^FAIL:' || true)
ok_count=$(printf '%s\n' "$OUT" | grep -c '^OK:' || true)
if [ "$CODE" -eq 0 ] && [ "$fail_count" -eq 0 ] && [ "$ok_count" -ge 1 ]; then
  pass "16: check on a fully-conformant tree exits 0 with an OK line and zero FAIL lines"
else
  fail "16: check on a fully-conformant tree exits 0 with an OK line and zero FAIL lines" \
    "code=$CODE fail_count=$fail_count ok_count=$ok_count out=[$OUT]"
fi

# ---------------------------------------------------------------------------
# Case 17: --dry-run is a no-op on disk for every mutating subcommand (AC6)
# ---------------------------------------------------------------------------
dryrun_scratch_a=$(new_scratch)
dryrun_plans_dir_a="$dryrun_scratch_a/project-plans"
build_full_fixture "$dryrun_scratch_a"
fp_before=$(tree_fingerprint "$dryrun_plans_dir_a")
run_script promote "$dryrun_plans_dir_a/proposals/promote-a-01-01-26.md" --dry-run --root "$dryrun_scratch_a" --plans-dir "$dryrun_plans_dir_a"
fp_after=$(tree_fingerprint "$dryrun_plans_dir_a")
if [ "$CODE" -eq 0 ] && [ "$fp_before" = "$fp_after" ]; then
  pass "17a: promote --dry-run makes zero filesystem changes, exit 0 (AC6)"
else
  fail "17a: promote --dry-run makes zero filesystem changes, exit 0 (AC6)" \
    "code=$CODE fp_before=$fp_before fp_after=$fp_after out=[$OUT]"
fi

dryrun_scratch_b=$(new_scratch)
dryrun_plans_dir_b="$dryrun_scratch_b/project-plans"
build_full_fixture "$dryrun_scratch_b"
fp_before=$(tree_fingerprint "$dryrun_plans_dir_b")
run_script archive "$dryrun_plans_dir_b/complete-b-01-01-26" --dry-run --root "$dryrun_scratch_b" --plans-dir "$dryrun_plans_dir_b"
fp_after=$(tree_fingerprint "$dryrun_plans_dir_b")
if [ "$CODE" -eq 0 ] && [ "$fp_before" = "$fp_after" ]; then
  pass "17b: archive --dry-run makes zero filesystem changes, exit 0 (AC6)"
else
  fail "17b: archive --dry-run makes zero filesystem changes, exit 0 (AC6)" \
    "code=$CODE fp_before=$fp_before fp_after=$fp_after out=[$OUT]"
fi

# ---------------------------------------------------------------------------
# Case 18: static check -- no --force/-f on git/rm, no git commit/push, no rm -rf (AC7)
# ---------------------------------------------------------------------------
static_hits=$(grep -vE '^\s*#' "$SCRIPT" | grep -vE -- '--force-incomplete' \
  | grep -nE -- '(--force\b)|(\brm -rf\b)|(\bgit +[a-zA-Z-]+ [^#]*-f\b)|(\brm -f\b)|(\bgit commit\b)|(\bgit push\b)' || true)
if [ -z "$static_hits" ]; then
  pass "18: script contains no --force/rm -rf/git commit/git push on an actual git/rm invocation (AC7)"
else
  fail "18: script contains no --force/rm -rf/git commit/git push on an actual git/rm invocation (AC7)" "hits: $static_hits"
fi

# ---------------------------------------------------------------------------
# Case 19: check flags the same plan-id present in both proposals/ and
# completed/ simultaneously, exit nonzero (plan AC5, third scenario)
# ---------------------------------------------------------------------------
dupe_scratch=$(new_scratch)
dupe_plans_dir="$dupe_scratch/project-plans"
build_dupe_fixture "$dupe_scratch"
run_script check --root "$dupe_scratch" --plans-dir "$dupe_plans_dir"
if [ "$CODE" -ne 0 ] \
   && printf '%s\n' "$OUT" | grep '^FAIL:' | grep -q 'dupe-a-01-01-26'; then
  pass "19: check flags the same plan-id in both proposals/ and completed/ (plan AC5)"
else
  fail "19: check flags the same plan-id in both proposals/ and completed/ (plan AC5)" \
    "code=$CODE out=[$OUT]"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
