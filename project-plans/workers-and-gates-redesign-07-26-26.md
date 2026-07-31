> **SUPERSEDED (2026-07-30)** by [`proposals/master-redesign-07-26-26.md`](proposals/master-redesign-07-26-26.md),
> which carried all of this plan's phases forward (renumbered) and merged in the packet
> model, the `dae` rename, the shared return envelope, kickback reason codes, scoped
> writes, and the safety-critical scripts. Executed 2026-07-30 under the master plan —
> see its syllabus for what actually landed. This file is a record; do not execute it.

# Workers-and-gates redesign

Restructure the agent-skills library around three execution tiers — **main-session
orchestrator skills** (own the user and every human gate), **worker agents** (warm,
addressable contexts: `planner` and `builder`), and **cold forks** (one-shot phases and
stateless review gates) — then consolidate `map`, `sync-status`, and `diagnose` into
`dev` as modes of one stage table.

Companion documents (design rationale lives there; this plan is execution only):

- [`proposals/agent-skills-architecture-overview.md`](proposals/agent-skills-architecture-overview.md) —
  gap analysis; items 2, 4, and 9 are partially adopted by this plan where the rewrite
  touches the same files; item 8 stays its own migration.
- [`proposals/builder-loop-redesign-07-21-26.md`](proposals/builder-loop-redesign-07-21-26.md) —
  contract-first loop design; its §7 test split and §4 nesting unknown are executed here.

## Phase syllabus

Single lane, strictly ordered — no `(lane)`/`(after:)` annotations because nearly every
phase writes the same shared touchpoints (`orchestrators/skills/dev/SKILL.md`,
`generic/AGENTS.md`, `docs/pipeline.md`), so parallel lanes would collide by
construction. Each phase lands via `push-main` (commit + push + install sync) and leaves
the pipeline coherent: no landing may reference a skill, agent, or file that does not
exist at that commit.

- [ ] Phase 1: Harness verification spikes
  - [ ] 1.1: Nested subagent spawning from a custom agent
  - [ ] 1.2: SendMessage continuation and parallel spawning of custom agent types
  - [ ] 1.3: `skills:` frontmatter preloading behavior inside agents
- [ ] Phase 2: Builder absorbs the loop
  - [ ] 2.1: Rewrite `builder.md` around the contract/impl loop
  - [ ] 2.2: Delete the `code`/`debug`/`test` skills and update every reference
- [ ] Phase 3: Planner worker
  - [ ] 3.1: `planner.md` system prompt — the invariants
  - [ ] 3.2: Build-type modules (feature, bugfix, rework, migration)
  - [ ] 3.3: Refocus `explore` as the shared mapping fork
  - [ ] 3.4: Wire planner into `dev`; retire the `plan` skill
- [ ] Phase 4: Dev reshape
  - [ ] 4.1: Thin `dev` body + stage table + sibling files
  - [ ] 4.2: Dependency-driven builder dispatch
  - [ ] 4.3: Run `init-workspace` in parallel with planning
  - [ ] 4.4: Lane-isolation decision and implementation
- [ ] Phase 5: Mode consolidation
  - [ ] 5.1: `document`/`sync`/`diagnose` as dev modes + planner modules diagnosis, reconcile
  - [ ] 5.2: `workflow-setup.sh --type` and `artifact-locations` rule extension
  - [ ] 5.3: Retire or alias `map`, `sync-status`, `diagnose`
- [ ] Phase 6: Docs, principles, roster cleanup
  - [ ] 6.1: AGENTS.md taxonomy and principles
  - [ ] 6.2: `/docs` and README refresh
  - [ ] 6.3: Proposal reconciliation and install-sync verification

## Goal & scope

**Goal.** One entry orchestrator (`dev`) with a mode-dispatched stage table; two worker
agents (`planner`, `builder`) that absorb their single-consumer skills; cold review
gates and thin forks for everything else. The user-facing skill roster drops from ~16
universal entries to ~9, every loop/plan rule lives in exactly one file, and the
plan→build handoff loses its lossy summary boundary.

**In scope:**

- Absorbing `code`/`debug`/`test` into the `builder` agent, restructured around the
  contract-first loop (brief §3-A, §7): `test-contract → code → test-impl → (debug ⇄
  code) → test-impl exits`.
- A new `planner` agent with per-issue-type modules, preloaded explore methodology, and
  a SendMessage revision loop replacing cold re-forks.
- Rewriting `dev` as a thin stage-table router (adopting overview item 9's sibling-file
  shape for `dev` only) with dependency-driven dispatch.
- Folding `map`, `sync-status`, `diagnose` into `dev` modes `document`, `sync`,
  `diagnose` (mode names are activities; `feature|bug|rework|migration` are issue types
  selecting a planner module within the default build run).
- The harness spikes that gate these designs (nesting, SendMessage, `skills:` preload).
- Doc/taxonomy updates and install sync at every landing.

**Explicitly out:**

- Overview item 8's script catalog (own migration; only `workflow-setup.sh --type` is
  touched here because 5.2 requires it).
- Item 9 progressive disclosure for any skill other than `dev`.
- A branch-management agent — rejected by design (git is already the external state
  store; mechanics stay scripts, conflicts route to builders, `review-pr` stays a cold
  fork). Recorded in 6.1 so it is not re-proposed.
- The orchestrator backlog (overview item 11), plugin packaging (item 13), and any
  renaming of surviving skills (`explore` et al. keep their names; the rename question
  dissolved when the squatting skills left the roster).
- Any change to `orchestrate`, `review-pr`, `push-main`, or the tool-based layer.

## Stack & versions

This is a content repo — Claude Code skill/agent markdown plus Bash hooks. There are no
language manifests or lockfiles (verified: repo tree contains only `.md` files and
`*.sh` hooks; no `package.json` etc.). The "stack" is the Claude Code harness feature
set this plan relies on:

- Agent definitions in `agents/*.md` with `model:` and `skills:` frontmatter
  (`orchestrators/agents/builder.md` is the existing example).
- `context: fork` skills, the Agent tool (including `isolation: worktree`), and
  SendMessage continuation — **1.1–1.3 exist because three of these behaviors are
  unverified**; design branches that depend on them are marked with the deciding spike.
- Hooks: `SessionStart`, `Stop`, `PreToolUse`; `orchestrators/hooks/workflow-setup.sh`,
  `resolve-config.sh`, `workflow-diff-check.sh` (existing).

## Conventions to enforce

- `source-push-sync` (repo rule): edit here, land on `main` via `push-main`, sync
  universal content to `~/.claude/` immediately — every phase, no exceptions. Deleted
  skills must also be deleted from the install.
- `model-policy`: `planner` declares `model: opus` (planning is high-leverage);
  `builder` stays `model: sonnet`; forks keep their own frontmatter.
- `plan-format`, `doc-format`, `artifact-locations` as written; 5.2 amends
  `artifact-locations` deliberately and is the only rule edit in the plan.
- `docs/conventions.md` body-section order for every skill body touched; the item-9
  amendment ("SKILL.md + optional sibling detail files") lands with 4.1.
- Every landing leaves a runnable pipeline: no dangling references (`grep` for deleted
  skill names must come back clean outside historical proposals), and `/dev` must be
  invocable at every commit.
- Load-bearing invariants never move into sibling files (overview item 9's rule): the
  loop-exit authority, the human gates, builders-never-edit-the-plan, push-policy.

## Phase detail

### Phase 1: Harness verification spikes

Read-only against the repo; all artifacts go to the session scratchpad, results are
recorded as annotations in this plan's syllabus and in brief §4. No repo files change
except this plan.

**1.1: Nested subagent spawning from a custom agent**
- **Files:** this plan (results annotation only).
- **Pattern:** brief §4's proposed experiment, run twice: (a) spawn a `builder`-type
  agent whose only task is to spawn a trivial sub-agent via the Agent tool; (b) spawn a
  `builder`-type agent whose only task is to invoke a small `context: fork` skill.
- **Acceptance:** a recorded yes/no for both Agent-in-agent and fork-in-agent, with the
  observed error if no.
- **Test approach:** the spike is the test; both outcomes are acceptable results.
- **Decides:** D1 (planner's explore-fork escalation runs inside the planner vs `dev`
  hoists the deep explore before spawning it) and whether brief §3-B's parallel loop
  can ever live inside the builder.

**1.2: SendMessage continuation and parallel spawning of custom agent types**
- **Files:** this plan (results annotation only).
- **Pattern:** spawn two `builder`-type agents in one message with trivial disjoint
  tasks; after completion, SendMessage one of them a follow-up and confirm it retains
  prior context.
- **Acceptance:** recorded yes/no for (a) parallel spawn of custom types, (b)
  continuation with state intact.
- **Test approach:** the spike is the test.
- **Decides:** whether the planner revision loop (3.4) uses SendMessage or falls back
  to re-spawn-with-corrections (cold, but functional).

**1.3: `skills:` frontmatter preloading behavior inside agents**
- **Files:** this plan (results annotation only).
- **Pattern:** spawn a `builder`-type agent and have it report verbatim whether the
  three loop skills' instructions are present in its context at start (they are
  declared today in `builder.md:4`).
- **Acceptance:** recorded yes/no; if no, note how the skills actually load.
- **Test approach:** the spike is the test.
- **Decides:** whether `planner` gets `skills: [explore]` (3.1) or embeds the explore
  methodology by reference ("Read `generic/skills/explore/SKILL.md` before exploring").

### Phase 2: Builder absorbs the loop

Single-consumer absorption: `code`, `debug`, `test` are invoked only inside builders
(verified 2026-07-26: `dev` step 8 dispatches builders even for single-lane plans;
`diagnose` routes fixes through builders; no other caller exists). The loop trio leaves
the roster and becomes the builder's internal state machine.

**2.1: Rewrite `builder.md` around the contract/impl loop**
- **Files:** `orchestrators/agents/builder.md`.
- **Pattern:** brief §3-A (sequential, single-context, dual-source) and §7's authority
  split, absorbed as internal phases rather than roster skills — the §8.1 naming
  question is thereby moot (they are section labels, not skill names). Structure: loop
  state machine stated once at the top, then four phase sections carrying the surviving
  discipline from `generic/skills/{test,code,debug}/SKILL.md` (plan-anchoring,
  probe-reverting, evidence-backed exit, delete-what-you-replace):
  - **test-contract** — authors tests solely from the plan; never reads implementation;
    never runs; never exits. First phase of every subphase slice.
  - **code** — implements against the plan, never validates against the tests
    (Goodhart guard, brief §2); never exits.
  - **test-impl** — reads the real code, adds implementation-aware tests, runs the full
    slice suite; **sole loop-breaker**; exit report quotes each acceptance criterion
    with the command and observed output that satisfied it.
  - **debug** — diagnose-only, never writes, probes reverted; routes to code or
    test-impl. (Fixes `builder.md:13`, which still carries the pre-`d446227` "MAY
    exit" contract — the drift that motivated single-file ownership.)
  - Keep: scope rules, never-edit-the-plan, final-report shape. Drop the `skills:`
    frontmatter line. System-prompt placement is deliberate: it survives context
    compaction on long lanes, which the preload mechanism does not guarantee.
- **Acceptance:** one authoritative statement of the loop invariants (only test-impl
  exits; test-contract never reads code; debug never writes; code is the only
  implementation writer — brief §7); no reference to `code`/`debug`/`test` as skills;
  body materially shorter than the three absorbed skills combined.
- **Test approach:** spawn a builder on a toy two-subphase lane in a scratch repo;
  confirm the transcript shows contract tests authored before implementation and an
  evidence-quoting exit report.

**2.2: Delete the `code`/`debug`/`test` skills and update every reference**
- **Files:** delete `generic/skills/code/`, `generic/skills/debug/`,
  `generic/skills/test/`; edit `orchestrators/skills/dev/SKILL.md` (step 8 loop-rule
  restatement now points at the builder's contract; the "fall back to general-purpose
  subagents if `builder` isn't installed" clause is removed — builder becomes required,
  it is synced to `~/.claude/agents/` by the same flow), `generic/skills/plan/SKILL.md`
  (step 3: "account for the executing skills" → "shape subphases into builder lanes"),
  `orchestrators/skills/diagnose/SKILL.md` (loop references), `generic/AGENTS.md`
  (skill table), `docs/pipeline.md`, `README.md`.
- **Pattern:** the reference sweep in brief §1's file lists — same files, deletion
  direction.
- **Acceptance:** `grep -rn '\`code\` skill\|\`debug\` skill\|\`test\` skill'` over
  skills/agents/docs returns nothing outside `project-plans/`; install sync removes
  `~/.claude/skills/{code,debug,test}`.
- **Test approach:** the grep above plus one `/dev`-driven toy run reaching the build
  loop without referencing the deleted skills.

### Phase 3: Planner worker

Promotion justified by contract change, not packaging: the planner explores for itself
(stateful) and survives the revision loop (multi-interaction). Cold gates stay cold —
`review-plan` is untouched as an independent fork.

**3.1: `planner.md` system prompt — the invariants**
- **Files:** `orchestrators/agents/planner.md` (new).
- **Pattern:** `builder.md` as the agent-definition example; invariant content sourced
  from `generic/skills/plan/SKILL.md` (explore-first precondition, `plan-format`
  compliance, disjoint-file-scope/lane rules including "separation outranks the
  builder-count target" from `2f596cd`, verify-don't-assume with cited sources, no time
  estimates, return contract: plan path + digest + declared classification + open
  decisions). Adds the worker behaviors: classify-confirm-load (type hint from `dev`,
  classification stated in the digest so the human gate catches a wrong module);
  exploration ladder (`/docs` as claims → Explore-subagent fan-out → own targeted reads
  → deep `explore` fork only when scope is wide and `/docs` is missing/stale, wired per
  D1/1.1); revision behavior (corrections arrive as messages; after repeated amendment
  rounds, rewrite the plan fresh from conclusions rather than patching). Frontmatter:
  `model: opus`; `skills: [explore]` if 1.3 confirmed preloading, else the
  read-the-skill-file instruction.
- **Acceptance:** every plan-shape rule in the current `plan` skill is either present
  here or in a 3.2 module — verified by side-by-side checklist; nothing plan-related
  remains only in `generic/skills/plan/SKILL.md`.
- **Test approach:** spawn planner on a toy feature ask in a scratch repo; verify the
  produced plan passes `plan-format` by inspection and the digest states its
  classification.

**3.2: Build-type modules (feature, bugfix, rework, migration)**
- **Files:** `orchestrators/agents/planner/plan-feature.md`, `plan-bugfix.md`,
  `plan-rework.md`, `plan-migration.md` (new).
- **Pattern:** modules carry only what differs (the builder-absorption packaging rule);
  invariants stay in `planner.md`. Feature: story-anchored acceptance criteria, 2–5
  builder parallelism target. Bugfix: subphase 1.1 is always a failing regression test;
  usually single-lane. Rework: existing suite passes *unchanged*; inventory→transform
  lanes; explicit delete-the-old-path subphases. Migration: inventory → codemod →
  verify-equivalence; target-major idioms pinned from manifests.
- **Acceptance:** no rule appears in two modules; no module restates a `planner.md`
  invariant; each is loadable standalone (planner reads exactly one per run).
- **Test approach:** toy planner runs with type `bugfix` and type `feature`; confirm
  the bugfix plan opens with a regression-test subphase and the feature plan declares
  lanes.

**3.3: Refocus `explore` as the shared mapping fork**
- **Files:** `generic/skills/explore/SKILL.md`.
- **Pattern:** explore keeps two consumers (planner escalation; `document` mode as its
  main phase) so it stays a roster fork — the multi-consumer half of the absorption
  rule. Body trimmed to the mapping role: whole-repo/whole-area inventory, docs-shaped
  output. Adopts overview item 2 for its output: writes the full map to disk (plans dir
  of the working directory) and returns the path plus a short abstract, so consumers
  read the artifact first-hand instead of a relayed digest.
- **Acceptance:** description no longer positions explore as the mandatory pre-plan
  phase; output contract is path + abstract; deep/shallow modes retained.
- **Test approach:** invoke the fork on this repo; confirm a map file lands on disk and
  the return is a path + abstract, not inline prose.

**3.4: Wire planner into `dev`; retire the `plan` skill**
- **Files:** `orchestrators/skills/dev/SKILL.md` (steps 4–7: spawn planner via Agent
  tool with the type; revision loop per 1.2 — SendMessage corrections, or documented
  re-spawn fallback; `/docs`-staleness check at setup with the D1 hoist if 1.1 said
  nesting is blocked), delete `generic/skills/plan/`,
  `generic/skills/review-plan/SKILL.md` (verdict now returns to `dev`, which relays
  corrections to the warm planner — gate mechanics otherwise untouched),
  `generic/AGENTS.md`, `docs/pipeline.md`.
- **Pattern:** overview item 4's judgment-loop rule applied to the plan gate while
  editing it: `max_iterations` on the revise loop with an explicit escalate-to-human
  branch.
- **Acceptance:** `/dev` toy run produces a plan authored by the planner agent; a
  revision instruction reaches the same planner instance (1.2 permitting) and the
  updated plan reflects it without a fresh exploration pass; `plan` gone from roster
  and install.
- **Test approach:** the toy run above, plus the dangling-reference grep for
  `` `plan` skill ``.

### Phase 4: Dev reshape

**4.1: Thin `dev` body + stage table + sibling files**
- **Files:** `orchestrators/skills/dev/SKILL.md` (rewrite), new siblings
  `orchestrators/skills/dev/worktree-modes.md`, `confluence-mode.md`,
  `build-dispatch.md`; `docs/conventions.md` (item-9 amendment: skill = SKILL.md +
  optional sibling detail files); note `push-main`'s sync step must copy the whole
  skill directory from this landing on.
- **Pattern:** overview item 9's target shape, `dev` as the decided first migrant. Body
  keeps: trigger, the stage table (setup → plan → plan gate → build → code gate →
  record → ship), every load-bearing invariant (human gates never skipped, builders
  never edit the plan, only test-impl breaks the loop, push-policy), and read-pointers
  to siblings. Bulk conditional prose moves: `--worktree new|resume|none` mechanics →
  `worktree-modes.md`; Confluence requirements capture + story file →
  `confluence-mode.md`; dispatch detail → `build-dispatch.md`. Both judgment gates get
  item 4's cap + escalation branch.
- **Acceptance:** body under ~60 lines; every invariant from the current
  `dev/SKILL.md` present in the body (checklist against the old file); siblings only
  hold conditional detail; a `--worktree none` toy run works end-to-end reading
  `worktree-modes.md` on demand.
- **Test approach:** toy `/dev` run in each worktree mode reaching the plan gate;
  diff-review that no invariant moved to a sibling.

**4.2: Dependency-driven builder dispatch**
- **Files:** `orchestrators/skills/dev/build-dispatch.md`.
- **Pattern:** replace lock-step waves with event-driven scheduling on the syllabus's
  existing `(after:)` edges: when a builder reports — merge/verify its lane (scope
  check against git, affected checks), tick its subphases, re-scan for newly unblocked
  lanes, dispatch immediately. Concurrency cap stays (brief §5: cap and isolation move
  together — raised only if 4.4 lands isolation). Builder crash-resume per overview
  item 11: a dead or context-exhausted lane is respawned fresh; it reads syllabus state
  and continues (machine-checkable exit, so the loop runs loose with a bounded respawn
  backstop). Final integration pass retained from current step 8.
- **Acceptance:** dispatch text contains no concept of "wave barrier"; a toy 3-lane
  plan with a cross-lane edge shows the dependent lane launching before the slowest
  independent lane finishes.
- **Test approach:** the toy 3-lane run, watching dispatch order in the transcript.

**4.3: Run `init-workspace` in parallel with planning**
- **Files:** `orchestrators/skills/dev/SKILL.md` (stage table row).
- **Pattern:** the planner reads code, it does not build it — `init-workspace` needs
  only the stack identification, which manifests provide directly. Fire it in the
  background at planner spawn; join before the plan gate (whose verification may run
  commands).
- **Acceptance:** stage table shows plan and init as concurrent; join point explicit.
- **Test approach:** toy run transcript shows both in flight simultaneously.

**4.4: Lane-isolation decision and implementation**
- **Files:** `orchestrators/skills/dev/build-dispatch.md`; possibly a new PreToolUse
  scope hook in `orchestrators/hooks/` (option B).
- **Pattern:** decision point D3, informed by 1.1/1.2 and brief §5. Option A:
  worktree-per-lane — builders spawn with `isolation: worktree` (or lane worktrees cut
  by `workflow-setup.sh` off the run branch), merged into the run branch per lane; a
  merge conflict is a scope violation detected mechanically; fixes test contamination
  (a builder's suite run no longer sees sibling lanes' half-written code). Option B:
  shared worktree + PreToolUse hook denying Edit/Write outside the lane's declared file
  scope — preventive rather than post-hoc, no merge overhead, but contamination
  remains. Recommendation: land B's hook immediately (cheap, useful under both), adopt
  A only for multi-lane plans, keeping single-lane runs in the shared worktree.
- **Acceptance:** the decision is recorded here with rationale; whichever option lands
  is exercised by a toy 2-lane run in which one builder attempts an out-of-scope write
  and is blocked (B) or the collision surfaces as a merge conflict (A).
- **Test approach:** the adversarial toy run above.

### Phase 5: Mode consolidation

The neat-consolidation rules: every mode shares the same setup and ship stages; each
mode's unique middle is one module or one fork; a mode needing special-casing *inside*
a shared stage does not get consolidated. `orchestrate`, `review-pr`, `push-main` stay
independent.

**5.1: `document`/`sync`/`diagnose` as dev modes + planner modules diagnosis, reconcile**
- **Files:** `orchestrators/skills/dev/SKILL.md` (stage table rows),
  `orchestrators/agents/planner/plan-diagnosis.md`, `plan-reconcile.md` (new, sourced
  from `orchestrators/skills/diagnose/SKILL.md` and
  `orchestrators/skills/sync-status/SKILL.md` respectively).
- **Pattern:** the stage table —
  `feature|bug|rework|migration`: full pipeline;
  `diagnose`: planner runs `plan-diagnosis` (investigate → ranked causes graded by
  likelihood × ease; the report *is* the plan; gate = pick the causes) → builders (fixes
  only) → code gate → record → ship;
  `document`: no planner — deep `explore` fork → record (the point) → ship;
  `sync`: planner runs `plan-reconcile` (reality vs plan/ticket; gate = confirm the
  diff) → no build → record (tick syllabus, update ticket, refresh docs) → ship.
  Mode vocabulary is deliberately two families: issue types (nouns, select a planner
  module) and activities (verbs, select stage rows); `document` not `docs` — a location
  is not an action.
- **Acceptance:** each consolidated mode expressed as a stage-table row plus at most
  one module/fork; zero mode-conditional branching inside shared stage prose; toy
  `--type document` run produces docs and a PR with no planner spawned.
- **Test approach:** toy runs of `--type document` and `--type diagnose` (scratch repo
  with a seeded bug) to their respective gates.

**5.2: `workflow-setup.sh --type` and `artifact-locations` rule extension**
- **Files:** `orchestrators/hooks/workflow-setup.sh`,
  `generic/rules/artifact-locations.md` (its `type ∈ feature|bug|hotfix` clause), the
  user-level install copies via sync.
- **Pattern:** decision point D4 resolved here: extend the branch-type vocabulary to
  `feature|bug|hotfix|docs|sync` so `document`/`sync` runs keep the `<type>/<name>`
  branch shape (`map` previously hand-rolled `feature/map-repo`).
- **Acceptance:** `workflow-setup.sh --type docs --name x` creates `docs/x`; rule text
  and script agree; existing three types unchanged.
- **Test approach:** run the script for each of the five types in a scratch repo;
  verify branch names.

**5.3: Retire or alias `map`, `sync-status`, `diagnose`**
- **Files:** `orchestrators/skills/map/`, `orchestrators/skills/sync-status/`,
  `orchestrators/skills/diagnose/` (delete, or reduce to three-line alias stubs
  invoking `dev` with the mode — decision D2), `orchestrators/AGENTS.md`.
- **Pattern:** whichever way D2 goes, all workflow prose leaves these files; the
  duplicated scaffolding (worktree setup, docs-target resolution, push-pr teardown —
  currently maintained in four places) exists only in `dev` and its siblings.
- **Acceptance:** grep finds no orchestration prose outside `dev` for these workflows;
  `/map` either resolves via alias or is documented as `/dev` `--type document` in
  README; install sync reflects the outcome.
- **Test approach:** invoke each retired entry point (or its documented replacement)
  once against a scratch repo.

### Phase 6: Docs, principles, roster cleanup

**6.1: AGENTS.md taxonomy and principles**
- **Files:** `generic/AGENTS.md`, `orchestrators/AGENTS.md`, root `AGENTS.md`.
- **Pattern:** document the tier model and its decision rules so future additions
  self-classify: *who needs to talk to it while it runs* (user → main-session skill;
  orchestrator → agent; nobody → fork); *workers are warm, gates are cold*; *absorb
  single-consumer skills into their worker, keep multi-consumer skills as shared
  forks*; *an agent earns a context only when its state cannot be externalized* (the
  branch-manager rejection: git state is already external); *fork when a summary is
  the deliverable, explore inline when the trail is*; the skill-minting rule from brief
  §6 (new skill only on a write-authority/exit-authority/dispatch-point change).
- **Acceptance:** each surviving roster entry and both agents appear in exactly one
  table with tier labeled; the rejected alternatives (branch-manager agent,
  per-audience code skills) recorded as considered-and-rejected with the one-line
  reason.
- **Test approach:** review pass against the final file tree — every file accounted
  for, no table row pointing at a deleted path.

**6.2: `/docs` and README refresh**
- **Files:** `docs/pipeline.md` (rewrite around the stage table and two workers),
  `docs/architecture.md`, `docs/conventions.md` (verify 4.1's amendment reads
  correctly in final context), `README.md`.
- **Pattern:** `doc-format` — update in place, one page per topic, delete sections for
  removed skills.
- **Acceptance:** no doc references a deleted skill as current; pipeline diagram
  matches the stage table.
- **Test approach:** the dangling-reference grep, scoped to `docs/` and `README.md`.

**6.3: Proposal reconciliation and install-sync verification**
- **Files:** `proposals/agent-skills-architecture-overview.md` (annotate items: 2
  partially adopted — explore artifact; 4 adopted at both gates; 9 adopted for `dev`;
  1 re-scoped — mode consolidation changes the `orchestrate`/`dev` boundary analysis;
  11's crash-resume adopted), `proposals/builder-loop-redesign-07-21-26.md` (§4 spike
  results, §7 executed-as-absorbed, §8 decisions recorded), this plan's syllabus (tick
  final boxes).
- **Pattern:** proposals are records, not living specs — annotate, don't rewrite
  history.
- **Acceptance:** every decided/adopted overview item names where it landed; a full
  `~/.claude/` install diff against the repo's universal content shows no drift
  (agents, skills incl. sibling files, rules, hooks).
- **Test approach:** the install diff, plus one end-to-end `/dev` feature run on a toy
  repo as the final smoke test.

## Risks, open questions, decision points

**Decision points (human):**

- **D1 — explore-fork escalation placement** (gated by 1.1): nesting allowed → planner
  invokes the fork itself; blocked → `dev` checks `/docs` staleness at setup and runs
  the deep explore before spawning the planner, handing it the map path.
- **D2 — alias stubs vs deletion** for `map`/`sync-status`/`diagnose`: stubs preserve
  muscle memory (`/map`) at the cost of three roster slots; deletion gives one front
  door (`/dev` `--type document`). Default recommendation: stubs for one release of
  habit, then delete.
- **D3 — lane isolation** (4.4): worktree-per-lane (A) vs shared worktree + scope hook
  (B) vs the recommended hybrid (hook now, worktrees for multi-lane plans).
- **D4 — branch-type vocabulary** (5.2): extend to `docs|sync` (recommended) vs map
  everything onto `feature/`.

**Risks:**

- **Harness behavior is assumed in three places** (nesting, SendMessage continuation,
  `skills:` preload). Phase 1 exists to convert assumptions into recorded facts before
  any dependent design lands; every dependent subphase names its spike.
- **The `dev` rewrite is the largest single-file change** in the repo's history; a bad
  landing breaks the primary workflow. Mitigation: the every-landing-coherent rule,
  toy-run acceptance criteria per subphase, and `--worktree resume` compatibility
  verified in 4.1.
- **Install desync** — deletions are the risky direction (a stale `~/.claude/skills/
  test/` would shadow the new design). Mitigation: sync includes deletions at every
  landing; 6.3's full diff is the backstop.
- **Loss of ad-hoc phase invocation:** `code`/`debug`/`test`/`plan` stop being
  individually invocable. Accepted — their descriptions already forbade ad-hoc use;
  ordinary conversation covers ad-hoc asks.
- **Planner context growth** over long revision cycles. Mitigated in 3.1 (Explore
  fan-out keeps file dumps out; rewrite-fresh discipline after repeated amendments);
  residual risk accepted.

**Open questions (non-blocking):**

- Whether `push-main`'s sync step needs its `sync-install.sh` (overview item 8, build
  order #1) *before* sibling-file skills land in 4.1 — hand-syncing directories is
  error-prone. Can be pulled into 4.1's landing if hand-sync proves shaky.
- Whether `review-code` should re-run the suite itself (independent verification)
  rather than trusting builder exit reports — improves the gate, touches only
  `review-code/SKILL.md`, deferred to keep this plan's blast radius bounded.

## Skill mapping

This plan executes in this repo under its own rules (`source-push-sync`: no worktrees,
no PRs, land on `main`):

- **Editing:** main session, direct edits, user-reviewed per phase.
- **Landing:** the `push-main` skill after each phase (commit, push, install sync —
  including deletions and, from 4.1 on, whole skill directories).
- **Spikes (Phase 1):** main session via the Agent tool and scratch repos; no repo
  writes.
- **Toy-run verification:** scratch repos under the session scratchpad; the final smoke
  test (6.3) is a real `/dev` run against a toy project.
- **Syllabus upkeep:** this file is the living record — tick subphases as they land,
  annotate spike results in place, record D1–D4 resolutions in their subphase blocks.
