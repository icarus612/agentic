#!/usr/bin/env bash
# resolve-type.test.sh
#
# SYNOPSIS
#   bash tests/resolve-type.test.sh
#
# DESCRIPTION
#   Blind contract test for orchestrators/hooks/resolve-type.sh — the dae type
#   resolver that maps a type (or alias) plus axis flags onto the five axes in
#   orchestrators/skills/dae/workflows.yaml and prints them as KEY=value lines.
#
#   Written from the contract text of contracts/l2.md ALONE (§2 the yaml table,
#   §3.2 the CLI, §3.3 flag/prefix resolution, §3.4 the resolution algorithm,
#   §3.5 the error set and its required stderr substrings, §3.6 the stdout
#   KEY=value contract, §3.7 the phase-existence table, §3.8 the five-step
#   rigor resolution and the D2 warning rule, §3.9 the override tiers, §3.10
#   the explicit non-goals). This suite NEVER reads resolve-type.sh's source
#   and never reads the real workflows.yaml — every expectation about that
#   table comes from §2.1 of the contract, which quotes it verbatim. The only
#   interaction with the script file itself is the case-00 `bash -n` sanity
#   precondition, which invokes it without inspecting its logic.
#
#   Assertions on stderr use only the substrings the contract's required-
#   substring columns (§3.5, §3.8) make contractual; the surrounding sentence
#   wording belongs to the implementer. Assertions on stdout use exact-line
#   matching, and absence of a line is asserted explicitly — an omitted rigor
#   phase, and map's absent PLANNER=/BRANCH=, are contractually ABSENT rather
#   than empty.
#
#   Fixture yamls are written into throwaway `mktemp -d` directories and passed
#   via the contract's internal `--yaml <path>` flag. Nothing is written
#   outside those scratch dirs; the repo's real workflows.yaml is never
#   mutated.
#
#   The locked-`--ship` cases (04, 29, 36b, and 44-50) were added later, from
#   the contract text of contracts/l1.md ALONE, under the same no-source-read
#   discipline.
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
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/orchestrators/hooks/resolve-type.sh"

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

# ---------------------------------------------------------------------------
# Invocation helpers. Both pin stdin to /dev/null and capture stdout, stderr
# and the exit code into the OUT / ERR / CODE globals.
# ---------------------------------------------------------------------------
OUT=""
ERR=""
CODE=0

run_in() {
  local dir="$1"
  shift
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  ( cd "$dir" && exec "$SCRIPT" "$@" ) </dev/null >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

run() {
  run_in "$REPO_ROOT" "$@"
}

ctx() {
  printf 'code=%s out=[%s] err=[%s]' "$CODE" "$OUT" "$ERR"
}

# ---------------------------------------------------------------------------
# Assertion primitives
# ---------------------------------------------------------------------------

# line <exact KEY=value>  -- exact whole-line match on stdout
line() { printf '%s\n' "$OUT" | grep -qxF -- "$1"; }

# out_re <regex>  -- regex match on stdout
out_re() { printf '%s\n' "$OUT" | grep -q -- "$1"; }

# err_sub <substring>  -- fixed-string match on stderr
err_sub() { printf '%s\n' "$ERR" | grep -qF -- "$1"; }

# err_tok <token>  -- stderr contains the token delimited by non-token chars.
# Used where a plain substring test would be satisfied by a LONGER token that
# merely contains it (e.g. asserting '--r' must not be satisfied by '--rigor').
err_tok() {
  printf '%s\n' "$ERR" | grep -qE -- "(^|[^A-Za-z0-9_=-])$1([^A-Za-z0-9_=-]|\$)"
}

# ok_lines <desc> <exact line...>  -- exit 0 and every listed line present
ok_lines() {
  local desc="$1"
  shift
  local s bad=""
  [ "$CODE" -eq 0 ] || bad="exit=$CODE"
  for s in "$@"; do
    line "$s" || bad="$bad missing-line:[$s]"
  done
  if [ -z "$bad" ]; then pass "$desc"; else fail "$desc" "$bad; $(ctx)"; fi
}

# no_lines <desc> <regex...>  -- exit 0 and every listed regex ABSENT on stdout
no_lines() {
  local desc="$1"
  shift
  local s bad=""
  [ "$CODE" -eq 0 ] || bad="exit=$CODE"
  for s in "$@"; do
    if out_re "$s"; then bad="$bad unexpected:[$s]"; fi
  done
  if [ -z "$bad" ]; then pass "$desc"; else fail "$desc" "$bad; $(ctx)"; fi
}

# err_case <desc> <required stderr substring...>  -- exit 1 and every substring
err_case() {
  local desc="$1"
  shift
  local s bad=""
  [ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
  for s in "$@"; do
    err_sub "$s" || bad="$bad missing-stderr:[$s]"
  done
  if [ -z "$bad" ]; then pass "$desc"; else fail "$desc" "$bad; $(ctx)"; fi
}

# no_key_block  -- stdout carries no KEY=value line at all
no_key_block() { ! out_re '^[A-Z][A-Z0-9_]*='; }

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Case 00: bash -n sanity precondition (the script must at least parse)
# ---------------------------------------------------------------------------
if bash -n "$SCRIPT" 2>/tmp/resolve-type-syntax-err.$$; then
  pass "00: bash -n resolve-type.sh exits 0"
else
  syntax_err=$(cat /tmp/resolve-type-syntax-err.$$ 2>/dev/null)
  fail "00: bash -n resolve-type.sh exits 0" "syntax error: $syntax_err"
  rm -f /tmp/resolve-type-syntax-err.$$
  echo "sanity failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
rm -f /tmp/resolve-type-syntax-err.$$

# ===========================================================================
# TABLE PARSING (§2.1, §2.3)
# ===========================================================================

# --- Case 01: all eleven canonical types resolve ----------------------------
# rework and sync are `against: require` rows (§2.1) and so are given one
# anchor; every other row is forbid or optional and is given none (live is
# `against: optional`, so it needs no anchor branch either).
for t in feature bugfix hotfix migration rework diagnose map analyze document sync live; do
  case "$t" in
    rework|sync) run "$t" --against REF ;;
    *)           run "$t" ;;
  esac
  bad=""
  [ "$CODE" -eq 0 ] || bad="exit=$CODE"
  line "TYPE=$t" || bad="$bad missing-line:[TYPE=$t]"
  for k in '^PIPELINE=' '^EXPLORE=' '^SHIP=' '^AGAINST_COUNT='; do
    out_re "$k" || bad="$bad missing:[$k]"
  done
  if [ -z "$bad" ]; then
    pass "01/$t: resolves, exit 0, TYPE/PIPELINE/EXPLORE/SHIP/AGAINST_COUNT all present"
  else
    fail "01/$t: resolves, exit 0, TYPE/PIPELINE/EXPLORE/SHIP/AGAINST_COUNT all present" \
      "$bad; $(ctx)"
  fi
done

# --- Case 02: row fidelity spot-checks against §2.1 ------------------------
run feature
ok_lines "02a: feature row fidelity (build/auto/publish/plan-feature/feature/)" \
  'TYPE=feature' 'PIPELINE=build' 'EXPLORE=auto' 'SHIP=publish' \
  'PLANNER=plan-feature' 'BRANCH=feature/'

run sync --against REF
ok_lines "02b: sync row fidelity (plan/plan-reconcile/sync/, anchor accepted)" \
  'TYPE=sync' 'PIPELINE=plan' 'PLANNER=plan-reconcile' 'BRANCH=sync/' \
  'AGAINST_COUNT=1' 'AGAINST_1=REF'

run hotfix
ok_lines "02c: hotfix row fidelity (PLANNER=plan-bugfix+minimal-scope)" \
  'TYPE=hotfix' 'PLANNER=plan-bugfix+minimal-scope' 'BRANCH=hotfix/'

# --- Case 02f: live row fidelity (contracts/l1.md §Round 3) -----------------
run live
ok_lines "02f: live row fidelity (live/auto/publish/plan-live/feature//REWORK=2)" \
  'TYPE=live' 'PIPELINE=live' 'EXPLORE=auto' 'SHIP=publish' \
  'PLANNER=plan-live' 'BRANCH=feature/' 'REWORK=2'

# --- Case 03: map emits no PLANNER= and no BRANCH= -------------------------
run map
no_lines "03: map emits no PLANNER= and no BRANCH= line (omitted, not empty)" \
  '^PLANNER=' '^BRANCH='

# --- Case 04: analyze carries BRANCH=docs/ with SHIP=publish ---------------
run analyze
ok_lines "04: analyze emits BRANCH=docs/ alongside SHIP=publish (RIGOR_PR=low)" \
  'TYPE=analyze' 'BRANCH=docs/' 'SHIP=publish' 'RIGOR_PR=low'

# --- Case 05: malformed rows -> E15, exit 1, no partial KEY=value block ----
f05a=$(new_scratch)
cat >"$f05a/workflows.yaml" <<'YAML'
types:
  feature:   {pipeline: build,  explore: auto, rigor: low, against: forbid, ship: publish, planner: plan-feature, branch: feature/}
  broken:    not-a-flow-map
default_type: feature
YAML
run --yaml "$f05a/workflows.yaml" broken
err_case "05a: malformed row (not a flow map) -> exit 1, 'malformed' + type name" \
  'malformed' 'broken'
if no_key_block; then
  pass "05a2: malformed row (not a flow map) prints no partial KEY=value block"
else
  fail "05a2: malformed row (not a flow map) prints no partial KEY=value block" "$(ctx)"
fi

f05b=$(new_scratch)
cat >"$f05b/workflows.yaml" <<'YAML'
types:
  feature:   {pipeline: build,  explore: auto, rigor: low, against: forbid, ship: publish, planner: plan-feature, branch: feature/}
  broken:    {pipeline: build, explore: auto, rigor: low, ship: publish}
default_type: feature
YAML
run --yaml "$f05b/workflows.yaml" broken
err_case "05b: malformed row (missing required key 'against') -> exit 1, 'malformed' + type name" \
  'malformed' 'broken'
if no_key_block; then
  pass "05b2: malformed row (missing required key) prints no partial KEY=value block"
else
  fail "05b2: malformed row (missing required key) prints no partial KEY=value block" "$(ctx)"
fi

f05c=$(new_scratch)
cat >"$f05c/workflows.yaml" <<'YAML'
types:
  feature:   {pipeline: build,  explore: auto, rigor: low, against: forbid, ship: publish, planner: plan-feature, branch: feature/}
  broken:    {pipeline: bogus, explore: auto, rigor: low, against: forbid, ship: publish}
default_type: feature
YAML
run --yaml "$f05c/workflows.yaml" broken
err_case "05c: malformed row (out-of-vocabulary cell) -> exit 1, 'malformed' + type name" \
  'malformed' 'broken'
if no_key_block; then
  pass "05c2: malformed row (out-of-vocabulary cell) prints no partial KEY=value block"
else
  fail "05c2: malformed row (out-of-vocabulary cell) prints no partial KEY=value block" "$(ctx)"
fi

# --- Case 06: missing / unreadable --yaml path -> E14 ----------------------
f06=$(new_scratch)
run --yaml "$f06/does-not-exist.yaml" feature
err_case "06: missing --yaml path -> exit 1, 'cannot read' + the given path" \
  'cannot read' "$f06/does-not-exist.yaml"

# ===========================================================================
# TYPE ALIASES (§2.2)
# ===========================================================================

# --- Case 07: alias -> canonical TYPE= -------------------------------------
run bug
ok_lines "07a: alias 'bug' resolves to canonical TYPE=bugfix" 'TYPE=bugfix'
run debug
ok_lines "07b: alias 'debug' resolves to canonical TYPE=diagnose" 'TYPE=diagnose'
run triage
ok_lines "07c: alias 'triage' resolves to canonical TYPE=diagnose" 'TYPE=diagnose'
run doc
ok_lines "07d: alias 'doc' resolves to canonical TYPE=document" 'TYPE=document'

# --- Case 08: map is its own type, not an alias of document ----------------
run map
ok_lines "08a: map resolves to TYPE=map, PIPELINE=report (no longer aliases document)" \
  'TYPE=map' 'PIPELINE=report'
no_lines "08b: map does not resolve to document" '^TYPE=document'

# --- Case 09: unknown type -> E2 -------------------------------------------
run notatype
err_case "09: unknown type -> exit 1, 'unknown type' + the offending name" \
  'unknown type' 'notatype'

# --- Case 10: no type given -> default_type, exit 0, no warning ------------
run
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE"
line 'TYPE=feature' || bad="$bad missing-line:[TYPE=feature]"
if err_sub 'warning'; then bad="$bad unexpected-warning"; fi
if [ -z "$bad" ]; then
  pass "10: no type given -> TYPE=feature (default_type), exit 0, no warning on stderr"
else
  fail "10: no type given -> TYPE=feature (default_type), exit 0, no warning on stderr" \
    "$bad; $(ctx)"
fi

# ===========================================================================
# FLAG ALIASES AND BRACKETED PREFIXES (§3.3)
# ===========================================================================

# --- Case 11: -r / --rig / --rigo / --rigor all resolve to the rigor axis --
run feature -r med;      r11a="$OUT"; c11a="$CODE"
run feature --rig med;   r11b="$OUT"; c11b="$CODE"
run feature --rigo med;  r11c="$OUT"; c11c="$CODE"
run feature --rigor med; r11d="$OUT"; c11d="$CODE"
if [ "$c11a" -eq 0 ] && [ "$c11b" -eq 0 ] && [ "$c11c" -eq 0 ] && [ "$c11d" -eq 0 ] \
   && [ "$r11a" = "$r11d" ] && [ "$r11b" = "$r11d" ] && [ "$r11c" = "$r11d" ] \
   && printf '%s\n' "$r11d" | grep -qxF 'RIGOR_EXPLORE=med'; then
  pass "11: -r / --rig / --rigo / --rigor med all resolve to rigor with identical stdout"
else
  fail "11: -r / --rig / --rigo / --rigor med all resolve to rigor with identical stdout" \
    "codes=$c11a/$c11b/$c11c/$c11d a=[$r11a] b=[$r11b] c=[$r11c] d=[$r11d]"
fi

# --- Case 12: --r is REJECTED as an unknown flag (below --rig minimum) -----
run feature --r med
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
err_sub 'unknown flag' || bad="$bad missing-stderr:[unknown flag]"
if ! err_tok '--r'; then bad="$bad missing-token:[--r]"; fi
if out_re '^RIGOR_'; then bad="$bad resolved-to-rigor"; fi
if [ -z "$bad" ]; then
  pass "12: '--r med' rejected as unknown flag (E1), exit 1, not resolved to rigor"
else
  fail "12: '--r med' rejected as unknown flag (E1), exit 1, not resolved to rigor" \
    "$bad; $(ctx)"
fi

# --- Case 13: -a and --against both populate AGAINST_* ---------------------
run bugfix -a SHORT
ok_lines "13a: -a populates AGAINST_COUNT/AGAINST_1" 'AGAINST_COUNT=1' 'AGAINST_1=SHORT'
run bugfix --against LONG
ok_lines "13b: --against populates AGAINST_COUNT/AGAINST_1" 'AGAINST_COUNT=1' 'AGAINST_1=LONG'

# --- Case 14: --p rejected; --pl -> --plan; --pi -> --pipeline -------------
run feature --p somevalue
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
err_sub 'unknown flag' || bad="$bad missing-stderr:[unknown flag]"
if ! err_tok '--p'; then bad="$bad missing-token:[--p]"; fi
if [ -z "$bad" ]; then
  pass "14a: '--p' rejected as unknown flag (ambiguous and below both minimums)"
else
  fail "14a: '--p' rejected as unknown flag (ambiguous and below both minimums)" "$bad; $(ctx)"
fi

run feature --pl /no/such/plan.md
ok_lines "14b: '--pl' resolves to --plan (PLAN= emitted on a build pipeline)" \
  'PLAN=/no/such/plan.md'

run map --pi build
err_case "14c: '--pi' resolves to --pipeline and is refused as locked (E3)" \
  '--pipeline' 'locked' 'map'

# --- Case 15: stale anchor-style '-r origin/main' fails on rigor vocabulary -
run feature -r origin/main
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
for s in 'rigor' 'origin/main' 'low' 'med' 'high'; do
  err_sub "$s" || bad="$bad missing-stderr:[$s]"
done
if out_re '^AGAINST_'; then bad="$bad leaked-AGAINST"; fi
if [ -z "$bad" ]; then
  pass "15: stale '-r origin/main' fails on the rigor value vocabulary (E7), never accepted as an anchor"
else
  fail "15: stale '-r origin/main' fails on the rigor value vocabulary (E7), never accepted as an anchor" \
    "$bad; $(ctx)"
fi

# --- Case 16: '--rigor=med' and '-rmed' are unknown flags ------------------
run feature --rigor=med
err_case "16a: '--rigor=med' (attached-value form) rejected as unknown flag" \
  'unknown flag' '--rigor=med'
run feature -rmed
err_case "16b: '-rmed' (bundled short form) rejected as unknown flag" \
  'unknown flag' '-rmed'

# ===========================================================================
# RIGOR RESOLUTION (§3.8 steps 1-3)
# ===========================================================================

# --- Case 17: scalar expansion over a build pipeline -----------------------
run feature --rigor med
ok_lines "17: 'feature --rigor med' sets all four phases to med" \
  'RIGOR_EXPLORE=med' 'RIGOR_PLAN=med' 'RIGOR_CODE=med' 'RIGOR_PR=med'

# --- Case 18: per-phase patch preserves the row default --------------------
run document --rigor pr:high
ok_lines "18: 'document --rigor pr:high' keeps the row's RIGOR_EXPLORE=med and sets RIGOR_PR=high" \
  'RIGOR_EXPLORE=med' 'RIGOR_PR=high'

# --- Case 19: an unmentioned phase never falls to low by fiat --------------
run feature --rigor explore:high
ok_lines "19a: 'feature --rigor explore:high' patches explore, leaves plan/code/pr at row defaults" \
  'RIGOR_EXPLORE=high' 'RIGOR_PLAN=low' 'RIGOR_CODE=low' 'RIGOR_PR=low'
run sync --against REF --rigor pr:high
ok_lines "19b: 'sync --rigor pr:high' leaves RIGOR_EXPLORE=med (row map-form default preserved)" \
  'RIGOR_EXPLORE=med' 'RIGOR_PR=high'

# --- Case 20: mixed form, scalar plus patch --------------------------------
run feature --rigor med,explore:high
ok_lines "20: 'feature --rigor med,explore:high' -> explore high, plan/code/pr med" \
  'RIGOR_EXPLORE=high' 'RIGOR_PLAN=med' 'RIGOR_CODE=med' 'RIGOR_PR=med'

# --- Case 21: scalar-then-patch is ALGORITHM-step order, not argv order ----
# §3.8 step 2 (scalar expansion) always runs before step 3 (per-phase patch),
# regardless of where the scalar sits in the spec string. Putting the patch
# BEFORE the scalar in argv (as here) must NOT wipe the patch: step 2 still
# expands the scalar 'med' to all four phases first, then step 3 still patches
# explore to 'high' on top of it. The normative worked example (§3.8 step 2)
# and case 21 itself both give this exact spec resolving to explore=high with
# plan/code/pr all med -- identical to case 20's 'med,explore:high', which
# proves position-independence: whichever order the scalar and the patch
# appear in argv, the resolved profile must be the same.
run feature --rigor explore:high,med
ok_lines "21: 'feature --rigor explore:high,med' -> explore high, plan/code/pr med (algorithm-step order; must not wipe the patch)" \
  'RIGOR_EXPLORE=high' 'RIGOR_PLAN=med' 'RIGOR_CODE=med' 'RIGOR_PR=med'

# --- Case 22: row forms with no --rigor ------------------------------------
run analyze
ok_lines "22a: 'analyze' with no --rigor -> RIGOR_EXPLORE=med (row map form)" 'RIGOR_EXPLORE=med'
run feature
ok_lines "22b: 'feature' with no --rigor -> all four low (row scalar form)" \
  'RIGOR_EXPLORE=low' 'RIGOR_PLAN=low' 'RIGOR_CODE=low' 'RIGOR_PR=low'

# --- Case 23: code is low on every shipped row that HAS a code phase -------
for t in feature bugfix hotfix migration rework diagnose sync live; do
  case "$t" in
    rework|sync) run "$t" --against REF ;;
    *)           run "$t" ;;
  esac
  ok_lines "23/$t: RIGOR_CODE=low with no override" 'RIGOR_CODE=low'
done
for t in map analyze document; do
  run "$t"
  no_lines "23/$t: no RIGOR_CODE= line (the pipeline has no code phase)" '^RIGOR_CODE='
done

# --- Case 24: invalid rigor value (E7) and invalid rigor phase (E8) --------
run feature --rigor bogus
err_case "24a: invalid rigor value -> E7 (rigor, the value, low, med, high)" \
  'rigor' 'bogus' 'low' 'med' 'high'
run feature --rigor bogusphase:high
err_case "24b: invalid rigor phase -> E8 (rigor, the phase, explore, plan, code, pr)" \
  'rigor' 'bogusphase' 'explore' 'plan' 'code' 'pr'

# ===========================================================================
# ABSENT-PHASE DROPPING AND THE D2 WARNING (§3.7, §3.8)
# ===========================================================================

# --- Case 25: f(pipeline, ship) dropping, silent path ----------------------
run map
ok_lines "25a: map (report+chat) emits RIGOR_EXPLORE=" 'RIGOR_EXPLORE=low'
no_lines "25b: map emits no RIGOR_PLAN=/RIGOR_CODE=/RIGOR_PR= lines" \
  '^RIGOR_PLAN=' '^RIGOR_CODE=' '^RIGOR_PR='
run document
ok_lines "25c: document (docs) emits RIGOR_EXPLORE= and RIGOR_PR=" \
  'RIGOR_EXPLORE=med' 'RIGOR_PR=low'
no_lines "25d: document emits no RIGOR_PLAN=/RIGOR_CODE= lines" \
  '^RIGOR_PLAN=' '^RIGOR_CODE='

# --- Case 26: scalar expansion is SILENT (no warning flood on map) ---------
run map --rigor med
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0)"
line 'RIGOR_EXPLORE=med' || bad="$bad missing-line:[RIGOR_EXPLORE=med]"
for k in '^RIGOR_PLAN=' '^RIGOR_CODE=' '^RIGOR_PR='; do
  if out_re "$k"; then bad="$bad unexpected:[$k]"; fi
done
if err_sub 'warning'; then bad="$bad unexpected-warning"; fi
if [ -z "$bad" ]; then
  pass "26: 'map --rigor med' -> exit 0, RIGOR_EXPLORE=med only, and NO warning on stderr"
else
  fail "26: 'map --rigor med' -> exit 0, RIGOR_EXPLORE=med only, and NO warning on stderr" \
    "$bad; $(ctx)"
fi

# --- Case 27: D2, user-typed. Warning AND exit 0, asserted as a pair -------
run map --rigor pr:high
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0 - a non-zero exit for D2 is forbidden)"
err_sub 'warning' || bad="$bad missing-stderr:[warning]"
err_tok 'pr' || bad="$bad warning-does-not-name-phase:[pr]"
err_tok 'map' || bad="$bad warning-does-not-name-type:[map]"
if [ -z "$bad" ]; then
  pass "27a: 'map --rigor pr:high' -> warning naming both 'pr' and 'map' AND exit status 0 (the pair)"
else
  fail "27a: 'map --rigor pr:high' -> warning naming both 'pr' and 'map' AND exit status 0 (the pair)" \
    "$bad; $(ctx)"
fi
ok_lines "27b: 'map --rigor pr:high' still prints the remaining axes" \
  'TYPE=map' 'PIPELINE=report' 'EXPLORE=auto' 'RIGOR_EXPLORE=low' 'SHIP=chat' 'AGAINST_COUNT=0'
no_lines "27c: 'map --rigor pr:high' drops the named absent phase (no RIGOR_PR= line)" '^RIGOR_PR='

# --- Case 28: D2, row map-form cell. Same pair, via a fixture --------------
f28=$(new_scratch)
cat >"$f28/workflows.yaml" <<'YAML'
types:
  feature:   {pipeline: build,  explore: auto, rigor: low, against: forbid, ship: publish, planner: plan-feature, branch: feature/}
  probe:     {pipeline: report, explore: auto, rigor: {explore: med, pr: high}, against: forbid, ship: chat}
default_type: feature
YAML
run --yaml "$f28/workflows.yaml" probe
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0 - a non-zero exit for D2 is forbidden)"
err_sub 'warning' || bad="$bad missing-stderr:[warning]"
err_tok 'pr' || bad="$bad warning-does-not-name-phase:[pr]"
err_tok 'probe' || bad="$bad warning-does-not-name-type:[probe]"
if [ -z "$bad" ]; then
  pass "28a: row map-form cell naming an absent phase -> warning naming 'pr' and 'probe' AND exit 0"
else
  fail "28a: row map-form cell naming an absent phase -> warning naming 'pr' and 'probe' AND exit 0" \
    "$bad; $(ctx)"
fi
ok_lines "28b: row map-form D2 still prints the remaining axes" \
  'TYPE=probe' 'PIPELINE=report' 'RIGOR_EXPLORE=med' 'SHIP=chat'
no_lines "28c: row map-form D2 drops the absent phase (no RIGOR_PR= line)" '^RIGOR_PR='

# --- Case 29: analyze's ship defaults to publish (RIGOR_PR=low) ------------
run analyze
ok_lines "29a: bare 'analyze' (report+publish) carries RIGOR_PR=low" \
  'SHIP=publish' 'RIGOR_PR=low'
run analyze --rigor pr:high
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE"
line 'RIGOR_PR=high' || bad="$bad missing-line:[RIGOR_PR=high]"
if err_sub 'warning'; then bad="$bad unexpected-warning"; fi
if [ -z "$bad" ]; then
  pass "29b: 'analyze --rigor pr:high' -> RIGOR_PR=high with NO warning"
else
  fail "29b: 'analyze --rigor pr:high' -> RIGOR_PR=high with NO warning" \
    "$bad; $(ctx)"
fi
run map --rigor pr:high
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0 - a non-zero exit for D2 is forbidden)"
err_sub 'warning' || bad="$bad missing-stderr:[warning]"
err_tok 'pr' || bad="$bad warning-does-not-name-phase:[pr]"
err_tok 'map' || bad="$bad warning-does-not-name-type:[map]"
if [ -z "$bad" ]; then
  pass "29c: 'map --rigor pr:high' still warns on stderr and still exits 0 (D2 precedent survives)"
else
  fail "29c: 'map --rigor pr:high' still warns on stderr and still exits 0 (D2 precedent survives)" \
    "$bad; $(ctx)"
fi

# ===========================================================================
# CONSTRAINT VIOLATIONS (§3.5, §3.9)
# ===========================================================================

# --- Case 30: against: forbid + anchors -> E4 ------------------------------
run map -a abc123
err_case "30: 'map -a abc123' (against: forbid) -> E4 (type name, --against, did you mean)" \
  'map' '--against' 'did you mean'

# --- Case 31: against: require + no anchors -> E5 --------------------------
run rework
err_case "31a: 'rework' with no anchors -> E5 (type name, requires at least one anchor, --against)" \
  'rework' 'requires at least one anchor' '--against'
run sync
err_case "31b: 'sync' with no anchors -> E5 (type name, requires at least one anchor, --against)" \
  'sync' 'requires at least one anchor' '--against'

# --- Case 32: against: optional, with and without ---------------------------
run bugfix
ok_lines "32a: 'bugfix' (optional) with no anchors -> exit 0, AGAINST_COUNT=0" 'AGAINST_COUNT=0'
run bugfix -a REF
ok_lines "32b: 'bugfix' (optional) with an anchor -> exit 0, AGAINST_COUNT=1" 'AGAINST_COUNT=1'
run diagnose
ok_lines "32c: 'diagnose' (optional) with no anchors -> exit 0, AGAINST_COUNT=0" 'AGAINST_COUNT=0'
run diagnose --against REF
ok_lines "32d: 'diagnose' (optional) with an anchor -> exit 0, AGAINST_COUNT=1" 'AGAINST_COUNT=1'
run feature
ok_lines "32e: 'feature' (optional) with no anchors -> exit 0, AGAINST_COUNT=0" 'AGAINST_COUNT=0'
run feature -a PROJ-123
ok_lines "32f: 'feature -a PROJ-123' (optional) with an anchor -> exit 0, AGAINST_COUNT=1, AGAINST_1=PROJ-123" \
  'AGAINST_COUNT=1' 'AGAINST_1=PROJ-123'
run migration
ok_lines "32g: 'migration' (optional) with no anchors -> exit 0, AGAINST_COUNT=0" 'AGAINST_COUNT=0'
run migration --against abc123,def456
ok_lines "32h: 'migration --against abc123,def456' (optional) -> exit 0, AGAINST_COUNT=2, order preserved" \
  'AGAINST_COUNT=2' 'AGAINST_1=abc123' 'AGAINST_2=def456'

# --- Case 33: --pipeline is locked -> E3 -----------------------------------
run map --pipeline build
err_case "33: 'map --pipeline build' -> E3 (--pipeline, locked, resolved type name)" \
  '--pipeline' 'locked' 'map'

# --- Case 34: --plan placement ---------------------------------------------
# E6 on every non-build pipeline. sync is `against: require`, so it is given an
# anchor to isolate E6 from E5.
run map --plan /no/such/plan.md
err_case "34a: '--plan' on map -> E6 (--plan, type name, pipeline: build)" \
  '--plan' 'map' 'pipeline: build'
run analyze --plan /no/such/plan.md
err_case "34b: '--plan' on analyze -> E6" '--plan' 'analyze' 'pipeline: build'
run document --plan /no/such/plan.md
err_case "34c: '--plan' on document -> E6" '--plan' 'document' 'pipeline: build'
run diagnose --plan /no/such/plan.md
err_case "34d: '--plan' on diagnose -> E6" '--plan' 'diagnose' 'pipeline: build'
run sync --against REF --plan /no/such/plan.md
err_case "34e: '--plan' on sync -> E6" '--plan' 'sync' 'pipeline: build'

run live --plan /no/such/plan.md
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
err_sub '--plan' || bad="$bad missing-stderr:[--plan]"
if ! err_tok 'live'; then bad="$bad missing-token:[live]"; fi
err_sub 'pipeline: build' || bad="$bad missing-stderr:[pipeline: build]"
if [ -z "$bad" ]; then
  pass "34f: '--plan' on live -> E6 (--plan, live, pipeline: build)"
else
  fail "34f: '--plan' on live -> E6 (--plan, live, pipeline: build)" "$bad; $(ctx)"
fi

# Accepted on every build pipeline, path emitted AS GIVEN, no existence check.
for t in feature bugfix hotfix migration rework; do
  case "$t" in
    rework) run "$t" --against REF --plan /deliberately/nonexistent/plan.md ;;
    *)      run "$t" --plan /deliberately/nonexistent/plan.md ;;
  esac
  ok_lines "34/$t: '--plan' accepted on a build pipeline, PLAN= emitted as given, no existence check" \
    "TYPE=$t" 'PLAN=/deliberately/nonexistent/plan.md'
done

# --- Case 35: unknown flags -> E1 ------------------------------------------
run feature -x
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
err_sub 'unknown flag' || bad="$bad missing-stderr:[unknown flag]"
err_tok '-x' || bad="$bad missing-token:[-x]"
if [ -z "$bad" ]; then
  pass "35a: '-x' -> E1 (unknown flag + the offending token)"
else
  fail "35a: '-x' -> E1 (unknown flag + the offending token)" "$bad; $(ctx)"
fi
run feature --nope
err_case "35b: '--nope' -> E1 (unknown flag + the offending token)" 'unknown flag' '--nope'

# --- Case 36: --explore value vocabulary; --ship is now locked (E3) --------
run feature --explore bogus
err_case "36a: '--explore bogus' -> E9 (explore, the value, shallow, deep, auto)" \
  'explore' 'bogus' 'shallow' 'deep' 'auto'
run feature --ship bogus
err_case "36b: '--ship bogus' -> not in VOCAB_SHIP, stderr names ship value/bogus/not one of chat, publish" \
  'ship value' 'bogus' 'is not one of chat, publish'

# --- Case 37: value-taking flag given no value -> E11 ----------------------
run feature --rigor
err_case "37a: '--rigor' at end of argv -> E11 (missing value + the flag)" \
  'missing value' '--rigor'
run feature --explore --ship publish
err_case "37b: '--explore' followed by another flag -> E11 (missing value + the flag)" \
  'missing value' '--explore'

# --- Case 38: empty anchor item -> E12 -------------------------------------
run bugfix --against 'a,,b'
err_case "38a: '--against a,,b' -> E12 (empty anchor + --against)" 'empty anchor' '--against'
run bugfix --against ','
err_case "38b: '--against ,' (bare comma) -> E12" 'empty anchor' '--against'
run bugfix --against ''
err_case "38c: '--against \"\"' (empty string) -> E12" 'empty anchor' '--against'

# --- Case 39: positional argument arity -> E13 -----------------------------
run feature extra
err_case "39a: two positional arguments -> E13 ('unexpected argument')" 'unexpected argument'
run feature --type map
err_case "39b: positional and --type disagree -> E13 ('conflicting')" 'conflicting'
run feature --type feature
ok_lines "39c: positional and --type agree -> accepted, exit 0" 'TYPE=feature'

# ===========================================================================
# ANCHOR PASS-THROUGH (§3.6)
# ===========================================================================

# --- Case 40: argv order preserved across repeats and comma splits ---------
run sync -a A,B -a C
ok_lines "40: 'sync -a A,B -a C' -> AGAINST_COUNT=3 with argv order preserved, values raw" \
  'AGAINST_COUNT=3' 'AGAINST_1=A' 'AGAINST_2=B' 'AGAINST_3=C'

# --- Case 41: no anchors -> AGAINST_COUNT=0 and no AGAINST_1= --------------
run feature
ok_lines "41a: 'feature' with no anchors -> AGAINST_COUNT=0" 'AGAINST_COUNT=0'
no_lines "41b: 'feature' with no anchors -> no AGAINST_1= line" '^AGAINST_1='

# ===========================================================================
# PURITY (§3.10, B12)
# ===========================================================================

# --- Case 42: identical output from an unrelated working directory ---------
run_in "$REPO_ROOT" feature
r42_repo="$OUT"
c42_repo="$CODE"
d42=$(new_scratch)
run_in "$d42" feature
r42_else="$OUT"
c42_else="$CODE"
if [ "$c42_repo" -eq 0 ] && [ "$c42_else" -eq 0 ] && [ "$r42_repo" = "$r42_else" ]; then
  pass "42a: identical output from an unrelated working directory (table found BASH_SOURCE-relative)"
else
  fail "42a: identical output from an unrelated working directory (table found BASH_SOURCE-relative)" \
    "repo_code=$c42_repo else_code=$c42_else repo=[$r42_repo] else=[$r42_else]"
fi
if [ -z "$(ls -A "$d42")" ]; then
  pass "42b: the script writes nothing into the working directory it is run from"
else
  fail "42b: the script writes nothing into the working directory it is run from" \
    "leftovers=[$(ls -A "$d42")]"
fi

# ===========================================================================
# STDOUT BLOCK SHAPE (§3.6 - exact contents and exact ORDER)
# ===========================================================================

# --- Case 43: the whole KEY=value block, verbatim and in order -------------
run feature
expected_feature='TYPE=feature
PIPELINE=build
EXPLORE=auto
RIGOR_EXPLORE=low
RIGOR_PLAN=low
RIGOR_CODE=low
RIGOR_PR=low
AGAINST_COUNT=0
SHIP=publish
REWORK=3
PLANNER=plan-feature
BRANCH=feature/'
if [ "$CODE" -eq 0 ] && [ "$OUT" = "$expected_feature" ]; then
  pass "43a: 'feature' stdout is exactly §3.6's block, in order, with nothing else"
else
  fail "43a: 'feature' stdout is exactly §3.6's block, in order, with nothing else" \
    "code=$CODE out=[$OUT] want=[$expected_feature]"
fi

run map
expected_map='TYPE=map
PIPELINE=report
EXPLORE=auto
RIGOR_EXPLORE=low
AGAINST_COUNT=0
SHIP=chat'
if [ "$CODE" -eq 0 ] && [ "$OUT" = "$expected_map" ]; then
  pass "43b: 'map' stdout is exactly §3.6's block - dropped phases, PLANNER and BRANCH all absent"
else
  fail "43b: 'map' stdout is exactly §3.6's block - dropped phases, PLANNER and BRANCH all absent" \
    "code=$CODE out=[$OUT] want=[$expected_map]"
fi
no_lines "43b2: 'map' emits no REWORK= line (map's row carries no rework: cell)" '^REWORK='

run analyze
expected_analyze='TYPE=analyze
PIPELINE=report
EXPLORE=deep
RIGOR_EXPLORE=med
RIGOR_PR=low
AGAINST_COUNT=0
SHIP=publish
BRANCH=docs/'
if [ "$CODE" -eq 0 ] && [ "$OUT" = "$expected_analyze" ]; then
  pass "43c: 'analyze' stdout is exactly contracts/l1.md §4.3's block - SHIP=publish, RIGOR_PR=low, no RIGOR_PLAN/RIGOR_CODE/PLANNER"
else
  fail "43c: 'analyze' stdout is exactly contracts/l1.md §4.3's block - SHIP=publish, RIGOR_PR=low, no RIGOR_PLAN/RIGOR_CODE/PLANNER" \
    "code=$CODE out=[$OUT] want=[$expected_analyze]"
fi
no_lines "43c2: 'analyze' emits no REWORK= line (analyze's row carries no rework: cell)" '^REWORK='

run live
expected_live='TYPE=live
PIPELINE=live
EXPLORE=auto
RIGOR_EXPLORE=low
RIGOR_PLAN=low
RIGOR_CODE=low
RIGOR_PR=low
AGAINST_COUNT=0
SHIP=publish
REWORK=2
PLANNER=plan-live
BRANCH=feature/'
if [ "$CODE" -eq 0 ] && [ "$OUT" = "$expected_live" ]; then
  pass "43d: 'live' stdout is exactly contracts/l1.md §Round 3's block, in order, with nothing else"
else
  fail "43d: 'live' stdout is exactly contracts/l1.md §Round 3's block, in order, with nothing else" \
    "code=$CODE out=[$OUT] want=[$expected_live]"
fi

# ===========================================================================
# PARSE ROBUSTNESS - NO SILENT WRONG ANSWERS (§4.2 cases 43-45)
# ===========================================================================

# --- Case R43: the E2 type list is DERIVED from the table, not hardcoded ---
# Fixture has exactly one row, 'solo'. An unknown-type error must mention
# 'solo' (the only row the table actually has) and must NOT mention any of
# the ten shipped type names - those would only appear via a hardcoded list.
fR43=$(new_scratch)
cat >"$fR43/workflows.yaml" <<'YAML'
types:
  solo: {pipeline: build, explore: auto, rigor: low, against: forbid, ship: publish}
default_type: solo
YAML
run --yaml "$fR43/workflows.yaml" nosuch
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
err_sub 'unknown type' || bad="$bad missing-stderr:[unknown type]"
err_sub 'nosuch' || bad="$bad missing-stderr:[nosuch]"
err_sub 'solo' || bad="$bad missing-stderr:[solo]"
for other in feature bugfix hotfix migration rework diagnose map analyze document sync; do
  if err_sub "$other"; then bad="$bad unexpected-hardcoded-type-name:[$other]"; fi
done
if [ -z "$bad" ]; then
  pass "R43: E2's type list is derived from the parsed table (mentions 'solo', not any shipped type name)"
else
  fail "R43: E2's type list is derived from the parsed table (mentions 'solo', not any shipped type name)" \
    "$bad; $(ctx)"
fi

# --- Case R44: no silent empty axes - empty table and garbage table --------
# Status-only would pass a silently broken parser (mawk rejects '--'); assert
# stdout is explicitly EMPTY, not just that the exit code is 1.
fR44a=$(new_scratch)
: >"$fR44a/workflows.yaml"
run --yaml "$fR44a/workflows.yaml" feature
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
[ -n "$ERR" ] || bad="$bad empty-stderr(want a loud message)"
[ -z "$OUT" ] || bad="$bad nonempty-stdout:[$OUT]"
if [ -z "$bad" ]; then
  pass "R44a: empty table file -> exit 1, loud stderr, NOTHING on stdout"
else
  fail "R44a: empty table file -> exit 1, loud stderr, NOTHING on stdout" "$bad; $(ctx)"
fi

fR44b=$(new_scratch)
cat >"$fR44b/workflows.yaml" <<'GARBAGE'
this is not yaml at all {{{ ]][[ ::: %%% ---
GARBAGE
run --yaml "$fR44b/workflows.yaml" feature
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
[ -n "$ERR" ] || bad="$bad empty-stderr(want a loud message)"
[ -z "$OUT" ] || bad="$bad nonempty-stdout:[$OUT]"
if [ -z "$bad" ]; then
  pass "R44b: garbage (non-yaml) table file -> exit 1, loud stderr, NOTHING on stdout"
else
  fail "R44b: garbage (non-yaml) table file -> exit 1, loud stderr, NOTHING on stdout" "$bad; $(ctx)"
fi

# --- Case R45: absent type (E2) vs unparseable row (E15) are distinguishable
# One fixture: a valid 'feature' row plus an unparseable 'broken' row. A type
# name absent from the table (E2) and a row present-but-unparseable (E15)
# must produce messages that are NOT interchangeable.
fR45=$(new_scratch)
cat >"$fR45/workflows.yaml" <<'YAML'
types:
  feature:   {pipeline: build, explore: auto, rigor: low, against: forbid, ship: publish, planner: plan-feature, branch: feature/}
  broken:    not-a-flow-map
default_type: feature
YAML

run --yaml "$fR45/workflows.yaml" ghost
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
err_sub 'unknown type' || bad="$bad missing-stderr:[unknown type]"
err_sub 'ghost' || bad="$bad missing-stderr:[ghost]"
if err_sub 'malformed'; then bad="$bad E2-message-must-not-say-malformed"; fi
if [ -z "$bad" ]; then
  pass "R45a: absent type name -> E2 substrings ('unknown type' + name), never 'malformed'"
else
  fail "R45a: absent type name -> E2 substrings ('unknown type' + name), never 'malformed'" "$bad; $(ctx)"
fi

run --yaml "$fR45/workflows.yaml" broken
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
err_sub 'malformed' || bad="$bad missing-stderr:[malformed]"
err_sub 'broken' || bad="$bad missing-stderr:[broken]"
if err_sub 'unknown type'; then bad="$bad E15-message-must-not-say-unknown-type"; fi
if [ -z "$bad" ]; then
  pass "R45b: unparseable row -> E15 substrings ('malformed' + type name), never 'unknown type'"
else
  fail "R45b: unparseable row -> E15 substrings ('malformed' + type name), never 'unknown type'" "$bad; $(ctx)"
fi

# ===========================================================================
# LOCKED --SHIP AXIS (contracts/l1.md §3.3, crits 6-12)
# ===========================================================================

# --- Case 44: feature --ship chat -> illegal override, not available -------
run feature --ship chat
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
for s in 'ship value' 'chat' 'not available' 'feature' 'publish'; do
  err_sub "$s" || bad="$bad missing-stderr:[$s]"
done
if ! no_key_block; then bad="$bad unexpected-partial-stdout:[$OUT]"; fi
if [ -z "$bad" ]; then
  pass "44: 'feature --ship chat' -> illegal override (exit 1), stderr names ship value/chat/not available/feature/publish, nothing on stdout (the §A1 regression: a build no longer ships chat)"
else
  fail "44: 'feature --ship chat' -> illegal override (exit 1), stderr names ship value/chat/not available/feature/publish, nothing on stdout (the §A1 regression: a build no longer ships chat)" \
    "$bad; $(ctx)"
fi

# --- Case 45: analyze --ship publish -> warn-and-continue, already the default
run analyze --ship publish
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0)"
line 'SHIP=publish' || bad="$bad missing-line:[SHIP=publish]"
err_sub '--ship' || bad="$bad missing-stderr:[--ship]"
err_sub 'already the default' || bad="$bad missing-stderr:[already the default]"
if [ -z "$bad" ]; then
  pass "45: 'analyze --ship publish' -> exit 0 AND SHIP=publish on stdout AND a stderr warning containing '--ship'/'already the default' (the triple)"
else
  fail "45: 'analyze --ship publish' -> exit 0 AND SHIP=publish on stdout AND a stderr warning containing '--ship'/'already the default' (the triple)" \
    "$bad; $(ctx)"
fi

# --- Case 46: map --sh chat -> the short form resolves; chat is map's default
run map --sh chat
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0)"
err_sub '--ship' || bad="$bad missing-stderr:[--ship]"
err_sub 'already the default' || bad="$bad missing-stderr:[already the default]"
if err_sub 'unknown flag'; then bad="$bad unexpected:[unknown flag]"; fi
if [ -z "$bad" ]; then
  pass "46a: 'map --sh chat' -> the short form resolves, chat is map's default -> warn-and-continue (exit 0, '--ship'/'already the default' warning), never 'unknown flag'"
else
  fail "46a: 'map --sh chat' -> the short form resolves, chat is map's default -> warn-and-continue (exit 0, '--ship'/'already the default' warning), never 'unknown flag'" \
    "$bad; $(ctx)"
fi
ok_lines "46b: 'map --sh chat' still prints the full block (warn-and-continue, not dropped)" \
  'TYPE=map' 'PIPELINE=report' 'SHIP=chat'

# --- Case 47: --ship with no value -> E11, unchanged -----------------------
run feature --ship
err_case "47: 'feature --ship' at end of argv -> E11 (missing value + --ship), unchanged by the lock" \
  'missing value' '--ship'

# --- Case 48: --shp is an unknown flag, not --ship/--sh --------------------
run feature --shp publish
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
err_sub 'unknown flag' || bad="$bad missing-stderr:[unknown flag]"
err_tok '--shp' || bad="$bad missing-token:[--shp]"
if err_tok '--ship'; then bad="$bad unexpected-token:[--ship]"; fi
if err_tok '--sh'; then bad="$bad unexpected-token:[--sh]"; fi
if [ -z "$bad" ]; then
  pass "48: 'feature --shp publish' -> E1 (unknown flag + --shp), stderr names neither --ship nor --sh"
else
  fail "48: 'feature --shp publish' -> E1 (unknown flag + --shp), stderr names neither --ship nor --sh" \
    "$bad; $(ctx)"
fi

# --- Case 49: illegal-override error's type lists are DERIVED, via fixture -
f49=$(new_scratch)
cat >"$f49/workflows.yaml" <<'YAML'
types:
  alpha: {pipeline: report, explore: auto, rigor: low, against: forbid, ship: chat}
  beta:  {pipeline: build,  explore: auto, rigor: low, against: forbid, ship: publish}
default_type: beta
YAML
run --yaml "$f49/workflows.yaml" beta --ship chat
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
err_sub 'ship value' || bad="$bad missing-stderr:[ship value]"
err_sub 'not available' || bad="$bad missing-stderr:[not available]"
err_sub 'beta' || bad="$bad missing-stderr:[beta]"
err_sub 'alpha' || bad="$bad missing-stderr:[alpha]"
for other in feature bugfix hotfix migration rework diagnose map analyze document sync; do
  if err_sub "$other"; then bad="$bad unexpected-hardcoded-type-name:[$other]"; fi
done
if [ -z "$bad" ]; then
  pass "49: the illegal-override ship error's derived type lists mention only 'alpha'/'beta' (fixture's own rows), never any shipped type name"
else
  fail "49: the illegal-override ship error's derived type lists mention only 'alpha'/'beta' (fixture's own rows), never any shipped type name" \
    "$bad; $(ctx)"
fi

# --- Case 50: --pipeline locked fires before the --ship row-legality check -
run feature --pipeline build --ship chat
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
err_sub '--pipeline' || bad="$bad missing-stderr:[--pipeline]"
err_sub 'locked' || bad="$bad missing-stderr:[locked]"
err_sub 'feature' || bad="$bad missing-stderr:[feature]"
if err_sub '--ship'; then bad="$bad unexpected-stderr:[--ship]"; fi
if [ -z "$bad" ]; then
  pass "50: 'feature --pipeline build --ship chat' -> the --pipeline locked check fires first, never mentions --ship"
else
  fail "50: 'feature --pipeline build --ship chat' -> the --pipeline locked check fires first, never mentions --ship" \
    "$bad; $(ctx)"
fi

# ===========================================================================
# REWORK DIAL (contracts/l1.md §Round 1)
# ===========================================================================

# --- Case 51: bracket minimums and rejections for --rework ------------------
run feature --rew 4;     r51a="$OUT"; c51a="$CODE"
run feature --rewo 4;    r51b="$OUT"; c51b="$CODE"
run feature --rework 4;  r51c="$OUT"; c51c="$CODE"
if [ "$c51a" -eq 0 ] && [ "$c51b" -eq 0 ] && [ "$c51c" -eq 0 ] \
   && [ "$r51a" = "$r51c" ] && [ "$r51b" = "$r51c" ] \
   && printf '%s\n' "$r51c" | grep -qxF 'REWORK=4'; then
  pass "51a: '--rew'/'--rewo'/'--rework' 4 on feature all resolve identically to REWORK=4"
else
  fail "51a: '--rew'/'--rewo'/'--rework' 4 on feature all resolve identically to REWORK=4" \
    "codes=$c51a/$c51b/$c51c a=[$r51a] b=[$r51b] c=[$r51c]"
fi

run feature --re 4
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
err_sub 'unknown flag' || bad="$bad missing-stderr:[unknown flag]"
if ! err_tok '--re'; then bad="$bad missing-token:[--re]"; fi
if out_re '^REWORK='; then bad="$bad resolved-to-rework"; fi
if [ -z "$bad" ]; then
  pass "51b: '--re 4' rejected as unknown flag (4 chars, below --rew's 5-char minimum)"
else
  fail "51b: '--re 4' rejected as unknown flag (4 chars, below --rew's 5-char minimum)" "$bad; $(ctx)"
fi

run feature --ri 4
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
err_sub 'unknown flag' || bad="$bad missing-stderr:[unknown flag]"
if ! err_tok '--ri'; then bad="$bad missing-token:[--ri]"; fi
if out_re '^RIGOR_'; then bad="$bad resolved-to-rigor"; fi
if out_re '^REWORK='; then bad="$bad resolved-to-rework"; fi
if [ -z "$bad" ]; then
  pass "51c: '--ri 4' rejected as unknown flag (4 chars, below both --rig's and --rew's 5-char minimums)"
else
  fail "51c: '--ri 4' rejected as unknown flag (4 chars, below both --rig's and --rew's 5-char minimums)" \
    "$bad; $(ctx)"
fi

run feature -r 4
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
for s in 'rigor' '4' 'low' 'med' 'high'; do
  err_sub "$s" || bad="$bad missing-stderr:[$s]"
done
if out_re '^REWORK='; then bad="$bad leaked-REWORK"; fi
if [ -z "$bad" ]; then
  pass "51d: '-r 4' still resolves to --rigor (single-dash alias stays rigor's alone) and fails on the rigor value vocabulary, not treated as --rework"
else
  fail "51d: '-r 4' still resolves to --rigor (single-dash alias stays rigor's alone) and fails on the rigor value vocabulary, not treated as --rework" \
    "$bad; $(ctx)"
fi

# --- Case 52: --rework value validation --------------------------------------
run feature --rework 0
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
for s in '--rework' '0' 'an integer 1 or greater'; do
  err_sub "$s" || bad="$bad missing-stderr:[$s]"
done
if ! no_key_block; then bad="$bad unexpected-partial-stdout:[$OUT]"; fi
if [ -z "$bad" ]; then
  pass "52a: 'feature --rework 0' -> exit 1, stderr names --rework/0/'an integer 1 or greater', nothing on stdout"
else
  fail "52a: 'feature --rework 0' -> exit 1, stderr names --rework/0/'an integer 1 or greater', nothing on stdout" \
    "$bad; $(ctx)"
fi

run feature --rework abc
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
for s in '--rework' 'abc' 'an integer 1 or greater'; do
  err_sub "$s" || bad="$bad missing-stderr:[$s]"
done
if ! no_key_block; then bad="$bad unexpected-partial-stdout:[$OUT]"; fi
if [ -z "$bad" ]; then
  pass "52b: 'feature --rework abc' -> exit 1, stderr names --rework/abc/'an integer 1 or greater', nothing on stdout"
else
  fail "52b: 'feature --rework abc' -> exit 1, stderr names --rework/abc/'an integer 1 or greater', nothing on stdout" \
    "$bad; $(ctx)"
fi

run feature --rework 7
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0 - above-ceiling --rework warns but does not fail)"
line 'REWORK=7' || bad="$bad missing-line:[REWORK=7]"
err_sub 'warning' || bad="$bad missing-stderr:[warning]"
if [ -z "$bad" ]; then
  pass "52c: 'feature --rework 7' -> exit 0 AND REWORK=7 on stdout AND a warning on stderr (the triple)"
else
  fail "52c: 'feature --rework 7' -> exit 0 AND REWORK=7 on stdout AND a warning on stderr (the triple)" \
    "$bad; $(ctx)"
fi

run feature --rework 1
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0)"
line 'REWORK=1' || bad="$bad missing-line:[REWORK=1]"
if err_sub 'warning'; then bad="$bad unexpected-warning"; fi
if [ -z "$bad" ]; then
  pass "52c2: 'feature --rework 1' -> exit 0, REWORK=1, no warning (1 is within the typical ceiling)"
else
  fail "52c2: 'feature --rework 1' -> exit 0, REWORK=1, no warning (1 is within the typical ceiling)" \
    "$bad; $(ctx)"
fi

# --- Case 53: --rework dropped with a warning on a no-code-phase type -------
run map --rework 3
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0)"
err_sub 'warning' || bad="$bad missing-stderr:[warning]"
err_tok '--rework' || bad="$bad warning-does-not-name-flag:[--rework]"
err_tok 'map' || bad="$bad warning-does-not-name-type:[map]"
if [ -z "$bad" ]; then
  pass "53a: 'map --rework 3' -> exit 0, warning naming --rework and map, REWORK= dropped"
else
  fail "53a: 'map --rework 3' -> exit 0, warning naming --rework and map, REWORK= dropped" \
    "$bad; $(ctx)"
fi
no_lines "53a2: 'map --rework 3' emits no REWORK= line (map has no code phase)" '^REWORK='

run document --rework 3
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0)"
err_sub 'warning' || bad="$bad missing-stderr:[warning]"
err_tok '--rework' || bad="$bad warning-does-not-name-flag:[--rework]"
err_tok 'document' || bad="$bad warning-does-not-name-type:[document]"
if [ -z "$bad" ]; then
  pass "53b: 'document --rework 3' -> exit 0, warning naming --rework and document, REWORK= dropped"
else
  fail "53b: 'document --rework 3' -> exit 0, warning naming --rework and document, REWORK= dropped" \
    "$bad; $(ctx)"
fi
no_lines "53b2: 'document --rework 3' emits no REWORK= line (document has no code phase)" '^REWORK='

run map
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0)"
if err_sub 'warning'; then bad="$bad unexpected-warning"; fi
if [ -z "$bad" ]; then
  pass "53c: bare 'map' (no --rework flag) -> no warning at all (nothing to drop)"
else
  fail "53c: bare 'map' (no --rework flag) -> no warning at all (nothing to drop)" "$bad; $(ctx)"
fi

# --- Case 54: row default vs. flag override ----------------------------------
run feature
ok_lines "54a: bare 'feature' -> REWORK=3 (row default)" 'REWORK=3'

run feature --rework 5
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0)"
line 'REWORK=5' || bad="$bad missing-line:[REWORK=5]"
if err_sub 'warning'; then bad="$bad unexpected-warning"; fi
if [ -z "$bad" ]; then
  pass "54b: 'feature --rework 5' -> REWORK=5 (flag wins over row default), no warning (5 is within the ceiling)"
else
  fail "54b: 'feature --rework 5' -> REWORK=5 (flag wins over row default), no warning (5 is within the ceiling)" \
    "$bad; $(ctx)"
fi

# ===========================================================================
# SHIP AS A PER-ROW LIST (contracts/l1.md §Round 2)
# ===========================================================================

# --- Case 55: split parsing of the '|'-separated ship list -----------------
f55a=$(new_scratch)
cat >"$f55a/workflows.yaml" <<'YAML'
types:
  feature:   {pipeline: build,  explore: auto, rigor: low, against: forbid, ship: publish, planner: plan-feature, branch: feature/}
  probe:     {pipeline: report, explore: auto, rigor: low, against: forbid, ship: chat|banana}
default_type: feature
YAML
run --yaml "$f55a/workflows.yaml" probe
err_case "55a: malformed row (ship alternative 'banana' not in VOCAB_SHIP) -> exit 1, 'malformed' + 'banana'" \
  'malformed' 'banana'

f55b=$(new_scratch)
cat >"$f55b/workflows.yaml" <<'YAML'
types:
  feature:   {pipeline: build,  explore: auto, rigor: low, against: forbid, ship: publish, planner: plan-feature, branch: feature/}
  probe:     {pipeline: report, explore: auto, rigor: low, against: forbid, ship: chat|}
default_type: feature
YAML
run --yaml "$f55b/workflows.yaml" probe
err_case "55b: malformed row (a stray trailing '|' is an empty alternative, not a silently dropped one) -> exit 1, 'malformed' + 'empty alternative'" \
  'malformed' 'empty alternative'

f55c_tight=$(new_scratch)
cat >"$f55c_tight/workflows.yaml" <<'YAML'
types:
  feature:   {pipeline: build,  explore: auto, rigor: low, against: forbid, ship: publish, planner: plan-feature, branch: feature/}
  probe:     {pipeline: report, explore: auto, rigor: low, against: forbid, ship: publish|chat}
default_type: feature
YAML
f55c_spaced=$(new_scratch)
cat >"$f55c_spaced/workflows.yaml" <<'YAML'
types:
  feature:   {pipeline: build,  explore: auto, rigor: low, against: forbid, ship: publish, planner: plan-feature, branch: feature/}
  probe:     {pipeline: report, explore: auto, rigor: low, against: forbid, ship: publish | chat}
default_type: feature
YAML
run --yaml "$f55c_tight/workflows.yaml" probe;  r55c_tight="$OUT";  c55c_tight="$CODE"
run --yaml "$f55c_spaced/workflows.yaml" probe; r55c_spaced="$OUT"; c55c_spaced="$CODE"
if [ "$c55c_tight" -eq 0 ] && [ "$c55c_spaced" -eq 0 ] \
   && printf '%s\n' "$r55c_tight" | grep -qxF 'SHIP=publish' \
   && [ "$r55c_tight" = "$r55c_spaced" ]; then
  pass "55c: 'ship: publish|chat' (tight) and 'ship: publish | chat' (spaced) parse identically, both defaulting to SHIP=publish"
else
  fail "55c: 'ship: publish|chat' (tight) and 'ship: publish | chat' (spaced) parse identically, both defaulting to SHIP=publish" \
    "tight_code=$c55c_tight spaced_code=$c55c_spaced tight=[$r55c_tight] spaced=[$r55c_spaced]"
fi

# --- Case 56: the first alternative is the row's default -------------------
f56=$(new_scratch)
cat >"$f56/workflows.yaml" <<'YAML'
types:
  feature:   {pipeline: build,  explore: auto, rigor: low, against: forbid, ship: publish, planner: plan-feature, branch: feature/}
  probe:     {pipeline: report, explore: auto, rigor: low, against: forbid, ship: chat|publish}
default_type: feature
YAML
run --yaml "$f56/workflows.yaml" probe
ok_lines "56: bare 'probe' (row 'ship: chat|publish', no --ship flag) -> SHIP=chat (first alternative is the default, not 'publish')" \
  'SHIP=chat'

# --- Case 57: warn-on-equal, fixed (single-valued) row ----------------------
run feature --ship publish
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0)"
line 'SHIP=publish' || bad="$bad missing-line:[SHIP=publish]"
err_sub 'warning' || bad="$bad missing-stderr:[warning]"
err_sub '--ship' || bad="$bad missing-stderr:[--ship]"
err_sub 'fixed' || bad="$bad missing-stderr:[fixed]"
err_sub 'feature' || bad="$bad missing-stderr:[feature]"
if [ -z "$bad" ]; then
  pass "57: 'feature --ship publish' -> exit 0, SHIP=publish, warning naming '--ship'/'fixed'/'feature' (single-valued row, equal to its own fixed value)"
else
  fail "57: 'feature --ship publish' -> exit 0, SHIP=publish, warning naming '--ship'/'fixed'/'feature' (single-valued row, equal to its own fixed value)" \
    "$bad; $(ctx)"
fi

# --- Case 58: warn-on-equal, overridable (multi-valued) row ----------------
# Deliberate duplicate of case 45 - that one lives in the "locked axis"
# section for continuity with its history, this one lives with its topical
# siblings.
run analyze --ship publish
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0)"
line 'SHIP=publish' || bad="$bad missing-line:[SHIP=publish]"
err_sub 'warning' || bad="$bad missing-stderr:[warning]"
err_sub '--ship' || bad="$bad missing-stderr:[--ship]"
err_sub 'already the default' || bad="$bad missing-stderr:[already the default]"
if [ -z "$bad" ]; then
  pass "58: 'analyze --ship publish' -> exit 0, SHIP=publish, warning naming '--ship'/'already the default' (multi-valued row, deliberate duplicate of case 45)"
else
  fail "58: 'analyze --ship publish' -> exit 0, SHIP=publish, warning naming '--ship'/'already the default' (multi-valued row, deliberate duplicate of case 45)" \
    "$bad; $(ctx)"
fi

# --- Case 59: apply-on-legal-override ---------------------------------------
run analyze --ship chat
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0)"
line 'SHIP=chat' || bad="$bad missing-line:[SHIP=chat]"
if out_re '^RIGOR_PR='; then bad="$bad unexpected:[RIGOR_PR=]"; fi
if err_sub 'warning'; then bad="$bad unexpected-warning"; fi
if [ -z "$bad" ]; then
  pass "59: 'analyze --ship chat' -> exit 0, SHIP=chat (legal override applies), no RIGOR_PR= line, no warning"
else
  fail "59: 'analyze --ship chat' -> exit 0, SHIP=chat (legal override applies), no RIGOR_PR= line, no warning" \
    "$bad; $(ctx)"
fi

# --- Case 60: error-on-illegal-override -------------------------------------
# Deliberate duplicate of case 44 - that one lives in the "locked axis"
# section for continuity with its history, this one lives with its topical
# siblings.
run feature --ship chat
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
for s in 'ship value' 'chat' 'not available' 'feature'; do
  err_sub "$s" || bad="$bad missing-stderr:[$s]"
done
if [ -z "$bad" ]; then
  pass "60: 'feature --ship chat' -> exit 1, illegal override (deliberate duplicate of case 44)"
else
  fail "60: 'feature --ship chat' -> exit 1, illegal override (deliberate duplicate of case 44)" \
    "$bad; $(ctx)"
fi

# --- Case 61: map --ship publish -> the phase-existence table sees ship ----
run map --ship publish
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0)"
line 'SHIP=publish' || bad="$bad missing-line:[SHIP=publish]"
if err_sub 'warning'; then bad="$bad unexpected-warning"; fi
if [ -z "$bad" ]; then
  pass "61a: 'map --ship publish' -> exit 0, SHIP=publish, no warning (legal override, different from map's chat default)"
else
  fail "61a: 'map --ship publish' -> exit 0, SHIP=publish, no warning (legal override, different from map's chat default)" \
    "$bad; $(ctx)"
fi
ok_lines "61b: 'map --ship publish' -> RIGOR_PR=low now present (the phase-existence table sees the resolved ship value)" \
  'RIGOR_PR=low'

# --- Case 62: precedence, complementing case 50 -----------------------------
# document is a non-build, single-valued-ship row; pair an illegal --ship
# override with a second problem that would otherwise also fire, to show the
# ship check fires first.
run document --ship chat --plan /no/such.md
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
for s in 'ship value' 'chat' 'not available' 'document'; do
  err_sub "$s" || bad="$bad missing-stderr:[$s]"
done
if err_sub '--plan'; then bad="$bad unexpected-stderr:[--plan]"; fi
if [ -z "$bad" ]; then
  pass "62a: 'document --ship chat --plan /no/such.md' -> the --ship row-legality check fires first, never mentions --plan"
else
  fail "62a: 'document --ship chat --plan /no/such.md' -> the --ship row-legality check fires first, never mentions --plan" \
    "$bad; $(ctx)"
fi

run document --ship chat --against X
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
for s in 'ship value' 'chat' 'not available' 'document'; do
  err_sub "$s" || bad="$bad missing-stderr:[$s]"
done
if err_sub '--against'; then bad="$bad unexpected-stderr:[--against]"; fi
if err_sub 'did you mean'; then bad="$bad unexpected-stderr:[did you mean]"; fi
if [ -z "$bad" ]; then
  pass "62b: 'document --ship chat --against X' -> the --ship row-legality check fires first, never mentions --against or 'did you mean'"
else
  fail "62b: 'document --ship chat --against X' -> the --ship row-legality check fires first, never mentions --against or 'did you mean'" \
    "$bad; $(ctx)"
fi

# ===========================================================================
# THE LIVE TYPE (contracts/l1.md §Round 3)
# ===========================================================================

# --- Case 63a: alias 'adhoc' resolves to the canonical 'live' --------------
run adhoc
ok_lines "63a: alias 'adhoc' resolves to canonical TYPE=live (not the alias itself)" 'TYPE=live'

# --- Case 63b: live --ship chat -> illegal override (ship: publish only) ---
run live --ship chat
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
err_sub 'ship value' || bad="$bad missing-stderr:[ship value]"
err_sub 'chat' || bad="$bad missing-stderr:[chat]"
err_sub 'not available' || bad="$bad missing-stderr:[not available]"
if ! err_tok 'live'; then bad="$bad missing-token:[live]"; fi
err_sub 'publish' || bad="$bad missing-stderr:[publish]"
if ! no_key_block; then bad="$bad unexpected-partial-stdout:[$OUT]"; fi
if [ -z "$bad" ]; then
  pass "63b: 'live --ship chat' -> illegal override (exit 1), stderr names ship value/chat/not available/live/publish, nothing on stdout"
else
  fail "63b: 'live --ship chat' -> illegal override (exit 1), stderr names ship value/chat/not available/live/publish, nothing on stdout" \
    "$bad; $(ctx)"
fi

# --- Case 63c: live --ship publish -> warn-and-continue, fixed row ---------
run live --ship publish
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE(want 0)"
line 'SHIP=publish' || bad="$bad missing-line:[SHIP=publish]"
err_sub 'warning' || bad="$bad missing-stderr:[warning]"
err_sub 'fixed' || bad="$bad missing-stderr:[fixed]"
if ! err_tok 'live'; then bad="$bad missing-token:[live]"; fi
if [ -z "$bad" ]; then
  pass "63c: 'live --ship publish' -> exit 0, SHIP=publish, warning naming 'fixed' and 'live' (single-valued row, equal to its own fixed value)"
else
  fail "63c: 'live --ship publish' -> exit 0, SHIP=publish, warning naming 'fixed' and 'live' (single-valued row, equal to its own fixed value)" \
    "$bad; $(ctx)"
fi

# --- Case 63d: live --rework 4 -> flag overrides the row's rework: 2 -------
run live --rework 4
ok_lines "63d: 'live --rework 4' -> REWORK=4 (flag overrides the row's rework: 2)" 'REWORK=4'

# --- Case 63e: live -a PROJ-123 -> against: optional accepts one anchor ----
run live -a PROJ-123
ok_lines "63e: 'live -a PROJ-123' -> AGAINST_COUNT=1, AGAINST_1=PROJ-123 (against: optional)" \
  'AGAINST_COUNT=1' 'AGAINST_1=PROJ-123'

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
