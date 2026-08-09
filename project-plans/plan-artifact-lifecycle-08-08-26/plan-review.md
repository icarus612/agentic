# plan-artifact-lifecycle-08-08-26.plan-review

## Round 1 — 08-08-26

```
verdict: rejected
next: plan-wrong
blocking: 1
non-blocking: 5
```

### Structural check

`validate-plan.sh` output, verbatim:

```
INFO: lane file-scope disjointness is not machine-checked — verify scopes in the detail blocks.
OK: plan is structurally valid (13 subphases)
```

### Parallelizability audit

Lane scopes verified disjoint by opening every named file: lane 1 = `generic/rules/` (3 files), lane 2 = `orchestrators/hooks/plan-lifecycle.sh` (new) + `tests/` (new) + `generic/skills/{review-plan,cleanup-merged}/SKILL.md`, lane 3 = `orchestrators/agents/planner*` + `orchestrators/skills/dae/` (6 files), lane 4 = six other `generic/skills/` SKILL.md files. No file appears in two lanes. Shared touchpoints (`generic/AGENTS.md`, `orchestrators/AGENTS.md`, root `README.md`/`AGENTS.md`) are correctly hoisted into serialized 5.1 with `after:` edges on all ten prior subphases. Intra-lane `after:` edges (1.2/1.3 after 1.1; 2.2/2.3 after 2.1) are real dependencies (they cite the layout/CLI the earlier subphase defines). No hidden cross-lane edge found: lanes 2–4 write prose from the plan's own "scheme this rework installs" section, not from lane 1's output file.

### Verified claims (all confirmed by opening the files)

- `plan-format.md:8,10` quotes exact; `:29-53` fenced examples, `:55` Living document, `:57` no-time-estimates, `:59` closing line — all as cited.
- `artifact-locations.md:14` quoted in full and exact; `:15,:16` are the worktrees/base-branch bullets; `:31` closing prohibition present.
- `run-artifacts.md:9,:11,:13` quotes exact; the script-enforcement half of `:13` is real (`report-verdict.sh`, `validate-report.sh` enums confirmed in the scripts).
- `validate-plan.sh`, `validate-report.sh`, `report-verdict.sh`, `mark-syllabus.sh` need no changes: all four take the plan/report path as an argument and assume nothing about its directory or filename (read end to end).
- `verify-run-scope.sh:43` is exactly the cited resolve call including the `2>/dev/null || echo /project-plans/` fallback, and the allowlist is prefix-matched (line 83), so the whole resolved plans dir — including new subdirs — is allowed; the "no script change needed" claim holds. `scope-writes.sh` (unmentioned by the plan) is likewise prefix-based via `CLAUDE_SCOPE_ALLOW`, so the nested layout needs no change there either.
- `sync-install.sh:74-83` `install_path()` as cited: any `orchestrators/hooks/*` file maps to `hooks/<file>`; a repo-root `tests/` matches no case arm and is never installed.
- `explore/SKILL.md:27` does write a map to the workflows dir — run-artifacts' "exactly two places" is currently contradicted, as 1.3 claims; `:66` quote exact.
- `cleanup-merged/SKILL.md:31` quoted in full and exact; `:13,:37,:41` as cited. `proposals/` appears in `generic/ orchestrators/ tool-based/` source ONLY at cleanup-merged:31, confirming 1.1's "one negative mention" root-defect claim.
- All lane-3/lane-4 cited lines exact: `planner.md:3,13`, revision-loop wording; `plan-diagnosis.md:3`; `plan-reconcile.md:3`; dae `SKILL.md:58,68,69,70,72`; `build.md:9,11`; `diagnose.md:9,11`; `sync.md:7,9`; `confluence-mode.md:18`; `worktree-modes.md:11`; `review-code:23,27,34`; `review-pr:27,28`; `comment-pr:23`; `document-local:29,31,39`; `push-pr:27,40`; review-plan source `:17,23,27,28,35,39,41,50` (source diff-identical to the install).
- Index/docs cites exact: `generic/AGENTS.md:25,27,28,46-48,52`; `orchestrators/AGENTS.md:29,103`; `README.md:31`/`AGENTS.md:13` tree lines; `docs/conventions.md:126,163,171,181`; `docs/pipeline.md:78,98` (the hand-off line list is complete — an independent grep of `docs/` found no further stale lines).
- `master-redesign-07-26-26.md:682` quote exact; the two `completed/` files match `<slug>-MM-DD-YY.md`; `proposals/.gitkeep` exists.

### Findings

- [blocking] Missed surface outside the sweep's reach: `tool-based/confluence/skills/document-confluence/SKILL.md:28` names "the plan path in `/project-plans/`" and "`<slug>-MM-DD-YY.story.md` next to the plan", and `:30` "a sibling story file next to the plan" — old-scheme wording in a file no subphase enumerates, violating the plan's own scope statement ("EVERY skill file whose wording names a plan path [or] a record filename"). Worse, 5.3's sweep runs only over `generic/ orchestrators/` plus root `README.md`/`AGENTS.md`, so this file survives the run untouched: a Confluence-mode run would be told to find a story file at a path the new layout makes impossible — exactly the R1 failure the plan calls "worse than no change" (R1's "derived from the actual repo-wide grep" mitigation claim is therefore inaccurate: the sweep is not repo-wide). Fix: add the file to a subphase (4.2 or a new lane-4 item; it shares no file with other lanes) AND extend 5.3's sweep scope to `tool-based/`.
- [non-blocking] `orchestrators/agents/builder.md:7` — "an approved plan path (in `/project-plans/`, or `CLAUDE_PROJECT_PLANS_DIR` if set)" is old-scheme wording not enumerated in 3.1 (whose scope is planner files only, though the phase header says lane 3 owns `orchestrators/agents/`). 5.3's `/project-plans/` pattern would catch it, but the 5.3 inventory cross-check ("every file named in a phase-1-through-4 subphase must appear in a post-edit grep") cannot prove an un-named file was edited — enumerate it explicitly in 3.1.
- [non-blocking] `orchestrators/skills/dae/build-dispatch.md:24` — "the plan path (or diagnosis report path)" goes stale once a diagnose run's report IS `plan.md`; none of 5.3's six patterns matches this phrasing, so it would survive. Add it to 3.2's file scope (build-dispatch.md is currently absent from it).
- [non-blocking] Archive-guard gap in 2.1: the completeness guard refuses only on remaining `- [ ]` checkboxes, but `mark-syllabus.sh` also writes `- [dropped]` ("closed without shipping"). A plan whose every subphase was dropped has no `- [ ]` left and archives cleanly into `completed/` — a nothing-shipped plan in the dir the plan defines as "shipped, and nothing else" (the exact mythic failure mode). 2.1 should state how an all-dropped (or zero-`[x]`/`[done]`) syllabus is treated, or say why it is out of guard scope.
- [non-blocking] Stack-table evidence imprecise: `find . -name '*test*'` also returns `orchestrators/agents/contract-tester.md` and `tool-based/svelte/rules/component-testing.md`, not only the three items the table cites. The conclusion (no test framework exists in this repo) still holds — none of the hits is a framework.
- [non-blocking] Two citation slips: 1.3's "add a THIRD bullet to the run-dir section (after `:21`)" — that section already has three bullets (`run-artifacts.md:19-21`), the addition is a fourth; and the "No jq dependency" comment sits at `resolve-config.sh:22-23`, not `:24-25`. Neither changes any conclusion.

### Open questions

- D1–D5 and A1–A3 are the plan's own designed gate decisions and are well-posed; none blocked verification. Note for the gate: D1 (whether `superseded/` exists) gates 1.1's proposed wording, 2.1's `supersede` subcommand, 2.3, and 5.2, and D3(b) would contradict the "rest of the dir is removed" sentence already baked into 1.1's proposed text and the scheme block — if D3 resolves to (b), those two places must be amended, which the plan (unlike its D1 note) does not currently say.

## Round 2 — 08-08-26

```
verdict: tentative
next: proceed
blocking: 0
non-blocking: 2
```

### Structural check

`validate-plan.sh` output, verbatim:

```
INFO: lane file-scope disjointness is not machine-checked — verify scopes in the detail blocks.
OK: plan is structurally valid (14 subphases)
```

(14 subphases, up from 13 — the new 4.3 is wired into the syllabus, 5.1's `after:` list, and 5.3's edges.)

### Round-1 findings — resolution audit

- **Blocker (document-confluence missed surface): RESOLVED.** New subphase 4.3 enumerates `tool-based/confluence/skills/document-confluence/SKILL.md` as its sole file scope; its quotes of `:28` ("the plan path in `/project-plans/`, the story file path (`<slug>-MM-DD-YY.story.md` next to the plan…") and `:30` ("…a sibling story file next to the plan") are verbatim-exact against the file. The optional-story/mandatory-key/needs-input text 4.3 orders preserved is really at `:30`. AND 5.3's sweep now runs over `generic/ orchestrators/ tool-based/` plus root `README.md`/`AGENTS.md`; the Goal & scope section and R1's mitigation text were both amended to match (R1 now correctly states the sweep alone is not a safety net and names the two enumeration-only surfaces).
- **Non-blocker a (builder.md:7): RESOLVED.** `orchestrators/agents/builder.md` is now in 3.1's file scope with the `:7` sentence quoted exactly ("You receive an approved plan path (in `/project-plans/`, or `CLAUDE_PROJECT_PLANS_DIR` if set)"), plus the never-moves-a-plan corollary tied to the real never-edits constraint at `build-dispatch.md:24`.
- **Non-blocker b (build-dispatch.md:24): RESOLVED.** `build-dispatch.md` is now in 3.2's file scope; the "(or diagnosis report path)" quote is exact at `:24`, the fix is stated, and 5.3 explicitly lists it as one of the two enumeration-only (ungreppable) surfaces. The `:16` `mark-syllabus.sh <plan>` stays-correct claim verified.
- **Non-blocker c (all-dropped archive gap): RESOLVED.** 2.1's completeness guard now has two halves (unfinished AND nothing-shipped), citing `mark-syllabus.sh:14` — verified exact: "dropped  - [ ] -> [dropped]  (closed without shipping)" — and `:31-37` for the writable states (verified: the case arm writes x/done/dropped/space). The checkbox-free diagnose-plan skip is stated with a rationale, acceptance criterion 2b covers all-dropped-refuses / one-[x]-archives, and the fixture list includes an all-dropped plan and a checkbox-free plan.
- **Citation slip 1 (run-artifacts bullet count): RESOLVED.** 1.3 now says "fourth bullet (after `:21`; that section's existing bullets are `:19-21`)" — verified: the run-dir section has exactly three bullets at `run-artifacts.md:19-21`.
- **Citation slip 2 (resolve-config jq comment): HALF-RESOLVED.** Conventions item 2 now cites `resolve-config.sh:22-23` (correct — the comment spans `:22-25`, starting at `:22`), but the Stack table row still says "its comment at `:24-25`". Residual, cosmetic — see findings.
- **Stack-table find imprecision: PARTIALLY RESOLVED.** The table now enumerates five hits, but a live `find . -name '*test*'` (excluding `.git/`) returns SIX: the five listed plus `tool-based/svelte/skills/write-component-test` (a skill dir). The conclusion — no test framework, no test suite in this repo — still holds; none of the six is a framework. See findings.

### Parallelizability re-audit (post-amendment)

Lane scopes re-verified disjoint after the additions: `builder.md` and `build-dispatch.md` appear only in lane 3 (3.1 and 3.2 respectively); `document-confluence/SKILL.md` appears only in 4.3 and is the sole `tool-based/` file in any lane; lane 2's `review-plan`/`cleanup-merged` scopes are unchanged and explicitly excluded from lane 4's header. Shared touchpoints remain hoisted into serialized 5.1, whose `after:` list now includes 4.3. No file in two lanes; no new hidden edge (4.3 writes from the plan's own scheme section, like the rest of lanes 2–4).

### New/changed content spot-checks

- 4.3's "skipped entirely by `sync-install.sh`" framing is consistent with `source-push-sync.md:3` (tool-based content installs into consuming projects, not `~/.claude`), already verified round 1 via `install_path()`.
- 4.3's executor note about a stale `sync-status` orchestrator is accurate: `sync-status` appears in source only inside `document-confluence/SKILL.md` itself (`:19`, `:30`); no such orchestrator exists. Note: `:19` is a second occurrence the note doesn't cite — immaterial, since the note's instruction is to leave both alone and surface the staleness in the exit report.
- 2.1's guard cites and the `--force-incomplete` audit-trail design check out against `mark-syllabus.sh`; the script-never-commits precedent at `mark-syllabus.sh:43-47` verified (mutation + print, no git).
- `resolve-config.sh:1,30` (shebang, `set -uo pipefail`) verified exact.

### Findings

- [non-blocking] Stack-table row 2 still cites the "No jq dependency" comment at `resolve-config.sh:24-25`; it starts at `:22` (the comment spans `:22-25`, and the quoted words sit on `:22`). Conventions item 2's `:22-23` is right; the table row was left behind. Changes no conclusion — fix opportunistically in the next amendment, not worth a round.
- [non-blocking] Stack-table row 4's `find . -name '*test*'` enumeration says five hits; the live command returns six — `tool-based/svelte/skills/write-component-test` is missing from the list. The row's conclusion (no test framework exists in this repo) is unaffected: the sixth hit is a skill directory, not a framework or suite.

### Open questions

- None new. D1–D5 and A1–A3 stand as the plan's designed gate decisions, unchanged from round 1 and well-posed. Round 1's gate note still applies: if D3 resolves to (b), 1.1's "The rest of the dir is removed" sentence and the scheme block's `archive` line must be amended — the plan still records this consequence only for D1, not D3.
