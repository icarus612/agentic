# Generic — the global layer (`domain: universal`)

Everything here is **bound to no technology and no service**. It works on any
project, any stack, so it installs once at the **user level** (`~/.claude/` or
`.agent/`) and is available everywhere.

The `tech-agnostic` rule polices the boundary: a technology named in a
universal skill is an *example only*. Real tech-specific guidance belongs to a
`domain: <tech>` skill, shipped with the project that uses it — see
[`../tool-based/`](../tool-based/).

## Execution model

Three tiers, by *who needs to talk to it while it runs*. The rule is the same
whether the thing is a skill or a worker agent, which is why entry points,
workers, and gates all live in this one universal layer now — folded in from
the former `orchestrators/` split, since both were `domain: universal` and
installed to the same `~/.claude/` locations.

| Tier | Talks to | Context | Examples |
|---|---|---|---|
| **Main-session orchestrator** | the user | the conversation | `dae`, `orchestrate` |
| **Worker agent** | its orchestrator (messages) | own, **warm** — survives revision loops | `planner`, `builder` (+ its `coder`/`contract-tester` sub-agents) |
| **Cold fork / gate** | nobody — returns one envelope | own, isolated, un-anchorable | `explore`, `review-plan`, `review-code`, `review-pr`, `document-local`, `init-workspace`, `push-pr`, `comment-pr`, `cleanup-merged` |

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
  scope checks, plan schema, plan lifecycle moves, install sync — all scripted;
  skills spend their tokens on judgment.
- *Structural anti-cheating over discipline.* The builder's coder never sees
  tests; its contract-tester never sees implementation — the artifact an agent
  would cheat off does not exist in any context it can see.

## `rules/` — always-on constraints

Loaded as context regardless of what was invoked; no selection step. Short,
declarative, no procedure. If it must hold even when nothing was invoked, it's
a rule.

| Rule | Holds |
|---|---|
| `verify-dont-assume` | Read the real code/config/docs before asserting. Confidently wrong is the failure mode. |
| `respect-versions-and-conventions` | Use idioms correct for the installed MAJOR version; project conventions are hard constraints. |
| `tech-agnostic` | Never assume or hard-code a stack; discover it, then load the skills whose `domain:` names it. |
| `push-policy` | Two modes by whether the repo has `dev`: WITH dev, dev is the integration branch (remote squash-merged PRs) and main is off-limits except an authorized hotfix; WITHOUT dev, main is the integration branch, squash-merged locally and pushed. Always: squash, ask before every push, never force-push, never commit on the integration branch. |
| `model-policy` | Each skill declares `model:` plus an ordered `model-fallback:`. |
| `artifact-locations` | Where docs, plans and their records, worktrees, and the base branch resolve from (config-resolved) — and how the docs target selects the documentation skill. |
| `doc-format` | How docs are structured and placed. |
| `plan-format` | How plans are named, phased, kept current, and moved through their lifecycle (proposals → per-plan dir → completed). |
| `run-artifacts` | Where run files live: committed plan records inside the plan's own dir; the gitignored run dir `<worktree>/.artifacts/` (progress log, contracts, exit reports), which dies with its worktree. Verdict vocabulary script-enforced. |
| `shell-discipline` | One command per Bash/run_command call — compounds are all-or-nothing at the permission gate; never chain `cd` with git/gh (cwd persists between calls, or `git -C`); prefer already-allowlisted invocation forms. |

## `skills/` — the tech-agnostic forks and gates

Invoked **by name by an orchestrator or worker**, not matched from a user
request — which is why each description names the pipeline it belongs to and
who invokes it (the guard that stops a single-word name like `explore`
auto-firing on an incidental keyword match). All are cold forks: isolated
context, inputs via args, one envelope back (`status`, `artifacts[]`, `next`,
`blockers[]` — see the conventions doc). The old build-loop trio
(`code`/`debug`/`test`) and the `plan` skill are gone — absorbed into the
`builder` and `planner` workers in `agents/` (below).

| Skill | Role |
|---|---|
| `explore` | The shared mapping fork: full structured map (stack + MAJOR versions, structure, dependency graph, patterns, conventions) written to disk, envelope pointer back. Invoked by the planner's escalation and the dae document workflow — NOT a mandatory pre-plan phase. |
| `init-workspace` | Install dependencies and set up toolchains inside a worktree (the run's parent, or a builder's child) so later stages can build and test. (Verbose name — `init` collides with a Claude Code built-in.) |
| `review-plan` | Cold gate before any code. `scripts/validate-plan.sh` owns the schema half; the fork verifies claims against reality; verdict round written to the plan dir's `plan-review.md` record, envelope verdict to the caller's human gate. |
| `review-code` | Cold gate before any docs. Verdict round written to the plan dir's `code-review.md` record; the envelope `next` carries the kickback reason code (`impl-wrong` \| `plan-wrong` \| `map-wrong` \| `needs-input`) the dae router routes on. |
| `review-pr` | The mandatory PR gate before `finalize` (and standalone on published PRs), run on a PR already open as a draft: the ENTIRE branch-vs-base diff against the plan or Jira ticket; script-enforced `ready \| tentative \| rejected` verdict in the plan dir's `pr-review.md` record. Never posts. |
| `comment-pr` | Post the plan dir's `pr-review.md` verdict to GitHub: `scripts/render-pr-comment.sh` renders the last round, `gh` posts it with confirmation. Never reviews. |
| `document-local` | Record stage when the docs target is a local path: write into the docs root, the single source of truth; optional changelog commit (never a push). |
| `push-pr` | The staged publisher, called with `--stage open-draft` \| `update` \| `finalize`: `open-draft` opens the draft PR right after plan approval, `update` pushes the branch after every lane merge-back and the record commit, `finalize` pushes final stragglers and flips the PR from draft to ready. Leaves the worktree standing — teardown is `cleanup-merged`'s, post-merge. `open-draft` and `finalize` each hold one conversational confirmation; `update` asks nothing. |
| `cleanup-merged` | Post-merge closeout: verified-merged branch deleted local+remote, worktrees pruned, run dir removed, only `plan.md` archived to `completed/` (its records removed with the rest of the dir), optional Jira transition. Safe deletes only. |

### Entry points

| Skill | Invoke | What it drives |
|---|---|---|
| **`dae`** | `/dae [--type\|-t <t>]` | The router: resolves the request to ONE of twelve types — build (`feature\|bugfix\|rework\|migration\|hotfix`), `live` (alias `adhoc` — an ad-hoc conversational build), `diagnose` (aliases `debug`, `triage` — breaking: these used to reach `bugfix`), `sync`, `map`, `analyze` (`map`'s own type, no longer a `document` alias), `document` (alias `doc`), `prove` (alias `disprove` — states a claim, gathers evidence, then dispatches a cold pass that must try to refute it) — whose `pipeline` axis selects the middle file it follows. Shared setup/ship stages, gate caps, kickback reason-code routing. Carries the `Stop`→`workflow-diff-check.sh` hook. |
| **`orchestrate`** | `/orchestrate` | Generic task coordinator: decompose any multi-part task, delegate to subagents, verify and synthesize. Not tied to the dae pipeline. |

## `agents/` — worker agents

Spawned via the Agent/invoke_subagent tool by an orchestrator (or a builder);
hold their own warm context; return the shared envelope (`docs/conventions.md`).

| Agent | Model | Role |
|---|---|---|
| **`planner`** | opus | Explores for itself (ladder: docs-as-claims → fan-out → own reads → `explore` fork), writes the plan/report to `proposals/` per `plan-format`, stays warm for revisions. Type modules in `agents/planner/`: `plan-{feature,bugfix,rework,migration,live,diagnosis,reconcile}.md`. |
| **`builder`** | sonnet | Per-lane mini-orchestrator of the packet model. Owns its child worktree, the contract, dispatch, debug mediation, and the e2e exit. Writes no implementation and no contract tests. |
| **`coder`** | sonnet | One packet (≤~5 coupled files) against its contract slice. Never reads or writes tests. |
| **`contract-tester`** | sonnet | Tests for one contract slice from the contract alone. Never reads the implementation — the blindness is its identity. |
| **`committee`** | opus | Generic fan-out wrapper: runs N cold copies of a wrapped skill and consolidates their claims into one artifact, at `rigor: med\|high` only — never loaded at `rigor: low`. Owns structure (fan-out, matching, consolidation) only; the wrapped skill supplies substance. |

**Considered and rejected:** a standalone `investigate` skill (single consumer —
folded into `plan-diagnosis`); a branch-management agent (git is the external
state store; worktree/branch state needs no context of its own); a builder-lane
`scope-writes` config (physical worktree isolation made it redundant);
wave-barrier dispatch (event-driven `(after:)` scheduling replaced it — a
dependent lane launches the moment its edge ticks).

## `settings/` — the user-level Claude Code settings

`settings.json` is the versioned source of `~/.claude/settings.json`:
permission allow/ask/deny lists, hook wiring, model choice, and UI flags —
never secrets (API keys and tokens do not belong here). `sync-install.sh`
installs it like any other universal unit. It is the one unit whose INSTALL
side also mutates legitimately (Claude Code appends "always allow" grants to
the live file); `sync-install.sh --check` flags that drift so accepted grants
get folded back into this copy before the next push.

## `hooks/`

Two kinds live here, both installing to the same `~/.claude/hooks/` — the
split that used to separate "global quality" hooks from "pipeline-scoped"
ones bought nothing once both source dirs installed to the same place, which
is exactly why they now share one directory and one list.

**Wired** — fire automatically via `settings.json` or a skill/agent's `hooks:`
frontmatter, never invoked by name: `smart-lint.sh` and `smart-test.sh`
(language-aware, blocking on failure, apply to every session), `ntfy-notifier.sh`,
the `record-changed.sh`/`test-changed.sh` pair, `worktree-reminder.sh` (a
`SessionStart` hook that reminds ANY session — not just an orchestrator-driven
one — to isolate file changes in a worktree and route pushes/PR reviews
through `push-pr`/`review-pr` instead of raw `git`/`gh` commands),
`workflow-diff-check.sh` (`Stop`, on `dae` only — builders check per lane
instead), `scope-writes.sh` (`PreToolUse` on `Write|Edit|MultiEdit|NotebookEdit`,
denying orchestrator writes outside the run's `.artifacts/`, the resolved
plans dir, and the resolved docs dir, self-configured from a parent-worktree
marker — `.artifacts/progress-log.md` — with no env var), `parent-tree-guard.sh`
(`PostToolUse` on `Bash` and on `Stop` — the Bash-side backstop, checking the
worktree's actual git state via `git status --porcelain` since a `PreToolUse`
hook can't see inside a Bash command), `allow-workflow-cleanup.sh`
(`PreToolUse` on `Bash(git branch:*)` and `Bash(git worktree remove:*)` —
auto-allows `-d` deletes of workflow-namespace branches tied to the
project's workflows dir and plain removals of lane-child worktrees
(`-l<n>` under the workflows dir; parents still prompt), no opinion on
everything else — note `-d` refuses any SQUASH-merged branch, since squash
leaves no merge ancestry and `push-policy` makes squash universal, so on a
landed branch the real delete is `git branch -D`, which is NOT auto-allowed
and prompts; that prompt is the safety check, and the content diff against
the base is what establishes the branch landed), and `branch-squash-guard.sh`
(`PreToolUse` on `Bash` and the write tools — enforces this user's two-mode
dev/main squash-only branch policy per `push-policy`; mode is detected per
invocation from the target repo, never a static toggle). Configured by
`CLAUDE_HOOKS_*` env vars — see [`hooks/README.md`](hooks/README.md).

**Helpers** — invoked explicitly, never wired: `workflow-setup.sh` (worktrees:
`--type feature|bug|hotfix|docs|sync`, `--parent` for builder child worktrees,
`--reuse` for crash-resume), `resolve-config.sh` (`CLAUDE_*` settings chain),
`resolve-type.sh` (the only reader of the type table `workflows.yaml`; prints
resolved axes as `KEY=value`, including `PATIENCE` on runs with a `code` phase;
a row's `ship` cell is a `|`-separated allowed-value list, first = default),
`resolve-anchor.sh` (per-item `--against` anchor resolution to typed pointers;
all-or-nothing), `mark-syllabus.sh` (scripted syllabus ticks), `verify-scope.sh`
(reported files vs real lane diff), `verify-run-scope.sh` (whole-run diff vs
the union of exit reports at the PR gate — unclaimed product changes are
blocking), `report-verdict.sh` (the ONLY writer of a verdict round — enforces
`ready|tentative|rejected` + kickback codes at write time), `validate-report.sh`
(caller-side report schema check, `--kind exit` for builder exit reports),
`plan-lifecycle.sh` (every plan move: `promote|archive|supersede|reopen|locate|check|adopt`
— `archive` refuses a plan that didn't ship), `resolve-scratch.sh` (the
`ship: chat` scratch-dir resolver; delegates the configured rung to
`resolve-config.sh`), and `sync-install.sh` (repo→`~/.claude` install sync,
deletions included — this repo's `push-main` runs it).

## The dae pipeline (build type)

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
                                               │
                                               ▼
                       push-pr --stage update (commit+push record output)
                                               │
                                               ▼
                     review-pr gate (mandatory, before finalize; branch vs
                     base; ready │ tentative │ rejected → replan / rebuild /
                     leave as draft + comment-pr)
                                               │
                                               ▼
                          push-pr --stage finalize (draft → ready)
```

`prove` (`pipeline: proof`) takes the same two-branch shape keyed on `ship`: at `ship: chat` it
short-circuits like `map`'s branch above (explore → fix the claim → a mandatory cold
falsification pass → verdict → chat + scratch file, then STOP — no gates, no worktree at
`rigor: low`); at `ship: publish` it converges on the same setup/record/ship tail as the branch
below, with no planner and no builder lanes (see `prove.md`).

Inside each builder: contract expansion → one parallel wave of `coder` ‖
`contract-tester` per packet → pipelined joins → debug-mediated rework (fresh
re-dispatch carrying contract + diagnosis, never the opposing artifact) → the
builder's own e2e tail, the sole loop exit — verified against the PLAN, which
catches a wrong contract that propagated into both code and tests.

The other types swap the middle file: `live` (conversational build, one phase
per user ask, ships on request), `diagnose` (planner ranks causes → pick
gate → fix lanes), `sync` (planner reconciles → confirm gate → record),
`document` (deep explore → record), `map` (the chat branch above: explore →
report skeleton → chat answer, no planner, no gates), `analyze` (the same
middle on the publish arc: explore → report skeleton → record under the
resolved docs root's `reports/`, no planner), `prove` (fix the claim →
gather via `explore` → a cold falsification pass, mandatory at every rigor
tier → verdict written to `proof-skeleton.md`; chat answer or record under
the resolved docs root's `proofs/`, no planner). All share setup/ship
(`ship: publish` types) and the same files in `skills/dae/`.

## Review rules for future types

Four standing rules any new `--type` row — and any reviewer judging one — is
held to:

- **Loops attach to axis VALUES, never to types.** No loop or gate branches
  on a type name; that discipline is what keeps adding a type cheap.
- **The seam rule.** Nothing loads "just in case." If a new type needs a
  skill outside the seams its row's axes name (Seam loading, in `dae`'s
  `SKILL.md`), the type's design is wrong or a seam is misplaced — fix the
  seam, never special-case the skill.
- **The carried invariants.** A new component adopts these rather than
  reinventing them: the shared worker envelope; kickbacks pass the report
  PATH, never a paraphrase; verdicts are script-written
  (`report-verdict.sh`); the plan→contract flow and its structural
  blindness; state lives in files, not context; ownership is
  machine-audited by the scope scripts; cold forks cannot ask mid-run;
  nothing publishes without passing the PR gate.
- **`pipeline` is not an array.** A run's artifact footprint (everything it
  writes) is not the same thing as its `pipeline` axis (the execution
  shape) — footprint is a planner-module constraint audited by the scope
  scripts after the fact, never a declared row field. A genuinely new,
  coherent stage combination is a new middle file and a new `pipeline`
  value, not a footprint flag bolted onto an existing one.
