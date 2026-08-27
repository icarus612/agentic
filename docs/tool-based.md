# Tech layers (`tool-based/`)

`tool-based/<tech>/` holds everything bound to one technology or service —
`domain: <tech>` on every skill and rule inside it. These install at **project
level** (the consuming project's `.claude/` or `.agent/`), because a project
ships with the tech it actually uses. Which layers a project loads is
discovered from its real manifests and lockfiles, never assumed
(`tech-agnostic`).

One directory per tech; the tech *is* the unit. There is no language grouping —
a project uses Svelte and Tailwind and TypeScript, not "javascript".

```
tool-based/<tech>/
├── AGENTS.md      # the tech's conventions, tooling, defaults
├── rules/         # always-on while this tech is in play  (domain: <tech>)
├── skills/        # on-demand procedures                  (domain: <tech>)
├── hooks/         # tech-specific hooks, if any
└── ci/            # shipped CI templates/references for consuming projects
```

## Status

Seven layers have real content; six are placeholder stubs (an `AGENTS.md`
containing only a `_TODO` line):

| Tech | Status | Rules | Skills |
|---|---|---|---|
| `svelte` | **real** | `use-runes`, `accessibility`, `component-testing` | `write-svelte-component`, `create-sveltekit-route`, `write-component-test`, `add-seo-metadata` |
| `tailwind` | **real** | `mobile-first`, `animation-performance` | `style-with-tailwind`, `build-responsive-layout` |
| `typescript` | **real** | `typescript-strict`, `code-quality` | `type-safely` |
| `django` | **real** | `django-conventions`, `security` | `create-django-resource` |
| `godot` | **real** | `gdscript-standards` | `generate-hex-neighbors`, `run-godot-test` |
| `medusa` | **real** | — | `medusa-api` |
| `confluence` | **real** | `external-storage-cap` | `document-confluence` |
| `bash` | stub | — | — |
| `git` | stub | — | — |
| `go` | stub | — | — |
| `react` | stub | — | — |
| `python` | stub | — | — |
| `fastapi` | stub | — | — |

`confluence` is the one layer bound to a *service* rather than a language:
`document-confluence` is a manual/recovery sync, run standalone by a human,
that mirrors the local docs tree to Confluence when the CI publish job hasn't
run, has failed, or a target is being backfilled — never a documentation
phase, never a source of truth — offloading large artifacts to Google Drive
via the Atlassian and Drive MCP servers.

## Naming

Tech skills are verb-first imperatives (`write-svelte-component`,
`run-godot-test`, `type-safely`). Unlike the universal phase skills, they *are*
meant to be matched by description whenever their tech is in play, so their
names and descriptions lead with the action and carry no workflow guard.

## Stubs are examples, not commitments

The stub names are placeholder categories the repo has scaffolded folders for —
not evidence any of them is prioritized or "the" supported stack list. Per
`tech-agnostic`, any technology named in a universal skill body is illustrative
only; real tech conventions live exclusively in a `domain: <tech>` layer.

## Adding a layer

Create `tool-based/<tech>/`, fill its `AGENTS.md` with real conventions, add
`rules/<name>.md` and `skills/<name>/SKILL.md` — each declaring
`domain: <tech>`, the single field that survives the flat install and marks the
skill as project-level.
