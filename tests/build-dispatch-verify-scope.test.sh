#!/usr/bin/env bash
# build-dispatch-verify-scope.test.sh — contract test for build-dispatch.md step 1 and verify-scope.sh.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$REPO_ROOT/agent-agnostic/skills/dae/build-dispatch.md"
VS="$REPO_ROOT/agent-agnostic/hooks/verify-scope.sh"

PASS=0
FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ok() { PASS=$((PASS + 1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }

STEP1="$(awk '
  /^## /{ insec = ($0 ~ /^## Event-driven scheduling/) }
  insec && /^1\. \*\*Verify the lane/ { on=1 }
  on && /^2\. / { exit }
  on { print }
' "$DOC" 2>/dev/null | tr '\n' ' ' | tr -s '[:space:]' ' ')"

if [ -n "$STEP1" ] && printf '%s' "$STEP1" | grep -qF 'Verify the lane'; then
  ok "00 step-1 extraction non-empty and contains 'Verify the lane'"
else
  bad "00 step-1 extraction empty or missing 'Verify the lane'"
fi

if printf '%s' "$STEP1" | grep -qF 'verify-scope.sh <child-worktree> <parent-branch> --report <run-dir>/reports/<lane-id>-exit.md'; then
  ok "01 step 1 invokes verify-scope.sh with --report"
else
  bad "01 step 1 lacks verify-scope.sh <child-worktree> <parent-branch> --report <run-dir>/reports/<lane-id>-exit.md"
fi

if printf '%s' "$STEP1" | grep -qF 'git diff --name-only' \
  && { printf '%s' "$STEP1" | grep -qiw 'forbidden' || printf '%s' "$STEP1" | grep -qiw 'never'; }; then
  ok "02 step 1 forbids git diff --name-only feeding"
else
  bad "02 step 1 lacks 'git diff --name-only' with forbidden/never"
fi

if [ -n "$STEP1" ] && ! printf '%s' "$STEP1" | grep -qF "fed the report's"; then
  ok "03 step 1 does not contain \"fed the report's\""
else
  bad "03 step 1 contains \"fed the report's\" (or extraction empty)"
fi

FX="$TMP/fx"
PARENT="parentbr"
mkdir -p "$FX/main"
git -C "$FX/main" init -q -b "$PARENT" 2>/dev/null || { git -C "$FX/main" init -q; git -C "$FX/main" checkout -q -b "$PARENT"; }
git -C "$FX/main" config user.email t@example.com
git -C "$FX/main" config user.name tester
echo base > "$FX/main/base.txt"
git -C "$FX/main" add base.txt
git -C "$FX/main" commit -q -m base
WT="$FX/wt"
git -C "$FX/main" worktree add -q -b child "$WT" "$PARENT"
mkdir -p "$WT/lane"
echo a > "$WT/lane/x.txt"
echo b > "$WT/lane/y.txt"
git -C "$WT" add lane
git -C "$WT" commit -q -m child
REPORT="$TMP/exit.md"
printf '## Files touched\n\n- x.txt\n- y.txt\n' > "$REPORT"

git -C "$WT" diff --name-only "$PARENT"..HEAD | bash "$VS" "$WT" "$PARENT" >"$TMP/stdin.out" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  ok "04a diff --name-only piped on stdin exits 0"
else
  bad "04a stdin mode exit $rc: $(cat "$TMP/stdin.out")"
fi

bash "$VS" "$WT" "$PARENT" --report "$REPORT" >"$TMP/report.out" 2>&1
rc=$?
if [ "$rc" -eq 1 ] && grep -qF 'UNREPORTED:' "$TMP/report.out"; then
  ok "04b prefix-less report fails with UNREPORTED"
else
  bad "04b --report mode exit $rc: $(cat "$TMP/report.out")"
fi

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
