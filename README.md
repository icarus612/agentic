# agentic

A **library** of AI-agent skills, rules, and hooks — a single source of truth
you install into Claude Code. It is **not** a project you run. Nothing here
executes; you copy pieces of it to where the tool expects them.

## The one question

Everything is classified by **what it is bound to** — and that answer also
decides where it installs:

| `domain:` | Bound to | Installs to |
|---|---|---|
| `universal` | nothing — works on any project, any stack | **user level**: `~/.claude/` (or `.agent/`) |
| `<tech>` (`svelte`, `django`, `confluence`, …) | one technology or service | **project level**: that project's `.claude/` / `.agent/` |

`domain:` is the only classifier, and it's the only one that survives: the
install target is flat (`skills/<name>/SKILL.md`), so this repo's folders
vanish. Nothing inside a skill or rule may reference this repo's layout.

## Directory map

```
agentic/
├── AGENTS.md                  # the index — read this first
├── orchestrators/             # ENTRY POINTS the user invokes        (domain: universal)
│   ├── skills/                #   dev (/dev), map (/map), orchestrate (/orchestrate)
│   ├── hooks/                 #   workflow-setup.sh, workflow-diff-check.sh, resolve-config.sh
│   └── agents/                #   builder.md — the build-loop sub-agent
├── generic/                   # GLOBAL: bound to no technology       (domain: universal)
│   ├── rules/                 #   the always-on set
│   ├── skills/                #   explore, plan, code, debug, test, review-*, document-local, push-pr, …
│   └── hooks/                 #   smart-lint.sh, smart-test.sh, … (wired via settings.json)
├── tool-based/                # bound to ONE technology              (domain: <tech>)
│   └── <tech>/                #   svelte, tailwind, typescript, django, godot, confluence, …
│       ├── rules/
│       └── skills/
└── docs/                      # meta-docs about this repo itself
```

## The dev pipeline

`/dev` orchestrates the whole thing; every phase is a universal skill it
invokes by name:

```
explore → init-workspace → plan → review-plan ⇄ (gate)
   → code ⇄ debug ⇄ test → review-code ⇄ (gate)
   → document-local | document-confluence → push-pr (⇢ review-pr)
```

Only `test` can break the build loop. Both gates can loop back to any earlier
phase. `/map` runs the documentation-only variant. Details:
[`orchestrators/AGENTS.md`](orchestrators/AGENTS.md).

## Skills, rules, hooks

- **Skills** — on-demand procedures. Selected by `description` or an explicit
  `/name`, never by folder. Universal *phase* skills are invoked by name by an
  orchestrator, so their descriptions say so — that guard is what stops
  single-word skills (`plan`, `code`, `test`) auto-firing on a stray keyword.
  Tech skills *are* meant to match whenever their tech is in play.
- **Rules** — always-on constraints. Short, no procedure. If it must hold even
  when nothing was invoked, it's a rule.
- **Hooks** — deterministic mechanical enforcement (shell, no model judgment).
  Skill-scoped hooks wire via a skill's `hooks:` frontmatter; global quality
  hooks wire via `settings.json`.

Litmus: *"must always hold"* → rule. *"how to do a job"* → skill. *"must happen
every time, mechanically"* → hook.

## Install

1. Copy `orchestrators/skills/*` and `generic/skills/*` into `~/.claude/skills/`,
   `orchestrators/agents/builder.md` into `~/.claude/agents/`, and
   `generic/rules/*` into your `CLAUDE.md` context.
2. Copy each `tool-based/<tech>/` layer your project uses into that **project's**
   `.claude/` (or `.agent/`).
3. Hooks (`generic/hooks/`, `orchestrators/hooks/`) go to `~/.claude/hooks/` —
   automated by Nix home-manager in this setup; copy them manually otherwise.

Distribution is deliberately copy-paste, not symlinks or a setup script, so it
behaves identically across platforms with zero tooling.

## Contributing

- Edit **here first**, never in `~/.claude/` — that's an install, not the source.
- A skill is bound to nothing (`domain: universal`, goes in `orchestrators/` or
  `generic/`) or to exactly one tech (`domain: <tech>`, goes in
  `tool-based/<tech>/`). There is no third option.
- Every skill declares `description`, `domain`, `model` + `model-fallback`, and
  the `rules:` it depends on.
- Keep rules short — they're always-on context.
- Never let a skill or rule reference this repo's directory layout.
