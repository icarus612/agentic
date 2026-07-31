# The dae pipeline

Canonical guide: [`orchestrators/AGENTS.md`](../orchestrators/AGENTS.md). This
page is the meta-summary; edit pipeline behavior in the payload files, not here.

One entry orchestrator — **`dae`** (`/dae`) — routes every request to exactly
one workflow and drives two **worker agents** (`planner`, `builder`) through
**cold gates** to a PR. Nothing in the pipeline is bound to a technology except
the record stage, when the docs target is Confluence.

```
dae (/dae) ─setup─▶ planner ‖ init-workspace ─▶ review-plan gate (human, capped)
                        ▲ SendMessage revisions        │ approved
                        │                              ▼
              plan-wrong kickback          builder lanes (event-driven dispatch,
                        │                  child worktree each, merge-back+cleanup)
                        │                              │ all lanes merged
                        └──── review-code gate (human, capped; reason codes
                              impl-wrong │ plan-wrong │ map-wrong) ◀── integration
                                               │ clean
                                               ▼
                          document-local | document-confluence ─▶ push-pr
```

## Workflows (`--type`)

| `--type` | Workflow file | Middle stages |
|---|---|---|
| `feature` / `bugfix` / `rework` / `migration` / `hotfix` | `build.md` | planner (type module) → plan gate → builder lanes → code gate |
| `diagnose` | `diagnose.md` | planner (`plan-diagnosis`: investigate, rank likelihood × ease) → pick-the-causes gate → fix lanes → code gate |
| `document` | `document.md` | deep `explore` (map on disk) → map-driven record; no planner |
| `sync` | `sync.md` | planner (`plan-reconcile`: classify done/partial/dropped/diverged vs the real diff) → confirm-the-diff gate → reconciliation-driven record |

All share the router's **setup** (docs target, Confluence requirements capture,
parent worktree `<type>/<name>-parent`) and **ship** (record → `push-pr`)
stages. `bugfix` vs `diagnose`: known cause → bugfix; unknown cause → diagnose.

## The three tiers

| Tier | Who | Context |
|---|---|---|
| Orchestrator | `dae`, `orchestrate` | the conversation; holds every human gate |
| Workers | `planner` (opus, warm — revisions via SendMessage), `builder` (sonnet, one per lane) + its `coder`/`contract-tester` sub-agents | own contexts |
| Cold forks | `explore`, `review-plan`, `review-code`, `init-workspace`, `document-local`/`document-confluence`, `push-pr`, `review-pr` | isolated; envelope return |

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
scope violation), removes the lane's worktree/branch, ticks the syllabus
(`mark-syllabus.sh`), re-scans the `(after:)` frontier, and dispatches
immediately — no wave barriers. At run end one worktree/branch remains: the
parent, which `push-pr` publishes.

## Gates

Both judgment gates are capped (3 loops, then escalate to the human) and
return envelope verdicts. The code gate's `next` carries a kickback reason
code: `impl-wrong` → redispatch the lane; `plan-wrong` → message the warm
planner; `map-wrong` → re-run `explore`, then the planner. Cheapest sufficient
re-entry always.

## Documentation dispatch

Per `artifact-locations`, setup resolves the docs target and the ship stage
dispatches on its shape: a filesystem path (default `/docs`) →
**`document-local`** (mirror/symlink rules per `doc-format`); a Confluence
location → **`document-confluence`** (`domain: confluence` — Confluence is the
docs source of truth; requirements were captured up front per
`confluence-mode.md` and persisted as a `.story.md` beside the plan; large
artifacts go to Google Drive per `external-storage-cap`). Extensible: another
`<target>:` scheme maps to `document-<target>`.

## Hooks & scripts

Bash, applying to a **consuming** project, not to `agentic` (except
`sync-install.sh`):

- Helpers (invoked, never wired): `workflow-setup.sh` (worktrees; types
  `feature|bug|hotfix|docs|sync`; `--parent` children; `--reuse` resume),
  `resolve-config.sh` (CLAUDE_* chain), `mark-syllabus.sh`, `verify-scope.sh`,
  `sync-install.sh` (this repo → `~/.claude`, deletions included).
- Wired: `workflow-diff-check.sh` (`Stop` on `dae`), `scope-writes.sh`
  (`PreToolUse`; orchestrator write-scope config).

## Naming

The orchestrator gets the shortest name (`/dae`); deprecated stubs (`/dev`,
`/map`, `/sync-status`, `/diagnose`) route to it for one release. Forks keep
guarded generic names (`explore`) or verbose collision-free ones
(`init-workspace`, `review-code`, `document-local`, `push-pr`, `review-pr`).
