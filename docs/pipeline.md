# The dev pipeline

Canonical guide: [`orchestrators/AGENTS.md`](../orchestrators/AGENTS.md). This
page is the meta-summary; edit pipeline behavior in the payload file, not here.

The orchestrators (`domain: universal`) drive it; every phase is a universal
skill they invoke **by name**. Nothing in the pipeline is bound to a technology
except the documentation phase, when the docs target is Confluence.

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

## Skills

| Skill | Model | Context | Role |
|---|---|---|---|
| `dev` | opus → sonnet → gemini-pro | inline (orchestrator) | `/dev` — drives the whole pipeline; resolves the docs target and captures story/requirements up front when it names Confluence; creates the worktree; tracks phase state; surfaces only blockers and summaries. Carries a `Stop` hook wired to `workflow-diff-check.sh`. |
| `map` | opus → sonnet → gemini-pro | inline (orchestrator) | `/map` — documentation-only runs on a fixed `feature/{re,}map-repo` branch: forced-DEEP `explore` → `init-workspace` → the document phase (map-driven: no plan, no diff — the map is ground truth) → `push-pr`. Not for documenting a change already built through the pipeline. |
| `explore` | sonnet | fork | Read-only codebase map: stack + MAJOR versions, structure, dependency graph, patterns, conventions. Shallow or deep; monorepo-aware. |
| `init-workspace` | sonnet | fork | Installs dependencies and sets up toolchains inside the worktree. (Verbose name — `init` collides with a Claude Code built-in.) |
| `plan` | opus → sonnet | fork | Turns explore's findings into an ordered plan in the plans dir. Requires at least a shallow explore; pins MAJOR versions; conventions as hard constraints. |
| `review-plan` | sonnet | fork | **Human gate** before any code. Verifies every claim, asks when unsure, returns a structured verdict (it cannot talk to the user itself). Loops back to `explore`/`plan`. |
| `code` | sonnet | inline (shared loop) | Implements one planned unit. **Never exits on its own.** |
| `debug` | sonnet | inline (shared loop) | Finds the real root cause and reports it with a fix recommendation — never writes the fix. Routes to `code` (implement) or `test` (verify). |
| `test` | sonnet | inline (shared loop) | Verifies against the plan. **The only skill that can break the loop.** |
| `review-code` | sonnet | fork | **Human gate** before any docs. Same discipline as `review-plan`; may loop back to **any** earlier phase. (Named noun-last — `code-review` collides with a built-in.) |
| `document-local` | sonnet | fork | Documentation phase when the docs target is a local path: writes into the docs root (mirroring project structure); optional changelog via `git add`+`git commit`, never a push. |
| `document-confluence` | sonnet | fork | Documentation phase when the docs target is Confluence. The one **tech-bound** phase (`domain: confluence`). |
| `push-pr` | sonnet | fork | Terminal phase: commits stragglers, pushes the workflow branch, opens a PR against the base branch (always asks first; never force-pushes, never pushes main), tears down the worktree. |
| `review-pr` | sonnet | fork | Reviews a GitHub PR — the one `push-pr` opened, or any the user points at. Posts comments only on explicit instruction; never merges or approves. |

The `code`/`debug`/`test` triad runs **inline inside one shared context per
`builder` sub-agent** — each builder preloads all three so the handoff rules
are in context before the first handoff, and the shared working state (edits,
errors, test output) survives across handoffs. `dev` dispatches builders from
the plan's syllabus: one builder per **lane** (a chain of subphases with only
internal dependencies), lanes running concurrently in dependency-ordered
**waves** (cap 5 per wave; a single-lane plan gets one builder). Each builder
owns its lane's file scope and never edits the plan file — `dev` ticks the
syllabus and runs the project's checks between waves and at a final
integration pass.

## Loop-breaking invariant

Repeated across the `dev` skill, the `builder` agent, and the three loop
skills — treat it as load-bearing:

> The `code` skill never exits on its own. The `debug` skill may exit but
> prefers handing off. Only the `test` skill can break the loop with a terminal
> success.

## Naming

The orchestrators are the user-facing surface and get the shortest names
(`/dev`, `/map`). Phase skills are invoked by name by an orchestrator, so they
keep generic single-word names where safe (`explore`, `plan`, `code`, `debug`,
`test`) — with **description guards** ("Part of the dev workflow, invoked by the
dev orchestrator…") so they never auto-fire on an incidental keyword match —
and verbose names where a single word would collide with a Claude Code built-in
(`init-workspace`, `review-code`) or be ambiguous (`document-local` /
`document-confluence`, `push-pr`, `review-pr`).

## Documentation dispatch

Per `artifact-locations`, the orchestrators resolve the docs target and
dispatch on the value's shape:

- **A filesystem path** (default `/docs`) → **`document-local`**
  (`domain: universal`); the local docs root is the single source of truth and
  `doc-format`'s mirror/symlink rules apply.
- **A Confluence location** — an Atlassian wiki URL or `confluence:<SPACE>[/<Parent Page>]`
  → **`document-confluence`** (`domain: confluence`); Confluence is the docs
  source of truth and no local `/docs` is maintained. The `dev` orchestrator
  additionally captures requirements up front (verbatim ask, narrative,
  acceptance criteria, Jira keys, Drive folder — in conversation, since forks
  can't converse) and persists them as a `.story.md` beside the plan, so the
  published page carries the story, not just the technical detail. Large
  artifacts go to Google Drive per `external-storage-cap`.
- Extensible: another target maps to the skill named `document-<target>`.

Claude Code selects skills by description or explicit name — never by config —
so the dispatch is the orchestrator's job: it resolves the target and invokes
the matching skill by name.

This absorbed the former `delivery` workflow: its connect preflight, Confluence
story/changelog publishing, Jira linking, and Drive offload all live in
`document-confluence`; its requirements capture lives in the `dev` orchestrator.

## Hooks

Both are POSIX-ish Bash and apply to a **consuming** project, not to `agentic`:

- **`workflow-setup.sh`** — a helper invoked by the orchestrators via Bash, not
  a hook. Creates the git worktree on branch `<type>/<name>`
  (`feature|bug|hotfix`), gitignores the worktrees dir, resolves the base
  branch, and prints machine-readable `WORKTREE`/`BRANCH`/`BASE`/`REUSED`
  lines. `--reuse` picks up an existing branch and merges the base into it
  (conflicts abort cleanly).
- **`workflow-diff-check.sh`** — a real hook, wired via frontmatter on the `dev`
  skill (`Stop`) only. Diffs the workflow branch against its merge-base, buckets
  changed files by extension, and runs vitest/`go test`/pytest if present. Exit
  0 when nothing is runnable; exit 2 with a stderr report when changed-file
  tests fail, blocking the stop until fixed. Deliberately not wired on the
  `builder` agent: parallel builders share one worktree, so a whole-worktree
  diff at one builder's stop would block on siblings' in-flight changes — `dev`
  runs the checks per wave instead.
