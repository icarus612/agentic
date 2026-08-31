# agentic — docs

Root documentation for the `agentic` repo, maintained per this library's own
`doc-format` and `artifact-locations` rules.

**Read this first if you want to know how the repo itself is put together.** If
you want the library's actual payload — the content you install — that lives in
[`../agent-agnostic/`](../agent-agnostic/) and
[`../tool-based/`](../tool-based/), indexed by the root
[`AGENTS.md`](../AGENTS.md). This `/docs` tree does not duplicate that content;
it explains the repo around it.

## Why `/docs` is separate from the payload

`agentic` is unusual for a project using its own `doc-format` rule: the repo
**is** a content library, so some of its "source files" — the root
[`README.md`](../README.md), [`AGENTS.md`](../AGENTS.md), and the per-layer
`AGENTS.md` guides — are load-bearing **payload**, not documentation about the
repo. Consumers paste them into their own `CLAUDE.md`, so their content and
location are fixed by the library's own conventions.

Those files are therefore **not** symlinks into `/docs` — repointing payload
paths would break the copy-paste contract the library exists to serve. `/docs`
holds *meta*-documentation instead: what the repo is, how its pieces compose,
and how a maintainer navigates and extends it. Where `/docs` describes
something with a canonical payload copy (e.g. the pipeline), it links out
rather than repeating it.

Note the asymmetry that makes this work: the `AGENTS.md` guides may describe the
repo's directory tree, because they never leave the repo intact. **Skills and
rules may not** — they get installed into a flat namespace where these folders
don't exist, so they refer to each other by name and to bindings by `domain:`.

## Map

| Page | Covers |
|---|---|
| [`architecture.md`](architecture.md) | The organizing principle (`domain:` = what a thing is bound to = where it installs), directory structure, the skill/rule/hook separation, and the dependency graph. |
| [`conventions.md`](conventions.md) | The authoritative spec: skill and rule file formats, the `domain:` classifier, model policy, artifact locations, plan format, contribution rules. |
| [`pipeline.md`](pipeline.md) | The dae pipeline: one router, twelve types over six `pipeline`-axis values (build / plan / report / docs / live / proof) resolving to seven middle files, two workers through cold gates to a PR — or, for a report type, straight to chat — plus the hooks and scripts. |
| [`tool-based.md`](tool-based.md) | The tech layers — status of each, naming, and how to add one. |
| [`known-issues.md`](known-issues.md) | Known gaps in current behavior, and work parked on purpose. |

## At a glance

- **Not a runtime project.** No manifest, lockfile, or build system. The
  only executable code is the Bash under `agent-agnostic/hooks/` (runs
  inside *consuming* projects), plus `tests/`
  (13 contract-test suites exercising those hooks against this repo itself —
  still no test framework or runner beyond that).
- **Everything else is markdown.**
- **One GitHub Actions workflow** — a post-merge docs→Confluence publish job
  that no-ops here because this repo configures no publish target, shipped as
  a working, copyable reference for consuming projects — **still no build
  system, license, `CONTRIBUTING.md`, or `CHANGELOG`.**
- **This `/docs` tree was bootstrapped by a map-driven documentation run** (a deep
  explore + map-driven document run) on 2026-07-06, with no accompanying code
  change and no changelog entry recorded, per the run's instructions.
