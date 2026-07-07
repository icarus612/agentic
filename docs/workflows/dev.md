# `dev` workflow

Canonical guide: [`agents/workflows/dev/AGENTS.md`](../../agents/workflows/dev/AGENTS.md).
This page is the meta-summary; edit the pipeline behavior in the payload file
above, not here.

The core build pipeline: 12 skills, 1 sub-agent definition, 2 hook scripts. No
`agents/workflows/dev/rules/` directory exists — intentionally; the dev
workflow's conventions are the universal rules (`artifact-locations`,
`plan-format`, `doc-format`, etc.), not anything dev-scoped.

```
dev-start ─orchestrates─▶  dev-explore → dev-plan → dev-plan-review ─(repeat)─┐
                                              │ approved                       │
                                              ▼                                │
                  dev-code ⇄ dev-debug ⇄ dev-test ──▶ dev-code-review ─(loop to ANY phase)
                                              │ clean                          │
                                              ▼                                │
                                       dev-document (& log) ◀──────────────────┘
```

`(repeat)` and the review loop mean any phase can jump back to an earlier one
when something is off, then resume forward.

## Skills

| Skill | Model | Context | Role |
|---|---|---|---|
| `dev-start` | opus → sonnet → gemini-pro | inline (orchestrator) | Drives the whole pipeline; creates the workflow worktree (step 0, via `workflow-setup.sh`); tracks phase state; surfaces only blockers/summaries. Has a `Stop` hook wired to `workflow-diff-check.sh`. |
| `dev-explore` | sonnet → gemini-pro | fork | Read-only codebase mapping. Shallow (docs/`AGENTS.md`/READMEs) or deep (full source); monorepo-aware. Outputs tech stack, patterns, conventions, dependency graph. |
| `dev-init` | sonnet → gemini-pro | fork | Sets up toolchain/dependencies inside the worktree so planning verification, the build loop, and tests all work. |
| `dev-plan` | opus → sonnet → gemini-pro | fork | Turns explore's findings into an ordered plan saved to `/project-plans/`. Requires at least a shallow explore first; pins MAJOR versions; enforces conventions as hard constraints. |
| `dev-plan-review` | sonnet → gemini-pro | fork | **Human gate** before any code. Verifies every claim, asks when unsure, returns a structured verdict (it cannot talk to the user itself). Loops back to `dev-explore` or `dev-plan`. |
| `dev-code` | sonnet → gemini-pro | inline (shared loop context) | Implements the plan. **Never exits on its own** — always hands off to `dev-debug` or `dev-test`. |
| `dev-debug` | sonnet → gemini-pro | inline (shared loop context) | Diagnoses and fixes issues. May exit, but prefers handing back to `dev-code` or `dev-test`. |
| `dev-test` | sonnet → gemini-pro | inline (shared loop context) | Verifies the implementation against the plan. **The only skill that can break the loop** with a terminal success exit. |
| `dev-code-review` | sonnet → gemini-pro | fork | **Human gate.** Same no-assumptions discipline as plan-review; may loop back to **any** earlier phase. |
| `dev-document` | sonnet → gemini-pro | fork | Writes technical docs into root `/docs` (mirroring project structure); optional changelog via `git add`+`git commit` (never push) and/or `docs/changelog`. This page and the rest of `agentic`'s own `/docs` tree were produced by this skill, in map-driven mode. |
| `dev-finish` | sonnet → gemini-pro | fork | Terminal phase: commits stragglers, pushes the workflow branch (always asks first, never force-pushes, never pushes main), tears down the worktree. |
| `dev-map` | opus → sonnet → gemini-pro | inline (small orchestrator) | Side-orchestrator for **doc-only** runs: forces `dev-explore` to DEEP mode, then invokes `dev-document` in map-driven mode (no plan, no diff — the map is ground truth). Not for documenting a change already built through the pipeline. |

The `dev-code`/`dev-debug`/`dev-test` triad runs **inline inside one shared
context** — the `dev-builder` sub-agent (`agents/workflows/dev/agents/dev-builder.md`)
preloads all three skills so the handoff rules are in context before the first
handoff. It carries the same `Stop` hook as `dev-start`.

## Hooks

Both are POSIX-ish Bash (`set -uo pipefail`), no dependency beyond common
Unix tools, and apply to a **consuming** project, not to `agentic` itself:

- **`workflow-setup.sh`** — invoked by `dev-start` (step 0), not a hook
  itself. Creates a git worktree in `.workflows/` (or `CLAUDE_WORKFLOWS_DIR`),
  ensures that dir is gitignored, and creates it on branch `<type>/<name>`
  (`type` ∈ `feature|bug|hotfix`, default `feature`) off the base branch
  (`--base`, else `main`, else `origin/HEAD`). Prints machine-readable
  `WORKTREE`/`BRANCH`/`BASE` lines.
- **`workflow-diff-check.sh`** — wired via frontmatter `hooks:` on `dev-start`
  (`Stop`) and `dev-builder` (`Stop`/`SubagentStop`). Diffs the workflow
  branch against its merge-base (committed + staged + unstaged + untracked),
  buckets changed files by extension, and conditionally runs
  `node_modules/.bin/vitest related`, `go test`, or `pytest`/`python -m
  pytest` if present in the consuming project. No `jq` dependency — JSON
  fields are grepped from the flat hook payload. Exits 0 (never blocks) when
  nothing changed or nothing is runnable; exits 2 with a report on stderr when
  changed-file tests fail, which blocks the stop until fixed. Both hook
  wirings point at a global install path (`~/.claude/hooks/...`) with an
  inline comment noting to swap it for a project-local `.claude/hooks/` copy.

## Loop-breaking invariant

This exact phrasing is repeated verbatim across `dev-start`, `dev-builder`,
and the three loop skill files — treat it as load-bearing:

> `dev-code` never exits on its own. `dev-debug` may exit but prefers handing
> off. Only `dev-test` can break the loop with a terminal success.

## Notes

- `dev-start` defaults itself to Opus and protects its own context: forked
  skills self-manage their model via frontmatter; it passes pointers (file
  paths, summaries), never raw payload dumps, into and out of forks.
- Story/narrative documentation and Jira/Confluence ticket linking are **not**
  part of `dev` — that's [`delivery`](delivery.md), which brackets it.
