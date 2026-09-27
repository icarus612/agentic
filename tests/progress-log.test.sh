#!/usr/bin/env bash
# progress-log.test.sh
#
# SYNOPSIS
#   bash tests/progress-log.test.sh
#
# DESCRIPTION
#   Blind contract test for agent-agnostic/hooks/progress-log.sh (Packet 4,
#   4.1): a small, argv-driven script (NOT a hook -- no stdin JSON payload,
#   invoked by Bash the same way mark-syllabus.sh is) that owns
#   <run-dir>/progress-log.md:
#
#     progress-log.sh --init <run-dir> <name> <branch> <base>
#     progress-log.sh --set <run-dir> <section> <text...>
#     progress-log.sh --append <run-dir> <section> <text...>
#
#   Written from the contract text (l1.md, Packet 4) alone. Never reads
#   progress-log.sh's source, in any mode, including to interpret a failure.
#
#   Text arguments below are always passed as a SINGLE space-free token
#   (e.g. "buildingnow") deliberately -- the contract leaves open whether
#   <text...> is "all remaining args joined with a single space" or "one
#   already-quoted final argument"; a single space-free argument produces an
#   identical result under either convention, so these tests don't have to
#   guess which one the implementation picked.
#
#   Section/content assertions use pure-bash line scanning and substring
#   matching (no grep/awk) specifically to avoid the ugrep/mawk pitfalls
#   named in the plan's Conventions section (a leading "--" or a line
#   starting "- " -- exactly what the seed content's "- Branch:` / "- Base:"
#   bullet lines look like -- can make grep/awk lie about a real match).
#
#   All fixtures are throwaway mktemp -d directories, cleaned up on exit via
#   trap.
#
# EXIT CODES
#   0  every case passed
#   1  at least one case failed (or the bash -n sanity precondition failed)
#
# Runnable with no arguments from any working directory.

set -uo pipefail

# ---------------------------------------------------------------------------
# Locate the script relative to this file's own location.
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/agent-agnostic/hooks/progress-log.sh"

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
# run_script <args...> -- invokes the script with the given argv (stdin from
# /dev/null -- this is an argv-driven script, not a hook), sets globals
# OUT / ERR / CODE.
# ---------------------------------------------------------------------------
OUT=""
ERR=""
CODE=0
run_script() {
  local out_f err_f
  out_f=$(mktemp)
  err_f=$(mktemp)
  "$SCRIPT" "$@" >"$out_f" 2>"$err_f" </dev/null
  CODE=$?
  OUT=$(cat "$out_f")
  ERR=$(cat "$err_f")
  rm -f "$out_f" "$err_f"
}

# ---------------------------------------------------------------------------
# Pure-bash content helpers (no grep/awk -- see header note).
# ---------------------------------------------------------------------------

# contains <haystack> <needle> -- true if needle is a literal substring of
# haystack (bash glob match, no external tool).
contains() {
  case "$1" in
    *"$2"*) return 0 ;;
    *) return 1 ;;
  esac
}

# section_exists <file> <section-name> -- true if a line exactly
# "## <section-name>" appears in file.
section_exists() {
  local file="$1" heading="## $2" line
  [ -f "$file" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$line" = "$heading" ]; then
      return 0
    fi
  done <"$file"
  return 1
}

# section_body <file> <section-name> -- prints the lines between the
# "## <section-name>" heading (exclusive) and the next "## " heading or EOF
# (exclusive), one per line.
section_body() {
  local file="$1" heading="## $2" line infile=0
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$infile" = 1 ]; then
      case "$line" in
        "## "*) infile=0 ;;
        *) printf '%s\n' "$line" ;;
      esac
    fi
    if [ "$line" = "$heading" ]; then
      infile=1
    fi
  done <"$file"
}

# file_content <file> -- whole file as one string, or a sentinel if absent.
file_content() {
  if [ -f "$1" ]; then
    cat "$1"
  else
    printf '<<absent>>'
  fi
}

# ---------------------------------------------------------------------------
# Case 01: bash -n sanity precondition (script must at least parse)
# ---------------------------------------------------------------------------
SYN_ERR_FILE=$(mktemp)
if bash -n "$SCRIPT" 2>"$SYN_ERR_FILE"; then
  pass "01: bash -n progress-log.sh exits 0"
else
  fail "01: bash -n progress-log.sh exits 0" "syntax error (or script does not exist yet): $(cat "$SYN_ERR_FILE")"
  rm -f "$SYN_ERR_FILE"
  echo "sanity failed: nothing else can be trusted, stopping."
  echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
  exit 1
fi
rm -f "$SYN_ERR_FILE"

# ---------------------------------------------------------------------------
# Case 02: --init on a fresh dir -> file created, expected seed structure
# (name/branch/base present, a "## State" section exists).
# ---------------------------------------------------------------------------
case02() {
  local label="02: --init on fresh dir -> seeded progress-log.md"
  local dir target content
  dir=$(new_scratch)
  target="$dir/progress-log.md"
  run_script --init "$dir" "myrun" "feature/x" "main"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if [ ! -f "$target" ]; then
    fail "$label -> file exists" "target=$target not created"
    return
  fi
  content=$(file_content "$target")
  if [ -z "$content" ]; then
    fail "$label -> file non-empty" "content was empty"
    return
  fi
  if ! contains "$content" "myrun"; then
    fail "$label -> content has run name" "content=[$content]"
    return
  fi
  if ! contains "$content" "feature/x"; then
    fail "$label -> content has branch" "content=[$content]"
    return
  fi
  if ! contains "$content" "main"; then
    fail "$label -> content has base" "content=[$content]"
    return
  fi
  if ! section_exists "$target" "State"; then
    fail "$label -> ## State section exists" "content=[$content]"
    return
  fi
  pass "$label"
}
case02

# ---------------------------------------------------------------------------
# Case 03: --init on a dir that already has a progress-log.md -> exit 1,
# existing content UNCHANGED. Positive control: --init on a genuinely fresh
# dir in the SAME run succeeds, so a bug that always refuses isn't mistaken
# for correct guarding.
# ---------------------------------------------------------------------------
case03() {
  local label="03: --init refuses an existing file, unchanged"
  local dir target before after
  dir=$(new_scratch)
  target="$dir/progress-log.md"
  printf '# Pre-existing content\n\nDO NOT TOUCH\n' >"$target"
  before=$(file_content "$target")

  run_script --init "$dir" "other" "other-branch" "other-base"
  if [ "$CODE" -ne 1 ]; then
    fail "$label -> exit 1" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  after=$(file_content "$target")
  if [ "$before" != "$after" ]; then
    fail "$label -> content unchanged" "before=[$before] after=[$after]"
    return
  fi
  pass "$label"

  # Positive control: a genuinely fresh dir's --init succeeds in this same run.
  local ctrl_dir ctrl_target
  ctrl_dir=$(new_scratch)
  ctrl_target="$ctrl_dir/progress-log.md"
  run_script --init "$ctrl_dir" "ctrl" "ctrl-branch" "ctrl-base"
  if [ "$CODE" -eq 0 ] && [ -f "$ctrl_target" ]; then
    pass "03b (positive control): --init on a fresh dir succeeds"
  else
    fail "03b (positive control): --init on a fresh dir succeeds" "code=$CODE target-exists=$([ -f "$ctrl_target" ] && echo yes || echo no) err=[$ERR]"
  fi
}
case03

# ---------------------------------------------------------------------------
# Case 04: --set on an existing section replaces its body; re-reading shows
# the NEW text and NOT the old text. Sibling sections are left alone.
# ---------------------------------------------------------------------------
case04() {
  local label="04: --set replaces an existing section's body"
  local dir target body
  dir=$(new_scratch)
  target="$dir/progress-log.md"
  printf '# Run: fixture\n\n## State\n\noldbodytext\n\n## Notes\n\nkeepthisnote\n' >"$target"

  run_script --set "$dir" "State" "newbodytext"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  body=$(section_body "$target" "State")
  if ! contains "$body" "newbodytext"; then
    fail "$label -> new text present in State body" "body=[$body]"
    return
  fi
  if contains "$body" "oldbodytext"; then
    fail "$label -> old text removed from State body" "body=[$body]"
    return
  fi
  body=$(section_body "$target" "Notes")
  if ! contains "$body" "keepthisnote"; then
    fail "$label -> sibling section (Notes) left untouched" "body=[$body]"
    return
  fi
  pass "$label"
}
case04

# ---------------------------------------------------------------------------
# Case 05: --set on a section that doesn't exist yet creates it (appended at
# EOF) rather than erroring.
# ---------------------------------------------------------------------------
case05() {
  local label="05: --set on a missing section creates it at EOF"
  local dir target body
  dir=$(new_scratch)
  target="$dir/progress-log.md"
  printf '# Run: fixture\n\n## State\n\nsomething\n' >"$target"

  run_script --set "$dir" "Log" "brandnewsection"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! section_exists "$target" "Log"; then
    fail "$label -> ## Log section created" "content=[$(file_content "$target")]"
    return
  fi
  body=$(section_body "$target" "Log")
  if ! contains "$body" "brandnewsection"; then
    fail "$label -> new section body has the text" "body=[$body]"
    return
  fi
  pass "$label"
}
case05

# ---------------------------------------------------------------------------
# Case 06: --append on an existing section adds a new line while preserving
# old lines (both old and new text present after).
# ---------------------------------------------------------------------------
case06() {
  local label="06: --append adds a line, preserving old content"
  local dir target body
  dir=$(new_scratch)
  target="$dir/progress-log.md"
  printf '# Run: fixture\n\n## Notes\n\noldline\n' >"$target"

  run_script --append "$dir" "Notes" "newline"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  body=$(section_body "$target" "Notes")
  if ! contains "$body" "oldline"; then
    fail "$label -> old line preserved" "body=[$body]"
    return
  fi
  if ! contains "$body" "newline"; then
    fail "$label -> new line present" "body=[$body]"
    return
  fi
  pass "$label"
}
case06

# ---------------------------------------------------------------------------
# Case 07: --append on a missing section creates it (same as --set's
# fallback).
# ---------------------------------------------------------------------------
case07() {
  local label="07: --append on a missing section creates it"
  local dir target body
  dir=$(new_scratch)
  target="$dir/progress-log.md"
  printf '# Run: fixture\n\n## State\n\nsomething\n' >"$target"

  run_script --append "$dir" "Log" "appendedentry"
  if [ "$CODE" -ne 0 ]; then
    fail "$label -> exit 0" "code=$CODE out=[$OUT] err=[$ERR]"
    return
  fi
  if ! section_exists "$target" "Log"; then
    fail "$label -> ## Log section created" "content=[$(file_content "$target")]"
    return
  fi
  body=$(section_body "$target" "Log")
  if ! contains "$body" "appendedentry"; then
    fail "$label -> new section body has the text" "body=[$body]"
    return
  fi
  pass "$label"
}
case07

# ---------------------------------------------------------------------------
# Case 08: malformed invocations -> exit 1 for each, stderr non-empty, and
# -- for --set/--append cases run against a real existing file -- the file
# is UNCHANGED (proving "usage error" means no mutation, not a partial one).
# Positive control: a well-formed call against the same kind of fixture
# succeeds, so the malformed-rejection isn't just "always fails".
# ---------------------------------------------------------------------------
case08() {
  local dir target before after

  # 08a: --init with no run-dir at all.
  run_script --init
  if [ "$CODE" -eq 1 ] && [ -n "$ERR" ]; then
    pass "08a: --init with no args -> exit 1, stderr non-empty"
  else
    fail "08a: --init with no args -> exit 1, stderr non-empty" "code=$CODE err=[$ERR]"
  fi

  # 08b: unknown flag.
  dir=$(new_scratch)
  run_script --bogus "$dir"
  if [ "$CODE" -eq 1 ] && [ -n "$ERR" ]; then
    pass "08b: unknown flag -> exit 1, stderr non-empty"
  else
    fail "08b: unknown flag -> exit 1, stderr non-empty" "code=$CODE err=[$ERR]"
  fi

  # 08c: --set missing section/text args, against a REAL existing file ->
  # exit 1, stderr non-empty, file unchanged.
  dir=$(new_scratch)
  target="$dir/progress-log.md"
  printf '# Run: fixture\n\n## State\n\nunchangedbody\n' >"$target"
  before=$(file_content "$target")
  run_script --set "$dir"
  after=$(file_content "$target")
  if [ "$CODE" -eq 1 ] && [ -n "$ERR" ] && [ "$before" = "$after" ]; then
    pass "08c: --set missing section/text -> exit 1, stderr non-empty, file unchanged"
  else
    fail "08c: --set missing section/text -> exit 1, stderr non-empty, file unchanged" \
      "code=$CODE err=[$ERR] before=[$before] after=[$after]"
  fi

  # 08d: --append missing text arg, against a REAL existing file -> exit 1,
  # stderr non-empty, file unchanged.
  dir=$(new_scratch)
  target="$dir/progress-log.md"
  printf '# Run: fixture\n\n## Notes\n\nunchangedbody\n' >"$target"
  before=$(file_content "$target")
  run_script --append "$dir" "Notes"
  after=$(file_content "$target")
  if [ "$CODE" -eq 1 ] && [ -n "$ERR" ] && [ "$before" = "$after" ]; then
    pass "08d: --append missing text arg -> exit 1, stderr non-empty, file unchanged"
  else
    fail "08d: --append missing text arg -> exit 1, stderr non-empty, file unchanged" \
      "code=$CODE err=[$ERR] before=[$before] after=[$after]"
  fi

  # 08e: --set with no run-dir at all.
  run_script --set
  if [ "$CODE" -eq 1 ] && [ -n "$ERR" ]; then
    pass "08e: --set with no args -> exit 1, stderr non-empty"
  else
    fail "08e: --set with no args -> exit 1, stderr non-empty" "code=$CODE err=[$ERR]"
  fi

  # Positive control: a well-formed --set call against the same kind of
  # fixture (real existing file) succeeds -- proves 08c/08d aren't just
  # "--set/--append always fail".
  dir=$(new_scratch)
  target="$dir/progress-log.md"
  printf '# Run: fixture\n\n## State\n\noldbody\n' >"$target"
  run_script --set "$dir" "State" "wellformedtext"
  if [ "$CODE" -eq 0 ] && contains "$(section_body "$target" "State")" "wellformedtext"; then
    pass "08f (positive control): well-formed --set succeeds against a real file"
  else
    fail "08f (positive control): well-formed --set succeeds against a real file" \
      "code=$CODE body=[$(section_body "$target" "State")]"
  fi
}
case08

# ---------------------------------------------------------------------------
# Case 09: --set/--append against a run-dir with NO progress-log.md at all
# -> exit 1, nothing created. Positive control: the identical operation
# against a dir that DOES have the file succeeds (already covered by
# cases 04/06 above, restated here inline for self-containment).
# ---------------------------------------------------------------------------
case09() {
  local dir target

  # --set, no file present.
  dir=$(new_scratch)
  target="$dir/progress-log.md"
  run_script --set "$dir" "State" "shouldnotappear"
  if [ "$CODE" -eq 1 ] && [ ! -f "$target" ]; then
    pass "09a: --set with no progress-log.md -> exit 1, nothing created"
  else
    fail "09a: --set with no progress-log.md -> exit 1, nothing created" \
      "code=$CODE file-exists=$([ -f "$target" ] && echo yes || echo no) err=[$ERR]"
  fi

  # --append, no file present.
  dir=$(new_scratch)
  target="$dir/progress-log.md"
  run_script --append "$dir" "State" "shouldnotappear"
  if [ "$CODE" -eq 1 ] && [ ! -f "$target" ]; then
    pass "09b: --append with no progress-log.md -> exit 1, nothing created"
  else
    fail "09b: --append with no progress-log.md -> exit 1, nothing created" \
      "code=$CODE file-exists=$([ -f "$target" ] && echo yes || echo no) err=[$ERR]"
  fi

  # Positive control: same op, file present -> succeeds.
  dir=$(new_scratch)
  target="$dir/progress-log.md"
  printf '# Run: fixture\n\n## State\n\nsomething\n' >"$target"
  run_script --set "$dir" "State" "shouldappear"
  if [ "$CODE" -eq 0 ] && contains "$(section_body "$target" "State")" "shouldappear"; then
    pass "09c (positive control): --set succeeds when progress-log.md exists"
  else
    fail "09c (positive control): --set succeeds when progress-log.md exists" \
      "code=$CODE body=[$(section_body "$target" "State")]"
  fi
}
case09

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
