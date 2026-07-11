---
name: artifact-locations
description: Where docs, plans, and workflow worktrees live — env-var overridable defaults /docs, /project-plans, .workflows; CLAUDE_DOCS_DIR may also name a Confluence location.
type: rule
domain: universal
---

# Artifact locations
Three artifact kinds, three locations. Each is overridable by an env var set in the project's `.claude/settings.json` `env` block (never the global `~/.claude/settings.json`):

- **Docs** — `CLAUDE_DOCS_DIR`, defaulting to root `/docs`. The single source of truth for all documentation; the value's SHAPE also selects the documenting skill:
  - A filesystem path (or unset → `/docs`): docs live locally at that path, structure per `doc-format`; the documentation phase is `document-local`.
  - A Confluence location — an Atlassian wiki URL (`https://<site>.atlassian.net/wiki/spaces/<SPACE>[/pages/...]`) or the shorthand `confluence:<SPACE>[/<Parent Page>]`: docs live in Confluence at that location, which becomes the source of truth (no local `/docs` is maintained); the documentation phase is `document-confluence`.
  - Extensible: a future `<target>:` scheme maps to the skill named `document-<target>`.
- **Implementation plans** — root `/project-plans/`, or `CLAUDE_PROJECT_PLANS_DIR` if set. Structure per `plan-format`.
- **Workflow worktrees** — root `.workflows/`, or `CLAUDE_WORKFLOWS_DIR` if set. Always gitignored; each worktree sits on a `<type>/<name>` branch (`type` ∈ `feature|bug|hotfix`, default `feature`) off the base branch.

These env vars and defaults are the ONLY sources for each location — don't consult `docs/AGENTS.md` or anything else for them, and don't save these artifacts anywhere else.
