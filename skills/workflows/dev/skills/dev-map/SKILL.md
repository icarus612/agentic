---
name: dev-map
description: Orchestrate a documentation-only run on a dedicated feature/{re,}map-repo branch — a deep dev-explore, dev-init, a map-driven dev-document, then dev-finish — to bootstrap or refresh root /docs when there is no code change to record.
type: workflow
domain: dev
rules: [verify-dont-assume, model-policy, artifact-locations, doc-format, push-policy]
model: opus
model-fallback: [sonnet, gemini-pro]
---

# dev-map

You are a small orchestrator for runs where the task IS the documentation — bootstrapping docs for an undocumented project, or refreshing docs suspected stale — rather than recording a reviewed change. You run each mapping in its own workflow worktree on a fixed branch (`feature/map-repo` or `feature/remap-repo`) and chain four forked skills: **dev-explore** establishes ground truth, **dev-init** makes the worktree runnable, **dev-document** writes the map into the root `/docs` single source of truth, and **dev-finish** publishes the branch and tears the worktree down. You do no exploring and no doc-writing yourself; you carry the map between the forks and keep your own context clean.

## When to use

- The user asks to bootstrap, refresh, audit, or clean up documentation with no accompanying code change.
- Docs are absent, thin, or suspected stale, and there is no diff or reviewed plan to drive dev-document's change flow.
- NOT for documenting a change built through the dev workflow — the orchestrator (e.g. `dev-start`) invokes **dev-document** directly for that.

## How it works

1. **Confirm scope and base.** For a monorepo, decide WITH the user whether to map the entire repo or one app and its dependencies. Set the target before exploring. Also ask the user which branch this run should be based on and brought up to date with: `main` (or the project's base branch) or the currently checked-out branch — ask, don't assume.
2. **Set up the workflow worktree.** Run `~/.claude/hooks/workflow-setup.sh --reuse --base <chosen branch> --name map-repo` via Bash (global install path; use the project's `.claude/hooks/` copy if installed project-specific) — `map-repo` when bootstrapping docs from nothing, `remap-repo` when refreshing existing ones. The branch is ALWAYS `feature/map-repo` or `feature/remap-repo`; never invent another name. `--reuse` picks up the branch left by a previous run and brings it up to date by merging the chosen base into it; if the script reports merge conflicts, stop and bring them to the user. Then `cd` into the printed WORKTREE path: ALL subsequent phases run inside it, and every path passed to forked skills must be inside it.
3. **Explore.** Invoke **dev-explore** directly via the Skill tool — it is a `context: fork` skill that runs in its own subagent and returns the structured map; NEVER wrap it in an Agent-tool spawn. Pass the scope (inside the worktree) as args and request **DEEP** mode — the default for this workflow, because the docs are the thing in doubt, so docs/READMEs cannot serve as ground truth (dev-explore's own AUTO rule reaches the same conclusion; pass a different mode only if the user explicitly asked for one). Collect the returned map.
4. **Init.** Invoke **dev-init** directly via the Skill tool — also a `context: fork` skill. Pass as args the worktree path and explore's stack summary; it installs dependencies and sets up language toolchains so anything dev-document needs to build or verify actually works. Surface only its summary.
5. **Document.** Invoke **dev-document** directly via the Skill tool — also a `context: fork` skill. Pass as args: the full structured map from the explore step, a statement that this is a **map-driven** run (no plan path, no build summary, no diff), and the changelog preference (commit, `docs/changelog`, both, or none — ask the user if unstated and it matters). dev-document treats the map as ground truth for what to add, update, and delete under root `/docs`.
6. **Finish (& tear down).** Invoke **dev-finish** directly via the Skill tool — also a `context: fork` skill. Pass as args the worktree path, the branch name, and confirmation the run is completely done. It commits any straggler docs, pushes the workflow branch (always asking the user first — a declined push is a valid reported outcome, never worked around), and removes the worktree. dev-map is NOT done until dev-finish reports.
7. **Report.** Surface dev-document's summary (docs paths written, symlinks created or repaired, changelog outcome) and dev-finish's outcome (pushed or declined, worktree removed) together with anything dev-explore flagged as unverified.

## Context management

- **Pass pointers and the structured map, not raw file dumps.** Both phases are forks with no access to this conversation; inputs arrive only via invocation args.
- dev-explore's fork runs read-only and cannot write files — its final report IS the map. Relay it to dev-document verbatim in args; do not summarize it down.
- Forked skills self-manage their models via their own frontmatter.

## Hand-off / next

dev-map ends when dev-finish reports the branch published (or the push declined) and the worktree torn down. If dev-explore or dev-document surfaces that the docs problem is actually a code problem (implementation wrong or incomplete), stop and bring it to the user — recommend the dev workflow (`dev-start`) rather than papering over it in prose.

## Notes

- Tech-stack agnostic: report and document what the repo actually uses; never assume a stack.
- Docs and plans locations come only from `CLAUDE_DOCS_DIR`/`CLAUDE_PROJECT_PLANS_DIR` env vars or their defaults (root `/docs`, `/project-plans/`).
- Never push from dev-map itself — publishing happens ONLY through dev-finish, which always asks the user first, never force-pushes, and never pushes main. dev-document may `git add` + `git commit` a changelog inside the worktree.
