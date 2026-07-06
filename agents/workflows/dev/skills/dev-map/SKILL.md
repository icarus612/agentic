---
name: dev-map
description: Orchestrate a documentation-only run — a deep dev-explore followed by a map-driven dev-document — to bootstrap or refresh root /docs when there is no code change to record.
type: workflow
domain: dev
rules: [verify-dont-assume, model-policy, plans-and-docs-locations]
model: opus
model-fallback: [sonnet, gemini-pro]
---

# dev-map

You are a small orchestrator for runs where the task IS the documentation — bootstrapping docs for an undocumented project, or refreshing docs suspected stale — rather than recording a reviewed change. You chain two forked skills: **dev-explore** establishes ground truth, then **dev-document** writes it into the root `/docs` single source of truth. You do no exploring and no doc-writing yourself; you carry the map between the two forks and keep your own context clean.

## When to use

- The user asks to bootstrap, refresh, audit, or clean up documentation with no accompanying code change.
- Docs are absent, thin, or suspected stale, and there is no diff or reviewed plan to drive dev-document's change flow.
- NOT for documenting a change built through the dev workflow — the orchestrator (e.g. `dev-start`) invokes **dev-document** directly for that.

## How it works

1. **Confirm scope.** For a monorepo, decide WITH the user whether to map the entire repo or one app and its dependencies. Set the target before exploring.
2. **Explore.** Invoke **dev-explore** directly via the Skill tool — it is a `context: fork` skill that runs in its own subagent and returns the structured map; NEVER wrap it in an Agent-tool spawn. Pass the scope as args and request **DEEP** mode — the default for this workflow, because the docs are the thing in doubt, so docs/READMEs cannot serve as ground truth (dev-explore's own AUTO rule reaches the same conclusion; pass a different mode only if the user explicitly asked for one). Collect the returned map.
3. **Document.** Invoke **dev-document** directly via the Skill tool — also a `context: fork` skill. Pass as args: the full structured map from step 2, a statement that this is a **map-driven** run (no plan path, no build summary, no diff), and the changelog preference (commit, `docs/changelog`, both, or none — ask the user if unstated and it matters). dev-document treats the map as ground truth for what to add, update, and delete under root `/docs`.
4. **Report.** Surface dev-document's summary (docs paths written, symlinks created or repaired, changelog outcome) together with anything dev-explore flagged as unverified.

## Context management

- **Pass pointers and the structured map, not raw file dumps.** Both phases are forks with no access to this conversation; inputs arrive only via invocation args.
- dev-explore's fork runs read-only and cannot write files — its final report IS the map. Relay it to dev-document verbatim in args; do not summarize it down.
- Forked skills self-manage their models via their own frontmatter.

## Hand-off / next

dev-map ends when dev-document reports. If dev-explore or dev-document surfaces that the docs problem is actually a code problem (implementation wrong or incomplete), stop and bring it to the user — recommend the dev workflow (`dev-start`) rather than papering over it in prose.

## Notes

- Tech-stack agnostic: report and document what the repo actually uses; never assume a stack.
- Docs and plans locations come only from `CLAUDE_DOCS_DIR`/`CLAUDE_PROJECT_PLANS_DIR` env vars or their defaults (root `/docs`, `/project-plans/`).
- Never push. dev-document may `git add` + `git commit` a changelog; publishing is out of scope for this workflow.
