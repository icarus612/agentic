---
name: run-artifacts
description: Where workflow-run files live — committed review records beside the plan, a gitignored run dir for the progress log / contracts / builder exit reports — and the scripts that enforce their formats.
domain: universal
---

# Run artifacts

Every dae run produces files in exactly two places. Nothing a worker, gate, or orchestrator needs to hand to another agent may live only in conversation context — if another agent (or a resumed run) needs it, it is one of these files, and the hand-off passes the file PATH.

## Committed review records — beside the plan, in the plans dir

Named `<slug>-MM-DD-YY.<kind>.md` next to the plan they belong to (`CLAUDE_PROJECT_PLANS_DIR` chain, default `/project-plans/`); archived together with the plan. Kinds: `story` (Confluence requirements capture), `diagnosis`, `sync-report`, and the three review reports — `plan-review`, `code-review`, `pr-review`. Review reports are append-per-round: each gate iteration adds a `## Round <n> — <date>` section (the revision-loop history is readable straight from the file), opened by `report-verdict.sh` and checked by `validate-report.sh` (install `~/.claude/hooks/`, or the project's `.claude/hooks/` copy). The header block's `verdict:` is one of `ready | tentative | rejected` and its `next:` one of `proceed | impl-wrong | plan-wrong | map-wrong | needs-input` — both scripts reject anything else, so the status vocabulary is enforced by code, not prose. A report that fails `validate-report.sh` is not a report.

## The gitignored run dir — `<workflows-dir>/<name>-artifacts/`

Sibling of the run's parent worktree, inside the workflows dir (already gitignored), created at setup, deleted by post-merge cleanup. Never committed. Contents:

- **`progress-log.md`** — the run's live state, owned and REWRITTEN IN PLACE by the orchestrator at every state change (stage transitions, gate rounds, lane events, plan amendments). One per plan/run. ALL small- and medium-sized run information lives here rather than only in chat: current stage, per-gate round counts with one-line outcomes, lane dispatch states, amendment log, open questions, and pointers to every other artifact. A resumed or compacted session reconstructs the run from this file plus the plan syllabus.
- **`contracts/<lane-id>.md`** — each builder's contract document, keyed by its lane id (`l1`, `l2`, … — the plan's lane number, the same id that names its branch and worktree). This is its defined home: never inside the child worktree (where it would either die with the lane or leak into the product branch).
- **`reports/<lane-id>-exit.md`** — each builder's exit report (envelope header + files touched + per-criterion evidence), written before the builder returns; its envelope points here. `validate-report.sh --kind exit` checks it; `verify-scope.sh` reads its file list per lane, and `verify-run-scope.sh` reads ALL of them at the PR gate — a product change in the run's diff that no exit report claims is a blocking finding (the exit reports are collectively the run's ownership ledger).
