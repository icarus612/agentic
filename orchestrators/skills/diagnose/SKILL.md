---
name: diagnose
description: Entry-point orchestrator for root-cause investigation — diffs the suspect work, explores deep, and produces a RANKED candidate-cause report graded by likelihood × ease-of-fix/test, gates on your pick, then drives only the chosen fixes through builders → review-code → push-pr. Targets a live branch or already-merged work; the issue can be a freeform description, a /project-plans/ plan, or a Jira ticket. Invoke as /diagnose. Not for building new features (that is /dev) or reconciling shipped work against its plan/ticket (that is /sync-status).
domain: universal
rules: [verify-dont-assume, respect-versions-and-conventions, model-policy, artifact-locations, push-policy]
model: opus
model-fallback: [sonnet, gemini-pro]
hooks:
  Stop:
    - matcher: ""
      hooks:
        - type: command
          # global install path; point at the project's .claude/hooks/ copy instead for a project-specific install
          command: "~/.claude/hooks/workflow-diff-check.sh"
---

# diagnose

You are a small orchestrator for root-cause investigation. Something is wrong — a bug, a regression, unexpected behavior, a stack trace — and the fix is NOT yet obvious. Your job is to localize it cheaply, investigate it rigorously, and produce a **ranked report of candidate causes** graded on two axes — how *likely* each is the real cause and how *easy* it is to fix and verify — then, only for the candidate(s) the user picks at a human gate, drive the fix through the same `builder` → `review-code` → `push-pr` machinery `dev` uses. The ranked report is the deliverable, not a phased plan. You reuse `sync-status`/`map`'s worktree/push-pr scaffolding and `dev`'s fix loop. You investigate before you touch code, and you never guess a cause you can't back with evidence.

## When to use

- A bug or regression whose ROOT CAUSE is genuinely unclear — you need to investigate before you can plan a fix, especially for ambiguous or abstract issues with several plausible suspects.
- The suspect work is a live branch, an open PR, a commit range, OR already merged to the base branch — `diagnose` reads history read-only to localize it, then fixes in an isolated worktree.
- The issue arrives as a freeform description, a stack trace, a `/project-plans/` plan whose behavior diverged, or a Jira ticket (fetched via the Atlassian MCP when connected).
- NOT for building a new feature or a change whose shape is already understood — that is the `dev` workflow (which plans first, then builds).
- NOT for reconciling already-shipped work against its plan/ticket when nothing is broken — that is `sync-status`.
- If the cause is already obvious and only the fix remains, skip straight to `dev` (or a single `builder`); `diagnose` earns its keep only when the investigation is the hard part.

## Invocation args

`/diagnose` accepts an optional `--explore <deep|shallow|auto>` flag (alias `--exp`) overriding the exploration mode for step 3. Parse it out of the invocation text before starting. **The default is DEEP** — bug-hunting needs real code paths, not doc summaries — so pass DEEP to `explore` unless the caller overrode it. `--ref <branch|pr|range>` may name the suspect work up front (otherwise resolve it in step 0). Absent flags change nothing.

## How it works

1. **Confirm scope and truth sources** (conversational — you are the main orchestrator, not a fork, so gather everything a fork couldn't ask for here, before setting anything up):
   - **The issue.** Capture it precisely: a freeform description/stack trace VERBATIM, or a plan path (`/project-plans/<slug>-MM-DD-YY.md`, dir resolved via `~/.claude/hooks/resolve-config.sh CLAUDE_PROJECT_PLANS_DIR --default /project-plans/`), or a Jira key (fetch the ticket yourself via the Atlassian MCP when connected — you are not a fork, you can call MCP tools directly; if the MCP isn't connected, take the issue text conversationally). At least one issue source is required — never invent one.
   - **The suspect work to diff** (unless `--ref` supplied): a branch name, a PR URL/number, an explicit commit range, or "already merged to the base branch" (ask for enough to locate it — a date range, PR number, or a slug to `git log --grep` for). ALWAYS ask; never guess this from the issue text alone.
   - Resolve the base branch SILENTLY in step 2 via `CLAUDE_BASE_BRANCH` (per `artifact-locations`) — never ask it conversationally; only surface it if resolution genuinely fails.

2. **Set up the workflow worktree.** Run `~/.claude/hooks/workflow-setup.sh --reuse --type bug --name diagnose-<slug>` via Bash (global install path; use the project's `.claude/hooks/` copy if installed project-specific) — `diagnose-<slug>` on a first run, `rediagnose-<slug>` if a prior diagnose branch for this slug already exists. Derive `<slug>` from the issue (or the plan/ticket). The branch is `bug/diagnose-<slug>` (or `bug/rediagnose-<slug>`). Don't pass `--base`: the script resolves `CLAUDE_BASE_BRANCH` itself (per `artifact-locations`, NEVER from CLAUDE.md prose); pass it only to override for this run, and if the script reports it can't resolve a base, surface that and ask. `cd` into the printed WORKTREE path — all subsequent phases run inside it; the worktree carries the full repo history, so the suspect reference from step 1 is reachable from inside it even when that work already merged elsewhere. Everything up to the human gate is read-only investigation; the worktree isolates any throwaway probes and holds the eventual fix in one place.

3. **Diff first (cheap), explore only if needed.** Inside the worktree, compute the real diff between the resolved base branch and the suspect reference — `git diff <base>...<ref>`, or `git log`/`git diff` over the given range; for "already merged," locate the merge/commits first (`git log --grep`, PR number, date range) then diff those. **Read it yourself** — this is the primary, low-cost localization and is frequently enough to form hypotheses on its own. Escalate to the **`explore`** skill (invoke it directly via the Skill tool — it is a `context: fork` skill; NEVER wrap it in an Agent-tool spawn) ONLY when the diff plus the issue don't localize the suspect area — e.g. the bug spans code the diff doesn't touch, or you can't answer *where does this behavior live* from the diff alone. Pass the suspect paths (plus any area the issue implicates) as the scope, and pass **DEEP** as the mode (per "Invocation args" — override only if the caller did). Collect its map as supporting evidence; keep the full file dumps out of your context.

4. **Investigate and rank the candidate causes.** Form candidate root-cause hypotheses, applying the **same discipline as the `debug` skill**: *reproduce* the failure deterministically where you can (capture exact command, input, observed-vs-expected); *locate* the cause by tracing real data/control flow, not assuming; back every hypothesis with evidence (a log, a narrowed test, a temporary probe you REVERT before moving on); diagnose the cause, not the symptom. You do NOT write any fix here — this phase only produces diagnoses. For an ambiguous bug with several plausible suspects, **fan out**: spawn one investigation subagent per suspect area via the Agent tool, all in a single message so they run concurrently (cap 5; general-purpose subagents applying the discipline above), each returning a STRUCTURED hypothesis — `{ root-cause claim, evidence (paths/hunks/repro), minimal proposed fix, files it would touch, self-rated likelihood, self-rated ease }`. For a simple, localized bug, investigate inline instead of spawning. Then **dedupe and rank** every surviving candidate on two axes:
   - **Likelihood** — how strongly the evidence supports this being the ACTUAL cause (High / Med / Low). An unverified guess is Low, however plausible it sounds.
   - **Ease** — how easy the fix is to implement AND verify (High / Med / Low), factoring blast radius, test surface, and convention fit.
   Order by likelihood first, ease as the tie-break; the naturally-first pick is a likely-and-easy candidate, but present the full ranking and let the human decide. Mark anything you could not verify as an open question rather than asserting it.

5. **Write the diagnosis report.** Write `<slug>-MM-DD-YY.diagnosis.md` in the resolved plans dir, inside the worktree — a persisted pointer artifact, the same pattern `sync-status` uses for its sync-report; this file, not a raw payload, is what the fix phase and `review-code` reference. Sections:
   - **Scope & Sources** — the issue (verbatim / plan path / Jira key), base branch, suspect reference, worktree/branch.
   - **Reproduction** — the exact way to trigger it, or an honest note that it couldn't be reproduced.
   - **Ranked Candidates** — a table: candidate → likelihood → ease → evidence (paths/hunks) → proposed fix → files it touches. This is the heart of the report.
   - **Diff Summary** — files touched by the suspect work, notable hunks.
   - **Open Questions / Unverified** — anything you couldn't prove.

6. **Human gate.** Present the ranked report and let the user pick which candidate(s) to pursue — one, several, or none. This is the review-plan analog: it is the human's call which cause to chase, and confidently chasing the wrong one is worse than asking. If they approve NONE (the report itself was the deliverable, or every candidate needs more information), skip to step 9 to preserve the report and stop — do not invent work.

7. **Fix — direct from the report** (only the approved candidate(s)). Each approved candidate IS a builder task: its report entry is the spec, its cited files are the file scope. No phased plan is generated. Schedule like `dev` does:
   - **Group candidates into lanes** by DISJOINT file scope, and into waves by any ordering dependency between them. Independent candidates with non-overlapping files run concurrently.
   - **Per wave, spawn one `builder` subagent per lane via the Agent tool — all in a SINGLE message** (cap 5 per wave; general-purpose if `builder` isn't installed). Each builder's prompt: the diagnosis report path, the candidate ID(s) it owns (its report entry replaces the plan-subphase detail block builders normally read), its file scope (the union of its candidates' cited files), the hard scope rule — never touch files outside that scope; sibling builders may own them mid-flight — and the rule that it must NOT edit the report file (you own it; parallel writers would clobber it). The builder runs the `code` → `debug` → `test` loop inline until the `test` skill declares a clean terminal success, then reports the candidate IDs fixed, files touched, and what `test` actually verified.
   - **After each wave:** tick the fixed candidate(s) in the report yourself, verify each builder stayed inside its file scope (compare reported files against git), run the project's checks on the wave's changed files, then dispatch the next wave. A blocker, scope violation, or failed check stops the schedule — resolve before continuing.
   - **After the final wave:** run one integration pass — the full test suite plus a check that the reproduction from step 5 no longer triggers the bug.
   Enforce the loop rules exactly inside every builder: the **`code`** skill NEVER exits on its own; the **`debug`** skill diagnoses and hands off but never breaks the loop; the **`test`** skill is the ONLY loop-breaker.

8. **Code review.** Invoke the **`review-code`** skill directly via the Skill tool — a `context: fork` skill. Pass the diagnosis report path (the spec of record, in place of a plan) and the build summary as args. It returns a structured verdict; present it to the user, collect approve/revise, and from here loop back to ANY earlier phase (fix, investigation, or explore) if something is off — re-invoke that skill yourself with the corrections as args. Repeat until clean.

9. **Finish (& tear down).** Invoke the **`push-pr`** skill directly via the Skill tool — a `context: fork` skill. Pass the worktree path, the branch name, the base branch, a short summary for the PR (the confirmed cause and what the fix changed — or, on a no-fix run, that this publishes the diagnosis report only), and confirmation the run is done. It commits the diagnosis report and any fix, pushes the branch, opens a PR against the base branch (always asking first — `git push`/PR creation may be permission-blocked or declined, a valid reported outcome), and removes the worktree. Running `push-pr` even on a no-fix run is what preserves the report (it lives in the worktree, which teardown removes); if the user wants no PR at all, they decline the push at its prompt and you note the report path. `diagnose` is NOT done until `push-pr` reports.

10. **Report.** Surface the ranked-candidate table, which candidate(s) were fixed and what `test` verified, the `review-code` verdict, and `push-pr`'s outcome together. If investigation stalled — no candidate reached a confident likelihood — say so plainly and list what evidence is still missing, rather than shipping a low-confidence fix to make the report tidy.

## Context management

- **Default yourself to Opus.** You are the coordinator; protect your context window.
- **Pass pointers, not payloads.** `explore`, the investigation subagents, `review-code`, and `push-pr` are forks/subagents with no access to this conversation — hand them file paths (diagnosis report, plan, suspect ref) and short summaries, never raw diff dumps or full explore maps inline.
- **The diagnosis report (step 5) IS the pointer artifact** carried from your investigation into the fix, review, and publish phases — write it once, reference its path afterward. You own it; builders never edit it, and you tick candidates off it yourself.
- **Forked skills self-manage their model** via their own frontmatter. Invoke them directly via the Skill tool; NEVER wrap a forked skill in an Agent-tool spawn. The code/debug/test loop is the exception: it runs inline inside the `builder` subagents you spawn via the Agent tool.
- **Surface only what matters:** blockers, the ranked report at the gate, and concise completion summaries. Keep raw tool output OUT of your context.

## Hand-off / next

- `diagnose` runs scope intake, worktree setup, then: **diff** → (**`explore`** DEEP, only if the diff doesn't localize it) → **investigate & rank** → **diagnosis report** → **human gate** → **`builder`** fix loop (only approved candidates) → **`review-code`** → **`push-pr`**.
- Loop-back points: the human gate → stop (no fix) or fix; `review-code` → any earlier phase. Resume forward after each loop.
- The run ends after **`push-pr`** has published the branch (or reported it declined) and torn down the worktree. If the real work turns out to be a new feature or a large redesign rather than a targeted fix, stop and recommend the `dev` workflow instead of forcing it through the fix loop.

## Notes

- Tech-stack agnostic: investigate against what the repo actually uses; never assume a stack.
- Diff before you explore, and explore before you fix — cheapest evidence first. A confidently-wrong root cause is worse than an honest "not yet isolated."
- Every candidate's likelihood must be earned with evidence (paths, hunks, a repro). An unverified hypothesis is Low likelihood no matter how plausible it reads.
- You do no coding yourself and write no fix during investigation — durable edits come only from the `code` skill inside builders; investigation probes are throwaway and reverted, exactly as the `debug` skill requires.
- The base branch and docs/plans locations come only from `CLAUDE_BASE_BRANCH`/`CLAUDE_PROJECT_PLANS_DIR` (per `artifact-locations`, via `resolve-config.sh`) — never asked conversationally, never CLAUDE.md prose.
- Never push from `diagnose` itself — only `push-pr` publishes, and it always asks first, never force-pushes, never pushes main.
- A skill-scoped `Stop` hook runs `workflow-diff-check.sh` while `diagnose` is active: it git-diffs the worktree and runs the project's checks on the changed files, blocking the stop until they pass. Hook failures are BLOCKING — fix them immediately, then continue.
