#!/usr/bin/env bash
# resolve-config-precedence.test.sh
#
# SYNOPSIS
#   bash tests/resolve-config-precedence.test.sh
#
# DESCRIPTION
#   Blind contract test for orchestrators/hooks/resolve-config.sh's resolution
#   chain (contracts/l1.md, Packet 6 / C9): the $HOME tier reorder that makes
#   $HOME/.claude/settings.json rank ahead of $HOME/.gemini/config/settings.json,
#   while leaving the project tiers (<root>/.agents/..., <root>/.claude/...)
#   untouched and still highest priority overall. Written from the contract
#   text alone (documented CLI usage: `resolve-config.sh <VAR_NAME>
#   [--default <value> | --base-branch-default] [--root <path>]`; exit 0 =
#   resolved value on stdout + source on stderr; exit 1 = unresolvable or bad
#   usage). Never reads resolve-config.sh's source.
#
#   All fixtures are throwaway mktemp -d directories used as a fake $HOME
#   (via HOME=<fixture> ...) and a fake project root (via --root <fixture>).
#   The real $HOME, ~/.claude, and ~/.gemini are never read or written.
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
SCRIPT="$REPO_ROOT/orchestrators/hooks/resolve-config.sh"

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

# run_resolve <HOME-dir> <VAR_NAME> [extra args...] -- invokes resolve-config.sh
# with HOME pinned to the given fixture dir, stdin from /dev/null, and sets
# globals OUT / ERR / CODE.
OUT=""
ERR=""
CODE=0
run_resolve() {
  local home_dir="$1" var="$2"
  shift 2
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  HOME="$home_dir" "$SCRIPT" "$var" "$@" </dev/null >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

# write_settings_json <file-path> <var1=val1> [var2=val2 ...]
# Writes a flat {"env": {...}} settings.json with the given key/value pairs.
write_settings_json() {
  local file="$1"
  shift
  mkdir -p "$(dirname "$file")"
  {
    printf '{\n  "env": {\n'
    local first=1 pair key val
    for pair in "$@"; do
      key="${pair%%=*}"
      val="${pair#*=}"
      if [ "$first" -eq 1 ]; then
        first=0
      else
        printf ',\n'
      fi
      printf '    "%s": "%s"' "$key" "$val"
    done
    printf '\n  }\n}\n'
  } >"$file"
}

new_home() { new_scratch; }
new_root() { new_scratch; }

# ---------------------------------------------------------------------------
# Case 0: bash -n sanity precondition (script must at least parse)
# ---------------------------------------------------------------------------
if bash -n "$SCRIPT" 2>/tmp/resolve-config-precedence-syntax-err.$$; then
  pass "00: bash -n resolve-config.sh exits 0"
else
  syntax_err=$(cat /tmp/resolve-config-precedence-syntax-err.$$ 2>/dev/null)
  fail "00: bash -n resolve-config.sh exits 0" "syntax error: $syntax_err"
  rm -f /tmp/resolve-config-precedence-syntax-err.$$
  echo "sanity failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
rm -f /tmp/resolve-config-precedence-syntax-err.$$

# ---------------------------------------------------------------------------
# Case set 1: nothing defines the var anywhere, no --default -> exit 1
# ---------------------------------------------------------------------------
c1_home=$(new_home)
c1_root=$(new_root)

run_resolve "$c1_home" CLAUDE_DOCS_DIR --root "$c1_root"
if [ "$CODE" -eq 1 ]; then
  pass "01: no HOME/.claude, no HOME/.gemini, no project tier, no --default -> exit 1"
else
  fail "01: no HOME/.claude, no HOME/.gemini, no project tier, no --default -> exit 1" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case set 2: only $HOME/.gemini/config/settings.json defines the var ->
# resolves to that value (Gemini tier still works when Claude's is absent).
# ---------------------------------------------------------------------------
c2_home=$(new_home)
c2_root=$(new_root)
write_settings_json "$c2_home/.gemini/config/settings.json" "CLAUDE_DOCS_DIR=from-gemini"

run_resolve "$c2_home" CLAUDE_DOCS_DIR --root "$c2_root"
if [ "$CODE" -eq 0 ] && [ "$OUT" = "from-gemini" ]; then
  pass "02: only \$HOME/.gemini/config/settings.json defines var -> resolves to it, exit 0"
else
  fail "02: only \$HOME/.gemini/config/settings.json defines var -> resolves to it, exit 0" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case set 3: THE PRECEDENCE CASE. Both $HOME/.claude/settings.json and
# $HOME/.gemini/config/settings.json define the var with DIFFERENT values ->
# the resolved value is the ~/.claude/ one, and the stderr source: line names
# the .claude/settings.json fixture path, not the .gemini one.
# ---------------------------------------------------------------------------
c3_home=$(new_home)
c3_root=$(new_root)
write_settings_json "$c3_home/.claude/settings.json" "CLAUDE_DOCS_DIR=from-claude-home"
write_settings_json "$c3_home/.gemini/config/settings.json" "CLAUDE_DOCS_DIR=from-gemini-home"

run_resolve "$c3_home" CLAUDE_DOCS_DIR --root "$c3_root"
if [ "$CODE" -eq 0 ] && [ "$OUT" = "from-claude-home" ]; then
  pass "03a: HOME tier precedence - both HOME files define var, .claude value wins on stdout"
else
  fail "03a: HOME tier precedence - both HOME files define var, .claude value wins on stdout" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

if printf '%s\n' "$ERR" | grep -qF "$c3_home/.claude/settings.json" \
   && ! printf '%s\n' "$ERR" | grep -qF "$c3_home/.gemini/config/settings.json"; then
  pass "03b: HOME tier precedence - stderr source: line names .claude/settings.json, not .gemini"
else
  fail "03b: HOME tier precedence - stderr source: line names .claude/settings.json, not .gemini" \
    "err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case set 4: a project-tier value still wins over BOTH $HOME entries, even
# when all three define different values (project tier untouched/highest).
# ---------------------------------------------------------------------------

# --- 4a: project tier via <root>/.claude/settings.json ----------------------
c4a_home=$(new_home)
c4a_root=$(new_root)
write_settings_json "$c4a_home/.claude/settings.json" "CLAUDE_DOCS_DIR=from-claude-home"
write_settings_json "$c4a_home/.gemini/config/settings.json" "CLAUDE_DOCS_DIR=from-gemini-home"
write_settings_json "$c4a_root/.claude/settings.json" "CLAUDE_DOCS_DIR=from-project-claude"

run_resolve "$c4a_home" CLAUDE_DOCS_DIR --root "$c4a_root"
if [ "$CODE" -eq 0 ] && [ "$OUT" = "from-project-claude" ]; then
  pass "04a: project-tier <root>/.claude/settings.json beats both HOME entries"
else
  fail "04a: project-tier <root>/.claude/settings.json beats both HOME entries" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# --- 4b: project tier via <root>/.agents/settings.json -----------------------
c4b_home=$(new_home)
c4b_root=$(new_root)
write_settings_json "$c4b_home/.claude/settings.json" "CLAUDE_DOCS_DIR=from-claude-home"
write_settings_json "$c4b_home/.gemini/config/settings.json" "CLAUDE_DOCS_DIR=from-gemini-home"
write_settings_json "$c4b_root/.agents/settings.json" "CLAUDE_DOCS_DIR=from-project-agents"

run_resolve "$c4b_home" CLAUDE_DOCS_DIR --root "$c4b_root"
if [ "$CODE" -eq 0 ] && [ "$OUT" = "from-project-agents" ]; then
  pass "04b: project-tier <root>/.agents/settings.json beats both HOME entries"
else
  fail "04b: project-tier <root>/.agents/settings.json beats both HOME entries" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case set 5: all four plan-named vars resolve identically from the same
# $HOME/.claude/settings.json regardless of which of two fixture --root
# working directories (both lacking project-tier files for these vars) the
# script is invoked from.
# ---------------------------------------------------------------------------
c5_home=$(new_home)
write_settings_json "$c5_home/.claude/settings.json" \
  "CLAUDE_DOCS_DIR=docs-value" \
  "CLAUDE_PROJECT_PLANS_DIR=plans-value" \
  "CLAUDE_WORKFLOWS_DIR=workflows-value" \
  "CLAUDE_BASE_BRANCH=base-branch-value"

c5_rootA=$(new_root)
c5_rootB=$(new_root)

c5_all_ok=1
for var_val in \
  "CLAUDE_DOCS_DIR=docs-value" \
  "CLAUDE_PROJECT_PLANS_DIR=plans-value" \
  "CLAUDE_WORKFLOWS_DIR=workflows-value" \
  "CLAUDE_BASE_BRANCH=base-branch-value"
do
  var="${var_val%%=*}"
  expected="${var_val#*=}"

  run_resolve "$c5_home" "$var" --root "$c5_rootA"
  a_out="$OUT"
  a_code="$CODE"

  run_resolve "$c5_home" "$var" --root "$c5_rootB"
  b_out="$OUT"
  b_code="$CODE"

  if [ "$a_code" -eq 0 ] && [ "$b_code" -eq 0 ] \
     && [ "$a_out" = "$expected" ] && [ "$b_out" = "$expected" ]; then
    pass "05: $var resolves identically ('$expected') from rootA and rootB"
  else
    fail "05: $var resolves identically ('$expected') from rootA and rootB" \
      "a_code=$a_code a_out=[$a_out] b_code=$b_code b_out=[$b_out]"
    c5_all_ok=0
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
