---
name: cleanup-merged
description: Post-merge closeout of a dae workflow run — verify the PR actually merged, delete the workflow branch (local and remote, with confirmation), prune worktrees, remove the gitignored run dir, archive the plan through `plan-lifecycle.sh` — only `plan.md` moves to `completed/`, never a plan that didn't ship, and optionally transition the Jira ticket. Invoked standalone after a PR merges, or by the dae orchestrator.
domain: universal
context: fork
rules: [verify-dont-assume, push-policy, artifact-locations, run-artifacts]
model: sonnet
model-fallback: [gemini-pro]
---

# cleanup-merged

You close the loop `push-pr` deliberately leaves open. The ship stage publishes the branch and tears down the worktree but keeps the local branch and touches nothing remote; once the PR has ACTUALLY merged, the leftovers become clutter that accumulates run after run — stale branches, orphaned worktrees, plan directories sitting under the plans dir, unarchived, long after they shipped. You remove exactly the leftovers of one merged run, and nothing else.

## When to use

- After a workflow PR has merged, to close out that run's branch, worktree remnants, run dir, and plan.
- Standalone as a sweep: point it at a repo and it finds workflow branches whose PRs merged and offers to clean each.
- NEVER before the merge — an open or draft PR's branch is live work; a declined-push branch is the user's local property. If the PR isn't merged, report that and stop.

## Inputs

You run as an isolated fork — everything arrives via invocation args. Expect: the branch name (or "sweep" to discover candidates), the plan path when the run had one, the run-artifacts dir path (`<workflows-dir>/<name>-artifacts/`) if it still exists, and the Jira key + desired transition when a ticket should be closed. Verify — don't trust: every deletion below is gated on evidence, not on the args' say-so.

## How it works

1. **Prove the merge.** `gh pr view <branch> --json state,mergedAt,mergeCommit` (or the GitHub MCP): state must be MERGED. No PR, or state OPEN/CLOSED-unmerged → stop and report; there is nothing safe to clean. In sweep mode, candidates are `<type>/<name>` branches whose PR is MERGED — list them and what would be removed, then proceed per the caller's confirmation.
2. **Delete the branches.** Remote: `git push origin --delete <branch>` — outward-facing, rides on the permission prompt; a decline is a valid outcome, record the command and continue. Local: `git branch -d <branch>` (safe delete only — if `-d` refuses, the branch holds unmerged commits; STOP and surface that instead of forcing `-D`).
3. **Prune worktree remnants.** If a worktree for the branch still exists, it should be clean (the work merged); `git worktree remove <path>` then `git worktree prune`. A dirty worktree at this stage means unshipped changes — stop and surface, never remove with force.
4. **Remove the run dir.** Delete `<workflows-dir>/<name>-artifacts/` (progress log, contracts, exit reports — ephemeral by the `run-artifacts` rule, and the run is over). Skip silently if already gone.
5. **Archive the plan.** Run `plan-lifecycle.sh check <plans-dir>` first; a
   `FAIL:` line means the layout is already off — surface it and stop rather
   than moving anything. Then `plan-lifecycle.sh archive <plans-dir>/<slug>-MM-DD-YY/`:
   ONLY `plan.md` moves, to `completed/<slug>-MM-DD-YY.md`, and the rest of the
   dir is removed. If the script refuses because the syllabus still has
   unchecked subphases, that is the correct answer and NOT something to force:
   an unfinished plan whose branch merged means the run closed differently than
   planned — take it back to the user, who decides between finishing the
   syllabus ticks and superseding the plan. Do NOT suggest `--force-incomplete`
   to the user as a way around this from this skill; that flag exists for a
   human decision made explicitly, not as this skill's default recovery path.
   **`completed/` means shipped. A plan that was replaced, abandoned, or
   superseded by a later plan never goes there** — its route is
   `plan-lifecycle.sh supersede --by <successor>`, which DELETES it outright
   (git history and the successor's supersession note are the record; there is
   no archive of abandoned plans). That is a user decision, not this skill's
   call: surface the refusal and stop. The two standing dirs (`proposals/`,
   `completed/`) are never deleted, empty or not. A run with no `plan.md`
   archives nothing; its record dir is simply removed. This is a repo change:
   commit it on a fresh `sync/cleanup-<name>` branch off the base (never commit
   to the base branch directly, per push-policy) and offer the caller the
   `push-pr` route for it — or leave the commit local if declined.
6. **Transition the ticket** (only when a key + transition arrived in the args): via the Atlassian MCP, transition the issue and drop a comment linking the merged PR. Never invent a key or a transition.
7. **Report the ledger.** Everything removed, everything declined/blocked (with the exact command to finish it manually), and the archive commit/branch if one was made.

## Hand-off / next

Return the shared worker envelope (see the conventions doc "Worker return envelope"): `status`; `artifacts[]` = [archive commit branch, if any]; `next` = done (or `push-pr` for the archive branch); `blockers[]` = anything that refused safe deletion. The run is fully closed only when branch, worktree, run dir, and plan location (proposal / active dir / completed) all reflect the merge.

## Notes

- Safe deletes only: `-d` not `-D`, no `--force` anywhere, nothing removed while it holds unmerged or uncommitted work. When a safe command refuses, that refusal is information — surface it.
- Never touch branches, worktrees, run dirs, or plans belonging to other runs; one run per invocation (sweep mode is N confirmed single-run cleanups, not one bulk delete).
- A declined remote delete or archive push is a valid outcome — report the exact commands and finish the rest.
