# The `prove` type, and folding `orchestrators/` into `agent-agnostic/`

**Type:** `feature` · **Planner module:** `plan-feature` · **Status:** COMPLETE — all 17 subphases shipped across 7 lanes; PR gate round 1 `tentative`/`proceed`, 0 blocking. **Rebased onto `main` at `afa4817`** (2026-08-29).

**Supersedes:** nothing.

**Scope has moved twice.** This plan began as two halves — a new `prove` type, and reopening `ship` as a per-row axis. Upstream work **shipped the second half** in the exact `chat|publish` cell syntax this plan proposed, so that half is delivered. The user then **added the layer fold** — merging `orchestrators/` into `agent-agnostic/` — which had been tracked here as an external dependency (its two competing branches have since been deleted, so it is designed fresh here). The plan is now: fold the layer, then build `prove` on the folded tree.

## Phase syllabus

- [ ] Phase 1: Fold `orchestrators/` into `agent-agnostic/`
  - [x] 1.1: The move itself — three `git mv` subtrees              (lane 1)
  - [x] 1.2: `sync-install.sh` — the layer mapping                  (lane 1, after: 1.1)
  - [x] 1.3: `claude-install-drift.sh` — the same mapping, mirrored (lane 1, after: 1.1)
  - [x] 1.4: `tests/` — path references across the suite            (lane 1, after: 1.2, 1.3)
- [ ] Phase 2: One layer, one guide
  - [x] 2.1: Merge `orchestrators/AGENTS.md` into the generic guide (lane 2, after: 1.1)
  - [x] 2.2: Root `AGENTS.md` + `README.md` — the tree loses a layer (lane 2, after: 2.1)
- [ ] Phase 3: The reference sweep
  - [x] 3.1: Skills, rules, and hook prose                          (lane 3, after: 1.1)
  - [x] 3.2: `docs/` and the project-scoped `.claude/`              (lane 3, after: 1.1)
- [ ] Phase 4: The type table and the resolver
  - [x] 4.1: `workflows.yaml` — the `prove` row, and `map`'s missing branch (lane 4, after: 1.1)
  - [x] 4.2: `resolve-type.sh` — the `proof` pipeline               (lane 4, after: 4.1)
  - [x] 4.3: `tests/resolve-type.test.sh` — `prove`, and `map`'s branch (lane 4, after: 4.2, 1.4)
- [ ] Phase 5: The proof pipeline's own files
  - [x] 5.1: `prove.md` — the middle file                           (lane 5, after: 1.1)
  - [x] 5.2: `proof-skeleton.md` — the fixed frame and its rules    (lane 5, after: 5.1)
- [ ] Phase 6: The report middle catches up to a switchable ship
  - [x] 6.1: `report.md` — two stale claims the ship revert left behind (lane 6, after: 1.1)
- [ ] Phase 7: Router integration
  - [x] 7.1: `dae/SKILL.md` — type table, seams, `ship: chat`, PR-gate spec (lane 7, after: 4.2, 5.1, 5.2, 6.1)
- [ ] Phase 8: Catalogue reconciliation
  - [x] 8.1: `AGENTS.md` + `docs/` — twelve types, six pipelines, seven middles (lane 7, after: 7.1, 2.2, 3.2)
- [ ] Phase 9: Verification
  - [x] 9.1: Whole suite, `bash -n`, and the install sync           (lane 7, after: 4.3, 8.1)

---

## Goal & scope

**Ask of record:** `.artifacts/the-ask.md` — the run dir of this run's parent worktree, captured verbatim from the `/dae` invocation before any planning, §A–§C.

**In scope**

1. **A new type `prove`** (alias `disprove`) on a **new `proof` pipeline** with its own middle file `prove.md` and its own frame `proof-skeleton.md`. It takes a claim — stated inline, or named by `--against` when the thing under test is a document — attempts to establish it, then **attempts to refute it**, and emits a verdict backed by anchored proof. It defaults to shipping a document; `chat` is reachable on the ship axis, which now exists (§A).
2. **One defect fix:** `map` carries no `branch:` cell, so `map --ship publish` resolves with no `BRANCH` and Setup falls through to `workflow-setup.sh`'s `feature` default — a docs-only report landing on a `feature/` branch. Verified below; see **R-1** for whether it belongs in this plan at all.
3. **Folding `orchestrators/` into `agent-agnostic/`** — both layers are `domain: universal` and both install to the same `~/.claude/` locations, so the split costs a second place to look and buys nothing. Includes the two scripts that independently reimplement the source↔install mapping, the merged layer guide, and a 463-reference sweep.
4. The consequential edits: the router's own `SKILL.md`, one stale sentence in `report.md`, the catalogue files that count types and pipelines, and the resolver's test suite.

**Ordering.** The fold runs FIRST. Phase 5 creates two new files in the dae skill dir; doing the fold afterwards would move them twice and leave every path in this plan describing a tree that no longer exists.

**Already delivered by `8875739` — explicitly NOT in scope**

- **§B in full.** `map: chat|publish` and `analyze: publish|chat` both resolve and both switch; `dae feature --ship chat` is refused against the row's own cell, and `--ship` matching a fixed row warns and is ignored rather than erroring. The per-row policy, the pipe syntax, the derived error lists — all shipped. This plan adds a row to that mechanism; it does not build it.

**Explicitly out of scope**

- **Widening `workflow-setup.sh`'s branch-type enum** (`feature|bug|hotfix|docs|sync`). `prove` publishes on the existing `docs/` prefix — zero edits to that script.
- **Changing any existing row's defaults**, ship cells, `against` rule, or `patience:` budget.
- **A new rigor phase.** The proof run reuses `explore`; see **DP-2**.
- **The `--pat[ience]` dial and the `live` type.** Both new since this plan was drafted; `prove` has no code phase, so `patience:` does not belong on its row and `--patience` correctly warns-and-drops against it.

## Stack & MAJOR versions

Verified from the tree, not from memory:

| Component | Version / shape | Verified from |
|---|---|---|
| Shell | `bash`, `set -uo pipefail`, no `jq`, no YAML library | `orchestrators/hooks/resolve-type.sh:33` (pre-fold path; now `agent-agnostic/hooks/`); the no-jq constraint is stated at `resolve-type.sh:20-21` and originates at `resolve-config.sh:21` |
| Type table | one-line flow-map rows under `types:`, parsed with `awk` + bash builtins | `orchestrators/skills/dae/workflows.yaml:5-10` (pre-fold path) (the "FORMAT IS LOAD-BEARING" comment block) |
| Test harness | hand-rolled bash suite, `run`/`ok_lines`/`no_lines`/`err_case` helpers, `--yaml <fixture>` injection | `tests/resolve-type.test.sh:1-45` |
| Branch-type enum | closed: `feature\|bug\|hotfix\|docs\|sync` | `orchestrators/hooks/workflow-setup.sh:70-74` (pre-fold path) |
| Repo integration | squash-merge to `main` locally, no PRs, then `sync-install.sh` | `.claude/rules/source-push-sync.md` |

There is no package manifest — this repo ships markdown and POSIX-ish bash only.

## Conventions to enforce

Hard constraints, not suggestions:

- **No control flow keys off a type name.** Every branch in a middle file and in `SKILL.md` reads a resolved *axis value* (`dae/SKILL.md:70`). This is why `prove` gets a new `pipeline` value rather than sharing `report`'s: with no planner-module discriminator, a shared `report` pipeline would force the router to pick a middle file by type name.
- **One-line flow-map rows.** No nesting past the inline `{…}` / `[…]` forms, no wrapped rows, no reformatting into block mappings (`workflows.yaml:5-10`). Column alignment is preserved.
- **`resolve-type.sh` is the only reader of the table** (`resolve-type.sh:13`). The router consumes `KEY=value` lines and never re-derives an axis.
- **Absent values are omitted, never emitted empty** (`dae/SKILL.md:78`).
- **Derived lists, never hardcoded enums, in error messages** — the existing `build_types` / `require_types` pattern at `resolve-type.sh:253-270`.
- **Reference, never restate.** A middle file points at the shared stage in `SKILL.md`; `SKILL.md` points at the middle for anything the middle owns.
- **Plan/docs artifact locations** resolve through `resolve-config.sh`; no hardcoded `/docs`.
- Skill/rule/hook edits happen **here**, never in `~/.claude/` (`source-push-sync`).

---

## Phase 1: Fold `orchestrators/` into `agent-agnostic/`

The repo has four source layers; two of them (`orchestrators/`, `agent-agnostic/`) are both `domain: universal` and both install to the same `~/.claude/` locations. The split buys nothing at install time and costs a second place to look. This phase merges them.

**Ordering note:** this phase runs FIRST, before any `prove` work, so the new files Phase 5 creates land in their final home rather than being moved twice. Every path elsewhere in this plan names the POST-move location.

### 1.1 — The move itself

**Files touched:** the whole `orchestrators/` tree (moved, not edited)

Three `git mv` operations, chosen so git records renames rather than delete+add:

| From | To | Note |
|---|---|---|
| `orchestrators/agents/` | `agent-agnostic/agents/` | new subdir; the target layer has none today |
| `orchestrators/hooks/*` | `agent-agnostic/hooks/` | merges into an existing dir |
| `orchestrators/skills/{dae,orchestrate}` | `agent-agnostic/skills/` | merges into an existing dir |

**`orchestrators/AGENTS.md` stays put in this subphase** — 2.1 merges its content into the generic guide and deletes it. So `orchestrators/` is NOT empty when this subphase ends and must NOT be removed here; **2.1 removes the now-empty directory** as its last act. A lane that deletes the file early destroys content 2.1 has to merge.

**Verify no filename collisions BEFORE moving.** The two hook dirs are disjoint today (`orchestrators/` carries `resolve-*`, `workflow-*`, `plan-*`, `verify-*`; `agent-agnostic/` carries `agy-*`, `claude-*`, `smart-*`, `record-*`, `test-*`, `ntfy-*`, `common-*`, `worktree-*`) and the skills dirs share no name — but confirm mechanically rather than trusting this table, and stop if anything collides.

**Acceptance criteria:**
1. `git status` shows renames (`R`), not delete+add pairs, for every moved file.
2. `orchestrators/` no longer exists.
3. No file was edited in this subphase — content is byte-identical across the move.
4. Nothing outside the four layers moved.

**Test approach:** none directly; 1.2-1.4 and 9.1 prove the tree still works.

### 1.2 — `sync-install.sh`: the layer mapping

**Files touched:** `agent-agnostic/hooks/sync-install.sh` (at its new path)

**This is the highest-risk subphase in the plan.** This script is what puts source files into `~/.claude/`; if its mapping is wrong the install silently stops tracking part of the repo. Six sites, all verified on `main` at `afa4817`:

1. The header's mapping table — the `{agent-agnostic,orchestrators}/…` alternations collapse to `agent-agnostic/…`, and `orchestrators/agents/` becomes `agent-agnostic/agents/`.
2. The precondition that BOTH source dirs exist → only `agent-agnostic/`.
3. The path→unit `case` — drop every `orchestrators/*` alternative; the `agents/*` arm re-roots.
4. The unit→path reverse lookup — same, including the `agents/*` arm which currently hardcodes `orchestrators/`.
5. The `--full` walk (`find agent-agnostic orchestrators agent-specific …`).
6. The range walk (`git diff … -- agent-agnostic orchestrators agent-specific`).

**Acceptance criteria:**
1. `sync-install.sh --check` reports the install clean against the moved tree.
2. The string `orchestrators` does not appear in the file.
3. An agent file resolves both directions: path→unit and unit→path.
4. `bash -n` clean.

**Test approach:** `tests/sync-install-settings-merge.test.sh` must still pass, plus a real `--check` run (4.1 of the verification phase re-runs it).

### 1.3 — `claude-install-drift.sh`: the same mapping, mirrored

**Files touched:** `agent-agnostic/hooks/claude-install-drift.sh`

This hook independently reimplements the same source↔install mapping in order to warn when the two diverge, so it carries its own copy of the layer list. Three runtime sites (a `for top in agent-agnostic orchestrators` loop, a path `case`, and the remediation message naming `./orchestrators/hooks/sync-install.sh`) plus its header table.

**Pattern to follow:** whatever 1.2 does; these two files must agree or the drift warning fires against a correct install.

**Acceptance criteria:** the string `orchestrators` does not appear; the remediation message names the new path; `bash -n` clean; the hook stays silent on a freshly-synced install.

**Test approach:** 9.1's sync + a deliberate no-op run.

### 1.4 — `tests/`: path references across the suite

**Files touched:** `tests/*.test.sh` (12 of 13 reference the path)

Mechanical, but **every instance must be enumerated, not spot-fixed** — this is the exact trap `verify-dont-assume` records, and a test suite that still points at the old tree fails loudly, which is the good case; one that silently skips is the bad one.

**Acceptance criteria:** all 13 suites green; no test names `orchestrators/`; **a positive control is run before reporting any grep clean**.

**Test approach:** the suites themselves.

---

## Phase 2: One layer, one guide

### 2.1 — Merge `orchestrators/AGENTS.md` into the generic guide

**Files touched:** `agent-agnostic/AGENTS.md`, `orchestrators/AGENTS.md` (deleted)

Not a concatenation — an edit. The generic guide is organized by subdirectory (`rules/`, `skills/`, `settings/`, `hooks/`); the orchestrators guide carries an entry-point table, the dae pipeline diagram, an agents section, a hooks section, and the **four standing review rules for a new `--type` row**. The merged file keeps the subdirectory spine and folds the orchestrator material in: `skills/` gains the entry points, a new `agents/` section arrives, `hooks/` merges two lists, and the pipeline diagram plus the review rules become their own sections.

**Nothing may be dropped in the merge.** The review rules in particular are cited from `docs/conventions.md` and are load-bearing for this very plan (see 5.1).

**Acceptance criteria:**
1. Every heading from both source files is represented.
2. The four review rules survive verbatim in substance.
3. `docs/conventions.md`'s link to them still resolves (3.2 fixes the path).
4. `orchestrators/AGENTS.md` is gone.

**Test approach:** heading-by-heading diff against both originals; the sweep at 9.1.

### 2.2 — Root `AGENTS.md` + `README.md`: the tree loses a layer

**Files touched:** `AGENTS.md`, `README.md`

Both draw the four-layer tree and describe what each layer is for. After 1.1 there are three. The sentence "Everything in `orchestrators/` and `agent-agnostic/` is `domain: universal`" becomes a statement about one layer — which is the point of the merge and should read as a simplification, not an omission.

**Acceptance criteria:** the tree diagrams show three source layers; no prose implies a fourth; the guide links resolve.

**Test approach:** the sweep at 9.1.

---

## Phase 3: The reference sweep

`orchestrators/` appears **463 times** across ~30 non-archive files. Phases 1 and 2 handle the load-bearing ones; this phase handles the rest. Archived plans under `project-plans/completed/` are history and are **NOT** edited — they correctly describe where things were when they shipped.

### 3.1 — Skills, rules, and hook prose

**Files touched:** `agent-agnostic/rules/artifact-locations.md`, `agent-agnostic/hooks/worktree-reminder.sh`, `agent-agnostic/hooks/resolve-scratch.sh`, and any sibling the sweep turns up

**NOT `workflows.yaml`** — it carries an `orchestrators/` reference too, but lane 4 edits that file for the `prove` row and the two lanes have no edge between them. **4.1 owns the whole file, including its path fix**; touching it from here is the merge conflict this split exists to prevent.

These are prose references naming a source path — comments, rule text, a skill's pointer to a hook. `artifact-locations` is the notable one: it tells every agent where the resolver lives, so a stale path there misdirects the whole system.

**Acceptance criteria:** no `orchestrators/` outside `project-plans/`; every rewritten path resolves to a real file (check, don't assume).

**Test approach:** the sweep at 9.1.

### 3.2 — `docs/` and the project-scoped `.claude/`

**Files touched:** `docs/architecture.md`, `docs/conventions.md`, `docs/known-issues.md`, `docs/pipeline.md`, `docs/README.md`, `scripts/README.md`, `.claude/rules/source-push-sync.md`, `.claude/skills/push-main/SKILL.md`

The two `.claude/` files matter operationally: `source-push-sync` and `push-main` both name `orchestrators/hooks/sync-install.sh` as the command to run after a push. A stale path there breaks the landing procedure for this repo — including the landing of this very plan.

**Acceptance criteria:** every named path resolves; the `push-main` procedure runs end-to-end afterwards (proved by this plan's own landing).

**Test approach:** the sweep at 9.1, plus landing this plan.

---

## Phase 4: The type table and the resolver

The per-row ship mechanism already exists on `main`; this phase adds a row to it and one new pipeline value. Nothing here builds or reverses machinery.

### 4.1 — `workflows.yaml`: the `prove` row, and `map`'s missing branch

**Files touched:** `agent-agnostic/skills/dae/workflows.yaml`

**Pattern to follow:** the `live` row, added by the same mechanism this row uses. One line, column-aligned, no nesting past the inline `{…}` / `[…]` forms.

```
  prove:     {pipeline: proof,  explore: deep, rigor: {explore: med},     against: optional, ship: publish|chat, branch: docs/,   aliases: [disprove]}
```

`ship: publish|chat` — leftmost is the default, so a bare `dae prove` writes a document and `--ship chat` switches it. `against: optional` — a claim may be stated inline or named by an anchor. No `patience:` cell: the proof pipeline has no code phase.

**Also, the defect fix:** `map` carries no `branch:` cell. Add `branch: docs/`.

**And, because this subphase owns the file:** the header comment's `orchestrators/hooks/resolve-type.sh` reference is repointed at `agent-agnostic/hooks/`. Lane 3 deliberately leaves it alone (see 3.1).

**Acceptance criteria:**
1. `resolve-type.sh prove` resolves; the row is one line and column-aligned.
2. `resolve-type.sh map --ship publish` emits `BRANCH=docs/`.
3. No other row changes.

**Test approach:** 4.3.

### 4.2 — `resolve-type.sh`: the `proof` pipeline

**Files touched:** `agent-agnostic/hooks/resolve-type.sh`

Two edits, both mirroring exactly how `live` was wired:

1. **`VOCAB_PIPELINE`** gains `proof`.
2. **The phase table** gains a `proof` arm shaped like `report`'s — `has_explore_phase` always, `has_pr_phase` only when `ship = publish`, no plan phase, no code phase. That single line is what makes `RIGOR_PR` appear on a published proof and vanish on a chat one, and what makes `--patience` correctly warn-and-drop against the row.

**Acceptance criteria:**
1. `prove` → `TYPE=prove`, `PIPELINE=proof`, `SHIP=publish`, `BRANCH=docs/`, `RIGOR_EXPLORE=med`, `RIGOR_PR=low`; no `RIGOR_PLAN`, no `RIGOR_CODE`, no `PATIENCE`.
2. `prove --ship chat` → `SHIP=chat`, and no `RIGOR_PR` line.
3. `disprove` → `TYPE=prove`.
4. `prove --patience 3` → exit 0, a warning naming the flag and the type, no `PATIENCE=` line.
5. `bash -n` clean.

**Test approach:** 4.3.

### 4.3 — `tests/resolve-type.test.sh`: `prove`, and `map`'s branch

**Files touched:** `tests/resolve-type.test.sh`

**Pattern to follow:** the suite's own style — 75-hash section banners, `# --- Case NN: <title> ---` padded to column 78, the existing helpers, labels repeated verbatim in `pass` and `fail`. **Append with the next free numbers; renumber nothing.** Case `63a-e` (the `live` row) is the closest model: a new row gets a fidelity case plus its axis-specific assertions.

Two existing spots need attention, and the builder must enumerate rather than spot-check:

- **The all-types loops** (two of them) must gain `prove`; the "code is low on every row with a code phase" loop must **not**.
- **`map`'s branch.** Grep the suite for cases asserting `map` emits no `BRANCH=`. 4.1 changes that.

**Acceptance criteria:** suite green; no case asserts `map` lacks a branch; `prove` appears in the all-types loops and not in the code-phase loop. **Run a positive control before reporting any grep clean.**

**Test approach:** this subphase *is* the test.

---

## Phase 5: The proof pipeline's own files

### 5.1 — `prove.md`: the middle file

**Files touched:** `agent-agnostic/skills/dae/prove.md` (new)

**Why a new pipeline rather than a flag on `report`:** `AGENTS.md:167-173` (pre-fold path; the rules now live in `agent-agnostic/AGENTS.md`) states the standing rule outright — *"`pipeline` is not an array … A genuinely new, coherent stage combination is a new middle file and a new `pipeline` value, not a footprint flag bolted onto an existing one."* The falsification stage is exactly such a combination. The rule that would otherwise force sharing `report`'s pipeline — no control flow keys off a type name — is what makes a shared pipeline impossible here, since `report` has no planner-module discriminator to select a second middle by.

**Pattern to follow:** `report.md` as it now stands on `main` — same document shape (a statement of what the pipeline is for and what the router hands it, a numbered **Stages** list branching on resolved axis values, a **Notes** tail). Match its register and its reference-don't-restate discipline exactly.

**Stages:**

1. **Setup, branching on `ship`.** `chat` → skip Setup entirely; invoke `resolve-scratch.sh --slug <slug>` and take the path from its `SCRATCHDIR:` line rather than assembling it (the script creates the dir; there is no separate `mkdir -p`). `publish` → the router's shared Setup on the row's `docs/` prefix. `resolve-scratch.sh` owns the resolution ladder and the variable name — reference `artifact-locations`, restate neither.
2. **The snapshot, at `chat` + `rigor ≥ med`.** `report.md` established this on `main` and it is **not optional here**: `prove` defaults to `rigor: {explore: med}`, so a chat-mode proof run lands in that cell *by default* rather than only under a `--rigor` override. Members read a detached worktree pinned at `HEAD` under the scratch dir, removed when the run ends. A moving tree makes independent verifiers disagree because the tree moved — which is corrosive for a report and fatal for a proof, where disagreement is the signal the verdict rests on. No git repo means no snapshot: warn and proceed, never block. **Point at `report.md`'s Setup section for the mechanics; do not restate the `git worktree add --detach` recipe.**
3. **Fix the claim.** Write the claim under test down **verbatim** before gathering anything. Inline claim → quoted from the ask. `--against <anchor>` → the resolved anchor is the subject, and the claim is the specific proposition about it that the user stated. A claim that cannot be written as a proposition with a truth value is not provable: stop and bring it to the user.
4. **Gather (the collector).** Invoke `explore` at the resolved depth, output path in the scratch dir (`chat`) or the run dir (`publish`). At `rigor: low`, invoke it directly — never `committee(explore, n=1)`. At `rigor ≥ med`, wrap in `committee` at the tier's width; point at `committee.md`, restate nothing.
5. **Falsify.** *This is the stage that makes `proof` a different pipeline from `report`, and it is not optional at any rigor.* A **cold** pass — one that has not seen the gathering pass's reasoning — is given the claim and the evidence paths and asked to **refute** it, defaulting to "refuted" under uncertainty. This is the same structural anti-cheating the builder's blind `contract-tester` embodies (`AGENTS.md:31-33`): the agent that argued for the claim must not be the one that judges it. At `rigor ≥ med` the falsification pass is the committee's, at the tier's width, with lenses that differ rather than repeat.
6. **Verdict + write.** Fill `proof-skeleton.md`. Written to disk in **both** ship modes.
7. **Deliver (`chat`)** — verdict and proof in chat, scratch path stated, then **STOP**. State the observable property in `report.md`'s current wording, not the retired one: no branch, no commit, nothing staged, and **nothing that reaches the product branch**. A gitignored scratch-dir write and the stage-2 snapshot are permitted by construction — "zero git side effects" is the pre-`5108f1d` phrasing and must not be revived here.
8. **Record + Ship (`publish`)** — invoke **`document-local`** (always; there is no mode branch and no document-skill dispatch since `5108f1d`) to record the proof under the resolved docs root's `proofs/` subdirectory, `<docs-root>/proofs/<slug>-MM-DD-YY.md`, stated in terms of the **resolved** root. Publishing beyond the repo is a CI job on merge, never a step of this run — see `doc-format`. Draft PR opens at the record commit (no planner, no builders — same reason as `document.md` and `report.md`); reference the shared **Open the draft PR** step by name. **PR-gate spec of record:** the claim as fixed at stage 3, plus the proof document. **Scope boundary: nothing outside `<docs-root>/proofs/` may have changed.**

**Notes tail:** a proof run never writes source; if establishing the claim would require changing code, stop and recommend a build or diagnose run (mirrors `report.md` and `document.md`).

**Acceptance criteria:**
1. Every branch reads a resolved axis value; the strings `prove` and `disprove` appear only in the title line and any example invocation — never as a condition.
2. The falsification stage is present at every rigor tier and is stated as structural, not as an instruction to try hard.
3. The snapshot rule is present and states that `prove`'s own default rigor reaches it.
4. Nothing the router or `report.md` owns is restated — spot-check the scratch ladder, the snapshot recipe, the draft-PR mechanism, the confirmation cadence, and the committee layout, each of which must be a pointer.
5. No sentence claims "zero git side effects", and no sentence implies a Confluence record path or a document-skill dispatch.

**Test approach:** no automated test — this is instruction text. Verified by the convention sweep at 9.1 and by the plan gate.

### 5.2 — `proof-skeleton.md`: the fixed frame and its rules

**Files touched:** `agent-agnostic/skills/dae/proof-skeleton.md` (new)

**Pattern to follow:** `report-skeleton.md` verbatim in structure — "a TEMPLATE PLUS ITS RULES, not prose about reports", a fenced frame, then one numbered rule block per section, and the same closing prohibition against per-type variants and reordering.

**The frame** (six sections; see **DP-5** on enforcement):

```markdown
## Claim under test

## Verdict

## Method

## Proof

## Falsification attempt

## Confidence + what would change the verdict
```

**Section rules, in brief** (the subphase writes them out in `report-skeleton.md`'s register):

- **Claim under test** — verbatim, as fixed at `prove.md` stage 2. Never a cleaned-up restatement; a narrowed claim is a different claim.
- **Verdict** — exactly one of **`proved` | `disproved` | `inconclusive`**, on its own line, before any prose. `inconclusive` is a first-class outcome and must never be dressed up as a weak `proved`.
- **Method** — depth, rigor, what was read and what was **trusted**; at `rigor ≥ med`, the committee's width and a pointer to the consolidated `accepted.md`, never to a member file.
- **Proof** — the free-organization zone, one constraint: **every step is anchored** — `file:line`, or a command with its actual output. An unanchored assertion is not proof; it moves to the last section.
- **Falsification attempt** — what was tried in order to refute the claim, and what happened. **A section saying nothing was tried is a defect**, not a strong result: it is the difference between a proof and an opinion.
- **Confidence + what would change the verdict** — the confidence statement, plus the concrete observation that would flip the verdict. A proof that nothing could falsify is a tautology or an unfalsifiable claim; say which.

**Acceptance criteria:** six sections, this order, these titles; the verdict vocabulary is closed and stated as closed; the falsification section's "empty means defect" rule is explicit; the file forbids per-type variants exactly as its sibling does.

**Test approach:** none automated (see DP-5); convention sweep at 9.1.

---

## Phase 6: The report middle catches up to a switchable ship

### 6.1 — `report.md`: two stale claims the ship revert left behind

**Files touched:** `agent-agnostic/skills/dae/report.md`

Reopening `--ship` on `main` did not update this file. Two sentences are now false, both verified on `main` at `afa4817`:

1. **`:11` says ship "resolves to the row's value only and accepts no flag at all".** It does accept a flag — that is the whole point of the revert. The sentence exists to contrast a free dial (`--explore`) against a non-free one, which is still a contrast worth drawing; recast `ship` as **constrained per row** rather than flagless. Do not delete the sentence.
2. **`:3` hedges "the row's `branch:` prefix where one exists".** After 4.1 both report rows carry one; drop the hedge.

Also check the bulleted "`map` is a cheap `analyze`" list — its third bullet ("loads none of the publish seam") describes `map` **at its default**, not structurally. One clause noting that it moves with the ship axis.

**Acceptance criteria:** no sentence claims `ship` accepts no flag; no sentence implies `map` is structurally chat-only; the file still branches on `ship`, never on a type name; the snapshot table and its rationale are **untouched**.

**Test approach:** convention sweep at 9.1.

---

## Phase 7: Router integration

### 7.1 — `dae/SKILL.md`: type table, seams, `ship: chat`, PR-gate spec

**Files touched:** `agent-agnostic/skills/dae/SKILL.md`

The single shared touchpoint. The flags table and the settled facts need **no** edit — `--ship` is already documented as constrained per row, and `--patience` is already there. The edits are additive:

- **Type selection** — "Eleven types" → **twelve**; a `prove` row (`proof` · `prove.md` · — · `docs/` · optional · `publish | chat`); `map`'s branch cell becomes `docs/` and its ship cell already shows both. Add a **`prove` vs `analyze`** bullet in the register of its neighbours: *`analyze` answers an open question; `prove` adjudicates a stated claim and must try to refute it.* Add a settled fact that **`disprove` is an alias, not a mode** — the run is symmetric and the verdict follows the evidence, never the word typed (see DP-3).
- **Seam loading** — a `pipeline: proof` row loading `prove.md`.
- **`ship: chat`** — names `prove.md` alongside `report.md` as an owner of the short-circuit.
- **Open the draft PR** — the record-commit list gains the proof pipeline; phrase it as *runs with no planner and no builders*.
- **PR gate** — the spec-of-record list gains: *prove → the claim as fixed, plus the proof document, scoped so that nothing outside the resolved docs root's `proofs/` subdirectory may have changed.*

**Acceptance criteria:**
1. `grep -c 'eleven types' SKILL.md` is 0 — **with a positive control** proving the grep works.
2. The flags table and settled-facts block are otherwise unchanged (verify, do not rewrite).
3. Every new claim about `prove.md`'s internals is a pointer, not a restatement.

**Test approach:** the greps above, plus the sweep at 9.1.

---

## Phase 8: Catalogue reconciliation

### 8.1 — `AGENTS.md` + `docs/`: twelve types, six pipelines, seven middles

**Files touched:** `agent-agnostic/AGENTS.md`, `docs/pipeline.md`, `docs/architecture.md`, `docs/README.md`

The tree currently reads "eleven types over five pipeline values resolving to six middle files" — the `live` type moved these once already. Adding `prove` makes it **twelve / six / seven**. Sites enumerated on `main` at `afa4817` with a positive control:

| File | Line | What is stale |
|---|---|---|
| `docs/README.md` | `:40` | the count sentence, and its parenthesised pipeline list (needs `proof`) |
| `docs/pipeline.md` | `:62` | "Eleven types over five `pipeline`-axis values, resolving to six middle files" |
| `agent-agnostic/AGENTS.md` | `:39` (pre-fold line) | "ONE of eleven types", plus the inline type list |
| `docs/architecture.md` | `:116` | "eleven types across five pipeline values", and the middle-file list beside it |

Two further sites carry no count but are in scope:

- `agent-agnostic/AGENTS.md` — the ASCII flow map and the "other types swap the middle file" paragraph, neither of which knows about `proof`.
- `docs/conventions.md:232` points at **`AGENTS.md`'s four standing review rules for a new `--type` row**. No edit needed, but the builder must confirm `prove` satisfies all four — in particular *"`pipeline` is not an array"*, which this design follows rather than violates (see 5.1).

*(Historical note: this subphase was written when the fold was an external dependency. It was pulled into this plan as Phase 1 and ran first, so by the time 8.1 executed the guide already lived at `agent-agnostic/AGENTS.md`. See **DP-4**.)*

**Acceptance criteria:** `grep -rIn -E '(eleven|twelve) types|(five|six) (pipeline|middle)' --include='*.md' docs/ agent-agnostic/` returns only correct, updated claims — **run the positive control first**; a bare zero is not evidence. Archived plans under `project-plans/completed/` are history and are **not** edited.

**Test approach:** the grep above, with its control.

---

## Phase 9: Verification

### 9.1 — Whole suite, `bash -n`, and the install sync

**Files touched:** none (verification only)

1. Run every suite in `tests/` — not just `resolve-type.test.sh`. The ship change touches a shared resolver; a green single suite is not evidence.
2. `bash -n` over every changed script.
3. Convention sweep: no middle file branches on a type name; no restated shared stage; `doc-format` respected for anything under `docs/`.
4. Confirm `workflow-setup.sh` was **not** edited — the out-of-scope boundary held.
5. After the squash-merge to `main`, run `sync-install.sh <pushed-range>` per `source-push-sync`. The sync is part of the change, not a follow-up.

**Acceptance criteria:** all suites green, `bash -n` clean, sweep clean, `sync-install.sh --check` reports no drift afterward.

---

## Risks, open questions, decision points

**Every blocking decision this plan carried has been resolved by work that landed on `main`.** Nothing below stops the build; the open items are scoping choices and recorded risks.

### DP-1 — *(RESOLVED on `main`)* The ship axis

Resolved twice, in opposite directions, while this plan sat at the gate. It was briefly locked; that lock was then reverted and the axis reopened as **per-row policy** — the exact design this plan proposed, in the exact `chat|publish` cell syntax, with the leftmost value as the row default. `map` and `analyze` both switch; every other row is fixed and rejects a value it does not list. **§B of the ask is delivered.** This plan now consumes that mechanism rather than building it, and needs no decision.

### DP-2 — *(RESOLVED on `main`)* The ship cell's syntax

The pipe form shipped. The flow-map alternative this plan offered is moot.

### DP-3 — Is `disprove` an alias, or a mode?

`disprove` is proposed as a pure **alias**: it selects the same symmetric run, and the verdict follows the evidence, not the word typed. Treating it as a mode ("go find the refutation") would bias the outcome — the Goodhart failure the repo's structural anti-cheating principle exists to prevent (`AGENTS.md:31-33`). **Recommendation: alias, and say so in `SKILL.md`** (7.1 does) so a later reader does not "fix" it into a mode.

### DP-4 — *(RESOLVED — pulled into this plan)* The layer fold

Formerly an external dependency with two competing branches. **Both branches have since been deleted**, so nothing is inherited and the fold is designed fresh as Phases 1-3, sequenced ahead of the `prove` work.

One judgement inside it is worth flagging rather than deciding silently: **`orchestrators/AGENTS.md` is merged into `agent-agnostic/AGENTS.md` (2.1), not deleted.** It carries the dae pipeline diagram and the four standing review rules for new types — the latter cited from `docs/conventions.md` and load-bearing for this plan's own Phase 5. Deleting it and scattering the content into `docs/` is the alternative; merging keeps one guide per layer, which is the convention the other three layers already follow.

### DP-5 — Does the `map` branch fix belong in this plan?

`map` carries no `branch:` cell, so `map --ship publish` resolves with no `BRANCH` and Setup falls through to `workflow-setup.sh`'s `feature` default — a docs-only report on a `feature/` branch. Verified with a positive control: `analyze` emits `BRANCH=`, `map --ship publish` does not. `report.md:11` is stale in the same way, still claiming ship "accepts no flag at all".

Both are **pre-existing defects on `main`**, introduced by the revert that delivered §B, not by this work. This plan fixes them (4.1, 6.1) because it is already editing both files and a published `map` is otherwise broken.

**Recommendation: keep them here**, since the cost is two lines and the alternative is shipping a plan that touches these files while knowingly leaving them wrong. **Alternative:** split them into a small standalone fix that lands first — reasonable if you want the defect fixed sooner than this plan ships, since it is independent of everything else here.

### DP-6 — Does `prove` warrant its own rigor phase?

`VOCAB_PHASE` is `explore | plan | code | pr`. The falsification stage is the one a user would most want to dial, and it is *not* the explore phase. This plan folds it under `explore` to avoid widening a vocabulary every row shares. **Recommendation: fold under `explore` now**, and revisit if a second pipeline ever wants an adversarial phase — at which point it is a `verify` phase belonging to more than one row.

### DP-7 — Should the proof verdict be script-enforced?

The repo's position is that enforcement is mechanical, not prose — `report-verdict.sh`, `validate-report.sh`, and now `validate-plan.sh` all exist so a malformed artifact is refused rather than trusted. A proof document with a free-text verdict is the weak point of this design, and the tree is trending against it. But its vocabulary (`proved|disproved|inconclusive`) is **not** a gate vocabulary (`ready|tentative|rejected`) and must not reuse those scripts. **Recommendation: ship the skeleton first, add `validate-proof.sh` as a follow-up** once the frame has survived real use — freezing a format nothing has exercised is the more likely mistake. Raise at the gate if that is too loose.

### R-1 — `resolve-anchor.sh` classifies a document as kind `plan`

`--against <path-to-a-doc>` resolves first-match-wins to the `plan` kind, because rung 1 is "exists on the filesystem" (`resolve-anchor.sh:15-17`). For a proof whose subject is an arbitrary document the label is misleading but the resolution is correct. **No change proposed** — renaming the kind would ripple through `plan-lifecycle.sh` and the front-matter format for a cosmetic gain. `prove.md` states the subject is whatever the anchor names and does not rely on the label.

### R-2 — The scratch dir's default subdirectory is named `reports/`

`resolve-scratch.sh` defaults to `<repo-root>/.artifacts/reports/<slug>-<runid>/`, and `--slug` is its only knob — so a chat-mode proof's artifacts land under a directory called `reports/`. Cosmetic, gitignored either way. **No change proposed.** Recorded so a reader does not mistake it for a misfile; `docs/known-issues.md` is the right home if it ever needs one.

### R-3 — A published proof is an agent-authored verdict in the docs tree

`<docs-root>/proofs/` becomes a permanent record of a claim this system adjudicated. The PR gate reviews it, but reads the same evidence. **Mitigation:** the mandatory falsification section and the closed verdict vocabulary — an `inconclusive` that cannot be dressed up as a weak `proved`. Accepted risk, recorded rather than solved.

---

## Skill mapping

| Part | Skill / agent |
|---|---|
| Phases 1–5 (execution) | `builder` lanes 1–3, per the syllabus annotations |
| Plan gate | `review-plan` + `validate-plan.sh` (shipped in `5108f1d`; it schema-checks this plan's ask-of-record pointer and runs the ask-vs-plan check) |
| Code gate | `review-code` |
| Record | `document-local` — always, no mode branch; the doc counts at 8.1 are docs-tree edits |
| PR gate | `review-pr`, spec of record = this plan + `.artifacts/the-ask.md` |
| Publish | `push-main` (this repo squash-merges to `main`; **no PRs**, per `source-push-sync`) |
| Install sync | `sync-install.sh`, at 9.1 — not optional |
| Runtime, once shipped | `prove.md` drives `resolve-scratch.sh`, `explore`, `committee` (at `rigor ≥ med`), `document-local`, `push-pr`, `review-pr` |
