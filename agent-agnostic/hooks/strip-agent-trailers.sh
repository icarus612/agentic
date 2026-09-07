#!/usr/bin/env bash
# strip-agent-trailers.sh — git commit-msg hook. Removes agent attribution
# trailers from every commit message, in every repo, regardless of what any
# agent was told to do.
#
# WHY THIS EXISTS
#   `includeCoAuthoredBy: false` in ~/.claude/settings.json suppresses the
#   `Co-Authored-By: Claude` trailer. It does NOT suppress `Claude-Session:`,
#   which the Claude Code harness injects as a separate system-prompt
#   instruction ("End git commit messages with: Claude-Session: <url>").
#
#   That instruction is re-read fresh by every subagent. A subagent that
#   commits sees the harness instruction and does not see the user's
#   preference, so it complies. Telling agents "no trailers" works only for
#   the agents you happen to tell, in the run you happen to tell them, and
#   fails silently everywhere else.
#
#   Measured on mythic-made 2026-09-07: 94 of 895 commits on `dev` carried a
#   trailer, spanning 2025-11-01 to 2026-09-06 — including two added the same
#   day an agent was explicitly instructed not to add them.
#
#   A prompt cannot enforce this. A commit-msg hook can: git runs it on the
#   message file before the commit object is written, so the trailer is gone
#   whether the committer was a person, an agent, a subagent, or a script.
#
# WHAT IT STRIPS
#   Lines matching (case-insensitive, leading whitespace tolerated):
#     Claude-Session: <anything>
#     Co-Authored-By: Claude <anything>
#     Co-Authored-By: <anything>@anthropic.com
#     Generated with [Claude Code](...)  /  robot-emoji Generated with ...
#   Then collapses any trailing blank lines the removal left behind.
#
#   It does NOT touch Co-Authored-By lines naming real humans — those are
#   legitimate git metadata and removing them would misattribute real work.
#
# INSTALL
#   Repo-local:   ln -sf <this file> <repo>/.git/hooks/commit-msg
#   All repos:    git config --global core.hooksPath ~/.git-hooks
#                 (then symlink this in as commit-msg there)
#
#   NOTE on core.hooksPath: it REPLACES per-repo .git/hooks wholesale rather
#   than layering. If a repo relies on husky/lefthook, setting it globally
#   will disable those. Check before using the global form.
#
#   A git worktree shares .git/hooks with its parent checkout, so a repo-local
#   install covers every worktree cut from it automatically.
#
# EXIT
#   Always 0. A failure to rewrite is reported but does NOT block the commit —
#   this hook exists to clean metadata, not to gate work.

set -uo pipefail

msg_file="${1:-}"
[ -n "$msg_file" ] || { echo "strip-agent-trailers: no commit-msg file given" >&2; exit 0; }
[ -f "$msg_file" ] || { echo "strip-agent-trailers: $msg_file not found" >&2; exit 0; }

before_hash=$(cksum < "$msg_file")

tmp="${msg_file}.strip-agent-trailers.$$"
trap 'rm -f "$tmp"' EXIT

# Perl rather than sed/grep: this environment ships ugrep and mawk variants
# whose flag handling differs (see the shell-discipline rule), and perl's
# behavior here is stable across all of them.
perl -0777 -pe '
    s/^[ \t]*Claude-Session:[^\n]*\n//gmi;
    s/^[ \t]*Co-Authored-By:[ \t]*Claude[^\n]*\n//gmi;
    s/^[ \t]*Co-Authored-By:[^\n]*\@anthropic\.com[^\n]*\n//gmi;
    s/^[ \t]*(?:\x{1F916}[ \t]*)?Generated with[ \t]*\[?Claude[^\n]*\n//gmi;
    s/\n{3,}\z/\n/;
    s/\s+\z/\n/;
' "$msg_file" > "$tmp" || {
    echo "strip-agent-trailers: rewrite failed, leaving message unchanged" >&2
    exit 0
}

if [ "$(cksum < "$tmp")" != "$before_hash" ]; then
    cat "$tmp" > "$msg_file"
    echo "strip-agent-trailers: removed agent attribution trailer(s)" >&2
fi

exit 0
