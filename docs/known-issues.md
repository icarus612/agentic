# Known issues

This page is the docs root's home for known gaps in current behavior and for work that is parked
on purpose. An entry here is **not** a bug report and **not** a backlog: it records a limitation
someone will actually hit, states whether anything is planned about it, and points at where that
plan lives. A parked proposal listed here is deliberately parked, not stale — it is not to be
deleted as cleanup.

Each entry follows the same shape: the limitation, where it's visible in the source, and its
status (parked with a pointer / no plan / fixed and awaiting removal).

## `-w none`: single-lane, no child-worktree isolation

**Limitation.** `--worktree none` runs every stage in the current checkout with no worktree at
all, and restricts builder dispatch to ONE lane at a time — there are no child worktrees, so
there is no physical isolation for parallel builders (`agent-agnostic/skills/dae/worktree-modes.md:13-15`
for the mode's definition; `agent-agnostic/skills/dae/build.md:27` for the single-lane
consequence). This mode DOES seed a run dir — `<repo-root>/.artifacts/` (`contracts/`, `reports/`,
`progress-log.md`, the `dae-role` marker) — mirroring what `workflow-setup.sh` seeds for a normal
parent worktree; the single-lane builder later reuses that same `.artifacts/` for its own contract
and exit report, since there is no separate child worktree to hold them.

**Source.** `agent-agnostic/skills/dae/worktree-modes.md:13-15`, `agent-agnostic/skills/dae/build.md:27`.

**Status.** Parked with a pointer. The redesign under discussion has the current checkout become
the run's PARENT while builder lanes still get isolated child worktrees. See
`project-plans/proposals/none-mode-parent-08-28-26.md` — that proposal is **intentionally parked,
not stale**: it was split out of an unrelated plan on purpose, and stays here until someone picks
it up deliberately.

## Two pre-plan files with no builder exit report: `57d2a3e`

**Limitation.** `tests/report-middle-contract.test.sh` and `tool-based/confluence/AGENTS.md` carry
no builder exit report claim, so `verify-run-scope.sh` flags them as unclaimed product changes
whenever it is re-run against `write-enforcement-and-ask-inlining-09-01-26`'s branch history. Both
files trace to `57d2a3e92d9fdde5d1a97c1a550b7d4891116403`, the branch's first commit (2026-09-01
15:55), made roughly seven hours before the plan itself was promoted (`01d8903`) — the orchestrator
wrote them directly, during the max-rigor `prove` audit that produced the plan, closing findings I10
(no `AGENTS.md` for the `tool-based/confluence/` tech layer, though `docs/tool-based.md` documents it
as the first entry of the standard layer shape) and supplying the `dae-axes-restructure-08-23-26`
§6.1 test oracle that had been declared but never shipped. No builder lane ever owned these files, so
no exit report legitimately can.

**Why not manufacture a claim.** `code-review.md`'s rounds 3-5 considered writing a fake builder
exit report retroactively, purely to make `verify-run-scope.sh` pass, and rejected it: doing so
"would launder an orchestrator product write into a fake builder claim and destroy the ledger's
meaning." The gate's actual resolution was to supply the missing review coverage directly — reading
both files in full and confirming neither is a defect (the Confluence `AGENTS.md` matches
`artifact-locations`/`doc-format`; the test file is test-only, 12 passing cases) — rather than paper
over the gap with a false claim. A disclosed, honestly-red ledger entry was judged better than a
green one obtained by lying about who wrote what.

**Source.** Commit `57d2a3e92d9fdde5d1a97c1a550b7d4891116403` ("fix(docs,hooks): close the four
Partials the plan audit found, plus two strays"); discussed at length in
`write-enforcement-and-ask-inlining-09-01-26`'s `code-review.md` (rounds 3-5). That plan shipped as
`21518ff` on `main`; its own plan dir is subject to the usual archive rule (only `plan.md` survives
to `completed/`), which is why this disclosure needs a home outside it.

**Status.** No plan and no pointer — this is a closed, one-time disclosure, not a parked proposal. A
future `verify-run-scope.sh` run against this same branch history will still report these two files
unclaimed; that is documented and expected, not a gap in the enforcement that shipped in `21518ff`.

## `parent-tree-guard.sh`: a promoted plan gets a sticky `deny`

**Limitation.** The plans-ledger keys every verdict on `(content hash, absolute path)` and judges a
path the first time it appears, under whatever `dae-role` is active then. The planner's proposal is
recorded `ok` under role `planner`. `plan-lifecycle.sh promote`, which `build.md` assigns to the
orchestrator, then moves it unchanged to `<slug>/plan.md`. The hash is the same but the path is new,
so it is judged under role `orchestrator`, which `role_allows()` limits to `*-review.md` and
`sync-report.md`. The result is a sticky `deny` that fires on every Bash call and at Stop until the
plan is committed. `plan-review.md` survives the same move only because of its basename. A pure
move of already-approved content is flagged as an orchestrator write, which is a false flag.
`2c8afa8` avoids this for `push-main`, which moves and commits in one call, but the `push-pr` route
still hits it: promote, then a separate `open-draft` commit.

Observed on mythic-made run `signup-countdown-click` (2026-10-21):

```
ok   d35d525b… project-plans/proposals/signup-countdown-click-10-20-26.md
deny d35d525b… project-plans/signup-countdown-click-10-20-26/plan.md
```

The documenter's Record-stage output is the same class, confirmed on mythic-made run
`home-countdown-mobile-taps` (2026-11-02). The documenter's edits to `docs/` (`hero.md`,
`changelog.md`, `known-issues.md`) were denied as product writes on the orchestrator's next Bash
call. The Write tool's agent identity lets the documenter write past `scope-writes.sh`, but
`parent-tree-guard.sh`'s scan of the uncommitted tree judges each path only by the `dae-role`
marker, which reads `orchestrator` at Record. The deny cleared once `push-pr --stage update`
committed the docs. The proposed fix below covers the move case only; the documenter case needs
the guard to credit a write made under a non-orchestrator agent identity.

**Source.** `agent-agnostic/hooks/parent-tree-guard.sh:359-373` (the ledger lookup and the write),
`:281` (`role_allows`).

**Status.** No plan yet. Proposed fix: treat a plans-dir path as clean when its content hash
already has an `ok` entry at any path under `plans_root`, so a pure move inherits the approval.
Controls for the fix: a moved `ok` file must pass, and a new orchestrator-written file with a fresh
hash must still be denied.

## `check-diff-hygiene.sh`: reworded comments count as new comments

**Limitation.** The comment checks (banner and density) count every `+` line in the diff. git shows
an edited line as a `-`/`+` pair, so a comment that already existed and had one word changed counts
as newly added commentary. On mythic-made PR #117 (2026-10-22), `signup-section.svelte.test.ts` was
reported as "7/13 added lines are comments", but 4 of the 7 were existing comments where only a
component name changed. That instance stayed under the threshold and did not block, but a rename
that rewords a few existing comment lines can trip `COMMENT DENSITY` or `COMMENT BANNER` and block
`gh pr ready` through `pr-ready-hygiene-guard.sh`, on code that added no commentary at all.

**Source.** `agent-agnostic/hooks/check-diff-hygiene.sh:103-145` (the added-line collector and the
banner/density counts).

**Status.** No plan yet. Proposed fix: within a hunk, pair each removed comment line with an added
comment line and count only the unpaired added ones. Controls for the fix: a pure reword of an
existing comment block must pass, and a new N-line banner in one hunk must still fail.
