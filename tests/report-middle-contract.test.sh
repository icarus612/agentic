#!/usr/bin/env bash
# report-middle-contract.test.sh
#
# SYNOPSIS
#   bash tests/report-middle-contract.test.sh
#
# DESCRIPTION
#   Contract test for agent-agnostic/skills/dae/report.md and its sibling
#   report-skeleton.md — the `map`/`analyze` middle of the dae pipeline.
#
#   Delivers the test oracle that dae-axes-restructure-08-23-26 §6.1
#   declared ("Test oracle: new contract tests") and never shipped. Every
#   assertion below is authored from §6.1's ACCEPTANCE CRITERIA as written
#   in that plan, never from whatever report.md happens to contain today —
#   a disagreement between the file and the contract is a FAILING test, not
#   a reason to soften the assertion.
#
#   §6.1's criteria, verbatim:
#     - "one file serves both `map` and `analyze` so they cannot drift"
#     - the five-part skeleton: question verbatim / method (depth, rigor,
#       what was trusted) / findings (the only free-organization zone) /
#       evidence (file:line per claim) / confidence + open questions
#     - "The `ship: chat` short-circuit skips Setup/Record/Ship and loads
#       none of the publish seam"
#     - "the scratch dir is defined outside any worktree ... and must still
#       exist on disk"
#
#   The load-bearing anti-drift property is that report.md branches on
#   resolved AXIS VALUES (`ship`, `rigor`), never on the type NAME — that is
#   the only thing keeping two presets from becoming two files. Case 03
#   exists to catch a future edit that reintroduces a type-name branch.
#
#   Read-only: this suite mutates nothing in the repo. The one executable
#   case (10) runs resolve-scratch.sh into a mktemp -d scratch dir removed
#   by the cleanup trap.
#
# EXIT CODES
#   0  every case passed
#   1  at least one case failed (or a sanity precondition failed)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIDDLE="$REPO_ROOT/agent-agnostic/skills/dae/report.md"
SKEL="$REPO_ROOT/agent-agnostic/skills/dae/report-skeleton.md"
DAEDIR="$REPO_ROOT/agent-agnostic/skills/dae"
SCRATCH_DIRS=()

TOTAL_PASS=0
TOTAL_FAIL=0

cleanup() { for d in "${SCRATCH_DIRS[@]:-}"; do [ -n "$d" ] && rm -rf "$d"; done; }
trap cleanup EXIT

pass() { TOTAL_PASS=$((TOTAL_PASS+1)); echo "PASS: $1"; }
fail() { TOTAL_FAIL=$((TOTAL_FAIL+1)); echo "FAIL: $1"; shift; for l in "$@"; do echo "      $l"; done; }

# has <file> <fixed-string> — grep -F, content-asserted, never exit-status-only
has() { grep -qF -- "$2" "$1"; }

# ---------------------------------------------------------------------------
# Sanity preconditions — a missing subject is a suite failure, not 0 cases
# ---------------------------------------------------------------------------
[ -f "$MIDDLE" ] || { echo "PRECONDITION FAILED: $MIDDLE missing"; exit 1; }
[ -f "$SKEL" ]   || { echo "PRECONDITION FAILED: $SKEL missing"; exit 1; }

# POSITIVE CONTROL for `has`: a string that is certainly present, and one
# that is certainly absent. Without this, every "not found" below is
# meaningless — a broken matcher looks exactly like a clean result.
if has "$MIDDLE" "report" && ! has "$MIDDLE" "zzz-string-that-cannot-exist-zzz"; then
  pass "00: matcher positive control (finds a present string, misses an absent one)"
else
  fail "00: matcher positive control failed — every assertion below is unreliable"
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"; exit 1
fi

# ---------------------------------------------------------------------------
# 01-03 — "one file serves both map and analyze so they cannot drift"
# ---------------------------------------------------------------------------
if [ ! -e "$DAEDIR/map.md" ] && [ ! -e "$DAEDIR/analyze.md" ]; then
  pass "01: no per-type middle exists (map.md / analyze.md absent) — one file serves both"
else
  fail "01: a per-type middle file exists — the presets have drifted into separate files" \
       "found: $(ls "$DAEDIR"/map.md "$DAEDIR"/analyze.md 2>/dev/null | tr '\n' ' ')"
fi

if has "$MIDDLE" "map" && has "$MIDDLE" "analyze"; then
  pass "02: the single middle names both presets it serves"
else
  fail "02: report.md does not name both map and analyze"
fi

# The anti-drift invariant, stated by the contract as the reason one file
# serves two presets. Assert the file DECLARES it; a future type-name branch
# would have to delete this sentence to look consistent.
if has "$MIDDLE" "never on the type name"; then
  pass "03: report.md declares every branch is on a resolved axis value, never the type name"
else
  fail "03: the anti-drift declaration ('never on the type name') is missing" \
       "This is what keeps map and analyze from becoming two files."
fi

# ---------------------------------------------------------------------------
# 04-05 — the five-part skeleton (§2.5, cited by §6.1)
# ---------------------------------------------------------------------------
missing=()
for sec in "Question" "Method" "Findings" "Evidence" "Confidence"; do
  has "$SKEL" "$sec" || missing+=("$sec")
done
if [ ${#missing[@]} -eq 0 ]; then
  pass "04: report-skeleton.md carries all five contract sections"
else
  fail "04: report-skeleton.md is missing contract section(s): ${missing[*]}"
fi

# "findings (the only free-organization zone)" — the constraint that makes
# the other four sections fixed. Losing it silently makes the frame optional.
if has "$SKEL" "free-organization"; then
  pass "05: the skeleton marks findings as the only free-organization zone"
else
  fail "05: the 'free-organization zone' constraint is absent from the skeleton"
fi

# ---------------------------------------------------------------------------
# 06-08 — the `ship: chat` short-circuit
# ---------------------------------------------------------------------------
# "skips Setup/Record/Ship and loads none of the publish seam" — enumerate
# every named component, so a partially-restored seam fails rather than a
# single keyword rescuing the case.
seam_missing=()
for tok in "workflow-setup.sh" "push-pr" "cleanup-merged" "progress-log"; do
  has "$MIDDLE" "$tok" || seam_missing+=("$tok")
done
if [ ${#seam_missing[@]} -eq 0 ]; then
  pass "06: the chat short-circuit enumerates every publish-seam component it skips"
else
  fail "06: the chat short-circuit does not name: ${seam_missing[*]}" \
       "Each must be named as skipped, or a reader cannot tell what chat mode omits."
fi

if has "$MIDDLE" "no branch, no commit"; then
  pass "07: report.md states the observable chat-mode property (no branch, no commit)"
else
  fail "07: the observable 'no branch, no commit' property is not stated"
fi

# The worktree-need table: three rows keyed on ship x rigor, per the contract.
if has "$MIDDLE" "publish" && has "$MIDDLE" "chat" && has "$MIDDLE" "snapshot"; then
  pass "08: the worktree-need table covers publish / chat-low / chat-med (snapshot) cells"
else
  fail "08: the ship x rigor worktree-need table is incomplete"
fi

# ---------------------------------------------------------------------------
# 09-10 — the scratch dir: defined outside any worktree, and exists on disk
# ---------------------------------------------------------------------------
if has "$MIDDLE" "resolve-scratch.sh" && has "$MIDDLE" "SCRATCHDIR:"; then
  pass "09: report.md resolves the scratch dir via resolve-scratch.sh's SCRATCHDIR: line"
else
  fail "09: report.md does not delegate scratch-dir resolution to resolve-scratch.sh" \
       "Assembling the path inline would duplicate the resolution ladder."
fi

# Executable: the contract says the scratch dir "must still exist on disk".
RS="$REPO_ROOT/agent-agnostic/hooks/resolve-scratch.sh"
if [ -x "$RS" ] || [ -f "$RS" ]; then
  tmp=$(mktemp -d); SCRATCH_DIRS+=("$tmp")
  out=$(cd "$tmp" && bash "$RS" --slug report-contract-probe 2>&1)
  dir=$(printf '%s\n' "$out" | sed -n 's/^SCRATCHDIR: //p' | head -1)
  if [ -n "$dir" ]; then SCRATCH_DIRS+=("$dir"); fi
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    pass "10: resolve-scratch.sh creates the dir it reports — it exists on disk"
  else
    fail "10: resolve-scratch.sh did not create the dir it reported" \
         "SCRATCHDIR=[$dir]" "output=[$out]"
  fi
else
  fail "10: resolve-scratch.sh not found at $RS"
fi

# ---------------------------------------------------------------------------
# 11 — the analyze PR-gate scope boundary
# ---------------------------------------------------------------------------
if has "$MIDDLE" "reports/"; then
  pass "11: report.md states the publish-mode scope boundary (docs root's reports/)"
else
  fail "11: the 'nothing outside <docs-root>/reports/ may have changed' boundary is missing"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ]
