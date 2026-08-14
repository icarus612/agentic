#!/usr/bin/env bash
# worktree-reminder.sh — SessionStart hook: remind every session (not just
# orchestrator-driven ones) to follow the workflow conventions that used to
# be documented only inside the dae orchestrator: isolate file changes in a
# worktree, and route pushes/PR reviews through push-pr/review-pr.
#
# WHY A REMINDER, NOT AN ENFORCED WORKTREE OR A BLOCK
#   SessionStart hooks cannot change the session's working directory or
#   block session start (code.claude.com/docs/en/hooks.md) — there is no
#   sandboxing mechanism. The best a hook can do is inject additionalContext
#   that the model reads and must voluntarily act on, exactly like the
#   existing skill-driven `cd` pattern (see orchestrators/hooks/workflow-setup.sh).
#   This hook makes that expectation apply to EVERY session, not just ones
#   that invoke an orchestrator skill (dae) — see
#   artifact-locations and push-policy.
#
# WHY source=startup ONLY
#   SessionStart also fires on --resume, /clear, and every compaction. Firing
#   this reminder then would repeatedly nudge mid-task sessions that are
#   already correctly inside a worktree, and (worse) could read as an
#   instruction to set up a SECOND worktree mid-run. Only fresh session
#   starts get the reminder.
#
# No jq dependency, matching this repo's other hooks — stdin is Claude
# Code's documented flat SessionStart payload, so grep/sed is enough.
#
# Never blocks: SessionStart hooks can't block session start anyway (exit
# code is not a gate here), so this always exits 0.
set -uo pipefail

input=$(cat)

source_val=$(grep -oE '"source"[[:space:]]*:[[:space:]]*"[^"]*"' <<< "$input" | head -1 | sed -E 's/^"source"[[:space:]]*:[[:space:]]*"(.*)"$/\1/')
[ "$source_val" = "startup" ] || exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

gitdir=$(git rev-parse --git-dir 2>/dev/null)
commondir=$(git rev-parse --git-common-dir 2>/dev/null)
in_worktree=0
[ "$gitdir" = "$commondir" ] || in_worktree=1

if [ "$in_worktree" = 1 ]; then
  worktree_msg='This session is already inside an isolated workflow worktree (linked git-dir detected) — no worktree setup needed.'
else
  worktree_msg='This session started on the main working tree, not an isolated workflow worktree. Per the artifact-locations rule: before making ANY file changes this session — whether or not an orchestrator skill (dae) is driving it — set one up first via ~/.claude/hooks/workflow-setup.sh --name <short-task-slug> (global install path; use the project .claude/hooks copy if installed project-specific), then cd into the printed WORKTREE path. Purely conversational or read-only turns do not need this.'
fi

push_msg='Before running git push or opening/commenting on/reviewing a pull request in ANY session — not just one driven by an orchestrator — prefer the push-pr/review-pr skills over raw git/gh commands: they enforce push-policy (two modes by whether the repo has a dev branch — WITH dev, dev is the integration branch and main is off-limits except an authorized hotfix; WITHOUT dev, main is the integration branch, squash-merged locally and pushed — always squash, ask before every push, never force-push, never commit on the integration branch) and the worktree teardown/PR conventions this repo expects.'

context=$(printf '%s\n\n%s' "$worktree_msg" "$push_msg")

# Pure parameter expansion, no sed. The previous form used GNU sed's label
# syntax (:a;N;$!ba) to fold newlines; BSD sed (macOS) rejects it as an unused
# label, so the hook emitted invalid JSON and its additionalContext was silently
# dropped on every macOS session. Do not reintroduce sed here — this runs
# identically on bash 3.2 (macOS system bash) and 5.x.
json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  printf '%s' "$s"
}

escaped=$(json_escape "$context")
printf '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "%s"}}\n' "$escaped"
