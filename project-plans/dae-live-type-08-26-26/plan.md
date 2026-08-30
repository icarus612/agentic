# dae: the `live` type, the `--rework` dial, and per-row `--ship`

## Phase syllabus

- [ ] Phase 1: The `--rework` build dial
  - [x] 1.1: Resolver + type table — `--rework` flag, `rework:` cell, `REWORK=` emission   (lane 1)
  - [x] 1.2: Router doc — flag table, bracket minimums, emitted keys, error set             (lane 2)
  - [x] 1.3: Builder dispatch prompt carries the budget                                     (lane 3)
  - [x] 1.4: Builder honors the budget as its loop bound; exhaustion exits `blocked`        (lane 3, after: 1.3)
- [ ] Phase 2: `--ship` becomes constrained per row
  - [x] 2.1: Resolver + type table — the `ship` cell becomes an allowed-value list          (lane 1, after: 1.1)
  - [x] 2.2: Router doc — `--ship` returns to the flag table in the constrained tier        (lane 2, after: 1.2)
- [ ] Phase 3: The `live` type
  - [x] 3.1: Resolver + type table — `pipeline: live` and the `live` row                    (lane 1, after: 2.1)
  - [x] 3.2: Type table — flip `feature` and `migration` `against:` to `optional`           (lane 1, after: 3.1)
  - [x] 3.3: `live.md` — the new middle file                                                (lane 4)
  - [x] 3.4: `review-pr` — a caller-supplied severity profile input                         (lane 4, after: 3.3)
  - [x] 3.5: `plan-live.md` — the new planner module                                        (lane 3)
  - [x] 3.6: `planner.md` — declared type list and module roster                            (lane 3, after: 1.4, 3.5)
  - [x] 3.7: Router doc — type table row, seam row, eleven types, disambiguation            (lane 2, after: 2.2)
- [ ] Phase 4: Orchestrator write-scope enforcement
  - [x] 4.1: `scope-writes.sh` — self-configuring, no env var                               (lane 6, after: 3.2)
  - [x] 4.2: `parent-tree-guard.sh` — new hook, checks the artifact not the command         (lane 6, after: 4.1)
  - [x] 4.3: Wire both in `settings.json`; confirm the sync-install mapping                 (lane 6, after: 4.2)
  - [x] 4.4: `verify-scope.sh` — a dirty child worktree FAILS, diff is committed-only       (lane 6, after: 4.3)
  - [x] 4.5: Contract tests for all three scripts, positive and negative                    (lane 6, after: 4.4)
- [ ] Phase 5: Integration
  - [x] 5.1: Payload guides — `SKILL.md`, `orchestrators/AGENTS.md`, root `README.md`       (lane 5, after: 1.4, 3.2, 3.4, 3.6, 3.7, 4.5)
  - [x] 5.2: Meta-docs — `docs/pipeline.md`, `docs/architecture.md`, `docs/README.md`       (lane 5, after: 5.1)
  - [x] 5.3: `docs/known-issues.md` — the home for parked work and known gaps               (lane 5, after: 5.2)
  - [x] 5.4: Merged-lane wording — `build-dispatch.md`, `builder.md`, `live.md`             (lane 5, after: 5.3)
  - [x] 5.5: Cross-file consistency sweep, full contract-test run, install-mapping check    (lane 5, after: 5.4)

---

## Goal & scope

**Ask of record:** `/home/icarus64/repos/agentic/.workflows/dae-live-type/.artifacts/brief.md` —
the durable brief captured before this planner was spawned, plus all four of its amendment
sections: `## Amendment 1` (2026-08-27, after the fast-forward to `origin/main @ d751bea`),
`## Amendment 2` (2026-08-28, the user's decisions after gate round 2), `## Amendment 3`
(2026-08-29, the orchestrator write-scope finding — implemented as Phase 4 and recorded in
`### Amendment 3` below), and `## Amendment 4` (2026-08-29, the merge-back regression — implemented
as 4.4/4.5/5.4 and recorded in `### Amendment 4` below). Every requirement below traces to that
file; the amendment list is part of the pointer, so a reader can tell which parts of the ask this
plan delivers without re-deriving it.

Three changes to the `dae` orchestrator.

1. **A `--rework <n>` build dial.** `builder.md:30` ("Loop per packet until green") and
   `builder.md:32` ("Diagnose-and-redispatch failures the same way, at chunk level") are today
   unbounded. Give the builder a persistence budget: max rework rounds per packet and max
   chunk-level e2e diagnose-and-redispatch rounds. On exhaustion the builder exits
   `status: blocked` with its diagnosis in the exit report; the router surfaces it. Never merged
   silently, never retried past the budget.
2. **`--ship` becomes CONSTRAINED per row, reversing the lock that just shipped.** See the
   supersession note below.
3. **A `live` type (alias `adhoc`) on a new `pipeline: live`.** A conversational, ask-by-ask
   build loop: the router stays in conversation during the build instead of flipping to auto
   mode, each user ask becomes one plan phase and one builder lane, each ask is captured as a
   durable file before the planner is messaged, and the run ships when the user says ship.
   Includes flipping `feature` and `migration` from `against: forbid` to `against: optional`, so
   a local-docs feature run can name its Jira ticket.

4. **Orchestrator write-scope enforcement, actually wired.** A mid-build finding (Amendment 3): the
   guard the docs claim protects the orchestrator has never existed in a working form. Rewrite it to
   be self-configuring, add a second hook that catches shell-side writes, wire both, and correct the
   three docs that assert the current state.
5. **A merge-back check that cannot pass on an empty merge** (Amendment 4): `verify-scope.sh` fails
   on a dirty child worktree and compares against the committed range only, with the dispatch loop
   and the builder contract updated to match.

### Amendment 3 — the enforcement gap this plan now closes

Found mid-build, on 2026-08-29, after lanes 2, 3 and 4 had merged. Three facts, each verified
against the tree:

- **`scope-writes.sh` was never wired.** `agent-specific/claude/settings.json:147-155` is the
  `PreToolUse` block for `Write|Edit|MultiEdit|NotebookEdit`, and it lists exactly one hook:
  `branch-squash-guard.sh`. No commit ever added `scope-writes.sh` anywhere in that file.
- **Its activation mechanism cannot work in Claude Code even if wired.** The hook is inert unless
  `CLAUDE_SCOPE_ALLOW` is set (`scope-writes.sh:36-37`), and hook environment is fixed at process
  start — an orchestrator cannot set a per-run env var for its own hooks. The allowlist is
  necessarily per-run (it names *this* run's worktree and plans dir), so the one thing the design
  needs is the one thing it cannot have.
- **Its stated backstop is vacuous for the orchestrator.** `scope-writes.sh:28-29` excuses not
  intercepting Bash on the grounds that "the worktree + branch isolation is the backstop for that."
  That holds for a BUILDER, which sits in a child worktree containing only its lane's work. The
  ORCHESTRATOR sits in the parent worktree, which contains the whole product tree. There is no
  isolation there to be a backstop. This is not hypothetical: an orchestrator on this very run ran
  `sed -i` against a product file in the parent worktree.

Three documents assert the protection exists — `orchestrators/AGENTS.md:115-117`
("Wired hooks: … `scope-writes.sh` (`PreToolUse` deny-outside-allowlist; live config = orchestrator
scope"), `docs/pipeline.md:181-182` ("Wired: … `scope-writes.sh` (`PreToolUse`; orchestrator
write-scope config)"), and `SKILL.md:143` ("`scope-writes.sh` enforces this when wired; its
allowlist is exactly those paths"). All three are wrong today and are corrected in Phase 5.

**Why this is worth a phase rather than a note.** `SKILL.md:143` also says the orchestrator's write
scope "is machine-audited". It is — but only at the PR gate, by `verify-run-scope.sh`, which is the
*last* gate of the run. A stray orchestrator write is currently invisible until then, and the
kickback at that point is expensive. Phase 4 moves the detection to the moment of the write.

### Amendment 4 — the merge-back check that passed on nothing

A second mid-build finding, 2026-08-29, on this run's own lane l4. The builder returned
`status: success` with its two files **uncommitted** in the child worktree. `verify-scope.sh`
reported `OK`. The `git merge <child-branch>` that followed merged **nothing** — silently, exit 0,
no conflict, no warning. The router only noticed because `git worktree remove` later refused to
remove a dirty worktree.

The cause is `verify-scope.sh:119-122`, which computes "the lane's diff" as the union of the
committed range (`:119`), unstaged changes (`:120`), staged changes (`:121`), and untracked files
(`:122`). Uncommitted work therefore counts as delivered work, and the check answers the wrong
question: it verifies "did the builder touch what it said it touched?" while the caller is about to
act on "is the work actually ON the branch I am merging?". The docstring states the four-way union
plainly at `:11-13`, so this is a design error rather than a slip.

Three failures had to line up, and Phase 4 and Phase 5 close each one: the check itself (4.4), the
dispatch loop's reaction to a dirty lane (5.4 item 1), and the builder's own obligation to commit
before reporting (5.4 item 2). Note what does NOT close it: `validate-report.sh` reads the report
file and never touches git, so no existing gate could have caught this — which is why the obligation
has to be stated where the builder can act on it.

### Deferred out of this plan — `-w none` parent semantics

An earlier draft carried a fourth change as its Phase 2: redefining `--worktree none` so the
current checkout becomes the run's PARENT while builder lanes still get child worktrees, which
would have required a new `workflow-setup.sh` mode that creates only the run dir. **The user
dropped it on 2026-08-28** (`brief.md` Amendment 2 §1).

Two consequences, both load-bearing for anyone reading this plan:

- **`-w none` is untouched by this plan.** It keeps today's meaning — no worktree, every stage in
  the current checkout, single-lane dispatch only (`worktree-modes.md:13-15`, `build.md:27`).
  Nothing here may edit `worktree-modes.md`, `build.md`, or `workflow-setup.sh`.
- **`live` uses the standard parent/child worktree scheme like every other type**, with no
  worktree-mode special case anywhere in its design.

The idea is parked, not discarded, in a stub proposal:
`project-plans/proposals/none-mode-parent-08-28-26.md`. That file has no ask of record yet and must
not be dispatched until one exists; it opens with a status line saying it is parked on purpose, so
nobody sweeps it up as stale. Subphase 5.3 makes the same fact visible from the docs side, in a new
`docs/known-issues.md` page — a limitation nobody can find, with a plan nobody can find either, is
the same as no plan at all.

### Supersession note — `--ship` returns to the flag table

`project-plans/completed/report-pipeline-and-locations-08-26-26.md` §1.2 chose to make `--ship`
**locked rather than constrained per row**, and that choice shipped in commit `5108f1d`. It is
visible today at `SKILL.md:43` ("`--ship` is locked the same way and for the same reason … A
per-row `require|optional|forbid` policy would imply some row wants the choice, and none does"),
`SKILL.md:44`, and `resolve-type.sh:479-494`.

**This plan deliberately reverses that decision.** The reversal is not a repudiation of the bug
it fixed: the real defect was that `dae feature --ship chat` was ACCEPTED — a build run that does
not ship, which is incoherent. Per-row legality fixes that same bug exactly, while keeping the
choice where it is legitimate. `map` and `analyze` are the same pipeline at different presets
(`SKILL.md:68`), and "answer in chat" vs "commit the report under the docs root" is a real user
choice on a report run, not a category error. Locking it forced that choice to be expressed by
switching TYPES, which is precisely the type-proliferation pressure the free and constrained
tiers exist to relieve (`SKILL.md:44`).

Mechanism: the row's `ship` cell lists its allowed values, first = default. A single value means
the row is fixed; `a|b` means overridable. Locked rows: every row that dispatches builders —
`feature`, `bugfix`, `hotfix`, `migration`, `rework`, `live`, `diagnose`, `sync` — plus
`document`. Overridable rows: `analyze: publish|chat` and `map: chat|publish`. `--sh[ip]` returns
to the `SKILL.md` flag table in the **constrained** tier; `-s` stays deliberately unassigned.

Per `plan-format`, the superseded plan is not deleted or re-archived — it shipped, and
`completed/` means shipped. This note is the record that one of its decisions was later reversed,
and the reason.

**Explicitly out of scope.**

- Adding work to a running lane; a new `ship` VALUE beyond `chat|publish`; warm builders.
- **`-w none` parent semantics** — deferred, see above.
- **Cheap per-lane init** (avoiding a full `init-workspace` per child worktree) — deferred to its
  own plan.
- Any change to `report-verdict.sh`'s verdict/`next` vocabulary, to `validate-report.sh`, or to
  `verify-run-scope.sh`. **The one carve-out:** Amendment 4 puts `verify-scope.sh` in scope for
  exactly one behavior change — the uncommitted-worktree check and the committed-only comparison
  that replaces its four-way diff union (4.4, tested in 4.5, documented in 5.4, swept in 5.5).
  Nothing else in that script is in scope: `claims_from_report()` and the `--report` input mode are
  untouched, and `verify-run-scope.sh` — which shares that parser — is not modified at all. This
  bullet said "the scope scripts" as a pair until Amendment 4; the pair is now split, deliberately,
  and this is the record of why.
- Forking `review-pr` or `review-code`. The live PR-gate profile is a caller-supplied input,
  never a second copy of the skill (`orchestrators/AGENTS.md:156-159`, the seam rule).
- `workflow-setup.sh` entirely — its branch-type enum (`feature|bug|hotfix|docs|sync`) already
  covers `live`'s `feature/` prefix, and the `-w none` deferral removes the only other reason to
  touch it.
- The stale workflow enumeration in the root `README.md:49-51` (it omits `map` and `analyze`) is
  repaired in 5.1 only because that subphase is editing the same sentence.

**Governance this plan is held to** (`orchestrators/AGENTS.md:149-172`, four standing review rules
for a new `--type` row):

- *Loops attach to axis VALUES, never to types* (`:154-155`). Every branch introduced below keys
  on `PIPELINE`, `SHIP`, `RIGOR_PLAN`, or `RIGOR_CODE` — never on `TYPE`. The resolver already
  branches on `$pipeline` this way at `resolve-type.sh:357-362` and `:496`.
- *The seam rule* (`:156-159`). `live` loads exactly what its row's axes name: `live.md` (new seam
  row), the `planner` warmed with `plan-live`, `review-plan` only at plan rigor med+, the publish
  seam, and `review-code` only when the user opts into the pre-PR review.
- *The carried invariants* (`:160-166`). `live` adopts the shared worker envelope,
  kickback-by-report-path, script-written verdicts, the plan→contract flow and its blindness,
  state-in-files, the scope scripts, and the mandatory PR gate — it reinvents none of them.
- *`pipeline` is not an array* (`:167-172`). `live` is a genuinely different stage shape, not a
  footprint flag: it inverts `build.md:13`'s auto-mode switch, has no mandatory code gate, and
  grows its plan phase-by-phase during the build.

---

## Stack & MAJOR versions

Verified from the environment and the sources themselves. This repo carries **no package
manifest** — no `package.json`, no `Makefile`, no `justfile` (confirmed by a tree-wide search of
the repo root) — so the "stack" is the shell toolchain the hooks bind to.
`.github/workflows/publish-docs.yml` and `scripts/` arrived in `d751bea`; they are CI templates
*for consumers* (`README.md:44`), not a build system for this repo, and no test suite runs under
CI.

| Component | Version / flavor | Verified from |
|---|---|---|
| Bash | 5.1.16(1) | `bash --version`; every hook declares `#!/usr/bin/env bash` (`resolve-type.sh:1`) |
| GNU sed | 4.8 | `sed --version`; used by `resolve-type.sh:276` |
| awk | POSIX subset only | `resolve-type.sh:231-246` uses no GNU extensions; `resolve-config.sh:21` records that this repo has **no jq and no YAML parser** |
| Test framework | none — hand-rolled `tests/*.test.sh`, **10 suites today, 13 after Phase 4** adds three, run as `bash tests/<name>.test.sh` | `ls tests/*.test.sh \| wc -l` → 10; `tests/resolve-type.test.sh:5,41` |
| Content format | Markdown skills/agents/rules with YAML frontmatter | `docs/conventions.md` |

No application framework, no compiled language, no lockfile. Idioms must match bash 5.1 and the
existing hooks' deliberately-portable style.

---

## Conventions to enforce

1. **This repo is the SOURCE; `~/.claude/` is an install.** Edit only `orchestrators/`,
   `agent-agnostic/`, `docs/`, `tests/`, and the root guides. Never edit `~/.claude/` — not to
   "check", not to test (`.claude/rules/source-push-sync.md:1-3`).
2. **`workflows.yaml` rows are ONE-LINE FLOW MAPS** (`workflows.yaml:6-10`): no YAML parser
   exists, `resolve-type.sh` parses rows with bash + awk, and nesting beyond the inline
   `rigor: {…}` map and `aliases: […]` list will not parse. Do not reformat into block mappings;
   do not wrap a row across lines.
3. **`resolve-type.sh` is the ONLY reader of the type table** (`resolve-type.sh:13-18`,
   `SKILL.md:75`).
4. **No control flow keys off a type name** (`SKILL.md:69`, `orchestrators/AGENTS.md:154-155`).
5. **Absent values are omitted, never emitted empty** (`SKILL.md:77`, `resolve-type.sh:524-538`).
6. **A stderr warning is not an error** (`SKILL.md:81`). A warning path exits 0 AND still prints
   the full `KEY=value` block; only a constraint violation exits 1 with nothing on stdout.
7. **`err()` messages end in a question** — every message in `resolve-type.sh` does
   (`:145,153,154,171,184,188,208,216,477,492,494`). `warn()` messages do not; they state the
   fact and say the run continues (`:465-466`). Match both voices.
8. **The contract tests are BLIND.** `tests/resolve-type.test.sh:12-35` never reads
   `resolve-type.sh`'s source and never reads the real `workflows.yaml` for fixture expectations.
   Preserve that discipline: new expectations come from this plan's detail blocks (and the
   contract the builder writes from them), never from reading the implementation.
9. **Test naming:** `NN[letter]: <description>`, or `NN/<type>: …` for loop-parameterized cases.
   Reuse the existing primitives — `ok_lines`, `no_lines`, `err_case`, `err_sub`, `err_tok`,
   `no_key_block` (`tests/resolve-type.test.sh:125-171`). Use `err_tok`, not `err_sub`, whenever a
   short token (`pr`, `live`, `--rew`, `--sh`) could be satisfied by a longer word.
10. **Skills and rules may not describe the directory tree** (`docs/README.md:29-32`); they refer
    to installed siblings by NAME only. `live.md` says "installed next to this one";
    `plan-live.md` says "alongside this definition" (`SKILL.md:19`, `planner.md:21`).
11. **`docs/` links out, it does not repeat** (`docs/pipeline.md:3-4`). Phase 4 updates counts and
    rows in `docs/`, never moves behavior there.
12. **Never a time estimate anywhere** (`plan-format`).
13. **Per-lane file-scope discipline.** Lanes 1–4 and lane 6 have provably disjoint file scopes
    (table below). Lane 5 is the serialized integration lane and is the ONLY lane touching the
    docs/guides that summarize all of it.
14. **Nothing in this plan touches `worktree-modes.md`, `build.md`, or `workflow-setup.sh`** —
    the `-w none` deferral. A diff that touches any of the three is out of scope and a finding.

### The exact `workflows.yaml` rows after this change

Pinned here so lanes 1, 2, 4 and 5 all write matching content without coordinating. Column
alignment is cosmetic; cell ORDER is not load-bearing (`resolve-type.sh:90-105` matches by key),
but keep `aliases:` last, as every existing row does.

```yaml
types:
  feature:   {pipeline: build,  explore: auto, rigor: low,                against: optional, ship: publish,      planner: plan-feature,   branch: feature/, rework: 3}
  bugfix:    {pipeline: build,  explore: auto, rigor: low,                against: optional, ship: publish,      planner: plan-bugfix,    branch: bug/,     rework: 3, aliases: [bug]}
  hotfix:    {pipeline: build,  explore: auto, rigor: low,                against: optional, ship: publish,      planner: plan-bugfix+minimal-scope, branch: hotfix/, rework: 3}
  migration: {pipeline: build,  explore: auto, rigor: low,                against: optional, ship: publish,      planner: plan-migration, branch: feature/, rework: 3}
  rework:    {pipeline: build,  explore: auto, rigor: low,                against: require,  ship: publish,      planner: plan-rework,    branch: feature/, rework: 3}
  live:      {pipeline: live,   explore: auto, rigor: low,                against: optional, ship: publish,      planner: plan-live,      branch: feature/, rework: 2, aliases: [adhoc]}
  diagnose:  {pipeline: plan,   explore: deep, rigor: low,                against: optional, ship: publish,      planner: plan-diagnosis, branch: bug/,     aliases: [debug, triage]}
  map:       {pipeline: report, explore: auto, rigor: low,                against: forbid,   ship: chat|publish}
  analyze:   {pipeline: report, explore: deep, rigor: {explore: med},     against: forbid,   ship: publish|chat, branch: docs/}
  document:  {pipeline: docs,   explore: deep, rigor: {explore: med},     against: forbid,   ship: publish,      branch: docs/,   aliases: [doc]}
  sync:      {pipeline: plan,   explore: deep, rigor: {explore: med},     against: require,  ship: publish,      planner: plan-reconcile, branch: sync/}

default_type: feature   # when nothing is inferable and the ask is purely additive
```

Two things the header comment block (`workflows.yaml:1-14`) must be extended to say, or a future
reader will "fix" them:

- **The `ship` cell is a `|`-separated allowed-value list, first = default.** One value means the
  row is fixed. `split_cells()` splits only on depth-0 commas, so a `|` inside a cell survives
  untouched (`resolve-type.sh:63-76`), and `publish|chat` is an ordinary plain scalar in YAML flow
  context. The resolver trims each alternative, so `publish|chat` and `publish | chat` both parse;
  the table uses the tight form and the DOCS render the spaced form (see 2.2).
- **The TYPE `rework` and the CELL `rework:` are unrelated.** The row key sits outside the flow
  map's `{…}` and `cell_value()` only ever searches INNER (`resolve-type.sh:80-105`).

### The exact `REWORK=` emission contract

`REWORK` is emitted **immediately after `SHIP=` and before `PLANNER=`** — it joins the
row-supplied optional tail (`resolve-type.sh:534-538`). Two full expected blocks, pinned:

```
TYPE=feature          TYPE=live
PIPELINE=build        PIPELINE=live
EXPLORE=auto          EXPLORE=auto
RIGOR_EXPLORE=low     RIGOR_EXPLORE=low
RIGOR_PLAN=low        RIGOR_PLAN=low
RIGOR_CODE=low        RIGOR_CODE=low
RIGOR_PR=low          RIGOR_PR=low
AGAINST_COUNT=0       AGAINST_COUNT=0
SHIP=publish          SHIP=publish
REWORK=3              REWORK=2
PLANNER=plan-feature  PLANNER=plan-live
BRANCH=feature/       BRANCH=feature/
```

`SHIP=` always emits the RESOLVED single value, never the row's list — the list is table syntax,
not output. `map`'s and `analyze`'s existing blocks (`tests/resolve-type.test.sh:749-777`) are
therefore unchanged.

### Lane file scopes (disjoint by construction)

| Lane | Files |
|---|---|
| 1 | `orchestrators/hooks/resolve-type.sh`, `orchestrators/skills/dae/workflows.yaml`, `tests/resolve-type.test.sh` |
| 2 | `orchestrators/skills/dae/SKILL.md` |
| 3 | `orchestrators/agents/builder.md`, `orchestrators/skills/dae/build-dispatch.md`, `orchestrators/agents/planner.md`, `orchestrators/agents/planner/plan-live.md` (new) |
| 4 | `orchestrators/skills/dae/live.md` (new), `agent-agnostic/skills/review-pr/SKILL.md` |
| 5 | `orchestrators/skills/dae/SKILL.md`, `orchestrators/skills/dae/build-dispatch.md`, `orchestrators/skills/dae/live.md`, `orchestrators/agents/builder.md`, `orchestrators/AGENTS.md`, `README.md`, `docs/pipeline.md`, `docs/architecture.md`, `docs/README.md`, `docs/known-issues.md` (new) |
| 6 | `orchestrators/hooks/scope-writes.sh`, `orchestrators/hooks/parent-tree-guard.sh` (new), `orchestrators/hooks/verify-scope.sh`, `agent-specific/claude/settings.json`, `tests/scope-writes.test.sh` (new), `tests/parent-tree-guard.test.sh` (new), `tests/verify-scope-clean.test.sh` (new) |

**Lane 5 also inherits `build-dispatch.md` and `builder.md` from the merged lane 3, and `live.md`
from the merged lane 4** (5.4). Same reasoning as `SKILL.md` below: those lanes closed before
Amendment 4, so the files are free, and neither lane 1 nor lane 6 touches them.

**Lane 5 inherits `SKILL.md` from the merged lane 2.** That file was lane 2's alone while lane 2 was
in flight; lane 2 merged before Amendment 3, so the file is free and the `SKILL.md:143` correction
(Amendment 3 item 5) lands in lane 5 rather than reopening a closed lane. Lane 1 and lane 6, the two
lanes still running, do not touch it.

**Lane 6 is internally serial** (4.1 → 4.2 → 4.3 → 4.4 → 4.5): 4.3 wires the hooks 4.1 and 4.2
produce, and 4.5 tests all three scripts. 4.4 is independent in CONTENT — `verify-scope.sh` is
invoked by the router's dispatch loop, not wired as a hook, so it shares no file with 4.1–4.3 — but
it shares the lane's single builder, so the chain is expressed serially rather than as a fork.

**Lane 1 is internally serial.** Its four subphases (1.1 → 2.1 → 3.1 → 3.2) all touch
`resolve-type.sh`, `workflows.yaml`, and `tests/resolve-type.test.sh`. The builder must treat them
as ONE serialized packet chain, not four parallel packets — the `(after:)` edges say so and the
file scope makes it mandatory. Lane 2's three subphases (1.2 → 2.2 → 3.7) are serial for the same
reason, as are lane 3's `build-dispatch.md`/`builder.md` pair (1.3 → 1.4), which must agree
word-for-word about what the budget means.

---

## Phase 1 — The `--rework` build dial

### 1.1: Resolver + type table — `--rework` flag, `rework:` cell, `REWORK=` emission   (lane 1)

**File scope:** `orchestrators/hooks/resolve-type.sh`, `orchestrators/skills/dae/workflows.yaml`,
`tests/resolve-type.test.sh`.

**Pattern to follow:** the free-tier flag path already in the file — `--explore` is parsed at
`:193`, validated at `:351-354`, and emitted unconditionally at `:523`; the conditional emission
to copy is the rigor tail at `:524-527`. The drop-with-warning path is `drop_phase()` at
`:464-471`; the optional row cell path is `planner`/`branch` at `:345-348` and `:535-536`.

**What to build.**

1. **Flag registration.** Add `--rework:--rew` to `FLAG_TABLE` (`:133`). No single-dash alias —
   `-r` already belongs to `--rigor` (`:142`) and must keep belonging to it. The bracket minimum
   `--rew` is chosen so `--re` and `--ri` (both length 4, below both minimums) remain unknown
   flags, and `--rig` / `--rew` disambiguate cleanly at length 5. Verify by reading
   `resolve_flag()` at `:135-158`: prefix match plus a `[ "${#tok}" -ge "${#min}" ]` floor, so
   nothing else changes.
2. **Error-message lists.** `:145` and `:153` enumerate the flags; add `--rework`, and add `--rew`
   to `:153`'s short-form list. Extend the SYNOPSIS at `:5-7` and the DESCRIPTION's free-tier
   sentence at `:14-16`. **Coordinate with 2.1:** those two lists lost `--ship` in `5108f1d`;
   Phase 2 restores it. Lane 1 runs 1.1 before 2.1, so 1.1 adds `--rework` only and 2.1 restores
   `--ship` without dropping it.
3. **Argv handling.** Add a `rework)` arm to the `case "$canon"` at `:191-212`, capturing the value
   into `rework_override` with a `have_rework` flag (mirroring `have_explore`).
4. **Value validation:**
   - Non-integer, empty, or `< 1` → `err`, exit 1, naming `--rework`, the offending value, and
     "an integer 1 or greater", ending in a question.
   - `> 5` → `warn` naming `--rework` and the value; the run **continues at exit 0** and still
     prints the full block. No hard ceiling.
5. **Row cell.** Read an optional `rework` cell exactly as `planner`/`branch` are read at
   `:345-348`. Precedence: the flag overrides the row; a row value with no flag is used as-is;
   neither present → nothing emitted.
6. **Conditional emission.** `REWORK=<n>` prints only when `has_code_phase = 1` (the variable
   exists at `:357-362`). When the run has no code phase and the user explicitly passed
   `--rework`, warn and drop — the shape `drop_phase()` uses at `:464-467` — naming the dial and
   the resolved type, exit 0, and **no `REWORK=` line**. A value inherited from the ROW on a
   code-phase-less run drops SILENTLY (no row carries one today; state the rule so a future row
   cannot warn spuriously — mirroring "a scalar expansion names nothing, so it drops silently",
   `:460-463`).
7. **Table rows.** Add `rework: 3` to the five `pipeline: build` rows (`feature`, `bugfix`,
   `hotfix`, `migration`, `rework`) exactly as pinned in Conventions. Do NOT add it to `diagnose`,
   `sync`, `map`, `analyze`, or `document` (settled decision D1 below). Extend the header comment
   block with the `rework:` cell paragraph and the name-collision note.

**Acceptance criteria.**

- `resolve-type.sh feature` prints exactly the pinned `feature` block, in order, with `REWORK=3`
  between `SHIP=` and `PLANNER=`, and nothing else.
- `feature --rework 7` → `REWORK=7`, exit 0, stderr warning naming `--rework`.
- `feature --rework 1` → `REWORK=1`, exit 0, no warning.
- `feature --rework 0`, `--rework abc` → exit 1, stderr names `--rework` and the value, nothing on
  stdout.
- `map --rework 3` → exit 0, a warning naming the dial and `map`, and NO `REWORK=` line.
- `document --rework 3` → same drop-with-warning shape (`docs` has a `pr` phase but no `code`
  phase, `:360`).
- `--rew 4`, `--rewo 4`, `--rework 4` resolve identically; `--re 4` and `--r 4` are unknown flags
  (exit 1); `-r 4` still means `--rigor` and fails on the rigor value vocabulary.
- `map` still prints exactly its existing block.
- `bash -n orchestrators/hooks/resolve-type.sh` exits 0.

**Test approach.** Extend `tests/resolve-type.test.sh` with a `REWORK DIAL` section banner after
the absent-phase/D2 section. New cases `51a-e` (bracket minimums and rejections, using `err_tok`
so `--rew` is not satisfied by `--rework`), `52a-c` (value validation; the `>5` case asserted as
the same warning-AND-exit-0 PAIR case 27 uses at `:514-530`), `53a-c` (drop-with-warning on `map`
and `document`, plus a `no_lines '^REWORK='` absence assertion), `54a-b` (row default vs flag
override). **Existing case this subphase breaks and must repair:** case `43a` at `:730-747`
asserts `feature`'s stdout byte-for-byte — it gains the `REWORK=3` line. Case `43b` (`map`,
`:749-761`) and `43c` (`analyze`, `:763-777`) are unchanged but should each gain an explicit
`^REWORK=` absence assertion. **The suite's numbered cases currently run through `50`** — `44`–`49`
are the ship-lock cases (`:880-948`) and `50` is the pipeline-vs-ship precedence case
(`:950-963`), the last case before the file's Summary block. New sections therefore start at `51`,
and this numbering is shared across 1.1, 2.1 and 3.1: 1.1 takes `51`–`54`, 2.1 takes `55`, 3.1
takes `56`. Verify with `grep -n '^# --- Case' tests/resolve-type.test.sh` before adding anything
— the highest existing number, not this plan's prose, is the authority.

**Test oracle:** `new contract tests`.

### 1.2: Router doc — flag table, bracket minimums, emitted keys, error set   (lane 2)

**File scope:** `orchestrators/skills/dae/SKILL.md`.

**Pattern to follow:** the flag table at `:25-34` and the "Facts settled below are not to be
re-litigated" bullet list at `:36-45`.

**What to build.**

1. A flag-table row: `` `--rew[ork]` `` | *(none)* | `<n>` — integer ≥ 1 | per the resolved type
   row. Place it after `--pl[an]` and before `--work[tree]`, so axis-and-dial flags stay grouped
   above the run-continuity flags. (2.2 inserts `--sh[ip]` into the same table; the two subphases
   are serial in lane 2, so the later one preserves the earlier's row.)
2. Update `:39`'s bracket-minimum sentence to add `--rew`. (2.2 restores `--sh` to the same
   sentence.)
3. Add a settled-fact bullet, sibling to `:40`'s "Why `--rig` and not `--r`": **why `--rew` and
   not `--re`** — `--rework` and `--rigor` share the `--r` prefix space, so both carry a
   5-character minimum and `-r` stays `--rigor`'s alone; `--rework` has no single-dash alias.
4. Add a settled-fact bullet: **`--rework` is a build DIAL, not a sixth axis.** There are still
   five axes (`:19`, `:44`). Rework is a *persistence budget* (how many times a builder may
   re-dispatch before giving up); rigor is *verification width* (how many cold reviewers judge).
   Orthogonal — a run may raise one without the other. Its override tier is **free**, alongside
   `--explore` and `--rigor` (`:44`).
5. Add `REWORK` to the emitted-keys list at `:77`, stating it appears only on runs that have a
   `code` phase and is omitted (never emitted empty) otherwise.
6. Extend `:79`'s error set with "`--rework` value validation (integer ≥ 1)" and `:81`'s warning
   examples with `dae map --rework 3` — a `report` pipeline has no `code` phase, so the dial is
   dropped and warned about, exit 0.
7. Re-read `:47`: `--worktree`/`--base`/`--name` are run continuity and are NOT passed to
   `resolve-type.sh`; `--rework` IS passed to it, so it does not belong in that sentence.

**Acceptance criteria.** Every claim the file makes about the resolver matches 1.1's behavior
verbatim: flag table, bracket minimums, emitted keys, error set, warning example. A reader with
only this file can predict `resolve-type.sh feature` and `resolve-type.sh map --rework 3` exactly.
No sentence calls rework an axis; the "five axes" count at `:19` and `:44` is unchanged.

**Test approach.** No automated test covers prose. Line-by-line read-through against 1.1's
acceptance criteria and against `resolve-type.sh` — read whatever revision of it is on disk at the
time. **This is a consistency check, not a scheduling dependency:** lane 2 carries no `(after:)`
edge to lane 1 and must not wait on it. Conventions pins the exact table rows and emission
contract precisely so lanes 1, 2, 4 and 5 write matching content without coordinating, and the
authoritative cross-file agreement check is 5.5, which does carry the full `after:` set. Plus a
grep for `axes`/`axis` confirming the count is still five.

**Test oracle:** `existing suite`.

### 1.3: Builder dispatch prompt carries the budget   (lane 3)

**File scope:** `orchestrators/skills/dae/build-dispatch.md`.

**Pattern to follow:** the "Builder dispatch prompt" section at `:27-29` — one dense paragraph
enumerating exactly what each builder receives.

**What to build.** Add the rework budget to that enumeration: each builder gets the run's `REWORK`
value when the resolver emitted one. State the fallback explicitly: **when no `REWORK` line was
emitted, no budget is passed and the builder's loops stay unbounded — today's behavior** (settled
decision D2 below). Say in one sentence what the budget means so the dispatcher cannot
mis-describe it: max rework rounds per packet AND max chunk-level e2e diagnose-and-redispatch
rounds — a persistence budget, not a verification width.

**Scope guard:** this subphase touches the dispatch-prompt paragraph only. `build-dispatch.md`'s
"Lanes and isolation" section (`:5-7`) is NOT in scope — the `-w none` work that would have
touched it is deferred out of this plan.

**Acceptance criteria.** The dispatch-prompt paragraph names the budget alongside the plan path,
lane ids, file scope, parent branch, run dir, and rework-report path. Its description of the
budget's meaning matches `builder.md` (1.4) in substance. The absent-budget fallback is stated,
not implied. `git diff` on this file shows changes inside the dispatch-prompt section only.

**Test approach.** Read-through against 1.4 and `SKILL.md`'s flag-table row (1.2); no automated
coverage exists for middle-file prose.

**Test oracle:** `existing suite`.

### 1.4: Builder honors the budget as its loop bound; exhaustion exits `blocked`   (lane 3, after: 1.3)

**File scope:** `orchestrators/agents/builder.md`.

**Pattern to follow:** the phase descriptions at `:30` (phase 4, "Loop per packet until green")
and `:32` (phase 5, chunk-level diagnose-and-redispatch), and the exit-report contract at `:36`,
which already defines `status: success|blocked|needs-input|failed`.

**What to build.**

1. In the input enumeration at `:7`, add the rework budget, with the same absent-means-unbounded
   fallback 1.3 states — worded to match, since the two files are the two halves of one contract.
2. Bound **phase 4**: the per-packet rework loop runs at most `<budget>` rounds. A round is one
   fresh `coder` or fresh `contract-tester` re-dispatch.
3. Bound **phase 5**: the chunk-level diagnose-and-redispatch loop runs at most `<budget>` rounds,
   counted separately from any packet's count.
4. Add an exhaustion rule to the Invariants block at `:9-18`, where the other never-negotiable
   rules live: on exhaustion the builder STOPS, writes its exit report with `status: blocked`, and
   puts its latest diagnosis (reproduction, location along the real flow, evidence, what it tried
   each round) in the report. It does NOT merge, does NOT report success, does NOT silently
   continue. This sits beside `:15` ("Only your e2e phase exits the loop") — the budget is the
   second, bounded exit, and the text must make clear it is an exit to `blocked`, never an exit to
   green.
5. State that the budget never licenses lowering the bar: a builder may not weaken a test, relax a
   contract, or skip the e2e tail to fit inside the budget. Running out is a report, not a
   shortcut. This is the Goodhart guard the dial needs, and it belongs in the Invariants block.

**Acceptance criteria.** Both loops name the bound. The exhaustion path is in the Invariants block,
names `status: blocked`, and requires the diagnosis in the exit report. The absent-budget fallback
matches 1.3 word-for-word in substance. No sentence permits declaring success on an exhausted
budget, and none permits weakening the oracle to fit it.

**Test approach.** Read-through against `build-dispatch.md` as 1.3 left it (same lane, so it is on
disk), and against `validate-report.sh --kind exit`'s accepted status vocabulary — `blocked` is
already valid (`builder.md:36`), so no script change is implied. Confirm by grepping
`orchestrators/hooks/validate-report.sh` for the status list before writing the text.

**Test oracle:** `existing suite`.

---

## Phase 2 — `--ship` becomes constrained per row

### 2.1: Resolver + type table — the `ship` cell becomes an allowed-value list   (lane 1, after: 1.1)

**File scope:** `orchestrators/hooks/resolve-type.sh`, `orchestrators/skills/dae/workflows.yaml`,
`tests/resolve-type.test.sh`.

**Pattern to follow:** the `--against` arity constraint at `:504-519` — the existing worked example
of a *constrained* axis validated at parse time against a per-row rule, with its error message's
type lists DERIVED from the parsed table (`:508-513`, `:253-273`). This subphase makes `ship` look
like `against`, not like `pipeline`.

**What to build.**

1. **Argv.** Restore value capture: the `ship)` arm at `:194` currently sets only `ship_given=1`
   and throws the value away. Capture it into `ship_override` with `have_ship=1`, as it did before
   `5108f1d` and as `explore` still does at `:193`.
2. **Row cell parsing.** `:340-341` currently reads one value and validates it with
   `in_list "$ship" "$VOCAB_SHIP"`. Split the cell on `|` into an ordered allowed-list, trimming
   each alternative; validate **every** alternative against `VOCAB_SHIP`, with a malformed-row
   error naming the offending alternative; reject an empty alternative (a stray `|`) the way
   `:208` rejects an empty anchor — a silently dropped alternative is worse than an error. The
   **first** value is the row's default.
3. **The resolution rule — four cases, exactly.** This is the whole semantic and it must be
   implemented as written:
   - **Not in `VOCAB_SHIP`** → `err`, exit 1, existing wording ("ship value '<v>' is not one of
     chat, publish — which did you mean?"). Unchanged.
   - **Equal to the row's default** → `warn`, exit 0, run continues with the default, full block on
     stdout. The wording branches on the row, not the type: a row with MORE THAN ONE alternative
     says the value is *already the default* for `<type>`; a SINGLE-alternative row says `--ship`
     is *fixed* on `<type>` and the flag is being ignored. Both are warnings, never errors —
     restating what a row already says is a no-op, not a category error.
   - **Different from the default AND present in the row's list** → apply it. `ship` becomes that
     value.
   - **Different from the default AND absent from the row's list** → `err`, exit 1, nothing on
     stdout. Retain the current phrasing's shape and its table-derived "for a chat answer run …,
     for a published report run …" tail.
4. **Ordering — and it matters twice.** The phase-existence table at `:357-362` reads `$ship` for
   `report`, so the override MUST resolve before it; that is why step 3 sits in the
   free-tier/override block at `:350-355` and not in the constraints block. To keep the error
   precedence the constraints block's own comment describes (`:473-476`: locked, then placement,
   then arity), **move the `--pipeline` lock check (`:477`) up to immediately before the ship
   resolution.** Pin the resulting precedence: locked `--pipeline` → constrained `--ship` →
   `--plan` placement → `--against` arity. The move is now doubly load-bearing: it keeps the
   pipeline error first AND prevents a stray ship WARNING from reaching stderr on a run that is
   about to be refused for its pipeline — which is exactly what case 50 asserts.
5. **Derived type lists.** `:254` and `:266-267` collect `chat_types` / `publish_types` by EQUALITY
   on the single ship value. Change to CONTAINMENT — a row belongs to `chat_types` if `chat` is
   among its alternatives — so the error message keeps naming every type that can actually do what
   the user asked. Do not hardcode any type name (`:248-252`).
6. **Delete the locked-`--ship` block at `:479-494` entirely.** Its behavior now lives in step 3.
   Per the repo's "no old code alongside new" standard, remove it; do not leave it guarded.
7. **Header comments.** `:6-7` and `:11-16` describe `--ship` as locked and exclude it from the
   SYNOPSIS at `:5-7`. Restore `[--sh[ip] <v>]` to the SYNOPSIS and rewrite the DESCRIPTION to say
   `--ship` is constrained per row, `--pipeline` alone is locked.
8. **Table.** Set the `ship` cells exactly as pinned in Conventions: `map: chat|publish`,
   `analyze: publish|chat`, every other row a single value. Add the header-comment paragraph
   describing the list syntax.

**Acceptance criteria.**

- `feature --ship chat` → exit 1; stderr names `--ship`, `feature`, and `publish`; **nothing on
  stdout** (`no_key_block`).
- `feature --ship publish` → **exit 0**, `SHIP=publish`, full block on stdout, and a stderr warning
  saying `--ship` is fixed on `feature` and is being ignored.
- `analyze --ship publish` → **exit 0**, `SHIP=publish`, full block, and a stderr warning saying
  `publish` is already the default for `analyze`.
- `analyze --ship chat` → exit 0, `SHIP=chat`, **no** `RIGOR_PR` line, and **no** warning.
- `map` (bare) → exit 0, `SHIP=chat`, no `RIGOR_PR` line; its `43b` block byte-identical to today's.
- `map --ship chat` and `map --sh chat` → exit 0, `SHIP=chat`, full block, warning "already the
  default"; never "unknown flag".
- `map --ship publish` → exit 0, `SHIP=publish`, no warning, and — because the phase table now sees
  the resolved value — `RIGOR_PR=low` IS emitted.
- `analyze` (bare) → exit 0, `SHIP=publish`; its `43c` block byte-identical to today's.
- `feature --ship banana` → exit 1 on the VALUE vocabulary, not on the row policy.
- `feature --ship` at end of argv → exit 1, "missing value" + `--ship` (unchanged).
- `feature --shp publish` → exit 1, unknown flag naming `--shp` and neither `--ship` nor `--sh`.
- A fixture row `ship: chat|banana` → exit 1, malformed row naming `banana`. A fixture row
  `ship: chat|` → exit 1 on the empty alternative. A fixture row `ship: publish | chat` (spaced)
  parses identically to the tight form.
- `feature --pipeline build --ship publish` → the `--pipeline` lock error, exit 1, and **no ship
  warning anywhere on stderr** (precedence).
- `bash -n orchestrators/hooks/resolve-type.sh` exits 0.

**Test approach.** **Cases 44, 45, 46 and 49 (`tests/resolve-type.test.sh:880-948`) are the
ship-LOCK regression suite and must be rewritten**, not deleted — they become the constrained
suite:

- **44** (`feature --ship chat`) keeps asserting a REFUSAL — the §A1 regression the lock existed to
  prevent, which per-row legality preserves. Its assertions survive; only the word "locked" in its
  banner needs revisiting.
- **45** (`analyze --ship publish`) **flips from an error case to a warn-and-continue case**: exit
  0, `SHIP=publish` on stdout, and a stderr warning containing "already the default". Assert the
  warning AND the exit-0 AND the stdout block as one triple, the way case 27 asserts its pair at
  `:514-530` — a warning path that silently stopped emitting the block would otherwise pass.
- **46** (`map --sh chat`) becomes "the short form resolves and the value warns as already-default,
  never 'unknown flag'": exit 0, block present, warning present.
- **49**'s fixture gains a `gamma: {… ship: chat|publish}` row and asserts the derived lists in the
  REFUSAL path (a value absent from the row's list), which is the only path that still errors.

Cases 47 (missing value) and 48 (`--shp` unknown) pass unchanged and must be left alone. Case 29's
banner comment ("analyze's ship is now locked to publish") needs rewording.

**Case 50 (`:950-963`) — assertions KEPT, banner reworded.** It runs
`feature --pipeline build --ship chat` and asserts exit 1 with `--pipeline`, `locked` and `feature`
on stderr and `--ship` ABSENT from it. Step 4 moves the `--pipeline` lock check but keeps it ahead
of the ship resolution and leaves its message untouched, so **every one of those assertions still
holds and the case body must not be edited.** Only its banner ("`--pipeline` locked fires before
`--ship` locked") goes stale, since `--ship` is no longer locked — reword it to "`--pipeline`
locked fires before the `--ship` row-legality check", exactly as case 29's banner is reworded
above. This case is the mechanical proof of the precedence step 4 pins; treating it as collateral
damage rather than as the precedence test would lose that.

Add new cases `55a-h` covering the row-list syntax and the full four-case matrix: the `|` split
(tight and spaced), first-as-default, malformed and empty alternatives, warn-on-equal for both a
fixed row and an overridable row, apply-on-legal-override, error-on-illegal-override, the
`map --ship publish` phase-table consequence, and a precedence assertion complementing case 50
from the other side (an illegal `--ship` fires before `--plan` placement and before `--against`
arity).

**Test oracle:** `new contract tests`.

### 2.2: Router doc — `--ship` returns to the flag table in the constrained tier   (lane 2, after: 1.2)

**File scope:** `orchestrators/skills/dae/SKILL.md`.

**Pattern to follow:** the `--ag[ainst]` row at `:30`, whose Default column already names a per-row
rule (`` per the resolved type row's `against:` rule (`forbid`|`optional`|`require`) ``) —
`--ship` gets the same treatment.

**What to build.**

1. **Restore the flag-table row:** `` `--sh[ip]` `` | *(none)* | `chat` \| `publish` | per the
   resolved type row's `ship:` list — first value is the default; a single-value row is fixed.
   Place it after `--pl[an]`, before `--rew[ork]` (1.2's row).
2. **`:39`** — add `--sh` back to the bracket-minimums sentence.
3. **`:42`** — keep `-s` and `-p` deliberately unassigned; `--ship` still has no single-dash alias.
   Reword only as needed so it no longer implies `--ship` is unavailable as a long flag.
4. **Rewrite `:43` as the supersession record.** It currently argues at length that "No row has a
   legitimate second ship value" and that "A per-row `require|optional|forbid` policy would imply
   some row wants the choice, and none does." Replace it with: `--pipeline` alone is locked; plus a
   short, dated note that the `--ship` lock shipped in `report-pipeline-and-locations-08-26-26` §1.2
   and was **deliberately reversed** here, with the reason from Goal & scope. Per convention this is
   a REPLACEMENT of the settled fact, not a second bullet contradicting the first.
5. **Rewrite `:44`'s override-tier bullet:** `--explore` and `--rework` are **free**; `--against`,
   `--plan`, and `--ship` are **constrained** (validated mechanically at parse time, before setup);
   `--pipeline` alone is **locked**. Keep the free tier's definition — an override can never produce
   an incoherent run — and explain that `--ship` sits in the constrained tier precisely because
   coherence is row-dependent: legal on `map`/`analyze`, incoherent on a build.
6. **Document the warn-vs-error rule**, since a user needs to predict it: naming the value a row
   already defaults to is a WARNING and the run continues; naming a different value the row allows
   APPLIES it; naming a value the row does not allow is an ERROR. Add the warning example to `:81`
   alongside the rigor one — `dae feature --ship publish` warns that `--ship` is fixed on `feature`
   and continues.
7. **`:79`'s error set:** "locked `--ship`" → "`--ship` legality against the row's `ship:` list".
8. **`:53-64` type table, `ship` column:** render an overridable cell as **`publish | chat`** —
   default first, spaces around the pipe (settled decision D10). `map` → `chat | publish`;
   `analyze` → `publish | chat`; every other row stays a single bare value. Update the column
   header if "ship default" no longer describes it accurately.
9. **`:68`'s `map` vs `analyze` bullet** currently ends "`map` skips the publishing pre/post run
   steps entirely and answers in chat; `analyze` always publishes." The second clause is no longer
   true. Reword: each has a default, and each can be pushed to the other mode by `--ship`; they
   still differ ONLY in axis values, never in shape.

**Acceptance criteria.** The flag table has a `--sh[ip]` row again. The override-tier bullet lists
exactly one locked flag. The supersession note names the superseded plan and the reason. No
sentence still claims no row wants a ship choice. The warn-vs-error rule is stated in all three of
its branches. Overridable ship cells render as `publish | chat` / `chat | publish`. The type
table's ship column matches `workflows.yaml` for all rows. A reader with only this file can predict
every one of 2.1's acceptance criteria.

**Test approach.** Read-through against 2.1's acceptance criteria as this plan states them — a
consistency check against the plan, NOT a scheduling dependency on lane 1 (see 1.2's test approach;
5.5 is where cross-file agreement is enforced). Plus `grep -n 'locked' SKILL.md` returning only
`--pipeline` hits and the historical note.

**Test oracle:** `existing suite`.

---

## Phase 3 — The `live` type

### 3.1: Resolver + type table — `pipeline: live` and the `live` row   (lane 1, after: 2.1)

**File scope:** `orchestrators/hooks/resolve-type.sh`, `orchestrators/skills/dae/workflows.yaml`,
`tests/resolve-type.test.sh`.

**Pattern to follow:** `VOCAB_PIPELINE` at `:121` and the phase-existence table at `:357-362`.

**What to build.**

1. `VOCAB_PIPELINE="build plan report docs live"` (`:121`).
2. Phase existence (`:358`): `build|plan|live)` sets `has_plan_phase`, `has_code_phase`, and
   `has_pr_phase` to 1. Live has a plan phase (its planner module), a code phase (it dispatches
   builders, and `RIGOR_CODE` decides the pre-PR review default), and a pr phase (`ship: publish`).
   Consequently `REWORK=` is emitted for live — the row supplies 2.
3. Add the `live` row to `workflows.yaml` exactly as pinned in Conventions, after `rework:` and
   before `diagnose:`, so the five build rows plus live read as one block.
4. **No `ship`-specific code is needed for live.** `live: {… ship: publish}` is a single-value list,
   so Phase 2's rule already refuses `dae live --ship chat` with an error and warns on
   `dae live --ship publish`. This is the seam rule working: a new type costs a row, not a special
   case.
5. `--plan` placement is deliberately UNCHANGED: `:496`'s `[ "$pipeline" != "build" ]` keeps
   rejecting `--plan` on live, and its error's build-type list is table-derived (settled decision
   D5).

**Acceptance criteria.**

- `resolve-type.sh live` prints exactly the pinned `live` block, in order.
- `resolve-type.sh adhoc` → `TYPE=live` (canonical name, not the alias).
- `live --ship chat` → exit 1, stderr names `--ship` and `live`, nothing on stdout.
- `live --ship publish` → exit 0, `SHIP=publish`, full block, stderr warning that `--ship` is fixed
  on `live`.
- `live` emits `RIGOR_PLAN`, `RIGOR_CODE`, `RIGOR_PR`, and `REWORK=2`.
- `live --rework 4` → `REWORK=4`.
- `live -a PROJ-123` → `AGAINST_COUNT=1` (the row is `optional`).
- `live --plan /some/path` → exit 1, the existing placement error, whose table-derived build-type
  list does not name `live`.
- `bash -n orchestrators/hooks/resolve-type.sh` exits 0.

**Test approach.** Add `live` to the canonical-type loop at `:196` (no anchor needed — it is
`optional`) and update the "all ten canonical types" banner at `:193` to eleven; add `live` to the
code-phase loop at `:463`; add a case asserting `--plan` is REFUSED on live (the accepting loop at
`:631-635` stays build-only). New cases: `02f` (live row fidelity, extending the spot-checks at
`:215-229`), `43d` (the whole `live` block verbatim, mirroring `43a`'s shape at `:730-747` — note
`43c` is already taken by `analyze`), and `56a-d` (alias `adhoc`; the `--ship chat` refusal; the
`--ship publish` warn-and-continue; `REWORK=2`). The suite's existing numbered cases end at `50`;
1.1 takes `51`–`54` and 2.1 takes `55`, so `56` is this subphase's first free number.

**Test oracle:** `new contract tests`.

### 3.2: Type table — flip `feature` and `migration` `against:` to `optional`   (lane 1, after: 3.1)

**File scope:** `orchestrators/skills/dae/workflows.yaml`, `tests/resolve-type.test.sh`.

**Pattern to follow:** the `bugfix` and `diagnose` rows, already `against: optional`
(`workflows.yaml:17,21`).

**What to build.** Change `against: forbid` → `against: optional` on the `feature` row (`:16`) and
the `migration` row (`:19`). Nothing else. Rationale (recorded in the header comment or the router
doc, which 3.7 owns): a Jira key is a first-class anchor kind, and a local-docs feature run
currently has no way to name its ticket — `resolve-type.sh` passes anchors through raw (`:25`,
`:528-533`) and `resolve-anchor.sh` resolves them, so nothing downstream changes.

**Why its own subphase:** a behavior flip on two shipped rows, independent of the `live` work,
separately reviewable and separately revertible.

**Acceptance criteria.**

- `feature -a PROJ-123` → exit 0, `AGAINST_COUNT=1`, `AGAINST_1=PROJ-123`.
- `migration --against abc123,def456` → exit 0, `AGAINST_COUNT=2`, order preserved.
- `feature` (no anchor) → exit 0, `AGAINST_COUNT=0` — optional, never required.
- `map -a abc123` → still exit 1, so the `forbid` path is unbroken.
- `rework` (no anchor) → still exit 1, so the `require` path is unbroken.

**Test approach.** **This subphase breaks an existing case and must repair it:** case `30` at
`:587-590` uses `run feature -a abc123` as its `against: forbid` → E4 fixture; `feature` is no
longer forbid. Repoint case 30 at a row that is still `forbid` (`map`, `analyze`, or `document`)
and keep asserting the same three substrings. Then extend case 32's optional family (`:600-609`)
with `32e/32f` for `feature` and `32g/32h` for `migration`, mirroring `32a-32d`. Re-check the
anchor-conditional idiom at `:196-198` and `:463-465` (both
`case "$t" in rework|sync) run "$t" --against REF`) — it still holds, since only `require` rows
need an anchor and neither flipped row is `require`. Case 34's loop at `:631-635` is NOT the same
idiom and needs no change: it iterates build types only, so its case statement is `rework)` alone
with no `sync` branch.

**Test oracle:** `new contract tests`.

### 3.3: `live.md` — the new middle file   (lane 4)

**File scope:** `orchestrators/skills/dae/live.md` (new file).

**Pattern to follow:** `build.md` (stage list + `## Notes`) and `report.md` (how a middle file
branches on resolved AXIS values and references shared stages instead of restating them). Read both
before writing. Length target: comparable to `report.md`, not longer.

**What to build.** A middle file titled `# live — the conversational increment workflow
(--type live, alias adhoc)`. Its distinguishing property, stated in the opening paragraph: this is
`build.md`'s loop with the auto-mode switch INVERTED. `build.md:13` ends the plan gate with "THEN
switch to auto mode and dispatch"; `live.md` never switches — the router stays conversational for
the whole build, because the user's next message is a first-class event source.

**Stages.**

1. **Setup** (shared — router; reference, never restate). Branch type `feature/` from the resolved
   row. Use the CURRENT setup wording: `CLAUDE_DOCS_DIR` resolves to a local path and
   `document-local` records, always; `CLAUDE_DOCS_PUBLISH` is resolved separately and, when set,
   `confluence-mode.md` captures requirements before exploring (`SKILL.md:110`). **The worktree
   scheme is the standard one** — the router's parent worktree per `worktree-modes.md`, with each
   builder lane's child cut off it per `build-dispatch.md`. Live introduces no worktree-mode
   special case and this file must not mention one. `ship: chat` is unreachable — the row is fixed
   to `publish` (3.1).
2. **Capture the ask, then plan.** **Every ask is written to a durable file BEFORE the planner is
   messaged:** `<run-dir>/asks/<n>.md`, numbered from 1 in arrival order, holding the user's words
   verbatim. This is not bookkeeping — it is what makes the run's ask-of-record real: a live plan
   has no single up-front brief, so the `asks/` DIRECTORY is what its plan's ask-of-record pointer
   names, and `review-plan`'s ask-vs-plan diff (`review-plan/SKILL.md:33`) reads the numbered file
   for the phase under review. An ask that reaches the planner only through conversation context is
   unauditable and is a defect in this loop.
   Then spawn the warm `planner` with module `plan-live`, the ask FILE path, the parent worktree
   path, and the resolved axes. It writes `Phase 1` with `1.1..1.k` subphases annotated `(lane 1)`
   to `<plans-dir>/proposals/<slug>-MM-DD-YY.md`. Run `validate-plan.sh` ALWAYS — it ships inside
   the `review-plan` skill at `<review-plan skill dir>/scripts/validate-plan.sh`, not as an
   installed hook. Invoke `review-plan` ONLY when `RIGOR_PLAN` is `med` or `high`; at `low` the
   plan goes straight to the user for approval. Then `plan-lifecycle.sh promote`, then the shared
   **Open the draft PR** step. `init-workspace` runs in parallel, joined before dispatch.
3. **The conversational loop.** Two event sources, interleaved, and the router waits on both:
   - **A user ask** → write `<run-dir>/asks/<n>.md` → SendMessage the warm planner with that path.
     It appends exactly ONE `Phase N` with `N.1..N.k` subphases annotated `(lane N)` to the SAME
     plan file; re-run `validate-plan.sh`; re-gate through `review-plan` only at plan rigor med+;
     then dispatch lane N per `build-dispatch.md`. **One ask = one phase = one lane.** No
     decomposing an ask across lanes, and no adding work to a lane already in flight.
   - **Concurrent asks** produce concurrent lanes. Where a new phase's file scope overlaps an
     unfinished phase's, the planner adds an `(after:)` edge so the two serialize automatically;
     the router does not adjudicate overlap itself.
   - **A builder report** → the per-lane merge sequence below.
4. **Per-lane merge.** `verify-scope.sh` against the exit report's file list → merge the child
   branch into the parent → `mark-syllabus.sh` per subphase → SendMessage the planner to annotate
   that phase's detail blocks with what actually shipped → `push-pr --stage update` (no
   conversational confirmation, per D1) → lane cleanup branching on the push outcome. All of that
   is `build-dispatch.md`'s, referenced not restated; the ONE addition is the last step, an
   **offer** — dismissable, never a stage, and a declined or ignored offer changes nothing about
   the run:
   - open the parent in the user's editor (`$VISUAL`, else `code <path>`) — offered
     unconditionally;
   - run the app via the `run` skill **if it is available in the session** — this repo does not
     ship a `run` skill, so it is named as an optional convenience and never as a dependency
     (settled decision D6).
5. **Ship** — entered when the user says so, never inferred. Integration pass in the parent (the
   full suite plus the plan's cross-lane acceptance criteria, plus
   `verify-run-scope.sh <parent-worktree> <base> <run-dir>`) → ask "pre-PR code review?",
   **defaulting to no at `RIGOR_CODE=low` and to yes at med or high**; on yes, invoke `review-code`
   with the plan path and the build summary → Record (shared — router) → `push-pr --stage update` →
   the router's PR gate → `push-pr --stage finalize`.

**Notes** (the section that carries the design decisions).

- **There is no code-gate STAGE.** `review-code` is an opt-in step at ship, not a gate the run must
  pass. The **PR gate is mandatory and unskippable** — `SKILL.md:116` admits no exception and no
  type row may route around it.
- **The PR gate's skeptical profile for live.** Live hands `review-pr` a severity profile (3.4)
  that says: *plan deviations are open questions, never blocking findings* — a live plan is a
  running transcript of what was asked, so divergence between it and the diff is the normal shape
  of the run, not a defect. Blocking is reserved for real bugs, convention and major-version
  violations, cross-lane duplication, failing automated checks, and `verify-run-scope.sh` UNCLAIMED
  lines. **`plan-wrong` is never a valid `next` on a live run** — a live plan cannot be "wrong" in
  the sense the kickback means, since it is amended in place at every ask; the reachable rejection
  codes are `impl-wrong` and `needs-input`. `review-pr` already leans this way — its step-3 clause
  on syllabus items that **diverged** (its word, `review-pr/SKILL.md:34`; the file never says
  "deviation") calls them "findings" without mandating a severity, and its notes at `:64` warn
  against inflating non-blocking notes into blocking ones. Be precise about what that does and does
  not buy: nothing in `review-pr` today says divergence DEFAULTS to non-blocking, so the profile is
  a genuine severity override for that one category — narrowly scoped and demote-only (3.4), but a
  real change in behavior, not a passive continuation of it.
- **The plan is the transcript.** It grows monotonically; earlier phases are annotated, never
  rewritten. `plan-live.md` owns that discipline — point at it, do not restate it.
- Every branch in this file keys on a resolved AXIS value (`RIGOR_PLAN`, `RIGOR_CODE`, `SHIP`,
  `REWORK`), never on the type name.
- If an ask turns out to need a real up-front design pass, say so and recommend a `feature` run —
  the mirror of `report.md:47`'s note.

**Acceptance criteria.** The file exists at `orchestrators/skills/dae/live.md`, is self-contained,
and describes stages 1–5 in order. It restates no shared-stage mechanics (Setup, Open the draft PR,
Ship, the PR gate, the confirmation cadence) — each is referenced by name. It contains no branch on
`TYPE`. **It contains no mention of `--worktree` or `-w` in any mode**, `none` included — live uses
the standard scheme and says so by referencing `worktree-modes.md`, not by discussing modes. It
never describes the directory tree. The `asks/<n>.md` capture is stated as happening BEFORE the
planner is messaged, not after. Every claim it makes about another file is citable to that file as
it stands at the end of this run.

**Test approach.** No automated test covers middle-file prose. Read-through against `SKILL.md`'s
shared-stage bullets (`:106-117`), `build-dispatch.md`, `review-plan/SKILL.md:33` (the ask-vs-plan
gate step the `asks/` files feed), and `review-pr/SKILL.md` as amended by 3.4 — confirming every
reference resolves and nothing is restated. Plus `grep -niE '\-\-worktree|[^a-z]-w |none mode'` over
the new file, which must return nothing.

**Test oracle:** `existing suite`.

### 3.4: `review-pr` — a caller-supplied severity profile input   (lane 4, after: 3.3)

**File scope:** `agent-agnostic/skills/review-pr/SKILL.md`.

**Pattern to follow:** the `## Inputs` section (currently a closed list of three — Target, Spec,
Report path) and the `## Rigor` block, which shows how a caller-side dial reaches this skill
without the skill branching on a run type. **Read the current file before editing** and confirm
every line number.

**What to build.** Add a FOURTH, optional input — a **severity profile** — expressed generically,
never as "live":

- **What it is:** an optional, caller-supplied statement of which finding categories this run
  treats as non-blocking, and which `next` codes are unreachable for it. Absent = the file's
  default policy, unchanged.
- **What it may and may not do:** it may DEMOTE a category to non-blocking or to
  `### Open questions`, and it may narrow the reachable `next` set. It may never promote something
  to blocking that the file does not already treat as blocking, and it may never suppress a finding
  entirely — a demoted finding is still written to the report, just not as `blocking`. This
  asymmetry is the whole safety property: a profile can make a gate less noisy, never less honest.
- **What it can never touch:** the categories this file already mandates as BLOCKING —
  `verify-run-scope.sh` UNCLAIMED lines, a documentation claim contradicting source, and reuse
  violations where the project's conventions mandate reuse — plus `report-verdict.sh`'s enforced
  verdict/`next` grammar. State that a profile asking for any of these is REFUSED, not honored, and
  reported as such.
- **Record it in the report round.** The round must say which profile was applied, so a reader can
  tell a quiet gate from a lenient one.

**Acceptance criteria.** `## Inputs` lists four items, the fourth marked optional with "absent =
the default policy". The demote-only asymmetry is stated explicitly. The mandated-blocking
categories are named as un-overridable. The word "live" appears nowhere in the file, and no
sentence branches on a run type — a reader cannot tell from this file which type introduced the
feature. The existing anti-inflation note and open-questions rule are left intact and are
consistent with the new text.

**Test approach.** Read-through against `report-verdict.sh` (the verdict grammar the profile must
not break), against `verify-run-scope.sh:165`'s `UNCLAIMED:` contract, and against `live.md`'s
Notes section (3.3) — the profile `live.md` describes handing over must be expressible under the
rules this subphase writes, with no gap and no extra permission.

**Test oracle:** `existing suite`.

### 3.5: `plan-live.md` — the new planner module   (lane 3)

**File scope:** `orchestrators/agents/planner/plan-live.md` (new file).

**Pattern to follow:** `plan-feature.md` (8 lines) and `plan-bugfix.md` (9 lines) — every module is
"type-specific guidance only; every invariant lives in the planner definition", four to six tight
bullets. Read `plan-feature.md`, `plan-bugfix.md`, and `plan-rework.md` before writing and match
their register exactly. Do not write a long file.

**What to build.** Bullets, in this order:

- **One ask = one phase = one lane.** Each user ask appends exactly one `Phase N` with subphases
  `N.1..N.k`, every one annotated `(lane N)` — the lane number IS the phase number, which makes
  lane ids collision-free across an unbounded run and keeps `build-dispatch.md:7`'s "the lane id
  `l<n>` comes straight from the plan's lane number" true without a mapping.
- **Cite the ask file.** Each phase's detail blocks name the `<run-dir>/asks/<n>.md` file that ask
  came from. The plan's ask-of-record pointer names the `asks/` DIRECTORY (`plan-format`'s Form P),
  and the per-phase citation is what lets `review-plan`'s ask-vs-plan diff line one phase up
  against one ask instead of the whole run against the whole transcript.
- **Append-only.** Never rewrite or renumber an earlier phase. New subphase detail blocks are
  appended BELOW the syllabus section's terminating `## ` boundary. This is not style — it is what
  `validate-plan.sh` requires: the syllabus must remain the FIRST `## ` section
  (`validate-plan.sh:44-52`), detail-block IDs are harvested only from outside the syllabus block,
  and an ID appearing in a SECOND detail block is a FAIL. **Verified:** the script has no
  contiguity, ordering, or start-at-1 check anywhere, so a plan that grows phase-by-phase passes
  exactly as a whole-cloth plan does.
- **Never write an `(after:)` edge to an ID that does not exist yet** — `validate-plan.sh` fails on
  a nonexistent target, and it parses `(after:)` only from syllabus checkbox lines, so an edge
  written only in a detail block is silently ignored.
- **Serialize on file-scope overlap.** Before appending a phase, compare its file scope against
  every UNFINISHED phase's. On overlap, add `(after: <the last subphase of the overlapping phase>)`
  so the lanes serialize; that is what keeps the disjointness invariant true when lanes are created
  one at a time and cannot be re-planned together.
- **Ask, don't assume.** The router is conversational during a live run and you are warm, so a
  clarifying question costs one message. When an ask is ambiguous about scope, target file, or
  acceptance, ASK rather than inferring — this module deliberately trades the usual
  assumption-and-flag posture for a question.
- **Explore only as far as the increment needs.** Optimize for correctness of THIS increment and
  for short ask-to-builder time: read the specific files the subphases will name (rung 3 of the
  planner's ladder — always), and climb to a fan-out or the `explore` fork only when the ask
  genuinely reaches unmapped territory. Do not re-explore what an earlier phase in this same run
  already established; cite it instead.
- **Test oracle default: `new contract tests`.** A small increment the existing suite already
  covers may declare `existing suite` instead.
- **Annotation duty.** When the router reports a merged lane, amend that phase's detail blocks with
  what actually shipped. The syllabus ticks are the router's, through `mark-syllabus.sh` — never
  yours.
- **The plan's required sections are written ONCE, with Phase 1**, and updated in place thereafter:
  Goal & scope grows a line per ask; Stack & MAJOR versions is pinned at the first ask and
  re-verified only when an ask reaches a new part of the stack.

**Acceptance criteria.** The file exists at `orchestrators/agents/planner/plan-live.md`, opens with
the same "Type-specific guidance only; every invariant lives in the planner definition" line its
siblings use, and contains only type-specific guidance — it restates no planner invariant. Every
claim it makes about `validate-plan.sh` is true of the script as it stands. A plan built by
following it passes `validate-plan.sh` after EVERY append, not only at the end — including the
ask-of-record check, which the `asks/` pointer satisfies.

**Test approach.** Construct a throwaway three-phase plan by hand following the module's rules —
append Phase 1 with an `asks/` ask-of-record pointer, validate; append Phase 2 with a cross-phase
`(after:)`, validate; append Phase 3, validate — and confirm
`bash agent-agnostic/skills/review-plan/scripts/validate-plan.sh <file>` prints
`OK: plan is structurally valid (<n> subphases)` and exits 0 at each step. Delete the throwaway; it
is not an artifact of this run.

**Test oracle:** `existing suite` (`validate-plan.sh` is the oracle; `tests/validate-plan.test.sh`
pins its behavior and must stay green).

### 3.6: `planner.md` — declared type list and module roster   (lane 3, after: 1.4, 3.5)

**File scope:** `orchestrators/agents/planner.md`.

**Pattern to follow:** the frontmatter `description` at `:3` and the `## Type module` section at
`:19-21`.

**What to build.**

1. Frontmatter `description` (`:3`): the declared type list becomes
   `feature|bugfix|rework|migration|live|diagnosis|reconcile`. This is the list a caller reads to
   know what may be passed, so it must be complete.
2. `## Type module` (`:21`): no change is required by the module-loading rule itself, but re-read
   it and confirm `plan-live.md` is reachable by the stated rule (`plan-<type>.md` alongside the
   definition) — it is, since the type is `live` and the module is `plan-live`.
3. Nothing else changes. In particular the invariants block at `:9-18` is untouched: `plan-live` is
   a module, and modules never override invariants.

**Acceptance criteria.** The frontmatter type list names `live` in the canonical position (between
`migration` and `diagnosis`, matching `workflows.yaml` row order). No other line changed. The
file's own rule for locating a module resolves `live` → `plan-live.md` without a special case.

**Test approach.** Read-through; confirm the module file 3.5 created is named exactly what this rule
derives.

**Test oracle:** `existing suite`.

### 3.7: Router doc — type table row, seam row, eleven types, disambiguation   (lane 2, after: 2.2)

**File scope:** `orchestrators/skills/dae/SKILL.md`.

**Pattern to follow:** the type-selection table at `:53-64` and its following bullet list at
`:66-69`; the seam-loading table at `:89-102`.

**What to build.**

1. **`:51`:** "Ten types" → "Eleven types".
2. **Type table (`:53-64`):** add the `live` row — `` `live` (alias `adhoc`) `` | `live` |
   `live.md` | `plan-live` | `feature/` | optional | publish. Place it after `rework` and before
   `diagnose`, matching `workflows.yaml` row order.
3. **`against` column corrections:** `feature` (`:55`) and `migration` (`:58`) become `optional`
   (3.2). Add a bullet to the `:66-69` list recording WHY: a Jira key is a first-class anchor kind,
   and a local-docs feature run had no way to name its ticket. A behavior change on two shipped
   rows must be visible, not silent.
4. **`:19`:** add `live.md` to the middle-file list. Leave "five axes" alone — `live` adds a
   `pipeline` VALUE, not a sixth axis, and rework is a dial (1.2).
5. **Seam table (`:89-102`):** add `| pipeline: live | live.md |` immediately after the
   `pipeline: build` row (`:92`).
6. **A disambiguation bullet** in the `:66-69` list, in the voice of `:71`'s "bugfix vs diagnose":
   **feature vs live.** `feature` = the shape of the work is knowable up front — plan it whole,
   gate it once, build it in auto mode. `live` = the shape emerges ask by ask — the router stays in
   conversation, each ask becomes one phase and one lane, and the run ships when the user says
   ship. "Let's start with X and see" is `live`; a described outcome is `feature`.
7. **`:66`'s note** — "`pipeline: plan` resolves to `diagnose.md` or `sync.md` by PLANNER MODULE…
   two files until a third plan-pipeline type appears" — is untouched and must stay untouched:
   `live` is its own pipeline, not a third `plan`-pipeline type.
8. **`:104`'s "Three observable consequences"** — re-read and confirm all three still hold with
   `live` present. They do; add a fourth only if the read-through finds a genuine gap, not for
   symmetry.
9. **Frontmatter `description` (`:3`):** add the live case ("an ad-hoc conversational build") to the
   prose enumeration of what `/dae` handles.

**Acceptance criteria.** The type table has eleven rows whose every cell matches `workflows.yaml` as
pinned in Conventions — pipeline, middle file, planner module, branch prefix, `against` rule, ship
column, for all eleven. The seam table names `live.md`. The `feature`/`migration` `against` flip is
both in the table and explained in the bullet list. The feature-vs-live bullet exists. No sentence
describes `live` as a `plan`-pipeline type or as a sixth axis.

**Test approach.** Cell-by-cell diff of the type table against `workflows.yaml` as this plan pins it
in Conventions (a manual two-column read), plus a read-through of the seam table against `live.md`'s
actual references. Run `resolve-type.sh live` and `resolve-type.sh feature` and compare against what
a reader of this file would predict — and if lane 1 has not landed yet, that comparison is against
the pinned blocks, not a blocker: lane 2 carries no `(after:)` edge to lane 1 by design (see 1.2's
test approach), and 5.5 is where cross-file agreement is enforced.

**Test oracle:** `existing suite`.

---

## Phase 4 — Orchestrator write-scope enforcement

Lane 6, dispatched once lane 1 has merged (`after: 3.2`). The edge is deliberate and not a file
conflict — lane 6's scope is disjoint from every other lane's. These hooks constrain the
ORCHESTRATOR's own writes, and landing them while other lanes are mid-flight would change the rules
underneath a running dispatch loop. Land them when the schedule is quiet.

### 4.1: `scope-writes.sh` — self-configuring, no env var   (lane 6, after: 3.2)

**File scope:** `orchestrators/hooks/scope-writes.sh`.

**Pattern to follow:** the file's own JSON extraction (`:43-55`) — `grep -oE` + `sed -E` on the hook
payload, no jq, matching `resolve-config.sh`'s style — and its prefix-containment test (`:64`). Both
survive the rewrite; only the source of the allowlist changes. For resolving the two configured
dirs, follow how any hook calls the resolver: `resolve-config.sh CLAUDE_PROJECT_PLANS_DIR` and
`CLAUDE_DOCS_DIR`, as `verify-run-scope.sh:106` already does for the plans dir.

**What to build.** Replace the `CLAUDE_SCOPE_ALLOW` mechanism (`:36-37`) with self-configuration
from the target path:

1. **Keep the tool gate and path extraction as they are** (`:45-56`), including the Antigravity tool
   aliases — this rewrite changes WHERE the allowlist comes from, not what counts as a write.
2. **Find the run's parent worktree by marker.** From the target path, walk up ancestor directories
   looking for one that contains `.artifacts/progress-log.md`. That file is the run dir's live-state
   file and exists only in a run's PARENT worktree (`run-artifacts`: the run dir belongs to the
   parent, and "a builder's child worktree never gets its own"). Stop at the filesystem root.
3. **No ancestor has the marker → exit 0, inert.** This is what keeps every other context working:
   a builder's child worktree has no progress log, so coders and contract-testers are untouched, and
   so is an ordinary checkout. Hooks fire for subagents too, so an unconditional deny here would
   block every coder on the project — the marker is what makes the hook safe to wire globally.
4. **An ancestor has the marker → allow only three roots:** that worktree's own `.artifacts/`, the
   resolved plans dir, and the resolved docs dir. Resolve the latter two with
   `resolve-config.sh CLAUDE_PROJECT_PLANS_DIR --default /project-plans/` and
   `resolve-config.sh CLAUDE_DOCS_DIR --default /docs --expect path`, rooted at the marked worktree
   (`--root`), so a repo-relative configuration resolves against the right tree. Reuse the existing
   `realpath -m` + prefix test at `:57-67`.
5. **Anything else → exit 2**, with stderr naming the rule, the offending path, and the three
   allowed roots, in the voice of the current message at `:69`: the orchestrator delegates building;
   dispatch a lane or report the scope gap rather than working around it.
6. **Rewrite the header block.** The SYNOPSIS's env var goes; the "BUILDER LANE SCOPE (documented,
   NOT wired)" section (`:21-25`) goes with it — that configuration cannot exist without the env
   var. **Replace `:28-29`'s backstop claim outright:** "the worktree + branch isolation is the
   backstop" is true for a builder and false for the orchestrator, which sits in the parent worktree
   with the whole product tree. Say that plainly and name `parent-tree-guard.sh` (4.2) as the actual
   Bash-side backstop. Per the repo's "no old code alongside new" standard, delete the stale text;
   do not leave it hedged.

**Acceptance criteria.**

- A `Write` to `<parent-worktree>/orchestrators/hooks/foo.sh` → exit 2, stderr names the rule and
  the path.
- A `Write` to `<parent-worktree>/.artifacts/progress-log.md` → exit 0.
- A `Write` to a file under the resolved plans dir → exit 0. Same for the resolved docs dir.
- A `Write` to a path inside a CHILD worktree (no `.artifacts/progress-log.md` at its root, and none
  in any ancestor) → exit 0. This is the case that keeps coders working, and it must be tested
  against a real directory layout, not asserted.
- A `Write` anywhere in a plain checkout with no run dir → exit 0.
- A non-write tool (`Read`, `Bash`, `Grep`) → exit 0 regardless of path.
- Malformed or empty stdin → exit 0, never a crash and never a spurious deny.
- `CLAUDE_SCOPE_ALLOW` is referenced nowhere in the file.
- `bash -n orchestrators/hooks/scope-writes.sh` exits 0.

**Test approach.** The suite is authored in 4.5, blind from this lane's contract, exercising the
criteria above against throwaway `mktemp -d` trees that mimic a parent worktree, a child worktree,
and a bare checkout. Do not hand-verify by writing to this repo's own tree — that is the behavior
the hook exists to stop.

**Test oracle:** `new contract tests` (authored in 4.5).

### 4.2: `parent-tree-guard.sh` — new hook, checks the artifact not the command   (lane 6, after: 4.1)

**File scope:** `orchestrators/hooks/parent-tree-guard.sh` (new file).

**Pattern to follow:** an existing hook of the same shape for its header/exit-code conventions and
its stdin handling — `scope-writes.sh` as 4.1 leaves it is the closest sibling, and shares the
parent-worktree marker walk. `workflow-diff-check.sh` is the existing precedent for a hook that
inspects the worktree's git state rather than the tool call.

**Why a second hook.** 4.1 intercepts the Write/Edit tools. It cannot see inside a Bash command —
`sed -i`, a `>` redirect, a heredoc, `tee`, `python -c` — and a PreToolUse hook never can. This hook
closes that hole by checking the ARTIFACT instead of the command: after Bash has run, look at what
actually changed on disk. That makes it indifferent to how the write was phrased, which is the
property the command-matching approach can never have.

**What to build.**

1. **Determine the cwd:** read `cwd` from the hook JSON on stdin using the same extraction idiom
   `scope-writes.sh:43-55` uses; fall back to `$PWD` when absent or unparseable.
2. **Same marker walk as 4.1:** walk up from the cwd for an ancestor containing
   `.artifacts/progress-log.md`. No marker → exit 0, inert. Keep this logic identical in behavior to
   4.1's — if the two ever disagree about what a parent worktree is, one of them is wrong.
3. **Inspect the tree:** run `git -C <marked-worktree> status --porcelain`. Consider every reported
   path — modified, added, deleted, renamed, AND untracked. Untracked counts: a new product file the
   orchestrator created is exactly the case this catches.
4. **Classify:** any reported path outside the resolved plans dir and the resolved docs dir is a
   product change. None → exit 0.
5. **Any product change → exit 2**, stderr naming the offending paths and saying: a product file
   changed in the run's parent worktree; the orchestrator is not a builder; revert it and dispatch a
   lane. Name the paths — a guard that says "something changed" without saying what forces a hunt.
6. **Wiring shape it must tolerate** (4.3 does the wiring): `PostToolUse` on `Bash` and `Stop`. It
   must therefore be safe to run often and on both payload shapes, and cheap — one `git status` in
   one directory.

**Acceptance criteria.**

- Clean parent worktree → exit 0.
- Parent worktree with a modified product file (e.g. `orchestrators/skills/dae/SKILL.md`) → exit 2,
  stderr names that path.
- Parent worktree with an UNTRACKED product file → exit 2, stderr names it.
- Parent worktree with a modified file under the resolved plans dir → exit 0.
- Parent worktree with a modified file under the resolved docs dir → exit 0.
- Parent worktree dirty ONLY under `.artifacts/` → exit 0 (it is gitignored, so `--porcelain`
  reports nothing; assert the observable outcome, not the reasoning).
- cwd in a child worktree, or in a plain checkout, or outside any repo → exit 0.
- Missing/empty stdin → falls back to `$PWD` and still behaves per the rules above.
- `bash -n orchestrators/hooks/parent-tree-guard.sh` exits 0.

**Test approach.** Authored in 4.5 against throwaway `git init` repos built by the test, so the
dirty/clean states are constructed rather than borrowed from the developer's tree.

**Test oracle:** `new contract tests` (authored in 4.5).

### 4.3: Wire both in `settings.json`; confirm the sync-install mapping   (lane 6, after: 4.2)

**File scope:** `agent-specific/claude/settings.json`. (`orchestrators/hooks/sync-install.sh` is
READ here, never edited — see step 3.)

**Pattern to follow:** the file's existing `hooks` block (`:111-187`) — every entry is
`{"type": "command", "command": "~/.claude/hooks/<file>"}`, referring to the INSTALL path, not the
repo path, since these run from the install.

**What to build.**

1. **`PreToolUse`, matcher `Write|Edit|MultiEdit|NotebookEdit` (`:147-155`)** — add
   `~/.claude/hooks/scope-writes.sh` to the existing `hooks` array, beside `branch-squash-guard.sh`
   (`:152`). This matcher block already exists; do not create a second one for the same matcher.
2. **`PostToolUse`** (`:157-175`) — add a new matcher block for `Bash` whose single hook is
   `~/.claude/hooks/parent-tree-guard.sh`. The existing `Write|Edit|MultiEdit` block (`:159-174`,
   lint/test/drift) is untouched.
3. **`Stop`** (`:176-186`) — add `~/.claude/hooks/parent-tree-guard.sh` to the existing block's
   `hooks` array, beside `ntfy-notifier.sh` (`:182`).
4. **Confirm the sync-install mapping covers the new hook — read-only.** `sync-install.sh:128` maps
   `orchestrators/hooks/*` → `hooks/<file>`, and `:151` resolves the reverse. A new file under
   `orchestrators/hooks/` is therefore covered with **no change to `sync-install.sh`**, and its
   header at `:14` documents exactly this rule. Verify by reading those lines and record the
   evidence; if the mapping did NOT cover it, that is a blocker to surface, not a script edit to
   make from this lane.
5. **Settings sync is a MERGE, not a copy** (`.claude/rules/source-push-sync.md`): a key the source
   defines wins, a key only the install has is preserved, and `permissions.allow` is unioned.
   `hooks` is a key this source defines, so adding to it propagates on the next sync. Do not touch
   `permissions`, and do not add a `model` key.

**Acceptance criteria.**

- `python3 -c 'import json;json.load(open("agent-specific/claude/settings.json"))'` exits 0 — the
  file is still valid JSON.
- The `Write|Edit|MultiEdit|NotebookEdit` PreToolUse block lists both `branch-squash-guard.sh` and
  `scope-writes.sh`; there is exactly ONE block with that matcher.
- A `PostToolUse` block with matcher `Bash` lists `parent-tree-guard.sh`; the existing
  `Write|Edit|MultiEdit` PostToolUse block is unchanged.
- The `Stop` block lists both `ntfy-notifier.sh` and `parent-tree-guard.sh`.
- Every added command path is `~/.claude/hooks/<file>` — the install path, matching its siblings.
- `permissions` is byte-identical to its pre-change state (`git diff` shows changes inside `hooks`
  only).
- The sync-install mapping check is recorded with the two line citations, and `sync-install.sh` is
  unmodified.

**Test approach.** JSON validity is the one mechanical check; the rest is a structural read of the
block against the criteria above. The hooks' BEHAVIOR is 4.5's job — this subphase only proves they
are wired in the right places with the right matchers. Do not run a real `sync-install.sh` — landing
and syncing is `push-main`'s job after the merge.

**Test oracle:** `existing suite`.

### 4.4: `verify-scope.sh` — a dirty child worktree FAILS, diff is committed-only   (lane 6, after: 4.3)

**File scope:** `orchestrators/hooks/verify-scope.sh`.

**Pattern to follow:** the script's own `err()` + `exit 1` convention (`:34`) and its
`UNREPORTED:`/`UNCHANGED:` line-per-finding output (`:127`, `:132`), which the caller already parses.
The new finding is a third line kind in the same shape.

**The regression this closes.** Lane l4's builder on this very run returned `status: success` with
its two files UNCOMMITTED in the child worktree. `verify-scope.sh` reported OK, and the
`git merge <child-branch>` that followed merged **nothing** — silently, with a clean exit. The router
only noticed because `git worktree remove` later refused. The cause is at `:119-122`, where "the
lane's diff" is computed as a four-way union:

```
git -C "$wt" diff --name-only "$parent"...HEAD        # :119  committed
git -C "$wt" diff --name-only HEAD                    # :120  unstaged
git -C "$wt" diff --name-only --cached                # :121  staged
git -C "$wt" ls-files --others --exclude-standard     # :122  untracked
```

Lines `:120-122` are what make uncommitted work look like delivered work. The docstring states the
behavior plainly at `:11-13` ("committed, staged, and untracked"), so this is a design error, not a
coding slip: the check answers "did the builder touch what it said it touched?" when the caller also
needs "is the work actually ON the branch I am about to merge?"

**What to build.**

1. **Add a cleanliness gate BEFORE the comparison.** Run `git -C "$wt" status --porcelain` and treat
   ANY reported entry — modified, staged, deleted, renamed, or untracked — as a failure, EXCEPT
   paths under `.artifacts/`. Emit one `UNCOMMITTED: <path>` line per offending path, in the same
   one-finding-per-line shape as `:127`, and fail.
2. **Then compare against the COMMITTED range only.** Reduce `:119-122` to the single
   `git diff --name-only "$parent"...HEAD` at `:119`; delete `:120-122`. Once the gate above passes,
   the working tree is clean, so those three commands can only ever return empty — keeping them
   would be dead code that silently re-opens the hole if the gate is ever bypassed. Per the repo's
   "no old code alongside new" standard, remove them.
3. **Exit code: 1**, the same as UNREPORTED — the caller's contract is "non-zero means do not
   merge", and splitting the failure kinds by exit code would force every caller to learn a new
   vocabulary for no gain. Distinguish them by the output LINE, which is how UNREPORTED and
   UNCHANGED are already distinguished.
4. **Order matters:** report UNCOMMITTED and stop before the reported-vs-diff comparison. A dirty
   worktree makes that comparison meaningless — every uncommitted file would also surface as
   UNCHANGED noise — and the operator needs one clear instruction, not two contradictory ones.
5. **Update the header block.** `:11-13`'s "committed, staged, and untracked" becomes "committed
   only, after refusing a dirty worktree"; add `UNCOMMITTED: <file>` to the findings list at
   `:14-15`; extend EXIT CODES (`:29-31`) to name the new failure under exit 1.
6. **Do not touch `claims_from_report()`** (`:36-86`) or the `--report` input mode (`:93-116`). They
   are a separate concern with their own suite, and `tests/verify-scope-parsing.test.sh` pins them.

**Acceptance criteria.**

- Child worktree with all lane work COMMITTED and a matching report → `OK: reported files match the
  lane diff (N changed)`, exit 0, exactly as today.
- Child worktree with a MODIFIED tracked product file → exit 1, stdout carries
  `UNCOMMITTED: <path>`, and no `OK:` line.
- Child worktree with a STAGED-but-uncommitted change → exit 1 with `UNCOMMITTED: <path>`.
- Child worktree with an UNTRACKED new file → exit 1 with `UNCOMMITTED: <path>`.
- Child worktree dirty ONLY under `.artifacts/` → the gate passes (that path is exempt).
- A file committed on the child branch but absent from the report still reports `UNREPORTED:` and
  exit 1 — the existing behavior is unchanged for clean worktrees.
- A file reported but not in the committed range still reports `UNCHANGED:` as a warning and does
  not by itself fail.
- `--report <exit-report>` mode behaves identically to argv mode with respect to the new gate.
- `bash -n orchestrators/hooks/verify-scope.sh` exits 0.

**Test approach.** Authored in 4.5 as `tests/verify-scope-clean.test.sh` — a NEW suite, not an
extension of `tests/verify-scope-parsing.test.sh`, whose stated scope is the shared
`claims_from_report` parser (`tests/verify-scope-parsing.test.sh:7-14`). Cleanliness of the worktree
is a different concern from report parsing, and merging them would blur a suite that currently has a
crisp identity. Fixtures are throwaway `git init` worktrees with deliberately constructed dirty and
clean states.

**Test oracle:** `new contract tests` (authored in 4.5).

### 4.5: Contract tests for all three scripts, positive and negative   (lane 6, after: 4.4)

**File scope:** `tests/scope-writes.test.sh` (new), `tests/parent-tree-guard.test.sh` (new),
`tests/verify-scope-clean.test.sh` (new).

**Pattern to follow:** `tests/workflow-setup-reuse.test.sh` — the closest existing sibling, because
it builds throwaway `git init` repos in `mktemp -d` and pins `HOME` to an empty dir so nothing
leaks from the developer's environment. Take the bookkeeping shape from any suite: `TOTAL_PASS` /
`TOTAL_FAIL`, `pass`/`fail` helpers, a `cleanup` trap over the scratch dirs, and a
`N passed, N failed` summary with exit 1 on any failure (`tests/resolve-type.test.sh:50-80`).
Assertions must be on OUTPUT CONTENT and EXIT CODE together, never exit code alone.

**What to build.** Three suites, each covering the positive AND negative cases its subphase's
acceptance criteria list — the criteria in 4.1, 4.2 and 4.4 are the contract, and this subphase makes
each one an executable case. The two hook suites must:

- **Construct their own fixtures.** A parent worktree is a directory containing
  `.artifacts/progress-log.md`; a child worktree is one without it; a plain checkout is a `git init`
  with neither. Build all three in `mktemp -d`, and never touch this repo's tree.
- **Feed the hooks realistic stdin** — the tool-call JSON shape the hooks parse, including the
  malformed and empty cases, so the inert-on-garbage behavior is pinned rather than assumed.
- **Assert the deny path names things.** A bare exit 2 is not enough: assert the stderr names the
  offending path, so a future refactor cannot degrade the message into an unactionable "denied".
- **Include the child-worktree case in both suites.** It is the single most important negative case
  in this phase: hooks fire for subagents, so a regression here blocks every coder on every project.
  It deserves an explicit, named case in each suite, not a shared helper's side effect.
- **Include one case per configured-dir root** (plans dir, docs dir) in each suite, resolved through
  `resolve-config.sh` rather than hardcoded, so the suites do not encode this repo's defaults.

`tests/verify-scope-clean.test.sh` covers 4.4's criteria against throwaway `git init` worktrees:
clean-and-committed passes with `OK:`; modified, staged, and untracked each fail with
`UNCOMMITTED: <path>`; an `.artifacts/`-only dirty tree passes; and the pre-existing `UNREPORTED:`
and `UNCHANGED:` behaviors still hold on a clean tree. That last group is the regression guard — the
fix must not cost the check its original job.

**Acceptance criteria.**

- All three files exist, are runnable as `bash tests/<name>.test.sh` from any working directory, and
  print `N passed, 0 failed` with exit 0.
- Every acceptance criterion listed in 4.1, 4.2 and 4.4 has at least one corresponding case.
- Each suite contains at least one ALLOW case and one DENY case (a suite that only tests denials
  cannot detect a hook that denies everything — this is the positive-control discipline
  `verify-dont-assume` requires, and it is why both directions are mandatory here).
- No suite writes anything outside its `mktemp -d` scratch dirs; all clean up on exit.
- The suite count is now **13**, which Phase 5 propagates to the docs.

**Test approach.** The suites ARE the test. Run each directly, and run the whole `tests/` directory
once to confirm nothing regressed — including `tests/verify-scope-parsing.test.sh`, which exercises
the same script 4.4 modifies and must stay green. Author them blind from this lane's contract, per
the repo's blind-test discipline (`tests/resolve-type.test.sh:12-35`) — the contract-tester writing
these must not read `scope-writes.sh`, `parent-tree-guard.sh`, or `verify-scope.sh`.

**Test oracle:** `new contract tests`.

---

## Phase 5 — Integration

### 5.1: Payload guides — `SKILL.md`, `orchestrators/AGENTS.md`, root `README.md`   (lane 5, after: 1.4, 3.2, 3.4, 3.6, 3.7, 4.5)

**File scope:** `orchestrators/skills/dae/SKILL.md`, `orchestrators/AGENTS.md`, `README.md`.

**Pattern to follow:** the entry-point table at `orchestrators/AGENTS.md:37-40`, the hooks paragraph
at `:96-`, the agents table at `:134-140` (header `:134-135`, five rows `:136-140`), and the
"Review rules for future types" section at `:149-172`.

**What to build.**

1. **`orchestrators/AGENTS.md:39`:** "ONE of ten types" → eleven, and add `live` (alias `adhoc`) to
   the enumeration in that cell.
2. **`orchestrators/AGENTS.md:86-92`** ("The other types swap the middle file" — the sentence runs
   to `:92`, ending "and the same files in `skills/dae/`"): add `live` with a one-clause
   description — conversational build, one phase per ask, ships on request.
3. **`orchestrators/AGENTS.md:136`:** the planner module roster
   `plan-{feature,bugfix,rework,migration,diagnosis,reconcile}.md` gains `live`.
4. **`orchestrators/AGENTS.md:96-`** (the hooks paragraph): `resolve-type.sh`'s summary is re-read
   for accuracy against 1.1, 2.1 and 3.1 — it gains the `REWORK` output and the per-row `ship`
   list. `workflow-setup.sh`'s summary is NOT touched (the `-w none` deferral).
5. **`README.md:49-51`:** the workflow enumeration is already stale (it omits `map` and `analyze`).
   Bring it current in one edit: the full eleven, or a shape that does not enumerate at all and
   points at `orchestrators/AGENTS.md`. **Prefer the pointer** — this sentence has now gone stale
   twice.
6. **`orchestrators/AGENTS.md:115-117`** (the `scope-writes.sh` clause of the "Wired hooks" list,
   whose "Wired hooks:" label sits one line earlier at `:114`) — `scope-writes.sh`'s entry
   currently reads "`PreToolUse` deny-outside-allowlist; live config = orchestrator scope; the
   builder-lane config was retired — worktree isolation replaced it". After Phase 4 that is wrong in
   every clause. Rewrite it: `scope-writes.sh` denies orchestrator writes outside the run's
   `.artifacts/`, the plans dir, and the docs dir, self-configured from the parent-worktree marker
   with no env var; and ADD `parent-tree-guard.sh` to the same list (`PostToolUse` on Bash and
   `Stop` — catches shell-side product writes in the parent worktree that a PreToolUse hook cannot
   see). Both are genuinely wired now, so they belong under "Wired hooks" rather than the
   "invoked, never wired" helpers sentence above it.
7. **`SKILL.md:143`** (the harness-scoped-writes invariant) — it currently hedges,
   "`scope-writes.sh` enforces this when wired; its allowlist is exactly those paths". Drop the
   hedge: the hook is wired, it self-configures, and its allowed roots are the run dir, the plans
   dir, and the docs dir. Name `parent-tree-guard.sh` as the Bash-side companion in the same
   sentence. Keep the rest of the bullet — the `verify-run-scope.sh` PR-gate audit and the
   "a stalled or dead lane is NEVER a license to do its work yourself" clause — intact; Phase 4 adds
   an earlier tripwire, it does not replace the gate.
8. **Do NOT touch `orchestrators/AGENTS.md:149-172`** (the four standing review rules). This change
   is held to them; it does not amend them.

**Acceptance criteria.** No "ten types" string survives in any of the three files. The planner
module roster is complete. The `README.md` enumeration is either complete or replaced by a pointer.
No sentence anywhere still says `scope-writes.sh` is unwired, conditionally wired, or
allowlist-configured, and `parent-tree-guard.sh` appears in the wired-hooks list. The four standing
review rules are byte-identical to their pre-change state. Nothing in any file describes a changed
`workflow-setup.sh`.

**Test approach.** `grep -rn "ten types\|Ten types"` over the three files returns nothing;
`grep -n "plan-{"` shows the complete roster; read-through against the final `workflows.yaml`;
`git diff` over `orchestrators/AGENTS.md:149-172` is empty. For the hook claims, read the two
rewritten sentences against `agent-specific/claude/settings.json` as 4.3 left it — the doc must
describe the wiring that is actually in the file, which is the failure mode this whole phase exists
to correct.

**Test oracle:** `existing suite`.

### 5.2: Meta-docs — `docs/pipeline.md`, `docs/architecture.md`, `docs/README.md`   (lane 5, after: 5.1)

**File scope:** `docs/pipeline.md`, `docs/architecture.md`, `docs/README.md`.

**Pattern to follow:** `docs/pipeline.md:3-4` — "Canonical guide: `orchestrators/AGENTS.md`. This
page is the meta-summary; edit pipeline behavior in the payload files, not here."

**What to build.**

1. **`docs/pipeline.md:57`:** "Ten types over four `pipeline`-axis values, resolving to five middle
   files" → eleven types, five pipeline values, six middle files. The parenthetical about
   `pipeline: plan` resolving by planner module stays.
2. **`docs/pipeline.md:61-`** (the type table): add a `live` row with its one-line loop description.
   **This table has NO `ship` column** — its columns are `--type` / `pipeline` axis / Middle file /
   Middle stages (`:61-62`), and it carries no `against` column either, so there are no ship or
   anchor cells to edit here. Ship behavior appears in this file only as prose, which item 3 below
   covers. Do not go looking for a cell that does not exist, and do not add a column.
3. **`docs/pipeline.md:81` — "`analyze` always publishes."** This is the SAME claim `SKILL.md:68`
   makes, which 2.2 step 9 rewrites; it lives in the prose paragraph under the type table
   (`:78-82`), not in any cell, which is why no other item here reaches it. After Phase 2 ships,
   `analyze --ship chat` is legal and this sentence is false. Rewrite it the same way 2.2 rewrites
   its twin: `analyze` DEFAULTS to publishing and `map` DEFAULTS to chat, and either can be pushed
   to the other mode with `--ship`. Keep the surrounding `map` sentence's substance — `map`'s
   zero-gate, no-worktree chat default is still accurate as its default.
4. **`docs/pipeline.md`'s ASCII flow diagram:** add the live branch, or — if it cannot be drawn
   without doubling the diagram's size — add a single annotated line beneath it. Legibility wins.
5. **`docs/pipeline.md`'s hooks & scripts section:** reflect `resolve-type.sh`'s `REWORK` output
   (1.1) and the per-row `ship` list (2.1) — this is where the `publish | chat` rendering (D10)
   actually applies in this file, since the type table has no ship column. `workflow-setup.sh`'s
   entry is NOT touched.
6. **`docs/architecture.md:114-117`:** the middle-file list gains `live.md`, and "ten types across
   four pipeline values" becomes eleven across five. **That is the whole edit at this range** — the
   passage also carries `map`'s own `ship: chat` default sentence, which stays true, and it contains
   NO `analyze` ship description to correct. The nearest `analyze` sentence ("The planner-less
   publish types (`document`, `analyze`) skip straight to…") is at `:133`, is accurate as written,
   and must be left alone: `analyze` still defaults to publishing after Phase 2 — only its ability
   to be overridden is new, and that belongs in the files 5.1 and 5.2 item 8 already cover.
7. **`docs/README.md:40`:** eleven types, five pipeline values (build / plan / report / docs /
   live), six middle files.
8. **`docs/pipeline.md:181-182`** (the "Wired" hook list) — currently "`scope-writes.sh`
   (`PreToolUse`; orchestrator write-scope config)". Same correction as `orchestrators/AGENTS.md`
   (5.1 item 6), in this file's terser register, and add `parent-tree-guard.sh` to the same list.
9. **The test-suite count goes 10 → 13**, at `docs/README.md:48` and `docs/architecture.md:168`.
   Phase 4 adds `tests/scope-writes.test.sh`, `tests/parent-tree-guard.test.sh`, and
   `tests/verify-scope-clean.test.sh`; everything else in this plan extends existing suites. Confirm with `ls tests/*.test.sh | wc -l` rather than
   trusting this sentence — it is the count on disk that must match the docs.
10. **Do NOT add the known-issues row to the Map table here** — 5.3 owns `docs/known-issues.md` and
    its link, and the two subphases are serial in lane 5. Leave the table otherwise as you found it.
11. **`docs/conventions.md` is deliberately untouched:** it points at
   `orchestrators/AGENTS.md#review-rules-for-future-types` rather than duplicating the type rules,
   so a new type costs it nothing. Confirm by reading, then leave it alone.

**Acceptance criteria.** Every count in these three files matches reality: eleven types, five
pipeline values, six middle files, **thirteen** test suites. **No sentence anywhere in `docs/` still says
`analyze` always publishes** — `grep -rn 'always publishes' docs/` returns nothing. No behavior is
described here that is not first described in a payload file. `docs/conventions.md` is unmodified.
Nothing describes a changed worktree mode.

**Test approach.** `grep -rn "ten types\|Ten types\|four \`pipeline\`\|five middle files"` over
`docs/` returns nothing; count the rows of the type table against `workflows.yaml`; compare
`ls tests/*.test.sh | wc -l` against the stated suite count (expect 13). Read the rewritten hook
list against `settings.json` as 4.3 left it.

**Test oracle:** `existing suite`.

### 5.3: `docs/known-issues.md` — the home for parked work and known gaps   (lane 5, after: 5.2)

**File scope:** `docs/known-issues.md` (new file), `docs/README.md`.

**Pattern to follow:** the existing topic pages under `docs/` (`architecture.md`, `conventions.md`,
`pipeline.md`, `tool-based.md`) and the Map table in `docs/README.md:36-41` that links each one.
The `doc-format` rule fixes the name shape: docs live at the docs root, `README.md` is the entry
point, and every other file is a lowercase kebab-case topic file — `known-issues.md` is exactly
that shape and needs no new convention.

**Why this exists.** The `-w none` redesign was cut from this plan and parked in
`project-plans/proposals/none-mode-parent-08-28-26.md`. A parked proposal is invisible to anyone
reading the docs: someone hitting `-w none`'s single-lane limitation has no way to learn that the
limitation is known, that a redesign exists, and that the redesign is deliberate rather than
forgotten. This page closes that gap once, for this entry and for every future one.

**What to build.**

1. **Create `docs/known-issues.md`** with an intro that establishes what the page is FOR, so future
   entries land here instead of being scattered or lost: this is the docs root's home for **known
   gaps in current behavior and work that is parked on purpose**. Say explicitly that an entry here
   is not a bug report and not a backlog — it records a limitation someone will actually hit,
   together with whether anything is planned about it and where that plan lives. Say that a parked
   proposal is deliberately parked, not stale, and must not be deleted as cleanup. Keep the intro
   short; the page's value is in its entries.
2. **Add the first entry**, carrying this content verbatim in substance:
   `-w none` runs one builder lane at a time and creates no run dir; the redesign — the current
   checkout as the parent, child lanes still isolated in their own worktrees, and the setup script
   gaining a run-dir-only mode — is parked in
   `project-plans/proposals/none-mode-parent-08-28-26.md`, and **that proposal is intentionally
   parked, not stale.**
   Ground the "current behavior" half in the source rather than asserting it: `worktree-modes.md:13-15`
   for the mode's definition and `build.md:27` for the single-lane consequence.
3. **Link it from `docs/README.md`'s Map table** (`:36-41`), in the same one-row-per-page form the
   other topic pages use, with a one-line description naming both halves — known gaps and parked
   work.
4. **Give the page a shape a second entry can follow** — a heading per entry, with the limitation,
   where it is visible in the source, and its status (parked with a pointer / no plan / fixed and
   awaiting removal). One entry does not need a schema, but it does need to model one, or the second
   entry will invent a different format.

**Scope guard.** This subphase documents the `-w none` limitation; it does not change it.
Convention 14 still holds — `worktree-modes.md`, `build.md`, and `workflow-setup.sh` are not in this
subphase's file scope and must not be touched. Describing current behavior accurately is the whole
job.

**Acceptance criteria.**

- `docs/known-issues.md` exists, is lowercase kebab-case at the docs root, and opens with an intro
  that names the page's purpose as both known gaps AND deliberately parked work.
- The `-w none` entry states the current behavior (one lane at a time, no run dir), names the
  redesign's three parts, points at `project-plans/proposals/none-mode-parent-08-28-26.md`, and says
  in as many words that the proposal is intentionally parked, not stale.
- Its claims about current behavior are true of `worktree-modes.md` and `build.md` as they stand at
  the end of this run — which, per the deferral, means unchanged from `main`.
- `docs/README.md`'s Map table has a row linking the new page.
- No file outside this subphase's file scope is modified.

**Test approach.** No automated test covers docs prose. Read-through against `worktree-modes.md:13-15`
and `build.md:27` to confirm the described limitation matches the shipped behavior, and against
`none-mode-parent-08-28-26.md` to confirm the three redesign parts are stated the same way in both
places. Confirm the link resolves: `test -f docs/known-issues.md` and a grep of `docs/README.md` for
the filename. 5.5's stale-citation sweep re-checks the two source citations.

**Test oracle:** `existing suite`.

---

### 5.4: Merged-lane wording — `build-dispatch.md`, `builder.md`, `live.md`   (lane 5, after: 5.3)

**File scope:** `orchestrators/skills/dae/build-dispatch.md`, `orchestrators/agents/builder.md`,
`orchestrators/skills/dae/live.md`.

**Why these files are here and not in their own lanes.** `build-dispatch.md` and `builder.md` were
lane 3's; `live.md` was lane 4's. Both lanes MERGED before Amendment 4, so reopening them is not an
option and the edits land in the integration lane instead — the same route `SKILL.md:143` took in
5.1. Lane 1 and lane 6 touch none of these three files, so the scope stays disjoint.

**Pattern to follow:** `build-dispatch.md`'s numbered dispatch-loop steps (`:11-23`), whose step 1
already stops the schedule on a missing/invalid exit report or UNREPORTED files; and `builder.md`'s
exit-report section (the `## Exit report` heading at `:35`, its single content paragraph at `:37`),
which already makes the report a FILE written before the envelope.
Both additions extend an existing rule rather than introducing a new one.

**What to build.**

1. **`build-dispatch.md` step 1 ("Verify the lane", `:13`)** — state that a DIRTY child worktree is a
   stop, of exactly the same kind as UNREPORTED files: `verify-scope.sh` now fails with
   `UNCOMMITTED: <path>` when the lane's work is not committed (4.4), and a stop means the merge does
   not happen and the schedule does not advance. Add the routing explicitly, because the tempting
   wrong move is the one this run actually made: **the router never commits on a builder's behalf.**
   It redispatches the lane with `--reuse` (the crash-resume path already described at `:34`) plus
   the instruction to commit its work. Committing for the builder would forge the ownership record
   that `verify-scope.sh` and `verify-run-scope.sh` exist to keep honest.
2. **`builder.md` exit-report section (`:35`, content at `:37`)** — the builder MUST commit its lane before writing
   the exit report. State the reason, not just the rule: an exit report naming files the branch does
   not contain is invalid, and **`validate-report.sh` cannot detect it** — the script reads the
   report file, not git, so no downstream check catches this. That makes it the builder's own
   responsibility, and the concrete last step is `git status --porcelain` returning empty before the
   report is written. Put this in the exit-report section where the report contract already lives,
   not in the Invariants block — it is a step in a procedure, not a standing prohibition.
3. **`live.md` per-lane merge step (stage 4)** — it already delegates the verify step to
   `build-dispatch.md` by pointer. Confirm that it does, and that it names `verify-scope.sh` without
   restating what that check covers. **Do not restate the UNCOMMITTED rule here.** If the pointer is
   already clean, this is a no-op read and the subphase records that; if `live.md` describes the
   verify step in enough detail that item 1's addition would make it stale, tighten it back to a
   pointer. Restating is the failure mode — the rule must live in exactly one place.

**Acceptance criteria.**

- `build-dispatch.md` step 1 names a dirty child worktree as a stop alongside UNREPORTED, and states
  the `--reuse` redispatch as the remedy.
- No file anywhere says or implies the router may commit a builder's work. `build-dispatch.md`'s new
  text says the opposite, in as many words.
- `builder.md`'s exit-report section requires an empty `git status --porcelain` before the report is
  written, and explains that `validate-report.sh` cannot catch a violation.
- `live.md` references the verify step by pointer only; a grep of `live.md` for `UNCOMMITTED` returns
  nothing.
- The UNCOMMITTED rule's substance appears in exactly one middle file (`build-dispatch.md`) and one
  agent definition (`builder.md`) — the two ends of the hand-off — and nowhere else.
- No file outside this subphase's file scope is modified.

**Test approach.** No automated test covers this prose. Read-through against `verify-scope.sh` as 4.4
left it, confirming the documented failure mode matches the implemented one exactly — including the
line shape `UNCOMMITTED: <path>`, since these files quote it. Then `grep -rn 'UNCOMMITTED'` across
`orchestrators/` to confirm the rule appears only where the criteria allow.

**Test oracle:** `existing suite`.

---

### 5.5: Cross-file consistency sweep, full contract-test run, install-mapping check   (lane 5, after: 5.4)

**File scope:** no product files — this subphase changes nothing; it verifies. Any defect it finds
routes back to the owning lane as an `impl-wrong` kickback rather than being fixed here (the
integration lane never does another lane's work).

**Pattern to follow:** `build.md:15`'s integration pass — full suite plus cross-lane acceptance
criteria plus `verify-run-scope.sh`.

**What to verify.**

1. **The whole contract-test suite, every file:**
   `for f in tests/*.test.sh; do echo "== $f"; bash "$f"; done` — every suite reports
   `N passed, 0 failed` and exits 0. **Thirteen** suites, none skipped — the three Phase 4 added
   included, and `tests/verify-scope-parsing.test.sh`, which covers the same script 4.4 changed. `tests/validate-plan.test.sh` and
   `tests/plan-lifecycle.test.sh` are included: 3.5's module leans on both scripts' behavior.
2. **`bash -n`** over every script this plan touches: `orchestrators/hooks/resolve-type.sh`,
   `orchestrators/hooks/scope-writes.sh`, `orchestrators/hooks/parent-tree-guard.sh`,
   `orchestrators/hooks/verify-scope.sh`.
   Plus `python3 -c 'import json;json.load(open("agent-specific/claude/settings.json"))'` for the
   settings file.
3. **Table ↔ doc agreement:** every cell of `SKILL.md`'s type table, `docs/pipeline.md`'s type
   table, and `workflows.yaml` agrees, for all eleven rows — including the `ship` column, where the
   docs render `publish | chat` and the table stores `publish|chat`.
4. **`resolve-type.sh` spot-runs** for each of the eleven types, confirming exit 0 (with an anchor
   for the two `require` rows) and that each block matches what the docs predict.
5. **No type-name branching introduced:**
   `grep -n 'resolved_type\|TYPE=' orchestrators/hooks/resolve-type.sh` shows the type name used
   only in messages and in the emitted `TYPE=` line — never as a control-flow condition. Same read
   over `live.md`.
6. **The deferral held.** `git diff --name-only <base>...HEAD` contains none of
   `orchestrators/skills/dae/worktree-modes.md`, `orchestrators/skills/dae/build.md`,
   `orchestrators/hooks/workflow-setup.sh`, `tests/workflow-setup-reuse.test.sh`. This is
   convention 14, checked mechanically — the deferral is a claim about the DIFF, so check the diff,
   not the prose. **Do not grep the changed files for `-w none`:** 5.3 deliberately writes that
   string into `docs/known-issues.md`, and 3.3's own acceptance criteria already run the
   worktree-mode grep where it belongs — scoped to `live.md` alone.
7. **Install mapping for the two NEW files.** `orchestrators/skills/dae/live.md` maps via
   `sync-install.sh`'s `orchestrators/skills/*/*` → `skills/dae/live.md` rule, and
   `orchestrators/agents/planner/plan-live.md` via its `orchestrators/agents/*` →
   `agents/planner/plan-live.md` rule (both documented in that script's header). Confirm by reading
   those lines and by a dry `sync-install.sh --check` whose reported drift is exactly this run's
   changed and new files and nothing else. **Do not run a real sync** — landing and syncing is
   `push-main`'s job, after the merge (`.claude/rules/source-push-sync.md:2-3`).
8. **`verify-run-scope.sh <parent-worktree> <base> <run-dir>`** reports no `UNCLAIMED:` lines —
   every changed product file is claimed by some lane's exit report.
9. **The hooks are wired and the docs say so.** `agent-specific/claude/settings.json` lists
   `scope-writes.sh` under `PreToolUse` `Write|Edit|MultiEdit|NotebookEdit` and
   `parent-tree-guard.sh` under both `PostToolUse` `Bash` and `Stop`; `orchestrators/AGENTS.md`,
   `docs/pipeline.md`, and `SKILL.md` each describe that wiring and no longer describe an
   allowlist-configured or unwired `scope-writes.sh`. **Diff the docs against the settings file, not
   against this plan** — three documents drifted from reality for the entire life of that hook
   precisely because nobody checked them against the wiring, and repeating the check against prose
   would repeat the failure.
10. **The known-issues page landed and is reachable.** `test -f docs/known-issues.md`; `docs/README.md`
   links it; the page's `-w none` entry names
   `project-plans/proposals/none-mode-parent-08-28-26.md` and calls it intentionally parked. A parked
   proposal with nothing pointing at it from the docs is the failure 5.3 exists to prevent, so verify
   the pointer, not just the file.
11. **Stale-citation sweep.** Every `file:line` reference written into a changed file still points at
   what it claims. This run has already been bitten once: the fast-forward to `d751bea` moved
   `report.md`'s closing note from `:25` to `:47`, `verify-run-scope.sh`'s `UNCLAIMED:` emitter to
   `:165`, `resolve-config.sh`'s hard-coded base default to `:114`, and `orchestrators/AGENTS.md`'s
   review rules to `:149-172`. Line numbers drift; a drifted citation is a finding.

**Acceptance criteria.** All eleven checks pass, with the command and its observed output recorded
per criterion in the lane's exit report. Any failure is reported as a blocker naming the owning lane and
subphase, never patched from this lane.

**Test approach.** The checks above ARE the test; each is a command with observable output.

**Test oracle:** `existing suite`.

---

## Risks, open questions, decision points

### Settled — recorded, not open

Decisions the user made across Amendments 1 and 2, listed so the gate can see what was decided and
why rather than re-litigating them.

- **D1 — `diagnose` and `sync` carry no `rework:` cell.** Both dispatch builders (`diagnose.md:13`)
  and both have a `code` phase (`resolve-type.sh:358`), so their builders keep today's unbounded
  loops while every build run's are bounded. **Accepted as briefed**; `--rework` is still honored if
  passed explicitly on those runs.
- **D2 — absent budget means unbounded**, i.e. today's behavior, stated explicitly in both
  `build-dispatch.md` (1.3) and `builder.md` (1.4) rather than left to inference.
- **D5 — `--plan <path>` stays rejected on `live`.** `resolve-type.sh:496`'s
  `[ "$pipeline" != "build" ]` gives this for free; adopting a pre-approved plan into a run whose
  whole shape is "grow the plan ask by ask" is incoherent.
- **D6 — the `run` skill is hedged.** This repo ships no `run` skill (confirmed by a tree-wide
  search of `orchestrators/skills/`, `agent-agnostic/skills/`, and `tool-based/*/skills/`); it is a
  vendor/plugin skill in the ambient roster. `live.md` names it as an optional convenience "if
  available"; the editor offer is unconditional.
- **D7 — `REWORK=` sits after `SHIP=`, before `PLANNER=`**, so the exact-block tests have something
  to assert.
- **D8 — per-ask durable asks.** Each live ask is written to `<run-dir>/asks/<n>.md` BEFORE the
  planner is messaged; the plan's ask-of-record pointer names the `asks/` directory; `plan-live`
  cites the per-phase ask file. This is what makes `review-plan`'s ask-vs-plan diff
  (`review-plan/SKILL.md:33`) runnable on a run that has no single up-front brief.
- **D9 — the integration phase is kept** (now Phase 4).
- **D10 — `--ship` semantics and rendering** (Amendment 2, replacing the earlier open question about
  refusing a no-op override). Naming the value a row already defaults to is a WARNING that continues
  the run, worded by whether the row is overridable ("already the default") or fixed ("`--ship` is
  fixed on `<type>`; ignoring"); naming a different value the row allows APPLIES it; naming a value
  the row does not allow is an ERROR; a value outside the vocabulary is an error as before.
  Overridable ship cells render as `publish | chat`, default first, in `SKILL.md` and `docs/`.
- **D11 — `-w none` is deferred out of this plan entirely** (Amendment 2 §1), parked in
  `project-plans/proposals/none-mode-parent-08-28-26.md`. `live` uses the standard parent/child
  worktree scheme. The earlier open question about the setup-script flag's name is moot and has been
  removed rather than carried.

### Open questions

None outstanding. Every question this plan raised has been settled by the user across Amendments 1
and 2; the settled set is recorded above rather than left implicit. If the gate finds a new one, it
belongs here, not in a subphase.

### Risks

- **R1 — the exact-block tests are brittle by design.** `tests/resolve-type.test.sh:730-777` asserts
  `feature`, `map`, and `analyze` stdout byte-for-byte. `REWORK=3` breaks `43a` immediately.
  Intended — the test IS the contract — but it means 1.1 cannot land without touching the test file,
  which is why lane 1 must stay serial.
- **R2 — three separate subphases each disturb existing cases, and the suite runs to case 50.** 1.1
  breaks `43a`; 2.1 rewrites `44`/`45`/`46`/`49` (with 45 and 46 *flipping from error to
  warn-and-continue*, not merely being reworded), rewords case 29's banner, and **must leave case
  50's body alone while rewording its banner** (its precedence assertions survive step 4's
  reordering — verified against `:950-963`, and stated in 2.1 rather than left for the gate to
  infer); 3.2 breaks `30`. Each repair is assigned to the subphase that causes it. A lane that lands
  one without its repair leaves the suite red on a case unrelated to its intent. The compounding
  hazard is numbering: **the highest existing case is `50`, not `49`**, so any subphase that appends
  a case must run `grep -n '^# --- Case' tests/resolve-type.test.sh` first rather than trusting a
  number quoted in prose. A duplicate case number does not fail the suite — both cases run and both
  report — so this collides silently.
- **R3 — the blind-test discipline is easy to violate under pressure.** The suite's whole value
  (`tests/resolve-type.test.sh:12-35`) is that it never reads the implementation. A contract-tester
  that peeks at `resolve-type.sh` to get an exact block right produces a test that can only ever
  agree with the code. The plan's pinned blocks exist precisely so it does not need to peek.
- **R4 — reversing a decision that shipped four commits ago.** `5108f1d` landed the `--ship` lock
  with its own tests and three paragraphs of reasoning in `SKILL.md:43-44`. The reversal must
  REPLACE that reasoning, not sit beside it — two contradictory settled-fact bullets in the same
  list is worse than either policy alone. 2.2's acceptance criteria make this explicit; the gate
  should check it specifically.
- **R5 — the warn path is the easiest thing to get subtly wrong.** A warning must exit 0 AND still
  print the full `KEY=value` block; an implementation that warns and then falls through a shared
  error path, or that warns and skips emission, would look correct in a stderr-only test. 2.1's
  acceptance criteria assert the triple (exit code, stdout block, stderr warning) together, and case
  45 must too — this is the same shape case 27 already uses for the rigor D2 warning.
- **R6 — dropping Phase 2 leaves lane 3 mixed.** Lane 3 now carries the rework-dial docs
  (`build-dispatch.md`, `builder.md`) and the planner files (`planner.md`, `plan-live.md`) — four
  files across two unrelated features. The scopes are disjoint from every other lane and the
  `(after:)` edges order them correctly, so this is legal, but a builder must not assume its lane is
  thematically coherent. Its contract should treat 1.3/1.4 and 3.5/3.6 as two independent packet
  chains.
- **R7 — the live loop's context cost.** The router stays conversational for the entire build
  instead of flipping to auto mode, so a long live run accumulates builder reports, merge events,
  and user asks in one context. `live.md` must lean hard on pointers-not-payloads and on the
  progress log; the `asks/<n>.md` files (D8) are part of that defense. A design risk of the type
  itself — the gate should read `live.md`'s Notes with it in mind.
- **R8 — `live` is the first type whose plan grows during the build.** Every gate re-reads the plan
  file at verdict time (`SKILL.md:130`), which is what makes this safe; but any downstream consumer
  that assumed a plan is complete at approval will now be wrong. 5.5's sweep is where that surfaces;
  none was found during exploration.

- **R10 — these hooks constrain the agent that is running the build.** Lane 6 changes the rules the
  ORCHESTRATOR operates under, mid-run, and `4.3`'s wiring takes effect for every session that syncs
  afterwards — not just this one. Two consequences. First, a bug in 4.1 that mis-identifies a parent
  worktree would deny legitimate writes on every project, and a bug in 4.2 would fail `Stop` on every
  session; both hooks are inert-by-default for exactly this reason, and 4.5's child-worktree and
  plain-checkout cases are the regression tests that matter most. Second, once wired, the
  orchestrator can no longer edit product files even to fix a lane — which is the intent, but it
  means any remaining lane must be dispatched, never patched. The `after: 3.2` edge exists so this
  lands when the schedule is quiet.
- **R11 — the docs drifted from the wiring for the entire life of `scope-writes.sh`.** Three separate
  files asserted a protection that was never wired, and nothing caught it: no test covers
  `settings.json`, and no gate diffs documentation against configuration. Phase 4 fixes this
  instance; it does not add a mechanism that would catch the next one. 5.5's check 9 is a manual
  diff, and that is the honest state of it — worth naming as residual risk rather than claiming the
  class is closed.

- **R12 — the two silent-success bugs this plan now fixes were found by accident, not by a gate.**
  `scope-writes.sh` was unwired for its whole life (R11); `verify-scope.sh` passed a lane that
  delivered nothing, and only a later `git worktree remove` refusal exposed it. Both share a shape:
  a check that reports success without having verified the thing its caller depends on. 4.4 and 5.4
  fix this instance; the class is not closed, and the honest reading of R11 and R12 together is that
  this pipeline's self-checks need a periodic audit against what they actually assert, not just
  against what their docstrings claim.

---

## Skill mapping

| Work | Executor |
|---|---|
| This plan | `planner` agent, module `plan-feature` (declared type: `feature`) |
| The plan gate on this file | `review-plan` (+ `agent-agnostic/skills/review-plan/scripts/validate-plan.sh`, `plan-lifecycle.sh check`) |
| Lanes 1–6 | `builder` agents, one per lane, dispatched per `build-dispatch.md` off the approved syllabus |
| Packet implementation | `coder` sub-agents inside each builder |
| Contract tests (1.1, 2.1, 3.1, 3.2, 4.5) | `contract-tester` sub-agents, blind, from the builder's contract text |
| Per-lane merge-back gate | `verify-scope.sh` as 4.4 hardens it — a dirty child worktree stops the merge |
| Per-lane scope check | `verify-scope.sh` against each exit report's `## Files touched` |
| Run-level scope check | `verify-run-scope.sh` at the integration pass (5.5) and again at the PR gate |
| Syllabus ticks | `mark-syllabus.sh`, orchestrator-only |
| Code gate | `review-code` after the build stage |
| Record | `document-local` (always — `CLAUDE_DOCS_DIR` resolves to a local path) |
| PR gate | `review-pr` → `pr-review.md`, verdict written by `report-verdict.sh` |
| Landing | **`push-main`, not `push-pr`** — this repo uses no PRs (`.claude/rules/source-push-sync.md:2`), squash-merges into `main` locally, then runs `orchestrators/hooks/sync-install.sh <pushed-range>` |
| Closeout | `cleanup-merged`, then `plan-lifecycle.sh archive` |
