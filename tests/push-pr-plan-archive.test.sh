#!/usr/bin/env bash
# Runs push-pr's <!-- plan-archive --> finalize block against a scratch repo.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_MD="$REPO_ROOT/agent-agnostic/skills/push-pr/SKILL.md"
HOOKS_DIR="$REPO_ROOT/agent-agnostic/hooks"
MARKER='<!-- plan-archive -->'
GATE_MARKER='<!-- pr-gate-check -->'

TOTAL_PASS=0
TOTAL_FAIL=0
SCRATCH=""
BLOCK=""

cleanup() {
  [ -n "$SCRATCH" ] && [ -d "$SCRATCH" ] && rm -rf "$SCRATCH"
  [ -n "$BLOCK" ] && [ -f "$BLOCK" ] && rm -f "$BLOCK"
}
trap cleanup EXIT

pass() { echo "PASS: $1"; TOTAL_PASS=$((TOTAL_PASS + 1)); }
fail() { echo "FAIL: $1 ($2)"; TOTAL_FAIL=$((TOTAL_FAIL + 1)); }

marker_count=$(grep -cxF "$MARKER" "$SKILL_MD")
marker_line=$(grep -nxF "$MARKER" "$SKILL_MD" | head -1 | cut -d: -f1)
gate_line=$(grep -nxF "$GATE_MARKER" "$SKILL_MD" | head -1 | cut -d: -f1)
finalize_line=$(grep -nE '^### `?--stage finalize`?$' "$SKILL_MD" | head -1 | cut -d: -f1)
flip_line=$(grep -nE '^5\. \*\*Flip draft to ready\.\*\*' "$SKILL_MD" | head -1 | cut -d: -f1)
fence_line=$(sed -n "$((${marker_line:-0} + 1))p" "$SKILL_MD")

if [ "$marker_count" = "1" ] && [ "$fence_line" = '```sh' ]; then
  pass "00: '$MARKER' occurs exactly once and opens a sh fence"
else
  fail "00: '$MARKER' occurs exactly once and opens a sh fence" "count=$marker_count next=[$fence_line]"
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi

if [ -n "$finalize_line" ] && [ -n "$gate_line" ] && [ -n "$flip_line" ] \
   && [ "$finalize_line" -lt "$gate_line" ] && [ "$gate_line" -lt "$marker_line" ] \
   && [ "$marker_line" -lt "$flip_line" ]; then
  pass "01: archive sits inside finalize, after the PR-gate check, before the ready flip"
else
  fail "01: archive sits inside finalize, after the PR-gate check, before the ready flip" \
    "finalize=$finalize_line gate=$gate_line archive=$marker_line flip=$flip_line"
fi

BLOCK=$(mktemp)
awk -v start="$marker_line" 'NR <= start + 1 { next } /^```/ { exit } { print }' "$SKILL_MD" >"$BLOCK"
if [ -s "$BLOCK" ] && bash -n "$BLOCK" 2>/dev/null; then
  pass "02: extracted archive block is non-empty and parses"
else
  fail "02: extracted archive block is non-empty and parses" "size=$(wc -c <"$BLOCK")"
fi

SCRATCH=$(mktemp -d)
slug="ship-it-01-02-26"
plans="$SCRATCH/project-plans"
mkdir -p "$plans/proposals" "$plans/completed" "$plans/$slug"
touch "$plans/proposals/.gitkeep" "$plans/completed/.gitkeep"
cat >"$plans/$slug/plan.md" <<'EOF'
# Ship It Plan

## Phase syllabus
- [x] Phase 1: Something
  - [x] 1.1: First subphase

## Phase 1: Something
Detail text.
EOF
printf 'verdict: ready\n' >"$plans/$slug/pr-review.md"
git -C "$SCRATCH" init -q -b feature/ship-it
git -C "$SCRATCH" -c user.name=t -c user.email=t@t add project-plans
git -C "$SCRATCH" -c user.name=t -c user.email=t@t commit -q -m "plan"

block_out=$(cd "$SCRATCH" \
  && PLAN_DIR="$plans/$slug" PLANS_DIR="$plans" PLAN_SLUG="$slug" \
     GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
     PATH="$HOOKS_DIR:$PATH" bash "$BLOCK" 2>&1)
block_rc=$?

if [ "$block_rc" -eq 0 ] && [ -f "$plans/completed/$slug.md" ] && [ ! -e "$plans/$slug" ]; then
  pass "03: block moves plan.md to completed/ and removes the plan dir"
else
  fail "03: block moves plan.md to completed/ and removes the plan dir" "rc=$block_rc out=[$block_out]"
fi

status_out=$(git -C "$SCRATCH" status --porcelain)
if [ -z "$status_out" ]; then
  pass "04: tree is clean after the single archive call"
else
  fail "04: tree is clean after the single archive call" "status=[$status_out]"
fi

head_msg=$(git -C "$SCRATCH" log -1 --format=%s)
head_files=$(git -C "$SCRATCH" show --name-status --format= HEAD | sort | tr '\n' ' ')
if [ "$head_msg" = "chore(plans): archive $slug" ] \
   && printf '%s' "$head_files" | grep -qF "completed/$slug.md" \
   && printf '%s' "$head_files" | grep -qF "$slug/pr-review.md"; then
  pass "05: archive is one commit on the branch carrying the move and the record removal"
else
  fail "05: archive is one commit on the branch carrying the move and the record removal" \
    "msg=[$head_msg] files=[$head_files]"
fi

echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ]
