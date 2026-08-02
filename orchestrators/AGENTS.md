# Orchestrators

Entry points and workers. The library runs on a **three-tier execution model**;
the decision rule for placing anything is *who needs to talk to it while it
runs*:

| Tier | Talks to | Context | Examples |
|---|---|---|---|
| **Main-session orchestrator** | the user | the conversation | `dae`, `orchestrate` |
| **Worker agent** | its orchestrator (messages) | own, **warm** — survives revision loops | `planner`, `builder` (+ its `coder`/`contract-tester` sub-agents) |
| **Cold fork / gate** | nobody — returns one envelope | own, isolated, un-anchorable | `explore`, `review-plan`, `review-code`, `document-*`, `init-workspace`, `push-pr`, `review-pr` |

**Principles** (each with its enforcement point):

- *Workers warm, gates cold.* A worker survives to be corrected (planner
  revisions, builder rework); a gate deliberately starts clean so its
  verification can't be anchored by the reasoning that produced the artifact.
- *Absorb single-consumer skills into their worker.* The old `code`/`debug`/
  `test` trio lives inside `builder`; the old `plan` skill inside `planner`;
  the investigate discipline inside the `plan-diagnosis` module. A skill earns
  a roster slot only with ≥2 consumers or a user-facing surface.
- *An agent earns a context only when its state can't be externalized.* Git IS
  the branch state — hence no branch-manager agent (rejected; see below).
- *Fork when a summary is the deliverable* — and the full artifact goes to
  disk: artifact-on-disk, pointer-in-envelope.
- *Every worker and fork returns the shared envelope* (`status`, `artifacts[]`,
  `next`, `blockers[]` — see `docs/conventions.md`).
- *Scripts own the mechanical, prose owns the judgment.* Syllabus ticks,
  scope checks, plan schema, install sync — all scripted; skills spend their
  tokens on judgment.
- *Structural anti-cheating over discipline.* The builder's coder never sees
  tests; its contract-tester never sees implementation — the artifact an agent
  would cheat off does not exist in any context it can see.

## Entry points

| Skill | Invoke | What it drives |
|---|---|---|
| **`dae`** | `/dae [--type\|-t <t>]` | The router: classifies the request into ONE workflow — build (`feature\|bugfix\|rework\|migration\|hotfix`), `diagnose`, `document`, `sync` — and follows that workflow's sibling file. Shared setup/ship stages, gate caps, kickback reason-code routing. Carries the `Stop`→`workflow-diff-check.sh` hook. |
| **`orchestrate`** | `/orchestrate` | Generic task coordinator: decompose any multi-part task, delegate to subagents, verify and synthesize. Not tied to the dae pipeline. |

## The dae pipeline (build workflow)

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

Inside each builder: contract expansion → one parallel wave of `coder` ‖
`contract-tester` per packet → pipelined joins → debug-mediated rework (fresh
re-dispatch carrying contract + diagnosis, never the opposing artifact) → the
builder's own e2e tail, the sole loop exit — verified against the PLAN, which
catches a wrong contract that propagated into both code and tests.

The other workflows swap the middle: `diagnose` (planner ranks causes →
pick gate → fix lanes), `document` (deep explore → record), `sync` (planner
reconciles → confirm gate → record). All share setup/ship and the same files
in `skills/dae/`.

## Hooks (`hooks/`)

Helpers, invoked explicitly (never wired): `workflow-setup.sh` (worktrees:
`--type feature|bug|hotfix|docs|sync`, `--parent` for builder child worktrees,
`--reuse` for crash-resume), `resolve-config.sh` (CLAUDE_* settings chain),
`mark-syllabus.sh` (scripted syllabus ticks), `verify-scope.sh` (reported
files vs real lane diff), `sync-install.sh` (repo→`~/.claude` install sync,
deletions included — this repo's `push-main` runs it).
Wired hooks: `workflow-diff-check.sh` (`Stop`, on `dae` only — builders check
per lane instead), `scope-writes.sh` (`PreToolUse` deny-outside-allowlist;
live config = orchestrator scope; the builder-lane config was retired —
worktree isolation replaced it).

## Agents (`agents/`)

| Agent | Model | Role |
|---|---|---|
| **`planner`** | opus | Explores for itself (ladder: docs-as-claims → fan-out → own reads → `explore` fork), writes the plan/report per `plan-format`, stays warm for revisions. Type modules in `agents/planner/`: `plan-{feature,bugfix,rework,migration,diagnosis,reconcile}.md`. |
| **`builder`** | sonnet | Per-lane mini-orchestrator of the packet model. Owns its child worktree, the contract, dispatch, debug mediation, and the e2e exit. Writes no implementation and no contract tests. |
| **`coder`** | sonnet | One packet (≤~5 coupled files) against its contract slice. Never reads or writes tests. |
| **`contract-tester`** | sonnet | Tests for one contract slice from the contract alone. Never reads the implementation — the blindness is its identity. |

**Considered and rejected:** a standalone `investigate` skill (single consumer —
folded into `plan-diagnosis`); a branch-management agent (git is the external
state store; worktree/branch state needs no context of its own); a builder-lane
`scope-writes` config (physical worktree isolation made it redundant);
wave-barrier dispatch (event-driven `(after:)` scheduling replaced it — a
dependent lane launches the moment its edge ticks).
