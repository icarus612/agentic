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
