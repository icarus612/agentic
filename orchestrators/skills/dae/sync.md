# sync — the reconcile workflow (`--type sync`)

For work that already shipped (merged, deployed, or on a long-lived branch) whose plan syllabus, Jira ticket, or docs nobody updated. Truth source: the plan/ticket versus the real diff — never a blind repo sweep. No builders: reconcile, confirm, record. If reconciliation finds real gaps the user wants closed, that's a hand-off to a build run — this workflow never writes application code.

## Stages

**1. Setup** (shared — router). Branch type `sync/`. Additionally capture, conversationally: which plan and/or Jira key this run reconciles against (at least one required) — resolve the plan's CURRENT location with `plan-lifecycle.sh locate <slug>`; if it is in `completed/`, `reopen` it before the run writes anything, and re-archive at closeout; and the **shipped work** to diff (`--ref`, or ask for a branch/PR/range/merge locator — never guess from the plan's slug). Resolve the Jira key from the plan dir's `story.md` when present; flag mismatches with a user-supplied key rather than silently picking; never invent or create a ticket here — shipped work updates an existing one.

**2. Plan ‖ init.** Spawn the **`planner`** agent with type `sync` (module `plan-reconcile`), the plan/ticket sources, the shipped-work reference, and the parent worktree path. It computes the real diff, classifies every syllabus item / acceptance criterion against it, and writes the reconciliation report as `sync-report.md` in the plan's dir; its envelope points at it. `init-workspace` runs in parallel (verification may need the toolchain), joined before the gate.

**3. Confirm-the-diff gate (human).** Present the classification table (done / partial / dropped / diverged, each with evidence). The user confirms or corrects; corrections → SendMessage the warm planner, which amends the report. Items genuinely incomplete that the user wants finished are named explicitly and recommended to a build run — never quietly marked done to tidy the report. Then run the router's shared **Open the draft PR** step: `sync.md` has no promotion step (its plan already exists, possibly `reopen`ed at setup — stage 1), so `open-draft` commits whatever is committable at that point — the `sync-report.md` the planner wrote into the plan dir (stage 2). Per D3, this holds even on this workflow's builder-less runs — the draft PR opens and later finalizes for uniformity across workflows, not as a tolerated exception.

**4. Record** (shared — router, reconciliation-driven variant). Invoke the mode's document skill with: the plan path, the report path, a statement that this is a **reconciliation-driven** run (the report stands in for a fresh review gate), and the changelog preference. It ticks/annotates the plan syllabus exactly per the confirmed classification (`- [x]` done, `- [dropped]` dropped, annotations for partial/diverged), refreshes docs to match reality, and — Confluence mode — updates pages and transitions/links the Jira ticket per the outcome.

**5. Ship** (shared — router). Commit and push the record-stage plan ticks and doc updates via `push-pr --stage update`, then run the PR gate: its spec of record is the **plan plus the confirmed sync report**, and the diff must contain exactly the ticks, annotations, and doc updates the confirmed classification supports — nothing else. Then `push-pr --stage finalize` publishes the `sync/` parent branch carrying the report, plan ticks, and doc updates.

## Notes

- Every classification cites real evidence (file paths, diff hunks) — an item is never "done" because its name appears in a commit message; unverifiable items are open questions, not guesses.
- "Diverged" is not automatically bad — state how reality differs and let the human decide; don't editorialize it as a defect.
