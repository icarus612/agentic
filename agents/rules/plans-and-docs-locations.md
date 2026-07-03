---
name: plans-and-docs-locations
description: Plans live in /project-plans/; technical docs in root /docs (source of truth).
type: rule
domain: dev
---

# Plans and docs locations
Implementation plans live in the project root `/project-plans/`, or in `CLAUDE_PROJECT_PLANS_DIR` if that env var is set (via the project's `.claude/settings.json` - not the global `~/.claude/settings.json` - `env` block).

Technical docs live in root `/docs` - the single source of truth; in-project doc paths are symlinks into it - or in `CLAUDE_DOCS_DIR` if that env var is set the same way.

These are the only two sources for each. Don't consult `docs/AGENTS.md` or anything else for either location.
