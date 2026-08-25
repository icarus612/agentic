# dae-axes-restructure-08-23-26.plan-review

## Round 1 — 08-23-26

```
verdict: rejected
next: plan-wrong
blocking: 1
non-blocking: 1
```

### Findings

- [blocking] Syllabus/prose contradiction on the `after:` graph. Phase 1's own callout states *"Blocking dependency. Every lane's first subphase declares after: 1.1"* — but subphase **2.1** (`finalize` refuses without a passing `pr-review.md`, lane 1) carries only `(lane 1)` in the syllabus, with no `after:` clause at all (line 11). Lane 1 actually starts at two independent points — 2.1 and 3.1 — and only 3.1 (line 14) declares `after: 1.1`. `validate-plan.sh` doesn't catch this because it only checks that named `after:` targets exist and the graph is acyclic; it can't check a syllabus annotation against unstructured prose elsewhere in the file. As written, an orchestrator scheduling strictly off the syllabus could dispatch lane 1's builder (and 2.1's edit to `push-pr/SKILL.md`) before the Phase 1 baseline capture completes, which is exactly the ordering the plan's own risk section says must not happen ("1.1 blocks all six lanes rather than running alongside them"). Fix is one line: add `after: 1.1` to 2.1 in the syllabus (and confirm the Phase 2 detail block agrees). Everything else in the dependency graph checks out — I independently re-derived all six lanes' edges and 9.1's fan-in (`after: 2.2, 3.2, 4.3, 5.4, 6.1, 7.2, 8.2`) and confirmed it names every lane's actual terminal subphase(s), including lane 1's two branches; the graph is otherwise acyclic (confirmed by `validate-plan.sh`: "OK: plan is structurally valid (21 subphases)").

- [non-blocking] Stack table is stale by one commit. The table (line 72) says "plain bash fixture suites, three of them" and the shebang-scan line (line 68) says "16 scripts under `orchestrators/hooks/` + `tests/`". `tests/sync-install-settings-merge.test.sh` landed in commit `5644e79` ("fix(sync-install): merge settings.json instead of clobbering it"), the commit immediately preceding this plan in `git log`, which post-dates the fact-gathering. Current tree: 4 suites (`plan-lifecycle.test.sh`, `resolve-config-precedence.test.sh`, `sync-install-settings-merge.test.sh`, `verify-scope-parsing.test.sh`), 17 total `#!/usr/bin/env bash` scripts across both dirs (13 hooks + 4 tests). Purely informational — no subphase's acceptance criteria depends on the exact count, and the new suite is unrelated to this migration — but worth a one-line fix in the same revision pass since the planner is already going back in.

### Open questions

None — no UNCERTAIN claims remain; every load-bearing assertion I checked resolved to VERIFIED or WRONG (see body).

## Round 2 — 08-23-26

```
verdict: tentative
next: proceed
blocking: 0
non-blocking: 4
```

### Findings

- [non-blocking] Round 1's blocking `after:` finding is fixed correctly, and the invariant restatement is sound. Syllabus line 11 now reads `2.1: ... (lane 1, after: 1.1)`. I independently re-derived the eight-entry enumeration the new Phase 1 callout claims (line 102: "2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1, and 8.2") against all 21 syllabus lines: lane 1 has two `after: 1.1` entries (2.1, 3.1), lane 6 has two (8.1, 8.2), lanes 2/3/4/5 have exactly one each (4.1, 5.1, 6.1, 7.1) — 2+1+1+1+1+2 = 8, matching exactly. I then traced every remaining subphase's `after:` chain back to 1.1 (2.2→2.1→1.1; 3.2→3.1→1.1; 4.2→4.1→1.1→4.3→4.2; 5.2/5.3→5.1→1.1→5.4→5.3; 7.2→7.1→1.1; 9.1→{2.2,3.2,4.3,5.4,6.1,7.2,8.2}, all of which trace to 1.1; 9.2→9.1, 10.1→9.2, 10.2→10.1) and confirmed the restated invariant — "no lane subphase is reachable without 1.1" — is true of the whole table, not just the eight direct entries. No third entry point was missed and no subphase escapes the dependency.

- [non-blocking] Round 1's stale-count fix is correct but incomplete — a third instance survives. Both corrected counts check out against the tree at the current HEAD (`5644e79`): the Stack table (line 68/72) now says "17 scripts... 13 hooks + 4 suites" and "four of them," and §2.11 D3 (line 788) now says "the four suites already in `tests/`" with a dated correction note citing `5644e79`. I confirmed the tree independently: `find tests -name '*.test.sh'` → 4 files; `find orchestrators/hooks -maxdepth 1 -name '*.sh'` → 13 files; a shebang scan of both dirs → 17 `#!/usr/bin/env bash` scripts. Both are right. But the plan's own opening banner (line 3) and Design-reference preamble (line 320) claim only **one** stale suite count existed and was corrected ("one stale test-suite count in §2.11 D3... nothing else in it is altered") — and that claim is now false. §2.12 "What changed in rev 5," item 14 (line 810) still reads: *"`tests/` was never mentioned in the migration plan despite three existing suites and two new scripts needing coverage."* That "three" is the same stale fact, uncorrected, sitting in the same preserved Design-reference section as the two instances that were fixed. It carries no operative weight (no subphase's acceptance criteria depends on it, same as round 1's original finding), so this stays non-blocking, but the round-2 task specifically asked me to confirm no third instance remains, and one does — worth closing in the same pass since two of three sibling instances already were.

- [non-blocking] Confirmatory: the D2 explicit-naming vs. scalar-expansion boundary (the priority item) is correct and does not need a re-ask. I checked whether the planner's line — "explicit `<phase>:<value>` naming warns, step-2 scalar expansion drops silently" — reopens the row-default/user-typed distinction the user explicitly rejected. It does not: the user's rejected distinction keys on *where the value came from* (a row's own default vs. something the user typed on the CLI); the planner's boundary keys on *how the value entered the profile* (an explicit token vs. mechanical fan-out from a bare scalar), and treats CLI and row sources identically on both sides of that line — a user-typed `--rigor pr:high` and a hypothetical row cell `{pr: high}` both warn; a user-typed bare `--rigor high` and a row's bare `rigor: low` both expand silently. Concretely: I traced §2.1's *pre-existing* (not newly written) resolution algorithm — step 1 is "the type row's rigor profile," and the row-format note (line 464) already states a bare-scalar row "expands by the step-2 rule" — meaning a bare-scalar row's unmentioned phases were **never** "explicitly named" to begin with, under the base spec's own framing, before D2 was ever raised as a question. §2.11's original D2 write-up (line 782, pre-round-1) was scoped narrowly to *"an explicitly typed `--rigor <phase>:<value>`"* — i.e., D2 was only ever asking about the explicit-naming half; the scalar-expansion half's "always silent" behavior was settled by step 4's base wording and was never part of what the user was asked to decide. So the planner's boundary doesn't invent new policy, it applies the user's D2 answer only to the half of the space D2 actually covered, and leaves the other half exactly as the un-appealed base design already had it. I also confirmed the concrete stakes: without this line, a `dae map` run (row: `rigor: low`, pipeline `report`/`ship: chat`, only `explore` exists) would print three spurious stderr warnings about `plan`/`code`/`pr` on every single ordinary invocation — the scenario 4.2's own text calls out. The boundary is stated identically and unambiguously in both 4.2 (prose + the "all errors" carve-out) and D2's entry (line 289), and 4.3 has a dedicated test case for each side (explicit-named-absent warns+exit-0; scalar-expansion is silent+exit-0). I don't think this needs the user's ruling — it's a correct, narrow application of the D2 answer already given, not a new interpretive fork.

- [non-blocking] One genuine cross-reference the planner didn't touch, adjacent to D1: §2.4's run-shape diagram (line 603) states `document explore(deep,low)`, but §2.2's actual type table (line 506, verified) sets `document: {..., rigor: {explore: med}, ...}`. This directly touches D1's resolution, whose entire rationale (line 287, line 632) is that `document`'s missing gate is mitigated by running its explore at `rigor: med` (committee cross-checking, singleton re-verification) — if a reader builds from §2.4's diagram instead of §2.2's table, `document` would run at `low`, silently dropping the safety net D1's resolution depends on. This is pre-existing in the preserved rev-5 spec (not something either gate round touched, and not one of the three edits the file's own "preserved as written except for three round-1 edits" claim at line 320 accounts for), so it isn't a new defect from this revision pass. It is **not blocking**, because the operative acceptance criteria that actually govern implementation — subphase 4.1's detail block — anchors explicitly to "§2.2's table verbatim," not to §2.4's diagram (verified: 4.1's Pattern-to-follow and Acceptance-criteria both cite §2.2 by name). But it's a real internal inconsistency inside the design rationale for the exact decision this round was asked to scrutinize most closely, and it's the kind of thing a future reader could stumble on when reasoning about *why* D1 was safe to resolve as (a). Worth a one-line fix (`low` → `med` at line 603) in the same pass, or an explicit note that §2.4's diagram predates the D1 rigor cell and is stale on this one row.

- [informational, no count against non-blocking above] §2.11's D2 body paragraph (line 784) still carries the pre-resolution proposal text verbatim — *"Distinguish the two cases if this is adopted: a row default naming an absent phase always drops silently... only a user-typed override errors"* — the exact row-default/user-typed distinction, and the erroring alternative, that the user rejected. This is not a contradiction: the section's opening marker (line 762) states plainly that "the arguments below are kept as the reasoning behind those calls; the plan's decision-points section carries what was actually chosen," and the D2 heading itself carries the tag `(RESOLVED: warn and continue.)`. Per the plan's own stated precedence rule ("marker wins"), there's no ambiguity for a careful reader. I'm noting it only because a reader skimming the D2 argument paragraph in isolation, without registering the heading tag or the section preamble, could momentarily read it as live. This is stylistic, not substantive — I'm not counting it as a fifth non-blocking item, just flagging it as available polish if the planner is touching this section again for the two items above.

### Structural checks (re-run, verbatim)

```
$ bash agent-agnostic/skills/review-plan/scripts/validate-plan.sh project-plans/proposals/dae-axes-restructure-08-23-26.md
INFO: lane file-scope disjointness is not machine-checked — verify scopes in the detail blocks.
OK: plan is structurally valid (21 subphases)

$ bash orchestrators/hooks/plan-lifecycle.sh check
OK: plans dir layout is conformant
```

(`plan-lifecycle.sh check <path>` requires `<path>` to be a directory under the plans dir; this plan is still a proposal file, so the correct invocation — matching what `cmd_check` actually supports — is the no-argument full scan, run above from the plan's own worktree.)

### Open questions

None — no UNCERTAIN claims remain. All four D1/D2 follow-ups and both re-verified counts resolved to VERIFIED or WRONG; none are blocking, and none require a fresh user ruling (see the D2 boundary finding above for why that specific priority item doesn't need to go back to the human).
