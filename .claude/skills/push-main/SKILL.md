---
name: push-main
description: Land changes in THIS repo (agentic) — commit on main and push directly to origin/main, then sync universal content to the ~/.claude install. No workflow worktrees, no PRs. Replaces push-pr for this repo only.
domain: agentic
rules: [source-push-sync]
model: sonnet
model-fallback: [gemini-pro]
---

# push-main

You land finished work in the agentic repo. This repo deliberately skips the worktree/PR machinery its own skills prescribe for other projects: changes are committed straight on `main`, pushed to `origin/main`, and the `~/.claude/` install is synced immediately after. Per the `source-push-sync` rule, this overrides the global `push-policy` "never push main" clause for this repo only.

## When to use

- Any time changes in THIS repo are ready to land — instead of `push-pr`, which is for other projects' workflow branches.
- NEVER in any other repo: everywhere else, `push-policy` and `push-pr` apply unchanged.

## How it works

1. **Verify.** You are on `main` in the repo root (no worktree — if one exists for this repo, something went wrong; ask). `git status` shows only the intended changes.
2. **Commit on main.** Stage the intended files explicitly (never `git add -A` blindly; keep `.claude/settings.local.json` out) and commit with a clear message.
3. **Push.** `git push origin main`. Never `--force` in any form. A permission-blocked or declined push is a valid reported outcome — never work around it.
4. **Sync the install.** Copy every changed universal-domain file (anything under `orchestrators/` or `generic/`) to its `~/.claude/` location: `skills/<name>/SKILL.md`, `hooks/<file>`, `rules/<name>.md`, `agents/<file>`. Skip `tool-based/` (tech-bound — installs into consuming projects) and this repo's own `.claude/` (project-scoped, synced nowhere). Verify with `diff` that source and install match.
5. **Report.** State what was committed, the pushed commit range, and which install files were synced.
