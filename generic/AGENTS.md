# Generic — the global layer (`domain: universal`)

Everything here is **bound to no technology and no service**. It works on any
project, any stack, so it installs once at the **user level** (`~/.claude/` or
`.agent/`) and is available everywhere.

The `tech-agnostic` rule polices the boundary: a technology named in a
universal skill is an *example only*. Real tech-specific guidance belongs to a
`domain: <tech>` skill, shipped with the project that uses it — see
[`../tool-based/`](../tool-based/).

## `rules/` — always-on constraints

Loaded as context regardless of what was invoked; no selection step. Short,
declarative, no procedure. If it must hold even when nothing was invoked, it's
a rule.

| Rule | Holds |
|---|---|
| `verify-dont-assume` | Read the real code/config/docs before asserting. Confidently wrong is the failure mode. |
| `respect-versions-and-conventions` | Use idioms correct for the installed MAJOR version; project conventions are hard constraints. |
| `tech-agnostic` | Never assume or hard-code a stack; discover it, then load the skills whose `domain:` names it. |
| `push-policy` | Ask before every push; never force-push; never push main. |
| `model-policy` | Each skill declares `model:` plus an ordered `model-fallback:`. |
| `artifact-locations` | Where docs, plans, and worktrees live (config-resolved) — and how the docs target selects the documentation skill. |
| `doc-format` | How docs are structured and placed. |
| `plan-format` | How plans are named, phased, and kept current. |

## `skills/` — the tech-agnostic phase skills

Invoked **by name by an orchestrator** (or preloaded into the `builder` agent),
not matched from a user request — which is why each description names the
pipeline it belongs to. Several are single words (`plan`, `code`, `test`,
`debug`, `explore`); that guard is what stops them auto-firing on an incidental
keyword match.

| Skill | Role |
|---|---|
| `explore` | Read-only codebase map: stack + MAJOR versions, structure, dependency graph, patterns, conventions. Shallow or deep; monorepo-aware. |
| `init-workspace` | Install dependencies and set up toolchains inside the worktree so later phases can build and test. (Verbose name — `init` collides with a Claude Code built-in.) |
| `plan` | Turn explore's findings into an ordered, convention-grounded plan in the plans dir. |
| `review-plan` | Human gate before any code. Verifies every claim; asks when unsure; loops back to `explore`/`plan`. |
| `code` | Implement one planned unit. **Never exits on its own.** |
| `debug` | Find the real root cause and fix it. May exit, but prefers handing off. |
| `test` | Verify against the plan. **The only loop-breaker.** |
| `review-code` | Human gate before any docs. May loop back to **any** earlier phase. |
| `document-local` | Documentation phase when the docs target is a local path: write into the docs root, the single source of truth; optional changelog commit (never a push). |
| `push-pr` | Terminal phase: commit stragglers, push the workflow branch, open a PR, tear down the worktree. Always asks first. |
| `review-pr` | Review a GitHub PR against its diff, plan, and conventions. Posts comments only on explicit instruction. |

## `hooks/` — global quality enforcement

Wired via `settings.json`, not skill frontmatter, so they apply to every
session: `smart-lint.sh` and `smart-test.sh` (language-aware, blocking on
failure), `ntfy-notifier.sh`, the `record-changed.sh`/`test-changed.sh` pair,
`worktree-reminder.sh` (a `SessionStart` hook that reminds ANY session — not
just an orchestrator-driven one — to isolate file changes in a worktree and
route pushes/PR reviews through `push-pr`/`review-pr` instead of raw
`git`/`gh` commands), and shared helpers. Configured by `CLAUDE_HOOKS_*` env
vars — see [`hooks/README.md`](hooks/README.md).

Pipeline-scoped hooks (worktree setup, config resolution, the Stop gate) are
**not** here — they belong to the orchestrators that own them:
[`../orchestrators/hooks/`](../orchestrators/hooks/).
