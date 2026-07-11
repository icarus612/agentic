# Conventions

This page is the authoritative spec for the library's file formats, plus the
meta-conventions (docs, contributing) that apply to the repo itself. The root
[`AGENTS.md`](../AGENTS.md) carries the short index version that ships as
payload.

## Skill file format

One skill per directory: `skills/<name>/SKILL.md`, YAML frontmatter followed by
a body with a fixed section order.

```markdown
---
name: <kebab-name>
description: <when to use this — the agent matches the task against THIS line>
type: <workflow|stack|singleton>
domain: <dev|python|singleton|…>         # the subcategory; mirrors the folder
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
Two description conventions are load-bearing:

- **Entry-point orchestrators** (`dev`, `map`, `orchestrate`) say how to invoke
  them (`/dev`, `/map`) — they are the user-facing surface.
- **Phase skills** state the workflow they belong to and who invokes them
  ("Part of the dev workflow, invoked by the dev orchestrator…"). Several are
  single words (`plan`, `code`, `test`, `debug`, `explore`); this guard is what
  keeps them from auto-firing on incidental keyword matches in the flat
  `~/.claude/skills/` namespace.

Optional frontmatter: `context: fork` (runs in an isolated subagent; inputs
arrive via invocation args only), `agent:` (a specific agent type for the
fork), `hooks:` (skill-scoped hook wiring, e.g. the `Stop` hook on `dev`).

## Rule file format

One rule per file: `rules/<name>.md`. Rules are always-on context, so they
stay short and frontmatter-light — no `model`, no selection step.

```markdown
---
name: <kebab-name>
description: <one-line summary, for humans + adapters>
type: rule
domain: <universal|dev|svelte|…>         # mirrors the folder
---

# <Rule title>
<the rule, in a sentence or two>
```

The 8 universal rules (`rules/`): `artifact-locations`, `doc-format`,
`model-policy`, `plan-format`, `push-policy`, `respect-versions-and-conventions`,
`tech-agnostic`, `verify-dont-assume`. Workflow-scoped:
`skills/workflows/dev/rules/external-storage-cap.md` (used by
`document-confluence`). Stack-scoped rules live under
`skills/stacks/<tech>/rules/` (e.g. svelte's `use-runes`, node's
`typescript-strict`).

## Type, domain, and folders

`type:` is `workflow`, `stack`, `singleton`, or `rule`; `domain:` mirrors the
folder (`skills/workflows/dev` → `domain: dev`, `skills/stacks/python` →
`domain: python`, `rules/` → `domain: universal`). A skill is never selected by
its folder — folders exist purely for composition (what a consumer copies into
a project) and maintenance.

## Model policy

Every skill declares `model:` (the primary) plus an ordered
`model-fallback:` ending in `gemini-pro` (the cross-vendor backstop):

- **Orchestration/planning** skills (`dev`, `map`, `plan`, `orchestrate`)
  → `opus → sonnet → gemini-pro`.
- **Everything else** → `sonnet → gemini-pro`.

This chain is declarative intent — each tool honors as much of it as it can.
Claude Code (the only wired tool today) reads just the single `model:` value
and ignores `model-fallback:` entirely; it has no Gemini path. A
Gemini-capable tool or multi-provider router would walk the full chain.
Full policy: [`rules/model-policy.md`](../rules/model-policy.md).

## Artifact locations (for consuming projects)

Defined by `rules/artifact-locations.md`, and load-bearing for how the
documentation phase behaves in any project that adopts this library:

| Artifact | Default | Override env var |
|---|---|---|
| Docs | root `/docs` | `CLAUDE_DOCS_DIR` — a path keeps docs local (`document-local`); an Atlassian wiki URL or `confluence:SPACE[/Parent]` makes Confluence the docs source of truth (`document-confluence`) |
| Implementation plans | root `/project-plans/` | `CLAUDE_PROJECT_PLANS_DIR` |
| Workflow worktrees | root `.workflows/` (gitignored, branch `<type>/<name>`) | `CLAUDE_WORKFLOWS_DIR` |

Override env vars are only ever set in a project's own `.claude/settings.json`
`env` block — never in the global `~/.claude/settings.json`. This repo has no
`.claude/settings.json`, so this `/docs` tree uses the plain defaults.

## Doc format (how this `/docs` tree itself is kept)

Per `rules/doc-format.md`: in local mode `/docs` mirrors the source tree; every
nested in-project doc path and README is normally a **symlink** into `/docs`,
never a copy; `README.md` is the entry point of each directory, other files
are lowercase kebab-case; one page per topic, updated in place rather than
duplicated. See [`README.md`](README.md#why-docs-is-separate-from-the-payload)
for why this repo currently has no symlinks to create — its README/AGENTS.md
files are library payload, not docs-about-the-repo.

## Plan format (for consuming projects)

Defined by `rules/plan-format.md`: filename `<feature-slug>-MM-DD-YY.md`;
phase syllabus first (one checkbox per phase); required sections — goal &
scope, stack & MAJOR versions (with the manifest/lockfile each was verified
from), conventions to enforce, phased tasks numbered `<phase>.<task>`,
risks/open questions/decision points, skill mapping; living document (syllabus
checked off as phases complete); never includes time estimates. In Confluence
mode the `dev` orchestrator also writes a sibling story file
(`<feature-slug>-MM-DD-YY.story.md`) capturing the verbatim ask, narrative,
acceptance criteria, and Jira keys.

## Contribution convention

- Edit content **in this repo first**, never in `~/.claude/` — installs are
  copies of this source of truth.
- A process goes under `skills/workflows/<wf>/`, a tech under
  `skills/stacks/<tech>/`, a standalone skill under `skills/singletons/`,
  universal rules in `rules/`.
- Every skill must declare `description`, `type` + `domain`, `model` +
  `model-fallback`, and `rules:`.
- Keep rules short and frontmatter-light — they're always-on context.
- Distribution is deliberately **copy-paste**, not symlinks or a setup
  script, so it behaves identically on Linux, macOS, and Windows with zero
  tooling. (Hooks are the one automated path: Nix home-manager installs them
  to `~/.claude/hooks/`.)
