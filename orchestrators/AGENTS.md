# Orchestrators

Entry-point skills the **user** invokes. They own no domain knowledge — they
drive a pipeline, delegate every real step to `generic/` phase skills (and
`tool-based/` skills when a technology or service is in play), and manage
context by passing pointers instead of payloads.

Everything an orchestrator owns lives here: the skills, the worktree/gate
scripts in [`hooks/`](hooks/), and the build-loop sub-agent in
[`agents/`](agents/).

| Skill | Invoke | What it drives |
|---|---|---|
| **`dev`** | `/dev` | The full build pipeline (below). Opus for itself; tracks phase state; surfaces only blockers and completion summaries. Carries a `Stop` hook wired to `workflow-diff-check.sh`. |
| **`map`** | `/map` | Documentation-only runs — a deep `explore`, `init-workspace`, a map-driven document phase, then `push-pr`, on a fixed `feature/{re,}map-repo` branch. For when there is no code change to record. |
| **`orchestrate`** | `/orchestrate` | Generic task coordinator: decompose any multi-part task, delegate to subagents (parallel where independent), verify and synthesize. Not tied to the dev pipeline. |
| **`sync-status`** | `/sync-status` | Reconciles ALREADY-SHIPPED work against its `/project-plans/` plan and/or Jira ticket — verifies what's done, checks off the plan syllabus, updates/transitions the ticket, refreshes docs, reports a diff against the base branch. Reuses `map`'s worktree/push-pr scaffolding; truth source is the plan/ticket, not a blind sweep. |
| **`diagnose`** | `/diagnose` | Root-cause investigation for an unclear bug — diffs the suspect work (live branch OR already-merged), explores DEEP only if the diff doesn't localize it, and produces a RANKED candidate-cause report graded by likelihood × ease-of-fix. Gates on the user's pick, then drives only the chosen fixes through `builder` → `review-code` → `push-pr`. Reuses `sync-status`'s worktree scaffolding and `dev`'s fix loop; the ranked report is the deliverable, not a phased plan. Carries the same `Stop`→`workflow-diff-check.sh` hook as `dev`. |

## The dev pipeline

```
dev (/dev) ─drives─▶  explore → init-workspace → plan → review-plan ─(repeat)─┐
                                         │ approved                            │
                                         ▼                                     │
                     code ⇄ debug ⇄ test ──▶ review-code ─(loop to ANY phase)
                                         │ clean                               │
                                         ▼                                     │
                  document-local | document-confluence (& log) ◀───────────────┘
                                         │
                                         ▼
                               push-pr  (⇢ optional review-pr)
```

`(repeat)` and the review loop mean any phase can jump **back to any earlier
phase** when something is off, then resume forward.

**Strict loop rule** — repeated verbatim in the `dev` skill, the `builder`
agent, and the three loop skills; treat it as load-bearing:

> The `code` skill never exits on its own. The `debug` skill may exit but
> prefers handing off. Only the `test` skill can break the loop with a terminal
> success.

The phase skills live in [`../generic/skills/`](../generic/skills/) — they are
tech-agnostic and usable outside this pipeline. Two human gates (`review-plan`
before any code, `review-code` before any docs) return structured verdicts; the
orchestrator holds the actual conversation with the user, because forks can't.

The documentation phase **dispatches on `CLAUDE_DOCS_DIR`**: a local path
(default `/docs`) → `document-local` (generic); a Confluence location →
`document-confluence` ([`../tool-based/confluence/`](../tool-based/confluence/)),
in which case the `dev` orchestrator also captures the story/requirements up
front, and the published pages carry the ask and narrative, not just the
technical detail.

## Hooks

- **`workflow-setup.sh`** — a helper, **not** a hook: the `dev`, `map`, and
  `sync-status` skills invoke it via Bash. Creates the git worktree in the
  resolved workflows dir (`CLAUDE_WORKFLOWS_DIR` chain) on branch
  `<type>/<name>` (`feature|bug|hotfix`), gitignores that dir, resolves the
  base branch via `resolve-config.sh` (`CLAUDE_BASE_BRANCH` chain, then a git
  heuristic), and prints machine-readable `WORKTREE`/`BRANCH`/`BASE`/`REUSED`
  lines. It rides along in a hooks dir to share the `~/.claude/hooks/`
  install path.
- **`resolve-config.sh`** — a helper, **not** a hook: resolves any
  `CLAUDE_*` config var (docs/plans/worktrees/base-branch) through the
  project → global → local-default chain described in `artifact-locations`,
  reading the settings JSON files directly rather than trusting the
  inherited process environment (Claude Code's `env` block doesn't
  deep-merge across scopes). `workflow-setup.sh` delegates to it for both the
  workflows dir and base-branch resolution; `dev`/`map`/`sync-status` call it
  directly for the docs (and, for `sync-status`, plans) dir.
- **`workflow-diff-check.sh`** — a real hook, wired via frontmatter `hooks:` on
  the `dev` skill (`Stop`) only. Diffs the workflow branch against its
  merge-base and runs the project's own checks on the changed files; exit 2
  blocks the stop until they pass. Deliberately NOT wired on the `builder`
  agent: builders run in parallel lanes sharing one worktree, so a
  whole-worktree diff at one builder's stop would block on siblings' in-flight
  changes — `dev` runs the checks per wave and at integration instead.

## Agents

- **`builder`** — the build-loop sub-agent, one per plan **lane**. Preloads
  `code`, `debug`, and `test` so the handoff rules are in context before the
  first handoff, and runs the triad **inline in one shared context** — the
  shared working state (edits, errors, test output) surviving across handoffs
  is the whole point. Spawned by `dev` via the Agent tool, in parallel waves
  scheduled from the plan's syllabus (one builder per lane, cap 5 per wave);
  each builder owns its lane's subphases and file scope, never touches files
  outside it, and never edits the plan file — `dev` ticks the syllabus from
  builder reports.

Rules: the always-on set lives in [`../generic/rules/`](../generic/rules/)
(`artifact-locations` for where docs/plans/worktrees live and how the docs
target dispatches, plus `plan-format`, `doc-format`, `push-policy`, …). Each
skill names what it needs in its `rules:` frontmatter.
