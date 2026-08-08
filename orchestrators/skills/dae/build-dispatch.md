# build-dispatch — lane dispatch, child-branch merge-back, crash-resume

Shared by `build.md` (plan syllabus) and `diagnose.md` (approved candidates). Two dispatch tiers, never conflated: **you dispatch lanes to builders** (this file); **each builder internally dispatches packets** to its own `coder`/`contract-tester` sub-agents (its definition owns that — not your business).

## Lanes and isolation

A **lane** is a chain of subphases whose only `(after:)` edges are internal (the plan's numbered `(lane <n>)` annotations name them; an unannotated plan is one lane). Every builder gets its own **child worktree**: its phase 0 runs `workflow-setup.sh --parent <parent-branch> --type <branch-type> --name <name>-l<n>` and its own `init-workspace` (worktrees share git history, not toolchains; per-lane init runs concurrently as part of the lane). The **lane id `l<n>` comes straight from the plan's lane number** — no separate id, no mapping: lane 1's branch is `<branch-type>/<name>-l1`, and the same id names its worktree dir, contract, and exit report. This is unconditional — single-lane runs get a child worktree (`l1`) too. With physical isolation, the concurrency cap is a resource knob, not a collision guard: default 5 builders in flight, raise deliberately when the machine allows.

## Event-driven scheduling (no waves)

The syllabus's `(after:)` edges ARE the schedule. Maintain the frontier: a lane is dispatchable the moment every subphase it depends on (outside itself) is ticked. Dispatch every dispatchable lane immediately — builders in one batch message when several unblock together — and then, on EACH builder report:

1. **Verify the lane**: check the exit report file exists and passes `validate-report.sh --kind exit`, then `verify-scope.sh <child-worktree> <parent-branch>` fed the report's `## Files touched` list — the reported files must match the lane's real diff. A missing/invalid exit report or UNREPORTED files stop the schedule; resolve before merging.
2. **Merge the child branch into the parent** (from the parent worktree: `git merge <child-branch>`). A merge conflict IS a mechanical scope violation — two lanes touched the same file; stop, surface it, don't force-resolve silently.
3. **Clean up the lane**: `git worktree remove <child-path>`, `git worktree prune`, delete the child branch. Lanes are ephemeral — merged means gone. Cleanup ONLY after a verified merge.
4. **Tick its subphases**: `mark-syllabus.sh <plan> <id> <x|done|dropped>` per the report.
5. **Update the progress log** — rewrite `<run-artifacts>/progress-log.md` with the lane event (merged/failed, exit report path, frontier state) per the router's invariant.
6. **Re-scan the frontier and dispatch immediately** — a dependent lane launches the moment its edge ticks, never waiting on the slowest unrelated lane.

At run end exactly ONE worktree/branch pair remains — the parent, `<branch-type>/<name>` — which the ship stage publishes and tears down.

## Builder dispatch prompt

Each builder gets: the plan path (or diagnosis report path), its lane's subphase/candidate IDs, its **lane id** (`l<n>`, from the plan's lane number), its file scope (the union of its detail blocks' file lists), the parent branch and branch type (for its phase 0), the run-artifacts dir (its contract goes to `contracts/<lane-id>.md`, its exit report to `reports/<lane-id>-exit.md` — per the `run-artifacts` rule), on rework the gate's report path (the findings FILE, never a paraphrase), and the hard rules — stay inside the file scope, never edit the plan/report file, write the exit report file (validated by `validate-report.sh --kind exit`) before returning the envelope that points at it.

## Failure paths

- **Builder reports a blocker / scope gap / plan defect:** stop that lane; route it (blocker → user; plan defect → `plan-wrong` kickback per the router). Its worktree stays for the resumed attempt.
- **Builder dies mid-lane:** respawn fresh with the same dispatch prompt plus `--reuse` (its phase 0 reuses the surviving child worktree/branch). The syllabus is the resume state — machine-checkable ticks, loose loop, bounded respawns (2 per lane, then escalate to the user).
- **Lane still alive at teardown** (dropped subphases, declined work): surface it to the user with its worktree/branch named — never silently delete unfinished work.
