# live — the conversational increment workflow (--type live, alias adhoc)

This is `build.md`'s loop with the auto-mode switch INVERTED. `build.md`'s plan gate ends with
"approve, THEN switch to auto mode and dispatch"; `live.md` never switches to auto mode — the
router stays conversational for the entire build, because the user's next message is a
first-class event source alongside a builder report.

## Stages

**1. Setup** (shared — router; reference `SKILL.md`'s shared Setup bullet and
`worktree-modes.md`, never restate their mechanics). Branch type `feature/` from the resolved
row. `CLAUDE_DOCS_DIR` resolves to a local path and `document-local` records, always;
`CLAUDE_DOCS_PUBLISH` is resolved separately and, when set, `confluence-mode.md` captures
requirements before exploring (`SKILL.md`'s shared-stage bullet). **The worktree scheme is the
standard parent/child scheme** — the router's parent worktree per `worktree-modes.md`, each
builder lane's child cut off it per `build-dispatch.md`. Live introduces NO worktree-mode
special case, and this file does not discuss one. `ship: chat` is unreachable on this type — the
row is fixed to `publish`.

**2. Capture the ask, then plan.** Every ask is written to a durable file BEFORE the planner is
messaged: `<run-dir>/asks/<n>.md`, numbered from 1 in arrival order, holding the user's words
verbatim. This is not bookkeeping — a live plan has no single up-front brief, so the `asks/`
DIRECTORY is what its plan's `plan-format` ask-of-record pointer names, and `review-plan`'s
ask-vs-plan diff (step 7, "Diff the plan against the ask of record") reads the numbered file for
the phase under review. An ask reaching the planner only through conversation context is a
defect in this loop.
Then spawn the warm `planner` agent with module `plan-live`, the ask FILE path (never pasted
content), the parent worktree path, and the resolved axes. It writes `Phase 1` with `1.1..1.k`
subphases annotated `(lane 1)` to `<plans-dir>/proposals/<slug>-MM-DD-YY.md`. Run
`validate-plan.sh` ALWAYS — it ships inside the `review-plan` skill at `<review-plan skill
dir>/scripts/validate-plan.sh`, NOT as an installed hook. Invoke `review-plan` ONLY when
`RIGOR_PLAN` is `med` or `high`; at `low` the plan goes straight to the user for approval. Then
`plan-lifecycle.sh promote`, then the shared **Open the draft PR** step. `init-workspace` runs in
parallel, joined before dispatch.

**3. The conversational loop.** Two event sources, interleaved, the router waits on both:
- **A user ask** → write `<run-dir>/asks/<n>.md` → SendMessage the warm planner with that path.
  It appends exactly ONE `Phase N` with `N.1..N.k` subphases annotated `(lane N)` to the SAME plan
  file; re-run `validate-plan.sh`; re-gate through `review-plan` only at plan rigor med+; then
  dispatch lane N per `build-dispatch.md`. **One ask = one phase = one lane.** No decomposing an
  ask across lanes, and no adding work to a lane already in flight.
- **Concurrent asks** produce concurrent lanes. Where a new phase's file scope overlaps an
  unfinished phase's, the planner adds an `(after:)` edge so the two serialize automatically —
  the router does not adjudicate overlap itself.
- **A builder report** → the per-lane merge sequence, stage 4 below.

**4. Per-lane merge.** `build-dispatch.md`'s merge-back sequence, by name: `verify-scope.sh`
against the exit report's file list → merge the child branch into the parent →
`mark-syllabus.sh` per subphase → `push-pr --stage update`, no conversational confirmation per D1
→ lane cleanup branching on the push outcome. One addition beyond `build-dispatch.md`: SendMessage
the planner to annotate that phase's detail blocks with what actually shipped. Then an **offer** —
explicitly dismissable, never a stage; a declined or ignored offer changes nothing about the run:
- open the parent worktree in the user's editor (`$VISUAL`, else `code <path>`) — offered
  unconditionally;
- run the app via the `run` skill **only if it is available in the session** — this repo does not
  ship a `run` skill, so name it as an optional convenience, never as a dependency.

**5. Ship** — entered only when the user says so, never inferred. Integration pass in the parent
(full suite + the plan's cross-lane acceptance criteria + `verify-run-scope.sh
<parent-worktree> <base> <run-dir>`) → ask "pre-PR code review?", **defaulting to no at
`RIGOR_CODE=low` and to yes at med or high**; on yes, invoke `review-code` with the plan path and
the build summary → Record (shared — router) → `push-pr --stage update` → the router's PR gate →
`push-pr --stage finalize`.

## Notes

- **There is no code-gate STAGE.** `review-code` is an opt-in step at ship, not a gate the run
  must pass. **The PR gate is mandatory and unskippable** — no type row may route around it
  (`SKILL.md`'s PR-gate bullet).
- **The PR gate's skeptical profile for live.** Live hands `review-pr` a severity profile
  (review-pr's caller-supplied severity profile input) that says: **plan deviations are open
  questions, never blocking findings** — a live plan is a running transcript of what was asked,
  so divergence between it and the diff is the normal shape of the run, not a defect. Blocking
  stays reserved for real bugs, convention and major-version violations, cross-lane duplication,
  failing automated checks, and `verify-run-scope.sh` UNCLAIMED lines. **`plan-wrong` is never a
  valid `next` on a live run** — a live plan cannot be "wrong" in the sense the kickback means,
  since it is amended in place at every ask; the reachable rejection codes are `impl-wrong` and
  `needs-input`. This is a genuine, narrowly-scoped, demote-only severity override — not a passive
  continuation of `review-pr`'s existing behavior.
- **The plan is the transcript.** It grows monotonically; earlier phases are annotated, never
  rewritten. `plan-live.md` owns that discipline — point at it by name.
- Every branch in this file keys on a resolved AXIS value (`RIGOR_PLAN`, `RIGOR_CODE`, `SHIP`,
  `REWORK`), never on the type name.
- If an ask turns out to need a real up-front design pass, say so and recommend a `feature` run —
  the run has outgrown a conversational increment and needs a plan gate before any code moves.
