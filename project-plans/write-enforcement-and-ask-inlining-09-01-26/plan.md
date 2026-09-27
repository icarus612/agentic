# Write enforcement that actually binds, and the ask moves into the plan

### Ask of record

Migrated inline 09-02-26, when lane 2 landed Phase 6 and retired the pointer form this plan
originally used. Entries are verbatim and append-only; earlier entries are never edited.

**09-01-26** — the original ask:

> lets do a review of the last 5 plans to merge to main and prove the plans actually landed (some
> things may have been changed and rechanged/reverted like the --ship strictness) lets have max
> rigor (high) for checking this too

**09-01-26 — appended, on the hook duplicate:**

> Why the fuck is allow workflow cleanup and parent tree guard running in every pre/post tool use?
> why the fuck is it not scoped to dae, and why the fuck is it on EVERY pre and post tool use?

> Add the hook fix to the list of isses found we will fix them all together

**09-01-26 — appended, the ask-of-record decision:**

> asks are usually light anyway. can you just append it to the top of the plan? also the-ask.md
> file should be updated every time a new ask is added (like if its mid build/plan)

**09-01-26 — appended, hook gate policy:**

> the main thing with hooks is to make sure that everything that needs a gate gets one, but ONLY
> the things that need them. dont over gate things, but make sure that all phases link to correct
> hooks, as some are put in place to block orchestrators from writing code, builders from
> modifying plans, or planers from changing things.

> its more like orchestrators dont make writes PERIOD, planners can only edit things in the
> PLAN_DIR env var, and builders cant edit anything in the PLAN_DIR or DOCS_DIR

**09-01-26 — appended, the plan gate:**

> add opening the plan to what dae should do whenever a plan is created

> it should create the plan, open it, and then ask for approve/rework/dissaprove

**09-01-26 — appended, process and artifact location:**

> a, and proof/issues can get merged into one file, and saved like/where an analysis does.

("a" = write a proper proposal and dispatch builder lanes for the remaining work, rather than
continuing to edit directly as the orchestrator.)

**Supersedes:** nothing.

## Phase syllabus
- [ ] Phase 1: Make the marker exist
  - [ ] 1.1: `workflow-setup.sh` seeds `progress-log.md`                      (lane 1)
  - [ ] 1.2: Contract test — a fresh parent worktree is gated from setup       (lane 1, after: 1.1)
- [ ] Phase 2: Give the hooks a role to key off
  - [ ] 2.1: The role marker — written by setup/dispatch, unwritable by the agent (lane 1, after: 1.1)
  - [ ] 2.2: `scope-writes.sh` — per-role allowed-root table                   (lane 1, after: 2.1)
  - [ ] 2.3: `parent-tree-guard.sh` — the same table, mirrored byte-identically (lane 1, after: 2.2)
  - [ ] 2.4: Contract tests for all three roles, positive and negative         (lane 1, after: 2.3)
- [ ] Phase 3: Stop the isolation breach
  - [ ] 3.1: `smart-test.sh` exits 0 for `coder` and `contract-tester`         (lane 1, after: 2.1)
  - [ ] 3.2: Contract test — neither role receives suite output                (lane 1, after: 3.1)
- [ ] Phase 4: Shrink the orchestrator to zero writes
  - [ ] 4.1: `progress-log.sh` — one script owns the progress log             (lane 1, after: 2.2)
  - [ ] 4.2: Orchestrator's allowed roots become empty                         (lane 1, after: 4.1)
  - [ ] 4.3: Tests for the script and the empty scope                          (lane 1, after: 4.2)
- [ ] Phase 5: Contain the uncontained runs
  - [ ] 5.1: `ship: chat` and `--worktree none` runs get a marker              (lane 1, after: 2.2)
  - [ ] 5.2: Test — a chat run is scoped                                       (lane 1, after: 5.1)
- [ ] Phase 6: The ask moves into the plan
  - [ ] 6.1: `plan-format` — verbatim ask at the top, append-only             (lane 2)
  - [ ] 6.2: `validate-plan.sh` check 6 — assert the section, not a path       (lane 2, after: 6.1)
  - [ ] 6.3: `tests/validate-plan.test.sh` — check-6 cases rewritten           (lane 2, after: 6.2)
  - [ ] 6.4: `run-artifacts` — drop `the-ask.md` from the run dir              (lane 2, after: 6.1)
  - [ ] 6.5: `planner.md` + `review-plan` — write it, append it, diff it       (lane 2, after: 6.1)
- [ ] Phase 7: The base branch stops lying
  - [ ] 7.1: `resolve-config.sh` — implement the documented git heuristic      (lane 3)
  - [ ] 7.2: `tests/resolve-config-precedence.test.sh` — the heuristic         (lane 3, after: 7.1)
- [ ] Phase 8: The plan gate opens the plan
  - [ ] 8.1: `dae/SKILL.md` — create / OPEN / ask(approve|rework|disapprove)   (lane 4)
  - [ ] 8.2: `build.md`, `live.md`, `diagnose.md` — reference, don't restate   (lane 4, after: 8.1)
- [ ] Phase 9: Docs stop overstating
  - [ ] 9.1: `SKILL.md` — "machine-auditable", and the skill-scoped Stop hook  (lane 4, after: 8.2)
  - [ ] 9.2: `artifact-locations` + `workflow-setup.sh` error text vs Phase 7  (lane 4, after: 7.1, 9.1)
- [ ] Phase 11: Close the two gaps the lanes found (amendment, 09-02-26)
  - [ ] 11.1: `none` mode seeds its markers under `.artifacts/`, like every other mode (lane 5)
  - [ ] 11.2: Test — a `none`-mode run is detected and role-flippable          (lane 5, after: 11.1)
- [ ] Phase 10: Verification
  - [ ] 10.1: Whole suite, `bash -n`, install sync, and the marker drill       (after: 1.2, 2.4, 3.2, 4.3, 5.2, 6.3, 6.5, 7.2, 9.2)

## Goal & scope

**In.** Make the dae write-scope rules actually bind, then implement the user's stated role policy:
orchestrators make no writes at all, planners write only the resolved plans dir, builders write
anything except the plans dir and the docs dir. Stop `smart-test.sh` from breaching `coder` and
`contract-tester` isolation. Move the ask of record into the plan, append-only. Fix the base-branch
fallback. Make the plan gate open the plan and offer three verdicts.

**Out.** Backfilling the five archived plans' dangling ask pointers (decide separately — Risks).
I3b's `if`-guarding of `branch-squash-guard.sh` (an optional optimization with a safety tail —
Risks). Wiring `verify-scope.sh` as a real gate (named in the audit, deliberately deferred: it
changes the merge-back path and deserves its own plan). Any change to `allow-workflow-cleanup.sh`,
which was investigated and found correct.

**Why this order.** Phase 1 is first because nothing else binds without it: the audit that produced
this plan was itself conducted with every write hook inert, and the fix is one line. Phase 3 is
early because it is an active correctness breach, not a gap — it contaminates two agents on every
run today.

## Stack & MAJOR versions

| Thing | Version / constraint | Verified from |
|---|---|---|
| Shell | `bash`, `set -uo pipefail`, no `jq`, no YAML library | `agent-agnostic/hooks/resolve-config.sh:21`; `resolve-type.sh:20-21` |
| Test harness | plain `bash` suites under `tests/`, `PASS:`/`FAIL:` lines, `N passed, M failed` tail, exit 0/1 | `tests/*.test.sh`, 14 files |
| Hook payload | JSON on stdin; only `cwd`, `session_id`, `stop_hook_active`, `tool_name`, `tool_input` are read anywhere | audit, positive-controlled grep over `agent-agnostic/hooks/` |
| Hook config | `agent-specific/claude/settings.json`, merged (never copied) into `~/.claude/settings.json` | `.claude/rules/source-push-sync.md` |
| `if` on a hook entry | supported; permission-rule syntax; tool-event hooks only | code.claude.com/docs/en/hooks.md |

## Conventions to enforce

- **`scope-writes.sh` and `parent-tree-guard.sh` share `find_parent_worktree` and
  `resolve_root_dir` VERBATIM, by design.** Change one, change the other, in the same commit. The
  reason is written at `scope-writes.sh`'s Shared abstraction note (added in `57d2a3e`).
- **Fail open, never closed.** Both marker hooks exit 0 on any resolution problem. Phase 2 must not
  turn a config failure into a denial.
- **A role signal must be structural.** The marker is written into a directory the agent may not
  write to. An env var the agent can `export` is not acceptable — see `structural-anti-cheating`.
- **Positive controls are mandatory in every test.** A hook that exits 0 because the fixture was
  malformed is indistinguishable from one that permits the action.
- `grep` here may be **ugrep** and `awk` **mawk**; assert on output CONTENT, never exit status alone.
- No time estimates anywhere.

## Phase 1: Make the marker exist

### 1.1 — `workflow-setup.sh` seeds `progress-log.md`
- **Files:** `agent-agnostic/hooks/workflow-setup.sh`
- **Pattern:** the existing run-dir creation, which already makes `.artifacts/`, `contracts/`,
  `reports/` and prints `RUNDIR:`.
- **Criteria:** a parent worktree is gated the instant setup returns. Seed a minimal
  `progress-log.md` (run name, branch, base, created-at, empty state section). Child worktrees
  (`--parent`) still get NO run dir and no marker. Idempotent under `--reuse`: an existing log is
  never overwritten.
- **Test:** run setup, assert the file exists before any agent acts; feed `scope-writes.sh` a
  product-path Edit payload and assert exit 2, with a plans-dir control at exit 0.

### 1.2 — Contract test
- **Files:** `tests/workflow-setup-reuse.test.sh` (extend)
- **Criteria:** fresh parent → marker present, product write denied. `--reuse` → existing log
  preserved byte-for-byte. `--parent` child → no marker, and the child is NOT gated by it.
- **Test:** `mktemp -d` git fixtures; positive control that the same payload is allowed pre-seed.

## Phase 2: Give the hooks a role to key off

### 2.1 — The role marker
- **Files:** `agent-agnostic/hooks/workflow-setup.sh`, `agent-agnostic/skills/dae/build-dispatch.md`
- **Criteria:** a role token — `orchestrator` | `planner` | `builder` — recorded where the ancestor
  walk already goes, in a location the agent itself cannot write to under its own scope. Absent
  marker = current behaviour, unchanged (fail open). Decide and record: whether the planner gets a
  distinct marker or is distinguished another way, given it shares the orchestrator's cwd.
- **Test:** each role's marker resolves to its own token; a missing/garbage token falls back to the
  MOST RESTRICTIVE role valid at that location rather than denying outright.
- **CRITERION CORRECTED 09-02-26, after code-review round 1.** This subphase originally read
  "a missing/garbage token falls back to today's **permissive** roots rather than denying." That
  wording was written to prevent a fail-closed regression and accidentally specified a **privilege
  upgrade**: an orchestrator (allowed nothing but its own gate reports) could write any invalid
  token and land on the legacy permissive roots, gaining the whole plans dir and docs tree —
  including `plan.md`, the run's own spec of record. Lane 6 implemented the criterion faithfully
  and the escalation was found by drilling the built artifact, not by reading it.
  The rule is now **least privilege, not permissive**: in a marked parent worktree an unresolved,
  garbage, or structurally impossible role resolves to `orchestrator`. This is NOT a fail-closed
  change — the no-marker case still exits 0 for everything, which is what the fail-open rule
  actually protects; the marked case already knows it is inside a dae run.

### 2.2 — `scope-writes.sh` per-role table
- **Files:** `agent-agnostic/hooks/scope-writes.sh`
- **Criteria:** orchestrator → `{}` after Phase 4 (until then, `.artifacts` only); planner →
  plans root ONLY; builder → everything EXCEPT plans root and docs root. The builder branch must
  work from a CHILD worktree, which has no marker above it — either the walk learns to find the
  sibling parent by the `-l<n>` suffix, or the dispatcher drops the marker in the child.
- **Test:** 3 roles × (allowed path, denied path), each with its opposite as control.

### 2.3 — `parent-tree-guard.sh`, mirrored
- **Files:** `agent-agnostic/hooks/parent-tree-guard.sh`
- **Criteria:** the same table, the same helpers, byte-identical per the Shared abstraction note.
- **Test:** a `diff` assertion that the two helper blocks are identical is itself a test case.

### 2.4 — Contract tests
- **Files:** `tests/scope-writes.test.sh`, `tests/parent-tree-guard.test.sh` (extend both)

## Phase 3: Stop the isolation breach

### 3.1 — `smart-test.sh` exits 0 for the blind roles
- **Files:** `agent-agnostic/hooks/smart-test.sh`
- **Criteria:** when the role marker says `coder` or `contract-tester`, exit 0 before running
  anything. Nothing is lost: the builder runs the suite at its phase-3 join and phase-5 e2e tail.
  Unknown/absent role → today's behaviour.
- **Test:** fixture project; assert that for each blind role the hook produces NO suite output and
  exit 0, with a positive control proving the same fixture DOES emit output for an unmarked role.

### 3.2 — Contract test
- **Files:** `tests/smart-test-role-scope.test.sh` *(new)*
- **Criteria:** the measured breach cannot recur — assert the coder fixture's output never contains
  the test file's assertions, and the tester fixture's never contains implementation-derived values.

## Phase 4: Shrink the orchestrator to zero writes

### 4.1 — `progress-log.sh`
- **Files:** `agent-agnostic/hooks/progress-log.sh` *(new)*
- **Pattern:** `mark-syllabus.sh` — one script owns one file.
- **Criteria:** `--init`, `--set <section> <text>`, `--append <section> <text>` covering stage, gate
  rounds, lane events, amendments, PR state, open questions. Creates the file if missing.
- **Test:** each subcommand round-trips; malformed args are a usage error, never a silent no-op.

### 4.2 — Orchestrator scope → empty
- **Files:** `agent-agnostic/hooks/scope-writes.sh`, `parent-tree-guard.sh`,
  `agent-agnostic/skills/dae/SKILL.md`
- **Criteria:** orchestrator Write/Edit is denied everywhere; its artifact mutations go through
  `progress-log.sh`, `mark-syllabus.sh`, `plan-lifecycle.sh`, `report-verdict.sh`. The router's
  harness-scoped-writes invariant is reworded to match.
- **NOTE — settled by DP-2 (Risks):** `report-verdict.sh` opens a round header but the reviewer
  still appends findings with Write/Edit, and gates run in the orchestrator's own context. So the
  orchestrator's allowed roots become exactly the run's review records under the plans dir
  (`<slug>-MM-DD-YY/*-review.md`, `sync-report.md`) and nothing else. Every doc line this subphase
  touches must say **"zero outside the run's gate reports"** — a bare "zero writes" claim here would
  be false, and this plan exists because of claims like that.

### 4.3 — Tests

## Phase 5: Contain the uncontained runs
### 5.1 — Marker for `ship: chat` and `--worktree none`
- **Files:** `agent-agnostic/hooks/resolve-scratch.sh`, `agent-agnostic/skills/dae/report.md`,
  `prove.md`, `worktree-modes.md`
- **Criteria:** these runs get a marker of their own so the same hooks engage. A chat run writes
  only its scratch dir; verify `--worktree none` empirically before assuming it is unmarked.
### 5.2 — Test

**Collision recorded 09-02-26.** Phase 5's containment and DP-2's orchestrator restriction were
designed independently and met for the first time in lane 6. `resolve-scratch.sh` deliberately
seeds a chat run's marker WITHOUT a `dae-role` token — its own comment says an `orchestrator`
marker would wrongly block the run's own scratch-dir writes — so it depended on exactly the
permissive absent-role fallback that the corrected 2.1 removes. Applying an orchestrator's
restriction to a chat run is a category error: such a run has no plan, no planner, no builders,
and no orchestrator in DP-2's sense; it is one agent writing a report.
Resolved **structurally, deliberately not with a third token**: a dae parent worktree's marked
root is a linked git worktree, a chat run's is the main checkout — distinguishable by `git-dir`
vs `git-common-dir`, which cannot be forged by writing a gitignored file. A `scratch` TOKEN would
have been the obvious fix and the wrong one: "your own root is yours" is a total escalation the
moment an orchestrator can write it. `resolve-scratch.sh` needed no change, and its comment
stays true.

## Phase 6: The ask moves into the plan
### 6.1 — `plan-format`
- **Files:** `agent-agnostic/rules/plan-format.md`
- **Criteria:** the ask is a verbatim section at the TOP of the plan, before the syllabus,
  APPEND-ONLY, each addition dated. Replaces the two-form pointer wording. States that git history
  on the committed plan is the tamper record.
### 6.2 — `validate-plan.sh` check 6
- **Files:** `agent-agnostic/skills/review-plan/scripts/validate-plan.sh`
- **Criteria:** assert the section exists, is non-empty, and precedes the syllabus. No filesystem
  resolution. An archived plan must PASS.
### 6.3 — `tests/validate-plan.test.sh` — rewrite check-6 cases (C11/C12 have no target any more)
### 6.4 — `run-artifacts` — drop `the-ask.md` from the run dir's contents
### 6.5 — `planner.md` + `review-plan` — the planner writes the ask into the plan and APPENDS on
  amendment (currently a mid-run ask is captured nowhere); the gate diffs against that section.
  `plan-live.md`'s `asks/<n>.md` scheme is the existing precedent — generalize it, don't duplicate.

## Phase 7: The base branch stops lying
### 7.1 — `resolve-config.sh` implements the documented heuristic
- **Files:** `agent-agnostic/hooks/resolve-config.sh`
- **Criteria:** `--base-branch-default` returns `main` when it exists, else the short name of
  `origin/HEAD`, else fails with the error `workflow-setup.sh:107` already promises. The hardcoded
  `"dev"` goes. Outside a git repo, fail rather than invent a branch.
### 7.2 — Tests, including the no-`main`/`origin/HEAD`-set case and the not-a-repo case.

## Phase 8: The plan gate opens the plan
### 8.1 — `dae/SKILL.md`
- **Files:** `agent-agnostic/skills/dae/SKILL.md`
- **Starting point:** `.artifacts/pending-plan-gate-edit.patch` — written, then reverted when
  `parent-tree-guard.sh` correctly refused an orchestrator product write. Reapply through this lane.
- **Criteria:** create → OPEN **in the user's editor** (`code <path>`, falling back to `$EDITOR`,
  then `xdg-open`; if none is available, say so and print the path — never silently substitute a
  chat dump for opening the file) → ask, offering exactly `approve` | `rework` | `disapprove` by
  name. Printing the plan into the transcript is NOT opening it and does not satisfy this step. `disapprove` stops the run
  and DELETES the proposal per `plan-format` (never `completed/`), and asks before any teardown.
### 8.2 — `build.md`, `live.md`, `diagnose.md` reference the shared step; restate nothing.

## Phase 9: Docs stop overstating
### 9.1 — `SKILL.md`: "machine-audited" → machine-*auditable* (`verify-scope.sh` /
  `verify-run-scope.sh` are opt-in scripts, not wired hooks); and the Stop-hook line says
  skill-scoped, matching `docs/pipeline.md:193`.
### 9.2 — `artifact-locations` and `workflow-setup.sh`'s error text reconciled with Phase 7's
  actual behaviour.

## Phase 10: Verification
### 10.1 — Whole suite + `bash -n` over every changed script + `sync-install.sh --check`, plus the
  **marker drill**: create a parent worktree, attempt a product write as each role, and assert the
  three outcomes. This drill is the regression guard for the failure that produced this plan.

## Phase 11: Close the two gaps the lanes found (amendment, 09-02-26)

Added after lanes 1–4 merged. Both gaps are things the lanes found by testing their own work and
raised rather than papered over; neither was visible when the plan was written.

### 11.1 — `none` mode seeds its markers under `.artifacts/`
- **Files:** `agent-agnostic/skills/dae/worktree-modes.md`, `agent-agnostic/skills/dae/build.md`
- **The defect:** `worktree-modes.md:15` has `none` mode seed `progress-log.md` and `dae-role`
  BARE at the repo root, on the reasoning that "no `.artifacts` dir exists yet at that point".
  Three things break as a result, and the file contradicts itself about one of them:
  1. `scope-writes.sh` and `parent-tree-guard.sh` both detect a run by `.artifacts/progress-log.md`.
     A bare root marker is invisible to them, so **a `none`-mode run has no write enforcement at
     all** — the exact hole Phase 1 existed to close, left open in one mode.
  2. `workflow-setup.sh --set-role`'s guard (`:83`) requires `.artifacts/progress-log.md`, so the
     role flip fails with `no run dir at <root>`. Verified by live drill, twice, independently.
  3. `worktree-modes.md:15` says `--set-role` "doesn't apply at Setup time" because there is no
     `.artifacts` dir, then prescribes `--set-role builder --root <repo-root>` at Build. Both
     cannot hold.
- **Criteria:** `none` mode seeds under `<repo-root>/.artifacts/` like every other mode. That one
  change fixes all three: marker detection works, `--set-role` works unchanged, and the
  self-contradiction goes. Do NOT instead loosen `--set-role`'s guard to accept a bare root file —
  that would make the marker location mode-dependent and give the two hooks a second shape to
  detect. `build.md`'s Build-stage flip (wired by lane 4, currently documented as failing) becomes
  correct, and its "Known gap, verified, not fixed here" note is removed.
- **Test:** a `none`-mode fixture at a repo root: assert `scope-writes.sh` detects the run and
  denies a product write under the `builder`→`orchestrator` flip, with the pre-seed permissive
  case as the positive control.

### 11.2 — Test coverage for the above
- **Files:** `tests/workflow-setup-reuse.test.sh` (extend) or a new `tests/none-mode-marker.test.sh`
- **Criteria:** the flip round-trips; the drill that failed for lane 4 now passes.

## Risks, open questions, decision points

1. **DP-1 — RESOLVED at the plan gate (09-01-26): option (a).** The planner is spawned with no
   worktree of its own, so `cwd` cannot separate it from the orchestrator. The router writes the
   role marker as part of spawning the planner, and restores it to `orchestrator` when the planner
   returns. Rejected: (b) a planner worktree — the planner's whole job is writing the plans dir,
   which lives in the parent, so a child worktree fights its purpose for real cost; (c) one shared
   scope — that is the status quo the plan exists to end. **Constraint on 2.1:** the marker must sit
   where the planner's own scope cannot reach it, so a planner that goes off-script cannot widen
   itself. If the implementer finds no such location, that is a blocking finding to raise, not a
   reason to fall back to (c).
2. **DP-2 — RESOLVED at the plan gate (09-01-26): define zero as excluding gate reports.** The
   orchestrator's allowed roots become exactly the run's own review records under the plans dir
   (`<plans-dir>/<slug>-MM-DD-YY/*-review.md` and `sync-report.md`); everything else — all product
   files, all docs, the rest of the plans dir — is denied. Script-mediating the findings append was
   rejected as circular: `report-verdict.sh` would need a body file that the reviewer must still
   write with Write/Edit, so the write does not disappear, it only moves. The real fix is that gate
   skills run in the orchestrator's own context and should be sub-agents with their own `reviewer`
   role — recorded here as **follow-up work, out of scope for this plan**. Until then, 4.2's wording
   must say "zero outside the run's gate reports" and must not claim a bare zero.
3. **DP-3 — DEFERRED at the plan gate (09-01-26): no backfill in this run.** Editing shipped
   history is not worth doing blind; revisit once Phase 6 has landed and the new failure mode is
   observable. Original framing below.
   **DP-3 — Backfill the five archived plans' dangling ask pointers?** Out of scope as written;
   they will keep failing check 6 until Phase 6 lands, and after it they will fail differently
   (no ask section at all). Editing shipped history is the user's call.
4. **Risk — the builder's child worktree has no marker.** 2.2 depends on solving this; if the walk
   cannot reliably find the sibling parent, the dispatcher must drop the marker into the child, and
   that is a `build-dispatch.md` change, not a hook change.
5. **Risk — fail-open is load-bearing.** Every phase here adds conditions to hooks that currently
   never deny on error. A bug that converts fail-open to fail-closed would block real work
   repo-wide. Phase 10's drill and each phase's negative controls exist for this.
6. **DP-4 — OPEN, needs the user: the `coder`/`contract-tester` role cannot be expressed by the
   current marker.** Phase 3 made `smart-test.sh` exit 0 for those two roles, closing the
   isolation breach on the READ side. But `--set-role` accepts only `orchestrator|planner|builder`
   (`workflow-setup.sh:80`), so **nothing can ever set those tokens and the fix is inert.** Lane 4
   investigated and found this is not a matter of adding two strings: `dae-role` is ONE FILE PER
   WORKTREE, while a builder and its `coder` and `contract-tester` all run concurrently in the SAME
   lane worktree. A per-worktree file structurally cannot say which of three concurrent agents is
   writing. Closing it needs a per-AGENT signal, which is a design change with its own plan — and
   it must stay structural (a marker the agent cannot write), never an env var the agent can set,
   per `structural-anti-cheating`. **Until it is closed, Phase 3's fix is dormant, not working.**
   Recorded here rather than quietly shipped as done.
7. **Deferred — I3b.** `if`-guarding `branch-squash-guard.sh` saves a fork per non-git command but
   risks silently disarming main protection if `if` matching and the script's own parsing diverge.
   Not worth the tail for the gain; revisit only with a test that proves equivalence.

## Skill mapping

| Work | Skill / agent |
|---|---|
| Phases 1–5, 7 (hooks, scripts, their tests) | `builder` → `coder` + `contract-tester`, lane 1 / lane 3 |
| Phase 6 (plan machinery, rules, planner, gate) | `builder`, lane 2 |
| Phases 8–9 (dae skill files, docs) | `builder`, lane 4 |
| Plan gate | `review-plan` |
| Code gate | `review-code` |
| Record | `document-local` |
| Ship | `push-main` (this repo: no PRs) |
