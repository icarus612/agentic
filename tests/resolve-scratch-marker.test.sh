#!/usr/bin/env bash
# resolve-scratch-marker.test.sh
#
# SYNOPSIS
#   bash tests/resolve-scratch-marker.test.sh
#
# DESCRIPTION
#   Blind contract test for the `ship: chat` marker behavior of
#   agent-agnostic/hooks/resolve-scratch.sh (contracts/l1.md, Packet 5, 5.1):
#   when resolve-scratch.sh resolves an in-repo scratch dir (rung 1 or rung
#   2 -- i.e. whenever a repo_root was actually resolved), it must ALSO seed
#   <repo_root>/.artifacts/progress-log.md (idempotent, never overwritten)
#   so a chat run's writes are structurally confined by scope-writes.sh's
#   absent-role fallback -- but it must NEVER write
#   <repo_root>/.artifacts/dae-role (per Packet 5's documented rationale:
#   marking role=orchestrator would wrongly restrict the chat run to
#   *-review.md/sync-report.md only, which would block its own scratch-dir
#   writes; leaving the role file absent lands on the permissive
#   artifacts_root/plans_root/docs_root fallback, which correctly covers the
#   chat run's own .artifacts/reports/<slug>-<runid>/ subtree).
#
#   Written from contracts/l1.md's Packet 5 "### Tests" list ALONE. This
#   suite NEVER reads agent-agnostic/hooks/resolve-scratch.sh's source -- no
#   cat, grep, sed, head, or read against it. The only interactions with
#   that file are: invoking it as a black box, and the case-00 `bash -n`
#   sanity precondition, which runs it through the parser without inspecting
#   its logic. The one exception to "never read implementation source" is
#   case 06, which shells out to the ALREADY-LANDED, DIFFERENT sibling hook
#   agent-agnostic/hooks/scope-writes.sh as a black-box tool (per the
#   dispatch instructions) -- its source is likewise never read here.
#
#   All fixtures are throwaway `mktemp -d` directories, tracked and removed
#   in a trap. HOME is always pinned to a fixture; CLAUDE_SCRATCH_DIR and
#   XDG_CACHE_HOME are always explicitly unset before invocation so no case
#   can accidentally pick up the developer's real config. --root is always
#   passed explicitly, pointed at an empty settings fixture (never the real
#   repo), so rung 1 (the configured var) never resolves and every case
#   below genuinely exercises rung 2 (in a git repo) or rung 3 (not a git
#   repo), per the shape the contract's own cases describe.
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
SCRIPT="$REPO_ROOT/agent-agnostic/hooks/resolve-scratch.sh"
SCOPE_SCRIPT="$REPO_ROOT/agent-agnostic/hooks/scope-writes.sh"

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

# blank_root -- an empty fixture with no .claude/settings.json, used
# wherever a case must prove rung 1 (the configured var) does not fire.
blank_root() { new_scratch; }

# ---------------------------------------------------------------------------
# Git fixture helper -- pins author identity and disables gpgsign so a host
# with commit signing configured cannot break fixture construction. Matches
# tests/resolve-scratch.test.sh's own convention exactly.
# ---------------------------------------------------------------------------
gitc() {
  local repo="$1"
  shift
  git -C "$repo" -c user.email=t@example.invalid -c user.name=t -c commit.gpgsign=false "$@"
}

init_git_repo() {
  local repo="$1"
  git init -q -b main "$repo"
  printf '# fixture\n' >"$repo/README.md"
  gitc "$repo" add -A
  gitc "$repo" commit -q -m "initial"
}

# ---------------------------------------------------------------------------
# Invocation helper for resolve-scratch.sh.
#   run_rs <cwd> <home> <root> -- <args...>
# --root is always passed explicitly (a fixture, never the real repo), HOME
# is always pinned, CLAUDE_SCRATCH_DIR/XDG_CACHE_HOME are always explicitly
# unset first so nothing leaks in from this test-runner's own environment.
# ---------------------------------------------------------------------------
OUT=""
ERR=""
CODE=0
run_rs() {
  local dir="$1" home="$2" root="$3"
  shift 3
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  ( cd "$dir" && unset CLAUDE_SCRATCH_DIR XDG_CACHE_HOME && HOME="$home" exec "$SCRIPT" --root "$root" "$@" ) \
    </dev/null >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# field <text> <prefix-ending-in-": "> -- first line starting with the
# prefix, prefix stripped. Used to extract the SCRATCHDIR: value.
field() {
  printf '%s\n' "$1" | grep -m1 -- "^${2}" | sed "s/^${2}//"
}

ctx() { printf 'code=%s out=[%s] err=[%s]' "$CODE" "$OUT" "$ERR"; }

# ---------------------------------------------------------------------------
# scope-writes.sh invocation helper (case 06 only) -- the real, already-
# landed sibling hook, used strictly as a black-box tool per the dispatch
# instructions. Same JSON shape tests/scope-writes.test.sh uses.
# ---------------------------------------------------------------------------
SCOPE_OUT=""
SCOPE_ERR=""
SCOPE_CODE=0
run_scope() {
  local stdin_content="$1"
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  printf '%s' "$stdin_content" | "$SCOPE_SCRIPT" >"$out_f" 2>"$err_f"
  SCOPE_CODE=$?
  SCOPE_OUT=$(cat "$out_f")
  SCOPE_ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# ===========================================================================
# Case 00: bash -n sanity precondition (contract Packet 5 test item 1) --
# must run first; nothing else can be trusted if the script does not parse.
# ===========================================================================
SYN_ERR_FILE=$(mktemp)
if bash -n "$SCRIPT" 2>"$SYN_ERR_FILE"; then
  pass "00: bash -n resolve-scratch.sh exits 0"
else
  fail "00: bash -n resolve-scratch.sh exits 0" "syntax error: $(cat "$SYN_ERR_FILE")"
  rm -f "$SYN_ERR_FILE"
  echo "sanity failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
rm -f "$SYN_ERR_FILE"

# ===========================================================================
# Case 01 (contract test item 2): fresh git repo, single call ->
# .artifacts/progress-log.md exists, .artifacts/dae-role does NOT.
# ===========================================================================
repo01=$(new_scratch)
init_git_repo "$repo01"
home01=$(new_scratch)
root01=$(blank_root)
run_rs "$repo01" "$home01" "$root01" --slug test-run --runid run01
bad=""
[ "$CODE" -eq 0 ] || bad="$bad exit=$CODE"
[ -f "$repo01/.artifacts/progress-log.md" ] || bad="$bad progress-log-missing"
[ -s "$repo01/.artifacts/progress-log.md" ] || bad="$bad progress-log-empty"
[ ! -e "$repo01/.artifacts/dae-role" ] || bad="$bad dae-role-unexpectedly-created"
if [ -z "$bad" ]; then
  pass "01: fresh git repo, --slug test-run -> .artifacts/progress-log.md exists (non-empty), .artifacts/dae-role absent (5.1)"
else
  fail "01: fresh git repo, --slug test-run -> .artifacts/progress-log.md exists (non-empty), .artifacts/dae-role absent (5.1)" "$bad; $(ctx)"
fi

# ===========================================================================
# Case 02 (contract test item 3): second call, different --runid, same
# repo -> the first call's progress-log.md content is byte-identical
# (idempotent -- no clobbering across concurrent/sequential chat runs).
# ===========================================================================
repo02=$(new_scratch)
init_git_repo "$repo02"
home02=$(new_scratch)
root02=$(blank_root)
run_rs "$repo02" "$home02" "$root02" --slug test-run --runid run02a
bad=""
[ "$CODE" -eq 0 ] || bad="$bad first-call-exit=$CODE"
[ -f "$repo02/.artifacts/progress-log.md" ] || bad="$bad first-call-missing-log"
content_before=$(cat "$repo02/.artifacts/progress-log.md" 2>/dev/null)
run_rs "$repo02" "$home02" "$root02" --slug test-run --runid run02b
[ "$CODE" -eq 0 ] || bad="$bad second-call-exit=$CODE"
content_after=$(cat "$repo02/.artifacts/progress-log.md" 2>/dev/null)
[ "$content_before" = "$content_after" ] || bad="$bad content-changed:before=[$content_before]after=[$content_after]"
[ ! -e "$repo02/.artifacts/dae-role" ] || bad="$bad dae-role-unexpectedly-created"
if [ -z "$bad" ]; then
  pass "02: second call with a different --runid, same repo -> progress-log.md content unchanged, idempotent (5.1)"
else
  fail "02: second call with a different --runid, same repo -> progress-log.md content unchanged, idempotent (5.1)" "$bad; $(ctx)"
fi

# ===========================================================================
# Case 03 (contract test item 4): positive control -- custom content seeded
# into progress-log.md BEFORE calling resolve-scratch.sh survives untouched.
# This is the genuine "only if absent" proof: unlike case 02 (which shows
# the script does not clobber its OWN prior output), this shows it does not
# clobber content it never wrote at all -- e.g. a repo root that happens to
# already be a real dae parent worktree's real progress log.
# ===========================================================================
repo03=$(new_scratch)
init_git_repo "$repo03"
home03=$(new_scratch)
root03=$(blank_root)
mkdir -p "$repo03/.artifacts"
custom_content="# Pre-existing real dae parent worktree log
- Branch: \`bug/some-other-run\`
CUSTOM-MARKER-$$"
printf '%s\n' "$custom_content" >"$repo03/.artifacts/progress-log.md"
run_rs "$repo03" "$home03" "$root03" --slug test-run --runid run03
bad=""
[ "$CODE" -eq 0 ] || bad="$bad exit=$CODE"
content_after03=$(cat "$repo03/.artifacts/progress-log.md" 2>/dev/null)
expected03=$(printf '%s\n' "$custom_content")
[ "$content_after03" = "$expected03" ] || bad="$bad content-clobbered:expected=[$expected03]got=[$content_after03]"
[ ! -e "$repo03/.artifacts/dae-role" ] || bad="$bad dae-role-unexpectedly-created"
if [ -z "$bad" ]; then
  pass "03: positive control -- pre-seeded custom progress-log.md content survives the call untouched (5.1)"
else
  fail "03: positive control -- pre-seeded custom progress-log.md content survives the call untouched (5.1)" "$bad; $(ctx)"
fi

# ===========================================================================
# Case 04 (contract test item 5): outside any git repo, HOME pinned to an
# empty scratch dir (so the rung-3 cache-dir fallback is itself a scratch
# path) -> no .artifacts marker is created anywhere (no product tree, no
# marker). Positive control: case 01 above (a genuine in-repo call) DOES
# create the marker, proving the mechanism itself works and this is not a
# vacuous "nothing happens because the script is broken" result.
# ===========================================================================
cwd04=$(new_scratch)
home04=$(new_scratch)
root04=$(blank_root)
run_rs "$cwd04" "$home04" "$root04" --slug test-run --runid run04
bad=""
[ "$CODE" -eq 0 ] || bad="$bad exit=$CODE"
sd04="$(field "$OUT" 'SCRATCHDIR: ')"
[ -n "$sd04" ] || bad="$bad empty-scratchdir-output"
[ -d "$sd04" ] || bad="$bad scratchdir-not-created:[$sd04]"
[ ! -d "$cwd04/.artifacts" ] || bad="$bad artifacts-under-cwd"
find_out04=$(find "$home04" -type d -name '.artifacts' 2>/dev/null)
[ -z "$find_out04" ] || bad="$bad artifacts-under-home:[$find_out04]"
# Positive control cross-check: case 01's in-repo fixture DID get a marker.
[ -f "$repo01/.artifacts/progress-log.md" ] || bad="$bad positive-control-broken:case01-marker-missing"
if [ -z "$bad" ]; then
  pass "04: outside any git repo -> no .artifacts marker created anywhere (rung 3), cf. case 01's positive control (5.1)"
else
  fail "04: outside any git repo -> no .artifacts marker created anywhere (rung 3), cf. case 01's positive control (5.1)" "$bad; $(ctx)"
fi

# ===========================================================================
# Case 05 (contract test item 6): end-to-end regression guard -- after
# resolve-scratch.sh has marked a repo (progress-log.md present, dae-role
# absent), feed the REAL scope-writes.sh a Write payload targeting the
# scratch report path -> exit 0 (allowed via the absent-role artifacts_root
# fallback). Feed it a Write targeting an arbitrary product file at the
# repo root -> exit 2 (denied) -- a marked-but-roleless chat run must stay
# confined to .artifacts/plans/docs, not get a free pass for having no role.
# ===========================================================================
repo05=$(new_scratch)
init_git_repo "$repo05"
home05=$(new_scratch)
root05=$(blank_root)
run_rs "$repo05" "$home05" "$root05" --slug e2e-slug --runid run05
bad=""
[ "$CODE" -eq 0 ] || bad="$bad resolve-scratch-exit=$CODE"
sd05="$(field "$OUT" 'SCRATCHDIR: ')"
[ -n "$sd05" ] || bad="$bad empty-scratchdir-output"
[ -f "$repo05/.artifacts/progress-log.md" ] || bad="$bad marker-missing"
[ ! -e "$repo05/.artifacts/dae-role" ] || bad="$bad dae-role-unexpectedly-present"

allow_target="$sd05/report.md"
deny_target="$repo05/some-product-file.go"

allow_payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$allow_target")
run_scope "$allow_payload"
if [ "$SCOPE_CODE" -ne 0 ]; then
  bad="$bad allow-case-exit=$SCOPE_CODE(out=[$SCOPE_OUT]err=[$SCOPE_ERR])"
fi

deny_payload=$(printf '{"tool_name": "Write", "file_path": "%s"}' "$deny_target")
run_scope "$deny_payload"
if [ "$SCOPE_CODE" -ne 2 ]; then
  bad="$bad deny-case-exit=$SCOPE_CODE(out=[$SCOPE_OUT]err=[$SCOPE_ERR])"
elif ! printf '%s\n' "$SCOPE_ERR" | grep -qF -- "$deny_target"; then
  bad="$bad deny-case-stderr-missing-path:err=[$SCOPE_ERR]"
fi

if [ -z "$bad" ]; then
  pass "05: e2e -- scope-writes.sh allows the scratch report path (exit 0), denies an arbitrary product file (exit 2) after resolve-scratch.sh marks (5.1)"
else
  fail "05: e2e -- scope-writes.sh allows the scratch report path (exit 0), denies an arbitrary product file (exit 2) after resolve-scratch.sh marks (5.1)" "$bad"
fi

# ---------------------------------------------------------------------------
# Tail
# ---------------------------------------------------------------------------
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ]
