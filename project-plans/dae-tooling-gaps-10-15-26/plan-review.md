# dae-tooling-gaps-10-15-26.plan-review

## Round 1 — 10-16-26

```
verdict: tentative
next: proceed
blocking: 0
non-blocking: 6
```

### Findings

- [non-blocking] Ask diff, defect 2: the plan's cause correction is right. In `lane-artifact-shell-guard.sh`, `is_target()` (:44-47) pattern-matches the token as written, `TARGET` (:36) needs a literal `.artifacts/` component, and `VAR_TARGET` (:42) only applies when the token has `$` or `~`. The guard never reads the payload `cwd` or any other cwd (no `cwd` reference in the script). The plan picks option A, tracking the in-command cwd. That is one of the two fixes the ask offers, and adding the payload-cwd seed widens it without inverting it. Not a divergence.
- [non-blocking] Ask diff, defect 1: `dae/build.md:27` already says "ready/tentative", so leaving it unedited is correct. The ready-only statements that need changing are `push-pr/SKILL.md:54, 60, 63` and `dae/SKILL.md:148`. A repo-wide grep over `agent-agnostic` and `docs` finds no others. `docs/architecture.md:143` and `validate-report.sh:16` state the vocabulary or the routing, which is already correct.
- [non-blocking] Case count in 1.3: the plan lists 6 bypass rows plus 4 extra denies plus 6 allows, which is 16 cases, but labels them `11a-11o`, which is 15. A cosmetic miscount; the builder should label by the real count.
- [non-blocking] Portability: Conventions says new shell must be bash-3.2/BSD-safe, but 2.4 relies on `realpath -m`, which BSD/macOS `realpath` lacks. `verify-run-scope.sh:46-47` and `smart-test.sh:23` already use it, so this follows existing practice. Consider noting that it is an existing assumption rather than claiming BSD safety.
- [non-blocking] 2.3 payload-cwd rows (last two denies in 1.3) depend on unverified assumption A3. Treehouse progress-log line 60 says the builder's session cwd stays in the parent worktree. That makes the in-command `cd` rows the ones that matter in practice; the payload-cwd rows are harmless extras.
- [non-blocking] Process-leak cause (A1, A2) is inference, as the plan admits. The code facts check out. `smart-test.sh` has bare `$(...)` runner substitutions at the cited lines. The source-file branch checks `package.json` in `$PWD` (:711). The owning-package walk (:606-619) covers only the test-file branch. The treehouse root `test` script is `turbo test`. 3.3 includes an optional measurement. Acceptable.

### Open questions

- None blocking. DP-1 through DP-6 are the human gate's choices. The recommended options (A for DP-1, DP-2, DP-5 and DP-6) are consistent with the ask.

### Verified

- `validate-plan.sh`: OK (13 subphases). `plan-lifecycle.sh check project-plans`: OK, layout conformant. The script's usage text shows `check` takes a directory, so a file path is rejected.
- Baseline `bash tests/lane-artifact-shell-guard.test.sh` gives `78 passed, 0 failed`, as the plan states.
- Line claims verified in the worktree:
  - `push-pr/SKILL.md:54, 58-61, 63`, and `dae/SKILL.md:148`.
  - `build-dispatch.md:15`.
  - `verify-run-scope.sh:116-126` and `:156-166`.
  - `smart-test.sh:20, 114, 150, 196-217, 606-619, 711` and the runner sites.
  - `validate-report.sh:84` prints `verdict <v>, next <n>`.
  - `tests/push-pr-gate-refusal.test.sh` case 06 (:303-308, :371-372) and text-2 (:395-404).
  - `verify-scope.sh:6` synopsis.
  - `docs/pipeline.md` mentions at ~191-192 and ~217-224.
- Treehouse evidence: 4 mode-120000 README symlinks exist. The root `test` script is `turbo test`. Progress-log lines 21, 30, 48, 50, 51 and 60 say what the plan cites.
- Lanes: file scopes are disjoint across the four lanes. The two `smart-test.sh` overlaps with the agent-identity proposal are in separate hunks and suites.
- No time estimates in the plan.
