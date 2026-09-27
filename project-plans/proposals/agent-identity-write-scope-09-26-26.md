# Role identity comes from the harness, not from a file

### Ask of record

Verbatim and append-only, per `plan-format`'s Ask of record rule (the inline form landed by the
predecessor run's Phase 6; there is no separate `the-ask.md`, which that same phase retired from
the run dir — so this section IS the durable ask artifact, not a pointer to one).

**09-26-26** — the ask, assembled from the user's own words across the predecessor run
`write-enforcement-and-ask-inlining-09-01-26`:

> its more like orchestrators dont make writes PERIOD, planners can only edit things in the
> PLAN_DIR env var, and builders cant edit anything in the PLAN_DIR or DOCS_DIR

> the main thing with hooks is to make sure that everything that needs a gate gets one, but ONLY
> the things that need them. dont over gate things

> orchestrators should do nothing but manage agents. so anything that writes should be an agent

And the decision that created this plan: land the current work, then rebuild the role mechanism on
agent identity in a follow-up.

## Phase syllabus

- [ ] Phase 1: Prove the mechanism before anything is built on it
  - [ ] 1.1: Regression tests reproducing all three forgeries, observed RED
  - [ ] 1.2: Live-capture `agent_type` at every real dispatch hop         (after: 1.1)
  - [ ] 1.3: Live-capture what a forked skill reports, with and without `agent:` (after: 1.2)
  - [ ] 1.4: Re-baseline against what the predecessor run actually landed
- [ ] Phase 2: The write hooks resolve identity from the harness
  - [ ] 2.1: `scope-writes.sh` — the identity table, `dae-role` read deleted (lane 1, after: 1.2, 1.4)
  - [ ] 2.2: `parent-tree-guard.sh` — the same table, helpers byte-identical (lane 1, after: 2.1)
  - [ ] 2.3: Run detection stops depending on a deletable file            (lane 1, after: 2.2)
  - [ ] 2.4: `smart-test.sh` — the blind roles get a real signal          (lane 1, after: 2.1)
  - [ ] 2.5: `workflow-setup.sh` / `resolve-scratch.sh` — the token is gone (lane 1, after: 2.3)
  - [ ] 2.6: Contract tests — every identity against every root          (lane 1, after: 2.5)
  - [ ] 2.7: Fail-open verification, positive-controlled                  (lane 1, after: 2.6)
- [ ] Phase 3: The audit machinery stops losing claims
  - [ ] 3.1: `claims_from_report()` reads every path in a bullet          (lane 2, after: 1.4)
  - [ ] 3.2: The claim-line contract gets an owner                        (lane 2, after: 3.1)
  - [ ] 3.3: `pr-ready-hygiene-guard.sh` stops firing on mentions of the flip (lane 2, after: 1.4)
  - [ ] 3.4: Contract tests for both parsers and the guard                (lane 2, after: 3.2, 3.3)
- [ ] Phase 4: Every writing agent carries a real identity
  - [ ] 4.1: The three gate skills get an identity                        (lane 3, after: 1.3, 2.1)
  - [ ] 4.2: `explore`'s map and claim writes get an identity             (lane 3, after: 4.1)
  - [ ] 4.3: The `--set-role` bracket is removed and every spawn site audited (lane 3, after: 2.5)
  - [ ] 4.4: The role model is rewritten as the identity model across the docs (lane 3, after: 4.3)
  - [ ] 4.5: An inventory test pins the fork/agent wiring                  (lane 3, after: 4.4)
- [ ] Phase 5: The shared touchpoints, and the items decided at the gate
  - [ ] 5.1: `check-diff-hygiene.sh` wiring                               (after: 2.7, 3.4, 4.5)
  - [ ] 5.2: `record-changed.sh` / `test-changed.sh`                      (after: 5.1)
  - [ ] 5.3: The two pre-plan unclaimed files                             (after: 5.1)
  - [ ] 5.4: The Antigravity port's identity gap                          (after: 5.1)
- [ ] Phase 6: Verification
  - [ ] 6.1: Whole suite, `bash -n`, shared-helper diff                   (after: 5.1, 5.2, 5.3, 5.4)
  - [ ] 6.2: The forgery drill, driven through a real dispatch chain      (after: 6.1)

## Goal & scope

**In.** Replace `.artifacts/dae-role` — a file any agent can write with one line of Bash and delete
with another — as the signal that decides which write roots an agent may touch. The replacement is
the harness-supplied `agent_type` field on the hook payload, which an agent cannot set. With that in
place, close the defects the predecessor run deliberately deferred: the dormant `coder`/
`contract-tester` isolation fix (DP-4), the orchestrator↔planner shared-cwd forgery (DP-1's
residual), `sync.md`'s missing planner bracket, and the ownership ledger's lossy claim parser. Two
further items — a hygiene check with no trigger in this repo, and two unreachable scripts — are
presented as decisions, not planned work.

**Out.** Any change to the *path rules* themselves — which roots each role may write. Those were
settled at the predecessor run's plan gate, drilled, and shipped; this plan re-anchors them on a
different identity signal and changes none of them. Also out: re-litigating anything the
predecessor run's code gate has already closed across six rounds, and the `--worktree none` parent
redesign parked at `project-plans/proposals/none-mode-parent-08-28-26.md`.

**Relationship to the predecessor.** This plan **supersedes nothing**. `write-enforcement-and-ask-
inlining-09-01-26` ships the path rules, the ask-inlining, the base-branch fix, the plan gate, and
the `documenter` agent; all of that stands. This is the follow-up the user asked for when they
decided to land that work and rebuild the role mechanism afterwards.

**Why this order.** Phase 1 is first and gates everything because the predecessor run's own code
gate reversed its verdict twice over exactly one question — whether the real dispatch chain produces
the identity the hook checks for. Nothing in Phase 2 is worth writing until that is measured.

## Evidence inherited from the predecessor run

The predecessor's reasoning lives in `.artifacts/progress-log.md`, which is gitignored and dies with
its worktree. Its code gate flagged that loss as a risk in rounds 3, 4 and 6. The load-bearing parts
are preserved here, so this plan stands without it.

**The probe that established the mechanism (09-15-26, predecessor run).** A throwaway hook wired
into the gitignored `.claude/settings.local.json` captured real payloads:

```
agent_type='<ABSENT>'         agent_id='<ABSENT>'      session=1c20bf61   main session
agent_type='Explore'          agent_id='a3621a3d...'   session=1c20bf61   a subagent
agent_type='general-purpose'  agent_id='a24f6a0a...'   a `context: fork` skill via the Skill tool
```

`session_id` is **identical** across parent and subagent, so it cannot distinguish them.
`agent_type`/`agent_id` can, and the harness supplies them. The probe was removed afterwards.

**Corroborated against Claude Code's current documentation** (fetched 09-26-26, not recalled):
`sub-agents.md` states an agent definition's `name` field — *"Hooks receive this value as
`agent_type`"*; `hooks.md` lists `agent_id` as *"Present only when the hook fires inside a subagent
call"* and `agent_type` as *"Present when session uses `--agent` or hook fires inside a subagent"*;
`skills.md` states that a skill's `agent:` key accepts *"`Explore`, `Plan`, `general-purpose`, or
custom agents from `.claude/agents/`"*. No other hook-input field identifies the calling agent or its
dispatch parent — there is no parent id, no nesting depth.

**Three forgeries, all reproduced by the predecessor run against real hooks in throwaway repos.**

1. *Role forgery.* `echo builder > .artifacts/dae-role` flipped a denied product write to allowed
   (code gate round 1). Closed on the branch for the literal token `builder` by a git-topology
   check plus a tamper check — but `orchestrator` and `planner` are still honored from the file
   unconditionally, and round 2 reproduced `printf 'planner' > .artifacts/dae-role` promoting an
   orchestrator to full plans-dir write access (`proposals/p.md`: exit 2 before, exit 0 after).
2. *Marker deletion.* `rm .artifacts/progress-log.md` returns both guards to exit 0 for everything.
   `.artifacts/` is gitignored, so `git status --porcelain` never reports the deletion, and
   `parent-tree-guard.sh` is `PostToolUse` — by the time it runs there is nothing left to detect
   against. Round 2 called this *"strictly more powerful than the role forgery it closed"*; round 3
   accepted it as a disclosed limitation on the user's decision to land and fix it here.
3. *Shared cwd.* The planner is spawned with no worktree of its own, so no path-based check
   separates it from the orchestrator. That is DP-1, and the `--set-role` bracket it produced is a
   workaround for the missing identity, not a fix.

**Two false cleans, both caught by positive controls, both recorded rather than hidden.** A search
for leftover claims returned zero because its `grep -v` filter excluded `.workflows` — and the
worktree itself lives under `.workflows`, so every real hit was discarded. A gate's first
documenter drill returned exit 0 on all nine payloads because it omitted `tool_name` and hit the
wrong-tool short-circuit; read as "it works", that run would have passed a broken guard.

**The verification lesson, stated as the predecessor's gate stated it.** Round 3 verified the
documenter fix *"by execution"* — by injecting `agent_type=documenter` into synthetic hook payloads
and confirming the write was allowed. Round 5 retracted it: *"Injecting `agent_type` into synthetic
JSON tests the lock, not the key — and every drill on record tested the lock."* The real dispatch
chain (documenter agent → `document-local` as a `context: fork` skill) did **not** carry that value,
because a fork with no `agent:` key spawns under its own default type. The fix took three further
rounds to close. **Every acceptance criterion in this plan tests the key.**

**Still open on the predecessor branch at the time of writing** (code gate round 6, `rejected` /
`impl-wrong`): `scope-writes.sh:281`'s allowance for a lane's own `contracts/<lane-id>.md` and
`reports/<lane-id>-exit.md` is gated on the payload's `cwd`, which Claude Code's `hooks.md`
documents as *"the new directory after Claude runs `cd`"* — mutable shell state, not a structural
signal. The gate's own suggested fix is the move this plan makes everywhere else: key it on
`agent_type`. Subphase 1.4 measures whatever shape that finding closed in before Phase 2 builds on
it.

## Stack & MAJOR versions

| Thing | Version / constraint | Verified from |
|---|---|---|
| Shell | GNU bash 5.1.16; `set -uo pipefail`; POSIX-ish, no bashisms beyond `[[ =~ ]]` | `bash --version`; `agent-agnostic/hooks/scope-writes.sh:1`, `:108` |
| Package manifest | **none** — no `package.json`, `pyproject.toml`, or `go.mod` anywhere in the tree | `find . -maxdepth 2` for all three returned empty; the repo is bash + markdown |
| Hook payload parsing | flat `grep -oE` + `sed -E` field extraction, **deliberately no `jq`** | `scope-writes.sh:250` (`# tool_name, without jq`), `resolve-config.sh:23-24` |
| `jq` availability | present at `/usr/bin/jq` but NOT relied on; only `agy-hook-adapter.sh` uses it, and it degrades gracefully when absent | `command -v jq`; `agy-hook-adapter.sh:52-55` |
| `python3` | 3.11.7 — used by exactly two hooks (`check-diff-hygiene.sh`, `pr-ready-hygiene-guard.sh`) and by `sync-install.sh`'s settings merge | `python3 --version`; `pr-ready-hygiene-guard.sh:15-20` |
| Test harness | plain bash suites under `tests/`, `pass`/`fail` helpers, `# Case NN:` banners, exit 0/1 | 20 files under `tests/`; `tests/scope-writes.test.sh` |
| `grep` | **ugrep 7.8.4**, not GNU grep | `grep --version` |
| `awk` | **mawk** (rejects `--version`) | `awk --version` → `awk: not an option` |
| Hook config (Claude) | `agent-specific/claude/settings.json`, MERGED not copied into `~/.claude/settings.json` | `.claude/rules/source-push-sync.md`; `tests/sync-install-settings-merge.test.sh` |
| Hook config (Antigravity) | `agent-specific/antigravity/hooks.json` via `agy-hook-adapter.sh` | `agent-specific/antigravity/hooks.json` |

## Conventions to enforce

- **`scope-writes.sh` and `parent-tree-guard.sh` share four helpers VERBATIM by design** —
  `find_parent_worktree`, `resolve_root_dir`, `find_lane_root`, `resolve_role`. Any commit touching
  one touches both, byte for byte. This is not a convention anyone has to remember: it is
  test-enforced at `tests/parent-tree-guard.test.sh:904-946`, which sed-extracts all four from both
  files, asserts each extract is non-empty (its own positive control), and diffs. Current state,
  measured 09-26-26: all four identical (`find_parent_worktree` md5 `f7c466b99061…`,
  `find_lane_root` `bad61220d33a…`, `resolve_role` `680a78a949bd…`, `resolve_root_dir`
  `7c4dea1cd3f1…`). **There is a fifth verbatim copy nobody has a test for:**
  `claims_from_report()` exists identically in `verify-run-scope.sh:42-92` and
  `verify-scope.sh:39-89`. Phase 3 must keep those two in sync and add the missing diff assertion.
- **Fail open, never closed.** No marker, unknown identity, git failure, config failure → exit 0.
  A change that turned this fail-closed would block work repo-wide, in every session, including
  sessions that have nothing to do with a dae run. Subphase 2.7 exists solely to verify this, and it
  is the reason no subphase here may introduce a denial on a *resolution* failure.
- **Least privilege on an unresolved identity, inside a detected run.** Fail-open governs the
  *undetected* case. Inside a detected run an unrecognized or absent identity resolves to the most
  restrictive role valid at that location — this is the correction the predecessor run made to its
  own subphase 2.1 after a gate found the original wording specified a privilege *upgrade*.
- **Positive controls are mandatory in every test and every search.** A hook that exits 0 because
  the fixture was malformed is indistinguishable from one that permits the action. A search that
  returns zero because its filter was wrong is indistinguishable from a clean tree. Both happened in
  the predecessor run.
- **Assert on output CONTENT, never on exit status alone.** `grep` here is ugrep and `awk` is mawk;
  both mis-parse leading `--` and produce wrong answers that look like right ones.
- **Test the key, not the lock.** An acceptance criterion satisfied by injecting a value into a
  hand-built payload proves only that the hook reads the value. Every identity criterion in this
  plan must additionally show that the *real dispatch* produces it.
- **Never `git add -A`.** Name the paths. A single `-A` in this repo swept an unrelated 8.4MB file
  onto `main` permanently.
- **No attribution trailers** in any commit message — no `Co-Authored-By`, no `Claude-Session`, no
  session URL. Enforced by `no-attribution-guard.sh` (`PreToolUse` on Bash) and by the
  `no-attribution-trailers` rule.
- No time estimates anywhere.

## Phase 1: Prove the mechanism before anything is built on it

Serial, no lane. Every later phase depends on what this phase measures; no builder is dispatched
until it is done. Phase 1 creates `tests/identity-forgery.test.sh`, which lane 1 owns from Phase 2
onward — the one file that crosses this boundary, stated here so nobody else claims it.

### 1.1 — Regression tests reproducing all three forgeries, observed RED

- **Files:** `tests/identity-forgery.test.sh` *(new)*
- **Pattern:** `tests/l6-role-escalation-e2e.test.sh` — it already builds a throwaway git repo, runs
  the REAL `workflow-setup.sh` to create a parent worktree and a `--parent` lane child, and drives
  the real hooks with crafted payloads. Case 04 there is the existing worked example of "reproduce
  the exploit, then assert it is closed".
- **Reproduction, exactly:**
  1. *Role forgery (planner arm).* Fresh parent worktree; `printf 'orchestrator' >
     .artifacts/dae-role`; feed `scope-writes.sh` a Write payload for
     `project-plans/proposals/p-01-01-26.md` → **expect exit 2**. Then `printf 'planner' >
     .artifacts/dae-role`; identical payload → **observed exit 0**. Expected after Phase 2: exit 2.
  2. *Marker deletion.* Same parent, role `orchestrator`; Write payload for `src/app.js` → exit 2.
     Then `rm .artifacts/progress-log.md`; identical payload → **observed exit 0**; and
     `parent-tree-guard.sh` on a dirty tree → **observed exit 0**. Expected after Phase 2: per DP-1.
  3. *Shared cwd.* From the parent worktree's own cwd, a payload carrying no `agent_type` and a
     payload carrying `agent_type=planner` must be **distinguishable**; today they are not, because
     `resolve_role` reads the file before it ever looks at the identity for anything but
     `documenter`. Assert today's indistinguishability, so the test flips when Phase 2 lands.
- **Criteria:** all three cases FAIL (red) against the tree as it stands, and each carries a
  positive control proving the harness can produce the opposite outcome on the same fixture. A test
  that is green before the fix has not reproduced anything.
- **Test oracle:** `new contract tests`. These three cases are the oracle for Phase 2.

### 1.2 — Live-capture `agent_type` at every real dispatch hop

- **Files:** none in the product tree. The probe writes only to a scratch log and to the gitignored
  `.claude/settings.local.json`, and both are removed before the subphase closes.
- **Pattern:** the predecessor run's own 09-15-26 probe, described above — a throwaway hook wired
  into `.claude/settings.local.json` appending the payload's `agent_type`, `agent_id`, `session_id`,
  `tool_name` and `cwd` to a log, then a real dispatch, then read the log, then remove the probe.
  **The gotcha that run recorded: a settings hook is picked up mid-session; a NEW agent definition
  may not be.** Claude Code's `sub-agents.md` says agent files are watched and picked up within
  seconds, with three stated exceptions (a newly created agents *directory*, agents under
  `--add-dir`, and sessions run with `--disable-slash-commands`). The repo's own experience
  contradicts the happy path, so this subphase MUST measure it rather than trust either source: if
  a freshly added definition is not dispatchable, every later probe needs a fresh session.
- **Criteria:** a committed evidence table giving the observed `agent_type` for each of:
  the main session (dae's own context); `planner`; `builder`; `coder`; `contract-tester`;
  `committee`; `documenter`; and a plain `Explore`. Each row records the value as captured from a
  real hook invocation, with the dispatch that produced it named. Missing rows are recorded as
  missing, never inferred. **Positive control:** at least one row must be a value the probe could
  have failed to see — the main session's ABSENT is that control, since a probe that logged a value
  there would prove the probe is reading the wrong thing.
  The table lands in the plan's dir as part of lane 1's contract inputs, not only in a report.
- **Known constraint to record, not to work around:** `documenter` exists only on the predecessor
  branch and is not installed at `~/.claude/agents/`; this session's own agent roster lists exactly
  `builder`, `coder`, `committee`, `contract-tester`, `planner` — the five definitions that ARE
  installed — which is first-hand evidence that a custom definition's `name` becomes a dispatchable
  subagent type. It is not yet evidence about the hook payload; that is what this subphase measures.
- **Test oracle:** `existing implementation` — the harness's observed behavior is the truth source.

### 1.3 — Live-capture what a forked skill reports, with and without `agent:`

- **Files:** none in the product tree; same probe-and-remove discipline as 1.2.
- **Criteria:** three measured rows: (a) a `context: fork` skill with **no** `agent:` key —
  expected `general-purpose` per the predecessor's probe, but measured again here; (b) the same
  skill with `agent: Explore` (a documented built-in); (c) the same skill with `agent: <a custom
  agent installed from this repo>`. Row (c) is the one the plan actually depends on, and it is
  **unverified today** — `skills.md` documents that custom agents are accepted, and **zero files in
  this repo declare `agent:` anywhere** (positive-controlled: the same search run returned 9 files
  for `^context: fork`, so the anchor and the tool both work). Documentation is not measurement.
- **Consequence if row (c) fails:** DP-2 loses its cheapest option and must resolve to removing
  `context: fork` from the gate skills (the route the predecessor run took for `document-local`) or
  to dispatching the gates as agents. The plan must not proceed on the assumption.
- **Test oracle:** `existing implementation`.

### 1.4 — Re-baseline against what the predecessor run actually landed

- **Files:** none written. Reads `main` after the predecessor lands.
- **Criteria:** a written baseline covering, each verified against the file and not against a report:
  1. Whether `scope-writes.sh:281`'s `cwd`-keyed contract/exit-report allowance still exists, and in
     what form. If it still trusts `cwd`, Phase 2 absorbs it (see DP-1's note); if it was re-keyed
     on `agent_type`, Phase 2 must not re-implement it.
  2. Whether all three of 1.1's reproductions still reproduce. A reproduction that has quietly gone
     away is a fact, not a convenience — record it and drop the corresponding case.
  3. The four shared helpers' md5s, re-measured, and the `claims_from_report()` pair's.
  4. **An open question to settle, not assume:** `parent-tree-guard.sh`'s orchestrator arm treats a
     `plan.md` change in the parent worktree as an offender, while `builder.md` says the
     orchestrator ticks the syllabus from the builder's report (via `mark-syllabus.sh`) and
     `documenter.md` says `document-local` makes those ticks. Establish which of those is true
     today, by drilling `mark-syllabus.sh` against a marked parent. If the orchestrator's own
     syllabus ticks are in fact denied, that is a defect this plan must either fix or record.
  5. Whether `docs/known-issues.md`'s `-w none` entry — which says that mode "creates no run dir
     (no `.artifacts/`)" — still matches behavior after the predecessor's Phase 11 made `none` mode
     seed `<repo-root>/.artifacts/`. If it is stale, it belongs in 5.3's scope.
- **Test oracle:** `existing implementation`.

## Phase 2: The write hooks resolve identity from the harness (lane 1)

### 2.1 — `scope-writes.sh` — the identity table, `dae-role` read deleted

- **Files:** `agent-agnostic/hooks/scope-writes.sh`
- **Pattern to follow — it already exists in this file.** The payload extraction is written:
  `scope-writes.sh:267-268` pulls `agent_type` with the same flat `grep -oE`/`sed -E` idiom the file
  uses for `tool_name`, `file_path` and `cwd`; `:294` passes it into `resolve_role` as `$3`; and
  `resolve_role:203-206` already short-circuits on `agent_type = documenter` **before** reading the
  marker. This subphase generalizes that existing short-circuit into the whole table and deletes
  `:211` (the `cat .../dae-role` read). It is a change to roughly five lines of logic plus the
  doc-comment, not a rewrite.
- **The table, and where each identity comes from:**

  | Identity | Source | Allowed roots (unchanged from what shipped) |
  |---|---|---|
  | `planner` | `agent_type` | the resolved plans root only, plus the explore-map and committee files already carved out at `:317-327` |
  | `builder` | `agent_type`, **or** structurally via `find_lane_root` | everything EXCEPT the plans root and the docs root |
  | `coder`, `contract-tester` | `agent_type` | same as `builder` (they write inside a lane) |
  | `documenter` | `agent_type` | the docs root, plus `plan.md` under the plans root |
  | `committee` | `agent_type` | its own `committees/<skill>/` files under the run dir |
  | `orchestrator` | **absence** of a recognized `agent_type` in a linked-worktree parent | this run's `*-review.md` and `sync-report.md` under the plans root, and nothing else — unless DP-2 moves the gates to their own identity, in which case this becomes empty |
  | `scratch` | structural: the marked root IS the main checkout | its own `.artifacts/` subtree |

- **Criteria:**
  - `resolve_role` reads no file. Its inputs are the marked root, the lane flag, and `agent_type`.
  - An unrecognized `agent_type` inside a detected run resolves to the most restrictive identity
    valid at that location — `orchestrator` in a linked-worktree parent, `scratch` in the main
    checkout. This covers the documented edge case where a main session started with `--agent X`
    carries an unexpected `agent_type`: least privilege makes it safe without a special case.
  - The structural `builder` derivation via `find_lane_root` is kept. It is not redundant with
    `agent_type=builder`: it is what keeps a lane child scoped when the identity is missing.
  - `agent_type` and the lane derivation must AGREE or the more restrictive wins. A `coder` payload
    arriving from outside any lane root does not become a builder.
- **Test approach:** 1.1's three cases flip from red to green, plus 2.6's matrix. **The criterion is
  not satisfied by synthetic payloads alone** — 6.2 drives it through a real dispatch.
- **Test oracle:** `new contract tests` (2.6) plus the 1.1 regression cases.

### 2.2 — `parent-tree-guard.sh` — the same table, helpers byte-identical

- **Files:** `agent-agnostic/hooks/parent-tree-guard.sh`
- **Pattern:** this file already reads `agent_type` at `:105` via its own `sfield` helper, and
  carries byte-identical copies of all four shared helpers (at `:107-229` and `:258-270`; note the
  placement differs from `scope-writes.sh` — `resolve_root_dir` sits after the git-status call
  here). Mirror 2.1's `resolve_role` exactly, character for character.
- **Criteria:**
  - The four helpers remain byte-identical to `scope-writes.sh`'s, verified by extraction and diff
    with a non-empty assertion on each extract, in the SAME commit as 2.1.
  - The tamper check at `:242-253` — which fires on the literal string `builder` in `dae-role` — is
    **deleted**, not left as dead code. There is no marker to tamper with once 2.5 lands, and a
    guard that reads a file nothing writes is the "wired but dead" class this run exists to remove.
  - The git-status offender classification (`:294-335`) keeps the same per-identity arms as
    `scope-writes.sh`'s allow-list, inverted as it is today.
  - Both hook events it serves (`PostToolUse` on Bash, and `Stop`) behave identically.
- **Test approach:** `tests/parent-tree-guard.test.sh` case 19 (the existing byte-identity diff) must
  pass unchanged; cases 21/22/23/26 (the forged-token corpus) are rewritten against the identity
  table rather than deleted, because the *escalations* they describe must still be denied even
  though the mechanism changed.
- **Test oracle:** `new contract tests` plus `existing suite`.

### 2.3 — Run detection stops depending on a deletable file

- **Files:** `agent-agnostic/hooks/scope-writes.sh`, `agent-agnostic/hooks/parent-tree-guard.sh`,
  `agent-agnostic/hooks/workflow-diff-check.sh`, and — only if DP-1 selects the structural
  detector — `agent-agnostic/hooks/progress-log.sh`,
  `agent-agnostic/hooks/plan-lifecycle.sh`, `agent-agnostic/hooks/resolve-scratch.sh`,
  `agent-agnostic/hooks/workflow-setup.sh`. All seven currently reference `.artifacts/progress-log.md`
  or `find_parent_worktree`.
- **The defect, precisely.** `agent_type` closes forgery of the *role*. It does nothing about
  deletion of the *run marker*, because those are two different signals:
  `find_parent_worktree` (`scope-writes.sh:117-129`) walks ancestors looking for
  `.artifacts/progress-log.md`, and `exit 0`s at `:292` when it finds none. `.artifacts/` is
  gitignored, so `git status --porcelain` cannot report the deletion, and `parent-tree-guard.sh` is
  `PostToolUse` — the `rm` has already run. One `rm` disables both guards, permanently and
  undetectably. It also has a non-adversarial form: any cleanup that clears `.artifacts/` silently
  turns enforcement off with no signal.
- **Criteria:** per **DP-1**'s resolution at the plan gate. Whichever shape is chosen must satisfy:
  detection survives deletion of any gitignored file; fail-open is preserved for a directory that is
  genuinely not a dae run; and the detector is a single definition, not a sixth verbatim copy.
- **Test approach:** 1.1's case 2, flipped. Plus a control proving an ordinary linked worktree that
  is NOT a dae run still exits 0 for every write — the fail-closed regression this risks.
- **Test oracle:** `new contract tests`.

### 2.4 — `smart-test.sh` — the blind roles get a real signal

- **Files:** `agent-agnostic/hooks/smart-test.sh`
- **The defect (DP-4, dormant since the predecessor run's Phase 3).** `:196-210` defines
  `smart_test_role()`, a **separate** ancestor walk that looks for `.artifacts/dae-role` itself —
  a different marker predicate from the two guards, which walk for `progress-log.md`. `:213-217`
  exits 0 for `coder` and `contract-tester`, closing a real isolation leak on the read side. But
  `workflow-setup.sh:80` accepts only `orchestrator|planner|builder`, so **nothing in the repo can
  ever write those two tokens**; and a builder shares one worktree with its coder and its
  contract-tester, so a per-worktree file structurally cannot say which of the three is acting.
  The fix has been switched on and unable to fire since it landed.
- **Criteria:** the blind-role check reads `agent_type` from the payload — the file already extracts
  `cwd` from the payload at `:150-151` via `_extract_field`, which is the idiom to follow — and exits
  0 for `coder` and `contract-tester` and for nothing else. `smart_test_role()`'s `dae-role` walk is
  deleted; **note that removing it also removes this hook's only run-detection predicate**, so if it
  still needs one, it uses whatever 2.3 settles on, not a third variant.
- **Test approach:** `tests/smart-test-role-scope.test.sh` — its case 03 is already a positive
  control proving the hook DOES emit output for a non-blind role on the same fixture, and case 03b
  the no-marker control. Re-point all eight cases at `agent_type`. The key test: dispatch a real
  `coder` and assert the suite output never reaches it (6.2).
- **Test oracle:** `new contract tests` plus 6.2's live drill.

### 2.5 — `workflow-setup.sh` / `resolve-scratch.sh` — the token is gone

- **Files:** `agent-agnostic/hooks/workflow-setup.sh`, `agent-agnostic/hooks/resolve-scratch.sh`
- **Criteria:**
  - `--set-role` (the whole mode, `workflow-setup.sh:58-88`) is **removed**, along with its usage
    strings at `:6` and `:27`. An identity that comes from the harness needs no setter, and leaving
    a setter for a signal nothing reads is dead wiring.
  - The `dae-role` seed at `:266-268` is removed. The `progress-log.md` seed at `:253-265` stays —
    it is the run marker, a different thing, subject to 2.3.
  - `resolve-scratch.sh:124-155` already deliberately writes a marker and never a `dae-role`, with a
    comment explaining why. That comment must be updated to state the new reason (`scratch` is
    derived structurally from the main-checkout topology) rather than the old one, or removed. Its
    behavior should not need to change — confirm that by test rather than by reading.
  - `agent-agnostic/skills/dae/worktree-modes.md:15` prescribes writing `dae-role` in `none` mode.
    That line is lane 3's to fix (4.3); flag it in the exit report as a cross-lane hand-off rather
    than reaching outside this lane's scope.
- **Test approach:** `tests/workflow-setup-reuse.test.sh` cases 16-18 and `tests/none-mode-marker.
  test.sh` cases 01-02 currently drive the real `--set-role` CLI; they are rewritten to assert the
  mode is gone and that the run marker is still seeded, with the pre-change behavior as the control.
- **Test oracle:** `existing suite`, rewritten.

### 2.6 — Contract tests — every identity against every root

- **Files:** `tests/scope-writes.test.sh`, `tests/parent-tree-guard.test.sh`,
  `tests/l6-role-escalation-e2e.test.sh`, `tests/identity-forgery.test.sh`,
  `tests/resolve-scratch-marker.test.sh`, `tests/workflow-diff-check.test.sh`
- **Pattern:** `tests/scope-writes.test.sh` cases 26-30 are the existing worked example of an
  `agent_type`-driven case, and case 30 is the model for the control: *"positive control — same
  docs-root target as case 26 WITHOUT `agent_type` → deny"*. Every new case pairs an allowed target
  with a denied one **at the identical path**, so the result turns on identity and not on path shape.
- **Criteria:** the full matrix — 7 identities × {product file, plans root, docs root, run dir,
  scratch dir} — each cell asserted with its inverse control, in both hooks. Plus: a lane child with
  no `agent_type`; a lane child claiming `agent_type=planner`; an unrecognized `agent_type`; an
  empty `agent_type`; and an `agent_type` containing shell metacharacters (the field is extracted by
  regex from raw JSON, so a hostile value must not escape the `case` arms).
- **Test oracle:** `new contract tests`.

### 2.7 — Fail-open verification, positive-controlled

- **Files:** `tests/identity-forgery.test.sh`
- **Criteria:** with no run detected anywhere above the target, EVERY write exits 0 from both hooks
  — product file, plans root, docs root, a deep new path, a path outside the repo, a non-git
  directory, and a **dirty** unmarked repo where `git status` is non-empty (the case most likely to
  break `parent-tree-guard.sh`). Each of those seven carries a positive control on the same fixture
  with the run detected, returning exit 2 — a zero that could not have been a two proves nothing.
  Additionally: an unreadable payload, an empty payload, and a payload whose `agent_type` extraction
  fails all exit 0.
- **Test oracle:** `new contract tests`.

## Phase 3: The audit machinery stops losing claims (lane 2)

Independent of Phase 2 in both file scope and logic; runs concurrently with lane 1.

### 3.1 — `claims_from_report()` reads every path in a bullet

- **Files:** `agent-agnostic/hooks/verify-run-scope.sh`, `agent-agnostic/hooks/verify-scope.sh`
- **The defect, measured.** `claims_from_report()` (`verify-run-scope.sh:42-92`, and a verbatim
  fifth copy at `verify-scope.sh:39-89`) takes `head -n1` of a bullet's backticked tokens
  (`:56`) and iterates with `read -r line`, which sees one **physical** line (`:51`). So a grouped
  bullet loses every path but the first, and a wrapped bullet loses its continuation silently. A
  prose term in backticks on line 1 — `` `Stop` ``, `` `base_branch_mode` `` — displaces the real
  path entirely. **Six of the predecessor run's seven exit reports broke this convention**, and
  nothing enforces it: the run's ownership ledger was quietly lossy throughout (17 stderr NOTEs, 8
  UNCLAIMED; after reformatting, 0 NOTEs and 2 UNCLAIMED).
- **Pattern:** the repo has already decided where this belongs. `verify-run-scope.sh:24-33` states
  it outright: *"claims_from_report() below is the single definition of what counts as a claim line
  … a future change should extend claims_from_report, never validate-report.sh's counter."*
- **Criteria:**
  - Continuation lines are joined into their bullet before parsing, so a wrapped bullet is one unit.
  - Every backticked token in a bullet is considered, not just the first.
  - A token is a claim when it is path-shaped (contains `/`, or has a dot-extension); every
    discarded token emits a NOTE naming it, so a real path that fails the shape test is visible
    rather than silently dropped. Over-claiming is as bad as under-claiming — a padded ledger
    defeats what the ledger is for.
  - Both copies change identically, in the same commit, and a diff assertion for the pair is added
    (see 3.4). This helper is the repo's only verbatim-shared function with no such test.
- **Test approach:** run the new parser over the predecessor run's own seven exit reports (available
  in git history at `.artifacts/reports/` only until closeout — capture them into the test fixture)
  and assert the claim set is a strict superset of today's, with the specific dropped paths named.
  **Positive control:** a synthetic report whose bullet contains a prose backtick and two real paths
  must yield exactly the two paths and one NOTE; the NOTE pattern is itself positive-controlled
  against synthetic input, because a NOTE counter that can never fire proves nothing.
- **Test oracle:** `new contract tests`.

### 3.2 — The claim-line contract gets an owner

- **Files:** `agent-agnostic/hooks/validate-report.sh`, `agent-agnostic/rules/run-artifacts.md`
- **Criteria:** per **DP-3**. If the gate chooses mechanical enforcement, it goes at
  `validate-report.sh:91-92` — the only place that touches `## Files touched` bullets, and it
  currently only *counts* them (`grep -cE '^\s*- \S'`), never inspecting content. Whichever way DP-3
  resolves, `run-artifacts.md`'s description of the exit report must state the contract explicitly,
  because today it is a convention nothing checks and six of seven reports broke it.
- **Note the documented objection this must answer:** `verify-run-scope.sh:27-31` argues that
  tightening the validator *"would retroactively invalidate exit reports that already passed and
  fight the markdown builders naturally write."* A subphase that tightens it is contradicting a
  written design decision and must say why, in the file, not only in a report.
- **Test oracle:** `new contract tests`.

### 3.3 — `pr-ready-hygiene-guard.sh` stops firing on mentions of the flip

- **Files:** `agent-agnostic/hooks/pr-ready-hygiene-guard.sh`,
  `tests/pr-ready-hygiene-guard.test.sh` *(new)*
- **The defect, reproduced first-hand while writing this plan (09-26-26).** The guard matches
  `(^|[;&|]|\n)\s*(sudo\s+)?gh\s+pr\s+ready\b` against the whole command string (`:24`). A plainly
  read-only command whose *quoted argument* happened to contain `|gh pr ready` —
  `grep -cE 'hygiene|gh pr ready|check-diff' <file>` — was blocked with exit 2, because the `|`
  inside the quotes satisfied the `[;&|]` alternative. The guard cannot tell a shell metacharacter
  from a character inside a quoted string. This is precisely what the user asked to avoid: *"dont
  over gate things"*.
- **Criteria:** the guard fires on an actual `gh pr ready` invocation and does not fire on a command
  that merely contains that text inside a quoted argument. It stays fail-open on any parse failure —
  a guard that cannot decide must not block. It keeps its documented reason for being a harness hook
  rather than a skill step (`:7-9`): a skill step only runs when an agent follows the skill.
- **Test approach:** paired cases — `gh pr ready` at a real command position (must block, the
  positive control that the guard is reachable at all) versus the same text inside single quotes,
  inside double quotes, as a substring of a longer word, and in a `grep` pattern (must not block).
  Assert on the guard's stderr CONTENT, not its exit status alone.
- **Test oracle:** `new contract tests`.

### 3.4 — Contract tests for both parsers and the guard

- **Files:** `tests/verify-scope-parsing.test.sh`, `tests/verify-scope-clean.test.sh`,
  `tests/pr-ready-hygiene-guard.test.sh`
- **Criteria:** `verify-scope-parsing.test.sh` gains the grouped-bullet, wrapped-bullet and
  prose-backtick cases, each with the pre-change behavior recorded as the control. A new case
  extracts `claims_from_report()` from both `verify-run-scope.sh` and `verify-scope.sh`, asserts
  each extract is non-empty, and diffs them — modelled on `tests/parent-tree-guard.test.sh:904-946`.
- **Test oracle:** `new contract tests` plus `existing suite`.

## Phase 4: Every writing agent carries a real identity (lane 3)

### 4.1 — The three gate skills get an identity

- **Files:** `agent-agnostic/skills/review-plan/SKILL.md`,
  `agent-agnostic/skills/review-code/SKILL.md`, `agent-agnostic/skills/review-pr/SKILL.md`, and —
  only if DP-2 selects it — `agent-agnostic/agents/reviewer.md` *(new)*
- **The defect this closes, and why it is not optional.** `review-plan`, `review-code` and
  `review-pr` all declare `context: fork` with no `agent:` key (each at line 5 of its SKILL.md;
  8 skills in `agent-agnostic/` declare it, plus `tool-based/confluence/skills/document-confluence`
  — 9 in total, positive-controlled, correcting the "ten skills" figure in the brief). A fork with
  no `agent:` runs as `general-purpose`. Each of these three writes a durable record under the plans
  root — `plan-review.md`, `code-review.md`, `pr-review.md` — and today those writes land because
  they are attributed to the *orchestrator*, whose carve-out at `scope-writes.sh:387-390` allows
  `*-review.md` and `sync-report.md`. **The moment identity comes from `agent_type`, a forked gate
  is `general-purpose`, not absent — and the orchestrator carve-out no longer covers it.** Without
  this subphase, Phase 2 breaks every gate in the pipeline.
- **The prize.** The predecessor run's DP-2 recorded, as explicit follow-up work, that *"gate skills
  run in the orchestrator's own context and should be sub-agents with their own `reviewer` role"*,
  and that until they are, the orchestrator's write scope cannot be zero. Giving the gates their own
  identity retires the `*-review.md` carve-out, which makes the user's words — *"orchestrators dont
  make writes PERIOD"* — literally true for the first time.
- **Criteria:** per **DP-2**. Whichever mechanism is chosen, the acceptance test is a **live
  dispatch**: run one real gate, have it write one real review record into a marked fixture, and
  capture the `agent_type` the hook actually sees. A synthetic payload does not satisfy this
  criterion — that is exactly the error the predecessor run's rounds 3-5 made and corrected.
- **Test oracle:** `existing implementation` for the identity capture; `new contract tests` (4.5)
  for the wiring inventory.

### 4.2 — `explore`'s map and claim writes get an identity

- **Files:** `agent-agnostic/skills/explore/SKILL.md`
- **Same defect, different write.** `explore` is `context: fork` (`SKILL.md:5`) and writes the
  structured map to the run dir (`SKILL.md:26`, `:91`) and, at `rigor: med|high`, a committee member
  file. Those writes are covered today by `scope-writes.sh:317-319` and `:377-386`, which carve out
  `explore-map-*.md` and `committees/*/…` for both `planner` and `orchestrator`. Under identity
  resolution those carve-outs stop matching a `general-purpose` fork.
- **Criteria:** the explore fork writes under an identity the hooks recognize, resolved the same way
  DP-2 resolves the gates. If that identity is distinct, the path carve-outs at `:317-319` and
  `:377-386` narrow to it — which is a scope *reduction*, and therefore needs its own control test
  proving the planner and the orchestrator can no longer write those paths directly.
- **Cross-lane note:** the carve-out lines live in `scope-writes.sh`, which is lane 1's file. This
  subphase specifies the requirement and hands it to lane 1 rather than reaching into its scope;
  lane 1's 2.1 owns the edit. Stated here because a hand-off nobody writes down is a hand-off nobody
  makes — the predecessor run carried three of these and had to expand a lane's brief mid-flight.
- **Test oracle:** `new contract tests`.

### 4.3 — The `--set-role` bracket is removed and every spawn site audited

- **Files:** `agent-agnostic/skills/dae/SKILL.md`, `build.md`, `live.md`, `diagnose.md`, `sync.md`,
  `worktree-modes.md`, `report.md`, `prove.md`, `document.md`, `build-dispatch.md`,
  `confluence-mode.md`
- **What goes.** The **Planner role flip** step (`SKILL.md:127-141`) and every bracket that cites it:
  `SKILL.md:129,136-137`; `build.md:11-12` (planner) and `:33` (the `--worktree none` builder flip);
  `diagnose.md:11-12`; `live.md:30-31`; `worktree-modes.md:15` (the `none`-mode `dae-role` write and
  the builder flip). A bracket exists only because the identity was missing; with `agent_type` there
  is nothing to flip and nothing to restore, and — critically — **nothing to forget to restore**.
- **`sync.md`'s missing bracket is closed by deletion, not by addition.** `sync.md` has zero
  `--set-role` occurrences while `build.md` has three (positive-controlled count across all twelve
  `dae/*.md` files). Its stage-2 planner spawn (`sync.md:9`) and its stage-3 re-entry
  (`sync.md:11`, *"SendMessage the warm planner"*) both run with the marker still at `orchestrator`.
  That has been benign only by coincidence: `sync-report.md` happens to sit on the orchestrator
  allow-list, so the one write it makes succeeds; any other planner write on a sync run is denied.
  Under identity resolution the planner is a `planner` wherever it is spawned from, and the gap
  closes without anyone adding a line.
- **Criteria — the audit, which is the real work here:** every spawn site in the dae skill is
  enumerated and classified as an **Agent-tool dispatch** (identity survives) or a **Skill-tool
  fork** (identity is swallowed unless DP-2's mechanism is applied). The list is written into the
  plan record, not only checked. A site that writes and is a bare fork is a finding, not a
  to-do-later. Use `documenter.md:9-11` as the worked example of how a dispatch-wrapper agent is
  documented; its own text — *"there is no role marker to bracket or flip … your identity is your
  `agent_type`"* — becomes true of every worker, and its `--set-role` cross-reference must go.
- **Test approach:** a positive-controlled count assertion — `--set-role` returns 0 across
  `agent-agnostic/`, while a pattern known to be present returns non-zero on the same run. **The
  predecessor run produced a false clean from exactly this kind of search** (a `grep -v` filter
  excluded `.workflows`, which the worktree path itself contains), so the control is mandatory, and
  the search must not filter on path.
- **Test oracle:** `existing suite` plus 4.5's inventory test.

### 4.4 — The role model is rewritten as the identity model across the docs

- **Files:** `AGENTS.md`, `agent-agnostic/AGENTS.md`, `README.md`, `docs/architecture.md`,
  `docs/pipeline.md`, `docs/conventions.md`
- **Criteria:** every description of the write-scope mechanism describes identity, not a marker
  file. Enumerate the instances — do not spot-check one and assume the rest.
  `agent-agnostic/AGENTS.md:151-153` and `docs/pipeline.md` both still describe the orchestrator's
  allowed scope as *".artifacts/, the resolved plans dir, and the resolved docs dir"*, which was the
  pre-DP-2 permissive allowance; both have survived four review rounds unfixed and both are wrong
  again in a new way after this plan. `docs/conventions.md:74-77` documents `agent:` as accepting
  *"either a built-in agent type or any custom subagent from `.claude/agents/`"* — that claim is
  correct per the harness docs but is currently used by nothing; after 4.1 it must describe real
  usage. `agent-agnostic/AGENTS.md:112`'s `documenter` row already describes the identity mechanism
  correctly and is the model to extend.
- **Test approach:** per instance, a positive-controlled search that the stale phrasing is gone AND
  that the search could have found it — the `verify-dont-assume` rule's "enumerate, don't
  spot-check" clause applies literally here, because this exact claim was fixed in one file and left
  standing in another across three rounds of the predecessor run.
- **Test oracle:** `existing suite`.

### 4.5 — An inventory test pins the fork/agent wiring

- **Files:** `tests/agent-identity-inventory.test.sh` *(new)*
- **Criteria:** a test that fails when a skill acquires `context: fork` without an identity
  mechanism, and when an agent definition's `name:` diverges from a token the hooks recognize.
  Concretely: enumerate every `SKILL.md` under `agent-agnostic/` and `tool-based/`; for each
  declaring `context: fork`, assert either that it writes nothing durable or that it carries the
  identity mechanism DP-2 selected; and assert every `name:` under `agent-agnostic/agents/` appears
  in the hooks' identity table (or is explicitly listed as intentionally unprivileged).
- **Why this test and not a convention:** *"wired but dead"* has now been found three times in this
  repo — `workflow-diff-check.sh` declared in a skill's frontmatter where skills cannot declare
  hooks; `record-changed.sh`/`test-changed.sh` referenced by no settings file in the repo's entire
  history; `check-diff-hygiene.sh` with no trigger in this repo's landing path. Each was a
  convention nobody checked. This is the check.
- **Test oracle:** `new contract tests`.

## Phase 5: The shared touchpoints, and the items decided at the gate

Serialized after every lane merges back. This phase owns every file two or more lanes would
otherwise contend for — `agent-specific/claude/settings.json`, `agent-specific/antigravity/hooks.json`,
`docs/known-issues.md`, and any second pass over `agent-agnostic/AGENTS.md`. No lane touches them.

### 5.1 — `check-diff-hygiene.sh` wiring

- **Files:** `agent-specific/claude/settings.json`, `.claude/skills/push-main/SKILL.md`,
  `agent-agnostic/rules/minimal-code-comments.md`
- **The state of things, verified rather than assumed.** The brief's framing ("wired only to
  `gh pr ready`") is not quite right and the precise version matters. `check-diff-hygiene.sh` has
  three call sites: `pr-ready-hygiene-guard.sh:32` (the harness hook, on `gh pr ready`),
  `agent-agnostic/agents/builder.md:40` (builder teardown, `--base <parent-branch> --scope all`),
  and `agent-agnostic/skills/push-pr/SKILL.md:69`. So in a normal dae run it *does* fire, per lane.
  What has no trigger is **this repo's own landing path**: `push-main/SKILL.md` contains zero
  references to hygiene or to `gh` at all (positive-controlled — `squash` returns 2 hits in the same
  file, so the search works), and builder teardown scans only a lane's own diff against the parent
  branch, so violations that predate a lane are never seen.
- **Criteria:** per **DP-4**. If the gate says wire it, it goes into this repo's landing path, and
  `minimal-code-comments.md:30-31` is updated to describe the real set of triggers.
- **The cost, measured, because it is decision-relevant.** A `check-diff-hygiene.sh` run triggered
  accidentally during this planning session reported **211 violations on the current branch**,
  including 16 `ATTRIBUTION` hits in commit messages (`Claude-Session:` trailers added before the
  no-attribution rule existed) and comment-banner/density findings across eleven hook and test
  files. The exact base ref that scan used is unknown, so the successor must re-run it deliberately
  before deciding. But the shape of the cost is clear: wiring this as a blocking check on
  `push-main` blocks the predecessor branch from landing, and force-push is forbidden so the
  trailers cannot be scrubbed from branch history. The squash message is written fresh, so nothing
  with a trailer reaches `main` — which is the argument for scoping any new check to the squash
  message and the resulting diff, not to branch history.
- **Test oracle:** `existing suite`.

### 5.2 — `record-changed.sh` / `test-changed.sh`

- **Files:** `agent-agnostic/hooks/record-changed.sh`, `agent-agnostic/hooks/test-changed.sh`,
  `agent-agnostic/AGENTS.md`
- **The state of things.** 38 lines and 124 lines respectively. Neither appears in
  `agent-specific/claude/settings.json`, in `agent-specific/antigravity/hooks.json`, in any skill,
  or in any agent definition — zero references across the repo's history (positive-controlled: the
  same search returns the scripts' own self-references and `workflow-diff-check.sh:4`, so the
  pattern is live). `workflow-diff-check.sh:4` describes itself as their *"simplified replacement"*,
  and it IS wired (`settings.json`'s `Stop` array). `agent-agnostic/AGENTS.md:172` already describes
  them accurately as unwired.
- **Criteria:** per **DP-5**. If removed: both files deleted, `AGENTS.md:172`'s paragraph rewritten
  rather than left describing files that are gone, and `workflow-diff-check.sh:4`'s reference to
  them updated. If kept: `AGENTS.md` says why, so the next audit does not rediscover them.
- **Test oracle:** `existing suite`.

### 5.3 — The two pre-plan unclaimed files

- **Files:** `docs/known-issues.md`
- **The state of things.** `verify-run-scope.sh . main .artifacts` fails on exactly
  `tests/report-middle-contract.test.sh` and `tool-based/confluence/AGENTS.md`. Both come from
  `57d2a3e`, the predecessor branch's FIRST commit, authored ~7 hours before `01d8903` promoted the
  plan — confirmed against git, not against a report. No builder could legitimately own them.
  The predecessor's code gate reviewed both files in full and found them benign, and refused to
  manufacture an exit report for them on the grounds that doing so *"would launder an orchestrator
  product write into a fake builder claim and destroy the ledger's meaning."* Rounds 3, 4, 5 and 6
  all concurred and all left it red.
- **The underlying defect, which outlives these two files:** the ledger cannot express a legitimate
  pre-plan commit carried on the same branch, so its only outcomes are "lie" or "stay red".
- **Criteria:** per **DP-6**. The default — and the recommendation — is a `docs/known-issues.md`
  entry in that file's existing shape (limitation / source / status), recording the two files as
  permanently accepted and the ledger's inexpressiveness as the real gap. This subphase also folds
  in 1.4's finding about the stale `-w none` entry if there is one.
- **Test oracle:** `existing suite`.

### 5.4 — The Antigravity port's identity gap

- **Files:** `agent-specific/antigravity/hooks.json`, `agent-agnostic/hooks/agy-hook-adapter.sh`
- **The defect, found while planning and not previously recorded anywhere.**
  `hooks.json` wires `scope-writes.sh` (`PreToolUse` on the write-shaped tools) and `smart-test.sh`
  through `agy-hook-adapter.sh`. But the adapter constructs the Claude-shaped payload itself, and it
  builds exactly this (`agy-hook-adapter.sh:65-68`):
  `{ tool_name: .toolCall.name, arguments: .toolCall.arguments } + {source}`.
  There is **no `cwd`, no `agent_type`, no `file_path`**. `scope-writes.sh` exits 0 at `:264` when
  no path field is present — so under Antigravity the write-scope hook has never enforced anything,
  and `agent_type` will never arrive there no matter what Phase 2 does. `parent-tree-guard.sh` is
  not wired under Antigravity at all.
- **Criteria:** per **DP-7**. The one outcome this plan rules out is leaving a wiring entry that
  describes enforcement which cannot happen — that is the fourth instance of the class this whole
  effort exists to remove. Either the adapter carries the fields the hook needs and the plan states
  what Antigravity supplies in place of `agent_type` (or that it supplies nothing, so enforcement
  fails open there, in writing), or the entry comes out.
- **Test oracle:** `new contract tests` if the adapter changes; otherwise `existing suite`.

## Phase 6: Verification

### 6.1 — Whole suite, `bash -n`, shared-helper diff

- **Files:** none written.
- **Criteria:** the full `tests/` suite green, asserted **by content** — count `PASS` and `FAIL`
  lines per file, with the `FAIL` pattern positive-controlled against synthetic input to prove it
  can match. Note that `tests/sync-install-settings-merge.test.sh` uses a different summary format
  and indented labels, so an anchored `^FAIL` sweep silently skips it; the predecessor run's gate
  hit exactly that and had to add it back by hand (593 + 12 = 605). `bash -n` on every changed
  script, with a positive control confirming `bash -n` does reject bad syntax. All four shared
  guard helpers re-extracted and diffed with a non-empty assertion on each extract, plus the
  `claims_from_report()` pair from 3.4.
- **Test oracle:** `existing suite`.

### 6.2 — The forgery drill, driven through a real dispatch chain

- **Files:** none written.
- **This is the subphase that tests the key.** Everything above can pass with synthetic payloads and
  still ship a dormant fix — that is precisely what happened twice in the predecessor run.
- **Criteria:** in a throwaway repo with a real parent worktree created by the real
  `workflow-setup.sh`, and with the hooks actually installed (note: **none of this binds until the
  push and the `sync-install.sh` that follows it** — the installed copies at `~/.claude/hooks/` are
  the old permissive ones, which is why the predecessor run's orchestrator was able to edit
  `plan.md` through the shell all session):
  1. Dispatch a real `planner`. It writes into the plans root: **allowed**. It attempts a product
     file: **denied**.
  2. Dispatch a real `builder` into a lane child. Product file: **allowed**. Plans root: **denied**.
     Docs root: **denied**.
  3. Dispatch a real `coder`. `smart-test.sh` produces **no suite output** for it — asserted on the
     absence of the suite's own strings, with a positive control that the same fixture DOES emit
     output for a non-blind identity.
  4. Dispatch a real `contract-tester`. Same.
  5. Dispatch a real gate (per DP-2's mechanism). Its review record write: **allowed**. A product
     file: **denied**.
  6. Dispatch a real `documenter`. Docs root: **allowed**. Product: **denied**.
  7. From the main session (the orchestrator), every write: **denied** — or, if DP-2 retired the
     `*-review.md` carve-out, denied without exception, which makes the ask literally true.
  8. `echo builder > .artifacts/dae-role` from any of the above, then repeat its denied case:
     **still denied**, and the file is inert.
  9. `rm .artifacts/progress-log.md`, then repeat: per DP-1's resolution.
  10. Outside any run: every write **allowed**, for every identity.
- **Recording:** a before → after table, like the predecessor run's, in the plan's dir. Any drill
  result that contradicts expectation is **run down, not waved through** — the predecessor run had
  two such contradictions and both turned out to be the orchestrator's own wrong expectation rather
  than a defect, which is only known because they were chased.
- **Test oracle:** `existing implementation`.

## Risks, open questions, decision points

1. **DP-1 — what makes a dae run detectable, once the marker can be deleted? NEEDS THE USER.**
   `agent_type` fixes the role but not run detection; `rm .artifacts/progress-log.md` still turns
   both guards off, permanently and undetectably.
   - **(a) Structural detection from git topology.** A linked git worktree whose root sits under the
     resolved `CLAUDE_WORKFLOWS_DIR` is a dae parent; a `<name>-l<n>` sibling of one is a lane child.
     No file involved, so nothing to delete. *Cost:* the workflows-dir value is resolved from
     settings files, and `.claude/settings.local.json` is gitignored and writable by a builder —
     so this trades one forgeable input for another unless the resolution is pinned. *Also:* it
     changes behavior for anyone with an ordinary linked worktree that happens to sit there.
   - **(b) Keep the marker, accept the deletion bypass, and record it.** Honest and cheap; leaves a
     one-command total bypass in place, which is the defect this plan was convened to remove.
   - **(c) Detect on the marker OR the topology, whichever fires.** Deletion no longer disables
     enforcement; a non-dae worktree under the workflows dir is the false-positive cost.
   - *Recommendation:* (c). It preserves today's behavior everywhere it is correct and removes the
     bypass, and the false-positive case fails toward *more* enforcement in a directory that is by
     definition a workflow worktree.
   - **Related, and settled by the same decision:** `scope-writes.sh:281`'s `cwd`-keyed allowance
     for a lane's own contract and exit report, which the predecessor run's code gate round 6
     rejected as trusting mutable shell state. If it is still `cwd`-keyed when 1.4 measures it,
     re-key it on `agent_type` — `builder`, `coder` and `contract-tester` are distinct identities,
     and the gate's own suggested fix says exactly this.

2. **DP-2 — how do the three gate skills and `explore` get an identity? NEEDS THE USER.**
   All four are `context: fork` with no `agent:`, so they run as `general-purpose`, and all four
   write durable records. Phase 2 breaks them unless this is answered.
   - **(a) `agent: reviewer` on the gate skills, plus a `reviewer.md` agent definition** (and the
     equivalent for `explore`). Documented as supported; **unverified in this repo — zero files
     declare `agent:`**, which is why 1.3 exists. Cheapest if it works.
   - **(b) Remove `context: fork` from the gate skills**, so they run inline as their caller. This is
     the route the predecessor run took for `document-local` and its gate called it *"a stronger fix
     — it deletes the fork boundary the identity had to cross"*. *Cost:* the gates lose their cold
     isolation, which is load-bearing — `review-code`'s value is that it reviews without having read
     the lane's reasoning. **This option should probably be rejected for the gates on exactly that
     ground**, even though it was right for `document-local`.
   - **(c) Dispatch the gates as real agents** (Agent tool, `subagent_type: reviewer`), the way
     `documenter` is dispatched. Keeps the cold isolation, gives a real harness identity, and is the
     follow-up the predecessor's DP-2 named. *Cost:* a change at every gate call site.
   - *Recommendation:* (a) if 1.3 proves it, falling back to (c). Either way the orchestrator's
     `*-review.md` carve-out retires and *"orchestrators dont make writes PERIOD"* becomes true.

3. **DP-3 — extend the parser, or enforce the format? NEEDS THE USER.**
   The brief offers both; the repo has a written position.
   - **(a) Extend `claims_from_report()` only.** `verify-run-scope.sh:24-33` says this explicitly:
     *"a future change should extend claims_from_report, never validate-report.sh's counter"*, on
     the grounds that tightening the validator retroactively invalidates reports that already passed.
   - **(b) Enforce one path per bullet in `validate-report.sh`.** Mechanical, catches drift at write
     time rather than at the gate. Contradicts the above and breaks existing reports.
   - **(c) Both:** extend the parser (so nothing is silently lost) and have the validator WARN
     rather than fail on a multi-path bullet.
   - *Recommendation:* (c). (a) alone leaves the format unenforced and it will drift again — it
     drifted in six of seven reports on the one run that cared about it.

4. **DP-4 — wire `check-diff-hygiene.sh` into this repo's landing path? NEEDS THE USER.**
   *The cost, stated:* a new blocking check on `push-main`. A scan during this planning session
   reported 211 violations on the current branch, 16 of them `Claude-Session:` trailers in commit
   messages that force-push policy makes unscrubbable. Wiring it as a branch-history check blocks
   the predecessor branch from landing. Wiring it against the squash message and the resulting diff
   instead would pass, because the squash message is written fresh. The third option is to leave it
   unwired here and record in `minimal-code-comments.md` that this repo has no landing-time check —
   honest, and no worse than today.

5. **DP-5 — delete `record-changed.sh` and `test-changed.sh`? NEEDS THE USER.**
   162 lines across two files, zero references in any settings file in the repo's history,
   superseded by `workflow-diff-check.sh` which says so in its own header. Deletion is the obvious
   call; it is a user decision because they may be wanted as a reference implementation.

6. **DP-6 — what to do about the two permanently unclaimed pre-plan files? NEEDS THE USER.**
   Options: record them in `docs/known-issues.md` as permanently accepted (recommended); or change
   `verify-run-scope.sh` to take an explicit `--allow` for pre-plan commits, which risks becoming a
   general escape hatch; or do nothing and let the check stay red, which teaches every future run
   that the check is advisory.

7. **DP-7 — what does the Antigravity port do about identity? NEEDS THE USER.**
   `agy-hook-adapter.sh` passes only `tool_name` and `arguments`, so `scope-writes.sh` has never
   enforced anything under Antigravity and `agent_type` cannot reach it. Options: extend the adapter
   with whatever Antigravity supplies (and state in writing what it does NOT supply, so the gap is
   recorded rather than assumed closed); or remove the `scope-writes` entry from `hooks.json` so the
   port stops claiming enforcement it does not have. Doing neither leaves a fourth "wired but dead"
   hook behind a plan whose purpose is removing them.

8. **Risk — fail-open is load-bearing, and this plan touches every hook that has it.** A bug that
   converts fail-open to fail-closed blocks work in every session repo-wide, not just dae runs.
   2.7 and 6.2's case 10 exist for this, and no subphase may introduce a denial on a resolution
   failure.

9. **Risk — the identity table's `orchestrator` arm is keyed on an ABSENCE.** Claude Code documents
   `agent_type` as present *"when session uses `--agent`"* as well as inside a subagent, so a main
   session started with `--agent X` carries an unexpected value. Least privilege (2.1) makes this
   safe rather than exploitable — an unrecognized identity resolves to the most restrictive role —
   but it means "orchestrator" is never positively identified, only inferred. Recorded so nobody
   later "improves" it into a positive check that has no signal to check.

10. **Risk — nothing in this plan binds until the push and the install sync.** The hooks at
    `~/.claude/hooks/` are the installed copies; the repo is the source. The predecessor run
    discovered mid-flight that its own enforcement was inert for exactly this reason. 6.2 must run
    against installed hooks, and this repo's `source-push-sync` rule makes the sync a mandatory part
    of the push, not a follow-up.

11. **Risk — lane collision, specifically on `dae/SKILL.md` and `workflow-setup.sh`.** The
    predecessor run had to reorder its lanes mid-flight because two of them shared exactly these two
    files. Here, `workflow-setup.sh` belongs to lane 1 alone and every `dae/*.md` file belongs to
    lane 3 alone; `agent-specific/claude/settings.json`, `agent-specific/antigravity/hooks.json`,
    `docs/known-issues.md` and any second pass over `agent-agnostic/AGENTS.md` belong to the
    serialized Phase 5 and to no lane. The one file that crosses a boundary is
    `tests/identity-forgery.test.sh`, created in serial Phase 1 and owned by lane 1 thereafter.

12. **Open question — does the orchestrator's own syllabus tick survive?** `builder.md` says the
    orchestrator ticks the syllabus from the builder's report; `documenter.md` says `document-local`
    makes those ticks; `parent-tree-guard.sh`'s orchestrator arm allows only `*-review.md` and
    `sync-report.md` under the plans root, which would make a `mark-syllabus.sh` edit of `plan.md`
    an offender. 1.4 settles which is true before any lane assumes either.

## Lanes

| Lane | Phases | File scope (exclusive) |
|---|---|---|
| **1** | Phase 2 | `agent-agnostic/hooks/{scope-writes,parent-tree-guard,smart-test,workflow-setup,resolve-scratch,workflow-diff-check}.sh`; `progress-log.sh` and `plan-lifecycle.sh` only if DP-1 selects the structural detector; `tests/{scope-writes,parent-tree-guard,smart-test-role-scope,l6-role-escalation-e2e,none-mode-marker,resolve-scratch-marker,workflow-setup-reuse,workflow-diff-check,identity-forgery}.test.sh` |
| **2** | Phase 3 | `agent-agnostic/hooks/{verify-run-scope,verify-scope,validate-report,pr-ready-hygiene-guard}.sh`; `agent-agnostic/rules/run-artifacts.md`; `tests/{verify-scope-parsing,verify-scope-clean,pr-ready-hygiene-guard}.test.sh` |
| **3** | Phase 4 | `agent-agnostic/skills/dae/*.md`; `agent-agnostic/skills/{review-plan,review-code,review-pr,explore}/SKILL.md`; `agent-agnostic/agents/*.md`; `AGENTS.md`; `agent-agnostic/AGENTS.md`; `README.md`; `docs/{architecture,pipeline,conventions}.md`; `tests/agent-identity-inventory.test.sh` |

Lane 2 has no dependency edge on lanes 1 or 3 and runs fully concurrently. Lane 3 carries `after:`
edges onto lane 1's 2.1 and 2.5 — not because their files overlap (they do not), but because lane
3's prose must state the identity table lane 1 actually shipped, and the predecessor run's single
most expensive failure was docs written against a table that then changed.

Phases 1, 5 and 6 are serial and belong to no lane. Phase 5 owns every shared touchpoint.

## Skill mapping

| Work | Skill / agent |
|---|---|
| Phase 1 (probes, baseline, the red regression tests) | the orchestrator, directly — no lane exists yet, and a probe that wires a settings hook is not a builder's job |
| Phase 2 (the enforcement hooks and their tests) | `builder` → `coder` + `contract-tester`, lane 1 |
| Phase 3 (the audit machinery) | `builder`, lane 2 |
| Phase 4 (skills, agents, docs) | `builder`, lane 3 |
| Phase 5 (shared touchpoints, gate-decided items) | `builder`, single serialized lane |
| Phase 6 (verification and the live drill) | the orchestrator, after all merge-backs |
| Plan gate | `review-plan` |
| Code gate | `review-code` |
| Record | `documenter` → `document-local` |
| Ship | `push-main` (this repo: squash to `main`, no PRs), then `sync-install.sh` |
