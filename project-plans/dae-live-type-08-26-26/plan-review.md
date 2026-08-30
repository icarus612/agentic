# dae-live-type-08-26-26.plan-review

## Round 1 — 08-27-26

```
verdict: rejected
next: plan-wrong
blocking: 2
non-blocking: 8
```

### Findings

- [blocking] **`plan-lifecycle.sh check` fails structurally.** `bash orchestrators/hooks/plan-lifecycle.sh check` (run from the plans-dir root, per the skill's mandate to run this alongside `validate-plan.sh`) exits 1: `FAIL: unrecognized filename in proposals/: drive-download-20260824T043851Z-1-001.zip`. Confirmed by directory listing: `project-plans/proposals/drive-download-20260824T043851Z-1-001.zip` (8.4MB) sits beside this proposal. The plan's own R9 already names this exact file and calls it "unrelated to this plan" / "outside this plan's scope" — that framing is accepted, but per this gate's own rule any `FAIL:` from either structural script is blocking regardless of whose fault it is or how old it is; a legacy/pre-existing issue is explicitly not an excuse. This is **not** a planner-content defect — it is a plans-dir housekeeping action (delete or relocate the stray zip) the caller/user should perform before promotion, independent of any plan revision. Flagging it here so it is not silently waved through.
- [blocking] **The plan's new-test-case numbering collides with an existing test case, across three subphases.** `tests/resolve-type.test.sh` already contains a `# --- Case 50: --pipeline locked fires before --ship locked` block at lines 950-963 (verified via `grep -n "^# --- Case" tests/resolve-type.test.sh` — the last existing case is 50, immediately before the file's Summary block). The plan's premise, stated explicitly in 1.1's Test approach ("Numbers 44–49 are taken by the ship-lock cases; start new sections at 50") and echoed downstream, is false — case 50 is already taken. Concretely:
  - **1.1** proposes new cases `50a-e`, `51a-c`, `52a-c`, `53a-b` for the rework dial — these must start at 51, not 50.
  - **3.1** proposes new cases `54a-f` for the ship row-list syntax, built on the same wrong base.
  - **4.1** proposes new cases `55a-c` for the `live` type, same issue.
  - More importantly, **Risk R2** ("three separate subphases each break an existing case: 1.1 breaks `43a`; 3.1 rewrites `44`/`45`/`46`/`49` and case 29's banner; 4.2 breaks `30`") omits case 50 entirely, even though 3.1 changes `--ship` from locked to constrained and case 50 asserts specifically that the `--pipeline` lock error fires before any `--ship` mention (`feature --pipeline build --ship chat` → exit 1, stderr has `--pipeline`/`locked`/`feature`, stderr does NOT have `--ship`). I checked this case's actual assertions against 3.1's reordering (pipeline lock check still fires first, error text unchanged) — the case likely still passes unmodified — but the plan never says so; it simply never mentions the case exists. A contract-tester working blind from 3.1's detail block, told "numbers 44-49 are taken... start at 50," has no way to know case 50 already exists and needs to be either left alone (with that decision stated) or repaired.
  This is a genuine "confidently wrong" foundation gap, not a matter of taste: every subphase's test-approach text was written as if the suite ends at case 49. Recommend a planner revision that (a) shifts the whole new-case numbering scheme to start at 51, (b) adds case 50 to R2's list of existing cases each subphase must check, with an explicit statement of whether 3.1 needs to touch it (my own check suggests it does not, but the plan should say so rather than the gate inferring it).

- [non-blocking] **1.1's "pattern to follow" mis-cites the `--explore` emission line.** The plan says "`--explore` is parsed at `:193`, validated at `:351-354`, and emitted at `:526`" — `:526` is actually `[ "$has_code_phase" = 1 ] && echo "RIGOR_CODE=$rigor_code"`; `EXPLORE=$explore` is unconditionally emitted at `:523`. Doesn't change what REWORK's conditional emission must do (still `[ "$has_code_phase" = 1 ] && echo "REWORK=$rework"` between `SHIP=` and `PLANNER=`, exactly as pinned), but the citation itself is wrong.
- [non-blocking] **3.1 step 4's constraints-reordering citations are all off by 2-4 lines.** Verified with `grep -n` against the current `resolve-type.sh`: the comment "constraints: locked, then placement, then arity" is a single line at `:473` (plan cites `:476-479`); the `--pipeline` lock check to move is at `:477` (plan cites `:480`); the locked-`--ship` block to delete spans `:479-494` (plan cites `:481-495`). The region is small and easy to re-locate by reading the file, and the pinned precedence ("locked `--pipeline` → constrained `--ship` → `--plan` placement → `--against` arity") is acceptance-criteria-tested regardless, but this is exactly the passage where precise citations matter most and Amendment 1 claimed "re-verify every line cite."
- [non-blocking] **Several `tests/resolve-type.test.sh` citations have drifted by a few lines** (verified against the current file): the six reusable primitives cited at `:133-169` actually span `:125-171`; case 43b (`map`'s block) cited at `:749-763` actually ends at `:761`; case 43c (`analyze`'s block) cited at `:765-781` actually spans `:763-777`; the ship-lock cases cited at `:880-935` actually run through `:948` (case 49 ends at 948, not 935). Also, 1.1's "anchor-conditional idiom at `:196-198`, `:463`, and `:631`" mischaracterizes `:631`: that loop's case statement is `case "$t" in rework) …` with no `sync` branch at all (unlike the other two cited spots, which genuinely are `rework|sync)`).
- [non-blocking] **`README.md:48-50` is off by one line** — the stale workflow enumeration (missing `map`/`analyze`) that 5.1 targets actually sits at `:49-51`. The staleness claim itself is correct.
- [non-blocking] **2.2's "same voice as the script's existing detached-HEAD refusal" undersells the gap.** `workflow-setup.sh`'s only current detached-HEAD check (`:175-177`) fires solely when adopting an existing worktree path under `--reuse` — there is no general "is the current HEAD detached" guard today. `--here`'s detached-HEAD refusal will need genuinely new logic (checking the CURRENT checkout, not a reused path), matched in wording/voice to the existing one rather than reused code. Worth a one-line clarification so the builder doesn't go hunting for a reusable general-purpose check that doesn't exist.
- [non-blocking] **2.3's acceptance-criteria grep should be case-insensitive.** `worktree-modes.md`'s current `none` section reads "Builder dispatch is limited to **ONE** lane at a time" (capitalized). The plan's verification grep ("`single-lane`, `one lane at a time`, `worktree none`") is case-sensitive as written and would silently pass even if a capitalized remnant survived 2.1's rewrite. Recommend `grep -i`.
- [non-blocking] **4.3's characterization of `review-pr`'s "deviation clause" is a fair paraphrase but not a literal one.** `review-pr/SKILL.md` step 3 uses the word "diverged" (not "deviation") and does say diverged syllabus items "are findings" without mandating blocking/non-blocking severity, and step notes (`:64`) do warn against inflating non-blocking notes into blocking ones — so the substance checks out. But framing 4.4's severity-profile mechanism as merely "pins existing latitude rather than overriding a rule" slightly undersells it: nothing in `review-pr` today says plan deviations default to non-blocking, so the profile is a genuine (if narrowly-scoped and asymmetric) severity override for one category, not a passive continuation of existing behavior.
- [non-blocking] **Lanes 1.2/3.2/4.7's "Test approach" text implies a temporal dependency on lane 1 that the syllabus doesn't declare.** Each says to read-through "against `resolve-type.sh` as it stands at the end of lane 1," but none carries an `(after:)` edge to the corresponding lane-1 subphase — by design, since Conventions pins the exact table rows and emission contract precisely so lanes 1/2/5/6 "write matching content without coordinating," and final cross-file consistency is genuinely checked at 5.3 (which does carry the full `after:` set). The design is sound; only the individual subphases' own wording could mislead a builder into thinking there's an enforced ordering that isn't actually there.

### Open questions

- **Q-A** (already flagged by the plan itself, `Risks, open questions, decision points`): confirm `--ship` on a locked row is REFUSED even when the value already agrees (3.1 pins this, matching today's case 45 behavior) — the user should explicitly confirm this UX choice, since the friendlier alternative (accept a no-op) was considered and rejected.
- **Q-B** (already flagged by the plan itself): how `SKILL.md`'s type table should render an overridable `ship` cell (`chat` *(or `publish`)* vs `chat|publish`) — a readability call for the user to make once so `docs/pipeline.md` can match it.
- **Q-C** (already flagged by the plan itself): confirm the flag name `--here` for `workflow-setup.sh`'s new in-place-parent mode, vs. the alternatives `--in-place` / `--rundir-only` considered in 2.2.

These three are the plan's own open questions, carried into this gate; I found no separate open questions of my own that would need to block a verdict beyond the two blocking findings above.

## Round 2 — 08-28-26

```
verdict: ready
next: proceed
blocking: 0
non-blocking: 1
```

### Findings

- [non-blocking] **1.3/1.4's rework-budget description has no explicit "not a scheduling dependency" disclaimer, unlike the 1.2/3.2/4.7 pattern the plan uses elsewhere.** 1.3 (lane 4, `build-dispatch.md`) and 1.4 (lane 3, `builder.md`) both describe the same rework-budget meaning ("max rework rounds per packet AND max chunk-level e2e diagnose-and-redispatch rounds") and 1.4's acceptance criteria requires it to "match 1.3 in substance," but neither subphase carries an `(after:)` edge to the other, and — unlike 1.2/3.2/4.7, which explicitly say "this is a consistency check, not a scheduling dependency" — 1.3/1.4 leave this implicit. Low risk in practice: the plan itself pins the exact one-sentence description both files must use, so a builder reading either subphase's text gets matching wording without needing to read the sibling lane's output. Purely a documentation-clarity nit, not a coordination defect; not blocking.

### Open questions

No new open questions from this round; the three carried from Round 1 (Q-A, Q-B, Q-C) remain open and unresolved by Amendment 1 — they are genuine user decisions the plan defaults sensibly but does not silently assume, and should be confirmed at the approval gate.

## Round 3 — 08-29-26

```
verdict: ready
next: proceed
blocking: 0
non-blocking: 6
```

### Findings

This round re-reviews the plan after Amendment 2 (dropping Phase 2 `-w none` entirely, settling
the `--ship` warn/error rule D10, and settling ship-cell rendering) landed on top of Round 2's
`ready` verdict. Both structural gates pass clean: `validate-plan.sh` reports `OK: plan is
structurally valid (17 subphases)`; `plan-lifecycle.sh check` reports `OK: plans dir layout is
conformant` — the stray `drive-download-...zip` that blocked Round 1 is confirmed gone from
`project-plans/proposals/` (removed in commit `3b2af5b`, already on this branch).

Verification for this round was split across parallel passes (resolver/table/tests;
router/builder/planner/review-pr; docs/AGENTS.md/README/lane-scope) plus direct spot-checks,
re-converging on one verdict. Combined, essentially every load-bearing citation in the plan was
checked against the actual worktree files, not the plan's prose: `orchestrators/hooks/resolve-type.sh`
(`FLAG_TABLE`/`resolve_flag`, argv handling, row-cell reads, the phase-existence table, the
2.1-cited constraints reordering now confirmed exactly at `:473`/`:477`/`:479-494`, and the output
block), `orchestrators/skills/dae/workflows.yaml` (current rows have no `rework:` cell, single-value
`ship:` cells throughout, `against: forbid` on `feature`/`migration` — exactly the pre-state the
plan's diff assumes), `tests/resolve-type.test.sh` (cases 29/30/32/34/43a-c/44-50 byte-exact against
their cited ranges; highest existing case confirmed `50`, so the plan's new numbering `51`-`56` is
collision-free), `orchestrators/skills/dae/SKILL.md` (flag table, bracket-minimum sentence,
override-tier bullet, emitted-keys/error-set/warning-example lines, the ten-row type table, the seam
table), `build-dispatch.md`, `orchestrators/agents/builder.md`, `orchestrators/agents/planner.md`,
`build.md` (confirmed `:13` ends "THEN switch to auto mode and dispatch," exactly as 3.3 quotes it)
and `report.md`, `agent-agnostic/skills/review-pr/SKILL.md` (confirmed `## Inputs` is currently a
closed 3-item list and step 3 says "diverged," never "deviation"), `plan-feature.md`/`plan-bugfix.md`
(confirmed 8/9 lines and the shared opening line, exactly as 3.5 claims),
`agent-agnostic/skills/review-plan/scripts/validate-plan.sh` (confirmed the syllabus-first check, the
outside-syllabus-only detail-ID harvest, the exactly-one-detail-block check, and no
contiguity/ordering/start-at-1 check anywhere, matching 3.5's claim), `orchestrators/AGENTS.md`,
`README.md:49-51` (confirmed the stale enumeration omits `map`/`analyze`), `docs/pipeline.md`,
`docs/architecture.md`, `docs/README.md`, `docs/conventions.md` (confirmed it points at
`orchestrators/AGENTS.md#review-rules-for-future-types`), `orchestrators/hooks/sync-install.sh`
(confirmed both install-mapping rules the plan cites), `orchestrators/hooks/validate-report.sh`
(already accepts `blocked`), and the parked stub `project-plans/proposals/none-mode-parent-08-28-26.md`
(well-formed plan-format: one phase, one subphase, explicit "no durable ask" statement, matching
what this plan's Goal & scope and 4.3 describe it as containing).

I diffed the plan's intent against the ask of record (`.artifacts/brief.md` + Amendment 1 +
Amendment 2): no undelivered requirement, no unrequested addition, and no inversion. The one
apparent divergence — Phase 2 (`-w none`) being dropped from a brief that originally specified it —
is not a silent departure: Amendment 2 §1, itself part of the ask of record, is the user's own
decision to drop it, and the plan's Goal & scope names the deferral and points at the parked stub
exactly as Amendment 2 requires.

Six non-blocking findings, all citation/doc-staleness nits, none load-bearing:

- [non-blocking] **`docs/pipeline.md:81` will go stale and nothing in the plan's file scope catches
  it.** It reads "...`rigor: low`; `analyze` always publishes." — the identical claim `SKILL.md:68`
  makes today, which 2.2 step 9 explicitly rewrites. `docs/pipeline.md:81` makes the same claim but
  sits outside the type table (which is what 4.2 step 2 targets) and outside every other item in
  4.2's edit list; nothing in the plan names this sentence. After 2.1/2.2 ship, `analyze --ship chat`
  is legal, so this sentence becomes false. Recommend adding an explicit line item to 4.2 covering
  `docs/pipeline.md:81` the same way 2.2 covers `SKILL.md:68`.
- [non-blocking] **4.2 step 2's instruction to "render the `map`/`analyze` ship cells as
  `chat | publish` / `publish | chat` to match 2.2" doesn't map onto `docs/pipeline.md`'s actual type
  table**, which has no `ship` column at all — its columns are `--type` / `pipeline` axis / `Middle
  file` / `Middle stages`, and ship behavior is only implied in prose (see the finding above). The
  builder will need to locate wherever a ship-cell rendering actually applies in this file — the
  Hooks & scripts section, most likely — rather than finding a literal cell to edit as the instruction
  implies.
- [non-blocking] **The plan's own Risk R9 is now stale.** It says `plan-lifecycle.sh check`
  "currently FAILS on this repo, on a stray `drive-download-20260824T043851Z-1-001.zip`." That file
  is gone (commit `3b2af5b`) and the check now passes cleanly, confirmed above. Harmless to leave —
  it doesn't gate anything — but a future revision should update or drop it so a reader doesn't go
  hunting for a file that no longer exists.
- [non-blocking] **3.2's citation `resolve-type.sh:83`** for "anchors are passed through raw" is off
  by 58 lines — the actual text ("Anchors are passed through raw — resolving them...") is at `:25`,
  in the file's header comment block, not `:83`. Doesn't affect 3.2's acceptance criteria, which don't
  depend on this line.
- [non-blocking] **4.1's citation `orchestrators/AGENTS.md:86-90`** ("the other types swap the middle
  file") is slightly short — the actual sentence runs `:86-92`. Doesn't change where `live` gets
  inserted into the enumeration.
- [non-blocking] **4.1's citation `orchestrators/AGENTS.md:133-138`** ("the agents table") stops short
  of the table's last two rows (`contract-tester`/`committee`, which run to `:140`). A
  pattern-reference only, not a load-bearing edit target.

### Open questions

None. Round 1's Q-A and Q-B were settled by the user in Amendment 2 (D10); Q-C became moot when
Amendment 2 dropped Phase 2 entirely. No new open questions surfaced in this round's verification.

## Round 4 — 08-29-26

```
verdict: rejected
next: plan-wrong
blocking: 1
non-blocking: 2
```

Scope for this round, per the caller: Amendment 3 only — the new Phase 4 (lane 6,
`scope-writes.sh`/`parent-tree-guard.sh`/settings wiring/contract tests) and the Phase 5
integration changes. Lanes l2/l3/l4 (Phases 1–3's already-merged subphases) were not re-reviewed,
per instruction. Both structural gates still pass: `validate-plan.sh` reports `OK: plan is
structurally valid (21 subphases)` (17 pre-existing + Phase 4's four new ones); `plan-lifecycle.sh
check project-plans/dae-live-type-08-26-26` reports `OK: plan dir conformant`. Git log confirms l2
(`9650443`), l3 (`2765ef1`), l4 (`b0bfa6f`) are merged and their syllabus items ticked, matching the
plan on disk.

Every load-bearing claim in Phase 4 and Phase 5 that could be checked against the real tree checked
out. Confirmed directly: `scope-writes.sh`'s `CLAUDE_SCOPE_ALLOW` mechanism, its "BUILDER LANE SCOPE
(documented, NOT wired)" block, and its "worktree + branch isolation is the backstop" line, all at
the exact lines 4.1 cites (`:4-5`, `:21-25`, `:28-29`, `:36-37`); `agent-specific/claude/settings.json`
has exactly ONE `PreToolUse` `Write|Edit|MultiEdit|NotebookEdit` block (`:147-155`, byte-exact to
4.3's citation) with only `branch-squash-guard.sh` in it — `scope-writes.sh` genuinely was never
wired, and there is no existing `PostToolUse` `Bash` matcher block, confirming 4.3's claim that one
must be created; `sync-install.sh:128` maps `orchestrators/hooks/*` → `hooks/<file>` exactly as 4.3
cites; `verify-run-scope.sh:106` resolves `CLAUDE_PROJECT_PLANS_DIR` exactly as 4.1 cites as the
pattern to follow; `workflow-diff-check.sh` has the cwd-from-stdin-else-`$PWD` idiom 4.2 cites as its
pattern; `tests/workflow-setup-reuse.test.sh` has the `mktemp -d`/pinned-`HOME`/`TOTAL_PASS`/`trap
cleanup` shape 4.4 cites; `parent-tree-guard.sh` does not yet exist (correctly a new file); the
current suite count is 10 (`ls tests/*.test.sh`), matching the "10 → 12" claim. `SKILL.md:143`,
`orchestrators/AGENTS.md:39/86-92/96/114-117/136`, `docs/pipeline.md:57/61-68/81/181-182`,
`docs/architecture.md:114-117/168`, `docs/README.md:40/48`, and `README.md:49-51` all read exactly as
Phase 5's citations describe — still stale (still saying "ten types," still unwired hooks, still
"`analyze` always publishes") — which is exactly the state Phase 5 is written to correct, and
`docs/pipeline.md`'s type table genuinely has no `ship` column, confirming 5.2 item 2's warning not to
look for one. Lane 6's file scope and lane 5's file scope are disjoint from each other and from every
other lane's, and the `(after:)` edges (`4.1` after `3.2`; `5.1` after `1.4, 3.2, 3.4, 3.6, 3.7, 4.4`)
are exactly what the dependency reasoning in Phase 4's intro and Phase 5's header require.

One blocking finding, found only because I re-read the ask of record at the top of this round rather
than trusting the round-3 diff: the ask of record has grown since this plan was last revised, in a
way that lands squarely inside the two phases this round was scoped to review.

### Findings

- [blocking] **The ask of record now contains an `## Amendment 4` (dated 2026-08-29) that Phase 4 and
  Phase 5 do not implement, and that directly contradicts a sentence already in the plan's own scope
  section.** `.artifacts/brief.md` was modified (mtime 14:08:19) after `plan.md` was last written
  (mtime 14:05:39) — this happened during my review, and I re-read the file per the standing
  instruction to treat a changed artifact as current rather than stale. Amendment 4 documents a real
  regression this very run hit: lane l4's builder returned `status: success` with two files
  uncommitted in its child worktree; `verify-scope.sh` reported OK because it counts staged+untracked
  changes rather than the committed diff; `git merge <child-branch>` then merged NOTHING, silently —
  the router only noticed because `git worktree remove` refused. `.artifacts/progress-log.md` confirms
  the router already witnessed this exact incident and logged it as a "NOTE for retro," but had not
  yet turned it into a plan amendment as of `plan.md`'s last edit. Amendment 4 requires, with its own
  lane assignments:
  1. `verify-scope.sh` gains a FAIL-on-uncommitted-change check, plus a new test file — **assigned to
     lane 6**, the exact lane this round reviews. Lane 6 as currently written (4.1–4.4) covers only
     `scope-writes.sh` and `parent-tree-guard.sh`; nothing in it touches `verify-scope.sh`.
  2. `build-dispatch.md` and `builder.md` gain a dirty-worktree-is-a-stop rule (the router never
     commits on a builder's behalf; the builder's last step before its exit report must be a clean
     `git status --porcelain`) — **assigned to the integration lane (Phase 5), as its own subphase**,
     since both files are lane 3's and lane 3 has merged. Phase 5 (5.1–5.4) has no subphase touching
     either file.
  3. `live.md`'s per-lane merge step must reference that same stop by pointer — **same integration
     subphase**. Phase 5 has no subphase touching `live.md` either.
  Worse than a simple omission: the plan's own "Explicitly out of scope" bullet
  (`plan.md:152-153`) reads "Any change to `report-verdict.sh`'s verdict/`next` vocabulary, to
  `validate-report.sh`, or to the scope scripts (`verify-scope.sh`, `verify-run-scope.sh`)" —
  the literal opposite of what Amendment 4 item 1 now requires. This is not a citation drift or a
  wording nitpick; it is the ask of record and the plan actively disagreeing about whether
  `verify-scope.sh` may be touched, and it sits inside the two phases I was asked to verify, not in
  the merged phases I was told to skip. Recommend routing this to the planner immediately as
  `plan-wrong`: Amendment 4 already names the exact five required changes and their lane assignments,
  so this should be a small, targeted revision (extend lane 6's file scope and add one subphase;
  extend the integration lane with one more subphase and its `after:` edges) rather than a redesign,
  and everything else Phase 4/5 currently contain can most likely survive the amendment unchanged.

- [non-blocking] **5.2 item 6 sends the builder looking for a "map/analyze ship description" at
  `docs/architecture.md:114-117` that isn't there.** That passage (confirmed by direct read) is only
  the middle-file list and the "ten types across four pipeline values" count — no ship-behavior prose
  at all. The nearest thing to a ship description in the file is line 133 ("The planner-less publish
  types (`document`, `analyze`) skip straight to…"), which is not "the same passage," is not wrong
  today, and needs no Phase 2 correction — `analyze` remains a publish-default type even after
  `--ship chat` becomes a legal override. Low risk (a builder finding nothing to correct there simply
  moves on), but worth dropping the instruction so nobody "corrects" line 133's still-accurate wording
  to satisfy it.
- [non-blocking] **`orchestrators/AGENTS.md:115-117`, cited for the "Wired hooks" list, is off by one
  line at the start.** The label "Wired hooks:" itself is at `:114`; the `scope-writes.sh` clause the
  plan quotes verbatim ("`PreToolUse` deny-outside-allowlist; live config = orchestrator scope; the
  builder-lane config was retired — worktree isolation replaced it") is exactly at `:115-117` as
  cited. Purely cosmetic — the quoted text is correct — but noting it continues this plan's pattern of
  small citation drift that prior rounds already tracked in bulk.

### Open questions

None from this round's verification. The blocking finding above is not an ambiguity needing the
user's judgment — Amendment 4 already states what to do and where; it is a plan revision that has not
happened yet.

## Round 5 — 08-29-26

```
verdict: rejected
next: plan-wrong
blocking: 1
non-blocking: 4
```

Scope for this round, per the caller: Amendments 3 AND 4 combined — Phase 4 (lane 6, 4.1–4.5) and
Phase 5 (5.1–5.5), re-reviewed against the plan as amended by commit `a172c9b`. Lanes l1–l4 (Phases
1–3's merged subphases, 13/23 ticked) were not re-reviewed, per instruction. Both structural gates
pass: `validate-plan.sh` reports `OK: plan is structurally valid (23 subphases)` (13 pre-existing +
Phase 4's 5 + Phase 5's 5); `plan-lifecycle.sh check` reports `OK: plan dir conformant`.

`a172c9b`'s diff (`git diff 2182599 a172c9b -- plan.md`) confirmed against the working tree: it adds
item 5 to the Goal & scope intro, the full `### Amendment 4` narrative section, risk `R12`, the
"Per-lane merge-back gate" skill-mapping row, the stack table's suite-count bump (12→13, one line),
and — the substantive piece — the entire `### 5.4: Merged-lane wording` detail block, which did not
exist before this commit (at `2182599` the syllabus already listed a `5.4` line but no matching
`### 5.4:` heading existed anywhere in the body — a structural gap this commit closes). `4.4`
(`verify-scope.sh`) itself was already fully written at `2182599`, predating this commit; only its
line-alignment whitespace changed here.

Every load-bearing citation in the new/changed material was checked against the real tree, not the
plan's prose: `orchestrators/hooks/verify-scope.sh`'s docstring (`:11-13`, `:14-15`, `:29-31`),
`err()` (`:34`), the four-way diff union (`:119-122` byte-exact — committed/unstaged/staged/
untracked in that order), and the `UNREPORTED`/`UNCHANGED` lines (`:127`, `:132`) all match 4.4's
citations exactly. `build-dispatch.md`'s step 1 ("Verify the lane") is exactly at `:13`; its
crash-resume `--reuse` path is exactly at `:34`, both byte-exact to 5.4's citations. `live.md`'s
stage 4 (`:47`) is confirmed already a clean pointer-by-name to `verify-scope.sh` with no restated
detail — exactly the state 5.4 item 3 describes as "a no-op read." `docs/architecture.md:114-117`
and `orchestrators/AGENTS.md:110-120` were re-read directly (see non-blocking findings below). The
test-suite count (10 on disk today, 13 claimed after Phase 4) and `agent-specific/claude/
settings.json`'s current `PreToolUse`/`PostToolUse`/`Stop` wiring were re-confirmed unchanged from
Round 4's verification. Lane 6's file scope (`scope-writes.sh`, `parent-tree-guard.sh`,
`settings.json`, `verify-scope.sh`, three new test files) and lane 5's file scope (`SKILL.md`,
`AGENTS.md`, root `README.md`, three `docs/` files, `build-dispatch.md`, `builder.md`, `live.md`)
remain disjoint from each other and from every other lane's; `5.4 (after: 5.3)` and the rest of the
`(after:)` chain are unchanged and still sound.

I diffed the plan's intent against the ask of record (`.artifacts/brief.md` through `## Amendment
4`, which the plan's own `### Amendment 3`/`### Amendment 4` sections quote and implement) for
exactly the three items Amendment 4 requires: (1) `verify-scope.sh` gains a FAIL-on-uncommitted
check plus a new test file, assigned to lane 6 — delivered by 4.4/4.5, with 4.5's file scope
explicitly listing `tests/verify-scope-clean.test.sh`. (2) `build-dispatch.md`/`builder.md` gain a
dirty-worktree-is-a-stop rule, assigned to the integration lane as its own subphase — delivered by
new 5.4 items 1–2, which name the router's no-commit-on-behalf-of-the-builder rule in as many words,
matching the ask verbatim. (3) `live.md`'s merge step references the stop by pointer — delivered by
5.4 item 3, correctly recognizing the pointer is already clean. No omission, no addition, no
inversion in this delivery.

One blocking finding: Round 4's underlying contradiction — not just the missing Amendment-4 content
around it — is still live.

### Findings

- [blocking] **The plan's own "Explicitly out of scope" bullet still forbids the exact file Phase 4
  requires changing, and `a172c9b` did not touch it.** `plan.md:176-177` (current numbering) reads:
  "Any change to `report-verdict.sh`'s verdict/`next` vocabulary, to `validate-report.sh`, or to the
  scope scripts (`verify-scope.sh`, `verify-run-scope.sh`)" — listed as explicitly out of scope for
  this entire plan. Phase 4.4 ("`verify-scope.sh` — a dirty child worktree FAILS, diff is
  committed-only," lane 6) directly modifies `orchestrators/hooks/verify-scope.sh`, as does 4.5
  (contract tests for it), 5.4 (documents the behavior it now implements), and 5.5 (runs
  `bash -n` over it and re-runs its test suites). This is the identical contradiction Round 4 raised
  ("the ask of record and the plan actively disagreeing about whether `verify-scope.sh` may be
  touched") — confirmed still present, unchanged, by `git diff 2182599 a172c9b -- plan.md`, which
  contains zero hunks touching the "Explicitly out of scope" section (verified directly: `git diff
  2182599 a172c9b -- plan.md | grep -n "Explicitly out of scope"` returns nothing). Round 4's
  finding text described this bullet by its then line numbers (`152-153`); it has since moved to
  `176-177` as unrelated content was inserted above it, but its wording is byte-identical to what
  Round 4 quoted. Commit `a172c9b` added the *substance* of Amendment 4 (the `### Amendment 4`
  narrative, `R12`, the full `5.4` detail block) but never revisited this bullet, so the plan still
  contains a standing self-contradiction: one section tells a reader `verify-scope.sh` may not be
  touched, three others depend on it being touched. Fix is small and targeted — carve out an
  exception in the out-of-scope bullet for the one behavior Amendment 4 adds (the uncommitted-check
  and its committed-only comparison), while keeping `verify-run-scope.sh` and the rest of
  `report-verdict.sh`/`validate-report.sh` genuinely out of scope, since nothing in Amendment 3 or 4
  touches those.

### Non-blocking findings

- [non-blocking] **Round 4's `docs/architecture.md:114-117` citation nit is still present, unchanged.**
  5.2 item 6 still reads: "The same passage's `map`/`analyze` ship description needs the Phase 2
  correction," citing `:114-117`. Re-read directly: that range is the middle-file list, the "ten
  types across four pipeline values" count, and `map`'s own ship-default sentence — it does not
  contain an `analyze` ship description at all. The actual `analyze`-adjacent sentence ("The
  planner-less publish types (`document`, `analyze`) skip straight to…") is at line 133, is not
  wrong today, and needs no Phase 2 correction, exactly as Round 4 found. A builder following this
  instruction literally will find nothing at `:114-117` to correct and should move on without
  "fixing" line 133's still-accurate wording.
- [non-blocking] **Round 4's `orchestrators/AGENTS.md:115-117` labeling nit is still present,
  unchanged.** 5.1 item 6 still frames `:115-117` as "the 'Wired hooks' list" — the label itself
  ("Wired hooks:") is one line earlier, at `:114` (re-confirmed: `sed -n '110,120p'
  orchestrators/AGENTS.md`). The quoted `scope-writes.sh` clause is genuinely byte-exact to
  `:115-117` as cited, so this remains purely cosmetic, not a citation error — carried forward
  because the caller asked to re-check it, not because it newly matters.
- [non-blocking] **The Goal & scope "Ask of record" pointer sentence undercounts the ask.** It reads
  "…plus its `## Amendment 1` … and `## Amendment 2` …" and stops there, even though
  `.artifacts/brief.md` has since grown `## Amendment 3` and `## Amendment 4` (both dated
  2026-08-29), and the plan's own `### Amendment 3`/`### Amendment 4` sections faithfully implement
  them (verified above — no divergence found). The pointer sentence is the one place a reader looks
  to know which parts of the ask this plan traces to, and it no longer lists two of the four
  sections it actually delivers. Low risk since the content itself checks out, but worth a one-line
  fix so the sentence stays trustworthy as a pointer.
- [non-blocking] **5.4's `builder.md` citation is off by 1-2 lines.** It cites `:34-36` for "the
  exit-report section" and the "report as a FILE" claim; the actual `## Exit report` heading is at
  `:35` and the single-paragraph content making that claim is at `:37` (confirmed via `grep -n`).
  Consistent with this plan's established pattern of small citation drift elsewhere (Rounds 1, 3, 4
  already carry similar nits); does not change what 5.4 item 2 must add or where.

### Open questions

None from this round's verification. The blocking finding is not an ambiguity needing the user's
judgment — the fix is a small, mechanical edit to one bullet's wording, not a design decision.

## Round 6 — 08-29-26

```
verdict: ready
next: proceed
blocking: 0
non-blocking: 0
```

Scope for this round, per the caller: verify commit `4bab265`'s fixes to Round 5's one blocking
finding and its four non-blocking nits, in Phase 4/Phase 5 only. Lanes l1–l4 (Phases 1–3, 13/23
ticked) were not re-reviewed, per instruction, and remain ticked and untouched by this commit
(confirmed: the syllabus's Phase 1–3 checkbox lines are byte-identical before and after `4bab265`).
Both structural gates pass: `validate-plan.sh` reports `OK: plan is structurally valid (23
subphases)`; `plan-lifecycle.sh check` reports `OK: plan dir conformant` — subphase count unchanged
from Round 5, as expected (this commit is a text fix, not a scope change).

`git diff 2182599 4bab265 -- plan.md` was read in full and every touched passage re-verified against
the real tree, not the commit message:

- **The blocking finding (out-of-scope bullet) is fixed.** `plan.md:180-187` now reads: "Any change
  to `report-verdict.sh`'s verdict/`next` vocabulary, to `validate-report.sh`, or to
  `verify-run-scope.sh`. **The one carve-out:** Amendment 4 puts `verify-scope.sh` in scope for
  exactly one behavior change — the uncommitted-worktree check and the committed-only comparison
  that replaces its four-way diff union (4.4, tested in 4.5, documented in 5.4, swept in 5.5).
  Nothing else in that script is in scope: `claims_from_report()` and the `--report` input mode are
  untouched, and `verify-run-scope.sh` — which shares that parser — is not modified at all." This
  resolves the exact contradiction Rounds 4 and 5 both raised: the bullet no longer forbids the file
  Phase 4 must touch, and it draws the carve-out narrowly (one behavior, not the whole script),
  consistent with what 4.4/4.5/5.4/5.5 actually do. Cross-checked against the real
  `orchestrators/hooks/verify-scope.sh` on disk: `claims_from_report()` (lines 36-93) and the
  `--report` argv handling (lines 95-117) are the parts the carve-out excludes, and the four-way diff
  union it targets is genuinely a separate, later block (`:119-122`) — the carve-out's boundary is
  drawn where the plan says it is, not just asserted.
- **Nit 1 (`docs/architecture.md:114-117` citation) is fixed.** Item 6 in 5.2 now says the range is
  "the whole edit" — middle-file list plus the "ten types across four pipeline values" count plus
  `map`'s own `ship: chat` sentence — and explicitly says there is NO `analyze` ship description to
  correct there, pointing instead at `:133`. Re-read `docs/architecture.md` directly: `:114-117` is
  exactly "request to ONE **type**, whose **pipeline** axis selects a middle file (... — ten types
  across four pipeline values). `map` (`pipeline: report`, `ship: chat`) defaults to answering in
  chat..." — no `analyze` sentence in range. `:133` is exactly "The planner-less publish types
  (`document`, `analyze`) skip straight to..." — matches the plan's new citation exactly.
- **Nit 2 (`orchestrators/AGENTS.md:115-117` labeling) is fixed.** Item 6 in 5.1 now reads "the
  `scope-writes.sh` clause of the 'Wired hooks' list, whose 'Wired hooks:' label sits one line
  earlier at `:114`" — re-read directly: `:114` is "Wired hooks: `workflow-diff-check.sh` ...", and
  `:115-117` is exactly the quoted `scope-writes.sh` clause, byte-exact. Fixed correctly.
- **Nit 3 (ask-of-record pointer undercount) is fixed.** The Goal & scope pointer now names all four
  amendments by section number and date, with a one-line rationale for the list ("the amendment list
  is part of the pointer, so a reader can tell which parts of the ask this plan delivers without
  re-deriving it"). `.artifacts/brief.md` was not independently re-read this round (out of the stated
  Phase 4/5 scope and not touched by this commit), but the pointer's own internal claims (Amendment 3
  → Phase 4, Amendment 4 → 4.4/4.5/5.4) match what Phase 4/5 actually contain.
- **Nit 4 (`builder.md` citation off by 1-2 lines) is fixed.** 5.4 item 2 now cites "`:35`, content at
  `:37`" instead of the old `:34-36`. Re-read `orchestrators/agents/builder.md` directly: `## Exit
  report` is the sole heading of that name, at line 35 exactly (`grep -n "^## Exit report"` returns
  one hit); its single content paragraph ("Your exit report is a FILE first...") is at line 37 (line
  36 is blank). Matches the new citation exactly.

No new defects introduced by this commit: the two whitespace-only column-alignment edits to the 4.4/
4.5 syllabus lines are cosmetic and don't change their `(after:)` edges or lane assignment. The suite
count updates ("12 → 13" everywhere it appears, plus the new `tests/verify-scope-clean.test.sh` in
4.5's file scope and 5.5's acceptance criteria) are internally consistent: 10 suites on disk today
(confirmed: `ls tests/*.test.sh` lists exactly 10) plus Phase 4's three new files
(`scope-writes.test.sh`, `parent-tree-guard.test.sh`, `verify-scope-clean.test.sh`) = 13, matching
every occurrence of the count in 5.2 and 5.5. `tests/verify-scope-parsing.test.sh` (5.5's other new
mention, "which covers the same script 4.4 changed") already exists on disk today, confirming it's
correctly described as part of the pre-existing 10, not a new file.

### Findings

None. All five of Round 5's findings (the one blocking, the four non-blocking) are confirmed fixed
against the real tree, and no new defect surfaced in this round's re-review of the changed passages.

### Open questions

None.
