# Architecture

## What this repo is

`agentic` is a **library** of AI-agent instructions and skills, not a project
you run (root [`README.md`](../README.md)). Nothing in it executes on its own;
consumers copy pieces of it into their own projects and their AI tool's
expected locations (Claude Code first). The only real execution surfaces are
the shell scripts under [`hooks/`](../hooks/) and
[`skills/workflows/dev/hooks/`](../skills/workflows/dev/hooks/), which run
inside a *consuming* project's sessions, not inside this repo.

## Two organizing principles

### 1. One source of truth, copy-paste distribution

All content lives in this repo, organized by kind at the root — `rules/`,
`hooks/`, `skills/` — and is edited here only. There are no per-tool adapter
folders: the library targets Claude Code's layout directly (skills →
`~/.claude/skills/`, agents → `~/.claude/agents/`, hooks → `~/.claude/hooks/`
via Nix home-manager, guides → `CLAUDE.md`). Distribution is deliberately
copy-paste, not symlinks or a setup script, so it behaves identically across
platforms with zero tooling.

### 2. Layered scope

Content composes in layers, broadest to narrowest:

```
universal  ⊕  workflow(s)  ⊕  stack(s)  ⊕  project
```

- **universal** — applies everywhere: `AGENTS.md`, `rules/`.
- **workflow** — a process you run: `skills/workflows/dev`.
- **stack** — applies to one tech: `skills/stacks/python/…`, `skills/stacks/javascript/svelte`, etc.
- **project** — applies to one consuming repo; lives in *that* repo, not here.

To set up a project, a consumer pulls in the universal rules plus the
workflow(s) and stack(s) they need, then adds project-specific instructions
locally.

## Directory structure

```
agentic/
├── README.md                          # library pitch + directory map + usage
├── AGENTS.md                          # universal index; layout; rule/hook pointers
├── rules/                             # 8 universal rules (type: rule, domain: universal)
├── hooks/                             # generic quality hooks (smart-lint, smart-test,
│                                      #   ntfy-notifier, record/test-changed, helpers)
├── skills/
│   ├── workflows/
│   │   └── dev/                       # the build pipeline (14 skills + 1 sub-agent + 2 scripts)
│   │       ├── AGENTS.md              # workflow guide
│   │       ├── rules/                 # external-storage-cap (dev-scoped)
│   │       ├── agents/builder.md      # build-loop sub-agent
│   │       ├── hooks/                 # workflow-setup.sh, workflow-diff-check.sh
│   │       └── skills/                # dev, map, explore, init-workspace, plan,
│   │                                  #   review-plan, code, debug, test, review-code,
│   │                                  #   document-local, document-confluence,
│   │                                  #   push-pr, review-pr
│   ├── stacks/                        # tech layers; several have real rules + skills
│   │   ├── bash/ git/ go/ godot/
│   │   ├── javascript/{node/generic, react, styles, svelte}/
│   │   └── python/{generic, django, fastapi}/
│   └── singletons/orchestrate/        # standalone skills
└── docs/                              # meta-docs about the repo (this tree)
```

See [`workflows/dev.md`](workflows/dev.md) for what's inside the workflow and
[`stacks.md`](stacks.md) for the stack layer.

## Skills, rules, and hooks — the separation

Three content kinds with a crisp division of labor:

> **Rules are always-on constraints.** Short, declarative, no procedure. If it
> must hold even when nothing was invoked, it's a rule. Universal rules live in
> `rules/`; workflow-scoped rules in `skills/workflows/<wf>/rules/`;
> stack-scoped rules in `skills/stacks/<tech>/rules/`. Skills declare their
> dependencies via `rules:` frontmatter.
>
> **Skills are on-demand procedures.** Two kinds: *entry-point orchestrators*
> the user invokes (`/dev`, `/map`, `/orchestrate`) and *phase skills* invoked
> by name by an orchestrator (or preloaded into an agent, like the build loop).
> A phase skill's description must state its workflow so it never auto-fires on
> incidental keyword overlap — several dev phases are single words (`plan`,
> `code`, `test`), and the description guard is what keeps them scoped.
>
> **Hooks are deterministic, mechanical enforcement — shell, no judgment.**
> Skill-scoped hooks wire via a skill's/agent's `hooks:` frontmatter (active
> only while that skill runs — `workflow-diff-check.sh`); global quality hooks
> wire via `settings.json` (`smart-lint.sh`, `smart-test.sh`). Helper scripts
> (`workflow-setup.sh`) ride along in `hooks/` to share the single
> `~/.claude/hooks/` install path but are invoked explicitly by skills, never
> wired as hooks.
>
> Litmus: "must always hold" → rule; "how to do a job" → skill; "must happen
> every time, mechanically, without model judgment" → hook.

Selection mechanics: a skill is selected by its `description` (or an explicit
`/name`), **not** by folder — folders exist for composition (what a consumer
copies) and maintenance. The `domain` field mirrors the folder. Formats:
[`conventions.md`](conventions.md).

## Dependency / hand-off graph

This is a documentation/prompt dependency graph, not a code import graph —
"depends on" means "hands off to" or "is composed with."

- **Root [`README.md`](../README.md)** and **`AGENTS.md`** index `rules/`
  (always-on) and `skills/workflows/`, `skills/stacks/`, `skills/singletons/`
  (selected by skill `description`).
- **Universal rules** (`rules/*.md`) are pulled in by nearly every skill via
  its `rules:` frontmatter — `verify-dont-assume` appears in almost all;
  `artifact-locations` in most; `tech-agnostic` in the
  explore/plan/review/code/init family.
- **`dev` pipeline**, driven by the `dev` orchestrator (`/dev`):
  read `CLAUDE_DOCS_DIR` (+ requirements capture when it names Confluence) →
  `workflow-setup.sh` (creates a git worktree) → `explore` →
  `init-workspace` → `plan` → `review-plan` (human gate, loops to
  explore/plan) → a `builder` sub-agent wrapping the `code` ⇄ `debug` ⇄ `test`
  loop (only `test` breaks it) → `review-code` (human gate, loops to any
  earlier phase) → `document-local` **or** `document-confluence` (dispatched by
  `CLAUDE_DOCS_DIR`) → `push-pr` (push + PR + `workflow-diff-check.sh`-gated
  teardown), with `review-pr` as an optional independent pass on the opened PR.
  `map` (`/map`) is a side-orchestrator for doc-only bootstrap/refresh runs:
  `workflow-setup.sh --reuse` (worktree on the fixed branch `feature/map-repo`
  or `feature/remap-repo`) → `explore` (forced DEEP) → `init-workspace` →
  the document phase (map-driven) → `push-pr` — this docs tree was produced by
  exactly that path.
- **Docs-target dispatch** (`artifact-locations` rule): `CLAUDE_DOCS_DIR`
  unset/path → `document-local` (root `/docs` is the source of truth);
  Confluence URL or `confluence:SPACE[/Parent]` → `document-confluence`
  (Confluence is the source of truth; the `dev` orchestrator captures the
  story/requirements up front; `external-storage-cap` sends large artifacts to
  Google Drive). The scheme is extensible: `<target>:` → `document-<target>`.
- **Model-fallback chain** (enforced by the `model-policy` rule):
  orchestration/planning skills (`dev`, `map`, `plan`) →
  `opus → sonnet → gemini-pro`; every other skill → `sonnet → gemini-pro`.
  Claude Code only honors the single primary `model:` value.

## Docs topology

No file in this repo currently sits where a symlink into `/docs` should be —
see [`README.md`](README.md#why-docs-is-separate-from-the-payload) for why the
root `README.md`, `AGENTS.md`, and the per-workflow/stack `AGENTS.md` guides
stay as real files in place: they are the library's shipped payload, not
documentation about this repo. `/project-plans/` (plans) and `.workflows/`
(workflow worktrees) are the other two artifact-location defaults defined by
`rules/artifact-locations.md`; neither directory exists in this repo today.

## Open items

- Six stack layers are still placeholder stubs (`bash`, `git`, `go`,
  `javascript/react`, `python/generic`, `python/fastapi`) — see
  [`stacks.md`](stacks.md).
- `model-fallback:` (and the `gemini-pro` backstop) is declarative only —
  Claude Code reads the single `model:` value; no other tool is wired today.
- No CI, build system, test suite, license file, `CONTRIBUTING.md`, or
  `CHANGELOG` exist in this repo.
