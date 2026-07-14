---
name: doc-format
description: How docs are structured — /docs mirrors the source tree; nested doc paths and READMEs are symlinks into it, never copies.
domain: universal
---

# Doc format
All documentation lives in the docs root (see `artifact-locations`) — never scattered through the source tree. This rule's mirror/symlink structure applies to LOCAL mode (a filesystem docs root); when `CLAUDE_DOCS_DIR` names a Confluence location, Confluence is the single source of truth, no local `/docs` is maintained, and page structure follows the `document-confluence` skill (with `external-storage-cap` governing what may land on Atlassian).

- **Mirror the source layout.** Single project: write directly into `/docs` (`docs/README.md`, `docs/architecture.md`, topic files). Monorepo or multi-README project: docs for `apps/[project]` live in `docs/apps/[project]`, docs for `packages/[pkg]` in `docs/packages/[pkg]`; root-level/global docs stay at the top of `/docs`. Create only the structure the code justifies — no empty scaffolding.
- **Symlink, never copy.** Every nested doc path is a symlink to its root counterpart: `apps/[project]/docs` → `docs/apps/[project]`, `apps/[project]/README.md` → `docs/apps/[project]/README.md`. Edit the file under `/docs`, never the symlinked location. If a real file sits where a symlink should be, move its content into `/docs` and replace it with the symlink. If the same content ever exists in two places, one of them must become a symlink.
- **Naming.** `README.md` as the entry point of each docs directory; other files are lowercase kebab-case topic files (`architecture.md`, `api-reference.md`, `changelog`).
- **One page per topic, kept current.** Update existing pages in place rather than appending duplicates; delete pages for code that was removed.

This rule is format and placement only — what to document and when is the documenting skill's job.
