#!/usr/bin/env bash
# verify-scope-parsing.test.sh
#
# SYNOPSIS
#   bash tests/verify-scope-parsing.test.sh
#
# DESCRIPTION
#   Blind contract test for the shared claims_from_report exit-report-claims
#   parser added to agent-agnostic/hooks/verify-run-scope.sh and
#   agent-agnostic/hooks/verify-scope.sh (contracts/l6.md, Packet 1 + Packet 1t).
#   Written from the contract text alone. Builds throwaway git-init'd fixture
#   worktrees under mktemp with real committed changes and synthetic
#   reports/*-exit.md files, and asserts on exit codes and stdout/stderr
#   content of the two scripts under test. Never reads either script's source.
#
# EXIT CODES
#   0  every case passed
#   1  at least one case failed (or the bash -n sanity precondition failed)
#
# Runnable with no arguments from any working directory.

set -uo pipefail

# ---------------------------------------------------------------------------
# Locate the scripts under test relative to this file's own location.
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_RUN="$REPO_ROOT/agent-agnostic/hooks/verify-run-scope.sh"
SCRIPT_VERIFY="$REPO_ROOT/agent-agnostic/hooks/verify-scope.sh"

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

# run_script_stdin <script> <stdin-content> <args...> -- same as run_script
# but feeds <stdin-content> on stdin instead of /dev/null.
run_script_stdin() {
  local script="$1" stdin_content="$2"
  shift 2
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  printf '%s\n' "$stdin_content" | "$script" "$@" >"$out_f" 2>"$err_f"
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
  git -C "$dir" config user.email "verify-scope-test@example.com"
  git -C "$dir" config user.name "verify-scope-test"
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
# Case 01/02: bash -n sanity precondition on both scripts under test (AC7)
# ---------------------------------------------------------------------------
sanity_failed=0

if bash -n "$SCRIPT_RUN" 2>/tmp/verify-scope-parsing-syntax-err-run.$$; then
  pass "01: bash -n verify-run-scope.sh exits 0 (AC7)"
else
  syntax_err=$(cat /tmp/verify-scope-parsing-syntax-err-run.$$ 2>/dev/null)
  fail "01: bash -n verify-run-scope.sh exits 0 (AC7)" "syntax error: $syntax_err"
  sanity_failed=1
fi
rm -f /tmp/verify-scope-parsing-syntax-err-run.$$

if bash -n "$SCRIPT_VERIFY" 2>/tmp/verify-scope-parsing-syntax-err-verify.$$; then
  pass "02: bash -n verify-scope.sh exits 0 (AC7)"
else
  syntax_err=$(cat /tmp/verify-scope-parsing-syntax-err-verify.$$ 2>/dev/null)
  fail "02: bash -n verify-scope.sh exits 0 (AC7)" "syntax error: $syntax_err"
  sanity_failed=1
fi
rm -f /tmp/verify-scope-parsing-syntax-err-verify.$$

if [ "$sanity_failed" -eq 1 ]; then
  echo "sanity failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi

# ---------------------------------------------------------------------------
# Case set 1: every accepted claim format parses and is treated as claimed
# (AC1). One report with all seven bullet shapes, each naming a distinct
# real changed file under a/.
# ---------------------------------------------------------------------------
c1_wt=$(new_git_worktree)
c1_base=$(git -C "$c1_wt" rev-parse HEAD)

mkdir -p "$c1_wt/a"
printf 'plain\n' >"$c1_wt/a/plain.sh"
printf 'backtick\n' >"$c1_wt/a/backtick.sh"
printf 'backtick-paren\n' >"$c1_wt/a/backtick-paren.sh"
printf 'backtick-annotation\n' >"$c1_wt/a/backtick-annotation.sh"
printf 'trailing-comma\n' >"$c1_wt/a/trailing-comma.sh"
printf 'dotslash\n' >"$c1_wt/a/dotslash.sh"
printf 'absolute\n' >"$c1_wt/a/absolute.sh"
commit_all "$c1_wt" "add seven claim-format targets"
c1_abs="$c1_wt/a/absolute.sh"

c1_rundir=$(new_scratch)
mkdir -p "$c1_rundir/reports"
cat >"$c1_rundir/reports/case1-exit.md" <<'EOF'
# case1 exit report

## Files touched
- a/plain.sh
- `a/backtick.sh`
- `a/backtick-paren.sh` (new)
- `a/backtick-annotation.sh` — some annotation
- a/trailing-comma.sh,
- ./a/dotslash.sh
EOF
printf -- '- %s\n' "$c1_abs" >>"$c1_rundir/reports/case1-exit.md"
cat >>"$c1_rundir/reports/case1-exit.md" <<'EOF'

## Notes
Nothing else in this section.
EOF

run_script "$SCRIPT_RUN" "$c1_wt" "$c1_base" "$c1_rundir"
c1_out="$OUT"
c1_code="$CODE"

if ! printf '%s\n' "$c1_out" | grep -qF "UNCLAIMED: a/plain.sh"; then
  pass "03: plain bullet 'a/plain.sh' claimed, no UNCLAIMED (AC1)"
else
  fail "03: plain bullet 'a/plain.sh' claimed, no UNCLAIMED (AC1)" "out=[$c1_out]"
fi

if ! printf '%s\n' "$c1_out" | grep -qF "UNCLAIMED: a/backtick.sh"; then
  pass "04: backticked bullet 'a/backtick.sh' claimed, no UNCLAIMED (AC1)"
else
  fail "04: backticked bullet 'a/backtick.sh' claimed, no UNCLAIMED (AC1)" "out=[$c1_out]"
fi

if ! printf '%s\n' "$c1_out" | grep -qF "UNCLAIMED: a/backtick-paren.sh"; then
  pass "05: backticked+paren-annotation bullet claimed, no UNCLAIMED (AC1)"
else
  fail "05: backticked+paren-annotation bullet claimed, no UNCLAIMED (AC1)" "out=[$c1_out]"
fi

if ! printf '%s\n' "$c1_out" | grep -qF "UNCLAIMED: a/backtick-annotation.sh"; then
  pass "06: backticked+dash-annotation bullet claimed, no UNCLAIMED (AC1)"
else
  fail "06: backticked+dash-annotation bullet claimed, no UNCLAIMED (AC1)" "out=[$c1_out]"
fi

if ! printf '%s\n' "$c1_out" | grep -qF "UNCLAIMED: a/trailing-comma.sh"; then
  pass "07: trailing-comma bullet claimed, no UNCLAIMED (AC1)"
else
  fail "07: trailing-comma bullet claimed, no UNCLAIMED (AC1)" "out=[$c1_out]"
fi

if ! printf '%s\n' "$c1_out" | grep -qF "UNCLAIMED: a/dotslash.sh"; then
  pass "08: ./-prefixed bullet claimed, no UNCLAIMED (AC1)"
else
  fail "08: ./-prefixed bullet claimed, no UNCLAIMED (AC1)" "out=[$c1_out]"
fi

if ! printf '%s\n' "$c1_out" | grep -qF "UNCLAIMED: a/absolute.sh"; then
  pass "09: absolute-path bullet claimed, no UNCLAIMED (AC1)"
else
  fail "09: absolute-path bullet claimed, no UNCLAIMED (AC1)" "out=[$c1_out]"
fi

if [ "$c1_code" -eq 0 ] && printf '%s\n' "$c1_out" | grep -q '^OK:'; then
  pass "10: case-set-1 run exits 0 with an OK: line (AC1)"
else
  fail "10: case-set-1 run exits 0 with an OK: line (AC1)" "code=$c1_code out=[$c1_out]"
fi

# ---------------------------------------------------------------------------
# Case set 2: false-positive direction still works (AC2, "the criterion that
# matters most") -- a genuinely unclaimed changed file must still fail loudly.
# ---------------------------------------------------------------------------

# --- 2a: in isolation, a report with zero relevant bullets -----------------
c2a_wt=$(new_git_worktree)
c2a_base=$(git -C "$c2a_wt" rev-parse HEAD)
mkdir -p "$c2a_wt/b"
printf 'x\n' >"$c2a_wt/b/unclaimed.sh"
commit_all "$c2a_wt" "add unclaimed file"

c2a_rundir=$(new_scratch)
mkdir -p "$c2a_rundir/reports"
cat >"$c2a_rundir/reports/case2a-exit.md" <<'EOF'
# case2a exit report

## Files touched
- c/not-relevant.sh
EOF

run_script "$SCRIPT_RUN" "$c2a_wt" "$c2a_base" "$c2a_rundir"
if [ "$CODE" -ne 0 ] \
   && printf '%s\n' "$OUT" | grep -q '^FAIL:' \
   && printf '%s\n' "$OUT" | grep -qF "UNCLAIMED: b/unclaimed.sh"; then
  pass "11: genuinely unclaimed file (isolation) prints UNCLAIMED, exit nonzero, FAIL: line (AC2)"
else
  fail "11: genuinely unclaimed file (isolation) prints UNCLAIMED, exit nonzero, FAIL: line (AC2)" \
    "code=$CODE out=[$OUT]"
fi

# --- 2b: alongside case set 1's claimed fixtures ----------------------------
c2b_wt=$(new_git_worktree)
c2b_base=$(git -C "$c2b_wt" rev-parse HEAD)
mkdir -p "$c2b_wt/a" "$c2b_wt/b"
printf 'plain\n' >"$c2b_wt/a/plain.sh"
printf 'backtick\n' >"$c2b_wt/a/backtick.sh"
printf 'backtick-paren\n' >"$c2b_wt/a/backtick-paren.sh"
printf 'backtick-annotation\n' >"$c2b_wt/a/backtick-annotation.sh"
printf 'trailing-comma\n' >"$c2b_wt/a/trailing-comma.sh"
printf 'dotslash\n' >"$c2b_wt/a/dotslash.sh"
printf 'absolute\n' >"$c2b_wt/a/absolute.sh"
printf 'y\n' >"$c2b_wt/b/unclaimed2.sh"
commit_all "$c2b_wt" "seven claimed + one unclaimed"
c2b_abs="$c2b_wt/a/absolute.sh"

c2b_rundir=$(new_scratch)
mkdir -p "$c2b_rundir/reports"
cat >"$c2b_rundir/reports/case2b-exit.md" <<'EOF'
# case2b exit report

## Files touched
- a/plain.sh
- `a/backtick.sh`
- `a/backtick-paren.sh` (new)
- `a/backtick-annotation.sh` — some annotation
- a/trailing-comma.sh,
- ./a/dotslash.sh
EOF
printf -- '- %s\n' "$c2b_abs" >>"$c2b_rundir/reports/case2b-exit.md"

run_script "$SCRIPT_RUN" "$c2b_wt" "$c2b_base" "$c2b_rundir"
c2b_out="$OUT"
c2b_ok=1
[ "$CODE" -ne 0 ] || c2b_ok=0
printf '%s\n' "$c2b_out" | grep -qF "UNCLAIMED: b/unclaimed2.sh" || c2b_ok=0
for p in a/plain.sh a/backtick.sh a/backtick-paren.sh a/backtick-annotation.sh a/trailing-comma.sh a/dotslash.sh a/absolute.sh; do
  printf '%s\n' "$c2b_out" | grep -qF "UNCLAIMED: $p" && c2b_ok=0
done
if [ "$c2b_ok" -eq 1 ]; then
  pass "12: run with both claimed and one genuinely-unclaimed file still fails on the unclaimed one only (AC2)"
else
  fail "12: run with both claimed and one genuinely-unclaimed file still fails on the unclaimed one only (AC2)" \
    "code=$CODE out=[$c2b_out]"
fi

# ---------------------------------------------------------------------------
# Case set 3: multi-backtick bullet claims only the first token (AC3)
# ---------------------------------------------------------------------------
c3_wt=$(new_git_worktree)
c3_base=$(git -C "$c3_wt" rev-parse HEAD)
printf 'a\n' >"$c3_wt/a.sh"
printf 'b\n' >"$c3_wt/b.sh"
commit_all "$c3_wt" "add a.sh and b.sh"

c3_rundir=$(new_scratch)
mkdir -p "$c3_rundir/reports"
cat >"$c3_rundir/reports/case3-exit.md" <<'EOF'
# case3 exit report

## Files touched
- `a.sh` — see `b.sh` for rationale
EOF

run_script "$SCRIPT_RUN" "$c3_wt" "$c3_base" "$c3_rundir"
c3_out="$OUT"
c3_err="$ERR"

if ! printf '%s\n' "$c3_out" | grep -qF "UNCLAIMED: a.sh"; then
  pass "13: multi-backtick bullet's first token (a.sh) is claimed (AC3)"
else
  fail "13: multi-backtick bullet's first token (a.sh) is claimed (AC3)" "out=[$c3_out]"
fi

if printf '%s\n' "$c3_err" | grep -q '^NOTE:' \
   && printf '%s\n' "$c3_err" | grep -qF "case3-exit.md" \
   && printf '%s\n' "$c3_err" | grep -qF "a.sh"; then
  pass "14: NOTE: line on stderr names the report and the bullet content (AC3)"
else
  fail "14: NOTE: line on stderr names the report and the bullet content (AC3)" "err=[$c3_err]"
fi

if printf '%s\n' "$c3_out" | grep -qF "UNCLAIMED: b.sh"; then
  pass "15: second backticked name (b.sh) is NOT claimed on its own (AC3)"
else
  fail "15: second backticked name (b.sh) is NOT claimed on its own (AC3)" "out=[$c3_out]"
fi

# ---------------------------------------------------------------------------
# Case set 4: harness-owned paths and --allow still work (AC4)
# ---------------------------------------------------------------------------

# --- 4a: a .gitignore change with zero reports claiming it ------------------
c4a_wt=$(new_git_worktree)
c4a_base=$(git -C "$c4a_wt" rev-parse HEAD)
printf '*.log\n' >"$c4a_wt/.gitignore"
commit_all "$c4a_wt" "add .gitignore"

c4a_rundir=$(new_scratch)
mkdir -p "$c4a_rundir/reports"

run_script "$SCRIPT_RUN" "$c4a_wt" "$c4a_base" "$c4a_rundir"
if [ "$CODE" -eq 0 ] && ! printf '%s\n' "$OUT" | grep -qF "UNCLAIMED: .gitignore"; then
  pass "16: harness-owned .gitignore change is not UNCLAIMED with zero claiming reports (AC4)"
else
  fail "16: harness-owned .gitignore change is not UNCLAIMED with zero claiming reports (AC4)" \
    "code=$CODE out=[$OUT]"
fi

# --- 4b: a file covered only by --allow <prefix> ----------------------------
c4b_wt=$(new_git_worktree)
c4b_base=$(git -C "$c4b_wt" rev-parse HEAD)
mkdir -p "$c4b_wt/generated"
printf 'out\n' >"$c4b_wt/generated/output.txt"
commit_all "$c4b_wt" "add generated output"

c4b_rundir=$(new_scratch)
mkdir -p "$c4b_rundir/reports"

run_script "$SCRIPT_RUN" "$c4b_wt" "$c4b_base" "$c4b_rundir" --allow "generated/"
if [ "$CODE" -eq 0 ] && ! printf '%s\n' "$OUT" | grep -qF "UNCLAIMED: generated/output.txt"; then
  pass "17: file covered only by --allow <prefix> is not UNCLAIMED (AC4)"
else
  fail "17: file covered only by --allow <prefix> is not UNCLAIMED (AC4)" \
    "code=$CODE out=[$OUT]"
fi

# ---------------------------------------------------------------------------
# Case set 5: verify-scope.sh --report / stdin equivalence, no-flag smoke (AC5)
# ---------------------------------------------------------------------------
c5_wt=$(new_git_worktree)
c5_base=$(git -C "$c5_wt" rev-parse HEAD)
mkdir -p "$c5_wt/a"
printf 'p\n' >"$c5_wt/a/plain5.sh"
printf 'b\n' >"$c5_wt/a/backtick5.sh"
commit_all "$c5_wt" "add case5 targets"

c5_rundir=$(new_scratch)
mkdir -p "$c5_rundir/reports"
cat >"$c5_rundir/reports/case5-exit.md" <<'EOF'
# case5 exit report

## Files touched
- a/plain5.sh
- `a/backtick5.sh`
EOF

run_script "$SCRIPT_VERIFY" "$c5_wt" "$c5_base" --report "$c5_rundir/reports/case5-exit.md"
c5_report_out="$OUT"
c5_report_code="$CODE"

c5_paths="a/plain5.sh
a/backtick5.sh"
run_script_stdin "$SCRIPT_VERIFY" "$c5_paths" "$c5_wt" "$c5_base"
c5_stdin_out="$OUT"
c5_stdin_code="$CODE"

if [ "$c5_report_out" = "$c5_stdin_out" ] && [ "$c5_report_code" -eq "$c5_stdin_code" ]; then
  pass "18: verify-scope.sh --report produces byte-identical stdout to the pre-extracted stdin list, same exit code (AC5)"
else
  fail "18: verify-scope.sh --report produces byte-identical stdout to the pre-extracted stdin list, same exit code (AC5)" \
    "report_code=$c5_report_code report_out=[$c5_report_out] stdin_code=$c5_stdin_code stdin_out=[$c5_stdin_out]"
fi

# --- no-flag smoke: matched claim on argv, no --report, no stdin -----------
c5m_wt=$(new_git_worktree)
c5m_base=$(git -C "$c5m_wt" rev-parse HEAD)
mkdir -p "$c5m_wt/x"
printf 'z\n' >"$c5m_wt/x/y.sh"
commit_all "$c5m_wt" "add x/y.sh"

run_script "$SCRIPT_VERIFY" "$c5m_wt" "$c5m_base" "x/y.sh"
if [ "$CODE" -eq 0 ]; then
  pass "19: no --report flag, argv claim matches the only changed file, exits 0 (AC5)"
else
  fail "19: no --report flag, argv claim matches the only changed file, exits 0 (AC5)" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# --- no-flag smoke: changed file with nothing reported/claimed at all ------
c5u_wt=$(new_git_worktree)
c5u_base=$(git -C "$c5u_wt" rev-parse HEAD)
mkdir -p "$c5u_wt/x"
printf 'z\n' >"$c5u_wt/x/z.sh"
commit_all "$c5u_wt" "add x/z.sh"

run_script "$SCRIPT_VERIFY" "$c5u_wt" "$c5u_base"
if [ "$CODE" -ne 0 ]; then
  pass "20: no --report flag, no argv/stdin claims, a changed file exists, exits nonzero (AC5)"
else
  fail "20: no --report flag, no argv/stdin claims, a changed file exists, exits nonzero (AC5)" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Lane-4 additions (contracts/l4.md, Packet P2 / P2t) -- CLAUDE_DOCS_DIR is
# always a local path, enforced by resolve-config.sh's --expect path and
# surfaced (not silently swallowed) by verify-run-scope.sh. Written from the
# P2 contract text alone; never reads verify-run-scope.sh's or
# resolve-config.sh's source.
# ---------------------------------------------------------------------------

# new_fixture_hookdir -- prints a fresh scratch dir containing a COPY (cp,
# not a read) of the real script under test plus a STUB resolve-config.sh.
# verify-run-scope.sh locates its resolver as a sibling of itself
# ($(dirname "${BASH_SOURCE[0]}")/resolve-config.sh per the contract), so
# this puts a test at the CLAUDE_DOCS_DIR resolution seam without any
# dependence on the real resolver's internals. The stub:
#   - logs every invocation's argv (var name plus all flags) to argv.log
#     beside itself, for the --expect-path-was-passed assertion (case 24);
#   - always resolves CLAUDE_PROJECT_PLANS_DIR successfully (a stub that
#     failed it would confound every case, per the contract);
#   - resolves CLAUDE_DOCS_DIR according to $STUB_MODE: "normal" (default)
#     succeeds with /docs; "unresolvable" and "rejecting" fail with the
#     exact contract message shapes for those two failure modes.
new_fixture_hookdir() {
  local dir
  dir=$(new_scratch)
  cp "$SCRIPT_RUN" "$dir/verify-run-scope.sh"
  chmod +x "$dir/verify-run-scope.sh"
  cat >"$dir/resolve-config.sh" <<'STUB'
#!/usr/bin/env bash
self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
printf '%s\n' "$*" >>"$self_dir/argv.log"
var="$1"
case "$var" in
  CLAUDE_PROJECT_PLANS_DIR)
    printf '%s\n' "/project-plans/"
    exit 0
    ;;
  CLAUDE_DOCS_DIR)
    case "${STUB_MODE:-normal}" in
      unresolvable)
        echo "resolve-config: cannot resolve CLAUDE_DOCS_DIR (no settings.local.json/settings.json/global settings.json value, and no usable default)" >&2
        exit 1
        ;;
      rejecting)
        echo "resolve-config: CLAUDE_DOCS_DIR must be a local path; a Confluence location belongs in CLAUDE_DOCS_PUBLISH (got: 'confluence:ENG')" >&2
        exit 1
        ;;
      *)
        printf '%s\n' "/docs"
        exit 0
        ;;
    esac
    ;;
  *)
    echo "stub resolve-config.sh: unexpected var $var" >&2
    exit 1
    ;;
esac
STUB
  chmod +x "$dir/resolve-config.sh"
  printf '%s' "$dir"
}

# ---------------------------------------------------------------------------
# Case set 6: docs/ and project-plans/ prefixes still allowed after the dead
# branch's removal, against the REAL resolver (P2 AC1 -- byte-identical
# allowed-prefix list; pure dead-code removal plus a declaration).
# ---------------------------------------------------------------------------

# --- 6a: both prefixes present, zero claiming reports, must still pass -----
c6a_wt=$(new_git_worktree)
c6a_base=$(git -C "$c6a_wt" rev-parse HEAD)
mkdir -p "$c6a_wt/docs" "$c6a_wt/project-plans"
printf 'x\n' >"$c6a_wt/docs/x.md"
printf 'y\n' >"$c6a_wt/project-plans/y.md"
commit_all "$c6a_wt" "add docs and project-plans files"

c6a_rundir=$(new_scratch)
mkdir -p "$c6a_rundir/reports"

run_script "$SCRIPT_RUN" "$c6a_wt" "$c6a_base" "$c6a_rundir"
if [ "$CODE" -eq 0 ] \
   && ! printf '%s\n' "$OUT" | grep -qF "UNCLAIMED: docs/x.md" \
   && ! printf '%s\n' "$OUT" | grep -qF "UNCLAIMED: project-plans/y.md" \
   && printf '%s\n' "$OUT" | grep -q '^OK:'; then
  pass "21: docs/ and project-plans/ prefixes both still allowed with zero claiming reports, exit 0 with an OK: line (P2 AC1)"
else
  fail "21: docs/ and project-plans/ prefixes both still allowed with zero claiming reports, exit 0 with an OK: line (P2 AC1)" \
    "code=$CODE out=[$OUT]"
fi

# --- 6b: negative control -- neither-prefix file, unclaimed, still fails ---
c6b_wt=$(new_git_worktree)
c6b_base=$(git -C "$c6b_wt" rev-parse HEAD)
mkdir -p "$c6b_wt/elsewhere"
printf 'z\n' >"$c6b_wt/elsewhere/z.md"
commit_all "$c6b_wt" "add file under neither prefix"

c6b_rundir=$(new_scratch)
mkdir -p "$c6b_rundir/reports"

run_script "$SCRIPT_RUN" "$c6b_wt" "$c6b_base" "$c6b_rundir"
if [ "$CODE" -ne 0 ] && printf '%s\n' "$OUT" | grep -qF "UNCLAIMED: elsewhere/z.md"; then
  pass "22: a file under neither the docs/ nor project-plans/ prefix, unclaimed, still fails loudly -- proves 21 cannot pass by allowing everything (P2 AC1)"
else
  fail "22: a file under neither the docs/ nor project-plans/ prefix, unclaimed, still fails loudly -- proves 21 cannot pass by allowing everything (P2 AC1)" \
    "code=$CODE out=[$OUT]"
fi

# ---------------------------------------------------------------------------
# Case E: the dead http*/confluence: case is gone (P2 AC2). Source-text
# assertion about a deletion, stated verbatim by the plan as a criterion.
# ---------------------------------------------------------------------------
ce_grep_out=$(grep -n 'http\*\|confluence:' "$SCRIPT_RUN")
if [ -z "$ce_grep_out" ]; then
  pass "23: grep -n 'http\\*\\|confluence:' over verify-run-scope.sh returns nothing (P2 AC2)"
else
  fail "23: grep -n 'http\\*\\|confluence:' over verify-run-scope.sh returns nothing (P2 AC2)" \
    "matched: $ce_grep_out"
fi

# ---------------------------------------------------------------------------
# Case set 7: the resolve-config.sh call for CLAUDE_DOCS_DIR passes
# --expect path (P2 AC3). Fixture hook dir + recording stub.
# ---------------------------------------------------------------------------
c7_hookdir=$(new_fixture_hookdir)
c7_wt=$(new_git_worktree)
c7_base=$(git -C "$c7_wt" rev-parse HEAD)
mkdir -p "$c7_wt/docs"
printf 'note\n' >"$c7_wt/docs/b-note.md"
commit_all "$c7_wt" "add docs note"

c7_rundir=$(new_scratch)
mkdir -p "$c7_rundir/reports"

run_script "$c7_hookdir/verify-run-scope.sh" "$c7_wt" "$c7_base" "$c7_rundir"

c7_docs_line=$(grep '^CLAUDE_DOCS_DIR' "$c7_hookdir/argv.log" 2>/dev/null | head -n1)
if printf '%s' "$c7_docs_line" | grep -qF -- '--expect path'; then
  pass "24: the resolve-config.sh call for CLAUDE_DOCS_DIR passes --expect path (P2 AC3)"
else
  fail "24: the resolve-config.sh call for CLAUDE_DOCS_DIR passes --expect path (P2 AC3)" \
    "argv.log=[$(cat "$c7_hookdir/argv.log" 2>/dev/null)]"
fi

# ---------------------------------------------------------------------------
# Case set 8: an unresolvable CLAUDE_DOCS_DIR still falls back to /docs and
# the run continues (P2 AC4). Fixture hook dir + unresolvable stub.
# ---------------------------------------------------------------------------
c8_hookdir=$(new_fixture_hookdir)
c8_wt=$(new_git_worktree)
c8_base=$(git -C "$c8_wt" rev-parse HEAD)
mkdir -p "$c8_wt/docs"
printf 'note\n' >"$c8_wt/docs/c-note.md"
commit_all "$c8_wt" "add docs note"

c8_rundir=$(new_scratch)
mkdir -p "$c8_rundir/reports"

export STUB_MODE=unresolvable
run_script "$c8_hookdir/verify-run-scope.sh" "$c8_wt" "$c8_base" "$c8_rundir"
unset STUB_MODE

if [ "$CODE" -eq 0 ] && ! printf '%s\n' "$OUT" | grep -qF "UNCLAIMED: docs/c-note.md"; then
  pass "25: an unresolvable CLAUDE_DOCS_DIR still falls back to /docs and the run continues (P2 AC4)"
else
  fail "25: an unresolvable CLAUDE_DOCS_DIR still falls back to /docs and the run continues (P2 AC4)" \
    "code=$CODE out=[$OUT]"
fi

# ---------------------------------------------------------------------------
# Case set 9: THE REGRESSION THAT PROTECTS THE MIGRATION PATH. A rejected
# CLAUDE_DOCS_DIR (old Confluence config) surfaces the resolver's error
# rather than silently falling back and fabricating a docs root (P2 AC5).
# Fixture hook dir + rejecting stub. Asserts all three of: exit 1, the
# resolver's message on stderr, and the ABSENCE of an OK: line -- a case
# that only checked the exit code would pass against a buggy script that
# fell back and then failed for an unrelated reason.
# ---------------------------------------------------------------------------
c9_hookdir=$(new_fixture_hookdir)
c9_wt=$(new_git_worktree)
c9_base=$(git -C "$c9_wt" rev-parse HEAD)
mkdir -p "$c9_wt/docs"
printf 'note\n' >"$c9_wt/docs/d-note.md"
commit_all "$c9_wt" "add docs note"

c9_rundir=$(new_scratch)
mkdir -p "$c9_rundir/reports"

export STUB_MODE=rejecting
run_script "$c9_hookdir/verify-run-scope.sh" "$c9_wt" "$c9_base" "$c9_rundir"
unset STUB_MODE

if [ "$CODE" -ne 0 ] \
   && printf '%s\n' "$ERR" | grep -qF 'must be a local path' \
   && ! printf '%s\n' "$OUT" | grep -q '^OK:'; then
  pass "26: a rejected CLAUDE_DOCS_DIR surfaces the resolver's error and does not fall back -- exit nonzero, 'must be a local path' on stderr, no OK: line on stdout (P2 AC5)"
else
  fail "26: a rejected CLAUDE_DOCS_DIR surfaces the resolver's error and does not fall back -- exit nonzero, 'must be a local path' on stderr, no OK: line on stdout (P2 AC5)" \
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
