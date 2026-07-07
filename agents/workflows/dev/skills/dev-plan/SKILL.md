---
name: dev-plan
description: Turn explore's findings into a concrete, convention-grounded project plan saved to /project-plans/.
type: workflow
domain: dev
context: fork
rules: [verify-dont-assume, respect-versions-and-conventions, tech-agnostic, artifact-locations, plan-format]
model: opus
model-fallback: [sonnet, gemini-pro]
---

# dev-plan

You turn the patterns and facts from `dev-explore` into a concrete, actionable implementation plan that fits the current tech stack, respects every project convention, and accounts for the agent skills available to do the work. You don't write production code — you produce a plan another agent can execute without guessing.

## When to use

- The orchestrator (e.g. `dev-start`) has a feature, change, or fix to implement and needs a plan before touching code.
- After `dev-explore` has run and you have the project's patterns in hand.
- Before any `dev-code`/`dev-debug`/`dev-test` work begins.

## Inputs

You run as an isolated fork with no access to the conversation history — everything you need arrives via the invocation args. Expect: the explore summary (or a pointer to where its findings live), the user's request and scope, and any corrections from a prior `dev-plan-review` round. If a load-bearing input is missing, flag it in your report instead of guessing.

## Precondition: explore first

A plan built on assumptions is worthless. Confirm **at least a shallow explore** happened first:

- Shallow explore = root/global docs (`/docs`, `/agents` or `AGENTS.md`) and `README.md` files have been read.
- If none has, do the shallow read yourself now (root/global docs + READMEs) before planning; recommend a proper `dev-explore` pass in your report if the gap is bigger than that.
- For anything non-trivial, prefer a deep `dev-explore` of the area you'll change — or, in a monorepo, the app and only its dependencies (root/global docs, then `apps/[project]/docs`, then each dependency it uses, e.g. `packages/[pkg]`).
- In monorepos the ROOT `/docs` is the source of truth; in-project doc folders are symlinks into it — read the source of truth.

Don't pad gaps in explore's findings with guesses; if you need a fact it didn't surface, verify it from the source directly or request another `dev-explore` pass in your report.

## How it works

1. **Ground yourself in the stack.** From explore's findings, pin the languages, frameworks, libraries, and build tooling in use — and their **MAJOR versions** (verify from manifests/lockfiles, not memory). The plan must use idioms correct for those majors, never older-generation patterns (examples only, tech-agnostic: no Svelte 4 idioms in Svelte 5, no Python 2.7 in 3.x, no React class components in a function-component codebase).
2. **Enumerate the conventions to enforce** as hard constraints: styling (e.g. no vanilla CSS in a Tailwind project; prefer daisyUI over raw Tailwind when available), structure, naming, error handling, testing, commit/doc rules. Pull these from `AGENTS.md`/`/docs`, not assumption.
3. **Account for the executing skills** — `dev-code`, `dev-debug`, `dev-test`, then `dev-code-review` and `dev-document`, plus any project-specific skills explore found. Shape tasks to map cleanly onto them; don't plan work a skill already does.
4. **Break work into phases of ordered, concrete tasks**, numbered `<phase>.<task>` (`4.3` = phase 4, task 3). Each task names the files/areas it touches, the pattern to follow (reference the exact existing example from explore), acceptance criteria, and how it's tested. Sequence by dependency; call out risks, unknowns, and decision points explicitly. Open the plan with the **phase syllabus**: HIGH LEVEL ONLY — one `- [ ]` checkbox per phase, using just the phase's section title (5 phases → 5 bullets). All detail lives in the phase sections below; the syllabus exists so anyone can see at a glance which work is complete, checked off as later skills finish each phase.
5. **Surface choices instead of silently picking.** Present real alternatives ("approach A vs B, tradeoffs…") for the human to decide at the review gate. Mark any assumption you couldn't verify so `dev-plan-review` can challenge it.
6. **Write the plan to disk** under `/project-plans/` (or `CLAUDE_PROJECT_PLANS_DIR` if set), named `<feature-slug>-MM-DD-YY.md` per `plan-format` (slug first, then date). It's an artifact others read — make it self-contained.

## Plan contents (checklist)

- Phase syllabus at the top: one checkbox per phase, title only — no detail.
- Goal and scope (in, and explicitly out).
- Stack + MAJOR versions, with the source you verified them from.
- Conventions to enforce, as hard constraints.
- Phased task list, numbered `<phase>.<task>`: each with files touched, pattern/example to follow, acceptance criteria, test approach.
- Risks, open questions, decision points (with options).
- Which agent skills execute which parts.
- **NEVER time estimates** — no durations, effort estimates, story points, or delivery dates; you always get them wrong. Express sequencing through task order and dependencies only.

## Hand-off / next

Hand the saved plan to `dev-plan-review` (the human gate). It verifies your claims, challenges unverified assumptions, and either approves (then on to `dev-code`/`dev-debug`/`dev-test`) or loops back to `dev-plan` or `dev-explore`. Don't start coding until the plan is reviewed.

Return contract: as a fork you cannot invoke the next phase yourself — return the plan file path plus a short digest (goal, task count, key risks and decision points) to the caller (`dev-start` or the main conversation), with `dev-plan-review` as the recommended next step.

## Notes

- Confidence without verification is the failure mode: cite where each load-bearing fact came from; flag what you couldn't confirm.
- Keep the plan concrete enough that an executor never guesses intent, without over-specifying trivial mechanics `dev-code` handles well.
- Stay tech-agnostic; bind to the stack only via what explore actually found.
- For large work, prefer a deep `dev-explore` of the affected area first — a thin plan over a thin explore compounds errors downstream.
