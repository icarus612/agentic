# Tool-based — the tech layers (`domain: <tech>`)

Everything bound to a **specific technology or service**. This is where the
`tech-agnostic` rule sends all stack-specific knowledge, so the universal layer
can stay clean.

These install at **project level** — the consuming project's `.claude/` or
`.agent/` — because a project ships with the tech it actually uses. Which
layers a project loads is discovered from its real manifests and lockfiles,
never assumed.

One directory per tech; the tech *is* the unit. No language grouping — a
project uses Svelte and Tailwind and TypeScript, not "javascript".

```
tool-based/<tech>/
├── AGENTS.md      # the tech's conventions, tooling, defaults
├── rules/         # always-on while this tech is in play  (domain: <tech>)
├── skills/        # on-demand procedures                  (domain: <tech>)
└── hooks/         # tech-specific hooks, if any
```

## Layers with real content

| Tech | Rules | Skills |
|---|---|---|
| **`svelte`** | `use-runes`, `accessibility`, `component-testing`, `server-boundaries` | `write-svelte-component`, `create-sveltekit-route`, `write-component-test`, `add-seo-metadata` |
| **`tailwind`** | `mobile-first`, `animation-performance` | `style-with-tailwind`, `build-responsive-layout` |
| **`typescript`** | `typescript-strict`, `code-quality` | `type-safely` |
| **`django`** | `django-conventions`, `security` | `create-django-resource` |
| **`godot`** | `gdscript-standards` | `generate-hex-neighbors`, `run-godot-test` |
| **`medusa`** | — | `medusa-api` — MedusaJS 2.x storefront integration (products, cart, checkout, auth) |
| **`confluence`** | `external-storage-cap` | `document-confluence` — the documentation phase when the docs target is a Confluence location: publishes the story + technical page and the changelog, links Jira bidirectionally, offloads large artifacts to Google Drive. Drives the Atlassian + Google Drive MCP servers. |

## Stubs (scaffolded, unwritten)

`bash`, `git`, `go`, `react`, `python`, `fastapi` — an `AGENTS.md` placeholder
and nothing else. They are example ecosystems the repo has folders for, **not**
a commitment or a supported-stack list.

## Adding a tech layer

Create `tool-based/<tech>/`, fill its `AGENTS.md` with real conventions, add
`rules/<name>.md` and `skills/<name>/SKILL.md`, each declaring
`domain: <tech>` — the single field that survives the flat install and marks
the skill as project-level. Skill names are verb-first imperatives
(`write-svelte-component`, `run-godot-test`): unlike universal phase skills,
these *are* meant to match by description whenever their tech is in play, so
they need no workflow guard.
