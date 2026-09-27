#!/usr/bin/env bash
# smart-test-role-scope.test.sh
#
# SYNOPSIS
#   bash tests/smart-test-role-scope.test.sh
#
# DESCRIPTION
#   Blind contract test for agent-agnostic/hooks/smart-test.sh's blind-role
#   short-circuit (Packet 3, subphases 3.1/3.2): the hook reads a JSON
#   tool-call payload on stdin, resolves a "cwd" field (falling back to
#   $PWD), and walks UP the directory ancestry from there looking for
#   .artifacts/dae-role. When that marker's (whitespace-stripped) content is
#   exactly "coder" or "contract-tester", the hook must exit 0 BEFORE running
#   any test suite -- no suite output may leak to stdout or stderr. Any other
#   marker state (absent, unreadable, or a token other than those two) must
#   fall through to the hook's pre-existing behavior: it actually runs the
#   fixture project's test suite.
#
#   Written from the contract text alone (Packet 3 section of
#   .artifacts/contracts/l1.md). NEVER reads smart-test.sh's source, in any
#   mode, including to interpret a failure -- not even the doc-comment
#   header. sed/grep/cat/head/less/an editor are never run against
#   smart-test.sh for the whole duration of authoring this file. The payload
#   shape (flat "tool_name"/"file_path"/"cwd" JSON keys) is carried over from
#   the sibling suites scope-writes.test.sh and parent-tree-guard.test.sh
#   (both read freely for suite/fixture conventions -- they test different,
#   unrelated hooks) -- not from smart-test.sh itself.
#
#   Fixture: a real, minimal Go module (go.mod + a plain source file + a
#   matching _test.go), per the contract's own text ("a fixture Go ... project
#   under a mktemp -d"), so the hook's language detection has something real
#   to run. Every file/package/module name in the fixture is built from one
#   distinctive marker token so a single string check answers "did the suite
#   actually run" without depending on go test's -v flag or on any assumption
#   about the hook's own log wording.
#
# EXIT CODES
#   0  every case passed
#   1  at least one case failed (or the bash -n sanity precondition failed)
#
# Runnable as `bash tests/smart-test-role-scope.test.sh` from any working
# directory.

set -uo pipefail

# ---------------------------------------------------------------------------
# Locate the script under test relative to this file's own location.
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/agent-agnostic/hooks/smart-test.sh"

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
# The distinctive marker. Every fixture file's basename, the Go module name,
# the Go package name, and a fmt.Println() call executed unconditionally by
# the test both embed this exact token. fmt.Println output from inside a Go
# test binary reaches the parent process's stdout regardless of any
# verbosity flag the hook may or may not pass to `go test`, so this is the
# single most flag-agnostic way to prove the suite actually ran.
# ---------------------------------------------------------------------------
MARKER="zzqsmarttestfixturewidget"

# new_go_fixture -- a fresh scratch dir containing a real, minimal Go module
# (go.mod, "<MARKER>.go", "<MARKER>_test.go") whose test both passes AND
# unconditionally prints a line containing MARKER. Prints the fixture root.
new_go_fixture() {
  local d
  d=$(new_scratch)
  cat >"$d/go.mod" <<EOF
module $MARKER

go 1.21
EOF
  cat >"$d/${MARKER}.go" <<EOF
package $MARKER

func Add(a, b int) int {
	return a + b
}
EOF
  cat >"$d/${MARKER}_test.go" <<EOF
package $MARKER

import (
	"fmt"
	"testing"
)

func TestAdd(t *testing.T) {
	fmt.Println("${MARKER}-ran")
	if Add(2, 3) != 5 {
		t.Fatalf("${MARKER}: unexpected result")
	}
}
EOF
  printf '%s' "$d"
}

# mark_role <fixture-dir> <role-content> -- writes .artifacts/dae-role
# directly under the fixture root (so the hook's upward walk finds it on the
# very first step, matching the contract's ROLE=$(smart_test_role
# "${CWD_FROM_PAYLOAD:-$PWD}") call against the payload's own cwd).
mark_role() {
  local dir="$1" role="$2"
  mkdir -p "$dir/.artifacts"
  printf '%s\n' "$role" >"$dir/.artifacts/dae-role"
}

# ---------------------------------------------------------------------------
# run_hook <fixture-dir> [role-header-note] -- invokes the hook with a
# Write-shaped PostToolUse payload naming the fixture's own Go source file as
# "file_path" and the fixture root as "cwd" (matching scope-writes.sh's flat
# file_path convention and parent-tree-guard.sh's flat cwd convention -- both
# already-established sibling-hook payload shapes, not inferred from
# smart-test.sh). Also cd's the test process into the fixture root before
# invoking, so a fallback-to-$PWD path (were the hook's cwd-JSON extraction
# to fail for any reason) still lands on the same marked directory. Sets
# globals OUT / ERR / CODE / COMBINED.
# ---------------------------------------------------------------------------
OUT=""
ERR=""
CODE=0
COMBINED=""
run_hook() {
  local fixture="$1"
  local payload out_f err_f
  payload=$(printf '{"tool_name": "Write", "file_path": "%s/%s.go", "cwd": "%s"}' \
    "$fixture" "$MARKER" "$fixture")
  out_f=$(mktemp)
  err_f=$(mktemp)
  ( cd "$fixture" && printf '%s' "$payload" | "$SCRIPT" ) >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  COMBINED="${OUT}"$'\n'"${ERR}"
  rm -f "$out_f" "$err_f"
}

# contains_marker -- true (0) if COMBINED contains MARKER anywhere, using a
# case-glob string match (never grep/awk exit status alone, per the
# ugrep/mawk caveat named in the contract).
contains_marker() {
  case "$COMBINED" in
    *"$MARKER"*) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Case 00: bash -n sanity precondition (script must at least parse)
# ---------------------------------------------------------------------------
SYN_ERR_FILE=$(mktemp)
if bash -n "$SCRIPT" 2>"$SYN_ERR_FILE"; then
  pass "00: bash -n smart-test.sh exits 0"
else
  fail "00: bash -n smart-test.sh exits 0" "syntax error: $(cat "$SYN_ERR_FILE")"
  rm -f "$SYN_ERR_FILE"
  echo "sanity failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
rm -f "$SYN_ERR_FILE"

# ---------------------------------------------------------------------------
# Case 03 is built FIRST (out of numeric order) so cases 01/02's "no leakage"
# assertions are checked against a fixture/hook pairing already PROVEN to
# produce marker output when unmarked-non-blind -- this is the contract's own
# ordering rationale ("a bare 'no output' from case 1/2 is worthless without
# this"). The pass/fail tally still reports cases in their contract-numbered
# labels.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Case 03: POSITIVE CONTROL -- role=builder -> the hook actually produces
# output containing the fixture's own marker, proving the fixture and the
# hook both really run when the role is not blind.
# ---------------------------------------------------------------------------
case03() {
  local label="03: POSITIVE CONTROL, role=builder -> suite actually runs (marker present)"
  local fixture
  fixture=$(new_go_fixture)
  mark_role "$fixture" "builder"
  run_hook "$fixture"
  if ! contains_marker; then
    fail "$label" "code=$CODE marker=[$MARKER] combined=[$COMBINED]"
    return
  fi
  pass "$label (code=$CODE)"
}
case03

# ---------------------------------------------------------------------------
# Case 03b: same positive control, but with NO .artifacts/dae-role file at
# all (the contract explicitly allows either fixture for this control) --
# confirms an absent marker also falls through to running the suite, not
# just an explicit non-blind role.
# ---------------------------------------------------------------------------
case03b() {
  local label="03b: POSITIVE CONTROL, no dae-role file at all -> suite actually runs (marker present)"
  local fixture
  fixture=$(new_go_fixture)
  run_hook "$fixture"
  if ! contains_marker; then
    fail "$label" "code=$CODE marker=[$MARKER] combined=[$COMBINED]"
    return
  fi
  pass "$label (code=$CODE)"
}
case03b

# ---------------------------------------------------------------------------
# Case 01: role=coder on a marked fixture -> exit 0, no suite-output leakage.
# ---------------------------------------------------------------------------
case01() {
  local label="01: role=coder -> exit 0, no suite output leaks"
  local fixture
  fixture=$(new_go_fixture)
  mark_role "$fixture" "coder"
  run_hook "$fixture"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE combined=[$COMBINED]"
    return
  fi
  if contains_marker; then
    fail "$label -> no marker in combined output" "marker=[$MARKER] combined=[$COMBINED]"
    return
  fi
  pass "$label"
}
case01

# ---------------------------------------------------------------------------
# Case 02: role=contract-tester on a marked fixture -> exit 0, no suite
# output leakage.
# ---------------------------------------------------------------------------
case02() {
  local label="02: role=contract-tester -> exit 0, no suite output leaks"
  local fixture
  fixture=$(new_go_fixture)
  mark_role "$fixture" "contract-tester"
  run_hook "$fixture"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE combined=[$COMBINED]"
    return
  fi
  if contains_marker; then
    fail "$label -> no marker in combined output" "marker=[$MARKER] combined=[$COMBINED]"
    return
  fi
  pass "$label"
}
case02

# ---------------------------------------------------------------------------
# Case 04: garbage/unrecognized role content -> falls through, same as the
# control (suite actually runs, marker present).
# ---------------------------------------------------------------------------
case04() {
  local label="04: role=garbage token -> falls through, suite actually runs (marker present)"
  local fixture
  fixture=$(new_go_fixture)
  mark_role "$fixture" "not-a-real-role"
  run_hook "$fixture"
  if ! contains_marker; then
    fail "$label" "code=$CODE marker=[$MARKER] combined=[$COMBINED]"
    return
  fi
  pass "$label (code=$CODE)"
}
case04

# ---------------------------------------------------------------------------
# Case 05: an orchestrator/planner/builder-marked-but-differently-worded
# sanity check is out of scope here (that's Packet 1/2's table, not this
# hook's) -- but a role of exactly "orchestrator" or "planner" (the other two
# real dae-run tokens, neither of which is coder/contract-tester) must ALSO
# fall through to running the suite, since only "coder"/"contract-tester"
# are blind here. Folded in as an extra control on the same fixture shape.
# ---------------------------------------------------------------------------
case05() {
  local label="05: role=orchestrator (not a blind role for this hook) -> suite actually runs"
  local fixture
  fixture=$(new_go_fixture)
  mark_role "$fixture" "orchestrator"
  run_hook "$fixture"
  if ! contains_marker; then
    fail "$label" "code=$CODE marker=[$MARKER] combined=[$COMBINED]"
    return
  fi
  pass "$label (code=$CODE)"
}
case05

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
