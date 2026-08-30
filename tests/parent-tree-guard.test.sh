#!/usr/bin/env bash
# parent-tree-guard.test.sh
#
# SYNOPSIS
#   bash tests/parent-tree-guard.test.sh
#
# DESCRIPTION
#   Blind contract test for orchestrators/hooks/parent-tree-guard.sh (Packet
#   2, subphase 4.2): a PostToolUse/Stop hook that walks up from the JSON
#   payload's "cwd" (or the process's actual $PWD if cwd is missing/the
#   payload can't be parsed) looking for an ancestor directory containing
#   .artifacts/progress-log.md (the "marker", same convention as the sibling
#   hook scope-writes.sh). No marker anywhere in the ancestry -> exit 0,
#   inert. A marker found -> that ancestor is the "marked parent worktree";
#   `git status --porcelain` there is classified path by path into ALLOWED
#   (resolves under the resolved CLAUDE_PROJECT_PLANS_DIR or CLAUDE_DOCS_DIR,
#   both worktree-root-relative via resolve-config.sh) or a PRODUCT CHANGE.
#   Zero product changes -> exit 0; one or more -> exit 2 naming every
#   offending path on stderr.
#
#   Written from the contract text alone. Never reads
#   orchestrators/hooks/parent-tree-guard.sh's source, in any mode -- nor
#   scope-writes.sh's or verify-scope.sh's. resolve-config.sh IS read and
#   shelled out to (a pattern/tool, not the implementation under test) to
#   learn the real resolved plans/docs dirs for fixtures.
#
# EXIT CODES
#   0  every case passed
#   1  at least one case failed (or the bash -n sanity precondition failed)
#
# Runnable as `bash tests/parent-tree-guard.test.sh` from any working
# directory.

set -uo pipefail

# ---------------------------------------------------------------------------
# Locate the script under test relative to this file's own location.
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/orchestrators/hooks/parent-tree-guard.sh"
RESOLVE_CONFIG="$REPO_ROOT/orchestrators/hooks/resolve-config.sh"

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
# Fixture helpers
# ---------------------------------------------------------------------------

git_init_repo() {
  local dir="$1"
  git -C "$dir" init -q
  git -C "$dir" config user.email "parent-tree-guard-test@example.com"
  git -C "$dir" config user.name "parent-tree-guard-test"
}

commit_all() {
  local dir="$1" msg="$2"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m "$msg" >/dev/null
}

# resolved_plans_dir / resolved_docs_dir <marked-root> -- shell out to the
# real resolve-config.sh (a tool, not the implementation under test) to
# learn where the hook is contractually supposed to look, exactly as the
# contract specifies the hook itself must call it.
resolved_plans_dir() {
  local root="$1" rel
  rel=$("$RESOLVE_CONFIG" CLAUDE_PROJECT_PLANS_DIR --default /project-plans/ --root "$root" 2>/dev/null)
  printf '%s' "${root%/}${rel}"
}

resolved_docs_dir() {
  local root="$1" rel
  rel=$("$RESOLVE_CONFIG" CLAUDE_DOCS_DIR --default /docs --root "$root" --expect path 2>/dev/null)
  printf '%s' "${root%/}${rel}"
}

# new_parent_worktree -- prints a fresh scratch dir path: git init'd, one
# baseline commit (README.md, a committed .gitignore containing
# `.artifacts/` -- the real repo's own convention per artifact-locations --
# and an ordinary tracked product file under orchestrators/hooks/), then the
# .artifacts/progress-log.md marker created (untracked -- the hook detects
# the marker by file EXISTENCE via -f, not via git, per the contract's
# fixture-construction note).
#
# .artifacts/ is gitignored in EVERY fixture built by this helper, not just
# case06's: the contract explicitly says behavior is UNSPECIFIED for a path
# under an un-gitignored, untracked .artifacts/ (case06 alone tests that
# directory's git-visible content). Leaving it un-gitignored here would make
# every "clean" / exit-0 assertion depend on that unspecified classification
# instead of on the acceptance criterion actually being tested.
new_parent_worktree() {
  local dir
  dir=$(new_scratch)
  git_init_repo "$dir"
  printf '# fixture repo\n' >"$dir/README.md"
  printf '.artifacts/\n' >"$dir/.gitignore"
  mkdir -p "$dir/orchestrators/hooks"
  printf 'echo baseline\n' >"$dir/orchestrators/hooks/some-file.sh"
  commit_all "$dir" "baseline"
  mkdir -p "$dir/.artifacts"
  printf 'baseline progress\n' >"$dir/.artifacts/progress-log.md"
  printf '%s' "$dir"
}

# run_guard <cwd-dir> [stdin-json] -- invokes the hook with cwd set to
# <cwd-dir> (subshell cd) and the given stdin (defaults to a PostToolUse
# payload naming <cwd-dir> as "cwd"). Sets globals OUT / ERR / CODE.
OUT=""
ERR=""
CODE=0
run_guard() {
  local cwd_dir="$1" stdin_json="${2-}"
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  if [ -z "${2+x}" ]; then
    stdin_json=$(printf '{"cwd": "%s", "tool_name": "Bash"}' "$cwd_dir")
  fi
  ( cd "$cwd_dir" && printf '%s' "$stdin_json" | "$SCRIPT" ) >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# ---------------------------------------------------------------------------
# Case 00: bash -n sanity precondition (script must at least parse)
# ---------------------------------------------------------------------------
SYN_ERR_FILE=$(mktemp)
if bash -n "$SCRIPT" 2>"$SYN_ERR_FILE"; then
  pass "00: bash -n parent-tree-guard.sh exits 0"
else
  fail "00: bash -n parent-tree-guard.sh exits 0" "syntax error: $(cat "$SYN_ERR_FILE")"
  rm -f "$SYN_ERR_FILE"
  echo "sanity failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
rm -f "$SYN_ERR_FILE"

# ---------------------------------------------------------------------------
# Case 01: clean parent worktree -> exit 0
# ---------------------------------------------------------------------------
case01() {
  local label="01: clean parent worktree (git status --porcelain reports nothing) -> exit 0"
  local wt
  wt=$(new_parent_worktree)
  run_guard "$wt"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case01

# ---------------------------------------------------------------------------
# Case 02: modified tracked product file -> exit 2, stderr names it
# ---------------------------------------------------------------------------
case02() {
  local label="02: modified tracked product file -> exit 2, stderr names it"
  local wt
  wt=$(new_parent_worktree)
  printf 'echo modified\n' >"$wt/orchestrators/hooks/some-file.sh"
  run_guard "$wt"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "orchestrators/hooks/some-file.sh"; then
    fail "$label -> stderr contains the literal path" "err=[$ERR]"
    return
  fi
  pass "$label"
}
case02

# ---------------------------------------------------------------------------
# Case 03: untracked product file -> exit 2, stderr names it
# ---------------------------------------------------------------------------
case03() {
  local label="03: untracked product file -> exit 2, stderr names it"
  local wt
  wt=$(new_parent_worktree)
  printf 'echo brand new\n' >"$wt/orchestrators/hooks/new-file.sh"
  run_guard "$wt"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "orchestrators/hooks/new-file.sh"; then
    fail "$label -> stderr contains the literal path" "err=[$ERR]"
    return
  fi
  pass "$label"
}
case03

# ---------------------------------------------------------------------------
# Case 04: modified file under the resolved plans dir -> exit 0
# ---------------------------------------------------------------------------
case04() {
  local label="04: modified file under the resolved plans dir -> exit 0"
  local wt plans_dir plan_file
  wt=$(new_parent_worktree)
  plans_dir=$(resolved_plans_dir "$wt")
  if [ -z "$plans_dir" ]; then
    fail "$label (prereq: resolve plans dir)" "resolve-config.sh could not resolve CLAUDE_PROJECT_PLANS_DIR"
    return
  fi
  mkdir -p "$plans_dir"
  plan_file="$plans_dir/existing-plan.md"
  printf '# plan\n' >"$plan_file"
  commit_all "$wt" "add plan file under plans dir"
  printf '# plan v2\n' >"$plan_file"
  run_guard "$wt"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "code=$CODE plans_dir=[$plans_dir] out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case04

# ---------------------------------------------------------------------------
# Case 05: modified file under the resolved docs dir -> exit 0
# ---------------------------------------------------------------------------
case05() {
  local label="05: modified file under the resolved docs dir -> exit 0"
  local wt docs_dir doc_file
  wt=$(new_parent_worktree)
  docs_dir=$(resolved_docs_dir "$wt")
  if [ -z "$docs_dir" ]; then
    fail "$label (prereq: resolve docs dir)" "resolve-config.sh could not resolve CLAUDE_DOCS_DIR"
    return
  fi
  mkdir -p "$docs_dir"
  doc_file="$docs_dir/existing-doc.md"
  printf '# doc\n' >"$doc_file"
  commit_all "$wt" "add doc file under docs dir"
  printf '# doc v2\n' >"$doc_file"
  run_guard "$wt"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "code=$CODE docs_dir=[$docs_dir] out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case05

# ---------------------------------------------------------------------------
# Case 06: dirty only under a .gitignore'd .artifacts/ -> exit 0
# ---------------------------------------------------------------------------
case06() {
  local label="06: dirty only under a .gitignore'd .artifacts/ -> exit 0"
  local wt
  wt=$(new_scratch)
  git_init_repo "$wt"
  printf '# fixture repo\n' >"$wt/README.md"
  mkdir -p "$wt/orchestrators/hooks"
  printf 'echo baseline\n' >"$wt/orchestrators/hooks/some-file.sh"
  printf '.artifacts/\n' >"$wt/.gitignore"
  commit_all "$wt" "baseline with .artifacts/ gitignored"
  mkdir -p "$wt/.artifacts"
  printf 'progress\n' >"$wt/.artifacts/progress-log.md"
  # Modify a second, uncommitted file under .artifacts/ too, to make sure
  # the dirt is entirely gitignored and produces nothing in git status.
  printf 'scratch\n' >"$wt/.artifacts/scratch.txt"

  # Sanity: confirm git status is actually clean under this fixture (the
  # contract's own caveat) before trusting the exit-0 assertion below.
  local porcelain
  porcelain=$(git -C "$wt" status --porcelain)
  if [ -n "$porcelain" ]; then
    fail "$label (prereq: git status --porcelain reports nothing)" "porcelain=[$porcelain]"
    return
  fi

  run_guard "$wt"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case06

# ---------------------------------------------------------------------------
# Case 07: rename outside plans/docs -> exit 2, stderr contains the NEW path
# ---------------------------------------------------------------------------
case07() {
  local label="07: git mv rename outside plans/docs -> exit 2, stderr contains the new path"
  local wt
  wt=$(new_parent_worktree)
  git -C "$wt" mv "orchestrators/hooks/some-file.sh" "orchestrators/hooks/renamed-file.sh"
  run_guard "$wt"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "orchestrators/hooks/renamed-file.sh"; then
    fail "$label -> stderr contains the new path" "err=[$ERR]"
    return
  fi
  pass "$label"
}
case07

# ---------------------------------------------------------------------------
# Case 08: cwd with NO marker in its ancestry (child-worktree stand-in) ->
# exit 0. Built as a git worktree of the parent so it has its own
# ancestry chain that never crosses the parent's .artifacts/ marker.
# ---------------------------------------------------------------------------
case08() {
  local label="08: cwd with no marker in its ancestry (child worktree stand-in) -> exit 0"
  local wt child
  wt=$(new_parent_worktree)
  child="$(new_scratch)/child-wt"
  if ! git -C "$wt" worktree add -q -b "case08-child" "$child" >/dev/null 2>&1; then
    fail "$label (prereq: git worktree add)" "could not create child worktree at $child"
    return
  fi
  # The child worktree must genuinely have no marker anywhere in its own
  # ancestry up to filesystem root for this case to test what it claims.
  if [ -f "$child/.artifacts/progress-log.md" ]; then
    fail "$label (prereq: child has no marker of its own)" "unexpected marker present"
    return
  fi
  run_guard "$child"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case08

# ---------------------------------------------------------------------------
# Case 09: cwd with no git repo and no marker at all -> exit 0
# ---------------------------------------------------------------------------
case09() {
  local label="09: cwd with no git repo and no marker anywhere -> exit 0"
  local dir
  dir=$(new_scratch)
  mkdir -p "$dir/some/nested/plain/dir"
  run_guard "$dir/some/nested/plain/dir"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case09

# ---------------------------------------------------------------------------
# Case 10: missing/empty stdin -> falls back to $PWD. Two sub-cases: the
# actual process cwd has a marker (parent) or doesn't (no marker), each run
# by literally cd-ing the test process there before invoking with empty
# stdin.
# ---------------------------------------------------------------------------
case10() {
  local label_a="10a: empty stdin, \$PWD is a marked parent with a product change -> exit 2 (fallback to \$PWD)"
  local label_b="10b: empty stdin, \$PWD has no marker in its ancestry -> exit 0 (fallback to \$PWD)"
  local wt no_marker_dir prev_pwd
  wt=$(new_parent_worktree)
  printf 'echo modified\n' >"$wt/orchestrators/hooks/some-file.sh"

  prev_pwd=$(pwd)
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  ( cd "$wt" && : | "$SCRIPT" ) >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"

  if [ "$CODE" -ne 2 ]; then
    fail "$label_a" "code=$CODE out=[$OUT] err=[$ERR]"
  elif ! printf '%s\n' "$ERR" | grep -qF "orchestrators/hooks/some-file.sh"; then
    fail "$label_a -> stderr names the path" "err=[$ERR]"
  else
    pass "$label_a"
  fi

  no_marker_dir=$(new_scratch)
  mkdir -p "$no_marker_dir/plain"
  out_f=$(mktemp)
  err_f=$(mktemp)
  ( cd "$no_marker_dir/plain" && : | "$SCRIPT" ) >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"

  if [ "$CODE" -ne 0 ]; then
    fail "$label_b" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label_b"
  fi
}
case10

# ---------------------------------------------------------------------------
# Case 11: multiple product changes -> exit 2, stderr names EVERY one
# ---------------------------------------------------------------------------
case11() {
  local label="11: two product changes (one modified, one untracked) -> exit 2, stderr names both"
  local wt
  wt=$(new_parent_worktree)
  printf 'echo modified\n' >"$wt/orchestrators/hooks/some-file.sh"
  printf 'echo new\n' >"$wt/orchestrators/hooks/another-new-file.sh"
  run_guard "$wt"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "orchestrators/hooks/some-file.sh"; then
    fail "$label -> stderr names the modified path" "err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "orchestrators/hooks/another-new-file.sh"; then
    fail "$label -> stderr names the untracked path" "err=[$ERR]"
    return
  fi
  pass "$label"
}
case11

# ---------------------------------------------------------------------------
# Case 12: Stop-shape payload (stop_hook_active field, no tool_name) with a
# marked, dirty parent still classifies correctly -> exit 2
# ---------------------------------------------------------------------------
case12() {
  local label="12: Stop-shape payload (stop_hook_active, no tool_name) -> exit 2 on a product change"
  local wt stdin_json
  wt=$(new_parent_worktree)
  printf 'echo modified\n' >"$wt/orchestrators/hooks/some-file.sh"
  stdin_json=$(printf '{"cwd": "%s", "stop_hook_active": false}' "$wt")
  run_guard "$wt" "$stdin_json"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "orchestrators/hooks/some-file.sh"; then
    fail "$label -> stderr names the path" "err=[$ERR]"
    return
  fi
  pass "$label"
}
case12

# ---------------------------------------------------------------------------
# Case 13: unparseable stdin -> falls back to \$PWD, same as missing stdin
# ---------------------------------------------------------------------------
case13() {
  local label="13: unparseable JSON on stdin -> falls back to \$PWD (marked parent, clean -> exit 0)"
  local wt out_f err_f
  wt=$(new_parent_worktree)
  out_f=$(mktemp)
  err_f=$(mktemp)
  ( cd "$wt" && printf 'not json at all {{{' | "$SCRIPT" ) >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case13

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
