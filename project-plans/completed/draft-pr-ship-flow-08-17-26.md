# draft-pr-ship-flow-08-17-26

Rework plan — replace the dae workflow's single terminal "push + open PR at the very end" ship stage with a **draft-PR-early, publish-continuously, finalize-late** flow: open a draft PR right after the plan is approved, push the parent branch after every lane merge-back, and end the run by committing the records, pushing, and flipping the draft to ready.

## Phase syllabus

- [ ] Phase 1: The publish contract — ship skills and policy prose
  - [x] 1.1: Rework `push-pr` into a three-stage publish skill        (lane 1)
  - [x] 1.2: Rework `review-pr` for a PR gate that runs on an open draft PR   (lane 1)
  - [x] 1.3: Rework `comment-pr` for the always-available posting path   (lane 1)
  - [x] 1.4: Rework `cleanup-merged`'s ship-stage account and draft preconditions   (lane 1)
  - [x] 1.5: Rewrite the `push-policy` rule's pushing clause   (lane 1)
  - [x] 1.6: Update the `run-artifacts` rule's ship-time note   (lane 1)
  - [x] 1.7: Align `worktree-reminder.sh`'s push/PR guidance prose   (lane 1)
- [ ] Phase 2: The dae workflow files
  - [x] 2.1: Rewrite the router's Ship stage, PR gate, and publish invariant   (lane 2)
  - [x] 2.2: `build.md` — draft PR at plan approval; new ship sequence   (lane 2)
  - [x] 2.3: `build-dispatch.md` — push the parent after every lane merge-back   (lane 2)
  - [x] 2.4: `diagnose.md` + `sync.md` — draft PR at their approval gates   (lane 2)
  - [x] 2.5: `document.md` + `worktree-modes.md` — no-plan-gate, resume, and `none` modes   (lane 2)
- [ ] Phase 3: Integration
  - [x] 3.1: Align the index and docs surface   (after: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 2.1, 2.2, 2.3, 2.4, 2.5)
  - [x] 3.2: Retired-vocabulary sweep and install-sync check   (after: 3.1)

---

## Goal & scope

### The defect

The ship flow is a single terminal event. Verified in the source:

- `orchestrators/skills/dae/SKILL.md:57` — "**Ship** — record via the mode's document skill, then the **PR gate** (below), then invoke `push-pr` (publishes the parent branch, always asks first…)". One push, one PR, at the end.
- `agent-agnostic/skills/push-pr/SKILL.md:13` — "make sure every artifact is committed on the workflow branch, publish that branch, open a pull request"; `:19` — "NEVER mid-workflow".
- `orchestrators/skills/dae/build-dispatch.md:11-18` — the per-lane merge-back event list (verify → merge → clean up the lane → tick → progress log → re-scan frontier) has **no push step**. Every merged lane exists only in the local parent worktree until the run ends.
- `agent-agnostic/rules/push-policy.md:14` — "Only the final ship skill (`push-pr`) pushes the workflow branch and opens the PR."

Consequences: a whole multi-lane run's work is local-only until the very last step (nothing is backed up, nothing is visible, no CI runs on it); the PR appears fully-formed with everything at once; and a `rejected` PR-gate verdict has to invent a "publish anyway as a draft" escape hatch (`SKILL.md:58`) because there is no PR yet to fall back to.

### In scope

1. **A three-stage publish contract** in `push-pr` (`open-draft` | `update` | `finalize`), pinned below, replacing its single terminal behavior.
2. **`open-draft` after plan approval** — the router commits the promoted plan dir, pushes the parent branch, and opens the PR **in draft**. Applies to every workflow that has a plan/approval gate (`build`, `diagnose`, `sync`); `document`, which has none, opens right after its record stage's first commit (D2).
3. **`update` after every lane merge-back** — a push of the parent branch as a new step in `build-dispatch.md`'s per-lane event list, so merged work is never only local. Also the vehicle for the record stage's doc commit.
4. **`finalize` as the last step** — commit the record/doc stragglers, push, refresh the PR body with the final summary and the `pr-review.md` pointer, then **remove the draft status**.
5. **PR-gate routing rewritten** for a world where the PR already exists: `ready`/`tentative` → finalize; `rejected` → replan / rebuild / **leave it as a draft** and post the report via `comment-pr`.
6. Every file that encodes the old single-shot flow, including the always-on rules and the index/docs surface.
7. **Deleting the old path** — the retired vocabulary (`push-pr --draft` as the rejected-verdict flag, "terminal ship stage", "NEVER mid-workflow", "publish anyway as a DRAFT PR") is removed, not left alongside the new prose. Subphase 3.2 is the dangling-reference check.

### Out of scope (explicitly)

- **`.claude/skills/push-main/SKILL.md`** — this repo's own ship route. It deliberately has no PRs at all (`source-push-sync` rule), so the draft-PR flow does not apply. Verified: its only references to `push-pr` are "replaces push-pr for this repo only" (`:3`, `:16-17`), which stay true. Untouched.
- **`branch-squash-guard.sh`** — verified it needs no change. It denies force-push in any form unconditionally, in all modes (`:334-345`); `git push` touching `main` in Mode A only (`:346-365`); commits on the integration branch (`:379-398`); and `gh pr merge` without `--squash` (`:426-434`). It never inspects `gh pr create` or `gh pr ready`, and never denies pushing a `<type>/<name>` branch. The new per-lane pushes pass it unchanged.
- **`verify-run-scope.sh` / `scope-writes.sh`** — no change. The plans dir is already in the allowlist (`verify-run-scope.sh:106` resolves `CLAUDE_PROJECT_PLANS_DIR` and allows it), so the new plan-dir commit at `open-draft` is not flagged.
- **Non-GitHub PR hosts** (GitLab, Bitbucket). `push-pr` currently handles GitHub via `gh` or the GitHub MCP and reports "pushed-only" otherwise; that fallback is preserved, not extended.
- **Any change to `agent-specific/claude/settings.json`.** Outward-facing `gh` actions should keep prompting, and the harness `ask` rule on `git push` stays as it is — see "The harness prompt is not what D1 governs" below, and the residual-risk entry that follows from it.
- **The three bash test scripts** under `tests/` — none touches the ship flow (verified: `plan-lifecycle`, `resolve-config-precedence`, `verify-scope-parsing`). They must keep passing; they gain nothing.

### The publish contract (pinned here so both lanes implement the same thing)

`push-pr` takes a required `--stage`. Verified capability facts behind it: `gh` 2.4.0 (the version installed here — an old floor) supports `gh pr create --draft` and `gh pr ready [<number>|<url>|<branch>]`; the GitHub MCP equivalents are `create_pull_request` (`draft: true`) and `update_pull_request` (`draft: false`). `gh pr ready --undo` does **not** exist at 2.4.0, so "back to draft" is MCP-only — the flow never needs it.

| Stage | Commits | Pushes | PR action |
|---|---|---|---|
| `open-draft` | the promoted plan dir (`plan.md`, `plan-review.md`, `story.md`) | `git push -u origin <branch>` | `gh pr create --draft` (or MCP `draft: true`). PR already exists → report it, never duplicate. |
| `update` | authorized stragglers only (the record stage's doc changes; nothing at a lane merge) | `git push origin <branch>` | none — the open PR tracks the branch |
| `finalize` | last record stragglers | `git push origin <branch>` | refresh title/body with the final summary + `pr-review.md` pointer, then flip draft → ready (`gh pr ready` / MCP `draft: false`) — **unless** the caller passes keep-draft |

Invariants that hold at every stage: never `--force`, never push the base branch, never remove the worktree, a declined push or PR action is a valid outcome (record the exact command, do not retry or route around it).

**Push outcomes are three, not two (A1).** Every stage's return distinguishes **succeeded**, **failed or declined**, and **publishing impossible for this run** (no remote, or no PR tooling). The caller branches on this: per A1 a lane's child worktree and branch are destroyed only after its work is on the remote, and "the user declined" (keep the worktree until a later push catches up) is a different situation from "this repo has no remote" (nothing to wait for — clean up normally).

**Confirmation cadence (D1, decided).** `open-draft` and `finalize` each hold a **conversational** confirmation before acting — they are the two outward-facing PR-state changes ("push and open the draft PR?", "push and mark the PR ready?"). `update` holds none: it runs as part of the lane-merge event and the record commit, with no question asked.

**The harness prompt is not what D1 governs.** Verified in `agent-specific/claude/settings.json`: `Bash(git push:*)` sits in `permissions.ask` (`Bash(git:*)` is in `allow`, but `ask` matches first for a push). So Claude Code raises its own permission prompt on *every* push regardless of any prose here, and `push-pr`'s current claim that the push "always prompts the user for explicit confirmation before it runs (standing permission policy)" (`push-pr:28`) is describing that harness rule, not a conversational gate. D1 is therefore a decision about the **conversational** layer only — the layer skills and rules can actually control — and every subphase below must be written at that layer. Making an `update` push literally silent would require narrowing the `ask` rule, a user-level settings change with the live-grant fold-back caveat from `source-push-sync`; that is deliberately **not** in this plan, and is carried as a residual risk for the user to take up separately.

Why `open-draft` must commit the plan: a PR cannot be opened on a branch with no commits ahead of base, and at plan-approval time the branch has none. Verified — `plan-lifecycle.sh:35-37` states "Nothing here ever runs `git commit` … callers commit", and the only thing that currently commits the plan is `push-pr`'s straggler step at the end of the run (`push-pr/SKILL.md:27`). The plan commit is therefore load-bearing, not incidental.

Degenerate cases the contract must state:
- **No PR exists at `update` or `finalize`** (the `open-draft` push or PR was declined, or the stage never ran): retry `open-draft`'s work once at that event rather than failing the stage (D5).
- **No remote or no PR tooling**: detect once, record it, and let the run continue local-only; never block a stage on it.
- **Resume mode**: `open-draft` is idempotent — an existing PR for the branch is reported, not recreated.

---

## Stack & MAJOR versions

This repo has no package manifest (verified: no `package.json`, `pyproject.toml`, `go.mod`, or `Makefile` at the root). The payload is markdown-with-YAML-frontmatter plus POSIX-ish bash.

| Thing | Version | Verified from |
|---|---|---|
| Skill/rule/agent payload | Markdown + YAML frontmatter, `domain:` classifier | `docs/conventions.md:37-44`, every `SKILL.md` frontmatter |
| `gh` CLI | 2.4.0 | `gh --version` — the floor this flow must work on; `gh pr ready --help` confirmed present, `--undo` absent |
| git | 2.34.1 | `git --version` |
| bash | 5.1.16 locally; hooks target a portability floor | `bash --version`; no shell script is edited by this plan |
| GitHub MCP | `create_pull_request(draft)`, `update_pull_request(draft)` | tool schemas, fetched and read |

---

## Conventions to enforce

1. **This repo is the source; `~/.claude/` is an install.** Every edit lands in `orchestrators/` or `agent-agnostic/`. Never edit `~/.claude/` (`.claude/rules/source-push-sync.md`).
2. **Frontmatter is untouched except where a `description:` states the old behavior.** Everything edited here is `domain: universal`; `context: fork`, `rules:`, `model:`, `model-fallback:` stay exactly as they are.
3. **Match the existing prose register.** These files are dense, second-person, imperative, with load-bearing emphasis in bold and file/flag names in backticks. Do not restructure a skill's section headings (`## When to use`, `## Inputs`, `## How it works`, `## Hand-off / next`, `## Notes`) — edit inside them.
4. **Delete the old path.** No sentence describing the single-shot flow survives anywhere, including in a `description:` frontmatter line or an index table row. No "previously…/now…" transition prose, no compatibility wording.
5. **Both lanes implement the pinned contract verbatim** — the stage names `open-draft` / `update` / `finalize` and the table above. Any wording drift between lane 1 and lane 2 is a defect caught at 3.2.
6. **No time estimates anywhere** (hard rule).
7. **Behavior is otherwise frozen.** Any change beyond the publish flow — CI-status checking at the gate, allowlist edits, skill renames — belongs to a decision point, never smuggled into a subphase.

**Test-oracle note.** The rework module's default oracle is `existing suite`; that default does not apply to prose payload, because there is no suite that executes a skill file. Every prose subphase therefore declares `equivalence check` — a per-file acceptance checklist plus the retired-vocabulary sweep at 3.2 — and 3.2 additionally declares `existing suite` for the three bash test scripts and `sync-install.sh --check`. No subphase declares `new contract tests`; no builder spawns a contract-tester on this plan.

---

## Phased subphases

### Phase 1: The publish contract — ship skills and policy prose

**Lane 1 file scope (whole lane, disjoint from lane 2):** `agent-agnostic/skills/push-pr/SKILL.md`, `agent-agnostic/skills/review-pr/SKILL.md`, `agent-agnostic/skills/comment-pr/SKILL.md`, `agent-agnostic/skills/cleanup-merged/SKILL.md`, `agent-agnostic/rules/push-policy.md`, `agent-agnostic/rules/run-artifacts.md`, `agent-agnostic/hooks/worktree-reminder.sh`.

#### 1.1: Rework `push-pr` into a three-stage publish skill

- **File scope:** `agent-agnostic/skills/push-pr/SKILL.md` (only).
- **Pattern to follow:** the file's own structure and voice. Its `## How it works` numbered steps and the "declined is a valid outcome" treatment at `:28-29` and `:47` are the model for how each stage's confirmation and decline path should read.
- **What changes:**
  - `description:` (`:3`) — currently "Terminal ship stage of the dae workflow — commit stragglers, push the workflow branch, and open a pull request against the base branch". Rewrite for the three stages; keep the "leaves the worktree standing / teardown is `cleanup-merged`'s job / never force-pushes, never pushes main" clauses.
  - Body opener (`:13`) — carries a **contradiction that must die**: "publish that branch, open a pull request against the base branch, **and remove the worktree so the workflows dir stays clean**", directly contradicting step 4 (`:35`) and the `run-artifacts` rule. Rewrite the opener for the staged model and drop the teardown claim.
  - `## When to use` (`:16-19`) — "Only after the full workflow has completed" and "**NEVER mid-workflow**" are exactly inverted by this rework. Replace with one entry per stage naming its trigger (plan approval / lane merge-back and record commit / end of run after the PR gate), plus the standalone use.
  - `## Inputs` (`:23`) — add `--stage`; replace "whether to open the PR as a DRAFT (the gate's publish-anyway path)" with the keep-draft flag on `finalize`; state which inputs each stage needs (`open-draft` needs the plan path and the plan-derived summary; `update` needs whether it may commit stragglers and which; `finalize` needs the work summary, the `pr-review.md` path, and the keep-draft decision).
  - **The confirmation prose**, currently at `:28`: "This always prompts the user for explicit confirmation before it runs (standing permission policy)". Rewrite per D1's decided cadence — a conversational confirmation at `open-draft` and `finalize`, none at `update` — and drop the "standing permission policy" framing, which conflates the conversational gate with the harness's `Bash(git push:*)` `ask` rule (see the Goal & scope note). The decline handling that follows it (`:28-29`, `:47`) is correct and stays.
  - `## How it works` (`:27-35`) — restructure to per-stage steps implementing the pinned contract table, keeping the existing verify-first discipline (clean tree, expected `<type>/<name>` branch, never main), the PR-template check (`:30`), the "PR already exists → update, don't duplicate" rule (`:33`), and the no-remote/no-tooling fallback (`:34`). Keep step 4's "leave the worktree standing" reasoning (`:35`) intact and applicable to all stages.
  - `## Hand-off / next` (`:39`) — "ends the workflow — nothing follows by default" is false for `open-draft` and `update`. Give a per-stage return contract; the follow-ups list (`comment-pr`, `review-pr`, `cleanup-merged`) stays, re-pointed at `finalize`.
  - **`update`'s return must distinguish THREE push outcomes, not two** (amendment A1): **succeeded**, **failed or declined**, and **publishing impossible for this run** (no remote, or no PR tooling — the detect-once case). This is load-bearing rather than cosmetic: per the amended 2.3, the caller decides whether to destroy the lane's child worktree and branch on exactly this distinction, and it cannot tell "the push didn't happen because the user said no" (keep the worktree) from "the push didn't happen because this repo has no remote" (cleanup is safe) unless the return says which. A two-state "succeeded or declined" return is a defect. The same three states apply to `finalize`'s return, since a successful `finalize` push is what clears any cleanups deferred earlier in the run.
- **Acceptance criteria:**
  - The three stage names appear exactly as `open-draft`, `update`, `finalize`, and their semantics match the pinned contract table cell for cell.
  - `open-draft` explicitly commits the promoted plan dir and explains why (a PR needs a commit ahead of base).
  - The confirmation cadence matches D1: conversational confirmation at `open-draft` and `finalize` only; `update` asks nothing. No sentence claims a push "always prompts" as a blanket property.
  - `finalize` pushes **before** flipping to ready, and names both mechanisms (`gh pr ready`, MCP `update_pull_request` with `draft: false`).
  - The skill keeps its name (D8) — no rename, no alias.
  - `update`'s and `finalize`'s return contracts each distinguish the three push outcomes (succeeded / failed-or-declined / publishing impossible), stated in terms a caller can branch on.
  - Every degenerate case in the contract (no PR yet, no remote/tooling, resume with an existing PR, declined push/PR) has a stated behavior.
  - No occurrence of "Terminal ship stage", "NEVER mid-workflow", "remove the worktree so the workflows dir stays clean", or `--draft` as a rejected-verdict flag.
  - Frontmatter keys other than `description` are byte-identical.
- **Test approach:** `equivalence check` — read the finished file against the contract table and the acceptance list above; `grep -n` for each retired phrase returns nothing.

#### 1.2: Rework `review-pr` for a PR gate that runs on an open draft PR

- **File scope:** `agent-agnostic/skills/review-pr/SKILL.md` (only).
- **Pattern to follow:** the file's existing `## Hand-off / next` sentence (`:48`), which is where the caller's routing options are named.
- **What changes:**
  - `description:` (`:3`) — "invoked by the dae orchestrator before `push-pr` on every run" → before `finalize`, on a PR that is already open as a draft.
  - `## When to use` (`:17`) — same correction: the gate now runs before the PR is flipped to ready, not before the PR exists.
  - `## Hand-off / next` (`:48`) — "routes a non-ready outcome: replan, rebuild, or publish-as-draft with the report posted via `comment-pr`" → the third option becomes **leave the PR as a draft** and post the report; nothing is "published anyway" because publishing already happened.
  - `## How it works` step 1 (`:32`) — branch mode stays the reviewed target (the diff is what matters and is cheaper), but note that the branch is now pushed, so PR mode is available for a fresh standalone pass. Do **not** add CI-status checking to the dae gate path — **D7 decided against it**; the existing PR-mode mention of CI status at `:32` stays exactly as it is, neither extended nor removed.
- **Acceptance criteria:** no sentence implies the PR does not yet exist at gate time; the rejected-verdict third option reads as "leave as draft + `comment-pr`"; the verdict vocabulary, `report-verdict.sh` / `validate-report.sh` steps, and `verify-run-scope.sh` step are untouched; no CI-status behavior added.
- **Test approach:** `equivalence check` — read against the acceptance list; `grep -n 'publish-anyway\|publish anyway\|before .push-pr.'` returns nothing.

#### 1.3: Rework `comment-pr` for the always-available posting path

- **File scope:** `agent-agnostic/skills/comment-pr/SKILL.md` (only).
- **Pattern to follow:** the file is deliberately narrow ("You publish a verdict that already exists"); keep it that narrow.
- **What changes:** `description:` (`:3`) "invoked by the dae orchestrator after review-pr (draft-publish path)"; `## When to use` (`:17`) "when the user chooses to publish despite a non-ready verdict (draft PR + posted report)". Both assume the PR is created at that moment. Rewrite for a PR that is already open: posting is available at any verdict, and the draft-retention path is the caller's decision, not a publish event. `:40` ("The `push-pr` skill links the report path in the PR body") stays true — re-point it at `finalize`.
- **Acceptance criteria:** no wording implies a PR is being created alongside the comment; one-comment-per-round and never-edit-earlier-rounds rules (`:29`, `:39`) intact; the `render-pr-comment.sh` contract untouched.
- **Test approach:** `equivalence check` against the acceptance list.

#### 1.4: Rework `cleanup-merged`'s ship-stage account and draft preconditions

- **File scope:** `agent-agnostic/skills/cleanup-merged/SKILL.md` (only).
- **What changes:**
  - Body opener (`:13`) — "The ship stage publishes the branch **and tears down the worktree** but keeps the local branch and touches nothing remote" is **already false today** (`push-pr` step 4 leaves it standing) and gets more wrong under the new flow ("touches nothing remote" — the run now pushes repeatedly). Rewrite it to describe what actually remains after `finalize`.
  - `:19` — "NEVER before the merge — an open or **draft** PR's branch is live work" already covers drafts correctly; keep, and make sure it does not read as if a draft PR were unusual.
- **Acceptance criteria:** the opener matches reality (worktree left standing by ship; the branch was pushed during the run); every deletion remains evidence-gated; steps 1–7, the `plan-lifecycle.sh archive` prose, and the safe-delete notes are otherwise unchanged.
- **Test approach:** `equivalence check` against the acceptance list; `grep -n 'tears down the worktree'` returns nothing.

#### 1.5: Rewrite the `push-policy` rule's pushing clause

- **File scope:** `agent-agnostic/rules/push-policy.md` (only).
- **Pattern to follow:** the file's terse bolded-lead bullet list.
- **What changes:**
  - `:14` — "**Pushing**: Builder agents should never push. Only the final ship skill (`push-pr`) pushes the workflow branch and opens the PR." Rewrite: builders still never push (unchanged and load-bearing); the parent branch is pushed repeatedly through `push-pr`'s stages across the run; the PR is opened as a draft early and flipped to ready at `finalize`.
  - `:15` — "**Permissions**: Every `git push` still requires explicit confirmation first — never push autonomously or silently." Rewrite to **D1's decided cadence**: a conversational confirmation is required at `open-draft` and `finalize` (the two outward-facing PR-state changes); the run's per-lane and record `update` pushes of the parent branch carry no conversational gate — the user's approval at the plan gate is what authorizes them. The scope of that carve-out is exactly the run's own parent branch through `push-pr --stage update`; every other push in every other context still requires confirmation.
  - Do **not** claim anything about harness permission prompts. The rule speaks to the conversational layer; the `Bash(git push:*)` `ask` entry is a separate mechanism and this plan does not touch it.
- **Acceptance criteria:** the bullet describes the staged flow; D1's cadence is stated with its carve-out scoped to the run's parent branch via `--stage update`, not to pushes generally; the never-force-push, never-commit-on-`dev`, and squash-only clauses survive with their force intact; the rule stays short (it is always-on context — `docs/conventions.md:221`).
- **Test approach:** `equivalence check` against the acceptance list.

#### 1.6: Update the `run-artifacts` rule's ship-time note

- **File scope:** `agent-agnostic/rules/run-artifacts.md` (only).
- **What changes:** `:36` — "**Only `cleanup-merged` may remove the worktree** … `push-pr` deliberately does NOT tear down: **at ship time the PR is merely OPEN**". The conclusion is right and gets stronger; the premise needs restating — the PR is open (as a draft) from plan approval onward, and `finalize` only flips it to ready. Adjust so the reasoning reads correctly under the new flow.
- **Acceptance criteria:** the "only `cleanup-merged` removes the worktree" invariant and the "never tear down an in-flight run" consequence are unchanged in force; the run-dir contents list and the `.gitignore` reasoning are untouched.
- **Test approach:** `equivalence check` against the acceptance list.

#### 1.7: Align `worktree-reminder.sh`'s push/PR guidance prose

- **File scope:** `agent-agnostic/hooks/worktree-reminder.sh` (only).
- **What changes:** the `push_msg` string at `:49` tells any session to route pushes and PR work through `push-pr`/`review-pr`, and summarizes `push-policy`. **Rewrite it unconditionally to match the final 1.5 text** — do not treat the current string as an accurate baseline to be adjusted only on demand. It is not one: the string claims push-policy has "**two modes** by whether the repo has a dev branch — WITH dev … WITHOUT dev, main is the integration branch", while `agent-agnostic/rules/push-policy.md` as written today describes exactly ONE mode (`dev` is unconditionally "the universal integration branch"; no "WITHOUT dev" fallback exists in the rule). That drift is **pre-existing**, independent of anything 1.5 changes, and left alone it would survive this rework untouched.
  - The string summarizes **the rule**, so reconcile it to the rule: the final `push-policy.md` text from 1.5 is the sole source, including D1's confirmation cadence. Add the staged publish flow (draft PR opened early, parent pushed through the run, flipped to ready at `finalize`).
  - **Do not** resolve the rule-versus-script divergence here (see the risk entry): `branch-squash-guard.sh` genuinely implements two modes while the rule states one. Rewriting the branch model in `push-policy.md` is outside this plan.
  - This is a shell string in a wired `SessionStart` hook — do not touch its quoting, the surrounding logic, or the `:5` header comment beyond what accuracy requires.
- **Acceptance criteria:** the "two modes" claim no longer appears unless 1.5's final rule text actually says so; `push_msg` and `push-policy.md` can be read side by side with no contradiction, including on the confirmation cadence; the staged flow is reflected; `bash -n agent-agnostic/hooks/worktree-reminder.sh` passes; the script's behavior and output shape are otherwise identical.
- **Test approach:** `equivalence check` plus the `bash -n` syntax check.

### Phase 2: The dae workflow files

**Lane 2 file scope (whole lane, disjoint from lane 1):** `orchestrators/skills/dae/SKILL.md`, `build.md`, `build-dispatch.md`, `diagnose.md`, `sync.md`, `document.md`, `worktree-modes.md`.

#### 2.1: Rewrite the router's Ship stage, PR gate, and publish invariant

- **File scope:** `orchestrators/skills/dae/SKILL.md` (only).
- **Pattern to follow:** the file's own "Shared stages" bullets and "Invariants (load-bearing — they live here, never in a sibling file)" section — the new publish rules belong in those two places, not scattered into workflow files.
- **What changes:**
  - `## Shared stages` "**Ship**" bullet (`:57`) — rewrite as the ordered sequence **record → commit the record output and push (`push-pr --stage update`) → PR gate → `push-pr --stage finalize`**. The commit-before-the-gate ordering is **D6, decided**: state it as settled behavior with its reason (the gate reviews `git diff <base>...<branch>`, which sees committed work only, so an uncommitted record stage would be invisible to it) — not as an option or an improvement. Keep "leaves the worktree and its run dir standing", "the run is NOT done until `push-pr` reports", and "a declined push is a valid outcome".
  - **Add a shared "Open the draft PR" step** to the same section, stated once for all workflows: after the approval gate and the `plan-lifecycle.sh promote`, invoke `push-pr --stage open-draft`, holding the conversational confirmation D1 requires. State the **D5** degradation as settled behavior — a declined or impossible open is recorded in the progress log, the run continues local-only, and the open is retried exactly once at the next `update` event; it never blocks a stage — and that the step is idempotent on resume.
  - `## Shared stages` "**PR gate**" bullet (`:58`) — rewrite the routing: `ready`/`tentative` → `finalize`; `rejected` → replan / rebuild / **leave as draft** with the report posted via `comment-pr`. Remove `push-pr --draft`. Keep the `(Recommended)` tagging and the "post-kickback rebuild re-enters this gate" rule.
  - Invariant `:74` — "Publishing happens ONLY through `push-pr` — never push yourself, never force-push, never push the base branch." Restate so it covers repeated staged pushes **while keeping the single-publisher property intact**: per **D4**, `push-pr --stage update` is the only per-lane push mechanism, so `push-pr` remains the sole publisher and no second publisher is named. "Never push yourself" therefore holds verbatim and must not be weakened.
  - Invariant `:68` — plan-location ownership. The promotion is now immediately followed by the plan-dir commit and the draft PR; say so, and keep "one promotion, right after the user's approval, and nothing else moved by hand".
  - Invariant `:70` — the progress log must additionally record the PR URL, its draft state, and the last pushed commit, so a resume knows a PR already exists.
  - Invariant `:72` — carries a **stale line citation**: "`verify-run-scope.sh:43` resolves and allows it". The actual line is `106` (verified). Fix the citation while the surrounding claim (the plans dir is allowed, so the new plan-dir commit is not flagged) stays true and becomes more load-bearing.
- **Acceptance criteria:** the draft-PR-open step and the finalize step both live in `## Shared stages` and are stated exactly once; the ship sequence commits and pushes the record output **before** the PR gate, written as settled behavior with its reason; the PR-gate routing has no "publish anyway"/`--draft` wording; the publish invariant permits the staged pushes without weakening the never-push-yourself / never-force-push / never-push-base clauses and names no publisher other than `push-pr`; the D1 cadence governs every confirmation the router holds; the progress-log invariant names PR URL + draft state; the `verify-run-scope.sh` citation reads `:106`; stage names match Phase 1's contract verbatim.
- **Test approach:** `equivalence check` — read against the acceptance list; `grep -n 'push-pr --draft\|publish anyway\|verify-run-scope.sh:43'` returns nothing.

#### 2.2: `build.md` — draft PR at plan approval; new ship sequence

- **File scope:** `orchestrators/skills/dae/build.md` (only).
- **Pattern to follow:** its numbered `## Stages` entries, which name the shared stages as "(shared — router)" rather than restating them.
- **What changes:** stage 3 (`:11`) — "After explicit approval, FIRST run `plan-lifecycle.sh promote <proposal-path>`, THEN switch to auto mode and dispatch" gains the draft-PR open between promotion and dispatch, referenced as the router's shared step (not duplicated prose). Note the ordering constraint explicitly: promote first, then `open-draft` (which commits the promoted plan dir), then dispatch. Stage 7 (`:19`) — rewrite the ship sequence to record → `push-pr --stage update` committing and pushing the record output → PR gate → `finalize`, per **D6**; the `--draft` mention goes. Stage 4 (`:13`) may need a pointer to the new per-lane push, but the mechanism itself belongs in 2.3, not here.
- **Acceptance criteria:** the draft PR is opened after promotion and before the first builder dispatch, in that order; the ship sequence shows the record commit and push preceding the PR gate; no shared-stage mechanics are duplicated into this file; no `--draft` flag mention survives; `--worktree none` note at `:25` still accurate.
- **Test approach:** `equivalence check` against the acceptance list.

#### 2.3: `build-dispatch.md` — push the parent after every lane merge-back

- **File scope:** `orchestrators/skills/dae/build-dispatch.md` (only).
- **Pattern to follow:** the existing 6-step numbered list under `## Event-driven scheduling (no waves)` (`:13-18`).
- **What changes:** insert the push as a new step in the per-lane event list, and **re-order the list so the lane's cleanup follows the push** (amendment A1).
  - **The order is: verify → merge → tick the subphases → update the progress log → `push-pr --stage update` → clean up the lane → re-scan the frontier.** State the rationale: the child worktree and branch are the only place a lane's work exists outside the parent's local history, so they are not destroyed until that work is on the remote. Push first, then delete.
  - The push goes through **`push-pr --stage update`** (D4 — the only mechanism; no direct `git push` from the router, no helper script) and holds **no conversational confirmation** (D1: only `open-draft` and `finalize` do). A merge conflict still stops everything before anything is pushed.
  - Where no PR exists yet because `open-draft` was declined or impossible, this event is the single **D5** retry point.
  - **What the cleanup step does when the push does not succeed** — write this so it cannot be misread, distinguishing the two cases by the three-state return `push-pr --stage update` gives back (see 1.1):
    - **Push succeeded** → clean up the lane immediately: `git worktree remove <child-path>`, `git worktree prune`, delete the child branch.
    - **Push failed or was declined** → **do NOT clean up.** Keep the child worktree and branch, and record a **deferred cleanup** in the progress log naming the lane id, its worktree path, and its branch. The schedule is not blocked — carry straight on to the frontier re-scan, exactly as before (D5's non-blocking rule is unchanged; only the cleanup waits, never the dispatch).
    - **Publishing is impossible for this run at all** (no remote, or no PR tooling — the contract's detect-once case) → this is **not** a failed push: there is nothing to wait for, so clean up normally. A local-only run must not accumulate every lane's worktree.
    - **Deferred cleanups are retried, not forgotten**: after any later `update` (or `finalize`) push succeeds, clean up every lane still carrying a deferred cleanup, not just the current one — one successful push makes all of them safe at once. If the run ends with deferred cleanups still outstanding, surface them to the user with their worktree paths and branch names; never delete them silently, and never let them go unmentioned. This is the same treatment `## Failure paths`'s "Lane still alive at teardown" entry (`:30`) already gives unfinished work — reference it rather than inventing a second convention.
  - `:20` ("At run end exactly ONE worktree/branch pair remains — the parent … which the ship stage publishes") needs two corrections: the "publishes" clause (the parent has been published since plan approval; ship finalizes it), and the "exactly ONE" claim, which now holds only when every lane's push succeeded — a lane with a deferred cleanup leaves its child pair standing, surfaced to the user.
- **Acceptance criteria:** the event list reads verify → merge → tick → progress log → push → cleanup → frontier re-scan, numbered accordingly; the push step names `push-pr --stage update` and asks the user nothing; the push-before-cleanup rationale is stated; all three push outcomes (succeeded / failed-or-declined / publishing impossible) have an explicit, distinguishable cleanup behavior; deferred cleanups are recorded in the progress log, retried after any later successful push, and surfaced at run end; a declined or failed push is still explicitly non-blocking to the frontier; the D5 retry point is named; the merge-conflict-is-a-scope-violation rule (`:14`) is unchanged; the `:20` sentence no longer claims first publication at ship time and no longer claims exactly one pair unconditionally.
- **Test approach:** `equivalence check` against the acceptance list.

#### 2.4: `diagnose.md` + `sync.md` — draft PR at their approval gates

- **File scope:** `orchestrators/skills/dae/diagnose.md`, `orchestrators/skills/dae/sync.md`.
- **Pattern to follow:** whatever 2.2 does for `build.md` — these three files must read consistently.
- **What changes:**
  - `diagnose.md` stage 3 (`:11`) — after the pick-the-causes gate and `plan-lifecycle.sh promote`, open the draft PR. This must cover the **none-picked** run explicitly: the report is the deliverable, the run skips to Record/Ship, and per **D3** the draft PR is still opened and then finalized — uniformity across workflows was chosen deliberately, so write it as the rule, not as an edge case being tolerated. Stage 6–7 (`:17`) — update the ship account; "the worktree is torn down" in that sentence is already inaccurate and must go.
  - `sync.md` stage 3 (`:11`, confirm-the-diff gate) — same treatment, also per **D3**. Stage 5 (`:15`) — update the ship account. Note `sync.md` has **no promotion step** (its plan already exists and may have been `reopen`ed at setup, `:7`), so the draft PR opens after the confirm gate against whatever is committable then — in practice the `sync-report.md` the planner wrote into the plan dir.
- **Acceptance criteria:** both files open the draft PR at their approval gate, phrased consistently with `build.md`; the none-picked diagnose path and the builder-less sync path are both explicitly handled as the rule rather than as exceptions; the sync file does not invent a promotion step and names what its first commit actually contains; `diagnose.md`'s "the worktree is torn down" claim is gone.
- **Test approach:** `equivalence check` against the acceptance list, read side by side with `build.md`.

#### 2.5: `document.md` + `worktree-modes.md` — no-plan-gate, resume, and `none` modes

- **File scope:** `orchestrators/skills/dae/document.md`, `orchestrators/skills/dae/worktree-modes.md`.
- **What changes:**
  - `document.md` says "**No planner and no builders**" (`:3`, verbatim) — hence no plan and no plan gate, so there is no approval gate to hang the draft-PR open on. Nothing commits before the record stage either: stage 2 tells the caller to "Pass the scope and an output path inside the parent worktree" (`:9`, verbatim) and the map is written there — the run dir by default, gitignored per `run-artifacts.md:30` — and no stage between setup and Record runs `git commit`. So the branch genuinely has no commits until Record.
  - **D2 = option A, decided:** the draft PR opens right after the record stage produces its first commit, and `finalize` follows the PR gate. Stage 3 (`:11`) gains the draft-PR open — sequenced as record → commit + `push-pr --stage open-draft` → PR gate → `finalize`, which also satisfies D6 for this workflow since the record output is committed before the gate either way. Stage 4 (`:13`) becomes the finalize. State plainly why this workflow's open point differs from the others (no approval gate, no earlier commit), so the asymmetry reads as deliberate rather than as an oversight.
  - `worktree-modes.md` — `resume` (`:11`): a resumed run may already have an open draft PR, and the progress log (per 2.1) is where its URL and draft state live; when the run dir died with the worktree, the PR is discoverable via `gh pr list --head <branch>`. `none` (`:15`): "`push-pr` pushes the current branch and skips teardown" needs restating for the staged flow, and the base-branch guard (STOP if the current branch is the base) becomes more urgent — it now dead-ends at plan approval, not at ship.
- **Acceptance criteria:** `document.md` opens the draft PR immediately after the record stage's first commit and finalizes after the PR gate, with the reason for differing from the other workflows stated, not implied; resume mode says how to discover an existing PR both with and without a surviving progress log; `none` mode's guard rationale names plan approval as the new failure point.
- **Test approach:** `equivalence check` against the acceptance list.

### Phase 3: Integration

Serialized, no lane. Both file sets touched here are shared surfaces — index tables and docs pages summarizing what lanes 1 and 2 changed — so they must not be written from a lane.

#### 3.1: Align the index and docs surface

- **File scope:** `AGENTS.md`, `orchestrators/AGENTS.md`, `agent-agnostic/AGENTS.md`, `README.md`, `docs/pipeline.md`, `docs/architecture.md`, `docs/conventions.md`.
- **Pattern to follow:** each file's existing shape — `orchestrators/AGENTS.md:41-63` and `docs/pipeline.md:11-27` carry the same ASCII pipeline diagram; `README.md:52-57` a compressed variant; `agent-agnostic/AGENTS.md:44-51` a skill-index table.
- **What changes (each verified as a real reference):**
  - `orchestrators/AGENTS.md` — diagram `:55-62` (`review-pr gate … → replan / rebuild / draft+comment-pr` then `push-pr`) must show the draft PR opening after the plan gate, the per-lane pushes, and the finalize; `:11` skill-tier list and `:73` shared-stage sentence.
  - `docs/pipeline.md` — diagram `:24-27`; `:40` ("**ship** (record → `push-pr`)"); `:49` fork list; `:73` ("the parent, which `push-pr` publishes"); `:88-92` gate paragraph (rejected → publish-as-draft).
  - `docs/architecture.md` — `:116` hand-off graph ("→ `push-pr`, with `review-pr` as an optional independent pass" — note this also contradicts `SKILL.md:58`, which makes the PR gate mandatory; fix both facts).
  - `README.md` — `:56` compressed diagram line.
  - `AGENTS.md` (root) — `:17` is a directory listing only; change nothing unless a name changed.
  - `agent-agnostic/AGENTS.md` — `:48` `review-pr` row, `:51` `push-pr` row ("Terminal ship stage … open a PR (draft on the gate's publish-anyway path)"), `:71` push/PR routing sentence.
  - `docs/conventions.md` — `:117` mentions the gate verdicts only; change only if lane 1 altered vocabulary (it should not have).
  - **`docs/pipeline.md:66-72` — the "Inside a builder" closing paragraph (amendment A1).** It restates the whole per-lane event sequence in prose, in the **pre-A1 order** and with no push at all: "on report, `dae` verifies the lane (`verify-scope.sh`), merges the child branch into the parent (a conflict IS a scope violation), **removes the lane's worktree/branch, ticks the syllabus** (`mark-syllabus.sh`), re-scans the `(after:)` frontier, and dispatches immediately". Rewrite it to the amended order — verify → merge → tick → progress log → push (`push-pr --stage update`) → cleanup → re-scan — so this summary and `build-dispatch.md` agree. The paragraph's closing sentence ("At run end one worktree/branch remains: the parent, which `push-pr` publishes") needs the same two corrections 2.3 makes to `build-dispatch.md:20`: the parent has been published since plan approval (ship finalizes it), and "one worktree/branch remains" holds only when every lane's push succeeded. Keep it a summary — the deferred-cleanup mechanics belong in `build-dispatch.md`, not here; one clause pointing at them is enough.
- **Acceptance criteria:** all three diagrams (orchestrators/AGENTS.md, docs/pipeline.md, README.md) tell the same story and agree with the payload files; every index row describing `push-pr` names the three stages; `docs/architecture.md` no longer calls the PR gate optional; `docs/pipeline.md`'s per-lane prose sequence matches `build-dispatch.md`'s amended order step for step, including the push and the push-before-cleanup placement; no docs page contradicts a payload file it summarizes.
- **Test approach:** `equivalence check` — read each diagram against `SKILL.md`'s final Shared stages section; diff the three diagrams against each other for the same stage order.

#### 3.2: Retired-vocabulary sweep and install-sync check

- **File scope:** read-only across the repo; edits only to fix stragglers found in files already owned by 1.x/2.x/3.1 (this subphase owns no new file).
- **Pattern to follow:** the rework rule that every replaced structure gets a deletion with a dangling-reference check.
- **What changes:** run the sweep and fix what it finds.
  - `grep -rn --include=*.md --include=*.sh -e 'push-pr --draft' -e 'Terminal ship stage' -e 'NEVER mid-workflow' -e 'publish anyway' -e 'publish-as-draft' -e 'draft-publish' -e 'tears down the worktree' -e 'remove the worktree so the workflows dir' -e 'verify-run-scope.sh:43' -e 'standing permission policy' -e 'two modes' .` — excluding `project-plans/` (historical records are not rewritten) — must return **no hits outside `project-plans/`**.
  - `grep -rn 'push-pr' . | grep -v project-plans` — every surviving mention must be consistent with the three-stage contract.
  - Cross-check the stage names appear identically in lane 1 and lane 2 output (`grep -rn 'open-draft\|--stage' orchestrators/skills/dae agent-agnostic`).
- **Acceptance criteria:** both greps clean; `bash tests/plan-lifecycle.test.sh`, `bash tests/resolve-config-precedence.test.sh`, `bash tests/verify-scope-parsing.test.sh` all pass (unchanged — they must be untouched by this run); `bash -n` clean on `worktree-reminder.sh`; `orchestrators/hooks/sync-install.sh --check` reports the changed units as pending sync (and nothing unexpected), confirming every edited file maps to a real install target.
- **Test approach:** `existing suite` (the three bash test scripts, `bash -n`, `sync-install.sh --check`) + `equivalence check` (the grep sweep).

---

## Risks, open questions, decisions

### Decisions — settled, no open questions remain

All eight decision points raised in plan-gate round 1 were settled by **the user, at the plan gate, 08-17-26**. They are recorded here as spec, and every subphase above is written to them. Nothing in this section is open; a builder implements what it says.

| # | Decision | Where it is implemented |
|---|---|---|
| **D1** | **Confirmation cadence: conversational confirmation at `open-draft` and `finalize`; none at `update`.** The two outward-facing PR-state changes ask; the per-lane and record pushes do not. The carve-out is scoped to the run's own parent branch through `push-pr --stage update` — every other push still asks. | 1.1, 1.5, 1.7, 2.1, 2.3 |
| **D2** | **The `document` workflow opens its draft PR right after the record stage's first commit**, and finalizes after the PR gate. It has no plan gate and no earlier commit, so this is its earliest possible open point; the asymmetry is deliberate and must be stated in the file. | 2.5 |
| **D3** | **Degenerate runs still open the draft PR** — a builder-less `sync` run and a none-picked `diagnose` run open and then finalize, for uniformity across workflows. Written as the rule, not as a tolerated edge case. | 2.4 |
| **D4** | **`push-pr --stage update` is the per-lane push mechanism.** No `push-branch.sh`, no direct `git push` from the router. The single-publisher invariant survives verbatim and the plan's lane scopes are unchanged. | 1.1, 2.1, 2.3 |
| **D5** | **A declined or impossible `open-draft` degrades, never blocks**: record it in the progress log, continue the run local-only, retry the open exactly once at the next `update` event. | 1.1, 2.1, 2.3 |
| **D6** | **The record output is committed and pushed BEFORE the PR gate.** This is an approved behavior change, not a side effect: today the record stage's docs are committed only by `push-pr` at the very end (`push-pr:27`) while `review-pr` reviews `git diff <base>...<branch>` (`review-pr:32`), which sees committed work only — so the PR gate never sees the doc changes. Committing first closes that gap. | 2.1, 2.2, 2.5 |
| **D7** | **No CI-status consultation at the PR gate.** `review-pr:32`'s existing PR-mode CI mention stays exactly as written; the dae gate path gains nothing. | 1.2 |
| **D8** | **`push-pr` keeps its name.** Its identity broadens from "terminal ship stage" to "the staged publisher"; a rename would ripple through every reference, the `~/.claude` install, and every historical plan record. | 1.1, 3.1 |

### Amendments after approval

**A1 — Child-lane cleanup happens AFTER the parent push, not before.** Raised by **the user, mid-build (code gate in flight), 08-18-26**, verbatim: *"worktree removals should happen post push for child branches"*.

The approved plan had the per-lane event list clean up the lane and *then* push (2.3's original wording: "**after** the merge and the lane cleanup, **before** the frontier re-scan"). That order destroys a lane's child worktree and branch while its work still exists only in the parent's *local* history — if the push then fails, the merged work has no remote copy and no surviving child. Reversed: **verify → merge → tick → progress log → push → cleanup → frontier re-scan**, so nothing ephemeral is deleted until the work is on the remote.

The cleanup step therefore becomes conditional on the push outcome, which is why the contract's return grew from two states to three (see "Push outcomes are three, not two" above): a declined push defers the lane's cleanup and keeps its worktree, while a run with no remote at all cleans up normally. Deferred cleanups are retried after any later successful push and surfaced to the user if the run ends with them outstanding.

**Specs changed by A1: 1.1, 2.3, and 3.1.** All three were already built and merged before the amendment arrived, so all three need rework. 3.1 is in the list because `docs/pipeline.md:66-72` independently restates the per-lane event sequence in prose — it would silently contradict the amended `build-dispatch.md` if left alone. No other subphase's spec is affected: 2.1's router prose and D1's cadence are untouched (lane cleanup is `build-dispatch.md`'s concern, not the router's), 1.4's `cleanup-merged` is about post-merge teardown of the parent rather than lane cleanup, and the lane structure is unchanged. Note the ordering constraint on the rework: 3.1 depends on 2.3, exactly as its `(after:)` edge already says.

**One consequence of D1 the builder must not overreach on.** D1 governs the **conversational** layer only. Verified in `agent-specific/claude/settings.json`: `Bash(git push:*)` is in `permissions.ask`, so Claude Code raises its own permission prompt on every push no matter what these files say. Making an `update` push literally silent would require narrowing that `ask` rule — a user-level settings change, subject to the live-grant fold-back caveat in `source-push-sync`, and explicitly **not** part of this plan. No subphase may edit `settings.json`; see the residual risk below.

### Risks

- **This change ships unexercised in its own repo.** `agentic` lands work through `push-main` with no PRs at all (`.claude/rules/source-push-sync.md`), so the run that ships this plan will not run the new flow. First real exercise is the next dae run in a consuming project. Mitigation to consider: a scratch-repo dry run of the three stages before relying on it.
- **Prose-only rework has no executable oracle.** The only guards are the acceptance checklists and 3.2's sweep. The specific failure mode is wording drift between lane 1 (the contract) and lane 2 (the callers) — which is why the contract is pinned in this plan rather than discovered by a builder.
- **CI cost and noise.** Pushing after every lane merge triggers a CI run per push in repos with CI on PRs, and a draft PR opened at plan approval contains only a plan file. Both are intended consequences of the user's request, but they are worth naming before rollout.
- **Draft PRs are not universally available** (some repository plans/hosts do not support them). The contract's no-tooling fallback covers it, but the failure surfaces earlier in the run now — at plan approval instead of at ship.
- **Residual risk on D1: the harness prompt still fires per push.** D1's "no confirmation at `update`" is real only at the conversational layer; the `Bash(git push:*)` `ask` entry means the user still sees a permission prompt on every lane-merge push. In practice D1 degrades toward "prompt every time" until the user either uses a session-level "always allow" or narrows that rule themselves. Flagged for the user as a **follow-up outside this plan**, not an open decision — no subphase depends on it, and none may touch `settings.json`.
- **Pre-existing contradictions being fixed in flight** (`push-pr:13` and `cleanup-merged:13` both claim ship tears down the worktree; `push-pr:28`'s "standing permission policy" framing; `worktree-reminder.sh:49`'s "two modes" summary of a single-mode rule; `docs/architecture.md:116` calls the PR gate optional; `SKILL.md:72` cites `verify-run-scope.sh:43` when the line is `106`). These are corrections, not scope creep — each is inside a file the rework already opens — but they should be visible in the review.
- **One pre-existing divergence this plan deliberately does NOT resolve**: `agent-agnostic/rules/push-policy.md` describes a single branch model (`dev` is unconditionally the integration branch) while `orchestrators/hooks/branch-squash-guard.sh` implements two modes (`:346-365` gates Mode A only, and Mode B treats `main` as the integration branch). 1.7 reconciles the hook's *reminder string* to the rule, which is the narrow fix; deciding which branch model is actually correct is a separate question the user should take up on its own. Left as-is, the rule and the guard still disagree after this run.

### Assumptions carried into the build

Not blocking — the decisions above are settled — but each is unverified and a builder that trips over one should stop and surface it rather than improvise.

- GitHub is the only PR host that matters; `gh` + the GitHub MCP are the only mechanisms. Unverified for any consuming project that uses another host.
- `gh` 2.4.0 is a safe floor for `--draft` and `pr ready` (verified locally; not verified across every environment this payload installs into).
- The promoted plan dir is enough of a first commit to open a PR — verified for `build` and `diagnose` (both promote). It is **not** the mechanism for `sync` (no promotion step; its committable content at the confirm gate is the `sync-report.md` the planner wrote into the plan dir) nor for `document` (no plan at all — D2 puts its open after the record commit). A builder implementing 2.4/2.5 must confirm those two workflows really do have something committable at their open point before relying on it.

---

## Skill mapping

| Part | Executed by |
|---|---|
| This plan | `planner` agent, `plan-rework` module (warm through the revision loop) |
| Plan gate | `review-plan` skill (`validate-plan.sh` + reality check) |
| Phase 1 (lane 1) | one `builder` — lane id `l1`, child worktree `feature/draft-pr-ship-flow-l1`; no `contract-tester` (no subphase declares `new contract tests`) |
| Phase 2 (lane 2) | one `builder` — lane id `l2`, child worktree `feature/draft-pr-ship-flow-l2` |
| Phase 3 | serialized in the parent worktree after both lanes merge — dispatched as its own single-lane builder, or run as the integration pass per `build.md` stage 4 |
| Code gate | `review-code` skill |
| Record | `document-local` (`CLAUDE_DOCS_DIR` resolves to a local path here; `/docs` edits in 3.1 are payload-index alignment, and the record stage still owns changelog and any remaining docs reconciliation) |
| PR gate | `review-pr` skill |
| Ship | **`push-main`**, not `push-pr` — this repo has no PRs (`.claude/rules/source-push-sync.md`), and the sync of universal content to `~/.claude/` is mandatory immediately after the push |
