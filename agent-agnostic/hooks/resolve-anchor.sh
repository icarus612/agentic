#!/usr/bin/env bash
# resolve-anchor.sh — resolve a --against anchor array into typed pointers.
#
# SYNOPSIS
#   resolve-anchor.sh --against <item[,item...]> [--against <item[,item...]>]... [--base <ref>] [--root <path>]
#
# DESCRIPTION
#   Turns a repeatable, comma-separable --against array into typed anchors
#   and emits the `anchors:` block that lands in plan front-matter and the
#   progress log. Items are collected left to right across flags, and left
#   to right within each comma-separated flag; order is preserved end to
#   end and duplicates are kept, never deduplicated.
#
#   Classification is first-match-wins, per item, in this order:
#     1. plan — the item names something that exists on the filesystem
#        (tested as given when absolute, else under --root).
#     2. jira — the item matches ^[A-Z][A-Z0-9]*-[0-9]+$. This is SHAPE
#        ONLY: a hook has no network access and no MCP, so ticket
#        existence is never checked, only the key's shape.
#     3. git — a range (contains "..." or ".." — "..." is tested first, it
#        is the longer separator; both endpoints must be non-empty, so
#        git's implicit-HEAD shorthand "A..", "..B", ".." is deliberately
#        NOT honored), a pull/merge request (#<n>, or a URL ending
#        /pull/<n>[/][?...][#...]), or a single ref resolvable by
#        `git rev-parse --verify`.
#     4. Anything else is unresolvable.
#
#   Resolution is all-or-nothing: every item is resolved into memory before
#   anything is printed, so one bad anchor never yields a partial
#   anchors: block on stdout. Stdout carries only that block; all progress
#   ("<raw> -> <kind> <resolved>") goes to stderr, so a caller can redirect
#   stdout straight into a front-matter file.
#
#   --base, when omitted, is resolved lazily (only if a git PR or single-ref
#   anchor needs one to build its range) via this repo's settings-chain
#   resolver: resolve-config.sh CLAUDE_BASE_BRANCH --base-branch-default.
#   --root defaults to `git rev-parse --show-toplevel`, else $PWD.
#
#   No jq, no new runtime dependency: awk/sed/grep/git only, composing
#   absolute paths with `cd ... && pwd` (no realpath, no readlink -f).
#
# EXIT CODES
#   0 - every anchor resolved; the anchors: block is on stdout
#   1 - any anchor unresolvable, or bad usage (nothing on stdout)
set -uo pipefail

err() { echo "resolve-anchor: $*" >&2; exit 1; }

hookdir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# --- args --------------------------------------------------------------
base=""
have_base=0
root=""
items=()

# split_csv <string> — appends each comma-separated, trimmed field of
# <string> to the global `items` array. Handles empty fields (leading,
# trailing, or consecutive commas) correctly, unlike `read -a`/IFS
# splitting, which silently drops empty trailing fields.
split_csv() {
  local s="$1" part
  while [[ "$s" == *,* ]]; do
    part="${s%%,*}"
    s="${s#*,}"
    part="${part#"${part%%[![:space:]]*}"}"
    part="${part%"${part##*[![:space:]]}"}"
    items+=("$part")
  done
  part="$s"
  part="${part#"${part%%[![:space:]]*}"}"
  part="${part%"${part##*[![:space:]]}"}"
  items+=("$part")
}

while [ $# -gt 0 ]; do
  case "$1" in
    --against)
      [ $# -ge 2 ] || err "--against requires a value"
      split_csv "$2"
      shift 2
      ;;
    --base) base="${2:-}"; have_base=1; shift 2 ;;
    --root) root="${2:-}"; shift 2 ;;
    *) err "unknown flag: $1" ;;
  esac
done

[ "${#items[@]}" -gt 0 ] || err "usage: resolve-anchor.sh --against <item[,item...]> [--against <item[,item...]>]... [--base <ref>] [--root <path>]"

pos=0
for raw in "${items[@]}"; do
  pos=$((pos + 1))
  [ -n "$raw" ] || err "empty --against item at position $pos"
done

[ -n "$root" ] || root=$(git rev-parse --show-toplevel 2>/dev/null) || root="$PWD"

# --- lazy base resolution (only when a git PR/single-ref item needs one) ---
resolve_base() {
  [ "$have_base" = 1 ] && return 0
  base=$("$hookdir/resolve-config.sh" CLAUDE_BASE_BRANCH --base-branch-default --root "$root" 2>/dev/null) \
    || err "cannot resolve a base branch for a git anchor's range — pass --base <ref>"
  have_base=1
}

# --- absolute path composition, no realpath/readlink -f ---------------------
abs_path() { # abs_path <existing path> -> prints absolute path
  local p="$1" d b
  if [ -d "$p" ]; then
    (cd "$p" && pwd)
  else
    d=$(dirname -- "$p")
    b=$(basename -- "$p")
    printf '%s/%s' "$(cd "$d" && pwd)" "$b"
  fi
}

# --- resolve every item into memory first (all-or-nothing) -----------------
out_kind=()
out_raw=()
out_resolved=()
out_range=()
out_has_range=()

pos=0
for raw in "${items[@]}"; do
  pos=$((pos + 1))

  # 1. plan — exists on the filesystem
  case "$raw" in
    /*) candidate="$raw" ;;
    *) candidate="$root/$raw" ;;
  esac
  if [ -e "$candidate" ]; then
    out_kind+=("plan")
    out_raw+=("$raw")
    out_resolved+=("$(abs_path "$candidate")")
    out_range+=("")
    out_has_range+=(0)
    continue
  fi

  # 2. jira — shape only, no network, no MCP
  if [[ "$raw" =~ ^[A-Z][A-Z0-9]*-[0-9]+$ ]]; then
    out_kind+=("jira")
    out_raw+=("$raw")
    out_resolved+=("$raw")
    out_range+=("")
    out_has_range+=(0)
    continue
  fi

  # 3. git
  matched=0

  # 3a. range — test "..." before ".."; both endpoints non-empty and
  # verifiable. git's implicit-HEAD shorthand (A.., ..B, ..) is NOT honored.
  if [[ "$raw" == *"..."* ]] || [[ "$raw" == *".."* ]]; then
    if [[ "$raw" == *"..."* ]]; then
      sep="..."
      left="${raw%%...*}"
      right="${raw#*...}"
    else
      sep=".."
      left="${raw%%..*}"
      right="${raw#*..}"
    fi
    if [ -n "$left" ] && [ -n "$right" ] \
      && sha_l=$(git -C "$root" rev-parse --verify -q "${left}^{commit}" 2>/dev/null) \
      && sha_r=$(git -C "$root" rev-parse --verify -q "${right}^{commit}" 2>/dev/null); then
      out_kind+=("git")
      out_raw+=("$raw")
      out_resolved+=("${sha_l}${sep}${sha_r}")
      out_range+=("$raw")
      out_has_range+=(1)
      matched=1
    else
      err "anchor at position $pos ('$raw') is unresolvable: not a path, not a ticket key, not a git ref (malformed range: both endpoints of '$sep' must be non-empty and resolvable)"
    fi
    [ "$matched" = 1 ] && continue
  fi

  # 3b. pull/merge request — #<n>, or a URL ending /pull/<n>[/][?...][#...]
  prnum=""
  if [[ "$raw" =~ ^#([0-9]+)$ ]]; then
    prnum="${BASH_REMATCH[1]}"
  elif [[ "$raw" =~ ^.*/pull/([0-9]+)(/)?([?#].*)?$ ]]; then
    prnum="${BASH_REMATCH[1]}"
  fi
  if [ -n "$prnum" ]; then
    resolve_base
    sha=""
    for ref in "refs/pull/${prnum}/head" "refs/merge-requests/${prnum}/head"; do
      if sha=$(git -C "$root" rev-parse --verify -q "${ref}^{commit}" 2>/dev/null) && [ -n "$sha" ]; then
        break
      fi
      sha=""
    done
    if [ -n "$sha" ]; then
      out_kind+=("git")
      out_raw+=("$raw")
      out_resolved+=("$sha")
      out_range+=("${base}...${sha}")
      out_has_range+=(1)
      continue
    fi
    err "anchor at position $pos ('$raw') is unresolvable: not a path, not a ticket key, not a git ref (PR/MR #${prnum} has no local ref; fetch it first: git fetch origin refs/pull/${prnum}/head:refs/pull/${prnum}/head)"
  fi

  # 3c. single ref
  if sha=$(git -C "$root" rev-parse --verify -q "${raw}^{commit}" 2>/dev/null) && [ -n "$sha" ]; then
    resolve_base
    out_kind+=("git")
    out_raw+=("$raw")
    out_resolved+=("$sha")
    out_range+=("${base}...${raw}")
    out_has_range+=(1)
    continue
  fi

  # 4. nothing matched
  err "anchor at position $pos ('$raw') is unresolvable: not a path, not a ticket key, not a git ref"
done

# --- all resolved: emit progress lines, then the anchors: block ------------
n="${#out_kind[@]}"
i=0
while [ "$i" -lt "$n" ]; do
  if [ "${out_kind[$i]}" = "jira" ]; then
    echo "resolve-anchor: ${out_raw[$i]} -> ${out_kind[$i]} ${out_resolved[$i]} (shape only; ticket existence not checked)" >&2
  else
    echo "resolve-anchor: ${out_raw[$i]} -> ${out_kind[$i]} ${out_resolved[$i]}" >&2
  fi
  i=$((i + 1))
done

{
  echo "anchors:"
  i=0
  while [ "$i" -lt "$n" ]; do
    echo "  - kind: ${out_kind[$i]}"
    echo "    raw: ${out_raw[$i]}"
    echo "    resolved: ${out_resolved[$i]}"
    if [ "${out_has_range[$i]}" = 1 ]; then
      echo "    range: ${out_range[$i]}"
    fi
    i=$((i + 1))
  done
}
