---
name: artifact-locations
description: Where docs, plans, worktrees, and the base branch resolve from — project → global → local-default chain via resolve-config.sh; CLAUDE_DOCS_DIR may also name a Confluence location.
domain: universal
---

# Artifact locations
Four artifact kinds, four locations. Each resolves through the SAME chain — project `.claude/settings.local.json` → project `.claude/settings.json` → global `~/.claude/settings.json` → a local default — via the shared resolver `resolve-config.sh` (`orchestrators/hooks/`, sibling to `workflow-setup.sh`; global install path `~/.claude/hooks/resolve-config.sh`, or the project's `.claude/hooks/` copy if installed project-specific):

- **Docs** — `CLAUDE_DOCS_DIR`, local default root `/docs`. The single source of truth for all documentation; the value's SHAPE also selects the documenting skill:
  - A filesystem path (or unset → `/docs`): docs live locally at that path, structure per `doc-format`; the documentation phase is `document-local`.
  - A Confluence location — an Atlassian wiki URL (`https://<site>.atlassian.net/wiki/spaces/<SPACE>[/pages/...]`) or the shorthand `confluence:<SPACE>[/<Parent Page>]`: docs live in Confluence at that location, which becomes the source of truth (no local `/docs` is maintained); the documentation phase is `document-confluence`.
  - Extensible: a future `<target>:` scheme maps to the skill named `document-<target>`.
- **Implementation plans** — `CLAUDE_PROJECT_PLANS_DIR`, local default root `/project-plans/`. Structure per `plan-format`.
- **Workflow worktrees** — `CLAUDE_WORKFLOWS_DIR`, local default root `.workflows/`. Always gitignored; each worktree sits on a `<type>/<name>` branch (`type` ∈ `feature|bug|hotfix`, default `feature`) off the base branch.
- **Base branch** — `CLAUDE_BASE_BRANCH`, local default resolved by a git heuristic (`main` if it exists, else the short name of `origin/HEAD`). What a workflow worktree is created off of, and what a diff/reconciliation report compares against. Resolved SILENTLY by `workflow-setup.sh` (which delegates to `resolve-config.sh CLAUDE_BASE_BRANCH --base-branch-default`) whenever an orchestrator doesn't pass `--base` explicitly — NEVER asked of the user conversationally, and NEVER read from CLAUDE.md prose.

Worktree isolation isn't only an orchestrator convention: `generic/hooks/worktree-reminder.sh` (a `SessionStart` hook) reminds ANY session — with or without `dev`/`map`/`sync-status` driving it — to set one up via `workflow-setup.sh` before mutating files, and to route pushes/PR reviews through `push-pr`/`review-pr` rather than raw `git`/`gh` commands.

## Resolution chain
1. `<project-root>/.claude/settings.local.json` → `env.<VAR>`
2. `<project-root>/.claude/settings.json` → `env.<VAR>`
3. `~/.claude/settings.json` (global/user) → `env.<VAR>`
4. The local default named above (static for docs/plans/worktrees; a git heuristic for the base branch).

The first scope that DEFINES the key wins — per-key fallback, not "whichever settings.json exists wins wholesale."

## The env-block gotcha
Claude Code's `env` block does NOT deep-merge across scopes: a higher-precedence settings file's `env` block WHOLESALE-REPLACES a lower one, not per key (code.claude.com/docs/en/configuration.md). A plain `${CLAUDE_DOCS_DIR:-...}` Bash read only sees whatever Claude Code itself merged into the process at session start — if a project's `.claude/settings.json` defines an `env` block AT ALL (even for unrelated keys), it can silently hide a global-only value for a key the project never mentions. The inherited process `$VAR` is NOT a substitute for this resolution chain; always resolve via `resolve-config.sh`, which reads the JSON files directly.

Never save these artifacts anywhere else, and don't consult `docs/AGENTS.md` or anything else for their locations.
