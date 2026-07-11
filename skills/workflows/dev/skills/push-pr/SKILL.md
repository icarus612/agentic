---
name: push-pr
description: Terminal phase of the dev workflow — commit stragglers, push the workflow branch, and open a pull request against the base branch (always asking for confirmation first), then tear down the workflow worktree. Never force-pushes, never pushes main. Invoked by the dev/map orchestrators.
type: workflow
domain: dev
context: fork
rules: [verify-dont-assume, artifact-locations, push-policy]
model: sonnet
model-fallback: [gemini-pro]
---

# push-pr

You close out a completed workflow run. Your job is to make sure every artifact is committed on the workflow branch, publish that branch, open a pull request against the base branch, and remove the worktree so the workflows dir stays clean. You run as an isolated fork.

## When to use

- Only after the full workflow has completed: the document phase has run and the `review-code` gate is clean.
- Standalone, to publish and tear down a workflow worktree that already finished but was left in place.
- NEVER mid-workflow — if the document phase or the `review-code` gate hasn't finished, this is the wrong phase.

## Inputs

You run as an isolated fork with no access to the conversation history — everything you need arrives via the invocation args. Expect: the worktree path, the branch name, the base branch, a short summary of the work (for the PR title/body), and confirmation from the caller that the workflow is completely done. Verify — don't trust: check `git status` is clean and the branch is the expected `<type>/<name>` (where `<type>` is `feature`, `bug`, or `hotfix`) before doing anything.

## How it works

1. **Verify completion.** Inside the worktree, confirm the working tree is clean and you're on the expected workflow branch — never main. If straggler artifacts (plans, docs) are uncommitted and the caller authorized committing them, commit with a clear message; otherwise stop and report.
2. **Publish.** `git push -u origin <branch>` to the workflow branch ONLY. Never `--force` in any form, never push main or the base branch. This always prompts the user for explicit confirmation before it runs (standing permission policy) — if the user declines, do NOT retry or work around it: record that the branch exists locally with all commits, skip the PR step, and move on to teardown considerations.
3. **Open the pull request.** After a successful push, open a PR from the workflow branch to the base branch — via the `gh` CLI (`gh pr create`) or the GitHub MCP capability, whichever is available. Opening a PR is outward-facing, so it rides on the same explicit confirmation as the push ("push and open a PR?"); if the user approved the push but declined the PR, report the exact command to open it later.
   - Check for a PR template (`.github/pull_request_template.md` or `.github/PULL_REQUEST_TEMPLATE/`) and structure the body with it.
   - Title: a one-line summary of the work. Body: what was built and why, key decisions, and a pointer to the plan file — drawn from the summary in your args, not invented.
   - If a PR already exists for this branch, update it instead of creating a duplicate.
   - If the repo has no remote hosting or no PR tooling is available, say so and report the branch as pushed-only — do not improvise.
4. **Tear down.** Only when the working tree is clean and all work is committed (commits are safe — the worktree shares the repo's object store, so removing the directory loses nothing committed): `git worktree remove <path>`. If that command is permission-blocked, fall back to reporting the exact cleanup commands for the user instead of deleting via raw `rm -rf` yourself. Then `git worktree prune` if removal succeeded. The local branch stays (deleting it is the user's call).
5. **Verify teardown.** `git worktree list` no longer shows the path; the workflows dir entry is gone.

## Hand-off / next

The `push-pr` skill ends the workflow — nothing follows by default. Return contract: the final report states the branch name; whether it was pushed or declined (with the exact push command if declined); the PR URL if one was opened (or the exact command to open it if declined/unavailable); whether the worktree was removed or the exact cleanup commands if blocked; and any straggler commits made. If the user wants an independent review of the opened PR, the caller invokes the `review-pr` skill with the PR URL.

## Notes

- Never force-push.
- Never push or commit to main/the base branch; the PR targets the base branch, you never write to it.
- Never remove a worktree with uncommitted changes.
- If anything isn't clean, stop and report instead of cleaning up.
- A declined push or PR is a VALID outcome, not an error to route around — the user may legitimately decline via the confirmation prompt.
