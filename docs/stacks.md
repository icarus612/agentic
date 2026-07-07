# Stack layers

`agents/stacks/<tech>/` is the third composition layer — tech-specific
conventions that apply on top of the universal rules and whichever workflow is
in play (see [`architecture.md`](architecture.md#2-layered-scope)). Each stack
directory follows the same shape:

```
stacks/<tech>/
├── AGENTS.md         # stack guide (currently a stub for every stack)
└── skills/.gitkeep   # placeholder — no stack skills authored yet
```

## Status: all placeholders

Every one of the 10 stack `AGENTS.md` files currently contains the literal
same stub — verified by reading each file:

```markdown
# <Stack> — stack instructions

Conventions, tooling, and defaults for any <stack> project.

_TODO: add conventions for this stack._
```

| Stack | Path | Status |
|---|---|---|
| Bash | `agents/stacks/bash/` | stub |
| Git | `agents/stacks/git/` | stub |
| Go | `agents/stacks/go/` | stub |
| JavaScript / Node (generic) | `agents/stacks/javascript/node/generic/` | stub |
| JavaScript / React | `agents/stacks/javascript/react/` | stub |
| JavaScript / Styles | `agents/stacks/javascript/styles/` | stub |
| JavaScript / Svelte | `agents/stacks/javascript/svelte/` | stub |
| Python (generic) | `agents/stacks/python/generic/` | stub |
| Python / Django | `agents/stacks/python/django/` | stub |
| Python / FastAPI | `agents/stacks/python/fastapi/` | stub |

No `skills/<name>/SKILL.md` exists under any stack yet — only the empty
`skills/.gitkeep` placeholder, so there are no stack-specific skills to select
by `description` at this time.

## Why they're listed as example ecosystems, not commitments

The stack names above (Python/Django/FastAPI, JavaScript/Node/React/Svelte/
Tailwind-family styles, Go, Bash, Git) are placeholder categories the repo has
already scaffolded folders for — they are not evidence any of them is
prioritized or "the" supported stack list. Per the `tech-agnostic` universal
rule (`agents/rules/tech-agnostic.md`), any technology named in a skill body is
illustrative only; real stack conventions belong exclusively in
`agents/stacks/<tech>/` once written.

## Adding real content to a stack

Per the contribution convention (`agents/README.md`, summarized in
[`conventions.md`](conventions.md#contribution-convention)): fill in the
stack's `AGENTS.md` with real conventions/tooling defaults, and add
`skills/<name>/SKILL.md` files with `type: stack`, `domain: <tech>` frontmatter
as needed — into `agents/stacks/<tech>/` directly, never into `tools/`.
