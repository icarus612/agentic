# Stack layers

`skills/stacks/<tech>/` is the third composition layer — tech-specific
conventions that apply on top of the universal rules and whichever workflow is
in play (see [`architecture.md`](architecture.md#2-layered-scope)). Each stack
directory follows the same shape:

```
skills/stacks/<tech>/
├── AGENTS.md         # stack guide (conventions, tooling, defaults)
├── rules/            # stack-scoped always-on rules (type: rule, domain: <tech>)
└── skills/           # stack skills (type: stack, domain: <tech>)
```

## Status

Five stacks have real content; six are still placeholder stubs (an `AGENTS.md`
containing only a `_TODO` line):

| Stack | Path | Status | Rules | Skills |
|---|---|---|---|---|
| Godot | `skills/stacks/godot/` | **real** | `gdscript-standards` | `generate-hex-neighbors`, `run-godot-test` |
| JavaScript / Node (generic) | `skills/stacks/javascript/node/generic/` | **real** | `code-quality`, `typescript-strict` | `type-safely` |
| JavaScript / Styles | `skills/stacks/javascript/styles/` | **real** | `animation-performance`, `mobile-first` | `build-responsive-layout`, `style-with-tailwind` |
| JavaScript / Svelte | `skills/stacks/javascript/svelte/` | **real** | `accessibility`, `component-testing`, `use-runes` | `add-seo-metadata`, `create-sveltekit-route`, `write-component-test`, `write-svelte-component` |
| Python / Django | `skills/stacks/python/django/` | **real** | `django-conventions`, `security` | `create-django-resource` |
| Bash | `skills/stacks/bash/` | stub | — | — |
| Git | `skills/stacks/git/` | stub | — | — |
| Go | `skills/stacks/go/` | stub | — | — |
| JavaScript / React | `skills/stacks/javascript/react/` | stub | — | — |
| Python (generic) | `skills/stacks/python/generic/` | stub | — | — |
| Python / FastAPI | `skills/stacks/python/fastapi/` | stub | — | — |

## Naming

Stack skills are verb-first imperatives (`write-svelte-component`,
`type-safely`, `run-godot-test`) — unlike dev workflow phase skills, they are
meant to be matched by description whenever their tech is in play, so their
names and descriptions lead with the action.

## Why stubs are listed as example ecosystems, not commitments

The stub stack names are placeholder categories the repo has scaffolded
folders for — they are not evidence any of them is prioritized or "the"
supported stack list. Per the `tech-agnostic` universal rule
(`rules/tech-agnostic.md`), any technology named in a skill body is
illustrative only; real stack conventions belong exclusively in
`skills/stacks/<tech>/` once written.

## Adding real content to a stack

Per the contribution convention
([`conventions.md`](conventions.md#contribution-convention)): fill in the
stack's `AGENTS.md` with real conventions/tooling defaults, add
`rules/<name>.md` files for always-on constraints, and add
`skills/<name>/SKILL.md` files with `type: stack`, `domain: <tech>`
frontmatter as needed — into `skills/stacks/<tech>/` directly.
