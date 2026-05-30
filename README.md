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
global  ⊕  stack(s)  ⊕  project
```

- **global** — applies everywhere (`agents/global/AGENTS.md`, `agents/global/skills/`)
- **stack** — applies to a tech (`agents/stacks/python/…`, `…/javascript/react/…`)
- **project** — applies to one repo; **lives in that repo**, not here

To set up a project you pull in `global` + the relevant `stack(s)`, then add
project-specific instructions locally.

## Directory map

```
agentic/
├── agents/                      # GENERIC source of truth — edit here
│   ├── global/                  # global scope (applies everywhere)
│   │   ├── AGENTS.md            # global instructions (every project)
│   │   └── skills/              # global, tech-agnostic workflow skills
│   └── stacks/                  # tech-specific layers
│       ├── python/{generic,fastapi,django}/
│       ├── javascript/
│       │   ├── node/generic/
│       │   ├── react/  svelte/  styles/
│       ├── go/   bash/   git/
│       └── …                    # each leaf: AGENTS.md + skills/
└── tools/                       # THIN adapters (how each tool consumes agents/)
    ├── claude/      gemini/      antigravity/
```

Each stack leaf holds its own `AGENTS.md` (stack instructions) and a `skills/`
dir. Multi-variant techs (python, javascript) are grouping folders; single techs
(go, bash, git) are leaves directly.

## Why tech is the folder axis, domain is a tag

An agent doesn't choose a skill by its folder — it matches the skill's
`description` frontmatter (or you invoke it by name). So folders exist for
**composition** (what you copy into a project) and **human maintenance**, while
frontmatter drives **agent selection** and **browsing**.

Tech is the hard relevance gate — `pytest` is useless in a Go repo — so tech is
the folder. The conceptual grouping you'd browse by (testing, deploy, lint) lives
in a `domain:` frontmatter tag. You get both without ever choosing between them.
See [`agents/README.md`](agents/README.md) for the skill format.

## Usage (copy-paste)

1. Clone or download this repo.
2. Copy `agents/global/AGENTS.md` (plus any `agents/stacks/<tech>/AGENTS.md` you
   need) into your project's instruction file.
3. Copy the `skills/` you want into your tool's skills location.
4. Follow the matching [`tools/<tool>/README.md`](tools/) for exact paths.

Copy-paste is intentional — chosen over symlinks or a setup script so it behaves
identically on Linux, macOS, and Windows with zero tooling.

## Contributing

- Add content to **`agents/` first** — global if it's universal, otherwise the
  right `stacks/<tech>/`.
- Give each skill a clear `description` (what the agent matches on) and an
  optional `domain:` tag.
- Only touch `tools/` when a tool needs new *wiring* — never to store content.
