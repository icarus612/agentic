---
name: dev-explore
description: Map a codebase before planning: deep (full project) or shallow (docs/AGENTS.md/README only) exploration, monorepo-aware, outputs tech stack, patterns, conventions, and dependency graph.
type: workflow
domain: dev
rules: [verify-dont-assume, tech-agnostic, plans-and-docs-locations]
model: sonnet
model-fallback: [gemini-pro]
---

# dev-explore

Before anyone plans or writes code, you build an accurate map of the codebase: its tech stack, the patterns it uses, the conventions it enforces, and how its pieces depend on each other. You are a reader and cartographer, not an editor — you change nothing and produce a structured map every later step relies on.

## When to use

- At the start of any non-trivial task, kicked off by `dev-start` or run directly.
- When `dev-plan`, `dev-plan-review`, or `dev-code-review` finds the current understanding is wrong or stale and loops back.
- Any time you need ground truth about a project instead of assumptions.

## Two modes

Pick one up front and state which you're running.

**SHALLOW** — fast orientation. Read ONLY the root `/docs` (source of truth), agent guidance (`/agents`, `AGENTS.md`, any `CLAUDE.md`), and every `README.md`. Use it to confirm facts, refresh stale knowledge, or meet the minimum a plan requires (never plan without AT LEAST a shallow explore). Cheap; run it liberally.

**DEEP** — full understanding. Read the entire target: source, config, tests, build files, docs. Trace real code paths, not descriptions. Use when the task touches non-trivial logic or you can't answer the structured-map questions from docs alone.

## Monorepo awareness

Detect single project vs. monorepo (look for `apps/`, `packages/`, workspace manifests, multiple build files). For a monorepo, choose ONE scope:

1. **Whole monorepo** — every app and package. Use when the task is cross-cutting or scope is unknown.
2. **Single app + its dependencies only** — explore in order and STOP at the edges: (1) root/global docs (`/docs`, `AGENTS.md`), (2) `apps/[project]/docs` and the app's source, (3) the docs and (if deep) source of EACH dependency it actually uses, e.g. `packages/[pkg]`. Don't wander into unrelated apps/packages.

The root `/docs` is the SINGLE SOURCE OF TRUTH; in-project doc folders and READMEs are SYMLINKS into it — same content, don't double-count. If `docs/AGENTS.md` names a different docs/plans location, honor it.

## How it works

1. **Declare scope and mode.** DEEP or SHALLOW; for monorepos, whole-repo or single-app(+deps), naming the target app.
2. **Read global guidance first.** `AGENTS.md`/`CLAUDE.md` and root `/docs` define the conventions to report; note any override (docs/plans location, tooling).
3. **Identify the tech stack.** From manifests, lockfiles, config: languages, frameworks, libraries, and especially MAJOR VERSIONS — record them precisely, since they drive which idioms are legal later.
4. **Map structure and dependencies.** Walk the layout. For monorepos build the app/package dependency graph; for a single app list exactly which internal packages and external libraries it depends on.
5. **Extract patterns and conventions** (deep, or as far as docs allow): how code is organized, named, tested, styled; what's idiomatic vs. forbidden (styling, preferred reuse, error handling, test layout, lint/format rules).
6. **Note the doc/symlink topology** — where source-of-truth docs live and which paths are symlinks into them.
7. **Produce the structured map** below. Be concrete, cite real paths, and flag anything you couldn't verify.

## Output: the structured map

- **Scope & mode** — what you explored and how.
- **Tech stack** — languages, frameworks, libraries WITH major versions.
- **Structure** — directory layout; apps/packages for monorepos.
- **Dependency graph** — who depends on whom (internal and key external).
- **Patterns** — idiomatic organization, naming, testing, styling.
- **Conventions / rules** — enforced standards, preferred reuse, forbidden patterns, tooling (lint/format/build/test).
- **Docs topology** — source-of-truth docs, which paths are symlinks, the plans location.
- **Open questions / unverified** — anything uncertain; flag rather than assert.

## Hand-off / next

Hand the map to `dev-plan`; its accuracy directly determines plan quality. If you ran shallow, say so — `dev-plan` may need a deep pass for risky areas, and `dev-plan-review` will re-check shallow facts since docs can be stale.

## Notes

- Read-only: never edit, format, or run mutating commands.
- Prefer real code and config over prose; descriptions drift, source doesn't.
- Be honest about coverage — "I did not read X" beats a confident guess.
- Stay tech-agnostic: any technology named is only an example; report what the repo actually uses.
- Respect scope boundaries in single-app mode to stay fast and keep your context clean for `dev-start`.
