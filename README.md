# agentic

A **library** of AI-agent instructions and skills — a single source of truth you
copy into your projects. It is **not** a project you run. Nothing here executes;
you take pieces from it and drop them where a given tool expects them.

## Two principles

### 1. Generic source of truth, thin tool adapters

All real content is **tool-agnostic** and lives in [`agents/`](agents/). Each AI
tool gets a small **adapter** under [`tools/<tool>/`](tools/) that only explains
*where that tool expects the files*. Adapters never duplicate content — they point
back at `agents/`.

```
agents/   ← canonical, generic content (edit here)
tools/    ← per-tool wiring instructions (claude, gemini, antigravity)
```

### 2. Layered scope

Content composes in layers, broadest to narrowest:

```
universal  ⊕  workflow(s)  ⊕  stack(s)  ⊕  project
```

- **universal** — applies everywhere (`agents/AGENTS.md`, `agents/rules/`)
- **workflow** — a process you run (`agents/workflows/dev`, `…/delivery`)
- **stack** — applies to a tech (`agents/stacks/python/…`, `…/javascript/react`)
- **project** — applies to one repo; **lives in that repo**, not here

To set up a project you pull in the universal rules + the workflow(s) and stack(s)
you need, then add project-specific instructions locally.

## Directory map

```
agentic/
├── agents/                          # GENERIC source of truth — edit here
│   ├── AGENTS.md                    # universal index + pointers
│   ├── rules/                       # universal rules (type: rule)
│   ├── workflows/                   # process skills + rules (type: workflow)
│   │   ├── dev/                     # build pipeline
│   │   │   ├── AGENTS.md
│   │   │   ├── rules/               # dev-scoped rules
│   │   │   └── skills/  → dev-start orchestrates:
│   │   │                 explore → plan → plan-review → code/debug/test → code-review → document
│   │   └── delivery/                # Jira / Confluence / Drive docs
│   │       ├── AGENTS.md
│   │       ├── rules/               # delivery-scoped rules
│   │       ├── shared/skills/  → delivery-start, delivery-connect, delivery-drive-archive
│   │       ├── pre/skills/     → delivery-pre-requirements
│   │       └── post/skills/    → delivery-post-confluence, -changelog, -jira-link
│   └── stacks/                      # tech-specific layers (type: stack)
│       ├── python/{generic,fastapi,django}/
│       ├── javascript/{node/generic,react,svelte,styles}/
│       └── go/  bash/  git/
└── tools/                           # THIN adapters (how each tool consumes agents/)
    └── claude/  gemini/  antigravity/
```

## Skills, rules, and folders

Three content kinds, each declaring a `type`:

- **`type: workflow` / `type: stack` skills** — a `skills/<name>/SKILL.md` with
  full frontmatter. Selected by the model via its `description` (or an explicit
  `/name`), so the body is loaded on demand.
- **`type: rule` rules** — a short `rules/<name>.md`, loaded as **always-on
  context** (no selection step). Each skill names the rules it needs in its
  `rules:` frontmatter so a tool can load them alongside the skill.

An agent selects a skill by `description`, **not** by folder — folders exist for
**composition** (what you copy into a project) and **maintenance**. Workflows
group by *process* (and cycle: `pre/`, `post/`, `shared/`); stacks group by
*tech* (the hard relevance gate). The `domain` field mirrors the folder.

See [`agents/README.md`](agents/README.md) for the exact skill and rule formats.

## Usage (copy-paste)

1. Clone or download this repo.
2. Copy `agents/AGENTS.md` + the universal `agents/rules/`, plus the
   `workflows/<wf>/` and `stacks/<tech>/` (`AGENTS.md`, `rules/`, `skills/`) you
   need, into your project / your tool's locations.
3. Copy the skill directories you want into your tool's skills location.
4. Follow the matching [`tools/<tool>/README.md`](tools/) for exact paths.

Copy-paste is intentional — chosen over symlinks or a setup script so it behaves
identically on Linux, macOS, and Windows with zero tooling.

## Contributing

- Add content to **`agents/` first** — a process under `workflows/<wf>/`, a tech
  under `stacks/<tech>/`, universal rules in `agents/rules/`.
- Give each skill a clear `description`, a `type` + `domain`, a `model` +
  `model-fallback`, and a `rules:` list of the rules it depends on.
- Keep rules short and frontmatter-light (they're always-on context).
- Only touch `tools/` when a tool needs new *wiring* — never to store content.
