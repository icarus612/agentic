# Plan-artifact lifecycle: dir-per-plan, proposals → active → completed

Rework of where implementation plans and their committed records live, and of the
moves between those states. Type: `rework` (restructure of an artifact convention;
the convention's consumers are ~20 markdown surfaces plus one new script).

## Phase syllabus

- [ ] Phase 1: Normative scheme (the three rules)
  - [x] 1.1: plan-format — plan dir lifecycle, naming, standing dirs      (lane 1)
  - [x] 1.2: artifact-locations — plans dir entry + committed/ephemeral split  (lane 1, after: 1.1)
  - [x] 1.3: run-artifacts — record kinds, negative statements, explore map    (lane 1, after: 1.1)
- [ ] Phase 2: Lifecycle tooling and its direct callers
  - [x] 2.1: plan-lifecycle.sh — promote/archive/supersede/reopen/locate/check  (lane 2)
  - [x] 2.2: review-plan — run `check` at the gate, hand off promotion          (lane 2, after: 2.1)
  - [x] 2.3: cleanup-merged — archive through the script, never archive superseded  (lane 2, after: 2.1)
- [ ] Phase 3: Orchestrator-side wording
  - [ ] 3.1: planner, builder, and the plan-* modules                     (lane 3)
  - [ ] 3.2: dae SKILL.md and its workflow siblings                       (lane 3)
- [ ] Phase 4: Skill wording
  - [ ] 4.1: review-code, review-pr, comment-pr                           (lane 4)
  - [ ] 4.2: document-local, push-pr, explore                             (lane 4)
  - [ ] 4.3: document-confluence (tool-based domain)                      (lane 4)
- [ ] Phase 5: Integration
  - [ ] 5.1: Index tables and repo tree listings   (after: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 3.1, 3.2, 4.1, 4.2, 4.3)
  - [ ] 5.2: This repo's own plans dir scaffolding (after: 1.1, 2.1)
  - [ ] 5.3: Dangling-reference sweep + live `check` run  (after: 5.1, 5.2)

## Goal & scope

**Goal.** Make the home of every plan artifact unambiguous and make the moves
between homes mechanical, so that (a) no agent can plausibly file a plan record in
the gitignored run dir or a builder contract in the plans dir, (b) the plans dir
root never accumulates loose files, and (c) an abandoned or superseded plan cannot
be archived into `completed/` as if it had shipped — the failure that occurred in
the mythic project's "made images fix" plans.

**In scope**
- The three normative rules: `generic/rules/plan-format.md`, `artifact-locations.md`,
  `run-artifacts.md`.
- One new script, `orchestrators/hooks/plan-lifecycle.sh`, plus its fixture test.
- Every skill / agent / workflow file whose wording names a plan path, a record
  filename, or an archive move (enumerated per subphase below, each with the exact
  current line it replaces) — in `generic/`, `orchestrators/`, **and `tool-based/`**.
  The `tool-based/` reach matters: that content is tech-bound and installs into the
  projects that use it rather than into `~/.claude` (`.claude/rules/source-push-sync.md:3`),
  so it is never caught by an install-side sweep and must be enumerated here.
- This repo's own `project-plans/` scaffolding.

**Explicitly out of scope**
- `~/.claude/**`. The install is produced by `sync-install.sh` at ship; no subphase
  writes there. (`sync-install.sh` needs no change: `install_path()` at
  `orchestrators/hooks/sync-install.sh:74-83` already maps any new file under
  `orchestrators/hooks/` to `hooks/<file>`, and a repo-root `tests/` dir is
  unmapped, so it will never be installed.)
- `/docs` in this repo. `docs/conventions.md:126,163,171,181` and
  `docs/pipeline.md:78,98` restate the old scheme and WILL be stale after this
  rework; per the run's shape that alignment belongs to the record stage
  (`document-local`), not to a build phase. The exact stale lines are listed in
  "Hand-off to the record stage" below so nothing is lost.
- Retro-fixing another project's `project-plans/completed/` (mythic). The archive
  guard added here prevents recurrence; cleaning up what already happened there is
  a separate, one-off task.
- Shipping. This repo uses no workflow worktrees and no PRs; landing is
  `push-main` + `sync-install.sh`, the orchestrator's job.
- Any change to the verdict vocabulary, report round format, lane-id scheme, or
  branch naming. Behavior outside artifact placement is frozen.

## Stack & MAJOR versions

Verified from the repo itself — there is no package manifest or lockfile of any
kind (`ls -a` at the repo root shows only `AGENTS.md`, `README.md`, `.claude/`,
`.gitignore`, `docs/`, `generic/`, `orchestrators/`, `project-plans/`,
`tool-based/`, `.workflows/`).

| Component | Version / form | Verified from |
|---|---|---|
| Content | Markdown skill/rule/agent definitions with YAML frontmatter | `generic/rules/plan-format.md:1-5` (frontmatter `name`/`description`/`domain`) |
| Executables | POSIX-ish Bash, `#!/usr/bin/env bash`, `set -uo pipefail`, no `jq` | `orchestrators/hooks/resolve-config.sh:1,30` and its comment at `:22` ("No jq dependency, matching this repo's other hooks") |
| Config resolution | `resolve-config.sh <VAR> [--default v] [--root p]` | `orchestrators/hooks/resolve-config.sh:5` |
| Test framework | **none exists in this repo** | `find . -name '*test*'` returns six hits — `generic/hooks/smart-test.sh`, `generic/hooks/test-changed.sh`, `orchestrators/agents/contract-tester.md`, `tool-based/godot/skills/run-godot-test`, `tool-based/svelte/rules/component-testing.md`, `tool-based/svelte/skills/write-component-test` — none of which is a test framework or a test suite |

## Conventions to enforce

Hard constraints, not suggestions:

1. **Source-only edits.** All changes land in `generic/`, `orchestrators/`,
   `project-plans/`, and a repo-root `tests/` (D4 settled: 2.1's test IS committed).
   Never `~/.claude/**` — `.claude/rules/source-push-sync.md:1-3`.
2. **No jq, no non-Bash dependency** in any script — `resolve-config.sh:22`.
3. **Scripts mutate, callers commit.** `mark-syllabus.sh` mutates the plan file and
   never commits (`orchestrators/hooks/mark-syllabus.sh:43-47`); `plan-lifecycle.sh`
   follows that precedent exactly.
4. **Safe operations only.** `cleanup-merged/SKILL.md:41` — "`-d` not `-D`, no
   `--force` anywhere, nothing removed while it holds unmerged or uncommitted work."
   The new script inherits this: refuse-on-conflict, never overwrite a destination,
   never remove a dir whose contents it did not expect.
5. **Replace, never accumulate.** Every wording subphase DELETES the old sentence it
   replaces. No subphase may leave old and new placement rules side by side; 5.3 is
   the dangling-reference check that proves it.
6. **Tech-agnostic prose.** Rules and skills stay stack-neutral (`tech-agnostic`
   rule); nothing here names a language or framework.
7. **No time estimates anywhere** — `plan-format.md:57`.

## The scheme this rework installs

Everything below is the target state; the subphases implement exactly it.

```
<plans-dir>/                          # CLAUDE_PROJECT_PLANS_DIR, default /project-plans/
  proposals/                          # standing dir — unapproved plans, flat files
    <slug>-MM-DD-YY.md                #   the proposal
    <slug>-MM-DD-YY.plan-review.md    #   its pre-approval gate rounds (sibling)
    <slug>-MM-DD-YY.story.md          #   Confluence-mode requirements capture (sibling)
  <slug>-MM-DD-YY/                    # ACTIVE plan dir — created at approval
    plan.md                           #   the spec of record (the promoted proposal)
    plan-review.md  code-review.md  pr-review.md  story.md  sync-report.md
  completed/                          # standing dir — SHIPPED plans only, flat files
    <slug>-MM-DD-YY.md                #   plan.md, renamed back
```

There are exactly **two** standing dirs. A superseded or abandoned plan has no
directory of its own anywhere: it is DELETED, and git history plus the successor
plan's supersession note are the record (D1, settled at the gate).

- **Spec of record is always `plan.md`**, whatever shape the workflow produces: a
  phased plan for build runs, a ranked candidate report for a diagnose run
  (`orchestrators/agents/planner/plan-diagnosis.md:3` already asserts "The report IS
  the plan" — this makes that literally true on disk). Consequence: **`diagnosis` is
  no longer a record kind.**
- **Record kinds (5):** `story`, `plan-review`, `code-review`, `pr-review`,
  `sync-report`. Inside a plan dir they are named for the kind alone — the dir
  carries the slug and date (D2, settled at the gate).
- **A run with no plan** (the `document` workflow; a Jira-key-only `sync` run) still
  gets a dir `<run-slug-or-jira-key>-MM-DD-YY/` holding only its records; it has no
  `plan.md`, so at closeout nothing is archived and the dir is removed.
- **A sync run reconciling an already-archived plan** reopens it:
  `plan-lifecycle.sh reopen completed/<slug>-MM-DD-YY.md` restores the dir with
  `plan.md`, the run ticks the syllabus and writes `sync-report.md` beside it, and
  closeout re-archives. This is why `reopen` exists.
- **The moves are scripted, never manual.** `archive` refuses a plan whose syllabus
  still holds unchecked subphases — that refusal is the structural fix for the
  mythic incident, not a prompt instruction.

## Phase 1: Normative scheme (the three rules)

Lane 1 owns `generic/rules/` exclusively. 1.2 and 1.3 come after 1.1 because both
cite the layout 1.1 defines; all three are one file each, so they serialize inside
the lane at no cost.

**1.1: plan-format — plan dir lifecycle, naming, standing dirs.**

- **File scope:** `generic/rules/plan-format.md` (only).
- **Current wording being replaced.** Line 8: "Implementation plans are
  self-contained markdown files in the plans dir (see `artifact-locations`)." Line
  10: "**Naming.** `<feature-slug>-MM-DD-YY.md` — slug first, then date (e.g.
  `user-auth-07-06-26.md`). One plan per feature/change; revisions update the same
  file rather than spawning versioned copies." Neither says anything about
  `proposals/`, `completed/`, or a per-plan dir — the lifecycle currently exists
  only as an undocumented directory layout plus one negative mention in
  `cleanup-merged/SKILL.md:31`. That gap is the root defect this rework closes.
- **Pattern to follow.** The rule's existing bullet style: a bolded lead-in, then
  prose; a fenced example block after the bullets (`plan-format.md:29-53`); the
  closing "This rule is format and placement only" line (`:59`) stays last.
- **Change.** Replace line 8's lead sentence with one that points at the layout, and
  replace the `**Naming.**` bullet with a `**Naming.**` + `**Where a plan lives, and
  its lifecycle.**` pair, inserted as the first two bullets so placement is read
  before structure:

  > - **Naming.** A plan is identified by `<feature-slug>-MM-DD-YY` — slug first,
  >   then date (e.g. `user-auth-07-06-26`). One plan per feature/change; revisions
  >   update the same plan rather than spawning versioned copies. That identifier
  >   names the proposal file, then the plan's directory, then its archived file —
  >   it never changes across the lifecycle.
  > - **Where a plan lives, and its lifecycle.** The plans dir root holds NO loose
  >   plan files: only the two standing dirs `proposals/` and `completed/`, and one
  >   directory per plan.
  >   - **Proposal.** An unapproved plan is a single file
  >     `<plans-dir>/proposals/<slug>-MM-DD-YY.md`. Records produced before approval
  >     — the gate's `<slug>-MM-DD-YY.plan-review.md`, a Confluence-mode
  >     `<slug>-MM-DD-YY.story.md` — sit beside it as siblings until it is promoted.
  >   - **Active.** On the user's approval at the plan gate the plan gets its own
  >     directory `<plans-dir>/<slug>-MM-DD-YY/`, and the proposal file becomes that
  >     dir's **`plan.md`** — the run's spec of record, whatever shape the workflow
  >     produced (a phased plan; a diagnose run's ranked candidate report). Its
  >     proposal siblings move in with it under bare kind names. Every later
  >     committed record of the run is written into that same dir; see
  >     `run-artifacts` for the kinds.
  >   - **Completed.** At post-merge closeout ONLY `plan.md` moves, to
  >     `<plans-dir>/completed/<slug>-MM-DD-YY.md` — reclaiming the proposal's name
  >     so `completed/` stays a flat, scannable list of what shipped. The rest of the
  >     dir is removed; the repo's history keeps the records.
  >   - **Superseded or abandoned.** A plan that never shipped NEVER enters
  >     `completed/` — `completed/` means shipped, and nothing else. It is DELETED:
  >     its proposal file, or its whole plan dir, is removed. There is no archive of
  >     abandoned plans, because the repo's history already is one. The obligation
  >     that replaces the file is a **supersession note in the successor**: whatever
  >     plan takes over MUST state, in its Goal & scope section, which plan it
  >     supersedes and why. A plan deleted with nothing naming it is work whose
  >     reasoning is lost; a plan kept "just in case" is the clutter this layout
  >     exists to remove.
  >   - The two standing dirs are never deleted, even when empty.
  >   - **The moves are performed by `plan-lifecycle.sh`** (`promote | archive |
  >     supersede | reopen | locate | check`; install `~/.claude/hooks/`, or the
  >     project's `.claude/hooks/` copy), never by hand. `archive` refuses a plan
  >     that did not ship — that refusal, not anyone's good intentions, is what keeps
  >     an abandoned plan out of `completed/`. `supersede` is the route that refusal
  >     names, and it refuses in turn unless a named successor actually exists and
  >     mentions the plan being superseded, so the note is enforced rather than
  >     merely requested.

  Also amend the **Living document** bullet (`:55`) with one clause: an
  archived plan's syllabus must already reflect reality, since `archive` reads it.
- **Acceptance criteria.**
  1. `plan-format.md` states all four states, the `plan.md` filename, the
     "only `plan.md` moves to completed" rule, the never-archive-superseded rule, and
     the successor's obligation to name what it supersedes and why.
  1b. Exactly two standing dirs are named; no third archive location is introduced.
  2. It names `plan-lifecycle.sh` as the only mover and names the archive guard.
  3. Old line 8 and old line 10 no longer appear verbatim.
  4. No time estimate is introduced; the closing line at `:59` is still last.
  5. Frontmatter `description` (`:3`) updated to mention the lifecycle.
- **Test approach / oracle:** `equivalence check` — diff-read the rule against the
  "scheme this rework installs" section above; every element present, nothing
  contradicting it left behind.

**1.2: artifact-locations — plans dir entry + committed/ephemeral split.**

- **File scope:** `generic/rules/artifact-locations.md` (only).
- **Current wording being replaced.** Line 14 in full: "- **Implementation plans** —
  `CLAUDE_PROJECT_PLANS_DIR`, local default root `/project-plans/`. Structure per
  `plan-format`." That single sentence is the entire statement of where plans live —
  it says nothing about records, and nothing forbids ephemeral files landing there.
- **Pattern to follow.** The sibling bullets at `:10-16`, which each carry the var,
  the default, and the semantics; the Docs bullet (`:10-13`) shows the nested-detail
  style this one should adopt.
- **Change.** Replace `:14` with:

  > - **Implementation plans and their committed records** —
  >   `CLAUDE_PROJECT_PLANS_DIR`, local default root `/project-plans/`. Layout and
  >   lifecycle (proposals → per-plan dir → completed) per `plan-format`; the record
  >   kinds that live in a plan's dir per `run-artifacts`. Everything here is a
  >   COMMITTED repo artifact, and the split with the run dir is absolute in both
  >   directions: a progress log, builder contract, or exit report under the plans
  >   dir is a misfile, and a plan or any of its records under `<workflows-dir>/` is
  >   a misfile the other way.

  Leave `:15` (worktrees) and `:16` (base branch) untouched. Update the frontmatter
  `description` (`:3`) so "plans" reads "plans and their records".
- **Acceptance criteria.**
  1. The plans bullet names both directions of the misfile rule explicitly.
  2. It defers layout to `plan-format` and kinds to `run-artifacts` — no third,
     divergent copy of the layout is introduced here.
  3. The closing prohibition at `:31` ("Never save these artifacts anywhere else…")
     still holds and is unedited.
- **Test approach / oracle:** `equivalence check` — the three rules must be
  mutually consistent and non-duplicating; read 1.1, 1.2, 1.3 together and confirm
  exactly one of them is normative for each fact (layout → plan-format; homes and
  the split → artifact-locations; kinds and formats → run-artifacts).

**1.3: run-artifacts — record kinds, negative statements, explore map.**

- **File scope:** `generic/rules/run-artifacts.md` (only).
- **Current wording being replaced.**
  - `:9` "Every dae run produces files in exactly two places. Nothing a worker, gate,
    or orchestrator needs to hand to another agent may live only in conversation
    context — if another agent (or a resumed run) needs it, it is one of these files,
    and the hand-off passes the file PATH."
  - `:11` heading: "## Committed review records — beside the plan, in the plans dir".
  - `:13` first sentence: "Named `<slug>-MM-DD-YY.<kind>.md` next to the plan they
    belong to (`CLAUDE_PROJECT_PLANS_DIR` chain, default `/project-plans/`); archived
    together with the plan. Kinds: `story` (Confluence requirements capture),
    `diagnosis`, `sync-report`, and the three review reports — `plan-review`,
    `code-review`, `pr-review`." Two things are now wrong here: the naming, and
    "archived together with the plan" (only `plan.md` is archived).
- **Change.**
  1. Heading `:11` → `## Committed plan records — inside the plan's dir`.
  2. Replace the first sentence of `:13` with:
     > A run's committed artifacts live in the plan's own directory
     > (`<plans-dir>/<slug>-MM-DD-YY/`, layout per `plan-format`): the spec of record
     > `plan.md`, plus records named for their kind alone — `story.md` (requirements
     > capture), `plan-review.md`, `code-review.md`, `pr-review.md`,
     > `sync-report.md`. There is no `diagnosis` record kind: a diagnose run's
     > ranked candidate report IS its `plan.md`. A run with no plan (a `document`
     > run; a ticket-only `sync` run) still gets a dir under the plans dir for its
     > records; having no `plan.md`, it archives nothing and the dir is removed at
     > closeout. At closeout ONLY `plan.md` is archived — the records stay in git
     > history, not in `completed/`.
     The remainder of `:13` (append-per-round, `report-verdict.sh`,
     `validate-report.sh`, the verdict/next enums, "A report that fails
     `validate-report.sh` is not a report") is CORRECT and stays verbatim.
  3. Append to `:9` one sentence: "A file that belongs to one home never appears in
     the other: no plan, story, or review record under `<workflows-dir>/`; no
     progress log, contract, or exit report under the plans dir."
  4. Add a fourth bullet to the run-dir section (after `:21`; that section's existing
     bullets are `:19-21`), because the current
     "exactly two places" claim is already false — `generic/skills/explore/SKILL.md:27`
     writes a map to the workflows dir:
     > - **`explore-map-<scope-slug>-<MM-DD-YY>.md`** — the `explore` fork's
     >   structured map, written to the resolved workflows dir (its default when the
     >   caller names no output path). Ephemeral like everything else on this side of
     >   the split, and never the plans dir — a map is not a plan record.
  5. Update the frontmatter `description` (`:3`) accordingly.
- **Acceptance criteria.**
  1. Record kinds are exactly the five named, with bare-kind filenames.
  2. `diagnosis` no longer appears as a record kind anywhere in the rule.
  3. Both negative statements (no records in the run dir; no run files in the plans
     dir) are present.
  4. The explore map is accounted for, so "two homes" is no longer contradicted.
  5. The script-enforcement half of `:13` survives unchanged.
- **Test approach / oracle:** `equivalence check` — as 1.2, read against 1.1/1.2 for
  single-source-of-truth; plus `grep -n 'diagnosis' generic/rules/run-artifacts.md`
  returning only the "no diagnosis record kind" sentence.

## Phase 2: Lifecycle tooling and its direct callers

Lane 2. 2.2 and 2.3 quote the script's exact CLI, so both come after 2.1.

**2.1: plan-lifecycle.sh — promote/archive/supersede/reopen/locate/check.**

- **File scope:** `orchestrators/hooks/plan-lifecycle.sh` (new),
  `tests/plan-lifecycle.test.sh` (new, repo root — D4 settled: committed, and this
  is the repo's first `tests/` dir).
- **Pattern to follow.** `orchestrators/hooks/mark-syllabus.sh` end to end: the
  `#!/usr/bin/env bash` + SYNOPSIS/DESCRIPTION/EXIT CODES comment block (`:1-21`),
  `set -uo pipefail` (`:22`), an `err()` one-liner writing to stderr and exiting 1
  (`:24`), positional-arg validation before any mutation (`:26-29`), and mutation
  that prints its result and never commits (`:43-47`). For flag parsing and config
  resolution follow `resolve-config.sh:34-47` (the `while [ $# -gt 0 ]` loop, `--root`
  handling, `git rev-parse --show-toplevel` fallback to `$PWD`).
- **CLI.**
  ```
  plan-lifecycle.sh <subcommand> [args] [--plans-dir <dir>] [--root <path>] [--dry-run]

    locate <slug>                          state + path of a plan's spec of record
    promote <proposal-file>                proposals/<slug>.md -> <slug>/plan.md
    archive <plan-dir>                     <slug>/plan.md -> completed/<slug>.md, dir removed
    supersede <plan-path> --by <successor> DELETE a plan that never shipped
    reopen <completed-file>                completed/<slug>.md -> <slug>/plan.md
    check [<path>]                         layout conformance of the plans dir (or one plan)
  ```
  - Plans dir resolves via `"$hookdir/resolve-config.sh" CLAUDE_PROJECT_PLANS_DIR
    --default /project-plans/ --root "$root"`, exactly as
    `verify-run-scope.sh:43` does it (that call is the copy-me reference, including
    the `2>/dev/null || echo /project-plans/` fallback).
  - Git-aware: `git mv` / `git rm` when the path is tracked (`git ls-files --error-unmatch`),
    plain `mv` / `rm` otherwise. **Never commits** — callers commit.
  - `--dry-run` prints every move it would make and mutates nothing.
- **Guards (the load-bearing part).**
  1. `promote`: source must be a file under `proposals/`; destination dir must not
     exist. Moves the proposal to `plan.md`, then every
     `proposals/<slug>-MM-DD-YY.<kind>.md` sibling to `<dir>/<kind>.md` for the five
     known kinds. Unknown-kind siblings are reported and left in place, never guessed
     at. Prints the new `plan.md` path on stdout (callers consume it).
  2. `archive`: requires `<dir>/plan.md`; refuses if `completed/<slug>-MM-DD-YY.md`
     already exists. **Completeness guard, two halves** — both must pass, and both
     read the syllabus checkbox states `mark-syllabus.sh:31-37` can write
     (`[x]`, `[done]`, `[dropped]`, `[ ]`):
     - *Unfinished:* any subphase still `- [ ]` → refuse with exit 1, print the
       offending lines, name `supersede` as the correct subcommand.
     - *Nothing shipped:* zero subphases in `[x]` or `[done]` state while one or more
       are `[dropped]` → refuse the same way. `mark-syllabus.sh:14` defines `dropped`
       as "closed without shipping", so an all-dropped plan shipped nothing and
       `completed/` is defined as shipped-and-nothing-else. Without this half the
       mythic failure mode walks straight back in through a side door: tick every
       subphase `dropped`, and an abandoned plan archives cleanly.
     A plan whose syllabus has no subphase checkboxes at all (a diagnose-shaped
     `plan.md` with no checkbox candidates) skips both halves — there is nothing to
     read, and refusing every diagnose run would make the guard noise rather than
     signal. Override is `--force-incomplete <reason>`, which
     requires a non-empty reason and writes `> Archived incomplete: <reason>` into
     the archived file immediately after its title, so the override is permanent and
     visible rather than a silent rubber stamp. After the move, remove the remainder
     of the dir; refuse to remove anything that is not a known record kind, naming it.
  3. `supersede` (D1 = delete outright): **deletes** the target — a proposal file, or
     a whole plan dir — and moves nothing. There is no `superseded/` dir; the script
     must never create one. Requires `--by <successor>`, and **refuses unless that
     successor file exists AND its text mentions the superseded plan's slug**: the
     rule says the successor must record what it supersedes and why, and this is what
     makes that mechanical instead of aspirational. Refuses if the target is under
     `completed/` (something that shipped is not superseded — `reopen` it or leave it
     alone). Prints exactly what it deleted, so the caller's commit message can say so.
  4. `reopen`: source under `completed/`; destination dir must not exist.
  5. `check` (D5 = hard fail): plans-dir root contains no files except `README.md` and
     dotfiles; every non-standing entry is a `<slug>-MM-DD-YY/` dir; each plan dir
     contains at most `plan.md` plus known record kinds; `proposals/` holds only
     `<slug>-MM-DD-YY[.<kind>].md` files and no subdirs; `completed/` holds only
     `<slug>-MM-DD-YY.md` files; no slug exists in two states at once. One `FAIL:`
     line per violation, **exit 1 — including for a pre-existing flat layout in a
     project that predates this scheme**; there is no advisory/legacy severity, and
     `review-plan` treats any `FAIL:` as a structural gate failure (2.2). A loud
     failure forces the one-time migration; a soft one lets mixed layouts live
     forever, which is the state this rework exists to end. `OK:` summary on success
     — the exact output contract of `validate-plan.sh:29,107-110` and
     `validate-report.sh:41,84`.
- **Acceptance criteria.**
  1. Every subcommand implements its guards; `bash -n` clean; no `jq`.
  2. `archive` on a plan with one unchecked subphase exits 1 and names `supersede`.
  2b. `archive` on a plan whose subphases are all `[dropped]` exits 1 and names
     `supersede`; the same plan with one `[x]` among the drops archives normally.
  3. `archive --force-incomplete "<reason>"` succeeds and the archived file carries
     the `> Archived incomplete:` line.
  4. `promote` on a proposal with a `.plan-review.md` sibling produces a dir with
     `plan.md` + `plan-review.md` and leaves `proposals/` free of that slug.
  4b. `supersede` deletes the target and exits 0 when the successor exists and names
     the slug; exits 1 leaving the target intact when the successor is missing, or
     exists but never mentions the slug. No `superseded/` dir is created by any
     subcommand, ever.
  5. `check` flags, each with exit 1: a loose file at the plans-dir root; a stray kind
     inside a plan dir; the same slug in both `proposals/` and `completed/`; an
     entirely flat legacy plans dir (no advisory severity exists).
  6. Every mutating subcommand is a no-op under `--dry-run`.
  7. No subcommand ever runs `git commit`, `git push`, `rm -rf` outside the
     resolved plans dir, or any `--force`.
- **Test approach / oracle:** `new contract tests`. The test builds a throwaway git
  repo under the scratch dir with a synthetic plans dir (a proposal + sibling
  review, a complete active plan, an incomplete active plan, an **all-dropped**
  active plan, a checkbox-free diagnose-shaped plan, an archived plan, a successor
  plan that names a slug and one that does not, and two deliberate layout
  violations), runs each subcommand, and asserts exit codes,
  stdout, and the resulting tree. It must cover the refusal paths, not only the
  happy paths — the refusals are the feature. The test is written from this
  subphase's CLI and guard contract alone, never from the finished script.

**2.2: review-plan — run `check` at the gate, hand off promotion.**

- **File scope:** `generic/skills/review-plan/SKILL.md` (only —
  `scripts/validate-plan.sh` is deliberately untouched; the layout check lives in
  `plan-lifecycle.sh` because only that script sits beside `resolve-config.sh` and
  can resolve the plans dir).
- **Current wording being replaced.** `:17` "After the `planner` worker has written a
  plan to `/project-plans/` (or `CLAUDE_PROJECT_PLANS_DIR` if set)."; `:23` "You
  receive the plan path (`/project-plans/`, or `CLAUDE_PROJECT_PLANS_DIR` if set)…";
  `:27` step 1 "Read it from `/project-plans/` (or `CLAUDE_PROJECT_PLANS_DIR` if
  set)."; `:35` step 9 "…`<slug>-MM-DD-YY.plan-review.md` beside the plan…"; `:41`
  hand-off "**Approved:** recommend approval. Once the user signs off at the
  caller's gate, the caller switches to auto mode and dispatches builder lanes from
  the syllabus."; `:50` "Plans live in `/project-plans/` (or
  `CLAUDE_PROJECT_PLANS_DIR` if set); never invent a plan that isn't written down."
- **Change.**
  - `:17`, `:23`, `:27`, `:50` — the plan path is now
    `<plans-dir>/proposals/<slug>-MM-DD-YY.md` before approval and
    `<plans-dir>/<slug>-MM-DD-YY/plan.md` after; the gate reads whichever path it was
    handed and must not assume the pre-approval one (post-approval amendment rounds
    re-enter this gate against `plan.md`).
  - `:28` step 2 — add `plan-lifecycle.sh check <plan-path>` alongside
    `validate-plan.sh`, with the same consequence the step already states for the
    existing script: any `FAIL:` line fails the gate structurally, output quoted
    verbatim in the verdict. Per D5 this holds for a legacy flat layout too — a
    project adopting this library meets the gate failure once and migrates; the gate
    must NOT be written to excuse pre-existing layouts.
  - `:35` step 9 — the report path is
    `<plans-dir>/proposals/<slug>-MM-DD-YY.plan-review.md` for a pre-approval round
    and `<plans-dir>/<slug>-MM-DD-YY/plan-review.md` afterwards; state that the
    caller supplies it and the gate does not compute it from a remembered layout.
  - `:41` — extend the Approved hand-off: recommend that the caller, after the
    user's sign-off, run `plan-lifecycle.sh promote <proposal-path>` and dispatch
    against the printed `plan.md` path. Keep the existing framing that a fork cannot
    perform the hand-off itself (`:39`).
- **Acceptance criteria.** No occurrence of `/project-plans/` as a bare plan
  location remains; the promotion hand-off is stated in the Approved bullet;
  `plan-lifecycle.sh check` is wired into step 2 with its failure consequence; the
  report path is described for both pre- and post-approval rounds.
- **Test approach / oracle:** `equivalence check` — walk the skill against the target
  scheme; confirm nothing instructs writing a record to a path the new layout forbids.

**2.3: cleanup-merged — archive through the script, never archive superseded.**

- **File scope:** `generic/skills/cleanup-merged/SKILL.md` (only).
- **Current wording being replaced.** `:31` step 5 in full: "**Archive the plan.**
  Move the plan and its committed review records
  (`.story`/`.diagnosis`/`.sync-report`/`.plan-review`/`.code-review`/`.pr-review`
  siblings) from the plans dir into `<plans-dir>/completed/` (creating it if absent —
  it is a standing dir; never delete an empty `proposals/`). This is a repo change:
  commit it on a fresh `sync/cleanup-<name>` branch off the base (never commit to the
  base branch directly, per push-policy) and offer the caller the `push-pr` route for
  it — or leave the commit local if declined." This is the exact behavior that
  produced the mythic incident: it moves records into `completed/` alongside the
  plan, and it has no notion of a plan that never shipped. Also `:13` ("plans sitting
  in the active plans dir long after they shipped") and `:3`/description and `:37`
  ("plan location") reference the old shape.
- **Change.** Rewrite step 5 as:

  > 5. **Archive the plan.** Run `plan-lifecycle.sh check <plans-dir>` first; a
  >    `FAIL:` line means the layout is already off — surface it and stop rather than
  >    moving anything. Then `plan-lifecycle.sh archive <plans-dir>/<slug>-MM-DD-YY/`:
  >    ONLY `plan.md` moves, to `completed/<slug>-MM-DD-YY.md`, and the rest of the
  >    dir is removed. If the script refuses because the syllabus still has unchecked
  >    subphases, that is the correct answer and NOT something to force: an unfinished
  >    plan whose branch merged means the run closed differently than planned — take it
  >    back to the user, who decides between finishing the syllabus ticks and
  >    superseding the plan. **`completed/` means shipped. A plan that was replaced,
  >    abandoned, or superseded by a later plan never goes there** — its route is
  >    `plan-lifecycle.sh supersede --by <successor>`, which DELETES it outright (git
  >    history and the successor's supersession note are the record; there is no
  >    archive of abandoned plans). That is a user decision, not this skill's call:
  >    surface the refusal and stop. The two standing dirs (`proposals/`,
  >    `completed/`) are never deleted, empty or not. A
  >    run with no `plan.md` archives nothing; its record dir is simply removed. This
  >    is a repo change: commit it on a fresh `sync/cleanup-<name>` branch off the base
  >    (never commit to the base branch directly, per push-policy) and offer the caller
  >    the `push-pr` route for it — or leave the commit local if declined.

  Update `:3` (frontmatter description) and `:13` to match; `:37`'s "plan location"
  sentence stays but should read against the new states.
- **Acceptance criteria.**
  1. The archive step invokes the script and never describes a manual move.
  2. The "refusal is the correct answer" instruction is explicit — no `--force-incomplete`
     is suggested to this skill at all.
  3. The never-archive-superseded rule appears in this skill, not only in the rules,
     and names deletion (not a move) as the alternative route.
  4. The safe-deletes note at `:41` still governs; nothing added contradicts it.
- **Test approach / oracle:** `equivalence check`, plus a read-through against 2.1's
  guard list confirming every refusal the script can emit has a stated handling here.

## Phase 3: Orchestrator-side wording

Lane 3 owns `orchestrators/agents/` and `orchestrators/skills/dae/`. Pure wording;
no file is shared with another lane.

**3.1: planner, builder, and the plan-* modules.**

- **File scope:** `orchestrators/agents/planner.md`,
  `orchestrators/agents/planner/plan-diagnosis.md`,
  `orchestrators/agents/planner/plan-reconcile.md`,
  `orchestrators/agents/builder.md`.
- **Current wording being replaced.**
  - `planner.md:13`: "**`plan-format` exactly.** Save to the plans dir
    (`CLAUDE_PROJECT_PLANS_DIR` chain, default `/project-plans/`), named
    `<slug>-MM-DD-YY.md`." → must become `…/proposals/<slug>-MM-DD-YY.md`, with the
    added statement that after approval the plan is at
    `<plans-dir>/<slug>-MM-DD-YY/plan.md` and amendment messages carry that path —
    the planner writes wherever its caller points it and never re-derives the path
    from memory across the promotion boundary.
  - `planner.md:3` (frontmatter description): "writes the implementation plan to the
    plans dir per plan-format" → name `proposals/`.
  - The revision-loop section of `planner.md` ("Corrections from the gate or the user
    arrive as follow-up messages; apply them as amendments to the SAME plan file")
    gains one clause: the same plan, at whatever path the correction names — a
    promotion changes the path, never the identity.
  - `plan-diagnosis.md:3`: "The deliverable is NOT a phased plan: it is a **ranked
    candidate-cause report**, written to the plans dir as
    `<slug>-MM-DD-YY.diagnosis.md`. The report IS the plan" → the report is written
    as `proposals/<slug>-MM-DD-YY.md` and becomes the run's `plan.md` on promotion;
    keep the "report IS the plan" framing, which this scheme now makes literal.
  - `plan-reconcile.md:3`: "The deliverable is a **reconciliation report** —
    `<slug>-MM-DD-YY.sync-report.md` next to the plan it reconciles" → written as
    `sync-report.md` inside the reconciled plan's dir; if that plan is already in
    `completed/`, the caller reopens it first (`plan-lifecycle.sh reopen`) and passes
    the restored path — the planner never writes into `completed/`.
  - `builder.md:7`: "You receive an approved plan path (in `/project-plans/`, or
    `CLAUDE_PROJECT_PLANS_DIR` if set)" → an approved plan path
    (`<plans-dir>/<slug>-MM-DD-YY/plan.md`); a builder is only ever dispatched
    post-approval, so it never sees a proposal. Reinforce the existing constraint
    that a builder never edits the plan file (`build-dispatch.md:24`) with its
    location corollary: a builder never moves a plan between states either — the
    lifecycle belongs to the orchestrator and to `cleanup-merged`.
- **Acceptance criteria.** All five path statements updated; the "never write into
  `completed/`" constraint present in `plan-reconcile`; the never-move corollary
  present in `builder.md`; no module re-derives a plan path from a slug.
- **Test approach / oracle:** `equivalence check`.

**3.2: dae SKILL.md and its workflow siblings.**

- **File scope:** `orchestrators/skills/dae/SKILL.md`, `build.md`, `build-dispatch.md`,
  `diagnose.md`, `sync.md`, `confluence-mode.md`, `worktree-modes.md`.
- **Current wording being replaced.**
  - `SKILL.md:58` (PR gate): "the report path (`<slug>-MM-DD-YY.pr-review.md` beside
    the plan, or named after the run slug when there is no plan)" → `<plan-dir>/pr-review.md`,
    or `<plans-dir>/<run-slug-or-jira-key>-MM-DD-YY/pr-review.md` for a plan-less run.
  - `SKILL.md:68` (invariant): "You own the plan file during the build: builders never
    edit it; your syllabus ticks go through `mark-syllabus.sh`." → add that the
    orchestrator also owns the plan's LOCATION, and that every state move goes
    through `plan-lifecycle.sh` — promotion right after the user's approval, nothing
    else moved by hand.
  - `SKILL.md:69` (amendability invariant): note that a promotion changes the plan
    path mid-run, so amendment messages to the warm planner and every later gate
    invocation must carry the current path, and the progress log records it.
  - `SKILL.md:70`/`:72`: the progress log must record the plan's current path and
    state; the harness-scoped write allowance already covers the plans dir
    (`verify-run-scope.sh:43` allows the whole resolved plans dir, so promotion
    commits inside a run's diff are not flagged — no script change needed there, but
    say so).
  - `build.md:11` step 3: "Only after explicit approval, switch to auto mode." → after
    explicit approval, FIRST `plan-lifecycle.sh promote <proposal-path>`, then switch
    to auto mode and dispatch against the printed `plan.md` path. Step 2 (`:9`) must
    also say the planner writes to `proposals/`.
  - `diagnose.md:9`: "writes the ranked diagnosis report to the plans dir" → to
    `proposals/`; `:11` step 3 (pick gate) gains the same promotion step as build's
    step 3 — including the **none-picked** branch at `:11`, where the report is the
    deliverable: promote it anyway so the run has a `plan.md` to ship and archive.
  - `sync.md:7`: "which plan (`<plans-dir>/<slug>-MM-DD-YY.md`)" → the plan's current
    location, resolvable with `plan-lifecycle.sh locate <slug>`; if it is in
    `completed/`, `reopen` it before the run writes anything, and re-archive at
    closeout. "Resolve the Jira key from the plan's sibling story file" → from the
    plan dir's `story.md`.
  - `sync.md:9`: "writes the reconciliation report next to the plan" → as
    `sync-report.md` in the plan's dir.
  - `confluence-mode.md:18`: "write the capture as `<slug>-MM-DD-YY.story.md` in the
    plans dir … It sits next to the future plan file" → as
    `proposals/<slug>-MM-DD-YY.story.md`, moving into the plan dir as `story.md` at
    promotion.
  - `worktree-modes.md:11`: "a plan with a partially-ticked syllabus → re-enter
    dispatch…; a plan not yet approved → the plan gate" → resolve where the plan
    actually is with `plan-lifecycle.sh locate <name>`; its state IS the resume
    signal (proposal → plan gate; active dir → dispatch; completed → nothing to
    resume). "an existing story file counts as captured requirements" → the story
    file at either of its two possible paths.
  - `build-dispatch.md:24`: "Each builder gets: the plan path (or diagnosis report
    path)" → just the plan path (`<plan-dir>/plan.md`); the parenthetical goes stale
    the moment a diagnose run's report IS `plan.md`, and it is phrased so that none
    of 5.3's grep patterns would catch it — this is the one surface that must be
    fixed by enumeration rather than by the sweep. `:16`'s `mark-syllabus.sh <plan>`
    invocation stays correct (the script takes a path).
- **Acceptance criteria.** Every one of the above lines updated; promotion appears
  exactly once per workflow (build step 3, diagnose step 3) and nowhere else; no dae
  file describes a manual move; the plan-path-changes-mid-run consequence is stated
  in the invariants, not only in the workflow files.
- **Test approach / oracle:** `equivalence check`, plus a trace of one full build run
  and one full diagnose run through the edited files confirming the plan path named
  at each stage is the path that stage would actually find.

## Phase 4: Skill wording

Lane 4 owns the remaining `generic/skills/` consumers (review-plan and
cleanup-merged belong to lane 2 and are excluded here) plus the one `tool-based/`
consumer in 4.3.

**4.1: review-code, review-pr, comment-pr.**

- **File scope:** `generic/skills/review-code/SKILL.md`,
  `generic/skills/review-pr/SKILL.md`, `generic/skills/comment-pr/SKILL.md`.
- **Current wording being replaced.**
  - `review-code/SKILL.md:23` "You receive via invocation args the plan path
    (`/project-plans/`, or `CLAUDE_PROJECT_PLANS_DIR` if set)…" and `:27` step 1
    "Read the plan from `/project-plans/` (or `CLAUDE_PROJECT_PLANS_DIR` if set)." →
    the plan path is `<plans-dir>/<slug>-MM-DD-YY/plan.md` (this gate always runs
    post-approval); it reads the path it was handed and never re-derives one.
  - `review-code/SKILL.md:34` step 8: "`<slug>-MM-DD-YY.code-review.md` beside the
    plan" → `code-review.md` in the plan's dir. The rest of the step (verdict
    vocabulary, `report-verdict.sh`, `validate-report.sh`, kickback codes) is correct
    and must survive verbatim.
  - `review-pr/SKILL.md:27`: the spec-of-record list names "a diagnosis report" as a
    distinct document → a diagnose run's spec of record is its `plan.md`; keep the
    prose name "diagnosis report" but point at the file.
  - `review-pr/SKILL.md:28`: "**Report path**: … `<slug>-MM-DD-YY.pr-review.md`
    beside the plan (or `<jira-key>-MM-DD-YY.pr-review.md` in the plans dir when
    there is no plan)" → `pr-review.md` in the plan's dir, or
    `<plans-dir>/<jira-key>-MM-DD-YY/pr-review.md` when there is no plan. The
    append-a-round-never-overwrite rule stays.
  - `comment-pr/SKILL.md:23`: "the report path (`<slug>-MM-DD-YY.pr-review.md`)" →
    `<plan-dir>/pr-review.md`. This skill only consumes a path it is handed; the
    change is one filename in an example.
- **Acceptance criteria.** All five references updated; no verdict/enum/round text
  altered anywhere; each gate is stated to use the path it is handed.
- **Test approach / oracle:** `equivalence check`.

**4.2: document-local, push-pr, explore.**

- **File scope:** `generic/skills/document-local/SKILL.md`,
  `generic/skills/push-pr/SKILL.md`, `generic/skills/explore/SKILL.md`.
- **Current wording being replaced.**
  - `document-local/SKILL.md:29` "the plan path in `/project-plans/`", `:31` "the
    plan path in `/project-plans/`, and the path to the **reconciliation report**
    (`<slug>-MM-DD-YY.sync-report.md`, next to the plan)", `:39` "Check the plan in
    `/project-plans/`" → the plan dir's `plan.md` and its `sync-report.md`. `:39`'s
    syllabus-ticking instruction is unchanged in substance and must survive: this
    skill is what makes a plan archivable or not, since 2.1's `archive` guard reads
    those ticks in both directions (`[ ]` blocks; all-`[dropped]` blocks) — add that
    one sentence so the coupling is visible, and so accurate `[dropped]` marking is
    understood as load-bearing rather than cosmetic.
  - `push-pr/SKILL.md:27` "If straggler artifacts (plans, docs) are uncommitted…" →
    stays, but name the plan dir so a promotion's rename is understood as a straggler
    to commit; `:40`'s pointer to `cleanup-merged` for "the plan archive" stays.
  - `explore/SKILL.md:27`: the map's default output path (workflows dir) is correct
    and unchanged — add only the negative clause that the map is never written to the
    plans dir, matching 1.3's new bullet. `:66`'s "(Docs/plans locations come only
    from `CLAUDE_DOCS_DIR`/`CLAUDE_PROJECT_PLANS_DIR` env vars or their defaults —
    never from these files.)" is correct and stays.
- **Acceptance criteria.** Plan/record paths updated; the document skill states the
  ticks-enable-archive coupling; explore's map placement is stated once, consistent
  with 1.3; nothing about the docs tree, mirroring, or symlinks is touched.
- **Test approach / oracle:** `equivalence check`.

**4.3: document-confluence (tool-based domain).**

- **File scope:** `tool-based/confluence/skills/document-confluence/SKILL.md` (only).
- **Why it is its own subphase.** This is the sole `tool-based/` consumer of the plan
  layout, and it is structurally easy to miss: `tool-based/` content is tech-bound
  (`domain: confluence`), installs into the projects that use Confluence rather than
  into `~/.claude`, and is skipped entirely by `sync-install.sh` — so nothing on the
  install side would ever surface the drift. Naming it separately makes the omission
  impossible rather than merely unlikely.
- **Current wording being replaced.**
  - `:28` **Change-driven** input list: "the plan path in `/project-plans/`, the story
    file path (`<slug>-MM-DD-YY.story.md` next to the plan — original ask verbatim,
    narrative, acceptance criteria, constraints, stakeholders)" → the plan dir's
    `plan.md` and its `story.md`. The parenthetical describing the story file's
    CONTENTS is correct and stays.
  - `:30` **Reconciliation-driven** input list: "the plan path (if one exists), the
    reconciliation report path, and the resolved Jira issue key(s) — resolved by
    `sync-status` from either a user-supplied key or a sibling story file next to the
    plan" → the plan dir's `plan.md` (if one exists) and its `sync-report.md`; the
    Jira key resolved from the plan dir's `story.md`. The rest of `:30` — story file
    OPTIONAL in this shape, Jira key MANDATORY, needs-input rather than inference —
    is correct and must survive verbatim.
  - Note for the executor, NOT to fix here: `:30` also names a `sync-status`
    orchestrator that no longer exists (the workflow is `dae --type sync`). That is a
    real staleness but a different defect; leave it, and surface it as a non-blocking
    observation in the exit report rather than widening this rework.
- **Acceptance criteria.**
  1. Both input lists name the plan dir's `plan.md`, `story.md`, `sync-report.md`.
  2. No `<slug>-MM-DD-YY.<kind>.md` form and no "next to the plan" phrasing remains.
  3. The optional-story / mandatory-key / needs-input logic at `:30` is unchanged.
  4. Nothing about Confluence targets, spaces, parent pages, or Drive folders is
     touched, and the file's `domain:` frontmatter is unchanged (it stays tool-based).
- **Test approach / oracle:** `equivalence check`.

## Phase 5: Integration

Serialized. 5.1 touches the index tables every lane feeds — the shared-touchpoint
files that must never be edited from two lanes. 5.3 is this rework's mandatory
dangling-reference check.

**5.1: Index tables and repo tree listings.**

- **File scope:** `generic/AGENTS.md`, `orchestrators/AGENTS.md`, and the repo-root
  `README.md` and `AGENTS.md` tree listings (`README.md:31`, `AGENTS.md:13` show the
  tree; D4 is settled, so the new `tests/` dir belongs in it — unconditionally).
- **Current wording being replaced.**
  - `generic/AGENTS.md:25` "| `artifact-locations` | Where docs, plans, and worktrees
    live (config-resolved)…"; `:27` "| `plan-format` | How plans are named, phased,
    and kept current. |"; `:28` "| `run-artifacts` | Where run files live: committed
    review records beside the plan; the gitignored run dir…"; `:46`/`:47`/`:48` (the
    `.plan-review.md` / `.code-review.md` / `.pr-review.md` record names); `:52` "|
    `cleanup-merged` | … plan + review records archived to `completed/` …".
  - `orchestrators/AGENTS.md:29` "scope checks, plan schema, install sync — all
    scripted" → add the plan lifecycle to the scripted list; `:103` (the planner row)
    "writes the plan/report per `plan-format`" → name `proposals/`.
- **Change.** One-line-per-row table updates only; these files are indexes, so they
  restate, never define. `:52` in particular must say ONLY `plan.md` is archived.
- **Acceptance criteria.** Every index row agrees with the phase-1 rules; no index
  introduces a fact the rules do not state.
- **Test approach / oracle:** `equivalence check`.

**5.2: This repo's own plans dir scaffolding.**

- **File scope:** `project-plans/proposals/.gitkeep` (existing, verify);
  `project-plans/completed/` (verify only — no edits expected). **No new directory is
  created:** D1 settled as delete-outright, so there is no `superseded/` dir here or
  in any other project, and this subphase must not create one.
- **Findings this subphase confirms rather than changes.** The two files already in
  `completed/` — `master-redesign-07-26-26.md` and `pr-review-contract-08-08-26.md`
  — already match the target `<slug>-MM-DD-YY.md` archived-plan shape exactly, and
  both are plans (not records). **No touch-up is needed**, and the archived-name
  choice in 1.1 was made partly so they stay conformant. `proposals/.gitkeep` exists
  and the empty-`proposals/` convention stays (now extended to all three standing
  dirs).
- **Acceptance criteria.** `plan-lifecycle.sh check` (from 2.1) run against this
  repo's `project-plans/` exits 0. The two completed files are unmodified. No plan
  content is edited by this subphase.
- **Test approach / oracle:** `existing suite` — the oracle is 2.1's own `check`
  subcommand run against real data; a non-zero exit is a failure of this subphase.

**5.3: Dangling-reference sweep + live `check` run.**

- **File scope:** no file is edited by default; any residue this sweep finds is
  fixed in place in the file that carries it.
- **The sweep.** From the repo root, over `generic/ orchestrators/ tool-based/` plus
  root `README.md`/`AGENTS.md` — i.e. every source dir, since `tool-based/` consumers
  are invisible to any install-side check — each pattern must return either zero hits
  or only hits that the new scheme sanctions:
  - `MM-DD-YY\.(story|diagnosis|sync-report|plan-review|code-review|pr-review)\.md`
    → zero (the old record-naming form is gone).
  - `beside the plan` → zero outside `proposals/`-sibling contexts.
  - `\.diagnosis\.md` → zero (the kind no longer exists).
  - `/project-plans/` → only as the documented DEFAULT VALUE of
    `CLAUDE_PROJECT_PLANS_DIR`, never as "where the plan file is".
  - `completed/` → only in contexts that say shipped-only.
  - `project-plans` bare → reviewed hit by hit.
  Cross-check the result against the surface inventory in this plan: every file named
  in a phase-1-through-4 subphase must appear in at least one post-edit grep for the
  NEW scheme, proving it was actually edited. **The cross-check only proves ENUMERATED
  files were touched — it cannot discover an un-enumerated one.** Two surfaces are
  known to be invisible to the six patterns and are covered by enumeration alone
  (`build-dispatch.md:24`'s "(or diagnosis report path)"; `document-confluence:30`'s
  "sibling story file next to the plan"); if the sweep finds any further phrasing in
  that class, add it to the pattern list rather than fixing it silently.
- **Also run:** `bash -n` on `plan-lifecycle.sh`; the 2.1 fixture test; and
  `plan-lifecycle.sh check` against this repo's `project-plans/`.
- **Acceptance criteria.** All six patterns clean; every named surface shows new-scheme
  wording; the three commands exit 0; no file states the old placement rule alongside
  the new one anywhere in the repo.
- **Test approach / oracle:** `equivalence check` — this subphase IS the deletion
  proof that the rework module requires for every replaced structure.

## Hand-off to the record stage (not a build phase)

`/docs` alignment is the run's `document-local` stage. The lines it must reconcile,
found in this rework's grep sweep and deliberately left to it:

- `docs/conventions.md:126` — "beside the plan
  (`<slug>-MM-DD-YY.{story,diagnosis,sync-report,plan-review,code-review,pr-review}.md`)".
- `docs/conventions.md:163` — the artifact-locations table row for implementation plans.
- `docs/conventions.md:171` — "Filename `<feature-slug>-MM-DD-YY.md`; phase syllabus first…".
- `docs/conventions.md:181` — "a sibling story file (`<feature-slug>-MM-DD-YY.story.md`)".
- `docs/pipeline.md:78` — "their verdict rounds to committed report files beside the plan".
- `docs/pipeline.md:98` — "persisted as a `.story.md` beside the plan".

## Risks, open questions, decision points

**Risks**

- **R1 — a missed surface is worse than no change.** A single file left saying
  "beside the plan" is an instruction an agent will follow, producing exactly the
  mixed layout this rework removes. Round 1 of the plan gate proved this risk is
  live, not theoretical: `tool-based/confluence/skills/document-confluence/SKILL.md`
  was missed by the first draft precisely because it sits outside the two source dirs
  everything else lives in. Mitigated on two independent tracks, because neither is
  sufficient alone: (a) 5.3's grep patterns, now run over ALL source dirs including
  `tool-based/`, catch phrasings that mention a path or a record filename; (b) the
  per-subphase enumeration catches phrasings that mention neither and are therefore
  ungreppable (`build-dispatch.md:24`, `document-confluence:30`). A surface must be
  covered by (a) or (b); the sweep alone is not a safety net.
- **R2 — the new script performs destructive git operations on the user's plans.**
  Mitigated by: refuse-on-conflict everywhere, `--dry-run`, no `--force`/`rm -rf`
  outside the resolved plans dir, and a fixture test that exercises the refusal paths
  (the refusals are the product).
- **R3 — the plan path changes mid-run**, at promotion. Anything holding the old path
  (the warm planner, the progress log, a queued gate invocation) breaks silently.
  Mitigated by 3.2's explicit invariant: the current path lives in the progress log
  and travels in every message; no agent re-derives a path from a slug.
- **R4 — cross-project blast radius.** These rules are universal-domain and sync to
  `~/.claude`, so every project using this library adopts the new layout at the next
  push. Existing projects have flat plans dirs that `check` will immediately flag.
  D5 settled this deliberately in favour of the loud option: `check` hard-fails on a
  legacy layout and `review-plan` treats it as a structural gate failure, so the next
  planning run in each adopting project stops until its plans dir is migrated. This
  is an accepted cost, not an oversight — the alternative lets mixed layouts persist
  indefinitely. Executors should expect the first post-adoption run in any consuming
  project to begin with a one-time migration.
- **R5 — self-reference.** This plan is itself a proposal under the OLD convention
  and will be the first artifact promoted under the new one; the promotion must
  happen with the script this plan creates, i.e. after phase 2 lands.

**Assumptions — carried to the gate and left standing (no user objection in round 2);
they remain assumptions, so a builder that finds one false stops and reports it**

- **A1.** "The user's thumbs-up" is the dae plan gate approval (`build.md:11` step 3,
  `diagnose.md:11` step 3). Standalone planning outside dae has no orchestrator; the
  rules put promotion on whoever ran the gate. Not independently verifiable — confirm.
- **A2.** A diagnose run's ranked report becoming `plan.md` is the right unification.
  It makes `plan-diagnosis.md:3`'s "The report IS the plan" literal and removes a
  record kind, but it does rename a document six places call "the diagnosis report".
- **A3.** A `sync` run against an archived plan should reopen it. Inferred from
  `sync.md:13`, where the record stage ticks the reconciled plan's syllabus — which
  requires the plan to be writable and then re-archived. Not stated anywhere today.

**Decisions — SETTLED by the user at the plan gate (round 2). Not reopenable by an
executor; a subphase that contradicts one of these is wrong, not creative.**

- **D1 — fate of superseded plans: DELETE OUTRIGHT.** There is no `superseded/`
  directory, in this repo or in any consuming project, and no subcommand may create
  one. A plan that never shipped has its proposal file or its whole plan dir deleted;
  git history is the archive. The obligation that replaces the file is a
  **supersession note in the successor plan** — which plan it replaces and why — and
  `plan-lifecycle.sh supersede` enforces that mechanically by refusing unless the
  named successor exists and mentions the superseded slug. Baked into 1.1 (the rule),
  2.1 (guard 3), 2.3 (the refusal route), 5.2 (no dir created).
- **D2 — record filenames inside a plan dir: BARE KIND NAMES.** `plan.md`,
  `plan-review.md`, `code-review.md`, `pr-review.md`, `story.md`, `sync-report.md`.
  The dir carries the slug and date; the filenames do not repeat them.
- **D3 — the rest of the dir at archive: DELETED.** Only `plan.md` moves, to
  `completed/<slug>-MM-DD-YY.md`; the records go with the dir. `completed/` stays a
  flat, scannable list of what shipped, and git history holds the review trail.
- **D4 — the lifecycle script's test is COMMITTED**, at `tests/plan-lifecycle.test.sh`.
  This is the repo's first `tests/` dir, accepted deliberately: the script performs
  destructive git operations and its archive guard is the entire structural fix for
  the mythic incident, so an unverified guard would be no guard at all. A repo-root
  `tests/` matches no arm of `sync-install.sh`'s `install_path()` (`:74-83`), so it
  never reaches `~/.claude`.
- **D5 — `check` severity on legacy layouts: HARD FAIL.** One `FAIL:` line per
  violation and exit 1, with no advisory or `LEGACY:` severity, including for a
  pre-existing flat plans dir; `review-plan` treats any `FAIL:` as a structural gate
  failure. Consequence accepted in R4: the first planning run in each adopting
  project stops until that project's plans dir is migrated.

## Skill mapping

| Work | Executor |
|---|---|
| 1.1–1.3 rules, 2.2–2.3, 3.x, 4.x, 5.1 wording | `builder` lanes → `coder` sub-agents (markdown only; no contract-tester, oracle is `equivalence check`) |
| 2.1 `plan-lifecycle.sh` + fixture test | `builder` lane → `coder` for the script, `contract-tester` for the fixture test (oracle `new contract tests`; the tester works from the CLI + guard contract in 2.1, never from the script) |
| 5.2, 5.3 | `builder` (integration lane, run in the parent) |
| Plan gate | `review-plan` (+ `validate-plan.sh`, and `plan-lifecycle.sh check` once 2.1 lands) |
| Code gate | `review-code` |
| Docs alignment (out of plan scope) | `document-local` at the record stage, against the line list above |
| Ship | `push-main` + `sync-install.sh <range>` — orchestrator's job for this repo; no worktree, no PR, no `push-pr`, no `cleanup-merged` |
