#!/usr/bin/env bash
# scope-writes.test.sh
#
# SYNOPSIS
#   bash tests/scope-writes.test.sh
#
# DESCRIPTION
#   Blind contract test for agent-agnostic/hooks/scope-writes.sh (Packet 1,
#   4.1): a PreToolUse hook that reads a JSON tool-call payload on stdin and
#   decides whether a write-shaped tool call (Write/Edit/NotebookEdit, plus
#   documented Antigravity aliases) targets an out-of-scope location under a
#   "marked" parent worktree -- one with an ancestor .artifacts/progress-log.md
#   file. Written from the contract text alone. Never reads scope-writes.sh's
#   source (nor parent-tree-guard.sh's nor verify-scope.sh's), in any mode,
#   including to interpret a failure.
#
#   All fixtures are throwaway mktemp -d directories, cleaned up on exit via
#   trap. The plans-dir and docs-dir ALLOW cases resolve their roots via the
#   real agent-agnostic/hooks/resolve-config.sh (a tool, not the implementation
#   under test) rather than hardcoding this repo's configured defaults.
#
# EXIT CODES
#   0  every case passed
#   1  at least one case failed (or the bash -n sanity precondition failed)
#
# Runnable with no arguments from any working directory.

set -uo pipefail

# ---------------------------------------------------------------------------
# Locate the scripts relative to this file's own location.
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/agent-agnostic/hooks/scope-writes.sh"
RESOLVE_SCRIPT="$REPO_ROOT/agent-agnostic/hooks/resolve-config.sh"

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
# run_hook <stdin-content> -- invokes the hook with the given content fed on
# stdin (no trailing newline forced), sets globals OUT / ERR / CODE.
# ---------------------------------------------------------------------------
OUT=""
ERR=""
CODE=0
run_hook() {
  local stdin_content="$1"
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  printf '%s' "$stdin_content" | "$SCRIPT" >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# run_hook_empty -- stdin genuinely empty (from /dev/null, not an empty
# string piped through a process substitution).
run_hook_empty() {
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  "$SCRIPT" </dev/null >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

# new_marked_worktree -- a fresh scratch dir containing .artifacts/progress-log.md,
# i.e. a stand-in "parent worktree" the hook should recognize as marked.
new_marked_worktree() {
  local d
  d=$(new_scratch)
  mkdir -p "$d/.artifacts"
  echo "x" >"$d/.artifacts/progress-log.md"
  printf '%s' "$d"
}

# new_unmarked_tree -- a fresh scratch dir with some nested subdirectories
# but NO .artifacts/progress-log.md anywhere in it (a "child worktree" or
# "plain checkout" stand-in, depending on the case). Always its own scratch
# root, never nested under a marked-worktree fixture.
new_unmarked_tree() {
  local d
  d=$(new_scratch)
  mkdir -p "$d/sub/dir"
  printf '%s' "$d"
}

# join_under <base> <resolved-relative-root> -- joins a worktree-root-relative
# resolved path (e.g. "/project-plans/" or "/docs") onto a fixture's root the
# same way the implementation is documented to: relative to the marked
# parent worktree's own root.
join_under() {
  local base="$1" rel="$2"
  rel="${rel#/}"
  rel="${rel%/}"
  base="${base%/}"
  if [ -z "$rel" ]; then
    printf '%s' "$base"
  else
    printf '%s/%s' "$base" "$rel"
  fi
}

# resolve_var <VAR> <default> <root> [extra resolve-config.sh args...] --
# prints the resolved value on stdout, returns nonzero if resolution failed.
resolve_var() {
  local var="$1" default="$2" root="$3"
  shift 3
  "$RESOLVE_SCRIPT" "$var" --default "$default" --root "$root" "$@" 2>/dev/null
}

# new_marked_worktree_with_role <role> -- like new_marked_worktree but also
# writes .artifacts/dae-role with the given content verbatim (a trailing
# newline is added; resolve_role is documented to tr -d '[:space:]' before
# matching, so this is a faithful "one-line role token" fixture -- also used,
# unmodified, to build a "garbage role" fixture by passing junk text).
new_marked_worktree_with_role() {
  local role="$1" d
  d=$(new_marked_worktree)
  printf '%s\n' "$role" >"$d/.artifacts/dae-role"
  printf '%s' "$d"
}

# new_marked_worktree_main_checkout_with_role <role> -- like
# new_marked_worktree_with_role, but the fixture directory is ALSO a REAL git
# MAIN CHECKOUT (plain `git init`, no `git worktree add`) -- this models
# --worktree none's topology, the one shape where `git rev-parse --git-dir`
# and `--git-common-dir` are EQUAL. Needed by the A1 fix's tests: the
# main-checkout gate reads real git state, not anything under .artifacts/, so
# a fixture claiming to be "--worktree none" has to actually be a git main
# checkout for the gate to see it that way.
new_marked_worktree_main_checkout_with_role() {
  local role="$1" d
  d=$(new_marked_worktree_with_role "$role")
  git -C "$d" init -q
  git -C "$d" config user.email "scope-writes-test@example.com"
  git -C "$d" config user.name "scope-writes-test"
  git -C "$d" commit -q --allow-empty -m init
  printf '%s' "$d"
}

# new_marked_worktree_linked_with_role <role> -- like
# new_marked_worktree_with_role, but the fixture directory is a REAL LINKED
# git worktree (cut via `git worktree add` off a throwaway container repo),
# never a main checkout -- this models new/resume mode's parent-worktree
# topology, where `git rev-parse --git-dir` and `--git-common-dir` DIFFER.
# The container repo is an unrelated, separately-registered scratch dir; only
# the returned linked-worktree path is meant to be used as a fixture root.
LINKED_WT_COUNTER=0
new_marked_worktree_linked_with_role() {
  local role="$1" container base target branch
  container=$(new_scratch)
  git -C "$container" init -q
  git -C "$container" config user.email "scope-writes-test@example.com"
  git -C "$container" config user.name "scope-writes-test"
  git -C "$container" commit -q --allow-empty -m init
  base=$(new_scratch)
  target="$base/linked-wt"
  LINKED_WT_COUNTER=$((LINKED_WT_COUNTER + 1))
  branch="scope-writes-linked-fixture-$LINKED_WT_COUNTER"
  git -C "$container" worktree add -q -b "$branch" "$target" >/dev/null 2>&1
  mkdir -p "$target/.artifacts"
  echo "x" >"$target/.artifacts/progress-log.md"
  printf '%s\n' "$role" >"$target/.artifacts/dae-role"
  printf '%s' "$target"
}

# new_marked_worktree_main_checkout_no_role -- like
# new_marked_worktree_main_checkout_with_role, but .artifacts/dae-role is
# NEVER created at all (not even empty) -- models a `ship: chat` scratch
# run's exact marker shape per Packet E's contract text (mirroring
# resolve-scratch.sh's own documented behavior, which this lane does not
# touch or read): .artifacts/progress-log.md present, dae-role ABSENT, the
# marked root a plain `git init` repo (main checkout), never a linked
# worktree.
new_marked_worktree_main_checkout_no_role() {
  local d
  d=$(new_marked_worktree)
  git -C "$d" init -q
  git -C "$d" config user.email "scope-writes-test@example.com"
  git -C "$d" config user.name "scope-writes-test"
  git -C "$d" commit -q --allow-empty -m init
  printf '%s' "$d"
}

# new_lane_root_pair -- prints "<parent-path> <child-path>" (space-separated):
# a marked parent worktree at "<base>/run" and an UNMARKED sibling lane child
# at "<base>/run-l1" (no .artifacts at all), matching find_lane_root's
# "<parent-name>-l<n>" sibling shape (both live directly under the same
# fresh scratch root, never nested).
new_lane_root_pair() {
  local base parent child
  base=$(new_scratch)
  parent="$base/run"
  child="$base/run-l1"
  mkdir -p "$parent/.artifacts" "$child"
  echo "x" >"$parent/.artifacts/progress-log.md"
  printf '%s %s' "$parent" "$child"
}

# ---------------------------------------------------------------------------
# Case 00: bash -n sanity precondition (script must at least parse)
# ---------------------------------------------------------------------------
SYN_ERR_FILE=$(mktemp)
if bash -n "$SCRIPT" 2>"$SYN_ERR_FILE"; then
  pass "00: bash -n scope-writes.sh exits 0"
else
  fail "00: bash -n scope-writes.sh exits 0" "syntax error: $(cat "$SYN_ERR_FILE")"
  rm -f "$SYN_ERR_FILE"
  echo "sanity failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
rm -f "$SYN_ERR_FILE"

# ---------------------------------------------------------------------------
# Case 01: Write to an out-of-scope path under a marked parent worktree
# -> exit 2, stderr contains the offending path literally.
# ---------------------------------------------------------------------------
case01() {
  local label="01: Write to out-of-scope path under marked parent -> deny"
  local parent target payload
  parent=$(new_marked_worktree)
  target="$parent/agent-agnostic/hooks/foo.sh"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case01

# ---------------------------------------------------------------------------
# Case 02 (Packet C fallout): Write to <parent>/.artifacts/progress-log.md,
# marked root with NO dae-role file at all -> exit 2. progress-log.md is not
# *-review.md/sync-report.md, so orchestrator's narrow allowance doesn't
# cover it under the new (least-privilege) unresolved-role fallback. Positive
# control on the SAME fixture: a *-review.md-named file under the resolved
# plans root still gets exit 0, proving the fixture isn't just broken/
# blanket-denying.
# ---------------------------------------------------------------------------
case02() {
  local label="02: Write to <parent>/.artifacts/progress-log.md -> deny (Packet C: not *-review.md/sync-report.md)"
  local parent target payload
  parent=$(new_marked_worktree)
  target="$parent/.artifacts/progress-log.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"

  local resolved plans_root review_target payload2
  if ! resolved=$(resolve_var CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$parent"); then
    fail "$label (positive-control setup)" "resolve-config.sh CLAUDE_PROJECT_PLANS_DIR failed"
    return
  fi
  plans_root=$(join_under "$parent" "$resolved")
  review_target="$plans_root/case02-plan-09-02-26/plan-review.md"
  payload2=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$review_target")
  run_hook "$payload2"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> positive control: *-review.md under plans_root allowed" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> positive control: *-review.md under plans_root allowed"
}
case02

# ---------------------------------------------------------------------------
# Case 03 (Packet C fallout): Write under the RESOLVED plans dir, arbitrary
# filename (plan.md, not *-review.md/sync-report.md) -> exit 2. Positive
# control on the same plans dir: a *-review.md-named file -> exit 0.
# ---------------------------------------------------------------------------
case03() {
  local label="03: Write under resolved CLAUDE_PROJECT_PLANS_DIR (non-matching name) -> deny"
  local parent resolved plans_root target payload
  parent=$(new_marked_worktree)
  if ! resolved=$(resolve_var CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$parent"); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_PROJECT_PLANS_DIR failed"
    return
  fi
  plans_root=$(join_under "$parent" "$resolved")
  target="$plans_root/case03-plan-08-29-26/plan.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "resolved=[$resolved] target=[$target] code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2 (resolved=[$resolved])"

  local review_target payload2
  review_target="$plans_root/case03-plan-08-29-26/plan-review.md"
  payload2=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$review_target")
  run_hook "$payload2"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> positive control: *-review.md under plans_root allowed" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> positive control: *-review.md under plans_root allowed"
}
case03

# ---------------------------------------------------------------------------
# Case 04 (Packet C fallout): Write under the RESOLVED docs dir -> exit 2,
# unconditionally. Orchestrator's rule never reaches the docs root at all
# (matching planner's and builder's already-existing docs-denial shape
# elsewhere in this file) -- no positive control possible for docs
# specifically, since orchestrator never gets it.
# ---------------------------------------------------------------------------
case04() {
  local label="04: Write under resolved CLAUDE_DOCS_DIR -> deny (orchestrator's rule never reaches docs)"
  local parent resolved docs_root target payload
  parent=$(new_marked_worktree)
  if ! resolved=$(resolve_var CLAUDE_DOCS_DIR /docs "$parent" --expect path); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_DOCS_DIR failed"
    return
  fi
  docs_root=$(join_under "$parent" "$resolved")
  target="$docs_root/topic.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "resolved=[$resolved] target=[$target] code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2 (resolved=[$resolved])"
}
case04

# ---------------------------------------------------------------------------
# Case 05: Write inside a tree with NO .artifacts/progress-log.md anywhere in
# its ancestry (a "child worktree" stand-in) -> exit 0. Single most important
# negative case; built under its own separate scratch root.
# ---------------------------------------------------------------------------
case05() {
  local label="05: Write under an unmarked tree (child-worktree stand-in) -> allow"
  local child target payload
  child=$(new_unmarked_tree)
  target="$child/sub/dir/agent-agnostic/hooks/foo.sh"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 0"
}
case05

# ---------------------------------------------------------------------------
# Case 06: Write anywhere in a plain directory tree with no run dir anywhere
# (a "plain checkout" stand-in) -> exit 0. Its own separate scratch root.
# ---------------------------------------------------------------------------
case06() {
  local label="06: Write under a plain checkout with no run dir -> allow"
  local plain target payload
  plain=$(new_unmarked_tree)
  target="$plain/README.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 0"
}
case06

# ---------------------------------------------------------------------------
# Case 07: non-write tools (Read, Bash, Grep) -> exit 0 regardless, even
# when a path field targets a clearly out-of-scope location under a marked
# worktree.
# ---------------------------------------------------------------------------
case07() {
  local parent target
  parent=$(new_marked_worktree)
  target="$parent/agent-agnostic/hooks/foo.sh"

  local payload
  payload=$(printf '{"tool_name": "Read", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -eq 0 ]; then
    pass "07a: Read tool with out-of-scope file_path -> exit 0 regardless"
  else
    fail "07a: Read tool with out-of-scope file_path -> exit 0 regardless" "code=$CODE out=[$OUT] err=[$ERR]"
  fi

  payload=$(printf '{"tool_name": "Bash", "command": "cat %s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -eq 0 ]; then
    pass "07b: Bash tool -> exit 0 regardless"
  else
    fail "07b: Bash tool -> exit 0 regardless" "code=$CODE out=[$OUT] err=[$ERR]"
  fi

  payload=$(printf '{"tool_name": "Grep", "pattern": "foo", "path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -eq 0 ]; then
    pass "07c: Grep tool with out-of-scope path -> exit 0 regardless"
  else
    fail "07c: Grep tool with out-of-scope path -> exit 0 regardless" "code=$CODE out=[$OUT] err=[$ERR]"
  fi
}
case07

# ---------------------------------------------------------------------------
# Case 08: an Antigravity tool-name alias (write_to_file / TargetFile) is
# still gated -- confirms the gate isn't hardcoded to only Write/Edit/
# NotebookEdit.
# ---------------------------------------------------------------------------
case08() {
  local label="08: Antigravity alias (write_to_file/TargetFile) out-of-scope -> deny"
  local parent target payload
  parent=$(new_marked_worktree)
  target="$parent/agent-agnostic/hooks/aliased.sh"
  payload=$(printf '{"tool_name": "write_to_file", "TargetFile": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case08

# ---------------------------------------------------------------------------
# Case 09: malformed stdin (not valid JSON at all) -> exit 0, no crash.
# ---------------------------------------------------------------------------
case09() {
  local label="09: malformed stdin (garbage bytes, not JSON) -> exit 0, no crash"
  local garbage
  garbage=$'\x01\x02 not json at all {{{ [[[ ))) $$$ ---- \xff\xfe'
  run_hook "$garbage"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 0"
}
case09

# ---------------------------------------------------------------------------
# Case 10: empty stdin -> exit 0.
# ---------------------------------------------------------------------------
case10() {
  local label="10: empty stdin -> exit 0"
  run_hook_empty
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 0"
}
case10

# ---------------------------------------------------------------------------
# Case 11: Edit tool (shares the Write file_path JSON shape) out-of-scope
# under a marked parent -> exit 2, stderr names the path.
# ---------------------------------------------------------------------------
case11() {
  local label="11: Edit tool, out-of-scope file_path -> deny"
  local parent target payload
  parent=$(new_marked_worktree)
  target="$parent/agent-agnostic/hooks/edited.sh"
  payload=$(printf '{"tool_name": "Edit", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case11

# ---------------------------------------------------------------------------
# Case 12: NotebookEdit tool (notebook_path JSON shape) out-of-scope under a
# marked parent -> exit 2, stderr names the path.
# ---------------------------------------------------------------------------
case12() {
  local label="12: NotebookEdit tool, out-of-scope notebook_path -> deny"
  local parent target payload
  parent=$(new_marked_worktree)
  target="$parent/agent-agnostic/hooks/notebook.ipynb"
  payload=$(printf '{"tool_name": "NotebookEdit", "notebook_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case12

# ---------------------------------------------------------------------------
# Case 13: role=builder (from .artifacts/dae-role) -- A1 fix adds a
# structural gate: `builder` is honored ONLY when the marked root is a git
# MAIN CHECKOUT (--worktree none's topology). In a LINKED worktree parent
# (new/resume mode) it is now REJECTED and falls back to absent-role
# behavior, because a genuine builder in that topology always runs in its own
# sibling lane child (find_lane_root, case16), never via the parent's own
# marker file. Split into 13a (main checkout, unchanged) and 13b (linked
# worktree, the actual fix).
# ---------------------------------------------------------------------------

# 13a: role=builder, main checkout -- deny-list semantics UNCHANGED from
# before this fix (product write allowed, plans/docs write denied): same
# assertions the old Case 13 made, now on a real git-backed main-checkout
# fixture instead of the old bare-mktemp one.
case13a() {
  local label="13a: role=builder, main checkout"
  local parent resolved plans_root allow_target deny_target payload
  parent=$(new_marked_worktree_main_checkout_with_role "builder")

  allow_target="$parent/agent-agnostic/hooks/builder-allowed.sh"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$allow_target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> product path allowed" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label -> product path allowed"
  fi

  if ! resolved=$(resolve_var CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$parent"); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_PROJECT_PLANS_DIR failed"
    return
  fi
  plans_root=$(join_under "$parent" "$resolved")
  deny_target="$plans_root/case13a-plan-09-02-26/plan.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$deny_target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> plans_root path denied" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$deny_target"; then
    fail "$label -> stderr names the offending path" "target=[$deny_target] err=[$ERR]"
    return
  fi
  pass "$label -> plans_root path denied, stderr names it"
}
case13a

# 13b: role=builder, linked worktree parent -- rejected. The actual security
# fix: a product-path write is now DENIED (exit 2), the opposite of what the
# old Case 13 asserted for this shape. The plans_root path is ALSO now
# denied (Packet C narrowed the rejected-role fallback from the old
# permissive plans+docs allowance to orchestrator's own restrictive rule) --
# a fresh positive control on the identical fixture (a *-review.md-named
# file in the same plans dir) proves orchestrator's narrow allowance still
# functions, this isn't the whole fixture going inert.
case13b() {
  local label="13b: role=builder, linked worktree parent -- rejected"
  local parent resolved plans_root target review_target deny_target payload
  parent=$(new_marked_worktree_linked_with_role "builder")

  if ! resolved=$(resolve_var CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$parent"); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_PROJECT_PLANS_DIR failed"
    return
  fi
  plans_root=$(join_under "$parent" "$resolved")
  target="$plans_root/case13b-plan-09-02-26/plan.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> plans_root path (non-matching name) now denied" "code=$CODE out=[$OUT] err=[$ERR]"
  elif ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
  else
    pass "$label -> plans_root path (non-matching name) now denied, stderr names it"
  fi

  review_target="$plans_root/case13b-plan-09-02-26/plan-review.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$review_target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> positive control: *-review.md under plans_root allowed" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label -> positive control: *-review.md under plans_root allowed"
  fi

  deny_target="$parent/src/app.js"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$deny_target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> product path denied" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$deny_target"; then
    fail "$label -> stderr names the offending path" "target=[$deny_target] err=[$ERR]"
    return
  fi
  pass "$label -> product path denied, stderr names it"
}
case13b

# ---------------------------------------------------------------------------
# Case 14: role=planner -> allow-list of plans_root ONLY. Positive control
# (a plans_root path is allowed) plus negative control (a plain product path
# is denied), same fixture.
# ---------------------------------------------------------------------------
case14() {
  local label="14: role=planner"
  local parent resolved plans_root allow_target deny_target payload
  parent=$(new_marked_worktree_with_role "planner")

  if ! resolved=$(resolve_var CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$parent"); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_PROJECT_PLANS_DIR failed"
    return
  fi
  plans_root=$(join_under "$parent" "$resolved")
  allow_target="$plans_root/case14-plan-09-02-26/plan.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$allow_target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> plans_root path allowed" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label -> plans_root path allowed"
  fi

  deny_target="$parent/agent-agnostic/hooks/planner-denied.sh"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$deny_target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> product path denied" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$deny_target"; then
    fail "$label -> stderr names the offending path" "target=[$deny_target] err=[$ERR]"
    return
  fi
  pass "$label -> product path denied, stderr names it"
}
case14

# ---------------------------------------------------------------------------
# Case 15: role=orchestrator -> allowed only under plans_root AND basename
# matches *-review.md or is exactly sync-report.md. Two positive controls
# (one per half of the OR) plus a negative control (a plans_root path that
# doesn't match either shape).
# ---------------------------------------------------------------------------
case15() {
  local label="15: role=orchestrator"
  local parent resolved plans_root allow_review allow_sync deny_target payload
  parent=$(new_marked_worktree_with_role "orchestrator")

  if ! resolved=$(resolve_var CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$parent"); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_PROJECT_PLANS_DIR failed"
    return
  fi
  plans_root=$(join_under "$parent" "$resolved")

  allow_review="$plans_root/case15-plan-09-02-26/plan-review.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$allow_review")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> *-review.md under plans_root allowed" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label -> *-review.md under plans_root allowed"
  fi

  allow_sync="$plans_root/case15-plan-09-02-26/sync-report.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$allow_sync")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> sync-report.md under plans_root allowed" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label -> sync-report.md under plans_root allowed"
  fi

  deny_target="$plans_root/case15-plan-09-02-26/plan.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$deny_target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> plan.md under plans_root (non-matching name) denied" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$deny_target"; then
    fail "$label -> stderr names the offending path" "target=[$deny_target] err=[$ERR]"
    return
  fi
  pass "$label -> plan.md under plans_root denied, stderr names it"
}
case15

# ---------------------------------------------------------------------------
# Case 16: role=builder inferred structurally via find_lane_root (a lane
# child worktree, itself unmarked, sibling of a marked parent). Positive
# control (a product path inside the child is allowed) plus negative control
# (a path shaped like the CHILD's own local plans dir is denied -- this is
# the actual regression guard: it must resolve against the child's own root,
# not the parent's, since that's what would collide with the real trees on
# merge-back).
# ---------------------------------------------------------------------------
case16() {
  local label="16: role=builder via lane-root (child worktree, unmarked, sibling of a marked parent)"
  local pair parent child resolved plans_root allow_target deny_target payload
  pair=$(new_lane_root_pair)
  parent="${pair% *}"
  child="${pair#* }"

  allow_target="$child/agent-agnostic/hooks/lane-allowed.sh"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$allow_target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> product path under child allowed" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label -> product path under child allowed"
  fi

  if ! resolved=$(resolve_var CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$child"); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_PROJECT_PLANS_DIR failed"
    return
  fi
  plans_root=$(join_under "$child" "$resolved")
  deny_target="$plans_root/case16-plan-09-02-26/plan.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$deny_target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> child's own local plans-dir-shaped path denied" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$deny_target"; then
    fail "$label -> stderr names the offending path" "target=[$deny_target] err=[$ERR]"
    return
  fi
  pass "$label -> child's own local plans-dir-shaped path denied, stderr names it"
}
case16

# ---------------------------------------------------------------------------
# Case 17: .artifacts/dae-role holding garbage text falls back to EXACTLY
# the same outcome as no role file at all on an identical fixture/path pair
# (Packet C: the unresolved-role fallback is now orchestrator's own
# restrictive rule, not the old permissive plans+docs allowance -- a
# non-matching plans_root path is denied, with a *-review.md-named file in
# the same plans dir as positive control, and a plain product path is
# denied) -- proves the fallback, doesn't just assert it doesn't crash.
# ---------------------------------------------------------------------------
case17() {
  local label="17: role=garbage token falls back to default (absent-role) behavior"
  local parent resolved plans_root target review_target deny_target payload
  parent=$(new_marked_worktree_with_role "not-a-real-role")

  if ! resolved=$(resolve_var CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$parent"); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_PROJECT_PLANS_DIR failed"
    return
  fi
  plans_root=$(join_under "$parent" "$resolved")
  target="$plans_root/case17-plan-09-02-26/plan.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> plans_root path (non-matching name) now denied" "code=$CODE out=[$OUT] err=[$ERR]"
  elif ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
  else
    pass "$label -> plans_root path (non-matching name) now denied, stderr names it"
  fi

  review_target="$plans_root/case17-plan-09-02-26/plan-review.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$review_target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> positive control: *-review.md under plans_root allowed" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label -> positive control: *-review.md under plans_root allowed"
  fi

  deny_target="$parent/agent-agnostic/hooks/garbage-role-denied.sh"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$deny_target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> out-of-scope path denied (same as default fallback)" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$deny_target"; then
    fail "$label -> stderr names the offending path" "target=[$deny_target] err=[$ERR]"
    return
  fi
  pass "$label -> out-of-scope path denied (same as default fallback), stderr names it"
}
case17

# ---------------------------------------------------------------------------
# Case 18: code-review round-1 escalation reproduction. Seed role=orchestrator
# in a LINKED WORKTREE marked root (product write denied -- baseline), then
# literally simulate the Bash tamper (a raw `printf 'builder' > .../dae-role`,
# no trailing newline, exactly like a plain shell redirect -- resolve_role is
# documented to tr -d '[:space:]' first so either form matches), then re-run
# the SAME product-path write and assert it is STILL denied. Reproduces
# code-review.md round 1's blocking finding #1 (a raw marker-file write used
# to escalate a parent-worktree orchestrator to full builder write scope).
# ---------------------------------------------------------------------------
case18() {
  local label="18: code-review round-1 escalation reproduction (linked worktree, orchestrator tampered to builder)"
  local parent target payload

  parent=$(new_marked_worktree_linked_with_role "orchestrator")
  target="$parent/src/app.js"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")

  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> baseline: product path denied for role=orchestrator" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> baseline: product path denied for role=orchestrator"

  # Simulate the raw Bash tamper -- no trailing newline.
  printf 'builder' >"$parent/.artifacts/dae-role"

  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> post-tamper: product path STILL denied" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> post-tamper: product path STILL denied (escalation no longer succeeds)"
}
case18

# ---------------------------------------------------------------------------
# Case 19 (Packet C addendum -- DP-2 regression fix): an unresolvable role in
# a MARKED context used to fall back to the OLD permissive rule (plans root
# AND docs root both allowed, only product denied). Seed role=orchestrator
# legitimately in a linked-worktree parent, then forge the marker to
# `builder` via a bare write (no hook -- simulating the escalation attempt,
# same tamper style as case18). Assert a write under the resolved plans root
# is now DENIED, and a write under the resolved docs root is also DENIED
# (previously both were exit 0 -- that was the regression this addendum
# closes).
# ---------------------------------------------------------------------------
case19() {
  local label="19: forged builder role, linked worktree parent -- plans root AND docs root now denied"
  local parent resolved_plans plans_root resolved_docs docs_root deny_plans deny_docs payload

  parent=$(new_marked_worktree_linked_with_role "orchestrator")
  printf 'builder' >"$parent/.artifacts/dae-role"

  if ! resolved_plans=$(resolve_var CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$parent"); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_PROJECT_PLANS_DIR failed"
    return
  fi
  plans_root=$(join_under "$parent" "$resolved_plans")
  deny_plans="$plans_root/case19-plan-09-02-26/plan.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$deny_plans")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> plans root denied" "code=$CODE out=[$OUT] err=[$ERR]"
  elif ! printf '%s\n' "$ERR" | grep -qF -- "$deny_plans"; then
    fail "$label -> stderr names the plans-root path" "target=[$deny_plans] err=[$ERR]"
  else
    pass "$label -> plans root denied, stderr names it"
  fi

  if ! resolved_docs=$(resolve_var CLAUDE_DOCS_DIR /docs "$parent" --expect path); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_DOCS_DIR failed"
    return
  fi
  docs_root=$(join_under "$parent" "$resolved_docs")
  deny_docs="$docs_root/case19-topic.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$deny_docs")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> docs root denied" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$deny_docs"; then
    fail "$label -> stderr names the docs-root path" "target=[$deny_docs] err=[$ERR]"
    return
  fi
  pass "$label -> docs root denied, stderr names it"
}
case19

# ---------------------------------------------------------------------------
# Case 20: same shape as case19, but the marker is forged to a plain garbage
# token ("xyz-garbage") instead of "builder" -- garbage must not behave any
# differently from a rejected `builder` claim. Plans root AND docs root both
# denied.
# ---------------------------------------------------------------------------
case20() {
  local label="20: forged garbage role, linked worktree parent -- plans root AND docs root now denied"
  local parent resolved_plans plans_root resolved_docs docs_root deny_plans deny_docs payload

  parent=$(new_marked_worktree_linked_with_role "orchestrator")
  printf 'xyz-garbage' >"$parent/.artifacts/dae-role"

  if ! resolved_plans=$(resolve_var CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$parent"); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_PROJECT_PLANS_DIR failed"
    return
  fi
  plans_root=$(join_under "$parent" "$resolved_plans")
  deny_plans="$plans_root/case20-plan-09-02-26/plan.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$deny_plans")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> plans root denied" "code=$CODE out=[$OUT] err=[$ERR]"
  elif ! printf '%s\n' "$ERR" | grep -qF -- "$deny_plans"; then
    fail "$label -> stderr names the plans-root path" "target=[$deny_plans] err=[$ERR]"
  else
    pass "$label -> plans root denied, stderr names it"
  fi

  if ! resolved_docs=$(resolve_var CLAUDE_DOCS_DIR /docs "$parent" --expect path); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_DOCS_DIR failed"
    return
  fi
  docs_root=$(join_under "$parent" "$resolved_docs")
  deny_docs="$docs_root/case20-topic.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$deny_docs")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> docs root denied" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$deny_docs"; then
    fail "$label -> stderr names the docs-root path" "target=[$deny_docs] err=[$ERR]"
    return
  fi
  pass "$label -> docs root denied, stderr names it"
}
case20

# ---------------------------------------------------------------------------
# Case 21: positive control for the Packet C fix -- a GENUINE `planner`
# token, seeded directly (not forged from a rejected state), in an
# equivalent linked-worktree fixture. Proves the fix didn't make the plans
# root unconditionally unreachable -- only closed the forged/garbage path to
# it. Plans root allowed; docs root and product path remain denied.
# ---------------------------------------------------------------------------
case21() {
  local label="21: genuine planner role, linked worktree parent -- plans root allowed, docs+product denied (positive control)"
  local parent resolved_plans plans_root resolved_docs docs_root allow_plans deny_docs deny_product payload

  parent=$(new_marked_worktree_linked_with_role "planner")

  if ! resolved_plans=$(resolve_var CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$parent"); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_PROJECT_PLANS_DIR failed"
    return
  fi
  plans_root=$(join_under "$parent" "$resolved_plans")
  allow_plans="$plans_root/case21-plan-09-02-26/plan.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$allow_plans")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> plans root allowed" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label -> plans root allowed"
  fi

  if ! resolved_docs=$(resolve_var CLAUDE_DOCS_DIR /docs "$parent" --expect path); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_DOCS_DIR failed"
    return
  fi
  docs_root=$(join_under "$parent" "$resolved_docs")
  deny_docs="$docs_root/case21-topic.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$deny_docs")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> docs root denied" "code=$CODE out=[$OUT] err=[$ERR]"
  elif ! printf '%s\n' "$ERR" | grep -qF -- "$deny_docs"; then
    fail "$label -> stderr names the docs-root path" "target=[$deny_docs] err=[$ERR]"
  else
    pass "$label -> docs root denied, stderr names it"
  fi

  deny_product="$parent/src/app.js"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$deny_product")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> product path denied" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$deny_product"; then
    fail "$label -> stderr names the product path" "target=[$deny_product] err=[$ERR]"
    return
  fi
  pass "$label -> product path denied, stderr names it"
}
case21

# ---------------------------------------------------------------------------
# Case 22 (Packet C addendum -- mandatory fail-open sanity re-check): a fully
# UNMARKED fixture (no .artifacts/progress-log.md anywhere in its ancestry at
# all) must still allow an arbitrary write completely unconditionally,
# unchanged by this addendum -- the unmarked path is a completely different
# code branch (the "else exit 0" before resolve_role is ever called) that
# Packet C does not touch. This must NOT regress to fail-closed.
# ---------------------------------------------------------------------------
case22() {
  local label="22: fully unmarked fixture -> arbitrary write still allowed unconditionally (fail-open re-check)"
  local child target payload
  child=$(new_unmarked_tree)
  target="$child/sub/dir/anything/goes/here.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case22

# ---------------------------------------------------------------------------
# Case 23 (Packet E -- structural `scratch` discriminator; scope corrected by
# Packet I): a main-checkout marked root with NO dae-role file at all (a
# ship: chat scratch marker's exact shape) -- the `scratch` allowance is
# scoped to <marked>/.artifacts ONLY, matching resolve-scratch.sh's own
# SCRATCHDIR shape (<marked>/.artifacts/reports/<slug>-<runid>/); nothing
# outside .artifacts, including the marked root's own top level, is allowed.
# 23a mirrors where a real chat run's scratch report lives
# (.artifacts/reports/<slug>/report.md) and is ALLOWED. 23b is a plain
# top-level file directly under the marked root, OUTSIDE .artifacts entirely
# -- it is correctly DENIED under the real rule. 23c is a distinguishing
# positive control: a path under .artifacts/ but NOT under .artifacts/reports/
# specifically is still ALLOWED, proving the rule is genuinely
# .artifacts-wide, not narrowed further to just reports/.
# ---------------------------------------------------------------------------
case23() {
  local label="23: Packet E/I -- main-checkout marked root, no dae-role file, scratch scoped to .artifacts only"
  local parent target payload

  parent=$(new_marked_worktree_main_checkout_no_role)
  target="$parent/.artifacts/reports/some-slug/report.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> 23a: write under <marked>/.artifacts/reports/<slug>/report.md allowed" "code=$CODE out=[$OUT] err=[$ERR]"
  else
    pass "$label -> 23a: write under <marked>/.artifacts/reports/<slug>/report.md allowed"
  fi

  parent=$(new_marked_worktree_main_checkout_no_role)
  target="$parent/top-level-scratch-file.txt"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> 23b: write directly under the marked root's top level (outside .artifacts) denied" "code=$CODE out=[$OUT] err=[$ERR]"
  elif ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> 23b: stderr names the denied path" "target=[$target] err=[$ERR]"
  else
    pass "$label -> 23b: write directly under the marked root's top level (outside .artifacts) denied, stderr names it"
  fi

  parent=$(new_marked_worktree_main_checkout_no_role)
  target="$parent/.artifacts/some-other-file.txt"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> 23c: write under <marked>/.artifacts/ but not under reports/ still allowed (positive control)" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> 23c: write under <marked>/.artifacts/ but not under reports/ still allowed (positive control)"
}
case23

# ---------------------------------------------------------------------------
# Case 24 (Packet E negative control): the scratch allowance from case23
# does NOT leak into a SEPARATE, unrelated fixture. A genuine
# orchestrator-marked main-checkout root (its own fresh mktemp -d, its own
# marker -- nothing shared with case23's fixture) still applies ONLY
# orchestrator's own narrow rule: a write under .artifacts/reports/ is not
# plans_root and doesn't match *-review.md/sync-report.md, so it is DENIED.
# This proves scope-writes.sh has no global/leaky state -- each hook
# invocation is independent and each fixture is governed by its own marker.
# ---------------------------------------------------------------------------
case24() {
  local label="24: Packet E negative control -- separate orchestrator-marked fixture governed by its own rule, not case23's scratch allowance"
  local parent target payload
  parent=$(new_marked_worktree_main_checkout_with_role "orchestrator")
  target="$parent/.artifacts/reports/some-slug/report.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label"
}
case24

# ---------------------------------------------------------------------------
# Case 25 (Packet E forgery reproduction -- the case the coordinator called
# "the one that matters most"): a REAL LINKED WORKTREE parent, role seeded
# legitimately as `orchestrator`, then the marker overwritten via a bare
# `printf 'scratch'` write (no hook -- simulating the tamper, same style as
# case18/case25's siblings elsewhere in this file). `scratch` is a computed
# value, NEVER read from the file -- writing the literal string `scratch`
# into dae-role must land in the exact same unresolved bucket as any other
# garbage token and be re-derived from the marked root's actual git topology
# (main_checkout=0 in a linked worktree -> orchestrator, unchanged by Packet
# E). A product-path write must therefore be STILL DENIED. If this were ever
# allowed, the fix would be broken.
#
# Positive control for Packet D/C's own garbage-handling coverage in this
# exact topology (linked worktree parent, forged/garbage role denies BOTH
# plans and docs roots) already exists at case20 (forged "xyz-garbage") and
# case19 (forged "builder") -- not duplicated here, see those cases.
# ---------------------------------------------------------------------------
case25() {
  local label="25: Packet E forgery reproduction (matters most) -- linked worktree parent, orchestrator forged to literal 'scratch'"
  local parent target payload

  parent=$(new_marked_worktree_linked_with_role "orchestrator")
  target="$parent/src/app.js"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")

  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> baseline: product path denied for role=orchestrator" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> baseline: product path denied for role=orchestrator"

  # Simulate the raw Bash tamper -- literal string "scratch", no trailing
  # newline (resolve_role is documented to tr -d '[:space:]' first).
  printf 'scratch' >"$parent/.artifacts/dae-role"

  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> post-forge: product path STILL denied" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> post-forge: product path STILL denied (literal 'scratch' string has no special effect)"
}
case25

# Case 26: agent_type is checked before resolve_role ever reads a marker file.
case26() {
  local label="26: agent_type=documenter, Write under resolved CLAUDE_DOCS_DIR (no dae-role file) -> allow"
  local parent resolved docs_root target payload
  parent=$(new_marked_worktree)
  if ! resolved=$(resolve_var CLAUDE_DOCS_DIR /docs "$parent" --expect path); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_DOCS_DIR failed"
    return
  fi
  docs_root=$(join_under "$parent" "$resolved")
  target="$docs_root/case26-topic.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s", "agent_type": "documenter"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "resolved=[$resolved] target=[$target] code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case26

case27() {
  local label="27: agent_type=documenter, Write outside docs root and not plan.md -> deny"
  local parent target payload
  parent=$(new_marked_worktree)
  target="$parent/src/app.js"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s", "agent_type": "documenter"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case27

case28() {
  local label="28: agent_type=documenter, Write to <plans-root>/some-plan-09-02-26/plan.md -> allow"
  local parent resolved plans_root target payload
  parent=$(new_marked_worktree)
  if ! resolved=$(resolve_var CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$parent"); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_PROJECT_PLANS_DIR failed"
    return
  fi
  plans_root=$(join_under "$parent" "$resolved")
  target="$plans_root/some-plan-09-02-26/plan.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s", "agent_type": "documenter"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label" "resolved=[$resolved] target=[$target] code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label"
}
case28

case29() {
  local label="29: agent_type=documenter, Write to <plans-root>/some-plan-09-02-26/notes.md (not plan.md) -> deny"
  local parent resolved plans_root target payload
  parent=$(new_marked_worktree)
  if ! resolved=$(resolve_var CLAUDE_PROJECT_PLANS_DIR /project-plans/ "$parent"); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_PROJECT_PLANS_DIR failed"
    return
  fi
  plans_root=$(join_under "$parent" "$resolved")
  target="$plans_root/some-plan-09-02-26/notes.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s", "agent_type": "documenter"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "resolved=[$resolved] target=[$target] code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2 (only plan.md is allowed, not the whole plans tree)"
}
case29

# Case 30: same target as case26 minus agent_type -- proves the gate is on
# agent_type, not path shape.
case30() {
  local label="30: positive control -- same docs-root target as case26 WITHOUT agent_type (role defaults to orchestrator) -> deny"
  local parent resolved docs_root target payload
  parent=$(new_marked_worktree)
  if ! resolved=$(resolve_var CLAUDE_DOCS_DIR /docs "$parent" --expect path); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_DOCS_DIR failed"
    return
  fi
  docs_root=$(join_under "$parent" "$resolved")
  target="$docs_root/case30-topic.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "resolved=[$resolved] target=[$target] code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2 (docs allowance is gated on agent_type=documenter, not just path shape)"
}
case30

case31() {
  local label="31: agent_type=coder (non-documenter) on lane-child fixture, path under docs root -> deny"
  local pair parent child resolved docs_root target payload
  pair=$(new_lane_root_pair)
  parent="${pair% *}"
  child="${pair#* }"
  if ! resolved=$(resolve_var CLAUDE_DOCS_DIR /docs "$child" --expect path); then
    fail "$label (setup)" "resolve-config.sh CLAUDE_DOCS_DIR failed"
    return
  fi
  docs_root=$(join_under "$child" "$resolved")
  target="$docs_root/case31-topic.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s", "agent_type": "coder"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "resolved=[$resolved] target=[$target] code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2 (non-documenter agent_type must not grant the documenter allowance; lane child resolves to builder, also docs-denied)"
}
case31

case32() {
  local label="32 (AC1): agent_type=builder, cwd=l1 child, path=parent's .artifacts/contracts/l1.md -> allow"
  local pair parent child cwd target payload
  pair=$(new_lane_root_pair)
  parent="${pair% *}"
  child="${pair#* }"
  cwd="$child"
  target="$parent/.artifacts/contracts/l1.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s", "agent_type": "builder", "cwd": "%s"}' "$target" "$cwd")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 0"
}
case32

case33() {
  local label="33 (AC2): agent_type=builder, cwd=l1 child, path=parent's .artifacts/reports/l1-exit.md -> allow"
  local pair parent child cwd target payload
  pair=$(new_lane_root_pair)
  parent="${pair% *}"
  child="${pair#* }"
  cwd="$child"
  target="$parent/.artifacts/reports/l1-exit.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s", "agent_type": "builder", "cwd": "%s"}' "$target" "$cwd")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 0"
}
case33

case34() {
  local label="34 (AC3): cwd=l1 child, path=SAME parent's .artifacts/contracts/l2.md (another lane) -> deny"
  local pair parent child other_child cwd target payload
  pair=$(new_lane_root_pair)
  parent="${pair% *}"
  child="${pair#* }"
  other_child="$(dirname "$parent")/$(basename "$parent")-l2"
  mkdir -p "$other_child"
  cwd="$child"
  target="$parent/.artifacts/contracts/l2.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s", "cwd": "%s"}' "$target" "$cwd")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case34

case35() {
  local label="35 (AC4): cwd=l1 child, path=parent's src/app.js (non-run-dir product path) -> deny"
  local pair parent child cwd target payload
  pair=$(new_lane_root_pair)
  parent="${pair% *}"
  child="${pair#* }"
  cwd="$child"
  target="$parent/src/app.js"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s", "cwd": "%s"}' "$target" "$cwd")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case35

case36() {
  local label="36 (AC5): cwd=parent itself (not a lane child), path=.artifacts/contracts/l1.md -> deny"
  local pair parent child cwd target payload
  pair=$(new_lane_root_pair)
  parent="${pair% *}"
  child="${pair#* }"
  cwd="$parent"
  target="$parent/.artifacts/contracts/l1.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s", "cwd": "%s"}' "$target" "$cwd")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case36

case37() {
  local label="37 (AC6): no cwd field at all, path=.artifacts/contracts/l1.md -> deny (unchanged)"
  local pair parent child target payload
  pair=$(new_lane_root_pair)
  parent="${pair% *}"
  child="${pair#* }"
  target="$parent/.artifacts/contracts/l1.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case37

case38() {
  local label="38 (AC7): orchestrator-role linked worktree, .artifacts/explore-map-foo-09-17-26.md -> allow"
  local parent target payload
  parent=$(new_marked_worktree_linked_with_role "orchestrator")
  target="$parent/.artifacts/explore-map-foo-09-17-26.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 0"
}
case38

case39() {
  local label="39 (AC8): planner-role linked worktree, .artifacts/explore-map-foo-09-17-26.md -> allow"
  local parent target payload
  parent=$(new_marked_worktree_linked_with_role "planner")
  target="$parent/.artifacts/explore-map-foo-09-17-26.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 0"
}
case39

case40() {
  local label="40 (AC9): orchestrator-role, .artifacts/explore-map-foo.txt (wrong extension) -> deny"
  local parent target payload
  parent=$(new_marked_worktree_linked_with_role "orchestrator")
  target="$parent/.artifacts/explore-map-foo.txt"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case40

case41() {
  local label="41 (AC10): orchestrator-role, .artifacts/sub/explore-map-foo-09-17-26.md (nested) -> deny"
  local parent target payload
  parent=$(new_marked_worktree_linked_with_role "orchestrator")
  target="$parent/.artifacts/sub/explore-map-foo-09-17-26.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case41

case42() {
  local label="42 (AC11): orchestrator-role, .artifacts/not-explore-map-foo-09-17-26.md (wrong prefix) -> deny"
  local parent target payload
  parent=$(new_marked_worktree_linked_with_role "orchestrator")
  target="$parent/.artifacts/not-explore-map-foo-09-17-26.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case42

# AC12 (regression, not a new case): satisfied by cases 1-31 above being unmodified.

case43() {
  local label="43 (AC13): orchestrator-role, .artifacts/committees/review-code/claims-c1.md -> allow"
  local parent target payload
  parent=$(new_marked_worktree_linked_with_role "orchestrator")
  target="$parent/.artifacts/committees/review-code/claims-c1.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 0"
}
case43

case44() {
  local label="44 (AC14): planner-role, .artifacts/committees/explore/claims-c3.md -> allow"
  local parent target payload
  parent=$(new_marked_worktree_linked_with_role "planner")
  target="$parent/.artifacts/committees/explore/claims-c3.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 0"
}
case44

case45() {
  local label="45 (AC15): orchestrator-role, .artifacts/committees/review-code/accepted.md -> allow"
  local parent target payload
  parent=$(new_marked_worktree_linked_with_role "orchestrator")
  target="$parent/.artifacts/committees/review-code/accepted.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 0"
}
case45

case46() {
  local label="46 (AC16): orchestrator-role, .artifacts/committees/review-code/reverify.md -> allow"
  local parent target payload
  parent=$(new_marked_worktree_linked_with_role "orchestrator")
  target="$parent/.artifacts/committees/review-code/reverify.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 0"
}
case46

case47() {
  local label="47 (AC17): orchestrator-role, .artifacts/committees/review-code/notes.md (not a named shape) -> deny"
  local parent target payload
  parent=$(new_marked_worktree_linked_with_role "orchestrator")
  target="$parent/.artifacts/committees/review-code/notes.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case47

case48() {
  local label="48 (AC18): orchestrator-role, .artifacts/committees/some-file.md (no skill subdir) -> deny"
  local parent target payload
  parent=$(new_marked_worktree_linked_with_role "orchestrator")
  target="$parent/.artifacts/committees/some-file.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case48

case49() {
  local label="49 (AC19): orchestrator-role, .artifacts/committees/review-code/sub/claims-c1.md (nested) -> deny"
  local parent target payload
  parent=$(new_marked_worktree_linked_with_role "orchestrator")
  target="$parent/.artifacts/committees/review-code/sub/claims-c1.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case49

case50() {
  local label="50 (AC20): orchestrator-role, .artifacts/random-notes.md (unrelated to committees/) -> deny"
  local parent target payload
  parent=$(new_marked_worktree_linked_with_role "orchestrator")
  target="$parent/.artifacts/random-notes.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case50

# Case 51: builder allowance requires agent_type=builder, not cwd alone -- no agent_type at all -> deny
case51() {
  local label="51: cwd=l1 child, path=parent's .artifacts/contracts/l1.md, NO agent_type field -> deny"
  local pair parent child cwd target payload
  pair=$(new_lane_root_pair)
  parent="${pair% *}"
  child="${pair#* }"
  cwd="$child"
  target="$parent/.artifacts/contracts/l1.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s", "cwd": "%s"}' "$target" "$cwd")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case51

# Case 52: same as case51 but for the reports/<lane-id>-exit.md target
case52() {
  local label="52: cwd=l1 child, path=parent's .artifacts/reports/l1-exit.md, NO agent_type field -> deny"
  local pair parent child cwd target payload
  pair=$(new_lane_root_pair)
  parent="${pair% *}"
  child="${pair#* }"
  cwd="$child"
  target="$parent/.artifacts/reports/l1-exit.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s", "cwd": "%s"}' "$target" "$cwd")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case52

# Case 53: agent_type present but wrong value (general-purpose, not builder) -> deny
case53() {
  local label="53: cwd=l1 child, path=parent's .artifacts/contracts/l1.md, agent_type=general-purpose -> deny"
  local pair parent child cwd target payload
  pair=$(new_lane_root_pair)
  parent="${pair% *}"
  child="${pair#* }"
  cwd="$child"
  target="$parent/.artifacts/contracts/l1.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s", "agent_type": "general-purpose", "cwd": "%s"}' "$target" "$cwd")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case53

# Case 54: same as case53 with a second wrong agent_type value (orchestrator) -> deny
case54() {
  local label="54: cwd=l1 child, path=parent's .artifacts/contracts/l1.md, agent_type=orchestrator -> deny"
  local pair parent child cwd target payload
  pair=$(new_lane_root_pair)
  parent="${pair% *}"
  child="${pair#* }"
  cwd="$child"
  target="$parent/.artifacts/contracts/l1.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s", "agent_type": "orchestrator", "cwd": "%s"}' "$target" "$cwd")
  run_hook "$payload"
  if [ "$CODE" -ne 2 ]; then
    fail "$label -> exit 2" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! printf '%s\n' "$ERR" | grep -qF -- "$target"; then
    fail "$label -> stderr names the offending path" "target=[$target] err=[$ERR]"
    return
  fi
  pass "$label -> exit 2, stderr names $target"
}
case54

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
