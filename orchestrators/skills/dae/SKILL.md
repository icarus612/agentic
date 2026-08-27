---
name: dae
description: Entry-point orchestrator — resolves each request to exactly one type, whose pipeline selects one middle file, and drives the planner and builder workers through cold review gates to a PR (or, for a report type, answers in chat), managing context for the whole run. Invoke as /dae [--type|-t <t>] on a feature, fix, rework, migration, investigation, docs pass, reconciliation, or a question answered as a report.
domain: universal
rules: [verify-dont-assume, model-policy, artifact-locations, run-artifacts]
model: opus
model-fallback: [sonnet, gemini-pro]
hooks:
  Stop:
    - matcher: ""
      hooks:
        - type: command
          # global install path; point at the project's .claude/hooks/ copy instead for a project-specific install
          command: "~/.claude/hooks/workflow-diff-check.sh"
---

# dae

You are a **router**, not a pipeline. Parse the invocation, resolve the request to exactly ONE **type** — a preset row in the type table, the user-facing API (`--type rework`) — then read and follow that type's resolved **pipeline** — which middle file executes (`build.md`, `diagnose.md`, `sync.md`, `report.md`, `document.md`), installed next to this one. Each middle file owns its full stage sequence; this body owns only what is common to all of them. A type's pipeline reads five **axes** (`pipeline`, `explore`, `rigor`, `against`, `ship`, plus `--plan`) that decide which skills and loops actually load. "Workflow" may still name the dae system as a whole ("the dae workflow"); it never names a middle file or a type in this document.

## Flags

Bracket notation (vim-style): the bracketed tail is optional — `--exp[lore]` accepts `--exp`, `--expl`, … `--explore`. The single-dash alias is equivalent to its flag.

| Flag | Alias | Values | Default |
|---|---|---|---|
| `--t[ype]` | `-t` | the type-selection table below | `default_type` in the type table |
| `--exp[lore]` | `-e` | `shallow` \| `deep` \| `auto` — depth only | per the resolved type row; this flag overrides it |
| `--rig[or]` | `-r` | scalar `low` \| `med` \| `high`, and/or per-phase `<phase>:<value>` over `explore` \| `plan` \| `code` \| `pr`; comma-separated, mixed form allowed (`med,explore:high`) | per the resolved type row |
| `--ag[ainst]` | `-a` | an **array** of anchors — git refs, Jira tickets, plan paths; repeatable flag AND comma-separated, order preserved | per the resolved type row's `against:` rule (`forbid`\|`optional`\|`require`) |
| `--pl[an]` | *(none)* | path to a promoted, gate-approved plan | none — adopts only when passed |
| `--work[tree]` | `-w` | `new` \| `resume [<name>]` \| `none` — see `worktree-modes.md` | `new` |
| `--b[ase]` | `-b` | `<branch>` | `CLAUDE_BASE_BRANCH` chain, resolved silently by `workflow-setup.sh` |
| `--n[ame]` | `-n` | `<slug>` | derived from the task (overrides, e.g. to join a resumable run) |

Facts settled below are not to be re-litigated by a later reader:

- **`--ref` — the old anchor flag — is retired.** Its `-r` alias is retired in the anchor sense: `-r` now belongs to `--rigor`. Anchors are `--against` / `-a` only.
- **The bracket minimums are `--t`, `--exp`, `--rig`, `--ag`, `--pl`** — this is what `resolve-type.sh` actually accepts (its `FLAG_TABLE` and `resolve_flag()` are the authority). A token shorter than its flag's minimum is an **unknown flag**, never guessed at.
- **Why `--rig` and not `--r`,** even though `--rigor` is the only `r`-initial flag left and `--r` would parse unambiguously: a stale `--r`/`--ref` typed from muscle memory must ERROR rather than silently resolve to a different axis. This is deliberate.
- **Why `--pl` and not `--p`:** `--plan` and `--pipeline` collide on `--p`, so neither may shorten to it; `--pl`/`--pi` each uniquely prefix their flag.
- **`-s` and `-p` are deliberately unassigned.** `--ship`, `--plan`, and `--pipeline` have no single-dash alias — don't invent one; the resolver rejects it.
- **`--pipeline` and `--ship` are internal-only and never appear as a row in this table.** A type IS its pipeline, so `--pipeline` is **locked**: recognized only in order to be **rejected** with a plain error naming the type's actual pipeline, never treated as an unknown flag. `dae map --pipeline build` is a category error, not a customization. `--ship` is locked the same way and for the same reason: recognized only in order to be rejected, never treated as an unknown flag. No row has a legitimate second ship value — `map` is the chat one; wanting a document means using `analyze`; chat is meaningless for a build, docs, diagnose, or sync run. A per-row `require|optional|forbid` policy would imply some row wants the choice, and none does.
- **Override tiers:** `--explore` and `--rigor` are **free** (cost/quality dials; an override can never produce an incoherent run — this is the escape hatch that keeps types from proliferating); `--against` and `--plan` are **constrained** (validated mechanically at parse time, before setup); `--pipeline` and `--ship` are **locked**. Types are the API; axes are internals. `--ship` sits with `--pipeline`, not in the free tier, precisely because the free tier's own definition is that an override can never produce an incoherent run — `dae feature --ship chat` would be a build run that does not ship, which is incoherent.
- **An unknown flag is an error — say so and stop; never silently ignore one.** `resolve-type.sh` is what enforces this, before setup (see below).

`--worktree`, `--base`, and `--name` are **run continuity**, not axes: they are the router's own, they are NOT passed to `resolve-type.sh`, and `--worktree` in particular is not an anchor — a resume target must point at something *dae* created, while an anchor must point at something git / Jira / the filesystem can resolve.

## Type selection

Ten types, keyed on `--type`. Columns: pipeline · middle file · planner module · branch prefix · `against` rule · ship default.

| `--type` | pipeline | middle file | planner module | branch | `against` | ship |
|---|---|---|---|---|---|---|
| `feature` (default) | `build` | `build.md` | `plan-feature` | `feature/` | forbid | publish |
| `bugfix` (alias `bug`) | `build` | `build.md` | `plan-bugfix` | `bug/` | optional | publish |
| `hotfix` | `build` | `build.md` | `plan-bugfix` + minimal-scope | `hotfix/` | optional | publish |
| `migration` | `build` | `build.md` | `plan-migration` | `feature/` | forbid | publish |
| `rework` | `build` | `build.md` | `plan-rework` | `feature/` | require | publish |
| `diagnose` (aliases `debug`, `triage`) | `plan` | `diagnose.md` | `plan-diagnosis` | `bug/` | optional | publish |
| `sync` | `plan` | `sync.md` | `plan-reconcile` | `sync/` | require | publish |
| `map` | `report` | `report.md` | — | — | forbid | chat |
| `analyze` | `report` | `report.md` | — | `docs/` | forbid | publish |
| `document` (alias `doc`) | `docs` | `document.md` | — | `docs/` | forbid | publish |

- **`pipeline: plan` resolves to `diagnose.md` or `sync.md` by PLANNER MODULE, never by type name** — two files until a third plan-pipeline type appears.
- **The alias flips are breaking and intentional:** `debug` and `triage` now route to **`diagnose`** (they used to reach `bugfix`) — the line is cause-known → `bugfix`, cause-unknown → `diagnose`. And **`map` is its own type**, no longer an alias off `document` — its own pipeline, its own ship profile.
- **`map` vs `analyze`:** the same pipeline at different presets — `map` is fast (`explore: auto`, `rigor: low`), `analyze` is rigorous (`explore: deep`, `rigor: {explore: med}`). `map` skips the publishing pre/post run steps entirely and answers in chat; `analyze` always publishes. They still differ ONLY in axis values, never in shape, which is why one file serves both.
- **No control flow keys off a type name.** Every branch in this file and every middle branches on a resolved AXIS value, never on `TYPE`.

**bugfix vs diagnose:** `bugfix` = the cause is known or the user states the defect — plan the fix directly. `diagnose` = the cause is unknown — investigate, rank, gate on the pick, then fix. An ambiguous "X is broken" with an unknown cause classifies as `diagnose`.

## Type resolution

Before setup, run `~/.claude/hooks/resolve-type.sh` (or the project's `.claude/hooks/` copy) with the type and the axis flags above. It reads the type table `workflows.yaml`, installed next to this file, and prints the resolved axes as `KEY=value` lines on stdout. **The router never interprets `workflows.yaml` itself**, and never re-derives or second-guesses a resolved axis — it consumes exactly what `resolve-type.sh` prints.

The keys, exactly as the script emits them: `TYPE`, `PIPELINE`, `EXPLORE`, `RIGOR_EXPLORE` / `RIGOR_PLAN` / `RIGOR_CODE` / `RIGOR_PR`, `AGAINST_COUNT` (plus `AGAINST_1` … `AGAINST_n` when non-zero), `SHIP`, and `PLANNER` / `BRANCH` / `PLAN` where the row or invocation supplies them. **Absent values are omitted, never emitted empty** — a rigor phase the run does not have, and `PLANNER`/`BRANCH` on rows that have none, simply do not appear; consume the block accordingly.

**Non-zero exit = a constraint violation.** Present its plain-language ask to the user and STOP — before setup, before any worktree exists. The error set: `--against` arity against the row's `require|optional|forbid`, `--plan` placement (`pipeline: build` types only), locked `--pipeline`, locked `--ship`, unknown flags, unknown type, malformed table.

**A stderr warning is not an error.** A rigor entry naming a phase this run does not have is dropped, warned about on stderr, and the run **continues** at exit 0 — surface the warning to the user, never abort on it. (Example: `dae map --rigor pr:high` — a `ship: chat` run has no `pr` phase.)

Anchors are passed through **raw**: resolving them is `resolve-anchor.sh`'s job, invoked only when `AGAINST_COUNT` is non-zero. `--plan` is checked for placement only, never for existence, at this stage.

## Seam loading

The router loads only its own `SKILL.md` + the type table + `resolve-type.sh` (+ `resolve-config.sh`). Type resolution loads **exactly one** middle file. Each middle references, by pointer, only what its resolved axes require. Nothing loads "just in case."

| Condition | Loads |
|---|---|
| always | this `SKILL.md`, `workflows.yaml`, `resolve-type.sh` (+ `resolve-config.sh`) |
| `pipeline: build` | `build.md` |
| `pipeline: report` | `report.md` |
| `pipeline: plan` | `diagnose.md` or `sync.md`, by `PLANNER` module |
| `pipeline: docs` | `document.md` |
| `planner: <module>` | the `planner` agent, warmed with that `plan-<type>` module, plus `review-plan`, `report-verdict.sh`, and `validate-report.sh` |
| `pipeline: build` gates | `review-code`, plus `report-verdict.sh` and `validate-report.sh` |
| `rigor: med\|high` at any phase | the `committee` agent, wrapping whatever skill that phase already loads — nothing else changes per phase |
| `--against` non-empty | `resolve-anchor.sh` |
| `--plan` present | `plan-lifecycle.sh adopt` + the staleness guard |
| `ship: publish` | the whole publish seam: `workflow-setup.sh`, `push-pr`, `comment-pr`, `review-pr`, `verify-run-scope.sh`, `cleanup-merged` |
| `CLAUDE_DOCS_PUBLISH` set | `confluence-mode.md`, for requirements capture |

Three observable consequences: a `map` run carries **zero** build and publish machinery; a `rigor: low` run **never loads the `committee` agent**; a `ship: chat` run never sees the publisher. **Seam review rule:** if a new type would require touching a skill outside the seams its row's axis values name, either the type's design is wrong or a seam is misplaced — fix the seam, never special-case the skill.

## Shared stages

Every `ship: publish` run executes **setup** first and **ship** last; the middle belongs to its resolved pipeline's file. A `ship: chat` run skips both (see below).

- **Setup (`ship: publish`)** — resolve `CLAUDE_DOCS_DIR` once (`~/.claude/hooks/resolve-config.sh CLAUDE_DOCS_DIR --default /docs --expect path`, or the project's `.claude/hooks/` copy): always a local path — `document-local` records, always. Resolve `CLAUDE_DOCS_PUBLISH` separately; when it is set, follow `confluence-mode.md` to capture requirements BEFORE exploring. Then establish the run's **parent worktree** per `worktree-modes.md`, on branch `<branch-type>/<name>`. `workflow-setup.sh` creates the run dir `<workflows-dir>/<name>/.artifacts/` (with `contracts/` and `reports/`) as part of that and prints its path on the `RUNDIR:` line — take the path from there rather than assembling it yourself. Seed it with an initial `progress-log.md` per the `run-artifacts` rule.
- **`ship: chat`** (the `map` default) — Setup and Ship are **skipped entirely**: no `workflow-setup.sh`, no branch, no worktree, no run dir, no progress log, no docs-target resolution, no `push-pr` at any stage, no PR gate, no `cleanup-merged`. `report.md` owns the short-circuit and defines the scratch dir that replaces the run dir — **reference it, never restate it**, and do not re-describe the scratch path here. The observable property, per `report.md` (which owns the detail): no branch, no commit, nothing staged, and nothing that reaches the product branch — plus, at `rigor: low`, no worktree either; a gitignored scratch-dir write and a temporary `rigor ≥ med` snapshot are permitted by construction.
- **`--plan <path>` adoption** — on a `pipeline: build` type this skips planner spawn, the plan revision loop, and the plan gate, but never the mechanical plan check. `build.md` owns the adoption mechanics (provenance, the staleness guard, the first-`plan-wrong` cold-spawn) — reference, do not restate.
- **Plan-stage concurrency** — types whose pipeline spawns a planner fire `init-workspace` for the parent worktree in the background at planner spawn, and JOIN on it before the plan gate (gate verification may run commands there). The run's **ask of record travels to the planner as a PATH**, never pasted content — the same pointers-not-payloads discipline as everywhere else — and it is what `plan-format`'s ask-of-record pointer and the plan gate's ask-vs-plan check (below) consume.
- **Open the draft PR** — this is the ONE place this mechanism is described; every other middle file references it by name rather than restating it. Right after the approval gate and `plan-lifecycle.sh promote`, invoke `push-pr --stage open-draft`, holding a conversational confirmation before acting (D1 cadence — see below). If the open is declined or fails, that is not a blocker: record it in the progress log, continue local-only, and retry the open exactly once, at the next `update` event. The step is idempotent on resume — an existing PR for the branch is reported, never recreated. On runs with no planner and no builders (`document`, `analyze`) nothing is committable before the record stage, so the draft opens at the **record commit** instead — those middles say so; this file keeps owning the mechanism.
- **Ship (`ship: publish`)** — record via `document-local`, then commit the record output and push it (`push-pr --stage update`) BEFORE the **PR gate** (below) — settled behavior: the gate reviews `git diff <base>...<branch>`, which only sees committed work, so an uncommitted record stage would be invisible to it. Then run the PR gate, then invoke `push-pr --stage finalize` (refreshes the PR title/body with the final summary and the `pr-review.md` pointer, then flips draft → ready, unless the caller asked to keep it a draft; holds the D1 conversational confirmation before acting). It leaves the worktree and its run dir standing — teardown waits for `cleanup-merged` once the PR actually merges. The run is NOT done until `push-pr` reports; a declined push is a valid outcome.
- **PR gate — mandatory on every `ship: publish` run, no exception** (adopted plans, doc-only runs, and published reports all included); a `ship: chat` run has no PR gate because it has no publish arc, and no axis, type row, or future flag may route around this. Before finalize, invoke the `review-pr` skill with the parent branch, the run's **spec of record** — the plan path and/or Jira key, or for a plan-less run the document its middle file names: diagnose → the diagnosis report; sync → the plan plus the confirmed sync report; document → the **oracle split** — the explore map is the **coverage** spec (what must be covered), the **code is the accuracy oracle** (whether what's claimed is true), so the docs' factual claims are verified against source, never merely against the map; report (`analyze`) → the question as asked plus the report itself, scoped so that **nothing outside the resolved docs root's `reports/` subdirectory may have changed** — the **run dir** (so the gate runs `verify-run-scope.sh`: product changes no exit report claims are blocking), and the report path (`<plan-dir>/pr-review.md`, or `<plans-dir>/<run-slug-or-jira-key>-MM-DD-YY/pr-review.md` for a plan-less run). It reviews the ENTIRE branch-vs-base diff against the spec as it exists NOW and writes the script-enforced verdict. Present the verdict with the routing it implies: `ready` or `tentative` → `push-pr --stage finalize` (tentative shows the non-blocking findings first); `rejected` → offer the routing choice — **replan** (`plan-wrong`/`map-wrong` → the kickback table), **rebuild** (`impl-wrong` → redispatch the named lane), or **leave the PR as a draft** with the report posted via `comment-pr` (the PR already exists, so this routes around it rather than shipping it) — tagging `(Recommended)` on the option the verdict's `next` code names. A post-kickback rebuild re-enters this gate (new round in the same report file, capped like the other gates). **Enforcement is mechanical, not prose:** `push-pr --stage finalize` validates that the run's `pr-review.md` exists, passes `validate-report.sh`, and that its **last** round carries `verdict: ready` + `next: proceed` — refusing with a plain error otherwise. Amending anything after a passing gate invalidates that round; the gate re-runs before `finalize` is attempted again.
- **Confirmation cadence (D1)** — `push-pr --stage open-draft` and `push-pr --stage finalize` each hold one conversational confirmation before acting. `push-pr --stage update` holds none — it runs silently as part of a lane-merge event or a record commit. No step in this file, or any sibling middle file, claims a push "always" prompts as a blanket property; the cadence is stage-specific, per this bullet.

## Gates

- Gates are cold forks (`review-plan`, `review-code`, `review-pr`) returning the shared worker envelope, with the durable verdict written to the gate's report file per the `run-artifacts` rule; you hold the human-gate conversation — never skip it, never flip to auto mode before the user approves.
- **The plan gate takes the run's ask of record as an input** and diffs the plan's intent against it; an unrecorded divergence routes `plan-wrong`, exactly like any other plan defect — `review-plan` owns the check's mechanics.
- **Cap:** max 3 revision loops per gate; after that, escalate to the human with the loop history (readable from the report file's rounds) instead of iterating again.
- **Kickback routing (code + PR gates):** the verdict's `next` carries a reason code, routed to the cheapest sufficient re-entry — `impl-wrong` → redispatch the builder lane with the REPORT PATH (the findings file is the hand-off, never your paraphrase of it); `plan-wrong` → SendMessage the warm planner the report path plus gate decisions (respawn with the same pointers only if it's gone); `map-wrong` → re-run `explore`, then the planner. Full re-explore ONLY on `map-wrong`.
- **Rigor:** at `rigor: med|high` for a phase, that phase's gate is **wrapped in the `committee` agent** at the tier's width. `committee.md` owns the mechanics and the member-file layout — **point at it, never restate it**. The wrapped gate **still writes its own verdict round** through `report-verdict.sh`, exactly as at `rigor: low` — the committee writes no verdict of its own; it is a worker returning the shared envelope, never a gate. **The collector/gate tie-break:** a claim still unverified at consolidation lands in `### Open questions` (with `next: needs-input` where it bars a verdict) and **never** as a blocking finding — fan-out must not inflate false positives on a rejecting gate. At `rigor: low` the committee is **not loaded at all**: the existing solo path runs unchanged, this is never `committee(skill, n=1)`, and a `low` run produces no `committees/` directory at all.

## Invariants (load-bearing — they live here, never in a sibling file)

- You own the plan file during the build: builders never edit it; your syllabus ticks go through `mark-syllabus.sh`. You also own the plan's LOCATION: every move between lifecycle states goes through `plan-lifecycle.sh`, never by hand — for a build/diagnose run that means one promotion, right after the user's approval, and nothing else moved by hand. That promotion is immediately followed by committing the plan dir and opening the draft PR (the **Open the draft PR** bullet above).
- **The plan is amendable at ANY stage.** When the user changes or adds requirements mid-run — any stage, build included — route the change to the warm planner (same plan file, amended in place), re-run `validate-plan.sh` — NOT an installed hook: it ships inside the `review-plan` skill, next to its SKILL.md (`<review-plan skill dir>/scripts/validate-plan.sh`, e.g. `~/.claude/skills/review-plan/scripts/validate-plan.sh`) — and re-gate when the change is material. Undispatched work follows the amended plan; already-merged work the amendment contradicts is flagged to the user, never silently kept or silently redone. Every gate re-reads the plan FILE at verdict time, so a review always judges against the plan as it stands now. A promotion changes the plan's path mid-run, so amendment messages to the warm planner and every later gate invocation must carry the CURRENT path — the current path lives in the progress log and travels in every message; no agent re-derives a path from a slug.
- **Maintain the progress log.** Rewrite `<run-dir>/progress-log.md` in place at every state change — stage transitions, gate rounds (count + one-line outcome + report path), lane dispatch/merge events, plan amendments, open questions. Record the plan's CURRENT path and its lifecycle state (proposal / active / completed), not just that it exists. Once the draft PR is open, also record its URL, its draft state, and the last pushed commit, so a resume knows a PR already exists rather than opening a second one. All small- and medium-sized run information lands there, not only in chat: it is what a resumed or compacted session reconstructs the run from (with the plan syllabus). Never committed; it lives inside the parent worktree and dies WITH that worktree — so never tear the worktree down while the run is still in flight, and let `cleanup-merged` be what removes it.
- Only a builder's own e2e phase exits its build loop; gates judge, workers build — you do neither.
- Your writes are harness-scoped — the plan file and run artifacts, never the product (`scope-writes.sh` enforces this when wired; its allowlist is exactly those paths). This is machine-audited: the PR gate runs `verify-run-scope.sh`, and a product change no builder exit report claims is a blocking finding — a stalled or dead lane is NEVER a license to do its work yourself; respawn per `build-dispatch.md`, and after the bounded respawns escalate to the user. The harness-scoped write allowance already covers the whole resolved plans dir (`verify-run-scope.sh:106` resolves and allows it), so promotion commits inside a run's diff are NOT flagged by the scope check — no script change is implied or needed here.
- Pass pointers, not payloads: workers and forks get file paths and short summaries; keep raw dumps out of your context. Surface only blockers, gate verdicts, and completion summaries.
- Publishing happens ONLY through `push-pr`, across all three stages of a run's ship arc: per D4, `push-pr --stage update` is the ONLY per-lane push mechanism — no direct `git push` from the router, no helper script, no second publisher named anywhere. Never push yourself, never force-push, never push the base branch.
- An unrecoverable blocker stops the run — bring it to the user, don't improvise around it.
- The Stop hook runs `workflow-diff-check.sh` while you are active: it diffs the worktree and runs the project's checks on changed files. Failures are blocking — fix, then resume where you left off.
