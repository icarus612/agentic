# build — the build workflow (`--type feature|bugfix|rework|migration|hotfix`)

The stage sequence for issue-type runs. Setup and ship are the router's shared stages; this file owns the middle. Follow it in order; the router's gate caps, kickback routing, and invariants apply throughout.

## Stages

**1. Setup** (shared — router). Docs target, Confluence requirements capture when applicable, parent worktree per `worktree-modes.md`, `--type` mapped to the branch type from the selection table.

**2. Plan ‖ init.** Spawn the **`planner`** agent via the Agent tool with: the user's request (verbatim ask + gathered context), the declared type (which names its `plan-<type>` module), the parent worktree path, the `--explore` mode if the user forced one, the story file path (Confluence mode), and any prior corrections. In the SAME message, invoke `init-workspace` for the parent worktree so toolchain setup runs while planning does. The planner explores for itself (its own ladder; it may fork the `explore` skill) and writes the plan to `proposals/` per `plan-format`. Collect its envelope — `artifacts[]` carries the plan path. JOIN on `init-workspace` before the gate.

**3. Plan gate (human).** Invoke the **`review-plan`** skill via the Skill tool with the plan path. It runs `validate-plan.sh` for the structural half and verifies claims against reality, returning an envelope verdict. Present the verdict and the plan to the user; collect approve/revise. On revise: SendMessage the corrections to the warm planner, which amends the same plan file; re-gate. Respect the router's cap (3 loops → escalate). After explicit approval, FIRST run `plan-lifecycle.sh promote <proposal-path>`, THEN switch to auto mode and dispatch against the printed `plan.md` path.

**4. Build.** Dispatch builder lanes from the approved plan's syllabus per `build-dispatch.md` — event-driven on the `(after:)` edges, one child worktree per builder, merge-back + `verify-scope.sh` + `mark-syllabus.sh` per lane report. After the last lane merges: run the integration pass in the parent worktree — the full test suite plus the plan's cross-lane acceptance criteria (each builder's e2e verified only its own chunk), plus `verify-run-scope.sh <parent-worktree> <base> <run-artifacts>` so unclaimed product changes surface NOW rather than at the PR gate. Route failures as an `impl-wrong` kickback to the owning lane.

**5. Code gate (human).** Invoke the **`review-code`** skill via the Skill tool with the plan path and the build summary. Present its envelope verdict; on revise, route by the reason code in `next` per the router's kickback table. Repeat (capped) until clean and approved.

**6. Record** (shared — router). `document-local` or `document-confluence` per the docs target, passing the plan path, build/review summary, and changelog preference. The document skill also ticks/annotates any syllabus items the build closed differently than planned.

**7. Ship** (shared — router). The router's PR gate first — `review-pr` on the parent branch vs the base, verdict presented with the push confirmation, non-ready verdicts routed per the router (replan / rebuild / draft-publish with `comment-pr`). Then `push-pr` with the parent worktree path, parent branch, base branch, a work summary, and the pr-review report path (linked in the PR body; `--draft` if the gate chose it). Not done until it reports.

## Notes

- Tech-stack agnostic: the plan binds to what the planner verified from manifests; enforce its conventions, never a remembered stack.
- The plan is the spec of record from approval on. Builders flagging plan defects mid-build stop their lane; route the defect as a `plan-wrong` kickback rather than letting anyone improvise.
- In `--worktree none` mode there is no parent worktree: single-lane plans only (there is nowhere to isolate parallel builders) — see `worktree-modes.md`.
