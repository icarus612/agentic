#!/usr/bin/env bash
# validate-plan.sh — structural (schema) checks for a plan-format plan file.
#
# SYNOPSIS
#   validate-plan.sh <plan-file>
#
# DESCRIPTION
#   Owns the mechanical half of the review-plan gate, so the reviewer fork
#   spends its whole budget verifying claims against reality. Checks:
#     1. The FIRST section heading is '## Phase syllabus'.
#     2. Every syllabus phase bullet has at least one subphase checkbox.
#     3. Subphase IDs are checkbox <-> detail-block 1:1 (every syllabus ID
#        has exactly one detail block below, and vice versa). A detail block
#        opens with its id in either markup the plans in the wild use — a bold
#        lead-in ('**<id>:') or a markdown heading ('### <id> — Title').
#        plan-format fixes the ID, not the markup around it, so both count.
#     4. Every '(after: ...)' reference names a real subphase ID.
#     5. The (after:) dependency graph is acyclic.
#   Lane file-scope disjointness is NOT machine-checked (scopes are prose in
#   the detail blocks) — that stays with the reviewer, flagged as INFO.
#
# EXIT CODES
#   0 - structurally valid (INFO lines may still print)
#   1 - violations found (one 'FAIL:' line each), or usage/read error
set -uo pipefail

plan="${1:-}"
[ -n "$plan" ] || { echo "usage: validate-plan.sh <plan-file>" >&2; exit 1; }
[ -f "$plan" ] || { echo "FAIL: plan file not found: $plan" >&2; exit 1; }

fail=0
say_fail() { echo "FAIL: $*"; fail=1; }

# --- 1. syllabus is the first section --------------------------------------
first_heading=$(grep -m1 -E '^## ' "$plan" || true)
case "$first_heading" in
  "## Phase syllabus"*) : ;;
  *) say_fail "first '## ' section must be '## Phase syllabus' (found: '${first_heading:-none}')" ;;
esac

# --- syllabus block = from the heading to the next '## ' -------------------
syllabus=$(awk '/^## Phase syllabus/{f=1;next} /^## /{if(f)exit} f' "$plan")
[ -n "$syllabus" ] || say_fail "empty or missing Phase syllabus section"

# --- 2. every phase bullet has >=1 subphase checkbox -----------------------
echo "$syllabus" | awk '
  /^- \[/ { if (phase != "" && subs == 0) printf "FAIL: phase with no subphase checkboxes: %s\n", phase
            phase=$0; subs=0; next }
  /^  +- \[/ { subs++ }
  END { if (phase != "" && subs == 0) printf "FAIL: phase with no subphase checkboxes: %s\n", phase }
' | while IFS= read -r line; do echo "$line"; done
# re-detect failure from subshell output
if echo "$syllabus" | awk '
  /^- \[/ { if (phase != "" && subs == 0) bad=1; phase=$0; subs=0; next }
  /^  +- \[/ { subs++ }
  END { if (phase != "" && subs == 0) bad=1; exit bad?0:1 }
'; then fail=1; fi

# --- collect syllabus subphase IDs (e.g. '1.1', '10.2') --------------------
syl_ids=$(echo "$syllabus" | grep -oE '^\s+- \[[^]]*\]\s+[0-9]+\.[0-9]+:' \
  | grep -oE '[0-9]+\.[0-9]+' | sort -u)
[ -n "$syl_ids" ] || say_fail "no '<phase>.<subphase>:' checkbox entries found in the syllabus"

# --- collect detail-block IDs (below the syllabus) --------------------------
# A detail block opens with its subphase id in either of the two markups the
# plans in the wild use: a bold lead-in ('**N.M:') or a markdown heading
# ('### N.M — Title'). plan-format fixes the ID, not the markup, so accept
# both — matching only one of them fails every plan written in the other.
# The trailing class stops '1.1' from also matching '1.10'.
detail_open='^(\*\*|#{2,6}[[:space:]]+)'
detail_close='([[:space:]]|:|$)'

# --- 3. 1:1 checkbox <-> detail block --------------------------------------
detail_ids=$(awk '/^## Phase syllabus/{f=1;next} /^## /{f=0} !f' "$plan" \
  | grep -oE "${detail_open}[0-9]+\.[0-9]+${detail_close}" \
  | grep -oE '[0-9]+\.[0-9]+' | sort -u)

for id in $syl_ids; do
  echo "$detail_ids" | grep -qx "$id" \
    || say_fail "syllabus subphase $id has no detail block ('**$id:' or '### $id ...')"
done
for id in $detail_ids; do
  echo "$syl_ids" | grep -qx "$id" || say_fail "detail block $id has no syllabus checkbox"
done
for id in $syl_ids; do
  n=$(grep -cE "${detail_open}${id//./\\.}${detail_close}" "$plan")
  [ "$n" -le 1 ] || say_fail "subphase $id has $n detail blocks (must be exactly 1)"
done

# --- 4. (after:) targets are real IDs --------------------------------------
edges=""  # "from to" pairs
while IFS= read -r line; do
  id=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+:' | head -1 | tr -d ':')
  afters=$(echo "$line" | grep -oE '\(after:[^)]*\)' | grep -oE '[0-9]+\.[0-9]+' || true)
  for a in $afters; do
    echo "$syl_ids" | grep -qx "$a" || say_fail "subphase $id depends on nonexistent ID $a"
    edges="$edges$id $a\n"
  done
done < <(echo "$syllabus" | grep -E '^\s+- \[')

# --- 5. acyclic dependency graph -------------------------------------------
if [ -n "$edges" ]; then
  if ! printf '%b' "$edges" | awk '
    NF==2 { adj[$1] = adj[$1] " " $2; nodes[$1]=1; nodes[$2]=1 }
    function visit(n,   i, k, parts) {
      if (state[n] == 1) { return 1 }         # back-edge: cycle
      if (state[n] == 2) { return 0 }
      state[n] = 1
      split(adj[n], parts, " ")
      for (i in parts) { k = parts[i]; if (k != "" && visit(k)) return 1 }
      state[n] = 2; return 0
    }
    END { for (n in nodes) if (visit(n)) { print "cycle involving " n; exit 1 } }
  ' >/dev/null; then
    say_fail "dependency graph has a cycle in its (after:) edges"
  fi
fi

echo "INFO: lane file-scope disjointness is not machine-checked — verify scopes in the detail blocks."
if [ "$fail" = 0 ]; then
  echo "OK: plan is structurally valid ($(echo "$syl_ids" | wc -l | tr -d ' ') subphases)"
fi
exit "$fail"
