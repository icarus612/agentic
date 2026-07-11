# agentic

A **library** of AI-agent instructions and skills — a single source of truth you
copy into your projects. It is **not** a project you run. Nothing here executes;
you take pieces from it and drop them where your tool expects them (Claude Code
first: `~/.claude/` or a project's `.claude/`).

## Two principles

### 1. One source of truth, copy-paste distribution

All content lives in this repo, organized by kind — `rules/`, `hooks/`, and
`skills/` — and is **edited here only**. Consumers copy what they need into
their tool's locations: skills into `~/.claude/skills/` (or a project's
`.claude/skills/`), rules and the `AGENTS.md` guides into `CLAUDE.md`, hooks
into `~/.claude/hooks/` (installed automatically by Nix home-manager in this
user's setup). Copy-paste is intentional — chosen over symlinks or a setup
script so it behaves identically on Linux, macOS, and Windows with zero tooling.

### 2. Layered scope

Content composes in layers, broadest to narrowest:

```
universal  ⊕  workflow(s)  ⊕  stack(s)  ⊕  project
```

- **universal** — applies everywhere (`AGENTS.md`, `rules/`)
- **workflow** — a process you run (`skills/workflows/dev`)
- **stack** — applies to a tech (`skills/stacks/python/…`, `…/javascript/svelte`)
- **project** — applies to one repo; **lives in that repo**, not here

To set up a project you pull in the universal rules + the workflow(s) and
stack(s) you need, then add project-specific instructions locally.

## Directory map

```
agentic/
├── AGENTS.md                        # universal index + pointers
├── rules/                           # universal rules (type: rule) — always-on context
├── hooks/                           # generic quality hooks (smart-lint, smart-test, …)
├── skills/
│   ├── workflows/
│   │   └── dev/                     # the build pipeline
│   │       ├── AGENTS.md            # workflow guide
│   │       ├── rules/               # workflow-scoped rules (external-storage-cap)
│   │       ├── agents/              # builder (the build-loop sub-agent)
│   │       ├── hooks/               # workflow-setup.sh, workflow-diff-check.sh
│   │       └── skills/  → dev (/dev) and map (/map) orchestrate:
│   │                     explore → init-workspace → plan → review-plan →
│   │                     code ⇄ debug ⇄ test → review-code →
│   │                     document-local | document-confluence → push-pr (⇢ review-pr)
│   ├── stacks/                      # tech-specific layers (type: stack)
│   │   ├── python/{generic,fastapi,django}/
│   │   ├── javascript/{node/generic,react,svelte,styles}/
│   │   └── godot/  go/  bash/  git/
│   └── singletons/                  # standalone skills (orchestrate)
└── docs/                            # meta-docs about this repo itself
```

## Skills, rules, and hooks

Three content kinds with a crisp separation (full spec:
[`docs/conventions.md`](docs/conventions.md), rationale:
[`docs/architecture.md`](docs/architecture.md)):

- **Skills** — on-demand procedures (`skills/<name>/SKILL.md`, full
  frontmatter). Entry-point orchestrators are user-invoked (`/dev`, `/map`,
  `/orchestrate`); phase skills are invoked by name by an orchestrator and
  their descriptions say so, so they never auto-fire on keyword overlap.
- **Rules** — always-on constraints (`rules/<name>.md`, short,
  frontmatter-light). Universal rules apply everywhere; workflow-scoped rules
  live with their workflow.
- **Hooks** — deterministic mechanical enforcement (shell, no judgment).
  Skill-scoped hooks wire via a skill's `hooks:` frontmatter; global quality
  hooks wire via `settings.json`.

An agent selects a skill by `description`, **not** by folder — folders exist for
**composition** (what you copy into a project) and **maintenance**. The `domain`
field mirrors the folder.

## Usage (copy-paste)

1. Clone or download this repo.
2. Copy the root `AGENTS.md`, the universal `rules/`, plus the
   `skills/workflows/<wf>/AGENTS.md` and `skills/stacks/<tech>/AGENTS.md`
   guides you need into your `CLAUDE.md` (project `./CLAUDE.md` or personal
   `~/.claude/CLAUDE.md`).
3. Copy the skill directories you want into `~/.claude/skills/<name>/` (or the
   project's `.claude/skills/`), and `skills/workflows/dev/agents/builder.md`
   into `~/.claude/agents/`.
4. Hooks (`hooks/` and `skills/workflows/dev/hooks/`) install to
   `~/.claude/hooks/` — automated via Nix home-manager in this setup; copy them
   manually otherwise.

## Contributing

- Edit content **here first**, never in `~/.claude/` — this repo is the source
  of truth; installs are copies.
- A process goes under `skills/workflows/<wf>/`, a tech under
  `skills/stacks/<tech>/`, a standalone skill under `skills/singletons/`,
  universal rules in `rules/`.
- Give each skill a clear `description` (phase skills must name their workflow
  in it), a `type` + `domain`, a `model` + `model-fallback`, and a `rules:`
  list of the rules it depends on.
- Keep rules short and frontmatter-light (they're always-on context).
