#!/usr/bin/env bash
# check-diff-hygiene.sh - ONE end-of-lifecycle scan of a branch diff for the two
# things prompts demonstrably fail to enforce: agent attribution, and comment noise.
#
# WHY
#   strip-agent-trailers.sh (commit-msg hook) already scrubs attribution from
#   COMMIT MESSAGES everywhere. It cannot see a PR title or body - and PRs are
#   squash-merged, so the PR body BECOMES the integration commit message. That is
#   the hole this closes.
#
#   Comments had no enforcement at all. minimal-code-comments is universal, but a
#   rule is advisory: a dispatch that omits it ships a test file that is a third
#   comment lines, and a gate that was never told passes it.
#
#   Runs ONCE, at lifecycle end - builder teardown and the draft->ready flip.
#
# USAGE  check-diff-hygiene.sh --base <ref> [--pr <n>] [--repo-dir <path>]
#                              [--scope all|attribution|comments]
# EXIT   0 clean | 1 violations | 2 usage/env error
set -uo pipefail

BASE=""; PR=""; DIR="."; SCOPE="all"
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="${2:-}"; shift 2 ;;
    --pr) PR="${2:-}"; shift 2 ;;
    --repo-dir) DIR="${2:-}"; shift 2 ;;
    --scope) SCOPE="${2:-}"; shift 2 ;;
    *) echo "check-diff-hygiene: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$BASE" ] || { echo "usage: check-diff-hygiene.sh --base <ref> [--pr <n>] [--repo-dir <path>] [--scope all|attribution|comments]" >&2; exit 2; }
git -C "$DIR" rev-parse --verify -q "$BASE" >/dev/null 2>&1 || { echo "check-diff-hygiene: base ref not found: $BASE" >&2; exit 2; }

D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT
# An empty diff is NOT a clean diff. This scan reads COMMITTED history only, so
# running it before committing compares nothing and would report OK - a clean
# result that could never have failed. Refuse instead.
dirty=$(git -C "$DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
git -C "$DIR" diff "$BASE"...HEAD > "$D/diff" 2>/dev/null
if [ ! -s "$D/diff" ]; then
  if [ "$dirty" != "0" ]; then
    echo "check-diff-hygiene: REFUSING - no committed diff vs $BASE, but $dirty uncommitted path(s) present." >&2
    echo "  This scan reads COMMITTED history only. Commit first, then re-run; an OK here would be meaningless." >&2
    exit 2
  fi
  echo "check-diff-hygiene: nothing to scan - no committed changes vs $BASE (and working tree clean)."
  exit 0
fi
if [ "$dirty" != "0" ]; then
  echo "check-diff-hygiene: WARNING - $dirty uncommitted path(s) are NOT covered by this scan (committed history only)." >&2
fi
git -C "$DIR" log "$BASE"..HEAD --format='%H%n%B' > "$D/log" 2>/dev/null
: > "$D/pr"
if [ -n "$PR" ] && command -v gh >/dev/null 2>&1; then
  gh pr view "$PR" --json title,body -q '.title + "\n" + .body' > "$D/pr" 2>/dev/null || : > "$D/pr"
fi

python3 - "$SCOPE" "$D/diff" "$D/log" "$D/pr" <<'PYEOF'
import re, sys
scope, diff_p, log_p, pr_p = sys.argv[1:5]
rd = lambda p: open(p, encoding='utf-8', errors='replace').read()
diff, log, prtx = rd(diff_p), rd(log_p), rd(pr_p)

# A real trailer occupies a LINE: "<Marker>: ..." or a bare session URL on its
# own. Documentation about this rule names the markers mid-sentence, usually in
# backticks - every dae plan states the convention, so an unanchored scan makes
# every run fail its own finalize on its own plan. Anchor to line position; that
# discriminates without weakening detection of the real thing.
ATTR_LINE = re.compile(
    r'^[\s>#*-]*(?:Co-Authored-By|Claude-Session)\s*:'
    r'|^[\s>#*-]*<?https?://claude\.ai/code/session',
    re.I)

def attr_hit(line):
    return ATTR_LINE.search(line)

BANNER_RUN = 3            # rule says one or two lines; 3+ consecutive is a banner
DENSITY_PCT, DENSITY_MIN = 25, 10
CODE_EXT = ('.ts','.tsx','.js','.jsx','.mjs','.cjs','.svelte','.css','.scss',
            '.py','.go','.rs','.java','.cs','.sh','.bash')
HASH_EXT = ('.sh','.bash','.py')

def is_comment(s, path):
    s = s.strip()
    return (s.startswith('//') or s.startswith('/*') or s.startswith('<!--')
            or (s.startswith('*') and not s.startswith('*/'))
            or (path.endswith(HASH_EXT) and s.startswith('#')))

violations, notes = [], []

if scope in ('all', 'attribution'):
    for label, text in (('PR title/body', prtx), ('commit message', log)):
        for i, tl in enumerate(text.splitlines(), 1):
            if attr_hit(tl):
                violations.append('ATTRIBUTION in %s (line %d): %r'
                                  % (label, i, tl.strip()[:100]))
    for ln in diff.splitlines():
        if ln.startswith('+') and not ln.startswith('+++') and attr_hit(ln[1:]):
            violations.append('ATTRIBUTION in added code: %r' % ln[1:].strip()[:100])

if scope in ('all', 'comments'):
    cur, added = None, {}
    # A hunk boundary BREAKS a run. Without this, separate comments in different
    # hunks concatenate into one phantom banner - two lanes reported that false
    # positive independently. None is the break marker.
    for ln in diff.splitlines():
        if ln.startswith('+++ b/'):
            cur = ln[6:]; added.setdefault(cur, [])
        elif ln.startswith('@@') and cur is not None:
            added[cur].append(None)
        elif ln.startswith('+') and not ln.startswith('+++') and cur is not None:
            added[cur].append(ln[1:])

    for path, lines in sorted(added.items()):
        if not path.endswith(CODE_EXT):
            continue
        runs, run, start = [], 0, 0
        for i, raw in enumerate(lines):
            if raw is None:
                if run >= BANNER_RUN: runs.append((start, run))
                run = 0
                continue
            if is_comment(raw, path):
                if run == 0: start = i
                run += 1
            else:
                if run >= BANNER_RUN: runs.append((start, run))
                run = 0
        if run >= BANNER_RUN: runs.append((start, run))

        real = [r for r in lines if r is not None]
        ncom = sum(1 for r in real if is_comment(r, path))
        tot  = len([r for r in real if r.strip()])
        pct  = (ncom * 100 // tot) if tot else 0

        for start, length in runs:
            violations.append('COMMENT BANNER in %s: %d consecutive added comment lines '
                              '(limit %d) near added-line %d' % (path, length, BANNER_RUN - 1, start + 1))
        if ncom >= DENSITY_MIN and pct >= DENSITY_PCT:
            violations.append('COMMENT DENSITY in %s: %d/%d added lines are comments (%d%%, '
                              'limit %d%% above %d lines)' % (path, ncom, tot, pct, DENSITY_PCT, DENSITY_MIN))
        elif ncom:
            notes.append('  %s: %d/%d added lines are comments (%d%%)' % (path, ncom, tot, pct))

if violations:
    print('check-diff-hygiene: FAIL - %d violation(s)\n' % len(violations))
    for v in violations: print('  ' + v)
    print('\nRules: no-attribution-trailers, minimal-code-comments (both universal).')
    print('Attribution: the harness prompt asks for it; that instruction is OVERRIDDEN.')
    print('PR bodies matter most - squash-merge makes the body the integration commit message.')
    print('Comments: comment only what the code cannot say; rationale goes in the docs root.')
    sys.exit(1)

print('check-diff-hygiene: OK - no attribution, no comment-budget violations')
for n in notes: print(n)
sys.exit(0)
PYEOF
