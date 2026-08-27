# Report pipeline, artifact locations, the ship axis, and the docs publish model

**Type:** `feature` · **Planner module:** `plan-feature` · **Status:** proposal, amended through plan-gate round 2.

**The ask of record:** `/home/icarus64/repos/agentic/.workflows/report-pipeline-and-locations/.artifacts/the-ask.md`, sections A–H, written before this planner was spawned, **plus the amendments decided at the plan gate** (recorded under **Amendment record** below). Every decision below traces to one or the other; where this plan diverges from either's literal wording it says so out loud, in **Risks, open questions, decision points**.

**Supersedes:** nothing. This is the first plan for this work. It *corrects* work that shipped under `project-plans/completed/dae-axes-restructure-08-23-26.md`, which is archived history and is not edited by this run (**DP-3**, upheld at round 1).

## Phase syllabus

- [ ] Phase 1: `ship` becomes a locked axis
  - [x] 1.1: `workflows.yaml` — `analyze` always publishes                      (lane 1)
  - [x] 1.2: `resolve-type.sh` — `--ship` is locked, not free                   (lane 1, after: 1.1)
  - [x] 1.3: `tests/resolve-type.test.sh` — locked ship, published analyze      (lane 1, after: 1.2)
- [ ] Phase 2: Artifact locations resolve, split, and stop colliding
  - [x] 2.1: `resolve-scratch.sh` — the scratch dir joins the config chain      (lane 2)
  - [x] 2.2: `tests/resolve-scratch.test.sh` — the new suite                    (lane 2, after: 2.1)
  - [x] 2.3: `artifact-locations` + `run-artifacts` — scratch dir, docs split   (lane 2, after: 2.1)
- [ ] Phase 3: `plan-lifecycle.sh archive` exits 0 on success
  - [x] 3.1: `remove_empty_dir` tolerates an already-removed dir                (lane 3)
  - [x] 3.2: `tests/plan-lifecycle.test.sh` — the F2 regression case            (lane 3, after: 3.1)
- [ ] Phase 4: `CLAUDE_DOCS_DIR` is always a local path — enforced
  - [x] 4.1: `resolve-config.sh --expect` — enforce the split where it is tested (lane 4, after: 2.3)
  - [x] 4.2: `verify-run-scope.sh` — drop the dead branch, declare the expectation (lane 4, after: 4.1)
  - [x] 4.3: Tests for the expectation flag and the scope script                (lane 4, after: 4.2)
- [ ] Phase 5: Confluence publishing moves to CI
  - [x] 5.1: `doc-format` — mirror/symlink ALWAYS; publishing is CI's job       (lane 5, after: 2.3)
  - [x] 5.2: `document-confluence` — REWRITE as manual/recovery sync            (lane 5, after: 5.1, 4.1)
  - [x] 5.3: `confluence-mode.md` — what survives, and what was never docs      (lane 5, after: 5.2)
  - [x] 5.4: The publish workflow — canonical in `.github/`, surfaced in `scripts/` (lane 5, after: 5.1, 4.1)
- [ ] Phase 6: DEEP explore means the project, not its dependencies
  - [x] 6.1: `explore/SKILL.md` — exclusions, the raw env read, precedence      (lane 6, after: 2.3)
- [ ] Phase 7: The ask-vs-plan gate
  - [x] 7.1: `plan-format` — the plan carries a pointer to its ask of record    (lane 7)
  - [x] 7.2: `validate-plan.sh` — the pointer is schema-checked                 (lane 7, after: 7.1)
  - [x] 7.3: `review-plan` — diff the ask against the design                    (lane 7, after: 7.2)
  - [x] 7.4: `planner.md` — record the ask, and resolve docs properly           (lane 7, after: 7.1, 2.3)
- [ ] Phase 8: The recording middles
  - [x] 8.1: `document.md` — record locally, full stop                          (lane 8, after: 5.1)
  - [x] 8.2: `report.md` — ship, scratch dir, snapshot rule, record, F1         (lane 8, after: 2.1, 8.1)
- [ ] Phase 9: Integration
  - [x] 9.1: `dae/SKILL.md` — the shared touchpoint                             (after: 1.2, 1.3, 2.3, 4.2, 5.3, 5.4, 6.1, 7.3, 8.2)
  - [x] 9.2: Doc sweep — the inversion, the new hook, `architecture.md`         (after: 9.1)
  - [x] 9.3: Doc sweep — stale counts, the docs model, `conventions.md`         (after: 9.1, 2.2)
- [ ] Phase 10: Verification
  - [x] 10.1: Whole-suite run + `bash -n` over every changed script             (after: 1.3, 2.2, 3.2, 4.3, 9.2, 9.3)

## Amendment record

Decisions arrived across two plan-gate rounds. **Three carried factual premises that did not survive verification against the tree; all three were withdrawn or corrected**, and the corrected form is what this plan implements.

| # | the decision | status |
|---|---|---|
| **A1** | **DP-2 resolved: the ask-vs-plan check goes IN THIS PLAN** (Option A, over this planner's Option B recommendation). The ask must be a real input to the gate, not an optional courtesy; a run whose ask is only conversation context has nothing to diff, and that must be stated rather than passing silently. | **Planned — Phase 7.** No dispute. Round 2 added one refinement: `story.md` already carries the verbatim ask, so it satisfies the pointer and no second artifact is invented (5.3, 7.1). |
| **A2** | **DP-1 resolved, by none of the offered options.** `document.md` owns *how/what* and dispatches for *where*; `analyze` must consume the same dispatch rather than hardcoding a local docs path. Analyze and document differ in what and why, never in where and how. | **Planned — 8.1 + 8.2.** Correct, and better than every option this planner offered. Round 2 changed its shape: there is no longer a *mode* dispatch to consume, so both middles now record locally and publish optionally — one sequence, shared. |
| **A3** | **Build `document-confluence`; it does not exist.** | **WITHDRAWN at round 2 — premise false.** It exists at `tool-based/confluence/skills/document-confluence/SKILL.md`, 63 lines, substantive; `docs/tool-based.md:33` lists the layer as real. It is absent from `~/.claude/skills/` **by design** (`domain: confluence`; `source-push-sync` sends tech-bound content to consuming projects). 5.2 **rewrites** it for its demoted role. See **DP-4**. |
| **A4** | **The read side must be covered in the local-vs-Confluence space** — `document-local` is write-only, there is no read abstraction, four readers assume a local path, and `explore` has three defects. | **SUPERSEDED by the round-2 decision — and it got SMALLER.** Docs are local-primary, so no read seam is needed and no reader changes its access method. Two of `explore`'s three defects dissolve; **the raw-env-read defect and the DEEP precedence rule survive** (6.1). See below. |
| **A5** | **Round 2: docs are LOCAL-PRIMARY. Confluence is a publish target, never a source of truth.** Confluence is read-only for humans; edits happen in the repo. | **Planned — 2.3, Phases 4, 5, 8.** This inverts the current `artifact-locations` rule and is the largest single change in the plan. |
| **A6** | **Round 3: a URL or `<scheme>:` in `CLAUDE_DOCS_DIR` is a HARD ERROR** — refuse outright, name the split, point at the publish var. | **Planned — stated in 2.3, enforced in 4.1.** Placed in `resolve-config.sh` rather than the router because that is where a test suite exists — which **closes R12** without restoring `--kind`. |
| **A7** | **Round 3: Confluence publishing moves to CI.** No in-run dispatch; `document-confluence` demoted to manual/recovery; the workflow lives here as a working reference, canonical in a scripts dir and symlinked into `.github/`. | **Planned — 5.1-5.4, 8.1, 8.2 — and it made the plan SMALLER again.** One premise corrected: **the symlink direction does not work** and is inverted, with evidence, in 5.4. See **DP-8**. |

**What the round-2 decision removed, explicitly, so nobody rebuilds it:** the docs **read seam** (a two-implementation read contract in `doc-format`), `document-local` gaining a read direction, `explore`'s path-assumption and SHALLOW-in-Confluence fixes, `planner.md` and `review-plan` reading through a seam, and **`resolve-config.sh --kind`**. Every reader keeps reading local files exactly as it does today.

**What survived from the parked work:** `explore`'s raw-env-var defect (6.1(b)) and DEEP precedence (6.1(c)); and the `--kind` flag's *unknown-scheme* requirement, which round 3 landed in `resolve-config.sh --expect publish-target` (4.1) where it is **tested** — **R12 is closed**. `document-confluence`'s dead-caller staleness survives only as an acceptance criterion, since 5.2 rewrites the sections that carried it.

**What round 3 removed:** the in-run publish dispatch from both recording middles (8.1, 8.2), `document-confluence`'s role in any run stage, and the parked router-side scheme check. **DP-1 is now fully dead** — with one record path and no modes, there is no "which document skill" question left to answer.

**The evidence that settled it**, verified before the decision and recorded because it is now design rationale rather than an open question: **DP-6** (under Confluence-primary the PR gate goes structurally blind on docs) and **DP-7** (concurrent doc writes have no backstop in Confluence, where they do in git).

## Goal & scope

### In scope

1. **§A / §A1 — `analyze` ships a DOCUMENT, and `ship` becomes a LOCKED axis.** The shipped `analyze` row reads `ship: chat` with `--ship publish` as an opt-in flag (`workflows.yaml:23`) — the exact inversion of the original ask. `analyze` becomes `ship: publish`, always, and `ship` becomes locked exactly like `--pipeline`. **Not** a re-default.
2. **§B / §B1 — `map` is a cheap `analyze` that skips the publishing pre/post run steps.** `map`'s row is **unchanged**. DEEP explore gains a **discovered** exclusion set.
3. **§C — the chat scratch dir joins the config chain and stops colliding**, with a var, a project-local default, and a per-run id.
4. **§D — a report run's worktree need is driven by the `ship`/`rigor` axes, never by the type name.**
5. **§F1–§F5 — five confirmed defects.** F6 is dissolved by A2/A5 rather than fixed.
6. **A1 — the plan gate gains an ask-vs-plan check**, anchored in a rule, a script, and the gate so it cannot decay into a courtesy.
7. **A5 / A6 / A7 — the docs model inverts and publishing leaves the agent.** `CLAUDE_DOCS_DIR` becomes always a local path, **enforced by a hard error**; a new `CLAUDE_DOCS_PUBLISH` holds an optional publish target; both recording middles record **locally only**; publishing becomes a **CI job on merge**, shipped here as a working reference; `document-confluence` is demoted to manual/recovery.
8. The doc and rule surfaces that repeat any of the above.

### Explicitly out of scope

- **§E — run-dir protection. REJECTED by the user.** No recovery machinery, no copy-out steps, no teardown guards.
- **§G — the contract-tester blindness weakness** and **removing the stray zip from git history** (force-push; forbidden).
- **An output-length axis.** Proposed and **rejected**.
- **A docs read seam, in any form.** Superseded by A5; see the Amendment record.
- **Building `document-confluence` from nothing.** It exists; 5.2 **rewrites** it for a demoted role (DP-4).
- **Making Confluence mode work in the global install.** It is uninstalled there *by design* — tech-bound content goes to consuming projects. Changing that is a separate, larger question about the tech-bound/universal split (DP-4).
- **Widening `workflow-setup.sh`'s branch-type enum** or `allow-workflow-cleanup.sh`'s auto-allow list.
- **`report-skeleton.md`, `build.md`, `document-local/SKILL.md`, `resolve-config.sh`** — each is already correct under local-primary; justified in the Lanes exclusion list.
- **`project-plans/completed/**`** — DP-3, upheld at round 1.
- Anything requiring a new runtime dependency.

## Stack & MAJOR versions

Verified in the parent worktree `/home/icarus64/repos/agentic/.workflows/report-pipeline-and-locations` on 08-26-26.

| Thing | Version / fact | Verified from |
|---|---|---|
| Package manifest | **None exists.** No `package.json`, `pyproject.toml`, `go.mod`, `Makefile`, lockfile, or `requirements.txt` at any depth ≤ 2 | `find . -maxdepth 2 …` returned nothing |
| Shell | **GNU bash 5.1.16(1)** | `bash --version`; every script opens `#!/usr/bin/env bash` |
| git | **2.34.1** | `git --version`. Supports `--path-format=absolute` (2.31+), relied on at `workflow-setup.sh:82`, `allow-workflow-cleanup.sh:75` |
| Parsers available | `awk`, `sed`, `grep`, bash builtins — **no `jq`, no YAML library** | `resolve-config.sh:20-24`, `workflows.yaml:6-10`, `resolve-type.sh:20-22` |
| Config resolver | **Fully var-agnostic** — takes the var name as an argument, so a NEW var costs zero script change | `resolve-config.sh:43`, `:59-64` |
| Test framework | **None.** 8 hand-rolled bash suites under `tests/`, each runnable with no arguments from any cwd | `ls tests/`; `docs/architecture.md:148-150` |
| Test runner / CI | **None.** No `.github/`, no Makefile; neither `smart-test.sh` nor `test-changed.sh` nor `workflow-diff-check.sh` carries a `*.test.sh` reference | exhaustive search of the tree |
| Blocking check set | The bash suites plus `bash -n` — **complete**, because there is nothing else | `docs/architecture.md:148` |
| Confluence integration | Via the **Atlassian MCP** (Jira + Confluence) and **Google Drive MCP**, referred to by capability and never by tool-function name | `document-confluence/SKILL.md:37`, `:58` |
| Install target | `~/.claude/`, an **install** of this repo, never an edit target. **`tool-based/<tech>/` never syncs there** | `.claude/rules/source-push-sync.md:1`, `:3` |

**Consequence:** every acceptance criterion must be checkable by `bash <suite>`, by `bash -n`, or by reading the file. There is no linter, formatter, or type checker — and no way to execute a Confluence path in this repo's test set, which is why 5.2's criteria are structural rather than behavioral (R10).

## Conventions to enforce

1. **Edit the repo, never `~/.claude/`** (`.claude/rules/source-push-sync.md:1-2`).
2. **No PRs in this repo.** Landing is `push-main` then a mandatory `sync-install.sh` from the **main checkout** — it refuses inside a linked worktree.
3. **No new runtime dependency.** `awk`/`sed`/bash builtins only.
4. **`domain: universal`** under `orchestrators/` and `agent-agnostic/`; **`domain: <tech>`** under `tool-based/<tech>/`. A universal file may name a tech-scoped skill only as a dispatch target **whose absence it handles loudly**.
5. **NEVER a time estimate** anywhere.
6. **No control flow keys off a type NAME.** Every branch keys on a resolved AXIS value (`dae/SKILL.md:70`, `report.md:3`). This is what F1 restores.
7. **Error messages derive their lists from parsed data, never a hardcoded literal** (`resolve-type.sh:248-274`).
8. **New scripts follow the hook header contract:** `#!/usr/bin/env bash`, title, `SYNOPSIS`, `DESCRIPTION`, `EXIT CODES`, then `set -uo pipefail` — never `set -e`. Pattern: `resolve-config.sh:1-31`.
9. **New test suites follow the seven-suite house skeleton**, not the deviant `sync-install-settings-merge.test.sh`.
10. **`KEY: value` from setup-style scripts** (`workflow-setup.sh:214-219`), **bare `KEY=value` from resolver-style scripts** (`resolve-type.sh:503-519`); resolution SOURCE on stderr (`resolve-config.sh:79`).
11. **Pointers, not payloads, and single ownership of a fact.** A file that restates what another owns is a defect even when accurate.
12. **`dae/SKILL.md` is a shared touchpoint.** Exactly one subphase (9.1) may edit it.
13. **`CLAUDE_DOCS_DIR` is a path. Always.** After 2.3/4.1, no file may pattern-match its value, branch on its shape, or read it without `resolve-config.sh` — and a non-path value is a **hard error**, never a warning or a fallback. The publish target is a **separate var**, and publication is **one-way, repo → target**.
14. **The local docs tree is the source of truth in every configuration.** A published copy is downstream output. Nothing may describe Confluence as canonical.
15. **Publishing is CI's job, not an agent's.** No run stage may dispatch to a publish skill. `document-confluence` is manual/recovery only.
16. **Never commit a symlink under `tool-based/`.** It ships to consuming projects as a path string that dangles or, worse, resolves onto the wrong file (5.4).
17. **A new script flag is ADDITIVE.** Adding one must leave the default invocation's stdout and stderr **byte-identical**, so existing callers need no edit. `resolve-config.sh` has four in-tree callers; 4.1's criterion 1 is this convention made testable.
### 1.1 — `workflows.yaml`: `analyze` always publishes

**File scope:** `orchestrators/skills/dae/workflows.yaml` — this file, and only this file.

**What changes.** Line 23's `analyze` row today reads:

```
  analyze:   {pipeline: report, explore: deep, rigor: {explore: med},     against: forbid,   ship: chat,    branch: docs/}   # --ship publish allowed: report committed under docs/reports/
```

Two edits: `ship: chat` → `ship: publish`, and the trailing `# --ship publish allowed: …` comment is **deleted** — it becomes false twice over, since publish is no longer opt-in and there is no `--ship` flag to opt in with. Column alignment is preserved. `branch: docs/` stays exactly as it is: it is what makes a published `analyze` reachable with **zero** script edits, because `workflow-setup.sh:71-74` validates `--type` against the closed enum `feature|bug|hotfix|docs|sync`. Widening that enum is explicitly not in scope.

**The `map` row (line 22) is NOT touched.** `explore: auto` stays, `rigor: low` stays, `ship: chat` stays. An earlier reading proposed forcing `map` to `explore: deep`; the user corrected it (`the-ask.md:62-64`). `auto` MAY resolve to SHALLOW, and that is intended — *"map CAN be shallow EVEN BY DEFAULT."*

**Pattern to follow:** the row grammar is fixed by `resolve-type.sh`'s parser — a one-line flow map, split on depth-0 commas, with a trailing `# comment` after the closing brace stripped by `flow_inner()` (`resolve-type.sh:78-88`). Do not reformat into a block mapping; do not wrap the row.

**Acceptance criteria**
1. `bash orchestrators/hooks/resolve-type.sh analyze` prints `SHIP=publish`.
2. It also prints `RIGOR_PR=low` — a `pipeline: report` row gains a `pr` phase exactly when `ship = publish` (`resolve-type.sh:360`). This is a *consequence* of the row change, not a second edit.
3. It still prints `BRANCH=docs/`, `EXPLORE=deep`, `RIGOR_EXPLORE=med`, `AGAINST_COUNT=0`, and no `RIGOR_CODE=` line.
4. `bash orchestrators/hooks/resolve-type.sh map` is byte-identical to its output before this change.
5. No `# --ship` comment survives anywhere in the file.

**Test approach:** exercised by 1.3; the five assertions above are runnable by hand in the meantime.

**Test oracle:** `new contract tests` (authored in 1.3).

---

### 1.2 — `resolve-type.sh`: `--ship` is locked, not free

**File scope:** `orchestrators/hooks/resolve-type.sh` — this file, and only this file.

**The live bug being fixed.** `--ship` is applied as a **free-tier** override at `resolve-type.sh:14` and `:350-353`, and `:351` validates only that the VALUE is in `VOCAB_SHIP` — never that it is legal for the resolved row. So **`dae feature --ship chat` is accepted today**: a build run that does not ship. The design's own definition of the free tier is *"cost/quality dials; overriding cannot produce an incoherent run"* (`dae/SKILL.md:45`), which `--ship` violates outright.

**Why locked rather than constrained per row.** No row has a legitimate second ship value. `map` is the chat one; if you want a document you use `analyze`. Chat is meaningless for a build, docs, diagnose or sync run. A per-row `require|optional|forbid` policy would imply some row wants the choice, and none does.

**Pattern to follow — `--pipeline`, verbatim.** `--pipeline` is the existing locked axis, and every mechanism this subphase needs already exists for it:

- it stays in `FLAG_TABLE` (`:133`) so the token *resolves* rather than reading as an unknown flag;
- its argv case consumes the value and sets a `_given` sentinel and nothing else (`:196`);
- it is **absent** from both "did you mean one of …" hint lists (`:145`, `:153`) — a locked flag is recognized in order to be rejected, never advertised;
- its rejection fires in the constraints block, **first**, before placement and arity, per the comment at `:472-475` (`:476`).

Mirror all four points for `--ship`.

**The edits.**

1. `:6` (SYNOPSIS) — drop `[--sh[ip] <v>]`.
2. `:14` (DESCRIPTION) — the free-tier list becomes `(--explore, --rigor)`.
3. `:15` — the locked/constrained sentence names ship: *"… validates the constrained and locked axes (`--against` arity, `--plan` placement, `--pipeline` and `--ship` are locked) …"*.
4. `:133` — `FLAG_TABLE` is **unchanged**; `--ship:--sh` stays so `--ship` and `--sh` both resolve.
5. `:145` and `:153` — remove `--ship` from the flag list and `--sh` from the bracket-minimum list in both hint strings. `:153`'s tail becomes `(short forms need at least --t, --exp, --rig, --ag, --pl)`.
6. `:167` — replace `ship_override=""; have_ship=0` with `ship_given=0`.
7. `:194` — `ship) ship_given=1 ;;` (the value is consumed by the shared `shift 2` above and not stored).
8. `:350-353` — **delete** the free-tier override block for ship entirely.
9. `:253-274` — extend the derived-list loop with `chat_types` and `publish_types`, built from each row's `ship` cell exactly as `build_types` is built from `pipeline` and `require_types` from `against`. Convention 7: the error must not hardcode `map`/`analyze`.
10. Immediately after `:476` (the `--pipeline` locked check) add the ship check, using `join_comma` for the derived lists and the repo's plain-language "which did you mean?" ending. Shape:

    > `--ship is locked: a type IS its ship mode, and type '<t>' ships '<ship>' — for a chat answer run <chat types>, for a published report run <publish types>?`

    Degrade the way `:479-483` and `:490-495` already do when a derived list comes back empty: drop that clause rather than printing an empty list.

**What must NOT change.** `VOCAB_SHIP` stays — the row's own `ship` cell is still validated against it at `:336`. `has_pr_phase` still keys on `$ship` at `:360`. `SHIP=` is still emitted at `:516`: the router consumes it, and locking the *flag* does not remove the *axis*.

**Acceptance criteria**
1. `resolve-type.sh feature --ship chat` exits **1** with the locked error naming `feature` and `publish` — the §A1 regression.
2. `resolve-type.sh analyze --ship publish` exits **1** with the same error, even though the value agrees with the row. Locked means locked; agreement is not an exemption.
3. `resolve-type.sh map --sh chat` exits **1** with the *locked* error — the bracket minimum still resolves, so the message is never "unknown flag".
4. `resolve-type.sh feature --ship` (no value) still errors on the missing value, unchanged.
5. `resolve-type.sh feature --shp publish` still errors as an **unknown flag**, and that message contains neither `--ship` nor `--sh`.
6. The locked error's type lists are derived: pointing `--yaml` at a fixture table whose rows use different type names produces those names in the message.
7. The `--pipeline` locked error is unchanged and fires **before** the ship check when both flags are passed.
8. `bash -n orchestrators/hooks/resolve-type.sh` is clean.

**Test approach:** 1.3 asserts each of the eight, including a `--yaml`-fixture case for criterion 6 — the suite already writes fixture tables with rows such as the `probe:` row at `tests/resolve-type.test.sh:532`.

**Test oracle:** `new contract tests` (authored in 1.3).

---

### 1.3 — `tests/resolve-type.test.sh`: locked ship, published analyze

**File scope:** `tests/resolve-type.test.sh` — this file, and only this file.

**Cases that must be rewritten** (verified locations; the coverage is still wanted, only the expectation moves — rewrite, do not delete):

- **Case 04, `:231-234`** — banner, label and assertion all say `SHIP=chat`. The point of the case (a `branch:` cell survives on a report row) still holds; the expectation becomes `SHIP=publish`, the banner and label stop saying "despite", and `RIGOR_PR=low` joins the asserted lines.
- **Case 29, `:551-568`** — the whole case is built on `--ship` being user-settable on `analyze`, and all three sub-cases die. `29a` (bare `analyze` has **no** `RIGOR_PR`) additionally inverts. Rewrite as: **29a** bare `analyze` **does** carry `RIGOR_PR=low`; **29b** `analyze --rigor pr:high` yields `RIGOR_PR=high` with **no** warning on stderr; **29c** `map --rigor pr:high` still warns on stderr and still exits **0** — the D2 warn-and-continue precedent, which must survive intact.
- **Case 36b, `:643-646`** — `--ship bogus` currently expects the value-vocabulary error (E10). `--ship` never reaches value validation now, so this becomes a **locked** (E3) assertion. **Case 36a (`:641-642`, `--explore bogus`) is unchanged** — the explore axis is still free, and that is the contrast the case exists to draw.

**Cases to verify unchanged, not edit** (each was checked and survives):

| case | lines | why it survives |
|---|---|---|
| 01 | `:189-209` | loops all ten types asserting a `^SHIP=` line exists — a value change does not affect it |
| 22a | `:451-453` | `analyze` → `RIGOR_EXPLORE=med`; the rigor cell is untouched |
| 23 | `:458-469` | `map analyze document` have no `RIGOR_CODE=` line — still true; a `report` pipeline gains `pr`, never `code` |
| 33 | `:596-599` | the canonical `--pipeline` E3 case — **copy its shape** for the new ship cases |
| 14c | `:383-385` | `--pi` resolves to `--pipeline` and is refused as locked — **copy its shape** for `--sh` |
| 34b | `:607-608` | `analyze --plan …` → E6; the pipeline axis is untouched |
| 43a/43b | `:711-748` | exact whole-stdout blocks for `feature` (already `SHIP=publish`) and `map` (`SHIP=chat`, and `map`'s row is untouched). Line 741 is `expected_map`'s closing `SHIP=chat'` — **`map`, not `analyze`; leave it alone** |
| `:652` | `feature --explore --ship publish` | asserts the "value looks like another flag" error. `--ship` still resolves as a flag token, so the behavior is unchanged — verify, do not edit |

**New cases to add**, one per uncovered acceptance criterion:

| new case | asserts |
|---|---|
| `feature --ship chat` | exit 1, locked error names `feature` and `publish` — **the §A1 regression test** |
| `analyze --ship publish` | exit 1, locked even when the value agrees with the row |
| `map --sh chat` | exit 1, the *locked* error, not "unknown flag" — the bracket minimum still resolves |
| `feature --shp publish` | exit 1, unknown-flag error whose text contains neither `--ship` nor `--sh` |
| `--yaml <fixture>` + `--ship` | the locked error's type lists come from the fixture's rows, not from `map`/`analyze` |
| `feature --pipeline build --ship chat` | the `--pipeline` error fires, not the ship one — locked-check ordering |
| **43c** | exact whole-stdout block for `analyze`, in KEY order, proving `SHIP=publish` and `RIGOR_PR=low` and nothing else — the same exact-equality shape as 43a/43b |

**Pattern to follow.** Match the file's own style exactly; introduce no second style. Section banners are 75-hash rules; case banners are `# --- Case NN: <title> ---` padded with dashes to column 78. Use the existing helpers — `run`, `run_in`, `ok_lines`, `no_lines`, `err_case`, `line`, `err_sub`, `err_tok`, `ctx` — and the hand-rolled long form (`bad=""` accumulator, then `if [ -z "$bad" ]; then pass … else fail … "$bad; $(ctx)"; fi`, as at `:557-568`) only where a bespoke predicate is genuinely needed. Labels repeat verbatim in both the `pass` and the `fail` arm. **Append new cases with the next free numbers; renumber nothing**, so a failure message still points where a reader expects. The E3 error vocabulary the suite asserts is the token `locked` plus the flag name plus the resolved type name (`:596-599`).

**Acceptance criteria**
1. `bash tests/resolve-type.test.sh` exits 0 with zero `FAIL:` lines.
2. Every one of 1.2's eight acceptance criteria has a case asserting it, and every one of 1.1's five.
3. `grep -n "SHIP=chat" tests/resolve-type.test.sh` matches only `map` cases; no case expects `SHIP=chat` from `analyze`, and no case expects `--ship` to be accepted on any row.
4. Case 36a and the `:652` flag-value case are byte-identical to before.
5. `bash -n tests/resolve-type.test.sh` is clean, and the file's own Case 00 `bash -n` precondition (`:169-183`) still runs first and unmodified.

**Test approach:** this subphase *is* the test approach for lane 1.

**Test oracle:** `new contract tests`.

---

### 2.1 — `resolve-scratch.sh`: the scratch dir joins the config chain

**File scope:** `orchestrators/hooks/resolve-scratch.sh` — **new file**; nothing else.

**Why a script and not prose in `report.md`.** Three reasons, all from the ask. **(a)** §C1: the path must resolve through the same four-scope chain as every other location, which means calling `resolve-config.sh` — prose cannot. **(b)** §C2: the collision fix needs a *deterministic, unique* path, not an instruction to be careful. **(c)** §F4: subphase 6.1 of the previous run left no durable suite because its subject was prose, and its tests ran from `/tmp` and are gone; this run is told the new chat/publish behavior *needs a committed test — it is exactly what regresses silently*. A script is testable; a paragraph is not. **This subphase, with 2.2, is F4's answer.**

**The resolution ladder** (§C3, in order; first hit wins):

1. **The configured var** — `CLAUDE_SCRATCH_DIR`, via `resolve-config.sh` with **no default**, so an unresolvable var falls through to rung 2 instead of erroring. Result: `<configured>/<slug>-<runid>/`.
2. **Inside a git repo** — `<main-checkout-root>/.artifacts/reports/<slug>-<runid>/`. The root is `dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`, exactly as `workflow-setup.sh:82` computes it and for the same reason: a run started inside some other worktree must not scatter its scratch into that worktree.
3. **Not a repo** — `${XDG_CACHE_HOME:-$HOME/.cache}/dae/reports/<slug>-<runid>/`. `map` must still work with a cwd that is not a repository at all (`report.md:8` already states this requirement); this rung preserves it.

**Why rung 2 has zero git side effects.** The repo's tracked `.gitignore` carries a bare `.artifacts/` entry (verified — `.gitignore` lines 5-6, committed) with **no leading slash**, so it matches `.artifacts/` at any depth, including `<repo-root>/.artifacts/`. A write there produces no untracked file in `git status`. `workflow-setup.sh:130-132` is what guarantees that entry exists, idempotently.

**The run id** (§C2). `<runid>` = `$(date +%Y%m%d-%H%M%S)-$$`, the same shape `workflow-setup.sh:100` already uses for a generated worktree name. It closes both collision bugs: *same question, same repo, concurrent* is separated by the PID; *same question, **different repos**, concurrent* — the serious one, because the current path has no project component at all — is separated by rung 2's repo root **and** the PID. A run id is required, not optional: worktree runs are protected by git refusing a duplicate branch, and a report run has no branch.

**Interface.**

```
resolve-scratch.sh --slug <slug> [--runid <id>] [--root <path>]
```

- `--slug` is **required**, and is slugified the way `workflow-setup.sh:96-101` slugifies `--name` (lowercase, non-alphanumerics collapsed to `-`, trimmed). An empty result is an error.
- `--runid` overrides the generated id, so the suite can assert an exact path. Not for orchestrator use.
- `--root` is passed through to `resolve-config.sh --root`, matching that script's own flag (`resolve-config.sh:38`), so the suite can point the chain at a fixture tree instead of the developer's real settings.

**Behavior.** `mkdir -p` the resolved directory — `report.md:8` requires it to exist before the Explore stage, so a crashed run leaves its claim files recoverable — then print, per convention 10:

```
SCRATCHDIR: <absolute path>
RUNID: <runid>
```

and on **stderr**, the resolution source in `resolve-config.sh:79`'s voice: `resolve-scratch: resolved via <configured var | git repo root | cache fallback>`.

**Header contract:** `#!/usr/bin/env bash`, title line, `SYNOPSIS`, `DESCRIPTION`, `EXIT CODES` (`0` resolved and created; `1` bad usage or mkdir failure), `set -uo pipefail`, an `err()` helper. Copy the shape of `resolve-config.sh:1-31`. **No `jq`.** Mode `0755`, matching six of the eight suites and every hook in `orchestrators/hooks/`.

**Acceptance criteria**
1. With `CLAUDE_SCRATCH_DIR` set in a fixture `.claude/settings.json`, the printed path is `<configured>/<slug>-<runid>` and stderr names the configured source.
2. With no var set, run inside a git repo, the path is `<main-checkout-root>/.artifacts/reports/<slug>-<runid>`.
3. Run from **inside a linked worktree** of that repo, rung 2 still yields the MAIN checkout's root — not the worktree's.
4. With no var set and a cwd that is not a git repo, the path is under `${XDG_CACHE_HOME:-$HOME/.cache}/dae/reports/` and the script exits **0**. Not being in a repo is never an error.
5. The directory exists on disk after the call.
6. Two calls with the same `--slug` and no `--runid` produce **different** paths.
7. `--slug` missing → exit 1 with a plain-language usage error; `--slug '///'` (empty after slugify) → exit 1.
8. The script invokes no `jq` and depends on nothing outside `awk`/`sed`/`grep`/git/bash builtins.
9. `bash -n` clean.

**Test approach:** 2.2 asserts all nine.

**Test oracle:** `new contract tests` (authored in 2.2).

---

### 2.2 — `tests/resolve-scratch.test.sh`: the new suite

**File scope:** `tests/resolve-scratch.test.sh` — **new file**; nothing else.

**Pattern to follow — the house skeleton, matched literally.** Seven of the eight existing suites are structurally byte-identical; the eighth, `tests/sync-install-settings-merge.test.sh`, is a deviant with different helper names and no `bash -n` precondition. **Do not use the deviant as the pattern.** Required elements, each with a reference:

- **Header block** — `#!/usr/bin/env bash`, `# resolve-scratch.test.sh`, then `SYNOPSIS` (a single `bash tests/resolve-scratch.test.sh` line), `DESCRIPTION` (including the house "Blind contract test … never reads the script under test's source" claim and an explicit statement of what is guaranteed untouched — `resolve-config-precedence.test.sh:20` is the model: *"The real $HOME, ~/.claude, and ~/.gemini are never read or written."*), `EXIT CODES` with exactly the two house lines, and the free-standing final line `# Runnable with no arguments from any working directory.` Reference: `tests/resolve-type.test.sh:1-38`.
- **`set -uo pipefail`** — no `-e`; failing cases must record and continue. Reference: `tests/resolve-type.test.sh:40`.
- **Self-location** — `REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` then `SCRIPT="$REPO_ROOT/orchestrators/hooks/resolve-scratch.sh"`. Reference: `tests/resolve-type.test.sh:42-46`.
- **Bookkeeping** — `TOTAL_PASS` / `TOTAL_FAIL` / `SCRATCH_DIRS=()`, the `cleanup()` + `trap cleanup EXIT` pair (with the `"${SCRATCH_DIRS[@]:-}"` expansion `set -u` requires), and `pass()` / `fail()` / `new_scratch()`. Reference: `tests/resolve-type.test.sh:48-78`.
- **Invocation helper** — `OUT` / `ERR` / `CODE` globals, stdin pinned to `/dev/null`, stdout and stderr captured to *separate* temp files, `CODE=$?` on the very next line, plus `ctx()`. Reference: `tests/resolve-type.test.sh:80-104`. Because this script's behavior depends on cwd and on `HOME`, use the `run_setup <repo> <home>` shape from `tests/workflow-setup-reuse.test.sh:101-119` rather than the bare `run`.
- **`bash -n` precondition as Case 00**, in the canonical form at `tests/resolve-type.test.sh:169-183` — including the literal `sanity failed: nothing else can be trusted, stopping.` line, the summary echo, and the early `exit 1`.
- **Case banners** `# --- Case NN: <title> ---`, labels `"NN: <assertion in present tense>"` repeated verbatim in both arms.
- **Summary block** — the identical closing eight lines shared by seven suites. Reference: `tests/resolve-type.test.sh:847-854`.

**Fixtures.** Build them with `new_scratch()`. Needed: a git repo with a `.claude/settings.json` carrying `env.CLAUDE_SCRATCH_DIR` (rung 1); a git repo with none (rung 2); a linked worktree cut from that repo via `git worktree add` (rung 2 from inside a worktree); and a plain `mktemp -d` with no `git init` (rung 3). For repo construction copy `tests/resolve-anchor.test.sh:123-152`'s wrapper, which is the only one that also pins `-c commit.gpgsign=false` — a host with commit signing on otherwise breaks the fixture. Every scratch dir is registered in `SCRATCH_DIRS`; the `git worktree add` fixture must additionally be unregistered (`git worktree remove`, or `rm -rf` of the whole containing repo followed by nothing that leaks) so the suite leaves no registered worktree behind.

**Precedent note for the builder:** grepping all of `tests/` for a not-a-git-repo assertion returns **zero hits** — no existing suite covers that branch. Criterion 4 establishes it, so there is no shape to copy; derive it from this block.

**Acceptance criteria**
1. One case per 2.1 acceptance criterion, 1 through 9, each independently named in its banner.
2. `bash tests/resolve-scratch.test.sh` exits 0 from the repo root, from `tests/`, and from `/` — the "runnable from any working directory" property every house suite claims of itself.
3. It never reads `orchestrators/hooks/resolve-scratch.sh`'s source. It is a blind contract test, written from 2.1's detail block; the file under test is invoked, never inspected.
4. It leaves nothing behind: no `mktemp` dir, no registered git worktree, no file inside this repo.
5. It never depends on the developer's real `~/.claude/settings.json` — every case pins `--root` at a fixture and pins `HOME`, and any case that could otherwise inherit a live `CLAUDE_SCRATCH_DIR` neutralizes it explicitly.
6. The file is mode `0755` and `bash -n` clean.

**Test approach:** this subphase *is* the test.

**Test oracle:** `new contract tests`.

---

### 2.3 — `artifact-locations` + `run-artifacts`: the scratch dir, and the docs var split

**File scope:** `agent-agnostic/rules/artifact-locations.md`, `agent-agnostic/rules/run-artifacts.md`.

**`artifact-locations.md`.** It opens *"Five artifact kinds, five locations. Four resolve through the SAME chain"* (`:8`). Both counts move — see **Counts, recomputed** below for the final figures, since this subphase adds two entries, not one. Add a bullet in its siblings' voice, positioned after the run-dir bullet:

> **The report scratch dir** — `CLAUDE_SCRATCH_DIR`, local default `<repo-root>/.artifacts/reports/<slug>-<runid>/` inside a git repo and `${XDG_CACHE_HOME:-$HOME/.cache}/dae/reports/<slug>-<runid>/` outside one. Where a `ship: chat` report run's explore map, committee claim files, and report land, because such a run has no worktree and therefore no run dir. Resolved by `resolve-scratch.sh`, which delegates rung 1 to `resolve-config.sh` — named the way the run-dir and base-branch bullets already name `workflow-setup.sh`.

Also amend the *Resolution chain* section's item 4 note — currently *"static for docs/plans/worktrees; a git heuristic for the base branch"* — to cover the new default's two-rung shape. **Keep** the standing sentence *"The run dir has no var of its own"*: the scratch dir now does, and the contrast is the point.

**The distinction that must be explicit,** because two different `.artifacts/` directories now exist and confusing them is the predictable failure: the **run dir** is `.artifacts/` at the root of a run's *parent worktree*; the **scratch dir default** is `.artifacts/reports/<slug>-<runid>/` at the root of the *main checkout*. The same unanchored `.gitignore` entry covers both; they have different owners and different lifetimes, and they are mutually exclusive per run — a run has a run dir or a scratch dir, never both.

**`run-artifacts.md`.** It opens *"Every dae run produces files in exactly two places"* (`:3`) and today mentions the scratch dir only in passing, inside the committee bullet (`:30`). Add the scratch dir as the third home, in one short block after the run-dir section: what lands there (the explore map, the `committees/<skill>/…` tree **by pointer to `committee.md`, never restated** per convention 11, and the report), that it is never committed, that it is resolved by `resolve-scratch.sh`, and that it belongs to `ship: chat` runs alone. The existing sentence at `:30` then shortens to a pointer at that block instead of half-defining the thing.

**(c) The docs variable splits in two — this is the round-2 decision, and it is the load-bearing half of this subphase.** `artifact-locations.md:9-13` currently makes `CLAUDE_DOCS_DIR` **shape-polymorphic**: a filesystem path selects `document-local`, an Atlassian URL or `confluence:` shorthand selects `document-confluence`, and — the sentence that is now false — a Confluence location *"becomes the source of truth (no local `/docs` is maintained)"*.

**Docs are LOCAL-PRIMARY.** Confluence is read-only for humans; edits happen in the repo. So:

- **`CLAUDE_DOCS_DIR` is ALWAYS a local filesystem path.** Its shape no longer selects a skill, and no caller anywhere may pattern-match its value. Delete the URL/shorthand alternatives and the source-of-truth sentence outright; keep the local default `/docs`. **Removing the shape-polymorphism is the point** — one var, one type.
- **A new optional var — `CLAUDE_DOCS_PUBLISH`** — holds the Confluence publish location, in the same two accepted forms the old var accepted (an Atlassian wiki URL, or `confluence:<SPACE>[/<Parent Page>]`). **Unset is the normal case** and means "record locally and stop". Set means "record locally, then additionally publish". It resolves through the identical four-scope chain; **`resolve-config.sh` needs NO code change** — it takes the var name as an argument and is entirely var-agnostic (`resolve-config.sh:43`, `:59-64`), verified.
- **The `<target>:` → `document-<target>` extensibility moves with it**, unchanged in spirit: the publish var's scheme selects the publish skill, and `confluence:` → `document-confluence` is the one mapping that exists today. State that an **unrecognized scheme is an error**, not a silently-ignored publish target — a typo'd `confluance:ENG` must not quietly mean "no publishing".
- **A URL or `<scheme>:` value in `CLAUDE_DOCS_DIR` is a HARD ERROR, not a warning and not a fallback.** State it in the rule; **4.1 enforces it in `resolve-config.sh`**, which is where it can be tested. The reason: a directory literally named after a URL is the failure nobody notices until something unrelated breaks on it, and the config chain has no other guard that would catch it. **A project carrying the old config stopping until someone edits `settings.json` is the correct outcome for a breaking config change** — the error names the split and points at `CLAUDE_DOCS_PUBLISH`, so the fix is one line in one file.
- **Say why, in one line, because the reason outranks the mechanism:** under Confluence-primary the PR gate goes blind — `review-pr` judges the branch diff, and docs that live only in Confluence are not in it. Local-primary keeps docs reviewable, diffable, revertible with the code, and covered by git's merge-conflict backstop.

**Name chosen:** `CLAUDE_DOCS_PUBLISH`. It names the **role** (a publish target) rather than the vendor, so the `<target>:` extensibility survives without a second rename. Rejected: `CLAUDE_CONFLUENCE_TARGET` (bakes in one vendor, contradicting `tech-agnostic`), `CLAUDE_DOCS_MIRROR` (implies two-way sync, which is exactly what this is not).

**Counts, recomputed.** The rule opens *"Five artifact kinds, five locations. Four resolve through the SAME chain"*. This subphase adds **two** entries — the scratch dir and the publish target — so the opening becomes **seven kinds, seven locations, six through the chain**. Count the bullets actually present rather than trusting this arithmetic.

**What must NOT change.** The absolute split — *"no plan, story, or review record under `<workflows-dir>/`; no progress log, contract, or exit report under the plans dir"* — holds unchanged, and the scratch dir joins the never-the-plans-dir side. **`orchestrators/agents/committee.md` is NOT edited and is not in any subphase's scope:** it already says *"on runs with no worktree the same relative layout lives under the scratch dir — identical layout, only the root moves"* (`committee.md:56`), which stays true and is the file that owns that fact. This is also §D's other half — `committee.md` defines only the artifact ROOT and says nothing about where members read, which is why worktree need is the wrapped skill's question, not the committee's.

**Acceptance criteria**
1. `artifact-locations.md`'s opening counts match the bullets actually present — count them, do not trust this plan's arithmetic.
2. The new bullet names `CLAUDE_SCRATCH_DIR`, both default rungs, and `resolve-scratch.sh`.
3. The two `.artifacts/` directories are distinguished explicitly, with the main-checkout-vs-parent-worktree contrast stated.
4. `run-artifacts.md` names the scratch dir as a home and points at `committee.md` for the member layout rather than restating it.
5. `git diff --name-only` does not list `orchestrators/agents/committee.md`.
6. Neither file gains a `jq`, a time estimate, or a branch on a type name.
7. **`CLAUDE_DOCS_DIR` is documented as always a local path.** Every URL / `confluence:` alternative is gone from its bullet, and `grep -n 'becomes the source of truth' agent-agnostic/rules/artifact-locations.md` returns nothing.
7b. **The frontmatter `description:` is updated too.** Line 2 currently reads *"… `CLAUDE_DOCS_DIR` may also name a Confluence location"* — the same inverted claim as the body, in different words and a different place, so criterion 7's `grep` does **not** catch it. It must name the split instead. Called out separately because a builder following the criteria literally would otherwise ship a rule whose own description contradicts it.
8. `CLAUDE_DOCS_PUBLISH` has its own bullet: optional, both accepted forms, unset = record-locally-and-stop, the `<target>:` → `document-<target>` mapping, and unrecognized-scheme-is-an-error.
9. The one-line reason (PR-gate blindness under Confluence-primary) is stated.
10. The rule states that a URL / `<scheme>:` value in `CLAUDE_DOCS_DIR` is a **hard error**, names `CLAUDE_DOCS_PUBLISH` as where such a value belongs, and says the migration is a one-line settings edit.
11. **`resolve-config.sh` is NOT edited by this subphase** — the rule states, 4.1 enforces. `git diff --name-only` for THIS subphase must not list it.

**Test approach:** none executable — these are rule documents with no script behind them. Verified by reading them against `resolve-scratch.sh`'s shipped behavior and against the committed `.gitignore`; criterion 5 is a mechanical check.

**Test oracle:** `existing implementation` — 2.1's shipped behavior is the truth source and the rules are derived from it, never the reverse. Contract-tester only, no coder. *(Declared honestly per §F3: this file scope contains no test file, so it does not claim `new contract tests`.)*

---

### 3.1 — `remove_empty_dir` tolerates an already-removed dir

**File scope:** `orchestrators/hooks/plan-lifecycle.sh` — this file, and only this file.

**The defect (§F2), confirmed in the tree.** `cmd_archive` moves `plan.md` out with `git_aware_mv` (`:301`), `git rm`s the remaining records (`:311-318`), then calls `remove_empty_dir "$plan_dir"` (`:320`), which is (`:170-174`):

```bash
remove_empty_dir() { # <dir> — plain rmdir, loudly fails if non-empty
  require_under_plans_dir "$1"
  if [ "$dry_run" = 1 ]; then echo "DRY-RUN: rmdir $1"; return 0; fi
  rmdir -- "$1" || err "rmdir failed (not empty?): $1"
}
```

`git mv` and `git rm` remove a directory they empty. So by the time `rmdir` runs the directory is frequently **already gone**, `rmdir` fails with ENOENT, and `err` exits **1** — after the archive has fully succeeded, and *before* the `echo "archived: …"` at `:323`. The caller sees a failure, and the message names the wrong cause: it says "not empty?" when the directory is not there at all. Hit live at this session's own closeout.

**The fix.** Treat an already-absent directory as success — the postcondition (`$1` does not exist) is satisfied either way:

```bash
remove_empty_dir() { # <dir> — the dir must not survive; already-gone counts
  require_under_plans_dir "$1"
  if [ "$dry_run" = 1 ]; then echo "DRY-RUN: rmdir $1"; return 0; fi
  [ -d "$1" ] || return 0        # git mv / git rm already took it
  rmdir -- "$1" || err "rmdir failed (not empty?): $1"
}
```

Update the function's own comment to say what it now means. **Keep the non-empty failure loud** — that guard is the real one, and this fix must not weaken it into `rm -rf` or `rmdir --ignore-fail-on-non-empty`. `remove_empty_dir` has exactly one caller (`:320`), verified, so the blast radius is `archive` alone. `require_under_plans_dir` stays first, before any filesystem test.

**Acceptance criteria**
1. `archive` on a plan dir whose entries are all git-**tracked** exits **0** and prints `archived: <src> -> <dest>` plus one `removed:` line per record.
2. `archive` on a plan dir whose entries are **untracked** (the `mv`/`rm` fallback path, which leaves the dir behind) also exits 0, and the directory is gone.
3. A plan dir containing an unexpected leftover still fails — from the pre-flight entry check at `:265-272`, which is unchanged.
4. If a directory somehow survives non-empty at `:320`, `rmdir` still fails loudly with the existing message.
5. `--dry-run` still prints `DRY-RUN: rmdir <dir>` and changes nothing.
6. `require_under_plans_dir` still refuses a path outside the plans dir, before the existence test.
7. `bash -n orchestrators/hooks/plan-lifecycle.sh` clean.

**Test approach:** 3.2 adds the regression case; existing archive cases 04, 05, 06, 07, 08, 09 and 17b must all still pass.

**Test oracle:** `existing suite` — `tests/plan-lifecycle.test.sh` already covers `archive`'s guards and success paths end to end (36 cases); 3.2 extends it with the one case it was missing.

---

### 3.2 — `tests/plan-lifecycle.test.sh`: the F2 regression case

**File scope:** `tests/plan-lifecycle.test.sh` — this file, and only this file.

**Why the existing suite missed this.** Case 04 (`:440-449`) archives a fully-shipped plan and asserts `CODE -eq 0`. It *should* have caught F2, so the first job of this subphase is to establish why it did not, and say so in the exit report. The likely answer is that the fixture's plan-dir entries are not committed in the way the live path exercises, so `git mv`/`git rm` never empty the directory. Whatever the real answer is, the new case must reproduce the **live** conditions: a plan dir whose `plan.md` and record files are all committed, so `git mv` and `git rm` really do remove the directory.

**The new cases.** Archive a committed plan dir holding `plan.md` plus at least two record files (`plan-review.md` and `code-review.md`, both on `cmd_archive`'s allowlist at `:270`), asserting:

- exit **0**;
- stdout carries `archived: <plan-dir>/plan.md -> <completed>/<slug>.md` and one `removed:` line per record;
- **stderr contains no `rmdir failed`**;
- `<completed>/<slug>.md` exists and `<plan-dir>` does not.

Add a companion case for the untracked path (a plan dir the fixture never `git add`s) asserting the same four, so both branches of `git_aware_mv` / `git_aware_rm` are covered.

**Pattern to follow:** the file's own case style — `run_script archive "$plans_dir/<fixture>" "${common_flags[@]}"` — and its fixture-construction block around `:170-180`. Append with the next free case numbers (the file currently runs `01`…`35`); renumber nothing.

**Acceptance criteria**
1. Both new cases pass against 3.1's fix.
2. At least one of them **fails** against the pre-3.1 script. Verify by stashing the fix, running the suite, and recording the observed failure in the exit report. A regression test that passes both ways is not a regression test.
3. `bash tests/plan-lifecycle.test.sh` exits 0 with zero `FAIL:` lines; every pre-existing case still passes.
4. The exit report states why case 04 did not already catch F2.
5. `bash -n` clean.

**Test approach:** this subphase *is* the test.

**Test oracle:** `new contract tests`.

---


---


---


---

### 4.1 — `resolve-config.sh --expect`: enforce the var split where it can be tested

**File scope:** `orchestrators/hooks/resolve-config.sh` — this file, and only this file.

**Round 3 brought this file back into scope, and closed R12 with it.** Round 2 removed the parked `--kind` flag because it had zero script consumers; that reasoning still holds and `--kind` stays dead. But the A8 hard error must live *somewhere*, and the resolver is the one place that both sees every config value and **has a test suite** (`tests/resolve-config-precedence.test.sh`, 20+ cases). Putting the check here rather than in the router also lets the **publish-scheme** check ride along — which is exactly what R12 needed and could not get from prose in `dae/SKILL.md`. **R12 is closed by this subphase**, without restoring `--kind`.

**Keep the script var-agnostic — this is the design constraint that shapes the flag.** `resolve-config.sh` knows nothing about which var it is resolving (`:43`, `:59-64`), and it must stay that way: a `if var == CLAUDE_DOCS_DIR` special case would make a generic resolver carry a table of its callers. So the **caller declares what shape it expects**, and the script validates the value against that declaration.

**The interface — additive, stdout-compatible by construction (convention 17).**

```
resolve-config.sh <VAR_NAME> [--default <v> | --base-branch-default] [--root <path>] [--expect path|publish-target]
```

Omitting `--expect` is the existing behavior, **byte-identical** — so `workflow-setup.sh`, `allow-workflow-cleanup.sh`, and every prose caller keep working untouched. With `--expect`:

- **`--expect path`** — the resolved value must be a filesystem path. An Atlassian wiki URL (`https://<site>.atlassian.net/wiki/...`) or any `<scheme>:` prefix is a **hard error**, exit 1. The message names the split and points at the publish var: *"CLAUDE_DOCS_DIR must be a local path; a Confluence location belongs in CLAUDE_DOCS_PUBLISH."* Do not hardcode `CLAUDE_DOCS_DIR` in that message — use the var name the caller passed (`$var`), so the script stays generic and the message stays specific.
- **`--expect publish-target`** — the resolved value must name a known publish target: an Atlassian wiki URL, or `confluence:<SPACE>[/<Parent Page>]`. Anything else — a bare path, or an **unrecognized scheme** such as a typo'd `confluance:ENG` — is a hard error naming the schemes that ARE known, **derived from the script's own scheme list rather than a hardcoded message literal** (convention 7). This is the check R12 flagged as untestable prose.

**The scheme-vs-path discrimination, stated once so both arms share it:** a leading `<word>:` is a scheme. An absolute or relative filesystem path is not. Be careful with the edge cases and write them down: a Windows-style `C:\...` and a path containing a colon mid-segment must not be misread as schemes. If the builder judges any edge case genuinely ambiguous, it is a needs-input for the reviewer, not a guess.

**What must NOT change.** `env_value_from()`, the six-file resolution order (`:59-64`), the stderr source note (`:79`), the exit-1-on-unresolvable behavior (`:76`), and the `--default` / `--base-branch-default` / `--root` semantics. **No `jq`.**

**Acceptance criteria**
1. Without `--expect`, stdout and stderr are **byte-identical** to before this change, for every existing case in the suite.
2. `--expect path` accepts `/docs`, `docs`, `/srv/x/docs`, and a path containing a colon mid-segment.
3. `--expect path` **rejects** `https://acme.atlassian.net/wiki/spaces/ENG` and `confluence:ENG`, exit 1, with a message naming the passed var and pointing at `CLAUDE_DOCS_PUBLISH`.
4. The rejection message uses the var name the caller passed — pointing the script at a different var name produces that name in the message.
5. `--expect publish-target` accepts an Atlassian wiki URL (with and without a `/pages/...` tail) and `confluence:ENG` / `confluence:ENG/Handbook`.
6. `--expect publish-target` **rejects** a bare path, and rejects `confluance:ENG` with a message listing the known schemes, derived rather than hardcoded.
7. `--expect` composes with `--default` and `--root`, and validates a value that came from the DEFAULT as well as one that came from settings.
8. An unresolvable var still exits 1 as today; `--expect` does not invent a value.
9. An invalid `--expect` argument is a usage error.
10. No `jq`; `bash -n` clean.

**Test approach:** 4.3 extends `tests/resolve-config-precedence.test.sh`, whose `run_resolve <HOME> <VAR> …` wrapper (`:19`) already pins `HOME` and `--root` at fixtures.

**Test oracle:** `new contract tests` (authored in 4.3).

---

### 4.2 — `verify-run-scope.sh`: drop the dead branch, declare the expectation

**File scope:** `orchestrators/hooks/verify-run-scope.sh` — this file, and only this file.

**Two edits, one deletion and one addition.**

**(a) Delete the dead `case`.** `:112-116` reads:

```bash
case "$docs" in
  http*|confluence:*) : ;;                # docs live off-repo — no local docs allowance
  *) allowed="$allowed
$(norm "$docs")" ;;
esac
```

After 2.3 and 4.1, `CLAUDE_DOCS_DIR` **cannot** hold `http*` or `confluence:*` — the resolver refuses it. The first arm is unreachable. **Delete the `case` and keep only its `*` arm's body:** the docs prefix is always allowed, because there is always a local docs tree. The file gets shorter.

**(b) Declare the expectation at the call.** `:107` becomes `resolve-config.sh CLAUDE_DOCS_DIR --default /docs --root "$wt" --expect path`. This is what makes (a) safe rather than merely optimistic: the deletion assumes a path, and `--expect path` is the assumption stated and enforced.

**The fallback needs care, and it is the one subtle thing here.** `:107` ends `2>/dev/null || echo /docs` — a resolver failure silently falls back to `/docs`. With `--expect path` that fallback now also swallows a *legitimate rejection*: a project with the old Confluence config would have its refusal converted into "docs are at `/docs`". **That is wrong and must not ship.** Distinguish the two: an unresolvable var still falls back to `/docs` (existing behavior, conservative), but a **rejection** must surface — the gate should fail loudly with the resolver's message rather than scan against a fabricated docs root. **Distinguish them on the MESSAGE, not the exit status** — both failure modes exit 1 (`resolve-config.sh`'s existing `err "cannot resolve $var (…)"` path, and 4.1's `--expect` rejection alike), so there is no distinguishing exit code to look for and a builder must not go hunting for one. The two message shapes are textually distinct and that is the whole signal. Comment why the two cases are not the same.

**What must NOT change.** The plans-dir resolution at `:106`, `norm()`, the `--allow` extras handling, and everything downstream of the allowed-prefix construction.

**Acceptance criteria**
1. With `CLAUDE_DOCS_DIR` a local path, the allowed-prefix list is **byte-identical** to before — same entries, same order. This is a pure dead-code removal plus a declaration; any behavior change here is a defect.
2. `grep -n 'http\*\|confluence:' orchestrators/hooks/verify-run-scope.sh` returns nothing.
3. The `resolve-config.sh` call passes `--expect path`.
4. An **unresolvable** `CLAUDE_DOCS_DIR` still falls back to `/docs` and the run continues.
5. A **rejected** `CLAUDE_DOCS_DIR` (old Confluence config) surfaces the resolver's error rather than falling back — verified by a case, not by inspection.
6. A comment explains why (4) and (5) differ.
7. The file is shorter than before.
8. `bash -n` clean.

**Test approach:** 4.3.

**Test oracle:** `existing suite` — extended by 4.3.

---

### 4.3 — Tests for the expectation flag and the scope script

**File scope:** `tests/resolve-config-precedence.test.sh`, `tests/verify-scope-parsing.test.sh`, and — only if this subphase concludes no suite covers `verify-run-scope.sh` (see below) — `tests/verify-run-scope.test.sh` *(new)*.

**`tests/resolve-config-precedence.test.sh`** gains one case per 4.1 criterion 1-10, appended with the next free numbers, reusing its own `run_resolve` wrapper and settings-fixture builders. **Criterion 1 (stdout byte-identity) is the important one** and must be an exact-equality assertion against a captured baseline, not a substring check — it is what proves the flag is additive.

**`verify-run-scope.sh` ownership must be established by reading, not by `grep -l`.** That pattern matches `tests/verify-scope-parsing.test.sh`, **but a name appearing in a file is not proof its `SCRIPT=` variable points there** — that suite may test `verify-scope.sh` and merely mention its sibling. Confirm before extending. If it does not cover `verify-run-scope.sh`, do not bend it: add `tests/verify-run-scope.test.sh` on the house skeleton (2.2's pattern list applies verbatim). **Guessing wrong here silently un-tests 4.2**, including criterion 5, which is the one that protects a user with the old config.

**Acceptance criteria**
1. Every 4.1 criterion and every 4.2 criterion has a case asserting it.
2. Criterion 1's byte-identity case would **fail** if `--expect`'s implementation altered default stdout — verify by perturbing, observing, reverting, and recording in the exit report.
3. 4.2 criterion 5 (rejection surfaces, does not fall back) has its own case; it is the regression that protects the migration path.
4. Ownership is confirmed by reading, and the exit report says which suite took the `verify-run-scope.sh` cases and why.
5. The suite(s) exit 0 with zero `FAIL:` lines; every pre-existing case still passes.
6. Any new suite is mode `0755` and is counted by 9.3 and 10.1.
7. `bash -n` clean on every file touched.

**Test oracle:** `new contract tests`.

---

### 5.1 — `doc-format`: mirror/symlink applies ALWAYS; publishing is CI's job

**File scope:** `agent-agnostic/rules/doc-format.md` — this file, and only this file.

**The carve-out dies with its premise.** The rule opens: *"This rule's mirror/symlink structure applies to LOCAL mode (a filesystem docs root); when `CLAUDE_DOCS_DIR` names a Confluence location, Confluence is the single source of truth, no local `/docs` is maintained, and page structure follows the `document-confluence` skill."* That sentence exists **only** because Confluence-primary meant there was no local tree.

- **Delete the carve-out.** Mirror/symlink structure, naming, and one-page-per-topic apply **unconditionally**. No "local mode" qualifier survives, because there is no other mode.
- **Replace it with the publish relationship, and name CI as the publisher.** Docs live in the repo under the resolved `CLAUDE_DOCS_DIR`. When `CLAUDE_DOCS_PUBLISH` is set, they are **additionally mirrored to that target by a CI job on merge** — not by any agent, and not as a stage of any run. `document-confluence` exists as a **manual/recovery** sync for when CI has not run or has failed (5.2).
- **State the direction and the consequence:** publication is **one-way, repo → target**. Confluence is read-only for humans; an edit made there is not a source change and is overwritten by the next sync. A reader who does not know this will eventually edit a page and lose it.
- **State that reading docs means reading the local tree**, in every configuration. Say it explicitly so nobody later re-derives a read abstraction from the absence of a statement — **round 2 removed exactly that**, and a silence is how it comes back.
- **Extend the closing scope sentence:** *"format and placement only"* stays true; **how** a published copy is produced is now CI's job, not a skill's.

**What must NOT change.** Every write-side rule: mirror layout, symlink-never-copy, naming, one-page-per-topic. They are correct and now apply more broadly, not differently.

**Acceptance criteria**
1. `grep -n 'LOCAL mode\|local mode' agent-agnostic/rules/doc-format.md` returns nothing.
2. The mirror/symlink/naming/one-page rules are byte-identical apart from removing any "in local mode" qualifier.
3. A publish paragraph names `CLAUDE_DOCS_PUBLISH`, says the publisher is **a CI job on merge**, and describes repo → target as **one-way**.
4. `document-confluence` is described as manual/recovery only, never as a run stage.
5. The Confluence-is-read-only-for-humans consequence is stated, including that an edit there is lost on the next sync.
6. One sentence states that reading docs means reading the local tree, in every configuration.
7. The closing scope sentence attributes publishing to CI.
8. No time estimate, no `jq`, no branch on a type name.

**Test approach:** none executable — a rule document. Verified by reading against 2.3's shipped var split and 5.4's shipped template; criteria 1 and 2 are mechanical.

**Test oracle:** `existing implementation`. Contract-tester only, no coder.

---

### 5.2 — `document-confluence`: REWRITE as a manual/recovery sync skill

**File scope:** `tool-based/confluence/skills/document-confluence/SKILL.md` — this file, and only this file. **The run's only `tool-based/skills/` file.**

**This subphase is a REWRITE, and the coordinator asked to be told that rather than have the existing stages bent into a role they were not built for. They were not.** I judged each of the seven stages against the demoted role — *sync the local docs tree to Confluence, outside any run* — and the majority does not survive:

| current | verdict under the sync role |
|---|---|
| Frontmatter `description:` — *"the documentation phase … invoked by the dev/map orchestrators"* | **REWRITE.** Wrong role, wrong callers, and it is the string a dispatcher matches on |
| `## When to use` — three run-triggered entries | **DIES.** There is no run trigger; it is invoked by a human or as CI recovery |
| `## Inputs` — parsed target, Jira keys, Drive folder, **plan path, story file, build/review summary** | **MOSTLY DIES.** A sync reads the **local docs tree**; it has no plan, no story, and no diff |
| The three run shapes — change-driven / map-driven / reconciliation-driven | **ALL DIE.** They classify *what a run produced*. A sync has exactly one shape: mirror the tree |
| Stage 1 — connect preflight | **SURVIVES** |
| Stage 2 — gather facts; **mark the plan syllabus** | **DIES.** Syllabus marking is `document-local`'s job and was never this skill's business outside a run |
| Stage 3 — publish story + technical page | **RESHAPED.** Publish doc pages mirroring the tree; the story/narrative sections have no source |
| Stage 4 — changelog page | **RESHAPED**, and optional: a changelog derived from the docs tree, not from a run |
| Stage 5 — link Jira bidirectionally | **DIES.** No run, no governing ticket |
| Stage 6 — Drive offload | **SURVIVES.** `external-storage-cap` still governs |
| Stage 7 — verify | **SURVIVES** |

Three of seven stages survive; two die outright, two reshape; the Inputs contract and the entire run-shape taxonomy die. **That is a rewrite.** Attempting it as an edit would leave plan/story plumbing threaded through a skill that never receives either.

**Note what this dissolves.** Round 2's 5.2(b) — fixing the **five dead-orchestrator references** (`dev`, `map`, `sync-status` at `:3`, `:17`, `:18`, `:29`, `:30`, `:54`) — is now moot as a *fix*: those lines live in the `When to use`, `Inputs` and hand-off sections being replaced. The **requirement survives as an acceptance criterion**: no retired orchestrator name may appear in the rewritten file.

**What the rewritten skill is.** A `domain: confluence`, `context: fork` skill that: resolves `CLAUDE_DOCS_DIR` (`--expect path`) and `CLAUDE_DOCS_PUBLISH` (`--expect publish-target`) via `resolve-config.sh`; preflights the Atlassian and Drive MCP connections; walks the local docs tree; creates or updates one Confluence page per doc, mirroring the tree's structure; offloads large or binary artifacts to Drive per `external-storage-cap`; deletes or flags pages whose source doc is gone; and verifies by re-reading. **It never authors documentation and is never a source of truth** — its `description:` must say so outright, because that string is what stops a future reader mistaking it for `document-local`'s Confluence twin.

**Preserve these, deliberately:** `domain: confluence`, `context: fork`, the `rules:` list including `external-storage-cap`, `model: sonnet`, the **needs-input discipline** (`:33` — stop and name exactly what is missing rather than guessing), the connect-preflight instinct (`:37`), and the convention of naming MCP **capabilities, never tool-function names** (`:58`). These are the parts that were right regardless of role.

**Say why it still exists**, in one line, so the demotion does not read as deprecation: CI is the normal publisher (5.4); this skill is what a human runs when CI has not run, has failed, or when a target is being backfilled for the first time.

**And note its installability:** `domain: confluence` means it installs with the Confluence layer into consuming projects, **never into `~/.claude/`** (`source-push-sync`). Under the CI model this is no longer a silent-failure risk — nothing in a run dispatches to it — which is one more way the decision reduced exposure.

**Acceptance criteria**
1. The `description:` names it a manual/recovery **sync** skill that mirrors the local docs tree to Confluence, explicitly not an author and not a source of truth.
2. `grep -n 'sync-status\|`dev` orchestrator\|`map` orchestrator\|dev/map' <file>` returns nothing.
3. `grep -n 'source of truth\|no local /docs\|instead of the repo' <file>` returns nothing claiming Confluence is canonical.
4. No plan path, story file, build summary, diff, or syllabus marking appears anywhere in its inputs or stages.
5. The three run shapes are gone; there is one shape.
6. It resolves both vars through `resolve-config.sh` with the matching `--expect`.
7. Drive offload and `external-storage-cap` survive; the needs-input discipline and capability-not-tool-name convention survive.
8. Frontmatter `domain`, `context`, `rules`, `model`, `model-fallback` are unchanged; only `name` stays and `description` is rewritten.
9. One line states why it still exists alongside CI.
10. Stale-page handling is specified: a page whose source doc was deleted is removed or flagged, never left silently.

**Test approach:** none executable, and **not executable even in principle here** — it needs a live Atlassian MCP connection this repo's test set cannot provide (R10). Criteria 2, 3, 4, 5 and 8 are mechanical (`grep`, diff); the rest are verified by reading.

**Test oracle:** `existing implementation` — the shipped skill's surviving parts plus 2.3's var split are the truth source. Contract-tester only, no coder.

---

### 5.3 — `confluence-mode.md`: what survives, and what was never about docs

**File scope:** `orchestrators/skills/dae/confluence-mode.md` — this file, and only this file.

**The finding this subphase acts on.** Read in full (20 lines). **Most of it survives, because most of it was never about where docs live** — the file conflates two independent concerns, and separating them is the whole edit:

| part | verdict |
|---|---|
| `:3` — *"Confluence becomes the docs source of truth, `document-confluence` is the record stage, and no local `/docs` is maintained"* | **DIES.** All three clauses false. The only sentence carrying the inverted premise |
| `:5-13` — the ask verbatim, narrative, acceptance criteria, constraints, stakeholders, Jira key(s) | **SURVIVES WHOLE.** This is **Jira/requirements capture**, triggered by ticket-tracked work, entirely orthogonal to where docs live |
| `:14` — *"The **publish targets**: confirm the Confluence space and parent page … and the Google Drive folder"* | **SURVIVES, already correctly named.** Only its source changes: `CLAUDE_DOCS_PUBLISH`, not `CLAUDE_DOCS_DIR`. These are now **CI's** targets, confirmed with the user once rather than per run |
| `:16-18` — the story file, its sections, promotion to `story.md`, the planner consuming its criteria | **SURVIVES WHOLE**, and becomes *more* load-bearing — see below |
| `:20` — the record-stage hand-off to `document-confluence` | **REWRITTEN.** There is no in-run publish step. It now says: the record stage is `document-local`, always; publishing to Confluence is **a CI job on merge** (5.4), with `document-confluence` as manual recovery (5.2) |
| the trigger condition | **CHANGES** — from "the docs target resolves to a Confluence location" to "`CLAUDE_DOCS_PUBLISH` is set" |

**The story file IS the ask of record — connect them rather than building a parallel mechanism.** `:18` says `story.md` carries **"Original Ask (verbatim)"** and that *"the planner consumes it (its acceptance criteria become plan constraints)"*. Phase 7 requires every plan to point at a durable ask artifact. **These are the same mechanism**; 7.1 accepts `story.md` as satisfying the pointer rather than demanding a second file. Say so here and in 7.1.

**Do NOT generalize the story file to every run.** It carries Jira keys, stakeholders and publish targets a plain ask does not need. The ask pointer names whichever durable artifact exists — `the-ask.md` or `story.md`.

**On the filename.** "confluence-mode" is now a mild misnomer — it is no longer a *mode*. **Keeping it, per the coordinator's accepted call:** renaming costs edits in `dae/SKILL.md:103`, `:111` and `docs/pipeline.md:154` for no behavioral gain.

**Acceptance criteria**
1. `:3` is replaced: the local docs tree is the source of truth; this file applies when `CLAUDE_DOCS_PUBLISH` is set.
2. The requirements-capture section (`:5-13`) is **byte-identical**, and the file says plainly that it is Jira/requirements capture, independent of where docs live.
3. `:14`'s publish targets parse from `CLAUDE_DOCS_PUBLISH` and are described as CI's targets.
4. The story-file section is intact and states that `story.md` satisfies Phase 7's ask-of-record pointer.
5. `:20` names CI as the publisher and `document-confluence` as manual recovery; **no in-run publish step is described**.
6. The filename is unchanged.
7. Nothing here restates what `document-confluence` or 5.4's template own.

**Test approach:** none executable. Verified by reading against 2.3, 5.2 and 5.4; criterion 2 is a mechanical diff check.

**Test oracle:** `existing implementation`. Contract-tester only, no coder.

---

### 5.4 — The docs→Confluence publish workflow: canonical in `.github/`, surfaced in `scripts/`

**File scope:** `.github/workflows/publish-docs.yml` *(new)*, `scripts/publish-docs.yml` *(new — a symlink)*, `scripts/README.md` *(new)*, `tool-based/confluence/ci/README.md` *(new)*.

**The requested link direction does not work. VERIFIED both ways — do not re-litigate this, and do not "fix" the symlink back.**

1. **Mechanism, proven locally in a throwaway repo.** With `scripts/publish-docs.yml` a real file and `.github/workflows/publish-docs.yml` a symlink to it, `git ls-files -s` reports the `.github` path as mode **`120000`**, and `git cat-file -p` on its blob prints exactly `../../scripts/publish-docs.yml` — **the target path string, not YAML.** That is what a consumer reading the blob receives.
2. **Behavior, confirmed externally.** GitHub does **not** resolve symbolic links when parsing workflows in `.github/workflows`; a symlink there fails CI immediately. It is an open feature request ([community discussion #109744](https://github.com/orgs/community/discussions/109744)), not a supported pattern.

**So the arrow inverts, and nothing else about the user's structure changes.** Every property they asked for survives:

| the user wanted | preserved by the inverted arrow |
|---|---|
| clearly tracked | both paths are tracked; the symlink is a committed repo object |
| viewable in a scripts dir | `cat scripts/publish-docs.yml` resolves and prints the YAML |
| easily copyable by other projects | one real file at a conventional, discoverable path |
| one thing, not two | still exactly one real file — only its home moved |

- **Canonical:** `.github/workflows/publish-docs.yml` — a **real file**, where Actions is certain to read it.
- **`scripts/publish-docs.yml`** — a **symlink** to `../.github/workflows/publish-docs.yml`.
- **This still matches the house convention.** `doc-format:11` says *"If the same content ever exists in two places, one of them must become a symlink"* — the rule constrains **duplication**, not which end is canonical. One real file, one link. Satisfied.

**`scripts/README.md` must explain the inversion**, because a symlink pointing "backwards" into `.github/` reads as a mistake to the next person and will otherwise be "corrected" into breakage. State the mechanism, the GitHub limitation, and that the direction is deliberate.

**The new top-level directory.** No `scripts/`, `bin/`, or `tools/` exists — top level is `agent-agnostic/ agent-specific/ docs/ orchestrators/ project-plans/ tests/ tool-based/` (verified). **`scripts/` is the name**: it is the user's own word, it is the near-universal convention, and unlike `bin/` it does not imply compiled or executable-only content. It is a genuine structural addition and 9.3 must add it to every tree block that enumerates the top level.

**On "maybe with install" — noted, not acted on.** The dir is a plausible future home for install tooling. **`orchestrators/hooks/sync-install.sh` does NOT move**: it is live and load-bearing — this repo's own push flow depends on it (`.claude/rules/source-push-sync.md:3`) — and relocating it mid-plan is precisely the unrequested churn that breaks things. Recorded as intent, planned as nothing.

**One artifact or two — DECIDED: one, and `tool-based/confluence/ci/` gets a REFERENCE, not a copy.**

A third *file* would drift, and this codebase has been bitten by drift repeatedly. But a third *symlink* is worse than drift here, and this is the trap worth naming: a symlink committed under `tool-based/confluence/ci/` ships to a consuming project as a blob containing `../../../.github/workflows/publish-docs.yml` — a path that either does not exist there or, worse, resolves onto that project's own unrelated workflow. **A dangling or mis-resolving symlink is a live hazard, not a stale copy.**

So `tool-based/confluence/ci/README.md` **references the canonical path in prose** and tells a consuming project to copy that file into its own `.github/workflows/`. A prose reference cannot drift into a wrong copy, and cannot resolve onto the wrong file.

**What the workflow does.** Stated as a contract before it is stated as YAML:

- **Trigger:** on merge to the base branch, path-filtered to the resolved docs root so unrelated merges do not republish.
- **Resolve** `CLAUDE_DOCS_PUBLISH` (`--expect publish-target`) and `CLAUDE_DOCS_DIR` (`--expect path`) through `resolve-config.sh`. **Unset publish var → no-op, exit 0.**
- **Mirror** the docs tree to the target: one page per doc, structure preserved, large/binary artifacts to Drive per `external-storage-cap`, stale pages removed or flagged.
- **Fail loudly** on auth or target errors — but **never gate the merge**, which has already happened. The job reports; it does not block.
- **Credentials come from the consuming project's CI secrets**, named in the README, never committed and never defaulted.

**The no-op here is a FEATURE, and must be graceful rather than an error.** This repo has no Confluence target, so the job resolves an unset `CLAUDE_DOCS_PUBLISH` and exits 0 with a clear "no publish target configured; nothing to do" message. That is worth having: it proves the YAML parses, proves the trigger fires, and demonstrates to a consuming project exactly what it will see before configuring a target. **A no-op that logged an error would teach the opposite lesson.**

**Platform, and the tension worth naming.** GitHub Actions is the concrete form — this repo's tooling already assumes GitHub (`push-pr`, `review-pr`, `comment-pr` all drive `gh`), so it is an established assumption, not a new one. But CI platform is **not** the Confluence axis, so `tool-based/confluence/ci/README.md` must state the contract **platform-neutrally** — trigger, resolution, mirror, failure semantics — so a project on another CI can implement the same thing.

**Acceptance criteria**
1. `.github/workflows/publish-docs.yml` is a **real file** — `git ls-files -s` shows mode `100644`, not `120000`.
2. `scripts/publish-docs.yml` is a **symlink** to it — mode `120000` — and `cat` through it prints the YAML.
3. `scripts/README.md` explains the inverted direction, citing both the git mechanism and the GitHub limitation, so it is not "fixed" later.
4. **No symlink exists under `tool-based/`** — `find tool-based -type l` returns nothing. Its README references the canonical path in prose.
5. The workflow triggers on merge to the base branch, path-filtered to the docs root.
6. An unset `CLAUDE_DOCS_PUBLISH` produces a **graceful no-op, exit 0**, with an explanatory message — not an error, not a skipped-with-warning.
7. Both vars resolve through `resolve-config.sh` with the matching `--expect`; neither is read as a raw env var.
8. Failures are loud and do not gate the merge.
9. No credential, token, space key, or Drive folder id is committed or defaulted.
10. `tool-based/confluence/ci/README.md` states the contract platform-neutrally, names required secrets, states the one-way direction, and points at `document-confluence` for manual recovery.
11. The YAML is syntactically valid — parse it with whatever exists (`python3 -c 'import yaml'` if available); **if no YAML parser exists here, say so in the exit report rather than claiming a check that did not run.**

**Test approach:** no bash suite can exercise a CI workflow — there is no runner here. Criteria 1, 2 and 4 are mechanical (`git ls-files -s`, `find -type l`), criterion 11 is a parse if a parser exists, and criterion 6 is verified by reading the no-op branch. **Recorded honestly rather than dressed up** (R10 extends to cover these files).

**Test oracle:** `existing implementation` — 2.3's var split and 4.1's `--expect` semantics are the truth source. Contract-tester only, no coder.
### 6.1 — `explore/SKILL.md`: exclusions, the raw env read, DEEP precedence

**File scope:** `agent-agnostic/skills/explore/SKILL.md` — this file, and only this file.

Three changes. (a) is the original §B1 work; (b) and (c) are the two amendment-A4 defects that **survive the local-primary decision**. All three land in one subphase because they are one file and one lane; each is independently checkable.

**What round 2 removed from this subphase.** The parked design had two more items: a *path-assumption* fix and a *SHALLOW-reads-nothing-in-Confluence-mode* fix. **Both dissolve.** `CLAUDE_DOCS_DIR` is now always a local path (2.3), so treating it as a path is correct, and SHALLOW reading the local docs tree is correct in every configuration. **The raw-env-var defect survives** — it was never about Confluence.

**(a) §B1 — DEEP means the project, not its dependencies.** The file contains **zero** mentions of `.git`, `node_modules`, `vendor`, or any equivalent, and DEEP is specified as *"Read the entire target: source, config, tests, build files, docs"* (`:36`). A DEEP pass on a JS project would walk `node_modules`. This is what the user's *"max depth (excluding known module dirs like .git, node_modules, whatever python/go/java/c# use)"* remark was about: making DEEP genuinely *complete* over the project, and correspondingly bounded at the project's edge. **It was never about forcing `map` to be deep** — see criterion 7.

*The design: discover first, backstop second.* A hardcoded list rots, so:

1. **Inside a git repo — the repo's own answer.** Tracked files are the project; everything else is a dependency, a build output, or scratch. The project's `.gitignore` is its own statement of what is not source. Prefer this: it cannot rot, and it is correct for ecosystems nobody thought to list.
2. **Outside a repo, or where a repo tracks its dependencies deliberately** (a vendored-deps repo is a real pattern) — fall back to a named baseline, and say in the map which rule was applied.

*The baseline floor*, named per ecosystem so a reader can see it is a floor and not a whitelist: VCS metadata (`.git`, `.hg`, `.svn`); node (`node_modules`, `.pnpm-store`); python (`.venv`, `venv`, `__pycache__`, `.tox`, `*.egg-info`); go (`vendor`); java (`target`, `build`, `.gradle`); c# (`bin`, `obj`, `packages`); rust (`target`); plus common build and cache output (`dist`, `build`, `.next`, `.svelte-kit`, `coverage`, `.cache`).

*Three constraints on how (a) is written:*

- **Tracked beats baseline, always.** If the project tracks a path the baseline names — a repo that really does commit `vendor/` — it is project source and is read. This is the whole rot-proofing, and it is also why the ambiguous names in the floor (`target` is both rust and java; `build` and `dist` are generic) are safe.
- **`tech-agnostic` applies to this list.** Every ecosystem named is an **example**, exactly as that rule requires of a `domain: universal` skill. The file already binds the rule (`:6`) and says so at `:102`; the new section must not contradict it.
- **The exclusion is reported, not silent.** `:101` already requires honesty about coverage. What was excluded, and by which rule, belongs in the map's **Scope & mode** section (`:84`).

**(b) The raw env-var read.** `:70` reads: *"The root `/docs` is the SINGLE SOURCE OF TRUTH (or `CLAUDE_DOCS_DIR` if that env var is set); in-project doc folders and READMEs are SYMLINKS into it — same content, don't double-count."* One defect, in the middle of an otherwise-correct sentence:

- It is a **raw env-var read**, not `resolve-config.sh`. That is precisely the gotcha `artifact-locations` documents at length: Claude Code's `env` block does not deep-merge across scopes, so a plain read sees only what was merged at session start and can **silently miss a project-scoped value**. `:75` already tells this skill that docs locations *"come only from `CLAUDE_DOCS_DIR`/`CLAUDE_PROJECT_PLANS_DIR` env vars or their defaults"* — which is the same mistake stated as policy, and must be corrected in both places.
Fixed by resolving through `resolve-config.sh` — the same resolver every other location already uses, and the reason it exists. **The value is a path and may be treated as one** (2.3); only the *method of obtaining it* is wrong. The symlink no-double-count rule at the end of `:70` is correct and stays exactly as written.

**Note what this defect is not.** It is not a Confluence problem and never was: a project that sets `CLAUDE_DOCS_DIR` to a non-default *local* path in its `.claude/settings.json` is already mis-read today if an unrelated `env` block shadows it. That is the whole bug, and it survives the round-2 decision untouched.

**(c) DEEP has no precedence rule.** `:36` lists *"source, config, tests, build files, docs"* and never says which wins when they disagree. The original ask said `--deep` may read docs *"but NEVER trust doc accuracy"*, and `document.md:13` already carries the strong form for the docs workflow: *"Where the docs and the source disagree, the source wins."* DEEP must carry it too. This is not decoration: an `explore` feeding an `analyze` report is exactly where a stale doc becomes a confidently wrong published answer, and `report-skeleton.md:27` already **requires** the Method section to state that at DEEP the docs are distrusted and the code is trusted — so the skeleton currently demands a property the skill never guarantees. Fixing `:36` closes that gap, and `:100` (*"Prefer real code and config over prose; descriptions drift, source doesn't"*) is the existing weaker phrasing to strengthen rather than duplicate.

**Acceptance criteria**
1. DEEP is bounded: the file states what is excluded and that the set is discovered from the project before any baseline applies.
2. The tracked-beats-baseline rule is explicit, with the vendored-deps case named as the reason.
3. Every named ecosystem is framed as an example per `tech-agnostic`; nothing reads as a supported-stack list.
4. The map's **Scope & mode** section is required to report what was excluded and under which rule.
5. `:36`'s "read the entire target" survives, scoped to the target's real boundary rather than deleted — DEEP still means complete.
6. `grep -n 'CLAUDE_DOCS_DIR' agent-agnostic/skills/explore/SKILL.md` shows no raw "if that env var is set" reading; both `:70` and `:75` route through `resolve-config.sh` and the seam.
7. **AUTO's DEEP-vs-SHALLOW decision rule (`:38-51`) is byte-identical to before.** `auto` may still pick SHALLOW, including for `map`. **No subphase in this plan changes `map`'s `explore` value**, and any diff there is a defect. (The parked design would have amended `:43`; local-primary makes that unnecessary.)
8. SHALLOW's docs-only scope (`:34`) is unchanged — it reads the local tree, which is correct in every configuration.
9. DEEP carries the precedence rule — code beats docs on conflict — in the strong form `document.md:13` already uses, and the map is required to reflect it, satisfying `report-skeleton.md:27`.
10. The frontmatter is unchanged; `domain: universal` stays.

**Test approach:** none executable — this is a skill document with no script behind it. Verified by reading against 2.3's shipped var split; criteria 6, 7 and 8 are mechanical `grep` / scoped-diff checks a contract-tester can run without judging prose.

**Test oracle:** `existing implementation` — the truth source is the skill's shipped behavior plus the `tech-agnostic` rule it binds and 2.3's shipped var split. Contract-tester only, no coder. *(Declared honestly per §F3: this file scope contains no test file, and no test is manufactured for prose.)*

---

### 7.1 — `plan-format`: the plan carries a pointer to its ask of record

**File scope:** `agent-agnostic/rules/plan-format.md` — this file, and only this file.

**Why this comes first in the lane.** Amendment A1 requires the ask to be *a real input to the gate, not an optional courtesy*. A gate cannot diff against something it has no reliable way to find. Making the pointer a **required, named part of the plan** is what converts the check from good intentions into something 7.2 can enforce mechanically — and it is the smallest possible change that achieves it.

**What to add.** In the **Required sections** list, the *Goal & scope* entry gains a mandatory **ask of record** pointer:

- The **path** to the run's durable ask artifact when one exists — the ask captured before the planner was spawned, so the brief is an artifact rather than conversation context. This run's own `<run-dir>/the-ask.md` is the worked example.
- **`story.md` counts.** A run that captured requirements per `confluence-mode.md` already has a durable artifact carrying *"Original Ask (verbatim)"* (`confluence-mode.md:18`); its `story.md` satisfies this pointer and **no second file is required**. 5.3 states the same connection from the other side. Do not mandate a new artifact where one already exists.
- Or, when no durable ask exists, an **explicit statement to that effect**. This is the case A1 singled out, and it must be written down rather than left blank: *a run whose ask is only conversation context has nothing to diff against*, so the gate's ask-vs-plan check cannot run, and everyone downstream should know that rather than assume it passed.

State the reason once, plainly, because a rule that only issues an instruction gets rationalized away: the plan is the second hop of a two-hop transformation (ask → plan → code), and **only the second hop was ever audited**. Every gate judged the implementation against the plan; nothing compared the plan against the ask.

**What must NOT change.** Everything else — naming, lifecycle, the phase/subphase grammar, the syllabus rules, the parallel-lane rules, and the NEVER-a-time-estimate rule. This adds one required element to one section.

**Acceptance criteria**
1. The *Goal & scope* required-section entry names the ask-of-record pointer as mandatory.
2. Both forms are covered: a path, or an explicit no-durable-ask statement.
3. `story.md` is named as satisfying the pointer, so a Confluence-mode run needs no second artifact.
4. The two-hop reason is stated once, in the rule's own voice.
5. Every other section of the rule is byte-identical to before.
6. No time estimate, no `jq`, no branch on a type name.
7. **This plan itself satisfies the new requirement** — it carries the pointer in its own preamble. Confirm rather than assume; a rule its own exemplar violates is a bad rule.

**Test approach:** partly executable — 7.2 makes conformance machine-checkable, and criterion 6 is verified by running 7.2's shipped `validate-plan.sh` against this very plan file.

**Test oracle:** `new contract tests` (the mechanical half is authored in 7.2).

---

### 7.2 — `validate-plan.sh`: the pointer is schema-checked

**File scope:** `agent-agnostic/skills/review-plan/scripts/validate-plan.sh` and — only if this subphase concludes no suite covers it (see Test approach) — `tests/validate-plan.test.sh` *(new)*. *(Note the location: this script ships **inside** the `review-plan` skill, not in a hooks dir — `dae/SKILL.md:130` says so explicitly. It is not installed to `~/.claude/hooks/`.)*

**What changes.** The script owns *"the mechanical half of the review-plan gate, so the reviewer fork spends its whole budget verifying claims against reality"* (`:8-9`). Add a **sixth check** in that spirit: the plan declares an ask of record. **Schema only** — the script verifies that the declaration is *present and well-formed*, never that the plan is *faithful* to the ask. Faithfulness is judgement and belongs to 7.3; a script that tried it would either be trivially foolable or produce false blocking findings.

The check: within the `Goal & scope` section (or the plan's preamble, matching where this plan puts it), find either a path-shaped ask pointer or an explicit no-durable-ask statement. Missing → a `FAIL:` line in the existing voice. Present-but-a-path-that-does-not-exist → **also** a `FAIL:`, because a pointer to nothing is worse than an honest absence, and unlike faithfulness it is cheaply checkable. Follow the existing `say_fail` mechanism (`:32`) and the `detail_open`/`detail_close` style of tolerating more than one markup (`:70-77`) — plans in the wild will phrase this differently, and matching exactly one phrasing would fail every plan written in the other.

**Extend the header block** (`:9-19`) to list check 6, keeping the numbered style, and extend the INFO note if the reviewer now has a companion judgement to make.

**Acceptance criteria**
1. A plan with a valid, existing ask path passes.
2. A plan with an explicit no-durable-ask statement passes.
3. A plan with neither fails with one `FAIL:` line naming what is missing.
4. A plan whose ask path does not exist fails, with a message distinguishing that case from the missing-declaration case.
5. At least two plausible markups for the declaration are accepted, in the spirit of `:70-77`.
6. **All five existing checks behave exactly as before**, and every plan currently in `project-plans/` that passed before still passes except where check 6 legitimately fires. Run it against every plan in the tree and record the results.
7. **This plan file passes** the shipped script.
8. Exit codes are unchanged: 0 valid (INFO allowed), 1 violations.
9. No `jq`; `bash -n` clean.

**Test approach:** criteria 1-5 and 8 need cases; there is **no existing suite for `validate-plan.sh`** — verify that by looking, and if none exists, add `tests/validate-plan.test.sh` on the house skeleton (2.2's pattern list applies verbatim), which raises 10.1's suite count again. Criteria 6 and 7 are run-and-record against the real tree.

**Test oracle:** `new contract tests`.

---

### 7.3 — `review-plan`: diff the ask against the design

**File scope:** `agent-agnostic/skills/review-plan/SKILL.md` — this file, and only this file.

**The systemic finding this closes (§H, and the reason this whole run exists).** Every gate judged the implementation against the **plan**. The plan gate verifies plan claims against the **tree**. The code and PR gates verify the diff against the **plan**. **Nothing at any point compared the plan against the original ask** — even though the previous run's plan preserved that ask verbatim at its Part 1, three hundred lines above the row that contradicted it. It is the same defect class as the `document` hole: a two-hop transformation where only the second hop is audited.

**What to add — an ask-vs-plan step**, as a first-class numbered step alongside the existing verification steps, not an aside:

- **Read the ask of record** at the pointer 7.1 requires and 7.2 validates. It is an **input to the gate**, not optional context.
- **Diff intent against design**, and report divergences. The useful shape is three buckets: something the ask asked for that the plan does not deliver; something the plan delivers that the ask never asked for; and — the one that caused this run — something the plan delivers **inverted** from what the ask said. An inversion is the hardest to see precisely because both documents discuss the same subject in the same words.
- **A divergence is a blocking finding by default**, routed with the existing `plan-wrong` kickback code, which already means exactly this. It is **not** blocking when the plan *itself* records the divergence as deliberate and gives its reasoning — the way this plan's **DP-3** declines the ask's literal instruction to sweep an archived file and says why. A gate that cannot tell those apart will either rubber-stamp inversions or block every legitimate judgement call, so the file must state the distinction with that example's shape.
- **No durable ask → say so.** The check cannot run; the verdict records that the ask-vs-plan comparison was **not performed** and why. This is the case A1 required be stated rather than passed over. It does not by itself reject a plan, and it must never be reported as a passing ask-vs-plan check.

**Where it goes.** Beside step 6's shallow-explore re-check (`:32`), which is the closest existing sibling — both are "re-verify a claim against its real source". Keep the file's numbered-step structure and its existing verdict vocabulary; the gate still writes its round through `report-verdict.sh` exactly as now.

**What must NOT change.** The verdict vocabulary (`ready | tentative | rejected`), the kickback codes, the cap, the committee-wrapping behavior at `rigor ≥ med`, and every existing step. This adds a step; it does not restructure the gate. **`:32`'s docs claim needs one touch:** it asserts *"root `/docs` is the source of truth"*, which is right in substance but hardcodes the path — route it through `resolve-config.sh` like 6.1(b) and 7.4(b), and leave the meaning alone.

**Acceptance criteria**
1. An ask-vs-plan step exists as a numbered step, with the ask named as a required input.
2. The three divergence buckets are named, with inversion called out as the one that motivated the check.
3. Divergence routes `plan-wrong` and is blocking by default.
4. The deliberate-and-recorded exception is stated, with the shape of a plan that declares its own departure.
5. The no-durable-ask case is stated, and is explicitly not reportable as a pass.
6. `:32`'s hardcoded `/docs` is routed through `resolve-config.sh`; its meaning is unchanged.
7. Verdict vocabulary, kickback codes, cap, and committee behavior are byte-identical.
8. `validate-plan.sh`'s division of labour is respected: the skill judges faithfulness, the script checks schema, and neither claims the other's job.

**Test approach:** none executable — this is a gate skill. Verified by reading against 7.1, 7.2 and 5.1; criterion 7 is a mechanical diff check.

**Test oracle:** `existing implementation` — 7.1's rule and 7.2's shipped script are the truth source. Contract-tester only, no coder.

---

### 7.4 — `planner.md`: record the ask, and resolve docs properly

**File scope:** `orchestrators/agents/planner.md` — this file, and only this file. **The `planner/plan-*.md` modules are NOT in scope** — the ask pointer is type-independent, so it belongs in the shared definition, not in six copies.

**Two changes.**

**(a) The planner records the ask of record.** The `plan-format` invariant in this file (which already requires syllabus-first, per-subphase file scope, and the never-a-time-estimate rule) gains the ask pointer: the planner writes it into the plan, taking the path from its caller. Without this, 7.1's requirement has no author and 7.2 fails every plan — the three subphases only work together.

State the corollary the round-1 experience proved: **the planner is handed the ask's PATH, not its content pasted into a prompt.** A durable artifact is what makes the check possible; conversation context is what made this run necessary. This mirrors the file's existing pointers-not-payloads discipline.

**(b) The docs ladder resolves properly.** `:11` reads: *"Climb the ladder as far as the task demands: (1) read `/docs` (or `CLAUDE_DOCS_DIR`) — treating its claims as *claims* to spot-verify against code, since docs drift"*. Rung 1 hardcodes `/docs` and does a raw env-var read — the same defect as `explore:70` (6.1(b)), in the file that spawns every plan. Route it through `resolve-config.sh`. **The path stays a path** (2.3); only the method of obtaining it changes. **The "docs are claims, not truth" framing is exactly right and must survive verbatim** — it is the same instinct 6.1(c) adds to DEEP, and it is why this ladder works.

**What must NOT change.** The rest of the ladder, the lane/disjointness invariants, the oracle-declaration requirement, the revision-loop behavior, and the return envelope.

**Acceptance criteria**
1. The planner is required to record the ask-of-record pointer in every plan it writes, in the form 7.1 defines.
2. Both forms are covered — a path, or the explicit no-durable-ask statement.
3. The path-not-payload point is stated for the ask specifically.
4. Ladder rung 1 routes through `resolve-config.sh`; no raw `CLAUDE_DOCS_DIR` read and no hardcoded `/docs` survives.
5. The "docs as claims to spot-verify against code" framing is preserved verbatim.
6. `grep -rn 'CLAUDE_DOCS_DIR' orchestrators/agents/planner/` returns nothing new — the modules are untouched.
7. Every other invariant in the file is byte-identical.

**Test approach:** none executable. Verified by reading against 7.1 and 2.3; criteria 4, 6 and 7 are mechanical.

**Test oracle:** `existing implementation`. Contract-tester only, no coder.

---

### 8.1 — `document.md`: record locally, full stop

**File scope:** `orchestrators/skills/dae/document.md` — this file, and only this file.

**Why this file changes now, when round 1 correctly excluded it.** Round 1 listed `document.md` as *"already dispatches correctly"*, and under the old model it did: it invoked *"the mode's document skill"* and let the mode decide. **Local-primary removes the modes.** Round 2 removed the modes; round 3 removed the publish step from the run entirely. There is now exactly one record path and no dispatch decision at all, so an either/or between two skills is doubly wrong. This is a genuine consequence of the decisions, not a round-1 miss, and it is worth saying so in the exit report.

**What changes.** Stage 3 (`:11`) currently reads: *"Invoke the mode's document skill … `document-local` reconciles the root `/docs` tree against the map; `document-confluence` publishes the technical map pages."* **That either/or disappears entirely.** Stage 3 invokes `document-local`, always, with the map path, the map-driven statement, and the changelog preference. **There is no second branch and no publish step in the run at all** — publishing is a CI job on merge (5.4), and `document-confluence` is manual recovery (5.2).

**This is smaller than round 2's version of this subphase**, which still had the run dispatching an optional publish. It now has one record path and no modes. Round 3's decision removed the branch rather than simplifying it.

**Three consequences to write down.**

- **The draft-PR timing is unchanged and must stay unchanged.** `:11`'s reasoning — the record commit is the earliest committable point, so `open-draft` fires there — depends on stage 3 producing a commit, which it always does. Local-only recording makes that argument *stronger*, never weaker. Do not disturb it.
- **The live Atlassian and Drive dependency leaves the run's critical path**, and that is worth one sentence: a run could previously complete build, code gate and record, then die on third-party auth unrelated to the work. It no longer can.
- **Stage 4's PR-gate oracle needs no change**, and this is the payoff worth stating. The map-is-coverage / code-is-accuracy split at `:13` works because the doc changes are **in the diff** — which local-only recording guarantees. Under the rejected Confluence-primary model this oracle had nothing to audit (DP-6). Add one clause noting that pages published later by CI are downstream output, outside the gate's scope and correct by construction if the local tree passed.

**What must NOT change.** Stages 1, 2 and 4's mechanics, the branch type `docs/`, the `read-only outside /docs` note at `:18`, and the monorepo scoping question at `:7`. `:7`'s Confluence clause (*"a map-driven run is technical-only — no story file and no Jira keys unless the user supplies them"*) stays true — it is about **requirements capture**, which 5.3 confirms is independent of where docs live.

**Acceptance criteria**
1. Stage 3 invokes `document-local` unconditionally and describes no publish step.
2. No either/or dispatch survives; `grep -n "mode's document skill\|document-confluence" orchestrators/skills/dae/document.md` returns nothing.
3. The file states that publishing is a CI job on merge, by pointer to `doc-format`, not restated here.
4. One sentence records that the live Atlassian/Drive dependency is off the run's critical path.
5. The `open-draft`-at-record-commit reasoning at `:11` is preserved.
6. Stage 4 gains one clause on CI-published pages being downstream of the gate; the map/code oracle split is otherwise byte-identical.
7. `:7`'s requirements-capture clause and `:18`'s scope note are unchanged.
8. Nothing owned by `document-local`, `document-confluence` or `dae/SKILL.md` is restated.

**Test approach:** none executable — a middle file. Verified by reading against 2.3, 5.1 and 5.4; criteria 2, 6 and 7 are mechanical.

**Test oracle:** `existing implementation` — 2.3's var split and 5.1's shipped rule are the truth source. Contract-tester only, no coder.
### 8.2 — `report.md`: ship, scratch dir, snapshot rule, record, F1

**File scope:** `orchestrators/skills/dae/report.md` — this file, and only this file. **`orchestrators/skills/dae/report-skeleton.md` is explicitly excluded** and must not appear in this lane's diff.

This is the run's headline subphase. Six changes, written in the file's own voice: it branches on resolved axis VALUES, never on a type name, and it references shared stages rather than restating them.

**(a) §B — the map/analyze distinction, stated correctly.** The intro (`:3`) already says the two are one pipeline at different presets. Add the user's own framing as the substantive half: **`map` is a cheap `analyze` that skips the publishing pre/post run steps.** It is cheaper because it explores less (`explore: auto`, which MAY resolve to SHALLOW — intended, not a shortfall), verifies less (`rigor: low`: one explorer, no committee), and loads none of the publish seam. It is **not** cheaper because it writes a shorter document: an output-length axis was proposed and **rejected** by the user, and this file must not reintroduce one by implication. State explicitly that `--explore` remains a **free** dial on both rows — the row value is a default, never a prohibition — which is exactly what distinguishes it from `ship` after 1.2.

**(b) §A — ship is no longer a flag.** Every place this file implies `ship` is user-selectable moves to "the row's resolved value". Concretely, `:21`'s *"the acceptance property that `analyze --ship publish` produces a branch touching only `docs/reports/`"* becomes `analyze`, unqualified. The `ship: chat` / `ship: publish` **branch structure is unchanged**: both modes still exist, both still branch on the axis, and `map` still takes the chat branch. What changes is that neither is reachable by a flag.

**(c) §C — the scratch dir stops being hardcoded.** `:8` today hardcodes `${XDG_CACHE_HOME:-$HOME/.cache}/dae/reports/<slug>-MM-DD-YY/` and calls `resolve-config.sh` zero times, which is why the user observed it writing into `.cache` on another machine with no way to configure it. Replace the literal with an invocation of **`resolve-scratch.sh --slug <slug>`**, taking the path from its `SCRATCHDIR:` line rather than assembling it — the same contract `dae/SKILL.md:111` already states for `workflow-setup.sh`'s `RUNDIR:` line.

Delete two now-false sentences: *"It sits OUTSIDE any worktree and OUTSIDE any repository — deliberately"* and *"Deriving it from the repo root, the workflows dir, or a run dir is a contract violation."* Rung 2 now deliberately **does** derive from the repo root, because `.artifacts/` is gitignored by a committed unanchored entry and a write there has zero git side effects.

Keep what is still true and load-bearing: it must work when the cwd is not a repo at all (rung 3 preserves this); it is created before the Explore stage so a crashed run's claims are recoverable; it is not under the run-dir conventions; it gets no `progress-log.md`; and its path is stated to the user in chat. Add that the path carries a **run id**, and why (§C2: two concurrent runs — same repo, or worse, different repos, where the current path has no project component at all — otherwise write into one directory, and a report run has no branch to protect it the way a worktree run does).

**(d) §D — worktree need comes from the axes, never from the type name.** Add a short table to stage 1, keyed on `ship` and `rigor` and on nothing else:

| `ship` | `rigor` | needs |
|---|---|---|
| `publish` | any | the shared Setup stage — full parent worktree + branch; it commits |
| `chat` | `low` | nothing; read the live cwd — genuinely fast |
| `chat` | `≥ med` | a pinned snapshot: a detached worktree at `HEAD`, no branch, removed when the run ends |

With the reasoning, briefly. At `low` there is one explorer, and one reader cannot disagree with itself — harmless. At `≥ med` there are 3-5 explorers reading over minutes; if the tree moves underneath them they disagree *because the tree moved*, which routes into the committee's dispute logic and turns it into noise. Build, diagnose, document and sync runs are already safe: their gates read a parent worktree pinned to a branch nobody else is touching, and the orchestrator serializes gates, so no race is possible. The exposed flow is exactly the `ship: chat` report run reading the live cwd — the tree the user may be editing right now. **No git repo → no snapshot possible → warn and proceed**, matching the D2 precedent (warn, never block).

Note that this cell is reachable *today* and is not hypothetical: `--rigor` stays a free dial, so `dae map --rigor med` produces `ship: chat` at `rigor: med` and must be specified.

Mechanics, kept minimal and stated here because no other file owns them: `git worktree add --detach <scratch-dir>/snapshot HEAD`, members read there, `git worktree remove` at the end. It goes under the **scratch dir** rather than the workflows dir on purpose — `worktree-modes.md:11` lists worktrees on disk in the workflows dir as **resumable run candidates**, and a snapshot is not a resumable run. Note that this removal is not on `allow-workflow-cleanup.sh`'s auto-allow list (`:112-122` — case 2 auto-allows only a path whose basename matches `-l[0-9]+$`), so it may prompt; prompting is fine, and widening that allowlist is **not** in scope.

**The invariant this qualifies — stated, never quietly broken.** `:19` today claims a chat run produces *"ZERO git side effects — no branch, no worktree, no commit, nothing staged, no file written inside any repository."* Two clauses must be rewritten honestly: a `rigor ≥ med` chat run **does** create a temporary detached worktree, and a rung-2 scratch dir **is** a file written inside a repository (a gitignored one). The invariant survives in the form that actually matters and must be restated as such: **no branch, no commit, nothing staged, and nothing that reaches the product branch** — plus, at `rigor: low`, no worktree either. Do not delete the invariant, and do not leave it overclaiming.

**(e) §F1 — `--against` keys on the axis, not on a row count.** `:14` reads *"`--against` is `forbid` on **both rows**"*. That is cardinality-keyed and contradicts this file's own `:3` principle that every branch keys on an axis VALUE — a third report row would silently falsify it. Rewrite as `against: forbid` — *this middle NEVER resolves anchors and never loads `resolve-anchor`; a violation is already an error at parse time, before Setup runs.* Minimal edit; the behavior is unchanged, only the justification stops depending on there happening to be two rows.

**(f) A2 — the record target mirrors `document.md`'s, and there is only one.** This replaced the F6 decision point at round 1 and is simplified again by round 3. `:21` hardcodes the record target as *"the report file under the resolved docs root's `reports/` subdirectory"* — **correct as a location** (there is always a local docs tree) but still wrong as a *mechanism*, because `analyze` reinvents a path where `document.md` invokes a skill.

Rewrite stage 5's record step to mirror **8.1's shipped shape exactly**: invoke `document-local` to record under the resolved docs root's `reports/` subdirectory. **No publish step, no mode branch, no Confluence anything** — publishing is CI's on merge (5.4). Then state the split the user named: **`analyze` and `document` differ in WHAT they publish and WHY, never in WHERE or HOW.**

Two consequences:

- **The PR-gate scope boundary survives verbatim, and that is the payoff.** `:21`'s *"nothing outside `<docs-root>/reports/` may have changed"* stays exactly as written, because there is always a local docs tree for it to constrain. Under the rejected Confluence-primary model it would have constrained a directory that did not exist (DP-6). Keep it, and note that CI-published pages are downstream of the gate.
- **The old F6 self-flag at `:28` is DELETED, not rewritten.** It recorded a gap — *"`ship: publish` with a Confluence docs target is undefined"* — that no longer exists. There is no Confluence docs *target*: there is a local record, and CI. Leaving the note would describe a design that was replaced twice.

**Acceptance criteria**
1. Every branch in the file keys on a resolved axis value: `grep -n 'both rows\|--ship' orchestrators/skills/dae/report.md` returns nothing.
2. The scratch path is obtained from `resolve-scratch.sh`'s `SCRATCHDIR:` line: `grep -n 'XDG_CACHE_HOME' orchestrators/skills/dae/report.md` returns nothing, and no hand-assembled path remains.
3. The §D table is present, keyed on `ship` and `rigor` only, with the no-repo warn-and-proceed case stated and the snapshot's location justified against `worktree-modes.md:11`.
4. The zero-side-effects invariant is restated accurately — no branch, no commit, nothing staged, nothing reaching the product branch; no worktree at `rigor: low` — and is neither deleted nor left overclaiming.
5. `map`'s cheapness is attributed to explore depth, rigor, and the skipped publish seam. No output-length axis, in any wording.
6. `--explore` is stated as a free dial on both rows; `ship` is not presented as user-selectable anywhere.
7. `git diff --name-only` does not list `orchestrators/skills/dae/report-skeleton.md`.
8. Nothing owned by `dae/SKILL.md` (Setup, Ship, the draft-PR mechanism, the confirmation cadence) or by `committee.md` (the member layout) is restated here — all stay pointers.
9. Stage 5 invokes `document-local` and describes no publish step — the same shape 8.1 ships, not a second one.
10. The what/why-vs-where/how split is stated explicitly.
11. The PR-gate scope boundary (`nothing outside <docs-root>/reports/`) is preserved verbatim, with published pages noted as downstream of the gate.
12. The former F6 self-flag at `:28` is gone — `grep -n 'real gap in the design' orchestrators/skills/dae/report.md` returns nothing.
13. `grep -n 'document-confluence\|Confluence' orchestrators/skills/dae/report.md` returns nothing.

**Test approach:** none executable — this is a skill document with no script behind it. Verified by reading against 2.1's shipped interface and against `dae/SKILL.md`'s shared-stage definitions; criteria 1, 2 and 7 are mechanical `grep` / `git diff` checks that a contract-tester can run without reading the prose.

**Test oracle:** `existing implementation` — the truth source is 2.1's shipped behavior plus the shared stages `dae/SKILL.md` already defines; this file is derived from both. Contract-tester only, no coder. *(Declared honestly per §F3: this file scope contains no test file, and no test is manufactured for prose. The machine-checkable behavior this file describes is tested in 2.2, which is where F4's committed test actually lives.)*

---

### 9.1 — `dae/SKILL.md`: the shared touchpoint

**File scope:** `orchestrators/skills/dae/SKILL.md` — this file, and only this file. **This is the run's single shared touchpoint, and exactly one subphase edits it** (convention 12). It burned the previous run; it is serialized here by construction, after every lane that changes a fact it repeats.

**The edits**, each verified against the current file:

| line | today | becomes |
|---|---|---|
| `:32` | the `--sh[ip]` row of the flag table | **deleted.** A locked flag is never a row in this table — `:44` already states that rule for `--pipeline` |
| `:40` | bracket minimums `--t, --exp, --rig, --ag, --sh, --pl` | drop `--sh`, matching how `--pi` is already absent |
| `:43` | *"`-s` and `-p` are deliberately unassigned. `--ship`, `--plan`, and `--pipeline` have no single-dash alias"* | **keep** — still true and still worth saying |
| `:44` | `--pipeline` is internal-only and locked | extend to cover `--ship`: recognized only in order to be rejected, with the reason — **no row has a legitimate second ship value.** `map` is the chat one; if you want a document you use `analyze`; chat is meaningless for a build, docs, diagnose or sync run. A per-row `require\|optional\|forbid` policy would imply some row wants the choice, and none does |
| `:45` | override tiers: free `--explore`/`--rigor`; constrained `--against`/`--plan`; locked `--pipeline` | move `--ship` from **free** to **locked**, and state why it was misclassified: the free tier's own definition is *"overriding cannot produce an incoherent run"*, and `dae feature --ship chat` is a build run that does not ship |
| `:64` | `analyze` row: ship = `chat (--ship publish allowed)` | ship = **`publish`** |
| `:69` | `map` vs `analyze` — "fast" vs "rigorous" | add the substantive half: `map` skips the publishing pre/post steps entirely; `analyze` always publishes. Keep the axis-value framing |
| `:80` | the error set the router surfaces on a non-zero exit | add locked `--ship` beside locked `--pipeline` |
| `:112` | *"`ship: chat` (the `map` default, and `analyze`'s)"* | `analyze`'s no longer. The bullet is otherwise unchanged and still points at `report.md` for the scratch dir — **do not restate the scratch path here, and do not import §D's snapshot table**; `report.md` owns both |
| `:115` | *"On runs with no planner and no builders (`document`, `analyze --ship publish`)"* | `analyze`, unqualified |
| `:117` | PR-gate spec of record: *"report (`analyze --ship publish`)"* | `report (analyze)`. The rest of the bullet — the `<docs-root>/reports/` scope boundary, `verify-run-scope.sh`, the report path — is unchanged |

**Also required by R2:** `:112`'s bullet asserts *"The observable property: a chat run produces **zero git side effects**."* 4.1 qualifies that claim. This line must be brought into agreement with `report.md`'s restatement — no branch, no commit, nothing staged, nothing reaching the product branch; no worktree at `rigor: low` — **by pointer where possible**, since `report.md` owns the detail.

**Lines to leave alone:**
- `:82`'s example *"`dae map --rigor pr:high` — a `ship: chat` run has no `pr` phase"* stays exactly as written. `map` is still `ship: chat`, `--rigor` is still free, and this is the D2 warn-and-continue precedent.
- `:105`'s three observable consequences (beyond the R2 agreement above), `:109`'s shared-stage sentence, and the whole **Seam loading** table (`:90-103`). `ship: publish` still loads the publish seam, and `analyze` moving into that set changes no row of it — which is the seam design working, not a gap.

**Acceptance criteria**
1. `grep -n -- '--ship\|--sh\b' orchestrators/skills/dae/SKILL.md` returns only `:43`'s deliberately-unassigned sentence and the locked-axis statements at `:44`/`:45`. No flag-table row, no bracket minimum, no `analyze --ship publish`.
2. The type table's `analyze` row reads `publish` and matches `workflows.yaml:23` exactly.
3. The override-tier bullet lists `--ship` as locked and gives the misclassification reason.
4. Nothing owned by `report.md` (the scratch dir, the §D snapshot table) or by `committee.md` (the member layout) is restated.
5. `:82` and the Seam loading table are byte-identical to before.
6. Every claim the file makes about `resolve-type.sh`'s accepted flags matches 1.2's shipped `FLAG_TABLE` and hint strings — checked by reading both, not assumed.
7. **No router-side Confluence check is added for the record target.** DP-1 was dissolved, not answered (A2, refined by A5): there is one record path — local, always — plus an optional publish step, so there is no docs-target conflict left for a parse-time error to catch. The bullet the amendment proposed would guard a state that can no longer occur.
8. **The Setup stage stops describing two docs modes.** `:111` currently says *"a path = local mode (`document-local` records), an Atlassian URL / `confluence:` shorthand = Confluence mode (`document-confluence` records; follow `confluence-mode.md` …)"*. After 2.3 there is one mode: resolve `CLAUDE_DOCS_DIR` (always a path) for the record location, and resolve `CLAUDE_DOCS_PUBLISH` separately — when set, `confluence-mode.md` still governs requirements capture (5.3) and a publish step follows the record. The **seam-loading row at `:103`** (*"Confluence docs target | `confluence-mode.md` + `document-confluence` records"*) must move with it: the trigger is the publish var, and `document-confluence` publishes rather than records.
8b. **No scheme-validation prose is added here.** Round 2 would have put the unrecognized-publish-scheme check in this file; 4.1 moved it into `resolve-config.sh --expect publish-target`, where it is tested. **R12 is closed** — do not add an untested prose duplicate of a check that now has a suite.
8d. **Round-4 addition — the Ship stage at `:116` still says *"record via the mode's document skill"*.**
   There is no mode and no second document skill after 8.1/8.2: both middles now invoke
   `document-local` directly. Correct it. **Verified gap:** `:111`'s two-modes prose IS covered by
   criteria 8 and 8c above, but `:116` was covered by nothing — the three plan references to
   *"the mode's document skill"* all concern `document.md` (8.1), not this router. Raised by lane 8,
   which checked 9.2 and 9.3's scopes as well before reporting it. Left unfixed, the run would ship a
   shared touchpoint contradicting both middles it dispatches to.

8c. **The Setup stage no longer chooses a document skill.** `:111`'s *"a path = local mode (`document-local` records), an Atlassian URL / `confluence:` shorthand = Confluence mode (`document-confluence` records …)"* becomes: resolve `CLAUDE_DOCS_DIR` (always a path, `--expect path`) for the record location; `document-local` records, always. `confluence-mode.md` still governs requirements capture when `CLAUDE_DOCS_PUBLISH` is set (5.3). **The seam-loading row at `:103`** — *"Confluence docs target | `confluence-mode.md` + `document-confluence` records"* — must move with it: the trigger is the publish var, `confluence-mode.md` is requirements capture, and `document-confluence` is **not** a run stage at all.
9. **The plan gate bullet names the ask-vs-plan check.** `:122`'s gate description and the `plan-wrong` routing at `:124` must reflect 7.3: the plan gate now takes the ask of record as an input, and an unrecorded divergence routes `plan-wrong` like any other plan defect. One sentence and a pointer at `review-plan` — the mechanics are 7.3's, not this file's.
10. **The run's ask is passed to the planner as a PATH.** The planner-spawn description gains it, per 7.4(a). This file owns what the router hands its workers, so the obligation to hand over the ask pointer is genuinely this file's and not a restatement.
11. The kickback table at `:124` is otherwise byte-identical; no new reason code is introduced. An ask-vs-plan divergence is a `plan-wrong`, which is what that code already means.

**Test approach:** none executable. Verified by reading against `workflows.yaml`, `resolve-type.sh` and `report.md` as those files stand after lanes 1-5, plus the two mechanical `grep` checks in criteria 1 and 5.

**Test oracle:** `existing implementation` — the truth source is the shipped behavior of lanes 1-5; the router document is derived from it.

---

### 9.2 — Doc sweep: the inversion, the new hook, `architecture.md`

**File scope:** `orchestrators/AGENTS.md`, `docs/pipeline.md`, `docs/architecture.md`, **`orchestrators/skills/dae/build.md`**.

- **Round-4 addition — `build.md` entered scope by this plan's own conditional and the scope line was never amended.** The exclusion table said *"if it names `document-confluence`, it moves into 9.2's sweep"*; lane 5 confirmed the condition FIRED and lane 9 made the change, which `l9-exit.md` claims — so the ownership ledger is intact and `verify-run-scope.sh` does not flag it. The gap was plan text only: unlike the plan's two other conditional files, this scope line was never updated. Recorded by 10.1 as F1.

Four kinds of edit, each with its verified location.

**(i) The ship inversion, everywhere it is repeated.**

- `orchestrators/AGENTS.md:45` — the run-shape diagram's chat branch reads `pipeline: report, ship: chat (map │ analyze)`. `analyze` no longer takes it: show `map` on the chat branch and `analyze` on the publish branch.
- `orchestrators/AGENTS.md:95-98` — *"`map`/`analyze` (the chat branch above: explore → report skeleton → chat answer, no planner, no gates)"*. Split it: `map` is the chat branch; `analyze` is the same middle on the publish arc, recording under the resolved docs root's `reports/`.
- `docs/pipeline.md:22` — the same diagram, the same fix. The two diagrams must stay consistent with each other.
- `docs/pipeline.md:66` — the `analyze` table row: *"chat answer (`--ship publish` opts into the record/PR stages below, scoped to `docs/reports/`)"* → a published report under the resolved docs root's `reports/`, no flag.
- `docs/pipeline.md:78` — *"`map` and `analyze` default to `ship: chat`"* → `map` does; `analyze` publishes.
- `docs/architecture.md:114` — *"A `pipeline: report` type (`map`/`analyze`) defaults to `ship: chat`"* → the same split. The sentence continues *"Every other type creates the parent worktree…"*, which must now include `analyze`.

Per **R2**, any of these that also assert zero git side effects must agree with 4.1's restatement rather than keep the unqualified claim.

**(ii) The new hook joins the two EXHAUSTIVE helper lists.** These two enumerate helpers with **no ellipsis**, so an omission is a real gap:

- `orchestrators/AGENTS.md:93-107` — add `resolve-scratch.sh` (the `ship: chat` scratch-dir resolver; delegates rung 1 to `resolve-config.sh`), in the same voice as its neighbours.
- `docs/pipeline.md:163-173` — the same.

`docs/architecture.md:50-53` ends its hook list with `…`, so it needs no entry; adding one is optional and harmless.

**(ii-b) `docs/architecture.md:148`'s "No CI" claim becomes FALSE — this run creates that drift.** It reads *"No CI, build system, license, `CONTRIBUTING.md`, or `CHANGELOG`."* After 5.4 this repo has `.github/workflows/publish-docs.yml`. Correct it precisely: there is now **one** workflow, a docs→Confluence publish job that **no-ops here** because this repo configures no publish target — it exists as a working, copyable reference for consuming projects. Do not overstate it into "this repo has CI" in the general sense; it has one job that does nothing here, deliberately.

**(iii) `docs/architecture.md`'s stale suite counts** — both move once 2.2 lands:

- `:68` — `# contract tests (8 suites) for the lifecycle + scope-verification scripts`
- `:149` — `holds 8 contract-test suites for the lifecycle + scope-verification`

**Count `ls tests/*.test.sh | wc -l` at edit time rather than trusting this plan's arithmetic.** Four separate stale-count defects were found in the previous run; this is the exact failure mode.

**(iv) §F5, first half — `docs/architecture.md:64`.** The line reads `#   svelte, tailwind, typescript, django, godot, confluence` with **no** ellipsis, and the tree has a **seventh** real layer: `tool-based/medusa/` (verified — `tool-based/medusa/AGENTS.md` carries real MedusaJS 2.x conventions, and `tool-based/medusa/skills/medusa-api/SKILL.md` exists). Add `medusa`.

**Do NOT touch `docs/architecture.md:143`.** *"Six tech layers are placeholder stubs: `bash`, `git`, `go`, `react`, `python`, `fastapi`"* is **correct** — verified: all six carry only a stub `AGENTS.md`. The ask says so explicitly. Sweeping it up is a defect.

**(iv-b) The top-level tree block gains two entries.** `docs/architecture.md`'s tree (around `:40-70`) enumerates the repo's top level. This run adds **`scripts/`** and **`.github/`** — both new. Add them with one-line comments naming what they are and, for `scripts/`, that its `publish-docs.yml` is a symlink into `.github/workflows/` rather than the other way round (5.4's verified constraint).

**(v) The docs publish model and the ask-vs-plan gate reach the meta-docs.** Both are new architecture, and these three files are where the architecture is described:

- `docs/pipeline.md`'s cold-fork list and `orchestrators/AGENTS.md`'s helper list both present `document-local` and `document-confluence` as two alternative record stages. After Phase 5 that is wrong in kind: `document-local` is **the** record stage, always; `document-confluence` is **not a run stage at all** — a manual/recovery sync outside every workflow. Remove it from any cold-fork or run-stage listing rather than re-describing it there.
- Anywhere either file states that a Confluence docs target means no local `/docs` — the inverted premise — must be corrected. `grep -rn 'source of truth' docs/ orchestrators/AGENTS.md` and check each hit.
- `docs/pipeline.md:163-173` and `orchestrators/AGENTS.md:93-107` are the two **exhaustive** helper lists; item (ii) adds `resolve-scratch.sh`. **`resolve-config.sh`'s entry is unchanged** — it gained no flag (4.1). `validate-plan.sh` is **not** a hook and must not be added to either list — it ships inside the `review-plan` skill (`dae/SKILL.md:130`).
- `docs/architecture.md`'s dae description (`:108-131`) walks the pipeline including the `review-plan` gate; the ask-vs-plan check belongs in that walk, in one clause.

**Acceptance criteria**
1. No file in scope still says `analyze` defaults to chat, or that `--ship publish` opts into anything.
2. Both diagrams show `map` on the chat branch and `analyze` on the publish branch, are consistent with each other, and agree with `dae/SKILL.md:64` as 6.1 leaves it.
3. `resolve-scratch.sh` appears in both exhaustive helper lists with a one-clause description.
4. Both suite counts in `architecture.md` equal `ls tests/*.test.sh | wc -l` at edit time.
5. `architecture.md:64` lists seven real layers including `medusa`.
6. `architecture.md:143` is byte-identical to before.
7. `grep -rn -- '--ship' docs/ orchestrators/AGENTS.md` returns nothing.
8. No zero-side-effects claim in scope is left unqualified where 8.2 qualified it.
9. `resolve-config.sh`'s entry is unchanged in both exhaustive lists; `validate-plan.sh` appears in neither.
10. `document-local` is described as the always record stage; `document-confluence` appears in no run-stage or cold-fork listing, and is described as manual/recovery where it appears at all.
10b. `architecture.md:148`'s "No CI" claim is corrected to name the one no-op workflow, without overstating it.
10c. The top-level tree block lists `scripts/` and `.github/`, with the symlink direction noted.
11. `architecture.md`'s pipeline walk names the ask-vs-plan check at the plan gate.
12. `grep -rn 'source of truth' docs/architecture.md docs/pipeline.md orchestrators/AGENTS.md` shows no surviving claim that Confluence is the docs source of truth.
13. Nothing in scope restates what `doc-format` or `artifact-locations` own — both stay pointers (convention 11).

**Test approach:** none executable — documentation. Verified by reading against the tree; criteria 4, 6 and 7 are mechanical.

**Test oracle:** `existing implementation` — the tree is the truth source and the docs are derived from it, never the reverse.

---

### 9.3 — Doc sweep: stale counts, the docs model, `conventions.md`

**File scope:** `docs/tool-based.md`, `docs/README.md`, `docs/conventions.md`, `README.md`, `AGENTS.md`, **`tool-based/AGENTS.md`**.

- **Round-4 addition — `tool-based/AGENTS.md:33` is now FALSE and was in NO lane's scope.**
  It describes `document-confluence` as the Confluence documentation phase that publishes story
  pages and links Jira. **Every clause of that is false after 5.2**, which rewrote the skill as a
  manual/recovery *sync* — no run shapes, no plan/story inputs, no Jira linking, and no in-run
  publish step at all. Correct it to describe the skill as it now is. **Verified gap:** the file
  appeared in no subphase's file scope AND was absent from the plan's explicit exclusion list —
  found by lane 5, which raised it rather than reaching outside its own scope. Disjoint from 9.2, which owns `docs/architecture.md`, `docs/pipeline.md` and `orchestrators/AGENTS.md`.

**Why `README.md` and `AGENTS.md` are now in scope, when R5 excluded them.** R5 leaves their *pre-existing* drift alone, and still does. But both carry **top-level tree blocks** (`README.md:29-41`, `AGENTS.md:11-24`), and 5.4 adds two new top-level entries — `scripts/` and `.github/`. **That drift is created by this run**, so it is this run's to fix. Add the two entries and change nothing else in either file; the stale `tests/` description R5 names stays as it is.

**The tech-layer structure block gains a fifth entry.** `docs/tool-based.md:13-19` documents `tool-based/<tech>/` as exactly four entries — `AGENTS.md`, `rules/`, `skills/`, `hooks/`. 5.4 adds `ci/`. Add it, described as shipped CI templates and references for consuming projects. Introducing a directory shape without documenting it is how the next reader concludes it was a mistake.

**§F5, second half — `docs/tool-based.md`.** `:23` reads *"Six layers have real content; six are placeholder stubs"*. Verified against the tree: **seven** real (`svelte`, `tailwind`, `typescript`, `django`, `godot`, `confluence`, **`medusa`**) and six stubs (`bash`, `git`, `go`, `react`, `python`, `fastapi`). Fix the sentence, and add the missing table row between `:33` and `:34` in the table's existing shape:

| `medusa` | **real** | — | `medusa-api` |

`tool-based/medusa/` has no `rules/` directory (verified), and the em dash is the table's own convention for none. The `confluence` paragraph at `:41-45` explains that layer as the one bound to a *service* rather than a language; nothing there changes.

**`docs/conventions.md` — the worker-envelope and run-artifacts summary.** It names `document-confluence` among the cold forks and summarizes the two artifact homes. Three updates: the scratch dir joins as the third home (2.3 owns the rule; this is the meta-doc's one-line reflection, **by pointer, not restated**); `document-confluence` is described as a publish step rather than a record stage; and the docs-var split gets one line pointing at `artifact-locations`.

**The suite count — `docs/README.md:48`.** *"(8 contract-test suites exercising those hooks against this repo itself"* → the real count once 2.2 lands. Same instruction as 9.2(iii): count the files, do not trust arithmetic.

**Deliberately NOT swept.** `README.md:41` and `AGENTS.md:24` (both at the repo root) describe `tests/` as *"plan-lifecycle.sh's fixture test"* — singular, and already stale by seven suites before this run touches anything. It is pre-existing drift outside the ask, and this run neither creates it nor worsens it. Flagged in **R5**, not fixed here; a subphase that fixed it would be scope creep past the ask.

**Acceptance criteria**
1. `docs/tool-based.md:23` reads seven real / six stubs, and the table carries thirteen rows.
2. The `medusa` row names `medusa-api` and no rules.
3. `docs/README.md`'s suite count equals `ls tests/*.test.sh | wc -l` at edit time.
4. The stub list is unchanged — still exactly the six.
5. `README.md` and `AGENTS.md` gain `scripts/` and `.github/` in their tree blocks, and are otherwise byte-identical — the R5 drift is NOT swept.
5b. `docs/tool-based.md`'s structure block lists `ci/` as a fifth entry.
6. `docs/conventions.md` names the scratch dir as a third artifact home by pointer at `run-artifacts`, and no longer lists `document-confluence` among the run's cold forks.
7. The suite count in `docs/README.md` accounts for **every** suite this run adds — `tests/resolve-scratch.test.sh`, plus whatever 4.3 and 7.2 concluded they needed. Count the directory; the number is not knowable from this plan.

**Test approach:** none executable — documentation. Verified by reading against the tree; criteria 1, 3 and 5 are countable or mechanical.

**Test oracle:** `existing implementation`.

---

### 10.1 — Whole-suite run + `bash -n` over every changed script

**File scope:** none — this subphase writes no product file. It runs checks and records results in the lane's exit report.

**Why it exists.** There is no CI, no build system, no runner, and no linter in this repo (verified: no `.github/`, no Makefile, and neither `smart-test.sh` nor `test-changed.sh` nor `workflow-diff-check.sh` carries a single `*.test.sh` reference). The bash suites plus `bash -n` are the **complete** blocking set, and they are discovered only by someone typing the command. Nothing else will catch a cross-lane break.

**What runs**

1. **`bash -n`** on every script changed or added. Known at plan time: `orchestrators/hooks/resolve-type.sh`, `orchestrators/hooks/plan-lifecycle.sh`, `orchestrators/hooks/resolve-scratch.sh`, `orchestrators/hooks/resolve-config.sh`, `orchestrators/hooks/verify-run-scope.sh`, `agent-agnostic/skills/review-plan/scripts/validate-plan.sh`, `tests/resolve-type.test.sh`, `tests/plan-lifecycle.test.sh`, `tests/resolve-scratch.test.sh`, `tests/resolve-config-precedence.test.sh`, `tests/verify-scope-parsing.test.sh`, plus any suite 4.3 or 7.2 added. (**`resolve-config.sh` IS in this list** — 4.1 edits it. An earlier revision said it was unchanged; that stopped being true when A6 gave it the hard error.) **Derive the list from `git diff --name-only <base>...HEAD` filtered to `*.sh`, not from this list** — this list is a floor and 4.3 and 7.2 may both extend it.
2. **Every suite in `tests/`, individually, from the repo root** — including the six this run does not touch, because 1.2 and 3.1 change scripts other suites may exercise. Enumerate with `ls tests/*.test.sh`; do not work from a list in this plan.
3. Each of the three new-or-changed suites **once more from a different cwd** (`/`), asserting the "runnable from any working directory" property every house suite claims of itself.
4. The mechanical greps and empty-diff checks backing 4.1, 5.1, 5.2, 5.3, 6.1, 8.1, 8.2, 9.2 and 9.3's acceptance criteria, run as one block and recorded with their real output.
5. **A coverage check on this plan.** Every file named in any subphase's file scope appears in `git diff --name-only <base>...HEAD`, and every file in that diff appears in some subphase's file scope. The previous run shipped three plan-mandated changes with **no owning subphase**; this symmetric check is what would have caught it.
6. **`chmod +x` verification** on every file this run ADDS — `orchestrators/hooks/resolve-scratch.sh`, `tests/resolve-scratch.test.sh`, and any suite from 4.3 / 7.2. Every hook and six of eight existing suites are `0755`; a non-executable new file is a silent defect nothing else catches.
7. **`validate-plan.sh` against every plan in the tree**, per 7.2 criterion 6 — including this plan file (criterion 7). A check that rejects the plans already in `project-plans/` is a regression, not a finding.
8. **The docs-model sweep**, three greps run together, because this is the single most likely silent half-shipment of the run:
   - `grep -rn 'CLAUDE_DOCS_DIR' agent-agnostic/ orchestrators/` — every hit either IS `resolve-config.sh` or routes through it; no raw env read survives.
   - `grep -rn 'confluence:\*\|http\*' orchestrators/hooks/` — no script pattern-matches a docs value any more (4.1).
   - `grep -rn 'source of truth' agent-agnostic/rules/ orchestrators/ docs/` — no surviving claim that Confluence is the docs source of truth, anywhere.
   - `grep -rn 'document-confluence' orchestrators/` — no run stage dispatches to it; any surviving mention describes manual/recovery only.
9. **The exhaustive-list check**: every `*.sh` under `orchestrators/hooks/` appears in both exhaustive helper lists (`orchestrators/AGENTS.md`, `docs/pipeline.md`), and nothing that is not a hook appears in either. Run it as a set comparison, not by eye.
10. **The symlink-direction check** (5.4's load-bearing constraint): `git ls-files -s .github/workflows/publish-docs.yml` shows mode `100644`; `git ls-files -s scripts/publish-docs.yml` shows `120000`; `find tool-based -type l` returns nothing. Assert all three — a reversed arrow silently breaks CI in every consuming project that copies it.

**Acceptance criteria**
1. Every `bash -n` is clean.
2. Every suite exits 0 with zero `FAIL:` lines, and the number of suites run equals `ls tests/*.test.sh | wc -l`.
3. The cwd-independence check passes for all three.
4. Every check in item 4 returns its expected result, empty or non-empty as the owning criterion specifies.
5. The item-5 coverage check is **symmetric** — no unowned file in the diff, no scoped file missing from it. Any asymmetry is a **blocking** finding reported to the orchestrator, never a note.
6. Every added file is mode `0755`.
7. `validate-plan.sh` passes on every plan in the tree, this one included, with no pre-existing plan newly rejected.
8. All three docs-model sweeps return clean.
9. The exhaustive-list set comparison is symmetric in both directions.
10. All three symlink-direction assertions pass.
11. Results are recorded in the exit report with the **actual command output**, not a summary of it.

**Test approach:** this subphase *is* the verification.

**Test oracle:** `existing suite` — the full set of suites, run whole.

---


---


---


---

## Lanes

**Eight lanes**, plus a serialized integration tail. This exceeds the 2–5 preference deliberately: separation outranks the count target, and every merge below would have created a shared file scope. Nothing is a manufactured lane.

| lane | subphases | file scope (complete) |
|---|---|---|
| **1** | 1.1, 1.2, 1.3 | `orchestrators/skills/dae/workflows.yaml`, `orchestrators/hooks/resolve-type.sh`, `tests/resolve-type.test.sh` |
| **2** | 2.1, 2.2, 2.3 | `orchestrators/hooks/resolve-scratch.sh` *(new)*, `tests/resolve-scratch.test.sh` *(new)*, `agent-agnostic/rules/artifact-locations.md`, `agent-agnostic/rules/run-artifacts.md` |
| **3** | 3.1, 3.2 | `orchestrators/hooks/plan-lifecycle.sh`, `tests/plan-lifecycle.test.sh` |
| **4** | 4.1, 4.2, 4.3 | `orchestrators/hooks/resolve-config.sh`, `orchestrators/hooks/verify-run-scope.sh`, `tests/resolve-config-precedence.test.sh`, `tests/verify-scope-parsing.test.sh`, and — only if 4.3 concludes it is needed — `tests/verify-run-scope.test.sh` *(new)* |
| **5** | 5.1, 5.2, 5.3, 5.4 | `agent-agnostic/rules/doc-format.md`, `tool-based/confluence/skills/document-confluence/SKILL.md`, `orchestrators/skills/dae/confluence-mode.md`, `.github/workflows/publish-docs.yml` *(new)*, `scripts/publish-docs.yml` *(new symlink)*, `scripts/README.md` *(new)*, `tool-based/confluence/ci/README.md` *(new)* |
| **6** | 6.1 | `agent-agnostic/skills/explore/SKILL.md` |
| **7** | 7.1, 7.2, 7.3, 7.4 | `agent-agnostic/rules/plan-format.md`, `agent-agnostic/skills/review-plan/SKILL.md`, `agent-agnostic/skills/review-plan/scripts/validate-plan.sh`, `orchestrators/agents/planner.md`, and — only if 7.2 concludes it is needed — `tests/validate-plan.test.sh` *(new)* |
| **8** | 8.1, 8.2 | `orchestrators/skills/dae/document.md`, `orchestrators/skills/dae/report.md` |
| *(none — serialized)* | 9.1 | `orchestrators/skills/dae/SKILL.md` |
| *(none — serialized)* | 9.2 | `orchestrators/AGENTS.md`, `docs/pipeline.md`, `docs/architecture.md` |
| *(none — serialized)* | 9.3 | `docs/tool-based.md`, `docs/README.md`, `docs/conventions.md`, `README.md`, `AGENTS.md` |
| *(none — serialized)* | 10.1 | *(no writes)* |

**No file appears twice** — audited mechanically in both directions. `README.md` and `AGENTS.md` entered scope at round 3 for one reason only (5.4's new top-level dirs) and are owned solely by 9.3. Four potential collisions are each serialized into exactly one subphase: `orchestrators/skills/dae/SKILL.md` into **9.1** (convention 12; this file burned the previous run), `agent-agnostic/rules/artifact-locations.md` into **2.3** (the scratch dir *and* the docs var split land together, because they are one file), `docs/architecture.md` into 9.2, and `docs/README.md` into 9.3.

**Two conditional new files** are pre-assigned to lanes 4 and 7, so a subphase that concludes it needs one already owns the scope and no lane boundary moves mid-run.

**Cross-lane edges are `after:` edges, never shared scope.** Round 2 changed the shape here: **2.3 is now the hub**, because the var split is what four other lanes depend on.

| edge | why |
|---|---|
| 4.1, 5.1, 6.1, 7.4 after 2.3 | each consumes the shipped var split; none edits the rule |
| 4.2 after 4.1, 4.3 after 4.2 | intra-lane: declare the expectation only once it exists |
| 5.2, 5.4 after 5.1; 5.3 after 5.2 | intra-lane, the publish model built outward from the rule |
| **5.2, 5.4 after 4.1** | both consume `resolve-config.sh --expect path\|publish-target`, the interface 4.1 creates. 5.4's Test-oracle line names *"4.1's `--expect` semantics"* as its truth source outright, and 5.2's criterion 6 requires the matching `--expect`. **Declared even though the practical risk is low** — the flag's spelling is pinned in this plan's text, and both subphases are verified by reading rather than by executing the script — because the schedule is derived from these edges, and an undeclared one lets the dispatcher start lane 5 before 4.1 exists. It also guards the real future hazard: a change to the flag's exact spelling landing in one lane and not the other |
| 8.1 after 5.1 | `document.md` cites the rule that says publishing is CI's job |
| 8.2 after 8.1 | `report.md` mirrors `document.md`'s shape — A2's *"never in where and how"* |
| 8.2 after 2.1 | `report.md` cites `resolve-scratch.sh`'s interface |
| 7.4 after 7.1 | the planner writes what the rule requires |
| 9.3 after 2.2 | the suite count depends on the new file existing |

**Files deliberately in NO lane's scope:**

| file | why not |
|---|---|
| `agent-agnostic/skills/document-local/SKILL.md` | round 1 planned a read direction for it; local-primary dissolves that. Its write-only description is now **correct**, and it is already the always record stage |
| `orchestrators/skills/dae/report-skeleton.md` | frame already filled identically at both types; an output-length axis was rejected |
| `orchestrators/agents/committee.md` | already owns the scratch-dir root fact correctly (`:56`) |
| `orchestrators/agents/planner/plan-*.md` | the ask pointer is type-independent — 7.4 puts it in the shared definition, not six copies |
| `orchestrators/skills/dae/worktree-modes.md` | the §D snapshot is not a `--worktree` mode |
| `orchestrators/hooks/workflow-setup.sh`, `allow-workflow-cleanup.sh`, `sync-install.sh` | enum- and allowlist-widening are out of scope; `sync-install.sh` maps hooks by pattern with no per-file enum |
| `agent-agnostic/AGENTS.md` | pre-existing drift outside the ask — R5 |
| `orchestrators/skills/dae/build.md` | still correct: it invokes the document skill per docs target, and after 5.1 that target is always local, so the dispatch resolves to `document-local` unconditionally. 8.1's sequence change is `document.md`'s to own. Confirm by reading in 9.1; if it names `document-confluence`, it moves into 9.2's sweep rather than gaining a lane |
| `project-plans/completed/**` | DP-3 |

---

## Risks, open questions, decision points

### Decision points

**DP-1 (§F6) — FULLY DEAD as of round 3.** Round 1 dissolved it (no gap specific to `analyze`); round 2 reshaped it (one docs mode); round 3 removed the last of it. With publishing moved to CI there is **one record path and no modes**, so there is no "which document skill" question for a parse-time error to answer. Recorded as closed, not deferred.

**DP-2 (§H) — RESOLVED at round 1: Option A, in this plan.** Chosen over this planner's Option B recommendation. Anchored in three layers so it cannot decay: a **rule** requires the pointer (7.1), a **script** enforces its presence (7.2), the **gate** judges faithfulness (7.3). Round 2 added the `story.md` connection so no parallel artifact is invented.

**DP-3 — the archived `§2.4` is not swept. UPHELD at round 1.** Editing `completed/` would rewrite the record of what shipped and destroy the evidence a later ask-vs-plan audit reads — which, after DP-2, is a real audit. The two **live** diagrams are swept instead (9.2(i)).

**DP-4 — `document-confluence` EXISTS. Premise withdrawn at round 2; recorded for the file.** Verified: `tool-based/confluence/skills/document-confluence/SKILL.md`, 63 lines, seven publish stages; `docs/tool-based.md:33` lists the layer as **real**. The "it does not exist" finding came from searching `agent-agnostic/skills/` and `~/.claude/skills/` — where it is genuinely absent, **by design**, because `source-push-sync` sends tech-bound content to consuming projects rather than the global install. **Round 3 changed what happens to it:** with publishing moved to CI, 5.2 is no longer an amendment but a **rewrite** — three of its seven stages survive the demotion to manual/recovery sync, and its Inputs contract and run-shape taxonomy die outright. Judged stage by stage in 5.2 rather than asserted.

**The honest residual, narrower than first stated:** Confluence mode is not unimplemented — it is **uninstalled in the global install by design**. A project that sets `CLAUDE_DOCS_PUBLISH` without installing the Confluence layer must fail **loudly** (5.2(c)); a silent skip is the dangerous outcome, because the local record succeeded and everything looks fine. **Making Confluence mode work globally is a separate, larger question about the tech-bound/universal split and is NOT in this plan.**

**DP-8 (NEW) — the requested symlink direction does not work. VERIFIED both ways; inverted in 5.4.** The user asked for the workflow canonical in a scripts dir and symlinked into `.github/`. **Established rather than assumed, in both directions:** (a) *mechanism*, proven locally — git stores the `.github` path as mode `120000` with blob content `../../scripts/publish-docs.yml`, the literal target string, **not YAML**; (b) *behavior*, confirmed externally — GitHub does not resolve symlinks in `.github/workflows`, and a symlink there fails CI immediately ([community discussion #109744](https://github.com/orgs/community/discussions/109744), open feature request). **The arrow inverts and nothing else changes**: canonical real file in `.github/workflows/`, symlink in `scripts/`. Every property the user named — tracked, viewable in a scripts dir, copyable, single-source — is preserved, and `doc-format:11` is satisfied either way since it constrains duplication, not which end is canonical. **`scripts/README.md` must record why**, or the direction gets "fixed" into breakage later.

**DP-5 — A4's script constraint, RESOLVED by the round-2 decision, and closed at round 3.** It was real but narrower than stated: `verify-run-scope.sh:112-116` already branched on `http*|confluence:*`, and it was the **only** script touching the docs root. Local-primary dissolves the problem rather than centralizing it — with `CLAUDE_DOCS_DIR` always a path, that branch is **dead code to delete** (4.1), and `resolve-config.sh` needs no flag at all. **This was the clearest example of a decision making the plan smaller:** the parked design added a script flag, a vocabulary, an error case and a test set; the shipped design deletes five lines. Round 3 then brought `resolve-config.sh` back for a *different* and better-justified reason — A6's hard error, which needs a tested home — and the publish-scheme check rode along, closing R12.

**DP-6 — the PR gate goes blind under Confluence-primary. VERIFIED, and now design rationale.** The chain, each link checked:

1. **The gate reviews a git diff, and only a git diff** — `review-pr/SKILL.md:26` (*"the diff is `git diff <base>...<branch>`"*), `:32` (*"The diff is the artifact"*), `:62` (*"Review the diff that exists"*).
2. **Under Confluence-primary there is no local docs tree**, so a doc change produces **no diff hunk**. The design already encoded this: `verify-run-scope.sh:112-116` removed the local docs allowance for off-repo values.
3. **So the accuracy oracle has nothing to audit.** `review-pr:37`'s subject is *"every load-bearing factual claim **in the diff**"*. Zero doc hunks means zero claims examined — **the step does not fail, it silently finds nothing.**
4. **No gate can compensate.** `grep -i confluence` across `review-pr`, `review-code`, `review-plan` returns one hit — `review-pr:27`, about fetching a **Jira ticket as a spec**. **No gate in the system reads a Confluence page.**
5. **And the gate is mandatory anyway** — `dae/SKILL.md:117`, *"EVERY `ship: publish` run, no exception."*

Under Confluence-primary a `document` run's entire deliverable would be invisible to the only gate that audits deliverables, and the run would still return `ready`. Local-primary keeps the deliverable in the diff, so `review-pr:37`'s code-as-accuracy-oracle works as designed and `verify-run-scope.sh` bounds it. **8.2 preserves the same property for `analyze`**, whose scope boundary would otherwise have constrained a directory that did not exist.

**DP-7 — concurrent doc writes: RESOLVED STRUCTURALLY at round 3, not merely mitigated.** Merges to the base branch are **serialized by git**, so a per-merge CI job publishes in order, one at a time. The last-write-wins hazard below is not guarded against — it is **removed**, because concurrent publishes can no longer occur. Recorded as the resolution. The original analysis is kept because it is why the decision was made: Stated here because the user asked, and recorded in the plan where it belongs (this section plus the lane-disjointness rules the Lanes section applies).

- **Prevention is at the PLAN layer** — `plan-format` requires lanes with no `after:` edge to have disjoint file scopes, and shared touchpoints to be serialized into their own subphase. This plan applies exactly that: 9.2 and 9.3 are serialized after 9.1, over disjoint file sets.
- **Git is the backstop when that fails** — `build-dispatch.md:14`, verbatim: *"A merge conflict IS a mechanical scope violation — two lanes touched the same file; stop, surface it, don't force-resolve silently."* `:17` makes it bite: the push *"never fires past a stopped or conflicted merge."*
- **One correction, in the design's favour:** **lanes never write docs at all.** Documentation is the Record stage, which runs **once per run**, after every lane has merged (`dae/SKILL.md:116`). Intra-run concurrent doc writes are structurally impossible for the doc tree; the plan-layer discipline matters for hand-written doc-sweep subphases like 9.2/9.3, which is exactly where it is applied.
- **The hazard that CI removes:** `grep -i 'version|conflict|concurrent|overwrite|lock'` across `document-confluence/SKILL.md` returns **nothing** relevant. Its update semantics are a bare read-modify-write — *"Search the space for an existing page …; update it if present"* (`:39`) — with no version precondition. Last write wins, silently. Worse, `:47`'s changelog is *"exactly ONE [page] in the space … reuse it for future entries"* — a single shared mutable resource **every run in the space** appends to, with no branch to protect it. That is the same shape as §C2's scratch-dir collision this plan already fixes. **Local-primary inherits git's conflict detection for free, and CI-on-merge inherits git's serialization for free; Confluence-primary would have needed an optimistic-concurrency story that does not exist anywhere in the design.** One residual, small and worth naming: `document-confluence` run **manually** while a CI job is in flight can still collide. That is a human choosing to race a job, not a designed path — 5.2 notes it; nothing guards it.

### Risks

**R1 — prose regressed silently last time (§F4).** Machine-checkable cores live in scripts with committed suites (2.1/2.2, 3.1/3.2, 4.1/4.2, 7.2); prose subphases carry `grep`/diff criteria a contract-tester can run without judging prose. Every unguardable subphase declares `existing implementation` rather than pretending otherwise (§F3).

**R2 — the §D snapshot qualifies a stated invariant.** "Zero git side effects" appears at `dae/SKILL.md:112`, `docs/pipeline.md:25`, `docs/architecture.md:116`. 8.2 restates it honestly; 9.1 and 9.2 carry criteria so the sweep cannot land partial.

**R3 — the `--ship` lock is a breaking change to a documented flag.** Accepted; the error names what to run instead. No deprecation path exists because there is no release process.

**R4 — stale counts.** The previous run found **four**. This run changes the suite count by **one to three** (2.2 certainly; 4.3 and 7.2 conditionally). Every count criterion says **count the directory at edit time**; 10.1 re-checks. The three literals are `architecture.md:68`, `architecture.md:149`, `docs/README.md:48`.

**R5 — pre-existing drift left alone.** `README.md:41` / `AGENTS.md:24` (*"plan-lifecycle.sh's fixture test"*, singular) and the incomplete no-ellipsis hook lists at `README.md:29-30` / `AGENTS.md:11-12`. Outside the ask; neither created nor worsened here.

**R6 — cross-lane citation dependencies.** Seven, all *citation* rather than write dependencies, and **2.3 is now the hub** — four lanes cite the var split. **Mitigation:** every cited interface is fixed by its own detail block (2.3's var names and semantics, 2.1's output lines, 5.2's reframing), so changing one is a plan amendment, not a lane decision. 10.1's coverage check re-reads both ends. **Residual:** if 2.3 lands wrong, four lanes are wrong together. It is the highest-leverage subphase in the plan and should be reviewed as such.

**R7 — the install sync is a landing-time obligation.** `sync-install.sh` runs from the **main checkout** after `push-main`; it refuses inside a linked worktree. **Lane 5 touches `tool-based/confluence/`, which by design does NOT sync to `~/.claude/`** — the orchestrator must not read its absence from the sync output as a failure.

**R8 — this run's own closeout depends on 3.1**, which fixes the `archive` exit-1-on-success bug.

**R9 — `plan-lifecycle.sh check` fails today, on `main`, for an unrelated reason.** Exit 1, `FAIL: unrecognized filename in proposals/: drive-download-20260824T043851Z-1-001.zip`. The file is **tracked** and on `main`; this plan's own filename is accepted. §G excluded the zip because purging *history* needs a force-push — correct — but `git rm`-ing the tracked file needs none. **Not planned**; raised for the user's call. One subphase in phase 9 scoped to `project-plans/proposals/` if wanted.

**R10 — Phase 5's Confluence half cannot be tested in this repo, at all, and round 3 widened it.** 5.2 needs a live Atlassian MCP connection; **5.4 additionally ships a CI workflow with no runner here** — its no-op path is the only branch this repo will ever execute, and even that only after a merge. There is no fixture and no suite that could host either. Their criteria are structural (`git ls-files -s`, `find -type l`, a YAML parse if a parser exists) and their oracle is `existing implementation`. **Confluence publishing ships verified-by-construction, not verified-by-execution** — this is the largest untested surface in the run and the reviewer should weigh it as such. Two things genuinely reduce the exposure, and neither is a consolation: a broken publish can no longer lose documentation (the local record already committed), and a broken publish can no longer fail a run (it is off the critical path entirely).

**R11 — the ask-vs-plan check could reject plans that are currently fine.** 7.2 adds a new failure mode and every plan in `project-plans/` predates the requirement. 7.2 criterion 6 and 10.1 item 7 require running it against the whole tree. **If existing plans fail, that is a finding about the check's strictness, not about those plans** — resolve by accepting the explicit no-durable-ask statement, never by retro-fitting asks onto archived plans.

**R12 — CLOSED at round 3.** Round 2 moved the unrecognized-publish-scheme check into `dae/SKILL.md` prose, where nothing tested it, and flagged the cost. A6's hard error gave `resolve-config.sh` a justified reason to change, and the scheme check rode along as `--expect publish-target` (4.1) — **tested by 4.3, in a suite that already exists.** No `--kind` flag was restored. Recorded rather than deleted because the reasoning is the useful part: a check without a test home is a real cost, and the right fix was to find it a home rather than to accept the gap.

**R13 (NEW) — `scripts/` is a new top-level directory, and new top-level directories go stale in tree blocks.** R4 is about counts; this is its structural twin. Three tree blocks enumerate the repo's top level (`docs/architecture.md`, `README.md`, `AGENTS.md`) and a fourth enumerates the tech-layer shape (`docs/tool-based.md:13-19`). 5.4 invalidates all four. 9.2 and 9.3 own them, and 10.1 does not currently diff tree blocks against the real tree — **it cannot, cheaply, since they are prose ASCII.** Accepted, flagged: the likeliest residual defect of this run is a tree block this planner did not find. Searched: those four; no other file enumerates the top level.

### Assumptions this planner could not verify

- **A1 — `CLAUDE_SCRATCH_DIR` and `CLAUDE_DOCS_PUBLISH` are free names.** The only `CLAUDE_*` vars in the tree are `CLAUDE_DOCS_DIR`, `CLAUDE_PROJECT_PLANS_DIR`, `CLAUDE_WORKFLOWS_DIR`, `CLAUDE_BASE_BRANCH`. Collision with something Claude Code itself defines is outside this repo and unverified.
- **A2 — why `tests/plan-lifecycle.test.sh` case 04 does not already catch F2.** Inferred, not confirmed. 3.2 must establish the real answer.
- **A3 — `git worktree add --detach` under a gitignored in-repo directory.** Expected to work on git 2.34.1; not exercised in this tree. Fallback is rung-3 placement.
- **A4 — the exact `analyze` KEY block after 1.1.** `RIGOR_PR=low` predicted by reading `resolve-type.sh:360` and `:509`; case 43c asserts exact equality so a wrong prediction fails loudly.
- **A5 — which suite owns `verify-run-scope.sh`.** `grep -l` matched `tests/verify-scope-parsing.test.sh`, but a name in a file is not proof its `SCRIPT=` points there. 4.2 must confirm by reading.
- **A6 — no suite covers `validate-plan.sh`.** Believed true from the listing; 7.2 must confirm rather than assume.
- **A7 — the Atlassian MCP's read capabilities for the publish step.** 5.2 specifies by *capability*, never by tool-function name, matching the file's own convention (`:58`). Whether every capability it needs is exposed is unverified here — R10 restated.
- **A8 — RESOLVED at round 3.** The migration hazard this planner flagged (an existing `CLAUDE_DOCS_DIR` holding a Confluence value being read as a local path, silently creating a directory named after a URL) is now a **hard error**: 2.3 states it, 4.1 enforces it, 4.3 tests it. A project with the old config stops until someone edits `settings.json`, which is the correct outcome for a breaking config change. Kept in the record because the flag-rather-than-plan-around-it call was the right one and the resolution came from it.
- **A9 (NEW) — that GitHub's symlink behavior will not change.** DP-8 rests on an **open feature request**; if GitHub ever resolves workflow symlinks, the inverted arrow becomes unnecessary (though still harmless). `scripts/README.md` should state the constraint as *currently true* rather than as a law, so a future reader can re-test it cheaply rather than assuming.
- **A10 (NEW) — that a consuming project's CI can run `resolve-config.sh`.** 5.4's job resolves both vars through it, which assumes the project installed the hooks. If a project installs only the Confluence layer and not the orchestrator hooks, the job cannot resolve anything. `tool-based/confluence/ci/README.md` must state that dependency; whether the job should degrade or fail loudly in that case is a judgement this planner left to the builder, flagged here rather than silently decided.

---

## Skill mapping

| part of the plan | who executes it |
|---|---|
| Lanes 1-8, dispatched per subphase | `builder` agent, one child worktree per lane on `feature/report-pipeline-and-locations-l<n>`, cut via `workflow-setup.sh --parent` |
| Packet implementation | `coder` sub-agents, for the `new contract tests` subphases: 1.1, 1.2, 1.3, 2.1, 2.2, 3.2, 4.2, 7.1, 7.2 |
| Test authoring | `contract-tester` sub-agents, blind, from the contract text alone. For the `existing implementation` subphases — 2.3, 5.1, 5.2, 5.3, **5.4**, 6.1, 7.3, 7.4, 8.1, 8.2, 9.1, 9.2, 9.3 — it is **contract-tester only, no coder**. 3.1 and 4.1 declare `existing suite`: coder only |
| Subphases 9.1-9.3 and 10.1 | serialized, no lane. 9.1 is the shared touchpoint; 10.1 is whole-run verification |
| Plan gate | `review-plan` + `validate-plan.sh`, into `plan-review.md`. **Note the recursion:** Phase 7 modifies both. The gate reviewing this plan runs the *pre-change* versions; the post-change versions govern the next run — and 7.2 criterion 7 requires the new script to pass on this plan file, the only self-consistency check available |
| Code gate | `review-code`, once every lane has merged |
| Record stage | `document-local` — and, because this repo sets no publish var, **5.2's Confluence path is not exercised by this run's own record stage** (R10) |
| PR gate | `review-pr` + `verify-run-scope.sh` — **whose behavior 4.1 changes.** The gate runs the post-change script against this run's own diff: a genuine end-to-end exercise of the deletion |
| Landing | **`push-main`** — local squash-merge to `main`, no PR. This repo's override of `push-policy` |
| Post-landing | `sync-install.sh <pushed-range>` from the **main checkout**. Mandatory. `tool-based/confluence/` will not appear in its output — by design (R7) |
| Closeout | `cleanup-merged`, then `plan-lifecycle.sh archive` — which 3.1 makes exit 0 (R8) |
