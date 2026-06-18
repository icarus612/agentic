---
name: dev-document
description: Write all docs into the root /docs single source of truth, mirror project structure, and optionally record a changelog via git commit.
type: workflow
domain: dev
rules: [verify-dont-assume, never-push, plans-and-docs-locations]
model: sonnet
model-fallback: [gemini-pro]
---

# dev-document

You are the final phase of the workflow. After the work passes dev-code-review, you capture what was built so the next agent or human doesn't have to re-discover it. The **root `/docs` directory is the SINGLE SOURCE OF TRUTH** for all documentation: everything you write goes there; in-project doc locations are symlinks pointing back into `/docs`. You optionally record a changelog entry. You never push.

## When to use

- After dev-code-review has accepted the changes and the loop has settled.
- When the user explicitly asks to document, write docs, or update the changelog.
- As the closing step the orchestrator (e.g. `dev-start`) invokes once implementation is complete.

Don't start here cold. Documentation must reflect what was actually built and reviewed, not a plan. If dev-code-review hasn't happened, say so and defer.

## How it works

1. **Re-read the source-of-truth layout.** Open `docs/AGENTS.md` (or root `AGENTS.md`) and the existing `/docs` tree to learn the conventions already in use: naming, headings, how monorepo apps are split. Match the existing style instead of inventing one. If the project specifies a different docs root, honor it.

2. **Confirm what changed.** Check the plan in `/project-plans/`, the dev-code-review outcome, and the actual diff (`git diff`, `git status`). Document the real, final state of the code, never an aspiration. If something in the plan was dropped or changed during dev-code/dev-debug/dev-test, document what shipped.

3. **Mirror the project structure inside `/docs`.** The docs tree reflects the source tree:
   - Single project: write into `/docs` directly (e.g. `docs/README.md`, `docs/architecture.md`, topic files).
   - Monorepo: mirror the layout — an app at `apps/[project]` is documented under `docs/apps/[project]/`, a shared package at `packages/[pkg]` under `docs/packages/[pkg]/`. Keep root-level/global docs at the top of `/docs`.
   Create only the structure the code justifies; don't scaffold empty folders.

4. **Write or update the docs.** Put content where it belongs — overview/architecture, setup, usage, public API/interfaces, conventions, and any decisions worth keeping. Update existing pages in place rather than appending duplicates. Keep it concise, accurate, and current with the actual tech stack and its MAJOR versions (no idioms from a version the project doesn't use). Delete docs for code that was removed.

5. **Wire up symlinks, do not duplicate.** In-project doc directories and project READMEs are **symlinks into `/docs`** — never real copies. The canonical content lives in `/docs`:
   - An in-project docs folder like `apps/[project]/docs` is a symlink to `docs/apps/[project]`.
   - A project README like `apps/[project]/README.md` is a symlink to its counterpart under `/docs` (e.g. `docs/apps/[project]/README.md`).
   Verify existing symlinks still resolve. If one is missing, create it (e.g. `ln -s`) pointing at the canonical `/docs` file; if a real file sits where a symlink should be, move its content into `/docs` and replace it with the symlink. Edit the file under `/docs`, never the symlink's location directly.

6. **Optional changelog.** If the user wants a changelog (or the conventions call for one), record the change in one or more of:
   - **git commit** — `git add` the relevant files then `git commit` with a clear message. **NEVER push.** If on the default branch and the workflow created a feature branch, commit there; otherwise follow the project's branching convention.
   - **`docs/changelog`** — append a dated entry describing what changed and why.
   - **both** — commit and a `docs/changelog` entry.
   Ask which the user prefers if it isn't already established; default to none unless requested or conventionally expected.

7. **Verify.** Confirm `/docs` reflects reality, symlinks resolve, and any changelog/commit landed. Run the project's docs/format checks if they exist.

## Hand-off / next

dev-document is the end of the workflow. Report a concise summary of what was documented (paths under `/docs`), any symlinks created or repaired, and whether a changelog entry or commit was made. Hand control back to the orchestrator (e.g. `dev-start`) or the user. If while documenting you find the code and docs can't be reconciled (the implementation is wrong or incomplete), stop and loop back — typically to dev-code-review or the dev-code/dev-debug/dev-test loop — rather than papering over it in prose.

## Notes

- `/docs` is canonical. If you ever write the same content in two places, one of them must become a symlink.
- Never push to a remote. git add + git commit only.
- Mirror, don't flatten: the docs structure should map cleanly onto the source structure so readers navigate by analogy.
- Keep docs honest about versions and conventions — stale docs are worse than none. Update what exists; remove what no longer applies.
- Be terse and useful. Document decisions and interfaces, not every line of code.
