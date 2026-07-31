# document — the docs workflow (`--type document`, alias `map`, `doc`)

For runs where the task IS the documentation — bootstrapping docs for an undocumented project, or refreshing docs suspected stale — with no code change to record. No planner and no builders: a deep map, a map-driven document pass, ship.

## Stages

**1. Setup** (shared — router). Branch type `docs/`. For a monorepo, decide WITH the user whether to map the whole repo or one app + its dependencies before exploring. Confluence mode: a map-driven run is technical-only — no story file and no Jira keys unless the user supplies them; still confirm space/parent-page/Drive targets conversationally.

**2. Map.** Invoke the **`explore`** skill via the Skill tool — DEEP mode (this workflow's default: the docs are the thing in doubt, so they can't serve as ground truth; honor an explicit `--explore` override). Pass the scope and an output path inside the parent worktree. It writes the full map to disk and returns the envelope; carry the map PATH forward, not its content. `init-workspace` may run in parallel with the mapping (the document pass may need to build or verify).

**3. Record** (shared — router, map-driven variant). Invoke the mode's document skill with: the map file path, a statement that this is a **map-driven** run (no plan path, no build summary, no diff — the map is ground truth for what to add, update, and delete), and the changelog preference (ask if unstated and it matters). `document-local` reconciles the root `/docs` tree against the map; `document-confluence` publishes the technical map pages.

**4. Ship** (shared — router). `push-pr` publishes the `docs/` parent branch with the doc changes.

## Notes

- If the mapping or document pass surfaces that the docs problem is actually a code problem (implementation wrong or incomplete), stop and bring it to the user — recommend a build or diagnose run rather than papering over it in prose.
- Read-only outside `/docs`: this workflow changes documentation, symlinks, and the changelog; never source.
