#!/usr/bin/env bash
# push-pr-gate-refusal.test.sh
#
# SYNOPSIS
#   bash tests/push-pr-gate-refusal.test.sh
#
# DESCRIPTION
#   Blind contract test for agent-agnostic/skills/push-pr/SKILL.md's
#   `--stage finalize` PR-gate precondition (contracts/l1-slices/pat.md,
#   Packet A-test / subphase 2.1). The subject under test IS a markdown spec
#   file: this suite necessarily opens SKILL.md to locate the single line
#   `<!-- pr-gate-check -->`, extract the fenced ```sh block that immediately
#   follows it, and execute that block for real against fixture pr-review.md
#   reports. Every assertion below is authored from the contract's literal
#   text, never from whatever SKILL.md happens to contain today — a
#   disagreement between the file and the contract is a FAILING test, not a
#   reason to adjust the assertion.
#
#   The extracted block is executed with:
#     - PR_REVIEW exported to the fixture path under test,
#     - PATH prefixed with <REPO_ROOT>/agent-agnostic/hooks so the bare names
#       `validate-report.sh` and `report-verdict.sh` resolve to the real
#       scripts in this repo,
#     - stdin from /dev/null, stdout/stderr captured, exit status recorded.
#
#   Fixtures are built with the real report-verdict.sh wherever it accepts
#   the combination (documented CLI: `report-verdict.sh <report-file>
#   <verdict> <next> <blocking> <non-blocking>`, exit 0 = round appended /
#   1 = usage or contract violation); only the malformed ones (02, 03) are
#   hand-written. validate-report.sh is called strictly as a black box
#   through its documented CLI (`validate-report.sh <report-file>`, exit 0
#   valid / 1 invalid) — its source is never read.
#
#   Cases 06, 08, 09 are mandatory: they catch a finalize predicate that
#   merely greps the word "ready" somewhere, or scans the whole report
#   instead of consulting only the LAST round.
#
#   All fixtures live in mktemp -d scratch dirs registered in SCRATCH_DIRS
#   and removed by the cleanup trap. This suite writes nothing inside the
#   repo and never mutates SKILL.md.
#
# EXIT CODES
#   0  every case passed
#   1  at least one case failed (or a sanity precondition failed)
#
# Runnable with no arguments from any working directory.

set -uo pipefail

# ---------------------------------------------------------------------------
# Locate the artifact under test and its dependencies relative to this
# file's own location.
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_MD="$REPO_ROOT/agent-agnostic/skills/push-pr/SKILL.md"
HOOKS_DIR="$REPO_ROOT/agent-agnostic/hooks"
REPORT_VERDICT="$HOOKS_DIR/report-verdict.sh"
MARKER='<!-- pr-gate-check -->'

# ---------------------------------------------------------------------------
# Bookkeeping
# ---------------------------------------------------------------------------
TOTAL_PASS=0
TOTAL_FAIL=0
SCRATCH_DIRS=()
EXTRA_TMP_FILES=()

cleanup() {
  local d
  for d in "${SCRATCH_DIRS[@]:-}"; do
    [ -n "$d" ] && [ -d "$d" ] && rm -rf "$d"
  done
  local f
  for f in "${EXTRA_TMP_FILES[@]:-}"; do
    [ -n "$f" ] && [ -f "$f" ] && rm -f "$f"
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

stop_now() {
  echo "sanity failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
}

# ---------------------------------------------------------------------------
# Case 00: sanity gate. The marker must exist EXACTLY once in SKILL.md and
# be immediately followed (the very next line) by a ```sh fence. If not,
# nothing else in this suite can be trusted.
# ---------------------------------------------------------------------------
marker_count=0
marker_line=0
sanity_ok=1
sanity_evidence=""

if [ ! -f "$SKILL_MD" ]; then
  sanity_ok=0
  sanity_evidence="SKILL.md not found at $SKILL_MD"
else
  marker_count=$(grep -cxF "$MARKER" "$SKILL_MD" 2>/dev/null)
  marker_count=${marker_count:-0}
  if [ "$marker_count" -ne 1 ]; then
    sanity_ok=0
    sanity_evidence="marker '$MARKER' occurs $marker_count time(s) in SKILL.md (expected exactly 1)"
  else
    marker_line=$(grep -nxF "$MARKER" "$SKILL_MD" 2>/dev/null | head -1 | cut -d: -f1)
    marker_line=${marker_line:-0}
    next_line_num=$((marker_line + 1))
    next_line=$(sed -n "${next_line_num}p" "$SKILL_MD")
    case "$next_line" in
      '```sh'*) : ;;
      *)
        sanity_ok=0
        sanity_evidence="line $next_line_num (immediately after the marker) is not a \`\`\`sh fence: [$next_line]"
        ;;
    esac
  fi
fi

if [ "$sanity_ok" -eq 1 ]; then
  pass "00: marker '$MARKER' occurs exactly once in SKILL.md and is immediately followed by a \`\`\`sh fence"
else
  fail "00: marker '$MARKER' occurs exactly once in SKILL.md and is immediately followed by a \`\`\`sh fence" \
    "$sanity_evidence"
  stop_now
fi

# ---------------------------------------------------------------------------
# Extraction: lines strictly between the fence immediately after the marker
# line and its closing fence. NOTE: no `--` is ever passed to awk here (this
# machine's awk is mawk, which reads a trailing `--` as a FILENAME, not an
# end-of-options marker, and can silently mis-parse while still exiting 0).
# ---------------------------------------------------------------------------
extract_block() {
  awk -v start="$marker_line" '
    NR <= start + 1 { next }
    /^```/ { exit }
    { print }
  ' "$SKILL_MD"
}

extract_section() {
  # Print all lines strictly after a heading line matching $1 (a markdown
  # heading like "### --stage finalize"), up to (but not including) the
  # next markdown heading of level 1-3. Heading lines are compared with
  # inline-code backticks stripped, since this doc's convention wraps
  # stage flags in backticks in every "### --stage X" heading
  # (e.g. "### `--stage finalize`") — a formatting detail, not a
  # substantive part of what's being asserted.
  local heading="$1"
  awk -v heading="$heading" '
    {
      norm = $0
      gsub(/`/, "", norm)
    }
    norm == heading { infile = 1; next }
    infile && /^#{1,3}[^#]/ { exit }
    infile { print }
  ' "$SKILL_MD"
}

FINALIZE_SCRIPT=$(mktemp)
EXTRA_TMP_FILES+=("$FINALIZE_SCRIPT")
extract_block > "$FINALIZE_SCRIPT"

# Case 00b: the extracted block must itself be non-empty, real bash — not
# an artifact of a mis-parse that happens to exit 0 (the exact mawk `--`
# failure mode this contract warns about). Assert on actual content, not
# just the parser's exit status.
if [ -s "$FINALIZE_SCRIPT" ] && bash -n "$FINALIZE_SCRIPT" 2>/tmp/pr-gate-refusal-synerr.$$; then
  pass "00b: extracted finalize block is non-empty and parses (bash -n)"
  rm -f /tmp/pr-gate-refusal-synerr.$$
else
  synerr=$(cat /tmp/pr-gate-refusal-synerr.$$ 2>/dev/null)
  rm -f /tmp/pr-gate-refusal-synerr.$$
  fail "00b: extracted finalize block is non-empty and parses (bash -n)" \
    "size=$(wc -c <"$FINALIZE_SCRIPT" 2>/dev/null) syntax_error=[$synerr]"
  stop_now
fi

# ---------------------------------------------------------------------------
# Execute the extracted block against a fixture PR_REVIEW path.
# ---------------------------------------------------------------------------
OUT=""
ERR=""
CODE=0
run_fixture() {
  local pr_review_path="$1"
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  PR_REVIEW="$pr_review_path" PATH="$HOOKS_DIR:$PATH" bash "$FINALIZE_SCRIPT" \
    </dev/null >"$out_f" 2>"$err_f"
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

run_case() {
  local num="$1" desc="$2" fixture_path="$3" expected="$4"
  run_fixture "$fixture_path"
  local ok=0
  if [ "$expected" = "proceed" ]; then
    [ "$CODE" -eq 0 ] && ok=1
  else
    [ "$CODE" -ne 0 ] && ok=1
  fi
  if [ "$ok" -eq 1 ]; then
    pass "$num: $desc"
  else
    fail "$num: $desc" "expected=$expected code=$CODE out=[$OUT] err=[$ERR]"
  fi
}

# ---------------------------------------------------------------------------
# Fixture builders. report-verdict.sh is used wherever it accepts the
# combination; only the two malformed reports (02, 03) are hand-written.
# Findings lines are kept in exact agreement with the header counts each
# call declares, so validate-report.sh never fails a fixture for the wrong
# reason.
# ---------------------------------------------------------------------------

build_case01() {
  # A path that does not exist at all.
  local dir
  dir=$(new_scratch)
  printf '%s' "$dir/does-not-exist.md"
}

build_case02() {
  # Hand-written: a single '## Round 1' whose header carries an invalid
  # verdict enum value ('shipit' is not ready|tentative|rejected).
  local dir f
  dir=$(new_scratch)
  f="$dir/pr-review.md"
  {
    printf '# pr-review\n'
    printf '\n## Round 1 — 08-24-26\n\n'
    printf '```\n'
    printf 'verdict: shipit\n'
    printf 'next: proceed\n'
    printf 'blocking: 0\n'
    printf 'non-blocking: 0\n'
    printf '```\n'
  } > "$f"
  printf '%s' "$f"
}

build_case03() {
  # Hand-written: no '## Round' section at all.
  local dir f
  dir=$(new_scratch)
  f="$dir/pr-review.md"
  printf '# pr-review\n\nNothing here yet.\n' > "$f"
  printf '%s' "$f"
}

build_case04() {
  # report-verdict.sh <f> rejected impl-wrong 1 0 + one blocking finding line.
  local dir f
  dir=$(new_scratch)
  f="$dir/pr-review.md"
  "$REPORT_VERDICT" "$f" rejected impl-wrong 1 0 >/dev/null
  {
    printf '\n### Findings\n'
    printf '%s\n' "- [blocking] the migration is not reversible"
  } >> "$f"
  printf '%s' "$f"
}

build_case05() {
  # report-verdict.sh <f> rejected needs-input 0 0 + a non-empty
  # '### Open questions' section.
  local dir f
  dir=$(new_scratch)
  f="$dir/pr-review.md"
  "$REPORT_VERDICT" "$f" rejected needs-input 0 0 >/dev/null
  {
    printf '\n### Open questions\n'
    printf '%s\n' "- which base branch should this target?"
  } >> "$f"
  printf '%s' "$f"
}

build_case06() {
  # report-verdict.sh <f> tentative proceed 0 0 — tentative is not ready.
  local dir f
  dir=$(new_scratch)
  f="$dir/pr-review.md"
  "$REPORT_VERDICT" "$f" tentative proceed 0 0 >/dev/null
  printf '%s' "$f"
}

build_case07() {
  # report-verdict.sh <f> ready proceed 0 0.
  local dir f
  dir=$(new_scratch)
  f="$dir/pr-review.md"
  "$REPORT_VERDICT" "$f" ready proceed 0 0 >/dev/null
  printf '%s' "$f"
}

build_case08() {
  # Round 1: ready proceed 0 0. Round 2: rejected impl-wrong 1 0 + blocking
  # line. The LAST round is rejected, so this must refuse even though an
  # earlier round said ready.
  local dir f
  dir=$(new_scratch)
  f="$dir/pr-review.md"
  "$REPORT_VERDICT" "$f" ready proceed 0 0 >/dev/null
  "$REPORT_VERDICT" "$f" rejected impl-wrong 1 0 >/dev/null
  {
    printf '\n### Findings\n'
    printf '%s\n' "- [blocking] regression introduced after round 1"
  } >> "$f"
  printf '%s' "$f"
}

build_case09() {
  # Round 1: rejected impl-wrong 1 0 + blocking line. Round 2: ready
  # proceed 0 0. The LAST round is ready, so this must proceed even though
  # an earlier round was rejected.
  local dir f
  dir=$(new_scratch)
  f="$dir/pr-review.md"
  "$REPORT_VERDICT" "$f" rejected impl-wrong 1 0 >/dev/null
  {
    printf '\n### Findings\n'
    printf '%s\n' "- [blocking] initial issue, fixed before round 2"
  } >> "$f"
  "$REPORT_VERDICT" "$f" ready proceed 0 0 >/dev/null
  printf '%s' "$f"
}

# ---------------------------------------------------------------------------
# Run all nine fixture cases from the contract's table.
# ---------------------------------------------------------------------------
run_case "01" "path that does not exist -> refuse (non-zero)" \
  "$(build_case01)" "refuse"

run_case "02" "hand-written report, Round 1 verdict: shipit (invalid enum) -> refuse" \
  "$(build_case02)" "refuse"

run_case "03" "hand-written report, no ## Round section at all -> refuse" \
  "$(build_case03)" "refuse"

run_case "04" "rejected impl-wrong 1 0 + one blocking finding -> refuse" \
  "$(build_case04)" "refuse"

run_case "05" "rejected needs-input 0 0 + non-empty Open questions -> refuse" \
  "$(build_case05)" "refuse"

run_case "06" "tentative proceed 0 0 -> refuse (tentative is not ready)" \
  "$(build_case06)" "refuse"

run_case "07" "ready proceed 0 0 -> proceed (exit 0)" \
  "$(build_case07)" "proceed"

run_case "08" "round 1 ready, round 2 rejected+blocking -> refuse (last round governs)" \
  "$(build_case08)" "refuse"

run_case "09" "round 1 rejected+blocking, round 2 ready -> proceed (last round governs)" \
  "$(build_case09)" "proceed"

# ---------------------------------------------------------------------------
# Textual assertions on SKILL.md itself.
# ---------------------------------------------------------------------------

# text-1: the ### --stage finalize section contains the marker line.
finalize_section=$(extract_section "### --stage finalize")
if printf '%s\n' "$finalize_section" | grep -qxF "$MARKER"; then
  pass "text-1: the ### --stage finalize section contains the pr-gate-check marker"
else
  fail "text-1: the ### --stage finalize section contains the pr-gate-check marker" \
    "section=[$finalize_section]"
fi

# text-2: the marker's block, whitespace-normalized, contains the literal
# 'validate-report.sh' and the literal 'verdict ready, next proceed'.
normalized_block=$(extract_block | tr -s '[:space:][:cntrl:]' ' ')
if printf '%s' "$normalized_block" | grep -qF "validate-report.sh" \
   && printf '%s' "$normalized_block" | grep -qF "verdict ready, next proceed"; then
  pass "text-2: extracted block (whitespace-normalized) contains literal 'validate-report.sh' and literal 'verdict ready, next proceed'"
else
  fail "text-2: extracted block (whitespace-normalized) contains literal 'validate-report.sh' and literal 'verdict ready, next proceed'" \
    "normalized=[$normalized_block]"
fi

# text-3: pr-review.md is named in the finalize inputs bullet.
finalize_bullets=$(grep -E '^[[:space:]]*[-*][[:space:]]*`finalize`' "$SKILL_MD" 2>/dev/null)
if [ -n "$finalize_bullets" ] && printf '%s\n' "$finalize_bullets" | grep -qF "pr-review.md"; then
  pass "text-3: pr-review.md is named in the finalize inputs bullet"
else
  fail "text-3: pr-review.md is named in the finalize inputs bullet" \
    "bullets=[$finalize_bullets]"
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
