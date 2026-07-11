# Dev workflow

The core build pipeline. Each skill lives in [`skills/<name>/SKILL.md`](skills/)
and carries its own one-line `description` (what an agent matches on). This is the
**guide**: when to reach for each skill and how they hand off.

```
dev ─orchestrates─▶  explore → init-workspace → plan → review-plan ─(repeat)─┐
                                          │ approved                          │
                                          ▼                                   │
                     code ⇄ debug ⇄ test ──▶ review-code ─(loop to ANY phase)
                                          │ clean                             │
                                          ▼                                   │
                                document-local (& log) ◀──────────────────────┘
```

`(repeat)` and the review loop mean you can jump **back to any earlier phase**
when something is off, then resume forward.

### When to use each skill

1. **`explore`** — start here for anything non-trivial, or when a later phase
   finds its understanding is stale. Shallow (docs/AGENTS.md/READMEs) or deep
   (full source); monorepo-aware. Read-only; outputs tech stack, patterns,
   conventions, dependency graph.
2. **`init-workspace`** — make the worktree runnable: install dependencies and
   set up language toolchains so plan verification, the build loop, and tests
   all work.
3. **`plan`** — turn findings into an ordered plan saved to `/project-plans/`.
   Requires at least a shallow explore first. Pins major versions, enforces
   conventions as hard constraints.
4. **`review-plan`** — the human gate before any code. Verifies every claim;
   does not assume; asks when unsure. Loops back to `explore` or `plan`,
   then switches to auto mode on approval.
5. **`code` / `debug` / `test`** — the build loop. **Strict rules:**
   - The `code` skill never exits on its own — always hands to `debug` or `test`.
   - The `debug` skill may exit, but prefers handing back to `code` or `test`.
   - The `test` skill is the only skill that can break the loop.
6. **`review-code`** — verify the implementation (same no-assumptions
   discipline). May loop back to **any** earlier phase.
7. **`document-local`** — write technical docs into root `/docs` (single source
   of truth; in-project paths symlink in). Optional changelog: `git add` + `git
   commit` only — never push.
8. **`push-branch`** — terminal phase: commit stragglers, push the workflow
   branch (always asking first), tear down the worktree.

- **`dev`** — the orchestrator (`/dev`). Drives the whole pipeline and the
  loop-backs, and acts as context manager: Opus for itself, Sonnet worker agents
  (Opus for the `plan` skill), tracks the current step, surfaces only blockers
  and completion summaries. For a single phase, invoke that skill directly.
- **`map`** — the documentation-only orchestrator (`/map`): a deep `explore`,
  `init-workspace`, a map-driven `document-local`, then `push-branch`, on a
  dedicated `feature/{re,}map-repo` branch.

> Story/narrative documentation and ticket linking are **not** here — that's the
> [`delivery`](../delivery/AGENTS.md) workflow, which brackets this one.

Rules: the artifact conventions this workflow relies on — `artifact-locations`
(where docs/plans/worktrees live), `plan-format`, and `doc-format` (how they are
named and structured) — are universal rules in [`../../rules/`](../../rules/);
the workflow has no dev-scoped rules of its own. Each skill lists the rules it
needs in its `rules:` frontmatter.
