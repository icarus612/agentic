# Agent instructions (index)

The library is split by **what a thing is bound to** — nothing, or one
technology. That single question also decides where it installs.

```
agentic/
├── AGENTS.md                  ← this file
├── orchestrators/             ← ENTRY POINTS the user invokes
│   ├── skills/                dev (/dev), map (/map), orchestrate (/orchestrate)
│   ├── hooks/                 workflow-setup.sh, workflow-diff-check.sh, resolve-config.sh
│   └── agents/                builder.md (the build-loop sub-agent)
├── generic/                   ← GLOBAL: bound to no technology
│   ├── rules/                 the always-on set (verify-dont-assume, push-policy, …)
│   ├── skills/                explore, plan, code, debug, test, review-*, document-local, push-pr, …
│   └── hooks/                 smart-lint.sh, smart-test.sh, … (wired via settings.json)
└── tool-based/                ← bound to ONE technology or service
    └── <tech>/                svelte, tailwind, typescript, django, godot, confluence, …
        ├── rules/
        └── skills/
```

## `domain:` — the only classifier

Every skill and rule declares exactly one field, and its value is what the
thing is bound to:

| `domain:` | Bound to | Installs to |
|---|---|---|
| `universal` | nothing — works on any project, any stack | **user level**: `~/.claude/` (or `.agent/`) |
| `<tech>` (`svelte`, `django`, `confluence`, …) | that one technology or service | **project level**: the consuming project's `.claude/` or `.agent/` |

Everything in `orchestrators/` and `generic/` is `domain: universal` — it goes
in once, globally, and is available everywhere. Everything under
`tool-based/<tech>/` is `domain: <tech>` — it ships with the projects that
actually use that tech, discovered from real manifests, never assumed
(`tech-agnostic`).

The install target is **flat** (`skills/<name>/SKILL.md`), so this repo's
folders do not survive it. That's the point of `domain:` — it is the only thing
that carries the binding once the tree is gone. **Nothing inside a skill or
rule may reference this repo's layout**; they refer to each other by name and
to bindings by `domain:`.

## The three kinds

- **Skills** — on-demand procedures, `skills/<name>/SKILL.md`. Selected by
  `description` or an explicit `/name`, **never** by folder.
  - *Orchestrators* are invoked by the user (`/dev`, `/map`, `/orchestrate`).
  - *Universal phase skills* are invoked **by name by an orchestrator**, so each
    description states the pipeline it belongs to — that guard is what stops
    single-word skills (`plan`, `code`, `test`) auto-firing on a stray keyword.
  - *Tech skills* **are** meant to match by description whenever their tech is
    in play; their names are verb-first (`write-svelte-component`).
- **Rules** — always-on constraints, `rules/<name>.md`, short and
  frontmatter-light. No selection step. If it must hold even when nothing was
  invoked, it's a rule. `domain: universal` rules are always on; `domain: <tech>`
  rules are on whenever that tech is in play. Skills name what they need in
  `rules:` frontmatter.
- **Hooks** — deterministic mechanical enforcement (shell, no model judgment).
  Skill-scoped hooks wire via a skill's/agent's `hooks:` frontmatter and run
  only while that skill is active (`workflow-diff-check.sh`); global quality
  hooks wire via `settings.json` (`smart-lint.sh`, `smart-test.sh`). Helper
  scripts (`workflow-setup.sh`, `resolve-config.sh`) sit in hook dirs to share
  the `~/.claude/hooks/` install path but are invoked explicitly, never wired.

Litmus: *"must always hold"* → rule. *"how to do a job"* → skill. *"must happen
every time, mechanically"* → hook.

Guides: [`orchestrators/AGENTS.md`](orchestrators/AGENTS.md) (the dev pipeline),
[`generic/AGENTS.md`](generic/AGENTS.md) (the global layer),
[`tool-based/AGENTS.md`](tool-based/AGENTS.md) (the tech layers).
