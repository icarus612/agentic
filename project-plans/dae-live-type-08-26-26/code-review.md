# code-review

## Round 1 — 08-29-26

```
verdict: ready
next: proceed
blocking: 0
non-blocking: 3
```

### Method

Reviewed each of the 6 merged lanes against its plan subphases and against real command
output — not against the exit reports' self-claims, which were checked afterward and found
consistent. Ran `resolve-type.sh` directly against every acceptance-criteria case in 1.1/2.1/3.1/3.2
(byte-exact block comparisons, warn/error/precedence cases, alias resolution); ran all 13
`tests/*.test.sh` suites for real (`169 passed` in `resolve-type.test.sh` alone; all others green);
read every changed file in full and diffed against `main`; ran `verify-run-scope.sh` over the whole
worktree (`OK: all 27 changed files claimed by 6 exit report(s) or harness-owned`, no `UNCLAIMED:`
lines); confirmed `bash -n` on all four touched hooks and JSON validity on `settings.json`; confirmed
`CLAUDE_SCOPE_ALLOW` is gone repo-wide and neither new hook is wired into the live `~/.claude/settings.json`
(sync has correctly not run early); confirmed Convention 14's deferral mechanically
(`git diff --name-only main...HEAD` contains none of `worktree-modes.md`, `build.md`,
`workflow-setup.sh`, `tests/workflow-setup-reuse.test.sh`).

### Findings

- [non-blocking] `orchestrators/skills/dae/live.md` is 85 lines against `report.md`'s 49 (`build.md`
  is 29) — plan subphase 3.3's "Pattern to follow" states an explicit length target: "comparable to
  `report.md`, not longer." The extra length is accounted for by content the plan's own "What to
  build" section explicitly mandates (5 full stages, the `asks/` capture mechanics, the severity-profile
  Notes), not padding, and 3.3's Acceptance Criteria never restate the length target as a checkable
  bar — but the stated target was still missed and is worth a maintainer's eye if the file grows
  further.
- [non-blocking] `docs/pipeline.md`'s wired-hooks list (~:178) describes `parent-tree-guard.sh` as
  wired only on `PostToolUse Bash`, omitting the `Stop` matcher it is also wired on (confirmed in
  `agent-specific/claude/settings.json` and stated correctly in `orchestrators/AGENTS.md`'s fuller
  entry). Not factually wrong — 5.2 item 8 explicitly sanctions this file's "terser register" — but
  it under-describes the actual wiring where a reader might expect parity with `AGENTS.md`.
- [non-blocking] `orchestrators/agents/planner/plan-live.md` is 14 lines against sibling modules'
  8–9 (`plan-feature.md`, `plan-bugfix.md`, `plan-rework.md`). 3.5's "Pattern to follow" describes
  "four to six tight bullets" as the sibling shape, but the file correctly contains all ten bullets
  3.5's own "What to build" enumerates — the length follows from mandated content, not scope creep.

### Open questions

None. Every acceptance criterion in the plan's 27 subphases (across Phases 1–5) was independently
verified against running code, not inferred from the exit reports.
