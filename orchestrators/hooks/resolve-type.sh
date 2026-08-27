#!/usr/bin/env bash
# resolve-type.sh — resolve a dae run type to its five axes, before setup.
#
# SYNOPSIS
#   resolve-type.sh [<type>] [--t[ype] <t>] [--exp[lore] <v>] [--rig[or] <spec>]
#                   [--ag[ainst] <a>[,<a>...]]... [--pl[an] <path>]
#                   [--yaml <path>]
#
# DESCRIPTION
#   Every dae type is a preset over five axes (pipeline, explore, rigor,
#   against, ship). The presets live in the type table
#   ../skills/dae/workflows.yaml, one flow-map row per type. This script is
#   the ONLY reader of that table: it resolves a type name or alias to its
#   row, applies the free-tier flag overrides (--explore, --rigor),
#   validates the constrained and locked axes (--against arity, --plan
#   placement, --pipeline and --ship are locked), and prints the resolved
#   axes as KEY=value lines on stdout for the router to consume. The router
#   never interprets the yaml itself.
#
#   The table is parsed with bash builtins and awk only — no jq, no YAML
#   library, matching this repo's other hooks (resolve-config.sh:21). That is
#   why every row is a one-line flow map; a block mapping will not parse.
#
#   Pure: it reads the table and argv, prints, and exits. No git, no network,
#   no filesystem writes. Anchors are passed through raw — resolving them
#   (git ref / Jira / plan path) belongs to resolve-anchor.sh, not here — and
#   --plan is checked for placement only, never for existence.
#
#   A rigor entry naming a phase this run does not have (e.g. `pr:high` on a
#   report pipeline shipping to chat) is a WARNING, not an error: the entry is
#   dropped, a warning naming the phase and the type goes to stderr, and
#   resolution continues to a normal exit 0.
#
# EXIT CODES
#   0 - resolved (KEY=value block on stdout; any dropped-phase warnings on stderr)
#   1 - unknown flag or type, missing value, constraint violation, malformed
#       or unreadable table
set -uo pipefail

err() { echo "resolve-type: $*" >&2; exit 1; }
warn() { echo "resolve-type: warning: $*" >&2; }

# --- small string helpers (no subshells: err must abort the whole script) ---
trim() { # trim <string> -> TRIM
  TRIM="$1"
  TRIM="${TRIM#"${TRIM%%[![:space:]]*}"}"
  TRIM="${TRIM%"${TRIM##*[![:space:]]}"}"
}

split_commas() { # split_commas <string> -> SPLIT[] (empty items preserved)
  SPLIT=()
  local s="$1" item
  while :; do
    case "$s" in
      *,*) item="${s%%,*}"; s="${s#*,}"; SPLIT+=("$item") ;;
      *)   SPLIT+=("$s"); break ;;
    esac
  done
}

# Split a flow-map body on DEPTH-0 commas only, so `rigor: {explore: med}` and
# `aliases: [bug]` survive intact.
split_cells() { # split_cells <inner> -> CELLS[]
  CELLS=()
  local s="$1" depth=0 cur="" i c
  for (( i=0; i<${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      '{'|'[') depth=$((depth+1)); cur="$cur$c" ;;
      '}'|']') depth=$((depth-1)); cur="$cur$c" ;;
      ',')     if [ "$depth" -eq 0 ]; then CELLS+=("$cur"); cur=""; else cur="$cur$c"; fi ;;
      *)       cur="$cur$c" ;;
    esac
  done
  CELLS+=("$cur")
}

# Take everything from the row's FIRST `{` to its LAST `}` — a trailing
# `# comment` after the closing brace never reaches the parse.
flow_inner() { # flow_inner <raw> -> INNER ; 1 when the value is not a flow map
  local s="$1"
  INNER=""
  case "$s" in *'{'*) ;; *) return 1 ;; esac
  s="${s#*\{}"
  case "$s" in *'}'*) ;; *) return 1 ;; esac
  INNER="${s%\}*}"
  return 0
}

cell_value() { # cell_value <inner> <key> -> CELLVAL ; 1 when the key is absent
  CELLVAL=""
  local key="$2" cell k
  split_cells "$1"
  for cell in ${CELLS[@]+"${CELLS[@]}"}; do
    trim "$cell"; cell="$TRIM"
    [ -n "$cell" ] || continue
    case "$cell" in *:*) ;; *) continue ;; esac
    k="${cell%%:*}"
    trim "$k"; k="$TRIM"
    [ "$k" = "$key" ] || continue
    trim "${cell#*:}"; CELLVAL="$TRIM"
    return 0
  done
  return 1
}

in_list() { # in_list <needle> <space-separated haystack>
  local needle="$1" item
  for item in $2; do [ "$item" = "$needle" ] && return 0; done
  return 1
}

join_comma() { # join_comma <item>... -> JOINED (", "-separated; no subshell)
  local item first=1
  JOINED=""
  for item in "$@"; do
    if [ "$first" -eq 1 ]; then JOINED="$item"; first=0; else JOINED="$JOINED, $item"; fi
  done
}

VOCAB_PIPELINE="build plan report docs"
VOCAB_EXPLORE="shallow deep auto"
VOCAB_SHIP="chat publish"
VOCAB_AGAINST="require optional forbid"
VOCAB_RIGOR="low med high"
VOCAB_PHASE="explore plan code pr"

# --- flag resolution: aliases and bracketed prefixes, BEFORE validation -----
# A `--…` token resolves to the unique long form it is a prefix of AND whose
# bracket minimum it is at least as long as. Below-minimum tokens (`--r`, which
# used to be `--ref`; `--p`, which is below both `--pl` and `--pi`) are unknown
# flags — never guessed at. `--yaml` is internal and matches exactly.
FLAG_TABLE="--type:--t --explore:--exp --rigor:--rig --against:--ag --ship:--sh --plan:--pl --pipeline:--pi"

resolve_flag() { # resolve_flag <token> -> CANON
  local tok="$1" entry long min matches="" count=0
  CANON=""
  case "$tok" in
    --yaml) CANON="yaml"; return 0 ;;
    -t) CANON="type"; return 0 ;;
    -e) CANON="explore"; return 0 ;;
    -r) CANON="rigor"; return 0 ;;
    -a) CANON="against"; return 0 ;;
    --*) ;;
    *) err "unknown flag: '$tok' — did you mean one of --type, --explore, --rigor, --against, --plan?" ;;
  esac
  for entry in $FLAG_TABLE; do
    long="${entry%%:*}"; min="${entry##*:}"
    [ "${long:0:${#tok}}" = "$tok" ] || continue
    [ "${#tok}" -ge "${#min}" ] || continue
    matches="$matches $long"; count=$((count+1))
  done
  [ "$count" -ne 0 ] || err "unknown flag: '$tok' — did you mean one of --type, --explore, --rigor, --against, --plan? (short forms need at least --t, --exp, --rig, --ag, --pl)"
  [ "$count" -eq 1 ] || err "ambiguous flag: '$tok' matches$matches — which one did you mean?"
  trim "$matches"; long="$TRIM"
  CANON="${long#--}"
  return 0
}

# --- argv ------------------------------------------------------------------
type_name=""; positional_count=0
explore_override=""; have_explore=0
ship_given=0
plan_path=""; have_plan=0
pipeline_given=0
yaml_path=""
rigor_items=(); anchors=()

set_type() { # set_type <value>
  if [ -n "$type_name" ] && [ "$type_name" != "$1" ]; then
    err "conflicting type: '$type_name' and '$1' were both given — which one did you mean?"
  fi
  type_name="$1"
}

while [ $# -gt 0 ]; do
  tok="$1"
  case "$tok" in
    -*)
      resolve_flag "$tok"
      canon="$CANON"
      # Every recognised flag takes a separate-argument value.
      if [ $# -lt 2 ]; then
        err "missing value for --$canon (given as '$tok') — what value should it take?"
      fi
      val="$2"
      case "$val" in
        -*) err "missing value for --$canon (given as '$tok') — '$val' looks like another flag, not a value; what value should it take?" ;;
      esac
      shift 2
      case "$canon" in
        type)     set_type "$val" ;;
        explore)  explore_override="$val"; have_explore=1 ;;
        ship)     ship_given=1 ;;
        plan)     plan_path="$val"; have_plan=1 ;;
        pipeline) pipeline_given=1 ;;
        yaml)     yaml_path="$val" ;;
        rigor)
          split_commas "$val"
          for item in ${SPLIT[@]+"${SPLIT[@]}"}; do
            trim "$item"; rigor_items+=("$TRIM")
          done
          ;;
        against)
          split_commas "$val"
          for item in ${SPLIT[@]+"${SPLIT[@]}"}; do
            trim "$item"
            [ -n "$TRIM" ] || err "empty anchor in --against '$val' — a silently dropped anchor is worse than an error; drop the stray comma or name the anchor you meant?"
            anchors+=("$TRIM")
          done
          ;;
      esac
      ;;
    *)
      positional_count=$((positional_count+1))
      [ "$positional_count" -le 1 ] || err "unexpected argument: '$tok' — the type is a single leading argument; did you mean to pass '$tok' to a flag such as --against?"
      set_type "$tok"
      shift
      ;;
  esac
done

# --- table -----------------------------------------------------------------
scriptdir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
[ -n "$yaml_path" ] || yaml_path="$scriptdir/../skills/dae/workflows.yaml"
[ -f "$yaml_path" ] && [ -r "$yaml_path" ] || err "cannot read the type table at '$yaml_path' — is the path right, and does workflows.yaml exist there?"

# One `<key><TAB><raw value>` line per entry under `types:`. The raw value is
# judged in bash so a non-flow-map row can be reported as malformed (E15)
# rather than silently skipped.
rows=$(awk '
  /^[[:space:]]*#/ { next }
  /^types:[[:space:]]*$/ { intypes = 1; next }
  intypes && /^[^[:space:]]/ { intypes = 0 }
  intypes {
    line = $0
    sub(/^[[:space:]]+/, "", line)
    if (line == "") next
    ci = index(line, ":")
    if (ci == 0) next
    key = substr(line, 1, ci - 1)
    rest = substr(line, ci + 1)
    sub(/^[[:space:]]+/, "", rest)
    print key "\t" rest
  }
' "$yaml_path")

# Derive the type/alias/pipeline lists used in error messages straight from
# $rows — never a hardcoded literal (§3.10, B13). Best-effort: a row whose raw
# value is not a flow map is simply skipped here (its malformedness is
# reported separately, on the row-parse path below, if it is the resolved
# row).
all_types=(); all_aliases=(); build_types=(); require_types=()
chat_types=(); publish_types=()
while IFS=$'\t' read -r key raw; do
  [ -n "$key" ] || continue
  all_types+=("$key")
  flow_inner "$raw" || continue
  if cell_value "$INNER" "pipeline"; then
    [ "$CELLVAL" != "build" ] || build_types+=("$key")
  fi
  if cell_value "$INNER" "against"; then
    [ "$CELLVAL" != "require" ] || require_types+=("$key")
  fi
  if cell_value "$INNER" "ship"; then
    [ "$CELLVAL" != "chat" ]    || chat_types+=("$key")
    [ "$CELLVAL" != "publish" ] || publish_types+=("$key")
  fi
  if cell_value "$INNER" "aliases"; then
    alias_list="$CELLVAL"
    alias_list="${alias_list#\[}"; alias_list="${alias_list%\]}"
    split_commas "$alias_list"
    for item in ${SPLIT[@]+"${SPLIT[@]}"}; do
      trim "$item"
      [ -n "$TRIM" ] || continue
      all_aliases+=("$TRIM")
    done
  fi
done <<< "$rows"

default_type=$(sed -n 's/^default_type:[[:space:]]*\([^#[:space:]]*\).*$/\1/p' "$yaml_path" | head -1)
[ -n "$type_name" ] || type_name="$default_type"
[ -n "$type_name" ] || err "no type given and the table at '$yaml_path' carries no default_type — which type did you mean?"

# --- resolve the type name: exact key first, then aliases ------------------
resolved_type=""; row_raw=""
while IFS=$'\t' read -r key raw; do
  [ -n "$key" ] || continue
  if [ "$key" = "$type_name" ]; then resolved_type="$key"; row_raw="$raw"; break; fi
done <<< "$rows"

if [ -z "$resolved_type" ]; then
  while IFS=$'\t' read -r key raw; do
    [ -n "$key" ] || continue
    flow_inner "$raw" || continue
    cell_value "$INNER" "aliases" || continue
    alias_list="$CELLVAL"
    alias_list="${alias_list#\[}"; alias_list="${alias_list%\]}"
    split_commas "$alias_list"
    for item in ${SPLIT[@]+"${SPLIT[@]}"}; do
      trim "$item"
      if [ "$TRIM" = "$type_name" ]; then resolved_type="$key"; row_raw="$raw"; break; fi
    done
    [ -z "$resolved_type" ] || break
  done <<< "$rows"
fi

if [ -z "$resolved_type" ]; then
  [ "${#all_types[@]}" -gt 0 ] || err "unknown type: '$type_name' — the table at '$yaml_path' parsed to zero types (an empty or broken 'types:' block) — which did you mean?"
  join_comma ${all_types[@]+"${all_types[@]}"}; types_str="$JOINED"
  if [ "${#all_aliases[@]}" -gt 0 ]; then
    join_comma ${all_aliases[@]+"${all_aliases[@]}"}; aliases_str="$JOINED"
    err "unknown type: '$type_name' — the table has $types_str (plus the aliases $aliases_str); which did you mean?"
  fi
  err "unknown type: '$type_name' — the table has $types_str; which did you mean?"
fi

# --- parse the row ---------------------------------------------------------
flow_inner "$row_raw" || err "malformed row for type '$resolved_type': the value is not a one-line flow map '{…}' — fix that row in the type table?"
row_inner="$INNER"

row_cell() { # row_cell <key> -> CELLVAL ; 1 when absent
  cell_value "$row_inner" "$1"
}

require_cell() { # require_cell <key> -> CELLVAL
  row_cell "$1" || err "malformed row for type '$resolved_type': required key '$1' is missing — add it to that row in the type table?"
  [ -n "$CELLVAL" ] || err "malformed row for type '$resolved_type': required key '$1' has no value — what should it be?"
}

require_cell "pipeline"; pipeline="$CELLVAL"
in_list "$pipeline" "$VOCAB_PIPELINE" || err "malformed row for type '$resolved_type': key 'pipeline' has value '$pipeline', which is not one of $VOCAB_PIPELINE — which did you mean?"

require_cell "explore"; explore="$CELLVAL"
in_list "$explore" "$VOCAB_EXPLORE" || err "malformed row for type '$resolved_type': key 'explore' has value '$explore', which is not one of $VOCAB_EXPLORE — which did you mean?"

require_cell "against"; against_rule="$CELLVAL"
in_list "$against_rule" "$VOCAB_AGAINST" || err "malformed row for type '$resolved_type': key 'against' has value '$against_rule', which is not one of $VOCAB_AGAINST — which did you mean?"

require_cell "ship"; ship="$CELLVAL"
in_list "$ship" "$VOCAB_SHIP" || err "malformed row for type '$resolved_type': key 'ship' has value '$ship', which is not one of $VOCAB_SHIP — which did you mean?"

require_cell "rigor"; row_rigor="$CELLVAL"

planner=""; have_planner=0
if row_cell "planner"; then planner="$CELLVAL"; have_planner=1; fi
branch=""; have_branch=0
if row_cell "branch"; then branch="$CELLVAL"; have_branch=1; fi

# --- free-tier overrides ---------------------------------------------------
if [ "$have_explore" = 1 ]; then
  in_list "$explore_override" "$VOCAB_EXPLORE" || err "explore value '$explore_override' is not one of shallow, deep, auto — which did you mean?"
  explore="$explore_override"
fi

# --- f(pipeline, ship): which rigor phases this run HAS ---------------------
has_explore_phase=1; has_plan_phase=0; has_code_phase=0; has_pr_phase=0
case "$pipeline" in
  build|plan) has_plan_phase=1; has_code_phase=1; has_pr_phase=1 ;;
  docs)       has_pr_phase=1 ;;
  report)     [ "$ship" = "publish" ] && has_pr_phase=1 ;;
esac

# --- rigor: row default, then the user spec (scalar first, then patches) ----
rigor_explore="low"; rigor_plan="low"; rigor_code="low"; rigor_pr="low"
named_explore=0; named_plan=0; named_code=0; named_pr=0

set_rigor() { # set_rigor <phase> <value>
  case "$1" in
    explore) rigor_explore="$2" ;;
    plan)    rigor_plan="$2" ;;
    code)    rigor_code="$2" ;;
    pr)      rigor_pr="$2" ;;
  esac
}
mark_named() { # mark_named <phase>
  case "$1" in
    explore) named_explore=1 ;;
    plan)    named_plan=1 ;;
    code)    named_code=1 ;;
    pr)      named_pr=1 ;;
  esac
}

# Step 1 — the row's profile. A scalar expands to all four phases (silently);
# the map form bases at all-low and patches the phases it names.
case "$row_rigor" in
  '{'*)
    flow_inner "$row_rigor" || err "malformed row for type '$resolved_type': key 'rigor' is not a flow map '{…}' — fix that row in the type table?"
    split_cells "$INNER"
    for cell in ${CELLS[@]+"${CELLS[@]}"}; do
      trim "$cell"; cell="$TRIM"
      [ -n "$cell" ] || continue
      case "$cell" in *:*) ;; *) err "malformed row for type '$resolved_type': key 'rigor' has entry '$cell', which is not '<phase>: <value>' — what did you mean there?" ;; esac
      trim "${cell%%:*}"; phase="$TRIM"
      trim "${cell#*:}"; value="$TRIM"
      in_list "$phase" "$VOCAB_PHASE" || err "malformed row for type '$resolved_type': key 'rigor' names phase '$phase', which is not one of $VOCAB_PHASE — which did you mean?"
      in_list "$value" "$VOCAB_RIGOR" || err "malformed row for type '$resolved_type': key 'rigor' gives phase '$phase' the value '$value', which is not one of $VOCAB_RIGOR — which did you mean?"
      set_rigor "$phase" "$value"
      mark_named "$phase"
    done
    ;;
  *)
    in_list "$row_rigor" "$VOCAB_RIGOR" || err "malformed row for type '$resolved_type': key 'rigor' has value '$row_rigor', which is not one of $VOCAB_RIGOR — which did you mean?"
    rigor_explore="$row_rigor"; rigor_plan="$row_rigor"; rigor_code="$row_rigor"; rigor_pr="$row_rigor"
    ;;
esac

# Step 2 — scalars apply BEFORE all phase patches, regardless of where they
# fall in the spec string. Two passes over the collected items (repeated
# --rigor flags append to one list, so "the spec" is the whole list, not any
# one flag's value):
#
#   pass A (step 2): scan every item for a bare scalar. If one or more exist,
#   the LAST bare scalar in the whole list sets all four phases, replacing
#   the row default from step 1. Position inside the spec string is
#   irrelevant — `explore:high,med` and `med,explore:high` reach this pass
#   with the same two items and the same outcome.
#
#   pass B (step 3): walk the <phase>:<value> items in argv order and patch
#   each named phase. A patch is a patch — an unmentioned phase keeps
#   whatever step 1 or the step-2 scalar left it at, and never falls to low
#   by fiat, and a patch is never re-wiped by a scalar that happens to sit
#   later in the string (there is no later pass that would do that).
#
# So `med,explore:high` is "everything med except explore", and
# `explore:high,med` is ALSO "everything med except explore" — the scalar is
# applied first (pass A), then the patch (pass B), independent of order.
#
# Both passes together validate every item exactly once (each item is a
# scalar or a <phase>:<value> pair, never both), so an item a later-processed
# scalar would have overwritten under naive argv order is still validated.
scalar_value=""; have_scalar=0
for item in ${rigor_items[@]+"${rigor_items[@]}"}; do
  case "$item" in
    *:*) ;;
    *)
      in_list "$item" "$VOCAB_RIGOR" || err "rigor value '$item' is not one of low, med, high — which did you mean?"
      scalar_value="$item"; have_scalar=1
      ;;
  esac
done
if [ "$have_scalar" = 1 ]; then
  rigor_explore="$scalar_value"; rigor_plan="$scalar_value"; rigor_code="$scalar_value"; rigor_pr="$scalar_value"
fi
for item in ${rigor_items[@]+"${rigor_items[@]}"}; do
  case "$item" in
    *:*)
      trim "${item%%:*}"; phase="$TRIM"
      trim "${item#*:}"; value="$TRIM"
      in_list "$phase" "$VOCAB_PHASE" || err "rigor phase '$phase' is not one of explore, plan, code, pr — which phase did you mean?"
      in_list "$value" "$VOCAB_RIGOR" || err "rigor value '$value' is not one of low, med, high — which did you mean?"
      set_rigor "$phase" "$value"
      mark_named "$phase"
      ;;
    *) ;;
  esac
done

# Step 4 — drop the phases this run does not have. A phase EXPLICITLY named by
# a <phase>:<value> entry — from the user spec or the row's map cell, the two
# are not distinguished — warns and is dropped; the run continues. A scalar
# expansion names nothing, so it drops silently.
drop_phase() { # drop_phase <phase> <named?>
  [ "$2" = 1 ] || return 0
  warn "rigor phase '$1' does not exist for type '$resolved_type' (pipeline $pipeline, ship $ship) — dropped; the run continues."
}
[ "$has_explore_phase" = 1 ] || drop_phase "explore" "$named_explore"
[ "$has_plan_phase" = 1 ] || drop_phase "plan" "$named_plan"
[ "$has_code_phase" = 1 ] || drop_phase "code" "$named_code"
[ "$has_pr_phase" = 1 ] || drop_phase "pr" "$named_pr"

# --- constraints: locked, then placement, then arity -----------------------
# Placement is judged before arity so that a misplaced --plan is reported as
# such even on a type that also wants an anchor — the flag that cannot belong
# here at all is the more useful thing to say first.
[ "$pipeline_given" = 0 ] || err "--pipeline is locked: a type IS its pipeline, and type '$resolved_type' is pipeline '$pipeline' — pick the type whose pipeline you want instead?"

if [ "$ship_given" = 1 ]; then
  ship_parts=()
  if [ "${#chat_types[@]}" -gt 0 ]; then
    join_comma ${chat_types[@]+"${chat_types[@]}"}; chat_str="$JOINED"
    ship_parts+=("for a chat answer run $chat_str")
  fi
  if [ "${#publish_types[@]}" -gt 0 ]; then
    join_comma ${publish_types[@]+"${publish_types[@]}"}; publish_str="$JOINED"
    ship_parts+=("for a published report run $publish_str")
  fi
  if [ "${#ship_parts[@]}" -gt 0 ]; then
    join_comma ${ship_parts[@]+"${ship_parts[@]}"}; ship_parts_str="$JOINED"
    err "--ship is locked: a type IS its ship mode, and type '$resolved_type' ships '$ship' — $ship_parts_str?"
  fi
  err "--ship is locked: a type IS its ship mode, and type '$resolved_type' ships '$ship' — pick the type whose ship mode you want instead?"
fi

if [ "$have_plan" = 1 ] && [ "$pipeline" != "build" ]; then
  if [ "${#build_types[@]}" -eq 0 ]; then
    err "--plan is accepted only on a 'pipeline: build' type, and type '$resolved_type' is pipeline '$pipeline' — drop --plan (the table at '$yaml_path' defines no pipeline: build type at all)?"
  fi
  join_comma ${build_types[@]+"${build_types[@]}"}; build_str="$JOINED"
  err "--plan is accepted only on a 'pipeline: build' type, and type '$resolved_type' is pipeline '$pipeline' — drop --plan, or run a build type such as $build_str?"
fi

anchor_count=${#anchors[@]}
case "$against_rule" in
  forbid)
    if [ "$anchor_count" -ne 0 ]; then
      if [ "${#require_types[@]}" -eq 0 ]; then
        err "type '$resolved_type' takes no anchors, but --against was given $anchor_count time(s) — passing anchors usually means another type was meant: did you mean a different type (the table at '$yaml_path' defines no against: require type at all)?"
      fi
      join_comma ${require_types[@]+"${require_types[@]}"}; require_str="$JOINED"
      err "type '$resolved_type' takes no anchors, but --against was given $anchor_count time(s) — passing anchors usually means another type was meant: did you mean $require_str?"
    fi
    ;;
  require)
    [ "$anchor_count" -gt 0 ] || err "type '$resolved_type' requires at least one anchor — what should it be compared against? Pass it with --against <anchor>."
    ;;
esac

# --- output ----------------------------------------------------------------
echo "TYPE=$resolved_type"
echo "PIPELINE=$pipeline"
echo "EXPLORE=$explore"
[ "$has_explore_phase" = 1 ] && echo "RIGOR_EXPLORE=$rigor_explore"
[ "$has_plan_phase" = 1 ] && echo "RIGOR_PLAN=$rigor_plan"
[ "$has_code_phase" = 1 ] && echo "RIGOR_CODE=$rigor_code"
[ "$has_pr_phase" = 1 ] && echo "RIGOR_PR=$rigor_pr"
echo "AGAINST_COUNT=$anchor_count"
i=0
for anchor in ${anchors[@]+"${anchors[@]}"}; do
  i=$((i+1))
  echo "AGAINST_$i=$anchor"
done
echo "SHIP=$ship"
[ "$have_planner" = 1 ] && echo "PLANNER=$planner"
[ "$have_branch" = 1 ] && echo "BRANCH=$branch"
[ "$have_plan" = 1 ] && echo "PLAN=$plan_path"
exit 0
