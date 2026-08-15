---
name: artifact-locations
description: Where docs, plans and their records, worktrees, the run dir, and the base branch resolve from — project → global → local-default chain via resolve-config.sh; CLAUDE_DOCS_DIR may also name a Confluence location.
domain: universal
---

# Artifact locations
Five artifact kinds, five locations. Four resolve through the SAME chain — project `.claude/settings.local.json` → project `.claude/settings.json` → global `~/.claude/settings.json` → a local default — via the shared resolver `resolve-config.sh` (`orchestrators/hooks/`, sibling to `workflow-setup.sh`; global install path `~/.claude/hooks/resolve-config.sh`, or the project's `.claude/hooks/` copy if installed project-specific):

- **Docs** — `CLAUDE_DOCS_DIR`, local default root `/docs`. The single source of truth for all documentation; the value's SHAPE also selects the documenting skill:
  - A filesystem path (or unset → `/docs`): docs live locally at that path, structure per `doc-format`; the documentation phase is `document-local`.
  - A Confluence location — an Atlassian wiki URL (`https://<site>.atlassian.net/wiki/spaces/<SPACE>[/pages/...]`) or the shorthand `confluence:<SPACE>[/<Parent Page>]`: docs live in Confluence at that location, which becomes the source of truth (no local `/docs` is maintained); the documentation phase is `document-confluence`.
  - Extensible: a future `<target>:` scheme maps to the skill named `document-<target>`.
- **Implementation plans and their committed records** — `CLAUDE_PROJECT_PLANS_DIR`, local default root `/project-plans/`. Layout and lifecycle (proposals → per-plan dir → completed) per `plan-format`; the record kinds that live in a plan's dir per `run-artifacts`. Everything here is a COMMITTED repo artifact, and the split with the run dir is absolute in both directions: a progress log, builder contract, or exit report under the plans dir is a misfile, and a plan or any of its records under a worktree's `.artifacts/` is a misfile the other way.
- **Workflow worktrees** — `CLAUDE_WORKFLOWS_DIR`, local default root `.workflows/`. Always gitignored; each worktree sits on a `<type>/<name>` branch (`type` ∈ `feature|bug|hotfix|docs|sync`, default `feature`) off the base branch. Runs that dispatch builders use the **parent/child scheme**: the run's parent worktree sits on `<type>/<name>` off the base branch (no suffix — this is the branch the PR publishes), and each builder lane's child worktree sits on `<type>/<name>-l<n>` (`l<n>` = the plan's lane number: `l1`, `l2`, …) cut off the parent branch via `workflow-setup.sh --parent` (modes without builders create the parent only). Children are ephemeral — merged back into the parent and removed lane by lane; only the parent branch is ever published.
- **The gitignored run dir** — `<workflows-dir>/<name>/.artifacts/`, i.e. `.artifacts/` at the root of the run's PARENT worktree. Not separately configurable: it is derived from the worktree, so it moves wherever `CLAUDE_WORKFLOWS_DIR` points. Holds the progress log, builder contracts, and exit reports (kinds and formats per `run-artifacts`). Kept out of the product branch by an `.artifacts/` entry in the repo's tracked `.gitignore`, which must be COMMITTED to take effect inside a worktree — the `<workflows-dir>/` entry does not cover it, and never `info/exclude`, which is repo-global and would leak a branch-specific rule to every branch. Created and gitignored idempotently by `workflow-setup.sh`; destroyed with its worktree, so a worktree must never be torn down while its run is still in flight.
- **Base branch** — `CLAUDE_BASE_BRANCH`, local default resolved by a git heuristic (`main` if it exists, else the short name of `origin/HEAD`). What a workflow worktree is created off of, and what a diff/reconciliation report compares against. Resolved SILENTLY by `workflow-setup.sh` (which delegates to `resolve-config.sh CLAUDE_BASE_BRANCH --base-branch-default`) whenever an orchestrator doesn't pass `--base` explicitly — NEVER asked of the user conversationally, and NEVER read from CLAUDE.md prose.

Worktree isolation isn't only an orchestrator convention: `agent-agnostic/hooks/worktree-reminder.sh` (a `SessionStart` hook) reminds ANY session — with or without the `dae` orchestrator driving it — to set one up via `workflow-setup.sh` before mutating files, and to route pushes/PR reviews through `push-pr`/`review-pr` rather than raw `git`/`gh` commands.

## Resolution chain
1. `<project-root>/.claude/settings.local.json` → `env.<VAR>`
2. `<project-root>/.claude/settings.json` → `env.<VAR>`
3. `~/.claude/settings.json` (global/user) → `env.<VAR>`
4. The local default named above (static for docs/plans/worktrees; a git heuristic for the base branch).

The run dir has no var of its own — it is `.artifacts/` inside the worktree the workflows-dir chain already resolved.

The first scope that DEFINES the key wins — per-key fallback, not "whichever settings.json exists wins wholesale."

## The env-block gotcha
Claude Code's `env` block does NOT deep-merge across scopes: a higher-precedence settings file's `env` block WHOLESALE-REPLACES a lower one, not per key (code.claude.com/docs/en/configuration.md). A plain `${CLAUDE_DOCS_DIR:-...}` Bash read only sees whatever Claude Code itself merged into the process at session start — if a project's `.claude/settings.json` defines an `env` block AT ALL (even for unrelated keys), it can silently hide a global-only value for a key the project never mentions. The inherited process `$VAR` is NOT a substitute for this resolution chain; always resolve via `resolve-config.sh`, which reads the JSON files directly.

Never save these artifacts anywhere else, and don't consult `docs/AGENTS.md` or anything else for their locations.
