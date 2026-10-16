# Fix five dae tooling defects found in the treehouse commerce7-rebuild run

### Ask of record

**10-16-26 — recorded verbatim from the caller's ask file**

**10-15-26** — Fix 5 tooling defects found during the treehouse-vineyards commerce7-rebuild run (evidence: /home/icarus64/repos/money-makers/treehouse-vineyards/.workflows/commerce7-rebuild/.artifacts/progress-log.md):
1. Finalize contract mismatch: agent-agnostic push-pr's finalize predicate (`validate-report.sh "$PR_REVIEW" | grep -qE 'verdict ready, next proceed'`) refuses a `tentative/proceed` PR verdict, while dae/build.md stage 7 says "On a ready/tentative verdict, push-pr --stage finalize" and review-pr defines tentative as mergeable. User decision: finalize ACCEPTS tentative — the predicate becomes `verdict (ready|tentative), next proceed`; update any prose/tests that state ready-only.
2. lane-artifact-shell-guard.sh bypass: a builder Bash command `cd <run-dir>/contracts && cat >> l8.md <<'EOF' …` (also `printf … >> contracts/l7.md` after cd into the run dir) is allowed (replay exit 0) while the absolute-path form is denied (exit 2). The guard resolves relative/bare destinations against the hook cwd, not the in-command `cd` target. Fix: track in-command `cd` (and `pushd`) targets when resolving relative destinations, or deny any write whose destination basename matches l<n>.md / l<n>-exit.md / *.agent when the command cd's into a run dir's contracts/reports/lanes. Add red-then-green tests for both shapes.
3. verify-run-scope.sh: doc-format-mandated symlinks into the docs root (e.g. apps/<app>/README.md -> ../../docs/apps/<app>/README.md, git mode 120000) are flagged UNCLAIMED. Treat a changed path that is a symlink whose target resolves inside the resolved docs root as harness-owned. Tests.
4. dae/build-dispatch.md step 1: make the exact per-lane command explicit — `verify-scope.sh <child-worktree> <parent-branch> --report <run-dir>/reports/<lane-id>-exit.md` — and state that piping `git diff --name-only` into verify-scope as the reported list is tautological and forbidden (it passed 8 lanes whose reports were actually unparseable).
5. smart-test.sh leaves orphaned vitest processes (≈90 observed, heavy load on builders). Find the cause (also the known cwd issue) and fix so test runs it spawns are cleaned up. Tests where feasible.
No attribution trailers of any kind — no Co-Authored-By, no Claude-Session, no session URL — in any commit or PR text. Never force-push.

User decisions this ask rests on (10-15-26, treehouse conversation): "Draft now, fix agentic (Recommended)"; contract side: "Finalize accepts tentative (Recommended)"; scope: "Shell guard cd-bypass, Docs symlink exemption, Per-lane --report wording, Vitest process leak".

## Phase syllabus

- [ ] Phase 1: Regression tests, observed red
  - [x] 1.1: Finalize predicate accepts `tentative/proceed` — gate-refusal suite cases flipped and added   (lane 1)
  - [x] 1.2: build-dispatch step 1 names the exact `--report` command — new text suite   (lane 1)
  - [x] 1.3: Shell guard denies lane-file writes reached through an in-command `cd`/`pushd` or the payload cwd   (lane 2)
  - [x] 1.4: verify-run-scope exempts symlinks into the docs root — new suite   (lane 3)
  - [x] 1.5: smart-test runs the owning package's tests and leaves no processes behind — new suite   (lane 4)
- [ ] Phase 2: Fixes
  - [x] 2.1: `push-pr` finalize predicate and the ready-only prose in `push-pr` and `dae/SKILL.md`   (lane 1, after: 1.1)
  - [x] 2.2: `build-dispatch.md` step 1 — the explicit per-lane command and the piped-diff ban   (lane 1, after: 1.2)
  - [x] 2.3: `lane-artifact-shell-guard.sh` — resolve destinations against a tracked in-command cwd   (lane 2, after: 1.3)
  - [x] 2.4: `verify-run-scope.sh` — docs-root symlinks are harness-owned   (lane 3, after: 1.4)
  - [x] 2.5: `smart-test.sh` — owning-package scope for source edits, and process-group containment   (lane 4, after: 1.5)
- [x] Phase 3: Verify, record, drill
  - [x] 3.1: Whole suite, `bash -n`, guard replay   (after: 2.1, 2.2, 2.3, 2.4, 2.5)
  - [x] 3.2: Docs-root pages updated at Record by the `documenter`   (after: 3.1)
  - [x] 3.3: Post-install drill — orchestrator, after `push-main` and `sync-install.sh`   (after: 3.2)

## Goal & scope

**Goal.** Close the five defects the treehouse-vineyards `commerce7-rebuild` run hit. That run is parked at Ship, with PR #1 still a draft, until defect 1 lands (progress-log lines 50-51).

**In.**
1. `push-pr --stage finalize` accepts a last PR-gate round of `tentative/proceed` as well as `ready/proceed`. Every statement that says ready-only changes to match.
2. `lane-artifact-shell-guard.sh` denies lane-file writes whose destination is relative or bare, resolving it through in-command `cd`/`pushd` targets and the payload `cwd`.
3. `verify-run-scope.sh` treats a changed path that is a symlink resolving inside the resolved docs root as harness-owned.
4. `dae/build-dispatch.md` step 1 spells out the exact `verify-scope.sh … --report …` command and forbids piping the diff in.
5. `smart-test.sh` scopes a source-file edit's JS tests to the package that owns the file. Every test process tree it spawns is contained in its own process group and killed when the hook exits or is signalled.

**Out.**
- Re-running the treehouse `finalize`. That belongs to the treehouse run, resumed by its own orchestrator after this lands. 3.3 only checks that the installed predicate would now pass.
- The `smart-test.sh` blind-role check. `smart_test_role()` (`smart-test.sh:196-217`) can never fire, because nothing writes `coder`/`contract-tester` into `dae-role`. That defect is owned by `project-plans/proposals/agent-identity-write-scope-09-26-26.md` subphase 2.4 (unapproved). It is not touched here. It contributes to builder load, because coders and testers also trigger suite runs, but it is not the leak.
- Whether JS `package` mode should stay in the default `CLAUDE_HOOKS_TEST_MODES` (`focused,package`, `smart-test.sh:114`). DP-4 decided: out of scope, recorded as a follow-up.
- Python/Go runner scoping. Only process containment applies to them (DP-1 decided: all 15 sites).
- `live.md` stage 4. It names `build-dispatch.md`'s sequence "by name" (`live.md:54-55`), so it picks up 2.2 without an edit.
- `docs/` pages. Builders are denied the docs root (`scope-writes.sh:44-47`). 3.2 does those pages at Record.

**Relationship to `agent-identity-write-scope-09-26-26.md` (unapproved proposal).** Disjoint, neither superseding nor depending. Both plans touch `smart-test.sh`, but that plan rewrites the role check (`:196-217`) and its suite `tests/smart-test-role-scope.test.sh`. This plan touches the runner call sites and the JS runner (`:289-778`) and adds a separate suite. Whichever lands second rebases across non-overlapping hunks.

## Stack & MAJOR versions

There is no language manifest or lockfile. The repo is shell scripts plus markdown (verified: no `package.json`/`*.json` at the worktree root). The tools were pinned by running them in this environment:
- **GNU bash 5.1.16** (`bash --version`). Hooks also target macOS: `smart-test.sh:577-579` comments on BSD sed portability. New shell code stays bash-3.2-safe, with no `setsid` dependence (DP-2 decided: `set -m`). It adds no new GNU-only dependency beyond the hooks' existing one, which is `realpath -m`.
  - BSD/macOS `realpath` lacks `-m`, yet `realpath -m` is already used throughout `agent-agnostic/hooks/`. Verified with `git grep -l 'realpath -m'`: `verify-run-scope.sh:46-47`, `verify-scope.sh`, `smart-test.sh`, `scope-writes.sh`, `parent-tree-guard.sh`, `plan-lifecycle.sh`, `allow-workflow-cleanup.sh` and `workflow-diff-check.sh`.
  - 2.4 follows that existing practice and does not remove the assumption. Making it portable is out of scope.
- **Python 3.11.7** (`python3 --version`), stdlib only. It is embedded in `lane-artifact-shell-guard.sh:9-122`.
- **git 2.34.1** (`git --version`).
- **pnpm** at `~/.nvm/versions/node/v24.15.0/bin/pnpm` and **jq** at `/usr/bin/jq`, both present. `smart-test.sh` depends on them. The new smart-test suite needs pnpm.
- `shellcheck` is **not installed** (`command -v shellcheck` empty). Syntax checking is `bash -n`.

## Conventions to enforce

- **Source → push → sync** (`.claude/rules/source-push-sync.md`): edit only under `agent-agnostic/` and `tests/`, never `~/.claude/`. Land with the `push-main` skill (squash into `main`, push, ask before pushing, never force-push). Then run `agent-agnostic/hooks/sync-install.sh <pushed-range>`. There is no PR.
- **No attribution trailers** in any commit: no `Co-Authored-By`, no `Claude-Session`, no session URL.
- **Test layout** (observed in `tests/*.test.sh`):
  - one `tests/<subject>.test.sh` per subject, runnable as `bash tests/<x>.test.sh` from any cwd, with `REPO_ROOT` derived from `BASH_SOURCE`;
  - `set -uo pipefail`;
  - `pass`/`fail` counters, an `N passed, M failed` summary line, exit 1 on any failure;
  - fixtures only under `mktemp -d`, removed by an `EXIT` trap, never writing inside the repo.
  - The whole suite is `for t in tests/*.test.sh; do bash "$t"; done` (`docs/reports/last-5-plans-landed-09-01-26.md:99`).
- **Minimal comments** (global rule). New tests carry a one-line header like `tests/lane-artifact-shell-guard.test.sh:2`, not the long banners of older suites. No per-test narration. Hook edits add at most one or two lines where the code cannot speak.
- **Verify the check.** `grep` here may be ugrep and `awk` may be mawk. Tests assert on output content as well as exit codes. Every "nothing found" assertion has a positive control in the same suite.
- **Tech-agnostic, `domain: universal`.** Everything edited lives in `agent-agnostic/`. No stack is assumed. JS handling stays behind the existing extension dispatch in `smart-test.sh:780-805`.
- **Skills reference each other by name, never by repo path** (`AGENTS.md`, "Nothing inside a skill or rule may reference this repo's layout").
- **Shell discipline.** One command per Bash call. `git -C`, never `cd && git`. Name paths when staging, never `git add -A`.

## Phase 1: Regression tests, observed red

Every 1.x lands red against the current tree. The detail block names the case that is red today, and the builder records the red output in the lane's exit report before the paired 2.x starts. Oracle for all of Phase 1: **new contract tests**.

### 1.1 — Finalize predicate accepts `tentative/proceed`

- **File scope:** `tests/push-pr-gate-refusal.test.sh`.
- **Defect, reproduced:**
  - The predicate block at `agent-agnostic/skills/push-pr/SKILL.md:58-61` (`<!-- pr-gate-check -->`) runs `validate-report.sh "$PR_REVIEW" | grep -qE 'verdict ready, next proceed'`.
  - `validate-report.sh:84` prints `OK: review report valid (round N: verdict <v>, next <n>, …)`, so a `tentative proceed 0 0` round prints `verdict tentative, next proceed` and the grep misses.
  - Observed today: case 06 expects refuse and passes, which is the defect encoded as a test. Expected per the user decision: proceed.
  - Treehouse evidence: progress-log line 50, "push-pr finalize REFUSED: predicate requires 'verdict ready, next proceed'; r2 is tentative".
- **Pattern to follow:** the existing `build_caseNN`/`run_case` table in the same file (`:241-379`). Fixtures are built with the real `report-verdict.sh`.
- **Changes:**
  - Case 06 becomes `tentative proceed 0 0 -> proceed (exit 0)`. Its comment line `tentative is not ready` goes. So does the header sentence (`:34-36`) that calls 06 a guard against ready-greps; that sentence is reworded to name 06 as the tentative-accept case.
  - New case 10: round 1 `tentative proceed`, round 2 `rejected impl-wrong 1 0` plus a blocking line → **refuse**. The last round governs.
  - New case 11: round 1 `rejected impl-wrong 1 0` plus a blocking line, round 2 `tentative proceed 0 0` → **proceed**.
  - `text-2` (`:395-404`): the literal it requires becomes `verdict (ready|tentative), next proceed` (`grep -F`, so the parens and pipe are literal).
  - New `text-4`: `SKILL.md`'s `### --stage finalize` step 1 sentence names `tentative`, and no longer contains the ready-only phrase `` must read `verdict: ready` / `next: proceed` ``.
  - New `text-5`: `agent-agnostic/skills/dae/SKILL.md` no longer contains `` `verdict: ready` + `next: proceed` ``, and its PR-gate enforcement sentence names `tentative`. Positive control: the same grep against the current file hits, which is why 1.1 is red.
- **Acceptance:** against the current tree, cases 06, 11, text-2, text-4 and text-5 fail. All other cases, including the new case 10, pass. Record the exact `N passed, M failed` line.
- **Test approach:** `bash tests/push-pr-gate-refusal.test.sh`, red now and green after 2.1.

### 1.2 — build-dispatch step 1 names the exact `--report` command

- **File scope:** `tests/build-dispatch-verify-scope.test.sh` (new).
- **Defect, reproduced:**
  - `agent-agnostic/skills/dae/build-dispatch.md:15` says only "`verify-scope.sh <child-worktree> <parent-branch>` fed the report's `## Files touched` list".
  - The treehouse orchestrator read "fed" as piping `git diff --name-only` in. That compares the diff with itself, so it passed every lane. The real check later failed with 316 UNCLAIMED (progress-log line 30).
- **Pattern to follow:** the text assertions in `tests/push-pr-gate-refusal.test.sh:383-415`: extract a section, normalize whitespace, `grep -F`.
- **Cases:**
  - **01.** Step 1 of `## Event-driven scheduling` (the paragraph starting `1. **Verify the lane**`) contains the literal `verify-scope.sh <child-worktree> <parent-branch> --report <run-dir>/reports/<lane-id>-exit.md`.
  - **02.** The same paragraph names `git diff --name-only` and calls piping it in forbidden. The assertion is the literal `git diff --name-only` plus one of the words `forbidden`/`never` in the same paragraph.
  - **03.** The paragraph no longer contains the ambiguous phrase `fed the report's`.
  - **04 (behavioral evidence, green before and after).** Build a `mktemp` git fixture whose exit report's `## Files touched` lists paths without the lane prefix. That is the l2/l5/l7 shape from progress-log line 30.
    - Piping `git diff --name-only <parent>..HEAD` into `verify-scope.sh` exits 0.
    - `verify-scope.sh <wt> <parent> --report <report>` exits 1 and prints `UNREPORTED:`.
    - This shows the prose fix matters and is the positive control for the tool's sensitivity.
- **Acceptance:** cases 01-03 fail against the current file. Case 04 passes.
- **Test approach:** `bash tests/build-dispatch-verify-scope.test.sh`.

### 1.3 — Shell guard denies writes reached through `cd`/`pushd` or the payload cwd

- **File scope:** `tests/lane-artifact-shell-guard.test.sh` (append only; existing cases unchanged).
- **Defect, reproduced** (replayed by this planner against the worktree's `agent-agnostic/hooks/lane-artifact-shell-guard.sh` with a builder payload, `cwd` `/tmp` unless noted):

  | Command | Exit today | Expected |
  |---|---|---|
  | `cat >> /w/run/.artifacts/contracts/l8.md <<'EOF'…` | 2 | 2 (control) |
  | `cd /w/run/.artifacts/contracts && cat >> l8.md <<'EOF'…` | 0 | 2 |
  | `cd /w/run/.artifacts && printf 'x' >> contracts/l7.md` | 0 | 2 |
  | `cd $RUN/reports && echo x > l2-exit.md` | 0 | 2 |
  | `pushd /w/run/.artifacts/lanes && echo a > l1.agent` | 0 | 2 |
  | payload `cwd=/w/run/.artifacts/contracts`, `cat >> l8.md <<EOF…` | 0 | 2 |
  | payload `cwd=/w/run/.artifacts`, `cp /tmp/x contracts/l3.md` | 0 | 2 |

  - **Cause, corrected from the ask's wording.** The guard does not resolve against the hook cwd at all. `is_target()` (`:44-47`) pattern-matches the token as written. `TARGET` (`:36`) needs a literal `.artifacts/` component, and `VAR_TARGET` (`:42`) applies only when the token contains `$`/`~`. A bare `l8.md` or `contracts/l7.md` matches neither, whatever the cwd.
- **Pattern to follow:** the existing `deny`/`allow` helpers and the `payload` builder (`:47-58`). Add an optional third `payload` argument for `cwd`, so the payload-cwd cases can set it. The default stays `/tmp`, so existing cases are unaffected.
- **New cases (16, labelled 11a-11p: 6 bypass-row denies + 4 extra denies + 6 allows):**
  - **deny** each of the six bypass rows above. Also deny:
    - `cd /w/run/.artifacts && cd contracts && tee l4.md`
    - `cd -P /w/run/.artifacts/reports && dd if=/tmp/a of=l1-exit.md`
    - `cd "$R" && cp /tmp/a contracts/l9.md`, a quoted variable cd with a relative tail
    - `cd /w/run/.artifacts/contracts; sed -i s/a/b/ l2.md`
  - **allow**:
    - `cd /w/run/.artifacts/contracts && cat l8.md` (read)
    - `cd /tmp && echo x > l8.md`, a lane-shaped basename outside a run dir
    - `(cd /w/run/.artifacts/contracts) ; echo x > l8.md` with payload cwd `/tmp`. The subshell's cd must not leak.
    - `cd /w/run/.artifacts/contracts && echo x > /tmp/l8.md`
    - `cd /w/run/.artifacts && echo x >> progress-log.md`
    - `cd /w/run/.artifacts/contracts && echo x > l1.md.bak`
  - **deny stderr:** for the bare `l8.md` case, stderr names the resolved path `/w/run/.artifacts/contracts/l8.md` and says `Write tool`. The existing `deny` helper already asserts both.
- **Acceptance:** every new deny case fails today with exit 0. Every new allow case passes. All 78 existing cases still pass. Baseline verified: `78 passed, 0 failed`.
- **Test approach:** `bash tests/lane-artifact-shell-guard.test.sh`.

- **Record note (shipped differently):** the lane 2 builder wrote its tests and fix without dispatching `coder`/`contract-tester`.

### 1.4 — verify-run-scope exempts docs-root symlinks

- **File scope:** `tests/verify-run-scope-docs-symlink.test.sh` (new).
- **Defect, reproduced:**
  - The treehouse branch carries four mode-`120000` entries: `apps/c7-app/README.md`, `apps/website/README.md`, `packages/config/README.md` and `packages/types/README.md` (verified with `git ls-files -s | grep ^120000` in the treehouse worktree).
  - `verify-run-scope.sh:156-166` exempts a changed path only by an exact or prefix match against `allowed`, which is `.gitignore`, the plans dir, the docs dir and any `--allow`. A symlink at `apps/x/README.md` matches none of them.
  - Treehouse evidence: progress-log line 48 records the PR gate rejected on 4 UNCLAIMED.
- **Pattern to follow:** `tests/verify-scope-parsing.test.sh`, the `new_git_worktree` fixture (`:114-125`), `run_script` (`:63-80`) and the scratch cleanup.
- **Cases:** each case builds a base commit, then a branch commit carrying the change, with an empty `reports/` run dir (zero exit reports, so no claims).
  - **01** `apps/web/README.md -> ../../docs/apps/web/README.md` (target file committed under `docs/`) → exit 0, `OK:`.
    - Today: exit 1, `UNCLAIMED: apps/web/README.md`.
  - **02** directory symlink `apps/web/docs -> ../../docs/apps/web` → exit 0.
  - **03** dangling symlink into the docs root (target not created) → exit 0. Resolution is lexical (`realpath -m`).
  - **04** symlink `apps/web/README.md -> ../../notes/README.md` (outside the docs root) → exit 1, `UNCLAIMED: apps/web/README.md`.
  - **05** lookalike prefix `apps/web/README.md -> ../../docs-old/README.md` → exit 1. Prefix matching must be by path component.
  - **06** regular file (not a symlink) `apps/web/README.md` → exit 1. Positive control: the scan still flags real product files.
  - **07** configured docs root: project `.claude/settings.json` with `{"env":{"CLAUDE_DOCS_DIR":"/documentation"}}`, symlink into `documentation/` → exit 0. A symlink into `docs/` in the same fixture → exit 1.
  - **08** symlink via an absolute target `$wt/docs/a.md` → exit 0.
- **Acceptance:** cases 01, 02, 03, 07 (first half) and 08 fail today. 04, 05, 06 and 07 (second half) pass.
- **Test approach:** `bash tests/verify-run-scope-docs-symlink.test.sh`.

### 1.5 — smart-test scopes to the owning package and leaves no processes behind

- **File scope:** `tests/smart-test-process-cleanup.test.sh` (new). Kept separate from `tests/smart-test-role-scope.test.sh` so the agent-identity proposal's 2.4 does not collide with it.
- **Cause, established by this planner** (code reading plus a live reproduction):
  - **(a) The cwd issue.** For a non-test source file, `run_javascript_tests` checks `[[ -f "package.json" ]]` and runs `$pkg_manager test` / `$pkg_manager test -- <test_file>` against the **hook process's `$PWD`** (`smart-test.sh:711`, `:725-727`, `:746-747`). It does not use the package that owns the edited file.
    - The owning-package walk added by `303a661` (`:607-619`) covers only the edited-file-is-a-test branch.
    - A builder's hook cwd is the parent worktree, not its lane child (treehouse progress-log line 60, "builder's cd does not persist into hook cwd").
    - The treehouse root `test` script is `turbo test`; both apps use `pnpm run test:unit -- --run --passWithNoTests` (verified with `jq`).
    - So every source-file edit by any builder ran `turbo test`, the full suite of every package, in the parent tree rather than the lane being edited. The focused call also ran `turbo test <path>`, which turbo parses as a task name and fails.
  - **(b) No containment.** Every runner call is a bare `$(…)` command substitution (`smart-test.sh:312, 350, 380, 399, 415, 453, 461, 516, 525, 548, 641, 652, 660, 725, 746`). The children share the hook's process group, and nothing kills them.
    - Reproduced: a fixture package whose `test` script is `sh -c "sleep 3171 & sleep 3171"`, hook started in the background, then `kill -TERM <hook pid>`. The hook exits 143, and `sh` and both `sleep` processes survive, reparented.
    - Any harness-side hook termination (timeout, cancellation, a stopped agent) therefore orphans the whole `pnpm → turbo → vitest → workers` tree.
    - (a) multiplies how many such trees exist and how long each runs, across concurrent builders. That matches the ~90-150 leftover vitest processes recorded at progress-log line 21.
- **Pattern to follow:** `tests/smart-test-role-scope.test.sh` for fixture and payload shape (flat JSON `tool_name`/`file_path`/`cwd` on stdin).
  - The hook is started in the background with `$!` captured.
  - Waits are bounded with `timeout N tail --pid=<pid> -f /dev/null` or `timeout N` around a `pgrep` poll. Never an unbounded wait.
  - Each run uses a per-run unique token in the fixture's spawned command (e.g. `sleep 7<random digits>`). Survivors are found with `pgrep -f "^sleep <token>$"`, which can never match the test's own shell. The `EXIT` trap kills them by the same anchored pattern.
- **Fixture:** a mini monorepo under `mktemp -d`.
  - Root `package.json`: `"test": "sh ./root-test.sh; turbo test"`. It contains `turbo`, so the orchestrator detector at `:612-614` classifies it as an orchestrator. `root-test.sh` touches `root-ran`.
  - `packages/a/package.json`: `"test": "sh ./pkg-test.sh"`. `pkg-test.sh` ignores its args and touches `pkg-ran`, and in the containment cases spawns the token process.
  - `packages/a/src/foo.ts` and `packages/a/src/foo.test.ts`. No `node_modules/.bin/vitest`, so the `$pkg_manager test` fallback is exercised.
- **Cases:**
  - **01** Edit `packages/a/src/foo.ts`, hook process cwd = fixture root → `root-ran` absent and `packages/a/pkg-ran` present.
    - Today: `root-ran` present (the root script ran), so red.
  - **02** Same edit, hook process cwd = an unrelated empty dir → `pkg-ran` present.
    - Today: nothing runs, because there is no `package.json` in `$PWD`. Red.
  - **03** Containment on signal: `pkg-test.sh` runs `sleep <token> & wait`. Start the hook, wait (bounded) until `pgrep -f "^sleep <token>$"` hits (that hit is the positive control), then send `kill -TERM <hook pid>` only. Within a bounded window, no `^sleep <token>$` survives.
    - Today: the sleep survives. Red.
  - **04** Containment on normal exit: `pkg-test.sh` runs `(sleep <token2> &); exit 0` → after the hook returns, no `^sleep <token2>$` survives. Positive control: the same command run directly, outside the hook, does leave the process, killed by the trap.
    - Today: survives. Red.
  - **05** Failure is still reported: `pkg-test.sh` exits 1 → the hook exits 2 and stderr contains `Tests failed` or `Focused tests failed`. This is existing behavior and passes today only once 01's scoping works, so it is listed as expected-green-after-2.5.
  - **06** Edited test file directly (`packages/a/src/foo.test.ts`) → `pkg-ran` present and `root-ran` absent. This is today's behavior from `303a661`, green before and after, a regression guard.
- **Prerequisite handling:** if `pnpm` is absent, print `SKIP: pnpm not on PATH` for cases 01-05 and count it as a failure only when `SMART_TEST_REQUIRE_PNPM=1`. This environment has pnpm, so the run here exercises everything.
- **Acceptance:** 01-04 fail today, and 06 passes. Record the output.
- **Test approach:** `bash tests/smart-test-process-cleanup.test.sh`.

## Phase 2: Fixes

Oracle for all of Phase 2: the paired 1.x suite goes green, plus the **existing suite** stays green. No new contract tests beyond Phase 1.

### 2.1 — `push-pr` finalize predicate and the ready-only prose

- **File scope:** `agent-agnostic/skills/push-pr/SKILL.md`, `agent-agnostic/skills/dae/SKILL.md`.
- **Changes** (enumerated with `git grep -nE 'verdict ready|verdict: ready|ready, next proceed|ready/proceed'` over `agent-agnostic/`, `docs/` and `tests/`; every non-test hit is listed here):
  - `push-pr/SKILL.md:60`: the predicate becomes `validate-report.sh "$PR_REVIEW" | grep -qE 'verdict (ready|tentative), next proceed'`.
  - `push-pr/SKILL.md:54`: "its **last** round must read `verdict: ready` / `next: proceed`" becomes "`verdict: ready` or `verdict: tentative`, with `next: proceed`".
  - `push-pr/SKILL.md:63`: "a last round that isn't ready/proceed" becomes "isn't ready/proceed or tentative/proceed".
  - `dae/SKILL.md:148`, the enforcement sentence: "its **last** round carries `verdict: ready` + `next: proceed`" becomes "`verdict: ready` or `tentative` + `next: proceed`". The routing clause earlier in the same bullet (`` `ready` or `tentative` → `push-pr --stage finalize` ``) is already correct.
  - `dae/build.md:27` ("On a ready/tentative verdict…") is already correct and is **not** edited. Recorded so the gate can check it was considered.
  - Not prose to change: `validate-report.sh:16-18`, `report-verdict.sh:21` and `plan-lifecycle.sh:404` (`adopt` already accepts `ready|tentative`) state the vocabulary, not the finalize rule.
- **Pattern to follow:** keep the `<!-- pr-gate-check -->` marker and a single fenced `sh` block directly after it. The suite extracts and executes that block (`tests/push-pr-gate-refusal.test.sh:11-14`).
- **Acceptance:** `bash tests/push-pr-gate-refusal.test.sh` passes in full. Re-running the enumeration grep returns only test files and the vocabulary lines listed above (positive control: the same grep before the edit returns the three prose lines).
- **Test approach:** 1.1's suite.

- **Record note (shipped differently):** `dae/build.md` needed no edit, as planned.

### 2.2 — `build-dispatch.md` step 1

- **File scope:** `agent-agnostic/skills/dae/build-dispatch.md`.
- **Change:** in step 1 (`:15`), replace "`verify-scope.sh <child-worktree> <parent-branch>` fed the report's `## Files touched` list" with the exact command `verify-scope.sh <child-worktree> <parent-branch> --report <run-dir>/reports/<lane-id>-exit.md`. Add one sentence: piping `git diff --name-only` (or any list derived from the lane's own diff) into `verify-scope.sh` as the reported list compares the diff with itself, so it can never fail. It is forbidden. The report file is the only input. Everything else in step 1 (dirty-worktree stop, `--reuse` remedy) is unchanged.
- **Pattern to follow:** the existing step-1 voice, plus `verify-scope.sh`'s own synopsis (`verify-scope.sh:6`).
- **Acceptance:** `bash tests/build-dispatch-verify-scope.test.sh` passes.
- **Test approach:** 1.2's suite.

### 2.3 — `lane-artifact-shell-guard.sh`: resolve destinations against a tracked cwd

- **File scope:** `agent-agnostic/hooks/lane-artifact-shell-guard.sh`.
- **Design (DP-5 decided: A):**
  - Inside the embedded Python, keep a virtual cwd `vcwd`, seeded from the payload's `cwd` field (string, or `None` if absent).
  - Walk segments in order:
    - A segment whose command word is `cd` or `pushd` sets `vcwd` from its first non-option operand. A relative operand is joined onto `vcwd` and normalized lexically (`posixpath.normpath`, no filesystem access).
    - A cd/pushd with no operand, or with `-`/`~` as operand, makes `vcwd` unknown (`None`). So does `popd`.
    - `(` pushes `vcwd` and `)` pops it, so subshell cds do not leak. Today `(`/`)` are in `SEPARATORS` (`:37`); they keep splitting segments but also drive the stack.
  - Every destination token already inspected stays checked against the raw token, so all existing behavior is kept. The inspected destinations are: redirect targets, `tee` operands, copier last operand, `sed -i`/`perl -i`/`truncate` operands and `dd of=`. **In addition**, when the token is relative and `vcwd` is known, the joined path `vcwd + "/" + tok` is checked through the same `is_target`.
    - A variable-built cd like `cd $R/contracts` gives `vcwd = "$R/contracts"`, so `l8.md` joins to `$R/contracts/l8.md` and the existing `VAR_TARGET` rule catches it. That covers the ask's basename-rule shape without a second rule.
  - The deny message prints the destination as written plus ` (resolves to <path>)` when the two differ.
- **Must stay true:** the header line (`:2`) still states the interpreter one-liner gap. No filesystem reads. Fail-open on parse errors as today (`:15-20`, `:33-34`).
- **Acceptance:** `bash tests/lane-artifact-shell-guard.test.sh` passes in full, all 78 old cases plus 11a-11p. Re-running this planner's replay table (1.3) gives 2 on every deny row.
- **Test approach:** 1.3's suite.

- **Record note (shipped differently):** the guard fix also covers `cp` and payload-cwd forms beyond the ask (cd/pushd tracking, popd/`cd -`/`cd ~` reset, subshell scope).

### 2.4 — `verify-run-scope.sh`: docs-root symlinks are harness-owned

- **File scope:** `agent-agnostic/hooks/verify-run-scope.sh`.
- **Change:**
  - After the docs root is resolved (`:116-126`), compute `docs_abs=$(realpath -m -- "$wt/$(norm "$docs")")`.
  - In the classification loop (`:156-166`), before printing `UNCLAIMED`, do this for a changed path `f` that is not claimed or allowed: if `[ -L "$wt/$f" ]`, compute `tgt=$(realpath -m -- "$wt/$f")`. If `tgt` equals `docs_abs` or starts with `docs_abs/`, `continue`.
  - Extend the header's harness-owned list (`:12-14`) with one clause: "symlinks whose target resolves inside the docs root (doc-format's mirror links)".
- **Pattern to follow:** the existing `realpath -m` use in `claims_from_report` (`:46-47`), and component-safe prefix tests with `case "$x" in "$root"|"$root"/*)`. Symlinks are detected with filesystem `-L` (DP-6 decided).
- **Portability note:** `realpath -m` is GNU coreutils; BSD/macOS `realpath` lacks `-m`. This subphase is therefore **not** BSD-safe. It inherits the assumption this script, and seven other hooks, already make (see Stack & MAJOR versions). It adds nothing new.
- **Acceptance:** `bash tests/verify-run-scope-docs-symlink.test.sh`, `bash tests/verify-scope-parsing.test.sh` (26 cases) and `bash tests/verify-scope-clean.test.sh` (10) all pass.
- **Test approach:** 1.4's suite plus the existing suites.

### 2.5 — `smart-test.sh`: owning-package scope and process-group containment

- **File scope:** `agent-agnostic/hooks/smart-test.sh`.
- **Change (a), scope.**
  - Hoist the owning-package walk at `:606-619` into one function, e.g. `find_js_package_dir <file>`. It prints the nearest ancestor whose `package.json` has a non-orchestrator `scripts.test` (same `turbo|nx|lerna` regex), or nothing. Use it in both branches.
  - In the source-file branch, replace the `$PWD` checks (`:711`) and the bare `$pkg_manager test` calls (`:725-727`, `:746-747`) with calls that run inside that package dir:
    - focused: the direct `node_modules/.bin/vitest run`/`jest` runner when present, else `$pkg_manager test -- <test file relative to pkg_dir>`, exactly as `:631-656` does;
    - package: `$pkg_manager test` inside that package dir.
  - No package found → keep today's "no runner" / "missing test file" error semantics (`:705-768`), but keyed on `pkg_dir`, not `$PWD`. The root orchestrator script is never run.
- **Change (b), containment.**
  - Add one helper, e.g. `run_contained <outvar-file> <dir> <cmd…>`:
    - enable job control around the launch (`set -m` … `set +m`), so the background job gets its own process group (pgid = its pid);
    - launch `( cd "$dir" && exec "$@" ) </dev/null >"$out" 2>&1 &`. `</dev/null` also keeps vitest out of watch mode;
    - record the pid in a global and `wait` it, capturing the exit code without tripping `set -e`;
    - then `kill -TERM -- -"$pid" 2>/dev/null || true` to reap anything the run left behind.
  - Install `trap` handlers for `EXIT`, `TERM`, `INT` and `HUP` that kill the recorded group. The signal traps then exit 128+n.
  - Route all 15 call sites through it (DP-1 decided: A): JS (`:641`, `:652`, `:660`, `:725`, `:746`), Go (`:312, 350, 380, 399, 415`) and Python (`:453, 461, 516, 525, 548`). Containment uses `set -m` (DP-2 decided). There is no internal per-run timeout (DP-3 decided).
  - Output capture and `format_test_output` use are unchanged.
- **Must stay true:** the blind-role short-circuit (`:196-217`) is untouched. Hook-file skip, config loading and exit codes are unchanged (`exit_with_test_failure` is exit 2). `tests/smart-test-role-scope.test.sh` (7 cases) stays green.
- **Acceptance:** `bash tests/smart-test-process-cleanup.test.sh` passes in full. `bash tests/smart-test-role-scope.test.sh` gives `7 passed, 0 failed`. `bash -n agent-agnostic/hooks/smart-test.sh` exits 0.
- **Test approach:** 1.5's suite plus the existing role-scope suite.

## Phase 3: Verify, record, drill

### 3.1 — Whole suite, `bash -n`, guard replay

- **File scope:** none (read-only).
- **Steps:** run `bash -n` on every changed hook, then the whole suite with one `bash tests/<x>.test.sh` call per file. Assert on each file's `N passed, M failed` line (`M` = 0), not only on its exit status. Re-run the 1.3 replay table against the worktree hook.
- **Acceptance:** every suite reports 0 failed, and the replay gives 2 on every deny row and 0 on the control-allow rows. A suite outside this plan's file scopes that fails must be checked against `main` (`52cc92e`) before it is attributed to this run.
- **Oracle:** existing suite.

### 3.2 — Docs-root pages updated at Record

- **Executed by:** the `documenter` agent (`document-local`) at Record. Builders are denied `docs/`.
- **File scope:** `docs/pipeline.md` only. Leave `docs/architecture.md:143` alone: it already says `ready`/`tentative` → finalize.
  - The `lane-artifact-shell-guard.sh` paragraph (`docs/pipeline.md:218-224`) gains: relative destinations are resolved through in-command `cd`/`pushd` (subshell-scoped) and the payload `cwd`.
  - The `verify-run-scope.sh` mention (`:191-192`) gains: symlinks resolving inside the docs root are harness-owned.
  - Where the hooks list describes `smart-test.sh`, if it does at all: test runs are scoped to the owning package and contained in a killed process group.
- **Acceptance:** each statement matches the shipped code. No other page carries a now-false claim. Run `git grep -n 'ready, next proceed\|verdict: ready. + .next: proceed' docs/`, with a positive control on a known string.
- **Oracle:** existing implementation (the docs are checked against the shipped code).

- **Record note (shipped differently):** `docs/pipeline.md` updated (guard cwd tracking, docs-root symlink exemption); `smart-test.sh` is not described in that page, so no clause was added there.

### 3.3 — Post-install drill

- **Executed by:** the orchestrator, after `push-main` lands the squash on `main` and `sync-install.sh <range>` reports a clean diff-verify.
- **File scope:** none in this repo. Read-only against the treehouse worktree.
- **Steps:**
  - Replay the 1.3 table against `~/.claude/hooks/lane-artifact-shell-guard.sh`.
  - Run `~/.claude/hooks/verify-run-scope.sh /home/icarus64/repos/money-makers/treehouse-vineyards/.workflows/commerce7-rebuild <its base> <its run dir>` **without** `--allow`. Expect `OK`, where it previously failed on the 4 README symlinks (progress-log line 48).
  - Run the installed `push-pr` predicate block, with `PR_REVIEW` set to the treehouse `pr-review.md`, through `validate-report.sh`. Expect exit 0 on its `tentative/proceed` round 2.
  - Optional live measurement: count `pgrep -c vitest` before and after a handful of hook-triggering edits in a throwaway JS fixture, confirming no growth.
- **Acceptance:** all three checks pass. Results go to this run's progress log. Resuming the treehouse finalize is the user's call, made in that run.
- **Oracle:** existing implementation (installed behavior).
- **Record note:** passed 10-16-26 against the installed tools after d696b46 — guard denied the l8 and l7 bypass forms (exit 2) and allowed a contract read (exit 0); treehouse verify-run-scope without --allow OK 572/572; the installed finalize predicate accepts the treehouse tentative/proceed pr-review. The optional vitest measurement was not run.

## Risks, open questions, decision points

### Decision points — settled by the user at the plan gate (10-16-26, round 1 tentative/proceed, approved)

- **DP-1 — How far `run_contained` reaches in `smart-test.sh`. DECIDED: A.** All 15 runner sites (Go, Python, JS). The leak is identical in each, and one helper makes it one change.
  - Rejected B: JS only (5 sites), which would leave Go/Python with the same latent orphan behavior.
- **DP-2 — Containment mechanism. DECIDED: A, bash job control (`set -m`).** It puts the background job in its own process group. It works on bash 3.2/macOS and Linux and needs no external binary.
  - Rejected B: `setsid`. It is util-linux and absent on macOS.
- **DP-3 — Per-run time bound inside `smart-test.sh`** (e.g. `CLAUDE_HOOKS_TEST_TIMEOUT`). **DECIDED: no internal timeout in this plan.** Recorded as a follow-up below.
- **DP-4 — JS `package` mode in the default `CLAUDE_HOOKS_TEST_MODES`. DECIDED: out of scope.** Recorded as a follow-up below.
- **DP-5 — Shell-guard approach. DECIDED: A.** Track in-command `cd`/`pushd` targets, seeded from the payload `cwd` (2.3).
  - Rejected B: the ask's basename rule. It misses the payload-cwd shape and `cd .artifacts && … contracts/l7.md` unless extended, at which point it becomes A.
- **DP-6 — How a changed path is recognized as a symlink in `verify-run-scope.sh`. DECIDED: A, filesystem `-L`** in the parent worktree.
  - Rejected B: git mode `120000` via `git ls-tree`. A symlink *deleted* on the branch therefore still reports UNCLAIMED. No such case has been observed.

### Follow-ups (recorded, not planned here)

- **From DP-3:** a per-run time bound inside `smart-test.sh`. Revisit only if 3.3's optional measurement still shows process growth after this plan ships.
- **From DP-4:** after 2.5, JS `package` mode runs the owning package's full suite on every edit. For treehouse's `apps/website` that is ~1073 tests per edit. Candidates: default JS to `focused` only, or make `package` opt-in.

### Assumptions not verified (for the review gate to challenge)

- **A1.** When Claude Code ends a hook (timeout, cancellation, stopped agent), it sends a catchable signal (SIGTERM) to the hook process, not SIGKILL and not to the hook's whole process group. The local reproduction proves that a TERM to the hook orphans its children today. It cannot prove which signal the harness sends. If it is SIGKILL, the traps in 2.5 cannot run, and only the scope fix plus the reap-on-normal-exit reduce the leak. 3.3's optional measurement is the check.
- **A2.** The ~90-150 leftover processes came mostly from root `turbo test` runs triggered by builder source-file edits. This is inferred from the code path, the treehouse root `test` script and the hook-cwd evidence (progress-log line 60). There is no process listing from the time.
- **A3.** The Claude Code hook payload carries `cwd` for subagent Bash calls. The existing suite already assumes it (`tests/lane-artifact-shell-guard.test.sh:51`), as does `smart-test.sh:150`. If it is absent, 2.3 falls back to `None`, which is today's behavior.

### Risks

- **Over-denial in 2.3.** Tracking a cd through `&&`/`||` assumes the cd ran. That can only produce a false *deny*, and only for a lane-file-shaped destination. This is acceptable for a write guard; the 11-series allow cases pin the boundaries.
- **`set -e` interplay in 2.5.** `smart-test.sh:20` runs `set -euo pipefail`, so `wait` returning non-zero must be captured (`wait "$pid" || rc=$?`). The 05 case catches a regression.
- **The test suite for 1.5 spawns real processes.** Every wait is bounded and every spawned token is reaped by the `EXIT` trap, using an anchored `pgrep -f` pattern that cannot match the suite's own shell. That self-match killed this planner's first ad-hoc reproduction shell.
- **Overlap with `agent-identity-write-scope-09-26-26.md`.** Covered in Goal & scope: disjoint hunks and separate suite files.
- **Follow-up observed while planning (out of scope):** the installed `smart-test.sh` blocks a Write to a throwaway `.py` file in a session scratchpad, demanding a test file for it. The `require_tests` path has no "not inside a project" exemption. Logged for the human; not planned here.

## Skill mapping

| Part | Executed by |
|---|---|
| 1.1, 1.2, 2.1, 2.2 (lane 1) | `builder` → `contract-tester` for 1.x, `coder` for 2.x |
| 1.3, 2.3 (lane 2) | `builder` → `contract-tester` / `coder` |
| 1.4, 2.4 (lane 3) | `builder` → `contract-tester` / `coder` |
| 1.5, 2.5 (lane 4) | `builder` → `contract-tester` / `coder` |
| 3.1 | orchestrator (or the last builder's e2e phase), read-only |
| 3.2 | `documenter` → `document-local`, at Record |
| Landing | `push-main` (squash into `main`, push with confirmation, no trailers), then `agent-agnostic/hooks/sync-install.sh <range>` |
| 3.3 | orchestrator, post-install |

**Lanes.** There are four, with disjoint file scopes and no shared touchpoint, so no integration subphase is needed:
- lane 1 — `push-pr/SKILL.md`, `dae/SKILL.md`, `dae/build-dispatch.md`, `tests/push-pr-gate-refusal.test.sh`, `tests/build-dispatch-verify-scope.test.sh`;
- lane 2 — the guard and its suite;
- lane 3 — `verify-run-scope.sh` and its new suite;
- lane 4 — `smart-test.sh` and its new suite.

Defects 1 and 4 share lane 1 because both are small dae-prose fixes. Their files do not overlap, and one builder avoids a fifth dispatch for a single paragraph.
