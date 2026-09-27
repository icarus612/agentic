#!/usr/bin/env bash
# resolve-config-precedence.test.sh
#
# SYNOPSIS
#   bash tests/resolve-config-precedence.test.sh
#
# DESCRIPTION
#   Blind contract test for agent-agnostic/hooks/resolve-config.sh's resolution
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
SCRIPT="$REPO_ROOT/agent-agnostic/hooks/resolve-config.sh"

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
# Case set 06: P1 criterion 1 -- `--expect` is additive: omitting it must
# leave behavior byte-identical to today. This is EXACT-EQUALITY (not a
# substring check) on the full stdout and stderr strings, for all three
# no-`--expect` outcomes named in the contract: resolution from a settings
# file, resolution from --default, and unresolvable-with-no-default. This
# is the case that must be capable of failing if default output changed by
# even one byte.
# ---------------------------------------------------------------------------

# --- 06a: settings-file resolution, exact stdout + exact stderr -------------
c6a_home=$(new_home)
c6a_root=$(new_root)
write_settings_json "$c6a_home/.claude/settings.json" "CLAUDE_DOCS_DIR=exact-value"

run_resolve "$c6a_home" CLAUDE_DOCS_DIR --root "$c6a_root"
c6a_expected_err="resolve-config: CLAUDE_DOCS_DIR resolved to 'exact-value' (source: $c6a_home/.claude/settings.json)"
if [ "$CODE" -eq 0 ] && [ "$OUT" = "exact-value" ] && [ "$ERR" = "$c6a_expected_err" ]; then
  pass "06a: no --expect, settings-file resolution -- stdout and stderr exact-equal to contract text"
else
  fail "06a: no --expect, settings-file resolution -- stdout and stderr exact-equal to contract text" \
    "code=$CODE out=[$OUT] err=[$ERR] expected_err=[$c6a_expected_err]"
fi

# --- 06b: --default resolution, exact stdout + exact stderr -----------------
c6b_home=$(new_home)
c6b_root=$(new_root)

run_resolve "$c6b_home" CLAUDE_DOCS_DIR --root "$c6b_root" --default some-default
c6b_expected_err="resolve-config: CLAUDE_DOCS_DIR resolved to 'some-default' (source: supplied default)"
if [ "$CODE" -eq 0 ] && [ "$OUT" = "some-default" ] && [ "$ERR" = "$c6b_expected_err" ]; then
  pass "06b: no --expect, --default resolution -- stdout and stderr exact-equal to contract text"
else
  fail "06b: no --expect, --default resolution -- stdout and stderr exact-equal to contract text" \
    "code=$CODE out=[$OUT] err=[$ERR] expected_err=[$c6b_expected_err]"
fi

# --- 06c: unresolvable, no default, exact stdout (empty) + exact stderr -----
c6c_home=$(new_home)
c6c_root=$(new_root)

run_resolve "$c6c_home" CLAUDE_DOCS_DIR --root "$c6c_root"
c6c_expected_err="resolve-config: cannot resolve CLAUDE_DOCS_DIR (no settings.local.json/settings.json/global settings.json value, and no usable default)"
if [ "$CODE" -eq 1 ] && [ -z "$OUT" ] && [ "$ERR" = "$c6c_expected_err" ]; then
  pass "06c: no --expect, unresolvable with no default -- exit 1, empty stdout, exact-equal stderr"
else
  fail "06c: no --expect, unresolvable with no default -- exit 1, empty stdout, exact-equal stderr" \
    "code=$CODE out=[$OUT] err=[$ERR] expected_err=[$c6c_expected_err]"
fi

# ---------------------------------------------------------------------------
# Case set 07: P1 criterion 2 -- `--expect path` accepts a plain local path,
# a colon-mid-segment path, and a single-letter (Windows-drive) prefix; none
# of these are scheme-prefixed per the contract's anchored ERE.
# ---------------------------------------------------------------------------
for c7_val in \
  "/docs" \
  "docs" \
  "/srv/x/docs" \
  "/srv/a:b/docs" \
  'C:\Users\me\docs'
do
  c7_home=$(new_home)
  c7_root=$(new_root)
  run_resolve "$c7_home" CLAUDE_DOCS_DIR --root "$c7_root" --default "$c7_val" --expect path
  if [ "$CODE" -eq 0 ] && [ "$OUT" = "$c7_val" ]; then
    pass "07: --expect path accepts '$c7_val', exit 0, value on stdout"
  else
    fail "07: --expect path accepts '$c7_val', exit 0, value on stdout" \
      "code=$CODE out=[$OUT] err=[$ERR]"
  fi
done

# ---------------------------------------------------------------------------
# Case set 08: P1 criterion 3 -- `--expect path` rejects a scheme-prefixed
# value (an Atlassian wiki URL, and a confluence: scheme): exit 1, empty
# stdout, stderr naming both the passed var and CLAUDE_DOCS_PUBLISH.
# ---------------------------------------------------------------------------
for c8_val in \
  "https://acme.atlassian.net/wiki/spaces/ENG" \
  "confluence:ENG"
do
  c8_home=$(new_home)
  c8_root=$(new_root)
  run_resolve "$c8_home" CLAUDE_DOCS_DIR --root "$c8_root" --default "$c8_val" --expect path
  if [ "$CODE" -eq 1 ] && [ -z "$OUT" ] \
     && printf '%s\n' "$ERR" | grep -qF 'must be a local path' \
     && printf '%s\n' "$ERR" | grep -qF 'CLAUDE_DOCS_PUBLISH'; then
    pass "08: --expect path rejects '$c8_val', exit 1, empty stdout, stderr names CLAUDE_DOCS_PUBLISH"
  else
    fail "08: --expect path rejects '$c8_val', exit 1, empty stdout, stderr names CLAUDE_DOCS_PUBLISH" \
      "code=$CODE out=[$OUT] err=[$ERR]"
  fi
done

# ---------------------------------------------------------------------------
# Case set 09: P1 criterion 4 -- the rejection message uses the var name the
# CALLER passed, never a hardcoded CLAUDE_DOCS_DIR.
# ---------------------------------------------------------------------------
c9_home=$(new_home)
c9_root=$(new_root)

run_resolve "$c9_home" CLAUDE_SOMETHING_ELSE --root "$c9_root" --default confluence:ENG --expect path
if [ "$CODE" -eq 1 ] \
   && printf '%s\n' "$ERR" | grep -qF 'CLAUDE_SOMETHING_ELSE' \
   && ! printf '%s\n' "$ERR" | grep -qF 'CLAUDE_DOCS_DIR'; then
  pass "09: rejection message names the passed var CLAUDE_SOMETHING_ELSE, not a hardcoded CLAUDE_DOCS_DIR"
else
  fail "09: rejection message names the passed var CLAUDE_SOMETHING_ELSE, not a hardcoded CLAUDE_DOCS_DIR" \
    "code=$CODE err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case set 10: P1 criterion 5 -- `--expect publish-target` accepts an
# Atlassian wiki URL with and without a /pages/... tail, and confluence:ENG /
# confluence:ENG/Handbook.
# ---------------------------------------------------------------------------
for c10_val in \
  "https://acme.atlassian.net/wiki/spaces/ENG" \
  "https://acme.atlassian.net/wiki/spaces/ENG/pages/12345/Home" \
  "confluence:ENG" \
  "confluence:ENG/Handbook"
do
  c10_home=$(new_home)
  c10_root=$(new_root)
  run_resolve "$c10_home" CLAUDE_DOCS_PUBLISH --root "$c10_root" --default "$c10_val" --expect publish-target
  if [ "$CODE" -eq 0 ] && [ "$OUT" = "$c10_val" ]; then
    pass "10: --expect publish-target accepts '$c10_val', exit 0, value on stdout"
  else
    fail "10: --expect publish-target accepts '$c10_val', exit 0, value on stdout" \
      "code=$CODE out=[$OUT] err=[$ERR]"
  fi
done

# ---------------------------------------------------------------------------
# Case set 11: P1 criterion 6 -- `--expect publish-target` rejects a bare
# path and an unknown scheme (confluance:ENG, a typo of confluence:ENG); the
# rejection message for the unknown scheme is DERIVED from PUBLISH_SCHEMES,
# so it must name every scheme the flag accepts ("confluence").
# ---------------------------------------------------------------------------

# --- 11a: bare path rejected -------------------------------------------------
c11a_home=$(new_home)
c11a_root=$(new_root)
run_resolve "$c11a_home" CLAUDE_DOCS_PUBLISH --root "$c11a_root" --default /docs --expect publish-target
if [ "$CODE" -eq 1 ] && [ -z "$OUT" ] \
   && printf '%s\n' "$ERR" | grep -qF 'must name a known publish target'; then
  pass "11a: --expect publish-target rejects a bare path '/docs', exit 1, empty stdout"
else
  fail "11a: --expect publish-target rejects a bare path '/docs', exit 1, empty stdout" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# --- 11b: unknown scheme rejected, message derives the known-schemes list ---
c11b_home=$(new_home)
c11b_root=$(new_root)
run_resolve "$c11b_home" CLAUDE_DOCS_PUBLISH --root "$c11b_root" --default confluance:ENG --expect publish-target
if [ "$CODE" -eq 1 ] && [ -z "$OUT" ] \
   && printf '%s\n' "$ERR" | grep -qF 'must name a known publish target' \
   && printf '%s\n' "$ERR" | grep -qF 'confluence'; then
  pass "11b: --expect publish-target rejects 'confluance:ENG', message lists known scheme 'confluence'"
else
  fail "11b: --expect publish-target rejects 'confluance:ENG', message lists known scheme 'confluence'" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case set 12: P1 criterion 7 -- `--expect` composes with --default and
# --root, and validates a value whichever rung produced it: --default, or a
# settings-file fixture.
# ---------------------------------------------------------------------------

# --- 12a: illegal value from --default is rejected ---------------------------
c12a_home=$(new_home)
c12a_root=$(new_root)
run_resolve "$c12a_home" CLAUDE_DOCS_DIR --root "$c12a_root" --default confluence:ENG --expect path
if [ "$CODE" -eq 1 ] && [ -z "$OUT" ] && printf '%s\n' "$ERR" | grep -qF 'must be a local path'; then
  pass "12a: --expect composes with --default -- an illegal default value is rejected"
else
  fail "12a: --expect composes with --default -- an illegal default value is rejected" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# --- 12b: legal value from --default resolves 0 -----------------------------
c12b_home=$(new_home)
c12b_root=$(new_root)
run_resolve "$c12b_home" CLAUDE_DOCS_DIR --root "$c12b_root" --default /docs --expect path
if [ "$CODE" -eq 0 ] && [ "$OUT" = "/docs" ]; then
  pass "12b: --expect composes with --default -- a legal default value resolves 0"
else
  fail "12b: --expect composes with --default -- a legal default value resolves 0" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# --- 12c: legal value from a settings-file fixture is validated (accepted) --
c12c_home=$(new_home)
c12c_root=$(new_root)
write_settings_json "$c12c_home/.claude/settings.json" "CLAUDE_DOCS_DIR=/srv/settings-docs"
run_resolve "$c12c_home" CLAUDE_DOCS_DIR --root "$c12c_root" --expect path
if [ "$CODE" -eq 0 ] && [ "$OUT" = "/srv/settings-docs" ]; then
  pass "12c: --expect composes with a settings-file fixture -- a legal value resolves 0"
else
  fail "12c: --expect composes with a settings-file fixture -- a legal value resolves 0" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# --- 12d: illegal value from a settings-file fixture is rejected ------------
c12d_home=$(new_home)
c12d_root=$(new_root)
write_settings_json "$c12d_home/.claude/settings.json" "CLAUDE_DOCS_DIR=confluence:ENG"
run_resolve "$c12d_home" CLAUDE_DOCS_DIR --root "$c12d_root" --expect path
if [ "$CODE" -eq 1 ] && [ -z "$OUT" ] && printf '%s\n' "$ERR" | grep -qF 'must be a local path'; then
  pass "12d: --expect composes with a settings-file fixture -- an illegal value is rejected"
else
  fail "12d: --expect composes with a settings-file fixture -- an illegal value is rejected" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case set 13: P1 criterion 8 -- an unresolvable var with --expect path and
# no default still exits 1 with the UNRESOLVABLE message (not the rejection
# message), and stdout is empty. --expect must not invent a value.
# ---------------------------------------------------------------------------
c13_home=$(new_home)
c13_root=$(new_root)
run_resolve "$c13_home" CLAUDE_DOCS_DIR --root "$c13_root" --expect path
if [ "$CODE" -eq 1 ] && [ -z "$OUT" ] \
   && printf '%s\n' "$ERR" | grep -qF 'cannot resolve' \
   && ! printf '%s\n' "$ERR" | grep -qF 'must be a local path'; then
  pass "13: --expect path, unresolvable var, no default -- exit 1, empty stdout, unresolvable message (not rejection)"
else
  fail "13: --expect path, unresolvable var, no default -- exit 1, empty stdout, unresolvable message (not rejection)" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case set 14: P1 criterion 9 -- an invalid --expect argument is a usage
# error, exit 1; --expect with no following value is also a usage error, not
# a silent accept.
# ---------------------------------------------------------------------------

# --- 14a: unknown --expect value ---------------------------------------------
c14a_home=$(new_home)
c14a_root=$(new_root)
run_resolve "$c14a_home" CLAUDE_DOCS_DIR --root "$c14a_root" --default /docs --expect bogus
if [ "$CODE" -eq 1 ] && printf '%s\n' "$ERR" | grep -qF -- '--expect'; then
  pass "14a: --expect bogus is a usage error, exit 1, stderr mentions --expect"
else
  fail "14a: --expect bogus is a usage error, exit 1, stderr mentions --expect" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# --- 14b: --expect with no following value -----------------------------------
c14b_home=$(new_home)
c14b_root=$(new_root)
run_resolve "$c14b_home" CLAUDE_DOCS_DIR --root "$c14b_root" --default /docs --expect
if [ "$CODE" -eq 1 ] && [ -z "$OUT" ]; then
  pass "14b: --expect with no following value is a usage error, not a silent accept (stdout stays empty)"
else
  fail "14b: --expect with no following value is a usage error, not a silent accept (stdout stays empty)" \
    "code=$CODE out=[$OUT] err=[$ERR]"
fi

# ---------------------------------------------------------------------------
# Case set 15: P1 criterion 10 -- no jq. We cannot grep the script's source
# for "jq" (that would be reading the implementation, forbidden for a blind
# contract test), and we chose NOT to restrict PATH down to bash-only either
# -- the script legitimately needs other external tools (grep/sed/etc. -
# unknown to us, blind) beyond jq, so stripping PATH to bash-only would risk
# a false FAIL for reasons unrelated to jq (the "fragile" case the contract
# warns about). Instead we shadow ONLY `jq` with a fake executable ahead of
# the real PATH, run a representative successful case through it, and assert
# on the fake's invocation LOG CONTENT (never on exit status alone): the log
# must stay empty, proving the script under test never shells out to jq,
# while every other tool on PATH remains the real one so nothing else in the
# script is disturbed. bash -n cleanliness (the other half of criterion 10)
# is already Case 00 and needs nothing new here.
# ---------------------------------------------------------------------------
c15_binfake=$(new_scratch)
c15_jqlog="$c15_binfake/jq.log"
{
  printf '#!/usr/bin/env bash\n'
  printf 'echo "jq called with: $*" >> %q\n' "$c15_jqlog"
  printf 'exit 1\n'
} >"$c15_binfake/jq"
chmod +x "$c15_binfake/jq"

c15_home=$(new_home)
c15_root=$(new_root)
write_settings_json "$c15_home/.claude/settings.json" "CLAUDE_DOCS_DIR=jq-check-value"

c15_old_path="$PATH"
PATH="$c15_binfake:$PATH"
run_resolve "$c15_home" CLAUDE_DOCS_DIR --root "$c15_root"
PATH="$c15_old_path"

if [ "$CODE" -eq 0 ] && [ "$OUT" = "jq-check-value" ] && [ ! -s "$c15_jqlog" ]; then
  pass "15: no jq -- a shadowed fake jq ahead of PATH is never invoked (log stays empty) during a successful resolution"
else
  fail "15: no jq -- a shadowed fake jq ahead of PATH is never invoked (log stays empty) during a successful resolution" \
    "code=$CODE out=[$OUT] err=[$ERR] jqlog=[$([ -f "$c15_jqlog" ] && cat "$c15_jqlog")]"
fi

# ---------------------------------------------------------------------------
# Fixture helpers for the --base-branch-default git heuristic (case sets 16+).
# Blind contract test for contracts/l3.md Packet 2: resolve-config.sh's
# `CLAUDE_BASE_BRANCH --base-branch-default --root <dir>` fallback must use a
# git heuristic (local branch 'main', else the short name of origin/HEAD,
# else fail) rather than a hardcoded value. Written from the contract text
# alone; never reads resolve-config.sh's source.
#
# Each helper builds a small throwaway git repo under mktemp -d (via the
# existing new_scratch, so it follows the same fixture-directory convention
# as new_home/new_root above). No real network remote is ever used --
# "origin/HEAD" fixtures are faked entirely with local refs.
# ---------------------------------------------------------------------------

# new_git_repo_with_main -- a repo with a local branch literally named
# 'main' and one reachable commit.
new_git_repo_with_main() {
  local d
  d=$(new_scratch)
  git init -q -b main "$d" >/dev/null 2>&1
  git -C "$d" -c user.email=test@example.com -c user.name=test \
    commit --allow-empty -q -m init >/dev/null 2>&1
  printf '%s' "$d"
}

# new_git_repo_no_main_origin_head <origin-branch> -- a repo whose initial
# (and only) local branch is 'trunk', NOT 'main', with
# refs/remotes/origin/HEAD symbolically pointed at
# refs/remotes/origin/<origin-branch> (both faked locally with
# update-ref/symbolic-ref -- no real remote is contacted).
new_git_repo_no_main_origin_head() {
  local origin_branch="$1" d sha
  d=$(new_scratch)
  git init -q -b trunk "$d" >/dev/null 2>&1
  git -C "$d" -c user.email=test@example.com -c user.name=test \
    commit --allow-empty -q -m init >/dev/null 2>&1
  sha=$(git -C "$d" rev-parse HEAD)
  git -C "$d" update-ref "refs/remotes/origin/$origin_branch" "$sha" >/dev/null 2>&1
  git -C "$d" symbolic-ref "refs/remotes/origin/HEAD" \
    "refs/remotes/origin/$origin_branch" >/dev/null 2>&1
  printf '%s' "$d"
}

# new_git_repo_neither -- a real git repo with a reachable commit, but no
# local 'main' branch and no origin/HEAD set at all.
new_git_repo_neither() {
  local d
  d=$(new_scratch)
  git init -q -b trunk "$d" >/dev/null 2>&1
  git -C "$d" -c user.email=test@example.com -c user.name=test \
    commit --allow-empty -q -m init >/dev/null 2>&1
  printf '%s' "$d"
}

# new_non_git_dir -- a plain empty directory, never git init'ed.
new_non_git_dir() {
  new_scratch
}

# ---------------------------------------------------------------------------
# Case set 16: contract AC1 -- local branch 'main' exists at --root ->
# resolved value is exactly 'main', exit 0. This case is itself the fixture's
# positive control per the contract's fixture-requirement section: if 'main'
# were not really created, this case fails loudly (it is still a valid repo,
# just the wrong branch, so it cannot silently degenerate into the
# not-a-repo path).
# ---------------------------------------------------------------------------
c16_home=$(new_home)
c16_root=$(new_git_repo_with_main)

if ! git -C "$c16_root" show-ref --verify --quiet refs/heads/main; then
  fail "16: fixture precondition -- local branch 'main' exists in c16_root" \
    "show-ref --verify --quiet refs/heads/main did not succeed on the freshly-built fixture"
else
  run_resolve "$c16_home" CLAUDE_BASE_BRANCH --base-branch-default --root "$c16_root"
  if [ "$CODE" -eq 0 ] && [ "$OUT" = "main" ]; then
    pass "16: --base-branch-default, local 'main' branch exists at --root -> stdout 'main', exit 0"
  else
    fail "16: --base-branch-default, local 'main' branch exists at --root -> stdout 'main', exit 0" \
      "code=$CODE out=[$OUT] err=[$ERR]"
  fi
fi

# ---------------------------------------------------------------------------
# Case set 17: contract AC2 -- no local 'main', but refs/remotes/origin/HEAD
# is a symbolic ref -> resolved value is the SHORT name of that ref
# (origin/<branch>, origin/ prefix kept), exit 0. Fixture preconditions
# (unscored) prove no local 'main' exists and that origin/HEAD really
# resolves to the expected ref before the scored case trusts the script's
# success.
# ---------------------------------------------------------------------------
c17_home=$(new_home)
c17_branch="trunk"
c17_root=$(new_git_repo_no_main_origin_head "$c17_branch")

c17_fixture_ok=1
if git -C "$c17_root" show-ref --verify --quiet refs/heads/main; then
  fail "17: fixture precondition -- no local 'main' branch in c17_root" \
    "show-ref --verify --quiet refs/heads/main unexpectedly succeeded"
  c17_fixture_ok=0
fi
c17_symref=$(git -C "$c17_root" symbolic-ref -q --short refs/remotes/origin/HEAD)
if [ "$c17_symref" != "origin/$c17_branch" ]; then
  fail "17: fixture precondition -- origin/HEAD resolves to origin/$c17_branch in c17_root" \
    "symbolic-ref -q --short refs/remotes/origin/HEAD printed [$c17_symref]"
  c17_fixture_ok=0
fi

if [ "$c17_fixture_ok" -eq 1 ]; then
  run_resolve "$c17_home" CLAUDE_BASE_BRANCH --base-branch-default --root "$c17_root"
  if [ "$CODE" -eq 0 ] && [ "$OUT" = "origin/$c17_branch" ]; then
    pass "17: --base-branch-default, no 'main' but origin/HEAD set -> stdout 'origin/$c17_branch', exit 0"
  else
    fail "17: --base-branch-default, no 'main' but origin/HEAD set -> stdout 'origin/$c17_branch', exit 0" \
      "code=$CODE out=[$OUT] err=[$ERR]"
  fi
fi

# ---------------------------------------------------------------------------
# Case set 18: contract AC3 -- neither a local 'main' branch nor origin/HEAD
# exists in a real git repo at --root -> exit 1, empty stdout, non-empty
# stderr. Fixture preconditions (unscored) prove both are really absent
# before trusting the scored failure as meaningful.
# ---------------------------------------------------------------------------
c18_home=$(new_home)
c18_root=$(new_git_repo_neither)

c18_fixture_ok=1
if git -C "$c18_root" show-ref --verify --quiet refs/heads/main; then
  fail "18: fixture precondition -- no local 'main' branch in c18_root" \
    "show-ref --verify --quiet refs/heads/main unexpectedly succeeded"
  c18_fixture_ok=0
fi
if git -C "$c18_root" symbolic-ref -q --short refs/remotes/origin/HEAD >/dev/null 2>&1; then
  fail "18: fixture precondition -- origin/HEAD is not set in c18_root" \
    "symbolic-ref -q --short refs/remotes/origin/HEAD unexpectedly succeeded"
  c18_fixture_ok=0
fi

if [ "$c18_fixture_ok" -eq 1 ]; then
  run_resolve "$c18_home" CLAUDE_BASE_BRANCH --base-branch-default --root "$c18_root"
  if [ "$CODE" -eq 1 ] && [ -z "$OUT" ] && [ -n "$ERR" ]; then
    pass "18: --base-branch-default, no 'main' and no origin/HEAD -> exit 1, empty stdout, non-empty stderr"
  else
    fail "18: --base-branch-default, no 'main' and no origin/HEAD -> exit 1, empty stdout, non-empty stderr" \
      "code=$CODE out=[$OUT] err=[$ERR]"
  fi
fi

# ---------------------------------------------------------------------------
# Case set 19: contract AC4 -- --root points at a directory that is not a
# git repository at all (plain mktemp -d, never git init'ed) -> exit 1,
# empty stdout, non-empty stderr. Fixture precondition (unscored) proves the
# directory really is outside any git repo before trusting the script's
# exit-1 as meaningful.
# ---------------------------------------------------------------------------
c19_home=$(new_home)
c19_root=$(new_non_git_dir)

if git -C "$c19_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "19: fixture precondition -- c19_root is not inside a git repository" \
    "rev-parse --is-inside-work-tree unexpectedly succeeded on a plain mktemp -d directory"
else
  run_resolve "$c19_home" CLAUDE_BASE_BRANCH --base-branch-default --root "$c19_root"
  if [ "$CODE" -eq 1 ] && [ -z "$OUT" ] && [ -n "$ERR" ]; then
    pass "19: --base-branch-default, --root is not a git repository -> exit 1, empty stdout, non-empty stderr"
  else
    fail "19: --base-branch-default, --root is not a git repository -> exit 1, empty stdout, non-empty stderr" \
      "code=$CODE out=[$OUT] err=[$ERR]"
  fi
fi

# ---------------------------------------------------------------------------
# Case set 20: contract AC5 -- an explicit CLAUDE_BASE_BRANCH value in a
# settings file still wins over the git heuristic, even in a --root repo
# where the heuristic would independently succeed and pick a DIFFERENT
# answer ('main'). Proves the override actually overrides something, not
# just that it works when the heuristic would have failed anyway.
# ---------------------------------------------------------------------------
c20_home=$(new_home)
c20_root=$(new_git_repo_with_main)
write_settings_json "$c20_home/.claude/settings.json" "CLAUDE_BASE_BRANCH=explicit-branch-value"

if ! git -C "$c20_root" show-ref --verify --quiet refs/heads/main; then
  fail "20: fixture precondition -- local branch 'main' exists in c20_root" \
    "show-ref --verify --quiet refs/heads/main did not succeed on the freshly-built fixture"
else
  run_resolve "$c20_home" CLAUDE_BASE_BRANCH --base-branch-default --root "$c20_root"
  if [ "$CODE" -eq 0 ] && [ "$OUT" = "explicit-branch-value" ]; then
    pass "20: explicit CLAUDE_BASE_BRANCH in settings wins over the git heuristic even though 'main' exists at --root"
  else
    fail "20: explicit CLAUDE_BASE_BRANCH in settings wins over the git heuristic even though 'main' exists at --root" \
      "code=$CODE out=[$OUT] err=[$ERR]"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
