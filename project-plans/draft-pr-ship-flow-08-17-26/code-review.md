# code-review

## Round 1 — 08-18-26

```
verdict: ready
next: proceed
blocking: 0
non-blocking: 1
```

### Method

Read the full plan (`plan.md`, all 336 lines, including the pinned publish-contract table and the D1–D8 decisions). Read every file in the 23-file diff (`git diff main...feature/draft-pr-ship-flow`) directly — not the exit reports as proof — for all three lanes: l1 (`push-pr`, `review-pr`, `comment-pr`, `cleanup-merged`, `push-policy.md`, `run-artifacts.md`, `worktree-reminder.sh`), l2 (`dae/SKILL.md`, `build.md`, `build-dispatch.md`, `diagnose.md`, `sync.md`, `document.md`, `worktree-modes.md`), l3 (`orchestrators/AGENTS.md`, `docs/pipeline.md`, `README.md`, `docs/architecture.md`, `agent-agnostic/AGENTS.md`). Ran independently: the three bash test suites (51/51 pass, matching the claimed count exactly — 20+11+20), `bash -n` on `worktree-reminder.sh` (clean), the full 10-phrase retired-vocabulary sweep repo-wide excluding `project-plans/` (zero hits), the `open-draft`/`--stage` cross-file grep (consistent spelling everywhere), a frontmatter-byte-diff check on all four edited `SKILL.md` files (only `description:` and body changed), `verify-run-scope.sh` against the full run (`OK: all 23 changed files claimed by 3 exit report(s) or harness-owned`), and `sync-install.sh --check` from the actual main checkout (confirms the claimed reason for running it there: the script hard-refuses inside any linked worktree). Verified two specific facts the plan leans on: `verify-run-scope.sh:106` is indeed the `CLAUDE_PROJECT_PLANS_DIR` resolution line (the plan's citation fix is correct), and `agent-specific/claude/settings.json` has `Bash(git:*)` in `allow` but `Bash(git push:*)` in `ask` (the D1 residual-risk claim is accurate). Cross-checked the three ASCII pipeline diagrams (`orchestrators/AGENTS.md`, `docs/pipeline.md`, `README.md`) against `dae/SKILL.md`'s finished `## Shared stages` section for stage order and wording. Confirmed the plan's declared out-of-scope files (`push-main/SKILL.md`, `branch-squash-guard.sh`, `verify-run-scope.sh`, `scope-writes.sh`, `settings.json`, the three test scripts) do not appear in the diff.

### Findings

- [non-blocking] `.artifacts/progress-log.md` is stale relative to the actual state: it still shows lane l3 as "DISPATCHED, in flight" and the PR gate as "0 rounds," while the plan's syllabus has all 14 subphases ticked, the integration pass (tests + `verify-run-scope.sh`) is done, and this code-review round is now complete. Not a defect in any shipped file — the log is gitignored, run-scoped bookkeeping, not part of the diff being reviewed — but the `run-artifacts` rule this same plan edited requires it be "rewritten in place at every state change," and a resumed session would reconstruct a wrong picture from it right now. Update it (lane l3 merged, code gate round 1 = ready) before the run proceeds to the PR gate.

### Verification highlights

- All eight D1–D8 decisions are implemented exactly as pinned, verbatim across both lanes: stage names (`open-draft`/`update`/`finalize`), the D1 confirmation cadence (conversational confirm at `open-draft`/`finalize` only, none at `update`), D4 (`push-pr --stage update` as the sole per-lane push mechanism, no direct `git push`, no helper script), D5 (declined/impossible `open-draft` degrades and retries once at the next `update`), D6 (record output committed+pushed before the PR gate, with the `git diff <base>...<branch>` reasoning stated), D7 (no CI-status addition — `review-pr`'s existing PR-mode CI mention is untouched), D8 (`push-pr` keeps its name).
- The retired-vocabulary deletion is complete and clean: zero hits outside `project-plans/` for all ten banned phrases (`push-pr --draft`, "Terminal ship stage", "NEVER mid-workflow", "publish anyway", "publish-as-draft", "draft-publish", "tears down the worktree", "remove the worktree so the workflows dir", `verify-run-scope.sh:43`, "standing permission policy", "two modes"). `docs/architecture.md` no longer calls the PR gate optional, verified by direct read of the new hand-off-graph bullet.
- Pre-existing contradictions the plan called out as fixed-in-flight are genuinely fixed: `push-pr`'s old "publish and remove the worktree" self-contradiction, `cleanup-merged`'s "touches nothing remote" claim, `worktree-reminder.sh`'s "two modes" misdescription of the (actually single-mode) `push-policy.md` rule, `SKILL.md`'s stale `verify-run-scope.sh:43` citation (now `:106`, verified against the real file), and `diagnose.md`'s "the worktree is torn down" claim.
- The three ASCII diagrams (`orchestrators/AGENTS.md`, `docs/pipeline.md`, `README.md`) agree with each other and with `dae/SKILL.md`'s finished Shared-stages prose on stage order and wording — no drift between the lane-1 contract and the lane-2/lane-3 callers, which the plan flagged as the specific failure mode most likely for a prose-only rework.
- Explicitly-out-of-scope files (`push-main/SKILL.md`, `branch-squash-guard.sh`, `verify-run-scope.sh`, `scope-writes.sh`, `agent-specific/claude/settings.json`, the three bash test scripts) are untouched, confirmed both by the diff stat and by the plan's own reasoning for each still holding on inspection.
- The one accepted deviation (`sync-install.sh --check` could not run in-worktree; evidence gathered from the main checkout instead) is a genuine, documented tool precondition (`sync-install.sh:56,90` — "Run from the repo root, on main, not inside a linked worktree"), not a shortcut; independently reproduced with the same result (STALE settings.json — pre-existing, unrelated live-grant drift — clean otherwise).

### Open questions

(none — all D1–D8 decisions were settled at the plan gate and every subphase implements them without deviation; the one non-blocking finding above is a process note, not a question blocking this verdict)

## Round 2 — 08-18-26

```
verdict: rejected
next: impl-wrong
blocking: 2
non-blocking: 0
```

### Method

Read the amended plan (`plan.md`, amendment A1 section and its changed specs for 1.1/2.3/3.1). Read lane l4's exit report and independently verified every claim in it against the real diff: `git show 147e34a --stat` (confirms exactly the three files A1's commit touched: `push-pr/SKILL.md`, `build-dispatch.md`, `docs/pipeline.md`) and `git diff main...feature/draft-pr-ship-flow` for the same three files, read in full. Confirmed the three-outcome vocabulary (succeeded / failed-or-declined / publishing impossible) is defined once in `push-pr/SKILL.md`'s new "The three push outcomes" subsection and referenced consistently by `update`'s and `finalize`'s return contracts, and that `build-dispatch.md`'s per-lane event list now reads verify → merge → tick → progress log → push (`push-pr --stage update`, no confirmation, D5 retry point named) → cleanup (three-way branch on push outcome, deferred-cleanup tracking, retry-on-later-success, surface-at-run-end) → re-scan, matching the amendment's required order exactly. Confirmed frontmatter on `push-pr/SKILL.md` was untouched by the A1 commit (the `description:` change visible in the full main-diff predates A1, from lane l1's original work — verified via `git show 147e34a -- agent-agnostic/skills/push-pr/SKILL.md`).

Then swept, per this round's brief, every file that states the lane sequence or `push-pr`'s return contract, including files l4 did not touch: `orchestrators/skills/dae/SKILL.md` (router prose — `grep -n` for worktree/cleanup/push-pr/outcome), `orchestrators/AGENTS.md`, `docs/architecture.md`, `agent-agnostic/AGENTS.md`, `README.md`, `docs/conventions.md`, root `AGENTS.md`. Ran a repo-wide grep for the pre-A1 phrasing pattern (`merge-back.*cleanup`, `cleanup.*push-pr`) and a separate grep for push-outcome vocabulary (`succeeded`, `declined`, `push outcome`) across all `.md` files outside `project-plans/`, to catch both a stale event order and any surviving two-state return language.

### Findings

- [blocking] `orchestrators/AGENTS.md:52-54` — the dae-pipeline ASCII diagram still states the pre-A1 order: "builder lanes (event-driven dispatch, child worktree each, merge-back+cleanup + push-pr --stage update per lane)". This lists cleanup before the push, directly contradicting the amended `build-dispatch.md` (verify → merge → tick → progress-log → **push** → **cleanup** → re-scan) and the now-corrected `docs/pipeline.md`, which states the same diagram box as "merge-back + push-pr --stage update + cleanup per lane" (push before cleanup). This file is inside subphase 3.1's file scope, and the amendment note explicitly lists 3.1 as A1-affected precisely because prose restating the per-lane sequence would "silently contradict the amended build-dispatch.md if left alone" — that reasoning applies here exactly as it did to `docs/pipeline.md`, but this file wasn't touched by l4 (its exit report's "Files touched" for the 3.1 slice lists only `docs/pipeline.md`). Fix: reorder to push-before-cleanup, matching `docs/pipeline.md`'s corrected wording.
- [blocking] `docs/architecture.md:116` — the same contradiction, same root cause: "merge-back + cleanup + `push-pr --stage update` per lane) → `review-code`" states cleanup before push, in the same file l4 was supposed to have swept (3.1's scope) but didn't touch. This directly contradicts `build-dispatch.md`'s amended event order and `docs/pipeline.md`'s corrected diagram/prose. Fix: reorder to push-before-cleanup.

Both findings are the same defect (subphase 3.1's A1 rework was scoped by the l4 builder to only `docs/pipeline.md` — the one file the amendment note named by example — rather than to the full 3.1 file scope the amendment note's own reasoning covers). No other file in the sweep carries the stale order or stale two-state push vocabulary: `orchestrators/skills/dae/SKILL.md`'s router prose doesn't restate the per-lane cleanup/push ordering at all (that's `build-dispatch.md`'s job, correctly not duplicated); `agent-agnostic/AGENTS.md`'s `push-pr` index row describes the three stages and their confirmation cadence without asserting lane-cleanup order; `README.md`'s compressed diagram omits cleanup from the per-lane summary entirely (no contradiction, just abbreviated, consistent with its "compressed variant" role); `docs/conventions.md` and root `AGENTS.md` don't restate the sequence. A repo-wide grep for `succeeded`/`declined`/`push outcome`/"two outcomes" found no surviving two-state return language outside the three files A1 correctly touched.

### Open questions

(none — the fix is mechanical: reorder the two diagram/prose fragments to push-before-cleanup, matching the wording `docs/pipeline.md` already carries)

## Round 3 — 08-18-26

```
verdict: ready
next: proceed
blocking: 0
non-blocking: 0
```

### Method

Read lane l5's exit report and commit `584af99` (`git show 584af99 --stat` and full diff) — confirms exactly the two files the round-2 findings named: `docs/architecture.md` (1 hunk, 1 insertion/1 deletion) and `orchestrators/AGENTS.md` (1 hunk, 2 insertions/2 deletions), nothing else touched. Read both files' current full context directly (not the diff alone): `docs/architecture.md:105-122` and `orchestrators/AGENTS.md:40-60`. Read `orchestrators/skills/dae/build-dispatch.md`'s per-lane event list (steps 1-7, specifically step 5's push and step 6's amendment-A1 cleanup-after-push branch) and `docs/pipeline.md`'s corresponding diagram/prose (lines 20-21, 80-92) to check both fixed fragments against the authoritative source. Ran a repo-wide sweep for the stale pattern (`grep -rn "merge-back+cleanup\|merge-back + cleanup\|cleanup + \`push-pr\|cleanup +push-pr" --include=*.md .`, excluding `project-plans/`) — zero hits. Ran `verify-run-scope.sh` against the full run (`OK: all 24 changed files claimed by 5 exit report(s) or harness-owned`), confirming l5's two files are accounted for and no unclaimed diff exists anywhere in the branch.

### Findings

Both round-2 blocking findings are resolved:

- `orchestrators/AGENTS.md:52-54` now reads "child worktree each, merge-back + / push-pr --stage update + cleanup per lane) " — push-before-cleanup, matching `docs/pipeline.md`'s wording byte-for-byte on the two-line diagram box and `build-dispatch.md`'s amended event order (verify → merge → tick → progress log → push → cleanup → re-scan).
- `docs/architecture.md:116` now reads "merge-back + `push-pr --stage update` + cleanup per lane) → `review-code`" — same order, same wording pattern as the other two files.

No regressions: the surrounding prose in both files (the rest of the `dae` hand-off-graph bullet in `docs/architecture.md:108-122`, the rest of the ASCII pipeline diagram in `orchestrators/AGENTS.md:40-73` including the `push-pr --stage open-draft`/`finalize` stages and the `review-pr` mandatory-gate wording added in round 1/2) is unchanged and still consistent with `build-dispatch.md` and `docs/pipeline.md`. No stale cleanup-before-push phrasing survives anywhere in the repo outside `project-plans/`.

### Open questions

(none)
