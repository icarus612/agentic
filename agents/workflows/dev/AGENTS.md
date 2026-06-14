# Dev workflow

The core build pipeline. Each skill lives in [`skills/<name>/SKILL.md`](skills/)
and carries its own one-line `description` (what an agent matches on). This is the
**guide**: when to reach for each skill and how they hand off.

```
dev-start ─orchestrates─▶  dev-explore → dev-plan → dev-plan-review ─(repeat)─┐
                                              │ approved                       │
                                              ▼                                │
                  dev-code ⇄ dev-debug ⇄ dev-test ──▶ dev-code-review ─(loop to ANY phase)
                                              │ clean                          │
                                              ▼                                │
                                       dev-document (& log) ◀──────────────────┘
```

`(repeat)` and the review loop mean you can jump **back to any earlier phase**
when something is off, then resume forward.

### When to use each skill

1. **`dev-explore`** — start here for anything non-trivial, or when a later phase
   finds its understanding is stale. Shallow (docs/AGENTS.md/READMEs) or deep
   (full source); monorepo-aware. Read-only; outputs tech stack, patterns,
   conventions, dependency graph.
2. **`dev-plan`** — turn findings into an ordered plan saved to `/project-plans/`.
   Requires at least a shallow explore first. Pins major versions, enforces
   conventions as hard constraints.
3. **`dev-plan-review`** — the human gate before any code. Verifies every claim;
   does not assume; asks when unsure. Loops back to `dev-explore` or `dev-plan`,
   then switches to auto mode on approval.
4. **`dev-code` / `dev-debug` / `dev-test`** — the build loop. **Strict rules:**
   - `dev-code` never exits on its own — always hands to `dev-debug` or `dev-test`.
   - `dev-debug` may exit, but prefers handing back to `dev-code` or `dev-test`.
   - `dev-test` is the only skill that can break the loop.
5. **`dev-code-review`** — verify the implementation (same no-assumptions
   discipline). May loop back to **any** earlier phase.
6. **`dev-document`** — write technical docs into root `/docs` (single source of
   truth; in-project paths symlink in). Optional changelog: `git add` + `git
   commit` only — never push.

- **`dev-start`** — the orchestrator. Drives the whole pipeline and the
  loop-backs, and acts as context manager: Opus for itself, Sonnet worker agents
  (Opus for `dev-plan`), tracks the current step, surfaces only blockers and
  completion summaries. For a single phase, invoke that skill directly.

> Story/narrative documentation and ticket linking are **not** here — that's the
> [`delivery`](../delivery/AGENTS.md) workflow, which brackets this one.

Rules: dev-scoped rules live in [`rules/`](rules/) (`plans-and-docs-locations`);
universal rules are in [`../../rules/`](../../rules/). Each skill lists the rules
it needs in its `rules:` frontmatter.
