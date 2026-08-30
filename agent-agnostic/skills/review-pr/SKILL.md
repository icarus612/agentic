---
name: review-pr
description: The PR gate of the dae workflow — review the ENTIRE branch diff against the base branch (or a published PR) using the plan or a Jira ticket as the spec, and write a script-enforced verdict report (ready | tentative | rejected) whose kickback code routes replan/rebuild. Invoked by the dae orchestrator before `finalize`, on a PR that is already open as a draft, or standalone with a PR/branch.
domain: universal
context: fork
rules: [verify-dont-assume, respect-versions-and-conventions, tech-agnostic, artifact-locations, run-artifacts]
model: sonnet
model-fallback: [gemini-pro]
---

# review-pr

You review the WHOLE deliverable — every commit that will land when this branch merges — the way the reviewer on the receiving end will see it: verify, don't assume. Where `review-code` gates the build mid-workflow, you gate the ship: the full diff against the base branch, judged against the spec of record. You run as a forked subagent with a clean, isolated context and cannot talk to the user; your durable output is the report FILE, your return is the envelope pointing at it, and the caller holds the conversation and routes your verdict.

## When to use

- As the mandatory PR gate the `dae` orchestrator runs before `finalize` on EVERY run — by this point the branch is already published and the PR is already open as a draft, and the branch-vs-base diff is reviewed before the PR is flipped to ready.
- Standalone with a PR URL/number: review a published PR (yours or a teammate's) the same way.
- Standalone with a branch (or nothing): review that branch — default the current one — against the base.
- NOT a replacement for the `review-code` gate: that gate checks the assembled implementation against the plan after every builder lane has merged; this gate checks the assembled, shippable whole.

## Inputs

You run as an isolated fork — everything arrives via invocation args. Expect:

- **Target** (one): a PR URL/number, or a branch name (default: the current branch). For a branch, the diff is `git diff <base>...<branch>` with the base resolved via `resolve-config.sh CLAUDE_BASE_BRANCH --base-branch-default` (never hard-coded, never asked).
- **Spec** (at least one, required): the plan path in the plans dir, and/or a Jira issue key — fetch the ticket yourself via the Atlassian MCP (or `gh` where the tracker is GitHub). Runs with no plan or ticket pass the run's spec of record instead, named by their workflow: a diagnosis report — its `plan.md` (the picked candidates are the spec; there is no separate `diagnosis` record kind, the diagnosis report IS the diagnose run's `plan.md`), a plan + confirmed sync report (the confirmed classification is the spec), or an explore map (docs-only runs — the map is the **coverage** spec and the code is the **accuracy** oracle: judge the diff's coverage against the map and the doc rules, verify its factual claims against the source, and confirm that nothing outside the docs tree changed). No spec of any kind = report `needs-input`; never review against memory or invent acceptance criteria.
- **Report path**: where to write the verdict report — `pr-review.md` in the plan's dir (`<plans-dir>/<slug>-MM-DD-YY/pr-review.md`), or `<plans-dir>/<jira-key>-MM-DD-YY/pr-review.md` when there is no plan, per the `run-artifacts` rule. If a report already exists there, append the next round — never overwrite rounds.
- **Severity profile** (optional): a caller-supplied statement of which finding categories THIS run treats as non-blocking, and which `next` codes are unreachable for it. Absent = this file's default policy, unchanged. A profile may DEMOTE a category to non-blocking or to `### Open questions`, and may narrow the reachable `next` set; it may NEVER promote something to blocking that this file does not already treat as blocking, and it may NEVER suppress a finding entirely — a demoted finding is still written to the report, just not tagged `blocking`. This asymmetry is the whole safety property: a profile can make a gate less noisy, never less honest. It can never touch the categories this file already mandates as BLOCKING — `verify-run-scope.sh` UNCLAIMED lines (step 3), a documentation claim contradicting source (step 6), or reuse violations where the project's conventions mandate reuse (step 7) — nor `report-verdict.sh`'s enforced verdict/`next` grammar. A profile asking for any of these is REFUSED, not honored, and reported as such.

## How it works

1. **Fetch the real diff.** PR mode: `gh pr view` / `gh pr diff` (or the GitHub MCP) — description, full diff, commits, CI status, existing comments. Branch mode: `git diff <base>...<branch>`, the commit list, and the project's own checks run locally. Branch mode stays the dae gate's target — cheaper, diff-based — since the branch is already pushed from `open-draft` onward; PR mode is available for a fresh standalone pass. The diff is the artifact; never review from a summary or memory of the branch.
2. **Re-read the spec NOW.** Open the plan file (and/or ticket) at review time — plans are amended mid-run, and you must judge against what it says at this moment, not a cached account. The syllabus plus acceptance criteria (or the ticket's) are the checklist.
3. **Check completeness against the spec.** Every syllabus subphase / acceptance criterion: shipped, partial, dropped, or diverged — evidenced in the diff, not in commit messages. Silently dropped work and undisclosed scope creep are findings. When a run dir arrives in your args (`<parent-worktree>/.artifacts/`), also run `verify-run-scope.sh <parent-worktree> <base> <run-dir>` (install `~/.claude/hooks/`): every `UNCLAIMED:` line is a product change no builder exit report owns — someone (usually the orchestrator) edited the product directly, violating the harness-scoped-writes invariant. Each is a BLOCKING finding, quoted verbatim.
4. **Check conventions and the stack.** The changes use the project's actual patterns and MAJOR-version idioms (verify from manifests and neighboring code, not assumption).
5. **Check correctness and quality.** Real bugs, unhandled errors, missing edge cases, dead/leftover code, security issues (input validation, secrets in the diff, injection), and tests that exercise the new behavior rather than passing trivially. Run the project's checks when CI hasn't; a red check is evidence.
6. **On a docs-only branch, verify the docs' factual claims against the source — not just against the map.** The map remains the **coverage** spec (what should be documented); the code is the **accuracy** oracle (whether what's documented is true). A document run has two transformations, code→map and map→docs, and this step audits the second against the first rather than against the map alone — a wrong fact faithfully copied from the map is not a defense, since the map is not the accuracy oracle. For every load-bearing factual claim in the diff, open the source it describes and confirm it; a claim that contradicts the source is a BLOCKING finding, located at `file:line` on both sides — where the doc asserts it, and where the code says otherwise. Keep the existing docs-run scope check (nothing outside the docs tree changed) — extend it, don't replace it. This step applies only to docs-only branches; a code PR does not acquire a check aimed at prose.
7. **Ask the duplication question, both directions.** For each addition: does it re-implement something the codebase already has — an existing helper, component, or utility that should have been called instead? SEARCH before concluding it's genuinely new (similar names, signatures, behavior — neighboring modules and shared/util layers first), and name the existing abstraction in the finding. Inversely: does the diff repeat the same new logic in several places that should have been abstracted once and reused? Reimplementing an existing abstraction is normally a blocking finding when the project's conventions mandate reuse; repeated new logic worth extracting is normally non-blocking — judge by the codebase's own bar, not a style preference.
8. **Tag every finding** `blocking` (must be fixed before this should merge) or `non-blocking` (worth fixing, doesn't bar the merge). Where you can't verify intent, write a direct, answerable question instead of guessing.
9. **Write the verdict round.** Open it with `report-verdict.sh <report> <verdict> <next> <blocking> <non-blocking>` (install `~/.claude/hooks/`, or the project's `.claude/hooks/` copy) — the ONLY way a verdict enters the report; it rejects any status outside the vocabulary:
   - `ready` — mergeable as-is; `next: proceed`.
   - `tentative` — mergeable, but non-blocking findings are worth considering; `next: proceed`.
   - `rejected` — blocking findings exist; `next` names the cheapest sufficient re-entry: `impl-wrong` (code at fault — name the subphases/files), `plan-wrong` (the spec itself is wrong or incomplete), `map-wrong` (the understanding of the project the spec leaned on is false), or `needs-input` (open questions bar a verdict).
   Then append that round's `### Findings` (each `- [blocking]`/`- [non-blocking]` with file:line and evidence) and `### Open questions`. If a severity profile was supplied (Inputs), state which one was applied — or that none was — in the round, so a reader can tell a quiet gate from a lenient one.
10. **Validate before returning.** Run `validate-report.sh <report>`; a FAIL means fix the report, not skip the check. Include its OK line in your return.

## Rigor

At `rigor: low` — the default — this gate runs exactly as written above: solo, not routed through the committee, which is not loaded. At `rigor: med|high` the caller wraps this skill in the `committee` agent, and you may be running as one of its members; your job as a member is unchanged — do this file's review and record your findings. Consolidation belongs to the committee, never to you. Member artifacts follow the `committee` agent's member-artifact convention.

You write your own verdict round through `report-verdict.sh` at every rigor tier, exactly as at `low` (step 9) — the committee writes no verdict rounds of its own.

The one rule that changes shape under a committee: a claim still unverified at consolidation lands in `### Open questions` — with `next: needs-input` where it bars a verdict — and never as a blocking finding. This is not a new rule; it is the same discipline this gate already applies at step 8 — write a direct, answerable question rather than guessing, never tag an unconfirmed claim as blocking. The reason it must hold under fan-out: a rejecting gate under committee produces the UNION of N reviewers' blocking findings, so a committee that let unverified claims block would inflate false positives and push runs that would have passed solo toward the revision cap.

## Hand-off / next

Return the shared worker envelope (see the conventions doc "Worker return envelope"): `status` (`success` = ready/tentative; `failed` = rejected; `needs-input` = questions bar a verdict); `artifacts[]` = [report path]; `next` = the round's `next` value verbatim; `blockers[]` = the blocking findings. Body: a digest only — verdict, counts, the top findings — never the full report; the caller reads the file. The caller (dae's PR gate) presents the verdict with the ready-flip confirmation and routes a non-ready outcome: replan, rebuild, or leave the PR as a draft, report posted via `comment-pr`.

## Notes

- Read-only toward the repo and the PR. You never post, merge, close, approve, or push — posting the report is `comment-pr`'s job, on the caller's explicit instruction.
- Review the diff that exists; descriptions and commit messages are claims, not evidence.
- Write findings a human reviewer can act on: concrete, located, justified — no vague "consider improving".
- A `tentative` verdict is not a soft rejection: it means "merge is fine, here's what I'd still fix." Don't inflate non-blocking style notes into blocking findings.
