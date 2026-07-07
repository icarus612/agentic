# Conventions

The authoritative spec for these formats lives in
[`agents/README.md`](../agents/README.md) and [`agents/AGENTS.md`](../agents/AGENTS.md)
— this page summarizes them for anyone navigating the repo without immediately
opening the payload files, and adds the meta-conventions (docs, contributing)
that apply to the repo itself.

## Skill file format

One skill per directory: `skills/<name>/SKILL.md`, YAML frontmatter followed by
a body with a fixed section order.

```markdown
---
name: <kebab-name>
description: <when to use this — the agent matches the task against THIS line>
type: <workflow|stack>
domain: <dev|delivery|python|…>          # the subcategory; mirrors the folder
rules: [<rule-name>, …]                  # the rules this skill depends on
model: <opus|sonnet|haiku>               # primary model the skill runs on
model-fallback: [<next>, …]              # ordered backups for tools that support them
---

# <name>
<intro paragraph>

## When to use
## Inputs            (fork skills only)
## How it works       (numbered steps)
## Hand-off / next
## Notes
```

A skill's body is loaded on demand — the model reads `description` to decide
whether to pull it in, which is why the description has to earn its tokens.

## Rule file format

One rule per file: `rules/<name>.md`. Rules are always-on context, so they
stay short and frontmatter-light — no `model`, no selection step.

```markdown
---
name: <kebab-name>
description: <one-line summary, for humans + adapters>
type: rule
domain: <universal|dev|delivery|…>       # mirrors the folder
---

# <Rule title>
<the rule, in a sentence or two>
```

The 8 universal rules (`agents/rules/`): `artifact-locations`, `doc-format`,
`model-policy`, `plan-format`, `push-policy`, `respect-versions-and-conventions`,
`tech-agnostic`, `verify-dont-assume`. One workflow-scoped rule exists today:
`agents/workflows/delivery/rules/external-storage-cap.md`. The `dev` workflow
has no rules of its own — its conventions are the universal set.

## Type, domain, and folders

`type:` is `workflow`, `stack`, or `rule`; `domain:` mirrors the folder
(`workflows/dev` → `domain: dev`, `stacks/python` → `domain: python`,
`rules/` → `domain: universal`). A skill is never selected by its folder —
folders exist purely for composition (what a consumer copies into a project)
and maintenance.

## Model policy

Every skill declares `model:` (the primary) plus an ordered
`model-fallback:` ending in `gemini-pro` (the cross-vendor backstop):

- **Orchestration/planning** skills (`dev-start`, `dev-plan`, `delivery-start`)
  → `opus → sonnet → gemini-pro`.
- **Everything else** → `sonnet → gemini-pro`.

This chain is declarative intent — each tool honors as much of it as it can.
Claude Code (the only fully-wired adapter today) reads just the single
`model:` value and ignores `model-fallback:` entirely; it has no Gemini path.
A Gemini-capable tool or multi-provider router would walk the full chain.
Full policy: [`agents/rules/model-policy.md`](../agents/rules/model-policy.md).

## Artifact locations (for consuming projects)

Defined by `agents/rules/artifact-locations.md`, and load-bearing for how
`dev-document`/`dev-map` behave in any project that adopts this library:

| Artifact | Default location | Override env var |
|---|---|---|
| Technical docs | root `/docs` | `CLAUDE_DOCS_DIR` |
| Implementation plans | root `/project-plans/` | `CLAUDE_PROJECT_PLANS_DIR` |
| Workflow worktrees | root `.workflows/` (gitignored, branch `<type>/<name>`) | `CLAUDE_WORKFLOWS_DIR` |

Override env vars are only ever set in a project's own `.claude/settings.json`
`env` block — never in the global `~/.claude/settings.json`. This repo has no
`.claude/settings.json`, so this `/docs` tree uses the plain defaults.

## Doc format (how this `/docs` tree itself is kept)

Per `agents/rules/doc-format.md`: `/docs` mirrors the source tree; every
nested in-project doc path and README is normally a **symlink** into `/docs`,
never a copy; `README.md` is the entry point of each directory, other files
are lowercase kebab-case; one page per topic, updated in place rather than
duplicated. See [`README.md`](README.md#why-docs-is-separate-from-agents) for
why this repo currently has no symlinks to create — its README/AGENTS.md
files are library payload, not docs-about-the-repo.

## Plan format (for consuming projects)

Defined by `agents/rules/plan-format.md`: filename
`<feature-slug>-MM-DD-YY.md`; phase syllabus first (one checkbox per phase);
required sections — goal & scope, stack & MAJOR versions (with the
manifest/lockfile each was verified from), conventions to enforce, phased
tasks numbered `<phase>.<task>`, risks/open questions/decision points, skill
mapping; living document (syllabus checked off as phases complete); never
includes time estimates.

## Contribution convention

From `agents/README.md` and the root `README.md`:

- Add new content to **`agents/` first** — a process under `workflows/<wf>/`,
  a tech under `stacks/<tech>/`, universal rules in `agents/rules/`. Only
  touch `tools/` when a tool needs new *wiring*, never to store content.
- Every skill must declare `description`, `type` + `domain`, `model` +
  `model-fallback`, and `rules:`.
- Keep rules short and frontmatter-light — they're always-on context.
- Distribution is deliberately **copy-paste**, not symlinks or a setup
  script, so it behaves identically on Linux, macOS, and Windows with zero
  tooling.
