#!/usr/bin/env bash
# Contract tests for smart-test.sh related-tests mode in JS package mode.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${SMART_TEST_SCRIPT:-$REPO_ROOT/agent-agnostic/hooks/smart-test.sh}"

TOTAL_PASS=0
TOTAL_FAIL=0
SCRATCH_DIRS=()

pass() {
  echo "PASS: $1"
  TOTAL_PASS=$((TOTAL_PASS + 1))
}

fail() {
  echo "FAIL: $1 ($2)"
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
}

cleanup() {
  local d
  for d in "${SCRATCH_DIRS[@]:-}"; do
    [ -n "$d" ] && [ -e "$d" ] && rm -rf "$d"
  done
  return 0
}
trap cleanup EXIT

# new_fixture <pkg-test-body> -- prints fixture root
new_fixture() {
  local d
  d=$(mktemp -d)
  SCRATCH_DIRS+=("$d")
  mkdir -p "$d/packages/a/src"
  cat >"$d/package.json" <<'JSON'
{"name":"root","private":true,"scripts":{"test":"sh ./root-test.sh; turbo test"}}
JSON
  : >"$d/pnpm-lock.yaml"
  printf 'touch root-ran\n' >"$d/root-test.sh"
  cat >"$d/packages/a/package.json" <<'JSON'
{"name":"a","private":true,"scripts":{"test":"sh ./pkg-test.sh"}}
JSON
  printf '%s\n' "$1" >"$d/packages/a/pkg-test.sh"
  printf 'export const foo = 1\n' >"$d/packages/a/src/foo.ts"
  printf 'export const t = 1\n' >"$d/packages/a/src/foo.test.ts"
  printf '%s' "$d"
}

# add_runner <fixture> <vitest|jest> <exit-code-on-related>
add_runner() {
  local bin="$1/packages/a/node_modules/.bin"
  mkdir -p "$bin"
  cat >"$bin/$2" <<RUNNER
#!/bin/sh
pkg="\$(cd "\$(dirname "\$0")/../.." && pwd)"
printf '%s\n' "\$*" >>"\$pkg/runner-argv.log"
case "\$*" in
  *related*|*--findRelatedTests*)
    echo "RELATED-MARKER-$3"
    exit $3
    ;;
esac
exit 0
RUNNER
  chmod +x "$bin/$2"
}

# payload <file> <cwd>
payload() {
  python3 -c '
import json, sys
print(json.dumps({"tool_name": "Edit", "file_path": sys.argv[1], "cwd": sys.argv[2]}))
' "$1" "$2"
}

CODE=0
ERR=""
# run_hook <launch-dir> <payload-file> <err-file>
run_hook() {
  (cd "$1" && CLAUDE_HOOKS_TEST_MODES=focused,package timeout 120 bash "$SCRIPT" <"$2" >/dev/null 2>"$3")
  CODE=$?
  ERR=$(cat "$3")
}

LOG=""
read_log() {
  LOG=""
  [ -f "$1/packages/a/runner-argv.log" ] && LOG=$(cat "$1/packages/a/runner-argv.log")
  return 0
}

has_pkg() { [ -f "$1/packages/a/pkg-ran" ] && echo yes || echo no; }
has_root() { [ -e "$1/root-ran" ] && echo yes || echo no; }

if ! command -v pnpm >/dev/null 2>&1; then
  if [ "${SMART_TEST_REQUIRE_PNPM:-0}" = "1" ]; then
    fail "pnpm availability" "pnpm not on PATH"
  else
    echo "SKIP: pnpm not on PATH"
  fi
  HAVE_PNPM=0
else
  HAVE_PNPM=1
fi

if [ "$HAVE_PNPM" = "1" ]; then
  pl=$(mktemp); SCRATCH_DIRS+=("$pl"); errf=$(mktemp); SCRATCH_DIRS+=("$errf")

  # 01
  fx=$(new_fixture 'touch pkg-ran')
  add_runner "$fx" vitest 0
  payload "$fx/packages/a/src/foo.ts" "$fx" >"$pl"
  run_hook "$fx" "$pl" "$errf"
  read_log "$fx"
  if printf '%s\n' "$LOG" | grep -F 'related' | grep -F -e '--run' | grep -qF "$fx/packages/a/src/foo.ts" \
    && [ "$(has_pkg "$fx")" = "no" ] && [ "$(has_root "$fx")" = "no" ]; then
    pass "01 vitest source edit runs related on absolute file, not pnpm test"
  else
    fail "01 vitest source edit runs related on absolute file, not pnpm test" "code=$CODE pkg-ran=$(has_pkg "$fx") root-ran=$(has_root "$fx") log=[$LOG]"
  fi

  # 02
  fx=$(new_fixture 'touch pkg-ran')
  add_runner "$fx" jest 0
  payload "$fx/packages/a/src/foo.ts" "$fx" >"$pl"
  run_hook "$fx" "$pl" "$errf"
  read_log "$fx"
  if printf '%s\n' "$LOG" | grep -F -e '--findRelatedTests' | grep -F -e '--passWithNoTests' | grep -qF "$fx/packages/a/src/foo.ts" \
    && [ "$(has_pkg "$fx")" = "no" ]; then
    pass "02 jest source edit runs findRelatedTests on absolute file, not pnpm test"
  else
    fail "02 jest source edit runs findRelatedTests on absolute file, not pnpm test" "code=$CODE pkg-ran=$(has_pkg "$fx") log=[$LOG]"
  fi

  # 03
  fx=$(new_fixture 'touch pkg-ran')
  add_runner "$fx" vitest 1
  payload "$fx/packages/a/src/foo.ts" "$fx" >"$pl"
  run_hook "$fx" "$pl" "$errf"
  read_log "$fx"
  if [ "$CODE" = "2" ] && printf '%s' "$ERR" | grep -qF 'RELATED-MARKER-1' \
    && printf '%s\n' "$LOG" | grep -qF 'related'; then
    pass "03 failing related run exits 2 with runner output on stderr"
  else
    fail "03 failing related run exits 2 with runner output on stderr" "code=$CODE log=[$LOG] stderr=[$ERR]"
  fi

  # 04
  fx=$(new_fixture 'touch pkg-ran')
  payload "$fx/packages/a/src/foo.ts" "$fx" >"$pl"
  run_hook "$fx" "$pl" "$errf"
  if [ "$(has_pkg "$fx")" = "yes" ] && [ "$(has_root "$fx")" = "no" ]; then
    pass "04 no direct runner falls back to pnpm test in owning package"
  else
    fail "04 no direct runner falls back to pnpm test in owning package" "code=$CODE pkg-ran=$(has_pkg "$fx") root-ran=$(has_root "$fx")"
  fi

  # 05
  fx=$(new_fixture 'touch pkg-ran')
  add_runner "$fx" vitest 0
  payload "$fx/packages/a/src/foo.test.ts" "$fx" >"$pl"
  run_hook "$fx" "$pl" "$errf"
  read_log "$fx"
  if printf '%s\n' "$LOG" | grep -qF 'run src/foo.test.ts' && ! printf '%s\n' "$LOG" | grep -qF 'related'; then
    pass "05 test-file edit runs the test file, no related invocation"
  else
    fail "05 test-file edit runs the test file, no related invocation" "code=$CODE log=[$LOG]"
  fi
fi

echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ] || exit 1
exit 0
