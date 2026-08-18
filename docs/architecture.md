# Architecture

## What this repo is

`agentic` is a **library** of AI-agent skills, rules, and hooks, not a project
you run (root [`README.md`](../README.md)). Nothing in it executes on its own;
consumers install pieces of it into Claude Code's expected locations. The only
execution surfaces are the shell scripts under `agent-agnostic/hooks/` and
`orchestrators/hooks/`, which run inside a *consuming* project's sessions, not
inside this repo.

## The organizing principle: one question

Everything is classified by **what it is bound to**. There is one field,
`domain:`, and its value answers that question — which in turn decides where
the thing installs:

| `domain:` | Bound to | Installs to |
|---|---|---|
| `universal` | nothing — any project, any stack | user level: `~/.claude/` (or `.agent/`) |
| `<tech>` | one technology or service | project level: that project's `.claude/` / `.agent/` |

Two consequences drive the whole design:

1. **The install target is flat.** `~/.claude/skills/<name>/SKILL.md` has no
   room for this repo's folders. So `domain:` is the *only* thing that carries
   the binding once the tree is gone — which is why it must exist, and why
   `type:` was removed (it could only restate what the folder already said, and
   the folder doesn't survive).
2. **No skill or rule may reference this repo's layout.** They refer to each
   other by name and to bindings by `domain:`. A skill that said "load the
   `stacks/<tech>/` layer" would be broken the moment it was installed. Only
   the `AGENTS.md` guides and this `/docs` tree — which never leave the repo —
   describe the directory structure.

The `tech-agnostic` rule enforces the boundary: a technology named in a
universal skill is an example only; real tech knowledge belongs to a
`domain: <tech>` skill that ships with the project using it.

## Directory structure

```
agentic/
├── README.md                  # pitch, map, install
├── AGENTS.md                  # the index (payload)
├── orchestrators/             # entry points + workers          (domain: universal)
│   ├── AGENTS.md
│   ├── skills/                #   dae (router + workflow siblings + scripts), orchestrate
│   ├── hooks/                 #   workflow-setup.sh, workflow-diff-check.sh, resolve-config.sh,
│   │                          #   sync-install.sh, scope-writes.sh, mark-syllabus.sh, verify-scope.sh,
│   │                          #   plan-lifecycle.sh, …
│   └── agents/                #   planner.md (+ planner/plan-*.md), builder.md, coder.md,
│                              #   contract-tester.md
├── agent-agnostic/                   # the global layer                (domain: universal)
│   ├── AGENTS.md
│   ├── rules/                 #   the always-on set (8)
│   ├── skills/                #   the 7 tech-agnostic forks/gates
│   ├── hooks/                 #   smart-lint, smart-test, ntfy, … (settings.json-wired)
│   └── settings/              #   settings.json — versioned source of ~/.claude/settings.json
├── tool-based/                # the tech layers                 (domain: <tech>)
│   ├── AGENTS.md
│   └── <tech>/                #   svelte, tailwind, typescript, django, godot, confluence
│       ├── AGENTS.md          #   + stubs: bash, git, go, react, python, fastapi
│       ├── rules/
│       └── skills/
├── tests/                     # contract tests for the lifecycle + scope-verification scripts
└── docs/                      # meta-docs about the repo (this tree)
```

See [`pipeline.md`](pipeline.md) for the dae pipeline and
[`tool-based.md`](tool-based.md) for the tech layers.

## Skills, rules, and hooks — the separation

> **Rules are always-on constraints.** Short, declarative, no procedure. If it
> must hold even when nothing was invoked, it's a rule. `domain: universal`
> rules are on regardless; `domain: <tech>` rules are on whenever that tech is
> in play. Skills declare what they need in `rules:` frontmatter.
>
> **Skills are on-demand procedures.** Selected by `description` or an explicit
> `/name`, never by folder. Orchestrators are invoked by the user; universal
> forks/gates are invoked by name by an orchestrator or worker, so their
> descriptions say so — the guard that stops single-word skills (`explore`)
> auto-firing on a stray keyword. Tech skills *are* meant to match by
> description whenever their tech is in play. A skill may carry sibling detail
> files and a `scripts/` dir next to its SKILL.md (the `dae` router's workflow
> files; `review-plan`'s `validate-plan.sh`).
>
> **Worker agents are neither.** `agents/*.md` definitions (`planner`,
> `builder`, `coder`, `contract-tester`) are spawned via the Agent/invoke_subagent tool, hold
> warm contexts, and return the shared envelope (`conventions.md`).
>
> **Hooks are deterministic, mechanical enforcement — shell, no judgment.**
> Skill-scoped hooks wire via a skill's/agent's `hooks:` frontmatter and run
> only while that skill is active (`workflow-diff-check.sh`); global quality
> hooks wire via `settings.json` (`smart-lint.sh`, `smart-test.sh`). Helper
> scripts (`workflow-setup.sh`, `resolve-config.sh`) sit in hook dirs to share
> the `~/.claude/hooks/` install path but are invoked explicitly, never wired.
>
> Litmus: "must always hold" → rule; "how to do a job" → skill; "must happen
> every time, mechanically, without model judgment" → hook.

## Dependency / hand-off graph

A prompt dependency graph, not a code import graph — "depends on" means "hands
off to" or "is composed with."

- **`dae`** (`/dae`) resolves the docs target, captures the story when it names
  Confluence, creates the parent worktree via `workflow-setup.sh`, classifies
  the request into ONE workflow (`build.md` / `diagnose.md` / `document.md` /
  `sync.md`), then drives: `planner` (‖ `init-workspace`) → `review-plan`
  (gate; capped; revisions via SendMessage to the warm planner) → approval →
  `push-pr --stage open-draft` (draft PR opens right after the gate) →
  `builder` lanes (event-driven dispatch; each in its own child worktree,
  running the packet model with `coder`/`contract-tester` sub-agents;
  merge-back + `push-pr --stage update` + cleanup per lane) → `review-code`
  (gate; capped; reason-code kickbacks) → `document-local` **or**
  `document-confluence` → `push-pr --stage update` (commits + pushes the
  record output) → `review-pr` — the mandatory PR gate, run before
  `finalize` on EVERY run, never optional or independent — (`ready`/
  `tentative` → `push-pr --stage finalize`; `rejected` → replan / rebuild /
  leave the PR as a draft + `comment-pr`).
- **Documentation dispatch** (`artifact-locations`): a local docs path →
  `document-local` (universal); a Confluence location → `document-confluence`
  (`domain: confluence`), which also pulls in `external-storage-cap` and sends
  large artifacts to Google Drive.
- **Universal rules** are pulled in by nearly every skill via `rules:` —
  `verify-dont-assume` in almost all, `artifact-locations` in most.
- **Model policy**: orchestration/planning (`dae`, `orchestrate`, the
  `planner` agent) → `opus → sonnet → gemini-pro`; everything else → `sonnet →
  gemini-pro`. Claude Code honors only the primary `model:`.

## Open items

- Six tech layers are placeholder stubs: `bash`, `git`, `go`, `react`,
  `python`, `fastapi` — see [`tool-based.md`](tool-based.md).
- `model-fallback:` is declarative only — Claude Code reads the single `model:`.
- The item-8 scripts re-sweep (further mechanical extractions) is deliberately
  deferred until after this redesign settled — sweep against the final tree.
- No CI, build system, test suite, license, `CONTRIBUTING.md`, or `CHANGELOG`.
