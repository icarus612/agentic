---
name: run-artifacts
description: Where workflow-run files live — committed plan records inside the plan's own dir, a gitignored run dir for the progress log / contracts / builder exit reports — and the scripts that enforce their formats.
domain: universal
---

# Run artifacts

Every dae run produces files in exactly two places. Nothing a worker, gate, or orchestrator needs to hand to another agent may live only in conversation context — if another agent (or a resumed run) needs it, it is one of these files, and the hand-off passes the file PATH. A file that belongs to one home never appears in the other: no plan, story, or review record under `<workflows-dir>/`; no progress log, contract, or exit report under the plans dir.

## Committed plan records — inside the plan's dir

A run's committed artifacts live in the plan's own directory (`<plans-dir>/<slug>-MM-DD-YY/`, layout per `plan-format`): the spec of record `plan.md`, plus records named for their kind alone — `story.md` (requirements capture), `plan-review.md`, `code-review.md`, `pr-review.md`, `sync-report.md`. There is no `diagnosis` record kind: a diagnose run's ranked candidate report IS its `plan.md`. A run with no plan (a `document` run; a ticket-only `sync` run) still gets a dir under the plans dir for its records; having no `plan.md`, it archives nothing and the dir is removed at closeout. At closeout ONLY `plan.md` is archived — the records stay in git history, not in `completed/`. Review reports are append-per-round: each gate iteration adds a `## Round <n> — <date>` section (the revision-loop history is readable straight from the file), opened by `report-verdict.sh` and checked by `validate-report.sh` (install `~/.claude/hooks/`, or the project's `.claude/hooks/` copy). The header block's `verdict:` is one of `ready | tentative | rejected` and its `next:` one of `proceed | impl-wrong | plan-wrong | map-wrong | needs-input` — both scripts reject anything else, so the status vocabulary is enforced by code, not prose. A report that fails `validate-report.sh` is not a report.

## The gitignored run dir — `<workflows-dir>/<name>-artifacts/`

Sibling of the run's parent worktree, inside the workflows dir (already gitignored), created at setup, deleted by post-merge cleanup. Never committed. Contents:

- **`progress-log.md`** — the run's live state, owned and REWRITTEN IN PLACE by the orchestrator at every state change (stage transitions, gate rounds, lane events, plan amendments). One per plan/run. ALL small- and medium-sized run information lives here rather than only in chat: current stage, per-gate round counts with one-line outcomes, lane dispatch states, amendment log, open questions, and pointers to every other artifact. A resumed or compacted session reconstructs the run from this file plus the plan syllabus.
- **`contracts/<lane-id>.md`** — each builder's contract document, keyed by its lane id (`l1`, `l2`, … — the plan's lane number, the same id that names its branch and worktree). This is its defined home: never inside the child worktree (where it would either die with the lane or leak into the product branch).
- **`reports/<lane-id>-exit.md`** — each builder's exit report (envelope header + files touched + per-criterion evidence), written before the builder returns; its envelope points here. `validate-report.sh --kind exit` checks it; `verify-scope.sh` reads its file list per lane, and `verify-run-scope.sh` reads ALL of them at the PR gate — a product change in the run's diff that no exit report claims is a blocking finding (the exit reports are collectively the run's ownership ledger).
- **`explore-map-<scope-slug>-<MM-DD-YY>.md`** — the `explore` fork's structured map, written to the resolved workflows dir (its default when the caller names no output path). Ephemeral like everything else on this side of the split, and never the plans dir — a map is not a plan record.
