#!/usr/bin/env bash
# parent-tree-guard.test.sh
#
# SYNOPSIS
#   bash tests/parent-tree-guard.test.sh
#
# DESCRIPTION
#   Blind contract test for agent-agnostic/hooks/parent-tree-guard.sh (Packet
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
#   agent-agnostic/hooks/parent-tree-guard.sh's source, in any mode -- nor
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
SCRIPT="$REPO_ROOT/agent-agnostic/hooks/parent-tree-guard.sh"
RESOLVE_CONFIG="$REPO_ROOT/agent-agnostic/hooks/resolve-config.sh"

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
# and an ordinary tracked product file under agent-agnostic/hooks/), then the
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
  mkdir -p "$dir/agent-agnostic/hooks"
  printf 'echo baseline\n' >"$dir/agent-agnostic/hooks/some-file.sh"
  commit_all "$dir" "baseline"
  mkdir -p "$dir/.artifacts"
  printf 'baseline progress\n' >"$dir/.artifacts/progress-log.md"
  printf '%s' "$dir"
}

# new_parent_worktree_with_role <role> -- like new_parent_worktree but also
# writes .artifacts/dae-role with the given content verbatim (a trailing
# newline is added). Lives under the same gitignored .artifacts/ as the
# progress-log.md marker, so it never appears in git status output -- also
# used, unmodified, to build a "garbage role" fixture by passing junk text.
new_parent_worktree_with_role() {
  local role="$1" d
  d=$(new_parent_worktree)
  printf '%s\n' "$role" >"$d/.artifacts/dae-role"
  printf '%s' "$d"
}

# new_lane_root_pair -- prints "<parent-path> <child-path>": a marked parent
# worktree at "<base>/run" (git repo, progress-log.md marker) and an
# UNMARKED sibling lane child at "<base>/run-l1" (its own separate git repo,
# no .artifacts at all), matching find_lane_root's "<parent-name>-l<n>"
# sibling shape. Both are real git repos since parent-tree-guard classifies
# via `git status --porcelain` run inside whatever cwd it's given (here, the
# child).
new_lane_root_pair() {
  local base parent child
  base=$(new_scratch)
  parent="$base/run"
  mkdir -p "$parent"
  git_init_repo "$parent"
  printf '# fixture repo\n' >"$parent/README.md"
  printf '.artifacts/\n' >"$parent/.gitignore"
  mkdir -p "$parent/agent-agnostic/hooks"
  printf 'echo baseline\n' >"$parent/agent-agnostic/hooks/some-file.sh"
  commit_all "$parent" "baseline"
  mkdir -p "$parent/.artifacts"
  printf 'baseline progress\n' >"$parent/.artifacts/progress-log.md"

  child="$base/run-l1"
  mkdir -p "$child/agent-agnostic/hooks"
  git_init_repo "$child"
  printf '# fixture repo (lane child)\n' >"$child/README.md"
  printf 'echo baseline\n' >"$child/agent-agnostic/hooks/some-file.sh"
  commit_all "$child" "baseline"
  printf '%s %s' "$parent" "$child"
}

# new_parent_worktree_linked_with_role <role> -- like
# new_parent_worktree_with_role, but the fixture directory is a REAL LINKED
# git worktree (cut via `git worktree add` off a throwaway container repo
# that is itself built by new_parent_worktree), never a main checkout -- this
# models new/resume mode's parent-worktree topology, where `git rev-parse
# --git-dir` and `--git-common-dir` DIFFER (the one shape the A1 fix actually
# changes builder-role handling for). `git worktree add` checks out the
# container's committed tree (README.md, .gitignore, agent-agnostic/hooks/
# some-file.sh) automatically; only the untracked .artifacts/progress-log.md
# marker and dae-role file need to be added back by hand, matching
# new_parent_worktree's own baseline content so the offender-scan assertions
# have something to compare against. The container repo is a separate,
# independently-registered scratch dir.
LINKED_WT_COUNTER=0
new_parent_worktree_linked_with_role() {
  local role="$1" container target branch
  container=$(new_parent_worktree)
  target="$(new_scratch)/linked-wt"
  LINKED_WT_COUNTER=$((LINKED_WT_COUNTER + 1))
  branch="parent-tree-guard-linked-fixture-$LINKED_WT_COUNTER"
  git -C "$container" worktree add -q -b "$branch" "$target" >/dev/null 2>&1
  mkdir -p "$target/.artifacts"
  printf 'baseline progress\n' >"$target/.artifacts/progress-log.md"
  printf '%s\n' "$role" >"$target/.artifacts/dae-role"
  printf '%s' "$target"
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
  wt=$(new_parent_worktree_with_role "orchestrator")
  printf 'echo modified\n' >"$wt/agent-agnostic/hooks/some-file.sh"
  run_guard "$wt"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "agent-agnostic/hooks/some-file.sh"; then
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
  wt=$(new_parent_worktree_with_role "orchestrator")
  printf 'echo brand new\n' >"$wt/agent-agnostic/hooks/new-file.sh"
  run_guard "$wt"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "agent-agnostic/hooks/new-file.sh"; then
    fail "$label -> stderr contains the literal path" "err=[$ERR]"
    return
  fi
  pass "$label"
}
case03

# ---------------------------------------------------------------------------
# Case 04 (Packet C fallout): modified file under the resolved plans dir,
# named existing-plan.md (not *-review.md/sync-report.md) -> exit 2
# (offender). Positive control in the same fixture shape: a *-review.md
# change instead is still clean (exit 0).
# ---------------------------------------------------------------------------
case04() {
  local label="04: modified file under the resolved plans dir (non-matching name) -> exit 2 (offender)"
  local wt plans_dir plan_file
  wt=$(new_parent_worktree_with_role "orchestrator")
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
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE plans_dir=[$plans_dir] out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "existing-plan.md"; then
    fail "$label -> stderr names the offending path" "err=[$ERR]"
    return
  fi
  pass "$label"

  local wt2 plans_dir2 review_file
  wt2=$(new_parent_worktree_with_role "orchestrator")
  plans_dir2=$(resolved_plans_dir "$wt2")
  if [ -z "$plans_dir2" ]; then
    fail "04: positive control (prereq: resolve plans dir)" "resolve-config.sh could not resolve CLAUDE_PROJECT_PLANS_DIR"
    return
  fi
  mkdir -p "$plans_dir2"
  review_file="$plans_dir2/existing-plan-review.md"
  printf '# review\n' >"$review_file"
  commit_all "$wt2" "add review file under plans dir"
  printf '# review v2\n' >"$review_file"
  run_guard "$wt2"
  if [ "$CODE" -ne 0 ]; then
    fail "04: positive control -- *-review.md change under plans dir still clean" "code=$CODE plans_dir=[$plans_dir2] out=[$OUT] err=[$ERR]"
    return
  fi
  pass "04: positive control -- *-review.md change under plans dir still clean"
}
case04

# ---------------------------------------------------------------------------
# Case 05 (Packet C fallout): modified file under the resolved docs dir ->
# exit 2, unconditionally -- the docs root is never clean for orchestrator's
# rule. A positive control isn't possible for docs itself; instead, a
# *-review.md change under the PLANS dir in an otherwise-identical fresh
# fixture is shown still clean, proving the hook isn't just broken/
# blanket-denying.
# ---------------------------------------------------------------------------
case05() {
  local label="05: modified file under the resolved docs dir -> exit 2 (docs root never clean for orchestrator's rule)"
  local wt docs_dir doc_file
  wt=$(new_parent_worktree_with_role "orchestrator")
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
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE docs_dir=[$docs_dir] out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "existing-doc.md"; then
    fail "$label -> stderr names the offending path" "err=[$ERR]"
    return
  fi
  pass "$label"

  local wt2 plans_dir2 review_file
  wt2=$(new_parent_worktree_with_role "orchestrator")
  plans_dir2=$(resolved_plans_dir "$wt2")
  if [ -z "$plans_dir2" ]; then
    fail "05: positive control (prereq: resolve plans dir)" "resolve-config.sh could not resolve CLAUDE_PROJECT_PLANS_DIR"
    return
  fi
  mkdir -p "$plans_dir2"
  review_file="$plans_dir2/existing-plan-review.md"
  printf '# review\n' >"$review_file"
  commit_all "$wt2" "add review file under plans dir"
  printf '# review v2\n' >"$review_file"
  run_guard "$wt2"
  if [ "$CODE" -ne 0 ]; then
    fail "05: positive control -- *-review.md change under plans dir still clean (hook isn't blanket-denying)" "code=$CODE plans_dir=[$plans_dir2] out=[$OUT] err=[$ERR]"
    return
  fi
  pass "05: positive control -- *-review.md change under plans dir still clean (hook isn't blanket-denying)"
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
  mkdir -p "$wt/agent-agnostic/hooks"
  printf 'echo baseline\n' >"$wt/agent-agnostic/hooks/some-file.sh"
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
  wt=$(new_parent_worktree_with_role "orchestrator")
  git -C "$wt" mv "agent-agnostic/hooks/some-file.sh" "agent-agnostic/hooks/renamed-file.sh"
  run_guard "$wt"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "agent-agnostic/hooks/renamed-file.sh"; then
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
  wt=$(new_parent_worktree_with_role "orchestrator")
  printf 'echo modified\n' >"$wt/agent-agnostic/hooks/some-file.sh"

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
  elif ! printf '%s\n' "$ERR" | grep -qF "agent-agnostic/hooks/some-file.sh"; then
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
  wt=$(new_parent_worktree_with_role "orchestrator")
  printf 'echo modified\n' >"$wt/agent-agnostic/hooks/some-file.sh"
  printf 'echo new\n' >"$wt/agent-agnostic/hooks/another-new-file.sh"
  run_guard "$wt"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "agent-agnostic/hooks/some-file.sh"; then
    fail "$label -> stderr names the modified path" "err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "agent-agnostic/hooks/another-new-file.sh"; then
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
  wt=$(new_parent_worktree_with_role "orchestrator")
  printf 'echo modified\n' >"$wt/agent-agnostic/hooks/some-file.sh"
  stdin_json=$(printf '{"cwd": "%s", "stop_hook_active": false}' "$wt")
  run_guard "$wt" "$stdin_json"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "agent-agnostic/hooks/some-file.sh"; then
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
# Case 14: role=builder (from .artifacts/dae-role) -> a builder's own
# product changes in its own worktree are the entire point; only a
# plans/docs collision is the offense (inverted from every other role).
# Positive control (product change allowed) plus negative control (change
# under plans_root denied), separate fixtures per assertion.
#
# Fixture note: new_parent_worktree_with_role builds a plain `git_init_repo`
# -- i.e. a real git MAIN CHECKOUT, no linked worktree -- which specifically
# models --worktree none's topology. This case's outcome (allowed) is
# UNCHANGED by the A1 fix: --worktree none's legitimate builder marker flip
# still works. Contrast with case 20 below, the linked-worktree shape the fix
# actually changes.
# ---------------------------------------------------------------------------
case14() {
  local label="14: role=builder"
  local wt
  wt=$(new_parent_worktree_with_role "builder")
  printf 'echo modified\n' >"$wt/agent-agnostic/hooks/some-file.sh"
  run_guard "$wt"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> product change allowed" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label -> product change allowed"
  fi

  local wt2 plans_dir plan_file
  wt2=$(new_parent_worktree_with_role "builder")
  plans_dir=$(resolved_plans_dir "$wt2")
  if [ -z "$plans_dir" ]; then
    fail "$label (prereq: resolve plans dir)" "resolve-config.sh could not resolve CLAUDE_PROJECT_PLANS_DIR"
    return
  fi
  mkdir -p "$plans_dir"
  printf 'keep\n' >"$plans_dir/.keep"
  commit_all "$wt2" "seed plans dir"
  plan_file="$plans_dir/case14-plan.md"
  printf '# plan\n' >"$plan_file"
  run_guard "$wt2"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> change under plans_root denied" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "case14-plan.md"; then
    fail "$label -> stderr names the offending path" "err=[$ERR]"
    return
  fi
  pass "$label -> change under plans_root denied, stderr names it"
}
case14

# ---------------------------------------------------------------------------
# Case 15: role=planner -> continue (not an offender) only under plans_root;
# anything else (including docs/product) is an offender. Positive control
# (plans_root change allowed) plus negative control (product change denied).
# ---------------------------------------------------------------------------
case15() {
  local label="15: role=planner"
  local wt plans_dir plan_file
  wt=$(new_parent_worktree_with_role "planner")
  plans_dir=$(resolved_plans_dir "$wt")
  if [ -z "$plans_dir" ]; then
    fail "$label (prereq: resolve plans dir)" "resolve-config.sh could not resolve CLAUDE_PROJECT_PLANS_DIR"
    return
  fi
  mkdir -p "$plans_dir"
  plan_file="$plans_dir/case15-plan.md"
  printf '# plan\n' >"$plan_file"
  run_guard "$wt"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> change under plans_root allowed" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label -> change under plans_root allowed"
  fi

  local wt2
  wt2=$(new_parent_worktree_with_role "planner")
  printf 'echo modified\n' >"$wt2/agent-agnostic/hooks/some-file.sh"
  run_guard "$wt2"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> product change denied" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "agent-agnostic/hooks/some-file.sh"; then
    fail "$label -> stderr names the offending path" "err=[$ERR]"
    return
  fi
  pass "$label -> product change denied, stderr names it"
}
case15

# ---------------------------------------------------------------------------
# Case 16: role=orchestrator -> continue only under plans_root AND basename
# matches *-review.md / sync-report.md; anything else is an offender. Two
# positive controls (one per half of the OR) plus a negative control (a
# plans_root change that doesn't match either shape).
# ---------------------------------------------------------------------------
case16() {
  local label="16: role=orchestrator"
  local wt plans_dir review_file
  wt=$(new_parent_worktree_with_role "orchestrator")
  plans_dir=$(resolved_plans_dir "$wt")
  if [ -z "$plans_dir" ]; then
    fail "$label (prereq: resolve plans dir)" "resolve-config.sh could not resolve CLAUDE_PROJECT_PLANS_DIR"
    return
  fi
  mkdir -p "$plans_dir/case16-plan"
  printf 'keep\n' >"$plans_dir/case16-plan/.keep"
  commit_all "$wt" "seed plans dir"
  review_file="$plans_dir/case16-plan/plan-review.md"
  printf '# review\n' >"$review_file"
  run_guard "$wt"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> *-review.md under plans_root allowed" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label -> *-review.md under plans_root allowed"
  fi

  local wt2 plans_dir2 sync_file
  wt2=$(new_parent_worktree_with_role "orchestrator")
  plans_dir2=$(resolved_plans_dir "$wt2")
  mkdir -p "$plans_dir2/case16-plan"
  printf 'keep\n' >"$plans_dir2/case16-plan/.keep"
  commit_all "$wt2" "seed plans dir"
  sync_file="$plans_dir2/case16-plan/sync-report.md"
  printf '# sync\n' >"$sync_file"
  run_guard "$wt2"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> sync-report.md under plans_root allowed" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label -> sync-report.md under plans_root allowed"
  fi

  local wt3 plans_dir3 plan_file
  wt3=$(new_parent_worktree_with_role "orchestrator")
  plans_dir3=$(resolved_plans_dir "$wt3")
  mkdir -p "$plans_dir3/case16-plan"
  printf 'keep\n' >"$plans_dir3/case16-plan/.keep"
  commit_all "$wt3" "seed plans dir"
  plan_file="$plans_dir3/case16-plan/plan.md"
  printf '# plan\n' >"$plan_file"
  run_guard "$wt3"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> plan.md under plans_root (non-matching name) denied" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "case16-plan/plan.md"; then
    fail "$label -> stderr names the offending path" "err=[$ERR]"
    return
  fi
  pass "$label -> plan.md under plans_root denied, stderr names it"
}
case16

# ---------------------------------------------------------------------------
# Case 17: role=builder inferred structurally via find_lane_root (a lane
# child worktree, itself unmarked, sibling of a marked parent). Positive
# control (a product change in the child is allowed) plus negative control
# (a change under the CHILD's own local plans dir is denied -- this is the
# actual regression guard: it must resolve against the child's own root,
# not the parent's).
# ---------------------------------------------------------------------------
case17() {
  local label="17: role=builder via lane-root (child worktree, unmarked, sibling of a marked parent)"
  local pair parent child
  pair=$(new_lane_root_pair)
  parent="${pair% *}"
  child="${pair#* }"

  printf 'echo modified\n' >"$child/agent-agnostic/hooks/some-file.sh"
  run_guard "$child"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> product change in child allowed" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label -> product change in child allowed"
  fi

  local pair2 parent2 child2 plans_dir plan_file
  pair2=$(new_lane_root_pair)
  parent2="${pair2% *}"
  child2="${pair2#* }"
  plans_dir=$(resolved_plans_dir "$child2")
  if [ -z "$plans_dir" ]; then
    fail "$label (prereq: resolve plans dir)" "resolve-config.sh could not resolve CLAUDE_PROJECT_PLANS_DIR"
    return
  fi
  mkdir -p "$plans_dir"
  printf 'keep\n' >"$plans_dir/.keep"
  commit_all "$child2" "seed plans dir"
  plan_file="$plans_dir/case17-plan.md"
  printf '# plan\n' >"$plan_file"
  run_guard "$child2"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> change under child's own local plans-dir-shaped path denied" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "case17-plan.md"; then
    fail "$label -> stderr names the offending path" "err=[$ERR]"
    return
  fi
  pass "$label -> change under child's own local plans-dir-shaped path denied, stderr names it"
}
case17

# ---------------------------------------------------------------------------
# Case 18: .artifacts/dae-role holding garbage text falls back to EXACTLY
# the same outcome as no role file at all on an identical fixture/path pair
# (i.e. today's absent-role behavior: continue under plans_root, offend on a
# plain product change) -- proves the fallback, doesn't just assert it
# doesn't crash.
# ---------------------------------------------------------------------------
case18() {
  local label="18: role=garbage token falls back to default (absent-role) behavior"
  local wt plans_dir plan_file
  wt=$(new_parent_worktree_linked_with_role "not-a-real-role")
  plans_dir=$(resolved_plans_dir "$wt")
  if [ -z "$plans_dir" ]; then
    fail "$label (prereq: resolve plans dir)" "resolve-config.sh could not resolve CLAUDE_PROJECT_PLANS_DIR"
    return
  fi
  # plans_dir must already be a TRACKED, committed directory before the
  # offending file is added -- otherwise git reports the whole brand-new
  # directory as one untracked entry ("?? project-plans/") rather than the
  # individual file inside it, and a filename grep can't match (same
  # seed-then-commit shape as case14/case16/case23's plans_dir setup).
  mkdir -p "$plans_dir"
  printf 'keep\n' >"$plans_dir/.keep"
  commit_all "$wt" "seed plans dir"
  plan_file="$plans_dir/case18-plan.md"
  printf '# plan\n' >"$plan_file"
  run_guard "$wt"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> change under plans_root (non-matching name) now denied" "code=$CODE out=[$OUT] err=[$ERR]"
  elif ! printf '%s\n' "$ERR" | grep -qF "case18-plan.md"; then
    fail "$label -> stderr names the offending path" "err=[$ERR]"
  else
    pass "$label -> change under plans_root (non-matching name) now denied, stderr names it"
  fi

  local wt1b plans_dir1b review_file
  wt1b=$(new_parent_worktree_linked_with_role "not-a-real-role")
  plans_dir1b=$(resolved_plans_dir "$wt1b")
  if [ -z "$plans_dir1b" ]; then
    fail "$label (positive-control prereq: resolve plans dir)" "resolve-config.sh could not resolve CLAUDE_PROJECT_PLANS_DIR"
    return
  fi
  mkdir -p "$plans_dir1b"
  printf 'keep\n' >"$plans_dir1b/.keep"
  commit_all "$wt1b" "seed plans dir"
  review_file="$plans_dir1b/case18-plan-review.md"
  printf '# review\n' >"$review_file"
  run_guard "$wt1b"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> positive control: *-review.md under plans_root allowed" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label -> positive control: *-review.md under plans_root allowed"
  fi

  local wt2
  wt2=$(new_parent_worktree_linked_with_role "not-a-real-role")
  printf 'echo modified\n' >"$wt2/agent-agnostic/hooks/some-file.sh"
  run_guard "$wt2"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> product change denied (same as default fallback)" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "agent-agnostic/hooks/some-file.sh"; then
    fail "$label -> stderr names the offending path" "err=[$ERR]"
    return
  fi
  pass "$label -> product change denied (same as default fallback), stderr names it"
}
case18

# ---------------------------------------------------------------------------
# Case 19 (2.3's own required test): the shared helper function bodies
# (find_parent_worktree, find_lane_root, resolve_role, resolve_root_dir)
# must be byte-identical between scope-writes.sh and parent-tree-guard.sh
# per the Shared design section's duplication discipline. Extract each via
# sed, assert every extract is non-empty (positive control -- an empty
# extract from a botched sed range is a false "identical", not a real one),
# then diff the two files' extracts per function.
#
# Documented placement choice: this case lives here in
# parent-tree-guard.test.sh rather than scope-writes.test.sh (the contract
# leaves the choice to the tester).
# ---------------------------------------------------------------------------
case19() {
  local label="19: shared helper function bodies are byte-identical between scope-writes.sh and parent-tree-guard.sh"
  local scope_writes="$REPO_ROOT/agent-agnostic/hooks/scope-writes.sh"
  local fn a b

  if [ ! -f "$scope_writes" ]; then
    fail "$label (prereq: scope-writes.sh exists)" "not found at $scope_writes"
    return
  fi

  for fn in find_parent_worktree find_lane_root resolve_role resolve_root_dir; do
    a=$(sed -n "/^${fn}()/,/^}/p" "$scope_writes")
    b=$(sed -n "/^${fn}()/,/^}/p" "$SCRIPT")

    if [ -z "$a" ]; then
      fail "$label -> $fn extracted non-empty from scope-writes.sh" "empty extract (bad sed range, or function missing/renamed)"
      continue
    fi
    if [ -z "$b" ]; then
      fail "$label -> $fn extracted non-empty from parent-tree-guard.sh" "empty extract (bad sed range, or function missing/renamed)"
      continue
    fi

    if ! diff <(printf '%s\n' "$a") <(printf '%s\n' "$b") >/dev/null 2>&1; then
      fail "$label -> $fn byte-identical between both files" "extracts differ: scope-writes.sh=[$a] parent-tree-guard.sh=[$b]"
      continue
    fi
    pass "$label -> $fn: both extracts non-empty and byte-identical"
  done
}
case19

# ---------------------------------------------------------------------------
# Case 20: role=builder in a LINKED WORKTREE parent (new/resume topology) --
# the A1 fix rejects `builder` there (a genuine builder always runs in its
# own sibling lane child, never via the parent's own marker -- case 17
# above), so it falls back to absent-role behavior: a product-file change is
# now an OFFENDER (exit 2, was exit 0 before this fix). The
# parent-tree-guard-side mirror of scope-writes.sh's case 13b.
#
# NOTE ON STDERR SHAPE: per the contract's A2 pseudocode, the tamper check
# (case 21 below) runs BEFORE the git-status offender scan and fires on
# `raw_role == "builder" && role != "builder"` alone -- which this fixture's
# marker ALSO satisfies, independent of whether a product file changed. So
# this case's denial may legitimately come from either the A2 tamper message
# or a per-path offender-scan message; only exit code 2 and a non-empty,
# on-topic stderr are asserted here, not which specific message wins --
# verified empirically against this worktree's fix (see case 21 for the
# check that has to be about A2 specifically).
# ---------------------------------------------------------------------------
case20() {
  local label="20: role=builder, linked worktree parent -- product change now an offender"
  local wt
  wt=$(new_parent_worktree_linked_with_role "builder")
  printf 'echo modified\n' >"$wt/agent-agnostic/hooks/some-file.sh"
  run_guard "$wt"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if [ -z "$ERR" ]; then
    fail "$label -> stderr is non-empty" "err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qiE "some-file\.sh|builder|tamper|forg|escalat"; then
    fail "$label -> stderr is on-topic (names the path, or the role/tamper reason)" "err=[$ERR]"
    return
  fi
  pass "$label"
}
case20

# ---------------------------------------------------------------------------
# Case 21 (A2): tamper detection. A LINKED WORKTREE parent, role=orchestrator
# legitimately, git status otherwise CLEAN (only .artifacts/dae-role gets
# overwritten -- gitignored, so `git status --porcelain` stays empty and the
# offender-scan below could never catch this change on its own). After
# confirming git status IS empty, simulate the Bash tamper by overwriting
# dae-role to "builder"; the guard must then deny with a stderr message
# naming the tampering, and this can only be the new dedicated A2 check (per
# the contract's own pseudocode it runs BEFORE the git-status offender scan),
# not the offender scan, since git status is otherwise clean.
#
# Two positive controls follow, proving the new check isn't trigger-happy:
# 21b, an identical fixture with NO tamper (legit orchestrator role, clean
# status) -> exit 0; and 21c, role=builder in a MAIN CHECKOUT fixture
# (--worktree none's legitimate marker flip, clean status) -> exit 0, proving
# the new tamper check leaves that topology's genuine builder flip alone.
# ---------------------------------------------------------------------------
case21() {
  local label_tamper="21a: linked worktree parent, orchestrator role tampered to builder, git status clean -> exit 2 (tamper detection)"
  local label_control="21b: identical fixture, no tamper (legit orchestrator), git status clean -> exit 0"
  local label_none_mode="21c: role=builder, MAIN CHECKOUT (--worktree none), git status clean -> exit 0 (legitimate flip unaffected)"

  local wt porcelain
  wt=$(new_parent_worktree_linked_with_role "orchestrator")
  porcelain=$(git -C "$wt" status --porcelain)
  if [ -n "$porcelain" ]; then
    fail "$label_tamper (prereq: git status --porcelain reports nothing before tamper)" "porcelain=[$porcelain]"
  else
    pass "$label_tamper (prereq): git status --porcelain is empty before tamper"

    printf 'builder' >"$wt/.artifacts/dae-role"

    run_guard "$wt"
    if [ "$CODE" -ne 2 ]; then
      fail "$label_tamper" "code=$CODE out=[$OUT] err=[$ERR]"
    elif [ -z "$ERR" ]; then
      fail "$label_tamper -> stderr is non-empty" "err=[$ERR]"
    elif ! printf '%s\n' "$ERR" | grep -qiE "builder|tamper|forg|escalat"; then
      fail "$label_tamper -> stderr names the tampering" "err=[$ERR]"
    else
      pass "$label_tamper"
    fi
  fi

  local wt2 porcelain2
  wt2=$(new_parent_worktree_linked_with_role "orchestrator")
  porcelain2=$(git -C "$wt2" status --porcelain)
  if [ -n "$porcelain2" ]; then
    fail "$label_control (prereq: git status --porcelain reports nothing)" "porcelain=[$porcelain2]"
  else
    run_guard "$wt2"
    if [ "$CODE" -ne 0 ]; then
      fail "$label_control" "code=$CODE out=[$OUT] err=[$ERR]"
    else
      pass "$label_control"
    fi
  fi

  local wt3 porcelain3
  wt3=$(new_parent_worktree_with_role "builder")
  porcelain3=$(git -C "$wt3" status --porcelain)
  if [ -n "$porcelain3" ]; then
    fail "$label_none_mode (prereq: git status --porcelain reports nothing)" "porcelain=[$porcelain3]"
  else
    run_guard "$wt3"
    if [ "$CODE" -ne 0 ]; then
      fail "$label_none_mode" "code=$CODE out=[$OUT] err=[$ERR]"
    else
      pass "$label_none_mode"
    fi
  fi
}
case21

# ---------------------------------------------------------------------------
# Case 22 (Packet C addendum -- DP-2 regression fix): forge `builder` into an
# orchestrator-seeded linked-worktree parent's marker (bare write, no hook --
# same tamper style as case21), then make an actual change under the
# resolved plans root (an untracked new file, matching this file's existing
# git-status-based offender-detection style, e.g. case03/case16) and the
# resolved docs root. Previously the unresolvable-role fallback treated
# plans/docs changes as clean for an absent/garbage role -- both must now be
# flagged as offenders (exit 2).
#
# STDERR SHAPE NOTE (same as case20/case21): a "builder" forgery ALSO
# satisfies the A2 tamper check's own trigger (raw_role == "builder" &&
# role != "builder"), which the contract's pseudocode runs BEFORE the
# git-status offender scan -- so denial here legitimately comes from the A2
# tamper message (naming the marker file), not a per-path offender-scan
# message naming the plan/doc file. Only exit code 2 plus on-topic,
# non-empty stderr is asserted, matching case20's precedent; case23 (garbage
# token, which does NOT trip A2) is what asserts the specific offending
# filename.
# ---------------------------------------------------------------------------
case22() {
  local label="22: forged builder role, linked worktree parent -- plans-root AND docs-root changes now offenders"

  local wt plans_dir plan_file
  wt=$(new_parent_worktree_linked_with_role "orchestrator")
  plans_dir=$(resolved_plans_dir "$wt")
  if [ -z "$plans_dir" ]; then
    fail "$label (prereq: resolve plans dir)" "resolve-config.sh could not resolve CLAUDE_PROJECT_PLANS_DIR"
    return
  fi
  mkdir -p "$plans_dir"
  plan_file="$plans_dir/case22-plan.md"
  printf '# plan\n' >"$plan_file"
  printf 'builder' >"$wt/.artifacts/dae-role"
  run_guard "$wt"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> plans-root change flagged as offender" "code=$CODE out=[$OUT] err=[$ERR]"
  elif [ -z "$ERR" ]; then
    fail "$label -> stderr is non-empty" "err=[$ERR]"
  elif ! printf '%s\n' "$ERR" | grep -qiE "case22-plan\.md|builder|tamper|forg|escalat"; then
    fail "$label -> stderr is on-topic (names the path, or the role/tamper reason)" "err=[$ERR]"
  else
    pass "$label -> plans-root change flagged as offender, on-topic stderr"
  fi

  local wt2 docs_dir doc_file
  wt2=$(new_parent_worktree_linked_with_role "orchestrator")
  docs_dir=$(resolved_docs_dir "$wt2")
  if [ -z "$docs_dir" ]; then
    fail "$label (prereq: resolve docs dir)" "resolve-config.sh could not resolve CLAUDE_DOCS_DIR"
    return
  fi
  mkdir -p "$docs_dir"
  doc_file="$docs_dir/case22-topic.md"
  printf '# doc\n' >"$doc_file"
  printf 'builder' >"$wt2/.artifacts/dae-role"
  run_guard "$wt2"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> docs-root change flagged as offender" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if [ -z "$ERR" ]; then
    fail "$label -> stderr is non-empty" "err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qiE "case22-topic\.md|builder|tamper|forg|escalat"; then
    fail "$label -> stderr is on-topic (names the path, or the role/tamper reason)" "err=[$ERR]"
    return
  fi
  pass "$label -> docs-root change flagged as offender, on-topic stderr"
}
case22

# ---------------------------------------------------------------------------
# Case 23: same shape as case22, but the marker is forged to a plain garbage
# token ("xyz-garbage") instead of "builder" -- garbage must not behave any
# differently from a rejected `builder` claim. Plans-root AND docs-root
# changes both flagged as offenders.
# ---------------------------------------------------------------------------
case23() {
  local label="23: forged garbage role, linked worktree parent -- plans-root AND docs-root changes now offenders"

  # plans_dir/docs_dir must already be a TRACKED, committed directory before
  # the actual test file is added -- otherwise git reports the whole
  # brand-new directory as one untracked entry ("?? project-plans/") rather
  # than the individual file inside it, and a filename grep can't match.
  # Same seed-then-commit shape as case14/case16's plans_dir setup.
  local wt plans_dir plan_file
  wt=$(new_parent_worktree_linked_with_role "orchestrator")
  plans_dir=$(resolved_plans_dir "$wt")
  if [ -z "$plans_dir" ]; then
    fail "$label (prereq: resolve plans dir)" "resolve-config.sh could not resolve CLAUDE_PROJECT_PLANS_DIR"
    return
  fi
  mkdir -p "$plans_dir"
  printf 'keep\n' >"$plans_dir/.keep"
  commit_all "$wt" "seed plans dir"
  plan_file="$plans_dir/case23-plan.md"
  printf '# plan\n' >"$plan_file"
  printf 'xyz-garbage' >"$wt/.artifacts/dae-role"
  run_guard "$wt"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> plans-root change flagged as offender" "code=$CODE out=[$OUT] err=[$ERR]"
  elif ! printf '%s\n' "$ERR" | grep -qF "case23-plan.md"; then
    fail "$label -> stderr names the plans-root offending path" "err=[$ERR]"
  else
    pass "$label -> plans-root change flagged as offender, stderr names it"
  fi

  local wt2 docs_dir doc_file
  wt2=$(new_parent_worktree_linked_with_role "orchestrator")
  docs_dir=$(resolved_docs_dir "$wt2")
  if [ -z "$docs_dir" ]; then
    fail "$label (prereq: resolve docs dir)" "resolve-config.sh could not resolve CLAUDE_DOCS_DIR"
    return
  fi
  mkdir -p "$docs_dir"
  printf 'keep\n' >"$docs_dir/.keep"
  commit_all "$wt2" "seed docs dir"
  doc_file="$docs_dir/case23-topic.md"
  printf '# doc\n' >"$doc_file"
  printf 'xyz-garbage' >"$wt2/.artifacts/dae-role"
  run_guard "$wt2"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> docs-root change flagged as offender" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "case23-topic.md"; then
    fail "$label -> stderr names the docs-root offending path" "err=[$ERR]"
    return
  fi
  pass "$label -> docs-root change flagged as offender, stderr names it"
}
case23

# ---------------------------------------------------------------------------
# Case 24: positive control for the Packet C fix -- a GENUINE `planner`
# token in a linked-worktree parent (same topology as case22/case23), a
# change under the plans root is still clean (exit 0). Proves the plans root
# really is still reachable for a REAL planner -- only the forged/garbage
# path into it is now closed.
# ---------------------------------------------------------------------------
case24() {
  local label="24: genuine planner role, linked worktree parent -- plans-root change still clean (positive control)"
  local wt plans_dir plan_file
  wt=$(new_parent_worktree_linked_with_role "planner")
  plans_dir=$(resolved_plans_dir "$wt")
  if [ -z "$plans_dir" ]; then
    fail "$label (prereq: resolve plans dir)" "resolve-config.sh could not resolve CLAUDE_PROJECT_PLANS_DIR"
    return
  fi
  mkdir -p "$plans_dir"
  plan_file="$plans_dir/case24-plan.md"
  printf '# plan\n' >"$plan_file"
  run_guard "$wt"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case24

# ---------------------------------------------------------------------------
# Case 25 (Packet E's structural `scratch` discriminator, corrected by
# Packet G): a main-checkout marked parent with NO dae-role file at all
# (new_parent_worktree() already builds exactly this shape -- a real git
# repo via plain `git init`, never a linked worktree, and it never creates
# dae-role) resolves to `scratch`. Packet G narrowed `scratch`'s allow-list
# in this file from "clean anywhere under marked, unconditionally" to
# "clean only under <marked>/.artifacts" -- matching scope-writes.sh's own
# scratch rule and closing a real Bash-side bypass (a scratch-marked
# main-checkout root with a modified tracked product file used to wrongly
# exit 0; it must now exit 2). Two sub-assertions on fresh fixtures: a
# change under <marked>/.artifacts/reports/<slug>/report.md (mirroring
# resolve-scratch.sh's own SCRATCHDIR shape) stays CLEAN (exit 0) --
# scratch's actual allowed root; a change OUTSIDE .artifacts (the case's
# original target, agent-agnostic/hooks/some-file.sh) is now an OFFENDER
# (exit 2), stderr naming the path.
# ---------------------------------------------------------------------------
case25() {
  local label="25: Packet E/G -- main-checkout marked parent, no dae-role file (scratch) -- clean only under .artifacts, offender outside it"
  local wt report_file
  wt=$(new_parent_worktree)
  mkdir -p "$wt/.artifacts/reports/case25-slug"
  report_file="$wt/.artifacts/reports/case25-slug/report.md"
  printf '# report\n' >"$report_file"
  run_guard "$wt"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> change under .artifacts/reports/<slug>/report.md clean" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label -> change under .artifacts/reports/<slug>/report.md clean"
  fi

  local wt2
  wt2=$(new_parent_worktree)
  printf 'echo modified\n' >"$wt2/agent-agnostic/hooks/some-file.sh"
  run_guard "$wt2"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> change outside .artifacts now an offender" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "agent-agnostic/hooks/some-file.sh"; then
    fail "$label -> stderr names the offending path" "err=[$ERR]"
    return
  fi
  pass "$label -> change outside .artifacts now an offender, stderr names it"
}
case25

# ---------------------------------------------------------------------------
# Case 26 (Packet E forgery reproduction -- the case the coordinator called
# "the one that matters most"): a REAL LINKED WORKTREE parent, role seeded
# legitimately as `orchestrator`, then the marker overwritten via a bare
# `printf 'scratch'` write (no hook -- git status of the marker itself stays
# invisible since .artifacts/ is gitignored in every fixture this file
# builds). `scratch` is a computed value, NEVER read from the file --
# writing the literal string `scratch` must land in the exact same
# unresolved bucket as any other garbage token and be re-derived from the
# marked root's actual git topology (main_checkout=0 in a linked worktree ->
# orchestrator, unchanged by Packet E). A genuine product-file change is
# then made (so there's something for the offender scan to classify) --
# assert it is STILL an offender (exit 2). Note: raw_role here is the
# literal string "scratch", not "builder", so the A2 tamper check's own
# trigger (raw_role == "builder" && role != "builder") does NOT fire; the
# denial must come from the ordinary git-status offender scan classifying
# the product file under orchestrator's resolved role, so stderr is asserted
# to name the specific offending path (same shape as case23's garbage-token
# case, not case20/22's on-topic-only assertion for an actual "builder"
# forgery).
# ---------------------------------------------------------------------------
case26() {
  local label="26: Packet E forgery reproduction (matters most) -- linked worktree parent, orchestrator forged to literal 'scratch', product change made -> STILL an offender"
  local wt
  wt=$(new_parent_worktree_linked_with_role "orchestrator")
  printf 'scratch' >"$wt/.artifacts/dae-role"
  printf 'echo modified\n' >"$wt/agent-agnostic/hooks/some-file.sh"
  run_guard "$wt"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "agent-agnostic/hooks/some-file.sh"; then
    fail "$label -> stderr names the offending path" "err=[$ERR]"
    return
  fi
  pass "$label"
}
case26

# Case 27: agent_type is checked before resolve_role ever reads a marker file.
case27() {
  local label="27: agent_type=documenter, modified file under resolved docs dir (no dae-role file) -> exit 0"
  local wt docs_dir doc_file stdin_json
  wt=$(new_parent_worktree)
  docs_dir=$(resolved_docs_dir "$wt")
  if [ -z "$docs_dir" ]; then
    fail "$label (prereq: resolve docs dir)" "resolve-config.sh could not resolve CLAUDE_DOCS_DIR"
    return
  fi
  mkdir -p "$docs_dir"
  doc_file="$docs_dir/case27-doc.md"
  printf '# doc\n' >"$doc_file"
  commit_all "$wt" "add doc file under docs dir"
  printf '# doc v2\n' >"$doc_file"
  stdin_json=$(printf '{"cwd": "%s", "tool_name": "Bash", "agent_type": "documenter"}' "$wt")
  run_guard "$wt" "$stdin_json"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "docs_dir=[$docs_dir] code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case27

case28() {
  local label="28: agent_type=documenter, change outside docs root and not plan.md -> exit 2"
  local wt target stdin_json
  wt=$(new_parent_worktree)
  target="$wt/agent-agnostic/hooks/some-file.sh"
  printf 'echo modified\n' >"$target"
  stdin_json=$(printf '{"cwd": "%s", "tool_name": "Bash", "agent_type": "documenter"}' "$wt")
  run_guard "$wt" "$stdin_json"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF "agent-agnostic/hooks/some-file.sh"; then
    fail "$label -> stderr names the offending path" "err=[$ERR]"
    return
  fi
  pass "$label"
}
case28

case29() {
  local label="29: agent_type=documenter, change to <plan-dir>/plan.md under resolved plans root -> exit 0"
  local wt plans_dir plan_file stdin_json
  wt=$(new_parent_worktree)
  plans_dir=$(resolved_plans_dir "$wt")
  if [ -z "$plans_dir" ]; then
    fail "$label (prereq: resolve plans dir)" "resolve-config.sh could not resolve CLAUDE_PROJECT_PLANS_DIR"
    return
  fi
  mkdir -p "$plans_dir/case29-plan-09-02-26"
  plan_file="$plans_dir/case29-plan-09-02-26/plan.md"
  printf '# plan\n' >"$plan_file"
  commit_all "$wt" "add case29 plan.md baseline"
  printf '# plan v2\n' >"$plan_file"
  stdin_json=$(printf '{"cwd": "%s", "tool_name": "Bash", "agent_type": "documenter"}' "$wt")
  run_guard "$wt" "$stdin_json"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "plans_dir=[$plans_dir] code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case29

# Case 30: symlink outside docs root whose target resolves under it -- the
# doc-format README-mirror case, left untracked so porcelain reports it.
case30() {
  local label="30: agent_type=documenter, symlink outside docs root whose target resolves under docs root -> exit 0"
  local wt docs_dir target_file link_path stdin_json
  wt=$(new_parent_worktree)
  docs_dir=$(resolved_docs_dir "$wt")
  if [ -z "$docs_dir" ]; then
    fail "$label (prereq: resolve docs dir)" "resolve-config.sh could not resolve CLAUDE_DOCS_DIR"
    return
  fi
  mkdir -p "$docs_dir"
  target_file="$docs_dir/case30-target.md"
  printf '# target\n' >"$target_file"
  link_path="$wt/docs-mirror.md"
  ln -s "$target_file" "$link_path"
  stdin_json=$(printf '{"cwd": "%s", "tool_name": "Bash", "agent_type": "documenter"}' "$wt")
  run_guard "$wt" "$stdin_json"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "link_path=[$link_path] target_file=[$target_file] code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case30

case31() {
  local label="31: positive control -- same docs-root change as case27 WITHOUT agent_type (role defaults to orchestrator) -> exit 2"
  local wt docs_dir doc_file
  wt=$(new_parent_worktree_with_role "orchestrator")
  docs_dir=$(resolved_docs_dir "$wt")
  if [ -z "$docs_dir" ]; then
    fail "$label (prereq: resolve docs dir)" "resolve-config.sh could not resolve CLAUDE_DOCS_DIR"
    return
  fi
  mkdir -p "$docs_dir"
  doc_file="$docs_dir/case31-doc.md"
  printf '# doc\n' >"$doc_file"
  commit_all "$wt" "add doc file under docs dir"
  printf '# doc v2\n' >"$doc_file"
  run_guard "$wt"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "docs_dir=[$docs_dir] code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case31

WORKFLOW_SETUP="$REPO_ROOT/agent-agnostic/hooks/workflow-setup.sh"

case32() {
  local label="32: planner's proposal, seen under planner, is not re-judged after the flip to orchestrator -> exit 0"
  local wt plans
  wt=$(new_parent_worktree_with_role planner)
  plans=$(resolved_plans_dir "$wt")
  mkdir -p "$plans/proposals"
  printf '# proposal\n' >"$plans/proposals/p-01-02-26.md"
  run_guard "$wt"
  [ "$CODE" -eq 0 ] || { fail "$label (planner)" "code=$CODE err=[$ERR]"; return; }
  printf 'orchestrator\n' >"$wt/.artifacts/dae-role"
  run_guard "$wt"
  [ "$CODE" -eq 0 ] || { fail "$label" "code=$CODE err=[$ERR]"; return; }
  printf '# proposal, edited by the orchestrator\n' >"$plans/proposals/p-01-02-26.md"
  run_guard "$wt"
  [ "$CODE" -eq 2 ] || { fail "$label (later orchestrator edit must deny)" "code=$CODE err=[$ERR]"; return; }
  pass "$label"
}
case32

case33() {
  local label="33: --set-role records the outgoing planner's write with no guard run in between -> orchestrator exit 0"
  local wt plans
  wt=$(new_parent_worktree_with_role planner)
  plans=$(resolved_plans_dir "$wt")
  mkdir -p "$plans/x-01-02-26"
  printf '# plan\n' >"$plans/x-01-02-26/plan.md"
  "$WORKFLOW_SETUP" --set-role orchestrator --root "$wt" 2>/dev/null
  run_guard "$wt"
  [ "$CODE" -eq 0 ] || { fail "$label" "code=$CODE err=[$ERR]"; return; }
  pass "$label"
}
case33

case34() {
  local label="34: a gate report written under the orchestrator is not re-judged under the documenter -> exit 0"
  local wt plans stdin_json
  wt=$(new_parent_worktree_with_role orchestrator)
  plans=$(resolved_plans_dir "$wt")
  mkdir -p "$plans/x-01-02-26"
  printf 'verdict: ready\n' >"$plans/x-01-02-26/code-review.md"
  run_guard "$wt"
  [ "$CODE" -eq 0 ] || { fail "$label (orchestrator)" "code=$CODE err=[$ERR]"; return; }
  stdin_json=$(printf '{"cwd": "%s", "tool_name": "Bash", "agent_type": "documenter"}' "$wt")
  run_guard "$wt" "$stdin_json"
  [ "$CODE" -eq 0 ] || { fail "$label" "code=$CODE err=[$ERR]"; return; }
  pass "$label"
}
case34

case35() {
  local label="35: positive control -- an unrecorded plans-dir write under the orchestrator still denies"
  local wt plans
  wt=$(new_parent_worktree_with_role orchestrator)
  plans=$(resolved_plans_dir "$wt")
  mkdir -p "$plans/x-01-02-26"
  printf '# plan\n' >"$plans/x-01-02-26/plan.md"
  run_guard "$wt"
  [ "$CODE" -eq 2 ] || { fail "$label" "code=$CODE err=[$ERR]"; return; }
  pass "$label"
}
case35

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
