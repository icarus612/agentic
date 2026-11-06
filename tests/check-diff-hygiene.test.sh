#!/usr/bin/env bash
# Contract tests for agent-agnostic/hooks/check-diff-hygiene.sh (comment scope).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/agent-agnostic/hooks/check-diff-hygiene.sh"

TOTAL_PASS=0
TOTAL_FAIL=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

pass() {
  echo "PASS: $1"
  TOTAL_PASS=$((TOTAL_PASS + 1))
}

fail() {
  echo "FAIL: $1 ($2)"
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
}

OUT=""
ERR=""
CODE=0
REPO=""

new_repo() {
  REPO=$(mktemp -d "$TMP_ROOT/repo.XXXXXX")
  git -C "$REPO" init -q -b main
  git -C "$REPO" config user.name test
  git -C "$REPO" config user.email test@example.com
}

commit_all() {
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m "$1"
}

start_feature() {
  commit_all base
  git -C "$REPO" checkout -q -b feat
}

filler() {
  local n="$1" tag="$2" i
  for ((i = 1; i <= n; i++)); do
    printf 'const %s%d = %d;\n' "$tag" "$i" "$i"
  done
}

hunks() {
  git -C "$REPO" diff main...HEAD | grep -c '^@@'
}

run_check() {
  local out_f err_f
  out_f=$(mktemp "$TMP_ROOT/out.XXXXXX")
  err_f=$(mktemp "$TMP_ROOT/err.XXXXXX")
  "$SCRIPT" --base main --repo-dir "$REPO" --scope comments >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
}

expect_hunks() {
  local label="$1" want="$2" got
  got=$(hunks)
  if [ "$got" -ne "$want" ]; then
    fail "$label fixture" "expected $want hunks, got $got"
    return 1
  fi
  return 0
}

expect_clean() {
  local label="$1"
  run_check
  if [ "$CODE" -eq 0 ]; then
    pass "$label -> exit 0"
  else
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
  fi
}

expect_violation() {
  local label="$1" marker="${2:-}"
  run_check
  if [ "$CODE" -ne 1 ]; then
    fail "$label -> exit 1" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if [ -n "$marker" ] && ! printf '%s\n' "$OUT" | grep -qF -- "$marker"; then
    fail "$label -> output has $marker" "out=[$OUT]"
    return
  fi
  pass "$label -> exit 1${marker:+, output has $marker}"
}

# 1
new_repo
{
  echo 'const a = 1;'
  printf '// alpha one\n// beta two\n// gamma three\n'
  echo 'const b = 2;'
} >"$REPO/f.ts"
start_feature
{
  echo 'const a = 1;'
  printf '// first line reworded\n// second line reworded\n// third line reworded\n'
  echo 'const b = 2;'
} >"$REPO/f.ts"
commit_all reword
expect_hunks "case 1" 1 && expect_clean "case 1 pure reword"

# 2
new_repo
{
  echo 'const top = 1;'
  for i in $(seq 1 12); do printf '// old note %d\n' "$i"; done
  echo 'const mid = 2;'
  echo 'const end = 3;'
} >"$REPO/f.ts"
start_feature
{
  echo 'const top = 10;'
  for i in $(seq 1 12); do printf '// new wording %d\n' "$i"; done
  echo 'const mid = 20;'
  echo 'const end = 3;'
} >"$REPO/f.ts"
commit_all reword-dense
expect_hunks "case 2" 1 && expect_clean "case 2 reword under density"

# 3
new_repo
{ echo 'const a = 1;'; echo 'const b = 2;'; } >"$REPO/f.ts"
start_feature
{
  echo 'const a = 1;'
  printf '// new one\n// new two\n// new three\n'
  echo 'const b = 2;'
} >"$REPO/f.ts"
commit_all banner
expect_hunks "case 3" 1 && expect_violation "case 3 new banner" "COMMENT BANNER"

# 4
new_repo
{
  echo 'const a = 1;'
  printf '// old one\n// old two\n'
  echo 'const b = 2;'
} >"$REPO/f.ts"
start_feature
{
  echo 'const a = 1;'
  printf '// reworded one\n// reworded two\n// extra three\n// extra four\n// extra five\n'
  echo 'const b = 2;'
} >"$REPO/f.ts"
commit_all reword-plus-new
expect_hunks "case 4" 1 && expect_violation "case 4 reword plus net-new" "COMMENT BANNER"

# 5
new_repo
{
  filler 8 a
  filler 8 b
  filler 8 c
  filler 8 d
  filler 8 e
} >"$REPO/f.ts"
start_feature
{
  filler 8 a
  printf '// one a\n// one b\n'
  filler 8 b
  printf '// two a\n// two b\n'
  filler 8 c
  printf '// three a\n// three b\n'
  filler 8 d
  printf '// four a\n// four b\n'
  filler 8 e
} >"$REPO/f.ts"
commit_all separate
expect_hunks "case 5" 4 && expect_clean "case 5 compliant comments across hunks"

# 6
new_repo
{
  filler 8 a
  printf '// old one\n// old two\n// old three\n'
  filler 8 b
  filler 8 c
} >"$REPO/f.ts"
start_feature
{
  filler 8 a
  filler 8 b
  printf '// new one\n// new two\n// new three\n'
  filler 8 c
} >"$REPO/f.ts"
commit_all removed-then-banner
expect_hunks "case 6" 2 && expect_violation "case 6 removals in other hunk do not pair" "COMMENT BANNER"

# 7
new_repo
{
  echo 'echo start'
  printf '# old one\n# old two\n# old three\n'
  echo 'echo end'
} >"$REPO/s.sh"
start_feature
{
  echo 'echo start'
  printf '# new one\n# new two\n# new three\n'
  echo 'echo end'
} >"$REPO/s.sh"
commit_all sh-reword
expect_hunks "case 7a" 1 && expect_clean "case 7a .sh reword"

new_repo
{ echo 'echo start'; echo 'echo end'; } >"$REPO/s.sh"
start_feature
{
  echo 'echo start'
  printf '# new one\n# new two\n# new three\n'
  echo 'echo end'
} >"$REPO/s.sh"
commit_all sh-banner
expect_hunks "case 7b" 1 && expect_violation "case 7b .sh new banner" "COMMENT BANNER"

# 8
new_repo
echo 'const a = 1;' >"$REPO/f.ts"
start_feature
printf 'const a = 1;\n// x\n// y\n// z\n' >"$REPO/f.ts"
run_check
if [ "$CODE" -eq 2 ] && printf '%s\n' "$ERR" | grep -qF -- "REFUSING"; then
  pass "case 8 uncommitted-only -> exit 2, stderr REFUSING"
else
  fail "case 8 uncommitted-only -> exit 2, stderr REFUSING" "code=$CODE out=[$OUT] err=[$ERR]"
fi

# 9
new_repo
{
  echo 'const a = 1;'
  printf '// old one\n// old two\n// old three\n'
} >"$REPO/a.ts"
start_feature
git -C "$REPO" rm -q a.ts
{
  echo 'const b = 1;'
  printf '// new one\n// new two\n// new three\n'
} >"$REPO/b.ts"
commit_all delete-and-add
expect_violation "case 9 deleted file does not pair with new file" "COMMENT BANNER"

# 10
new_repo
{
  echo 'const a = 1;'
  printf '// old one\n// old two\n// old three\n'
  echo 'const b = 2;'
} >"$REPO/f.ts"
start_feature
{
  echo 'const a = 1;'
  printf '// different x\n// different y\n// different z\n'
  echo 'const b = 2;'
} >"$REPO/f.ts"
commit_all replace-block
expect_hunks "case 10" 1 && expect_clean "case 10 replacement within one hunk"

# 11
new_repo
{
  printf '%s\n' '.a {' '--foo: 1px;' '}'
  filler 8 x
} >"$REPO/file.css"
start_feature
{
  printf '%s\n' '.a {' '}'
  filler 8 x
  printf '%s\n' '/* one */' '/* two */' '/* three */'
} >"$REPO/file.css"
commit_all css-banner
if git -C "$REPO" diff main...HEAD | grep -qxF -- '---foo: 1px;'; then
  run_check
  if [ "$CODE" -ne 1 ]; then
    fail "case 11 css banner -> exit 1" "code=$CODE out=[$OUT] err=[$ERR]"
  elif ! printf '%s\n' "$OUT" | grep -F -- "COMMENT BANNER" | grep -qF -- "file.css"; then
    fail "case 11 banner names file.css" "out=[$OUT]"
  else
    pass "case 11 removed ---foo line keeps file attribution"
  fi
else
  fail "case 11 fixture" "diff lacks ---foo line"
fi

echo
echo "passed=$TOTAL_PASS failed=$TOTAL_FAIL"
[ "$TOTAL_FAIL" -eq 0 ]
