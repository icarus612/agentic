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
#     6. The plan carries a well-formed ask-of-record declaration, in its
#        preamble or its '## Goal & scope' section: a path-shaped backticked
#        token that resolves to a real file (Form P), or an explicit
#        no-durable-ask statement (Form N). Schema only — whether the plan is
#        actually FAITHFUL to that ask is the reviewer's judgement, not this
#        script's.
#   Lane file-scope disjointness is NOT machine-checked (scopes are prose in
#   the detail blocks) — that stays with the reviewer, flagged as INFO.
#   Ask-vs-plan FAITHFULNESS is likewise NOT machine-checked (only the
#   declaration's schema is) — that companion judgement also stays with the
#   reviewer, flagged as INFO.
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

# --- 6. ask-of-record declaration (schema only) -----------------------------
# Search region: the union of the preamble (lines before the first '## '
# heading) and the '## Goal & scope' section (that heading to the next
# '## '). Both locations are conforming per plan-format; the union preserves
# document order since the preamble always precedes any '## ' section.
preamble=$(awk '/^## /{exit} {print}' "$plan")
goal_scope=$(awk '/^## Goal & scope/{f=1;next} /^## /{if(f)exit} f' "$plan")
ask_region=$(printf '%s\n%s\n' "$preamble" "$goal_scope")

# A declaration line carries the phrase 'ask of record' (case-insensitive) in
# one of three markups: a bold lead-in ('**The ask of record:** ...' /
# '**Ask of record:** ...'), a markdown heading ('### Ask of record' ..
# '###### Ask of record', levels 3-6 only), or a list bullet
# ('- Ask of record: ...' / '- **Ask of record:** ...' /
# '  - Ask of record — ...'). Matching only one markup would fail every plan
# written in another — the same tolerance detail_open/detail_close already
# applies above. Level 2 is excluded on purpose: a '## Ask of record' heading
# would itself be a top-level section, colliding with the syllabus-first
# check and unreachable by either search window above.
ask_decl_regex='^(\*\*[^*]*ask of record[^*]*\*\*|#{3,6}[[:space:]]+.*ask of record|[[:space:]]*-[[:space:]]+.*ask of record)'
ask_decl_line=$(echo "$ask_region" | grep -im1 -E "$ask_decl_regex" || true)

if [ -z "$ask_decl_line" ]; then
  say_fail "no ask-of-record declaration found — the preamble or '## Goal & scope' must carry one (see plan-format)"
else
  # Form P precedence: the first path-shaped backticked token (contains '/'
  # or ends '.md') wins even if a negative marker also appears on the line.
  ask_path=""
  while IFS= read -r tok; do
    tok="${tok#\`}"; tok="${tok%\`}"
    case "$tok" in
      */*|*.md) ask_path="$tok"; break ;;
    esac
  done < <(echo "$ask_decl_line" | grep -oE '`[^`]+`')

  if [ -n "$ask_path" ]; then
    # Path resolution: as given if absolute; else relative to the plan
    # file's own directory; else relative to the cwd. First hit wins.
    case "$ask_path" in
      /*) ask_resolved="$ask_path" ;;
      *)
        plan_dir=$(dirname -- "$plan")
        if [ -f "$plan_dir/$ask_path" ]; then
          ask_resolved="$plan_dir/$ask_path"
        else
          ask_resolved="$ask_path"
        fi
        ;;
    esac
    [ -f "$ask_resolved" ] \
      || say_fail "ask-of-record declaration points to a path that does not exist: $ask_path"
  elif echo "$ask_decl_line" | grep -qiE 'no durable ask|no ask of record|not captured|conversation context|\bnone\b'; then
    : # Form N: an explicit no-durable-ask statement.
  else
    say_fail "ask-of-record declaration is malformed — the path or no-durable-ask statement must be on the declaration line itself, not a following line: $ask_decl_line"
  fi
fi

echo "INFO: lane file-scope disjointness is not machine-checked — verify scopes in the detail blocks."
echo "INFO: ask-vs-plan faithfulness is not machine-checked — only the declaration's schema is; that companion judgement is the reviewer's."
if [ "$fail" = 0 ]; then
  echo "OK: plan is structurally valid ($(echo "$syl_ids" | wc -l | tr -d ' ') subphases)"
fi
exit "$fail"
