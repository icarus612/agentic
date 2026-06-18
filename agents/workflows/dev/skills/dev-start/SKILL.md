---
name: dev-start
description: Orchestrator that drives the full explore→plan→plan-review→code/debug/test→code-review→document workflow and manages context.
type: workflow
domain: dev
rules: [verify-dont-assume, model-policy, plans-and-docs-locations]
model: opus
model-fallback: [sonnet, gemini-pro]
---

# dev-start

You are the orchestrator. Drive the full development workflow from start to finish, delegate the real work to agents, track which step you are on, and keep your own context clean by surfacing only blockers and completion summaries. You are also the context manager for the whole run.

## When to use

- The user asks to start, drive, or "run the workflow" on a feature, fix, or project.
- Any non-trivial change that benefits from explore → plan → review → build → review → document.
- You need a single coordinator to track progress across multiple phases and loop back when things go wrong.

If the user wants only one phase (just an explore, just a plan), invoke that sibling skill directly instead of the full orchestration.

## The pipeline

Drive these phases in order. "Repeat" means you may loop back to ANY earlier step at the listed gates, then resume forward.

1. **dev-explore** — understand the codebase and patterns. ALWAYS request AUTO mode so explore picks DEEP or SHALLOW itself; handle monorepos.
2. **dev-plan** — turn findings into a concrete project plan saved under `/project-plans/` (or the location in `docs/AGENTS.md`).
3. **dev-plan-review** — verify the plan, ask when unsure. HUMAN review gate. May loop back to **dev-explore** or **dev-plan**. Repeat until the user approves; then switch to auto mode.
4. **dev-code / dev-debug / dev-test** — build the plan as a tight loop (see loop rules below).
5. **dev-code-review** — verify the implementation, same verify-don't-assume discipline. May loop back to ANY earlier phase. Repeat until clean.
6. **dev-document** — write everything into the ROOT `/docs` (mirror project structure), and optionally record a changelog (git commit only, never push; and/or `docs/changelog`).

## How it works

1. **Confirm scope.** Read the user's request. For a monorepo, decide WITH the user whether to cover the entire repo or one app and its dependencies. Set the target before exploring.
2. **Explore.** Delegate to **dev-explore** via a Sonnet agent, ALWAYS requesting AUTO mode so explore picks DEEP or SHALLOW itself rather than asking the user. Ensure AT LEAST a shallow explore happens before any planning. Collect the returned patterns/summary; do not pull the full file contents into your own context.
3. **Plan.** Delegate to **dev-plan** using an Opus agent (planning is high-leverage). Pass the explore summary, the current tech stack, and the available agent skills so the plan respects MAJOR versions and project conventions. Confirm the plan was written to `/project-plans/`.
4. **Plan review (gate).** Run **dev-plan-review**. This is the human gate: present the plan and the review's verified-vs-uncertain notes to the user. If the user dislikes it, loop back to **dev-explore** or **dev-plan** and repeat. Only proceed once approved, then switch to auto mode.
5. **Build (code/debug/test loop).** Hand the approved plan to the **dev-code** skill. Respect the loop rules exactly:
   - **dev-code** NEVER exits on its own — it always hands off to **dev-debug** or **dev-test**.
   - **dev-debug** MAY exit, but PREFERABLY hands to **dev-code** or **dev-test** when finished.
   - **dev-test** is the ONLY skill that can break the loop.
   Let the agents run the loop; only surface blockers or the completion summary back to yourself.
6. **Code review.** Run **dev-code-review** on the result. Same verify-don't-assume rigor as plan-review. From here you may loop back to ANY previous phase (code/debug/test, plan, or explore) if something feels off. Repeat until the review is clean.
7. **Document (& log).** Run **dev-document** to write into ROOT `/docs`, mirroring project structure (monorepo → `docs/apps/[project]`, etc.), keeping `/docs` as the single source of truth. Optionally record the changelog as a git commit (`git add` + `git commit` ONLY, NEVER push), in `docs/changelog`, or both.

## Context management

- **Default yourself to Opus.** You are the coordinator; protect your context window.
- **Delegate to Sonnet agents** for the bulk of the work (explore, code/debug/test, document). Use **Opus agents for the plan phase** (and any deep architectural reasoning).
- **Track the current step explicitly** (a TODO list or running status). Always know which phase you are in and which gate is next.
- **Let agents do the work.** Do not perform exploration, coding, or doc-writing yourself when an agent can.
- **Surface only what matters:** blockers, decisions needing the user, and concise completion summaries. Keep raw file dumps and verbose tool output OUT of your context.

## Hand-off / next

- dev-start invokes, in order: **dev-explore** → **dev-plan** → **dev-plan-review** → **dev-code** (which loops with **dev-debug** and **dev-test**) → **dev-code-review** → **dev-document**.
- Loop-back points: plan-review → explore/plan; code-review → any earlier phase. Resume forward after each loop.
- The run ends after **dev-document** (and optional changelog) completes with a clean code-review.

## Notes

- Tech-stack agnostic: any technology mentioned is an example only. Never hard-code a stack.
- Never skip the plan-review human gate. Confidently-incorrect plans are worse than slow ones.
- Enforce the code/debug/test loop rules without exception — only **dev-test** breaks the loop.
- Keep `/docs` (root) as the single source of truth; in-project doc folders and READMEs are symlinks into it.
- If a phase reports an unrecoverable blocker, stop and bring it to the user rather than improvising around it.
