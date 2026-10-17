#!/usr/bin/env bash
# Runs push-main's <!-- plan-promote --> and <!-- plan-archive --> blocks against a scratch repo with a real parent-tree-guard in force.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_MD="$REPO_ROOT/.claude/skills/push-main/SKILL.md"
HOOKS_DIR="$REPO_ROOT/agent-agnostic/hooks"
GUARD="$HOOKS_DIR/parent-tree-guard.sh"
PROMOTE_MARKER='<!-- plan-promote -->'
ARCHIVE_MARKER='<!-- plan-archive -->'
SLUG="ship-it-01-02-26"

TOTAL_PASS=0
TOTAL_FAIL=0
TMPS=()

cleanup() {
  local p
  for p in "${TMPS[@]:-}"; do
    [ -n "$p" ] && [ -e "$p" ] && rm -rf "$p"
  done
}
trap cleanup EXIT

pass() { echo "PASS: $1"; TOTAL_PASS=$((TOTAL_PASS + 1)); }
fail() { echo "FAIL: $1 ($2)"; TOTAL_FAIL=$((TOTAL_FAIL + 1)); }

marker_count() { grep -cxF "$1" "$SKILL_MD" 2>/dev/null || true; }
marker_line() { grep -nxF "$1" "$SKILL_MD" 2>/dev/null | head -1 | cut -d: -f1; }
fence_after() { local n; n=$(marker_line "$1"); [ -n "$n" ] && sed -n "$((n + 1))p" "$SKILL_MD"; }

extract_block() {
  local marker="$1" out n
  out=$(mktemp); TMPS+=("$out")
  n=$(marker_line "$marker")
  [ -n "$n" ] && awk -v start="$n" 'NR <= start + 1 { next } /^```/ { exit } { print }' "$SKILL_MD" >"$out"
  printf '%s' "$out"
}

PROMOTE_BLOCK=$(extract_block "$PROMOTE_MARKER")
ARCHIVE_BLOCK=$(extract_block "$ARCHIVE_MARKER")

pl_n=$(marker_line "$PROMOTE_MARKER")
pa_n=$(marker_line "$ARCHIVE_MARKER")
heading=""
[ -n "$pl_n" ] && heading=$(head -n "$pl_n" "$SKILL_MD" | grep -E '^#{1,6} ' | tail -1)
squash_n=$(grep -nE '^2\. \*\*Squash-merge' "$SKILL_MD" | head -1 | cut -d: -f1)

if [ "$(marker_count "$PROMOTE_MARKER")" = "1" ] && [ "$(fence_after "$PROMOTE_MARKER")" = '```sh' ] \
   && [ "$(marker_count "$ARCHIVE_MARKER")" = "1" ] && [ "$(fence_after "$ARCHIVE_MARKER")" = '```sh' ]; then
  pass "00: plan-promote and plan-archive each occur exactly once and open a sh fence"
else
  fail "00: plan-promote and plan-archive each occur exactly once and open a sh fence" \
    "promote=$(marker_count "$PROMOTE_MARKER")/[$(fence_after "$PROMOTE_MARKER")] archive=$(marker_count "$ARCHIVE_MARKER")/[$(fence_after "$ARCHIVE_MARKER")]"
fi

if printf '%s' "$heading" | grep -qi 'Plan lifecycle' \
   && [ -n "$pa_n" ] && [ -n "$squash_n" ] && [ "$pa_n" -lt "$squash_n" ]; then
  pass "01: plan-promote sits under a 'Plan lifecycle' heading; plan-archive precedes the squash-merge step"
else
  fail "01: plan-promote sits under a 'Plan lifecycle' heading; plan-archive precedes the squash-merge step" \
    "heading=[$heading] archive=$pa_n squash=$squash_n"
fi

WT=""
LEDGER=""
new_fixture() {
  local base main
  base=$(mktemp -d); TMPS+=("$base")
  main="$base/main"
  WT="$base/wt"
  git init -q -b main "$main"
  git -C "$main" config user.email t@t
  git -C "$main" config user.name t
  mkdir -p "$main/project-plans/proposals" "$main/project-plans/completed"
  touch "$main/project-plans/proposals/.gitkeep" "$main/project-plans/completed/.gitkeep"
  printf '.artifacts/\n' >"$main/.gitignore"
  printf '# fixture\n' >"$main/README.md"
  git -C "$main" add -A
  git -C "$main" commit -q -m baseline
  git -C "$main" worktree add -q -b feature/ship-it "$WT"
  mkdir -p "$WT/.artifacts"
  : >"$WT/.artifacts/progress-log.md"
  LEDGER="$WT/.artifacts/plans-ledger"
  set_role planner
}

set_role() { (cd "$WT" && PATH="$HOOKS_DIR:$PATH" timeout 30 "$HOOKS_DIR/workflow-setup.sh" --set-role "$1" --root "$WT" >/dev/null 2>&1); }

G_RC=0
G_ERR=""
run_guard() {
  G_ERR=$(cd "$WT" && printf '{"cwd": "%s", "tool_name": "Bash"}' "$WT" | timeout 30 "$GUARD" 2>&1 >/dev/null)
  G_RC=$?
}

plan_text() {
  local mark="$1"
  cat <<PLAN
# Ship It Plan

## Phase syllabus
- [$mark] Phase 1: Something
  - [$mark] 1.1: First subphase

## Phase 1: Something
Detail text.
PLAN
}

write_proposal() {
  local mark="$1"
  plan_text "$mark" >"$WT/project-plans/proposals/$SLUG.md"
  printf 'verdict: ready\n' >"$WT/project-plans/proposals/$SLUG.plan-review.md"
}

B_OUT=""
B_RC=0
run_block() {
  local block="$1"
  B_OUT=$(cd "$WT" \
    && PROPOSAL="$WT/project-plans/proposals/$SLUG.md" PLAN_SLUG="$SLUG" \
       PLANS_DIR="$WT/project-plans" PLAN_DIR="$WT/project-plans/$SLUG" \
       GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
       PATH="$HOOKS_DIR:$PATH" timeout 60 bash "$block" 2>&1)
  B_RC=$?
}

in_head() { git -C "$WT" cat-file -e "HEAD:$1" 2>/dev/null; }
tree_status() { git -C "$WT" status --porcelain -- project-plans; }
ledger_ok() { [ -f "$LEDGER" ] && grep -qw 'ok' "$LEDGER"; }
ledger_no_deny() { [ ! -f "$LEDGER" ] || ! grep -qw 'deny' "$LEDGER"; }

promote_flow() {
  local tracked="${1:-no}"
  new_fixture
  write_proposal x
  if [ "$tracked" = yes ]; then
    git -C "$WT" add project-plans
    git -C "$WT" -c user.name=t -c user.email=t@t commit -q -m "proposal"
  fi
  run_guard
  set_role orchestrator
  run_block "$PROMOTE_BLOCK"
}

promote_check() {
  local label="$1" extra="$2" need_ok="${3:-yes}"
  local st head_msg ok_good=0
  if [ "$need_ok" = yes ]; then ledger_ok && ok_good=1; else ok_good=1; fi
  st=$(tree_status)
  run_guard
  if [ ! -s "$PROMOTE_BLOCK" ]; then
    fail "$label" "promote block missing"
  elif [ "$B_RC" -eq 0 ] && in_head "project-plans/$SLUG/plan.md" && in_head "project-plans/$SLUG/plan-review.md" \
     && [ -z "$st" ] && [ "$G_RC" -eq 0 ] && [ "$ok_good" -eq 1 ] && ledger_no_deny \
     && [ "$extra" = ok ]; then
    pass "$label"
  else
    fail "$label" "rc=$B_RC status=[$st] guard=$G_RC/[$G_ERR] extra=$extra out=[$B_OUT]"
  fi
}

promote_flow no
extra=ok
promote_check "02: promote of untracked proposal + plan-review sibling commits both, tree clean, guard ok" "$extra"
CASE02_WT="$WT"

if [ -s "$PROMOTE_BLOCK" ]; then
  set_role planner
  run_guard
  if [ "$G_RC" -eq 0 ] && [ -f "$WT/.artifacts/dae-role" ] && grep -qx 'planner' "$WT/.artifacts/dae-role"; then
    pass "04: after promote, set-role planner then guard exits 0"
  else
    fail "04: after promote, set-role planner then guard exits 0" "guard=$G_RC err=[$G_ERR] role=[$(cat "$WT/.artifacts/dae-role" 2>/dev/null)]"
  fi
else
  fail "04: after promote, set-role planner then guard exits 0" "promote block missing"
fi

promote_flow yes
extra=ok
if [ -s "$PROMOTE_BLOCK" ]; then
  if git -C "$WT" cat-file -e "HEAD~1:project-plans/proposals/$SLUG.md" 2>/dev/null && ! in_head "project-plans/proposals/$SLUG.md"; then
    extra=ok
  else
    extra="proposal-not-removed-by-HEAD-commit"
  fi
fi
promote_check "03: promote of tracked proposal commits plan.md and the proposal deletion, tree clean" "$extra" no

new_fixture
mkdir -p "$WT/project-plans/$SLUG"
plan_text x >"$WT/project-plans/$SLUG/plan.md"
git -C "$WT" add project-plans
git -C "$WT" -c user.name=t -c user.email=t@t commit -q -m "plan"
run_guard
set_role orchestrator
run_block "$ARCHIVE_BLOCK"
run_guard
st=$(tree_status)
if [ ! -s "$ARCHIVE_BLOCK" ]; then
  fail "05: archive of fully ticked plan commits completed/<slug>.md, removes plan dir" "archive block missing"
elif [ "$B_RC" -eq 0 ] && in_head "project-plans/completed/$SLUG.md" && ! in_head "project-plans/$SLUG/plan.md" \
     && [ ! -e "$WT/project-plans/$SLUG" ] && [ -z "$st" ] && [ "$G_RC" -eq 0 ]; then
  pass "05: archive of fully ticked plan commits completed/<slug>.md, removes plan dir"
else
  fail "05: archive of fully ticked plan commits completed/<slug>.md, removes plan dir" \
    "rc=$B_RC status=[$st] guard=$G_RC/[$G_ERR] out=[$B_OUT]"
fi

new_fixture
mkdir -p "$WT/project-plans/$SLUG"
plan_text ' ' >"$WT/project-plans/$SLUG/plan.md"
git -C "$WT" add project-plans
git -C "$WT" -c user.name=t -c user.email=t@t commit -q -m "plan"
run_guard
set_role orchestrator
head_before=$(git -C "$WT" rev-parse HEAD)
run_block "$ARCHIVE_BLOCK"
head_after=$(git -C "$WT" rev-parse HEAD)
if [ ! -s "$ARCHIVE_BLOCK" ]; then
  fail "06: archive refuses a plan with unchecked subphases, nothing committed" "archive block missing"
elif [ "$B_RC" -ne 0 ] && [ "$head_before" = "$head_after" ] && ! in_head "project-plans/completed/$SLUG.md" \
     && in_head "project-plans/$SLUG/plan.md"; then
  pass "06: archive refuses a plan with unchecked subphases, nothing committed"
else
  fail "06: archive refuses a plan with unchecked subphases, nothing committed" \
    "rc=$B_RC before=$head_before after=$head_after out=[$B_OUT]"
fi

M_CO="Co-Authored""-By"
M_CS="Claude""-Session"
M_URL="claude.ai/code/""session"
BAD_RE="${M_CO}|${M_CS}|${M_URL//./\\.}"
control="msg
${M_CS}: https://${M_URL}_x
${M_CO}: someone"
if [ "$(printf '%s\n' "$control" | grep -ciE "$BAD_RE")" -ge 2 ]; then
  ctl=ok
else
  ctl=broken
fi

promote_flow no
promote_msg=$(git -C "$WT" log -1 --format=%B)
run_guard
set_role orchestrator
run_block "$ARCHIVE_BLOCK"
archive_msg=$(git -C "$WT" log -1 --format=%B)
if [ ! -s "$PROMOTE_BLOCK" ] || [ ! -s "$ARCHIVE_BLOCK" ]; then
  fail "07: commit messages are chore(plans) promote/archive without attribution" "block missing"
elif [ "$ctl" = ok ] \
   && [ "$(printf '%s' "$promote_msg" | head -1)" = "chore(plans): promote $SLUG" ] \
   && [ "$(printf '%s' "$archive_msg" | head -1)" = "chore(plans): archive $SLUG" ] \
   && ! printf '%s\n%s\n' "$promote_msg" "$archive_msg" | grep -qiE "$BAD_RE"; then
  pass "07: commit messages are chore(plans) promote/archive without attribution (grep control hits)"
else
  fail "07: commit messages are chore(plans) promote/archive without attribution" \
    "control=$ctl promote=[$promote_msg] archive=[$archive_msg] out=[$B_OUT]"
fi

echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ]
