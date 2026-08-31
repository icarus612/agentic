# Architecture

## What this repo is

`agentic` is a **library** of AI-agent skills, rules, and hooks, not a project
you run (root [`README.md`](../README.md)). Nothing in it executes on its own;
consumers install pieces of it into Claude Code's expected locations. The only
execution surfaces are the shell scripts under `agent-agnostic/hooks/`, which run
inside a *consuming* project's sessions, not inside this repo.

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
├── agent-agnostic/             # the global layer                (domain: universal)
│   ├── AGENTS.md
│   ├── rules/                 #   the always-on set (10)
│   ├── skills/                #   the 9 tech-agnostic forks/gates, plus dae (router +
│   │                          #   workflows.yaml type table + middle files +
│   │                          #   report-skeleton.md) and orchestrate
│   ├── hooks/                 #   smart-lint, smart-test, ntfy, … (settings.json-wired),
│   │                          #   plus workflow-setup.sh, resolve-config.sh, resolve-type.sh,
│   │                          #   resolve-anchor.sh, sync-install.sh, scope-writes.sh,
│   │                          #   mark-syllabus.sh, verify-scope.sh, plan-lifecycle.sh, …
│   ├── agents/                #   planner.md (+ planner/plan-*.md), builder.md, coder.md,
│   │                          #   contract-tester.md, committee.md
│   └── settings/              #   settings.json — versioned source of ~/.claude/settings.json
├── tool-based/                # the tech layers                 (domain: <tech>)
│   ├── AGENTS.md
│   └── <tech>/                #   svelte, tailwind, typescript, django, godot, confluence, medusa
│       ├── AGENTS.md          #   + stubs: bash, git, go, react, python, fastapi
│       ├── rules/
│       └── skills/
├── .github/                   # publish-docs.yml — canonical; post-merge docs→Confluence publish (no-op here)
├── scripts/                   # publish-docs.yml — SYMLINK into .github/workflows/, not the reverse (see README.md)
├── tests/                     # contract tests (13 suites) for the lifecycle + scope-verification scripts
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
> files and a `scripts/` dir next to its SKILL.md (the `dae` router's middle
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

- **`dae`** (`/dae`) resolves the docs target, captures the story when
  `CLAUDE_DOCS_PUBLISH` is set (`confluence-mode.md`), and resolves the
  request to ONE **type**, whose **pipeline** axis selects a middle file
  (`build.md` / `live.md` / `diagnose.md` / `sync.md` / `report.md` /
  `document.md` / `prove.md` — twelve types across six pipeline values). `map`
  (`pipeline: report`, `ship: chat`) defaults to answering in chat: explore,
  fill the report skeleton, answer in chat — zero gates, and (per
  `report.md`) no branch, commit, or anything staged — no worktree either at
  `rigor: low`. Every
  other type — every `ship: publish` type, `analyze` and `document`
  included — creates the parent worktree via `workflow-setup.sh`. Types
  carrying a `planner:` cell (every `pipeline: build` type, plus
  `diagnose` and `sync`) drive:
  `planner` (‖ `init-workspace`) → `review-plan` (gate; capped; takes the
  run's ask of record as an input, an unrecorded divergence routing
  `plan-wrong`; revisions via SendMessage to the warm planner) → approval →
  `push-pr --stage open-draft` (draft PR opens right after the gate) →
  `builder` lanes (event-driven dispatch; each in its own child worktree,
  running the packet model with `coder`/`contract-tester` sub-agents;
  merge-back + `push-pr --stage update` + cleanup per lane) → `review-code`
  (gate, run once every builder lane has merged, over the whole assembled
  implementation — never scoped to one lane; capped; reason-code kickbacks).
  The planner-less publish types (`document`, `analyze`) skip straight to
  a deep explore/report pass — no plan gate, no builder lanes, no
  `review-code`: nothing is committable before the record stage, so the
  draft PR opens at the **record commit** instead. Both arcs converge on
  the shared record + ship tail:
  → `document-local` → `push-pr --stage update` (commits + pushes the record
  output) → `review-pr` — the mandatory PR gate, run before `finalize` on
  EVERY `ship: publish` run, never optional or independent —
  (`ready`/`tentative` → `push-pr --stage finalize`; `rejected` → replan /
  rebuild / leave the PR as a draft + `comment-pr`).
- **Documentation dispatch** (`artifact-locations`): `CLAUDE_DOCS_DIR` is
  always a local path, and the record stage is always `document-local`
  (universal). The optional `CLAUDE_DOCS_PUBLISH` names a separate publish
  target — publishing is a CI job on merge, never a run stage — and when it
  is set, `confluence-mode.md` (`domain: universal`) governs requirements
  capture, pulling in `external-storage-cap` for large artifacts to Google
  Drive. `document-confluence` is the manual/recovery sync that mirrors the
  local docs tree to that target, never a run stage.
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
- One GitHub Actions workflow — a post-merge docs→Confluence publish job
  that no-ops in this repo, since this repo configures no publish target;
  it ships as a working, copyable reference for consuming projects. Still
  no build system, license, `CONTRIBUTING.md`, or `CHANGELOG`. `tests/`
  holds 13 contract-test suites for the lifecycle + scope-verification
  scripts — still no test framework or runner beyond that.
