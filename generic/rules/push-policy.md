---
name: push-policy
description: Two modes selected by whether the repo has a dev branch — dev-integration repos never touch main (except an authorized hotfix); no-dev repos treat main as the integration branch, squash-merged locally and pushed. Squash always; never force-push; never commit on the integration branch.
domain: universal
---

# Push policy
The flow is one of two modes, selected per-repo by whether a `dev` branch exists (`branch-squash-guard.sh` detects this automatically — dev wins when present — and enforces everything below at the tool-call level, for both Claude Code and Antigravity; `resolve-config.sh`'s `CLAUDE_BASE_BRANCH` heuristic is where the "dev wins" precedence lives, so every consumer — the guard, `workflow-setup.sh`, the dae skills — resolves the same integration branch). This rule states the same policy for the model to reason about.

## Mode A — the repo HAS a `dev` branch (the general/enterprise case)
- `dev` is the integration branch: branch FROM dev, open a **remote** PR (GitHub) INTO dev, and it must be squash-merged (`gh pr merge --squash`).
- `main` is off-limits: never branch from main, never `git merge` into main, never commit or edit files directly on main, never `git push` main — **unless it's an authorized hotfix.** The exception requires explicit, deliberate user authorization for that specific hotfix — never implied, never a standing setting left on. Set `CLAUDE_HOTFIX_MAIN_AUTHORIZED=1` (via a `.claude/settings.local.json` `env` block, resolved through the same `resolve-config.sh` chain as every other `CLAUDE_*` var — never a bare inherited shell variable) for the duration of the hotfix, then unset it. Even an authorized hotfix merge into main must still be squashed — the squash rule has no exception.

## Mode B — the repo has NO `dev` branch (this repo, daedalus-mono, personal repos generally)
- `main` IS the integration branch: branch from main, squash-merge the branch into main **locally** (`git merge --squash <branch>` then `git commit`), then `git push` to publish main. No remote PR is needed. Pushing main is explicitly SANCTIONED here — the deliberate reversal of the old "never push main" rule for repos with no `dev`, not an oversight.
- If a GitHub PR is opened anyway, it must still be squash-merged (`gh pr merge --squash`).

## Universal in both modes, no exception
- **Squash, always** — `git merge --squash` locally, `gh pr merge --squash` remotely. Never a plain merge commit, never a rebase merge.
- **Never commit, or write-tool edit, directly on the integration branch** (`dev` in Mode A, `main` in Mode B) — branch first, always.
- **Force-push, in any form, is never allowed**, on any branch, in either mode, hotfix or not.
- **Every `git push` still requires explicit confirmation first** — never push autonomously or silently, even when the push itself (of a feature branch, or of the integration branch where that's sanctioned) is otherwise permitted.
