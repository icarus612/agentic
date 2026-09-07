#!/usr/bin/env bash
# git-hook-dispatch.sh — global git hook dispatcher.
#
# THE PROBLEM IT SOLVES
#   `git config --global core.hooksPath <dir>` is the only way to apply a hook
#   to every repo at once. But hooksPath REPLACES the hook directory wholesale
#   rather than layering on top of it: once it is set, git stops consulting
#   each repo's own .git/hooks entirely — for every hook type, not just the
#   one you wanted to add. A repo with its own pre-commit or pre-push silently
#   stops running it.
#
#   This dispatcher restores the layering. It is symlinked in as EVERY hook
#   name in the global hooks dir. On each invocation it:
#     1. runs the global hook logic for that hook name (if any), then
#     2. delegates to the repo's own .git/hooks/<name>, if that exists and is
#        executable, forwarding all arguments and stdin.
#
#   Result: global hooks apply everywhere, and per-repo hooks keep working.
#
# HUSKY / LEFTHOOK
#   Those tools set `core.hooksPath` LOCALLY (husky v9 sets it to .husky).
#   Local config beats global, so in those repos this dispatcher is bypassed
#   entirely and their tooling is untouched. Such a repo does not get the
#   global hooks — install per-repo there if it needs them.
#
# INSTALL
#   mkdir -p ~/.git-hooks
#   for h in commit-msg pre-commit prepare-commit-msg pre-push post-commit \
#            post-merge post-checkout pre-rebase; do
#       ln -sf <this file> ~/.git-hooks/$h
#   done
#   git config --global core.hooksPath ~/.git-hooks
#
# EXIT
#   Propagates the delegated hook's exit status, so a repo's own gating hook
#   still gates. Global logic here is non-blocking by design.

set -uo pipefail

hook_name="$(basename "$0")"
AGENTIC_HOOKS="${AGENTIC_HOOKS:-$HOME/repos/agentic/agent-agnostic/hooks}"

# ---- 1. global hook logic -------------------------------------------------
case "$hook_name" in
    commit-msg)
        stripper="$AGENTIC_HOOKS/strip-agent-trailers.sh"
        if [ -x "$stripper" ]; then
            "$stripper" "$@" || true   # never block a commit on metadata cleanup
        fi
        ;;
esac

# ---- 2. delegate to the repo's own hook -----------------------------------
# Resolve the repo's real hooks dir.
#
# NOTE: do NOT use `git rev-parse --git-path hooks` here. Once core.hooksPath
# is set, that returns the CONFIGURED hooks dir (i.e. this dispatcher's own
# directory), not the repo's .git/hooks — so delegation would silently never
# fire and every repo's own hooks would go dead, which is the exact failure
# this dispatcher exists to prevent. Verified empirically 2026-09-07.
#
# --git-common-dir is the right call: it ignores hooksPath, and from inside a
# linked worktree it resolves to the PARENT's git dir, which is where git
# actually keeps the shared hooks.
repo_hook=""
if common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
    candidate="$common_dir/hooks/$hook_name"
    # Guard against self-recursion if a repo symlinks its hook back to this file.
    if [ -x "$candidate" ] && [ "$(readlink -f "$candidate" 2>/dev/null)" != "$(readlink -f "$0" 2>/dev/null)" ]; then
        repo_hook="$candidate"
    fi
fi

if [ -n "$repo_hook" ]; then
    exec "$repo_hook" "$@"
fi

exit 0
