---
name: dev-finish
description: Terminal phase: commit and push the workflow branch (always asking for confirmation first), then tear down the workflow worktree once everything is published. Never force-pushes, never pushes main.
type: workflow
domain: dev
context: fork
rules: [verify-dont-assume, artifact-locations, push-policy]
model: sonnet
model-fallback: [gemini-pro]
---

# dev-finish

You close out a completed workflow run. Your job is to make sure every artifact is committed on the workflow branch, publish that branch, and remove the worktree so the workflows dir stays clean. You run as an isolated fork.

## When to use

- Only after the full workflow has completed: dev-document has run and dev-code-review is clean.
- Standalone, to publish and tear down a workflow worktree that already finished but was left in place.
- NEVER mid-workflow — if dev-document or dev-code-review hasn't finished, this is the wrong phase.

## Inputs

You run as an isolated fork with no access to the conversation history — everything you need arrives via the invocation args. Expect: the worktree path, the branch name, and confirmation from the caller that the workflow is completely done. Verify — don't trust: check `git status` is clean and the branch is the expected `<type>/<name>` (where `<type>` is `feature`, `bug`, or `hotfix`) before doing anything.

## How it works

1. **Verify completion.** Inside the worktree, confirm the working tree is clean and you're on the expected workflow branch — never main. If straggler artifacts (plans, docs) are uncommitted and the caller authorized committing them, commit with a clear message; otherwise stop and report.
2. **Publish.** `git push -u origin <branch>` to the workflow branch ONLY. Never `--force` in any form, never push main or the base branch. This always prompts the user for explicit confirmation before it runs (standing permission policy) — if the user declines, do NOT retry or work around it: record that the branch exists locally with all commits and move on.
3. **Tear down.** Only when the working tree is clean and all work is committed (commits are safe — the worktree shares the repo's object store, so removing the directory loses nothing committed): `git worktree remove <path>`. If that command is permission-blocked, fall back to reporting the exact cleanup commands for the user instead of deleting via raw `rm -rf` yourself. Then `git worktree prune` if removal succeeded. The local branch stays (deleting it is the user's call).
4. **Verify teardown.** `git worktree list` no longer shows the path; the workflows dir entry is gone.

## Hand-off / next

dev-finish ends the workflow — nothing follows. Return contract: the final report states the branch name; whether it was pushed or declined (with the exact push command if declined); whether the worktree was removed or the exact cleanup commands if blocked; and any straggler commits made.

## Notes

- Never force-push.
- Never push or commit to main/the base branch.
- Never remove a worktree with uncommitted changes.
- If anything isn't clean, stop and report instead of cleaning up.
- A declined push is a VALID outcome, not an error to route around — the user may legitimately decline via the confirmation prompt.
