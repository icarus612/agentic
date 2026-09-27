#!/usr/bin/env bash
# validate-plan.test.sh
#
# SYNOPSIS
#   bash tests/validate-plan.test.sh
#
# DESCRIPTION
#   Blind contract test for
#   agent-agnostic/skills/review-plan/scripts/validate-plan.sh (Packet B,
#   contracts/l2.md, section B-2, against B-1's behaviour / acceptance
#   criteria and section 0.1's shared "Ask of record" section schema).
#   Written from the contract text alone; NEVER reads validate-plan.sh's
#   source.
#
#   Checks 1-5 (syllabus-first, phase-has-subphase, checkbox<->detail 1:1,
#   (after:) targets real, acyclic) are unchanged by this contract, and are
#   covered here only as a regression pass (case series C9) fired in
#   isolation against an otherwise-conforming fixture, plus a fully
#   conforming control.
#
#   Check 6 is REPLACED by this contract: the old two-form ask-of-record
#   POINTER (a backticked path resolved on disk, or a "no durable ask
#   exists" statement) is retired. The new check looks, in the plan's
#   PREAMBLE only (everything before the first "## " line), for a markdown
#   heading (level 3 through 6) whose text contains "ask of record"
#   case-insensitively, opening a section of one or more dated, verbatim
#   entries. There is no filesystem resolution of anything inside that
#   section's text -- none. Cases C1-C8 below cover B-1's 11 numbered
#   acceptance criteria for this new check, one case per criterion (C9's
#   regression series absorbs criterion 9; C10 absorbs the INFO-line half of
#   criterion 11; C11 absorbs criterion 10's usage-error wording).
#
#   All fixtures are synthetic plan files written into throwaway `mktemp -d`
#   scratch dirs, never into this repo. Per the contract's "the grep here
#   may be ugrep, the awk may be mawk -- exit status is not evidence"
#   convention, every case here asserts on actual stdout/stderr CONTENT,
#   never on exit status alone.
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

first_fail_line() {
  printf '%s\n' "$COMBINED" | grep '^FAIL:' | head -n1
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
# of a pass or a fail on checks 1-5 (unrelated to the ask schema).
#
# build_plan <ask-section-block-or-empty> <mutation>
# Mutations: none | v1_syllabus_not_first | v2_phase_no_subphase |
#            v3_checkbox_no_detail | v4_detail_no_checkbox |
#            v5_after_nonexistent | v6_cycle
#
# The ask-section block, when non-empty, is inserted verbatim into the
# PREAMBLE (before "## Phase syllabus", the first "## " section) -- the new
# schema is preamble-only, so there is no "placement" parameter any more.
# ---------------------------------------------------------------------------

SYLLABUS_BLOCK='## Phase syllabus
- [ ] Phase 1: Alpha
  - [ ] 1.1: First alpha thing
  - [ ] 1.2: Second alpha thing (after: 1.1)
- [ ] Phase 2: Beta
  - [ ] 2.1: First beta thing (after: 1.2)'

GOAL_SCOPE_BLOCK='## Goal & scope
In scope: the alpha and beta things. Out of scope: everything else. The ask
itself lives in the Ask of record section above; this section only restates
scope.'

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

# ---------------------------------------------------------------------------
# Ask-of-record section fixtures (section 0.1's new schema).
# ---------------------------------------------------------------------------

# A fully conforming section: level-3 heading, one dated verbatim entry.
ASK_SECTION_L3='### Ask of record

**09-01-26:** Build a small tool that validates project plans against the
contract shape described in this fixture, exactly as requested, verbatim.'

# A fully conforming section using the OTHER end of the accepted heading
# range (level 6), to prove the whole 3-6 span is tolerated, not just 3.
ASK_SECTION_L6='###### Ask of record

**09-01-26:** Build a small tool that validates project plans against the
contract shape described in this fixture, exactly as requested, verbatim.'

# Heading present, but nothing except blank lines follows it before the
# preamble ends (i.e. before "## Phase syllabus").
ASK_SECTION_HEADING_ONLY='### Ask of record

'

# A conforming section whose entry text happens to mention a file path that
# does not exist anywhere on disk. Proves check 6 never resolves it.
ASK_SECTION_DANGLING_PATH='### Ask of record

**09-01-26:** See `.artifacts/the-ask.md` for background; the verbatim ask
text is captured right here regardless of whether that file exists on disk.'

# The OLD, now-retired one-line pointer style: a bold lead-in with no
# heading at all. Under the new schema this must FAIL (no heading to find).
ASK_SECTION_OLD_STYLE='**Ask of record:** `/some/nonexistent/path/the-ask.md`'

# Two distinct "ask of record" heading lines, each with nothing of
# substance around it -- both malformed/empty.
ASK_SECTION_DOUBLE_MALFORMED='### Ask of record

### Ask of record
'

build_plan() {
  local ask_section="$1" mutation="$2"
  local syllabus="$SYLLABUS_BLOCK"
  local phase1="$PHASE1_BLOCK"

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

  local preamble="# Sample Plan"
  if [ -n "$ask_section" ]; then
    preamble="$preamble

$ask_section"
  fi

  local body="$preamble

$syllabus

$GOAL_SCOPE_BLOCK

$STACK_BLOCK

$CONVENTIONS_BLOCK

$phase1

$PHASE2_BLOCK

$TAIL_BLOCK
"

  if [ "$mutation" = "v1_syllabus_not_first" ]; then
    # Swap Goal & scope ahead of Phase syllabus -- syllabus is no longer the
    # first ## section. The ask section, still ahead of both, stays valid
    # and in the preamble either way.
    body="$preamble

$GOAL_SCOPE_BLOCK

$syllabus

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
# C1 -- a proper Ask of record section (level-3 heading, dated verbatim
# entry, in the preamble, before Phase syllabus) -> check 6 produces NO
# FAIL. (criterion 1; also the positive control paired with C2, C3, C6, C8)
# ===========================================================================
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$ASK_SECTION_L3" none)")
run_validate "$plan"
if [ "$CODE" -eq 0 ] && has_ok && [ "$(fail_count)" -eq 0 ]; then
  pass "C1: proper Ask of record section -> exit 0, OK present, no check-6 FAIL"
else
  fail "C1: proper Ask of record section -> exit 0, OK present, no check-6 FAIL" \
    "code=$CODE combined=[$COMBINED]"
fi

# ===========================================================================
# C2 -- heading present, nothing but blank lines beneath it before the
# preamble ends -> exactly one check-6 FAIL. (criterion 2)
# ===========================================================================
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$ASK_SECTION_HEADING_ONLY" none)")
run_validate "$plan"
c2_fail_count="$(fail_count)"
c2_fail_line="$(first_fail_line)"
if [ "$CODE" -ne 0 ] && [ "$c2_fail_count" -eq 1 ] && [ -n "$c2_fail_line" ]; then
  pass "C2: Ask of record heading present but body empty -> exactly one check-6 FAIL"
else
  fail "C2: Ask of record heading present but body empty -> exactly one check-6 FAIL" \
    "code=$CODE combined=[$COMBINED]"
fi

# ===========================================================================
# C3 -- no Ask of record heading anywhere in the preamble -> exactly one
# check-6 FAIL, with wording DISTINCT from C2's (the contract requires the
# two failure shapes -- missing section vs. empty section -- to be told
# apart). (criterion 3, distinctness vs. criterion 2)
# ===========================================================================
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "" none)")
run_validate "$plan"
c3_fail_count="$(fail_count)"
c3_fail_line="$(first_fail_line)"
if [ "$CODE" -ne 0 ] && [ "$c3_fail_count" -eq 1 ] && [ -n "$c3_fail_line" ] \
  && [ "$c3_fail_line" != "$c2_fail_line" ]; then
  pass "C3: no Ask of record heading anywhere -> exactly one check-6 FAIL, distinct wording from C2"
else
  fail "C3: no Ask of record heading anywhere -> exactly one check-6 FAIL, distinct wording from C2" \
    "code=$CODE c2=[$c2_fail_line] c3=[$c3_fail_line] combined=[$COMBINED]"
fi

# ===========================================================================
# C4 -- the section's body text mentions a path to a file that does not
# exist on disk -> NO check-6 FAIL. Proves "no filesystem resolution at
# all" is real, not just claimed in a comment. (criterion 4)
# ===========================================================================
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$ASK_SECTION_DANGLING_PATH" none)")
run_validate "$plan"
if [ "$CODE" -eq 0 ] && has_ok && [ "$(fail_count)" -eq 0 ] \
  && [ ! -e "$d/.artifacts/the-ask.md" ]; then
  pass "C4: Ask of record body mentions a nonexistent file path -> no check-6 FAIL (no filesystem resolution)"
else
  fail "C4: Ask of record body mentions a nonexistent file path -> no check-6 FAIL (no filesystem resolution)" \
    "code=$CODE combined=[$COMBINED]"
fi

# ===========================================================================
# C5 -- an ARCHIVED-state simulation: the section present and non-empty, but
# no run dir, no .artifacts/ tree, nothing on disk beyond the plan file
# itself -> still passes with NO check-6 FAIL. (criterion 5 -- a plan
# properly written under the NEW scheme; NOT about the five pre-existing
# archived plans under project-plans/completed/, which are out of scope
# per contract section 0.2 and are expected to keep failing.)
# ===========================================================================
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$ASK_SECTION_L3" none)")
scratch_listing="$(ls -A "$d")"
run_validate "$plan"
if [ "$CODE" -eq 0 ] && has_ok && [ "$(fail_count)" -eq 0 ] \
  && [ "$scratch_listing" = "plan.md" ]; then
  pass "C5: archived-state simulation (plan file alone, nothing else on disk) -> still passes check 6"
else
  fail "C5: archived-state simulation (plan file alone, nothing else on disk) -> still passes check 6" \
    "code=$CODE listing=[$scratch_listing] combined=[$COMBINED]"
fi

# ===========================================================================
# C6 -- two different "ask of record" heading lines, both malformed/empty
# -> still exactly one check-6 FAIL, never two (no cascade). (criterion 6)
# ===========================================================================
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$ASK_SECTION_DOUBLE_MALFORMED" none)")
run_validate "$plan"
if [ "$CODE" -ne 0 ] && [ "$(fail_count)" -eq 1 ]; then
  pass "C6: two malformed/empty Ask of record headings -> still exactly one check-6 FAIL, no cascade"
else
  fail "C6: two malformed/empty Ask of record headings -> still exactly one check-6 FAIL, no cascade" \
    "code=$CODE fail_count=$(fail_count) combined=[$COMBINED]"
fi

# ===========================================================================
# C7 -- heading level tolerance across the whole 3-6 range: level 3 is
# already proven accepted by C1; this proves the other end, level 6, is
# accepted too. (criterion 7)
# ===========================================================================
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$ASK_SECTION_L6" none)")
run_validate "$plan"
if [ "$CODE" -eq 0 ] && has_ok && [ "$(fail_count)" -eq 0 ]; then
  pass "C7: level-6 heading (###### Ask of record) accepted, alongside level 3 proven in C1"
else
  fail "C7: level-6 heading (###### Ask of record) accepted, alongside level 3 proven in C1" \
    "code=$CODE combined=[$COMBINED]"
fi

# ===========================================================================
# C8 -- the OLD Form P/Form N one-line-declaration style ONLY (bold
# lead-in, no heading, nothing beneath it) -> now FAILS check 6. This is
# the deliberate breaking change the migration accepts: it proves check 6
# actually moved to the new schema instead of silently still accepting the
# old one. Positive counterpart: C1 (the same intent, expressed as a
# heading instead of a bold lead-in, passes). (criterion 8)
# ===========================================================================
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$ASK_SECTION_OLD_STYLE" none)")
run_validate "$plan"
if [ "$CODE" -ne 0 ] && [ "$(fail_count)" -eq 1 ]; then
  pass "C8: old-style bold lead-in declaration (no heading) -> now FAILS check 6 (positive counterpart: C1)"
else
  fail "C8: old-style bold lead-in declaration (no heading) -> now FAILS check 6 (positive counterpart: C1)" \
    "code=$CODE combined=[$COMBINED]"
fi

# ===========================================================================
# C9 -- regression on the five pre-existing checks (1-5): each fires in
# isolation, each is silent on a fully conforming fixture. Every fixture
# below carries a valid new-style Ask of record section, so any FAIL it
# produces is attributable to the one structural mutation under test, not
# to check 6. (criterion 9)
# ===========================================================================

# --- conforming control: zero FAIL lines, OK present ------------------------
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$ASK_SECTION_L3" none)")
run_validate "$plan"
if [ "$CODE" -eq 0 ] && has_ok && [ "$(fail_count)" -eq 0 ]; then
  pass "C9-control: fully conforming plan (new-style ask section) -> zero FAIL lines, OK present"
else
  fail "C9-control: fully conforming plan (new-style ask section) -> zero FAIL lines, OK present" \
    "code=$CODE combined=[$COMBINED]"
fi

# --- v1: syllabus is not the first section ----------------------------------
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$ASK_SECTION_L3" v1_syllabus_not_first)")
run_validate "$plan"
if [ "$CODE" -ne 0 ] && [ "$(fail_count)" -ge 1 ]; then
  pass "C9-v1: syllabus not first section -> at least one FAIL"
else
  fail "C9-v1: syllabus not first section -> at least one FAIL" \
    "code=$CODE combined=[$COMBINED]"
fi

# --- v2: a phase bullet with no nested subphase checkbox --------------------
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$ASK_SECTION_L3" v2_phase_no_subphase)")
run_validate "$plan"
if [ "$CODE" -ne 0 ] && [ "$(fail_count)" -ge 1 ]; then
  pass "C9-v2: phase with no subphase checkbox -> at least one FAIL"
else
  fail "C9-v2: phase with no subphase checkbox -> at least one FAIL" \
    "code=$CODE combined=[$COMBINED]"
fi

# --- v3: a syllabus checkbox with no matching detail block ------------------
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$ASK_SECTION_L3" v3_checkbox_no_detail)")
run_validate "$plan"
if [ "$CODE" -ne 0 ] && [ "$(fail_count)" -ge 1 ]; then
  pass "C9-v3: syllabus checkbox with no detail block -> at least one FAIL"
else
  fail "C9-v3: syllabus checkbox with no detail block -> at least one FAIL" \
    "code=$CODE combined=[$COMBINED]"
fi

# --- v4: a detail block with no matching syllabus checkbox ------------------
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$ASK_SECTION_L3" v4_detail_no_checkbox)")
run_validate "$plan"
if [ "$CODE" -ne 0 ] && [ "$(fail_count)" -ge 1 ]; then
  pass "C9-v4: detail block with no syllabus checkbox -> at least one FAIL"
else
  fail "C9-v4: detail block with no syllabus checkbox -> at least one FAIL" \
    "code=$CODE combined=[$COMBINED]"
fi

# --- v5: (after:) names a subphase id that does not exist -------------------
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$ASK_SECTION_L3" v5_after_nonexistent)")
run_validate "$plan"
if [ "$CODE" -ne 0 ] && [ "$(fail_count)" -ge 1 ]; then
  pass "C9-v5: (after:) names a nonexistent id -> at least one FAIL"
else
  fail "C9-v5: (after:) names a nonexistent id -> at least one FAIL" \
    "code=$CODE combined=[$COMBINED]"
fi

# --- v6: a two-node dependency cycle ----------------------------------------
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$ASK_SECTION_L3" v6_cycle)")
run_validate "$plan"
if [ "$CODE" -ne 0 ] && [ "$(fail_count)" -ge 1 ]; then
  pass "C9-v6: two-node dependency cycle -> at least one FAIL"
else
  fail "C9-v6: two-node dependency cycle -> at least one FAIL" \
    "code=$CODE combined=[$COMBINED]"
fi

# ===========================================================================
# C10 -- a fully conforming plan: exit-0 path, OK present, and the EXISTING
# lane-disjointness INFO line present byte-identical (unchanged wording).
# Plus a bonus check that a passing plan carries at least two INFO: lines
# -- the existing lane-disjointness one plus the ask-vs-plan faithfulness
# companion note, both stated by the contract to be unchanged.
# (criterion 11)
# ===========================================================================
d=$(new_scratch)
plan=$(write_plan "$d" "$(build_plan "$ASK_SECTION_L3" none)")
run_validate "$plan"
if [ "$CODE" -eq 0 ] && has_ok \
  && printf '%s\n' "$COMBINED" | grep -qF \
    "INFO: lane file-scope disjointness is not machine-checked — verify scopes in the detail blocks."; then
  pass "C10: fully conforming plan -> exit 0, OK present, existing lane-disjointness INFO byte-identical"
else
  fail "C10: fully conforming plan -> exit 0, OK present, existing lane-disjointness INFO byte-identical" \
    "code=$CODE combined=[$COMBINED]"
fi

if [ "$(info_count)" -ge 2 ]; then
  pass "C10-bonus: passing plan carries the ask-vs-plan faithfulness INFO line alongside the lane-disjointness one"
else
  fail "C10-bonus: passing plan carries the ask-vs-plan faithfulness INFO line alongside the lane-disjointness one" \
    "info_count=$(info_count) combined=[$COMBINED]"
fi

# ===========================================================================
# C11 -- usage errors byte-identical (no argument; missing plan file). Not
# about the ask schema at all -- unchanged in substance. (criterion 10)
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

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
