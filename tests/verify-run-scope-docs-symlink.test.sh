#!/usr/bin/env bash
# Blind contract test: verify-run-scope.sh treats symlinks resolving into the docs root as harness-owned.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_RUN="$REPO_ROOT/agent-agnostic/hooks/verify-run-scope.sh"

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

EMPTY_HOME=$(new_scratch)
export HOME="$EMPTY_HOME"
unset CLAUDE_DOCS_DIR

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

new_git_worktree() {
  local dir
  dir=$(new_scratch)
  git_init_repo "$dir"
  printf 'baseline\n' >"$dir/README.md"
  commit_all "$dir" "baseline"
  printf '%s' "$dir"
}

WT=""
BASE=""
RUNDIR=""
new_fixture() {
  WT=$(new_git_worktree)
  RUNDIR=$(new_scratch)
  mkdir -p "$RUNDIR/reports"
}

commit_base() {
  commit_all "$WT" "base files"
  BASE=$(git -C "$WT" rev-parse HEAD)
}

run_case() {
  run_script "$SCRIPT_RUN" "$WT" "$BASE" "$RUNDIR"
}

expect_ok() {
  local name="$1"
  if [ "$CODE" -eq 0 ] && printf '%s\n' "$OUT" | grep -qF "OK:" \
    && ! printf '%s\n' "$OUT" | grep -qF "UNCLAIMED"; then
    pass "$name"
  else
    fail "$name" "code=$CODE out=$OUT err=$ERR"
  fi
}

expect_unclaimed() {
  local name="$1" path="$2"
  if [ "$CODE" -eq 1 ] && printf '%s\n' "$OUT" | grep -qF "UNCLAIMED: $path"; then
    pass "$name"
  else
    fail "$name" "code=$CODE out=$OUT err=$ERR"
  fi
}

if ! bash -n "$SCRIPT_RUN" 2>/dev/null; then
  fail "00: bash -n verify-run-scope.sh" "syntax error"
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi

new_fixture
mkdir -p "$WT/docs/apps/web" "$WT/apps/web"
printf 'doc\n' >"$WT/docs/apps/web/README.md"
commit_base
ln -s ../../docs/apps/web/README.md "$WT/apps/web/README.md"
commit_all "$WT" "symlink"
run_case
expect_ok "01: file symlink into docs root is not UNCLAIMED"

new_fixture
mkdir -p "$WT/docs/apps/web" "$WT/apps/web"
printf 'doc\n' >"$WT/docs/apps/web/README.md"
commit_base
ln -s ../../docs/apps/web "$WT/apps/web/docs"
commit_all "$WT" "dir symlink"
run_case
expect_ok "02: directory symlink into docs root is not UNCLAIMED"

new_fixture
mkdir -p "$WT/apps/web"
commit_base
ln -s ../../docs/apps/web/README.md "$WT/apps/web/README.md"
commit_all "$WT" "dangling symlink"
run_case
expect_ok "03: dangling symlink into docs root is not UNCLAIMED"

new_fixture
mkdir -p "$WT/apps/web" "$WT/notes"
printf 'n\n' >"$WT/notes/README.md"
commit_base
ln -s ../../notes/README.md "$WT/apps/web/README.md"
commit_all "$WT" "outside symlink"
run_case
expect_unclaimed "04: symlink outside docs root is UNCLAIMED" "apps/web/README.md"

new_fixture
mkdir -p "$WT/apps/web" "$WT/docs-old"
printf 'o\n' >"$WT/docs-old/README.md"
commit_base
ln -s ../../docs-old/README.md "$WT/apps/web/README.md"
commit_all "$WT" "lookalike symlink"
run_case
expect_unclaimed "05: lookalike docs-old symlink is UNCLAIMED" "apps/web/README.md"

new_fixture
mkdir -p "$WT/apps/web"
commit_base
printf 'regular\n' >"$WT/apps/web/README.md"
commit_all "$WT" "regular file"
run_case
expect_unclaimed "06: regular file is UNCLAIMED" "apps/web/README.md"

new_fixture
mkdir -p "$WT/.claude" "$WT/documentation/apps/web" "$WT/apps/web"
printf '{"env":{"CLAUDE_DOCS_DIR":"/documentation"}}\n' >"$WT/.claude/settings.json"
printf 'doc\n' >"$WT/documentation/apps/web/README.md"
commit_base
ln -s ../../documentation/apps/web/README.md "$WT/apps/web/README.md"
commit_all "$WT" "symlink into custom docs root"
run_case
expect_ok "07a: symlink into configured docs root is not UNCLAIMED"

new_fixture
mkdir -p "$WT/.claude" "$WT/docs/apps/web" "$WT/apps/web"
printf '{"env":{"CLAUDE_DOCS_DIR":"/documentation"}}\n' >"$WT/.claude/settings.json"
printf 'doc\n' >"$WT/docs/apps/web/README.md"
commit_base
ln -s ../../docs/apps/web/README.md "$WT/apps/web/README.md"
commit_all "$WT" "symlink into non-configured docs"
run_case
expect_unclaimed "07b: symlink into docs/ when root is /documentation is UNCLAIMED" "apps/web/README.md"

new_fixture
mkdir -p "$WT/docs" "$WT/apps/web"
printf 'a\n' >"$WT/docs/a.md"
commit_base
ln -s "$WT/docs/a.md" "$WT/apps/web/a.md"
commit_all "$WT" "absolute symlink"
run_case
expect_ok "08: absolute-target symlink into docs root is not UNCLAIMED"

echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ] || exit 1
exit 0
