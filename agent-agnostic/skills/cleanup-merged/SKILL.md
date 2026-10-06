---
name: cleanup-merged
description: Post-merge closeout of a dae workflow run — verify the PR actually merged, delete the workflow branch (local and remote, with confirmation), prune worktrees, remove the gitignored run dir, confirm the plan already landed in `completed/` (push-pr archives it at finalize, inside the PR), and optionally transition the Jira ticket. Makes no commits. Invoked standalone after a PR merges, or by the dae orchestrator.
domain: universal
context: fork
rules: [verify-dont-assume, push-policy, artifact-locations, run-artifacts]
model: sonnet
model-fallback: [gemini-pro]
---

# cleanup-merged

You close the loop `push-pr` deliberately leaves open. The ship sequence publishes the branch repeatedly across the run — `open-draft` at plan approval, `update` after every lane merge-back and record commit, `finalize` at the end — but never removes the worktree and never removes the branch; only once the PR has ACTUALLY merged do the leftovers become this skill's job: stale branches, orphaned worktrees, run dirs. The plan is not a leftover — `finalize` archived it inside the PR, so the merge already carried it into `completed/`. You remove exactly the leftovers of one merged run, nothing else, and you never commit anything.

## When to use

- After a workflow PR has merged, to close out that run's branch, worktree remnants, run dir, and plan.
- Standalone as a sweep: point it at a repo and it finds workflow branches whose PRs merged and offers to clean each.
- NEVER before the merge — an open or draft PR's branch is live work; a declined-push branch is the user's local property. If the PR isn't merged, report that and stop.

## Inputs

You run as an isolated fork — everything arrives via invocation args. Expect: the branch name (or "sweep" to discover candidates), the plan path when the run had one, the run dir path (`<workflows-dir>/<name>/.artifacts/`, inside the parent worktree) if it still exists, and the Jira key + desired transition when a ticket should be closed. Verify — don't trust: every deletion below is gated on evidence, not on the args' say-so.

## How it works

1. **Prove the merge.** `gh pr view <branch> --json state,mergedAt,mergeCommit` (or the GitHub MCP): state must be MERGED. No PR, or state OPEN/CLOSED-unmerged → stop and report; there is nothing safe to clean. In sweep mode, candidates are `<type>/<name>` branches whose PR is MERGED — list them and what would be removed, then proceed per the caller's confirmation.
2. **Delete the branches.** Remote: `git push origin --delete <branch>` — outward-facing, rides on the permission prompt; a decline is a valid outcome, record the command and continue. Local: **`git branch -d <branch>` will refuse whenever the branch was SQUASH-merged** — squash creates a new commit with no merge ancestry, so git cannot see the branch as merged however completely its content landed. Since `push-policy` makes squash the universal integration route, that refusal is the NORMAL case, not evidence of unmerged work, and treating it as a stop leaves a stale branch behind after every run. **Check content, not ancestry:** `git diff <base> <branch>` must show nothing beyond changes deliberately made on the base after the merge. Then `git branch -D <branch>` — `-D` is on the ASK list, so it prompts and the user approves; that prompt IS the safety check and this is the intended path, not an override. Only the long form `--delete --force` is denied. If the content diff shows REAL unmerged work, that is the case to stop and surface.
3. **Prune worktree remnants.** If a worktree for the branch still exists, it should be clean (the work merged); `git worktree remove <path>` then `git worktree prune`. A dirty worktree at this stage means unshipped changes — stop and surface, never remove with force. The run dir inside does NOT interfere: because `.artifacts/` is gitignored, git treats it as ignored, and `git worktree remove` deletes the worktree without complaint and without `--force` (verified). So `--force` is never needed here — if plain `remove` refuses, that is a real modification and a genuine stop signal.
4. **Confirm the run dir went with it.** The run dir lives at `<workflows-dir>/<name>/.artifacts/`, INSIDE the worktree, so step 3 already removed it (progress log, contracts, exit reports — ephemeral by the `run-artifacts` rule, and the run is over). Verify it is gone rather than deleting separately. Older runs may still have a sibling `<workflows-dir>/<name>-artifacts/` from the previous layout; delete that if present. Skip silently if already gone.
5. **Confirm the plan landed archived.** `plan-lifecycle.sh locate <slug>-MM-DD-YY` (the full plan id) against the up-to-date base must print `completed: <path>` — `push-pr --stage finalize` archived it on the branch, so the squash merge carried `completed/<slug>-MM-DD-YY.md` onto the base with the work. Anything else (an active plan dir still on the base, or no plan found for a run that had one) is a defect in that run's finalize: report it as a blocker and stop. Never archive here, and never commit — not on the base, not on a `sync/cleanup-*` branch. A post-merge commit is exactly what this design exists to prevent. A plan-less run has nothing to confirm.
6. **Transition the ticket** (only when a key + transition arrived in the args): via the Atlassian MCP, transition the issue and drop a comment linking the merged PR. Never invent a key or a transition.
7. **Report the ledger.** Everything removed, everything declined/blocked (with the exact command to finish it manually), and the plan's confirmed `completed/` path.

## Hand-off / next

Return the shared worker envelope (see the conventions doc "Worker return envelope"): `status`; `artifacts[]` = [the plan's `completed/` path, if any]; `next` = done; `blockers[]` = anything that refused safe deletion, plus a plan not found in `completed/`. The run is fully closed only when branch, worktree, and run dir are gone and the plan sits in `completed/` on the base.

## Notes

- Safe deletes only: `-d` not `-D`, no `--force` anywhere, nothing removed while it holds unmerged or uncommitted work. When a safe command refuses, that refusal is information — surface it.
- Never touch branches, worktrees, run dirs, or plans belonging to other runs; one run per invocation (sweep mode is N confirmed single-run cleanups, not one bulk delete).
- A declined remote delete is a valid outcome — report the exact command and finish the rest.
