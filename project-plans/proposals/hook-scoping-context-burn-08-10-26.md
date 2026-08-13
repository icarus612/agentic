# hook-scoping-context-burn-08-10-26

Bugfix plan — unscoped PostToolUse hooks burn orchestrator context and block on
out-of-scope findings; two-tier dispatch has no defined packet-join mechanism.

## Phase syllabus

- [ ] Phase 1: Reproduce
  - [ ] 1.1: Regression test — smart-lint fires a full repo lint on a gitignored markdown edit   (lane 1)
  - [ ] 1.2: Regression test — smart-test blocks an edit for a missing colocated test file       (lane 1, after: 1.1)
- [ ] Phase 2: smart-lint.sh — scope, budget, attribute
  - [ ] 2.1: Gate on the edited file: skip non-source and gitignored paths                       (lane 1, after: 1.1)
  - [ ] 2.2: Lint only the edited file's language, not every detected type                       (lane 1, after: 2.1)
  - [ ] 2.3: Budget linter output and attribute findings to the edited file                      (lane 1, after: 2.1)
  - [ ] 2.4: Block only on findings attributable to the edit                                     (lane 1, after: 2.3)
- [ ] Phase 3: smart-test.sh — stop blocking on absence
  - [ ] 3.1: Remove the "missing required test file" block                                       (lane 1, after: 1.2)
  - [ ] 3.2: Budget test output and drop the whole-suite default mode                            (lane 1, after: 3.1)
- [ ] Phase 4: Hook documentation
  - [ ] 4.1: Correct generic/hooks/README.md to match real behaviour                             (lane 1, after: 2.4, 3.2)
- [ ] Phase 5: Builder robustness to a missing sub-agent report
  - [ ] 5.1: Define the packet join as a filesystem check                                        (lane 2)
  - [ ] 5.2: Give coder and contract-tester a defined on-disk completion signal                  (lane 2, after: 5.1)
  - [ ] 5.3: Add a stalled-packet failure path to builder.md                                     (lane 2, after: 5.2)
- [ ] Phase 6: Sub-agent worktree confinement
  - [ ] 6.1: Prohibit nested per-agent worktree isolation for lane sub-agents                    (lane 2, after: 5.3)
  - [ ] 6.2: Make coder and contract-tester verify their worktree before working                 (lane 2, after: 6.1)
- [ ] Phase 7: False completion and dispatch durability
  - [ ] 7.1: Make the builder's success envelope conditional on its own exit report              (lane 2, after: 5.3)
  - [ ] 7.2: Make the orchestrator poll lane state on disk, not trust completion reports         (lane 2, after: 7.1)
  - [ ] 7.3: Add a literal builder dispatch-prompt template and make respawn re-readable         (lane 2, after: 7.2)
- [ ] Phase 8: Integration and verification
  - [ ] 8.1: Update the repo-level docs that describe these hooks and tiers                      (after: 4.1, 6.2, 7.3)
  - [ ] 8.2: Full regression run and install-drift verification                                  (after: 8.1)

---

## Goal & scope

### The defect, as measured

**Primary (Defect 1).** `generic/hooks/smart-lint.sh` is wired as a global
`PostToolUse` hook on `Write|Edit|MultiEdit`
(`generic/settings/settings.json:142-147`). It extracts the edited file's path
into `TARGET_FILE` (`smart-lint.sh:680-686`) but uses that value for **exactly
one thing** — scoping Prettier (`smart-lint.sh:491-507`). Every other code path
ignores it:

- `lint_javascript()` runs the **root** `pnpm run lint` whenever a root
  `package.json` has a `"lint"` script (`smart-lint.sh:420-444`), regardless of
  what was edited.
- `main()` runs the linter for **every** detected project type on a
  `mixed:` repo (`smart-lint.sh:706-723`), so a Go edit in a polyglot repo also
  triggers the JS lint.
- Linter output is echoed **verbatim and unbounded** (`smart-lint.sh:442-443`,
  and the same pattern at `:283`, `:337`, `:387-388`, `:585-587`).
- Any error returns 2 (`smart-lint.sh:745-749`) with
  `❌ ALL ISSUES ARE BLOCKING ❌` (`:216`).

`should_skip_file()` (`smart-lint.sh:167-191`) — the function that would consult
`.claude-hooks-ignore` and the inline `claude-hooks-disable` marker — **is
defined and never called.** A repo-wide grep finds exactly one occurrence, the
definition itself. `get_modified_files()` (`:158-164`) is dead in the same way.
`generic/hooks/README.md:123-133` documents both exclusion mechanisms as
working; they have never worked.

**Measured reproduction** (controlled fixture at
`scratchpad/fix1`: a git repo whose `.gitignore` contains `.artifacts/`, a root
`package.json` with a `lint` script emitting an 89-line pre-existing error
baseline, and a `.artifacts/progress-log.md`):

| Hook payload `file_path` | exit | stderr bytes | stderr lines | wall |
|---|---|---|---|---|
| `.artifacts/progress-log.md` (gitignored markdown) | **2** | **7,729** | **113** | 545 ms |
| `src/a.ts` (real source edit — behaviour to preserve) | 2 | 7,729 | 113 | — |

The two rows are **byte-identical**: the hook cannot tell a gitignored markdown
write from a TypeScript edit. 7,729 bytes of mostly-ASCII linter output is
roughly 2,000–2,600 tokens; the field report of ~10 such triggers in one session
puts the recurring cost at roughly 20–26k tokens, all of it the same already-known
baseline. That estimate is derived from the measured byte count, not measured
directly.

**Live reproduction, captured while writing this plan** (stronger than the
fixture, and it exposes a sub-defect the fixture could not). Editing **this plan
file** — a `.md` under `/home/icarus64/repos/agentic/project-plans/proposals/` —
fired the hook, which ran `turbo lint` inside
`/home/icarus64/repos/money-makers/mythic-made/.workflows/shop-flag-config`: **a
different repository**, merely the session's cwd. It then blocked (exit 2) on
six pre-existing Prettier warnings in files the edit never touched, in a repo the
edit was not even in.

That adds **Defect 1c — the hook lints `$PWD`, not the edited file's project.**
Nothing in `smart-lint.sh` derives a repo root from `TARGET_FILE`; `find_pruned`
(`:84-102`) and every linter run from the inherited working directory. The
transcript also confirms two findings above independently: `Project type:
mixed:javascript,nix` followed by *both* `Running JavaScript/TypeScript linters`
and `Running Nix linters` is `main()`'s all-types sweep (`:706-723`, the target of
2.2), and the blocking finding was pure formatting debt in unrelated files (the
target of 2.4). Subphase 2.1 must therefore also `cd` to the edited file's
repository root — or skip entirely when `TARGET_FILE` lies outside the current
repo — before any detection or linting happens.

Detection cost compounds it: `detect_project_type()` (`smart-lint.sh:108-155`)
makes six pruned `find` passes over the tree. One such pass over
`money-makers/mythic-made` measured **65 ms / 8,324 hits**, so ≈390 ms of pure
directory walking precedes every edit, markdown included.

**The blocking behaviour is provably unactionable inside a `dae` run.** The
orchestrator's writes are harness-scoped to the plan file and run artifacts by
`orchestrators/hooks/scope-writes.sh` (see `orchestrators/skills/dae/SKILL.md:72`:
"Your writes are harness-scoped — the plan file and run artifacts, never the
product"). `scope-writes.sh:66` denies any write outside that allowlist. So
smart-lint's exit 2 demands a product-code fix that a second hook in this same
repo will refuse. Two wired hooks contradict each other.

**Secondary (Defect 1b) — `smart-test.sh`.** Its `main()` **is** extension-gated
(`smart-test.sh:691-705`): a `.md` edit falls through to `exit 0` (measured: 239
bytes, exit 0). But two other pathologies are live:

- It blocks (`return 2` → `exit_with_test_failure`) **merely because a colocated
  test file does not exist** — `:637-642` (JS), `:661-671`, `:310-315` (Go),
  `:381-385`. Measured on a plain `.ts` edit with no sibling test: **exit 2,
  2,406 bytes**, without ever running a test. This is fatal for the `dae`
  build tier: `orchestrators/agents/coder.md:9` forbids a coder from touching
  test files at all, so a coder is blocked on **every file it creates**, by
  design, forever.
- `format_test_output()` (`:224-236`) carries the comment *"Show the full output
  - no truncation when tests fail"* — an explicit unbounded dump — and the
  default mode list `focused,package` (`:114`) makes mode `package` run the whole
  suite (`$pkg_manager test`, `:645-657`) on any JS edit.

**Not defective — leave alone.** `generic/hooks/record-changed.sh` never blocks
(`:38` `exit 0`) and only appends a path. `generic/hooks/test-changed.sh` and
`orchestrators/hooks/workflow-diff-check.sh` already do the right thing:
extension gating (`test-changed.sh:71-76`, `workflow-diff-check.sh:69-73`) and
bounded output via `tail -30` (`test-changed.sh:85,94,110`;
`workflow-diff-check.sh:83,93,112`). **These are the in-repo pattern this fix
brings smart-lint and smart-test up to** — not new invention. (The
`record-changed`/`test-changed` pair is not currently wired in
`generic/settings/settings.json` at all; it is dormant.)

**Defect 2 — no packet-join mechanism.** `orchestrators/agents/builder.md:28`
says *"As each packet's code and tests both **land**, run that packet's tests"* —
and "land" is defined nowhere. `orchestrators/skills/dae/build-dispatch.md:3`
explicitly disclaims the tier ("its definition owns that — not your business").
There is no `SendMessage` guidance, no poll, no timeout, and no recovery path
anywhere at the builder↔coder tier. Meanwhile `coder.md:15` and
`contract-tester.md:14` both say *"Your final text is the deliverable"* — an
in-context-only hand-off that directly contradicts
`generic/rules/run-artifacts.md:9` ("if another agent … needs it, it is one of
these files, and the hand-off passes the file PATH"). **No on-disk artifact is
defined for a coder or a contract-tester** — the run dir's schema
(`run-artifacts.md:24-30`) has `progress-log.md`, `contracts/`, `reports/` and
explore maps, and nothing per-packet. The observed stall is the predictable
consequence: the only hand-off channel is one the builder was never told to
expect.

**Defect 2b — the packet join failed three times in one run, in both
directions.** Field evidence added after this plan's first draft, all from one
live `dae` run: (1) a coder's completion report was delivered to the top-level
orchestrator instead of its builder, which then blocked forever and returned
mid-lane with no envelope; (2) a builder returned status **`completed`** while
one of its coders was **still running**, with six of nine subphases unfinished;
(3) the orchestrator's own `SendMessage` to `builder` was rejected — *"No agent
named 'builder' is reachable"* — and worked only when addressed by raw agent id.
So name-based addressing is unreliable **in both directions**, not merely
child→parent. This is behavioural evidence about the harness, still not something
the repo states (see D6), and it is exactly why phases 5–7 are designed to make
the disk, not the message, the source of truth.

**Defect 3b (new) — `isolation: "worktree"` strands a lane sub-agent.** A builder
dispatched a coder with the Agent tool's `isolation: "worktree"`. The harness cut
a throwaway worktree at `.claude/worktrees/agent-<id>` from unrelated history and
hard-confined the coder to it: Write/Edit refused every outside path, Bash
refused even a heredoc redirect outside it, `EnterWorktree` refused the lane
worktree (not registered under `.claude/worktrees/`), and `ExitWorktree` refused
because the agent was a subagent with a cwd override. The sandbox also lacked a
file already committed on the lane branch — a disconnected checkout, not an
alias. The coder researched correctly, could not write anywhere useful, and
stopped rather than writing to the wrong tree. One packet wasted plus a manual
round trip.

The cause is conceptual and the repo is silent on it. `build-dispatch.md:7`
establishes that **every builder already has its own child worktree** —
*"Every builder gets its own child worktree"* — and `builder.md:22` says *"Every
subsequent phase runs inside this worktree; never touch the parent or sibling
worktrees."* **That child worktree IS the isolation.** Nesting a second per-agent
worktree inside it is never right for a lane sub-agent; `isolation: "worktree"`
exists for agents that would otherwise collide on a shared checkout, which a lane
coder by construction cannot. Yet a repo-wide grep for `isolation` across
`generic/`, `orchestrators/`, `tool-based/` and `docs/` finds **no guidance
whatsoever** — the only hits are in a completed plan
(`project-plans/completed/master-redesign-07-26-26.md:234`), which lists the Agent
tool's `isolation:` parameter as an open spike. `builder.md:26`'s dispatch wave
never mentions passing the worktree path; `coder.md:13` says only *"Work only
inside the worktree you were given"* — with no way to learn which one, and no
instruction to check.

**Defect 3c (new) — a builder can return `completed` with no exit report.** Lane
2 above returned success with **no `reports/l2-exit.md` on disk** and most of its
work undone. Note carefully: **the instruction already exists and was violated.**
`builder.md:36` requires the report be written *"before returning"* and validated
with `validate-report.sh --kind exit`; `build-dispatch.md:24` repeats it as a hard
rule. So restating it is worthless — the fix must be a **refusal** the builder
applies to its own envelope, plus an orchestrator-side route. The orchestrator
side is half-built: `build-dispatch.md:13` does verify the report before merging,
so the *merge* was never at risk, but its remedy is the vague *"resolve before
merging"* rather than the respawn path that already exists at `:29`. Worse,
`build-dispatch.md:11` drives the whole schedule *"on EACH builder report"* — the
completion notification is the trigger. In this run the notification was wrong and
the disk was right, **every single time**.

**Defect 4 — the brief's premise is false; the real defect is different.**
`build-dispatch.md:24` does *not* say a builder is handed its contract path. It
hands the builder **the plan path, its subphase IDs, its lane id, its file scope,
the parent branch, and the run dir**, and names the contract as an *output*
location ("its contract **goes to** `contracts/<lane-id>.md`"). The **builder
writes its own contract** (`builder.md:24` "saved as
`<run-dir>/contracts/<lane-id>.md>`"; `builder.md:11` "Your own writes are: the
contract document…"), so "write the contract first and pass a path" is
impossible on a first dispatch. Contract-path-as-input is documented only for a
*second* dispatch (`run-artifacts.md:36`: "redispatches a lane from its
contract"). The actual defect is twofold: there is **no literal dispatch-prompt
template** (an asymmetry — `build.md:9` *does* give one for the planner), and
`build-dispatch.md:29` instructs a respawn to use *"the same dispatch prompt"*
while nothing on disk stores it, which is exactly what forces re-typing after a
crash.

### In scope

1. Make `smart-lint.sh` decide from the edited file whether to run at all, run
   in **that file's** repository, run only the relevant language, bound its
   output, and block only on findings the edit could plausibly own.
2. Stop `smart-test.sh` blocking on the *absence* of a test file; bound its
   output; drop whole-suite runs from the default mode list.
3. Add the repo's first tests for `generic/hooks/*.sh`, following the existing
   `tests/*.test.sh` harness.
4. Correct `generic/hooks/README.md`, which documents dead features and a wrong
   install mechanism.
5. Define the builder↔coder packet join as a filesystem check with a stall
   failure path, and give coder/contract-tester a defined on-disk signal.
6. Prohibit nested per-agent worktree isolation for lane sub-agents, and make a
   coder verify its worktree before doing any work.
7. Make a builder's success envelope conditional on its own validated exit
   report, and make the orchestrator poll lane state on disk rather than trust a
   completion report.
8. Add a literal builder dispatch-prompt template so a respawn re-reads rather
   than re-types.

### Explicitly out of scope

- **Defect 3 — consolidating `generic/rules/`.** Measured, then declined; see
  Decision point D4. No subphase plans it.
- `orchestrators/hooks/workflow-diff-check.sh`, `generic/hooks/test-changed.sh`,
  `generic/hooks/record-changed.sh` — inspected, found already correct, not
  touched.
- `generic/settings/settings.json`. Claude Code hook matchers select on **tool
  name**, not path (`settings.json:142` `"matcher": "Write|Edit|MultiEdit"`), so
  path filtering *must* live inside the scripts; no wiring change achieves it.
  Editing this file also carries the sync carve-out risk in
  `.claude/rules/source-push-sync.md:9` (a full reconcile overwrites live grants).
- Committing, pushing, `sync-install.sh`, and the `push-main` skill. The user
  performs those; 8.2 verifies only.
- Refactoring `smart-lint.sh`'s duplicated helper set (it re-defines
  `log_*`/`add_error`/`detect_project_type` instead of sourcing
  `common-helpers.sh`, which `smart-test.sh:27` does source). Noted as a
  follow-up candidate, not fixed here — the bugfix module's minimal-scope rule.
- Adding CI or a test runner. See Decision point D5.

### Supersession

Supersedes nothing. `project-plans/plan-artifact-lifecycle-08-08-26/plan.md`
created the `tests/` directory this plan extends; it remains active and is not
superseded.

---

## Stack & MAJOR versions

Verified by direct inspection — **this repo has no manifests at all**:
`ls` for `package.json`, `Makefile`, `flake.nix`, `Cargo.toml`, `go.mod`,
`justfile`, `.github/` returns nothing. Confirmed by the repo's own
`docs/architecture.md:135`: *"No CI, build system, test suite, license,
`CONTRIBUTING.md`, or `CHANGELOG`."*

| Layer | Technology | Version | Verified from |
|---|---|---|---|
| Scripts | Bash | `#!/usr/bin/env bash` on all 11 hook scripts and both tests | `head -1 generic/hooks/*.sh tests/*.sh` |
| Portability floor | **bash 3.2 + BSD userland (macOS)** | hard constraint | `generic/hooks/worktree-reminder.sh:53-57`; commit `878d8ce` "portable across BSD/GNU sed and macOS bash 3.2" |
| Dev host bash | GNU bash | 5.1.16 | `bash --version` |
| git | git | 2.34.1 | `git --version` |
| Everything else | Markdown | — | file listing |
| Linters | none installed | `shellcheck` absent | `command -v shellcheck` → not found |
| Test framework | none — hand-rolled `tests/*.test.sh` | — | `tests/plan-lifecycle.test.sh:5` (`bash tests/…`), no runner exists |

The **consuming** projects these hooks serve are polyglot by design
(`generic/rules/tech-agnostic.md`); `smart-lint.sh:108-155` detects go, python,
javascript, rust and nix. No fix may narrow that.

---

## Conventions to enforce

Hard constraints, each with its source:

1. **bash 3.2 / BSD-safe.** No `mapfile`/`readarray`, no associative arrays, no
   `${arr[@]@Q}`, no GNU-only `sed` idioms. Use `while IFS= read -r` loops
   (`workflow-diff-check.sh:51` states the reason verbatim) and parameter
   expansion over `sed` (`smart-test.sh:529-531`; `worktree-reminder.sh:53-57`).
2. **No `jq` dependency in new code paths.** `record-changed.sh:3`,
   `test-changed.sh:13`, `workflow-diff-check.sh:21` and `resolve-config.sh:22-25`
   all state jq is not on PATH and extract fields with `grep`/`sed`.
   `smart-lint.sh:682` and `smart-test.sh:141` currently *do* use jq and guard on
   `command_exists jq` — preserve that guard; do not add new unguarded jq calls.
3. **Exit-code vocabulary.** Gating hooks: `0` pass, `1` general error, `2`
   blocking (`smart-lint.sh:14-18`). Advisory hooks: always `0`
   (`claude-install-drift.sh:19,42-43`). Tests: `0` all pass, `1` any failure
   (`plan-lifecycle.test.sh:15-18`).
4. **Never break CLI mode.** `smart-lint.sh --fast`, `--debug` and a bare path
   argument (`:649-673`) plus the no-stdin fallback (`:680`) must keep working;
   with no `TARGET_FILE` the hook stays repo-wide. `README.md:137-141` documents
   these.
5. **Tech-agnostic.** `generic/rules/tech-agnostic.md`. Any new gate must work
   identically for go/python/javascript/rust/nix. No package-manager-specific or
   monorepo-tool-specific logic (`turbo --filter` and friends are forbidden).
6. **Edit source, never the install.** `.claude/rules/source-push-sync.md:5`.
   `~/.claude/hooks/` holds **real copies, not symlinks** (verified: 24 regular
   files, all mtime `Aug 9 21:50`; `diff ~/.claude/hooks/smart-lint.sh
   generic/hooks/smart-lint.sh` → identical). A source edit changes nothing in a
   live session until `sync-install.sh` runs.
7. **Test-file conventions.** `tests/<script-name>.test.sh`; `set -uo pipefail`,
   never `set -e`; `SCRIPT` resolved from `${BASH_SOURCE[0]}`; `pass`/`fail`
   counters; `mktemp -d` scratch registered in `SCRATCH_DIRS` with an `EXIT`
   trap; `run_script`/`run_script_stdin` wrappers setting `OUT`/`ERR`/`CODE`;
   **Case 01 is always a `bash -n` precondition that aborts the file**; trailer
   prints `"$TOTAL_PASS passed, $TOTAL_FAIL failed"` and exits 0/1. Full detail
   in 1.1's pattern block.
8. **Tests never read the script under test's source** —
   `plan-lifecycle.test.sh:13`, `verify-scope-parsing.test.sh:20`, per
   `orchestrators/agents/contract-tester.md:9`.
9. **Nothing in a skill or rule may name this repo's layout**
   (`AGENTS.md:51-55`, `docs/conventions.md:30-33`) — the install is flat. Hook
   *scripts* are exempt in practice (`claude-install-drift.sh:81-82`).
10. **Shell discipline** for the implementer's own commands:
    `generic/rules/shell-discipline.md` — one command per Bash call, never chain
    `cd` with git; use `git -C`.

---

## Phase 1: Reproduce

### 1.1: Regression test — smart-lint fires a full repo lint on a gitignored markdown edit  (lane 1)

**File scope:** `tests/smart-lint-scoping.test.sh` (new).

**Exact reproduction** (this is the observed red state, measured before any
change):

```
Fixture: a git repo with
  .gitignore          containing ".artifacts/"
  package.json        {"scripts":{"lint":"node lint.js"}}
  lint.js             prints 89 "src/a.ts:N:1 error … @typescript-eslint/no-explicit-any"
                      lines to stderr, exits 1
  node_modules/       (empty dir — smart-lint.sh:434 requires it to exist)
  src/a.ts            a real source file
  .artifacts/progress-log.md

Invocation:
  printf '{"session_id":"t","tool_name":"Write","tool_input":{"file_path":"<abs>/.artifacts/progress-log.md"}}' \
    | bash generic/hooks/smart-lint.sh

Observed:  exit 2 · 7,729 bytes on stderr · 113 lines · all 89 baseline errors
Expected:  exit 0 · no linter invoked · at most one advisory line
```

**Pattern to follow:** `tests/plan-lifecycle.test.sh` and
`tests/verify-scope-parsing.test.sh` verbatim. Specifically:

- Header block with `SYNOPSIS` / `DESCRIPTION` / `EXIT CODES`, and the
  declaration "Never reads the script under test's source."
  (`plan-lifecycle.test.sh:2-20`).
- `set -uo pipefail` (`:21`); `SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/generic/hooks/smart-lint.sh"`
  (shape from `:26`).
- `TOTAL_PASS`/`TOTAL_FAIL`/`SCRATCH_DIRS`, `cleanup()`+`trap cleanup EXIT`,
  `pass()`, `fail()` — copy `:31-51` byte-for-byte.
- `new_scratch()` from `:74-79`.
- **`run_script_stdin`** from `verify-scope-parsing.test.sh:63-95` — smart-lint
  reads its JSON payload from stdin, so the stdin-piping variant is the one
  required; the `</dev/null` variant covers CLI mode.
- Case 01 is the `bash -n` precondition from `plan-lifecycle.test.sh:280-293`,
  including the abort-the-file behaviour.
- Case naming `"NN: <description> (ACn)"`; trailer
  `echo "$TOTAL_PASS passed, $TOTAL_FAIL failed"` then `exit 0`/`exit 1`.

Representative case shape to imitate (`plan-lifecycle.test.sh:305-318`):

```bash
# --- Case 02: promote with a .plan-review.md sibling (AC4) -----------------
run_script promote "$plans_dir/proposals/promote-a-01-01-26.md" "${common_flags[@]}"
expected_out="$plans_dir/promote-a-01-01-26/plan.md"
if [ "$CODE" -eq 0 ] \
   && [ "$OUT" = "$expected_out" ] \
   && [ -f "$plans_dir/promote-a-01-01-26/plan.md" ]; then
  pass "02: promote with plan-review sibling moves both, prints exact path (AC4)"
else
  fail "02: promote with plan-review sibling moves both, prints exact path (AC4)" \
    "code=$CODE out=[$OUT] expected_out=[$expected_out] err=[$ERR]"
fi
```

**Acceptance criteria:**

- AC1 — `bash -n tests/smart-lint-scoping.test.sh` exits 0, and the file's own
  Case 01 runs `bash -n` on `smart-lint.sh`.
- AC2 — a fixture builder creates the tree above under `mktemp -d`, registered
  in `SCRATCH_DIRS`, removed by the `EXIT` trap. No writes outside it.
- AC3 — a case asserts exit **0** for a gitignored markdown payload. **This case
  fails today** (actual: 2) and is the plan's red test.
- AC4 — a case asserts stderr for that payload is **under 512 bytes** and
  contains **none** of the 89 baseline error lines. Fails today (7,729 bytes,
  89 matches).
- AC5 — a case asserts a `docs/notes.md` payload (**not** gitignored, still not a
  lintable source file) also exits 0 with bounded stderr. Fails today.
- AC6 — a **preserved-behaviour** case: the `src/a.ts` payload still invokes the
  linter. Passes today and must keep passing.
- AC7 — a **preserved-behaviour** case: CLI mode (`run_script` with `</dev/null`
  and no path, cwd = fixture) still runs repo-wide. Passes today, must keep
  passing.
- AC9 — **cross-repo case (Defect 1c).** Build a *second* fixture repo B with no
  linter, `cd` into it, and send a payload naming a `.ts` file in fixture A. The
  hook must lint **A**, not B — assert via a marker the fixture's `lint` script
  touches. Fails today: the hook lints whatever `$PWD` holds. This is the
  live-captured defect and its regression test.
- AC10 — a payload naming a file in **no** git repository exits 0.
- AC8 — the file exits 1 while any case fails, 0 when all pass.

**Test approach / oracle:** `new contract tests`. Written before any change to
`smart-lint.sh`, run, and **observed red on AC3/AC4/AC5 and green on AC6/AC7**
before phase 2 starts. Record the observed byte counts in the run's progress log.

---

### 1.2: Regression test — smart-test blocks an edit for a missing colocated test file  (lane 1, after: 1.1)

**File scope:** `tests/smart-test-scoping.test.sh` (new).

**Exact reproduction:**

```
Fixture: the same shape as 1.1, plus package.json scripts.test = "node t.js"
         (t.js prints 120 failure lines to stderr, exits 1)
         src/a.ts exists; NO src/a.test.ts

Invocation:
  printf '{"session_id":"t","tool_name":"Edit","tool_input":{"file_path":"<abs>/src/a.ts"}}' \
    | bash generic/hooks/smart-test.sh

Observed:  exit 2 · 2,406 bytes · "❌ Missing required test file for: …"
           followed by "❌ TESTS FAILED - BLOCKING ❌"
           — and no test was ever executed
Expected:  exit 0 (absence of a test is not a test failure)
```

Second reproduction, same fixture with `src/a.test.ts` present and failing:
observed unbounded dump via `format_test_output()` (`smart-test.sh:224-236`);
expected bounded to the repo's `tail -30` convention.

**Pattern to follow:** identical to 1.1 — same harness, `SCRIPT` pointed at
`generic/hooks/smart-test.sh`.

**Acceptance criteria:**

- AC1 — Case 01 `bash -n` precondition on `smart-test.sh`.
- AC2 — a case asserts exit **0** for a `.ts` edit with no sibling test file.
  Fails today (2).
- AC3 — a case asserts the string `Missing required test file` is **absent** from
  stderr. Fails today.
- AC4 — a case with a failing sibling test asserts exit **2** (a real failure
  still blocks) **and** stderr under 4,096 bytes. The exit-2 half passes today;
  the bound fails today.
- AC5 — a **preserved-behaviour** case: a `.md` payload exits 0. Passes today
  (measured 239 bytes) and must keep passing.
- AC6 — a case asserts the same for a `.go` file with no `_test.go` sibling,
  proving the fix is not JS-specific (`smart-test.sh:310-315` is the Go arm of
  the same defect). Skipped with an explicit `pass` note when `go` is absent from
  PATH — the harness has no skip primitive, so the skip must be visible in the
  output line.

**Test approach / oracle:** `new contract tests`. Observed red on AC2/AC3/AC4
and green on AC5 before phase 3.

---

## Phase 2: smart-lint.sh — scope, budget, attribute

### 2.1: Gate on the edited file: skip non-source and gitignored paths  (lane 1, after: 1.1)

**File scope:** `generic/hooks/smart-lint.sh` (only).

**What to change.** After `TARGET_FILE` is resolved (`smart-lint.sh:680-686`) and
**before** `detect_project_type()` runs at `:700`, add a gate that exits 0 when a
`TARGET_FILE` is present and either:

1. its extension is not one any supported linter consumes, or
2. `git check-ignore -q -- "$TARGET_FILE"` succeeds.

**Then `cd` to the edited file's own repository root** — `git -C "$(dirname
"$TARGET_FILE")" rev-parse --show-toplevel` — before detection or linting. This
is Defect 1c, and it is not hypothetical: the live capture in Goal & scope shows
an edit to a file under `/home/icarus64/repos/agentic/` running `turbo lint` in
`/home/icarus64/repos/money-makers/mythic-made/.workflows/shop-flag-config` purely
because that was `$PWD`. Skip entirely (exit 0) when the edited file is in no
repository, and run the ignore check from that root so relative-path semantics
are right.

Order matters: resolve the root **first**, then run `git check-ignore` against it,
since an ignore rule is meaningless evaluated from an unrelated repo.

When `TARGET_FILE` is empty (CLI mode) the gate is inert and everything proceeds
repo-wide from `$PWD`, exactly as today.

**Pattern to follow.** The extension gate is a `case` statement in the shape of
`generic/hooks/test-changed.sh:71-76` and
`orchestrators/hooks/workflow-diff-check.sh:69-73` — the same construct, extended
to cover every language `smart-lint.sh` supports plus their config/format
surfaces (`.go .py .js .jsx .mjs .cjs .ts .tsx .svelte .vue .rs .nix`, and the
files the linters themselves format: `.json .css .scss .html .yaml .yml .md` are
**deliberately excluded** — see Decision point D2, which must be settled before
this subphase is implemented).

The gitignore check is one subprocess. Verified behaviour on git 2.34.1:
`git check-ignore -q -- <abs-path>` returns 0 when ignored, 1 when not, 128
outside a repo. Treat **only** exit 0 as "skip"; 1 and 128 both proceed. This
covers `.artifacts/**` and `.workflows/**` for free, because
`generic/rules/run-artifacts.md` already requires both entries to be committed to
the consuming repo's `.gitignore` — no new config, and it stays tech-agnostic
because it reads the project's own ignore rules rather than a hard-coded list.

**Also in this subphase:** delete `should_skip_file()` (`:167-191`) and
`get_modified_files()` (`:158-164`). Both are dead
(`generic/rules/tech-agnostic.md` is silent here, but `AGENTS.md`'s "Delete old
code when replacing it" applies). The `.claude-hooks-ignore` mechanism they were
meant to serve is superseded by `git check-ignore`; `generic/hooks/claude-hooks-ignore`
is removed and the README corrected in 4.1. This is contingent on Decision point
D3.

**Acceptance criteria:**

- 1.1 AC3, AC4 and AC5 go green.
- 1.1 AC6 and AC7 stay green.
- `grep -c should_skip_file generic/hooks/smart-lint.sh` → 0.
- The gate emits **at most one** line to stderr when it skips, and that line is
  suppressed unless `CLAUDE_HOOKS_DEBUG=1`. The header at `:689-691` must move
  below the gate, or a skipped edit still costs three lines per edit.
- No `mapfile`, no associative arrays, no GNU-only `sed`.

**Test approach / oracle:** `existing suite` — `tests/smart-lint-scoping.test.sh`
from 1.1, run to green.

---

### 2.2: Lint only the edited file's language, not every detected type  (lane 1, after: 2.1)

**File scope:** `generic/hooks/smart-lint.sh` (only).

**What to change.** `main()` (`:704-736`) iterates every type in a `mixed:`
detection and calls all matching linters. When `TARGET_FILE` is set, derive the
single language from its extension and dispatch only that arm. Keep the
full sweep when `TARGET_FILE` is empty.

This also removes most of the ≈390 ms detection cost: with a known extension,
`detect_project_type()` need not run at all on the hook path.

**Pattern to follow:** the extension→language mapping already written in
`test-changed.sh:71-76` (`js`/`go`/`py` buckets), widened to rust and nix. The
existing `case "$PROJECT_TYPE" in … "go") lint_go ;; …` dispatch at `:726-735` is
the target shape — reuse it with the language derived from the file rather than
from a tree scan.

**Acceptance criteria:**

- A new case in `tests/smart-lint-scoping.test.sh`: in a fixture containing both
  a `package.json` with a failing `lint` script **and** a `.go` file, a payload
  naming the `.go` file does **not** produce the JS linter's output.
- 1.1 AC6 stays green (a `.ts` payload still runs the JS linter).
- 1.1 AC7 stays green (CLI mode still sweeps every detected type).

**Test approach / oracle:** `existing suite` (extended by one case).

---

### 2.3: Budget linter output and attribute findings to the edited file  (lane 1, after: 2.1)

**File scope:** `generic/hooks/smart-lint.sh` (only).

**What to change.** Every `echo "$…_output" >&2` becomes a bounded emit. Add one
helper — placed beside `add_error()` (`:200-204`) — that prints:

- a one-line count (`"N finding(s) from <tool> in <dir>"`), then
- the lines that **mention `TARGET_FILE`** (by basename and by repo-relative
  path), then
- at most `CLAUDE_HOOKS_OUTPUT_LINES` (default **30**) further lines, then
- a `"… (M more lines suppressed; run <tool> yourself to see them)"` trailer.

Call sites to convert: `:277`, `:282`, `:321`, `:337`, `:368`, `:388`, `:442`,
`:443`, `:516`, `:517`, `:580`, `:587`, `:617`, `:626`, `:637`.

**Pattern to follow:** `tail -30` as used in `test-changed.sh:85,94,110` and
`workflow-diff-check.sh:83,93,112` — same budget, same repo. The added value over
plain `tail` is the attribution pass, which is what turns "here is the repo's
debt" into "here is what your edit touched".

**Acceptance criteria:**

- 1.1 AC4 green with margin: stderr for a `src/a.ts` payload against the 89-error
  baseline is **under 4,096 bytes** (today: 7,729) while still naming
  `src/a.ts`.
- A new case: when the baseline errors are in `src/other.ts` and the payload
  names `src/a.ts`, stderr contains the count but **not** the 89 lines.
- `CLAUDE_HOOKS_OUTPUT_LINES=0` suppresses the sample entirely, leaving the count.
- The default (30) is documented in 4.1.

**Test approach / oracle:** `existing suite` (extended by two cases).

---

### 2.4: Block only on findings attributable to the edit  (lane 1, after: 2.3)

**File scope:** `generic/hooks/smart-lint.sh` (only).

**What to change.** `main()` returns 2 whenever `CLAUDE_HOOKS_ERROR_COUNT > 0`
(`:745-749`). Change the rule to: **return 2 only when at least one finding
mentions `TARGET_FILE`**; otherwise emit the count as advisory and return 0.
When `TARGET_FILE` is empty (CLI mode), keep today's behaviour — any error
blocks.

Formatter failures (`gofmt -w`, `prettier --write`, `cargo fmt`, `black`) already
scope themselves to the edited file after 2.1/2.2 and keep blocking.

This is the subphase that resolves the contradiction with `scope-writes.sh:66`:
after it, the hook never demands a write the harness will deny.

**Pattern to follow:** `workflow-diff-check.sh:16-19` states the principle this
adopts — *"never blocks for infrastructure reasons"*, blocking reserved for
"failures on changed files". `claude-install-drift.sh:19` is the advisory-exit-0
precedent.

**Acceptance criteria:**

- New case: 89 baseline errors in `src/other.ts`, payload names `src/a.ts` →
  **exit 0**, with a one-line advisory count on stderr.
- New case: an error line naming `src/a.ts`, payload names `src/a.ts` → **exit 2**
  (the hook still catches what the edit broke).
- 1.1 AC7 (CLI mode) still exits 2 on any error.
- The `❌ ALL ISSUES ARE BLOCKING ❌` banner (`:216`) and the NEXT STEPS block
  (`:757-763`) print only on a real block, never on the advisory path.

**Test approach / oracle:** `existing suite` (extended by two cases). Contingent
on Decision point D1.

---

## Phase 3: smart-test.sh — stop blocking on absence

### 3.1: Remove the "missing required test file" block  (lane 1, after: 1.2)

**File scope:** `generic/hooks/smart-test.sh` (only).

**What to change.** Delete the four blocking-on-absence paths and their
`require_tests` scaffolding:

- Go: `:310-315` and `:381-385` (plus `require_tests` at `:277-280`,
  `should_skip_test_requirement()` at `:183-218`).
- Python: `:427-434` scaffolding and its focused-mode counterpart.
- JS: `:637-642` and `:661-671` (plus `require_tests` at `:577-588`).

An absent test file becomes a no-op: run what exists, exit 0. Whether it leaves
a `CLAUDE_HOOKS_DEBUG`-only note is the implementer's call; it must not print at
default verbosity.

**Why this is load-bearing beyond token cost:** `orchestrators/agents/coder.md:9`
— *"If a test file falls inside the paths you were handed, that's a dispatch
error — report it, don't open it."* A coder that cannot write tests is blocked by
this hook on every file it creates. The `dae` build tier cannot function with the
current behaviour.

**Pattern to follow:** `test-changed.sh:87` — *"No local vitest → nothing to run;
stay silent (don't block the stop)"* — the same repo's stance on "nothing to run
is not a failure."

**Acceptance criteria:**

- 1.2 AC2, AC3 and AC6 go green.
- 1.2 AC4's exit-2 half stays green: a **failing** test still blocks.
- 1.2 AC5 stays green.
- `grep -c "Missing required test file\|No tests found for\|tests required" generic/hooks/smart-test.sh` → 0.

**Test approach / oracle:** `existing suite` — `tests/smart-test-scoping.test.sh`.

---

### 3.2: Budget test output and drop the whole-suite default mode  (lane 1, after: 3.1)

**File scope:** `generic/hooks/smart-test.sh` (only).

**What to change.**

1. `format_test_output()` (`:224-236`) currently documents unbounded output in a
   comment. Replace its body with the repo's `tail -30` budget plus a suppressed-line
   trailer, honouring `CLAUDE_HOOKS_OUTPUT_LINES` (the same variable 2.3
   introduces — keep the name and default identical across both hooks).
2. Change the `CLAUDE_HOOKS_TEST_MODES` default at `:114` from `focused,package`
   to **`focused`**. Mode `package` runs the entire suite on every edit
   (`:645-657` for JS, `:319-340` for Go) — the same "re-list known debt"
   pathology as Defect 1. `package` stays available for projects that opt in via
   `.claude-hooks-config.sh`.

**Pattern to follow:** `test-changed.sh:85`
(`"$(printf '%s\n' "$out" | tail -30)"`) — copy the idiom exactly so the two
hooks read the same.

**Acceptance criteria:**

- 1.2 AC4's byte bound goes green.
- New case: with `CLAUDE_HOOKS_TEST_MODES` unset, a `.ts` edit with a *passing*
  sibling test does **not** invoke the root `test` script (assert via a marker
  file the fixture's `test` script touches when it runs).
- New case: `CLAUDE_HOOKS_TEST_MODES=focused,package` restores the whole-suite
  run — the opt-in survives.
- `format_test_output`'s comment no longer claims "no truncation".

**Test approach / oracle:** `existing suite` (extended by two cases).

---

## Phase 4: Hook documentation

### 4.1: Correct generic/hooks/README.md to match real behaviour  (lane 1, after: 2.4, 3.2)

**File scope:** `generic/hooks/README.md`; delete `generic/hooks/claude-hooks-ignore`.

**What to change** — every item verified as currently wrong:

- `:123-133` documents `.claude-hooks-ignore` and the inline
  `// claude-hooks-disable` marker as working exclusion mechanisms. Both are dead
  (`should_skip_file()` has no call site). Replace with the real rule: the hook
  skips non-source extensions and anything `git check-ignore` matches, so a
  project excludes files through its own `.gitignore`.
- `:97-99` claims *"Automatically installed by Nix home-manager to
  `~/.claude/hooks/`"*. The real mechanism is
  `orchestrators/hooks/sync-install.sh` (`.claude/rules/source-push-sync.md:7`),
  a copy-based sync run from `main` after a push. `docs/conventions.md:216-217`
  repeats the wrong claim and is fixed in 8.1.
- `:120` points at `example-claude-hooks-config.sh`, which does not exist; the
  shipped file is `generic/hooks/claude-hooks-config.sh`.
- `:65-66` says *"By `exit 2` on success…"*, contradicting `:143-146` (`0` =
  passed). Fix the prose.
- `smart-test.sh` has **no README section at all** despite being wired at
  `generic/settings/settings.json:150`. Add one covering its modes, its exit
  codes, and the 3.1/3.2 behaviour change.
- Env vars: only 5 of the 22 `CLAUDE_HOOKS_*` variables in `generic/hooks/*.sh`
  are documented (`:107-118`). Document at minimum the ones this plan's
  behaviour depends on — `CLAUDE_HOOKS_OUTPUT_LINES` (new),
  `CLAUDE_HOOKS_TEST_MODES`, `CLAUDE_HOOKS_TEST_ON_EDIT`,
  `CLAUDE_HOOKS_ENABLE_RACE`, `CLAUDE_HOOKS_PRUNE_EXTRA`, and the per-language
  `*_ENABLED` set. Completing all 22 is optional.

**Pattern to follow:** `generic/rules/doc-format.md` — one page per topic, kept
current, edited in place. The README's existing section shape
(`### <script>` → bullets → transcript sample) is retained.

**Acceptance criteria:**

- No sentence in the README describes a mechanism with no call site. Verify by
  grepping each documented feature name for an implementation.
- `generic/hooks/claude-hooks-ignore` is deleted and nothing references it
  (`grep -rn "claude-hooks-ignore" generic/ orchestrators/ docs/ tests/` → 0 hits).
- The install section names `sync-install.sh`.
- A `smart-test.sh` section exists.
- `CLAUDE_HOOKS_OUTPUT_LINES` is documented with its default of 30.

**Test approach / oracle:** `equivalence check` — no executable oracle exists for
prose. The review-code gate verifies each corrected claim against the cited line
in the script. The deletion check and the `claude-hooks-ignore` grep are
mechanical and belong in the exit report as commands with their output.

---

## Phase 5: Builder robustness to a missing sub-agent report

### 5.1: Define the packet join as a filesystem check  (lane 2)

**File scope:** `orchestrators/agents/builder.md` (only).

**What to change.** `builder.md:28` reads *"**3. Pipelined joins.** As each
packet's code and tests both land, run that packet's tests immediately — no
barrier on the slowest packet."* — with "land" undefined and no mechanism named
anywhere at this tier.

Replace the undefined verb with an explicit, mechanism-independent rule:

- A packet is complete when **the files its contract slice names exist on disk
  and the packet's tests run** — verified by the builder itself, from the
  worktree, not by receiving a message.
- A sub-agent's return text is **corroboration, not the trigger**. Never block
  on it. State plainly that a sub-agent's completion notification may be
  delivered elsewhere and must never be a precondition for progress.

**Why:** `generic/rules/run-artifacts.md:9` already states the governing
principle — *"Nothing a worker, gate, or orchestrator needs to hand to another
agent may live only in conversation context."* `builder.md:28` is the one place
in the pipeline that violates it. Note the exact precedent one tier up:
`build-dispatch.md:13` tells the orchestrator to verify a builder by *"check the
exit report file exists and passes `validate-report.sh --kind exit`"*. This
subphase makes the builder tier do the same kind of thing.

**Pattern to follow:** `build-dispatch.md:13` (disk verification as the join) and
`workflow-diff-check.sh` / `verify-scope.sh` (git diff as the ground truth for
what a lane actually changed).

**Acceptance criteria:**

- `builder.md` step 3 names a concrete verification (files exist + tests run),
  with no undefined verb.
- The text states explicitly that a missing sub-agent notification is expected
  and non-fatal.
- No `SendMessage` mechanics are asserted — the guidance must hold whatever the
  harness's addressing turns out to do. (The addressing claim in the brief was
  **not** independently verified; nothing in the repo documents builder↔coder
  addressing at all, so the fix is deliberately mechanism-agnostic. See Decision
  point D6.)
- Nothing in the file names this repo's directory layout (`AGENTS.md:51-55`).

**Test approach / oracle:** `equivalence check` — a markdown agent definition has
no executable oracle. Verified by the review-code gate against these criteria.

---

### 5.2: Give coder and contract-tester a defined on-disk completion signal  (lane 2, after: 5.1)

**File scope:** `orchestrators/agents/coder.md`, `orchestrators/agents/contract-tester.md`.

**What to change.** Both files end with *"Your final text is the deliverable"*
(`coder.md:15`, `contract-tester.md:14`) — an in-context-only hand-off that
`run-artifacts.md:9` forbids. Neither is listed among the worker-envelope
adopters (`docs/conventions.md:114-121`), which is fine; the gap is that neither
leaves anything a parent can check.

The minimal fix that changes no artifact schema: state that the **files the
packet names are the deliverable**, and that the final text is a summary of work
already durable on disk. Require each to finish by listing the absolute paths it
wrote, so the builder's 5.1 check has an exact target. Decision point D7 covers
the heavier alternative (a new per-packet artifact kind).

**Pattern to follow:** `builder.md:36` — *"Your exit report is a FILE first: write
`<run-dir>/reports/<lane-id>-exit.md` **before returning**"* — the same
ordering discipline (durable first, return second), applied one tier down
without inventing a new file kind.

**Acceptance criteria:**

- Neither file claims its conversational return is the primary deliverable.
- Both require the written files to be complete on disk before returning.
- Both require the return text to list absolute paths written.
- `contract-tester.md:9`'s never-read-the-implementation constraint is untouched
  — it is the agent's identity and must survive verbatim.
- No new artifact kind is introduced, so `generic/rules/run-artifacts.md` is
  **not** edited (it is out of this lane's file scope).

**Test approach / oracle:** `equivalence check`.

---

### 5.3: Add a stalled-packet failure path to builder.md  (lane 2, after: 5.2)

**File scope:** `orchestrators/agents/builder.md`, `orchestrators/skills/dae/build-dispatch.md`.

**What to change.** `builder.md` has **no failure-paths section at all**; its
only loop (`:30`) keys on test redness, never on a missing report.
`build-dispatch.md:26-30` has a Failure paths section for the lane tier
("Builder dies mid-lane: respawn fresh… bounded respawns, 2 per lane") — the
packet tier has no equivalent.

Add the mirror-image section to `builder.md`: when a packet's expected files are
absent after its sub-agent should have finished, treat the packet as **stalled**,
re-dispatch a fresh sub-agent with the same contract slice, bound the retries
(match the lane tier's 2), and escalate to the orchestrator through the exit
report's `blockers[]` rather than blocking indefinitely. Add one cross-reference
line to `build-dispatch.md`'s Failure paths noting that a builder handles packet
stalls internally and surfaces only the escalation.

**Pattern to follow:** `build-dispatch.md:29` verbatim in structure — trigger,
action, bound, escalation. `orchestrators/skills/dae/SKILL.md:72` supplies the
constraint that must be restated at this tier: *"a stalled or dead lane is NEVER
a license to do its work yourself"* — a builder must not implement a stalled
packet itself (`builder.md:11`: "You write no implementation and no contract
tests").

**Acceptance criteria:**

- `builder.md` gains a Failure paths section covering the stalled packet.
- The retry bound is explicit and the escalation route named.
- The section states the builder must not implement the packet itself.
- `build-dispatch.md` gains at most one cross-reference line; the tier separation
  at `:3` is preserved, not blurred.

**Test approach / oracle:** `equivalence check`.

---

## Phase 6: Sub-agent worktree confinement

### 6.1: Prohibit nested per-agent worktree isolation for lane sub-agents  (lane 2, after: 5.3)

**File scope:** `orchestrators/agents/builder.md`,
`orchestrators/skills/dae/build-dispatch.md`.

**What to change.** `builder.md:26` describes the dispatch wave — *"spawn
simultaneously … a **`coder`** (its packet's contract slice + the files it owns)"*
— and never mentions the worktree. Nothing anywhere tells a builder **not** to
pass `isolation: "worktree"`, and nothing tells it to hand over its own worktree
path. Verified: `grep -rn "isolation"` across `generic/`, `orchestrators/`,
`tool-based/` and `docs/` returns no guidance at all; the sole hit is a completed
plan listing the Agent tool's `isolation:` parameter as an unresolved spike
(`project-plans/completed/master-redesign-07-26-26.md:234`).

Add to `builder.md`'s Invariants (the file's own "authoritative — stated once"
section, `:9-18`) a **prohibition with its reason**, not a style note:

- A lane sub-agent is **never** dispatched with per-agent worktree isolation.
  The builder's child worktree from phase 0 **is** the isolation
  (`build-dispatch.md:7`); a coder writes inside it, on the lane branch, so its
  work reaches merge-back. A nested throwaway worktree is cut from unrelated
  history and hard-confines the agent: it cannot write the lane's files, cannot
  reach the lane worktree, and cannot leave — its output is unrecoverable and the
  packet is lost.
- Per-agent isolation exists for agents that would otherwise collide on a shared
  checkout. Lane sub-agents cannot collide: they are packet-disjoint by
  construction (`builder.md:12`, one packet per coder) inside a worktree only
  this lane owns.
- Every sub-agent dispatch **passes the builder's worktree path explicitly, as an
  absolute path**, and instructs the agent to work there. This is the missing
  half of `coder.md:13` ("Work only inside the worktree you were given" — which
  today names no mechanism by which it is given).

Add one line to `build-dispatch.md`'s Lanes and isolation section (`:5-7`)
stating that the child worktree is the isolation boundary for the whole lane,
sub-agents included, so the tier-one reader is not left to infer it.

**Pattern to follow:** `builder.md:17` — *"Stay inside your lane's file scope and
your own child worktree"* — and `builder.md:22` — *"never touch the parent or
sibling worktrees"*. Both already state the confinement for the builder; this
subphase extends the same rule downward, in the same voice, to the agents it
spawns.

**Acceptance criteria:**

- `builder.md`'s Invariants contain the prohibition, stated as a prohibition,
  with the "the child worktree IS the isolation" reason attached.
- The dispatch step (`:26`) requires passing the absolute worktree path.
- `build-dispatch.md` gains at most one clarifying line; the tier separation at
  `:3` survives.
- The text does not describe harness internals (`.claude/worktrees/` paths,
  `EnterWorktree`/`ExitWorktree` behaviour) as guaranteed. Those are observed
  symptoms, not a documented contract — state the rule and the reason, not the
  mechanism. See Decision point D9.

**Test approach / oracle:** `equivalence check`.

---

### 6.2: Make coder and contract-tester verify their worktree before working  (lane 2, after: 6.1)

**File scope:** `orchestrators/agents/coder.md`,
`orchestrators/agents/contract-tester.md`.

**What to change.** In the reported incident the coder discovered the mismatch
**only after completing its research** — the whole packet's work was already done
when it found it had nowhere to put it. `coder.md:13` says only *"Work only
inside the worktree you were given."*

Add a **fail-fast precondition as the first action**, before any research or
authoring: confirm the working directory resolves to the worktree path in the
prompt (a `git rev-parse --show-toplevel` comparison), and if it does not — or if
writes to that path are refused — **stop immediately and report the mismatch**,
naming both the expected and actual paths. Do not research first. Do not write
elsewhere.

State plainly that stopping is the correct outcome, not a failure: writing
correct work into the wrong tree is worse than not writing it. The reported coder
did exactly this and it was the right call; the cost was that it did so late.

**Pattern to follow:** `builder.md:17-18` — *"A needed file outside scope is a
scope gap — stop and report it, don't touch it"* — the same stop-and-report
discipline, applied to the workspace rather than the file scope. Phase 0 ordering
in `builder.md:22` ("Every subsequent phase runs inside this worktree") is the
precedent for making workspace verification precede all other work.

**Acceptance criteria:**

- Both files place the worktree check before any other instruction in their
  procedure.
- Both name the exact check and require reporting expected vs actual on
  mismatch.
- Both state that stopping is correct behaviour.
- `coder.md:9`'s never-touch-tests rule and `contract-tester.md:9`'s blindness
  rule are untouched — they are the agents' identities.
- No harness internals are asserted as contract (same constraint as 6.1).

**Test approach / oracle:** `equivalence check`.

---

## Phase 7: False completion and dispatch durability

### 7.1: Make the builder's success envelope conditional on its own exit report  (lane 2, after: 5.3)

**File scope:** `orchestrators/agents/builder.md` (only).

**What to change — and what NOT to.** The instruction **already exists**:
`builder.md:36` requires the report be written *"before returning"* and run
through `validate-report.sh --kind exit`, and `build-dispatch.md:24` repeats it as
a hard rule. A builder nonetheless returned `completed` with no
`reports/l2-exit.md` on disk and six of nine subphases unfinished. **Restating the
requirement would change nothing** — it was already stated twice and violated.

Convert it from an instruction into a **self-applied refusal** with a defined
alternative:

- `status: success` in the envelope is permitted **only** when the builder has
  itself observed `validate-report.sh --kind exit <report>` print `OK:`. Not
  "wrote the report" — observed the validator pass. (Verified contract:
  `validate-report.sh:86-96` checks a fenced `status:` from the enum, a non-empty
  `## Files touched`, and a non-empty `## Evidence`; it prints `OK: exit report
  valid (status …, N files)` and exits 0.)
- If the report cannot be written or does not validate, the builder returns
  `failed` or `blocked` with the reason — **never** `success`. A truthful failure
  is recoverable through the respawn path at `build-dispatch.md:29`; a false
  success is not, because it retires the lane from the frontier.
- Returning while any dispatched sub-agent is still running is itself a
  `failed` condition, not a success. This is the second half of the reported
  incident and it ties directly to 5.1: the builder must confirm each packet's
  files on disk, not assume completion.

**Pattern to follow:** `generic/skills/review-plan/scripts/validate-plan.sh` and
`report-verdict.sh`/`validate-report.sh` as a pair — the repo's existing stance,
stated in `validate-report.sh:9-11`: *"A report that fails here is not a report —
gates rerun, callers refuse the hand-off."* This subphase applies that existing
principle to the builder's own return.

**Acceptance criteria:**

- `builder.md`'s Exit report section makes `success` conditional on an observed
  `OK:` from the validator.
- It names `failed`/`blocked` as the required alternative and says why (the
  respawn path exists; a false success has none).
- It states that outstanding sub-agents preclude `success`.
- The existing report schema is unchanged — no new sections, since
  `validate-report.sh:86-96` is the fixed contract.

**Test approach / oracle:** `equivalence check`.

---

### 7.2: Make the orchestrator poll lane state on disk, not trust completion reports  (lane 2, after: 7.1)

**File scope:** `orchestrators/skills/dae/build-dispatch.md` (only).

**What to change.** `build-dispatch.md:11` drives the entire schedule *"on EACH
builder report"* — the completion notification is the trigger. Across the
reported run the notification was wrong and the disk was right **every single
time**: a report delivered to the wrong agent, a `completed` that wasn't, and a
`SendMessage` that could not resolve `builder` by name at all.

Two changes:

1. Make the disk the source of truth for lane state. A lane's real state is
   readable from its worktree — commits on the child branch, uncommitted change
   count, and the presence and validity of `reports/<lane-id>-exit.md`. State
   that the orchestrator may check these at any time and **must** check them
   before acting on any completion signal, and that a completion notification is
   corroboration rather than the trigger. Note explicitly that a notification may
   be delivered to the wrong agent or never arrive, so a lane must never be
   parked waiting on one.
2. Sharpen `:13`'s remedy. It currently says a missing or invalid exit report
   *"stop[s] the schedule; resolve before merging"* — correct but undirected.
   Route it instead to the failure path that already exists at `:29`: treat a
   missing or invalid report as **lane failure**, respawn with `--reuse` under the
   existing 2-respawn bound, and escalate after that. The merge itself was never
   at risk — `:13` already gates it — so the gap is purely that a false
   `completed` silently stalls the lane until a human notices.

**Pattern to follow:** `build-dispatch.md:13` itself (disk verification already
gates the merge — this generalizes the same check to scheduling) and
`build-dispatch.md:29`'s existing trigger→action→bound→escalation shape for the
new routing.

**Acceptance criteria:**

- `:11`'s scheduling text names disk state as authoritative and the notification
  as corroboration.
- The specific observables are named: child-branch commits, uncommitted count,
  exit-report presence and validity.
- A missing/invalid report routes to `:29`'s respawn path with its existing
  bound; no new bound is invented.
- The text states a lane is never parked waiting on a notification.
- Addressing mechanics are **not** asserted (D6) — the guidance must hold whether
  or not name-based `SendMessage` works.

**Test approach / oracle:** `equivalence check`.

---

### 7.3: Add a literal builder dispatch-prompt template and make respawn re-readable  (lane 2, after: 7.2)

**File scope:** `orchestrators/skills/dae/build-dispatch.md` (only).

**What to change.** `build-dispatch.md:22-24` specifies the builder dispatch
prompt as one prose sentence listing eight items. `build.md:9` by contrast gives
the planner dispatch as a literal itemized list — the asymmetry is the gap.
`build-dispatch.md:29` then says a respawn uses *"the same dispatch prompt"*,
which nothing stores.

Two changes:

1. Convert `:24`'s prose into a **literal fenced template** with named
   placeholders, so an orchestrator fills slots instead of composing prose. The
   eight items stay exactly as they are — plan path, lane subphase/candidate IDs,
   lane id, file scope, parent branch and branch type, absolute run dir, the
   rework findings path when reworking, and the hard rules.
2. State that the filled template is **recorded in the run's progress log** at
   dispatch (which `run-artifacts.md:26` already designates as the run's live
   state and the thing a resumed session reconstructs from) and that a respawn
   **re-reads it from there** rather than reconstructing it. This adds no new
   artifact kind and stays inside the orchestrator's existing write scope
   (`SKILL.md:72`: "the plan file and run artifacts").

**Do not** claim a builder is handed its contract path on first dispatch. The
builder **writes** its own contract (`builder.md:24`, `builder.md:11`;
`run-artifacts.md:28`), so the contract does not exist until step 1 of the
builder's own procedure. Contract-as-input is correct only for the rework
redispatch already documented at `run-artifacts.md:36`. This subphase must not
contradict that.

**Pattern to follow:** `build.md:9`'s literal planner-dispatch list — same
altitude, same repo, same skill family.

**Acceptance criteria:**

- A fenced template exists whose slots are a superset of the eight items at
  `:24`; no item is dropped.
- The respawn instruction at `:29` points at the recorded prompt.
- The file still does not claim the contract is a first-dispatch input.
- No new artifact kind: `generic/rules/run-artifacts.md` is untouched.
- The two-tier separation at `:3` survives.

**Test approach / oracle:** `equivalence check`. Contingent on Decision point D8.

---

## Phase 8: Integration and verification

### 8.1: Update the repo-level docs that describe these hooks and tiers  (after: 4.1, 6.2, 7.3)

**File scope (shared touchpoint — serialized, single lane, after both lanes
merge):** `AGENTS.md`, `README.md`, `docs/architecture.md`, `docs/conventions.md`,
`docs/pipeline.md`, `generic/AGENTS.md`, `orchestrators/AGENTS.md`.

**What to change.** Both lanes' changes land in shared prose; this is why the
phase is serialized rather than split. Specific known-stale lines:

- `docs/conventions.md:216-217` — repeats the wrong Nix home-manager install
  claim corrected in 4.1.
- `generic/AGENTS.md:67-68` — describes `smart-lint.sh`/`smart-test.sh` as
  "blocking on failure"; after 2.4 and 3.1 that is only conditionally true.
- `AGENTS.md:79-80` and `docs/architecture.md:95-96` — the same claim.
- `AGENTS.md:24`, `README.md:41`, `docs/architecture.md:66` — describe `tests/`
  as covering only the lifecycle/scope scripts; two hook test files now exist.
- `orchestrators/AGENTS.md:104` and `docs/pipeline.md:48` — the builder/coder
  tier description, if phases 5–7 changed anything a reader of those summaries
  would now find wrong.
- `orchestrators/skills/dae/worktree-modes.md:15` — the no-worktree mode says
  *"no child worktrees, so no physical isolation for parallel builders"*. Since
  6.1 makes the child worktree the stated isolation boundary for sub-agents too,
  check whether this mode now needs an explicit note about what a sub-agent
  inherits when no worktree exists. Verify before editing — it may already be
  covered by the one-lane-at-a-time restriction in the same sentence.

**Pattern to follow:** `generic/rules/doc-format.md` — update in place, one topic
per page, no duplication. Keep each file's existing tree-diagram and table shapes.

**Acceptance criteria:**

- No doc asserts unconditional blocking for the two hooks.
- The `tests/` description names hook coverage.
- No doc references `.claude-hooks-ignore` or Nix home-manager installation.
- `grep -rn "claude-hooks-ignore\|home-manager" --include=*.md .` returns only
  intentional historical mentions inside `project-plans/`.

**Test approach / oracle:** `equivalence check` plus the two mechanical greps
above, whose output goes in the exit report.

---

### 8.2: Full regression run and install-drift verification  (after: 8.1)

**File scope:** none — verification only. No file is modified.

**What to do.**

1. Run all four test files individually and record `"N passed, M failed"` for
   each: `tests/plan-lifecycle.test.sh`, `tests/verify-scope-parsing.test.sh`,
   `tests/smart-lint-scoping.test.sh`, `tests/smart-test-scoping.test.sh`. There
   is no runner (confirmed: no Makefile, no `.github/`, no runner script;
   `docs/architecture.md:135`), so each is invoked by hand as
   `bash tests/<file>` per `plan-lifecycle.test.sh:5`.
2. `bash -n` every modified script.
3. Re-run the **1.1 measurement** verbatim against the fixed hook and record the
   new exit code and byte count beside the pre-fix numbers (exit 2 / 7,729 bytes
   / 113 lines). This is the plan's headline evidence and belongs in the exit
   report as a before/after table. **Record the branch every measurement was
   taken on** — per R5, this defect's output is branch-dependent (the reported
   89-error baseline exists on `feat/medusa-shop` and not on `dev`), so an
   unlabelled number is not reproducible.
4. Re-run the **live cross-repo reproduction** (Defect 1c): from a working
   directory inside one repository, edit a markdown file inside a *different*
   repository and confirm the hook now exits 0 and lints nothing. Pre-fix
   behaviour is captured in Goal & scope — exit 2, `turbo lint` in the wrong
   repo. Record both.
5. **Install reachability.** State in the exit report that
   `~/.claude/hooks/*.sh` are **copies, not symlinks** (verified: 24 regular
   files) and that no session sees these changes until
   `orchestrators/hooks/sync-install.sh` runs from `main` after a push, per
   `.claude/rules/source-push-sync.md:5-7`. Do **not** run it: the user handles
   commit, push and sync, and `sync-install.sh:83` refuses to run off `main`
   anyway, so a worktree cannot perform it. Note that
   `generic/settings/settings.json:118` runs `sync-install.sh --check` at every
   `SessionStart`, so drift will surface until the user syncs.

**Acceptance criteria:**

- All four test files exit 0.
- `bash -n` clean on `smart-lint.sh` and `smart-test.sh`.
- The before/after measurement table is in the exit report with real numbers.
- The exit report states the sync obligation and that it was deliberately not
  performed.

**Test approach / oracle:** `existing suite`.

---

## Risks, open questions, decision points

### Decision points — a human must settle these before the dependent subphase runs

**D1 (blocks 2.4) — what should smart-lint block on?**

- **(a) Attribute to the edited file** *(recommended, planned above)*. Block only
  when a finding names `TARGET_FILE`. No state, no invalidation, works for every
  language. Weakness: a genuine cross-file break (an edit that breaks a
  *different* file's lint) becomes advisory rather than blocking.
- **(b) Stored baseline diff.** Record findings per repo+branch under
  `$HOME/.claude/state/smart-lint/`, report only new ones. Strictly more accurate
  than (a), including cross-file breaks. Costs: where the baseline lives, when it
  is invalidated (branch switch, dependency install, linter version change,
  concurrent lanes writing the same baseline), and a stale baseline hides real
  regressions — the failure mode is silent.
- **(c) Never block; always advisory.** Simplest and fully removes the
  `scope-writes.sh` contradiction. Costs the hook its enforcement value, which
  `AGENTS.md:84-85` says is the entire reason a hook exists rather than a rule.

Recommendation: **(a)** now, **(b)** as a separate later plan if (a) proves too
loose in practice. (a) and (b) compose — (b) can be added behind an opt-in
variable without undoing (a).

**D2 (blocks 2.1) — which extensions count as lintable?** The core set
(`.go .py .js .jsx .mjs .cjs .ts .tsx .rs .nix`) is uncontroversial. The
question is the formatter surface Prettier owns: `.json .css .scss .html .yaml
.yml .md .svelte .vue`. Including them means a markdown edit **outside** a
gitignored path still runs Prettier — which is arguably correct (Prettier does
format markdown) and arguably the exact defect being fixed. Options: **(a)**
source-only, formatters never fire on doc/config files; **(b)** include the
formatter surface but only for the `prettier --check <single file>` path, never
the ESLint path. Recommendation: **(b)** — it keeps formatting enforcement while
never triggering a repo-wide lint from a doc edit. Needs a human call because it
changes what gets auto-formatted.

**D3 (blocks 2.1) — delete or wire up `.claude-hooks-ignore`?** It is documented
(`README.md:123-133`) but has never worked. **(a)** Delete the dead code and the
example file; rely on `git check-ignore` *(planned above)*. **(b)** Wire
`should_skip_file()` into the gate, keeping both mechanisms. (b) preserves a
documented feature some consuming project might expect; nothing in this repo
uses it, and no `.claude-hooks-ignore` exists in any project on this machine that
was checked. Recommendation: **(a)**, per `AGENTS.md`'s delete-old-code rule.

**D4 (Defect 3) — consolidate the always-on rules? Measured recommendation: no.**

| Rule | bytes | words | share |
|---|---|---|---|
| `plan-format.md` | 8,152 | 1,271 | 31% |
| `run-artifacts.md` | 6,238 | 999 | 24% |
| `artifact-locations.md` | 5,831 | 794 | 22% |
| `shell-discipline.md` | 1,762 | 277 | 7% |
| `doc-format.md` | 1,914 | 270 | 7% |
| `tech-agnostic.md` | 915 | 144 | 3% |
| `respect-versions-and-conventions.md` | 440 | 57 | 2% |
| `verify-dont-assume.md` | 409 | 64 | 2% |
| `model-policy.md` | 455 | 63 | 2% |
| `push-policy.md` | 401 | 63 | 2% |
| **total** | **26,517** | **4,002** | |

26.5 KB is roughly **6,600 tokens, once per session**. Defect 1 measured
**7,729 bytes ≈ 2,000–2,600 tokens per trigger, recurring** — at the reported ten
triggers, three to four times the entire rule payload, every session. Merging
`artifact-locations.md` and `run-artifacts.md` (the genuine overlap, 12,069 bytes
combined) could plausibly recover 2–3 KB ≈ 600 tokens once — under 3% of what
Defect 1 costs, against a real risk of losing a load-bearing distinction. Both
rules were referenced repeatedly during the reporting session; `model-policy.md`,
the one never consulted, is 455 bytes and not worth touching. **Recommendation:
do nothing.** If the user wants it anyway, it belongs in its own plan with its
own review gate, not bolted onto a bugfix — the bugfix module's minimal-scope
rule.

**D5 — add a test runner?** The repo deliberately has no CI
(`docs/architecture.md:135`) and tests are run by hand. This plan adds two test
files, bringing the total to four, at which point "run them by hand" starts to
leak. Options: **(a)** leave it; **(b)** add `tests/run-all.sh` (a dozen lines,
no dependencies). Recommendation: **(a)** for this plan — it is scope creep on a
bugfix — but flagging it as the obvious next small plan.

**D6 (informs 5.1, 6.1, 7.2) — SendMessage addressing: three field data points,
still nothing the repo states.** Originally flagged as unverified. The evidence is
now stronger and **bidirectional**: a coder's report reached the orchestrator
instead of its builder; the orchestrator's own `SendMessage` to `builder` was
rejected with *"No agent named 'builder' is reachable"* and worked only by raw
agent id. So name-based addressing is unreliable in both directions.

This remains **behavioural evidence about the harness, not repo content**, and
static inspection cannot settle it — the repo documents builder↔coder addressing
nowhere, and every `SendMessage` mention is orchestrator→warm-planner. The
position is unchanged and now better justified: phases 5–7 are designed to be
**correct either way**, asserting nothing about addressing and making the disk
authoritative throughout. Recording agent ids at dispatch (so a fallback address
exists) is a plausible additional mitigation but depends on harness behaviour this
plan cannot verify — raised here rather than planned. A dedicated diagnose run
against the harness is the honest route if the user wants the mechanism itself
understood.

**D9 (blocks 6.1, 6.2) — how much harness behaviour should the docs assert?** The
`isolation: "worktree"` incident is described in terms of specific harness
internals: `.claude/worktrees/agent-<id>` paths, `EnterWorktree` refusing an
unregistered worktree, `ExitWorktree` refusing a subagent with a cwd override.
None of that is a documented contract, and `generic/rules/tech-agnostic.md`'s
spirit — do not hard-code what you have not verified as stable — argues against
writing it down as fact. Options: **(a)** state only the rule and the reason
("the lane's child worktree is the isolation; never nest another"), keeping the
docs true even if the harness changes *(recommended, planned above)*; **(b)** also
document the observed symptoms so a future reader recognizes the failure mode
quickly, at the cost of encoding possibly-unstable behaviour; **(c)** treat it as
a harness bug to report upstream rather than a doc fix. (a) and (c) are not
exclusive — the prohibition is worth having regardless of whether the harness
changes.

**D7 (blocks 5.2) — per-packet artifact kind?** **(a)** Minimal *(planned)*: the
packet's own files are the deliverable; no schema change; `run-artifacts.md`
untouched. **(b)** Add `packets/<lane-id>-<packet>.md` as a fifth run-dir artifact
kind, giving the builder an unambiguous existence check. (b) is cleaner and
matches how every other tier works, but it edits an always-on rule, expands the
run-dir schema, and adds a write to every coder — a real cost for a stall that
(a) already prevents. Recommendation: **(a)**.

**D8 (blocks 7.3) — where does the filled dispatch prompt live?** **(a)** In the
progress log *(planned)* — no new artifact kind, already the designated resume
state (`run-artifacts.md:26`). **(b)** A dedicated
`.artifacts/dispatch/<lane-id>.md`. (b) is tidier for a machine to read back; (a)
keeps the run dir's schema fixed and puts the prompt where a resuming session
already looks first. Recommendation: **(a)**.

### Risks

- **R1 — a scoping gate can hide a real regression.** Narrowing what smart-lint
  examines means an edit that breaks a *different* file's lint may go unreported
  until the `dae` integration pass. Mitigation: `workflow-diff-check.sh` (Stop,
  on `dae`) and the per-wave/integration checks in `build.md:13` still run the
  project's full checks on changed files. The PostToolUse hook is the fast inner
  loop, not the gate of record. This is a deliberate trade and belongs in the
  plan-review discussion.
- **R2 — `git check-ignore` skips gitignored generated source.** A project that
  gitignores generated `.ts`/`.go` it still wants linted loses coverage.
  Judged acceptable and arguably correct; no such case exists in this repo or the
  reporting project. Documented in 4.1 so it is discoverable.
- **R3 — no test coverage exists for these hooks today.** Confirmed: `tests/`
  contains two files, both targeting `orchestrators/hooks/`; a grep for any
  `generic/hooks` name across `tests/*.sh` returns nothing. So 1.1 and 1.2 are
  writing the first tests for an 766-line and a 714-line script, and can only
  cover the paths this plan touches. Regressions elsewhere in those scripts
  remain possible. Adding the tests is in scope precisely because changing
  untested behaviour otherwise has no oracle.
- **R4 — the fix is invisible until synced.** `~/.claude/hooks/` holds copies.
  Until the user pushes to `main` and runs `sync-install.sh`, every live session
  keeps the old behaviour, and `claude-install-drift.sh` will warn (advisorily)
  on each source edit. 8.2 records the obligation; it cannot discharge it, since
  `sync-install.sh:83` refuses to run off `main`.
- **R5 (narrowed) — the field baseline is branch-dependent, not doubtful.** My
  first draft flagged the reported 89 `apps/admin` ESLint errors as "not
  reproducible" because `pnpm lint` passes on `mythic-made` at `dev` (2 tasks,
  both cached, 916 bytes). That was a wrong inference from the right observation:
  those errors live only on `feat/medusa-shop`, which carries shop-only admin code
  (`printful-fulfillment/**`, the OAuth callbacks, the auth subscribers) that
  `dev` does not have, and they reproduced at three independent measurements on
  that branch. **The reported figure stands.** The residual risk is only that a
  measurement of this defect is meaningless without naming the branch it was
  taken on — 8.2's before/after table must record the branch alongside the
  numbers. My fixture figures are unaffected: they were never dependent on
  mythic-made at all.
- **R8 — phases 5–7 fix documentation for a failure whose mechanism is a
  harness behaviour.** Every remedy makes agents independent of messaging rather
  than fixing messaging, because messaging is not this repo's to fix. If the
  underlying addressing behaviour changes, the guidance stays correct but the
  original stall becomes unreproducible, so the fix can never be *demonstrated*
  to work — only reasoned about. This is the honest limit of a docs-only remedy
  and the reason D6 keeps pointing at a separate diagnose run.
- **R9 — lane 2 grew from 3 subphases to 8.** The three new incidents all landed
  in the orchestration-markdown lane, and its four files (`builder.md`,
  `coder.md`, `contract-tester.md`, `build-dispatch.md`) are touched by many
  subphases in overlapping combinations — `builder.md` alone by 5.1, 5.3, 6.1 and
  7.1. Splitting lane 2 was considered and **rejected**: the overlap cannot be
  hoisted into an integration subphase without serializing the very files that
  would need to be split, so per the disjoint-file-scope rule the correct move is
  to keep it merged. Lane 2 is now larger than lane 1; that is a load-balance
  cost accepted to preserve scope separation, and it does not delay lane 1, which
  carries the dominant defect and runs concurrently.
- **R6 — bash 3.2 portability is unverified by the tests themselves.** The
  existing test files already use `md5sum` (GNU-only;
  `plan-lifecycle.test.sh:71,340`), so the harness is *less* portable than the
  hooks it tests. New tests must not deepen that: no `mapfile`, no `md5sum` in
  the new files. There is no macOS host available here to verify against, so
  portability is enforced by code review against the constraint, not by
  execution.
- **R7 — lane 2 has no executable oracle.** Every subphase in phases 5 and 6
  edits markdown agent/skill definitions. Their correctness is judged by the
  review-code gate against the stated acceptance criteria. If the gate wants
  machine-checkable evidence, the only honest options are static greps for
  required phrases, which are brittle. Stated plainly rather than papered over.

### Open questions

- **Q1** — should `CLAUDE_HOOKS_OUTPUT_LINES` default to 30 (matching
  `test-changed.sh`/`workflow-diff-check.sh`) or lower? 30 lines of ESLint output
  is roughly 600–900 bytes, which seems right, but the number is a guess
  calibrated to the existing convention rather than to measurement.
- **Q2** — after 3.2 changes the `CLAUDE_HOOKS_TEST_MODES` default, does any
  consuming project rely on `package` mode? No `.claude-hooks-config.sh` exists
  in this repo or in `money-makers/mythic-made`; other projects were not
  surveyed.
- **Q3** — `sync-install.sh:117-119` resolves a `hooks/<file>` unit by trying
  `generic/` then `orchestrators/`, first hit wins, so identically-named hook
  files silently shadow. No collision exists today. Worth knowing; not fixed
  here.

---

## Skill mapping

| Work | Executor |
|---|---|
| Whole run | `dae` (`--type bugfix`), routing through `build.md` and `build-dispatch.md` |
| This plan; amendments from the gate | `planner` (warm, `plan-bugfix` module) |
| Plan approval | `review-plan` |
| Lane 1 and lane 2 | `builder`, one per lane, per `build-dispatch.md` |
| 1.1, 1.2 and the added cases in 2.2–2.4, 3.2 | `contract-tester` — written from the contract slice alone, never reading `smart-lint.sh`/`smart-test.sh` source (`contract-tester.md:9`) |
| 2.1–2.4, 3.1–3.2 | `coder`, packets scoped one hook script each |
| 4.1, 5.1–5.3, 6.1–6.2, 7.1–7.3, 8.1 | `coder` (markdown edits; oracle is the review gate, not tests) |
| 8.2 | the lane-1 `builder`'s own exit verification |
| Post-build review | `review-code`, then `review-pr` |
| Commit, push, install sync | **the user**, per `.claude/rules/source-push-sync.md` — `push-main`, then `sync-install.sh` from `main`. Not performed by this run. |
| Doc updates in 8.1 | `document-local` if the orchestrator prefers a dedicated pass; otherwise inline in the serialized phase |
