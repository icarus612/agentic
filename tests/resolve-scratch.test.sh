#!/usr/bin/env bash
# resolve-scratch.test.sh
#
# SYNOPSIS
#   bash tests/resolve-scratch.test.sh
#
# DESCRIPTION
#   Blind contract test for orchestrators/hooks/resolve-scratch.sh — the
#   report-scratch-dir resolver for a `ship: chat` run (contracts/l2.md §A):
#   the four-scope CLAUDE_SCRATCH_DIR chain (rung 1, via resolve-config.sh),
#   the in-repo default rooted at the MAIN checkout (rung 2), and the
#   not-a-repo cache fallback (rung 3), plus the run-id collision fix and the
#   usage-error surface of --slug / --runid / --root.
#
#   Written from contracts/l2.md §A ALONE. This suite NEVER reads
#   orchestrators/hooks/resolve-scratch.sh's source — no cat, grep, sed, head,
#   or read against it. The only interaction with that file is invoking it as
#   a black box, plus the case-00 `bash -n` sanity precondition, which runs it
#   through the parser without inspecting its logic. Every expected path is
#   computed independently, from the literal formulas §A1 quotes from
#   workflow-setup.sh (the --git-common-dir root computation, the slugifier)
#   and from git itself run against throwaway fixtures — never by reading the
#   script under test.
#
#   All fixtures are throwaway `mktemp -d` directories. The real $HOME,
#   ~/.claude, ~/.gemini, and the real ~/.cache are never read or written:
#   every invocation pins HOME (and XDG_CACHE_HOME where relevant) to a
#   fixture and passes --root at a fixture, even in cases whose outcome does
#   not depend on the settings chain, so no case can accidentally pick up the
#   developer's real config. CLAUDE_SCRATCH_DIR and XDG_CACHE_HOME are always
#   explicitly unset or pinned before invocation, never inherited. The one
#   `git worktree add` fixture is explicitly unregistered with `git worktree
#   remove` (falling back to removing its containing repo) before the suite
#   exits, and every scratch dir is tracked and removed in a trap.
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
SCRIPT="$REPO_ROOT/orchestrators/hooks/resolve-scratch.sh"

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
# Git fixture helper -- pins author identity and disables gpgsign so a host
# with commit signing configured cannot break fixture construction.
# ---------------------------------------------------------------------------
gitc() {
  local repo="$1"
  shift
  git -C "$repo" -c user.email=t@example.invalid -c user.name=t -c commit.gpgsign=false "$@"
}

# init_git_repo <dir> -- git init -b main, one commit, so --git-common-dir
# and rev-parse both have something real to resolve.
init_git_repo() {
  local repo="$1"
  git init -q -b main "$repo"
  printf '# fixture\n' >"$repo/README.md"
  gitc "$repo" add -A
  gitc "$repo" commit -q -m "initial"
}

# git_common_root <repo> -- the A1 MAIN-checkout-root formula, run against a
# fixture repo, independent of the script under test.
git_common_root() {
  local repo="$1"
  dirname "$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)"
}

# slugify_ref <text> -- the A1 slugifier formula, quoted verbatim in the
# contract, run independently to compute expected slugs.
slugify_ref() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}

# write_scratch_settings <root-dir> <value> -- writes <root>/.claude/settings.json
# with env.CLAUDE_SCRATCH_DIR = <value>.
write_scratch_settings() {
  local root="$1" value="$2"
  mkdir -p "$root/.claude"
  {
    printf '{\n  "env": {\n    "CLAUDE_SCRATCH_DIR": "%s"\n  }\n}\n' "$value"
  } >"$root/.claude/settings.json"
}

# ---------------------------------------------------------------------------
# Invocation helper.
#   run_scratch <cwd> <home> <root> <xdg-cache-home-or-empty-to-unset> -- <args...>
# --root is always passed explicitly (a fixture, never the real repo), HOME is
# always pinned, CLAUDE_SCRATCH_DIR is always explicitly unset first so a
# leaked value from this test-runner's own environment can never leak in, and
# XDG_CACHE_HOME is either pinned to the given fixture value or explicitly
# unset. stdin is /dev/null; stdout and stderr are captured separately.
# ---------------------------------------------------------------------------
OUT=""
ERR=""
CODE=0
run_scratch() {
  local dir="$1" home="$2" root="$3" xdg="$4"
  shift 4
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  if [ -n "$xdg" ]; then
    ( cd "$dir" && unset CLAUDE_SCRATCH_DIR && XDG_CACHE_HOME="$xdg" HOME="$home" exec "$SCRIPT" --root "$root" "$@" ) \
      </dev/null >"$out_f" 2>"$err_f"
  else
    ( cd "$dir" && unset CLAUDE_SCRATCH_DIR XDG_CACHE_HOME && HOME="$home" exec "$SCRIPT" --root "$root" "$@" ) \
      </dev/null >"$out_f" 2>"$err_f"
  fi
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# ---------------------------------------------------------------------------
# Assertion primitives
# ---------------------------------------------------------------------------

# line <exact line>  -- exact whole-line match on stdout (SCRATCHDIR:/RUNID:
# are asserted as whole lines per contract B4, never substrings).
line() { printf '%s\n' "$OUT" | grep -qxF -- "$1"; }

# err_sub <substring>  -- fixed-string match on stderr
err_sub() { printf '%s\n' "$ERR" | grep -qF -- "$1"; }

# field <text> <prefix-ending-in-": "> -- first line starting with the
# prefix, prefix stripped. Used to extract SCRATCHDIR:/RUNID: values.
field() {
  printf '%s\n' "$1" | grep -m1 -- "^${2}" | sed "s/^${2}//"
}

ctx() { printf 'code=%s out=[%s] err=[%s]' "$CODE" "$OUT" "$ERR"; }

# ---------------------------------------------------------------------------
# Case 00: bash -n sanity precondition (the script must at least parse).
# This is also this suite's coverage of A6 criterion 9 verbatim.
# ---------------------------------------------------------------------------
if bash -n "$SCRIPT" 2>/tmp/resolve-scratch-syntax-err.$$; then
  pass "00: bash -n resolve-scratch.sh exits 0 (A6.9)"
else
  syntax_err=$(cat /tmp/resolve-scratch-syntax-err.$$ 2>/dev/null)
  fail "00: bash -n resolve-scratch.sh exits 0 (A6.9)" "syntax error: $syntax_err"
  rm -f /tmp/resolve-scratch-syntax-err.$$
  echo "sanity failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
rm -f /tmp/resolve-scratch-syntax-err.$$

# A neutral, empty settings root: a fixture with NO .claude/settings.json at
# all, used wherever a case must prove rung 1 does not resolve.
blank_root() { new_scratch; }

# ===========================================================================
# RUNG 1 -- the configured var (A6.1, plus the A3 normalization rules)
# ===========================================================================

# --- Case 01a: absolute configured value ------------------------------------
cwd01a=$(new_scratch)
home01a=$(new_scratch)
root01a=$(new_scratch)
target01a=$(new_scratch)
write_scratch_settings "$root01a" "$target01a"
run_scratch "$cwd01a" "$home01a" "$root01a" "" --slug myslug --runid fx01a
sd01a="$(field "$OUT" 'SCRATCHDIR: ')"
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE"
line "SCRATCHDIR: $target01a/myslug-fx01a" || bad="$bad missing-line:[SCRATCHDIR: $target01a/myslug-fx01a]"
line "RUNID: fx01a" || bad="$bad missing-line:[RUNID: fx01a]"
err_sub "resolve-scratch: resolved via configured var" || bad="$bad missing-stderr"
if [ -z "$bad" ]; then
  pass "01a: absolute CLAUDE_SCRATCH_DIR -> SCRATCHDIR=<configured>/<slug>-<runid>, 'resolved via configured var' (A6.1)"
else
  fail "01a: absolute CLAUDE_SCRATCH_DIR -> SCRATCHDIR=<configured>/<slug>-<runid>, 'resolved via configured var' (A6.1)" "$bad; $(ctx)"
fi

# --- Case 01b: leading ~/ expands to $HOME/ ---------------------------------
cwd01b=$(new_scratch)
home01b=$(new_scratch)
root01b=$(new_scratch)
write_scratch_settings "$root01b" '~/myscratch'
run_scratch "$cwd01b" "$home01b" "$root01b" "" --slug myslug --runid fx01b
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE"
line "SCRATCHDIR: $home01b/myscratch/myslug-fx01b" || bad="$bad missing-line:[SCRATCHDIR: $home01b/myscratch/myslug-fx01b]"
err_sub "resolve-scratch: resolved via configured var" || bad="$bad missing-stderr"
if [ -z "$bad" ]; then
  pass "01b: leading ~/ in the configured value expands against \$HOME (A3 rung 1 normalization)"
else
  fail "01b: leading ~/ in the configured value expands against \$HOME (A3 rung 1 normalization)" "$bad; $(ctx)"
fi

# --- Case 01c: relative configured value inside a git repo resolves against
#     the rung-2 repo root -----------------------------------------------
repo01c=$(new_scratch)
init_git_repo "$repo01c"
home01c=$(new_scratch)
write_scratch_settings "$repo01c" 'relscratch'
mainroot01c="$(git_common_root "$repo01c")"
run_scratch "$repo01c" "$home01c" "$repo01c" "" --slug myslug --runid fx01c
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE"
line "SCRATCHDIR: $mainroot01c/relscratch/myslug-fx01c" || bad="$bad missing-line:[SCRATCHDIR: $mainroot01c/relscratch/myslug-fx01c]"
err_sub "resolve-scratch: resolved via configured var" || bad="$bad missing-stderr"
if [ -z "$bad" ]; then
  pass "01c: relative configured value inside a git repo resolves against the repo root (A3 rung 1 normalization)"
else
  fail "01c: relative configured value inside a git repo resolves against the repo root (A3 rung 1 normalization)" "$bad; $(ctx)"
fi

# --- Case 01d: relative configured value NOT inside a git repo resolves
#     against $PWD --------------------------------------------------------
cwd01d=$(new_scratch)
home01d=$(new_scratch)
root01d=$(new_scratch)
write_scratch_settings "$root01d" 'relscratch2'
run_scratch "$cwd01d" "$home01d" "$root01d" "" --slug myslug --runid fx01d
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE"
line "SCRATCHDIR: $cwd01d/relscratch2/myslug-fx01d" || bad="$bad missing-line:[SCRATCHDIR: $cwd01d/relscratch2/myslug-fx01d]"
err_sub "resolve-scratch: resolved via configured var" || bad="$bad missing-stderr"
if [ -z "$bad" ]; then
  pass "01d: relative configured value outside a git repo resolves against \$PWD (A3 rung 1 normalization)"
else
  fail "01d: relative configured value outside a git repo resolves against \$PWD (A3 rung 1 normalization)" "$bad; $(ctx)"
fi

# ===========================================================================
# RUNG 2 -- inside a git repo, no configured var (A6.2)
# ===========================================================================

# --- Case 02: no var resolvable, cwd inside a git repo ----------------------
# The settings root passed via --root is deliberately a DIFFERENT, empty
# fixture from the git repo itself, to demonstrate --root affects rung 1 only
# and never changes which repo rung 2 finds (A2).
repo02=$(new_scratch)
init_git_repo "$repo02"
home02=$(new_scratch)
root02=$(blank_root)
mainroot02="$(git_common_root "$repo02")"
run_scratch "$repo02" "$home02" "$root02" "" --slug myslug --runid fx02
sd02="$(field "$OUT" 'SCRATCHDIR: ')"
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE"
line "SCRATCHDIR: $mainroot02/.artifacts/reports/myslug-fx02" || bad="$bad missing-line:[SCRATCHDIR: $mainroot02/.artifacts/reports/myslug-fx02]"
err_sub "resolve-scratch: resolved via git repo root" || bad="$bad missing-stderr"
if [ -z "$bad" ]; then
  pass "02: no configured var, cwd inside a git repo -> <main-checkout-root>/.artifacts/reports/<slug>-<runid>, 'resolved via git repo root' (A6.2)"
else
  fail "02: no configured var, cwd inside a git repo -> <main-checkout-root>/.artifacts/reports/<slug>-<runid>, 'resolved via git repo root' (A6.2)" "$bad; $(ctx)"
fi

# ===========================================================================
# RUNG 2 from inside a linked worktree still yields the MAIN root (A6.3)
# ===========================================================================

# --- Case 03: linked worktree ------------------------------------------------
repo03=$(new_scratch)
init_git_repo "$repo03"
wt03_parent=$(new_scratch)
wt03_path="$wt03_parent/wt"
home03=$(new_scratch)
root03=$(blank_root)
mainroot03="$(git_common_root "$repo03")"

if gitc "$repo03" worktree add -q -b wt03-branch "$wt03_path" >/dev/null 2>&1; then
  run_scratch "$wt03_path" "$home03" "$root03" "" --slug myslug --runid fx03
  bad=""
  [ "$CODE" -eq 0 ] || bad="exit=$CODE"
  line "SCRATCHDIR: $mainroot03/.artifacts/reports/myslug-fx03" || bad="$bad missing-line:[SCRATCHDIR: $mainroot03/.artifacts/reports/myslug-fx03]"
  err_sub "resolve-scratch: resolved via git repo root" || bad="$bad missing-stderr"
  case "$mainroot03" in
    "$wt03_path"|"$wt03_path"/*) bad="$bad fixture-broken:mainroot-equals-worktree" ;;
  esac
  sd03="$(field "$OUT" 'SCRATCHDIR: ')"
  case "$sd03" in
    "$wt03_path"*) bad="$bad resolved-under-worktree-not-main:[$sd03]" ;;
  esac
  if [ -z "$bad" ]; then
    pass "03: from inside a linked worktree, rung 2 still yields the MAIN checkout's root, not the worktree's (A6.3)"
  else
    fail "03: from inside a linked worktree, rung 2 still yields the MAIN checkout's root, not the worktree's (A6.3)" "$bad; $(ctx)"
  fi
  # Unregister the worktree immediately -- do not leave it registered.
  gitc "$repo03" worktree remove --force "$wt03_path" >/dev/null 2>&1 || rm -rf "$wt03_path"
else
  fail "03: from inside a linked worktree, rung 2 still yields the MAIN checkout's root, not the worktree's (A6.3)" \
    "could not construct the git-worktree-add fixture"
fi

# ===========================================================================
# RUNG 3 -- not a git repo (A6.4)
# ===========================================================================

# --- Case 04a: XDG_CACHE_HOME unset -> falls back to $HOME/.cache ----------
cwd04a=$(new_scratch)
home04a=$(new_scratch)
root04a=$(blank_root)
run_scratch "$cwd04a" "$home04a" "$root04a" "" --slug myslug --runid fx04a
sd04a="$(field "$OUT" 'SCRATCHDIR: ')"
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE"
line "SCRATCHDIR: $home04a/.cache/dae/reports/myslug-fx04a" || bad="$bad missing-line:[SCRATCHDIR: $home04a/.cache/dae/reports/myslug-fx04a]"
err_sub "resolve-scratch: resolved via cache fallback" || bad="$bad missing-stderr"
if [ -z "$bad" ]; then
  pass "04a: not a git repo, XDG_CACHE_HOME unset -> \$HOME/.cache/dae/reports/<slug>-<runid>, exit 0, 'resolved via cache fallback' (A6.4)"
else
  fail "04a: not a git repo, XDG_CACHE_HOME unset -> \$HOME/.cache/dae/reports/<slug>-<runid>, exit 0, 'resolved via cache fallback' (A6.4)" "$bad; $(ctx)"
fi

# --- Case 04b: XDG_CACHE_HOME set and absolute is honored -------------------
cwd04b=$(new_scratch)
home04b=$(new_scratch)
root04b=$(blank_root)
xdg04b=$(new_scratch)
run_scratch "$cwd04b" "$home04b" "$root04b" "$xdg04b" --slug myslug --runid fx04b
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE"
line "SCRATCHDIR: $xdg04b/dae/reports/myslug-fx04b" || bad="$bad missing-line:[SCRATCHDIR: $xdg04b/dae/reports/myslug-fx04b]"
err_sub "resolve-scratch: resolved via cache fallback" || bad="$bad missing-stderr"
if [ -z "$bad" ]; then
  pass "04b: not a git repo, XDG_CACHE_HOME set and absolute -> honored verbatim (A6.4 / A3 rung 3)"
else
  fail "04b: not a git repo, XDG_CACHE_HOME set and absolute -> honored verbatim (A6.4 / A3 rung 3)" "$bad; $(ctx)"
fi

# --- Case 04c: XDG_CACHE_HOME set but NOT absolute is ignored ---------------
cwd04c=$(new_scratch)
home04c=$(new_scratch)
root04c=$(blank_root)
run_scratch "$cwd04c" "$home04c" "$root04c" "relative/xdg/path" --slug myslug --runid fx04c
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE"
line "SCRATCHDIR: $home04c/.cache/dae/reports/myslug-fx04c" || bad="$bad missing-line:[SCRATCHDIR: $home04c/.cache/dae/reports/myslug-fx04c]"
err_sub "resolve-scratch: resolved via cache fallback" || bad="$bad missing-stderr"
if [ -z "$bad" ]; then
  pass "04c: not a git repo, XDG_CACHE_HOME set but relative -> ignored, falls back to \$HOME/.cache (A3 rung 3: 'honored only when set and absolute')"
else
  fail "04c: not a git repo, XDG_CACHE_HOME set but relative -> ignored, falls back to \$HOME/.cache (A3 rung 3: 'honored only when set and absolute')" "$bad; $(ctx)"
fi

# ===========================================================================
# The directory exists on disk after the call, in every rung (A6.5)
# ===========================================================================

# --- Case 05: existence check reusing the paths resolved above -------------
bad=""
for pair in "01a:$sd01a" "02:$sd02" "03:$sd03" "04a:$sd04a"; do
  tag="${pair%%:*}"
  p="${pair#*:}"
  [ -n "$p" ] || { bad="$bad empty-path-for:[$tag]"; continue; }
  [ -d "$p" ] || bad="$bad not-a-directory:[$tag:$p]"
done
if [ -z "$bad" ]; then
  pass "05: the resolved directory exists on disk after the call, in every rung (A6.5)"
else
  fail "05: the resolved directory exists on disk after the call, in every rung (A6.5)" "$bad"
fi

# ===========================================================================
# Two calls with the same --slug and no --runid produce different paths (A6.6)
# ===========================================================================

# --- Case 06 -----------------------------------------------------------------
cwd06=$(new_scratch)
home06=$(new_scratch)
root06=$(blank_root)
run_scratch "$cwd06" "$home06" "$root06" "" --slug samesamesame
out06a="$OUT"; code06a="$CODE"
sd06a="$(field "$out06a" 'SCRATCHDIR: ')"
run_scratch "$cwd06" "$home06" "$root06" "" --slug samesamesame
out06b="$OUT"; code06b="$CODE"
sd06b="$(field "$out06b" 'SCRATCHDIR: ')"
bad=""
[ "$code06a" -eq 0 ] || bad="$bad exit1=$code06a"
[ "$code06b" -eq 0 ] || bad="$bad exit2=$code06b"
[ -n "$sd06a" ] || bad="$bad empty-first-scratchdir"
[ -n "$sd06b" ] || bad="$bad empty-second-scratchdir"
[ "$sd06a" != "$sd06b" ] || bad="$bad identical-paths:[$sd06a]"
if [ -z "$bad" ]; then
  pass "06: two calls with the same --slug and no --runid produce different SCRATCHDIR paths (A6.6)"
else
  fail "06: two calls with the same --slug and no --runid produce different SCRATCHDIR paths (A6.6)" \
    "$bad; a=[$out06a] b=[$out06b]"
fi

# ===========================================================================
# --slug usage errors (A6.7)
# ===========================================================================

# --- Case 07a: --slug missing entirely --------------------------------------
cwd07=$(new_scratch)
home07=$(new_scratch)
root07=$(blank_root)
run_scratch "$cwd07" "$home07" "$root07" "" --runid fx07a
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
[ -n "$ERR" ] || bad="$bad empty-stderr"
err_sub '--slug' || bad="$bad missing-stderr:[--slug]"
if [ -z "$bad" ]; then
  pass "07a: --slug entirely missing -> exit 1, plain-language usage error mentioning --slug (A6.7)"
else
  fail "07a: --slug entirely missing -> exit 1, plain-language usage error mentioning --slug (A6.7)" "$bad; $(ctx)"
fi

# --- Case 07b: --slug present but its value is missing ---------------------
run_scratch "$cwd07" "$home07" "$root07" "" --slug
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
[ -n "$ERR" ] || bad="$bad empty-stderr"
err_sub '--slug' || bad="$bad missing-stderr:[--slug]"
if [ -z "$bad" ]; then
  pass "07b: --slug given with no following value -> exit 1, usage error mentioning --slug (A2 / A6.7)"
else
  fail "07b: --slug given with no following value -> exit 1, usage error mentioning --slug (A2 / A6.7)" "$bad; $(ctx)"
fi

# --- Case 07c: --slug '///' slugifies to the empty string -------------------
run_scratch "$cwd07" "$home07" "$root07" "" --slug '///'
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
[ -n "$ERR" ] || bad="$bad empty-stderr"
if [ -z "$bad" ]; then
  pass "07c: --slug '///' (slugifies to empty) -> exit 1 (A6.7)"
else
  fail "07c: --slug '///' (slugifies to empty) -> exit 1 (A6.7)" "$bad; $(ctx)"
fi

# --- Case 07d: --slug '' (empty string value) also slugifies to empty ------
run_scratch "$cwd07" "$home07" "$root07" "" --slug ''
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
[ -n "$ERR" ] || bad="$bad empty-stderr"
if [ -z "$bad" ]; then
  pass "07d: --slug '' (empty string value) -> exit 1 (A2 / A6.7)"
else
  fail "07d: --slug '' (empty string value) -> exit 1 (A2 / A6.7)" "$bad; $(ctx)"
fi

# ===========================================================================
# No jq dependency (A6.8) -- shim proof, never reads the source
# ===========================================================================

# --- Case 08 -------------------------------------------------------------
shimdir=$(new_scratch)
marker="$shimdir/.jq-was-called"
cat >"$shimdir/jq" <<SHIM
#!/usr/bin/env bash
touch "$marker"
exit 1
SHIM
chmod +x "$shimdir/jq"

cwd08=$(new_scratch)
home08=$(new_scratch)
root08=$(blank_root)
out_f=$(mktemp); err_f=$(mktemp)
( cd "$cwd08" && unset CLAUDE_SCRATCH_DIR XDG_CACHE_HOME \
    && PATH="$shimdir:$PATH" HOME="$home08" exec "$SCRIPT" --root "$root08" --slug myslug --runid fx08 ) \
  </dev/null >"$out_f" 2>"$err_f"
CODE=$?
OUT=$(cat "$out_f"); ERR=$(cat "$err_f")
rm -f "$out_f" "$err_f"
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE"
line "RUNID: fx08" || bad="$bad missing-line:[RUNID: fx08]"
[ -e "$marker" ] && bad="$bad jq-was-invoked"
if [ -z "$bad" ]; then
  pass "08: a shimmed 'jq' ahead on PATH is never invoked -- the script depends on no jq (A6.8)"
else
  fail "08: a shimmed 'jq' ahead on PATH is never invoked -- the script depends on no jq (A6.8)" "$bad; $(ctx)"
fi

# ===========================================================================
# --runid usage errors (A2, supplementary to A6.7's --slug coverage)
# ===========================================================================

# --- Case 09a: --runid '' (empty value) is a usage error --------------------
cwd09=$(new_scratch)
home09=$(new_scratch)
root09=$(blank_root)
run_scratch "$cwd09" "$home09" "$root09" "" --slug myslug --runid ''
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
[ -n "$ERR" ] || bad="$bad empty-stderr"
err_sub '--runid' || bad="$bad missing-stderr:[--runid]"
if [ -z "$bad" ]; then
  pass "09a: --runid '' (empty value) -> exit 1, usage error mentioning --runid (A2)"
else
  fail "09a: --runid '' (empty value) -> exit 1, usage error mentioning --runid (A2)" "$bad; $(ctx)"
fi

# --- Case 09b: --runid containing a '/' is a usage error --------------------
run_scratch "$cwd09" "$home09" "$root09" "" --slug myslug --runid 'a/b'
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
[ -n "$ERR" ] || bad="$bad empty-stderr"
err_sub '--runid' || bad="$bad missing-stderr:[--runid]"
if [ -z "$bad" ]; then
  pass "09b: --runid containing a '/' -> exit 1, usage error mentioning --runid (A2: 'one path segment, never a path')"
else
  fail "09b: --runid containing a '/' -> exit 1, usage error mentioning --runid (A2: 'one path segment, never a path')" "$bad; $(ctx)"
fi

# ===========================================================================
# Unknown flag / bare positional argument (A2, supplementary)
# ===========================================================================

# --- Case 10a: an unrecognized flag is a usage error -------------------------
cwd10=$(new_scratch)
home10=$(new_scratch)
root10=$(blank_root)
run_scratch "$cwd10" "$home10" "$root10" "" --slug myslug --bogus somevalue
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
[ -n "$ERR" ] || bad="$bad empty-stderr"
if [ -z "$bad" ]; then
  pass "10a: an unrecognized flag -> exit 1 (A2: 'any other flag ... is a usage error')"
else
  fail "10a: an unrecognized flag -> exit 1 (A2: 'any other flag ... is a usage error')" "$bad; $(ctx)"
fi

# --- Case 10b: a bare positional argument is a usage error -------------------
run_scratch "$cwd10" "$home10" "$root10" "" --slug myslug extraneous
bad=""
[ "$CODE" -eq 1 ] || bad="exit=$CODE(want 1)"
[ -n "$ERR" ] || bad="$bad empty-stderr"
if [ -z "$bad" ]; then
  pass "10b: a bare positional argument -> exit 1 (A2: '...or a bare positional argument, is a usage error')"
else
  fail "10b: a bare positional argument -> exit 1 (A2: '...or a bare positional argument, is a usage error')" "$bad; $(ctx)"
fi

# ===========================================================================
# Stdout purity in the success path (A4: "Nothing else may be printed on
# stdout in the success path.")
# ===========================================================================

# --- Case 11 -----------------------------------------------------------------
cwd11=$(new_scratch)
home11=$(new_scratch)
root11=$(blank_root)
run_scratch "$cwd11" "$home11" "$root11" "" --slug myslug --runid fx11
expected11="SCRATCHDIR: $home11/.cache/dae/reports/myslug-fx11
RUNID: fx11"
if [ "$CODE" -eq 0 ] && [ "$OUT" = "$expected11" ]; then
  pass "11: success-path stdout is exactly SCRATCHDIR: then RUNID:, in order, nothing else (A4)"
else
  fail "11: success-path stdout is exactly SCRATCHDIR: then RUNID:, in order, nothing else (A4)" \
    "code=$CODE out=[$OUT] want=[$expected11]"
fi

# ===========================================================================
# Slugification matches the A1 formula exactly (A1/A2)
# ===========================================================================

# --- Case 12 -----------------------------------------------------------------
cwd12=$(new_scratch)
home12=$(new_scratch)
root12=$(blank_root)
raw12='My Cool Idea!'
expected_slug12="$(slugify_ref "$raw12")"
run_scratch "$cwd12" "$home12" "$root12" "" --slug "$raw12" --runid fx12
bad=""
[ "$CODE" -eq 0 ] || bad="exit=$CODE"
line "SCRATCHDIR: $home12/.cache/dae/reports/$expected_slug12-fx12" \
  || bad="$bad missing-line:[SCRATCHDIR: $home12/.cache/dae/reports/$expected_slug12-fx12]"
if [ -z "$bad" ]; then
  pass "12: --slug '$raw12' slugifies to '$expected_slug12', matching the A1 formula exactly"
else
  fail "12: --slug '$raw12' slugifies to '$expected_slug12', matching the A1 formula exactly" "$bad; $(ctx)"
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
