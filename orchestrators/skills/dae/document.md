# document — the docs workflow (`--type document`, alias `doc`)

For runs where the task IS the documentation — bootstrapping docs for an undocumented project, or refreshing docs suspected stale — with no code change to record. No planner and no builders: a deep map, a map-driven document pass, ship.

## Stages

**1. Setup** (shared — router). Branch type `docs/`. For a monorepo, decide WITH the user whether to map the whole repo or one app + its dependencies before exploring. Confluence mode: a map-driven run is technical-only — no story file and no Jira keys unless the user supplies them; still confirm space/parent-page/Drive targets conversationally.

**2. Map.** Invoke the **`explore`** skill via the Skill tool — DEEP mode (this workflow's default: the docs are the thing in doubt, so they can't serve as ground truth; honor an explicit `--explore` override). Pass the scope and an output path inside the parent worktree. It writes the full map to disk and returns the envelope; carry the map PATH forward, not its content. `init-workspace` may run in parallel with the mapping (the document pass may need to build or verify).

**3. Record** (shared — router, map-driven variant). Invoke the mode's document skill with: the map file path, a statement that this is a **map-driven** run (no plan path, no build summary, no diff — the map is ground truth for what to add, update, and delete), and the changelog preference (ask if unstated and it matters). `document-local` reconciles the root `/docs` tree against the map; `document-confluence` publishes the technical map pages. Once this pass produces its first commit, run `push-pr --stage open-draft` (holding the D1 conversational confirmation) to push the branch and open the draft PR. This workflow has no planner and no builders, hence no approval gate and nothing committable before Record — the record commit is therefore the earliest point at which a draft PR can open, and that is deliberately where it opens: not earlier, not deferred to Ship. It also satisfies the requirement that record output be committed and pushed before the PR gate, structurally rather than as an extra step — the commit that triggers `open-draft` here IS the record output, unlike the other dae workflows, where `open-draft` fires earlier (at plan approval) and their record commit follows it.

**4. Ship** (shared — router). The PR gate checks two oracles: the **explore map** is the coverage spec, deciding what must be covered — the gate confirms nothing the map records is missing from the doc changes. The **code** is the accuracy oracle, deciding whether what the docs say is true — every factual claim in the doc diff is checked against source. Where the docs and the source disagree, the source wins: a doc claim that matches the map but contradicts the code is a finding, not a pass. The doc changes must also conform to `doc-format`, and nothing outside the docs tree, symlinks, and changelog may have changed. After the PR gate passes, run `push-pr --stage finalize` (holding the D1 conversational confirmation) to push any last record stragglers, refresh the PR title/body, and flip the `docs/` parent branch's PR from draft to ready.

## Notes

- If the mapping or document pass surfaces that the docs problem is actually a code problem (implementation wrong or incomplete), stop and bring it to the user — recommend a build or diagnose run rather than papering over it in prose.
- Read-only outside `/docs`: this workflow changes documentation, symlinks, and the changelog; never source.
