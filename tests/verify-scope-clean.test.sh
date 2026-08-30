#!/usr/bin/env bash
# verify-scope-clean.test.sh
#
# SYNOPSIS
#   bash tests/verify-scope-clean.test.sh
#
# DESCRIPTION
#   Blind contract test for the NEW clean-worktree gate added to
#   orchestrators/hooks/verify-scope.sh (contracts/l6.md, Packet 4.4). Before
#   any of the script's older "what changed vs. what was reported" comparison
#   logic runs, the script must now first check `git status --porcelain` on
#   the worktree and refuse (exit 1, one `UNCOMMITTED: <path>` line per
#   offending path) unless the tree is clean -- except for paths under
#   `.artifacts/`, which are exempt because that directory is gitignored in
#   real use. Only once the tree is clean does the script fall through to its
#   original behavior, now narrowed to compare the COMMITTED range
#   (`git diff --name-only <parent-branch>...HEAD`) against the caller's
#   reported files (argv, stdin, or `--report <exit-report>`).
#
#   Written from the contract text alone. Builds throwaway git-init'd
#   fixture worktrees under mktemp, using the new_git_worktree /
#   git_init_repo / commit_all / run_script / run_script_stdin idioms from
#   the sibling suite tests/verify-scope-parsing.test.sh (a test of a
#   different, shared behavior of the same script family). Never reads
#   orchestrators/hooks/verify-scope.sh's source, nor scope-writes.sh's, nor
#   parent-tree-guard.sh's, in any mode.
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
SCRIPT_VERIFY="$REPO_ROOT/orchestrators/hooks/verify-scope.sh"

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

# run_script <script> <args...> -- invokes <script> with stdin from /dev/null
# (so a script that conditionally reads stdin when it's not a tty never
# blocks), sets globals OUT / ERR / CODE.
OUT=""
ERR=""
CODE=0
run_script() {
  local script="$1"
  shift
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  "$script" "$@" </dev/null >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

git_init_repo() {
  local dir="$1"
  git -C "$dir" init -q
  git -C "$dir" config user.email "verify-scope-clean-test@example.com"
  git -C "$dir" config user.name "verify-scope-clean-test"
}

commit_all() {
  local dir="$1" msg="$2"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m "$msg" >/dev/null
}

# new_git_worktree -- prints a fresh scratch dir path, git-init'd with one
# baseline commit (README.md). Caller captures the baseline commit as the
# "base"/"parent" ref before making further changes.
new_git_worktree() {
  local dir
  dir=$(new_scratch)
  git_init_repo "$dir"
  printf 'baseline\n' >"$dir/README.md"
  commit_all "$dir" "baseline"
  printf '%s' "$dir"
}

# ---------------------------------------------------------------------------
# Case 01: bash -n sanity precondition on the script under test.
# ---------------------------------------------------------------------------
if bash -n "$SCRIPT_VERIFY" 2>/tmp/verify-scope-clean-syntax-err.$$; then
  pass "01: bash -n verify-scope.sh exits 0 (sanity precondition)"
else
  syntax_err=$(cat /tmp/verify-scope-clean-syntax-err.$$ 2>/dev/null)
  fail "01: bash -n verify-scope.sh exits 0 (sanity precondition)" "syntax error: $syntax_err"
  rm -f /tmp/verify-scope-clean-syntax-err.$$
  echo "sanity failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
rm -f /tmp/verify-scope-clean-syntax-err.$$

# ---------------------------------------------------------------------------
# Case 02: worktree with all lane work COMMITTED, matching reported files
# (argv mode) -> OK: reported files match the lane diff (N changed), exit 0.
# ---------------------------------------------------------------------------
c2_wt=$(new_git_worktree)
c2_base=$(git -C "$c2_wt" rev-parse HEAD)
mkdir -p "$c2_wt/a"
printf 'x\n' >"$c2_wt/a/x.sh"
commit_all "$c2_wt" "add a/x.sh"

run_script "$SCRIPT_VERIFY" "$c2_wt" "$c2_base" "a/x.sh"
if [ "$CODE" -eq 0 ] && printf '%s\n' "$OUT" | grep -qF "OK: reported files match the lane diff (1 changed)"; then
  pass "02: clean worktree, committed work matches argv-reported files -> OK line with correct count, exit 0"
else
  fail "02: clean worktree, committed work matches argv-reported files -> OK line with correct count, exit 0" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case 03: worktree with a MODIFIED tracked file (committed once, then
# edited again without re-committing) -> exit 1, UNCOMMITTED: <path>, and NO
# OK: line (the new gate runs before the older comparison logic at all).
# ---------------------------------------------------------------------------
c3_wt=$(new_git_worktree)
c3_base=$(git -C "$c3_wt" rev-parse HEAD)
mkdir -p "$c3_wt/a"
printf 'v1\n' >"$c3_wt/a/mod.sh"
commit_all "$c3_wt" "add a/mod.sh"
printf 'v2\n' >>"$c3_wt/a/mod.sh"

run_script "$SCRIPT_VERIFY" "$c3_wt" "$c3_base" "a/mod.sh"
if [ "$CODE" -eq 1 ] \
   && printf '%s\n' "$OUT" | grep -qF "UNCOMMITTED: a/mod.sh" \
   && ! printf '%s\n' "$OUT" | grep -q '^OK:'; then
  pass "03: worktree with a modified-but-uncommitted tracked file -> exit 1, UNCOMMITTED line, no OK: line"
else
  fail "03: worktree with a modified-but-uncommitted tracked file -> exit 1, UNCOMMITTED line, no OK: line" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case 04: worktree with a STAGED-but-not-committed change (git add, no
# git commit) -> exit 1 with UNCOMMITTED: <path>.
# ---------------------------------------------------------------------------
c4_wt=$(new_git_worktree)
c4_base=$(git -C "$c4_wt" rev-parse HEAD)
mkdir -p "$c4_wt/a"
printf 'staged\n' >"$c4_wt/a/staged.sh"
git -C "$c4_wt" add "a/staged.sh"

run_script "$SCRIPT_VERIFY" "$c4_wt" "$c4_base" "a/staged.sh"
if [ "$CODE" -eq 1 ] && printf '%s\n' "$OUT" | grep -qF "UNCOMMITTED: a/staged.sh"; then
  pass "04: worktree with a staged-but-not-committed file -> exit 1, UNCOMMITTED line"
else
  fail "04: worktree with a staged-but-not-committed file -> exit 1, UNCOMMITTED line" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case 05: worktree with an UNTRACKED new file (never git added) -> exit 1
# with UNCOMMITTED: <path>. The containing directory is committed FIRST (via
# a sibling placeholder file) so that git status reports the untracked FILE
# itself rather than folding a brand-new untracked directory into a single
# "?? a/" line -- that directory-collapsing is plain git behavior, orthogonal
# to the gate under test.
# ---------------------------------------------------------------------------
c5_wt=$(new_git_worktree)
mkdir -p "$c5_wt/a"
printf 'placeholder\n' >"$c5_wt/a/placeholder.sh"
commit_all "$c5_wt" "add a/ with a placeholder file"
c5_base=$(git -C "$c5_wt" rev-parse HEAD)
printf 'untracked\n' >"$c5_wt/a/untracked.sh"

run_script "$SCRIPT_VERIFY" "$c5_wt" "$c5_base" "a/untracked.sh"
if [ "$CODE" -eq 1 ] && printf '%s\n' "$OUT" | grep -qF "UNCOMMITTED: a/untracked.sh"; then
  pass "05: worktree with an untracked new file -> exit 1, UNCOMMITTED line"
else
  fail "05: worktree with an untracked new file -> exit 1, UNCOMMITTED line" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case 06: worktree dirty ONLY under a .gitignore'd .artifacts/ directory ->
# the gate PASSES (falls through to normal OK/UNREPORTED/UNCHANGED logic on
# a tree that's otherwise clean). Fixture: a file is committed under
# .artifacts/ BEFORE .gitignore lists it (so git still tracks it), then
# .gitignore is committed, then the already-tracked file is modified without
# a further commit -- this is the case that actually exercises the .artifacts/
# exemption, since a brand-new untracked file under an ignored directory
# would never show up in `git status --porcelain` in the first place.
# ---------------------------------------------------------------------------
c6_wt=$(new_git_worktree)
mkdir -p "$c6_wt/.artifacts"
printf 'v1\n' >"$c6_wt/.artifacts/tracked.txt"
commit_all "$c6_wt" "add .artifacts/tracked.txt before it is ignored"
printf '.artifacts/\n' >"$c6_wt/.gitignore"
commit_all "$c6_wt" "add .gitignore for .artifacts/"
c6_base=$(git -C "$c6_wt" rev-parse HEAD)
printf 'v2\n' >>"$c6_wt/.artifacts/tracked.txt"

run_script "$SCRIPT_VERIFY" "$c6_wt" "$c6_base"
if [ "$CODE" -eq 0 ] \
   && ! printf '%s\n' "$OUT" | grep -q '^UNCOMMITTED:' \
   && printf '%s\n' "$OUT" | grep -qF "OK: reported files match the lane diff (0 changed)"; then
  pass "06: worktree dirty only under .artifacts/ -> gate passes, falls through to OK: on an otherwise-clean, unchanged tree"
else
  fail "06: worktree dirty only under .artifacts/ -> gate passes, falls through to OK: on an otherwise-clean, unchanged tree" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case 07: CLEAN worktree, a file committed on the branch but absent from
# the reported set -> UNREPORTED: <path>, exit 1 (pre-existing, unchanged
# behavior -- regression guard).
# ---------------------------------------------------------------------------
c7_wt=$(new_git_worktree)
c7_base=$(git -C "$c7_wt" rev-parse HEAD)
mkdir -p "$c7_wt/a"
printf 'x\n' >"$c7_wt/a/unreported.sh"
commit_all "$c7_wt" "add a/unreported.sh"

run_script "$SCRIPT_VERIFY" "$c7_wt" "$c7_base"
if [ "$CODE" -eq 1 ] \
   && printf '%s\n' "$OUT" | grep -qF "UNREPORTED: a/unreported.sh" \
   && ! printf '%s\n' "$OUT" | grep -q '^UNCOMMITTED:'; then
  pass "07: clean worktree, committed file absent from reported set -> UNREPORTED line, exit 1 (regression)"
else
  fail "07: clean worktree, committed file absent from reported set -> UNREPORTED line, exit 1 (regression)" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case 08: CLEAN worktree, a file reported but with no diff in the committed
# range -> UNCHANGED: <path> (reported but no diff), warning only, exit
# stays 0 if nothing else is unreported (pre-existing, unchanged behavior --
# regression guard).
# ---------------------------------------------------------------------------
c8_wt=$(new_git_worktree)
c8_base=$(git -C "$c8_wt" rev-parse HEAD)

run_script "$SCRIPT_VERIFY" "$c8_wt" "$c8_base" "a/never-changed.sh"
if [ "$CODE" -eq 0 ] \
   && printf '%s\n' "$OUT" | grep -qF "UNCHANGED: a/never-changed.sh (reported but no diff)" \
   && printf '%s\n' "$OUT" | grep -qF "OK: reported files match the lane diff (0 changed)"; then
  pass "08: clean worktree, reported file with no diff -> UNCHANGED warning only, exit 0, OK: line still prints (regression)"
else
  fail "08: clean worktree, reported file with no diff -> UNCHANGED warning only, exit 0, OK: line still prints (regression)" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case 09: --report <exit-report> mode, clean-and-matching case -> OK,
# exit 0. Confirms the new gate applies identically under --report input.
# ---------------------------------------------------------------------------
c9_wt=$(new_git_worktree)
c9_base=$(git -C "$c9_wt" rev-parse HEAD)
mkdir -p "$c9_wt/a"
printf 'r\n' >"$c9_wt/a/reported.sh"
commit_all "$c9_wt" "add a/reported.sh"

c9_rundir=$(new_scratch)
mkdir -p "$c9_rundir/reports"
cat >"$c9_rundir/reports/case9-exit.md" <<'EOF'
# case9 exit report

## Files touched
- a/reported.sh
EOF

run_script "$SCRIPT_VERIFY" "$c9_wt" "$c9_base" --report "$c9_rundir/reports/case9-exit.md"
if [ "$CODE" -eq 0 ] && printf '%s\n' "$OUT" | grep -qF "OK: reported files match the lane diff (1 changed)"; then
  pass "09: --report mode, clean worktree matching the report's Files touched -> OK line, exit 0"
else
  fail "09: --report mode, clean worktree matching the report's Files touched -> OK line, exit 0" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case 10: --report <exit-report> mode, an UNCOMMITTED case -> exit 1 with
# UNCOMMITTED: <path>. Confirms the new gate applies identically under
# --report input, regardless of what the report itself claims.
# ---------------------------------------------------------------------------
c10_wt=$(new_git_worktree)
c10_base=$(git -C "$c10_wt" rev-parse HEAD)
mkdir -p "$c10_wt/a"
printf 'v1\n' >"$c10_wt/a/dirty.sh"
commit_all "$c10_wt" "add a/dirty.sh"
printf 'v2\n' >>"$c10_wt/a/dirty.sh"

c10_rundir=$(new_scratch)
mkdir -p "$c10_rundir/reports"
cat >"$c10_rundir/reports/case10-exit.md" <<'EOF'
# case10 exit report

## Files touched
- a/dirty.sh
EOF

run_script "$SCRIPT_VERIFY" "$c10_wt" "$c10_base" --report "$c10_rundir/reports/case10-exit.md"
if [ "$CODE" -eq 1 ] \
   && printf '%s\n' "$OUT" | grep -qF "UNCOMMITTED: a/dirty.sh" \
   && ! printf '%s\n' "$OUT" | grep -q '^OK:'; then
  pass "10: --report mode, dirty worktree -> exit 1, UNCOMMITTED line, no OK: line, regardless of report content"
else
  fail "10: --report mode, dirty worktree -> exit 1, UNCOMMITTED line, no OK: line, regardless of report content" \
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
