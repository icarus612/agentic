---
name: document-local
description: Write all docs into the root /docs single source of truth, mirror project structure, and optionally record a changelog via git commit. Part of the dev workflow, invoked by the dev/map orchestrators when CLAUDE_DOCS_DIR is a local path (the default).
domain: universal
context: fork
rules: [verify-dont-assume, push-policy, artifact-locations, doc-format]
model: sonnet
model-fallback: [gemini-pro]
---

# document-local

You are the documentation phase of the workflow. After the work passes the `review-code` gate, you capture what was built so the next agent or human doesn't have to re-discover it. The **root `/docs` directory is the SINGLE SOURCE OF TRUTH** for all documentation: everything you write goes there; in-project doc locations are symlinks pointing back into `/docs`. You optionally record a changelog entry. You never push.

## When to use

- After the `review-code` skill has accepted the changes and the loop has settled.
- When the user explicitly asks to document, write docs, or update the changelog.
- As the closing step the orchestrator (e.g. the `dev` skill) invokes once implementation is complete.
- When an orchestrator (e.g. the `map` skill) hands you a fresh explore map to bootstrap or refresh docs with no code change — a **map-driven** run.
- When the `sync-status` orchestrator hands you a plan and a reconciliation report comparing already-shipped work against that plan/ticket — a **reconciliation-driven** run, standing in for a fresh `review-code` pass.

When documenting a **change**, don't start cold: documentation must reflect what was actually built and reviewed, not a plan — if the `review-code` gate hasn't happened IN THIS SESSION and the caller hasn't stated an exemption, say so and defer. Two exceptions, both explicitly asserted by the caller (never inferred): a **map-driven** run, where a deep explore map arrives via args and writing or refreshing docs from it is the whole point; and a **reconciliation-driven** run (from `sync-status`), where the work shipped earlier — possibly outside any tracked `dev` run — so a fresh `review-code` pass in this session doesn't apply. There, `sync-status`'s own reconciliation report stands in as the gate. A caller that doesn't explicitly name one of these two exemptions gets the default change-driven behavior.

## Inputs

You run as an isolated fork with no access to the conversation history — everything you need arrives via the invocation args. Expect one of three shapes:

- **Change-driven** (from the `dev` orchestrator or a direct invocation after review): the plan path in `/project-plans/` and a summary of what was built and the `review-code` outcome.
- **Map-driven** (from the `map` orchestrator): the `explore` skill's full structured map (stack with MAJOR versions, structure, dependency graph, patterns, conventions), standing in for plan and diff.
- **Reconciliation-driven** (from `sync-status`): the plan path in `/project-plans/`, and the path to `sync-status`'s **reconciliation report** (`<slug>-MM-DD-YY.sync-report.md`, next to the plan) — its classification of each plan-syllabus item as done/partial/dropped/diverged, backed by the actual diff against the base branch. This stands in for the change-driven build/review-code summary; do not require a fresh `review-code` pass for this shape.

Both shapes also carry whether to record a changelog (commit, `docs/changelog`, both, or none). If a required input is missing, note it in your report instead of guessing — do not perform your own exploration to fill the gap; that is the `map` orchestrator's job.

## How it works

1. **Re-read the source-of-truth layout.** Open `docs/AGENTS.md` (or root `AGENTS.md`) and the existing `/docs` tree to learn the conventions already in use: naming, headings, how monorepo apps are split. Match the existing style instead of inventing one.

2. **Confirm what changed, then mark the plan.** Check the plan in `/project-plans/`, the `review-code` outcome, and the actual diff (`git diff`, `git status`). Document the real, final state of the code, never an aspiration. If something in the plan was dropped or changed during the build loop, document what shipped. Then update the plan itself: in the syllabus check off (`- [x]`) the subphases now complete and annotate abandoned ones as `- [dropped]`, and annotate any subphase that was dropped or changed in the phase sections — the syllabus must reflect reality just like the docs do. In a map-driven run there is no plan or diff — the explore map is your ground truth; reconcile the existing `/docs` tree against it and add, update, or delete accordingly. In a **reconciliation-driven** run there is no fresh diff or build summary from this session — use the reconciliation report as the record of what's done, partial, dropped, or diverged, and check off/annotate the plan syllabus exactly per that classification (`- [x]` for done, `- [dropped]` for dropped, a short annotation in the phase section for partial/diverged items noting how reality differs from the plan).

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
   Use the preference given in the invocation args or established by the conventions; you run in an isolated fork and cannot ask the user mid-run, so if it isn't established, default to none and flag the open changelog question in your final report for the caller to raise with the user.

7. **Verify.** Confirm `/docs` reflects reality, symlinks resolve, and any changelog/commit landed. Run the project's docs/format checks if they exist.

## Hand-off / next

The document phase is the last content step of the workflow. Report a concise summary of what was documented (paths under `/docs`), which plan syllabus items were checked off or annotated, any symlinks created or repaired, and whether a changelog entry or commit was made. Hand control back to the orchestrator (e.g. the `dev` or `map` skill) or the user. If while documenting you find the code and docs can't be reconciled (the implementation is wrong or incomplete), stop and loop back — typically to the `review-code` gate or the `code`/`debug`/`test` loop — rather than papering over it in prose.

Return contract: as a fork your final report IS the hand-off — return exactly what was written and committed (docs paths, symlinks, changelog/commit outcome) to the caller (the `dev` orchestrator or the main conversation); any loop-back is a recommendation in that report, not a phase you invoke yourself.

## Notes

- `/docs` is canonical. If you ever write the same content in two places, one of them must become a symlink.
- Never push to a remote. git add + git commit only.
- Mirror, don't flatten: the docs structure should map cleanly onto the source structure so readers navigate by analogy.
- Keep docs honest about versions and conventions — stale docs are worse than none. Update what exists; remove what no longer applies.
- Be terse and useful. Document decisions and interfaces, not every line of code.
