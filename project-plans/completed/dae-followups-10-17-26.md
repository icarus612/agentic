# dae-followups — fix the three dae-tooling-gaps follow-ups

### Ask of record

**10-17-26** — "fix all 3", referring to the three follow-ups left open by dae-tooling-gaps (archived at project-plans/completed/dae-tooling-gaps-10-15-26.md, landed d696b46 + 089c0da):
1. parent-tree-guard in push-main repos (this agentic repo): plan promotion (`plan-lifecycle.sh promote`) and archive (`plan-lifecycle.sh archive`) are denied as "product file changed in the run's parent worktree", because push-main repos have no push-pr open-draft/finalize stage to own those moves. Observed: the promotion was flagged under the orchestrator role AND under the planner role (planner should be allowed to write the plans dir — investigate why), and the archive move (project-plans/completed/<slug>.md) was flagged under the orchestrator role on 10-16-26.
2. smart-test.sh has no internal timeout or forced kill: run_contained cleans up only on TERM/INT/HUP/EXIT (relies on assumption A1 that the harness sends a catchable signal). Add a per-run time bound (plan's DP-3 suggestion: e.g. CLAUDE_HOOKS_TEST_TIMEOUT) and escalate TERM -> KILL on the process group.
3. smart-test.sh JS package mode (DP-4): a source edit runs the owning package's entire test suite on every edit. Narrow it to the tests related to the edited file (e.g. the runner's related-tests mode), keeping the owning-package scoping from dae-tooling-gaps.
No attribution trailers of any kind — no Co-Authored-By, no Claude-Session, no session URL — in any commit or PR text. Never force-push. Lands via push-main (agentic repo).

## Phase syllabus
- [x] Phase 1: Red regression tests
  - [x] 1.1: Guard names the plans-ledger when a sticky verdict denies   (lane 1)
  - [x] 1.2: push-main promote and archive blocks leave a guard-clean tree   (lane 1)
  - [x] 1.3: smart-test per-run timeout with TERM→KILL escalation   (lane 2)
  - [x] 1.4: smart-test JS package mode runs related tests only   (lane 2)
- [x] Phase 2: Fixes
  - [x] 2.1: parent-tree-guard reports ledger-sticky denials as such   (lane 1, after: 1.1)
  - [x] 2.2: push-main owns plan promotion and archive as chained commits   (lane 1, after: 1.2)
  - [x] 2.3: run_contained gets a watchdog and escalating group kill   (lane 2, after: 1.3)
  - [x] 2.4: JS package mode uses the runner's related-tests mode   (lane 2, after: 1.4, 2.3)
- [x] Phase 3: Verify and record
  - [x] 3.1: Whole suite, bash -n, guard replay   (after: 2.1, 2.2, 2.3, 2.4)
  - [x] 3.2: Docs-root pages updated at Record   (after: 3.1)

## Goal & scope

Fix the three follow-ups that `project-plans/completed/dae-tooling-gaps-10-15-26.md` left open (its "Follow-ups" section and DP-3/DP-4, plus the push-main guard denials observed afterwards).

**Defect 1. In push-main repos, parent-tree-guard denies plan promotion and archive.**

The root cause was reproduced in a scratch repo against this worktree's hooks. The script is described under Risks.
- `plan-lifecycle.sh` only moves files. Its header says "this script mutates, callers commit" (`agent-agnostic/hooks/plan-lifecycle.sh:44-48`). An uncommitted `promote` or `archive` leaves `project-plans/<slug>/plan.md` (or `project-plans/completed/<slug>.md`) dirty in the parent worktree.
- The guard runs as PostToolUse after that Bash call. Under `orchestrator` it allows only `*-review.md` and `sync-report.md` in the plans dir (`parent-tree-guard.sh:311-323`), so it denies. Reproduced: step [3] gives exit 2 after promote, and step [6] gives exit 2 on `completed/x-01-02-26.md` after archive.
- **Why the planner was flagged.** The guard writes each plans-dir verdict to `.artifacts/plans-ledger`, keyed on `<content-hash> <abs-path>`. A matching `deny` line is checked *before* the current role's rule (`parent-tree-guard.sh:359-366`). This is deliberate: "a denied edit is never laundered by a later role" (`docs/pipeline.md:229-234`, commit `92d7771`). The orchestrator's uncommitted promote therefore writes `deny <hash> …/plan.md`. After `--set-role planner`, the same unchanged file hits that line and is denied again, with the *planner* message: "the planner writes only the plans dir". That contradicts the planner's own allow rule (`:291-295`). Reproduced: step [4] gives exit 2 under `planner`, and the ledger holds `ok <H> …/proposals/x.md` next to `deny <H> …/x/plan.md`, with the same hash.
- **Why push-pr repos rarely see it.** `push-pr --stage finalize` runs archive and commit in ONE chained call, "so the tree is never left with a staged plan move between calls" (`agent-agnostic/skills/push-pr/SKILL.md:75-81`). `open-draft` commits the promoted dir right after promotion (`:37`). push-main (`.claude/skills/push-main/SKILL.md`) has neither stage, so in this repo nothing commits these moves.
- **Fix, without widening the orchestrator's scope:**
  - push-main gains push-pr's chained-commit discipline for both moves (2.2). The guard then only ever sees a clean tree, so it never writes a deny verdict.
  - The guard's role table is untouched.
  - The guard's denial message is corrected so a ledger-sticky denial says so (2.1). Today's message is what made the planner case look inexplicable.

**Defect 2. `smart-test.sh` has no internal time bound.**
- `run_contained` (`smart-test.sh:298-314`) waits forever.
- Cleanup sends only `TERM`, from the `EXIT`/`TERM`/`INT`/`HUP` traps (`:287-296`), so it relies on assumption A1. A child that ignores TERM survives every path.
- The fix adds a per-run watchdog (`CLAUDE_HOOKS_TEST_TIMEOUT`) and changes every group kill to TERM, then a grace period, then KILL.

**Defect 3. JS `package` mode runs the owning package's whole suite on every source edit** (`smart-test.sh:773-784`).
- The fix narrows it to the runner's related-tests mode for the edited file.
- It keeps `find_js_package_dir` owning-package scoping (`:599-616`) and `select_js_runner` (`:618-626`).

**Out of scope:**
- Changing the universal dae router's bare `plan-lifecycle.sh promote` step (`agent-agnostic/skills/dae/build.md:19`, `diagnose.md:15`, `live.md:40`, `SKILL.md:146,161`). The same transient denial happens there in push-pr repos too, until open-draft commits. See DP-1.
- The ledger's verdict semantics (hash+path keying, deny-first).
- Go/Python runner selection.
- JS `focused` mode.
- The test-file-edit branch (`:663-698`).
- The `require_tests` scratchpad exemption noted in the prior plan's Risks.
- Moving the real file `agent-agnostic/hooks/README.md` into the docs root. That is a pre-existing doc-format deviation and is not touched.

## Stack & MAJOR versions

| Unit | Version / constraint | Verified from |
|---|---|---|
| Hooks | bash, with **bash 3.2/macOS compatibility required**. No `timeout`/`setsid` (GNU/util-linux only), no `wait -n`, no associative arrays. `printf -v` is used already (`smart-test.sh:311`). | prior plan DP-2 (`dae-tooling-gaps-10-15-26.md:336-337`); `smart-test.sh:304-307` uses `set -m` |
| vitest | 3.2.4. `cli.command("related [...filters]")`. `related` defaults `passWithNoTests ??= true`. Paths resolve via `resolve(root, file)`, so absolute paths are fine. `--run` disables watch (`if (options.run) options.watch = false`). 2.1.9 also defines `related` and handles `run`. | installed `/home/icarus64/repos/money-makers/triple-m/node_modules/.pnpm/vitest@3.2.4_…/node_modules/vitest/dist/chunks/cac.Cb-PYCCB.js:1335,1369-1382`, `coverage.DL5VHqXY.js:3807`, `cli-api.BkDphVBG.js:10538` (the plan gate confirmed these there; an identical 3.2.4 copy also exists under `/home/icarus64/repos/money-makers/mythic-made/node_modules/.pnpm/vitest@3.2.4_…/`); `/home/icarus64/repos/money-makers/triple-m/node_modules/.pnpm/vitest@2.1.9_…/node_modules/vitest/dist/chunks/cac.CB_9Zo9Q.js` |
| jest | 29.7.0. `--findRelatedTests` is boolean, and file paths are positional and required. `--passWithNoTests` exists. Without it, "no tests found" fails. | `~/.cache/yarn/v6/npm-jest-cli-29.7.0-…/node_modules/jest-cli/build/args.js:50-56,274-280,438-442`. No project-installed jest exists on this machine, so the yarn cache copy is the only binary source available. |
| Claude Code hook timeout | Default 600 s for `command` hooks. The doc does not state the cancel signal or whether the process group is signalled, so A1 stays unverifiable. | code.claude.com/docs/en/hooks (fetched 10-17-26). `agent-specific/claude/settings.json:181-184` sets no `timeout` on smart-test. |
| Test harness | plain bash suites, `N passed, M failed` summary line | `tests/parent-tree-guard.test.sh`, `tests/push-pr-plan-archive.test.sh`, `tests/smart-test-process-cleanup.test.sh` |

Baselines (run 10-17-26 in this worktree):
- `parent-tree-guard.test.sh`: 55 passed, 0 failed
- `smart-test-process-cleanup.test.sh`: 6/0
- `smart-test-role-scope.test.sh`: 7/0
- `push-pr-plan-archive.test.sh`: 6/0
- `plan-lifecycle.test.sh`: 38/0

## Conventions to enforce

- **Source → push → sync** (`.claude/rules/source-push-sync.md`):
  - Edit only in this repo (`agent-agnostic/`, `tests/`, `.claude/skills/push-main/`), never `~/.claude/`.
  - Land with `push-main`, then run `sync-install.sh <range>`. There is no PR.
  - `.claude/skills/push-main/` is project-scoped and syncs nowhere.
- **No attribution trailers of any kind.** No `Co-Authored-By`, no `Claude-Session`, no session URL in any commit. This includes the commit messages inside the new push-main blocks.
- **Never force-push. Name paths in `git add`/`git commit`**, never bare `-A` (`shell-discipline`).
- **Guard twins stay identical.** `find_parent_worktree`, `find_lane_root`, `resolve_role` and `resolve_root_dir` are "copied verbatim" between `parent-tree-guard.sh` and `scope-writes.sh` (`parent-tree-guard.sh:112,196,263`). 2.1 touches none of them. `scope-writes.sh` is not in any file scope.
- **Blind-role short-circuit untouched** (`smart-test.sh:189-218`). Exit-code contract unchanged: failure is exit 2 via `exit_with_test_failure`.
- **Contract tests are blind.** Contract tests are written from the contract text and never read the implementation, as in the existing suite headers (`tests/parent-tree-guard.test.sh:21-24`).
- **Every spawned test process is bounded and reaped** with an anchored `pgrep -f '^sleep <token>$'` pattern. The prior plan records the self-match hazard (`dae-tooling-gaps-10-15-26.md` Risks).
- **Minimal comments** (`minimal-code-comments`). `check-diff-hygiene.sh` gates builder teardown.
- **Assert on summary-line content**, never on exit status alone (`shell-discipline`, `verify-dont-assume`).

## Phase 1: Red regression tests

### 1.1 — Guard names the plans-ledger when a sticky verdict denies

- **File scope:** `tests/parent-tree-guard.test.sh` (append cases after `case35`, before the summary).
- **Pattern:** the existing ledger cases `case33`–`case35`, plus the fixture helpers `new_parent_worktree_with_role` / `run_guard`.
- **Reproduction (observed 10-17-26 in a scratch repo):**
  1. Use a linked parent worktree with role `planner`. Write `proposals/x-01-02-26.md` and run the guard: exit 0.
  2. Flip to `orchestrator` via `workflow-setup.sh --set-role`. Run `plan-lifecycle.sh promote` uncommitted, then the guard: exit 2.
  3. Flip to `planner` and run the guard: exit 2, stderr "the planner writes only the plans dir".
  4. Expected: still exit 2, since the deny verdict sticks by design, but stderr must state that the verdict was recorded earlier in `plans-ledger` and is not a judgment under the current role.
- **New cases:**
  - **36:** the sequence above. Assert exit 2, assert stderr matches `plans-ledger`, and assert stderr does NOT contain the bare planner line "the planner writes only the plans dir" for a path that only the ledger denied.
  - **37:** control. A fresh orchestrator-role product write (not ledger-derived) still prints today's orchestrator line and no `plans-ledger` mention.
- **Acceptance:**
  - Red on today's guard: 36 fails on the stderr assertion.
  - 37 is green before and after.
  - Cases 01–35 unchanged.
- **Test oracle:** new contract tests.

### 1.2 — push-main promote and archive blocks leave a guard-clean tree

- **File scope:** `tests/push-main-plan-lifecycle.test.sh` (new).
- **Pattern:** `tests/push-pr-plan-archive.test.sh`. That test extracts the `<!-- plan-archive -->` sh fence from a SKILL.md with `awk`, checks its placement, and runs it in a scratch repo with `PATH="$HOOKS_DIR:$PATH"`.
- **Markers under test:** `<!-- plan-promote -->` and `<!-- plan-archive -->` in `.claude/skills/push-main/SKILL.md`. Each must occur exactly once and open a sh fence. Inputs are the env vars `PROPOSAL`, `PLAN_SLUG`, `PLANS_DIR`, `PLAN_DIR`, mirroring push-pr's names.
- **Fixture:**
  - A main repo plus a **linked worktree** carrying `.artifacts/progress-log.md` and `dae-role`, so the real guard is in force.
  - Role `orchestrator` when each block runs. Proposals are written under role `planner` and the guard is run once, so the ledger holds the planner's `ok` line, as in a real run.
- **Cases:**
  - **00/01:** each marker exists once and opens a sh fence. `plan-promote` sits in a section naming the post-approval promotion. `plan-archive` sits before step 2 (squash-merge) of "How it works".
  - **02:** promote with an **untracked** proposal plus a `.plan-review.md` sibling. The block exits 0, `$PLAN_DIR/plan.md` and `plan-review.md` are in `HEAD`, `git status --porcelain -- "$PLANS_DIR"` is empty, the guard exits 0, and the ledger has no `deny` line.
  - **03:** the same with a **tracked** proposal (committed before promotion). The tree is clean, so the staged deletion of the proposal path is in the commit too.
  - **04:** after 02, `workflow-setup.sh --set-role planner`, then the guard exits 0. This is the direct regression for the planner-role flag.
  - **05:** archive on a fully ticked, committed plan dir. The block exits 0, `completed/<slug>.md` is in `HEAD`, the plan dir is gone, the tree is clean, and the guard exits 0 under `orchestrator`.
  - **06:** archive refusal is preserved. On a plan with an unchecked subphase the block exits non-zero, nothing is committed, and `HEAD` is unchanged.
  - **07:** the HEAD commit messages are `chore(plans): promote <slug>` / `chore(plans): archive <slug>` and contain no `Co-Authored-By`/`Claude-Session`/`claude.ai/code/session`. This is a positive-control grep against a string seeded into a scratch file.
- **Acceptance:** red today, with 00 failing because neither marker exists in push-main's SKILL.md.
- **Test oracle:** new contract tests.

### 1.3 — smart-test per-run timeout with TERM→KILL escalation

- **File scope:** `tests/smart-test-timeout.test.sh` (new).
- **Pattern:** `tests/smart-test-process-cleanup.test.sh`. Reuse its `new_fixture`, `payload`, token helpers, pnpm gating (`SMART_TEST_REQUIRE_PNPM`) and `cleanup` reaping. Bound every hook run with the suite's own wall-clock wrapper; the existing suite uses GNU `timeout 120` in the test harness only.
- **Cases** (all use `CLAUDE_HOOKS_TEST_KILL_GRACE=1`):
  - **01:** a package test body that hangs (`sleep <tok>`) with `CLAUDE_HOOKS_TEST_TIMEOUT=2`. The hook returns within a bound well under the wrapper (assert elapsed ≤ 15 s), exits 2, stderr names the timeout ("timed out after 2s" or similar, pinned in the contract), and `sleep <tok>` is gone.
  - **02:** the body ignores TERM (`trap '' TERM; sleep <tok>`) with timeout 2. Same assertions. Proves the KILL escalation, since an ignored disposition is inherited across exec. The positive control: the same body run directly survives a plain `kill -TERM`.
  - **03:** the trap path escalates. Use no timeout (`CLAUDE_HOOKS_TEST_TIMEOUT=0`) and a TERM-ignoring body. Send `kill -TERM` to the hook pid, and `sleep <tok>` must be gone within grace plus slack. Red today, because the trap sends TERM only.
  - **04:** the watchdog leaves nothing behind. A fast passing body with `CLAUDE_HOOKS_TEST_TIMEOUT=7<rand>`. The hook exits 0, and no `sleep 7<rand>` process survives the hook's return. The positive control: during a slow body the watchdog's sleep IS visible.
  - **05:** a fast failing body (`exit 1`) under a timeout still exits 2 with the normal failure message and no timeout wording.
  - **06:** `CLAUDE_HOOKS_TEST_TIMEOUT=0` disables the bound. A 3-second body passes with exit 0 and no timeout wording.
- **Acceptance:** red today on 01, 02 and 03 (hang or survivor), and on 04 only if the watchdog leaks once added. 05 and 06 are green-before invariants.
- **Test oracle:** new contract tests.

### 1.4 — smart-test JS package mode runs related tests only

- **File scope:** `tests/smart-test-related.test.sh` (new).
- **Pattern:** as 1.3. Fixtures add an executable fake runner at `packages/a/node_modules/.bin/vitest` (or `jest`). It appends its argv, one invocation per line, to `packages/a/runner-argv.log` and exits 0, or the exit code the case sets. `pkg-test.sh` touches `pkg-ran` (the full-suite marker), as the existing fixture does.
- **Cases** (source edit to `src/foo.ts` with `src/foo.test.ts` present, modes `focused,package`):
  - **01 vitest:** the log has a line containing `related`, `--run` and the absolute path of `src/foo.ts`. `pkg-ran` is absent and `root-ran` is absent.
  - **02 jest:** the log has `--findRelatedTests`, `--passWithNoTests` and the absolute `src/foo.ts`. `pkg-ran` is absent.
  - **03:** related failure propagates. The fake runner exits 1 on a `related`/`--findRelatedTests` invocation, so the hook exits 2 and stderr carries the runner output.
  - **04:** no direct runner (no `node_modules/.bin/vitest|jest`). Package mode still runs `pnpm test` in the owning package, so `pkg-ran` is present (DP-7 decided: A). This is a green-before invariant.
  - **05:** a test-file edit (`src/foo.test.ts`) is unchanged. The runner is invoked with `run src/foo.test.ts`, with no `related`.
- **Acceptance:** red today on 01 and 02 (`pkg-ran` present, no related invocation). 04 and 05 are green before and after.
- **Test oracle:** new contract tests.

## Phase 2: Fixes

### 2.1 — parent-tree-guard reports ledger-sticky denials as such

- **File scope:** `agent-agnostic/hooks/parent-tree-guard.sh` only. The classification loop is at `:339-373` and the message block at `:377-401`.
- **Change:**
  - Record which offenders came from the `deny` ledger hit at `:361-363`, for example in a second array.
  - For those, print a distinct line saying the change was denied when it first appeared, under the role active then, and that the verdict sticks to its content hash in `<ledger path>`. Remedy: revert, or commit through the owning stage.
  - Print the role-specific trailer only when at least one offender was judged under the current role.
  - Verdict semantics, exit codes, role table and twin functions are unchanged.
- **Pattern:** the existing per-role message `case` at `:381-400`.
- **Acceptance:**
  - 1.1's cases 36 and 37 pass.
  - `bash tests/parent-tree-guard.test.sh` gives `57 passed, 0 failed`.
  - `tests/mark-syllabus-guard-e2e.test.sh` and `tests/l6-role-escalation-e2e.test.sh` stay green.
  - `bash -n` exits 0.
- **Test oracle:** the 1.1 regression test plus the existing suite.

### 2.2 — push-main owns plan promotion and archive as chained commits

- **File scope:** `.claude/skills/push-main/SKILL.md` only.
- **Change:**
  - Add a section (e.g. "Plan lifecycle in this repo") stating that push-main has no `open-draft`/`finalize`. Therefore, in this repo, the dae router's post-approval "`plan-lifecycle.sh promote`, then **Open the draft PR**" pair is replaced by the `<!-- plan-promote -->` block, and `update` is a no-op (there is no remote branch).
  - The block runs from the parent worktree as ONE chained Bash call: promote, then stage exactly the new plan dir plus any tracked proposal paths the move vacated, then `git commit -m "chore(plans): promote $PLAN_SLUG" -- <those paths>`.
  - Explain the reason in one sentence: the write-scope hooks read the tree after every Bash call, and a dirty promotion is denied and sticks in the plans-ledger. This mirrors push-pr `:75-76`.
  - Add **step 0** to "How it works", before step 1 Verify: run `plan-lifecycle.sh check "$PLANS_DIR"`, then the `<!-- plan-archive -->` block in the workflow worktree, after Record ticked the syllabus. That block is `plan-lifecycle.sh archive "$PLAN_DIR" && git commit -m "chore(plans): archive $PLAN_SLUG" -- "$PLAN_DIR" "$PLANS_DIR/completed/$PLAN_SLUG.md"`.
  - The archive therefore lands inside the squash, matching `plan-format` ("nothing is ever committed to the base after a merge"). It does not land as a second commit on main the way `089c0da` did.
  - An `archive` refusal stops push-main. Never `--force-incomplete`.
  - A run with no `plan.md` skips the step.
- **Pattern:** `agent-agnostic/skills/push-pr/SKILL.md:37` (commit the promoted dir) and `:75-83` (chained archive block, marker, refusal semantics).
- **Exact staging form:** left to the coder, constrained by 1.2's cases 02 and 03. An untracked proposal needs an explicit `git add -- "$PLAN_DIR"`, and a tracked one leaves a staged deletion that must be inside the commit's pathspec. Assumption A5 covers this.
- **Acceptance:**
  - `bash tests/push-main-plan-lifecycle.test.sh` passes in full.
  - `bash tests/push-pr-plan-archive.test.sh` gives `6 passed, 0 failed`; push-pr is untouched, as a regression guard on the shared marker name.
- **Test oracle:** the 1.2 regression test plus the existing suite.

### 2.3 — run_contained gets a watchdog and escalating group kill

- **File scope:** `agent-agnostic/hooks/smart-test.sh`. This covers `load_config` (`:111-126`), the CONFIGURATION header (`:15-18`), `kill_contained_group` and the traps (`:285-296`), and `run_contained` (`:298-314`).
- **Change:**
  - **Config.** `load_config` exports `CLAUDE_HOOKS_TEST_TIMEOUT` (default 300, DP-4 decided: A) and `CLAUDE_HOOKS_TEST_KILL_GRACE` (default 3). Non-integer values fall back to the default with one stderr warning. `0` disables the timeout. Document both in the header.
  - **Group kill.** One helper, e.g. `kill_group_escalating <pgid>`, sends `kill -TERM -- -<pgid>`, polls `kill -0 -- -<pgid>` in short steps (`sleep 0.1`, which works under BSD and GNU sleep) up to the grace, then sends `kill -KILL -- -<pgid>`. Both the post-`wait` reap in `run_contained` and `kill_contained_group` (the traps) use it.
  - **Watchdog.** When the timeout is > 0, launch a watchdog in its **own** process group under the same `set -m` bracket, so killing its group also kills its `sleep`. It sleeps for the timeout, writes a flag file, then calls the escalating kill on `RUN_CONTAINED_PID`'s group. After `wait` returns, kill the watchdog group; the traps kill it too.
  - **Timeout reporting.** If the flag exists, `run_contained` returns non-zero and prefixes the captured output with `smart-test: timed out after <N>s (process group TERM→KILL)`. Callers already format and report failures, so a timeout surfaces as exit 2 (DP-5 decided: A).
  - **Unchanged:** no GNU `timeout`, no `setsid`. `set -e` safety is preserved (`wait … || rc=$?`). All 15 call sites keep their current signature.
- **Pattern:** the existing `run_contained` and its traps, and prior plan 2.5 (`dae-tooling-gaps-10-15-26.md:286-293`).
- **Acceptance:**
  - `bash tests/smart-test-timeout.test.sh` passes in full.
  - `smart-test-process-cleanup.test.sh` gives `6 passed, 0 failed`.
  - `smart-test-role-scope.test.sh` gives `7 passed, 0 failed`.
  - `bash -n` exits 0.
  - `grep -nE '(^|[^-])\btimeout\b +[0-9]|setsid|wait -n' agent-agnostic/hooks/smart-test.sh` finds no executable use. Give it a positive control on a scratch line.
- **Test oracle:** the 1.3 regression test plus the existing suite.

### 2.4 — JS package mode uses the runner's related-tests mode

- **File scope:** `agent-agnostic/hooks/smart-test.sh`. This covers the `"package"` arm in `run_javascript_tests` (`:773-784`) and a new sibling helper next to `select_js_runner` (`:618-626`). It is serialized after 2.3 because the file is the same.
- **Hard constraint:** `select_js_runner`'s output must stay unchanged (`node_modules/.bin/vitest run` / `node_modules/.bin/jest`). The focused arm and the test-file branch depend on it, and 1.4 case 05 asserts `run src/foo.test.ts`. The related-mode command goes in a new sibling helper (e.g. `select_js_related_runner <pkg_dir>`), never in an edit to `select_js_runner`.
- **Change:**
  - In the source-file branch's package arm, when `select_js_runner` found a direct runner, run its related mode on the **absolute** edited file inside `pkg_dir` via `run_contained`:
    - vitest: `node_modules/.bin/vitest related --run "$file"`
    - jest: `node_modules/.bin/jest --findRelatedTests --passWithNoTests "$file"`
  - With no direct runner, keep `$pkg_manager test` (DP-7 decided: A).
  - Update the progress line from "Running all tests..." to say related tests.
  - Unchanged: `select_js_runner`'s output, `find_js_package_dir`, `focused` mode, the test-file branch, the "no runner / missing test" semantics, and the default `CLAUDE_HOOKS_TEST_MODES`.
- **Pattern:** the focused arm's `runner`-vs-`pkg_manager` split (`:751-757`).
- **Acceptance:**
  - `bash tests/smart-test-related.test.sh` passes in full.
  - 1.3's suite and both existing smart-test suites stay green.
  - `bash -n` exits 0.
- **Test oracle:** the 1.4 regression test plus the existing suite.

## Phase 3: Verify and record

### 3.1 — Whole suite, bash -n, guard replay

- **File scope:** none (read-only).
- **Steps:**
  - Run `bash -n` on `parent-tree-guard.sh` and `smart-test.sh`.
  - Run every `tests/*.test.sh` with one `bash tests/<x>.test.sh` call per file, asserting on each `N passed, M failed` line (`M` = 0).
  - Replay the defect-1 scratch reproduction (see Risks) against the worktree hooks. Steps [3], [4] and [6] must still deny, since the guard is unchanged in substance, and [4] must now name the ledger. Then run the same flow through the push-main blocks and confirm every guard pass gives exit 0.
- **Acceptance:** every suite reports 0 failed. A failing suite outside this plan's scopes is compared against `main` (`089c0da`) before it is attributed to this run.
- **Test oracle:** existing suite.

### 3.2 — Docs-root pages updated at Record

- **Executed by:** `documenter` (`document-local`). Builders are denied `docs/`.
- **File scope:** `docs/pipeline.md`.
  - In the `parent-tree-guard.sh` clause (`:228-234`), add that a ledger-sticky denial is reported as such, naming the ledger.
  - Near the `sync-install.sh`/`push-main` mention (`:200`), add one clause, only if that paragraph speaks to landing: in this repo `push-main` commits plan promotion and archive as chained calls.
  - No page documents smart-test's configuration (verified: `grep -n smart-test docs/*.md` hits only `architecture.md:51,98`, which are listings). The new variables stay documented in the hook's own CONFIGURATION header. Do not create a page.
- **Acceptance:** each added statement matches the shipped code, and no page carries a now-false claim. Verify with `git grep -n 'plans-ledger' docs/`, with a positive control on a known existing string.
- **Test oracle:** existing implementation.

## Risks, open questions, decision points

### Decision points — settled by the user at the plan gate (10-17-26, round 1 tentative/proceed, approved)

- **DP-1 — Where the promotion commit lives. DECIDED: A, push-main only** (2.2). The orchestrator in this repo uses push-main's `plan-promote` block in place of build.md's bare promote plus open-draft.
  - Rejected B: also make the universal router chain `promote && git add && git commit` (`dae/build.md:19`, `diagnose.md:15`, `live.md:40`, `SKILL.md:146,161`). It would also remove the transient denial in push-pr repos (where push-pr's open-draft step 1 already tolerates "if not already committed", `push-pr/SKILL.md:37`), but it is a broader universal change. Recorded as a follow-up below.
- **DP-2 — The guard message change (2.1). DECIDED: A, include it.** It is what would have answered "why was planner flagged".
  - Rejected B: drop it, leaving lane 1 as SKILL.md plus its test.
- **DP-3 — When push-main archives. DECIDED: A, on the workflow branch before the squash**, per `plan-format`. Consequence: a syllabus subphase that can only run after landing (like the prior plan's 3.3 post-install drill) blocks the archive, so this repo's plans keep post-landing drills out of the syllabus.
  - Rejected B: archive in a second push-main landing after post-landing checks, as `089c0da` did. It conflicts with `plan-format`.
- **DP-4 — Default `CLAUDE_HOOKS_TEST_TIMEOUT`. DECIDED: A, 300 s.** It stays below the harness's 600 s default.
  - Rejected B: 120 s, which risks false timeouts on cold vitest starts.
  - Rejected C: 540 s.
- **DP-5 — What a timeout means. DECIDED: A, a test failure, exit 2**, with a message naming the variable.
  - Rejected B: a warning, exit 0. It is non-blocking but hides hangs.
- **DP-6 — Shape of narrowing. DECIDED: A, change in place.** JS `package` mode with a direct runner becomes related-tests.
  - Rejected B: a new `related` mode plus a changed default `CLAUDE_HOOKS_TEST_MODES`, which changes user-facing config.
- **DP-7 — Package mode with no direct runner. DECIDED: A, keep the full `$pkg_manager test`** in the owning package.
  - Rejected B: skip package mode. Runner-less packages would lose all package coverage.

### Follow-ups (recorded, not planned here)

- **From DP-1:** chain the commit onto the universal dae router's `plan-lifecycle.sh promote` step, so push-pr repos also never show a transient denial or write a ledger deny line between promotion and open-draft.

### Assumptions not verified (for the review gate to challenge)

- **A1 (carried over).** The harness's cancel signal is undocumented (hooks doc, 10-17-26). 2.3's internal watchdog makes the tests' timing independent of A1, but a SIGKILL to the hook itself still bypasses the traps.
- **A4.** In this repo, the dae orchestrator learns that push-main replaces push-pr's stages by reading push-main's SKILL.md. No universal file names push-main, and none may (`AGENTS.md`, layout rule). Rule `source-push-sync` points to push-main for landing.
- **A5** (still open; the plan gate accepted delegating it to the red tests). `git commit -- <pathspec>` does not pick up untracked files, so the promote block needs an explicit `git add` of the new dir. A tracked proposal's staged deletion must be in the pathspec, or the tree stays dirty. This could not be checked locally because the planner's `git commit` was permission-denied. 1.2 cases 02 and 03 are the check.
- **A6.** jest's flags were verified only against a yarn-cache jest-cli 29.7.0, not a project install.

### Risks

- **Defect-1 reproduction script** (planner scratchpad, not committed). It runs these steps:
  1. `git init` and a linked worktree with `.artifacts/{progress-log.md,dae-role}`.
  2. As planner: write the proposal and run the guard (exit 0).
  3. Flip to orchestrator and run the guard (exit 0).
  4. `plan-lifecycle.sh promote` uncommitted, then the guard: exit 2, `…/x-01-02-26/plan.md`.
  5. Flip to planner and run the guard: exit 2, planner message.
  6. Commit and run the guard (exit 0).
  7. `archive` uncommitted, then the guard: exit 2, `…/completed/x-01-02-26.md`, porcelain `R  …plan.md -> …completed/x-01-02-26.md`.

  3.1 re-creates it from these steps.
- **Watchdog leaks.** If the watchdog shares the hook's group, killing the watchdog subshell orphans its `sleep`. 2.3 requires the watchdog's own group, and 1.3 case 04 catches a leak.
- **Double execution.** With `focused,package`, a source edit with a sibling test runs that test once in focused mode and again in the related set. That is acceptable, and much cheaper than today's full suite.
- **vitest `forceRerunTriggers`.** Editing a config file that matches them makes `related` run everything (`cli-api.BkDphVBG.js:7851`). This is runner behavior, not a regression.
- **Dogfooding.** This run's own promotion and archive happen in this repo. After 2.2 lands in the worktree, the orchestrator can use the new blocks for this plan's archive. The promotion predates them and must be committed by hand in one chained call.

## Skill mapping

| Part | Executed by |
|---|---|
| 1.1, 1.2, 2.1, 2.2 (lane 1) | `builder` → `contract-tester` for 1.x, `coder` for 2.x |
| 1.3, 1.4, 2.3, 2.4 (lane 2) | `builder` → `contract-tester` for 1.x, `coder` for 2.x (2.3 before 2.4, same file) |
| 3.1 | orchestrator, read-only |
| 3.2 | `documenter` → `document-local`, at Record |
| Landing | `push-main`: archive block (2.2) on the workflow branch, squash into `main`, push with confirmation, no trailers. Then `agent-agnostic/hooks/sync-install.sh <range>`. |

**Lanes.** There are two, with disjoint file scopes and no shared touchpoint, so no integration subphase is needed:
- lane 1: `agent-agnostic/hooks/parent-tree-guard.sh`, `tests/parent-tree-guard.test.sh`, `.claude/skills/push-main/SKILL.md`, `tests/push-main-plan-lifecycle.test.sh`;
- lane 2: `agent-agnostic/hooks/smart-test.sh`, `tests/smart-test-timeout.test.sh`, `tests/smart-test-related.test.sh`.

Defects 2 and 3 share one lane because both edit `smart-test.sh`, and 2.4 is serialized after 2.3.
