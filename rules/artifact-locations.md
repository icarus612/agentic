---
name: artifact-locations
description: Where docs, plans, and workflow worktrees live — env-var overridable defaults /docs, /project-plans, .workflows.
type: rule
domain: universal
---

# Artifact locations
Three artifact kinds, three locations. Each is overridable by an env var set in the project's `.claude/settings.json` `env` block (never the global `~/.claude/settings.json`):

- **Technical docs** — root `/docs`, or `CLAUDE_DOCS_DIR` if set. The single source of truth for all documentation; structure per `doc-format`.
- **Implementation plans** — root `/project-plans/`, or `CLAUDE_PROJECT_PLANS_DIR` if set. Structure per `plan-format`.
- **Workflow worktrees** — root `.workflows/`, or `CLAUDE_WORKFLOWS_DIR` if set. Always gitignored; each worktree sits on a `<type>/<name>` branch (`type` ∈ `feature|bug|hotfix`, default `feature`) off the base branch.

These env vars and defaults are the ONLY sources for each location — don't consult `docs/AGENTS.md` or anything else for them, and don't save these artifacts anywhere else.
