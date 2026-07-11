# Architecture

## What this repo is

`agentic` is a **library** of AI-agent instructions and skills, not a project
you run (root [`README.md`](../README.md)). Nothing in it executes on its own;
consumers copy pieces of it into their own projects and their own AI tool's
expected locations. The only real execution surface is two Bash scripts
(`agents/workflows/dev/hooks/*.sh`) that run inside a *consuming* project's
workflow, not inside this repo.

## Two organizing principles

### 1. Generic source of truth, thin tool adapters

All real content is tool-agnostic and lives in [`agents/`](../agents/). Each AI
tool gets a small adapter under [`tools/<tool>/`](../tools/) that only explains
*where that tool expects the files* — adapters never duplicate content, they
point back at `agents/`.

```
agents/   ← canonical, generic content (edit here)
tools/    ← per-tool wiring instructions (claude, gemini, antigravity)
```

### 2. Layered scope

Content composes in layers, broadest to narrowest:

```
universal  ⊕  workflow(s)  ⊕  stack(s)  ⊕  project
```

- **universal** — applies everywhere: `agents/AGENTS.md`, `agents/rules/`.
- **workflow** — a process you run: `agents/workflows/dev`, `agents/workflows/delivery`.
- **stack** — applies to one tech: `agents/stacks/python/…`, `agents/stacks/javascript/react`, etc.
- **project** — applies to one consuming repo; lives in *that* repo, not here.

To set up a project, a consumer pulls in the universal rules plus the
workflow(s) and stack(s) they need, then adds project-specific instructions
locally.

## Directory structure

```
agentic/
├── README.md                          # library pitch + directory map + usage
├── agents/                            # canonical, tool-agnostic source of truth
│   ├── AGENTS.md                      # universal index; skill/rule format spec; model policy summary
│   ├── README.md                      # deeper spec: skill format, rule format, type/domain/folder semantics
│   ├── rules/                         # 8 universal rules (type: rule, domain: universal)
│   ├── stacks/                        # 10 tech-scoped placeholders (AGENTS.md stub + empty skills/.gitkeep)
│   │   ├── bash/, git/, go/
│   │   ├── javascript/{node/generic, react, styles, svelte}/
│   │   └── python/{generic, django, fastapi}/
│   └── workflows/
│       ├── dev/                       # the build pipeline (12 skills + 1 sub-agent + 2 hooks)
│       └── delivery/                  # wraps dev with Jira/Confluence/Drive (7 skills)
└── tools/                             # thin per-tool adapters, no content of their own
    ├── antigravity/README.md          # partial — instructions & skills location unverified
    ├── claude/README.md                # complete
    └── gemini/README.md                # partial — skills location + gemini-pro model id unconfirmed
```

See [`workflows/dev.md`](workflows/dev.md) and [`workflows/delivery.md`](workflows/delivery.md)
for what's inside each workflow, [`stacks.md`](stacks.md) for the stack layer,
and [`tools.md`](tools.md) for adapter status.

## Skills, rules, and folders

Three content kinds, each declaring a `type` in its frontmatter:

- **`type: workflow` / `type: stack` skills** — a `skills/<name>/SKILL.md` with
  full frontmatter (`name`, `description`, `type`, `domain`, `rules`, `model`,
  `model-fallback`, optional `context: fork`, `agent:`, `hooks:`). Selected by
  the model via its `description` (or an explicit `/name`), so the body loads
  on demand.
- **`type: rule` rules** — a short `rules/<name>.md`, loaded as **always-on
  context** with no selection step. Each skill names the rules it needs in its
  `rules:` frontmatter.

An agent selects a skill by `description`, **not** by folder — folders exist
for composition (what a consumer copies into a project) and maintenance.
Workflows group skills by *process* (and cycle: `pre/`, `post/`, `shared/`);
stacks group by *tech*. The `domain` field mirrors the folder. Full format spec:
[`agents/README.md`](../agents/README.md); summarized in
[`conventions.md`](conventions.md).

## Dependency / hand-off graph

This is a documentation/prompt dependency graph, not a code import graph —
"depends on" means "hands off to" or "is composed with."

- **Root [`README.md`](../README.md)** points to `agents/` (content) and
  `tools/` (adapters); defines the universal ⊕ workflow ⊕ stack ⊕ project
  composition model above.
- **`agents/AGENTS.md` / `agents/README.md`** index `agents/rules/`
  (always-on) and `agents/workflows/`, `agents/stacks/` (selected by skill
  `description`).
- **Universal rules** (`agents/rules/*.md`) are pulled in by nearly every
  skill via its `rules:` frontmatter — `verify-dont-assume` appears in all 19
  skills; `artifact-locations` in most; `tech-agnostic` in the
  explore/plan/plan-review/code/code-review/init/map family.
- **`dev` pipeline**, driven by `dev-start`:
  `dev-start` → `workflow-setup.sh` (creates a git worktree) → `dev-explore` →
  `dev-init` → `dev-plan` → `dev-plan-review` (human gate, loops to
  explore/plan) → a `dev-builder` sub-agent wrapping the
  `dev-code` ⇄ `dev-debug` ⇄ `dev-test` loop (only `dev-test` breaks it) →
  `dev-code-review` (human gate, loops to any earlier phase) → `dev-document`
  → `dev-finish` (push + `workflow-diff-check.sh`-gated teardown).
  `dev-map` is a side-orchestrator for doc-only bootstrap/refresh runs:
  `workflow-setup.sh --reuse` (worktree on the fixed branch `feature/map-repo`
  or `feature/remap-repo`, base merged in on reuse) → `dev-explore` (forced
  DEEP) → `dev-init` → `dev-document` (map-driven) → `dev-finish` — this docs
  tree was produced by exactly that path.
- **`delivery` workflow** wraps `dev`: `delivery-start` → `delivery-connect` →
  `delivery-pre-requirements` → **`dev-start`** (the full dev pipeline
  embedded as the "implementation" step) → `delivery-post-confluence` →
  `delivery-post-changelog` → `delivery-post-jira-link`, with
  `delivery-drive-archive` callable from any step that needs to offload
  large/binary artifacts.
- **`tools/claude`, `tools/gemini`, `tools/antigravity`** each read-only
  reference `agents/` — no original content, only copy-paste/wiring
  instructions; forbidden from duplicating `agents/` content
  (`agents/README.md` contributing guidance).
- **Model-fallback chain** (enforced by the `model-policy` rule):
  orchestration/planning skills (`dev-start`, `dev-plan`, `delivery-start`) →
  `opus → sonnet → gemini-pro`; every other skill → `sonnet → gemini-pro`.
  Claude Code (the one complete adapter) only honors the single primary
  `model:` value.

## Docs topology

No file in this repo currently sits where a symlink into `/docs` should be —
see [`README.md`](README.md#why-docs-is-separate-from-agents) for why the
root `README.md`, `agents/AGENTS.md`/`agents/README.md`, the per-workflow
`AGENTS.md` guides, and the `tools/<tool>/README.md` adapters stay as real
files in place: they are the library's shipped payload, not documentation
about this repo. `/project-plans/` (plans) and `.workflows/` (workflow
worktrees) are the other two artifact-location defaults defined by
`agents/rules/artifact-locations.md`; neither directory exists in this repo
today.

## Open items

- All 10 `agents/stacks/<tech>/AGENTS.md` files are placeholder stubs — see
  [`stacks.md`](stacks.md).
- `tools/gemini/README.md` and `tools/antigravity/README.md` carry explicit
  `_TODO` markers — see [`tools.md`](tools.md).
- `agents/workflows/dev/rules/` intentionally does not exist — the dev
  workflow's conventions are the universal rules; there are no dev-scoped
  rules to add yet.
- No CI, build system, test suite, license file, `CONTRIBUTING.md`, or
  `CHANGELOG` exist in this repo.
