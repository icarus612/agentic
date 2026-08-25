# dae Restructure — Types as Presets over Axes

**Status:** APPROVED at the plan gate and promoted (08-24-26); in flight on `feature/dae-axes-restructure`. Rev 5 design, amended in three rounds — two at the gate, one post-approval:

- **Round 1 (08-23-26):** the missing `after: 1.1` edge on 2.1; a refreshed Stack table; the recorded resolutions of **D1** (rigor as substitute) and **D2** (warn and continue).
- **Round 2 (08-24-26):** §2.4's run-shape diagram corrected to match §2.2's table for `document`; the last stale test-suite count (§2.12 item 14).
- **Round 3 (08-24-26, post-approval, driven by 1.1's own findings — lane `l0`):** 1.1's acceptance criteria rewritten around what a baseline can actually carry, and the subphase marked `- [done]` (it closed differently than planned); 5.2's byte-for-byte oracle replaced with four structural checks after it was measured impossible; 3.2 and 10.1 re-worded to the layer they are checkable at; 10.1's `bug/`-branch and `triage`-error corrections; the committee's member-artifact convention — one file per member under `committees/<skill>/`, member id `c<n>`, the committee type carried by the directory — stated once, in 5.1; and `--rigor`'s alias/bracket assignment (`-r`, `--rig[or]`), which moved `--against` to `-a`. Evidence: `<run-dir>/reports/l0-exit.md` and `<run-dir>/contracts/l0.md`.

The stale count was a *repeated* fact, not one line — `tests/sync-install-settings-merge.test.sh` landed in `5644e79`, after the rev 5 fact-gathering, and the old counts appeared in **four** places: the Stack table's suite count and its script count (both flagged at round 1), §2.11 D3 (found while amending, round 1), and §2.12 item 14 (found by the gate, round 2). All four now read correctly against the tree — **4** suites, **17** `#!/usr/bin/env bash` scripts. Design unchanged from the rev 5 spec, preserved under **Design reference** below, which enumerates the edits made to it.

**Supersedes:** nothing. This is the first plan for this work.

## Phase syllabus

- [ ] Phase 1: Baseline
  - [done] 1.1: Capture the pre-migration regression reference
- [ ] Phase 2: Run-tooling hardening
  - [x] 2.1: `finalize` refuses without a passing `pr-review.md`     (lane 1, after: 1.1)
  - [x] 2.2: `push-pr` accepts `docs/` and `sync/` branches          (lane 1, after: 2.1)
  - [x] 2.3: `--reuse` recovers a surviving worktree, not just a branch (lane 7)
- [ ] Phase 3: Anchors
  - [x] 3.1: `resolve-anchor.sh` + tests                             (lane 1, after: 1.1)
  - [x] 3.2: `--ref` → `--against` in the two middles that use it    (lane 1, after: 3.1)
- [ ] Phase 4: Type table + resolver
  - [x] 4.1: `workflows.yaml`                                        (lane 2, after: 1.1)
  - [x] 4.2: `resolve-type.sh`                                       (lane 2, after: 4.1)
  - [x] 4.3: `tests/resolve-type.test.sh`                            (lane 2, after: 4.2)
- [ ] Phase 5: Committee + rigor
  - [x] 5.1: The `committee` agent                                   (lane 3, after: 1.1)
  - [x] 5.2: `explore` emits claims; committee wraps it              (lane 3, after: 5.1)
  - [x] 5.3: Gate skills: collector/gate tie-break + wrap            (lane 3, after: 5.1)
  - [x] 5.4: `review-pr` docs-branch accuracy check                  (lane 3, after: 5.3)
- [ ] Phase 6: Report pipeline
  - [x] 6.1: `report.md` + skeleton + the `ship: chat` short-circuit (lane 4, after: 1.1)
- [ ] Phase 7: Plan handoff
  - [x] 7.1: `plan-lifecycle.sh adopt` + tests                       (lane 5, after: 1.1)
  - [x] 7.2: Staleness guard + cold-amend kickback routing           (lane 5, after: 7.1)
- [ ] Phase 8: Docs workflow + reconcile grammar
  - [x] 8.1: `document.md` PR-gate oracle split                      (lane 6, after: 1.1)
  - [x] 8.2: `plan-reconcile` emits full build grammar               (lane 6, after: 1.1)
- [ ] Phase 9: Integration
  - [x] 9.1: `dae/SKILL.md` — the shared touchpoint                  (after: 2.2, 3.2, 4.3, 5.4, 6.1, 7.2, 8.2)
  - [x] 9.2: Doc sweep + the `run-artifacts` rule                    (after: 9.1)
- [ ] Phase 10: Verification
  - [x] 10.1: Regression against the Phase 1 baseline                (after: 9.2, 2.3)
  - [x] 10.2: The `audit` new-type drill                             (after: 10.1)

## Outcome — what shipped, before and after

*Written at closeout, after the ship gate returned `ready`/`proceed`. The verbatim original ask is
preserved below at **Part 1**; this section is what it turned into.*

**The ask, in one line:** a new run type should cost a table row, not a new workflow.

| | before | after |
|---|---|---|
| **Types** | 8, each a bespoke workflow with its own logic | 10 rows over 5 orthogonal axes (`pipeline`, `explore`, `rigor`, `against`, `ship`) |
| **Router** | `dae/SKILL.md` interpreted the type table itself; type names hardcoded in it | consumes `resolve-type.sh`'s `KEY=value` output — **the router no longer knows the type vocabulary** |
| **Cost of a new type** | new workflow file + router edits + planner module + doc updates | **one `workflows.yaml` row**, plus at most one planner module |
| **Anchors** | `--ref`, exactly one value | `--against`/`-a`, an **array** — git refs, tickets, plan paths — resolved by `resolve-anchor.sh`, all-or-nothing |
| **Verification depth** | one pass, always solo, not addressable | `--rigor`/`-r`: a four-phase profile (`explore`/`plan`/`code`/`pr`) at `low`\|`med`\|`high` |
| **Cross-checking claims** | none — one agent's output was the answer | generic `committee` agent wrapping any claim-emitting skill; artifacts at `committees/<skill>/<file>-c<n>.md` |
| **Quick questions** | none — every run cut a branch and a worktree | `map` (fast) and `analyze` (careful) share one `report` middle; `ship: chat` produces **zero git side effects** |
| **sync → build** | re-plan by hand | `plan-lifecycle.sh adopt` — provenance recorded, staleness guard, cold-amend routing |
| **Docs PR gate** | judged the docs against the survey **only**, so a wrong fact copied faithfully passed | survey = **coverage** spec, code = **accuracy** oracle |
| **`map`** | an alias off `document` — gave you the whole docs workflow | its own type: `{pipeline: report, explore: auto, rigor: low, against: forbid, ship: chat}` |
| **`debug` / `triage`** | `debug` → `bugfix`; `triage` was an unlisted-value **error** | both → `diagnose` |
| **Test suites / hooks** | 4 / 13 | 8 / 15 |

**Four live defects fixed along the way**, none of them in the original analysis — three were found by
the run's own builders, one by its own crash recovery:

- `push-pr` rejected `docs/` and `sync/` branches — its own publisher tripped document and sync runs.
- `push-pr --stage finalize` could flip a PR to ready with **no passing `pr-review.md`** at all.
- `explore` declared `agent: Explore`, an agent type with **no write tool**, while its entire contract
  was writing a map to disk. Runs either improvised a shell heredoc or silently wrote nothing.
- `workflow-setup.sh --reuse` recovered a surviving *branch* but not a surviving *worktree* — and a
  crash leaves both. Added to scope mid-run at the user's request as **2.3**.

**What the migration deliberately did NOT do:** `low` is the pre-existing solo path, byte-for-byte
untouched, never routed through the committee. That was the plan's own stated worst case
(`committee(skill, n=1)`), and 5.2's four structural checks exist to catch it.

**Proof the headline claim holds.** 10.2 stood up a throwaway `audit` type and measured what it cost:
**one row, zero templates, zero orchestration changes** — and the unedited resolver derived correct
behavior for a type it had never seen. 10.1 confirmed nothing else moved: 8/8 routing probes unanimous
across 3 independent blind trials, exactly two intended differences, and the four pre-existing middles'
stage sequences **byte-identical**.

## Goal & scope

**Goal.** Restructure `dae` so that types are **presets over orthogonal axes** rather than bespoke workflows, so a new type costs one table row plus (at most) one planner module — no new loops, no new orchestration. Full design rationale is preserved under **Design reference**; this section states only what is in and out.

**In scope**
- The five axes, the type table, and a script that resolves and validates them (`resolve-type.sh`).
- The generic `committee` agent and the four-phase rigor profile.
- The `report` pipeline (`map`, `analyze`) and the `ship: chat` short-circuit.
- `--ref` → `--against` as an array, with `resolve-anchor`.
- The sync → build plan handoff (`plan-lifecycle.sh adopt`, staleness guard, cold-amend routing).
- Six defects verified against the current tree: the missing `finalize` PR-gate refusal, `push-pr`'s branch-enum gap, `document.md`'s map-only PR oracle, the nonexistent doc file named by the old Step 9, the already-false acceptance criterion 8, and the unmentioned `tests/` suites.

**Explicitly out of scope**
- sync generic/no-anchor sweep mode (gated flag; invariant amendment per §2.2.4)
- rigor auto-escalation (`high` stays a manual ask)
- old-conversation mining as a sync input
- factoring `diagnose.md` + `sync.md` into `reconcile.md` (wait for the third plan-pipeline type)
- an actual `sync-tests` type (§2.9 is the recipe; ship it only when wanted)
- Any change to `~/.claude/` by hand. This repo is the source; the install is refreshed by `sync-install.sh` after the push (`.claude/rules/source-push-sync.md`).
- Any product change in another repository.

## Stack & MAJOR versions

Verified from the repo itself, not from memory:

| thing | version / fact | verified from |
|---|---|---|
| Shell | GNU bash **5.1.16** | `bash --version` |
| Script interpreter | `#!/usr/bin/env bash` on all 17 scripts under `orchestrators/hooks/` + `tests/` (13 hooks + 4 suites) | shebang scan of both dirs, 08-23-26 at `5644e79` |
| Package manifest | **none** — no `package.json`, `pnpm-lock.yaml`, `go.mod`, `pyproject.toml`, or `Makefile` at the repo root | `ls` at root |
| Payload | Markdown skills/rules/agents + bash hooks. No compiled language, no dependency graph. | repo tree |
| JSON/YAML parsing | **no `jq`, deliberately** — hooks hand-parse with `awk`/`sed` | `orchestrators/hooks/resolve-config.sh:21` |
| Test harness | plain bash fixture suites, four of them, run directly — `plan-lifecycle`, `resolve-config-precedence`, `sync-install-settings-merge`, `verify-scope-parsing` | `tests/*.test.sh` |
| Agent frontmatter | `name`, `description`, `model` | `orchestrators/agents/coder.md:1-5` |
| Skill frontmatter | `name`, `description`, `domain`, `context`, `rules`, `model`, `model-fallback` | `agent-agnostic/skills/explore/SKILL.md:1-9` |

> **These are BASELINE counts, as of `5644e79` — deliberately not updated to post-migration numbers.**
> This section pins what the plan was built against, and the as-of stamp is doing real work: overwriting
> it with current numbers would erase the provenance every "verified from" column exists to provide.
> For reference, the run itself has since added **2 hooks** (`resolve-anchor.sh`, `resolve-type.sh`) and
> **4 suites** (`push-pr-gate-refusal`, `resolve-anchor`, `resolve-type`, `workflow-setup-reuse`), so the
> tree now holds **23** bash scripts (15 hooks + 8 suites) against the table's 17 (13 + 4). Both numbers
> are correct for their respective points in time. *(Raised as staleness by lane 7 in round 4; recorded
> this way rather than by overwriting, because the fourth recurrence of a "stale count" turned out not
> to be stale at all — the earlier three were genuinely wrong, this one is a dated snapshot doing its
> job.)*

**Consequence for this plan:** every new script must parse without a dependency, which is why `workflows.yaml` is constrained to one-line flow maps (4.1).

## Conventions to enforce

Hard constraints, not preferences:

- **Source, not install.** All edits land in this repo's `orchestrators/`, `agent-agnostic/`, `tool-based/`. Never edit `~/.claude/` directly; `sync-install.sh` refreshes it after the push. (`.claude/rules/source-push-sync.md`)
- **No PRs in this repo.** Integration is a local squash-merge into `main` via the `push-main` skill. Ask before every push; never force-push; never commit directly on `main`.
- **`domain: universal`** on everything added under `orchestrators/` and `agent-agnostic/`. Tech-bound content belongs in `tool-based/` and never installs to `~/.claude/`.
- **No `jq`, no new runtime dependency.** `awk`/`sed` only, matching every existing hook.
- **Verdicts are script-written.** `report-verdict.sh` is the only way a verdict enters a report; `validate-report.sh` checks it. No skill invents a status vocabulary.
- **The status vocabulary is closed.** `ready | tentative | rejected` × `proceed | impl-wrong | plan-wrong | map-wrong | needs-input`. Anything needing a sixth value is a design error, not a script change.
- **`plan-format` and `run-artifacts`** govern anything this work emits. Committed plan records in the plans dir; progress logs, contracts, exit reports, claim files in the gitignored run dir. Never crossed.
- **No time estimates** anywhere in this plan or anything derived from it.
- **One command per Bash call**; never chain `cd` with `git`/`gh` (`shell-discipline`).

## Phase 1: Baseline

### 1.1 — Capture the pre-migration regression reference

- **Status: closed as `done`, not as planned.** Ran as lane `l0` and returned `needs-input`. The acceptance criteria below are the **amended** ones, rewritten from what the capture proved was actually possible; the original wording assumed a dae run is a program whose output can be recorded and replayed. Full record: `<run-dir>/contracts/l0.md` and `<run-dir>/reports/l0-exit.md`.
- **File scope:** none in this repo — verified zero product files touched (`git diff feature/dae-axes-restructure...HEAD --stat` empty on `l0`). All output lands in the gitignored run dir at `<run-dir>/baseline/`.
- **Pattern to follow:** the spec's Step 0 — a pinned sandbox repo, not this one, so a run's own side effects cannot contaminate the reference. Delivered as `baseline/sandbox` (`tallyq`, dependency-free bash, mirroring this repo's no-manifest shape), base commit `30ff0cf`, five branches created through the real `workflow-setup.sh`, one per branch type.
- **Acceptance criteria (amended).** A baseline is accepted when **every downstream consumer named in this plan has either a re-runnable oracle on the deterministic layer, or an explicit, evidenced statement that it cannot have one.** Possessing captured artifacts is not the criterion; carrying an oracle is. The governing split:
  - **Deterministic layer** — hook behavior, git state, file content, closed-vocabulary decisions. Every oracle lives here.
  - **Stochastic layer** — planner prose, explore maps, gate reasoning, builder transcripts. Reference only, **never** an oracle. Measured rather than assumed: four controlled `explore` runs on identical input produced maps differing by **218 of 276 lines** (7855 vs 10581 bytes, different sha256) — `baseline/repro/RESULT.md`. An oracle placed here is not a weak check but a **false** one: it fails correct implementations and passes incorrect ones, at random.

  What the delivered baseline provides, per consumer:
  - **2.2** — `baseline/bin/check-push-pr-enum.sh`, which reds pre-migration with exactly `FAIL: push-pr branch enum missing: docs sync`, plus the `docs/` and `sync/` sandbox branches.
  - **3.2** — `baseline/fixtures/3.2-anchor-resolution.md`: all three single-anchor forms with their resolved git ranges and canonical diffs, plus a seeded defect whose failure output reproduces byte-identically; `--ref` sites enumerated at `baseline/signatures/ref-flag-occurrences.md`.
  - **8.1** — `baseline/fixtures/8.1-seeded-map.md` (input) and `8.1-contradictions.md` (ground truth: two facts contradicting source at cited `file:line`), read through the closed `verdict`/`next` vocabulary plus a substring check, never a prose diff.
  - **10.1** — `baseline/bin/extract-signature.sh` + `signatures/router-signature.txt` (flags, type-selection table, per-workflow stage sequences, both branch enums, anchor-flag sites, hook/suite inventory), and the eight pinned probes in `fixtures/routing-probes.md`, measured **8/8 unanimous across 3 independent trials**.
  - **Existing-suite oracle** — all four `tests/*.test.sh` green pre-migration (`baseline/substrate/test-suite-baseline.txt`).
  - **5.2** — recorded as **not servable at the byte layer**, with the substitute written into 5.2 itself.
- **Deliberately NOT captured: an end-to-end transcript corpus for the five types.** This is a recorded decision, not a shortfall to be made up later. A transcript cannot carry an oracle (the 218/276 measurement above), so the corpus would have been authoritative-looking and uncheckable — and 10.1, written against it, would have degraded silently into a human eyeball comparison. The human gates compound it: an auto-approved run is not the run a human would have shaped, so the capture would not even be of the thing it claimed to record. A stated gap beats a false baseline.
- **Test approach:** none — this subphase *is* the fixture. Its acceptance is the per-consumer list above, each item re-runnable today.
- **Test oracle:** n/a (fixture capture).

> **Blocking dependency.** Every subphase that *enters* a lane declares `after: 1.1` — that is 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1, and 8.2. Note lane 1 has **two** independent entry points (2.1 and 3.1), so "one per lane" is the wrong count; the invariant is that no lane subphase is reachable without 1.1. Without this capture, 5.2's `low`-path structural checks and the Phase 10 regression are unverifiable claims rather than checks.

## Phase 2: Run-tooling hardening

### 2.1 — `finalize` refuses without a passing `pr-review.md`

- **File scope:** `agent-agnostic/skills/push-pr/SKILL.md`; `tests/push-pr-gate-refusal.test.sh` *(new)*.
- **Pattern to follow:** the caller side of the report contract as the review gates already implement it — `review-pr/SKILL.md` step 9 runs `validate-report.sh` and fixes FAILs rather than skipping. `finalize` adopts the same contract as a precondition.
- **Acceptance criteria:** `--stage finalize` validates that the run's `pr-review.md` (a) exists, (b) passes `validate-report.sh`, and (c) has a **last** round carrying `verdict: ready` + `next: proceed`. Any miss → refuse with a plain error and do not flip draft → ready. Stated as a stage precondition in the skill body, not advice. **Verified precondition:** no such check exists today — `push-pr/SKILL.md:29,57` only *links* the report into the PR body.
- **Test approach:** bash fixture suite in the style of `tests/plan-lifecycle.test.sh` — build four report files (absent, malformed, last-round `rejected`, last-round `ready`/`proceed`) and assert refuse/refuse/refuse/proceed.
- **Test oracle:** `new contract tests`.

### 2.2 — `push-pr` accepts `docs/` and `sync/` branches

- **File scope:** `agent-agnostic/skills/push-pr/SKILL.md`.
- **Pattern to follow:** the authoritative branch-type enum in `workflow-setup.sh:65-66` — `feature|bug|hotfix|docs|sync`. `push-pr` must match that set exactly, not a subset.
- **Acceptance criteria:** the branch verification at `SKILL.md:24` names all five prefixes. A `docs/` or `sync/` branch passes verification at every stage. **Verified defect:** it currently names only `feature`, `bug`, `hotfix`, so document and sync runs trip their own publisher.
- **Test approach:** replay the Phase 1 `document` and `sync` baselines through `push-pr`; neither trips branch verification.
- **Test oracle:** `existing suite` (the Phase 1 baseline).

### 2.3 — `--reuse` recovers a surviving worktree, not just a branch

- **File scope:** `orchestrators/hooks/workflow-setup.sh`; `tests/workflow-setup-reuse.test.sh` *(new)*.
- **Pattern to follow:** the script's own `err()` discipline and exit-code contract, and the fixture
  style of `tests/resolve-config-precedence.test.sh`.
- **Verified defect** (confirmed independently by lanes 1 and 3 during this run's crash recovery, then
  by the orchestrator against the source): `workflow-setup.sh:142` runs
  `[ -e "$path" ] && err "worktree path already exists"` **unconditionally**, before the `--reuse`
  logic at `:145`. So `--reuse` recovers a surviving BRANCH but never a surviving WORKTREE — and a
  crash leaves *both* standing. Every respawned lane therefore hits it, which is exactly the moment
  the recovery path is supposed to work. Both lanes worked around it by running the merge step by
  hand; hand-improvising git during crash recovery is the failure mode this script exists to prevent.
- **Acceptance criteria:** with `--reuse`, an existing path that IS a registered worktree of this repo
  on the expected `<type>/<name>` branch is **adopted** — the base branch is merged in exactly as the
  branch-only path already does, and `REUSED: yes` is reported. Without `--reuse`, an existing path
  still errors as it does today. **The adoption must be guarded, not blanket:** a path that exists but
  is NOT a registered worktree, or is a worktree on a DIFFERENT branch, still errors — silently
  adopting an unrelated directory would be worse than the defect. Conflicts on the merge abort as they
  already do. **The scope of this subphase is that path check alone**; no other behavior changes.
- **Test approach:** bash fixture suite over a throwaway repo. Cases: (a) `--reuse` with both branch
  and worktree surviving → adopts, merges base, reports `REUSED: yes`; (b) `--reuse` with branch only
  (the case that already works) → unchanged; (c) no `--reuse`, path exists → still errors; (d) path
  exists but is not a worktree → errors; (e) path is a worktree on a different branch → errors;
  (f) a merge conflict during adoption → aborts cleanly, leaving no half-made worktree.
  **Assert on output content, not exit status alone** — a failed git call inside a pipeline can exit 0.
- **Test oracle:** `new contract tests`.

> **Added to scope by the user, mid-run.** Found by this run's own crash recovery rather than by the
> original analysis, which is why it appears here rather than in the approved plan's first draft.
> Phase 2's title broadened from "Publisher hardening" to "Run-tooling hardening" to cover it: 2.1 and
> 2.2 hardened `push-pr`, this hardens `workflow-setup.sh`, and all three are defects in the run's own
> infrastructure. It carries no `after:` edge — its file scope is disjoint from every other subphase,
> so it may run concurrently with Phase 9. **10.1 gains it as a dependency** so the regression pass
> runs against a tree with everything in it.

## Phase 3: Anchors

### 3.1 — `resolve-anchor.sh` + tests

- **File scope:** `orchestrators/hooks/resolve-anchor.sh` *(new)*; `tests/resolve-anchor.test.sh` *(new)*.
- **Pattern to follow:** `orchestrators/hooks/resolve-config.sh` — bash, `err()` + explicit exit codes, `awk`/`sed` parsing, **no `jq`**. Test fixtures follow `tests/resolve-config-precedence.test.sh`.
- **Acceptance criteria:** resolves each item independently to a typed pointer `{kind: git|jira|plan, raw, resolved}` via `git rev-parse` / ticket lookup / path check. Repeatable flag *and* comma-separated both accepted; order preserved. **All-or-nothing:** one unresolvable anchor fails the whole parse (a silently dropped anchor is worse than an error). Emits the `anchors:` block for plan front-matter and the progress log.
- **Test approach:** fixture repo with known refs and paths — multi-anchor ordering preserved; one bad anchor fails the entire call; each `kind` resolves correctly.
- **Test oracle:** `new contract tests`.

### 3.2 — `--ref` → `--against` in the two middles that use it

- **File scope:** `orchestrators/skills/dae/diagnose.md`, `orchestrators/skills/dae/sync.md`. **`dae/SKILL.md` is deliberately excluded — it is the shared touchpoint, serialized into 9.1.**
- **Pattern to follow:** each file's existing "capture the suspect/shipped work" prose.
- **Acceptance criteria:** no `--ref` remains in either file; both describe an anchor **array**; both delegate resolution to `resolve-anchor.sh`. **`-r` no longer means an anchor** — it is reassigned to `--rigor` (9.1 owns the table entry), and `--against` takes **`-a`**. Neither file may document `-r` in the anchor sense. A stale `-r <branch>` is expected to fail on the *value* vocabulary (`low`/`med`/`high`/`<phase>:<value>`), never to resolve silently into a rigor setting.
- **Test approach:** two halves, at the layer each can actually be checked.
  - *Textual* — `grep -r -- '--ref'` over both files returns nothing; the two pre-migration sites are pinned at `<run-dir>/baseline/signatures/ref-flag-occurrences.md` (`diagnose.md:7`, `sync.md:7`).
  - *Behavioral, at the **anchor-resolution** layer* — each of the three single-anchor forms (branch, range, sha) captured in `<run-dir>/baseline/fixtures/3.2-anchor-resolution.md` must still resolve to the same git range and produce the same diff, and the seeded defect's failure output — byte-stable across runs — must still be the reproduction the run targets. 3.1's `resolve-anchor.sh` is tested directly against that table.
  - **Not** "the diagnose baseline's investigation behaves identically": 1.1 established that an LLM investigation's narrative is not diffable (218 of 276 lines differed across identical runs), so the claim is asserted over **what the anchor resolves to and what the reproduction does**, never over what the investigation says about it. This is a change of layer, not a relaxation — the resolution table is a stricter check than reading two narratives side by side.
- **Test oracle:** `existing suite` (the Phase 1 anchor-resolution table).

## Phase 4: Type table + resolver

### 4.1 — `workflows.yaml`

- **File scope:** `orchestrators/skills/dae/workflows.yaml` *(new)*.
- **Pattern to follow:** §2.2's table verbatim. **One-line flow maps only** — no block mappings, no nesting beyond the inline `rigor:` map — so `sed`/`awk` can parse it under the no-`jq` constraint.
- **Acceptance criteria:** all ten type rows plus `default_type`. Exact skill names, no prose in cells. `rigor` cells per §2.2 (`code` implicitly `low` on every row). `analyze` carries `branch: docs/` so a publish-mode report has a prefix `workflow-setup.sh` already accepts.
- **Test approach:** every row parses under 4.3's suite; a malformed row fails loudly rather than silently yielding empty axes.
- **Test oracle:** `new contract tests` (via 4.3).

### 4.2 — `resolve-type.sh`

- **File scope:** `orchestrators/hooks/resolve-type.sh` *(new)*.
- **Pattern to follow:** `resolve-config.sh` — same parsing style, same `err()`/exit-code discipline, same no-dependency rule.
- **Acceptance criteria:** resolves a type (or alias) to its row; applies the **free / constrained / locked** override tiers; runs §2.1's five-step rigor resolution including per-phase patching and absent-phase handling (below); validates `against` arity per the row's `require|optional|forbid` and `--plan` placement (`pipeline: build` only); rejects `--pipeline` as locked and unknown flags outright. Resolves single-dash aliases and bracketed long-form prefixes **before** validation — `-r`, `--rig`, `--rigo`, `--rigor` all resolve to the rigor axis, `-a` to `--against` — and rejects a below-minimum prefix (`--r`) as an unknown flag rather than guessing at it. **All errors fire before setup**, with a plain-language ask. Prints resolved axes as `KEY=value` lines; the router consumes that output rather than interpreting the yaml itself.
- **Absent-phase rigor — warn and continue (D2, resolved; a deliberate exception to the "all errors" rule above).** A rigor entry that **explicitly names** a phase this run does not have (per §2.1's `f(pipeline, ship)` table) is dropped, a warning naming the phase and the type is written to **stderr**, and resolution **continues normally**. This case is a **warning, not an error**: it never aborts, never blocks setup, and **a non-zero exit for it is forbidden** — the "all errors fire before setup" sentence governs the error set (`against` arity, `--plan` placement, locked `--pipeline`, unknown flags), which this case is not a member of. The warning does **not** distinguish a user-typed `--rigor <phase>:<value>` from a row's map-form cell: both warn, both continue. "Explicitly names" means a `<phase>:<value>` entry — the step-2 scalar expansion to all four phases is not an explicit naming and drops silently, otherwise every `map` run would warn about the three phases its pipeline structurally cannot have.
- **Test approach:** 4.3.
- **Test oracle:** `new contract tests`.

### 4.3 — `tests/resolve-type.test.sh`

- **File scope:** `tests/resolve-type.test.sh` *(new)*.
- **Pattern to follow:** `tests/resolve-config-precedence.test.sh` — fixture dirs, assert-on-output helpers, one case per behavior.
- **Acceptance criteria:** covers scalar expansion to all four phases; per-phase patching **over** row defaults (an unmentioned phase keeps the row value, never falls to `low`); the mixed form `med,explore:high`; absent-phase dropping per `f(pipeline, ship)`; every constraint violation in 4.2; alias resolution — both **type** aliases (`debug` → `diagnose`) and **flag** aliases: `-r`, `--rig`, `--rigo`, `--rigor` each resolve to the rigor axis and `-a` to `--against`; `--r` is rejected as below the bracket minimum rather than resolved; and a stale anchor-style `-r <branch>` fails on the rigor value vocabulary rather than being silently accepted. **Absent-phase warning case (D2):** an explicitly named absent phase — e.g. `dae map --rigor pr:high`, whose `ship: chat` run has no `pr` phase — asserts **both** that the warning text is emitted on stderr (naming the dropped phase) **and** that the exit status is **0**, with the remaining axes still printed as `KEY=value` lines. A row's map-form cell naming an absent phase asserts the same pair, since the two are not distinguished. The scalar-expansion path asserts the opposite: no warning, exit 0.
- **Test approach:** the suite is the test.
- **Test oracle:** `new contract tests`.

## Phase 5: Committee + rigor

### 5.1 — The `committee` agent

- **File scope:** `orchestrators/agents/committee.md` *(new)*.
- **Pattern to follow:** `orchestrators/agents/builder.md` — the tree's existing mini-orchestrator agent that spawns cold sub-agents and consolidates. Same frontmatter shape (`name`, `description`, `model`), same "Invariants (authoritative — stated once, here)" structure.
- **Acceptance criteria:** implements §2.10 exactly. Skill-parameterised — owns fan-out, claim collection, matching by evidence location, dispute/singleton re-verification **against the source**, consolidation, and the §2.8 #1 worker envelope. Knows nothing about what it is verifying. `model: opus`; the N sub-agents inherit the **wrapped skill's** model. **Writes no verdict rounds of its own** — where it wraps a gate, that gate writes its own round exactly as at `rigor: low`.
- **Member identity and artifacts — stated ONCE here, authoritatively.** This subphase owns the convention; **5.2 and 5.3 consume it and must neither restate nor redefine it**, the same discipline that makes `dae/SKILL.md` the single shared touchpoint in 9.1.
  - **Every member writes a FILE; nothing is returned in-band.** A member's claims land on disk and its return is a **path**, never a payload — the same pointer-not-payload contract as `contracts/<lane-id>.md` and `reports/<lane-id>-exit.md` (§2.8 #5, `run-artifacts`). **The committee consolidates by reading the member FILES**, not member return values. A claim that exists only in an agent's return cannot be re-read by a resumed run, audited by a gate, or diffed by the consolidator.
  - **Member id is `c<n>`, exactly paralleling the lane's `l<n>`** — plain, unqualified, `c1`…`c5`. It stays that simple because **the committee type is a DIRECTORY, not a filename segment**: every committee gets its own dir under `committees/`, so member 1 of the explore committee and member 1 of the code-gate committee are both `c1` and cannot collide.
  - **Layout:** `<run-dir>/committees/<skill>/<kind>-c<n>.md` for per-member artifacts, with the committee-level files beside them in the same per-skill dir.

    ```
    <run-dir>/committees/explore/claims-c1.md      # member 1's claims
    <run-dir>/committees/explore/claims-c2.md      #   … c3 … c5 per tier
    <run-dir>/committees/explore/reverify.md       # committee-level: re-verification trace
    <run-dir>/committees/explore/accepted.md       # committee-level: consolidated artifact (§2.5 names it)
    <run-dir>/committees/review-code/claims-c1.md  # a different committee, same plain c1
    ```

    `<kind>` names the per-member artifact — today only `claims`; the committee-level files carry no `c<n>` because they belong to no member. On `ship: chat` runs the same relative layout lives under the scratch dir (§2.8 chat exception) — identical layout, only the root moves.
  - **`<skill>` is the wrapped skill's own `name:`, verbatim** (`explore`, `review-plan`, `review-code`, `review-pr`) — **derived, never a hardcoded enum**. It is a directory name rather than a filename segment now, but the requirement and its reason are unchanged: the committee is skill-parameterised and must not know the list, or 10.2's drill — a fourth skill wrapped with zero `committee.md` edits — would fail on the enum instead of proving genericity. A new committee type creates a new directory and nothing else.
  - **No round segment, deliberately — do not reintroduce one.** `review-code` sits inside the cap-3 revision loop, so the same committee type can stand up more than once in a run, and a later round simply **overwrites** the earlier round's files in that dir. This is a decision, not an oversight: a superseded review is stale and worth nothing, so losing it costs nothing, and nothing downstream consumes an old round's claims. A later implementer who wants round history must raise it as a design change, not add an `r<n>` segment on the assumption its absence was a gap.
  - **At `rigor: low` none of this exists.** No committee runs, so **there is no `committees/` directory at all** — no per-skill dir, no member file, no `accepted.md`. `c1` is **not** the solo path's name for itself: a `committees/` tree appearing on a `low` run is the diagnostic signature of the forbidden `committee(skill, n=1)` implementation (§2.1 implementation note), and 5.2's check (d) is precisely the assertion that catches it.
- **Test approach:** exercised by 5.2 and 5.3; its genericity is proven by 10.2 (a fourth skill wrapped with zero committee-side edits). The id contract is checked directly: a `med` run leaves exactly three member files `claims-c1…c3` under `committees/<skill>/`, a `high` run five, each non-empty, with `<skill>` equal to the wrapped skill's declared `name:`; the consolidated `committees/<skill>/accepted.md` cites them; and two committees of different types in one run produce two sibling directories, each with its own `c1`, nothing overwritten across types.
- **Test oracle:** `new contract tests`.

### 5.2 — `explore` emits claims; committee wraps it

- **File scope:** `agent-agnostic/skills/explore/SKILL.md`.
- **Already landed on the parent branch — NOT this lane's work.** The `agent: Explore` frontmatter pin was deleted from this file in commit `d24ac5e`, before any lane dispatched. That agent type carries no Write/Edit tool while the skill's core contract is writing the map to disk, so artifact *existence* was nondeterministic: in 1.1's four controlled runs both SHALLOW runs refused to write and returned the map inline, and both DEEP runs improvised a Bash heredoc (`<run-dir>/baseline/repro/RESULT.md`, contract finding F2). `explore` was the only skill in the tree pinning `agent:`; no `context: fork` skill pins one now (verified across all ten). **Lane 3 must not re-fix this and must not read its absence as a defect.** The file stays in scope because 5.2 still edits it — for the claims work below, and nothing else about the frontmatter.
- **Pattern to follow:** explore's existing map-to-disk + envelope contract. Depth (`AUTO`/`SHALLOW`/`DEEP`) is untouched — rigor is orthogonal to it.
- **Acceptance criteria:** claims are atomized and evidence-anchored (`file:line`). At `rigor ≥ med` the committee returns the **same artifact type** a solo explore returns, with claims as its evidence layer, so no downstream consumer branches on rigor. **The `low` path is not routed through the committee** — it is the existing code path, unchanged (§2.1 implementation note). Member files and their ids follow 5.1's convention; **5.2 does not restate it**.
- **Test approach:**
  - ***`low` path — four structural checks.*** The run must satisfy all four:
    1. **(a)** it reports `low`/solo mode and does **not** route through the committee;
    2. **(b)** it produces exactly **one** map artifact, at the requested path;
    3. **(c)** that artifact contains the required structured sections;
    4. **(d)** **no** claim files and **no** re-verification trace are emitted — those are the `med`/`high` markers (per 5.1, that means **no `committees/` directory exists at all** for this run — not an empty one, and no `c1` file inside one).
  - ***`med`/`high`.*** A map plus per-member claim files plus a re-verification trace for a seeded dispute; a seeded singleton is re-verified, never dropped.
- **Why the byte-for-byte oracle was dropped — a change of layer, not a weakening.** The original test approach read *"`low` output diffs byte-for-byte against the Phase 1 baseline."* 1.1 measured it and it is **empirically impossible**: four runs of the same path on identical input produced maps differing by **218 of 276 lines** (7855 vs 10581 bytes, different sha256) — `<run-dir>/baseline/repro/RESULT.md`. Byte-equality is a test for deterministic output; the artifact is generated prose, which has no canonical form, so that oracle would fail a correct implementation and pass a broken one at random. What 5.2 exists to catch is the plan's own stated worst case — ***"`low` must not be implemented as `committee(skill, n=1)`"*** — and that is a question of **which code path ran**, which checks (a)–(d) decide, not a question of prose wording, which no oracle can decide. The substitution is supported by the same capture: 1.1's routing probes were **8/8 unanimous across 3 independent trials**, so closed-vocabulary decisions are stable exactly where prose generation is not. Reading this as a relaxed check inverts it — the four checks test the property that matters; the byte diff never could.
- **Test oracle:** `new contract tests` at every tier. (Was `equivalence check` for `low`; retired for the reason above — the Phase 1 baseline cannot serve as a byte-level truth source for an LLM-authored artifact, and 1.1 records this consumer as not servable at that layer.)

### 5.3 — Gate skills: collector/gate tie-break + wrap

- **File scope:** `agent-agnostic/skills/review-plan/SKILL.md`, `agent-agnostic/skills/review-code/SKILL.md`, `agent-agnostic/skills/review-pr/SKILL.md`.
- **Pattern to follow:** `review-plan/SKILL.md` step 7's existing discipline — classify VERIFIED / UNCERTAIN / WRONG, and *"never silently upgrade UNCERTAIN to VERIFIED."* The tie-break is that rule surviving a committee, not a new rule.
- **Acceptance criteria:** each gate states that a claim still unverified at consolidation lands in `### Open questions` (with `next: needs-input` where it bars a verdict) and **never** as a blocking finding. Each still writes its own verdict round through `report-verdict.sh` at every rigor tier. **Wrapping all three requires zero edits to `committee.md`** — that non-change is the proof the abstraction holds.
- **Test approach:** a seeded singleton finding on each gate lands as an open question, not a blocking finding; `validate-report.sh` passes each gate's report at `low`, `med`, and `high`.
- **Test oracle:** `new contract tests`.

### 5.4 — `review-pr` docs-branch accuracy check

- **File scope:** `agent-agnostic/skills/review-pr/SKILL.md`.
- **Pattern to follow:** its own steps 3–5 structure (completeness → conventions → correctness).
- **Acceptance criteria:** the docs-only branch gains a check step that verifies the docs' **factual claims against source**. The map remains the *coverage* spec; the code becomes the *accuracy* oracle. **Round-4 addition — the spec sentence itself, not just a new step.** `review-pr/SKILL.md:27` still names *"an explore map (docs-only runs) — judge the diff against the map and the doc rules"* as the whole spec of record. Adding a check step while leaving that sentence intact lands the oracle split HALF-APPLIED: the file would simultaneously say the map is the spec and that the code is the accuracy oracle. Update it to match. The file is already 5.3/5.4's scope, so no boundary moves. **Verified gap:** its current step list has no such check, so a wrong fact faithfully copied from the map passes today.
- **Test approach:** a docs diff carrying a seeded fact that contradicts the code produces a blocking finding.
- **Test oracle:** `new contract tests`.

## Phase 6: Report pipeline

### 6.1 — `report.md` + skeleton + the `ship: chat` short-circuit

- **File scope:** `orchestrators/skills/dae/report.md` *(new)*, `orchestrators/skills/dae/report-skeleton.md` *(new)*.
- **Pattern to follow:** the existing middles — `document.md` for stage-numbered structure and for referencing (never restating) the shared setup/ship stages.
- **Acceptance criteria:** one file serves both `map` and `analyze` so they cannot drift. §2.5's five-part skeleton: question verbatim · method (depth/rigor, what was trusted) · findings (the only free-organization zone) · evidence (`file:line` per claim) · confidence + open questions. The `ship: chat` short-circuit skips Setup/Record/Ship and loads none of the publish seam; the scratch dir is defined **outside any worktree** (§2.8 chat exception) and must still exist on disk.
- **Test approach:** `dae map "..."` produces zero git side effects (no branch, no worktree, no commit) and is materially faster than `analyze` on the same question; `dae analyze --ship publish` produces a branch touching only `docs/reports/`.
- **Test oracle:** `new contract tests`.

## Phase 7: Plan handoff

### 7.1 — `plan-lifecycle.sh adopt` + tests

- **File scope:** `orchestrators/hooks/plan-lifecycle.sh`, `tests/plan-lifecycle.test.sh`.
- **Pattern to follow:** the script's existing subcommand structure (`locate`/`promote`/`archive`/`supersede`/`reopen`/`check`, each a `cmd_*` function with its own usage guard) and the existing fixture style in its test suite.
- **Acceptance criteria:** `adopt <path>` imports a plan into the run's namespace and records provenance in the plan front-matter *and* progress log — source run, source gate verdict, `explored_at` SHA, inherited `anchors:`. A plan with **no recorded gate approval** is not silently accepted: it surfaces the one conversational confirm the caller must hold.
- **Test approach:** extend `tests/plan-lifecycle.test.sh` in its existing style — adopt writes provenance; adopt of an ungated plan flags it; adopt does not move or mutate the source.
- **Test oracle:** `existing suite`.

### 7.2 — Staleness guard + cold-amend kickback routing

- **File scope:** `orchestrators/skills/dae/build.md`.
- **Pattern to follow:** build.md's existing kickback-routing prose and the "plan is amendable at ANY stage" invariant — staleness is one more amendment trigger, not a new mechanism.
- **Acceptance criteria:** `--plan` adoption skips planner spawn, the plan revision loop, and the plan gate — but **never** the mechanical plan check. Staleness = `git diff --name-only <explored_at>..HEAD` ∩ union of lane file scopes; empty → proceed, non-empty → forced amendment pass, re-gated if material. First `plan-wrong` on an adopted plan **cold-spawns** the source planner module with **paths only**, and that planner then stays warm for the rest of the run.
- **Test approach:** fast path — sync → accept → lane dispatch with no planner spawn and no plan gate. Guard — touch a file inside a lane's scope between sync and handoff; adoption forces amendment. Kickback — a seeded `plan-wrong` produces an amended plan from a cold spawn fed only paths, and a *second* `plan-wrong` routes by `SendMessage`.
- **Test oracle:** `new contract tests`.

## Phase 8: Docs workflow + reconcile grammar

### 8.1 — `document.md` PR-gate oracle split

- **File scope:** `orchestrators/skills/dae/document.md`.
- **Pattern to follow:** the file's own stage-4 prose.
- **Acceptance criteria:** stage 4 names **the map as the coverage spec and the code as the accuracy oracle**, replacing *"The PR gate's spec of record is the explore map."* **Verified defect:** a document run has two transformations (code→map, map→docs) and the gate currently audits only the second, so a wrong fact in the map is reproduced into the docs and passes correctly.
- **Also 8.1's, assigned in round 4 — the retired `map` alias in this file's own header.** `document.md:1` reads *"# document — the docs workflow (`--type document`, alias `map`, `doc`)"*, but the plan retires `map` as an alias off `document` (§2.5; 9.1's criteria; §2.12 item 2). That line had **no owner**: 9.1's file scope is `dae/SKILL.md` ONLY so it cannot reach it, and 8.1's criteria named only the stage-4 oracle split. Left unfixed, `document.md` keeps advertising an alias the router no longer routes — a live contradiction on the very surface 10.1's signature diff reads. **Drop `map` from the header, keep `doc`.** Assigned here because the FILE is already 8.1's exclusive scope, so this moves no scope boundary and cannot collide with another lane. Found by lane 6, which correctly refused to touch it until ownership was settled.
- **Test approach:** run the Phase 1 `document` baseline against a map carrying a seeded fact that contradicts the code; the gate must now catch it instead of confirming it.
- **Test oracle:** `new contract tests`.

### 8.2 — `plan-reconcile` emits full build grammar

- **File scope:** `orchestrators/agents/planner/plan-reconcile.md`.
- **Pattern to follow:** `orchestrators/agents/planner/plan-feature.md`'s per-subphase detail-block requirement — the grammar a builder needs to write a packet contract without asking anything.
- **Acceptance criteria:** emits the full build grammar — `(lane n)`, `(after:)` edges, **and** per-subphase detail blocks with oracle declarations. Lane names alone are not dispatchable. The requested-vs-delivered table gains a per-anchor column. This is what makes the §2.7 handoff zero-transform.
- **Test approach:** a sync run's promoted plan passes `validate-plan.sh` unmodified, and a builder handed one of its lanes writes a packet contract without asking a question.
- **Test oracle:** `existing suite` (`validate-plan.sh`).

## Phase 9: Integration

### 9.1 — `dae/SKILL.md` — the shared touchpoint

- **File scope:** `orchestrators/skills/dae/SKILL.md`. **This is the only subphase permitted to touch it.** Six lanes converge here; a lane editing it directly is a scope violation `verify-scope.sh` will catch at merge-back.
- **Pattern to follow:** the file's existing Flags and Workflow-selection tables.
- **Acceptance criteria:** flag table gains `--rigor` (scalar + per-phase), array `--against`, `--plan`, `--ship`; `--pipeline` documented as internal-only and never as a user flag. The router consumes `resolve-type.sh`'s output rather than interpreting `workflows.yaml` itself. Seam loading per §2.6. Alias flips land here: `debug`/`triage` → `diagnose`, and `map` off `document`. **Round-4 addition — `SKILL.md:59` specifically.** The PR-gate bullet still names *"document: the explore map"* as the whole spec of record, which is the map-only oracle 8.1 and 5.4 retire. 9.1 must update it so the split is applied on all three surfaces (`document.md` → 8.1, `review-pr/SKILL.md` → 5.4, `dae/SKILL.md` → here). Two of three would leave the router contradicting the skills it dispatches. Part 0 terminology adopted throughout — "workflow" stops meaning two things.
- **Flag aliases and bracket minimums (round 3, user-assigned).** `--rig[or]` with the short alias **`-r`** — `--rig`, `--rigo`, `--rigor` all resolve, per the vim-style bracket convention the table already documents (`dae/SKILL.md:24`). **`--against` takes `-a`**; `-r` is no longer an anchor alias (3.2). **Verified free against the current table** (`dae/SKILL.md:27-32`, which takes `-t`, `-e`, `-w`, `-r` → `--ref`, `-b`, `-n`): retiring `--ref` releases `-r`, and `-a`, `-p`, `-s` are unused anywhere in `orchestrators/skills/dae/`. **The `r` long-form prefix space is clear** — with `--ref` retired, `--rigor` is the only `r`-initial flag in the resolved set, so even `--r` would parse unambiguously. The minimum is nonetheless **`--rig`**, deliberately: a stale `--r`/`--ref` typed from muscle memory must ERROR rather than silently resolve to a different axis. Recorded so a later reader does not re-litigate `--r[igor]` as an oversight. **One collision not to resolve into:** `--plan` and `--pipeline` share the `--p` prefix, so neither bracket minimum may be `--p` (`--pla` / `--pip` at the shortest); `-p` and `-s` stay free for `--plan` and `--ship` if the table gives them aliases.
- **Test approach:** a feature run's context contains no `report.md` and no committee; `dae --type debug "auth randomly 500s"` routes to `diagnose.md`; `dae map` no longer routes to `document.md`.
- **Test oracle:** `new contract tests`.

### 9.2 — Doc sweep across the five real files, plus the `run-artifacts` rule

- **File scope:** `docs/architecture.md`, `docs/pipeline.md`, `docs/conventions.md`, `docs/README.md`, `orchestrators/AGENTS.md`, **`agent-agnostic/rules/run-artifacts.md`**, **`orchestrators/agents/planner.md`**, **`agent-agnostic/skills/review-pr/SKILL.md`**, **`orchestrators/agents/builder.md`**.
- **Pattern to follow:** each doc's existing register; `orchestrators/AGENTS.md` is the canonical pipeline guide (type list at `:39`, `--type` enum at `:88`) and the others summarize it. For the rule file, its own existing run-dir bullets — `contracts/<lane-id>.md` at `:28` and `reports/<lane-id>-exit.md` at `:29` — which state a path, who writes it, and what reads it.
- **Round-4 addition — `planner.md`'s oracle set is short by one, and it is the AUTHORITY.**
  `orchestrators/agents/planner.md:14` declares the oracle vocabulary as three values — `new contract
  tests` | `existing suite` | `equivalence check` — but this plan uses a **fourth**, `existing
  implementation` (§2.2.1, §2.8 #4), and **9.2 declares that very oracle for itself**. The tree
  therefore has planner modules offering a value their own authority does not list, and the builder's
  packet machine reads that field to size its contract-tester fan-out — so an unlisted value is not
  cosmetic. Add `existing implementation` to the set with the same one-line gloss style the other
  three carry. **Verified gap:** `planner.md` was in NO subphase's file scope; found by lane 6, which
  correctly refused to reach outside its own. It lands here for the same reason the `run-artifacts`
  rule does — 9.2 is serialized after every lane merges, so it records what shipped, and no lane's
  scope touches `orchestrators/agents/planner.md`.
- **Test approach for it:** `grep -n 'existing implementation' orchestrators/agents/planner.md`
  returns the added value, and the four values in `planner.md:14` match the set actually used across
  this plan's subphase detail blocks — checked by extracting every `**Test oracle:**` line from
  `plan.md` and diffing the distinct values against the module's list. **A value used but unlisted is
  a finding; a value listed but unused by THIS PLAN is NOT.** The oracle vocabulary is the UNION
  across all planner modules, not one plan's usage — `equivalence check` is unused here but is
  `plan-migration.md:7`'s declared default, and `plan-reconcile.md:24` already enumerates the full
  four-value closed set. Pruning a value this plan happens not to use would silently break the
  migration module. *(Corrected in round 4: the original wording said "listed but unused is a
  finding", which applied literally would have deleted `equivalence check`. Caught by the Phase 9
  builder, which declined to apply it literally and flagged it instead.)*
- **Round-4 addition — `review-pr/SKILL.md:20` is the ONLY actually-wrong description of `review-code`'s scope in the tree.**
  It reads *"that gate checks the build against the plan **lane by lane**"*, contradicted by
  `review-code/SKILL.md:17` (*"After every builder lane has merged…"*). §2.12 item 10 names this exact
  line and assigns the fix here; 9.2's reconciliation list already names "the conflicting descriptions
  of `review-code`'s scope". But the file was **not in 9.2's scope** — it was lane 3's (5.3/5.4), and
  lane 3 correctly left the line alone because neither of its criteria named it. **Without this, 9.2
  would certify by grep that "no doc still describes `review-code` as lane-scoped" — true of the five
  docs, false of the tree.** Fix is one clause: it checks the assembled implementation after every
  lane has merged. Found by the Phase 9 builder, which raised it rather than absorbing it.
- **Round-4 addition — `builder.md:24` has the same short oracle set as `planner.md:14`, and IS the consumer.**
  It enumerates three values — `new contract tests` (default), `existing suite`, `equivalence check` —
  omitting `existing implementation`. The stated rationale for fixing `planner.md` is that *"the
  builder's packet machine reads that field to size its contract-tester fan-out"*; `builder.md` IS that
  packet machine, so fixing the authority alone leaves authority and consumer disagreeing in the
  opposite direction. **Not hypothetical:** the Phase 9 builder hit it on this very run — 9.2 declares
  `existing implementation` and `builder.md` gave it no spawn shape, so it derived one from §2.2.1 and
  recorded that reading in `contracts/l9.md`. Add the fourth value **with its spawn shape**, matching
  the wording that lands in `planner.md:14`. Note §2.2.1's literal shape ("contract-tester only, no
  coder") is written for tests-only work and fits prose-derived-from-shipped-behavior poorly; say what
  the shape actually is rather than copying a clause that does not fit.
- **The rule file is BEHAVIOR, not documentation.** `agent-agnostic/rules/run-artifacts.md` is `domain: universal`, so `sync-install.sh` copies it to `~/.claude/rules/` on push and it is then loaded by every agent that declares it — including agents on runs that have nothing to do with this plan. Treat it with the same care as a skill edit: it is the only place the claim-file layout becomes binding on anyone who did not read this plan. It sits here rather than in a lane because 9.2 is serialized after every lane has merged, so `committee.md` (5.1) already exists and the rule can describe what shipped rather than what was intended, and because no lane's file scope touches `agent-agnostic/rules/` — putting it in one would manufacture the cross-lane collision Phase 9 exists to avoid.
- **Acceptance criteria:** Part 0 terminology adopted; run-shape diagram gains the chat branch; §2.3, §2.6, §2.8, §2.9 recorded as the review rules for future types. Two specific reconciliations: the conflicting descriptions of `review-code`'s scope (it runs **after every lane has merged** — it is not lane-scoped), and the `pipeline` naming collision with `docs/pipeline.md`, which uses the word for the whole run arc. **Verified:** the old Step 9's `agent-skills-architecture-overview.md` does not exist; those five files are the real doc surface.
- **Acceptance criteria — the `run-artifacts` rule addition.** The rule's run-dir contents list gains one bullet for committee artifacts, sibling to the `contracts/` and `reports/` bullets and in their style, stating exactly:
  - the path — **`committees/<skill>/claims-c<n>.md`**, one file per committee member, with the **committee type as a DIRECTORY** so every member id is a plain `c<n>` (`c1`…`c5`) that cannot collide across concurrent committees;
  - that **`<skill>` is the wrapped skill's own `name:`, verbatim — derived, never a hardcoded enum**, so a newly wrapped skill creates a new directory and nothing else;
  - the two committee-level files beside the members in the same per-skill dir — **`committees/<skill>/accepted.md`** (the consolidated artifact) and **`committees/<skill>/reverify.md`** (the re-verification trace) — which carry no `c<n>` because they belong to no member;
  - that a member **returns a path, never a payload**, and the committee consolidates by reading the files (the same pointer-not-payload contract the rule already states for contracts and exit reports);
  - that a later round of the same committee **overwrites** the earlier one's files, deliberately — a superseded review is stale and nothing consumes it, which is why there is no round segment in the name;
  - and that **none of it exists at `rigor: low`** — no `committees/` directory at all — because no committee runs. 5.1 is the authority for all of this; the rule states it, it does not redefine it.
- **Test approach:** `grep` proves no doc still describes `review-code` as lane-scoped and no doc uses "workflow" for both senses. For the rule, the same concreteness: `grep -n 'committees/<skill>/claims-c<n>.md' agent-agnostic/rules/run-artifacts.md` returns the new bullet; `grep -n 'rigor: low' agent-agnostic/rules/run-artifacts.md` returns the sentence stating no `committees/` directory exists there; and after `sync-install.sh`, `diff agent-agnostic/rules/run-artifacts.md ~/.claude/rules/run-artifacts.md` is empty — proving the behavior change actually reached the install rather than stopping at the repo.
- **Test oracle:** `existing implementation` (the shipped behavior is the truth source; docs and rules are derived from it — the rule describes the layout 5.1 shipped, never the reverse).

## Phase 10: Verification

### 10.1 — Regression against the Phase 1 baseline

- **File scope:** none — verification only.
- **Pattern to follow:** 1.1's signature extractor and pinned routing probes, re-run against the migrated tree.
- **Acceptance criteria:** the structural signature and the probe results reproduce, modulo exactly **two** intended differences:
  1. **`debug`/`triage` now route to `diagnose`.** This **includes `-t triage`**, which pre-migration is a stable **ERROR** — measured 3/3 trials, the router declines to coerce it to anything (`<run-dir>/baseline/signatures/routing-probe-results.md`). Its error → `diagnose` transition is part of intended difference #1, **not** a third difference. Counting it separately would make a correct migration look like a regression.
  2. **`map` is its own type**, no longer an alias off `document`.

  Any third difference is a regression and blocks. **`bugfix` and `diagnose` share the `bug/` branch type**, so setup-stage output alone cannot tell them apart: compare the **workflow/middle file and planner module** from the signature, never the branch prefix. A check written against branch name will report agreement it did not actually observe.
- **Test approach:** signature diff plus routing probes — **not** a transcript replay.
  - *Structural* — re-run `<run-dir>/baseline/bin/extract-signature.sh` against the post-migration tree and diff against `signatures/router-signature.txt`. It covers flags, the type-selection table, per-workflow stage sequences, both branch enums, anchor-flag occurrences, and the hook/suite inventory; every difference is discrete and attributable.
  - *Behavioral* — re-run the eight pinned probes (`<run-dir>/baseline/fixtures/routing-probes.md`). **P2, P6, and P8 must move** to their stated post-migration values; the controls **P1, P3, P4, P5, P7 must not move**. A control that moves is the blocking third difference.
  - *Why not replay-and-diff* — 1.1 proved LLM transcripts are not diffable (218 of 276 lines differed across identical runs), while the same capture measured routing probes at 8/8 unanimous across 3 trials. The signature+probe pair tests the same claim the original wording aimed at — that nothing changed except the two intended routing changes — on ground that can actually carry it.
- **Test oracle:** `existing suite` (the Phase 1 baseline's re-runnable oracles: the signature extractor and the probe set).

### 10.2 — The `audit` new-type drill

- **File scope:** `orchestrators/skills/dae/workflows.yaml` (one throwaway row, reverted after), one skeleton variant.
- **Pattern to follow:** §2.6's seam review rule — if a new type needs a skill outside the seams its row's axes name, the seam is misplaced.
- **Acceptance criteria:** a throwaway `audit` type — `{pipeline: report, explore: deep, rigor: {explore: med}, against: optional, ship: publish, branch: docs/}` — works with **one yaml row and one template, zero orchestration changes**. The row must carry a `branch:` prefix `workflow-setup.sh` already accepts, or the drill fails on the closed enum rather than on the design. Simultaneously proves committee genericity: the fourth wrapped skill requires zero `committee.md` edits. If either needed more, the migration is not done.
- **Test approach:** add the row, run it, revert it. Count the files changed outside the row and the template — must be zero.
- **Test oracle:** `new contract tests`.

## Risks, open questions, decision points

### Decision points — recorded decisions and remaining open questions (carried from §2.11)

**D1 — `document`'s spec of record has no gate. RESOLVED at the plan gate, round 1: option (a), rigor as substitute.** The question was real: every other run type's spec of record passed an independent gate before the PR gate leaned on it, while `document`'s explore map goes straight from explorer to spec. The user chose **(a)** — the `document` workflow **stays gate-free**, with **no human confirm step on the explore survey**. The hole is closed by the two automatic safeguards the plan already carries: `rigor: {explore: med}` on the `document` row in **4.1** (several agents produce the survey, their claims are cross-checked, and a singleton claim is re-verified against source rather than dropped), plus subphase **8.1**, which makes **the code the accuracy oracle at the PR gate** and demotes the survey to the coverage spec. **The accepted trade-off, stated plainly:** because both safeguards sit downstream of the survey, the catch lands *after* the docs are written — rework is later and larger than a confirm gate would make it. That is bought deliberately, in exchange for never interrupting a docs run with a human confirm. Option (b), a real map-confirm gate, is rejected for this reason and remains available if the trade proves wrong in practice. **No structural change: 4.1's type table already encodes (a), and 8.1 is unchanged.**

**D2 — an explicitly typed `--rigor <phase>:<value>` naming an absent phase. RESOLVED at the plan gate, round 1: warn and continue.** Neither of the original options was taken whole. Silent dropping loses the signal (`--rigor pr:high` on a `ship: chat` run probably meant `--ship publish`, and a run that quietly did not do what was asked is the failure mode the spec's flag strictness exists to prevent); erroring makes a cost dial fatal, which a **free**-tier axis must never be. The resolution is the middle: **emit a warning on stderr and continue** — the case is never fatal and never blocks the run, and a non-zero exit for it is forbidden. The proposed **row-default vs user-typed** distinction is **not adopted**: both warn, both continue, and the resolver never needs to know where the entry came from. The only line the rule draws is between an explicit `<phase>:<value>` naming (warns) and the step-2 scalar expansion (silent) — without that line, every `map` run would warn about three phases its pipeline structurally cannot have. **Landed in 4.2 (behavior, and its status as a deliberate exception to that subphase's "all errors fire before setup" rule) and 4.3 (a case asserting both the warning text and exit status 0).**

**D3 — `workflows.yaml` parsing.** Settled in this plan as `resolve-type.sh` + one-line flow maps + a test suite (4.1–4.3), because a table the router is merely *asked* to obey is prompt discipline, not enforcement, and acceptance criterion 1 promises parse-time errors before setup. Recorded here because it was an open question in rev 4 and the alternative — trusting the router — remains available if the resolver proves more trouble than it is worth.

### Risks

- **Markdown behavior has no executable oracle.** Most of this plan edits skill prose, where the only regression net is the Phase 1 baseline. Every subphase whose oracle is `existing suite` or `equivalence check` is exactly as good as 1.1's capture — which is why 1.1 blocks all six lanes rather than running alongside them.
- **Six lanes, one shared file.** `dae/SKILL.md` is the convergence point for the flag table, the router wiring, seam loading, and the alias flips. It is serialized into 9.1 by design. A lane that edits it opportunistically creates a merge conflict, and per §2.8 #6 *a conflict between independent lanes IS a scope violation* — stop, don't resolve past it.
- **The pre-push hook runs `sync-install.sh --full` on every push in this repo.** Any live-only block in `~/.claude/settings.json` (grants added during sessions, autoMode) is clobbered unless folded back into `agent-specific/claude/settings.json` first. Check before the push, not after.
- **`low` must not be implemented as `committee(skill, n=1)`.** Tempting for uniformity; it puts every currently-working behavior downstream of new code and destroys the only regression baseline this plan has. Called out in 5.2 and §2.1.
- **Alias flips are breaking.** `debug` moves from `bugfix` to `diagnose`. Anyone with muscle memory gets a different pipeline. Intentional (§2.2.3), but it lands in 9.1 where it is visible rather than buried in an early step.

## Skill mapping

| plan region | executed by |
|---|---|
| Amendments to this plan | `planner` (module `plan-feature`), warm across the revision loop |
| The plan gate on this file | `review-plan` (+ `validate-plan.sh`, `plan-lifecycle.sh check`) |
| Phases 2–8 (six lanes) | `builder` per lane, dispatching `coder` + `contract-tester` per packet |
| Phase 9 integration | `builder`, single lane, serialized |
| Phases 1 and 10 | `builder`'s own e2e/verification tail — no product writes |
| Post-build gate | `review-code` |
| Ship gate | `review-pr` (+ `verify-run-scope.sh`) |
| Landing | **`push-main`** — this repo uses no PRs; squash-merge to `main` locally, then `sync-install.sh` |
| Built here, exercised in 10.2 | `committee` (new, Phase 5) |


---

# Design reference

The rev 5 spec. This is the rationale behind every phase above; the plan is not readable as a design document without it. It is preserved as written except for the gate edits below, each marked in place. Where a marker and the surrounding prose disagree about whether something is still open, the marker and the plan's decision-points section win.

- **Round 1:** the D1 and D2 *resolution markers* (§2.1, §2.5, §2.11); the stale test-suite count in §2.11 D3.
- **Round 2:** the stale test-suite count in §2.12 item 14 — the fourth and last instance of it (see the status block at the top); and §2.4's `document` run shape, which read `explore(deep,low)` while §2.2's table has carried `rigor: {explore: med}` since rev 5. §2.2 is authoritative and 4.1 anchors to it, so nothing was ever going to be built wrong — but the diagram was contradicting the med-rigor cross-check that is *half the reason* D1 was resolvable without a confirm gate, so it is corrected rather than left as a cosmetic slip. Per §2.4's own legend (*"`rigor` decides whether the reconcile loop wraps explore"*), the row also gains the `⟳ reconcile` marker its two sibling `med` rows already carry; leaving that off would have swapped one contradiction for another.
- **Round 3 (post-approval):** the §2.1 "Retire `--ref` entirely" paragraph, whose *"Keep `-r` as the short alias if desired"* is superseded — `-r` now belongs to `--rigor` (`--rig[or]`), and `--against` takes `-a`. Marked in place; the assignment itself lives in 9.1, which owns the flag table. Also three **path markers**: §2.1, §2.8 #5, and §2.10 name the committee claim directory as `.artifacts/claims/`, which the user has since restructured to `.artifacts/committees/<skill>/` — 5.1 is authoritative, and each spot is marked rather than silently rewritten.

## Part 0 — Terminology (pinned; use these words exactly)

The current tree uses "workflow" for two different things. This spec splits them and never mixes them again:

- **type** — a preset row in the table (§2.2); the user-facing API (`--type rework`). Types differ by planner module, constraints, defaults, branch prefix.
- **pipeline** — which middle file executes (`build.md`, `diagnose.md`, `sync.md`, `report.md`, `document.md`); the execution *shape*. Many types share one pipeline (five types → `build.md`).
- **axes** — the knobs a pipeline reads (`explore`, `rigor`, `against`, `ship`, `plan`) that decide which skills and loops actually load.
- **skills / agents / scripts** — the components pipelines invoke, loaded per seam (§2.6).
- **committee** — the generic fan-out agent that runs N cold copies of *some other skill* and consolidates their claims (§2.10). It supplies structure only; the wrapped skill supplies substance. Loaded only at `rigor: med|high`.

**Naming caution (rev 5):** `docs/pipeline.md` in this repo already uses "pipeline" for the whole dae run arc, which is not what the axis means. Part 0's sense is the one this spec uses; Step 9's sweep must reconcile that doc, or the axis loses the disambiguation it was renamed to gain.

The hierarchy in one picture:

```
type (row, the API)          pipeline (middle file)        skills/loops
─────────────────────        ──────────────────────        ────────────
feature   ┐
bugfix    │
hotfix    ├──────────────▶   build.md          ──────▶  planner, builder lanes,
migration │                                             plan/code gates...
rework    ┘
diagnose  ────────────────▶  diagnose.md       ──────▶  planner, pick gate, lanes
sync      ────────────────▶  sync.md           ──────▶  planner, confirm gate
map       ┐
analyze   ┘──────────────▶   report.md         ──────▶  explore, skeleton
document  ────────────────▶  document.md       ──────▶  explore, record
```

The axis was previously named `output`; it is renamed **`pipeline`** everywhere because "output" invites reading it as *artifact footprint* (everything a run writes), which it never meant — see §2.9 for why footprint is not an axis at all. The former `answer | report` values collapse into a single `report` (they were always one file; the distinction was artifact-thinking).

## Part 1 — The Original Ask (verbatim intent, preserved for context)

The user wants `/dae` to support the following workflows. This is the requirements source of truth; the design in Part 2 must satisfy all of it.

- **document / doc-sync** — syncs docs with code. Only touches `/docs`, never modifies code, ALWAYS assumes code is right over documentation. Doesn't worry about changelogs/updates. Uses the `docs/*` branch name.
- **build** — builds a feature / bugfix / migration / rework based off a plan. A build's rework and a sync are basically the same thing, except a rework ALWAYS requires a point to go off of, whereas a sync can be generic.
- **debug (?)** — helps debug based off abstract/qualitative conditions and potentially a breaking-change commit. Debug and build's bugfix subtype share `bug/*` or `hotfix/*` branch naming, but debug is abstract while bugfix is "here is what is broken and where/how" (less exploring). **Resolution (§2.2.3): `debug` becomes an alias of `diagnose`; bugfix stays in build.**
- **triage / diagnose** — the first phase of debug but also standalone. Looks for bugs and ranks them by likelihood of being the issue; if no specifics given, finds any bugs it can and ranks by severity. The general version rates each finding on: security, scope (how often the code is used), and experience-breaking impact.
- **map** — explores the repo (same explore as document/build), spits out a quick report to the user. Similar to analyze but FAST. Depth: `--shallow` (docs only), `--deep` (code; may read docs but NEVER trust doc accuracy), `--auto`.
- **sync (?)** — takes Jira ticket(s) or a previous plan and reports requested vs. delivered, plus a reconciliation plan that can be kicked to a builder loop. (Generic no-input mode deferred; §2.2.4.) Own explore/plan loop; build loop identical to the build type's.
- **analyze** — answers a question about the current repo as a report. Code over docs, but looks at everything. Reports only, never plans. Base template with dynamic sections per question.
- analyze and sync use a **higher-accuracy explore** — multiple agents voting on which findings are accurate.
- **(rev 2)** Skills split along the seams of the type table so each run loads only what it needs.
- **(rev 2)** Easy path from a sync run's plan into a bugfix/rework build that skips the plan phase/loop, with a defensible answer on whether explore is skipped.
- **(rev 3)** `--against` accepts **multiple anchors**, not one.
- **(rev 3)** The original implementation's contract discipline must not get lost: **predefined contracts flowing from plans to builders, and state stored in files — never context — so interruption loses nothing.** §2.8 pins these.
- **(rev 4)** Raised: should the pipeline axis be an array, since build touches plan+code+tests+docs while a hypothetical `sync-tests` type would touch only tests? **Resolution: no — §2.9.** Footprint is constrained by planner modules and audited by scope scripts, never declared by the row.

Core requirement for the structure itself: **simple to use and understand, robust, and highly scalable — new types must reuse existing skills / loops / axes with near-zero new orchestration.**

## Part 2 — Target Design

### §2.0 The core idea

`dae` types are **presets over five orthogonal axes**. Skills implement axis values. Loops attach to axis values, never to types. A type is one row of defaults + constraints in a table. Adding a future type = pick a pipeline (reuses an existing middle), set four cells, maybe write a planner module. No new loops, no new orchestration.

The router remains a router: parse → resolve type → apply preset → validate constraints → load only the skills the resolved axes require (§2.6) → execute the middle keyed by `pipeline` → ship per `ship`.

### §2.1 The five axes (each a flag)

| flag | values | selects | override tier |
|---|---|---|---|
| `--pipeline` | `build` \| `plan` \| `report` \| `docs` | which middle file + record skill | **locked** (internal; never documented as a user flag) |
| `--explore` | `shallow` \| `deep` \| `auto` | explore **depth** | free |
| `--rigor` | scalar `low` \| `med` \| `high`, and/or per-phase `<phase>:<value>` over `explore` \| `plan` \| `code` \| `pr` | committee width (1 / 3 / 5) at each rigor-eligible phase | free |
| `--against` | **array** of anchors: git refs, Jira tickets, plan paths — repeatable flag and/or comma-separated | external anchors — §2.2.2 | constrained per type (`require` / `optional` / `forbid`) |
| `--plan` | path to a promoted, gate-approved plan | plan adoption — skips planner + plan gate; §2.7 | constrained: `pipeline: build` types only |
| `--ship` | `chat` \| `publish` | short-circuit vs. full Setup→Record→Ship | free where the type row allows; some types pin it |

**Unchanged and orthogonal:** `--worktree` (`new|resume [<name>]|none`) is **run continuity** — dae's own state (progress log, plan file, worktree). NOT an anchor. Opposite validators: a resume target must point at something *dae created*; an anchor must point at something *git / Jira / the filesystem can resolve*. If the log died with the worktree, say so plainly and reconstruct only what the plan dir, syllabus, and git history evidence — existing `worktree-modes.md` rule stands.

**Retire `--ref` entirely.** Grep the skill tree; replace every anchor-sense use with `--against`. *(Resolution marker, round 3: the "keep `-r`" option is superseded — the user assigned **`-r` to `--rigor`**, long form `--rig[or]`; `--against` takes **`-a`**. See 3.2 and 9.1.)*

#### Why explore split into depth × rigor

Depth and rigor are independent dimensions. Rigor is NOT a fourth depth value: map sometimes wants fast+deep, analyze always wants rigorous+deep; conflating them forces fake combinations. One `explore` skill takes both knobs; depth means the same thing at every rigor tier — one skill, no drift.

#### What rigor is for — the rule that decides where it attaches

> **Rigor is the oracle of last resort.** Use it where the only way to check a claim is for someone to go read, and one reader cannot read it all. Where a harder oracle exists — tests, a script, a diff — use that instead. A committee is strictly worse than execution.

A committee does two jobs at once, and both are load-bearing:

- **Overlap catches misjudgment.** Where N readers read the same thing and disagree, the disagreement is the signal.
- **Union catches omission.** Cold-forked readers do not read the same files — each picks its own search path — so the primary yield of fanning out is *coverage*, not agreement.

Two rules follow:

1. **The committee allocates verification budget; it does not vote truth into existence.** A majority never makes a claim true. It decides which claims are worth a second, targeted read **against the source**. Disputes are resolved by going to look, never by a second vote.
2. **The threshold is a routing rule, never a rejection rule.** Nothing is discarded for lack of votes. A singleton — one reader found what the others never looked at — is precisely the rare finding the fan-out was bought for. It gets re-verified, not dropped.

#### Rigor tiers (1 / 3 / 5 agents)

Always odd — odd panels guarantee a strict majority on every claim; "tie" is unreachable and the consolidator needs no tiebreak rule. Only the three names are exposed (no raw `N`) — that is how oddness is enforced without a validation rule.

| tier | agents | machinery | accept threshold | re-verify |
|---|---|---|---|---|
| `low` | 1 | none — the existing solo path, **unchanged** | n/a | n/a |
| `med` | 3 | claims → `committee` consolidation | ≥ 2 of 3 | disputed + singleton claims |
| `high` | 5 | claims → `committee` consolidation | ≥ 3 of 5 | disputed + minority claims |

`low` is **not** "a committee of one." It is the existing code path, untouched, and the `committee` agent is not loaded at all (§2.6).

> **⚠ ROUND-4 RESOLUTION MARKER — the `low` oracle (this marker WINS over any surrounding rev 5 prose).**
> The rev 5 spec preserved below asserts in several places that `low`'s output is **byte-for-byte**
> identical to pre-migration, and directs verification by transcript spot-check and artifact diff.
> **That oracle is retired.** Phase 1.1 measured it impossible: four controlled `explore` runs with
> identical inputs produced maps differing by **218 of 276 lines** (7855 vs 10581 bytes, different
> sha256), and both SHALLOW runs wrote no file at all. Generated prose has no canonical form, so
> byte-equality tests a property the artifact never had.
>
> **What is UNCHANGED and still binding:** `low` IS the existing solo path, it is NOT routed through
> the committee, and implementing it as `committee(skill, n=1)` remains prohibited — that
> prohibition is the whole point and it is stronger than ever.
>
> **What replaced the oracle:** 5.2's four structural checks — (a) solo routing, no committee;
> (b) exactly one map artifact at the requested path; (c) required sections present; (d) **no
> `committees/` directory exists at all**. A change of LAYER, not a weakening: the question "did the
> cheap path get silently reimplemented on new code" is about WHICH CODE PATH RAN, which these
> decide, not about prose wording, which no oracle can decide.
>
> Recorded because lane 4's coder read the stale half in good faith and wrote a false claim into
> `report.md` (caught and fixed in-lane). **5.2 and 10.1 read these same lines.**

> **Implementation note (rev 5, load-bearing).** Do NOT implement `low` as `committee(skill, n=1)` for uniformity. Doing so puts every currently-working behaviour downstream of new code and destroys the regression baseline Step 4 checks against *(round 4: the baseline is still load-bearing and this prohibition still stands verbatim; only its ORACLE changed — see the marker below)*. `low` = invoke the skill directly. `med|high` = invoke it through the committee.

Mechanics at `rigor ≥ med` are the `committee` agent's, described once in §2.10. Claim files live under `.artifacts/claims/` on publish runs and in the scratch dir on chat runs — **files, not context** (§2.8 #5) — and the consolidated artifact is passed onward as a **path**. *(Path marker, round 3: the directory is `.artifacts/committees/<skill>/`, not `.artifacts/claims/` — member files `claims-c<n>.md`, committee-level `accepted.md`/`reverify.md`. See 5.1, which is authoritative.)*

#### Where rigor attaches — four phases

Rigor is eligible at four points. Which of them **exist** for a run is a function of the pipeline *and* the ship axis:

| pipeline | `explore` | `plan` | `code` | `pr` |
|---|---|---|---|---|
| `build` | ✓ | ✓ | ✓ | ✓ |
| `plan` (diagnose/sync) | ✓ | ✓ | ✓ | ✓ |
| `docs` | ✓ | — | — | ✓ |
| `report` | ✓ | — | — | only at `ship: publish` |

Each point is justified by a *different* argument, which is why they are set independently rather than derived from one another:

- **`explore`** — nothing downstream ever re-reads the map; it is the widest read in the run.
- **`plan`** — cost asymmetry, not absence: later gates do catch a wrong fact, but by then it has been built.
- **`code`** — the surface is the whole assembled implementation (`review-code` runs *after every lane has merged*, not per-lane), and two of its checks have no oracle at all: cross-lane duplication — a defect class lane blindness deliberately *manufactures* — and the kickback routing call (`impl-wrong` vs `plan-wrong` vs `map-wrong`), which routes the entire run.
- **`pr`** — last line of defence; after it passes, `finalize` ships.

**`code` defaults to `low` in every row.** It is addressable, so the capability exists for a multi-lane run or a second consecutive `impl-wrong`, but no default run pays for it. Two reasons: `review-code` sits inside the cap-3 revision loop, so a committee there can run three times where explore runs once; and a false rejection is most expensive here — at `code` it redispatches builders, at `pr` it costs a round on an otherwise-finished run, at `plan` it costs a planner round with no code yet written. Severity orders **`code` > `pr` > `plan`**.

#### Rigor resolution

```
1. profile <- the type row's rigor profile                       (the default)
2. if a scalar was given:  profile <- {explore: v, plan: v, code: v, pr: v}
3. for each <phase>:<value> override:  profile[phase] <- value   (patch, not replace)
4. drop phases this run does not have (per the table above)
5. emit RIGOR_EXPLORE / RIGOR_PLAN / RIGOR_CODE / RIGOR_PR
```

Step 3 patches **over** whatever is already there: `--rigor explore:high` sets explore and leaves plan, code, and pr at their row defaults. An unmentioned phase never falls to `low`. Scalar-then-patch ordering makes the mixed form work with no special case — `--rigor med,explore:high` is "everything med except explore."

Step 4 drops **silently** where the phase was never named explicitly — i.e. the step-2 scalar expansion. *(Resolution marker, gate round 1: §2.11 D2 is settled — an **explicitly named** `<phase>:<value>` the run does not have is dropped **with a warning on stderr**, and the run continues; never an error, and the row-default/user-typed distinction is not adopted. See the plan's decision-points section and subphase 4.2.)*

Row format follows the same scalar-or-explicit pattern as `--against`: a bare scalar expands by the step-2 rule, and the map form appears only where phases actually diverge.

```yaml
feature:   {... rigor: low ...}                # all four low
document:  {... rigor: {explore: med} ...}     # the rest stay low
```

#### Wrapping a collector vs. wrapping a gate — the one divergent rule

Three of the four attachment points wrap **gates** (`review-plan`, `review-code`, `review-pr`); only `explore` wraps a **collector**. The algorithm is identical. Exactly one tie-break diverges — what happens to a claim that reaches the end still unverified:

- **Collector** — include it, flagged unverified. A marginal claim in a map is cheap and informative.
- **Gate** — it **cannot block**. It lands as an open question, never as a blocking finding.

This needs no new machinery. It is existing gate discipline (`review-plan` step 7 already classifies claims VERIFIED / UNCERTAIN / WRONG and forbids silently upgrading UNCERTAIN) expressed in the vocabulary the report scripts already enforce: `next: needs-input` backed by a non-empty `### Open questions`, with `validate-report.sh` requiring `blocking >= 1` for any other rejection. The committee's only obligation is to **preserve** that discipline rather than let majority-voting override it — and because the rule belongs to the wrapped skill, the committee itself never learns what a gate is.

Without this rule, fan-out on a rejecting gate inflates false positives: N reviewers produce the *union* of their blocking findings, every extra blocking finding costs a revision round, and runs that would have passed solo get pushed toward cap-3 human escalation.

Default `med` at `explore` where accuracy is the point (analyze, sync, document); `high` is a manual escalation (five deep readers is real cost).

#### Override tiers (the anti-vibecoding contract)

- **Free** (`--explore`, `--rigor`): cost/quality dials; overriding cannot produce an incoherent run. This is the escape hatch that prevents type proliferation.
- **Constrained** (`--against` per column; `--plan` on `pipeline: build` only): validated mechanically at parse time, before setup. Violation = error + plain-language ask, same severity as an unknown flag.
- **Locked** (`--pipeline`): a type IS its pipeline. `dae map --pipeline build` is a category error, not a customization.

**Interface rule:** types are the API; axes are internals. `--pipeline` never appears in user-facing docs.

### §2.2 The type table (the entire preset system)

```yaml
# workflows.yaml — structurally boring on purpose: exact skill names, no prose in cells,
# executed imperatively ("exactly the row for this type"), no interpretive gap.
types:
  feature:   {pipeline: build,  explore: auto, rigor: low,                against: forbid,   ship: publish, planner: plan-feature,   branch: feature/}
  bugfix:    {pipeline: build,  explore: auto, rigor: low,                against: optional, ship: publish, planner: plan-bugfix,    branch: bug/,     aliases: [bug]}
  hotfix:    {pipeline: build,  explore: auto, rigor: low,                against: optional, ship: publish, planner: plan-bugfix+minimal-scope, branch: hotfix/}
  migration: {pipeline: build,  explore: auto, rigor: low,                against: forbid,   ship: publish, planner: plan-migration, branch: feature/}
  rework:    {pipeline: build,  explore: auto, rigor: low,                against: require,  ship: publish, planner: plan-rework,    branch: feature/}
  diagnose:  {pipeline: plan,   explore: deep, rigor: low,                against: optional, ship: publish, planner: plan-diagnosis, branch: bug/,     aliases: [debug, triage]}
  map:       {pipeline: report, explore: auto, rigor: low,                against: forbid,   ship: chat}
  analyze:   {pipeline: report, explore: deep, rigor: {explore: med},     against: forbid,   ship: chat,    branch: docs/}   # --ship publish allowed: report committed under docs/reports/
  document:  {pipeline: docs,   explore: deep, rigor: {explore: med},     against: forbid,   ship: publish, branch: docs/,   aliases: [doc]}
  sync:      {pipeline: plan,   explore: deep, rigor: {explore: med},     against: require,  ship: publish, planner: plan-reconcile, branch: sync/}

default_type: feature   # when nothing is inferable and the ask is purely additive
```

**Reading the `rigor` cell (rev 5).** A bare scalar expands to all four phases; the map form names only the phases that diverge, and every unnamed phase is `low`. So `code: low` holds for every row above — addressable, never a default cost (§2.1).

**`branch:` on `analyze` (rev 5, verified).** `analyze --ship publish` needs a worktree, and `workflow-setup.sh:65-66` validates `--type` against a **closed enum** (`feature|bug|hotfix|docs|sync`), with `allow-workflow-cleanup.sh:90` hardcoding the matching globs. Reusing the existing `docs/` prefix — the report lands under `docs/reports/` anyway — keeps the Step 10 `audit` drill honest at one yaml row with **zero** script edits. Widening the enum instead is the alternative; it is a deliberate one-time change, not something a new row may do implicitly. `map` is `ship: chat` and needs no prefix.

`pipeline: plan` resolves to `diagnose.md` or `sync.md` by planner module (two files until a third plan-pipeline type appears, then factor into `reconcile.md`).

#### 2.2.1 The `planner` column, explained

The plan **phase** is shared structure — spawn `planner` (opus, **warm**; revisions arrive by `SendMessage`, never a respawn) ‖ `init-workspace`, revision loop capped at 3, `review-plan` gate, `promote` via `plan-lifecycle.sh`. Identical for every type that has it. The planner **module** is the domain-knowledge insert the warm planner loads: it defines *what this type's plan must contain to pass its gate*. Structure is never per-type; content requirements are.

| module | type | plan must contain |
|---|---|---|
| `plan-feature` | feature | scope; lane syllabus with `(lane n)` + `(after:)` edges; **per-subphase detail blocks** (interfaces, behaviors, acceptance criteria, test-oracle declaration) that builders decompose into packet contracts |
| `plan-bugfix` | bugfix | reproduction; root-cause statement; fix scope (what it deliberately does NOT touch); regression-test lane |
| `plan-bugfix+minimal-scope` | hotfix | plan-bugfix + minimal-scope module: smallest diff, no opportunistic cleanup |
| `plan-migration` | migration | before/after shape; ordered steps; rollback strategy; `equivalence check` oracle declarations |
| `plan-rework` | rework | analysis of each anchor (what shipped); delta statement; preservation list (behavior that must NOT change); `existing suite` oracle where applicable |
| `plan-diagnosis` | diagnose | ranked candidate report — likelihood, evidence, security / scope / experience-breaking ratings. **The report IS the plan** (it is the run's `plan.md`; there is no separate diagnosis record kind). |
| `plan-reconcile` | sync | requested-vs-delivered table per anchor (done / partial / dropped / diverged, each with evidence) + reconciliation syllabus. **MUST emit the full build plan grammar** — `(lane n)`, `(after:)` edges, *and the per-subphase detail blocks and oracle declarations builders need to write packet contracts* (§2.8). Lane names alone are not dispatchable. This is what makes the §2.7 handoff zero-transform. |
| *(none)* | map, analyze, document | no plan phase exists in these middles |

**Test oracles** a subphase may declare (the builder varies sub-agent spawning by this — an existing seam):

| oracle | spawns | truth source |
|---|---|---|
| `new contract tests` (default) | coder + contract-tester per packet | the contract |
| `existing suite` (rework) | coder only | pre-existing tests |
| `equivalence check` (migration) | coder only; builder does the read-through | old behavior |
| `existing implementation` *(new — tests-only work, §2.9)* | **contract-tester only, no coder** | shipped code's observed behavior + docs, expressed as contracts |

The planner column is the **only** legitimately per-type behavioral field (branch prefix is naming, aliases are routing). Anything else a type "does differently" must be an axis value or a planner-module constraint — enforce in review.

#### 2.2.2 The `against` column, explained — an array

`--against` answers: **"what already-existing things is this run reasoning about?"** Anchors point at *product* history — merged PRs, commit ranges, Jira tickets, old approved plans — things that exist whether or not dae ever ran. Multiple anchors are first-class:

- `dae sync --against PROJ-482,PROJ-490` — one delivery reconciled against two tickets; the requested-vs-delivered table gets an anchor column.
- `dae rework --against '#341' --against .plans/checkout-v1/plan.md` — the plan states the intent, the PR states what shipped; plan-rework analyzes both.
- `dae diagnose --against abc123f --against def456a` — two suspect commits narrow the hunt.

Mechanics:
- Repeatable flag and comma-separated both accepted; order preserved.
- `resolve-anchor` resolves **each item independently** to a typed pointer — `{kind: git|jira|plan, raw, resolved}` (`git rev-parse` / ticket lookup / file existence). **All-or-nothing:** one unresolvable anchor fails the whole parse — a silently dropped anchor is worse than an error.
- Resolved anchors are written to the run's plan front-matter and progress log as an `anchors:` block — **on disk, not held in context** (§2.8) — so a resumed or amended run reasons about exactly the same set.

The column value is the parse-time constraint on the array:

| value | meaning | on violation |
|---|---|---|
| `require` | array must be non-empty — no "rework" relative to nothing, no "requested vs delivered" without a *requested* | error before setup; ask conversationally |
| `optional` | zero or more; anchors sharpen the run, absence doesn't break it | proceed |
| `forbid` | type doesn't consume anchors; any being passed signals a different type was meant | error: "did you mean rework/sync?" |

#### 2.2.3 Alias changes (breaking, intentional)

1. `debug`, `triage` → `diagnose` (was: `debug` → `bugfix`). Cause known → bugfix; cause unknown → diagnose. The line stands.
2. `map` stops aliasing `document` — own type, own pipeline, own ship profile.

#### 2.2.4 Resolved design questions

- *bugfix under debug?* No — would duplicate the entire build middle for a planner-module difference. Alias move gives the behavior without the duplication.
- *rework separate?* No — `against: require` is a cell, not a row.
- *sync generic mode:* **deferred, not rejected.** v1 = `against: require`. The sweep, when added, goes behind an explicit flag with the invariant amended to "never a *silent* sweep: inferred scope must pass a gate before planning."
- *pipeline as an array?* No — §2.9.

### §2.3 Loops attach to axis values

| loop | attaches to | notes |
|---|---|---|
| plan revision loop (warm planner ↔ `review-plan`, cap 3, then human) | any middle with a planner | skipped under `--plan` adoption (§2.7) |
| build lane loop (builder-internal packet loop; only its own e2e tail exits) | `pipeline: build` | unchanged per `build-dispatch.md` |
| code gate loop (`review-code`; `impl-wrong`→lane redispatch from its contract, `plan-wrong`→planner, `map-wrong`→re-explore) | `pipeline: build` | `plan-wrong` target differs for adopted plans — §2.7 |
| PR gate loop (`review-pr`, cap 3; **mandatory on every publish run**) | `ship: publish` | now conditional on the ship axis |
| committee consolidation loop | `rigor: med\|high` at any of the four phases (§2.1) | new — `committee` agent, §2.10; attaches to the RIGOR VALUE, never to a phase name or a type |
| pick gate ("none" is a valid outcome; report still promotes and ships) | `planner: plan-diagnosis` | existing |
| confirm gate (done / partial / dropped / diverged, each with evidence) | `planner: plan-reconcile` | existing |

No loop names a workflow type. That rule is what makes new types free — enforce in review.

### §2.4 Per-type run shapes (loops + axes, resolved)

`⟳` marks a loop; gates in **bold**.

```
feature / migration        explore(auto,low) → ⟳ plan loop → **plan gate** → lanes ⟳ → **code gate** ⟳ → record → **PR gate** ⟳ → finalize
bugfix / hotfix            same; optional anchors narrow explore; hotfix planner adds minimal-scope
rework                     same; anchors REQUIRED; plan-rework analyzes the anchors first
bugfix/rework via --plan   [staleness guard §2.7] → lanes ⟳ → **code gate** ⟳ → record → **PR gate** ⟳ → finalize        (no explore, no plan loop)
diagnose                   explore(deep,low) → plan-diagnosis (ranked report = plan.md) → **pick gate** → lanes ⟳ (picked only) → **code gate** ⟳ → record → **PR gate** ⟳
map                        explore(auto,low) → report skeleton → chat + scratch file                                        (zero gates, zero git side effects)
analyze                    explore(deep,med) ⟳ reconcile → report skeleton → chat        [--ship publish: + record → **PR gate** ⟳]
document                   explore(deep,med) ⟳ reconcile → record pass (docs tree + symlinks + changelog only) → **PR gate** ⟳   (open-draft fires at the record commit)
sync                       explore(deep,med) ⟳ reconcile → plan-reconcile → **confirm gate** → record → **PR gate** ⟳ → [offer handoff §2.7]
```

Read a row by its axes: `pipeline` picks the middle and its gates, `rigor` decides whether the reconcile loop wraps explore, `ship` decides whether the publishing arc exists, `planner` decides which plan loop and which human-gate flavor.

### §2.5 The four middles (keyed by `pipeline`)

**`build` → `build.md` — UNCHANGED** except the `--plan` adoption entry (§2.7). All existing structure and invariants stand verbatim: setup → warm planner ‖ init-workspace → plan gate → promote → open-draft → event-driven lanes (no wave barriers; `(after:)` edges ARE the schedule) → per-lane merge-back in the load-bearing order (verify-scope → merge, where *a conflict IS a scope violation* → tick syllabus → progress log → `push-pr --stage update` → only then lane cleanup, deferred on failed push) → code gate → record → ship. Note the pipeline is named for its *shape*, not its footprint: one build run legitimately writes plan, code, tests, and docs, and archives the plan — that is `build.md` plus `plan-lifecycle.sh` doing their jobs, not multiple pipelines composed (§2.9).

**`report` → `report.md` — NEW FILE.** One file serves map and analyze; same pipeline at different presets, cannot drift apart. Flow: explore (per depth+rigor) → fixed skeleton → deliver per `--ship`. Skeleton (frozen frame, dynamic interior): 1. Question as asked (verbatim) · 2. Method (depth/rigor, what was trusted; docs explicitly distrusted when deep) · 3. Findings (sections dynamic per question — the model's only free-organization zone) · 4. Evidence (`file:line` per claim; rigor ≥ med sources from `accepted.md`) · 5. Confidence + open questions. General-triage findings carry the security / scope / experience-breaking ratings. `chat` = answer in chat + scratch file; `analyze --ship publish` = `docs/reports/` via record→ship.

**`plan` → `diagnose.md` and `sync.md` — LIGHTLY TOUCHED.** Shapes stand: explore → planner writes report-that-IS-the-plan → human gate (pick / confirm) → promote (preserved even on "none") → lanes in-run (diagnose) or handoff (sync, §2.7). Changes: sync at `rigor: med`; both consume the `--against` array; `plan-reconcile` emits full build grammar (§2.2.1).

**`docs` → `document.md` — MOSTLY UNCHANGED.** Deep explore → map-driven record pass → ship. Read-only outside `/docs`; code always right over docs; PR-gate scope boundary stays "nothing outside the docs tree, symlinks, and changelog." Changes: drop the `map` alias, and split the PR gate's oracle (below).

**The PR-gate oracle split (rev 5, verified).** `document.md` step 4 currently makes the **explore map** the gate's entire spec of record: *"The PR gate's spec of record is the explore map: the doc changes must reflect it."* A document run has **two** places to be wrong —

```
code ──(stage 2: explore)──▶ map ──(stage 3: record)──▶ docs
```

— and that gate audits only the second. Map→docs is a paraphrase with both artifacts in front of the reviewer (low risk, easy to audit); code→map is a read of the whole repo whose source is in front of nobody downstream (high risk, never re-checked). A wrong fact in the map is reproduced faithfully into the docs and passes the gate correctly.

The gate is not *fenced off* from the code — it carries `verify-dont-assume`, and its step 4 verifies conventions from manifests and neighbouring code — but **nothing directs it to check the docs' factual claims against source**, and the one check that is specified (completeness) is map-anchored. So the fix is two halves:

1. `document.md` step 4 names **the map as the coverage spec and the code as the accuracy oracle**.
2. `review-pr`'s docs-only branch gains an actual check step for verifying prose claims against source; its current step list has none.

This is why `document` carries `rigor: {explore: med}` — see §2.11 D1. *(Resolution marker, gate round 1: D1 is settled as option (a). Rigor there is a **mitigation accepted as the fix** — `document` stays gate-free, and the catch lands after the docs are written.)*

### §2.6 Skill inventory — cut along the seams

Loading rule: **the router loads only its own `SKILL.md` + `workflows.yaml` (+ `resolve-config.sh`). Type resolution loads exactly one middle file. Each middle references, by pointer, only what its resolved axes require.** Nothing loads "just in case": a map run carries zero build machinery, a `low` run never loads the `committee` agent, a chat run never sees the publisher. Sub-agents are cold forks receiving pointers, not payloads.

This table is reconciled against the **actual current tree** (sibling files, cold forks, agents, scripts, rules); items marked *(new)* are the only additions.

| load condition | what loads |
|---|---|
| **always (router)** | `dae/SKILL.md`, `workflows.yaml` *(new)*, `resolve-type.sh` *(new — §2.11 D3)*, `resolve-config.sh`; declared rules: `verify-dont-assume`, `model-policy`, `artifact-locations`, `run-artifacts`; `workflow-diff-check.sh` stays wired on `Stop` via frontmatter |
| `pipeline: build` | `build.md`, `build-dispatch.md`, `worktree-modes.md`; `builder` agent (sonnet — itself spawns `coder` + `contract-tester`; dae never spawns those); `init-workspace`; `plan-lifecycle.sh`, `mark-syllabus.sh`, `verify-scope.sh` |
| `pipeline: report` | `report.md` *(new)* + skeleton template(s) *(new)* |
| `pipeline: plan` | `diagnose.md` **or** `sync.md` (per planner module, never both) |
| `pipeline: docs` | `document.md` |
| `planner: <module>` | `planner` agent (opus, warm) + exactly the one `plan-*` module named by the row; `review-plan`; `report-verdict.sh` + `validate-report.sh` (gate report contracts) |
| `pipeline: build` gates | `review-code` (+ the same two report scripts) |
| `rigor: med\|high` **at any phase** | the `committee` agent *(new — §2.10; generic, wraps whichever phase skill the profile names; envelope return; claim files per §2.1)*. Nothing else changes per phase: the wrapped skill is the one that phase already loads. |
| `--against` non-empty | `resolve-anchor` *(new, thin: per-item rev-parse / ticket lookup / path check → typed pointers → `anchors:` block on disk)* |
| `--plan` present | `plan-lifecycle.sh adopt` *(new action)* + staleness guard (§2.7) |
| `ship: publish` | `workflow-setup.sh` (parent worktree, `RUNDIR:` line, committed-`.gitignore` handling), `push-pr` (sole publisher: `open-draft`/`update`/`finalize` with the existing confirmation cadence; **`finalize` mechanically refuses without a validated, passing `pr-review.md`** — see §2.8 #8), `comment-pr`, `review-pr` (**mandatory before finalize, on every publish run without exception**), `verify-run-scope.sh` (UNCLAIMED = blocking), `cleanup-merged` (the **only** teardown, post-merge) |
| docs target is Confluence | `confluence-mode.md`, `document-confluence` (domain-gated, not universal); else `document-local` |

Genuinely new: `committee` *(agent)*, `resolve-anchor`, `resolve-type.sh` + `workflows.yaml`, `report.md` + skeletons, `plan-lifecycle.sh adopt`. Everything else is the existing tree re-seamed, not rewritten. **`reconcile-claims` is gone** — rev 4's dedicated reconciler is subsumed by the generic committee (§2.10), which is one fewer new component, not one more.

**Seam review rule:** if a new type would require touching a skill outside the seams its row's axis values name, either the type's design is wrong or a seam is misplaced. Fix the seam — never special-case the skill.

### §2.7 Plan handoff: sync → bugfix/rework without re-planning

Sync ends holding a promoted, human-gated plan in full build grammar (§2.2.1). Re-planning it in a build run would be waste *and* drift risk. Adoption skips exactly the phases whose work already happened — and nothing else.

**Entry points (same mechanism):**
1. **Inline offer** at sync's ship stage: "N genuine gaps confirmed; hand off to a build run?" On accept, dae starts the build run, defaulting `--type rework`, inheriting sync's full `anchors:` array (provenance stays connected).
2. **Standalone:** `dae bugfix|rework --plan <path>` any time later.

**Mechanics:**
- `plan-lifecycle.sh adopt <path>`: import the plan into this run's namespace; record provenance in the plan front-matter *and* progress log — source run, source gate verdict, `explored_at` SHA, inherited `anchors:`. The current plan path then travels in every message exactly as today.
- `validate-plan.sh` (or the tree's equivalent mechanical plan check) **still runs.** Adoption skips human judgment that already happened — never mechanical well-formedness. Lane annotations, `(after:)` edges, and subphase detail blocks must all parse; this is the proof that plan-reconcile's grammar requirement held.
- **Skipped:** planner spawn, plan revision loop, plan gate. The confirm gate WAS this plan's approval.
- **Not skipped:** everything downstream is stock `build.md` — builders write their own packet contracts from the plan's detail blocks into `.artifacts/contracts/<lane-id>.md`, contract-testers stay implementation-blind, exit reports, verify-scope, the merge-back order, `verify-run-scope.sh` at the PR gate. **Adoption changes where the plan came from, never how it is executed** (§2.8).
- Draft PR opens at adoption; then straight to lane dispatch.
- A `--plan` pointing at a plan with **no recorded gate approval** (hand-written, or from an aborted run) requires one conversational confirm: "no gate approval on record — treat as approved?"

**The explore question — a rule, not a vibe:** parent-level explore exists to feed a planner; no planner, no parent explore. Builders explore their own lanes per contract anyway, seeded with pointers to the sync run's artifacts (accepted-claims file, sync-report). So explore is **skipped by default, guarded by staleness**:
- `adopt` computes `git diff --name-only <explored_at>..HEAD` ∩ (union of lane file scopes).
- **Empty** → proceed; the world the plan assumed is intact where it matters.
- **Non-empty** → neither silently proceed nor full re-explore: force a **plan amendment pass** — spawn the source planner module in amend mode with the offending diff; re-gate if material. This reuses the existing "plan is amendable at any stage" invariant verbatim; staleness is just one more amendment trigger.

**Kickback routing for adopted plans — DECIDED: cold amend.** `review-code` returning `plan-wrong` normally routes by `SendMessage` to the still-warm planner. An adopted plan's author lived in the sync run; its context is gone and nothing can recover it. Rule:
- First `plan-wrong` (or staleness hit): **cold-spawn** the `planner` agent with the source module (from provenance) in amend mode, handing it **paths only** — plan, gate report, provenance block, sync-report, accepted-claims.
- That planner then **stays warm for the remainder of the run** — from the first amendment on, the run has a real planner again and subsequent kickbacks use the normal `SendMessage` grammar.
- The provenance block is how `review-code`/the router know which routing applies.

*Why cold-amend beats a standby planner:* a standby planner spawned at adoption would only "warm up" by reading the same files a cold spawn reads — its warmth is counterfeit (it didn't write the plan; it holds no unwritten reasoning), and it costs an idle opus context for the whole build against a kickback that may never fire. The system's own philosophy decides this: state lives in files so that interruption loses nothing — and cold re-entry from artifacts is already in the loop grammar (`map-wrong` re-runs explore cold; worktree resume reconstructs from disk). If a cold amend cannot succeed from the artifacts alone, that is an artifact-completeness bug to surface and fix, not a gap to paper over with an idle agent.

**Scope note:** diagnose needs none of this — its picked candidates already become lanes in the same run, with the warm planner still present.

### §2.8 Invariants carried forward — verbatim, non-negotiable

The restructure moves seams; it must not move these. Sourced from `docs/conventions.md` and the current tree; every new component adopts them.

1. **The worker return envelope is universal.** `status: success|blocked|needs-input|failed` · `artifacts: [paths]` · `next` · `blockers`, followed by a digest — never artifact content. *Artifact-on-disk, pointer-in-envelope.* A worker inventing its own shape is a convention violation. **New adopters:** the `committee` agent (artifacts = claim files + the consolidated artifact its wrapped skill produces), the `report.md` middle's explore consumers, `resolve-anchor` output handling.
2. **Kickbacks pass the report path, never a paraphrase.** Reason codes route to the cheapest sufficient re-entry (`impl-wrong` → lane from its contract; `plan-wrong` → planner per §2.7; `map-wrong` → re-explore). Reports append `## Round <n>` per iteration — the revision history reads straight from the file.
3. **Report contracts stay script-enforced.** `report-verdict.sh` is the only way a verdict enters a report; `validate-report.sh` re-checks enums, count consistency, and open-questions on `needs-input`; `--kind exit` checks builder exit reports (fenced `status:`, non-empty `## Files touched`, non-empty `## Evidence`). The committee does **not** write verdict rounds of its own: it is a worker returning the §2.8 #1 envelope, never a gate. Where it wraps a gate skill, that skill writes its verdict round through these scripts exactly as it does at `rigor: low` — which is why the committee needs no place in the `ready|tentative|rejected` vocabulary, a vocabulary rev 4's reconciler never fit.
4. **Plan → contract flow is preserved under every path into build — adoption included.** The plan carries lane syllabus + per-subphase detail blocks + oracle declarations (`new contract tests` | `existing suite` | `equivalence check` | `existing implementation`); each builder decomposes its lane into packets and writes `contracts/<lane-id>.md` in the **parent** worktree; `coder` never reads or writes tests; `contract-tester` reads the contract text alone — the blindness is architectural, and red-packet redispatch carries contract + diagnosis, never the opposing artifact's source. Only the builder's own e2e tail — verified against the **plan's** acceptance criteria, not the contract — exits the lane loop.
5. **State lives in files, not context — interruption loses nothing.** Progress log rewritten in place at every state change; the plan's current path travels in every message; `.artifacts/` layout unchanged (`progress-log.md`, `contracts/`, `reports/`, explore maps, **plus `committees/<skill>/`** *(new — see 5.1; the rev 5 spec said `claims/`)* and the `anchors:` block *(new)* in plan front-matter + progress log). Run dir lives in the parent worktree only; its lifetime is the worktree's; `cleanup-merged` is the only teardown; deferred cleanup on failed push stands. Plans-dir/run-dir split stays absolute in both directions.
6. **Ownership is machine-audited, never prompt-disciplined.** `verify-scope.sh` per lane before merge; merge conflicts between "independent" lanes ARE scope violations — stop, don't resolve past them; `verify-run-scope.sh` at the PR gate treats every UNCLAIMED product change as blocking. dae's writes stay harness-scoped; a stalled lane is never a license to do its work yourself. **Footprint-restricted types (§2.9) hang their restrictions on exactly these scripts.**
7. **Cold forks cannot ask mid-run.** Unresolved questions become flagged questions in the final report (the changelog-preference default-to-none-and-flag pattern is the model); loop-backs are recommendations in the report, never phases the fork invokes itself. Applies to the `committee` agent and every report-middle fork. Its corollary at `rigor ≥ med` is §2.1's divergent tie-break: a claim still unverified at consolidation time is an open question, never a blocking finding.
8. **Nothing publishes without passing the PR gate — mechanically.** `review-pr` runs on every `ship: publish` run, whole branch-vs-base diff, no exception for adopted plans, doc-only runs, or published reports. Enforcement is code, not prose: `push-pr --stage finalize` validates that the run's `pr-review.md` exists, passes `validate-report.sh`, and its **last** round carries `verdict: ready` + `next: proceed` — refusing with a plain error otherwise. Amending anything after a passing gate (a late plan amendment, a re-opened lane) invalidates the round: the gate re-runs before finalize is attempted again, consistent with "every gate re-reads the plan file at verdict time." No axis, type row, or future flag may route around this — a hypothetical `ship` value that skipped the gate while still pushing is a design rejection, not a configuration.

**Chat-run exception, stated rather than hidden:** `ship: chat` runs have no worktree, so claim files and the report live in the scratch dir. Their interruption story is deliberately weaker — acceptable because a map/analyze re-run is cheap and side-effect-free. The scratch dir must still exist *on disk* (a crashed analyze leaves its claims recoverable); it is simply not under git or the run-dir conventions.

### §2.9 Why `pipeline` is not an array (footprint vs. pipeline)

The question that prompted this section: build touches plan + code + tests + docs and archives the plan, while a hypothetical `sync-tests` type would touch only tests — shouldn't the axis be an array of what a run writes?

**No, because that reading conflates two different things:**

- **Artifact footprint** — everything the run writes. Build's footprint is wide; that width is `build.md`'s *stages in sequence* plus `plan-lifecycle.sh` doing its job (plan archival is lifecycle, not output). It was never four pipelines composed.
- **Pipeline** — the execution shape. One value, one middle file. This is what the axis selects and why it is locked.

**What an array would cost:**
1. **Ordering** — the router would need dependency edges between array items, reinventing the pipeline inside the router, which is exactly what the middles exist to own.
2. **Loop anchoring** — loops attach to axis values (§2.3). "Code gate attaches to `code ∈ pipeline`" forces a fresh adjudication per combination; the loop table stops being a table.
3. **Combinatorial garbage** — of the subsets of `{plan, code, tests, docs}`, four or five are coherent, and those are precisely the named middles. The enum IS the curation — the same move as rigor exposing `low/med/high` instead of raw N.
4. **Expressiveness** — diagnose's shape is "plan, then build *only the picked candidates*, where none is a valid pick." No stage array expresses conditional-build-gated-on-a-human-verdict. Middles carry *logic*, not stage lists; an array is strictly weaker than the files that already exist.

**How footprint restriction actually works — the existing pattern, twice over:** hotfix isn't a different pipeline, it's `plan-bugfix+minimal-scope` (a module constraining footprint). Document's "read-only outside /docs" isn't declared, it's *enforced at the PR gate*. Footprint is a **planner-module constraint audited by the scope scripts** (§2.8 #6) — stronger than any up-front declaration, because it is checked after the fact from artifacts.

**Worked example — `sync-tests` (illustrative, not scheduled):**

```yaml
sync-tests: {pipeline: build, explore: auto, rigor: low, against: optional, ship: publish,
             planner: plan-testsync, branch: feature/}
```

`plan-testsync` requires: every lane scoped to test files only (a glob whitelist that `verify-scope.sh` / `verify-run-scope.sh` enforce mechanically — any non-test file in the diff is an UNCLAIMED blocking finding), and every subphase declaring the `existing implementation` oracle (§2.2.1): shipped code is the truth, contracts are derived from its observed behavior plus docs, **contract-testers only, no coders**. Testers stay implementation-blind per §2.8 #4, writing tests against *intended* behavior from contracts — so a tests-only run surfaces impl/intent divergences as failing tests, making it a shallow diagnose for free.

Net cost: one yaml row, one planner module, one oracle mode (already added to the table). It passes the Step 9 audit drill. That is the reconciliation — the axes absorb footprint variation without becoming arrays, because footprint was never the axis's job.

**Extension rule for all futures like it:** a genuinely new *coherent stage combination* = a new middle file = a new `pipeline` enum value. Explicit, cheap, and it keeps incoherent combinations unreachable rather than merely discouraged. Record intensity stays parameterized where it already is (the changelog preference flowing into record); do not add a `record:` row field until a real type needs record fully off — and if that day comes, it is a constrained row field like `against`, not an axis.

### §2.10 The `committee` agent — generic structure, skill-supplied substance

**Replaces rev 4's `reconcile-claims`.** `committee` is a **higher-order agent**: it owns the *how* of multi-agent verification and knows nothing about what is being verified. The subject matter arrives as a skill.

```
committee(skill: explore,     n: 5) -> merged map + accepted claims
committee(skill: review-plan, n: 3) -> claim classification + the gate's own verdict round
committee(skill: review-code, n: 3) -> findings + the gate's own verdict round
committee(skill: review-pr,   n: 3) -> findings + the gate's own verdict round
```

**What the committee owns (the how).** Fan out N cold sub-agents over the wrapped skill; collect each one's claims to its own file under `.artifacts/claims/`; match claims by evidence location; route disputes and singletons to targeted re-verification **against the source**; consolidate; return the shared worker envelope pointing at the result. *(Path marker, round 3: the directory is `.artifacts/committees/<skill>/`, not `.artifacts/claims/` — member files `claims-c<n>.md`, committee-level `accepted.md`/`reverify.md`. See 5.1, which is authoritative.)*

**What the wrapped skill owns (the what).** What a claim is, what evidence looks like, what the consolidated artifact should be, and how a still-unverified claim is treated at the end (§2.1's collector/gate tie-break).

Four consequences fall out of that split, each of which was a defect in rev 4's design:

- **Output-contract drift becomes impossible.** The committee returns whatever its wrapped skill returns, merged. A consumer cannot tell `low` from `high` by artifact shape, because it is the same skill either way — so no downstream consumer branches on rigor. rev 4 would have had `explore` return a map at `low` and an `accepted.md` at `med`, forcing every consumer (planner, report skeleton, record pass) to grow a rigor-conditional branch — exactly the drift the axis exists to prevent.
- **No modes.** rev 4 needed a "generate" path for explorer claims and would have needed a separate "verify" path for claims extracted from a plan. Parameterisation removes the distinction: one mechanism, different skills.
- **New rigor points are free.** Pointing the committee at another phase's skill requires no committee change — the axes' scalability requirement applied one level up.
- **It is a worker, not a gate** (§2.8 #3).

**Committee-eligibility contract.** A skill may be wrapped only if it emits atomized, evidence-anchored claims. Verified against the current tree, all four qualify: `explore` (claims carry `file:line`), `review-plan` (steps 4–7 already classify every claim VERIFIED / UNCERTAIN / WRONG), `review-code` and `review-pr` (findings carry `file:line` + evidence). Eligibility is therefore **not** what limits where rigor attaches — §2.1's attachment table is a **policy** choice about cost, not a capability limit.

**Shape and model.** A mini-orchestrator that spawns cold sub-agents and consolidates is structurally the same shape as `builder`, so `committee` is an **agent**, not a skill — a second instance of a pattern this tree already proves, which is what keeps it inside the "near-zero new orchestration" requirement. `model: opus` (consolidation is adjudication, which is planning-shaped per `model-policy`). The N sub-agents inherit the **wrapped skill's** declared model — `explore` stays sonnet — so cost scales with the subject, not the wrapper.

### §2.11 Open decision points (rev 5 — a human must choose)

> *Resolution marker, gate round 1: **D1 and D2 are no longer open.** D1 → option (a), rigor as substitute; D2 → warn on stderr and continue, with the row-default/user-typed distinction rejected. D3 was already settled in the plan body. The arguments below are kept as the reasoning behind those calls; the plan's decision-points section carries what was actually chosen.*

**D1 — document's spec of record has no gate. Rigor substitute, or a real gate? (RESOLVED: (a).)**

Verified across the tree, every run type's spec of record passed an independent gate before the PR gate leaned on it — except one:

| run | spec of record | gated before becoming the spec? |
|---|---|---|
| build | plan | yes — `review-plan`, human gate |
| diagnose | diagnosis report (= `plan.md`) | yes — pick gate |
| sync | plan + confirmed sync report | yes — confirm gate |
| **document** | **explore map** | **no gate at all** |

The map goes straight from the explorer to being the artifact the ship gate judges against. It is the only unvalidated spec of record in the system. Two ways to close it:

- **(a) Rigor as substitute** — `document: rigor: {explore: med}`, as the table now carries it. Cheaper, adds no gate, preserves document's deliberate "no gates" character. Statistical, not structural: a committee raises the odds of catching a bad map, it does not guarantee it.
- **(b) A real map-confirm gate** — mirroring diagnose's pick gate and sync's confirm gate, before the record pass. Structurally consistent with every other type and closes the hole rather than narrowing it, at the cost of one more human interaction on every document run.

These are not exclusive; (b) with `rigor: low` is also coherent. **The table currently encodes (a).** Note that (a) is what makes explore rigor worth its cost on document runs specifically — the argument is "it stands in for the missing gate," not merely "docs should be accurate."

**D2 — an explicitly typed `--rigor <phase>:<value>` naming a phase this run does not have. (RESOLVED: warn and continue.)**

§2.1 step 4 currently **drops it silently**, per the instruction that absent phases are simply ignored. The alternative is to error, in the style `against: forbid` already uses (*"did you mean rework/sync?"*): `--rigor pr:high` on a `ship: chat` run probably means `--ship publish` was intended, and silently swallowing it produces a run that quietly did not do what was asked — the failure mode the spec's strictness about unknown flags exists to prevent. Distinguish the two cases if this is adopted: a **row default** naming an absent phase always drops silently (config, not intent); only a **user-typed** override errors.

**D3 — `workflows.yaml` needs a parser, and this repo has a no-jq policy.**

`resolve-config.sh:21` states the constraint explicitly ("No jq dependency, matching this repo's other hooks"), and no YAML parser exists anywhere in the tree. A table the router is merely *asked* to obey is prompt discipline, not enforcement — the thing this repo elsewhere refuses to rely on (`report-verdict.sh`, `validate-report.sh`, `verify-scope.sh` are scripts precisely because prose does not hold), and acceptance criterion 1 promises parse-time errors *before setup*, which is a script's job. **Recommended:** ship `resolve-type.sh` beside the yaml — reads the row, applies the free/constrained/locked tiers, runs §2.1's rigor resolution, validates `against` arity and `--plan` placement, prints resolved axes as `KEY=value` lines for the router to consume. Keep rows to **one-line flow maps** so sed/awk can parse them without a dependency, and add `tests/resolve-type.test.sh` beside the four suites already in `tests/`. *(Count corrected in round 1: the rev 5 spec said three, written before `tests/sync-install-settings-merge.test.sh` landed in `5644e79`.)*

### §2.12 What changed in rev 5

Design changes:

1. **`reconcile-claims` → the generic `committee` agent** (§2.10). Wraps any claim-emitting skill; owns structure only. Resolves three rev-4 defects at once: who owns the committee, output-contract drift between rigor tiers, and the reconciler's non-fit with the `ready|tentative|rejected` verdict vocabulary.
2. **Rigor generalised from an explore-only knob to a four-phase profile** — `explore`, `plan`, `code`, `pr` — with explicit resolution rules, scalar-or-per-phase syntax, and attachment determined by `f(pipeline, ship)` (§2.1).
3. **`code` added as an addressable phase, defaulted `low` everywhere.** Capability without default cost; justified by cross-lane duplication and kickback routing having no oracle, bounded by the cap-3 loop and the `code > pr > plan` false-rejection severity ordering.
4. **`low` pinned as the existing solo path, unchanged** *(round 4: was "byte-for-byte" — verified impossible, see §2.1's round-4 marker)*, with an explicit prohibition on implementing it as `committee(skill, n=1)`.
5. **Rigor reframed around "oracle of last resort"**, with the two committee rules made explicit: it allocates verification budget rather than voting truth into existence, and the threshold routes rather than rejects.
6. **The collector/gate tie-break** (§2.1) — three of four attachment points wrap gates, so an unverified claim must land as an open question, never as a blocking finding. Uses the existing `needs-input` vocabulary; no new machinery.
7. **`document`'s PR-gate oracle split** (§2.5) — map for coverage, code for accuracy — plus the matching check step in `review-pr`'s docs branch.
8. **`analyze` gains `branch: docs/`** so a publish-mode report has a prefix `workflow-setup.sh` already accepts (§2.2).
9. **`document`, `analyze`, `sync` rigor cells** are now `{explore: med}` rather than a bare scalar, so the new phases stay `low`.

Corrections verified against the tree (not design changes — the spec asserted otherwise):

10. **`review-code` is not lane-scoped.** It runs *"after every builder lane has merged"*; its surface is the whole assembled implementation. `review-pr`'s description of it ("lane by lane") is misleading enough to reconcile in Step 9.
11. **`push-pr` rejects `docs/` and `sync/` branches today** — `push-pr/SKILL.md:24` verifies the branch is `feature`, `bug`, or `hotfix`. Document and sync runs already trip their own publisher. Pre-existing bug, inside the seam this restructure re-cuts.
12. **`agent-skills-architecture-overview.md` does not exist.** The real doc surface is five files (Step 9).
13. **`workflow-setup.sh` and `allow-workflow-cleanup.sh` hardcode the branch-prefix enum**, so acceptance criterion 8 as written is already false (now rescoped).
14. **`tests/` was never mentioned in the migration plan** despite four existing suites and two new scripts needing coverage.
15. **`push-pr --stage finalize` does not validate `pr-review.md` today** — it only links it. §2.8 #8's mechanical refusal is genuinely new, and is now Step 1 rather than a clause inside Step 7.

---

## Acceptance criteria
1. Every type runs end-to-end per its row; constraint violations (`against` array rules, `--plan` on non-build, locked `--pipeline`, unknown flags) error at parse time, before setup, with a plain-language ask — **enforced by `resolve-type.sh`, not by the router's good intentions** (§2.11 D3).
2. `map` completes with zero git side effects and is materially faster than `analyze` on the same question.
3. `med`/`high` produces claim-level evidence with majority thresholds; disputes and singletons show a re-verification trace against the source, not a second vote. Where the committee wraps a **gate**, that gate's own verdict round is written normally through `report-verdict.sh` and passes `validate-report.sh` — the committee writes no verdict of its own.
4. Context seams hold: a map run's context contains no build/publish skills; a `low` run never loads the `committee` agent, and it is **the same code path as pre-migration** — verified by 5.2's four structural checks (solo routing; exactly one map artifact at the requested path; required sections present; **no `committees/` directory at all**). *(Round 4: this criterion previously said "byte-for-byte identical" and directed a transcript spot-check plus artifact diff. Both were retired — see §2.1's round-4 marker.)*
5. Handoff fast path reaches lane dispatch with no planner spawn and no plan gate; staleness guard forces amendment when base moved inside lane scope; adopted-plan `plan-wrong` cold-amends from paths only, then stays warm.
6. §2.8 holds everywhere new code runs: envelope returns, script-enforced verdicts, plan→contract detail blocks survive adoption, `anchors:`/claims on disk, no state that exists only in context.
7. The `existing implementation` oracle produces a tests-only diff, mechanically verified by the scope scripts.
8. **No loop or gate branches on a type name** — grep proves it. *(rev 5 rescope: the original wording, "no loop, gate, or script references a type name," is already false and stays false — `workflow-setup.sh:65-66` and `allow-workflow-cleanup.sh:90` hardcode the branch-prefix enum, and `plan-lifecycle.sh:48` lists `sync-report` among its record kinds. Branch prefixes and record-kind names are naming, not behaviour; the criterion that matters is that no control flow keys off a type.)*
9. **The PR gate is inescapable on publish:** for each publish pipeline (build, plan, docs, and `analyze --ship publish`) — including a handoff run — `push-pr --stage finalize` invoked without a passing, validated `pr-review.md` refuses with a plain error; with one, it proceeds. Test the refusal on the handoff run specifically, since it is the path that skips the most upstream gates.
10. The `audit` drill passes: one row, one template, nothing else.
11. **Rigor resolves per §2.1's five steps.** A scalar sets all four phases; `--rigor explore:high` leaves the other three at their row defaults and never at `low`; `--rigor med,explore:high` resolves to everything-med-except-explore; phases the run does not have are dropped; `code` is `low` on every shipped row.
12. **The committee is genuinely generic.** Wrapping the second, third, and fourth skills requires **zero** committee-side changes — the same proof-by-non-change the `audit` drill applies to the axes. A consumer cannot distinguish `low` from `high` by artifact shape at any attachment point.
