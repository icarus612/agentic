#!/usr/bin/env bash
# workflow-setup-reuse.test.sh
#
# SYNOPSIS
#   bash tests/workflow-setup-reuse.test.sh
#
# DESCRIPTION
#   Blind contract test for orchestrators/hooks/workflow-setup.sh's --reuse
#   guard (contracts/l7.md, subphase 2.3): the [ -e "$path" ] check at :142
#   must become --reuse-aware so a surviving *worktree* (not just a surviving
#   *branch*) can be adopted after a crashed lane, guarded by a decision
#   table (C2) that only ever adopts a path that is a registered worktree of
#   this repo on the expected branch, and errors with specific substrings
#   otherwise (C6b/c/d). Written from the contract text and its "Documented
#   CLI" section alone. Never reads workflow-setup.sh's source, in any mode.
#
#   All fixtures are throwaway mktemp -d git repos, invoked with HOME pinned
#   to an empty scratch dir and --base main passed explicitly, so neither the
#   real repo, its real worktrees, nor the real $HOME are ever touched.
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
SCRIPT="$REPO_ROOT/orchestrators/hooks/workflow-setup.sh"

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
# Fixture-setup helper: runs a command, and on failure records why into
# CURRENT_SETUP_ERR instead of letting the case silently proceed. Every git
# call used to BUILD a fixture goes through this, per the "check your own
# fixture setup commands" requirement -- a failed setup step must fail the
# case, never let it fall through to a false PASS.
# ---------------------------------------------------------------------------
CURRENT_SETUP_ERR=""
step() {
  local desc="$1"
  shift
  local out
  if ! out=$("$@" 2>&1); then
    CURRENT_SETUP_ERR="$desc failed: $out"
    return 1
  fi
  CURRENT_SETUP_ERR=""
  return 0
}

# init_repo <dir> -- git init -b main, identity config, one commit containing
# shared.txt (base content, used by the merge-conflict case) and README.md.
init_repo() {
  local repo="$1"
  step "git init" git init -q -b main "$repo" || return 1
  step "git config user.email" git -C "$repo" config user.email "tester@example.com" || return 1
  step "git config user.name" git -C "$repo" config user.name "Tester" || return 1
  printf 'base\n' >"$repo/shared.txt" || return 1
  printf '# fixture repo\n' >"$repo/README.md" || return 1
  step "git add initial files" git -C "$repo" add -A || return 1
  step "git commit initial" git -C "$repo" commit -q -m "initial commit" || return 1
  return 0
}

# ---------------------------------------------------------------------------
# Invocation helper: pins HOME to an empty scratch dir, cwd inside the
# fixture repo, captures stdout/stderr/exit code separately into globals.
# ---------------------------------------------------------------------------
OUT=""
ERR=""
CODE=0
run_setup() {
  local repo="$1" home="$2"
  shift 2
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  ( cd "$repo" && HOME="$home" "$SCRIPT" "$@" ) </dev/null >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# get_field <text> <prefix-ending-in-": "> -- first line starting with the
# prefix, prefix stripped.
get_field() {
  printf '%s\n' "$1" | grep -m1 -- "^${2}" | sed "s/^${2}//"
}

# has_exact_line <text> <line> -- true iff <text> contains <line> as a whole
# line (used for the frozen REUSED: yes|no output, C7).
has_exact_line() {
  printf '%s\n' "$1" | grep -qxF -- "$2"
}

# phys_path <dir> -- symlink-resolved absolute path (C5's own comparison
# rule, reused here for the test's own registration checks).
phys_path() {
  ( cd "$1" 2>/dev/null && pwd -P )
}

# worktree_registered_at <repo> <path> <branch> -- true iff `git worktree
# list --porcelain` in <repo> shows a worktree at the physical path of
# <path> currently on refs/heads/<branch>.
worktree_registered_at() {
  local repo="$1" path="$2" branch="$3" pp
  pp=$(phys_path "$path") || return 1
  git -C "$repo" worktree list --porcelain 2>/dev/null | awk -v want="$pp" -v wantref="refs/heads/$branch" '
    /^worktree / { p=substr($0,10); cur_match=(p==want); next }
    /^branch /   { if (cur_match && $0=="branch " wantref) { found=1 } ; next }
    /^$/         { cur_match=0 }
    END { exit(found?0:1) }
  '
}

# no_merge_in_progress <worktree-dir>
no_merge_in_progress() {
  ! git -C "$1" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Case 00: bash -n sanity precondition (script must at least parse)
# ---------------------------------------------------------------------------
SYN_ERR_FILE=$(mktemp)
if bash -n "$SCRIPT" 2>"$SYN_ERR_FILE"; then
  pass "00: bash -n workflow-setup.sh exits 0"
else
  fail "00: bash -n workflow-setup.sh exits 0" "syntax error: $(cat "$SYN_ERR_FILE")"
  rm -f "$SYN_ERR_FILE"
  echo "sanity failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
rm -f "$SYN_ERR_FILE"

# ---------------------------------------------------------------------------
# Case 01: fresh create, no --reuse
# ---------------------------------------------------------------------------
case01() {
  local label="01: fresh create, no --reuse"
  local repo home wt_path branch rundir
  repo=$(new_scratch)
  home=$(new_scratch)
  init_repo "$repo" || { fail "$label" "$CURRENT_SETUP_ERR"; return; }

  run_setup "$repo" "$home" --name case01 --base main
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! has_exact_line "$OUT" "REUSED: no"; then
    fail "$label -> REUSED: no" "out=[$OUT]"
    return
  fi
  wt_path=$(get_field "$OUT" "WORKTREE: ")
  branch=$(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$branch" != "feature/case01" ]; then
    fail "$label -> worktree on feature/case01" "branch=[$branch] path=[$wt_path]"
    return
  fi
  rundir=$(get_field "$OUT" "RUNDIR: ")
  if [ -z "$rundir" ] || [ ! -d "$rundir/contracts" ] || [ ! -d "$rundir/reports" ]; then
    fail "$label -> RUNDIR present with contracts/ and reports/" "rundir=[$rundir] out=[$OUT]"
    return
  fi
  pass "$label -> exit 0, REUSED: no, worktree on feature/case01, RUNDIR has contracts/+reports/"
}
case01

# ---------------------------------------------------------------------------
# Case 02: --parent <branch> -- BASE: names the parent, no RUNDIR line
# ---------------------------------------------------------------------------
case02() {
  local label="02: --parent <branch>"
  local repo home base_field
  repo=$(new_scratch)
  home=$(new_scratch)
  init_repo "$repo" || { fail "$label" "$CURRENT_SETUP_ERR"; return; }
  step "create parent branch" git -C "$repo" branch parent-line main || { fail "$label" "$CURRENT_SETUP_ERR"; return; }

  run_setup "$repo" "$home" --name case02 --parent parent-line
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  base_field=$(get_field "$OUT" "BASE: ")
  if [ "$base_field" != "parent-line" ]; then
    fail "$label -> BASE: parent-line" "base_field=[$base_field] out=[$OUT]"
    return
  fi
  if printf '%s\n' "$OUT" | grep -q '^RUNDIR: '; then
    fail "$label -> no RUNDIR: line" "out=[$OUT]"
    return
  fi
  pass "$label -> exit 0, BASE: parent-line, no RUNDIR: line"
}
case02

# ---------------------------------------------------------------------------
# Case 03: path exists, no --reuse -> exit 1, C6a verbatim, nothing created
# ---------------------------------------------------------------------------
case03() {
  local label="03: path exists, no --reuse"
  local repo home path expected
  repo=$(new_scratch)
  home=$(new_scratch)
  init_repo "$repo" || { fail "$label" "$CURRENT_SETUP_ERR"; return; }
  path="$repo/.workflows/case03"
  mkdir -p "$path" || { fail "$label" "mkdir -p $path failed"; return; }
  echo "pre-existing" >"$path/marker.txt"

  run_setup "$repo" "$home" --name case03 --base main
  expected="workflow-setup: worktree path already exists: $path (pick another --name)"
  if [ "$CODE" -ne 1 ]; then
    fail "$label -> exit 1" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$expected"; then
    fail "$label -> stderr matches C6a verbatim" "expected=[$expected] err=[$ERR]"
    return
  fi
  if [ ! -f "$path/marker.txt" ] || [ -e "$path/.git" ] \
     || git -C "$repo" show-ref --verify --quiet refs/heads/feature/case03; then
    fail "$label -> nothing was created" "marker present=$( [ -f "$path/marker.txt" ] && echo yes || echo no ) .git present=$( [ -e "$path/.git" ] && echo yes || echo no )"
    return
  fi
  pass "$label -> exit 1, stderr verbatim C6a, nothing created"
}
case03

# ---------------------------------------------------------------------------
# Case 04: branch survives, worktree removed, --reuse -> today's behavior
# ---------------------------------------------------------------------------
case04() {
  local label="04: branch survives, worktree removed, --reuse"
  local repo home path path2 branch
  repo=$(new_scratch)
  home=$(new_scratch)
  init_repo "$repo" || { fail "$label" "$CURRENT_SETUP_ERR"; return; }

  run_setup "$repo" "$home" --name case04 --base main
  if [ "$CODE" -ne 0 ]; then
    fail "$label (prereq: fresh create)" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  path=$(get_field "$OUT" "WORKTREE: ")

  step "remove worktree, keep branch" git -C "$repo" worktree remove --force "$path" || { fail "$label" "$CURRENT_SETUP_ERR"; return; }
  if [ -e "$path" ]; then
    fail "$label (prereq: worktree dir gone)" "path still exists: $path"
    return
  fi

  echo "case04-marker" >"$repo/case04-marker.txt"
  step "add marker" git -C "$repo" add case04-marker.txt || { fail "$label" "$CURRENT_SETUP_ERR"; return; }
  step "commit marker on main" git -C "$repo" commit -q -m "case04 marker" || { fail "$label" "$CURRENT_SETUP_ERR"; return; }

  run_setup "$repo" "$home" --name case04 --base main --reuse
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! has_exact_line "$OUT" "REUSED: yes"; then
    fail "$label -> REUSED: yes" "out=[$OUT]"
    return
  fi
  path2=$(get_field "$OUT" "WORKTREE: ")
  if [ ! -f "$path2/case04-marker.txt" ]; then
    fail "$label -> merge brought in the post-divergence main commit" "path2=[$path2]"
    return
  fi
  branch=$(git -C "$path2" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$branch" != "feature/case04" ]; then
    fail "$label -> worktree on feature/case04" "branch=[$branch]"
    return
  fi
  pass "$label -> exit 0, REUSED: yes, worktree re-created with the new main commit merged in"
}
case04

# ---------------------------------------------------------------------------
# Case 05 -- the headline case. Branch AND worktree both survive (crash
# simulation): adoption merges the base in without git worktree add.
# ---------------------------------------------------------------------------
case05() {
  local label="05: branch AND worktree survive (headline adoption case)"
  local repo home path path2 branch marker_before marker_after
  repo=$(new_scratch)
  home=$(new_scratch)
  init_repo "$repo" || { fail "$label" "$CURRENT_SETUP_ERR"; return; }

  run_setup "$repo" "$home" --name case05 --base main
  if [ "$CODE" -ne 0 ]; then
    fail "$label (prereq: fresh create)" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  path=$(get_field "$OUT" "WORKTREE: ")

  echo "case05-marker-inode" >"$path/case05-marker.txt"
  marker_before=$(cat "$path/case05-marker.txt")

  echo "case05-new-main-content" >"$repo/case05-new.txt"
  step "add new main file" git -C "$repo" add case05-new.txt || { fail "$label" "$CURRENT_SETUP_ERR"; return; }
  step "commit new main file" git -C "$repo" commit -q -m "case05 new main content" || { fail "$label" "$CURRENT_SETUP_ERR"; return; }

  # Deliberately do NOT remove or touch the worktree -- this is the crash simulation.
  run_setup "$repo" "$home" --name case05 --base main --reuse
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! has_exact_line "$OUT" "REUSED: yes"; then
    fail "$label -> REUSED: yes" "out=[$OUT]"
    return
  fi
  path2=$(get_field "$OUT" "WORKTREE: ")
  if [ "$(phys_path "$path2")" != "$(phys_path "$path")" ]; then
    fail "$label -> same worktree directory reused, not recreated" "path=[$path] path2=[$path2]"
    return
  fi
  marker_after=$(cat "$path2/case05-marker.txt" 2>/dev/null || echo "MISSING")
  if [ "$marker_after" != "$marker_before" ]; then
    fail "$label -> pre-existing marker file survives adoption" "before=[$marker_before] after=[$marker_after]"
    return
  fi
  branch=$(git -C "$path2" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$branch" != "feature/case05" ]; then
    fail "$label -> still checked out on feature/case05" "branch=[$branch]"
    return
  fi
  if [ ! -f "$path2/case05-new.txt" ]; then
    fail "$label -> new main commit's file merged in" "path2=[$path2]"
    return
  fi
  pass "$label -> exit 0, REUSED: yes, same dir adopted (marker intact), base merged in"
}
case05

# ---------------------------------------------------------------------------
# Case 06: --reuse, $path is a plain directory, not a worktree -> exit 1
# ---------------------------------------------------------------------------
case06() {
  local label="06: --reuse, path exists but is not a registered worktree"
  local repo home path marker_before marker_after
  repo=$(new_scratch)
  home=$(new_scratch)
  init_repo "$repo" || { fail "$label" "$CURRENT_SETUP_ERR"; return; }
  path="$repo/.workflows/case06"
  mkdir -p "$path" || { fail "$label" "mkdir -p $path failed"; return; }
  echo "case06-marker" >"$path/marker.txt"
  marker_before=$(cat "$path/marker.txt")

  run_setup "$repo" "$home" --name case06 --base main --reuse
  if [ "$CODE" -ne 1 ]; then
    fail "$label -> exit 1" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -q "is not a registered worktree"; then
    fail "$label -> stderr contains 'is not a registered worktree'" "err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$path"; then
    fail "$label -> stderr names the offending path" "path=[$path] err=[$ERR]"
    return
  fi
  marker_after=$(cat "$path/marker.txt" 2>/dev/null || echo "MISSING")
  if [ "$marker_after" != "$marker_before" ] || [ -e "$path/.git" ]; then
    fail "$label -> directory left untouched" "before=[$marker_before] after=[$marker_after] .git=$( [ -e "$path/.git" ] && echo present || echo absent )"
    return
  fi
  pass "$label -> exit 1, stderr names the path and 'is not a registered worktree', untouched"
}
case06

# ---------------------------------------------------------------------------
# Case 07: --reuse, $path is a registered worktree on a different branch
# ---------------------------------------------------------------------------
case07() {
  local label="07: --reuse, worktree on a different branch"
  local repo home path branch_after
  repo=$(new_scratch)
  home=$(new_scratch)
  init_repo "$repo" || { fail "$label" "$CURRENT_SETUP_ERR"; return; }
  step "create other-branch" git -C "$repo" branch other-branch main || { fail "$label" "$CURRENT_SETUP_ERR"; return; }
  step "worktree add on other-branch" git -C "$repo" worktree add "$repo/.workflows/case07" other-branch || { fail "$label" "$CURRENT_SETUP_ERR"; return; }
  path="$repo/.workflows/case07"

  run_setup "$repo" "$home" --name case07 --base main --reuse
  if [ "$CODE" -ne 1 ]; then
    fail "$label -> exit 1" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -q "is on branch"; then
    fail "$label -> stderr contains 'is on branch'" "err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$path"; then
    fail "$label -> stderr names the path" "path=[$path] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "other-branch"; then
    fail "$label -> stderr names the actual branch (other-branch)" "err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "feature/case07"; then
    fail "$label -> stderr names the expected branch (feature/case07)" "err=[$ERR]"
    return
  fi
  branch_after=$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$branch_after" != "other-branch" ]; then
    fail "$label -> worktree left untouched, still on other-branch" "branch_after=[$branch_after]"
    return
  fi
  pass "$label -> exit 1, stderr names both branches and the path, untouched"
}
case07

# ---------------------------------------------------------------------------
# Case 08: --reuse, adoption merge conflict aborts without destroying the
# worktree (C4/C6d)
# ---------------------------------------------------------------------------
case08() {
  local label="08: --reuse, adoption merge conflict"
  local repo home path expected content_after
  repo=$(new_scratch)
  home=$(new_scratch)
  init_repo "$repo" || { fail "$label" "$CURRENT_SETUP_ERR"; return; }

  run_setup "$repo" "$home" --name case08 --base main
  if [ "$CODE" -ne 0 ]; then
    fail "$label (prereq: fresh create)" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  path=$(get_field "$OUT" "WORKTREE: ")

  echo "worktree-version" >"$path/shared.txt"
  step "commit divergent edit in worktree" bash -c "git -C '$path' add shared.txt && git -C '$path' commit -q -m 'worktree edit'" \
    || { fail "$label" "$CURRENT_SETUP_ERR"; return; }

  echo "main-version" >"$repo/shared.txt"
  step "commit divergent edit on main" bash -c "git -C '$repo' add shared.txt && git -C '$repo' commit -q -m 'main edit'" \
    || { fail "$label" "$CURRENT_SETUP_ERR"; return; }

  # Deliberately do NOT remove the worktree -- crash simulation, adoption path.
  run_setup "$repo" "$home" --name case08 --base main --reuse
  if [ "$CODE" -ne 1 ]; then
    fail "$label -> exit 1" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  expected="workflow-setup: merging 'main' into 'feature/case08' hit conflicts — resolve them manually, then re-run"
  if ! printf '%s\n' "$ERR" | grep -qF -- "$expected"; then
    fail "$label -> stderr matches C6d verbatim" "expected=[$expected] err=[$ERR]"
    return
  fi
  if [ ! -d "$path" ]; then
    fail "$label -> worktree directory still exists" "path=[$path]"
    return
  fi
  if ! worktree_registered_at "$repo" "$path" "feature/case08"; then
    fail "$label -> worktree still registered on feature/case08" "path=[$path]"
    return
  fi
  if ! no_merge_in_progress "$path"; then
    fail "$label -> no MERGE_HEAD left behind (merge --abort ran)" "path=[$path]"
    return
  fi
  content_after=$(cat "$path/shared.txt" 2>/dev/null || echo "MISSING")
  if [ "$content_after" != "worktree-version" ]; then
    fail "$label -> conflicted file is pre-merge content" "content_after=[$content_after]"
    return
  fi
  pass "$label -> exit 1, stderr verbatim C6d, worktree intact/registered, no MERGE_HEAD, pre-merge content"
}
case08

# ---------------------------------------------------------------------------
# Case 09: --reuse, $path is a worktree in detached HEAD
# ---------------------------------------------------------------------------
case09() {
  local label="09: --reuse, worktree in detached HEAD"
  local repo home path
  repo=$(new_scratch)
  home=$(new_scratch)
  init_repo "$repo" || { fail "$label" "$CURRENT_SETUP_ERR"; return; }
  step "worktree add --detach" git -C "$repo" worktree add --detach "$repo/.workflows/case09" main || { fail "$label" "$CURRENT_SETUP_ERR"; return; }
  path="$repo/.workflows/case09"

  run_setup "$repo" "$home" --name case09 --base main --reuse
  if [ "$CODE" -ne 1 ]; then
    fail "$label -> exit 1" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "(detached HEAD)"; then
    fail "$label -> stderr contains '(detached HEAD)'" "err=[$ERR]"
    return
  fi
  pass "$label -> exit 1, stderr contains '(detached HEAD)'"
}
case09

# ---------------------------------------------------------------------------
# Case 10: regression guards on untouched behavior
# ---------------------------------------------------------------------------
case10() {
  local repo home
  repo=$(new_scratch)
  home=$(new_scratch)
  init_repo "$repo" || { fail "10: regression guards (setup)" "$CURRENT_SETUP_ERR"; return; }

  # 10a: --type bogus -> exit 1 naming the five valid types
  run_setup "$repo" "$home" --name case10a --type bogus --base main
  local label_a="10a: --type bogus -> exit 1 naming the five valid types"
  if [ "$CODE" -ne 1 ]; then
    fail "$label_a" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    local missing="" t
    for t in feature bug hotfix docs sync; do
      printf '%s\n' "$ERR" | grep -qF -- "$t" || missing="$missing $t"
    done
    if [ -n "$missing" ]; then
      fail "$label_a" "stderr missing types:$missing err=[$ERR]"
    elif [ -e "$repo/.workflows/case10a" ] || git -C "$repo" show-ref --verify --quiet refs/heads/feature/case10a; then
      fail "$label_a" "side effects were created despite the error"
    else
      pass "$label_a"
    fi
  fi

  # 10b: --parent x --base y -> exit 1, mutual exclusion, nothing created
  run_setup "$repo" "$home" --name case10b --parent main --base main
  local label_b="10b: --parent + --base together -> exit 1 mutual exclusion"
  if [ "$CODE" -ne 1 ]; then
    fail "$label_b" "code=$CODE out=[$OUT] err=[$ERR]"
  elif ! printf '%s\n' "$ERR" | grep -q "workflow-setup:"; then
    fail "$label_b" "stderr does not carry the expected err() prefix: err=[$ERR]"
  elif [ -e "$repo/.workflows/case10b" ] || git -C "$repo" show-ref --verify --quiet refs/heads/feature/case10b; then
    fail "$label_b" "side effects were created despite the mutual-exclusion error"
  else
    pass "$label_b"
  fi
}
case10

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
