# Master redesign — merged proposal

One plan superseding the four prior documents. Restructure the library around three
execution tiers — **main-session orchestrator** (renamed `dev` → **`dae`**), **worker
agents** (`planner`, `builder`), and **cold forks/gates** — consolidate `map`,
`sync-status`, and `diagnose` into `dae` modes, and fold in the adopted architecture
items (return envelope, kickback reason codes, scoped-writes hook, the safety-critical
scripts) that previously had no owner.

**Merge rule: most-recent-wins.** Where the four sources conflict, the newest decision
stands and the older one is discarded, not reconciled. Sources and their fate:

| Source | Fate in this plan |
|---|---|
| `../workers-and-gates-redesign-07-26-26.md` (plan, 07-26) | **Skeleton of this plan.** All its phases carry forward, renumbered, with the merged additions below. Superseded by this file on approval. |
| `investigate-worker-07-22-26.md` (plan, 07-22; **deleted 2026-07-26**) | **Fully obsolete, never executed** — the file was removed from the repo. Its consumer (`diagnose` skill) and cross-ref target (`debug` skill) are deleted by this plan; its D1 return-inline decision lost to the artifact-on-disk convention. Its *content* — the investigation discipline and hypothesis envelope — is preserved in full in 6.1, which folds it into the planner's `plan-diagnosis` module. No `investigate` roster skill is created. |
| `agent-skills-architecture-overview.md` (proposal) | Items 2 (generalized), 3, 4, 5, 6, 9 (for `dae`) adopted here. Item 8 adopted **as a principle only**: the line-cited prose catalog is discarded as brittle (it cites files this plan rewrites or deletes); only functionally necessary scripts are scheduled, the rest is a fresh post-landing sweep. Items 1 (dissolved by mode consolidation), 7 (re-evaluate post-consolidation), 10–13 deferred. |
| `builder-loop-redesign-07-21-26.md` (proposal) | §7's authority split survives; its **packaging** is twice superseded: the skills-split framing fell to worker absorption, and §3-A's sequential single-context loop fell to the **packet model** (user directive 2026-07-30) — §3-B's isolated parallel authoring, adopted as the DEFAULT at packet granularity rather than an escalation mode. §4 nesting unknown is spike 1.1 (now a hard gate on 3.1, contingency D5); §5 cap/isolation coupling lands in 5.5; §8.1–8.2 naming/rename questions moot. |

**The rename (user directive, 2026-07-26):** the entry orchestrator is **`dae`**,
invoked `/dae`. Everything the prior plan said about `dev` applies to `dae`; the rename
lands with the thin-body rewrite (5.1) so it is one migration, not two.

## Roster disposition — full list

Every current skill and agent, with its fate under this plan. Universal roster goes
from 16 skills to 10 (plus two worker agents).

| Entry | Fate | Where it goes / what changes | Plan ref |
|---|---|---|---|
| `dev` | **Renamed + redesigned** | Becomes `dae`: a thin **router** body that parses flags, classifies the request, and activates ONE localized workflow sibling (`build.md`, `document.md`, `sync.md`, `diagnose.md`) plus shared detail files (`worktree-modes.md`, `confluence-mode.md`, `build-dispatch.md`); gate caps + kickback routing | 5.1–5.5, 6.1 |
| `code` | **Deleted (absorbed)** | Internal phase of the `builder` agent | 3.1, 3.2 |
| `debug` | **Deleted (absorbed)** | Internal phase of the `builder` agent (diagnose-only, never writes) | 3.1, 3.2 |
| `test` | **Deleted (absorbed)** | Split into `test-contract` / `test-impl` internal builder phases; test-impl is the sole loop-breaker | 3.1, 3.2 |
| `plan` | **Deleted (absorbed)** | Invariants → `planner.md`; type-specific content → planner modules | 4.1, 4.2, 4.4 |
| `map` | **Retired or aliased (D2)** | `/dae --type document` | 6.1, 6.3 |
| `sync-status` | **Retired or aliased (D2)** | `/dae --type sync`; reconciliation method → `plan-reconcile` planner module | 6.1, 6.3 |
| `diagnose` | **Retired or aliased (D2)** | `/dae --type diagnose`; investigation method → `plan-diagnosis` planner module | 6.1, 6.3 |
| `investigate` (planned, never built) | **Never created** | Its discipline + hypothesis envelope fold into `plan-diagnosis`; the investigate-worker plan was fully obsolete and its file deleted (2026-07-26) | 6.1 |
| `explore` | **Kept, redesigned** | Refocused as the shared mapping fork: artifact on disk, envelope return, no longer the mandatory pre-plan phase | 4.3 |
| `review-plan` | **Kept, light redesign** | Stays a cold gate; gains `scripts/validate-plan.sh` for the structural half; verdict becomes the shared envelope, returned to `dae` | 4.4 |
| `review-code` | **Kept, light redesign** | Stays a cold gate; verdict becomes the shared envelope carrying a kickback reason code | 5.4 |
| `init-workspace` | **Kept, timing change only** | Runs in parallel with planning; body untouched | 5.3 |
| `document-local` | **Kept** | Unchanged; remains the record stage in local-docs mode | — |
| `document-confluence` | **Kept** | Unchanged; remains the record stage in Confluence mode | — |
| `push-pr` | **Kept** | Unchanged | — |
| `review-pr` | **Kept** | Unchanged | — |
| `orchestrate` | **Kept** | Unchanged; item 1's description-overlap fix dissolved by mode consolidation | — |
| `push-main` (repo-only) | **Kept, mechanics scripted** | Sync step becomes `sync-install.sh` (whole directories, deletions) | 2.1 |
| `builder` (agent) | **Redesigned** | Becomes a per-chunk mini-orchestrator running the packet model: contract expansion → one parallel dispatch wave (`coder` ‖ `contract-tester` off the shared contract) → pipelined per-packet joins → debug-mediated rework → e2e/functional exit (authored + run by the builder — implementation-aware verification is its exit duty). Writes no implementation and no contract tests | 3.1 |
| `coder` (agent) | **New** | Thin sub-agent: implements ONE packet (≤~5 coupled files) against its contract slice; never reads or writes tests | 3.1 |
| `contract-tester` (agent) | **New** | Thin sub-agent: authors tests for one contract slice from the contract alone; never reads the implementation — in any mode, no exceptions (the blindness is its identity, not a dispatch parameter) | 3.1 |
| `planner` (agent) | **New** | Worker agent; invariants + per-type modules (`plan-{feature,bugfix,rework,migration,diagnosis,reconcile}.md`); warm revision loop | 4.1, 4.2, 6.1 |
| New harness scripts/hooks | **New** | `sync-install.sh`, `scope-writes.sh`, `validate-plan.sh`, `mark-syllabus.sh`, `verify-scope.sh`, `workflow-setup.sh --type` extension | 2.1, 2.2, 4.4, 5.2, 6.2 |

## `dae` — router + localized workflows

`dae`'s body is a **router**, not a workflow: it parses the invocation, classifies the
request into exactly one workflow, and activates that workflow's own localized sibling
file. Every workflow file owns its full stage sequence; the body owns only what is
common to all of them (flag parsing, setup/ship stages, the load-bearing invariants,
gate caps, kickback routing).

```
orchestrators/skills/dae/
  SKILL.md            ← router: trigger, flags, workflow-selection table, invariants
  build.md            ← the build workflow (issue types feature|bugfix|rework|migration):
                         planner → plan gate → builders → code gate → record → ship
  diagnose.md         ← root-cause workflow: planner(plan-diagnosis) → pick-causes gate
                         → fix builders → code gate → record → ship
  document.md         ← docs workflow (was map): deep explore → record → ship; no planner
  sync.md             ← reconcile workflow (was sync-status): planner(plan-reconcile) →
                         confirm-diff gate → record (tick syllabus, ticket, docs) → ship
  worktree-modes.md   ← shared: --worktree new|resume|none mechanics
  confluence-mode.md  ← shared: Confluence requirements capture + story file
  build-dispatch.md   ← shared by build.md and diagnose.md: lane dispatch, child-branch
                         merge-back, crash-resume
  scripts/            ← single-skill scripts (never loaded, only run)
```

**Full type coverage.** Two vocabularies, both routed by the same `--type` flag:

| `--type` value | Kind | Workflow file | Planner module | Branch type (6.2) |
|---|---|---|---|---|
| `feature` (default) | issue type | `build.md` | `plan-feature.md` | `feature/` |
| `bugfix` (alias `bug`, `debug`) | issue type | `build.md` | `plan-bugfix.md` (subphase 1.1 is always a failing regression test) | `bug/` |
| `rework` | issue type | `build.md` | `plan-rework.md` | `feature/` |
| `migration` | issue type | `build.md` | `plan-migration.md` | `feature/` |
| `hotfix` | issue type | `build.md` | `plan-bugfix.md`, minimal-scope constraint | `hotfix/` |
| `diagnose` | activity | `diagnose.md` | `plan-diagnosis.md` | `bug/` |
| `document` (alias `map`, `doc`) | activity | `document.md` | — (no planner) | `docs/` |
| `sync` | activity | `sync.md` | `plan-reconcile.md` | `sync/` |

The **bugfix vs diagnose** boundary: `bugfix` = the cause is known or the user states
the defect — plan the fix directly; `diagnose` = the cause is unknown — investigate,
rank, gate on the pick, then fix. The router states this rule so ambiguous "X is
broken" requests classify deterministically (unknown cause → `diagnose`).

**Flags.** Current accepted flags, verified from the live skills (2026-07-26:
`dev/SKILL.md` — `--explore`/`--exp`, `--worktree`/`--work`; `diagnose/SKILL.md` —
`--explore` defaulting deep, `--ref`; `map`/`sync-status` — none;
`workflow-setup.sh` — `--name`, `--base`, `--type feature|bug|hotfix`, `--reuse`),
consolidated into `dae`'s invocation contract:

| Flag | Values | Default | Provenance |
|---|---|---|---|
| `--type` | table above | infer from request; `feature` when purely additive ask | **New** (router selector; replaces separate entry points) |
| `--explore` (alias `--exp`) | `deep\|shallow\|auto` | per-workflow: `auto` (build), `deep` (diagnose, document) | Carried from `dev` + `diagnose` |
| `--worktree` (alias `--work`) | `new\|resume [<name>]\|none` | `new` | Carried from `dev`; now valid for every workflow (was `dev`-only) |
| `--ref` | `<branch\|pr\|range>` | resolved conversationally | Carried from `diagnose`; also consumed by `sync` (the shipped-work reference `sync-status` currently asks for conversationally) |
| `--base` | `<branch>` | `CLAUDE_BASE_BRANCH` chain via `workflow-setup.sh` | Promoted pass-through (today `dev`/`diagnose` prose passes it to the script on explicit override only) |
| `--name` | `<slug>` | derived from the task | Promoted pass-through to `workflow-setup.sh` (overrides the derived slug, e.g. to join a specific resumable run) |

Unknown flags are an error, not silently ignored. Flag parsing is one of the
mechanical candidates for the deferred scripts re-sweep (`parse-flags.sh`), not
scheduled in this plan.

> **EXECUTION RECORD (2026-07-30):** all phases executed and landed in one session, one
> push. Decisions: D1/D5 resolved YES by spike 1.1 (nesting works; no hoisting); D2 =
> alias stubs for one release — `dev`, `map`, `sync-status`, `diagnose` all reduced to
> thin stubs routing to `/dae`; D3 was pre-resolved (worktree-per-builder, always); D4 =
> extended vocabulary (`docs|sync` branch types added). Deviations: (a) the 4.4 "wire
> planner into dev" edit landed as part of 5.1's full router rewrite rather than as a
> separate dev edit — same session, same push, net-identical result; (b) the toy runs
> that require spawning the NEW agent/skill definitions (builder packet run, planner
> runs, `/dae` end-to-end smoke) could not execute in the landing session — Claude Code
> snapshots the agent/skill registry at session start, so the new definitions only go
> live after the install sync, in the next session. Scripts were all exercised against
> scratch fixtures (sync-install add/modify/delete + whole-dir, scope-writes
> allow/deny/traversal, validate-plan good/malformed, mark-syllabus flip/reopen/missing,
> verify-scope match/unreported, workflow-setup all five types + parent→child). The
> first real `/dae` run in a fresh session is the outstanding smoke test.

## Phase syllabus

Two lanes. Lane A is the serial core — nearly every subphase writes the shared
touchpoints (`orchestrators/skills/dae/SKILL.md`, `generic/AGENTS.md`,
`docs/pipeline.md`), so it stays strictly ordered. Lane B is harness-side work
(`orchestrators/hooks/`, `generic/rules/`, this repo's `.claude/skills/push-main/`) with
file scopes disjoint from lane A. Phase 1 spikes are read-only and independent of both.
Each phase lands via `push-main` and leaves the pipeline coherent: no landing may
reference a skill, agent, or file that does not exist at that commit.

- [x] Phase 1: Harness verification spikes  (run 2026-07-30)
  - [x] 1.1: Nested subagent spawning from a custom agent — **YES, both**: a `builder`-type agent spawned an Agent-tool subagent (Explore type, synchronous, reply received) AND invoked a `context: fork` skill (`explore`), which forked to its own subagent and returned a summary. → D1: planner spawns its own forks/subagents. D5: packet dispatch lives inside the builder.
  - [x] 1.2: SendMessage continuation and parallel spawning of custom agent types — **YES, both**: two `builder`-type agents spawned in one message ran concurrently; a SendMessage follow-up resumed one and it answered from retained context. → 4.4 revision loop and 5.4 kickback default use SendMessage.
  - [x] 1.3: `skills:` frontmatter preloading behavior inside agents — **YES**: the full bodies of the `skills:` frontmatter skills are injected verbatim into the agent's context at start (alongside the normal one-line availability listing). → planner needs no preload: since fork-invocation works inside agents (1.1), it invokes `explore` via the Skill tool on demand instead of carrying its body.
- [x] Phase 2: Shared harness scripts & hooks
  - [x] 2.1: `sync-install.sh`                                  (lane B)
  - [x] 2.2: Path-scope PreToolUse hook                          (lane B)
- [x] Phase 3: Builder becomes the packet-model mini-orchestrator
  - [x] 3.1: Rewrite `builder.md` (packet model) + `coder`/`contract-tester` agents + shared return envelope  (lane A, after: 1.1)
  - [x] 3.2: Delete `code`/`debug`/`test`, sweep references             (lane A, after: 3.1, 2.1)
- [x] Phase 4: Planner worker
  - [x] 4.1: `planner.md` system prompt — the invariants          (lane A, after: 3.2, 1.3)
  - [x] 4.2: Build-type modules (feature, bugfix, rework, migration)  (lane A, after: 4.1)
  - [x] 4.3: Refocus `explore` as the shared mapping fork         (lane A, after: 4.1)
  - [x] 4.4: Wire planner in; retire `plan`; `validate-plan.sh`   (lane A, after: 1.2, 4.2, 4.3)
- [x] Phase 5: `dae` reshape
  - [x] 5.1: Rename `dev` → `dae`; router body + `build.md` workflow + shared siblings  (lane A, after: 2.1, 4.4)
  - [x] 5.2: Dependency-driven dispatch + `mark-syllabus.sh` + `verify-scope.sh`  (lane A, after: 5.1)
  - [x] 5.3: Run `init-workspace` in parallel with planning       (lane A, after: 5.1)
  - [x] 5.4: Gate loops — caps, escalation, kickback reason codes (lane A, after: 5.1)
  - [x] 5.5: Per-builder worktree isolation (parent/child branches, per-builder init)  (lane A, after: 2.2, 5.2, 6.2)
- [x] Phase 6: Mode consolidation
  - [x] 6.1: Workflow siblings `diagnose.md`/`document.md`/`sync.md` + planner modules `plan-diagnosis` (absorbs investigate), `plan-reconcile`  (lane A, after: 5.2)
  - [x] 6.2: `workflow-setup.sh --type` + `artifact-locations` rule extension  (lane B)
  - [x] 6.3: Retire or alias `map`, `sync-status`, `diagnose`     (lane A, after: 6.1, 6.2)
- [x] Phase 7: Docs, principles, roster cleanup
  - [x] 7.1: AGENTS.md taxonomy and principles                    (after: 6.3)
  - [x] 7.2: `/docs` and README refresh                           (after: 6.3)
  - [x] 7.3: Supersession annotations, install-sync diff, end-to-end smoke test  (after: 7.1, 7.2)

## Goal & scope

**Goal.** One entry orchestrator (`dae`) routing to localized workflow files; two worker
agents (`planner`, `builder`) absorbing their single-consumer skills; cold gates and
thin forks for everything else; one shared return envelope; kickbacks routed to the
cheapest sufficient re-entry; orchestrator and builder writes harness-scoped; the
safety-critical mechanical steps scripted. The universal roster drops from ~16 entries
to ~9, and every loop/plan rule lives in exactly one file.

**In scope:**

- Everything in the workers-and-gates plan's scope (builder absorption, planner worker,
  thin `dae`, mode consolidation, spikes, doc/taxonomy updates, install sync at every
  landing) — under the new `dae` name.
- **The builder packet model** (user directive 2026-07-30, superseding brief §3-A's
  sequential default): within a chunk, code and test authoring run async in isolated
  sub-agents off a shared per-chunk contract, so cheating (coding-to-the-test,
  test-mirrors-code) is **structurally impossible, not disciplinary** — the artifact
  an agent would cheat off does not exist in any context it can see, and the
  debug-mediated rework loop preserves that property across iterations.
- **Item 3 — shared return envelope** (`status`, `artifacts[]`, `next`, `blockers[]`)
  defined once and adopted by every worker/fork this plan rewrites: builder exit
  report, planner return, `explore` output, review-gate verdicts, diagnosis subagents.
  Generalizes the prior plan's partial adoption of item 2 (explore-only).
- **Item 5 — kickback reason codes** at the code gate, defaulting to plan amendment via
  the warm planner (SendMessage), escalating to re-explore only on a wrong-map reason.
- **Item 6 — scoped writes**, merged with the prior plan's 4.4-B into ONE path-scope
  PreToolUse hook with two configurations (orchestrator scope, builder lane scope).
- **Scripts (item 8, principle only):** `sync-install.sh`, the path-scope hook,
  `validate-plan.sh`, `mark-syllabus.sh`, `verify-scope.sh`, `workflow-setup.sh
  --type`. Each lands in the phase that rewrites its consumer, specified by function —
  never by line numbers into files this plan changes.
- The **investigation discipline** from the investigate-worker plan, as content of the
  `plan-diagnosis` planner module — not as a roster skill.

**Explicitly out (deferred, recorded so they aren't re-proposed):**

- The rest of the item-8 catalog — re-swept fresh against the final file tree after
  Phase 7; the 2026-07-22 catalog is stale on arrival.
- Item 7 (`dispatch-policy.md`) — after consolidation only `dae` and `orchestrate`
  remain as consumers; re-evaluate then.
- Items 10–13 (self-improvement skill, orchestrator backlog, tech-skill gaps, plugin
  packaging — the last interacts with `sync-install.sh` and must be a deliberate
  migration decision if ever taken).
- The mechanical wide-sweep shape (one identical transform × many independent files —
  renames, API migrations at scale). Not a builder chunk: per-file failure isolation
  is the point and coherence is irrelevant, so it stays overview-item-11 backlog
  territory (its own orchestrator or Workflow-tool harness).
- A branch-management agent — rejected by design (git is the external state store);
  recorded in 7.1.
- Any change to `orchestrate`, `review-pr`, `push-main` (beyond 2.1's script call), or
  the tool-based layer. Item 9 progressive disclosure for any skill other than `dae`.

## Stack & versions

Unchanged from the prior plan (verified there, 2026-07-26): a content repo — Claude
Code skill/agent markdown plus Bash hooks; no language manifests or lockfiles. The
"stack" is the harness feature set: agent definitions in `agents/*.md` with `model:`
and `skills:` frontmatter; `context: fork` skills; the Agent tool (incl. `isolation:
worktree`); SendMessage continuation; `SessionStart`/`Stop`/`PreToolUse` hooks;
existing `workflow-setup.sh`, `resolve-config.sh`, `workflow-diff-check.sh`. Spikes
1.1–1.3 exist because three of these behaviors are unverified.

## Conventions to enforce

- `source-push-sync`: edit here, land on `main` via `push-main`, sync universal content
  to `~/.claude/` immediately — every phase. Deletions sync too (a stale
  `~/.claude/skills/test/` or `skills/dev/` would shadow the new design).
- `model-policy`: `planner` declares `model: opus`; `builder` stays `model: sonnet`;
  forks keep their own frontmatter.
- `plan-format`, `doc-format`, `artifact-locations` as written; 6.2 amends
  `artifact-locations` deliberately and is the only rule edit in the plan.
- `docs/conventions.md` body-section order for every skill body touched; the item-9
  amendment (SKILL.md + optional sibling files + optional `scripts/`) lands with 5.1.
- Every landing leaves a runnable pipeline: dangling-reference grep clean outside
  `project-plans/`, and the entry orchestrator invocable at every commit (`/dev` up to
  5.1, `/dae` from 5.1 on).
- Load-bearing invariants never move into sibling files: loop-exit authority, human
  gates, builders-never-edit-the-plan, push-policy.
- Scripts are specified by function, not by line citations into moving files.

## Phase detail

### Phase 1: Harness verification spikes

Read-only against the repo; artifacts to the session scratchpad; results recorded as
annotations in this syllabus. Identical to the prior plan's Phase 1 — reproduced here
so this file is self-contained.

**1.1: Nested subagent spawning from a custom agent**
- **Files:** this plan (results annotation only).
- **Pattern:** run twice — (a) a `builder`-type agent spawns a trivial sub-agent via
  the Agent tool; (b) a `builder`-type agent invokes a small `context: fork` skill.
- **Acceptance:** recorded yes/no for Agent-in-agent and fork-in-agent, with observed
  errors.
- **Decides:** D1 (planner's deep-explore escalation runs inside the planner vs `dae`
  hoists it) and **D5** — where the builder's packet dispatch lives. This spike is a
  **hard gate on 3.1**: the packet model requires the builder (itself an Agent-tool
  subagent) to spawn `coder`/`contract-tester` sub-agents. Nesting works → builder is a
  self-contained mini-orchestrator per chunk. Nesting blocked → D5's contingency.

**1.2: SendMessage continuation and parallel spawning of custom agent types**
- **Files:** this plan (results annotation only).
- **Pattern:** spawn two `builder`-type agents in one message with trivial disjoint
  tasks; SendMessage one a follow-up; confirm retained context.
- **Acceptance:** recorded yes/no for parallel spawn and warm continuation.
- **Decides:** whether the planner revision loop (4.4) and the kickback default (5.4)
  use SendMessage or fall back to re-spawn-with-corrections.

**1.3: `skills:` frontmatter preloading behavior inside agents**
- **Files:** this plan (results annotation only).
- **Pattern:** spawn a `builder`-type agent; have it report verbatim whether the loop
  skills declared in `builder.md` are present in its context at start.
- **Acceptance:** recorded yes/no; if no, note how skills actually load.
- **Decides:** whether `planner` gets `skills: [explore]` (4.1) or a read-the-file
  instruction.

### Phase 2: Shared harness scripts & hooks  (lane B)

Disjoint from every lane-A file; can land while Phase 1/3 run.

**2.1: `sync-install.sh`**
- **Files:** `orchestrators/hooks/sync-install.sh` (new), `.claude/skills/push-main/SKILL.md`
  (its sync step becomes "run the script"), `.claude/rules/source-push-sync.md` if its
  step-3 wording needs the pointer.
- **Pattern:** compute changed universal-domain files from `git diff`, map each to its
  `~/.claude/` install path, copy **whole skill directories** (sibling files arrive in
  5.1), **propagate deletions**, `diff` to verify. Precheck: on `main`, repo root, not
  a worktree; never stage `.claude/settings.local.json`.
- **Acceptance:** a scratch run over a synthetic diff (add + modify + delete, incl. a
  skill directory) produces a `diff`-clean install; push-main prose no longer describes
  the mechanics it now runs.
- **Test approach:** the scratch run above. Lands before 3.2 (first deletion) and 5.1
  (first sibling-file directory) — the two risky sync directions.

**2.2: Path-scope PreToolUse hook**
- **Files:** `orchestrators/hooks/scope-writes.sh` (new).
- **Pattern:** one config-driven hook denying Edit/Write outside an allowlisted path
  set. Its live consumer is the **orchestrator scope** (plan file + run artifacts;
  shrinks to run artifacts alone once `mark-syllabus.sh` lands in 5.2) — overview
  item 6. A builder-lane config is NOT wired: per-builder worktree isolation (5.5)
  makes it redundant. Hooks enforce, skills judge.
- **Acceptance:** hook exists with both configurations documented in its header; a
  scratch invocation denies an out-of-scope write and permits an in-scope one. Wiring
  into live skills happens in 5.5 — this subphase ships the mechanism only.
- **Test approach:** the scratch invocation.

### Phase 3: Builder becomes the packet-model mini-orchestrator  (lane A)

Single-consumer absorption, unchanged rationale (verified 2026-07-26: only builders
invoke `code`/`debug`/`test`) — but the absorbed loop is the **packet model**, not
§3-A's sequential single-context loop. The builder takes a chunk (its lane's
subphases), dispatches all authoring to isolated sub-agents, and itself writes only
the contract document, the e2e/functional suite, the test runs, and the final report.

**3.1: Rewrite `builder.md` (packet model) + `coder`/`contract-tester` agents + shared return envelope**
- **Files:** `orchestrators/agents/builder.md` (rewrite),
  `orchestrators/agents/coder.md`, `orchestrators/agents/contract-tester.md` (new),
  `docs/conventions.md` (envelope section).
- **Pattern — the builder's phases per chunk:**
  0. **Workspace.** Create the lane's own child worktree on `<type>/<name>-<lane-id>`
     off the run's parent branch (`workflow-setup.sh --parent`, per 6.2; `--reuse` on
     crash-resume) and run `init-workspace` in it. All subsequent phases run inside
     this worktree; the builder never touches the parent or sibling worktrees.
  1. **Contract expansion** (serial, builder's own context). Decompose the plan slice
     into a technical contract: per-packet interfaces, behaviors, and acceptance
     criteria. A **packet** is a cohesive group of ≤~5 coupled files sharing a
     contract slice — grouped by coupling the contract exposes, never by arithmetic.
     Internal detail only: anything changing externally-visible behavior beyond the
     approved plan escalates to the human gate. Sanity threshold: a chunk expanding
     past ~20–25 files means a mis-scoped lane (flag back to `dae`) or sweep-shaped
     work (out of scope for builders).
  2. **One parallel dispatch wave.** For every packet, spawn simultaneously a
     **`coder`** (implements the packet against its contract slice; never reads or
     writes tests) and a **`contract-tester`** (authors that slice's tests from the
     contract alone; never reads the implementation) — code packets per-file-group,
     test packets per-contract-slice (one tester may cover tightly-coupled files
     together). Neither sees the other's output: the no-cheat property is structural.
     Spawns queue against the harness concurrency cap; width = packet count. A
     subphase whose test oracle is the existing suite (see 4.2) simply has no
     contract-tester spawns.
  3. **Pipelined joins.** As each packet's code + tests both land, run that packet's
     tests immediately — no barrier on the slowest packet; red packets enter rework
     while others still author.
  4. **Debug-mediated rework.** On red, the builder's **debug** phase (diagnose-only,
     never writes, probes reverted) identifies the root cause and routes: code wrong →
     re-dispatch a fresh `coder` with the **contract + diagnosis — never the test
     source**; test wrong → re-dispatch a fresh `contract-tester` with the **contract +
     diagnosis — never the implementation source**. Debug is the anonymizing
     middleman; isolation survives every iteration, not just the first. Loop per
     packet until green.
  5. **E2E/functional tail (serial, sole exit).** Only after all packets are green:
     integration/functional/e2e tests across the whole chunk — the cross-file
     behavior no packet agent could see — **authored and run by the builder itself**.
     This is the old test-impl role: implementation-aware *by design*, so blindness
     has no value here; the temptation to weaken its own e2e checks is backstopped by
     the cold `review-code` gate and the Stop hook. Verified against the **plan**
     (not the contract; this is what catches a wrong contract that propagated
     identically into code and tests). Debug loop at chunk level the same way. Exit
     report = the shared envelope, quoting each acceptance criterion with the command
     and observed output that satisfied it.
  Invariants stated once at the top of `builder.md`: the builder writes no
  implementation and no contract tests (e2e authoring/running is its verification
  duty); `coder` is the only implementation writer; `contract-tester` is blind —
  never reads implementation, in any mode, no exceptions; debug never writes; only
  the builder's e2e phase exits; never-edit-the-plan and scope rules retained. Drop
  the `skills:` frontmatter line.
  **New:** `docs/conventions.md` gains the worker return envelope — `status`,
  `artifacts[]` (paths), `next`, `blockers[]` — and the builder's exit report is its
  first adopter.
- **Acceptance:** one authoritative statement of the invariants; no reference to
  `code`/`debug`/`test` as skills; both sub-agent definitions carry their isolation
  constraint in their own system prompts (not merely in dispatch prompts); envelope
  defined in exactly one place; dispatch is one wave with pipelined joins (no
  authoring barrier in the text).
- **Test approach:** builder on a toy two-packet chunk in a scratch repo with one
  seeded contract violation; transcript shows a single dispatch wave of coders +
  contract-testers, the red packet reworked via a fresh re-dispatch carrying diagnosis
  (not the opposing artifact), the e2e tail, and an envelope-shaped exit report.

**3.2: Delete the `code`/`debug`/`test` skills, sweep references**
- **Files:** delete `generic/skills/{code,debug,test}/`; edit
  `orchestrators/skills/dev/SKILL.md` (loop-rule restatement points at the builder's
  contract; the general-purpose-fallback clause removed — builder becomes required and
  synced), `generic/skills/plan/SKILL.md`, `orchestrators/skills/diagnose/SKILL.md`,
  `generic/AGENTS.md`, `docs/pipeline.md`, `README.md`.
- **Acceptance:** `grep -rn '\`code\` skill\|\`debug\` skill\|\`test\` skill'` clean
  outside `project-plans/`; install sync (via 2.1's script) removes
  `~/.claude/skills/{code,debug,test}` and installs
  `~/.claude/agents/{builder,coder,contract-tester}.md`.
- **Test approach:** the grep plus one toy `/dev` run reaching the build loop.

### Phase 4: Planner worker  (lane A)

Promotion justified by contract change: the planner explores for itself and survives
the revision loop. `review-plan` stays a cold gate.

**4.1: `planner.md` system prompt — the invariants**
- **Files:** `orchestrators/agents/planner.md` (new).
- **Pattern:** as the prior plan's 3.1 — invariants sourced from
  `generic/skills/plan/SKILL.md` (explore-first, `plan-format`, disjoint-lane rules
  incl. "separation outranks the builder-count target" from `2f596cd`, cited sources,
  no time estimates); classify-confirm-load; exploration ladder (`/docs` as claims →
  Explore fan-out → own reads → deep `explore` fork per D1/1.1); revision behavior
  (corrections as messages; rewrite fresh after repeated amendments). **Return is the
  shared envelope**: `artifacts[]` = [plan path], body = digest + declared
  classification + open decisions. Frontmatter: `model: opus`; `skills: [explore]` per
  1.3 or the read-the-file instruction.
- **Acceptance:** every plan-shape rule from the `plan` skill present here or in a 4.2
  module (side-by-side checklist); envelope-shaped return.
- **Test approach:** planner on a toy feature ask; plan passes `plan-format` by
  inspection; digest states classification.

**4.2: Build-type modules (feature, bugfix, rework, migration)**
- **Files:** `orchestrators/agents/planner/plan-{feature,bugfix,rework,migration}.md` (new).
- **Pattern:** modules carry only what differs; invariants stay in `planner.md`.
  Feature: story-anchored criteria, 2–5 builder lanes. Bugfix: 1.1 is always a failing
  regression test. Rework: existing suite passes unchanged; delete-the-old-path
  subphases. Migration: inventory → codemod → verify-equivalence; target idioms pinned
  from manifests. **Type variation lives in the plan, not the builder:** every
  subphase detail block must declare its **test oracle** — `new contract tests` (from
  the acceptance criteria), `existing suite` (rework: tests written before the change
  are the strongest anti-cheat oracle), or `equivalence check` (migration). The
  builder's uniform packet machine reads this field to size its contract-tester fan-out
  and stays type-blind — the classification is never duplicated at two tiers.
- **Acceptance:** no rule in two modules; no module restates an invariant; each
  loadable standalone; every module's subphase template carries the test-oracle field.
- **Test approach:** toy runs with types `bugfix` and `feature`.

**4.3: Refocus `explore` as the shared mapping fork**
- **Files:** `generic/skills/explore/SKILL.md`.
- **Pattern:** two consumers survive (planner escalation; `document` mode) so it stays
  a roster fork. Body trimmed to mapping; writes the full map to disk and returns the
  **envelope** (`artifacts[]` = [map path], body = short abstract) — item 2 executed
  through item 3's shape.
- **Acceptance:** no longer positioned as the mandatory pre-plan phase; envelope
  return; deep/shallow modes retained.
- **Test approach:** invoke on this repo; map file on disk, envelope back.

**4.4: Wire planner into the orchestrator; retire `plan`; `validate-plan.sh`**
- **Files:** `orchestrators/skills/dev/SKILL.md` (spawn planner with type; revision
  loop per 1.2 — SendMessage or documented re-spawn fallback; D1 hoist if nesting
  blocked), delete `generic/skills/plan/`, `generic/skills/review-plan/SKILL.md`
  (verdict returns to the orchestrator as an envelope; gate mechanics otherwise
  untouched), `generic/skills/review-plan/scripts/validate-plan.sh` (new),
  `generic/AGENTS.md`, `docs/pipeline.md`.
- **Pattern:** `validate-plan.sh` owns the structural half of plan review as schema
  checks — syllabus first, every phase has subphases, checkbox↔detail-block 1:1,
  `(after:)` targets real IDs, dependency graph acyclic, declared lane file scopes
  disjoint — so the reviewer fork spends its whole budget on verifying claims against
  reality. Item 4's judgment-loop rule applies to the gate: `max_iterations` + an
  explicit escalate-to-human branch.
- **Acceptance:** toy run produces a planner-authored plan; a revision instruction
  reaches the same planner instance (1.2 permitting); `validate-plan.sh` rejects a
  seeded malformed plan; `plan` gone from roster and install.
- **Test approach:** the toy run plus the dangling-reference grep for `` `plan` skill ``.

### Phase 5: `dae` reshape  (lane A)

**5.1: Rename `dev` → `dae`; router body + `build.md` workflow + shared siblings**
- **Files:** `orchestrators/skills/dev/` **renamed** `orchestrators/skills/dae/`;
  rewrite `SKILL.md` as the router; new siblings `build.md` (the build workflow —
  issue types `feature|bugfix|rework|migration|hotfix`), `worktree-modes.md`,
  `confluence-mode.md`, `build-dispatch.md`; `docs/conventions.md` (item-9
  amendment); reference sweep (`generic/AGENTS.md`, `orchestrators/AGENTS.md`,
  `docs/`, `README.md`, any hook or skill naming `/dev`); install sync adds
  `~/.claude/skills/dae/` (whole directory, via 2.1) and **deletes**
  `~/.claude/skills/dev/`.
- **Pattern:** the "`dae` — router + localized workflows" section above. The body
  keeps ONLY: trigger (`/dae`), the flag contract, the workflow-selection table
  (`--type` → workflow file, incl. the bugfix-vs-diagnose classification rule),
  the shared setup/ship stages, every load-bearing invariant, and read-pointers.
  All build-pipeline prose moves to `build.md`; conditional mechanics to the shared
  siblings. At this landing only `build.md` exists — the router table routes
  `diagnose|document|sync` to "not yet migrated: use `/diagnose`, `/map`,
  `/sync-status`" until 6.1 lands their files (every-landing-coherent rule). The
  rename is purely nominal; it lands here so the largest rewrite and the rename are
  one sweep.
- **Acceptance:** body under ~60 lines; invariant checklist against the old file
  passes; `/dae` invocable and `--type bugfix` selects `plan-bugfix` with a `bug/`
  branch; `grep -rn '/dev\b\|\`dev\` skill'` clean outside `project-plans/` and git
  history; a `--worktree none` toy run works end-to-end.
- **Test approach:** toy `/dae` runs (`--type feature`, `--type bugfix`) in each
  worktree mode to the plan gate; diff-review that no invariant moved to a sibling.

**5.2: Dependency-driven dispatch + `mark-syllabus.sh` + `verify-scope.sh`**
- **Files:** `orchestrators/skills/dae/build-dispatch.md`,
  `orchestrators/hooks/mark-syllabus.sh` (new), `orchestrators/hooks/verify-scope.sh` (new).
- **Pattern:** two dispatch tiers, never conflated — `dae` dispatches **lanes** to
  builders (this file); each builder internally dispatches **packets** to
  `coder`/`contract-tester` sub-agents (`builder.md`, 3.1, placement per D5).
  Event-driven scheduling on the syllabus's `(after:)` edges — when a
  builder reports, verify its lane (`verify-scope.sh`: reported files vs `git diff
  --name-only`), merge its child branch into the parent (per 5.5; a conflict is a
  mechanical scope violation), clean up the lane (worktree remove + branch delete,
  per 5.5), tick its subphases (`mark-syllabus.sh <file> <id>
  <state>` flips
  `- [ ]`→`- [x]`/`- [dropped]`), re-scan, dispatch immediately. Concurrency cap stays
  coupled to isolation (5.5). Builder crash-resume: a dead lane is respawned fresh and
  reads syllabus state (machine-checkable exit → loose loop, bounded respawn
  backstop). Scripting the syllabus tick is what lets the orchestrator's write scope
  shrink in 5.5.
- **Acceptance:** no wave-barrier concept in the dispatch text; toy 3-lane plan with a
  cross-lane edge shows the dependent lane launching before the slowest independent
  lane finishes; both scripts exercised in that run.
- **Test approach:** the toy 3-lane run.

**5.3: Run `init-workspace` in parallel with planning**
- **Files:** `orchestrators/skills/dae/SKILL.md` (stage table row).
- **Pattern:** fire `init-workspace` for the **parent worktree** in the background at
  planner spawn; join before the plan gate (whose verification may run commands
  there). Builders init their own child worktrees in their phase 0 (5.5) — this
  subphase covers the parent only.
- **Acceptance:** stage table shows plan and init concurrent; join point explicit.
- **Test approach:** toy run transcript shows both in flight.

**5.4: Gate loops — caps, escalation, kickback reason codes**
- **Files:** `orchestrators/skills/dae/SKILL.md` (both gate rows),
  `generic/skills/review-code/SKILL.md` (verdict shape only).
- **Pattern:** item 4 at both judgment gates: `max_iterations` + escalate-to-human.
  Item 5 at the code gate: the `review-code` verdict envelope carries a **reason code**
  (`plan-wrong` | `map-wrong` | `impl-wrong`); `dae` routes on it — `impl-wrong` →
  redispatch the builder lane with the findings; `plan-wrong` → SendMessage the warm
  planner an amendment (1.2 permitting; else re-spawn with corrections); `map-wrong` →
  re-run `explore`, then the planner. Default is the cheapest sufficient re-entry;
  full re-explore only on `map-wrong`.
- **Acceptance:** both gates capped with an escalation branch; the three reason codes
  and their routes stated once in the stage table; `review-code`'s verdict is the
  shared envelope with the reason code in `next`.
- **Test approach:** toy run in which a seeded plan flaw surfaces at the code gate and
  the transcript shows re-entry at plan amendment, not re-explore.

**5.5: Per-builder worktree isolation (parent/child branches, per-builder init)**
- **Files:** `orchestrators/skills/dae/build-dispatch.md`,
  `orchestrators/skills/dae/worktree-modes.md`; hook wiring for 2.2's
  `scope-writes.sh` orchestrator config (settings/frontmatter as the harness
  requires).
- **Pattern:** **D3 resolved (user directive 2026-07-30): worktree-per-builder,
  always** — not just multi-lane plans. `dae` creates the run's **parent** worktree
  on `<type>/<name>-parent` off the base branch (setup stage); each dispatched
  builder's phase 0 creates its own **child** worktree on `<type>/<name>-<lane-id>`
  off the parent branch (via `workflow-setup.sh --parent`, per 6.2) and runs
  `init-workspace` in it — a fresh git worktree shares history, not toolchains
  (`node_modules`, virtualenvs), so per-builder init is required, and it
  parallelizes: each lane's install runs concurrently as part of that lane. On a
  builder's exit report, dispatch merges the child branch into the parent
  (`verify-scope.sh` first; a merge conflict IS a mechanical scope violation —
  physical isolation replaces the builder-lane hook config, which is retired
  unneeded), then **cleans the lane up**: `git worktree remove` + prune and delete
  the child branch. Lanes are ephemeral — merged means gone; at run end exactly ONE
  worktree/branch pair remains (`<type>/<name>-parent`), which `push-pr` publishes
  and tears down as today. Cleanup happens only after a verified merge: a crashed or
  unfinished lane keeps its worktree/branch for crash-resume — a respawned builder
  reuses it (`--reuse`) instead of starting clean — and any lane still alive at
  teardown (dropped subphases) is surfaced to the user, never silently deleted. The final
  integration pass and plan-gate command runs happen in the parent worktree. With
  isolation landed, the concurrency cap decouples from collision risk and may rise
  (brief §5's cap/isolation coupling, satisfied). The 2.2 hook keeps ONE live
  config: orchestrator scope (plan file + run artifacts, per item 6).
- **Acceptance:** dispatch text contains no shared-worktree path for builders;
  adversarial toy 2-lane run — an out-of-scope builder write surfaces as a merge
  conflict at merge-back and `verify-scope.sh` flags it; each lane's transcript shows
  its own init; after both lanes merge, `git worktree list` shows only the parent
  (plus the repo root) and no `<type>/<name>-<lane-id>` branches survive; an
  orchestrator write outside plan-file/run-artifacts is denied by the hook.
- **Test approach:** the adversarial toy run, plus a kill-and-respawn of one builder
  confirming worktree reuse.

### Phase 6: Mode consolidation  (lane A except 6.2)

Consolidation rules: every mode shares setup and ship; each mode's unique middle is
one module or one fork; a mode needing special-casing inside a shared stage does not
consolidate. `orchestrate`, `review-pr`, `push-main` stay independent.

**6.1: Workflow siblings `diagnose.md`/`document.md`/`sync.md` + planner modules `plan-diagnosis` (absorbs investigate), `plan-reconcile`**
- **Files:** `orchestrators/skills/dae/SKILL.md` (router table rows go live), new
  workflow siblings `orchestrators/skills/dae/{diagnose,document,sync}.md` (sourced
  from `orchestrators/skills/diagnose/SKILL.md`, `map/SKILL.md`,
  `sync-status/SKILL.md`), `orchestrators/agents/planner/plan-diagnosis.md`,
  `plan-reconcile.md` (new).
- **Pattern:** each activity gets its own localized workflow file per the router
  section — issue types (nouns) select a planner module inside `build.md`; activities
  (verbs) select a workflow file. `document.md`: no planner — deep `explore` fork →
  record → ship. `sync.md`: planner runs `plan-reconcile` (reality vs plan/ticket;
  gate = confirm the diff; consumes `--ref` for the shipped-work reference) → no
  build → record → ship. `diagnose.md`: planner runs `plan-diagnosis` (consumes
  `--ref` for the suspect work) → pick-the-causes gate → builders (fixes only) →
  code gate → record → ship; shares `build-dispatch.md` with `build.md`.
  **`plan-diagnosis` absorbs the investigate-worker plan's content** (that plan was
  deleted 2026-07-26; this module is the sole surviving record of its method): the
  investigation discipline — reproduce → locate along the real flow →
  evidence-backed with probes reverted → never write a durable fix; the countable
  fan-out rule — one subagent per distinct suspect area, batched in one message;
  and the **hypothesis envelope** each investigation subagent returns (the shared
  envelope, body fields: `root_cause`, `evidence`, `likelihood High|Med|Low`,
  `ease High|Med|Low`, `proposed_fix`, `files`). The planner dedupes, ranks on
  likelihood × ease, and the ranked report **is** the plan; gate = pick the causes.
  No `investigate` roster skill — the module is its single consumer, same absorption
  rule as the builder's loop trio. Whether subagents are spawned by the planner or
  hoisted to `dae` follows D1/1.1, same as the explore escalation.
- **Acceptance:** each mode = one stage-table row + at most one module/fork; zero
  mode-conditional branching inside shared stage prose; the diagnosis discipline
  appears only in `plan-diagnosis.md`; toy `--type document` run produces docs + PR
  with no planner spawned; toy `--type diagnose` run (seeded bug) reaches the
  pick-the-causes gate with ranked, envelope-shaped hypotheses.
- **Test approach:** the two toy runs.

**6.2: `workflow-setup.sh --type` + `artifact-locations` rule extension  (lane B)**
- **Files:** `orchestrators/hooks/workflow-setup.sh`,
  `generic/rules/artifact-locations.md` (`type ∈ feature|bug|hotfix` clause), install
  copies via sync.
- **Pattern:** decision D4: extend to `feature|bug|hotfix|docs|sync` so
  `document`/`sync` runs keep the `<type>/<name>` branch shape. Plus the
  **parent/child scheme** (user directive 2026-07-30, consumed by 5.5): the script
  gains `--parent <branch>` to cut a worktree off an arbitrary parent branch instead
  of base. Naming: `dae`'s run worktree is `<type>/<name>-parent` (off base); each
  builder lane is `<type>/<name>-<lane-id>` (off the parent), where `<lane-id>` is
  the lane number or slugged phase title. Modes without builders (`document`, `sync`)
  create the parent only. The `artifact-locations` branch-shape clause is amended to
  record both extensions.
- **Acceptance:** `workflow-setup.sh --type docs --name x` creates `docs/x-parent`;
  `--parent docs/x-parent --name x-1` creates a worktree on `docs/x-1` off it; rule
  and script agree; existing three types unchanged.
- **Test approach:** run the script for all five types plus a parent→child pair in a
  scratch repo.

**6.3: Retire or alias `map`, `sync-status`, `diagnose`**
- **Files:** `orchestrators/skills/{map,sync-status,diagnose}/` (delete, or reduce to
  alias stubs invoking `/dae` with the mode — decision D2), `orchestrators/AGENTS.md`.
- **Acceptance:** no orchestration prose outside `dae` for these workflows; each
  retired entry point resolves via alias or documented `/dae --type` replacement;
  install sync reflects the outcome (deletions via 2.1's script).
- **Test approach:** invoke each retired entry point or its replacement once.

### Phase 7: Docs, principles, roster cleanup

**7.1: AGENTS.md taxonomy and principles**
- **Files:** `generic/AGENTS.md`, `orchestrators/AGENTS.md`, root `AGENTS.md`.
- **Pattern:** document the tier model and decision rules: *who needs to talk to it
  while it runs* (user → main-session skill; orchestrator → agent; nobody → fork);
  *workers warm, gates cold*; *absorb single-consumer skills into their worker*
  (builder loop trio, plan, the investigate discipline); *an agent earns a context
  only when its state can't be externalized* (branch-manager rejection); *fork when a
  summary is the deliverable*; the brief-§6 skill-minting rule; *every worker returns
  the shared envelope*; *scripts own the mechanical, prose owns the judgment*.
  Considered-and-rejected list includes the standalone `investigate` skill (folded —
  single consumer) with the one-line reason.
- **Acceptance:** every surviving entry and both agents in exactly one table with tier
  labeled; rejections recorded.
- **Test approach:** review pass against the final tree.

**7.2: `/docs` and README refresh**
- **Files:** `docs/pipeline.md` (rewrite around the stage table and two workers),
  `docs/architecture.md`, `docs/conventions.md` (verify 3.1's envelope and 5.1's
  item-9 amendment read correctly), `README.md`.
- **Acceptance:** no doc references a deleted skill or `/dev` as current; pipeline
  diagram matches the stage table.
- **Test approach:** dangling-reference grep scoped to `docs/` and `README.md`.

**7.3: Supersession annotations, install-sync diff, end-to-end smoke test**
- **Files:** `../workers-and-gates-redesign-07-26-26.md`,
  `agent-skills-architecture-overview.md`,
  `builder-loop-redesign-07-21-26.md` (each gets a header annotation: superseded by /
  merged into this plan, with the per-item disposition — for the brief: §3-B adopted
  as the packet-model default, §3-A superseded, §7's authority split preserved inside
  it), this plan's syllabus (final ticks).
- **Pattern:** proposals and superseded plans are records — annotate, don't rewrite.
- **Acceptance:** every adopted/discarded item names where it landed or why it died; a
  full `~/.claude/` install diff (via `sync-install.sh`) shows no drift; one
  end-to-end `/dae` feature run on a toy repo passes as the final smoke test.
- **Test approach:** the install diff plus the smoke run.

## Risks, open questions, decision points

**Decision points (human):**

- **D1 — deep-explore / investigation-fan-out placement: RESOLVED** (spike 1.1,
  2026-07-30): nesting works — the planner spawns its own forks/subagents (explore
  escalation in build modes, suspect-area investigation in diagnose mode). No hoisting.
- **D2 — alias stubs vs deletion** for `map`/`sync-status`/`diagnose` (6.3). Default:
  stubs for one release of habit, then delete. Note the rename doubles the muscle-memory
  argument — `/dev` also disappears; decide whether `/dev` gets a one-release stub
  pointing at `/dae`.
- **D3 — lane isolation: RESOLVED** (user directive 2026-07-30): worktree-per-builder,
  always — `dae` cuts `<type>/<name>-parent` off base; each builder cuts
  `<type>/<name>-<lane-id>` off the parent and runs its own `init-workspace`; merge
  conflicts at merge-back are the mechanical scope check. Recorded in 5.5/6.2; the
  builder-lane scope-hook config is retired unneeded.
- **D4 — branch-type vocabulary** (6.2): extend to `docs|sync` (recommended) vs map
  everything onto `feature/`.
- **D5 — packet-dispatch placement: RESOLVED** (spike 1.1, 2026-07-30): nesting works
  — the builder is a self-contained per-chunk mini-orchestrator spawning
  `coder`/`contract-tester` sub-agents itself. The hoist-into-`dae` contingency is not
  needed and was not built.

**Risks:**

- **Harness behavior assumed in three places** (nesting, SendMessage, preload) —
  Phase 1 converts assumptions to recorded facts; every dependent subphase names its
  spike. Nesting (1.1) is now the highest-stakes one: the packet model depends on it
  outright, with D5 as the designed contingency rather than a redesign-on-failure.
- **Token cost of the packet model** — per-packet sub-agents each re-read overlapping
  context, and every rework iteration spawns fresh agents. Accepted deliberately: the
  spend buys structural anti-cheating and authoring parallelism; packet grouping
  (≤~5 coupled files, cohesion-driven) is the cost bound, and wall-clock is capped by
  harness concurrency width regardless of fan-out count.
- **The rename widens the blast radius of the largest rewrite** (5.1): every reference
  to `/dev` — skills, docs, hooks, install — must move in one landing. Mitigation: the
  rename is nominal, the sweep is mechanical grep work, and the every-landing-coherent
  rule applies. **Out-of-repo references** (e.g. the user-global `~/.claude/CLAUDE.md`
  prose mentioning the dev workflow, muscle memory, external notes) can't be fixed
  from this repo — flagged at 5.1's landing as a manual follow-up.
- **Install desync on deletions** — mitigated by landing `sync-install.sh` (2.1)
  before the first deletion (3.2) and first directory-shaped skill (5.1); 7.3's full
  diff is the backstop.
- **Loss of ad-hoc phase invocation** (`code`/`debug`/`test`/`plan`) — accepted; their
  descriptions already forbade ad-hoc use.
- **Planner context growth** over long revision cycles — mitigated in 4.1; residual
  risk accepted.

**Open questions (non-blocking):**

- Whether `review-code` should re-run the suite itself rather than trusting builder
  exit reports — deferred to keep blast radius bounded.
- The post-landing scripts re-sweep (deferred item 8 remainder): scheduled as its own
  small plan after 7.3, against the final tree.

## Skill mapping

This plan executes in this repo under its own rules (`source-push-sync`: no worktrees,
no PRs, land on `main`):

- **Editing:** main session, direct edits, user-reviewed per phase.
- **Landing:** `push-main` after each phase — commit, push, install sync via
  `sync-install.sh` once 2.1 lands (hand-verified sync for Phase 1–2 landings before
  it).
- **Spikes (Phase 1):** main session via the Agent tool and scratch repos; no repo
  writes.
- **Toy-run verification:** scratch repos under the session scratchpad; 7.3's smoke
  test is a real `/dae` run on a toy project.
- **Syllabus upkeep:** this file is the living record — tick subphases as they land,
  annotate spike results and D1–D5 resolutions in place.
