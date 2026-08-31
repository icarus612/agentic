---
name: push-main
description: Land changes in THIS repo (agentic) — squash-merge a workflow branch into main locally and push directly to origin/main, then sync universal content to the ~/.claude install. No GitHub PRs, ever. Replaces push-pr for this repo only.
domain: agentic
rules: [source-push-sync]
model: sonnet
model-fallback: [gemini-pro]
---

# push-main

You land finished work in the agentic repo, after it was developed on a workflow branch in a worktree cut off `main` via `workflow-setup.sh` — same as every other project. This repo deliberately skips only the PR machinery its own skills prescribe for other projects: instead of opening a pull request, you merge that branch into `main` locally, push to `origin/main`, and sync the `~/.claude/` install immediately after. Per the `source-push-sync` rule, this overrides the global `push-policy` "never push main" clause for this repo only.

## When to use

- Any time changes in THIS repo are ready to land — instead of `push-pr`, which is for other projects' workflow branches.
- NEVER in any other repo: everywhere else, `push-policy` and `push-pr` apply unchanged.

## How it works

1. **Verify.** A workflow worktree exists for this change, on its `<type>/<name>` branch, clean, with everything committed there (per `workflow-setup.sh`'s standard scheme). The main checkout, in the repo root, is on `main` with a clean tree. Note the pre-merge remote tip: `old=$(git rev-parse origin/main)`.
2. **Squash-merge locally.** From the main checkout: `git merge --squash <type>/<name>` followed by `git commit`. Squash is the rule, universally, per `push-policy` — one commit per run on `main`, one revert point, and the per-subphase trail stays readable in the run's exit reports and in the branch itself until it is retired. `--no-ff` was this repo's former exception and is no longer permitted; `branch-squash-guard.sh` denies any non-squash merge into the base branch at the tool-call level.
3. **Refuse on conflict.** If the merge conflicts, `git merge --abort` and stop — never resolve conflicts at the landing stage. Reconcile inside the workflow worktree and re-invoke `push-main`; report the exact state.
4. **Push.** `git push origin main`. Never `--force` in any form. A permission-blocked or declined push is a valid reported outcome — never work around it.
5. **Retire the branch.** After a successful push: remove the worktree first (`git worktree remove <path>`, then `git worktree prune` — a branch checked out in a worktree cannot be deleted), then delete the branch.
   **`git branch -d` WILL refuse, every time, and that is not a problem to surface.** This repo lands by SQUASH merge (step 2), which creates a new commit with no merge ancestry — so git cannot see the branch as merged no matter how completely its content landed. Treating that refusal as "the merge did not fully land" is wrong reasoning and leaves a stale branch behind after every single run.
   **The real check is content, not ancestry:** `git diff <base> <type>/<name>` must show nothing beyond changes you deliberately made on the base AFTER the merge (an `archive` run deleting the plan's review records is the normal case). An empty-or-explained diff means the content is fully on the base.
   **Then `git branch -D <type>/<name>`.** `-D` is on the ASK list — it prompts, and the user approves it; that prompt IS the safety check, and it is the intended path here, not an override. Only the long form `--delete --force` is denied. Never force-PUSH — that is a different thing and remains forbidden in every form.
6. **Sync the install.** Run `agent-agnostic/hooks/sync-install.sh <old>..HEAD` (the range just pushed; the script maps every changed universal-domain file to its `~/.claude/` location, copies whole skill/agent directories, propagates deletions, and `diff`-verifies), from the main checkout — never the workflow worktree, which no longer exists at this point anyway; the script refuses inside a linked worktree and requires HEAD on main. It skips `tool-based/` (tech-bound — installs into consuming projects), this repo's own `.claude/` (project-scoped, synced nowhere), and `AGENTS.md` files by construction. If the push was blocked or declined, skip this step — the install must never get ahead of `origin/main`. For a full-tree verification (or to recover a drifted install), use `sync-install.sh --check` / `--full`.
7. **Report.** State what was merged (the branch), the pushed commit range, that the worktree and branch were removed, and the `SYNCED:`/`DELETED:` lines the script printed.
