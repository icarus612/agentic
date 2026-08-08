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
| `run-artifacts` | Where run files live: committed review records beside the plan; the gitignored run dir (progress log, contracts, exit reports). Verdict vocabulary script-enforced. |
| `shell-discipline` | One command per Bash call — compounds are all-or-nothing at the permission gate; never chain `cd` with git/gh (cwd persists between calls, or `git -C`); prefer already-allowlisted invocation forms. |

## `skills/` — the tech-agnostic forks and gates

Invoked **by name by an orchestrator or worker**, not matched from a user
request — which is why each description names the pipeline it belongs to and
who invokes it (the guard that stops a single-word name like `explore`
auto-firing on an incidental keyword match). All are cold forks: isolated
context, inputs via args, one envelope back (`status`, `artifacts[]`, `next`,
`blockers[]` — see the conventions doc). The old build-loop trio
(`code`/`debug`/`test`) and the `plan` skill are gone — absorbed into the
`builder` and `planner` workers in `../orchestrators/agents/`.

| Skill | Role |
|---|---|
| `explore` | The shared mapping fork: full structured map (stack + MAJOR versions, structure, dependency graph, patterns, conventions) written to disk, envelope pointer back. Invoked by the planner's escalation and the dae document workflow — NOT a mandatory pre-plan phase. |
| `init-workspace` | Install dependencies and set up toolchains inside a worktree (the run's parent, or a builder's child) so later stages can build and test. (Verbose name — `init` collides with a Claude Code built-in.) |
| `review-plan` | Cold gate before any code. `scripts/validate-plan.sh` owns the schema half; the fork verifies claims against reality; verdict round written to the `.plan-review.md` record, envelope verdict to the caller's human gate. |
| `review-code` | Cold gate before any docs. Verdict round written to the `.code-review.md` record; the envelope `next` carries the kickback reason code (`impl-wrong` \| `plan-wrong` \| `map-wrong` \| `needs-input`) the dae router routes on. |
| `review-pr` | The PR gate before any push (and standalone on published PRs): the ENTIRE branch-vs-base diff against the plan or Jira ticket; script-enforced `ready \| tentative \| rejected` verdict in the `.pr-review.md` record. Never posts. |
| `comment-pr` | Post a `.pr-review.md` verdict to GitHub: `scripts/render-pr-comment.sh` renders the last round, `gh` posts it with confirmation. Never reviews. |
| `document-local` | Record stage when the docs target is a local path: write into the docs root, the single source of truth; optional changelog commit (never a push). |
| `push-pr` | Terminal ship stage: commit stragglers, push the workflow branch, open a PR (draft on the gate's publish-anyway path), tear down the worktree. Always asks first. |
| `cleanup-merged` | Post-merge closeout: verified-merged branch deleted local+remote, worktrees pruned, run dir removed, plan + review records archived to `completed/`, optional Jira transition. Safe deletes only. |

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
