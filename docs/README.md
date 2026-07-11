# agentic — docs

This is the root documentation for the `agentic` repo, maintained per this
library's own `doc-format` and `artifact-locations` rules
(`rules/doc-format.md`, `rules/artifact-locations.md`).

**Read this first if you want to know how the repo itself is put together.**
If you want the library's actual payload — the content you copy into your own
projects — that lives in [`../skills/`](../skills/), [`../rules/`](../rules/),
and [`../hooks/`](../hooks/), indexed by the root
[`AGENTS.md`](../AGENTS.md). This `/docs` tree does not duplicate that content;
it explains the repo around it.

## Why `/docs` is separate from the payload

`agentic` is unusual for a project using its own `doc-format` rule: the repo
**is** a content library, so some of its "source files" — the root
[`README.md`](../README.md), [`AGENTS.md`](../AGENTS.md), and the per-workflow
and per-stack `AGENTS.md` guides — are load-bearing **library payload**, not
documentation about the repo. They are copy-paste output: consumers paste them
into their own `CLAUDE.md`/skills folders, so their content and location are
fixed by the library's own conventions.

Because of that, those files are **not** symlinks into `/docs` — repointing
load-bearing payload paths would break the copy-paste contract the library
exists to serve. `/docs` instead holds *meta*-documentation: what the repo is,
how its pieces compose, and how a maintainer navigates and extends it. Where
`/docs` describes something that also has a canonical payload copy (e.g. the
dev pipeline), it links out to that file rather than repeating it.

There is currently nothing in the repo that duplicates content across two
locations, so there are no in-project doc symlinks to create or repair yet.

## Map

| Page | Covers |
|---|---|
| [`architecture.md`](architecture.md) | The layering model (universal ⊕ workflow ⊕ stack ⊕ project), directory structure, the skill/rule/hook separation principle, and the dependency/hand-off graph. |
| [`conventions.md`](conventions.md) | Skill and rule file formats (the authoritative spec), the model policy, artifact locations and the docs-target dispatch, and the contribution convention. |
| [`workflows/dev.md`](workflows/dev.md) | The `dev` build pipeline: explore → plan → review → build loop → review → document (local or Confluence) → PR, plus the `map` doc-only orchestrator. |
| [`stacks.md`](stacks.md) | Status of the tech-specific `skills/stacks/<tech>/` layers. |

## At a glance

- **Not a runtime project.** There is no manifest, lockfile, build, or test
  suite anywhere in this repo. The only executable code is the Bash scripts
  under `hooks/` and `skills/workflows/dev/hooks/`, which run inside
  *consuming* projects, not this one.
- **Everything here is markdown + shell scripts.** See
  [`architecture.md`](architecture.md) for the full inventory.
- **No CI, license, `CONTRIBUTING.md`, or `CHANGELOG`** exist in the repo.
- **This `/docs` tree was bootstrapped by the `map` orchestrator** (then named
  `dev-map`: a deep explore + map-driven document run) on 2026-07-06, with no
  accompanying code change and no changelog entry recorded, per the run's
  instructions.
