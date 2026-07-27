# Plan: `investigate` — a forked root-cause worker

Extract the "hunt a root cause and return a ranked hypothesis" discipline —
currently embodied as ad-hoc general-purpose subagents inside `diagnose` — into
a first-class, forked, read-heavy worker skill, applying the conventions the
`agent-skills-architecture-overview.md` proposal highlights. Then rewire the
one real consumer (`diagnose`) to invoke it, cross-reference it from `debug`,
and register it in the generic index.

Self-contained: every load-bearing fact below cites the file it was verified
from. This is the `agentic` skills library — a prose/markdown skill collection,
not a runtime codebase (verified: `README.md`, `AGENTS.md`) — so it follows
this repo's `source-push-sync` flow (edit on `main`, no worktree/PR, land via
`push-main`, sync universal content to `~/.claude/`).

## Phase syllabus

- [ ] Phase 1: Author the worker
  - [ ] 1.1: Write `generic/skills/investigate/SKILL.md`
- [ ] Phase 2: Wire the consumers
  - [ ] 2.1: Rewire `diagnose` to invoke `investigate`            (lane A, after: 1.1)
  - [ ] 2.2: Add a see-also cross-reference in `debug`            (lane B, after: 1.1)
  - [ ] 2.3: Register `investigate` in `generic/AGENTS.md`         (lane C, after: 1.1)
- [ ] Phase 3: Verify & land
  - [ ] 3.1: `review-code` gate over the authored/updated files   (after: 2.1, 2.2, 2.3)
  - [ ] 3.2: `push-main` + sync install                            (after: 3.1)

## Goal & scope

**In scope**
- A new `domain: universal`, `context: fork` worker skill `investigate` under
  `generic/skills/` that takes ONE suspect area + an issue, applies `debug`'s
  reproduce→locate→evidence method, and RETURNS a structured hypothesis
  (never writes a durable fix, never hands into a loop).
- Rewiring `diagnose` step 4 (and its dependent references) to fan out
  `investigate` forks — one per suspect area — instead of ad-hoc
  general-purpose Agent-tool subagents.
- A one-line see-also in `debug` distinguishing it (loop-bound) from
  `investigate` (forked, pre-fix, returns a result).
- Registering `investigate` in the `generic/AGENTS.md` skills table.

**Out of scope**
- Any new run-dir / on-disk artifact convention (`.claude/runs/…`). The repo's
  existing forked workers (`explore`) return their result INLINE as the final
  report; `investigate` matches that. See Decision D1.
- A `triage`/router skill, a `shared/dispatch-policy.md` extraction, or any
  other proposal idea not needed to ship `investigate`. (YAGNI — deferred.)
- Changing `debug`'s loop contract in any way beyond an additive see-also line.
- Touching `dev`, `sync-status`, `map`, `orchestrate` — none consume
  investigation (verified via `grep -rniE 'investigat|fan[ -]out|hypothes'`
  across `orchestrators/` and `generic/` SKILL.md files, 2026-07-22).

## Stack & MAJOR versions

- **Artifact type:** Claude Code Agent Skills — markdown `SKILL.md` files with
  YAML frontmatter. No language runtime, no package manager, no test suite
  (verified: `README.md` "It is **not** a project you run. Nothing here
  executes"). "Build" = authoring prose; "test" = the `review-code` gate.
- **Frontmatter contract** (verified from sibling skills `explore/SKILL.md`,
  `debug/SKILL.md`, `diagnose/SKILL.md`): `name`, `description`, `domain`,
  optional `context: fork` + `agent:`, `rules: […]`, `model:`,
  `model-fallback: […]`, optional `hooks:`.

## Conventions to enforce

- **`domain:` is the only classifier** (`AGENTS.md`). `investigate` is bound to
  no tech → `domain: universal` → lives in `generic/`, installs to `~/.claude/`.
- **Description = trigger spec, not summary** (proposal §2; `AGENTS.md` "each
  description states the pipeline it belongs to"). A single-word skill name in
  the generic layer must name its caller so it does not auto-fire on a stray
  keyword.
- **Fork read-heavy, inline write-heavy** (proposal §2). Investigation is
  read/reproduce-heavy and returns a summary → `context: fork`, mirroring
  `explore`.
- **Structured return envelope** (proposal §2): a fixed-shape return —
  `status`, the hypothesis fields, `next`, `blockers` — so the caller branches
  on fields, not re-parsed prose.
- **Countable fork criteria** (proposal §"One design constraint"): the CALLER
  decides fan-out by a countable rule — *one `investigate` per distinct suspect
  area* — not by "when it feels heavy."
- **Single responsibility / no contract creep** (`AGENTS.md`; `debug/SKILL.md`):
  `investigate` never writes a durable fix and never hands into a loop; that
  keeps it cleanly distinct from `debug`.
- **Tech-agnostic, verify-don't-assume, respect-versions-and-conventions**
  (always-on rules).
- **Repo flow:** `source-push-sync` — edit on `main`, no worktree/PR, land via
  `push-main`, then sync `SKILL.md` files to `~/.claude/skills/<name>/`.
  `AGENTS.md` is repo meta-doc → synced nowhere.

## Phase 1: Author the worker

### 1.1 — Write `generic/skills/investigate/SKILL.md`

- **Files:** `generic/skills/investigate/SKILL.md` (new).
- **Pattern to follow:** `generic/skills/explore/SKILL.md` for the fork shape
  (`context: fork` + `agent:`, "Inputs" section for a conversation-less fork,
  "Return contract" wording) and `generic/skills/debug/SKILL.md` for the
  diagnostic method (reproduce → locate → evidence → revert probes → never fix).
- **Frontmatter:** `name: investigate`; `domain: universal`; `context: fork`;
  `agent: general-purpose` (it must RUN commands to reproduce and add/revert
  probes, so the read-only `Explore` agent `explore` uses is too narrow —
  Decision D2); `rules: [verify-dont-assume, respect-versions-and-conventions,
  artifact-locations]`; `model: sonnet`; `model-fallback: [gemini-pro]`.
  No `hooks:`.
- **Description (trigger spec):** names its caller — invoked BY the `diagnose`
  orchestrator (and future incident/triage skills) to investigate ONE suspect
  area and return a ranked hypothesis; explicitly NOT the loop-bound `debug`
  skill and NOT for ad-hoc requests.
- **Body sections:** intro (the forked, return-a-result counterpart to
  `debug`); When to use; **Inputs** (arrives via args — issue text, the ONE
  suspect scope, diff/repro context, optional explore map); How it works
  (reproduce → locate via real flow → evidence-backed, probe reverted → grade
  likelihood + ease); **Output: the hypothesis envelope** (`status:
  investigated|inconclusive|blocked`; `root_cause`; `evidence`; `likelihood
  High|Med|Low`; `ease High|Med|Low`; `proposed_fix`; `files`; `next`;
  `blockers`); Hand-off / next (as a fork its return IS the hand-off; recommend
  the caller rank it against siblings); Notes (one suspect-space per invocation
  — caller fans out for several; never writes a durable fix; unverified ⇒ Low).
- **Acceptance:** frontmatter matches the sibling contract; description names
  `diagnose` as caller; envelope fields are explicit; the "never fix / never
  loop" boundary is stated; no stack hard-coded.
- **Test approach:** read-through against `explore`/`debug` for structural
  parity; confirmed at the 3.1 `review-code` gate.

## Phase 2: Wire the consumers

### 2.1 — Rewire `diagnose` to invoke `investigate`  (lane A)

- **Files:** `orchestrators/skills/diagnose/SKILL.md`.
- **Change:** In step 4, replace "spawn one investigation subagent per suspect
  area via the Agent tool … general-purpose subagents applying the discipline
  above" with: invoke the **`investigate`** skill directly via the Skill tool —
  one invocation per distinct suspect area (the countable fan-out rule), batched
  in a single message for concurrency when there are several; a simple localized
  bug uses a single `investigate`. Collect each returned hypothesis envelope;
  dedupe and rank on likelihood × ease (unchanged). Update the dependent
  references that say "investigation subagents": Context-management bullet
  (line ~75), Hand-off bullet (line ~82), and any Notes wording — so they name
  the `investigate` fork and keep the "NEVER wrap a forked skill in an
  Agent-tool spawn" rule consistent. The two-axis ranking, the diagnosis
  report, the human gate, and the fix loop are UNCHANGED.
- **Pattern to follow:** how `diagnose` already invokes `explore` ("invoke it
  directly via the Skill tool — it is a `context: fork` skill; NEVER wrap it in
  an Agent-tool spawn").
- **Acceptance:** no remaining reference to Agent-tool "investigation
  subagents"; `investigate` invoked as a fork; ranking/report/gate/fix intact.
- **Test approach:** re-grep for "investigation subagent" / "via the Agent
  tool" in the investigation context → none; 3.1 gate.

### 2.2 — Add a see-also cross-reference in `debug`  (lane B)

- **Files:** `generic/skills/debug/SKILL.md`.
- **Change:** add ONE line to the Notes section distinguishing `debug` (the
  loop-bound diagnosis half of the build loop) from `investigate` (the forked,
  pre-fix worker that returns a ranked hypothesis and never hands into a loop).
  Additive only — no change to `debug`'s loop contract, When-to-use, or
  hand-off rules (per the "editing skills minimally" guidance and Out-of-scope).
- **Acceptance:** exactly one additive cross-reference line; every existing
  `debug` rule byte-identical otherwise.
- **Test approach:** `git diff` shows only an addition; 3.1 gate.

### 2.3 — Register `investigate` in `generic/AGENTS.md`  (lane C)

- **Files:** `generic/AGENTS.md`.
- **Change:** add one row to the `skills/` table. Placement: adjacent to
  `debug` (its closest sibling), naming it as the forked, return-a-hypothesis
  counterpart invoked by `diagnose`.
- **Acceptance:** table row present, wording consistent with neighbors;
  file still valid markdown.
- **Test approach:** visual/table check; 3.1 gate.

## Phase 3: Verify & land

### 3.1 — `review-code` gate over the authored/updated files

- **Files (reviewed, not edited):** the four files above.
- **Change:** invoke `review-code` (fork) with this plan path + a change
  summary; it verifies the new skill and the rewiring against the plan and the
  repo's conventions. Human gate — loop back to Phase 1/2 on any finding.
- **Acceptance:** clean verdict (or all findings resolved).

### 3.2 — `push-main` + sync install

- **Files:** all four, plus this plan file.
- **Change:** via the `push-main` skill — commit on `main`, push, then sync the
  universal `SKILL.md` files to `~/.claude/skills/investigate/SKILL.md` and
  `~/.claude/skills/diagnose/SKILL.md` (and `debug/SKILL.md`); verify with
  `diff`. `generic/AGENTS.md` and the plan are repo docs — NOT synced.
- **Acceptance:** pushed commit range reported; install files `diff`-clean
  against source.

## Risks, open questions, decision points

- **D1 — Return inline vs. on-disk artifact.** The proposal favors
  "artifacts on disk, workers pass paths." But the repo's ONLY existing forked
  worker (`explore`) returns its map INLINE as the final report; no run-dir
  convention exists yet. **Decision: return inline** (the structured envelope
  IS the fork's final report), matching the established convention;
  `diagnose` consolidates envelopes into its on-disk diagnosis report, which
  already satisfies the "artifact on disk" intent at the orchestrator layer.
  Adopting a general run-dir is a separate, repo-wide change — deferred.
- **D2 — Which fork agent.** `explore` uses the read-only `Explore` agent.
  `investigate` must reproduce failures and add/revert probes → needs to run
  commands → **`agent: general-purpose`**. Flag at the gate if a narrower
  read-only investigation agent is later preferred.
- **D3 — Parallel fork invocation.** `diagnose` will invoke `investigate`
  multiple times (one per suspect area). If the harness cannot run several
  Skill-tool forks concurrently, they degrade to sequential — correctness is
  unaffected, only wall-clock. Noted, not blocking.
- **Open question:** should `debug` eventually be refactored to *delegate* to
  `investigate` to remove the duplicated method entirely? Out of scope now
  (would touch the load-bearing loop contract); revisit if a third consumer of
  the method appears.

## Skill mapping

- **Authoring (Phase 1–2):** because this is a prose/markdown skills repo with
  no runtime or test suite, the `code`→`debug`→`test` build loop is degenerate
  — the orchestrator authors the `SKILL.md`/index edits directly (as `map` and
  `sync-status` do for their doc/report artifacts), and `review-code` is the
  verification gate in place of a runtime `test` pass. Lanes A/B/C touch
  disjoint files and may be written together.
- **Phase 3.1:** `review-code` (fork) — the human gate.
- **Phase 3.2:** `push-main` (this repo's terminal skill, replacing `push-pr`).
