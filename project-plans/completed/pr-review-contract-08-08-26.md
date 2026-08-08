# PR-review contract, run artifacts & cleanup — findings and work record

Executed in one session on 08-08-26 (audit requested 08-07-26); all subphases shipped. This file is both the plan of record and the findings writeup the run was asked for.

## Phase syllabus
- [x] Phase 1: Audit
  - [x] 1.1: Classify every dae hand-off as file-based or context-only
- [x] Phase 2: Contract machinery
  - [x] 2.1: run-artifacts rule
  - [x] 2.2: report-verdict.sh + validate-report.sh
- [x] Phase 3: The PR gate
  - [x] 3.1: review-pr rebuilt as the mandatory pre-push gate
  - [x] 3.2: comment-pr skill + render script
  - [x] 3.3: dae ship-stage wiring
- [x] Phase 4: Retrofit
  - [x] 4.1: Gate verdicts persisted to report files
  - [x] 4.2: Builder contract + exit report on disk
  - [x] 4.3: dae progress log + live plan amendments
- [x] Phase 5: Cleanup
  - [x] 5.1: cleanup-merged skill
  - [x] 5.2: This repo's stale leftovers
- [x] Phase 6: Docs & indexes
  - [x] 6.1: conventions/pipeline/AGENTS pages updated

## Goal & scope

**In:** a machine-enforced review contract (`ready | tentative | rejected`) for reviewing an ENTIRE PR/branch against a project plan or Jira ticket; a skill that posts that verdict to GitHub; dae integration routing a failed verdict back into replan/rebuild; documented locations/formats for every cross-agent file; post-merge cleanup; an audit of context-only vs file-based information passing.
**Out:** Confluence-mode changes beyond what the shared stages inherit; retrofitting `coder`/`contract-tester`/`init-workspace` returns (thin, single-consumer, consumed immediately — context-return is correct there).

## Stack & versions

Bash (`set -uo pipefail`, no jq — matching the existing `orchestrators/hooks/` style, verified by reading them); markdown skills per the repo's skill file format (docs/conventions.md).

## Conventions to enforce

Skill/rule frontmatter per docs/conventions.md; no skill or rule names this repo's directory layout; verdict/status vocabularies enter reports only through scripts; artifact-on-disk, pointer-in-envelope.

## Phase 1: Audit

**1.1: Classify every dae hand-off.** Read the full dae tree (router + 7 siblings), all gate/phase skills, 4 agents + 6 planner modules, 7 hooks. **Already file-based and enforced:** the plan file (`validate-plan.sh` schema, `mark-syllabus.sh` sole mutation path), the explore map, `.story`/`.diagnosis`/`.sync-report` sidecars, builder scope checked against the real diff by `verify-scope.sh`. **Context-only gaps found:** (1) gate verdicts existed only as fork return messages — kickbacks were re-typed paraphrases, resume lost gate history, the 3-loop cap untracked; (2) builder evidence (criterion + command + output) died with the lane worktree; (3) the builder contract file had no defined home — died uncommitted or leaked into the product branch; (4) `review-pr` had no contract at all — loose verdict, no envelope, no file, no scripts, no dae integration; (5) "run artifacts" referenced (`scope-writes.sh`, dae invariants) but never defined; (6) the envelope itself was prose-enforced only; (7) no post-merge cleanup existed anywhere — live evidence: this repo's stale `docs/skill-permission-docs` worktree and fully-merged remote `feature/parallel-build-loop`. All seven closed by phases 2–5.

## Phase 2: Contract machinery

**2.1: run-artifacts rule.** New `generic/rules/run-artifacts.md` (universal, always-on). Two homes: committed review records beside the plan (`<slug>-MM-DD-YY.{story,diagnosis,sync-report,plan-review,code-review,pr-review}.md`), and the gitignored run dir `<workflows-dir>/<name>-artifacts/` (`progress-log.md` — the run's live state, rewritten in place, one per plan, never committed, home of ALL small/medium run info; `contracts/<lane-id>.md`; `reports/<lane-id>-exit.md`). Acceptance: rule lists locations, naming, and the enforcing script for each. Test: review of the rule against every consumer edited in phases 3–4.

**2.2: report-verdict.sh + validate-report.sh.** New `orchestrators/hooks/`. Writer side: `report-verdict.sh <report> <verdict> <next> <blocking> <non-blocking>` is the ONLY way a verdict round enters a report — rejects any verdict outside `ready|tentative|rejected`, any next outside `proceed|impl-wrong|plan-wrong|map-wrong|needs-input`, and cross-field violations (ready/tentative ⇒ proceed + 0 blocking; rejected ⇒ kickback code, ≥1 blocking unless needs-input). Caller side: `validate-report.sh` re-checks enums and cross-field rules, verifies header counts match tagged `- [blocking]`/`- [non-blocking]` finding lines, requires open questions for needs-input; `--kind exit` checks builder exit reports (status enum, non-empty Files touched + Evidence). Acceptance: enum/consistency violations exit 1 with FAIL lines. Test: 12-case end-to-end run in scratch — all passed.

## Phase 3: The PR gate

**3.1: review-pr rebuilt.** `generic/skills/review-pr/SKILL.md` rewritten: mandatory pre-push gate (and standalone on PRs/branches). Inputs: target (PR URL/number or branch, default current vs base via `resolve-config.sh CLAUDE_BASE_BRANCH`), spec (plan path and/or Jira key — fetched, never invented; none ⇒ needs-input), report path. Reviews the ENTIRE diff against the spec re-read at verdict time; findings tagged blocking/non-blocking; round written via `report-verdict.sh`, checked via `validate-report.sh`; envelope `next` carries the kickback code. Never posts/merges/approves.

**3.2: comment-pr.** New `generic/skills/comment-pr/` + `scripts/render-pr-comment.sh`. Validates the report, renders the LAST round (badge, counts, findings table, open questions) — output used verbatim, one comment per round, confirm-first posting via `gh`; never reviews, never edits earlier comments. Render script tested against both scratch reports.

**3.3: dae wiring.** `dae/SKILL.md` ship stage: record → PR gate (always) → `push-pr`. Verdict presented WITH the push confirmation; `rejected` offers replan / rebuild / publish-as-draft-with-comment, `(Recommended)` per the kickback code; post-kickback rebuilds re-enter the gate as a new round, capped. `build.md` stage 7 updated to match; `push-pr` gained the draft flag, report link in the PR body, and the comment-pr/cleanup-merged hand-off lines.

## Phase 4: Retrofit

**4.1: Gate verdicts persisted.** `review-plan` → `.plan-review.md`, `review-code` → `.code-review.md`, one round per gate iteration (loop history durable); envelopes carry [plan path, report path]; dae's kickback routing passes the REPORT PATH to redispatched workers, never a paraphrase.

**4.2: Builder artifacts on disk.** `builder.md`: contract at `<run-artifacts>/contracts/<lane-id>.md` (explicitly never in the worktree); exit report at `reports/<lane-id>-exit.md` (status header, Files touched, per-criterion Evidence), self-validated with `--kind exit` before returning; envelope points at it. `build-dispatch.md`: dispatch prompt passes the run dir; lane verification checks the exit report first and feeds its file list to `verify-scope.sh`.

**4.3: dae invariants.** Setup creates the run dir + progress log. New invariants: the plan is amendable at ANY stage (warm-planner amendment of the same file, `validate-plan.sh` re-run, material changes re-gate, contradicted merged work flagged — and gates re-read the plan file at verdict time, so review-pr always uses current info); the progress log is rewritten at every state change and is what a resumed/compacted session reconstructs from. Dispatch loop step 5 updates it per lane event.

## Phase 5: Cleanup

**5.1: cleanup-merged.** New `generic/skills/cleanup-merged/SKILL.md`: prove the merge (`gh pr view` state MERGED — else stop), delete remote (permission-gated) and local (`-d` only, never `-D`) branch, prune worktree remnants (never with uncommitted work), remove the run dir, archive the plan + review-record siblings to `<plans-dir>/completed/` on a `sync/cleanup-<name>` branch (never committed to the base directly), optional Jira transition; sweep mode = N confirmed single-run cleanups.

**5.2: This repo's leftovers.** The `skill-permission-docs` worktree held an unshipped README section (install permission grant) — salvaged into this commit, worktree removed, branch deleted. The merged remote branch deletion was permission-declined in-session; user runs `git push origin --delete feature/parallel-build-loop`.

## Phase 6: Docs & indexes

**6.1: Pages updated.** `docs/conventions.md` (9 rules; envelope adopters incl. review-pr + exit reports; new "Run artifacts & verdict reports" section), `docs/pipeline.md` (diagram + gates section), `generic/AGENTS.md` (rule + skill tables), `orchestrators/AGENTS.md` (tier row, diagram, hooks list).

## Risks, open questions, decision points

- `scope-writes.sh`'s orchestrator allowlist should include the run-artifacts dir when a project wires it; its docstring already describes the shape — inert until wired.
- Remote branch deletion left to the user (permission-declined in-session).
- Retrofit deliberately excluded `coder`/`contract-tester` returns (see scope).

## Skill mapping

`review-pr` (gate) → `comment-pr` (posting) → `push-pr` (ship, draft path) → `cleanup-merged` (post-merge). Format enforcement: `report-verdict.sh` / `validate-report.sh` (install: `~/.claude/hooks/`).
