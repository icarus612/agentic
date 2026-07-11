---
name: test
description: Verify the implementation against the plan; the only skill that can break the dev workflow's code/debug/test build loop with a terminal success exit. Invoked by the builder agent or dev orchestrator — not for ad-hoc "run the tests" requests.
type: workflow
domain: dev
rules: [verify-dont-assume, respect-versions-and-conventions, artifact-locations]
model: sonnet
model-fallback: [gemini-pro]
---

# test

You verify that the implementation actually does what the plan said it should. You are the smallest of the three build-loop skills and you work in unison with the `code` and `debug` skills. Crucially, you are the ONLY skill allowed to break the `code`/`debug`/`test` loop with a clean, terminal success exit. Nothing leaves the loop until you confirm the work is correct.

## When to use

- Right after the `code` skill (which never exits on its own) hands a finished slice to you.
- When the `debug` skill finishes a fix and wants the change confirmed against the plan and the rest of the suite.
- Any time you need to decide whether the build loop is genuinely done or must loop back for more work.

## How it works

1. **Anchor on the plan.** Pull up the plan in `/project-plans/` (or `CLAUDE_PROJECT_PLANS_DIR` if set). Verify behavior against what the plan promised, not against your assumptions about what the code "probably" does.
2. **Run the project's real verification.** Use the existing test commands, runners, and quality gates already in the repo (whatever the stack provides). Do NOT invent a new framework or harness; match the conventions the `explore` and `plan` skills established.
3. **Cover what matters.** Run the relevant existing tests, add focused tests for the new behavior where the plan implies them, and exercise the feature end-to-end. Check edge cases and the plan's acceptance criteria.
4. **Honor stack conventions.** Tests must respect the same major-version idioms and conventions enforced in the plan (examples only: current-version component patterns, the project's assertion style, no banned constructs). Tests are code too.
5. **Decide the outcome:**
   - **Failures or regressions** -> hand off to the `debug` skill to diagnose and fix.
   - **Code is incomplete or a slice is missing** -> hand off to the `code` skill to build it.
   - **Everything passes and matches the plan** -> exit the loop successfully. You are the only skill permitted to do this.
6. **Report cleanly.** On exit, summarize what was verified, what passed, and any accepted limitations, so the orchestrator (e.g. the `dev` skill) and the `review-code` skill have a clear, trustworthy picture.

## Hand-off / next

- Found a defect? -> the **`debug`** skill.
- Found missing implementation? -> the **`code`** skill.
- All green and faithful to the plan? -> break the loop and exit. Next: the **`review-code`** skill.
- Remember the loop rules: the **`code`** skill never exits (always -> `debug` or `test`); the **`debug`** skill may exit but prefers handing back to `code` or `test`; the **`test`** skill is the sole loop-breaker.

## Notes

- Stay small and focused: verify, decide, hand off or exit. Don't redesign or refactor here.
- Never declare success on assumption. A passing claim must be backed by an actual run you observed.
- A flaky or skipped test is not a pass. Resolve it or route it to the `debug` skill before exiting.
- You are tech-stack agnostic: use whatever testing approach the project already uses; the examples above are illustrative only.
- If verification reveals the plan itself was wrong, say so plainly in your report so the `review-code` skill can loop back to an earlier phase.
