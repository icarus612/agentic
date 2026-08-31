# pr-review

## Round 1 — 08-30-26

```
verdict: tentative
next: proceed
blocking: 0
non-blocking: 3
```

**Target:** branch `feature/prove-type-and-ship-axis` vs `main` (worktree
`/home/icarus64/repos/agentic/.workflows/prove-type-and-ship-axis`; no PRs in this repo, per
`source-push-sync` — this is the pre-`push-main` branch-vs-base review).

**Spec of record:** `project-plans/prove-type-and-ship-axis-08-26-26/plan.md` (17/17 subphases
checked) plus `.artifacts/the-ask.md` (the ask-of-record pointer the plan names in Goal & scope).

**Severity profile:** none supplied — default policy applied throughout.

### Verification performed

- `verify-run-scope.sh . main .artifacts` → `OK: all 73 changed files claimed by 7 exit report(s)
  or harness-owned`. No UNCLAIMED lines — every product change is owned by a lane's exit report.
- All 13 suites in `tests/` run directly (not taken from the progress log): 435+ assertions,
  0 failures, including `resolve-type.test.sh` at 181 cases (prove-specific: 02g, 02g2, 43e,
  64a-64d, plus the all-types loops at 01/23 gaining `prove` and the code-phase loop at 23
  correctly excluding it alongside map/analyze/document).
- `bash -n` over every changed script under `agent-agnostic/hooks/`: clean.
- Rename fidelity for Phase 1 (`git diff -M`): every moved file shows as a `rename`
  (87-100% similarity, i.e. content-preserving), never delete+add.
- `orchestrators/` string sweep (case-insensitive, with a positive control against `main`,
  which found 1 hit confirming the grep itself works): zero literal-path references remain
  outside `project-plans/`; the handful of surviving "orchestrator(s)" hits (`AGENTS.md:63`,
  `docs/conventions.md:64`, `docs/architecture.md:81`, `agent-agnostic/AGENTS.md:17`) are the
  common-noun role ("orchestrators are invoked by the user") or an intentional historical
  mention of the fold itself, not the stale directory path.
- Catalogue counts (`docs/README.md`, `docs/pipeline.md`, `docs/architecture.md`,
  `agent-agnostic/AGENTS.md`): all read "twelve types … six pipeline values … seven middle
  files" consistently; no stale "eleven/five/six" survives.
- Spot-verified `workflows.yaml`'s `prove` row and `map`'s new `branch: docs/` cell,
  `resolve-type.sh`'s `VOCAB_PIPELINE`/phase-table edits, `prove.md` and `proof-skeleton.md`
  in full, `report.md`'s three corrected sentences, `sync-install.sh`'s six sites and
  `claude-install-drift.sh`'s mirrored sites, and `docs/conventions.md`'s link to
  `agent-agnostic/AGENTS.md#review-rules-for-future-types` — all match the plan's acceptance
  criteria exactly, including the AC that `prove`/`disprove` appear only in the title line and
  the one documented example invocation of `prove.md`, never as a branch condition.
- Confirmed `map`/`analyze`'s `ship: chat|publish` axis already existed on `main` before this
  branch (§B, out of scope here) — this branch only added `map`'s missing `branch: docs/` cell,
  matching the plan's scope claim.

### Findings

- [non-blocking] `project-plans/prove-type-and-ship-axis-08-26-26/plan.md:3` — the header still
  reads `**Status:** proposal, pre-gate`, but the syllabus (all 17 subphases `[x]`) and the run's
  own progress log show the plan fully built with all lanes merged and the PR gate already in
  flight. Stale status line in the plan record itself; worth a line before archiving so a later
  reader of `completed/` isn't misled about how this run actually proceeded (no plan-gate round
  was run — the user approved directly, per the progress log's Gates table).
- [non-blocking] `project-plans/prove-type-and-ship-axis-08-26-26/plan.md:419` — Phase 8's
  "⚠ `feature/fold-orchestrators` is still unlanded" warning contradicts **DP-4** two pages later
  (line 459), which states both competing branches were deleted and the fold was designed fresh
  inside this same plan. Leftover from an earlier draft before the plan was rewritten around the
  narrowed scope; harmless (the fold this plan performs already supersedes the warning) but an
  internal inconsistency in the record worth cleaning up.

- [non-blocking] `project-plans/prove-type-and-ship-axis-08-26-26/plan.md` — the **Stack & MAJOR
  versions** table's "Verified from" column still cites pre-fold paths that no longer exist:
  `orchestrators/hooks/resolve-type.sh:33`, `orchestrators/skills/dae/workflows.yaml:5-10`,
  `orchestrators/hooks/workflow-setup.sh:70-74`. Defensible as a provenance record (those were
  the real paths when the facts were verified, and Phase 1 is the thing that moved them), and
  deliberately outside the `orchestrators/` sweep, which excluded `project-plans/` by design.
  Flagged only because these become dead paths for anyone reading the plan from `completed/`
  after archival — same class as the two findings above, all three confined to the plan record
  rather than shipped content.

### Gate-owner addendum (checks beyond the delegated pass)

Verified independently, all clean, none changing the verdict:

- **Merged layer guide, nothing dropped.** All six sections of the deleted
  `orchestrators/AGENTS.md` (intro three-tier table, all 7 principles, Entry points, dae
  pipeline, Hooks, Agents, Review rules) are present in `agent-agnostic/AGENTS.md`. The four
  standing review rules survive verbatim at `agent-agnostic/AGENTS.md:244+`, and the sole
  citation of the anchor (`docs/conventions.md:232`) resolves.
- **`prove` satisfies the four rules.** `resolve-type.sh:433` (`report|proof)`) branches on the
  **pipeline axis value**, never the type name; `VOCAB_PIPELINE` (`resolve-type.sh:133`) gains
  `proof` as a scalar — `pipeline` is still not an array. The only other `prove`/`disprove`
  occurrences outside the dae skill dir are the ordinary noun "proof" in `review-code/SKILL.md`
  and `review-plan/SKILL.md`.
- **Cross-lane coherence, `SKILL.md` ↔ `prove.md`.** All six of `SKILL.md`'s claims about
  `prove.md` match it: the type row (`SKILL.md:71` vs `workflows.yaml:36` — pipeline, middle,
  no planner module, `docs/`, `against: optional`, `ship: publish|chat`); alias-not-a-mode
  (`prove.md:3`); falsification unconditional at every rigor tier (`prove.md:17`); `prove.md`
  owning the `ship: chat` short-circuit (`prove.md:8`); draft PR opening at the record commit
  (`prove.md:23`); and the `<docs-root>/proofs/` scope boundary (`prove.md:23`). `prove.md` is
  28 lines and consistently POINTS at what other files own — `report.md`'s snapshot mechanics,
  `committee.md`, `AGENTS.md`, `doc-format`, `resolve-scratch.sh`, the shared "Open the draft
  PR" step — restating none of them, as its acceptance criteria require.
- **Links and paths resolve.** All 23 relative markdown link targets across 103 product `.md`
  files resolve (scanner positive-controlled against an injected bad link). The only broken
  links in the tree are 12 inside the gitignored `.artifacts/` run dir — quoted excerpts in
  lane contracts and exit reports, not shipped content. Of 20 backticked repo-ish prose paths,
  the 7 that miss at repo root are all legitimate: two are skill-relative and exist
  (`comment-pr/scripts/render-pr-comment.sh`, `review-plan/scripts/validate-plan.sh`),
  `hooks/README.md` is relative to `agent-agnostic/AGENTS.md:161` and exists, and the rest
  (`.agents/GEMINI.md`, `.claude/settings.local.json`, `docs/AGENTS.md`,
  `.github/pull_request_template.md`) describe *consuming* projects, not this repo.
- **`workflows.yaml`'s header is not stale** — the open question flagged at dispatch. Lines 6-8
  now read `agent-agnostic/hooks/resolve-config.sh:21` and `agent-agnostic/hooks/
  resolve-type.sh`; no `orchestrators/` path survives in it.
- **Ask-vs-plan: no overclaim.** `.artifacts/the-ask.md` carries three sections. §A (the new
  type, defaulting to a document with `chat` switchable) is delivered — `ship: publish|chat`
  puts `publish` first, so the document is the default, and `map` keeps `chat|publish`,
  honoring §B's "keep the current defaults." §B is explicitly and accurately carved out under
  "Already delivered by `8875739` — explicitly NOT in scope", naming exactly what shipped
  there; the plan claims only to add a row to that mechanism, which is what the diff does. §C
  (plan then pause) was honored.

### Open questions

None barring the verdict — all seven decision points the plan carried (DP-1 through DP-7, R-1
through R-3) are either resolved on `main` already or are explicitly recorded, deferred
risks/scope choices the plan itself argues for keeping as-is (e.g. DP-7's "ship the skeleton
first, add `validate-proof.sh` as a follow-up," which this review confirms has no dangling
reference expecting that script yet).
