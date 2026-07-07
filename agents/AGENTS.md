# Agent instructions (universal)

The index for this layer. Universal rules apply to **every** project, workflow,
and stack; workflow and stack layers add to them, they never replace them.

## Library layout

```
agents/
├── AGENTS.md              ← this file: index + pointers
├── rules/                 ← universal rules (type: rule, domain: universal)
├── workflows/<wf>/        ← process skills + rules (type: workflow)
│   ├── AGENTS.md          ← that workflow's guide
│   ├── rules/             ← workflow-scoped rules
│   └── skills/
└── stacks/<tech>/         ← stack skills + rules (type: stack)
    ├── AGENTS.md
    └── skills/
```

Each skill is a `skills/<name>/SKILL.md` with frontmatter. `type:` is **workflow**
or **stack**; `domain:` is the subcategory (`dev`, `delivery`, `python`, …). A
skill is selected by its `description` (or an explicit `/name`) — folders are for
composition and maintenance, not selection.

Workflows:
- **`dev`** — explore → plan → review → build → review → document. See
  [`workflows/dev/AGENTS.md`](workflows/dev/AGENTS.md).
- **`delivery`** — wraps `dev` with Jira/Confluence/Drive project documentation
  (pre: requirements, post: publish + link). See
  [`workflows/delivery/AGENTS.md`](workflows/delivery/AGENTS.md).

## Rules

Behavioral rules are individual files (`type: rule`) loaded as **always-on
context**. Each declares its scope via `domain`:

- **Universal** ([`rules/`](rules/)) — apply everywhere: `verify-dont-assume`,
  `respect-versions-and-conventions`, `push-policy`, `model-policy`,
  `tech-agnostic`, plus the artifact conventions `artifact-locations`,
  `doc-format`, `plan-format` (where docs/plans/worktrees live and how they
  are named and structured).
- **Workflow-scoped** — live with their workflow and apply when it is in play:
  [`workflows/delivery/rules/`](workflows/delivery/rules/) (`external-storage-cap`).
  The dev workflow currently has none — its conventions are universal.

Each skill names the rules it depends on in its `rules:` frontmatter field, so a
tool can load them alongside the skill — universal rules are on regardless.
