# The dae pipeline

Canonical guide: [`orchestrators/AGENTS.md`](../orchestrators/AGENTS.md). This
page is the meta-summary; edit pipeline behavior in the payload files, not here.

**"Pipeline" is used in two senses here — this page's own title is the
first.** As the whole run arc (router → workers → gates → PR, or → chat for a
report type), "pipeline" is what this page describes and titles itself after.
As one of the five resolved axes, the **`pipeline` axis** names something
narrower: which *middle file* a type executes. Below, "the `pipeline` axis"
is named explicitly wherever that narrower sense applies; everywhere else
"pipeline" means the whole run arc.

One entry orchestrator — **`dae`** (`/dae`) — resolves every request to
exactly one **type**, whose `pipeline` axis selects a middle file, then drives
two **worker agents** (`planner`, `builder`) through **cold gates** to a PR —
or, for `map` (`pipeline: report`, `ship: chat`), answers the question in
chat instead; `analyze` runs the same middle but publishes. Nothing in the
pipeline is bound to a technology: the record stage is `document-local` in
every configuration.

```
                    ┌─ pipeline: report, ship: chat (map) ─▶ explore ─▶ fill
                    │  report skeleton ─▶ answer in chat + scratch file (zero
                    │  gates, no branch/commit/staged — no worktree either at
                    │  rigor: low — see report.md; no PR)
dae (/dae) ─resolve type/pipeline─┤
                    │
                    └─ ship: publish ─setup─▶ planner ‖ init-workspace ─▶ review-plan gate (human, capped)
                        ▲ SendMessage revisions        │ approved
                        │                              ▼
              plan-wrong kickback        push-pr --stage open-draft (draft PR
                        │                opens, 1 confirmation)
                        │                              │
                        │                              ▼
                        │                  builder lanes (event-driven dispatch,
                        │                  child worktree each, merge-back +
                        │                  push-pr --stage update + cleanup per lane)
                        │                              │ all lanes merged
                        └──── review-code gate (human, capped; reason codes
                              impl-wrong │ plan-wrong │ map-wrong) ◀── integration
                                               │ clean
                                               ▼
                                        document-local
                                               ▼
                       push-pr --stage update (commit+push record output)
                                               ▼
                     review-pr gate (mandatory, before finalize; branch vs
                     base; ready │ tentative │ rejected → replan / rebuild /
                     leave as draft + comment-pr)
                                               ▼
                          push-pr --stage finalize (draft → ready)
```

## Types (`--type`)

Ten types over four `pipeline`-axis values, resolving to five middle files
(`pipeline: plan` resolves to `diagnose.md` or `sync.md` by planner module,
never by type name).

| `--type` | `pipeline` axis | Middle file | Middle stages |
|---|---|---|---|
| `feature` (default) / `bugfix` (alias `bug`) / `hotfix` / `migration` / `rework` | `build` | `build.md` | planner (type module) → plan gate → builder lanes → code gate |
| `diagnose` (aliases `debug`, `triage`) | `plan` | `diagnose.md` | planner (`plan-diagnosis`: investigate, rank likelihood × ease) → pick-the-causes gate → fix lanes → code gate |
| `sync` | `plan` | `sync.md` | planner (`plan-reconcile`: classify done/partial/dropped/diverged vs the real diff) → confirm-the-diff gate → reconciliation-driven record |
| `map` | `report` | `report.md` | fast `explore` → fill the report skeleton → chat answer; no planner, no gates, no branch/commit/staged — no worktree either at `rigor: low` |
| `analyze` | `report` | `report.md` | rigorous `explore` (deep, `rigor: med`) → fill the report skeleton → a published report under the resolved docs root's `reports/` (record/PR stages below); no planner |
| `document` (alias `doc`) | `docs` | `document.md` | deep `explore` (map on disk) → map-driven record; no planner |

**Alias flips (breaking):** `debug`/`triage` now route to `diagnose` — they
used to reach `bugfix`; the line is cause-known → `bugfix`, cause-unknown →
`diagnose`. `map` is its own type with its own pipeline and ship profile, no
longer an alias of `document`.

All `ship: publish` types share the router's **setup** (docs target,
Confluence requirements capture, parent worktree `<type>/<name>`) and
**ship** (`open-draft` at plan approval → per-lane/record
`push-pr --stage update` pushes → PR gate → `finalize`) stages. `map` defaults
to `ship: chat` — the diagram's chat branch above, with zero gates and (per
`report.md`) no branch, commit, or anything staged — no worktree either at
`rigor: low`; `analyze` always publishes. `bugfix` vs `diagnose`: known cause
→ bugfix; unknown cause → diagnose.

## The three tiers

| Tier | Who | Context |
|---|---|---|
| Orchestrator | `dae`, `orchestrate` | the conversation; holds every human gate |
| Workers | `planner` (opus, warm — revisions via SendMessage), `builder` (sonnet, one per lane) + its `coder`/`contract-tester` sub-agents | own contexts |
| Cold forks | `explore`, `review-plan`, `review-code`, `review-pr`, `init-workspace`, `document-local`, `push-pr`, `comment-pr`, `cleanup-merged` (+ `committee`, wrapping a gate at `rigor: med\|high`) | isolated; envelope return |

Every worker and fork returns the **shared envelope** — `status`,
`artifacts[]`, `next`, `blockers[]` (defined once in
[`conventions.md`](conventions.md)) — with the real artifact on disk.

## Inside a builder (the packet model)

Contract expansion → ONE parallel dispatch wave (per packet: a `coder`, and a
`contract-tester` when the subphase's declared test oracle is `new contract
tests`) → pipelined per-packet joins → debug-mediated rework (fresh re-dispatch
carrying contract + diagnosis, NEVER the opposing artifact's source) → the
builder's own e2e/functional tail — the sole loop exit, verified against the
PLAN, which catches a wrong contract that propagated into both code and tests.
Anti-cheating is structural: the coder never sees tests, the tester never sees
implementation, and the artifacts an agent could cheat off never enter its
context.

Each builder works in its own **child worktree** (`workflow-setup.sh --parent`)
with its own `init-workspace`; on report, `dae` verifies the lane
(`verify-scope.sh`), merges the child branch into the parent (a conflict IS a
scope violation), ticks the syllabus (`mark-syllabus.sh`), updates the
progress log, and pushes the parent (`push-pr --stage update` — no
confirmation) BEFORE removing the lane's worktree/branch — cleanup waits for
the push because the child is the only place a lane's work exists outside the
parent's local history. A failed or declined push defers that lane's cleanup
(worktree and branch kept, recorded in the progress log, retried after a later
successful push) without blocking the schedule; a run with no remote or PR
tooling at all cleans up normally, since there's nothing to wait for. `dae`
then re-scans the `(after:)` frontier and dispatches immediately — no wave
barriers. At run end the parent is the only worktree/branch remaining IF every
lane's push succeeded — already published (pushed, PR opened as draft, since
plan approval and kept current by every lane-merge push) — `finalize`
completes that publication by flipping draft → ready; any lane still carrying
a deferred cleanup is surfaced to the user with its worktree path and branch
name.

## Gates

All judgment gates are capped (3 loops, then escalate to the human), write
their verdict rounds to committed report files in the plan's own dir —
`<plans-dir>/<slug>-MM-DD-YY/<kind>.md`; a pre-approval plan-review round
goes to `proposals/<slug>-MM-DD-YY.plan-review.md` beside the proposal and
moves in at promotion (per the `run-artifacts` rule — the verdict vocabulary
`ready | tentative | rejected` is enforced by
`report-verdict.sh`/`validate-report.sh`, and the loop history is readable
from the file), and return envelope verdicts. `review-code` runs once — after
EVERY builder lane has merged, over the whole assembled implementation, never
scoped to a single lane. The code and PR
gates' `next` carries a kickback reason code: `impl-wrong` → redispatch the
lane; `plan-wrong` → message the warm planner; `map-wrong` → re-run `explore`,
then the planner — the redispatched worker gets the report PATH, never a
paraphrase. Cheapest sufficient re-entry always. The PR gate runs on EVERY
run, mandatory, before `push-pr --stage finalize`: the whole branch-vs-base
diff against the plan/ticket as amended (plans are amendable at any stage;
gates re-read the file at verdict time). A rejected verdict offers replan /
rebuild / leave the PR as a draft (+ `comment-pr` posting the report),
`(Recommended)` per its kickback code.

## Documentation dispatch

Per `artifact-locations`, setup resolves `CLAUDE_DOCS_DIR` — always a local
path — and the ship stage always records through **`document-local`**
(mirror/symlink rules per `doc-format`). The optional `CLAUDE_DOCS_PUBLISH`
names a separate publish target; publishing is a **CI job on merge**, never a
run stage. When `CLAUDE_DOCS_PUBLISH` is set, `confluence-mode.md` governs
requirements capture up front, persisted as
`proposals/<slug>-MM-DD-YY.story.md`, the plan dir's `story.md` after
promotion; large artifacts go to Google Drive per `external-storage-cap`.
**`document-confluence`** is a manual/recovery sync that mirrors the local
docs tree to Confluence — never a record stage, never a source of truth.

## Hooks & scripts

Bash, applying to a **consuming** project, not to `agentic` (except
`sync-install.sh`):

- Helpers (invoked, never wired): `workflow-setup.sh` (worktrees; types
  `feature|bug|hotfix|docs|sync`; `--parent` children; `--reuse` resume),
  `resolve-config.sh` (CLAUDE_* chain), `resolve-type.sh` (the only reader of
  the type table `workflows.yaml`; prints resolved axes as `KEY=value`),
  `resolve-anchor.sh` (per-item `--against` anchor resolution to typed
  pointers; all-or-nothing), `mark-syllabus.sh`, `verify-scope.sh`,
  `verify-run-scope.sh` (whole-run diff vs the union of exit reports, at the
  PR gate), `plan-lifecycle.sh` (every plan move:
  `promote | archive | supersede | reopen | locate | check | adopt`; `archive`
  refuses a plan that didn't ship), `report-verdict.sh` (the only writer of a
  verdict round), `validate-report.sh` (caller-side report schema check),
  `resolve-scratch.sh` (the `ship: chat` scratch-dir resolver; delegates the
  configured rung to `resolve-config.sh`),
  `sync-install.sh` (this repo → `~/.claude`, deletions included).
- Wired: `workflow-diff-check.sh` (`Stop` on `dae`), `scope-writes.sh`
  (`PreToolUse`; orchestrator write-scope config),
  `allow-workflow-cleanup.sh` (`PreToolUse`; auto-allows the two provably-safe
  lane-cleanup commands), `branch-squash-guard.sh` (`PreToolUse`; enforces the
  squash-only branch policy per `push-policy`).

## Naming

The orchestrator gets the shortest name (`/dae`); the old entry points (`/dev`,
`/map`, `/sync-status`, `/diagnose`) are deleted — `/dae --type` covers them. Forks keep
guarded generic names (`explore`) or verbose collision-free ones
(`init-workspace`, `review-code`, `document-local`, `push-pr`, `review-pr`).
