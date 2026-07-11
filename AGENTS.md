# Agent instructions (universal)

The index for this layer. Universal rules apply to **every** project, workflow,
and stack; workflow and stack layers add to them, they never replace them.

## Library layout

```
agentic/
├── AGENTS.md                  ← this file: index + pointers
├── rules/                     ← universal rules (type: rule, domain: universal)
├── hooks/                     ← generic quality hooks (smart-lint, smart-test, …)
└── skills/
    ├── workflows/<wf>/        ← process skills + rules (type: workflow)
    │   ├── AGENTS.md          ← that workflow's guide
    │   ├── rules/             ← workflow-scoped rules
    │   ├── agents/            ← sub-agent definitions
    │   ├── hooks/             ← workflow hook/helper scripts
    │   └── skills/
    ├── stacks/<tech>/         ← stack skills + rules (type: stack)
    │   ├── AGENTS.md
    │   ├── rules/
    │   └── skills/
    └── singletons/            ← standalone skills, no workflow/stack (type: singleton)
        ├── AGENTS.md
        └── <name>/SKILL.md
```

Each skill is a `skills/<name>/SKILL.md` with frontmatter. `type:` is
**workflow**, **stack**, or **singleton**; `domain:` is the subcategory (`dev`,
`python`, `singleton`, …). A skill is selected by its `description` (or an
explicit `/name`) — folders are for composition and maintenance, not selection.
Entry-point orchestrators are user-invoked (`/dev`, `/map`); phase skills are
invoked by name by an orchestrator, and their descriptions say so.

Workflows:
- **`dev`** — explore → plan → review → build → review → document → PR. Two
  entry points: `/dev` (full pipeline) and `/map` (documentation-only runs).
  The documentation phase dispatches on `CLAUDE_DOCS_DIR`: local docs via
  `document-local`, or Confluence publishing (story pages, changelog, Jira
  links) via `document-confluence`. See
  [`skills/workflows/dev/AGENTS.md`](skills/workflows/dev/AGENTS.md).

Singletons ([`skills/singletons/`](skills/singletons/)) are standalone skills
that belong to neither a workflow nor a stack — currently **`orchestrate`**, a
generic task coordinator.

## Rules

Behavioral rules are individual files (`type: rule`) loaded as **always-on
context**. Each declares its scope via `domain`:

- **Universal** ([`rules/`](rules/)) — apply everywhere: `verify-dont-assume`,
  `respect-versions-and-conventions`, `push-policy`, `model-policy`,
  `tech-agnostic`, plus the artifact conventions `artifact-locations`,
  `doc-format`, `plan-format` (where docs/plans/worktrees live and how they
  are named and structured).
- **Workflow-scoped** — live with their workflow and apply when it is in play:
  [`skills/workflows/dev/rules/`](skills/workflows/dev/rules/)
  (`external-storage-cap`, used by `document-confluence`).
- **Stack-scoped** — live with their stack under
  `skills/stacks/<tech>/rules/` and apply when that tech is in play.

Each skill names the rules it depends on in its `rules:` frontmatter field, so a
tool can load them alongside the skill — universal rules are on regardless.

## Hooks

Hooks are deterministic, mechanical enforcement — shell scripts, no model
judgment. Two wirings: **skill-scoped** hooks via a skill's or agent's `hooks:`
frontmatter (active only while that skill runs, e.g. `workflow-diff-check.sh`
on the `dev` skill and `builder` agent), and **global quality** hooks via
`settings.json` ([`hooks/`](hooks/): `smart-lint.sh`, `smart-test.sh`, …).
Helper scripts like `workflow-setup.sh` ride along in hook directories to share
the `~/.claude/hooks/` install path but are invoked explicitly by skills, never
wired as hooks.
