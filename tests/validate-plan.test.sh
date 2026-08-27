#!/usr/bin/env bash
# validate-plan.test.sh
#
# SYNOPSIS
#   bash tests/validate-plan.test.sh
#
# DESCRIPTION
#   Blind contract test for
#   agent-agnostic/skills/review-plan/scripts/validate-plan.sh (Packet B,
#   contracts/l7.md, section B-2, against B-1's behaviour / output
#   additions / acceptance criteria and section 0's shared ask-of-record
#   schema). Written from the contract text alone; NEVER reads
#   validate-plan.sh's source.
#
#   Covers cases C1-C12: the new check 6 (ask-of-record schema: existing
#   path, no-durable-ask statement, missing declaration, dangling path,
#   the three accepted markups, the two accepted locations, story.md as an
#   ordinary Form P path, a malformed declaration, one-FAIL-never-a-cascade,
#   a fully conforming plan's exact OK/INFO output, and usage errors) plus
#   a regression pass over the five pre-existing checks (syllabus-first,
#   phase-with-no-subphase, checkbox-with-no-detail, detail-with-no-checkbox,
#   after: naming a nonexistent id, and a dependency cycle), each fired in
#   isolation against an otherwise-conforming fixture, and silent against a
#   fully conforming control.
#
#   All fixtures are synthetic plan files written into throwaway `mktemp -d`
#   scratch dirs, never into this repo. Per the contract's "the awk here is
#   mawk, exit status is not evidence" convention (Sec 1.3), every case here
#   asserts on actual stdout/stderr CONTENT, never on exit status alone.
#
# EXIT CODES
#   0  every case passed
#   1  at least one case failed (or the bash -n sanity precondition failed)
#
# Runnable with no arguments from any working directory.

set -uo pipefail

# ---------------------------------------------------------------------------
# Locate the script under test relative to this file's own location. Per the
# contract: it ships INSIDE the review-plan skill, next to SKILL.md -- not in
# a hooks dir.
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/agent-agnostic/skills/review-plan/scripts/validate-plan.sh"

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

# run_validate <args...> -- invokes validate-plan.sh with stdin from
# /dev/null, and sets globals OUT / ERR / CODE / COMBINED.
OUT=""
ERR=""
CODE=0
COMBINED=""
run_validate() {
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  "$SCRIPT" "$@" </dev/null >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  COMBINED="$OUT
$ERR"
  rm -f "$out_f" "$err_f"
}

fail_count() {
  printf '%s\n' "$COMBINED" | grep -c '^FAIL:'
}

has_ok() {
  printf '%s\n' "$COMBINED" | grep -q '^OK: plan is structurally valid'
}

info_count() {
  printf '%s\n' "$COMBINED" | grep -c '^INFO:'
}

# ---------------------------------------------------------------------------
# Case 00: bash -n sanity precondition. If the script under test does not
# exist yet or fails to parse, nothing else here can be trusted.
# ---------------------------------------------------------------------------
if bash -n "$SCRIPT" 2>/tmp/validate-plan-syntax-err.$$; then
  pass "00: bash -n validate-plan.sh exits 0"
else
  syntax_err=$(cat /tmp/validate-plan-syntax-err.$$ 2>/dev/null)
  fail "00: bash -n validate-plan.sh exits 0" "syntax error: $syntax_err"
  rm -f /tmp/validate-plan-syntax-err.$$
  echo "sanity failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
rm -f /tmp/validate-plan-syntax-err.$$

# ===========================================================================
# Fixture construction
# ===========================================================================
# A shared, fully-conforming plan template. Every fixture is a copy of this
# with exactly one deliberate change, so a failure can be attributed to that
# one change and not to accidental drift between fixtures.
#
# Detail blocks deliberately mix BOTH accepted opening markups within the
# same fixture (bold lead-in "**N.M:" for phase 1, heading "### N.M --
# Title" for phase 2) so neither markup style is ever the accidental cause
# of a pass or a fail.
#
# build_plan <ask-line-or-empty> <placement: preamble|goalscope> <mutation>
# Mutations: none | v1_syllabus_not_first | v2_phase_no_subphase |
#            v3_checkbox_no_detail | v4_detail_no_checkbox |
#            v5_after_nonexistent | v6_cycle | double_malformed_ask
# ---------------------------------------------------------------------------

SYLLABUS_BLOCK='## Phase syllabus
- [ ] Phase 1: Alpha
  - [ ] 1.1: First alpha thing
  - [ ] 1.2: Second alpha thing (after: 1.1)
- [ ] Phase 2: Beta
  - [ ] 2.1: First beta thing (after: 1.2)'

GOAL_SCOPE_BLOCK='## Goal & scope
In scope: the alpha and beta things. Out of scope: everything else.'

STACK_BLOCK='## Stack & MAJOR versions
Bash 5, verified from this repo'"'"'s own tooling.'

CONVENTIONS_BLOCK='## Conventions to enforce
Keep fixtures minimal and self-contained.'

PHASE1_BLOCK='## Phase 1: Alpha
**1.1: First alpha thing**
Detail for the first alpha thing. Acceptance criteria: it exists. Test approach: manual.

**1.2: Second alpha thing**
Detail for the second alpha thing. Acceptance criteria: it exists. Test approach: manual.'

PHASE2_BLOCK='## Phase 2: Beta
### 2.1 — First beta thing
Detail for the first beta thing. Acceptance criteria: it exists. Test approach: manual.'

TAIL_BLOCK='## Risks, open questions, decision points
None.

## Skill mapping
Not applicable to this fixture.'

build_plan() {
  local ask_line="$1" placement="$2" mutation="$3"
  local syllabus="$SYLLABUS_BLOCK"
  local goalscope="$GOAL_SCOPE_BLOCK"
  local phase1="$PHASE1_BLOCK"
  local preamble_ask=""
  local goalscope_ask=""

  if [ -n "$ask_line" ]; then
    if [ "$placement" = "preamble" ]; then
      preamble_ask="
$ask_line
"
    else
      goalscope="## Goal & scope
In scope: the alpha and beta things. Out of scope: everything else.
$ask_line"
    fi
  fi

  case "$mutation" in
    v2_phase_no_subphase)
      syllabus="$syllabus
- [ ] Phase 3: Gamma"
      ;;
    v3_checkbox_no_detail)
      syllabus="## Phase syllabus
- [ ] Phase 1: Alpha
  - [ ] 1.1: First alpha thing
  - [ ] 1.2: Second alpha thing (after: 1.1)
  - [ ] 1.3: Orphan checkbox with no detail block
- [ ] Phase 2: Beta
  - [ ] 2.1: First beta thing (after: 1.2)"
      ;;
    v4_detail_no_checkbox)
      phase1="$PHASE1_BLOCK

**1.4: Orphan detail with no syllabus checkbox**
This detail block has no matching 1.4 entry in the phase syllabus."
      ;;
    v5_after_nonexistent)
      syllabus="## Phase syllabus
- [ ] Phase 1: Alpha
  - [ ] 1.1: First alpha thing
  - [ ] 1.2: Second alpha thing (after: 9.9)
- [ ] Phase 2: Beta
  - [ ] 2.1: First beta thing (after: 1.2)"
      ;;
    v6_cycle)
      syllabus="## Phase syllabus
- [ ] Phase 1: Alpha
  - [ ] 1.1: First alpha thing (after: 1.2)
  - [ ] 1.2: Second alpha thing (after: 1.1)
- [ ] Phase 2: Beta
  - [ ] 2.1: First beta thing (after: 1.2)"
      ;;
  esac

  local body="# Sample Plan
${preamble_ask}
$syllabus

$goalscope

$STACK_BLOCK

$CONVENTIONS_BLOCK

$phase1

$PHASE2_BLOCK

$TAIL_BLOCK
"

  if [ "$mutation" = "v1_syllabus_not_first" ]; then
    # Swap Goal & scope ahead of Phase syllabus -- syllabus is no longer the
    # first ## section.
    body="# Sample Plan
${preamble_ask}
$goalscope

$syllabus

$STACK_BLOCK

$CONVENTIONS_BLOCK

$phase1

$PHASE2_BLOCK

$TAIL_BLOCK
"
  fi

  if [ "$mutation" = "double_malformed_ask" ]; then
    body="# Sample Plan

**Ask of record:** first mention, no path and no negative marker
**Ask of record:** second mention, also neither a path nor a marker

$syllabus

$goalscope

$STACK_BLOCK

$CONVENTIONS_BLOCK

$phase1

$PHASE2_BLOCK

$TAIL_BLOCK
"
  fi

  printf '%s' "$body"
}

write_plan() {
  local dir="$1" content="$2"
  local f="$dir/plan.md"
  printf '%s\n' "$content" >"$f"
  printf '%s' "$f"
}

# ===========================================================================
# C1 -- valid, existing ask path (Form P) -> passes, OK present, no check-6
# FAIL. (criterion 1)
# ===========================================================================
d=$(new_scratch)
ask_file="$d/the-ask.md"
printf 'the ask\n' >"$ask_file"
plan=$(write_plan "$d" "$(build_plan "**Ask of record:** \`$ask_file\`" preamble none)")
run_validate "$plan"
if [ "$CODE" -eq 0 ] && has_ok && [ "$(fail_count)" -eq 0 ]; then
  pass "C1: existing Form P ask path -> exit 0, OK present, no FAIL"
else
  fail "C1: existing Form P ask path -> exit 0, OK present, no FAIL" \
    "code=$CODE combined=[$COMBINED]"
fi

# ===========================================================================
# C2 -- explicit no-durable-ask statement (Form N) -> passes. (criterion 2)
# ===========================================================================
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "**Ask of record:** no durable ask exists for this run." preamble none)")
run_validate "$plan"
if [ "$CODE" -eq 0 ] && has_ok && [ "$(fail_count)" -eq 0 ]; then
  pass "C2: explicit no-durable-ask statement (Form N) -> exit 0, OK present, no FAIL"
else
  fail "C2: explicit no-durable-ask statement (Form N) -> exit 0, OK present, no FAIL" \
    "code=$CODE combined=[$COMBINED]"
fi

# ===========================================================================
# C3 -- no declaration at all -> exactly one check-6 FAIL naming the missing
# declaration. (criterion 3)
# ===========================================================================
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "" preamble none)")
run_validate "$plan"
c3_fail_count="$(fail_count)"
c3_fail_line=$(printf '%s\n' "$COMBINED" | grep '^FAIL:' | head -n1)
if [ "$CODE" -ne 0 ] && [ "$c3_fail_count" -eq 1 ] \
  && printf '%s\n' "$c3_fail_line" | grep -qiE "ask.{0,2}of.{0,2}record"; then
  pass "C3: no declaration at all -> exactly one check-6 FAIL naming the missing declaration"
else
  fail "C3: no declaration at all -> exactly one check-6 FAIL naming the missing declaration" \
    "code=$CODE combined=[$COMBINED]"
fi

# ===========================================================================
# C4 -- ask path does not exist -> FAIL distinguishable from C3. (criterion 4)
# ===========================================================================
d=$(new_scratch)
missing_ask="$d/does-not-exist/the-ask.md"
plan=$(write_plan "$d" "$(build_plan "**Ask of record:** \`$missing_ask\`" preamble none)")
run_validate "$plan"
c4_fail_count="$(fail_count)"
c4_fail_line=$(printf '%s\n' "$COMBINED" | grep '^FAIL:' | head -n1)
if [ "$CODE" -ne 0 ] && [ "$c4_fail_count" -eq 1 ] \
  && [ -n "$c4_fail_line" ] && [ "$c4_fail_line" != "$c3_fail_line" ]; then
  pass "C4: dangling ask path -> exactly one check-6 FAIL, distinct message from C3"
else
  fail "C4: dangling ask path -> exactly one check-6 FAIL, distinct message from C3" \
    "code=$CODE c3=[$c3_fail_line] c4=[$c4_fail_line]"
fi
c4_fail_line_saved="$c4_fail_line"

# ===========================================================================
# C5 -- at least two of section 0's three markups accepted; cover all three.
# (criterion 5)
# ===========================================================================
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "**Ask of record:** no durable ask exists for this run." preamble none)")
run_validate "$plan"
if [ "$CODE" -eq 0 ] && [ "$(fail_count)" -eq 0 ]; then
  pass "C5a: bold lead-in markup (**Ask of record:**) accepted"
else
  fail "C5a: bold lead-in markup (**Ask of record:**) accepted" "code=$CODE combined=[$COMBINED]"
fi

# NOTE on placement: a level-2 "## Ask of record" heading cannot occur in
# the preamble (a "## " line there becomes the first ## section itself, per
# section 0's own "Where" definition of preamble as "before the first ## "),
# and it cannot occur inside "## Goal & scope" either (that section's window
# runs only "to the next ^## ", so a second level-2 heading would itself end
# the window before covering it) -- so a level-2 heading declaration cannot
# satisfy both the Markup list and the Where rule simultaneously; see the
# contract-ambiguity note in the final report. A level-3..6 heading nested
# *inside* "## Goal & scope" is unambiguously placeable (its window ends
# only at the next literal "^## ", not "^### "), so that is what this case
# exercises -- it still exercises the "markdown heading" markup family.
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "### Ask of record: no durable ask exists for this run." goalscope none)")
run_validate "$plan"
if [ "$CODE" -eq 0 ] && [ "$(fail_count)" -eq 0 ]; then
  pass "C5b: markdown heading markup (### Ask of record: ..., nested in Goal & scope) accepted"
else
  fail "C5b: markdown heading markup (### Ask of record: ..., nested in Goal & scope) accepted" "code=$CODE combined=[$COMBINED]"
fi

d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "- Ask of record: no durable ask exists for this run." preamble none)")
run_validate "$plan"
if [ "$CODE" -eq 0 ] && [ "$(fail_count)" -eq 0 ]; then
  pass "C5c: list bullet markup (- Ask of record: ...) accepted"
else
  fail "C5c: list bullet markup (- Ask of record: ...) accepted" "code=$CODE combined=[$COMBINED]"
fi

# ===========================================================================
# C6 -- declaration accepted in the preamble, and inside ## Goal & scope.
# ===========================================================================
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "**Ask of record:** no durable ask exists for this run." preamble none)")
run_validate "$plan"
if [ "$CODE" -eq 0 ] && [ "$(fail_count)" -eq 0 ]; then
  pass "C6a: declaration in the preamble accepted"
else
  fail "C6a: declaration in the preamble accepted" "code=$CODE combined=[$COMBINED]"
fi

d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "**Ask of record:** no durable ask exists for this run." goalscope none)")
run_validate "$plan"
if [ "$CODE" -eq 0 ] && [ "$(fail_count)" -eq 0 ]; then
  pass "C6b: declaration inside ## Goal & scope accepted"
else
  fail "C6b: declaration inside ## Goal & scope accepted" "code=$CODE combined=[$COMBINED]"
fi

# ===========================================================================
# C7 -- story.md-shaped path accepted as an ordinary Form P path.
# ===========================================================================
d=$(new_scratch)
mkdir -p "$d/run-dir"
story="$d/run-dir/story.md"
printf 'Original Ask (verbatim)\n...\n' >"$story"
plan=$(write_plan "$d" "$(build_plan "**Ask of record:** \`$story\`" preamble none)")
run_validate "$plan"
if [ "$CODE" -eq 0 ] && has_ok && [ "$(fail_count)" -eq 0 ]; then
  pass "C7: story.md-shaped existing path accepted as Form P"
else
  fail "C7: story.md-shaped existing path accepted as Form P" \
    "code=$CODE combined=[$COMBINED]"
fi

# ===========================================================================
# C8 -- malformed declaration: phrase present, neither a path nor a negative
# marker -> FAIL distinct from C3 and C4.
# ===========================================================================
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "**Ask of record:** somewhere, still to be decided" preamble none)")
run_validate "$plan"
c8_fail_count="$(fail_count)"
c8_fail_line=$(printf '%s\n' "$COMBINED" | grep '^FAIL:' | head -n1)
if [ "$CODE" -ne 0 ] && [ "$c8_fail_count" -eq 1 ] \
  && [ -n "$c8_fail_line" ] \
  && [ "$c8_fail_line" != "$c3_fail_line" ] \
  && [ "$c8_fail_line" != "$c4_fail_line_saved" ]; then
  pass "C8: malformed declaration -> exactly one check-6 FAIL, distinct from C3 and C4"
else
  fail "C8: malformed declaration -> exactly one check-6 FAIL, distinct from C3 and C4" \
    "code=$CODE c3=[$c3_fail_line] c4=[$c4_fail_line_saved] c8=[$c8_fail_line]"
fi

# ===========================================================================
# C9 -- regression on the five pre-existing checks: each fires in isolation,
# each is silent on a fully conforming fixture. Every fixture below carries a
# valid Form N ask declaration, so any FAIL it produces is attributable to
# the one structural mutation under test, not to check 6.
# ===========================================================================
valid_ask_line="**Ask of record:** no durable ask exists for this run."

# --- conforming control: zero FAIL lines, OK present ------------------------
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$valid_ask_line" preamble none)")
run_validate "$plan"
if [ "$CODE" -eq 0 ] && has_ok && [ "$(fail_count)" -eq 0 ]; then
  pass "C9-control: fully conforming plan -> zero FAIL lines, OK present"
else
  fail "C9-control: fully conforming plan -> zero FAIL lines, OK present" \
    "code=$CODE combined=[$COMBINED]"
fi

# --- v1: syllabus is not the first section ----------------------------------
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$valid_ask_line" preamble v1_syllabus_not_first)")
run_validate "$plan"
if [ "$CODE" -ne 0 ] && [ "$(fail_count)" -ge 1 ]; then
  pass "C9-v1: syllabus not first section -> at least one FAIL"
else
  fail "C9-v1: syllabus not first section -> at least one FAIL" \
    "code=$CODE combined=[$COMBINED]"
fi

# --- v2: a phase bullet with no nested subphase checkbox --------------------
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$valid_ask_line" preamble v2_phase_no_subphase)")
run_validate "$plan"
if [ "$CODE" -ne 0 ] && [ "$(fail_count)" -ge 1 ]; then
  pass "C9-v2: phase with no subphase checkbox -> at least one FAIL"
else
  fail "C9-v2: phase with no subphase checkbox -> at least one FAIL" \
    "code=$CODE combined=[$COMBINED]"
fi

# --- v3: a syllabus checkbox with no matching detail block ------------------
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$valid_ask_line" preamble v3_checkbox_no_detail)")
run_validate "$plan"
if [ "$CODE" -ne 0 ] && [ "$(fail_count)" -ge 1 ]; then
  pass "C9-v3: syllabus checkbox with no detail block -> at least one FAIL"
else
  fail "C9-v3: syllabus checkbox with no detail block -> at least one FAIL" \
    "code=$CODE combined=[$COMBINED]"
fi

# --- v4: a detail block with no matching syllabus checkbox ------------------
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$valid_ask_line" preamble v4_detail_no_checkbox)")
run_validate "$plan"
if [ "$CODE" -ne 0 ] && [ "$(fail_count)" -ge 1 ]; then
  pass "C9-v4: detail block with no syllabus checkbox -> at least one FAIL"
else
  fail "C9-v4: detail block with no syllabus checkbox -> at least one FAIL" \
    "code=$CODE combined=[$COMBINED]"
fi

# --- v5: (after:) names a subphase id that does not exist -------------------
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$valid_ask_line" preamble v5_after_nonexistent)")
run_validate "$plan"
if [ "$CODE" -ne 0 ] && [ "$(fail_count)" -ge 1 ]; then
  pass "C9-v5: (after:) names a nonexistent id -> at least one FAIL"
else
  fail "C9-v5: (after:) names a nonexistent id -> at least one FAIL" \
    "code=$CODE combined=[$COMBINED]"
fi

# --- v6: a two-node dependency cycle ----------------------------------------
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$valid_ask_line" preamble v6_cycle)")
run_validate "$plan"
if [ "$CODE" -ne 0 ] && [ "$(fail_count)" -ge 1 ]; then
  pass "C9-v6: two-node dependency cycle -> at least one FAIL"
else
  fail "C9-v6: two-node dependency cycle -> at least one FAIL" \
    "code=$CODE combined=[$COMBINED]"
fi

# ===========================================================================
# C10 -- a fully conforming plan: exit-0 path, OK present, and the EXISTING
# lane-disjointness INFO line present byte-identical.
# ===========================================================================
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$valid_ask_line" preamble none)")
run_validate "$plan"
if [ "$CODE" -eq 0 ] && has_ok \
  && printf '%s\n' "$COMBINED" | grep -qF \
    "INFO: lane file-scope disjointness is not machine-checked — verify scopes in the detail blocks."; then
  pass "C10: fully conforming plan -> exit 0, OK present, existing lane-disjointness INFO byte-identical"
else
  fail "C10: fully conforming plan -> exit 0, OK present, existing lane-disjointness INFO byte-identical" \
    "code=$CODE combined=[$COMBINED]"
fi

# Bonus (not a numbered C-case, but directly required by B-1's "Output
# additions"): a passing plan carries at least two INFO: lines -- the
# existing lane-disjointness one plus the new ask-vs-plan companion note.
if [ "$(info_count)" -ge 2 ]; then
  pass "C10-bonus: passing plan carries the new ask-vs-plan companion INFO line alongside the existing one"
else
  fail "C10-bonus: passing plan carries the new ask-vs-plan companion INFO line alongside the existing one" \
    "info_count=$(info_count) combined=[$COMBINED]"
fi

# ===========================================================================
# C11 -- usage errors byte-identical.
# ===========================================================================
run_validate
if [ "$CODE" -ne 0 ] \
  && printf '%s\n' "$COMBINED" | grep -qF "usage: validate-plan.sh <plan-file>"; then
  pass "C11a: no argument -> usage: validate-plan.sh <plan-file>"
else
  fail "C11a: no argument -> usage: validate-plan.sh <plan-file>" \
    "code=$CODE combined=[$COMBINED]"
fi

d=$(new_scratch)
missing_plan="$d/no-such-plan.md"
run_validate "$missing_plan"
if [ "$CODE" -ne 0 ] \
  && printf '%s\n' "$COMBINED" | grep -qF "FAIL: plan file not found: $missing_plan"; then
  pass "C11b: missing plan file -> FAIL: plan file not found: <path>"
else
  fail "C11b: missing plan file -> FAIL: plan file not found: <path>" \
    "code=$CODE combined=[$COMBINED]"
fi

# ===========================================================================
# C12 -- only one check-6 FAIL line is ever emitted per plan, never a
# cascade -- even when two candidate declaration lines are present (first
# match in document order wins per section 0; later ones are ignored).
# ===========================================================================
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "" preamble double_malformed_ask)")
run_validate "$plan"
if [ "$CODE" -ne 0 ] && [ "$(fail_count)" -eq 1 ]; then
  pass "C12: two malformed ask-of-record lines -> still exactly one check-6 FAIL, no cascade"
else
  fail "C12: two malformed ask-of-record lines -> still exactly one check-6 FAIL, no cascade" \
    "code=$CODE fail_count=$(fail_count) combined=[$COMBINED]"
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
