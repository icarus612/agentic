# Proof — did the last five plans actually land?

## Claim under test

Verbatim, exactly as fixed at stage 3 (`claim.md`), before any evidence was gathered:

> For each of the five most recent plans whose implementation landed on `main` —
> `prove-type-and-ship-axis-08-26-26`, `dae-live-type-08-26-26`,
> `report-pipeline-and-locations-08-26-26`, `dae-axes-restructure-08-23-26`, and
> `draft-pr-ship-flow-08-17-26` — **every subphase its syllabus marks as completed is actually
> present and in force in the tree at `main` (`aad8532`), and no later commit has silently
> changed, reverted, or superseded it without that change being recorded.**

Truth conditions fixed with it: the claim is REFUTED for a plan if any `- [x]` / `- [done]`
subphase is **Absent**, **Partial** (present but materially short of its acceptance criteria),
**Silently reverted**, or **Superseded without record**. A `- [dropped]` subphase is a recorded
non-delivery and is not a refutation; a subphase marked `- [x]` that was in fact dropped is.
Default under uncertainty: REFUTED.

## Verdict

disproved

Narrowly, and not in the way the ask suspected. The claim is a universal conjunction over 103
subphases; it fails because **4 of them are Partial**, which the fixed truth conditions name as a
refutation. It does **not** fail on anything missing, reverted, or misreported: Absent = 0,
Reverted-silent = 0, Superseded-silent = 0, Syllabus-false = 0.

Stated the other way round, so the result is not misread: **99 of 103 subphases (96%) landed and
are in force**, and the specific suspicion that prompted the run — that the `--ship` strictness
was changed and re-changed without record — is itself **disproved**. The reversal happened and is
documented in three independent places, one of them a section literally headed "Supersession
note".

Had the claim been stated as "the plans substantively landed", the verdict would be `proved`. It
was not stated that way, and narrowing it now would be substituting a different claim for the one
fixed at stage 3.

## Method

Resolved axes: `TYPE=prove`, `PIPELINE=proof`, `EXPLORE=deep`, `RIGOR_EXPLORE=high`, `SHIP=chat`.

- **Snapshot.** All evidence read at a detached worktree pinned at `aad8532`, so the tree could
  not move under the readers (`chat` + `rigor >= med` requires this).
- **Gather.** `committee(explore, high)` — 5 cold members over the current tree. Panel ran full.
  4 disputes and 10 minority/singleton groups routed to a targeted second read against source; in
  three disputes *no member was right* and the resolution came from the re-read, not a vote.
  Consolidated at `committees/explore/accepted.md`.
- **Falsify.** 5 cold members, one plan per lens, each additionally carrying a shared cross-seam
  obligation on the `--ship` chain. Consolidated at `committees/falsify/accepted.md`; the
  re-verification trace is `committees/falsify/reverify.md`.
- **What was TRUSTED, as distinct from read.** The source at the snapshot was the only oracle.
  Explicitly NOT trusted: the plans' own syllabus ticks; the explore map (used as a lead
  generator, with the source overriding it wherever they disagreed); and the members' own return
  digests — final counts were recomputed from the member FILES, which caught three digest errors
  including one of my own.
- **Deviation from the pipeline, recorded.** `prove.md` stage 5 says the falsification pass at
  `rigor >= med` is "the committee's", but no wrappable falsification skill exists in the repo and
  `committee.md` invariant 2 forbids inventing one. The consolidator therefore performed the
  committee's phases 1-5 directly over 5 cold `general-purpose` members, following
  `committee.md`'s member-artifact layout exactly. This is a gap in the `prove` pipeline as
  shipped, not a defect of this run.

## Proof

Free-organization zone. Every step below is anchored to a `file:line` or to a command and its
actual output.

**P1 — Nothing is missing.** 0 ABSENT across 103 adjudicated subphases, counted from the member
files' `###` headings (`committees/falsify/accepted.md`, per-lens table). The one apparent ABSENT
in a raw grep was the string inside the heading
`### report-pipeline-and-locations §5.2 — LANDED (the brief's suspected ABSENT is disproved)`.

**P2 — The `--ship` suspicion, answered.** In force at `aad8532`, from `workflows.yaml:32,33,36`:
`map: chat|publish`, `analyze: publish|chat`, `prove: publish|chat` — per-row constrained, not
locked. The lock existed and was undone. The record:
- `dae-live-type-08-26-26.md:147-170` — section headed "Supersession note — `--ship` returns to
  the flag table";
- `dae-live-type-08-26-26.md:644-659` — the per-case spec for rewriting §1.3's locked-ship tests,
  so those assertions were deliberately rewritten rather than quietly deleted;
- `agent-agnostic/skills/dae/SKILL.md:46` — names the superseded plan, its §1.2, sha `5108f1d`,
  and the reasoning, written by `8875739` itself.
Reached independently by four of five members.

**P3 — The two syllabus-honesty traps, both cleared on generated evidence.**
- `axes-restructure` §1.1 is `- [done]` (its baseline died with its worktree, per the documented
  architecture) while §10.1 `- [x]` claims a regression against that baseline. Rather than accept
  either mark, c4 re-derived §10.1 from git: four middles' stage headers byte-identical
  `5644e79` -> `dac8ea0`, with a passing negative control, and exactly the two intended routing
  differences.
- §10.2's absent `audit` row is prescribed by the plan itself ("reverted after", `:472`). c4
  re-ran the drill: one line added to a `/tmp` copy of the table, the unedited resolver derived
  `PIPELINE=report EXPLORE=deep RIGOR_EXPLORE=med SHIP=publish BRANCH=docs/`, and its error text
  auto-enumerated `audit` — proving the resolver carries no hardcoded type enum.

**P4 — The install matches the source.** 78 files, 0 stale / 0 missing / 0 orphan against
`~/.claude/`, positive control fired at 30 (c1). `prove-type` §9.1's sync claim is true.

**P5 — The suite is green.** `for t in tests/*.test.sh; do bash "$t"; done` at the snapshot:
13 suites, **435 assertions, 0 failures** (`testrun.md`). The 435 figure is a correction — the
falsification brief stated 275, an arithmetic error of mine that three members independently
caught.

**P6 — The four Partials that carry the verdict.**
- `prove-type` §2.2 — root `AGENTS.md`/`README.md` tree diagrams show two source layers where the
  criterion demands three; `agent-specific/` is absent entirely and both diagrams list a
  nonexistent `agent-agnostic/settings/`. Material: the diagram *is* the deliverable.
- `prove-type` §7.1 — `SKILL.md:46` ("the two rows (`map`, `analyze`)") and `SKILL.md:47` ("legal
  on `map`/`analyze`") both stale; the table has three overridable ship rows. Found by c2 against
  c1's LANDED, resolved at source, and widened from one stale sentence to two (dispute D1 in
  `reverify.md`). Aggravating: the same plan's §6.1 was itself a sweep for this exact class of
  stale claim in the sibling file.
- `dae-live-type` §5.5 — the consistency sweep missed a dangling cross-reference its own lane
  authored: `parent-tree-guard.sh:26` cites a "Shared abstraction note" in `scope-writes.sh` that
  was never written.
- `axes-restructure` §6.1 — declared "new contract tests" as its acceptance oracle; no committed
  suite for `report.md` exists. The gap is recorded by name at
  `report-pipeline-and-locations-08-26-26.md:269`, so it is not a silent omission — but the
  oracle that was to keep §6.1 honest was never built. Material.

## Falsification attempt

Every lens was dispatched adversarially, with "refuted" as the default under uncertainty, and
each was given named attack surfaces chosen to be the most likely places the plans were
overstated. What was tried, and what happened:

- **"The 463-reference `orchestrators/` sweep cannot have been complete."** Refutation FAILED.
  345 residual hits, all but one under `project-plans/` (historical by nature); the single
  survivor is a correctly-tensed historical citation. (c1)
- **"`--rework` was renamed to `--patience`, so `dae-live-type` Phase 1's deliverable is gone."**
  Refutation FAILED. `git grep -w REWORK` outside `project-plans/` is empty against a **27-hit
  positive control**, so the rename is complete rather than half-applied, and it is recorded three
  ways. (c2)
- **"`report-pipeline` §1.1/§1.2 shipped behaviour that is false today."** The premise is TRUE —
  and the refutation still FAILED, because the truth condition excludes supersession *with*
  record, and the record exists in three places (P2). (c3)
- **"`document-confluence` doesn't exist."** This lead came from me, and it was WRONG. It exists
  at `tool-based/confluence/skills/document-confluence/SKILL.md`, rewritten; absent from
  `~/.claude/` by design, because `domain: confluence` content installs into consuming projects.
  c3 disproved my lead with a positive control on the pre-ship blob. (c3)
- **"§1.1 is `- [done]` so §10.1's `- [x]` must be false."** Refutation FAILED, on regenerated
  evidence rather than on the plan's word (P3). (c4)
- **"The oldest plan has had four later plans to erode it."** Refutation FAILED on all four
  hypotheses: `push-pr`'s three stages survived (diffed: purely additive); `review-pr`'s §1.2
  sites intact under two later edits; all seven of §2.1's `SKILL.md` deliverables survived three
  full rewrites of that file, including "Publishing happens ONLY through `push-pr`" verbatim;
  `push-policy.md` has **zero** commits since `a4c7c32`. (c5)
- **"A ten-pattern retired-vocabulary sweep will have survivors."** Refutation FAILED — clean
  outside `project-plans/`, every pattern positively controlled and `--include=*.sh` reach proven.
  (c5)

What the attempts DID succeed in breaking: the four Partials in P6, one of which (§7.1) was found
only because two members disagreed at the same location and the tie was resolved by re-reading the
source rather than by counting votes.

## Confidence + what would change the verdict

**High** on the negative findings — that nothing is Absent and nothing was silently reverted.
Those rest on five independent cold enumerations of full syllabi, with positive controls on the
searches that produced zeros, which is the specific discipline this repo's `verify-dont-assume`
rule exists to enforce.

**Moderate** on the exact Partial count of 4. "Materially short of its acceptance criteria" is a
judgement, and a stricter reader would find more Partials (several LANDED subphases carry small
prose defects catalogued in `issues.md`), while a more lenient one would find two — §7.1's stale
sentences and §5.5's dangling reference are arguably immaterial. The verdict is stable across
that range: it only takes one Partial to disprove a universal conjunction, and §2.2 and §6.1 are
material on any reading.

**This claim is falsifiable, and here is what would flip it.** The verdict flips to `proved` if,
and only if, all four Partials are closed: the tree diagrams in root `AGENTS.md`/`README.md`
corrected to three source layers with `agent-specific/` present and the nonexistent
`agent-agnostic/settings/` removed; `SKILL.md:46-47` corrected to three overridable ship rows;
`parent-tree-guard.sh:26`'s dangling citation either written or removed; and a committed contract
suite for `report.md` delivered against §6.1's declared oracle. Three are single-line edits; the
fourth is a test suite.

It would flip to a *deeper* `disproved` on the discovery of any subphase that is genuinely Absent
or silently reverted. None was found — but the honest limit of this run is that it read the tree
as it stands and the history of the files each ship commit touched; a deliverable removed by a
commit touching *no* file that its own ship commit touched would not be caught by that history
sweep, though it would still have been caught by the five per-subphase source reads.

**Not a tautology and not unfalsifiable:** the claim made a specific, checkable assertion about
103 named subphases, and it was in fact refuted on four of them.

---

## Appendix — findings for repair

The six sections above are `proof-skeleton.md`'s fixed frame, unmodified. This appendix is
additive: it carries the defects found *while* proving the claim, none of which is a refutation of
it. Severity order; attribution names the plan that owns each, where one does.

Scope note: NONE of these is a refutation of the claim under test. They are defects found while
proving it. Ordered by severity. Attribution says which plan (if any) owns the defect; several
are pre-existing and owned by no plan under test.

---

### I1 — Every archived plan permanently fails `validate-plan.sh` check 6
**Severity: high (self-defeating rule interaction).** **Attribution:** `report-pipeline` §7.1/§7.2
(each landed as specified; the defect is the interaction).

Three rules are individually correct and jointly unsatisfiable:
- `plan-format` REQUIRES an ask-of-record pointer in every plan;
- `run-artifacts` puts the ask inside the run dir (`<worktree>/.artifacts/`);
- `cleanup-merged` DESTROYS the run dir with the worktree at closeout.

So the pointer dangles the moment a plan is archived. Verified on all five plans under test — all
five FAIL. Positive control: rewriting one plan's pointer to an existing file makes the failure
disappear, so the check works; the target is genuinely gone.

### DECISION (user, this session): inline the ask into the plan, append-only

The separate `the-ask.md` file goes away entirely. Instead:

1. **The ask lives at the TOP of the plan file**, verbatim. Asks are usually short, so the size
   cost is acceptable and no second artifact has to survive cleanup.
2. **It is APPEND-ONLY and updated whenever a new ask arrives mid-run** — during planning, during
   build, at any stage. Each addition is appended as a new dated entry rather than editing or
   replacing the previous text.
3. **Tamper-evidence comes from git**, not from file separation: the plan is a committed artifact,
   so `git log -p` on it is the immutable record of what was asked and when. This was the one
   objection to inlining, and append-only + commit history answers it.

Rationale for rejecting the alternatives: pointing at a file in the plan dir (option 1) is more
machinery than short asks justify; exempting `completed/` plans from the check (option 2) keeps
the rule but discards its entire purpose, since the question "did we build what was asked?" only
gets asked after the work ships.

### Knock-on edits the fix pass must cover

- `rules/plan-format.md` — the ask-of-record section becomes "verbatim ask at the top of the
  plan, append-only", not "a pointer to a path". Its two-form wording (a path, or an explicit
  statement that no durable ask exists) is replaced.
- `validate-plan.sh` check 6 — stops resolving a filesystem path; instead asserts the ask section
  is present, non-empty, and positioned before the phase syllabus.
- `tests/validate-plan.test.sh` — check-6 cases are rewritten for the new shape (the existing
  C11/C12 malformed-declaration cases have no target to point at any more).
- `rules/run-artifacts.md` — drop `the-ask.md` from the run dir's contents.
- `agent-agnostic/skills/dae/SKILL.md` — the "ask of record travels to the planner as a PATH,
  never pasted content" clause: the planner still receives the ask, but writes it INTO the plan it
  produces, so no durable pre-plan file is required.
- `agents/planner.md` — records the ask into the plan's top section, and appends on amendment.
- `review-plan` — the ask-vs-plan diff reads the plan's own top section.
- The plan-amendment path in `SKILL.md` (the "plan is amendable at ANY stage" invariant) — must
  now also append the new ask, which is currently captured nowhere.

**Note:** this fix does NOT retroactively repair the five archived plans, whose pointers stay
dangling. Decide separately whether to backfill them or accept the historical failures.

---

### I2 — `resolve-config.sh` hardcodes `dev` as the base branch; three docs promise a git heuristic
**Severity: high (latent; bites any repo that does not pin the var).** **Attribution:** none of the
five plans — pre-existing.

- `resolve-config.sh:113-115` — `resolved="dev"`, no git call at all.
- `workflow-setup.sh:106-107` — delegates entirely to it, and its own error text promises
  "no 'main', no origin/HEAD".
- `rules/artifact-locations.md:16,26` — promises "a git heuristic (`main` if it exists, else the
  short name of `origin/HEAD`)".

Masked in this repo only because `.claude/settings.json:3` pins `CLAUDE_BASE_BRANCH: main`.
Any repo without that pin gets `dev` and `workflow-setup.sh` cuts a worktree off a branch that
does not exist.

**Fix direction:** implement the documented heuristic in the `--base-branch-default` branch, or
change all three prose sites to admit the real behaviour. Implementing it is the better fix.

---

### I3 — WITHDRAWN (not a defect); replaced by a narrower, optional finding
**Original report (WRONG): "`allow-workflow-cleanup.sh` is wired twice, pure waste."**

That was my error. The two entries are NOT duplicates — they carry different `if` conditions:
`if: "Bash(git branch:*)"` and `if: "Bash(git worktree remove:*)"`. My first check dumped only the
`command` field and never looked at `if`.

`if` IS a supported Claude Code hook field (permission-rule syntax, evaluated on PreToolUse /
PostToolUse / PostToolUseFailure / PermissionRequest / PermissionDenied) — verified against
https://code.claude.com/docs/en/hooks.md. So `allow-workflow-cleanup.sh` fires ONLY on those two
command shapes, never on general Bash. It is correct as written; the "fix" I proposed would have
broken working config. Nothing to do here.

### What IS true — the actual per-Bash-call cost

| hook | guard | runs on |
|---|---|---|
| `allow-workflow-cleanup.sh` x2 | `if Bash(git branch:*)` / `if Bash(git worktree remove:*)` | only those commands — CORRECT |
| `branch-squash-guard.sh` (Bash matcher) | none | EVERY Bash call |
| `parent-tree-guard.sh` (Bash matcher) | none | after EVERY Bash call, plus every Stop |

Two unconditional spawns per command, not four.

### I3a — `parent-tree-guard.sh` unconditional: JUSTIFIED, do not change

Its design is deliberately "do not parse the command, inspect the artifact afterwards" — any
command can mutate files (`sed -i`, `>`, heredocs, `tee`, `python -c`), so no command-pattern
guard can be correct for it. It already early-exits on the marker walk when no dae run is active.
The marker (`.artifacts/progress-log.md`) is its scope mechanism.

**Why it cannot be bound to the dae skill instead (asked, and worth recording):** hooks match tool
names and command patterns; there is no "while skill X is loaded" condition. More importantly, a
guard active only while its skill is loaded would be escaped by exactly the off-script behaviour it
exists to catch. Self-enforcement is not enforcement — the guard must sit outside the model's
control. The runtime marker is that, implemented the only way available.

### I3b — `branch-squash-guard.sh` unconditional: a REAL but OPTIONAL optimization

It only ever acts on `git` and `gh` commands. Empirically, on `main`:
`git merge foo` -> exit 2 (denied); `gh pr merge 1` -> exit 2 (denied);
`ls -la`, `pnpm install`, `npm publish`, `rm -rf /tmp/x`, `gh pr create` -> exit 0.

So its Bash entry could become TWO `if`-guarded entries — `Bash(git *)` and `Bash(gh *)` —
matching the pattern `allow-workflow-cleanup.sh` already uses in the same block. Saves one fork on
every non-git command.

**RISK, and why this is not being done unilaterally:** this hook is what protects `main` from
non-squash merges, force-pushes and direct commits. If `if` pattern matching differs even slightly
from the script's own command parsing — chained commands, leading env assignments, subshells — the
guard silently stops firing and nobody finds out until main is damaged. The upside is one process
spawn per command; the downside is losing main protection silently. That trade needs an explicit
decision, and cannot be validated without changing live settings and testing against them.

**Also note:** the `Write|Edit|MultiEdit|NotebookEdit` entry for this same script must stay
UNGUARDED — it stops file edits while on main, which has nothing to do with git command shapes.

**STATUS: awaiting user decision. Not fixed in this pass.**

---

### I4 — FIXED in `57d2a3e` · Two stale sentences in `dae/SKILL.md` claim two overridable ship rows; there are three
**Severity: low (prose).** **Attribution:** `prove-type-and-ship-axis` §7.1 -> downgraded to PARTIAL.

- `SKILL.md:46` — "without taking the choice away from **the two rows** (`map`, `analyze`)"
- `SKILL.md:47` — "legal on `map`/`analyze`, incoherent on a build"

`workflows.yaml` has THREE rows with a `|` ship list: `map`, `analyze`, **`prove`**. The prove
plan added the third row and did not update the prose two lines away — while its own §6.1 was a
sweep for exactly this class of stale claim in the sibling file.

---

### I5 — FIXED in `57d2a3e` · `parent-tree-guard.sh:26` cites a section that does not exist
**Severity: low (dangling cross-reference).** **Attribution:** `dae-live-type` §5.5 -> PARTIAL
(its own lane authored the dangling reference the citation sweep then missed).

Cites a "Shared abstraction note" in `scope-writes.sh` that was never written.

---

### I6 — FIXED in `57d2a3e` · `agent-agnostic/AGENTS.md:86` describes an impossible alternative
**Severity: low (prose).** **Attribution:** `report-pipeline` (excluded as R5 drift at ship, then
folded into the swept file by `prove-type` §2.1 and never re-swept).

Says `document-local` is the "Record stage **when the docs target is a local path**". After
§2.3/§4.1 the docs target is ALWAYS a local path, so the conditional describes a branch that
cannot not-hold.

---

### I7 — FIXED in `57d2a3e` · `plan-live.md` mis-attributes "Form P"
**Severity: low (prose).** **Attribution:** `dae-live-type` §3.5.

Attributes the term to `plan-format`; it is `validate-plan.sh`'s term.

---

### I8 — FIXED in `57d2a3e` · `prove-type-and-ship-axis` §2.2: tree diagrams show two source layers, not three
**Severity: low (docs).** **Attribution:** `prove-type-and-ship-axis` §2.2 -> PARTIAL.

`agent-specific/` is absent from root `AGENTS.md` entirely, and both diagrams list a nonexistent
`agent-agnostic/settings/`. Pre-existing defect carried forward with no record.

---

### I9 — FIXED in `57d2a3e` · `report.md`'s declared contract-test oracle was never delivered
**Severity: medium (a declared verification oracle that does not exist).**
**Attribution:** `dae-axes-restructure` §6.1 -> PARTIAL. The gap is RECORDED by name at
`report-pipeline-and-locations-08-26-26.md:269`, so it is not a silent omission.

§6.1 declared "new contract tests" as its acceptance oracle; no committed suite exists for
`report.md`. Content survived two later rewrites intact (c4 verified), but the oracle that was
supposed to keep it honest was never built.

---

### I10 — FIXED in `57d2a3e` · `tool-based/confluence/` is the only tech layer with no `AGENTS.md`
**Severity: low.** **Attribution:** none of the five plans — it never existed
(`git log --all -- tool-based/confluence/AGENTS.md` returns nothing).

`docs/tool-based.md:13-19` documents `AGENTS.md` as the first entry of the standard layer shape;
12 of 13 layers have one.


---

---

### Not an issue — recorded so it is not re-litigated

- **The `--ship` lock -> per-row reversal is RECORDED, three ways**, and is therefore not a silent
  revert: `dae-live-type-08-26-26.md:147-170` (a section literally headed "Supersession note"),
  its test-rewrite spec at `:644-659`, and `dae/SKILL.md:46` naming the plan, its §1.2 and sha
  `5108f1d`.
- **`--rework` -> `--patience`** is fully applied (`git grep -w REWORK` outside `project-plans/`
  is empty against a 27-hit positive control) and recorded in source + commit message — but has
  NO plan-level record, because `afa4817` had no plan behind it. Worth knowing; not a defect.

---

## Addendum — found after the proof was written

**A1. The write-scope hooks were inert for this entire fix pass.** `workflow-setup.sh` creates
`.artifacts/` with `contracts/` and `reports/`, but does NOT seed `progress-log.md` — and that
file is the marker `scope-writes.sh` and `parent-tree-guard.sh` walk up to find. Seeding it is the
orchestrator's documented job (`dae/SKILL.md` setup stage), and it was skipped. Consequence: every
product edit of this session, commit `57d2a3e` included, was made with zero write enforcement.

Demonstrated both ways on the same payload, same worktree:
- marker absent -> `scope-writes.sh` exit **0** (edit to `agent-agnostic/skills/dae/SKILL.md` allowed)
- marker present -> exit **2**, `DENIED ... outside the allowed write scope`, and
  `parent-tree-guard.sh` fired on the uncommitted edit: *"the orchestrator is not a builder;
  revert the change(s) above and dispatch a lane instead."*
- control, marker present -> a write to the plans dir still exit **0**.

**The structural flaw: the orchestrator creates the marker that polices the orchestrator.** That
is the same self-enforcement failure that makes skill-bound hooks useless, and it fails exactly as
predicted — by being forgotten. **Fix: `workflow-setup.sh` seeds `progress-log.md` itself.** It
already creates the sibling directories, it runs before any agent acts, and an orchestrator cannot
forget what it does not do. This ranks ABOVE I1 and I2: it is what makes every other write rule
actually bind.

**A2. Hook gate coverage by role** (separate audit, empirical, every claim positive-controlled):

- **`smart-test.sh` breaches `coder` and `contract-tester` isolation, architecturally.** Wired
  PostToolUse on every write tool with no role awareness, it runs the suite and pipes the output
  into whichever agent just wrote. Measured: a coder editing `calc.py` receives the test file's
  source and assertions; a contract-tester editing `test_calc.py` receives
  `E + where -1 = add(1, 2)` — the implementation's actual return value. `contract-tester.md` says
  "never read the implementation ... in any mode, no exceptions"; a hook it never invoked violates
  that on every write. No prompt discipline can prevent it. This is the worst finding of the audit.
- **A builder can edit the plan file, by either route** — child worktree has no marker (exit 0),
  and the parent's plans dir is an *allowed* root (exit 0); control on the same run:
  `src/app.ts` -> exit 2. Every gate re-reads the plan at verdict time, so a builder could edit the
  spec to match its own output.
- **The planner has the orchestrator's scope, not its own** — spawned with no worktree of its own,
  it inherits the marked parent's, so it can write the docs dir and the run dir.
- **`ship: chat` runs have no write containment at all** — no Setup means no `progress-log.md`,
  so both marker hooks are inert for the whole run. `map`, `analyze` and `prove` currently run
  unscoped.
- **Roles cannot be told apart today.** The only payload fields any hook reads are `cwd`,
  `session_id`, `stop_hook_active`, `tool_name`, `tool_input`; no hook reads any identity field
  (positive-controlled). `session_id` cannot substitute — `test-changed.sh:9-11` records that
  SubagentStop reports the MAIN session's id. `cwd` distinguishes a *place*, not a *role*.
  Recommended signal: a **role marker file** written by the dispatcher into a directory the agent
  cannot write to, read during the ancestor walk the hooks already perform. An env var is cheaper
  but weaker — an agent can export its own, so it is not a structural boundary.
- **"Orchestrator writes nothing" has one blocker:** the progress log is the highest-frequency
  write in a run and has no script, while syllabus ticks and plan moves already go through
  `mark-syllabus.sh` and `plan-lifecycle.sh`. A `progress-log.sh` would complete the set and let
  the allowed-roots list shrink to empty.
- **`SKILL.md:153` overstates "machine-audited"** — `verify-scope.sh` and `verify-run-scope.sh`
  are not wired hooks; they are scripts an agent chooses to run. Machine-*auditable*.
