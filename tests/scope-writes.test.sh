#!/usr/bin/env bash
# scope-writes.test.sh
#
# SYNOPSIS
#   bash tests/scope-writes.test.sh
#
# DESCRIPTION
#   Blind contract test for orchestrators/hooks/scope-writes.sh (Packet 1,
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
#   real orchestrators/hooks/resolve-config.sh (a tool, not the implementation
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
SCRIPT="$REPO_ROOT/orchestrators/hooks/scope-writes.sh"
RESOLVE_SCRIPT="$REPO_ROOT/orchestrators/hooks/resolve-config.sh"

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
  target="$parent/orchestrators/hooks/foo.sh"
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
# Case 02: Write to <parent>/.artifacts/progress-log.md -> exit 0
# ---------------------------------------------------------------------------
case02() {
  local label="02: Write to <parent>/.artifacts/progress-log.md -> allow"
  local parent target payload
  parent=$(new_marked_worktree)
  target="$parent/.artifacts/progress-log.md"
  payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$target")
  run_hook "$payload"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 0"
}
case02

# ---------------------------------------------------------------------------
# Case 03: Write under the RESOLVED plans dir -> exit 0
# ---------------------------------------------------------------------------
case03() {
  local label="03: Write under resolved CLAUDE_PROJECT_PLANS_DIR -> allow"
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
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "resolved=[$resolved] target=[$target] code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 0 (resolved=[$resolved])"
}
case03

# ---------------------------------------------------------------------------
# Case 04: Write under the RESOLVED docs dir -> exit 0
# ---------------------------------------------------------------------------
case04() {
  local label="04: Write under resolved CLAUDE_DOCS_DIR -> allow"
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
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "resolved=[$resolved] target=[$target] code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  pass "$label -> exit 0 (resolved=[$resolved])"
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
  target="$child/sub/dir/orchestrators/hooks/foo.sh"
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
  target="$parent/orchestrators/hooks/foo.sh"

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
  target="$parent/orchestrators/hooks/aliased.sh"
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
  target="$parent/orchestrators/hooks/edited.sh"
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
  target="$parent/orchestrators/hooks/notebook.ipynb"
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
# Summary
# ---------------------------------------------------------------------------
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
