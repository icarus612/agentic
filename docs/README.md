# agentic — docs

This is the root documentation for the `agentic` repo, maintained per this
library's own `doc-format` and `artifact-locations` rules
(`agents/rules/doc-format.md`, `agents/rules/artifact-locations.md`).

**Read this first if you want to know how the repo itself is put together.**
If you want the library's actual payload — the content you copy into your own
projects — that lives in [`../agents/`](../agents/) and is documented in place
by [`agents/AGENTS.md`](../agents/AGENTS.md) and [`agents/README.md`](../agents/README.md).
This `/docs` tree does not duplicate that content; it explains the repo around it.

## Why `/docs` is separate from `agents/`

`agentic` is unusual for a project using its own `doc-format` rule: the repo
**is** a content library, so some of its "source files" — the root
[`README.md`](../README.md), [`agents/AGENTS.md`](../agents/AGENTS.md),
[`agents/README.md`](../agents/README.md), the per-workflow `AGENTS.md` guides,
and the `tools/<tool>/README.md` adapters — are load-bearing **library
payload**, not documentation about the repo. They are copy-paste output:
consumers paste them into their own `CLAUDE.md`/`GEMINI.md`/skills folders, so
their content and location are fixed by the library's own conventions
(`agents/README.md`'s skill/rule format).

Because of that, this bootstrap does **not** turn those files into symlinks
into `/docs` — doing so would repoint load-bearing payload paths and break the
copy-paste contract the library exists to serve. `/docs` instead holds
*meta*-documentation: what the repo is, how its pieces compose, and how a
maintainer navigates and extends it. Where `/docs` describes something that
also has a canonical payload copy (e.g. the dev pipeline), it links out to that
file rather than repeating it.

There is currently nothing in the repo that duplicates content across two
locations, so there are no in-project doc symlinks to create or repair yet. If
that changes (e.g. a future `tools/<tool>/docs/` folder or a project-level
README under `agents/` starts holding real prose instead of pointers), point it
back at `/docs` per `doc-format`.

## Map

| Page | Covers |
|---|---|
| [`architecture.md`](architecture.md) | The layering model (universal ⊕ workflow ⊕ stack ⊕ project), directory structure, and dependency/hand-off graph. |
| [`conventions.md`](conventions.md) | Skill and rule file formats, the model policy, artifact locations, and the contribution convention. |
| [`workflows/dev.md`](workflows/dev.md) | The `dev` build pipeline: explore → plan → review → build loop → review → document → finish, plus `dev-map`. |
| [`workflows/delivery.md`](workflows/delivery.md) | The `delivery` workflow that wraps `dev` with Jira/Confluence/Drive publishing. |
| [`stacks.md`](stacks.md) | Status of the tech-specific `stacks/<tech>/` layers (all currently placeholder stubs). |
| [`tools.md`](tools.md) | Status of the per-tool adapters (`claude` complete, `gemini`/`antigravity` partial). |

## At a glance

- **Not a runtime project.** There is no manifest, lockfile, build, or test
  suite anywhere in this repo — verified by an exhaustive file listing (no
  `*.json`/`*.yaml`/`*.toml`, no `.claude/`, no `package.json`/`go.mod`/
  `requirements.txt`). The only executable code is two Bash scripts under
  `agents/workflows/dev/hooks/`, which run inside *consuming* projects, not
  this one.
- **Everything here is markdown + two shell scripts.** See
  [`architecture.md`](architecture.md) for the full inventory.
- **No CI, license, `CONTRIBUTING.md`, or `CHANGELOG`** exist in the repo, and
  git history (8 commits, all messaged `"update"`) has nothing changelog-worthy
  to mine.
- **This `/docs` tree was bootstrapped by `dev-map`** (a deep `dev-explore` +
  map-driven `dev-document` run) on 2026-07-06, with no accompanying code
  change and no changelog entry recorded, per the run's instructions.
