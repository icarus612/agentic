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

# build_adopt_fixture <dir> -- fixture tree for the `adopt` subcommand
# (contract l5.md, Packet 1t), git-init'd and committed so `explored_at`
# derivation (git log -1 -- <source>) has real history to read.
build_adopt_fixture() {
  local dir="$1" pd
  pd="$dir/project-plans"
  mkdir -p "$pd"

  # gated-src: qualifying gate record -- last round is ready/proceed.
  mkdir -p "$pd/gated-src-01-01-26"
  cat >"$pd/gated-src-01-01-26/plan.md" <<'EOF'
# Gated Src Plan

## Phase syllabus
- [ ] Phase 1: Do the thing
  - [ ] 1.1: First subphase

## Phase 1: Do the thing
Detail text for subphase 1.1.
EOF
  cat >"$pd/gated-src-01-01-26/plan-review.md" <<'EOF'
# Plan review for Gated Src

## Round 1 — 08-01-26

```
verdict: tentative
next: proceed
blocking: 0
non-blocking: 0
```

## Round 2 — 08-02-26

```
verdict: ready
next: proceed
blocking: 0
non-blocking: 0
```
EOF

  # ungated-src: same plan shape, no review record beside it at all.
  mkdir -p "$pd/ungated-src-01-01-26"
  cat >"$pd/ungated-src-01-01-26/plan.md" <<'EOF'
# Ungated Src Plan

## Phase syllabus
- [ ] Phase 1: Do the thing
  - [ ] 1.1: First subphase

## Phase 1: Do the thing
Detail text for subphase 1.1.
EOF

  # rejected-src: a valid (schema-passing) review record whose last round is
  # a rejection -- must NOT count as a qualifying gate approval.
  mkdir -p "$pd/rejected-src-01-01-26"
  cat >"$pd/rejected-src-01-01-26/plan.md" <<'EOF'
# Rejected Src Plan

## Phase syllabus
- [ ] Phase 1: Do the thing
  - [ ] 1.1: First subphase

## Phase 1: Do the thing
Detail text for subphase 1.1.
EOF
  cat >"$pd/rejected-src-01-01-26/plan-review.md" <<'EOF'
# Plan review for Rejected Src

## Round 1 — 08-01-26

```
verdict: rejected
next: impl-wrong
blocking: 1
non-blocking: 0
```

- [blocking] something is fundamentally broken
EOF

  # anchored-src: leading front-matter with an anchors: block (two items)
  # plus one unrelated top-level key, above a plan-format body. No review
  # record beside it -- callers exercising this fixture must pass
  # --assume-gated to get past the gate guard.
  mkdir -p "$pd/anchored-src-01-01-26"
  cat >"$pd/anchored-src-01-01-26/plan.md" <<'EOF'
---
owner: someone-else
anchors:
  - anchor-one
  - anchor-two
---
# Anchored Src Plan

## Phase syllabus
- [ ] Phase 1: Do the thing
  - [ ] 1.1: First subphase

## Phase 1: Do the thing
Detail text for subphase 1.1.
EOF

  git -C "$dir" init -q
  git -C "$dir" config user.email "plan-lifecycle-test@example.com"
  git -C "$dir" config user.name "plan-lifecycle-test"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m "adopt fixture"
}

# build_f2_fixture <dir> -- fixture for the F2 regression (contract l3.md,
# Packet 2): archive on a plan dir where git mv/git rm removes the dir's
# LAST entry before remove_empty_dir runs against it. Two plan dirs, same
# shape (plan.md, all-checked syllabus, plus plan-review.md and
# code-review.md so removal of the last entry is exercised):
#   - f2-tracked-01-01-26   -- created and populated BEFORE the commit, so
#                              all three files are git-tracked and
#                              archive's git mv/git rm path runs for real.
#   - f2-untracked-01-01-26 -- created AFTER the commit, so nothing in it
#                              is tracked and archive falls back to plain
#                              mv/rm instead.
build_f2_fixture() {
  local dir="$1" pd
  pd="$dir/project-plans"
  mkdir -p "$pd/proposals" "$pd/completed"

  # f2-tracked: plan.md + two records, populated before the commit below.
  mkdir -p "$pd/f2-tracked-01-01-26"
  cat >"$pd/f2-tracked-01-01-26/plan.md" <<'EOF'
# F2 Tracked Plan

## Phase syllabus
- [x] Phase 1: Something
  - [x] 1.1: First subphase
  - [done] 1.2: Second subphase

## Phase 1: Something
Detail text.
EOF
  cat >"$pd/f2-tracked-01-01-26/plan-review.md" <<'EOF'
# Plan review for F2 Tracked

Some review text.
EOF
  cat >"$pd/f2-tracked-01-01-26/code-review.md" <<'EOF'
# Code review for F2 Tracked

Some review text.
EOF

  git -C "$dir" init -q
  git -C "$dir" config user.email "plan-lifecycle-test@example.com"
  git -C "$dir" config user.name "plan-lifecycle-test"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m fixture

  # f2-untracked: same shape, populated AFTER the commit -- untracked.
  mkdir -p "$pd/f2-untracked-01-01-26"
  cat >"$pd/f2-untracked-01-01-26/plan.md" <<'EOF'
# F2 Untracked Plan

## Phase syllabus
- [x] Phase 1: Something
  - [x] 1.1: First subphase
  - [done] 1.2: Second subphase

## Phase 1: Something
Detail text.
EOF
  cat >"$pd/f2-untracked-01-01-26/plan-review.md" <<'EOF'
# Plan review for F2 Untracked

Some review text.
EOF
  cat >"$pd/f2-untracked-01-01-26/code-review.md" <<'EOF'
# Code review for F2 Untracked

Some review text.
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
# adopt fixtures: a dedicated scratch tree, git-init'd and committed, shared
# across cases 20-30 (each mutation targets a fresh --as destination so the
# shared state stays legible); cases 31-35 use their own isolated scratch
# trees where the case needs a clean run-dir or a controlled git history.
# ---------------------------------------------------------------------------
adopt_scratch=$(new_scratch)
adopt_plans_dir="$adopt_scratch/project-plans"
adopt_run_dir="$adopt_scratch/.artifacts"
build_adopt_fixture "$adopt_scratch"
mkdir -p "$adopt_run_dir"
adopt_common_flags=(--root "$adopt_scratch" --plans-dir "$adopt_plans_dir")

# baseline md5s of every source plan.md, captured before case 20 runs (A5,
# checked by case 27 after cases 20-26 have all run against this tree).
gated_md5_before=$(md5sum "$adopt_plans_dir/gated-src-01-01-26/plan.md" | awk '{print $1}')
ungated_md5_before=$(md5sum "$adopt_plans_dir/ungated-src-01-01-26/plan.md" | awk '{print $1}')
rejected_md5_before=$(md5sum "$adopt_plans_dir/rejected-src-01-01-26/plan.md" | awk '{print $1}')
anchored_md5_before=$(md5sum "$adopt_plans_dir/anchored-src-01-01-26/plan.md" | awk '{print $1}')

# --- Case 20: adopt a gated source (A2) -------------------------------------
run_script adopt "$adopt_plans_dir/gated-src-01-01-26/plan.md" --run-dir "$adopt_run_dir" "${adopt_common_flags[@]}"
gated_dest_dir="$adopt_plans_dir/gated-src-$(date +%m-%d-%y)"
gated_front=""
[ -f "$gated_dest_dir/plan.md" ] && gated_front=$(sed -n '1,20p' "$gated_dest_dir/plan.md")
if [ "$CODE" -eq 0 ] \
   && [ "$OUT" = "$gated_dest_dir/plan.md" ] \
   && [ -f "$gated_dest_dir/plan.md" ] \
   && printf '%s' "$gated_front" | grep -q 'adopted: true' \
   && printf '%s' "$gated_front" | grep -q 'source_run: gated-src-01-01-26' \
   && printf '%s' "$gated_front" | grep -q 'explored_at:' \
   && printf '%s' "$gated_front" | grep -q 'source_gate_verdict:.*ready' \
   && printf '%s' "$gated_front" | grep -q 'source_gate_verdict:.*plan-review'; then
  pass "20: adopt a gated source succeeds, stdout is exactly the dest path, front matter carries provenance (A2)"
else
  fail "20: adopt a gated source succeeds, stdout is exactly the dest path, front matter carries provenance (A2)" \
    "code=$CODE out=[$OUT] err=[$ERR] expected=[$gated_dest_dir/plan.md] front=[$gated_front]"
fi

# --- Case 21: the adopted body survives (A2) --------------------------------
first_heading=""
[ -f "$gated_dest_dir/plan.md" ] && first_heading=$(grep -m1 -E '^## ' "$gated_dest_dir/plan.md")
if [ "$first_heading" = "## Phase syllabus" ] \
   && grep -qF '1.1: First subphase' "$gated_dest_dir/plan.md" \
   && grep -qF 'Detail text for subphase 1.1.' "$gated_dest_dir/plan.md"; then
  pass "21: adopted body keeps ## Phase syllabus as first heading, subphase detail block verbatim (A2)"
else
  fail "21: adopted body keeps ## Phase syllabus as first heading, subphase detail block verbatim (A2)" \
    "first_heading=[$first_heading]"
fi

# --- Case 22: provenance reaches the progress log (A7) ----------------------
progress_log="$adopt_run_dir/progress-log.md"
if [ -f "$progress_log" ] \
   && grep -q '^## Plan provenance (adopted)$' "$progress_log" \
   && grep -q 'source run: gated-src-01-01-26' "$progress_log" \
   && grep -q 'explored_at:' "$progress_log"; then
  pass "22: progress log carries the plan provenance section naming the source run and explored_at (A7)"
else
  fail "22: progress log carries the plan provenance section naming the source run and explored_at (A7)" \
    "exists=$([ -f "$progress_log" ] && echo yes || echo no) content=[$(cat "$progress_log" 2>/dev/null)]"
fi

# --- Case 23: ungated source refuses (A3) -----------------------------------
ungated_dest_dir="$adopt_plans_dir/ungated-src-$(date +%m-%d-%y)"
run_script adopt "$adopt_plans_dir/ungated-src-01-01-26/plan.md" --run-dir "$adopt_run_dir" "${adopt_common_flags[@]}"
if [ "$CODE" -ne 0 ] \
   && printf '%s' "$ERR" | grep -q 'no recorded gate approval' \
   && printf '%s' "$ERR" | grep -q -- '--assume-gated' \
   && [ ! -e "$ungated_dest_dir" ]; then
  pass "23: adopt of an ungated source refuses, stderr names the confirm, no destination created (A3)"
else
  fail "23: adopt of an ungated source refuses, stderr names the confirm, no destination created (A3)" \
    "code=$CODE err=[$ERR] dest_exists=$([ -e "$ungated_dest_dir" ] && echo yes || echo no)"
fi

# --- Case 24: a rejected record does not count as approval (A3) ------------
rejected_dest_dir="$adopt_plans_dir/rejected-src-$(date +%m-%d-%y)"
run_script adopt "$adopt_plans_dir/rejected-src-01-01-26/plan.md" --run-dir "$adopt_run_dir" "${adopt_common_flags[@]}"
if [ "$CODE" -ne 0 ] \
   && printf '%s' "$ERR" | grep -q 'no recorded gate approval' \
   && printf '%s' "$ERR" | grep -q -- '--assume-gated' \
   && [ ! -e "$rejected_dest_dir" ]; then
  pass "24: a rejected plan-review record does not qualify as approval, same refusal as an ungated source (A3)"
else
  fail "24: a rejected plan-review record does not qualify as approval, same refusal as an ungated source (A3)" \
    "code=$CODE err=[$ERR] dest_exists=$([ -e "$rejected_dest_dir" ] && echo yes || echo no)"
fi

# --- Case 25: --assume-gated unblocks it (A4) -------------------------------
assume_reason="ops approved this out of band"
run_script adopt "$adopt_plans_dir/ungated-src-01-01-26/plan.md" --run-dir "$adopt_run_dir" --assume-gated "$assume_reason" "${adopt_common_flags[@]}"
ungated_front=""
[ -f "$ungated_dest_dir/plan.md" ] && ungated_front=$(sed -n '1,20p' "$ungated_dest_dir/plan.md")
if [ "$CODE" -eq 0 ] \
   && [ -f "$ungated_dest_dir/plan.md" ] \
   && printf '%s' "$ungated_front" | grep -q "source_gate_verdict:.*none-on-record" \
   && printf '%s' "$ungated_front" | grep -qF "$assume_reason"; then
  pass "25: --assume-gated <reason> unblocks adoption, destination records none-on-record and the reason verbatim (A4)"
else
  fail "25: --assume-gated <reason> unblocks adoption, destination records none-on-record and the reason verbatim (A4)" \
    "code=$CODE err=[$ERR] front=[$ungated_front]"
fi

# --- Case 26: --assume-gated with an empty reason ---------------------------
run_script adopt "$adopt_plans_dir/rejected-src-01-01-26/plan.md" --run-dir "$adopt_run_dir" --assume-gated "" "${adopt_common_flags[@]}"
if [ "$CODE" -ne 0 ] \
   && printf '%s' "$ERR" | grep -q 'non-empty reason' \
   && [ ! -e "$rejected_dest_dir" ]; then
  pass "26: --assume-gated with an empty reason is refused, nothing created"
else
  fail "26: --assume-gated with an empty reason is refused, nothing created" \
    "code=$CODE err=[$ERR] dest_exists=$([ -e "$rejected_dest_dir" ] && echo yes || echo no)"
fi

# --- Case 27: source is never moved or mutated across cases 20-26 (A5) -----
gated_md5_after=$(md5sum "$adopt_plans_dir/gated-src-01-01-26/plan.md" | awk '{print $1}')
ungated_md5_after=$(md5sum "$adopt_plans_dir/ungated-src-01-01-26/plan.md" | awk '{print $1}')
rejected_md5_after=$(md5sum "$adopt_plans_dir/rejected-src-01-01-26/plan.md" | awk '{print $1}')
anchored_md5_after=$(md5sum "$adopt_plans_dir/anchored-src-01-01-26/plan.md" | awk '{print $1}')
if [ "$gated_md5_before" = "$gated_md5_after" ] \
   && [ "$ungated_md5_before" = "$ungated_md5_after" ] \
   && [ "$rejected_md5_before" = "$rejected_md5_after" ] \
   && [ "$anchored_md5_before" = "$anchored_md5_after" ] \
   && [ -f "$adopt_plans_dir/gated-src-01-01-26/plan.md" ] \
   && [ -f "$adopt_plans_dir/ungated-src-01-01-26/plan.md" ] \
   && [ -f "$adopt_plans_dir/rejected-src-01-01-26/plan.md" ] \
   && [ -f "$adopt_plans_dir/anchored-src-01-01-26/plan.md" ]; then
  pass "27: source plan.md files are never moved or mutated across cases 20-26 (A5)"
else
  fail "27: source plan.md files are never moved or mutated across cases 20-26 (A5)" \
    "gated=$gated_md5_before/$gated_md5_after ungated=$ungated_md5_before/$ungated_md5_after rejected=$rejected_md5_before/$rejected_md5_after anchored=$anchored_md5_before/$anchored_md5_after"
fi

# --- Case 28: anchors inherited in order (A6) -------------------------------
run_script adopt "$adopt_plans_dir/anchored-src-01-01-26/plan.md" --run-dir "$adopt_run_dir" --assume-gated "no review record for this fixture" --as "anchored-dest-01-01-26" "${adopt_common_flags[@]}"
anchored_dest="$adopt_plans_dir/anchored-dest-01-01-26/plan.md"
anchored_front=""
fence_count=0
if [ -f "$anchored_dest" ]; then
  anchored_front=$(awk 'BEGIN{c=0} /^---$/{c++; print; if (c==2) exit; next} {print}' "$anchored_dest")
  fence_count=$(grep -cE '^---$' "$anchored_dest")
fi
anchor_one_line=$(printf '%s\n' "$anchored_front" | grep -n 'anchor-one' | head -1 | cut -d: -f1)
anchor_two_line=$(printf '%s\n' "$anchored_front" | grep -n 'anchor-two' | head -1 | cut -d: -f1)
if [ "$CODE" -eq 0 ] \
   && [ -n "$anchor_one_line" ] && [ -n "$anchor_two_line" ] \
   && [ "$anchor_one_line" -lt "$anchor_two_line" ] \
   && printf '%s' "$anchored_front" | grep -q 'owner: someone-else' \
   && [ "$fence_count" -eq 2 ]; then
  pass "28: anchors inherited from source front matter in order, unrelated top-level key carried through, one fence pair (A6)"
else
  fail "28: anchors inherited from source front matter in order, unrelated top-level key carried through, one fence pair (A6)" \
    "code=$CODE err=[$ERR] fence_count=$fence_count front=[$anchored_front]"
fi

# --- Case 29: --anchors overrides (A6) --------------------------------------
run_script adopt "$adopt_plans_dir/gated-src-01-01-26/plan.md" --run-dir "$adopt_run_dir" --anchors "a,b" --as "anchors-override-01-01-26" "${adopt_common_flags[@]}"
override_dest="$adopt_plans_dir/anchors-override-01-01-26/plan.md"
override_front=""
[ -f "$override_dest" ] && override_front=$(awk 'BEGIN{c=0} /^---$/{c++; print; if (c==2) exit; next} {print}' "$override_dest")
a_line=$(printf '%s\n' "$override_front" | grep -nE '^[[:space:]]*-[[:space:]]*a[[:space:]]*$' | head -1 | cut -d: -f1)
b_line=$(printf '%s\n' "$override_front" | grep -nE '^[[:space:]]*-[[:space:]]*b[[:space:]]*$' | head -1 | cut -d: -f1)
if [ "$CODE" -eq 0 ] && [ -n "$a_line" ] && [ -n "$b_line" ] && [ "$a_line" -lt "$b_line" ]; then
  pass "29: --anchors a,b overrides a source with no anchors, both present in the order given (A6)"
else
  fail "29: --anchors a,b overrides a source with no anchors, both present in the order given (A6)" \
    "code=$CODE err=[$ERR] front=[$override_front]"
fi

# --- Case 30: no anchors anywhere yields anchors: none (A6) ----------------
run_script adopt "$adopt_plans_dir/gated-src-01-01-26/plan.md" --run-dir "$adopt_run_dir" --as "no-anchors-01-01-26" "${adopt_common_flags[@]}"
none_dest="$adopt_plans_dir/no-anchors-01-01-26/plan.md"
if [ "$CODE" -eq 0 ] && [ -f "$none_dest" ] && grep -qE '^anchors: none$' "$none_dest"; then
  pass "30: no anchors in the source and none passed via --anchors yields the explicit line 'anchors: none' (A6)"
else
  fail "30: no anchors in the source and none passed via --anchors yields the explicit line 'anchors: none' (A6)" \
    "code=$CODE err=[$ERR]"
fi

# --- Case 31: --run-dir is required (usage) ---------------------------------
run_script adopt "$adopt_plans_dir/gated-src-01-01-26/plan.md" --as "no-run-dir-01-01-26" "${adopt_common_flags[@]}"
if [ "$CODE" -ne 0 ] && [ ! -e "$adopt_plans_dir/no-run-dir-01-01-26" ]; then
  pass "31: adopt with no --run-dir exits non-zero and creates nothing"
else
  fail "31: adopt with no --run-dir exits non-zero and creates nothing" \
    "code=$CODE err=[$ERR] dest_exists=$([ -e "$adopt_plans_dir/no-run-dir-01-01-26" ] && echo yes || echo no)"
fi

# --- Case 32: destination collision -----------------------------------------
run_script adopt "$adopt_plans_dir/gated-src-01-01-26/plan.md" --run-dir "$adopt_run_dir" --as "collide-target-01-01-26" "${adopt_common_flags[@]}"
collide_first_code=$CODE
collide_dest="$adopt_plans_dir/collide-target-01-01-26/plan.md"
collide_first_md5=""
[ -f "$collide_dest" ] && collide_first_md5=$(md5sum "$collide_dest" | awk '{print $1}')
run_script adopt "$adopt_plans_dir/gated-src-01-01-26/plan.md" --run-dir "$adopt_run_dir" --as "collide-target-01-01-26" "${adopt_common_flags[@]}"
collide_second_md5=""
[ -f "$collide_dest" ] && collide_second_md5=$(md5sum "$collide_dest" | awk '{print $1}')
if [ "$collide_first_code" -eq 0 ] && [ "$CODE" -ne 0 ] \
   && [ -n "$collide_first_md5" ] && [ "$collide_first_md5" = "$collide_second_md5" ]; then
  pass "32: adopting the same source into an existing --as destination refuses on the second attempt, first destination unchanged"
else
  fail "32: adopting the same source into an existing --as destination refuses on the second attempt, first destination unchanged" \
    "first_code=$collide_first_code code=$CODE first_md5=$collide_first_md5 second_md5=$collide_second_md5 err=[$ERR]"
fi

# --- Case 33: adopt --dry-run makes zero filesystem changes (A8) -----------
dryrun_adopt_scratch=$(new_scratch)
dryrun_adopt_plans_dir="$dryrun_adopt_scratch/project-plans"
dryrun_adopt_run_dir="$dryrun_adopt_scratch/.artifacts"
build_adopt_fixture "$dryrun_adopt_scratch"
mkdir -p "$dryrun_adopt_run_dir"
fp_before=$(tree_fingerprint "$dryrun_adopt_plans_dir")
run_script adopt "$dryrun_adopt_plans_dir/gated-src-01-01-26/plan.md" --run-dir "$dryrun_adopt_run_dir" --dry-run --root "$dryrun_adopt_scratch" --plans-dir "$dryrun_adopt_plans_dir"
fp_after=$(tree_fingerprint "$dryrun_adopt_plans_dir")
if [ "$CODE" -eq 0 ] && [ "$fp_before" = "$fp_after" ] && [ ! -f "$dryrun_adopt_run_dir/progress-log.md" ]; then
  pass "33: adopt --dry-run makes zero filesystem changes, creates no progress log, exit 0 (A8)"
else
  fail "33: adopt --dry-run makes zero filesystem changes, creates no progress log, exit 0 (A8)" \
    "code=$CODE fp_before=$fp_before fp_after=$fp_after out=[$OUT] err=[$ERR]"
fi

# --- Case 34: provenance section is replaced, not appended (A7) ------------
replace_scratch=$(new_scratch)
replace_plans_dir="$replace_scratch/project-plans"
replace_run_dir="$replace_scratch/.artifacts"
build_adopt_fixture "$replace_scratch"
mkdir -p "$replace_run_dir"
run_script adopt "$replace_plans_dir/gated-src-01-01-26/plan.md" --run-dir "$replace_run_dir" --as "replace-first-01-01-26" --root "$replace_scratch" --plans-dir "$replace_plans_dir"
replace_first_code=$CODE
run_script adopt "$replace_plans_dir/ungated-src-01-01-26/plan.md" --run-dir "$replace_run_dir" --as "replace-second-01-01-26" --assume-gated "second adopt for replace test" --root "$replace_scratch" --plans-dir "$replace_plans_dir"
replace_heading_count=0
[ -f "$replace_run_dir/progress-log.md" ] && replace_heading_count=$(grep -cE '^## Plan provenance \(adopted\)$' "$replace_run_dir/progress-log.md" || true)
if [ "$replace_first_code" -eq 0 ] && [ "$CODE" -eq 0 ] \
   && [ "$replace_heading_count" -eq 1 ] \
   && grep -q 'source run: ungated-src-01-01-26' "$replace_run_dir/progress-log.md"; then
  pass "34: two successive adopts (different --as) against the same --run-dir leave exactly one provenance heading (A7)"
else
  fail "34: two successive adopts (different --as) against the same --run-dir leave exactly one provenance heading (A7)" \
    "first_code=$replace_first_code code=$CODE heading_count=$replace_heading_count err=[$ERR]"
fi

# --- Case 35: changed-file recording ----------------------------------------
changed_scratch=$(new_scratch)
changed_plans_dir="$changed_scratch/project-plans"
changed_run_dir="$changed_scratch/.artifacts"
build_adopt_fixture "$changed_scratch"
mkdir -p "$changed_run_dir"
echo "post-adoption-source change" >"$changed_scratch/extra-tracked-file.txt"
git -C "$changed_scratch" add -A
git -C "$changed_scratch" commit -q -m "advance history past the source's own commit"
run_script adopt "$changed_plans_dir/gated-src-01-01-26/plan.md" --run-dir "$changed_run_dir" --root "$changed_scratch" --plans-dir "$changed_plans_dir"
changed_line=""
[ -f "$changed_run_dir/progress-log.md" ] && changed_line=$(grep -E '^- changed since explored_at:' "$changed_run_dir/progress-log.md" || true)
if [ "$CODE" -eq 0 ] && [ -n "$changed_line" ] && printf '%s' "$changed_line" | grep -qE '[0-9]|unknown'; then
  pass "35: progress log records a 'changed since explored_at' line carrying a count or 'unknown'"
else
  fail "35: progress log records a 'changed since explored_at' line carrying a count or 'unknown'" \
    "code=$CODE changed_line=[$changed_line] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# F2 fixtures: a dedicated scratch tree exercising the git-tracked vs
# untracked removal paths that trigger the remove_empty_dir defect (F2) --
# archive removing a plan dir's last entry before the rmdir step runs.
# ---------------------------------------------------------------------------
f2_scratch=$(new_scratch)
f2_plans_dir="$f2_scratch/project-plans"
build_f2_fixture "$f2_scratch"

# ---------------------------------------------------------------------------
# Case 36: archive on a fully git-tracked plan dir -- the F2 regression
# ---------------------------------------------------------------------------
run_script archive "$f2_plans_dir/f2-tracked-01-01-26" --root "$f2_scratch" --plans-dir "$f2_plans_dir"
expected_archived="archived: $f2_plans_dir/f2-tracked-01-01-26/plan.md -> $f2_plans_dir/completed/f2-tracked-01-01-26.md"
expected_removed_1="removed: $f2_plans_dir/f2-tracked-01-01-26/plan-review.md"
expected_removed_2="removed: $f2_plans_dir/f2-tracked-01-01-26/code-review.md"
archived_line_ok=0
printf '%s\n' "$OUT" | grep -Fqx "$expected_archived" && archived_line_ok=1
removed_1_ok=0
printf '%s\n' "$OUT" | grep -Fqx "$expected_removed_1" && removed_1_ok=1
removed_2_ok=0
printf '%s\n' "$OUT" | grep -Fqx "$expected_removed_2" && removed_2_ok=1
err_no_rmdir_failed=0
printf '%s' "$ERR" | grep -q 'rmdir failed' || err_no_rmdir_failed=1
if [ "$CODE" -eq 0 ] \
   && [ "$archived_line_ok" -eq 1 ] \
   && [ "$removed_1_ok" -eq 1 ] \
   && [ "$removed_2_ok" -eq 1 ] \
   && [ "$err_no_rmdir_failed" -eq 1 ] \
   && [ -z "$ERR" ] \
   && [ -f "$f2_plans_dir/completed/f2-tracked-01-01-26.md" ] \
   && [ ! -e "$f2_plans_dir/f2-tracked-01-01-26" ]; then
  pass "36: archive on a fully git-tracked plan dir exits 0, no rmdir-failed lie, stderr empty (F2)"
else
  fail "36: archive on a fully git-tracked plan dir exits 0, no rmdir-failed lie, stderr empty (F2)" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case 37: archive on an untracked plan dir -- the mv/rm fallback path
# ---------------------------------------------------------------------------
run_script archive "$f2_plans_dir/f2-untracked-01-01-26" --root "$f2_scratch" --plans-dir "$f2_plans_dir"
expected_archived_u="archived: $f2_plans_dir/f2-untracked-01-01-26/plan.md -> $f2_plans_dir/completed/f2-untracked-01-01-26.md"
expected_removed_u1="removed: $f2_plans_dir/f2-untracked-01-01-26/plan-review.md"
expected_removed_u2="removed: $f2_plans_dir/f2-untracked-01-01-26/code-review.md"
archived_line_u_ok=0
printf '%s\n' "$OUT" | grep -Fqx "$expected_archived_u" && archived_line_u_ok=1
removed_u1_ok=0
printf '%s\n' "$OUT" | grep -Fqx "$expected_removed_u1" && removed_u1_ok=1
removed_u2_ok=0
printf '%s\n' "$OUT" | grep -Fqx "$expected_removed_u2" && removed_u2_ok=1
err_no_rmdir_failed_u=0
printf '%s' "$ERR" | grep -q 'rmdir failed' || err_no_rmdir_failed_u=1
if [ "$CODE" -eq 0 ] \
   && [ "$archived_line_u_ok" -eq 1 ] \
   && [ "$removed_u1_ok" -eq 1 ] \
   && [ "$removed_u2_ok" -eq 1 ] \
   && [ "$err_no_rmdir_failed_u" -eq 1 ] \
   && [ -z "$ERR" ] \
   && [ -f "$f2_plans_dir/completed/f2-untracked-01-01-26.md" ] \
   && [ ! -e "$f2_plans_dir/f2-untracked-01-01-26" ]; then
  pass "37: archive on an untracked plan dir (mv/rm fallback) exits 0, no rmdir-failed lie, stderr empty (F2)"
else
  fail "37: archive on an untracked plan dir (mv/rm fallback) exits 0, no rmdir-failed lie, stderr empty (F2)" \
    "code=$CODE out=[$OUT] err=[$ERR]"
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
