# draft-pr-ship-flow-08-17-26.plan-review

## Round 1 — 08-17-26

```
verdict: rejected
next: needs-input
blocking: 1
non-blocking: 4
```

### Findings

- [blocking] `plan-lifecycle.sh check` (run against the plans dir root, `orchestrators/skills/dae/../../../` resolved as `project-plans/`) fails with two hits, both in `proposals/`:
  ```
  FAIL: unrecognized filename in proposals/: antigravity-integration-plan.md
  FAIL: unrecognized filename in proposals/: dual-engine-antigravity-08-10-26-sync-report.md
  ```
  Neither file matches the `<slug>-MM-DD-YY.md` or `<slug>-MM-DD-YY.<kind>.md` naming convention (`antigravity-integration-plan.md` has no date suffix at all; `dual-engine-antigravity-08-10-26-sync-report.md` uses a hyphen before `sync-report` where the convention requires a dot: `dual-engine-antigravity-08-10-26.sync-report.md`). These are pre-existing legacy files unrelated to this plan's own content — `draft-pr-ship-flow-08-17-26.md` itself passes every check — but per this skill's own instructions a pre-existing flat/legacy layout is explicitly NOT to be excused: "the correct outcome is a structural failure that forces a one-time migration." `validate-plan.sh` on the plan itself is clean (`OK: plan is structurally valid (14 subphases)`), so this is a plans-dir hygiene blocker, not a defect in the plan's own content. Recommend a one-time cleanup — rename each to the `<slug>-MM-DD-YY[.kind].md` convention or move/retire them — before this gate can pass cleanly.

- [non-blocking] `agent-agnostic/hooks/worktree-reminder.sh:49` (`push_msg`) currently reads: "...prefer the push-pr/review-pr skills over raw git/gh commands: they enforce push-policy (**two modes** by whether the repo has a dev branch — WITH dev, dev is the integration branch and main is off-limits except an authorized hotfix; WITHOUT dev, main is the integration branch, squash-merged locally and pushed — ...)". Verified against the actual `agent-agnostic/rules/push-policy.md`, which currently describes only ONE mode (dev is unconditionally "the universal integration branch" — no "WITHOUT dev" fallback exists in the rule as written today). This drift pre-dates the plan and isn't in the plan's own enumerated list of "pre-existing contradictions being fixed in flight" (which names `push-pr:13`, `cleanup-merged:13`, `docs/architecture.md:116`, and the `SKILL.md:72` stale citation, but not this one). Subphase 1.7's instruction — "Verify against the final 1.5 wording and adjust **only if 1.5 made it inaccurate**" — risks a builder reading the current text as an accurate baseline and leaving the "two modes" claim untouched, since it was already wrong before 1.5 touches anything. Recommend 1.7's acceptance criteria explicitly require reconciling `push_msg`'s "two modes" description against the actual (single-mode) `push-policy.md` content, independent of whatever 1.5 changes.

- [non-blocking] `orchestrators/hooks/branch-squash-guard.sh:346-365` — the plan cites this range as the block that "denies force-push, `git push` touching `main` in Mode A." Verified: the **force-push** denial is actually a separate, earlier, unconditional (all-modes) block at lines 334-345; `:346-365` is only the Mode-A "push touching main" denial. The underlying substantive claim (both denials exist and the new per-lane/per-stage pushes don't trip either) still holds — this is a citation-range imprecision, not a wrong conclusion, and doesn't change the plan's out-of-scope determination for this script.

- [non-blocking] `orchestrators/skills/dae/document.md` citations are close paraphrases rather than verbatim quotes: `:3` actually reads "No planner and no builders" (not "no planner and no plan gate" as the plan states — true in substance since there's no plan either, but not the literal wording), and `:9` actually reads "Pass the scope and an output path inside the parent worktree" (not "the explore map goes to the gitignored run dir" verbatim — consistent in substance with `explore`'s stated default of writing to the run dir when no output path is named, per `run-artifacts.md:30`, but not an exact quote). Neither affects DP2's framing or the acceptance criteria.

- [non-blocking] Cross-diagram consistency (informational, already covered by 3.1's own acceptance criteria): `orchestrators/AGENTS.md:44-63`'s pipeline diagram is not byte-identical to `docs/pipeline.md:11-27` (extra connector lines, different indentation), and `README.md:56`'s compressed diagram currently orders `push-pr` before `review-pr` (with a dashed-arrow annotation) where the other two diagrams sequence `review-pr` gate before `push-pr`. Subphase 3.1's acceptance criterion ("diff the three diagrams against each other for the same stage order") already catches this, so no plan change needed — flagging only so the reviewer of 3.1's output knows this divergence is real and pre-existing, not a lane 1/lane 2 wording-drift artifact.

### Open questions

Structural/process:
- How should the two legacy `proposals/` files be handled before this gate can pass — renamed to the naming convention, moved, or retired? This is a repo-hygiene decision outside this plan's stated scope but blocking its structural check.

The plan's own decision points (DP1-DP8, `## Risks, open questions, decision points`) are all genuinely unresolved and load-bearing for the subphase content as written — none should be treated as already-decided by the plan's "default" language unless the human explicitly confirms it:
- **DP1 (push-authorization cadence)** — (A)/(B)/(C) changes the exact wording 1.5 and 2.1/2.3 must write; "not decided" per the plan itself.
- **DP2 (where `document` opens its draft PR)** — changes subphase 2.5's content materially depending on (A) vs (B).
- **DP3 (degenerate runs: sync / none-picked diagnose)** — affects whether 2.4's `sync.md`/no-pick `diagnose.md` treatment opens a PR at all.
- **DP4 (mechanism for the per-lane push)** — the highest-impact open question: the plan's whole Phase 2 lane scope and subphase count is written assuming option (A) (`push-pr --stage update`). If (B) is chosen (a new `push-branch.sh` script), the plan states this itself: "Phase 2 gains a script subphase and the lane scopes shift" — i.e. a structural revision, not just wording.
- **DP5 (declined/impossible `open-draft`)** — has a proposed default in the plan; needs explicit confirmation, not silent adoption.
- **DP6 (commit record output before the PR gate)** — an explicit behavior change riding along in the rework; the plan is correct to flag this needs its own sign-off separate from the mechanical rework.
- **DP7 (CI status at the PR gate)** — default is "not included"; confirm the default stands.
- **DP8 (keep the name `push-pr`)** — default is "keep the name"; confirm the default stands.

None of these require re-exploration (`map-wrong`) — the plan's own verified facts are sound — but the plan cannot be promoted and dispatched until a human has actually chosen among DP1-DP4 (which affect subphase content/lane scope) and confirmed the stated defaults for DP5-DP8.

## Round 2 — 08-17-26

```
verdict: ready
next: proceed
blocking: 0
non-blocking: 1
```

### Findings

- [non-blocking] Trivial line-citation drift (1-3 lines) on several multi-line-range citations, none affecting any acceptance criterion's substance: `orchestrators/AGENTS.md` diagram cited as `:55-62` (the specific quoted fragment is actually at `:58-62`, full diagram spans `:44-63`); `docs/pipeline.md` diagram cited as `:24-27` (actual `:24-28`); `agent-agnostic/AGENTS.md` skill-index table cited as `:44-51` (actual table spans `:42-52`); `orchestrators/hooks/branch-squash-guard.sh`'s commit-on-integration-branch denial cited as `:379-398` (actual `:379-397`) and the `gh pr merge --squash` denial cited as `:426-434` (actual `:426-436`). None of these change which text the acceptance criteria point at; no action needed.

### Open questions

None. Every load-bearing claim in Phase 1, Phase 2, and Phase 3 was independently re-verified against the actual files in this run (not re-trusted from round 1 or from the plan's own citations) — every `file:line` citation, every verbatim quote, the `gh` 2.4.0 version and its `--draft`/`pr ready --undo` flag behavior, the `agent-specific/claude/settings.json` `permissions.ask`/`allow` claim, `plan-lifecycle.sh`'s "never commits" claim, `verify-run-scope.sh:106`'s corrected citation, and the three test scripts' non-involvement in the ship flow. Zero WRONG findings. Lane 1 (`agent-agnostic/...`) and lane 2 (`orchestrators/skills/dae/...`) file scopes are genuinely disjoint by directory, matched 1:1 against their subphases' individual file-scope lines, and neither lane's subphases actually need to read the other's edited output — both draw the pinned publish-contract table directly from the plan text, so there is no hidden `(after:)` edge the syllabus is missing. `validate-plan.sh` and `plan-lifecycle.sh check` both pass clean (the round-1 blocking legacy-filename issue is resolved — the `proposals/` dir no longer contains the two non-conforming files). All eight decision points (D1-D8) read as genuinely settled, each with a stated reason and a subphase mapping, not smuggled defaults. Recommend: promote and dispatch.
