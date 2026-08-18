---
name: comment-pr
description: Post a review-pr verdict report to GitHub as a PR comment — render the report file through the contract script and publish it with confirmation. Part of the dae workflow, invoked by the dae orchestrator after review-pr at any verdict, on the PR already open, or standalone with a report path and PR; never reviews anything itself.
domain: universal
context: fork
rules: [verify-dont-assume, push-policy, artifact-locations, run-artifacts]
model: sonnet
model-fallback: [gemini-pro]
---

# comment-pr

You publish a verdict that already exists. The `review-pr` skill wrote a report file; you render it into a GitHub comment and post it. You never re-review, never edit the report's substance, and never form your own opinion of the PR — if the report is missing or malformed, that's a `review-pr` problem to send back, not a gap for you to fill.

## When to use

- By the `dae` orchestrator's PR gate to post the verdict report at any outcome (`ready`, `tentative`, or `rejected`) — whether the PR stays a draft is the caller's separate decision, made at the PR gate, not something this skill's posting triggers.
- Standalone: post any existing `pr-review.md` report to its PR.
- NEVER to write a review comment from scratch — no report file, no comment.

## Inputs

You run as an isolated fork — everything arrives via invocation args. Expect: the report path (`<plan-dir>/pr-review.md`), the PR URL/number (and repo if not the current one), and confirmation from the caller that posting was explicitly approved by the user.

## How it works

1. **Validate the report.** Run `validate-report.sh <report>` (install `~/.claude/hooks/`, or the project's `.claude/hooks/` copy). A FAIL stops you cold: return `failed` naming the FAIL lines — the fix belongs to `review-pr`.
2. **Render the comment.** `scripts/render-pr-comment.sh <report>` (ships with this skill, next to this file) turns the LAST round into the comment body: a verdict badge line, the finding counts, the findings table, and open questions. Use its output verbatim as the body — the rendering is the contract; don't hand-write a variant.
3. **Confirm, then post.** Posting to a PR is outward-facing: it rides on the explicit user approval your args assert (and the permission prompt). Post as a single PR comment via `gh pr comment <pr> --body-file <rendered>` or the GitHub MCP. If a previous comment from an earlier round exists, post the new round as a new comment — the PR thread is the history; never edit or delete earlier ones.
4. **Never go further.** No merging, closing, approving, requesting changes, or review-state changes — a comment is the entire footprint.

## Hand-off / next

Return the shared worker envelope (see the conventions doc "Worker return envelope"): `status`; `artifacts[]` = [report path]; `next` = done; `blockers[]`. Body: the comment URL, the verdict posted, and nothing else. A declined post (permission denied at the prompt) is a valid outcome — report it with the exact command to post later, don't retry.

## Notes

- The report file is the single source of the comment's content; if it reads wrong, the report is wrong — kick back, don't patch in flight.
- One comment per verdict round; never spam rounds the PR already carries.
- The `push-pr` skill's `finalize` stage links the report path in the PR body; your comment is the readable rendering of it.
