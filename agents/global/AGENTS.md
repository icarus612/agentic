# Global agent instructions

Universal, tech-agnostic conventions that apply to **every** project and stack.
This is the base layer — stack and project layers add to it, they never replace
it. Everything here names technologies only as examples; bind to a real tech
stack via the relevant `stacks/<tech>/AGENTS.md` and the project itself.

---

## The workflow

All work flows through a fixed pipeline of skills. Each skill lives in
[`skills/<name>/SKILL.md`](skills/) and carries its own one-line `description`
(what an agent matches on to auto-select it). This section is the **guide**: it
says *when* to reach for each skill in more detail than that one-liner, and how
the skills hand off to each other.

```
begin  ──orchestrates──▶  explore → plan → plan-review ─(repeat)─┐
                                          │ approved             │
                                          ▼                      │
                              code ⇄ debug ⇄ test  ──▶ code-review ─(loop to ANY phase)
                                          │ clean                │
                                          ▼                      │
                                     document (& log) ◀──────────┘
```

`(repeat)` and the code-review loop mean you can jump **back to any earlier
phase** when something is off — a shallow explore turned out stale, the plan was
wrong, the build revealed a bad assumption — then resume forward.

### When to use each skill

1. **`explore`** — *start here for anything non-trivial, or whenever a later
   phase finds its understanding is wrong/stale.* Builds an accurate map of the
   codebase before any planning. Two modes: **shallow** (only `/docs`, `/agents`
   / `AGENTS.md`, and `README.md` files — fast orientation) and **deep** (full
   source, config, tests — real code paths). Monorepo-aware: explore the whole
   repo, or a single app and only its dependencies (root docs → `apps/[project]`
   → that app's `packages/[pkg]` deps). Read-only; outputs tech stack (with major
   versions), patterns, conventions, dependency graph, and what it could *not*
   verify.

2. **`plan`** — *once you have explore's findings and need a concrete path before
   touching code.* Turns patterns into an ordered, executable plan. Requires **at
   least a shallow explore first** (it will trigger `explore` if none happened).
   Pins **major versions** and enforces **all conventions** as hard constraints
   (e.g. no Svelte 4 idioms in Svelte 5, no Python 2 in 3.x, no vanilla CSS in a
   Tailwind project, prefer daisyUI over raw Tailwind — examples only). Saves the
   plan to the project root `/project-plans/` (or the `docs/AGENTS.md` location).

3. **`plan-review`** — *the human review gate, before any code is written.*
   Verifies every load-bearing claim in the plan against reality —
   **does not assume anything**. Minor assumptions are allowed only if a shallow
   explore verified them in docs, and even then it re-checks anything important
   (docs go stale). Asks questions when unsure; being unsure is fine, being
   **confidently incorrect is not**. Presents to the user for sign-off, then
   switches to auto mode. Can loop back to `explore` or `plan`.

4. **`code` / `debug` / `test`** — *the build loop; use once a plan is approved.*
   Three small skills that work in unison and call each other. **Loop rules
   (strict):**
   - `code` **never exits on its own** — always hands off to `debug` or `test`.
   - `debug` **may** exit, but **prefers** handing back to `code` or `test`.
   - `test` is the **only** skill that can break the loop (terminal success).

   Use `code` to implement a planned unit, `debug` to find and fix a root cause,
   `test` to verify against the plan and decide whether step 4 is truly done.

5. **`code-review`** — *after the build loop settles, before documenting.* Same
   verify-don't-assume discipline as `plan-review`, but the artifact is real code:
   checks it against the plan, the conventions, and for actual correctness/bugs.
   From here you may **loop back to ANY earlier phase** — into code/debug/test,
   back to `plan`, or all the way to `explore`.

6. **`document`** — *after code-review accepts the work.* Writes all docs into the
   **root `/docs`, the single source of truth**, mirroring the project structure
   (monorepo → `docs/apps/[project]`, etc.). In-project doc folders and project
   READMEs are **symlinks into `/docs`**, never copies. Optional changelog: a git
   commit (`git add` + `git commit` **only — never push**), a `docs/changelog`
   entry, or both.

- **`begin`** — *the orchestrator; use to drive the whole pipeline end to end.*
  Runs explore → plan → plan-review → code/debug/test → code-review → document,
  handling the loop-backs. Also the **context manager**: defaults itself to Opus,
  delegates the bulk of work to **Sonnet agents** (uses **Opus for the plan
  phase**), tracks the current step, and surfaces only blockers and completion
  summaries to keep its context window clean. For a single phase, invoke that
  skill directly instead of `begin`.

---

## Cross-cutting rules

- **Verify, don't assume.** Read the real code/config/docs. Being unsure and
  asking is correct; being confidently wrong is the failure mode the review gates
  exist to catch.
- **Respect major versions and conventions.** Use idioms correct for the
  installed major version; treat project conventions as hard constraints.
- **Plans live in `/project-plans/`**; **docs live in root `/docs`** (source of
  truth, in-project paths symlink into it).
- **Never push.** Changelog/commit work is `git add` + `git commit` only.
- **Model policy.** Each skill declares a `model:` (Anthropic-first) with an
  ordered `model-fallback:` ending in `gemini-pro`. `begin` and `plan` resolve
  opus → sonnet → gemini-pro; the rest sonnet → gemini-pro. Each tool honors what
  it supports (Claude Code: the single `model:` value only).
- **Tech-stack agnostic.** These skills name technologies only as examples; the
  actual stack comes from the project and its `stacks/<tech>/` layers.
