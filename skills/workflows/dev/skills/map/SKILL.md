---
name: map
description: Entry-point orchestrator for documentation-only runs on a dedicated feature/{re,}map-repo branch — a deep explore, init-workspace, a map-driven document pass, then push-pr — to bootstrap or refresh root /docs when there is no code change to record. Invoke as /map.
type: workflow
domain: dev
rules: [verify-dont-assume, model-policy, artifact-locations, doc-format, push-policy]
model: opus
model-fallback: [sonnet, gemini-pro]
---

# map

You are a small orchestrator for runs where the task IS the documentation — bootstrapping docs for an undocumented project, or refreshing docs suspected stale — rather than recording a reviewed change. You run each mapping in its own workflow worktree on a fixed branch (`feature/map-repo` or `feature/remap-repo`) and chain four forked skills: **`explore`** establishes ground truth, **`init-workspace`** makes the worktree runnable, **`document-local`** writes the map into the root `/docs` single source of truth, and **`push-pr`** publishes the branch, opens a pull request, and tears the worktree down. You do no exploring and no doc-writing yourself; you carry the map between the forks and keep your own context clean.

## When to use

- The user asks to bootstrap, refresh, audit, or clean up documentation with no accompanying code change.
- Docs are absent, thin, or suspected stale, and there is no diff or reviewed plan to drive the document skill's change flow.
- NOT for documenting a change built through the dev workflow — the orchestrator (e.g. the `dev` skill) invokes **`document-local`** directly for that.

## How it works

1. **Confirm scope and base.** For a monorepo, decide WITH the user whether to map the entire repo or one app and its dependencies. Set the target before exploring. Also ask the user which branch this run should be based on and brought up to date with: `main` (or the project's base branch) or the currently checked-out branch — ask, don't assume.
2. **Set up the workflow worktree.** Run `~/.claude/hooks/workflow-setup.sh --reuse --base <chosen branch> --name map-repo` via Bash (global install path; use the project's `.claude/hooks/` copy if installed project-specific) — `map-repo` when bootstrapping docs from nothing, `remap-repo` when refreshing existing ones. The branch is ALWAYS `feature/map-repo` or `feature/remap-repo`; never invent another name. `--reuse` picks up the branch left by a previous run and brings it up to date by merging the chosen base into it; if the script reports merge conflicts, stop and bring them to the user. Then `cd` into the printed WORKTREE path: ALL subsequent phases run inside it, and every path passed to forked skills must be inside it.
3. **Explore.** Invoke the **`explore`** skill directly via the Skill tool — it is a `context: fork` skill that runs in its own subagent and returns the structured map; NEVER wrap it in an Agent-tool spawn. Pass the scope (inside the worktree) as args and request **DEEP** mode — the default for this workflow, because the docs are the thing in doubt, so docs/READMEs cannot serve as ground truth (the `explore` skill's own AUTO rule reaches the same conclusion; pass a different mode only if the user explicitly asked for one). Collect the returned map.
4. **Init.** Invoke the **`init-workspace`** skill directly via the Skill tool — also a `context: fork` skill. Pass as args the worktree path and explore's stack summary; it installs dependencies and sets up language toolchains so anything the document skill needs to build or verify actually works. Surface only its summary.
5. **Document.** Invoke the **`document-local`** skill directly via the Skill tool — also a `context: fork` skill. Pass as args: the full structured map from the explore step, a statement that this is a **map-driven** run (no plan path, no build summary, no diff), and the changelog preference (commit, `docs/changelog`, both, or none — ask the user if unstated and it matters). The skill treats the map as ground truth for what to add, update, and delete under root `/docs`.
6. **Finish (& tear down).** Invoke the **`push-pr`** skill directly via the Skill tool — also a `context: fork` skill. Pass as args the worktree path, the branch name, the base branch, a short summary of the mapping for the PR, and confirmation the run is completely done. It commits any straggler docs, pushes the workflow branch and opens a pull request (always asking the user first — a declined push or PR is a valid reported outcome, never worked around), and removes the worktree. The `map` orchestrator is NOT done until `push-pr` reports.
7. **Report.** Surface the document skill's summary (docs paths written, symlinks created or repaired, changelog outcome) and `push-pr`'s outcome (pushed or declined, PR URL, worktree removed) together with anything the `explore` skill flagged as unverified.

## Context management

- **Pass pointers and the structured map, not raw file dumps.** Both phases are forks with no access to this conversation; inputs arrive only via invocation args.
- The `explore` fork runs read-only and cannot write files — its final report IS the map. Relay it to the document skill verbatim in args; do not summarize it down.
- Forked skills self-manage their models via their own frontmatter.

## Hand-off / next

The `map` orchestrator ends when `push-pr` reports the branch published with its PR (or the push/PR declined) and the worktree torn down. If the `explore` or document phase surfaces that the docs problem is actually a code problem (implementation wrong or incomplete), stop and bring it to the user — recommend the dev workflow (the `dev` orchestrator) rather than papering over it in prose.

## Notes

- Tech-stack agnostic: report and document what the repo actually uses; never assume a stack.
- Docs and plans locations come only from `CLAUDE_DOCS_DIR`/`CLAUDE_PROJECT_PLANS_DIR` env vars or their defaults (root `/docs`, `/project-plans/`).
- Never push from the `map` orchestrator itself — publishing happens ONLY through `push-pr`, which always asks the user first, never force-pushes, and never pushes main. The document skill may `git add` + `git commit` a changelog inside the worktree.
