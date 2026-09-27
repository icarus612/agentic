# code-review

## Round 1 — 09-02-26

```
verdict: rejected
next: impl-wrong
blocking: 2
non-blocking: 3
```

### Method

Read the plan (`plan.md`), then `git diff main..HEAD` (40 files, +4514/-344), read every
changed file in full (not just diff hunks), diffed the shared hook helpers byte-for-byte, ran
all 18 test suites directly (522/522 pass, matching the progress log's claim), ran `bash -n` on
every changed script, and empirically reproduced two exploit/failure scenarios in scratch git
fixtures rather than trusting the tests' own account of themselves. Three independent forked
sub-reviews covered lanes 1 (Phases 1-5), 2 (Phase 6), and 3/4/5 (Phases 7-9, 11); I verified
Phase 4 and the two blocking findings below directly and first-hand.

### Findings

- [blocking] **The role marker is not structural — it is silently rewritable via Bash, defeating
  the plan's own "must be structural" convention.** `agent-agnostic/hooks/scope-writes.sh` and
  `agent-agnostic/hooks/parent-tree-guard.sh` gate the new per-role write scope on
  `.artifacts/dae-role`. `.artifacts/` is gitignored by design (`run-artifacts` rule).
  `scope-writes.sh` is a PreToolUse hook on `Write|Edit|MultiEdit|NotebookEdit` only — it never
  sees Bash. `parent-tree-guard.sh` is the documented Bash-side backstop, but it detects offending
  changes via `git status --porcelain`, which **never reports a gitignored path** —
  `parent-tree-guard.sh`'s own header comment says as much ("`.artifacts/` needs no special case:
  it's gitignored... `git status --porcelain` never reports it") without recognizing that this
  makes `dae-role` itself invisible to the one hook meant to guard Bash-side mutation of it.
  Reproduced directly in a scratch git repo (twice, independently — once by me, once by the
  lane-1 sub-review): seed `.artifacts/dae-role` = `orchestrator`, `printf 'builder' >
  .artifacts/dae-role` via plain Bash, `git status --porcelain` on the marked worktree is empty,
  `parent-tree-guard.sh` exits 0 (clean), and a subsequent `Write` to a product file
  (`src/app.js`) that would have been DENIED under `orchestrator` is now ALLOWED under the
  self-granted `builder` role. This is exactly the failure mode the plan's own "Conventions to
  enforce" section warns against ("A role signal must be structural... An env var the agent can
  `export` is not acceptable") and that DP-1 explicitly told the implementer to raise rather than
  ship ("If the implementer finds no such location, that is a blocking finding to raise, not a
  reason to fall back to (c)"). Lane 1, subphases 2.1-2.3.
  (`agent-agnostic/hooks/scope-writes.sh`, `agent-agnostic/hooks/parent-tree-guard.sh`,
  `agent-agnostic/hooks/workflow-setup.sh`.)

- [blocking] **DP-1's planner role flip — "the router writes the role marker as part of spawning
  the planner, and restores it to orchestrator when the planner returns" — was never
  implemented, and this breaks the planner's ability to write its own plan.** `dae-role` is set
  to `orchestrator` at parent-worktree creation (`workflow-setup.sh:266-268`) and nothing in the
  mainline flow ever changes it: `grep -n role agent-agnostic/skills/dae/SKILL.md` returns zero
  matches, and `live.md`/`diagnose.md`'s planner-spawn steps (both touched by this diff) contain
  no `--set-role` call either. Since the planner shares the orchestrator's cwd (per DP-1: "the
  planner is spawned with no worktree of its own"), it inherits whatever `resolve_role` reads at
  that marker — which stays `orchestrator` — and the new orchestrator rule allows only
  `*-review.md`/`sync-report.md` under the plans root. Reproduced directly: with
  `dae-role=orchestrator`, a `Write` to `project-plans/proposals/foo-01-01-26.md` is **DENIED**
  (exit 2) by `scope-writes.sh`. `build.md:27` and `worktree-modes.md:15` both cite "the planner
  spawn/restore pattern `SKILL.md` already uses" as an existing precedent for the `--worktree
  none` builder-role flip they *do* wire correctly — but that precedent does not exist; both
  citations point at nothing. `workflow-setup.sh:250-252`'s own comment ("an in-flight run's
  current role, e.g. mid-planner-spawn, must survive a crash-resume unchanged") shows the lane
  author assumed this flip happens somewhere — it doesn't, anywhere in this diff or in `main`.
  Once these hooks are active, this breaks plan-writing for every `build`/`live`/`diagnose` run
  that spawns a planner — the exact mechanism Phase 2 exists to enforce, applied to the one role
  (planner) whose spawn site was never wired. Lane 1 (2.1) decided the marker shape but the
  actual flip belongs at the planner-spawn call sites in `SKILL.md`/`live.md`/`diagnose.md`,
  which Phase 2's file scope never named and lane 4 (which did touch `SKILL.md`/`live.md`/
  `diagnose.md` for Phase 8) also didn't add.

- [non-blocking] **`agent-agnostic/AGENTS.md:260`** still reads "ownership is machine-audited by
  the scope scripts" — the exact overstated phrasing Phase 9.1 exists to fix (the audit finding
  it responds to, `docs/reports/last-5-plans-landed-09-01-26.md:465`, named only `SKILL.md:153`,
  which lane 4 did fix correctly). `AGENTS.md` was never in 9.1's or 9.2's named file scope, so
  this is a plan-scope gap rather than a lane defect, but it leaves the same overstatement live
  one file away from the one it fixed. One-line fix, no urgency.

- [non-blocking] **`resolve-scratch.sh`'s in-repo marker always seeds at `<repo-root>/.artifacts`**
  regardless of where a non-default `CLAUDE_SCRATCH_DIR` points. If that var is ever configured to
  an absolute path outside the repo tree, scratch writes there go unmarked by the new hooks. Low
  impact today (no product tree sits at an arbitrary scratch path to protect), flagged for
  awareness rather than as a defect to fix now.

- [non-blocking] **`tests/validate-plan.test.sh` case C4** asserts `[ ! -e
  "$d/.artifacts/the-ask.md" ]`, which is trivially true since the fixture never creates that
  path — a weak standalone proof that filesystem resolution is gone. The real proof (the
  resolution code itself deleted from `validate-plan.sh`) was confirmed directly by reading the
  script, so this is a test-quality nit, not a functional gap.

### Open questions

None — both blocking findings were independently reproduced with concrete repro steps, so
nothing here is left as an unverified claim.

## Round 2 — 09-02-26

```
verdict: rejected
next: plan-wrong
blocking: 2
non-blocking: 5
```

### Method

Cold review: I wrote none of this and read no lane reasoning before judging. Ran the full suite
myself (19 files; 575 PASS lines by my own tally plus `sync-install-settings-merge`'s 12 in its
own output format = **587 cases, 0 failures, every file exit 0** — the claim holds exactly).
Extracted all four shared helpers from both hooks with `awk` and compared them by `diff` **and**
`md5sum`, each with a positive control that a one-character change is detected (my first control
was invalid — it substituted a string `resolve_role` does not contain — so I rebuilt it before
trusting any result): `find_parent_worktree`, `find_lane_root`, `resolve_role`, `resolve_root_dir`
are **byte-identical** across `scope-writes.sh` and `parent-tree-guard.sh`.

Rather than accept round 1's two findings as closed on the strength of the tests or the exit
reports, I built a fixture with the **real `workflow-setup.sh`** (a fresh git repo with a
*committed* `.gitignore` carrying `.artifacts/`, a real parent worktree, and a real `--parent`
lane child) and ran the escalations by hand, recording raw exit codes. Every zero reported below
carries a positive control; where a control failed I discarded the result and re-ran. Findings are
stated against files, not against the exit reports or the progress log.

### Round 1's two blocking findings — both genuinely closed

**Round 1 finding 1 (forgeable `dae-role`) is CLOSED.** Against the real fixture, `echo builder >
.artifacts/dae-role` — round 1's exact exploit, which then ALLOWED a product write — now yields:

```
raw marker = builder;  git status --porcelain = EMPTY (still invisible, as round 1 said)
Write src/app.js            -> exit 2   (resolved role is orchestrator, not the forged builder)
parent-tree-guard.sh        -> exit 2   ("contains 'builder' ... only ever forgery")
```

The tamper check fires with `git status` empty, so it is genuinely independent of the git-status
scan — the specific defect round 1 named. I also confirmed the neighbouring cases hold: a forged
literal `scratch` in a linked-worktree parent grants nothing (product **and** `.artifacts` writes
both exit 2), a garbage token denies, and a lane child's role is derived structurally — planting
`planner` into a child's own `.artifacts/dae-role` still denied the plans dir (exit 2).

**Round 1 finding 2 (no planner-spawn site set the role) is CLOSED.** The bracket is present in
`SKILL.md`, `build.md`, `live.md`, `diagnose.md` (one `--set-role planner` plus a restore in each),
and I verified the flip end-to-end through the real script rather than by grep: as `orchestrator` a
proposal write is denied (exit 2); after `workflow-setup.sh --set-role planner` the same write and
a `plan.md` write both succeed (exit 0) while `src/app.js` stays denied (exit 2); after the
restore the proposal write is denied again. `prove.md`/`report.md` correctly have no bracket
because they spawn no planner ("no planner and no builders" in their own text).

**The least-privilege fallback did NOT become fail-closed.** With no marker anywhere in the
ancestry, every write exits 0: product, plans, docs, a deep new path, a path outside the repo, a
non-git directory, and — the case most likely to have broken — a **dirty** unmarked repo where
`git status` is non-empty (`parent-tree-guard.sh` exits 0 there too). The top repo-wide risk in the
plan is clean.

**The `scratch` discriminator is correct in both directions.** A genuine `ship: chat` run seeded by
`resolve-scratch.sh` (marker present, `dae-role` deliberately absent) can write its own
`report.md`, `committees/<skill>/claims-c1.md`, and explore map (all exit 0) while product and
plans writes are denied (exit 2); and, as above, forging `scratch` inside a real parent worktree
grants nothing.

### Findings

- [blocking] **No role can write the docs root, so the Record stage is structurally blocked for
  every worktree-based dae run.** The role policy the plan states at `plan.md:95` — "orchestrators
  make no writes at all, planners write only the resolved plans dir, builders write anything except
  the plans dir and the docs dir" — assigns the docs root to **no role at all**, while the same
  plan schedules `document-local` at Record (`plan.md:388`, `| Record | document-local |`). I
  confirmed the consequence empirically in the real fixture, for every role that exists:
  ```
  role=orchestrator   docs/architecture.md -> 2    docs/reports/r-09-01-26.md -> 2
  role=planner        docs/architecture.md -> 2    docs/reports/r-09-01-26.md -> 2
  role=builder        docs/architecture.md -> 2    docs/reports/r-09-01-26.md -> 2
  ```
  The Bash route is closed too: writing `docs/architecture.md` with a shell redirect and then
  running `parent-tree-guard.sh` gives **exit 2** ("product file changed in the run's parent
  worktree ... the orchestrator writes only this run's own gate reports"). `document-local` is
  `context: fork` (`agent-agnostic/skills/document-local/SKILL.md:5`) — it shares the orchestrator's
  cwd and never calls `workflow-setup.sh`, exactly DP-1's planner situation — and **none of its nine
  invocation sites is bracketed** with a role flip (`build.md:25`, `live.md:12`, `diagnose.md:21`,
  `report.md:43`, `prove.md:23`, `document.md:11`, `sync.md:13`, `SKILL.md:130,154`). Two of those
  mandate docs writes by name: `report.md:43` (`<docs-root>/reports/`) and `prove.md:23`
  (`<docs-root>/proofs/`). The same skill also checks off syllabus items in `plan.md`
  (`document-local/SKILL.md:39`), which the orchestrator role denies as well. This is **not** a
  round-2 regression — at round 1 (`fc5d789`) the explicit `orchestrator` arm already denied docs;
  the permissive plans+docs+`.artifacts` allowance only ever applied to an *unresolved* role, which
  `workflow-setup.sh`'s seeding makes unreachable in practice. It was simply never noticed, and
  `--set-role` accepts only `orchestrator|planner|builder` (`workflow-setup.sh:79-82`), so no
  amount of wiring fixes it: **there is no docs-writing role to flip to.** This routes `plan-wrong`
  because the gap is in the approved role policy itself, not in any lane's execution of it.
  Undisclosed anywhere — searches of the six exit reports, the six contracts, `progress-log.md`,
  `plan.md`, and round 1's report return nothing on it (controls passing). Worse, the run recorded
  the denial as the *goal*: `progress-log.md:184-192` tabulates `docs/` as "denied" for all three
  roles and calls it "the user's stated policy exactly", and `l6-exit.md:159-161` lists "docs write:
  DENIED" as the fix — the argument that was made for the planner ("it cannot write the plan it
  exists to write", `progress-log.md:233-235`) was never made for `document-local`.

- [blocking] **Deleting the run-dir marker is a total, permanently undetectable bypass of both
  hooks — the same defect class round 1 rejected this build for, and strictly more powerful than
  the role forgery it closed.** Both hooks locate a run only by testing for the existence of
  `.artifacts/progress-log.md` (`scope-writes.sh:118`, `:149`; identical in `parent-tree-guard.sh`),
  and `.artifacts/` is gitignored, so the file is invisible to `git status --porcelain` — the very
  property round 1's finding turned on. One plain `rm` disables everything, verified in the real
  fixture:
  ```
  rm .artifacts/progress-log.md
  Write src/app.js       -> exit 0   (ALLOWED — was exit 2 one command earlier)
  parent-tree-guard.sh   -> exit 0   (finds no marker; silent)
  ```
  Round 1's forgery is at least *caught retroactively* by the new tamper check. This is not caught
  at all, ever: `parent-tree-guard.sh` is wired **`PostToolUse`** on `Bash` (and `Stop`) —
  `agent-specific/claude/settings.json:161,179-187,188-202` — so the `rm` executes first, and by the
  time the hook runs there is no marker left to detect tampering against. The tamper check added in
  round 2 fires only on the literal string `builder` in `dae-role`; it has no notion of a marker
  that has ceased to exist. This also has a non-adversarial form: any cleanup that clears
  `.artifacts/` silently turns the whole feature off with no signal. It is undisclosed — searches
  across the exit reports, contracts, progress log, plan, and round 1's report for marker
  deletion/removal return nothing, with positive controls confirming the searches work. Like the
  finding above it needs a plan decision (what makes run-detection tamper-evident), not a
  redispatch, hence `plan-wrong` rather than `impl-wrong`.

- [non-blocking] **`verify-run-scope.sh . main .artifacts` FAILS** with five unclaimed product
  changes: `AGENTS.md`, `README.md`, `agent-agnostic/AGENTS.md`, `tool-based/confluence/AGENTS.md`,
  `tests/report-middle-contract.test.sh`. This is **not** a lane failing to claim its work — all
  five trace to `57d2a3e`, the branch's *first* commit, which predates the plan's own promotion
  commit (`01d8903`). It is pre-plan work carried on the same branch. Flagged because the PR gate
  runs exactly this check and will fail on it: it needs either an owning exit report or an explicit
  recorded note before that gate, not a silent pass.

- [non-blocking] **`agent-agnostic/AGENTS.md:142-145` still documents the removed permissive
  orchestrator scope** — "denying orchestrator writes outside the run's `.artifacts/`, the resolved
  plans dir, and the resolved docs dir" describes `.artifacts` + plans + **docs** as *allowed*,
  which is the legacy allowance this round deliberately removed. Stale, and now wrong in the
  opposite direction from the round-1 non-blocking below.

- [non-blocking] **Round 1's non-blocking items 1 and 3 are still open**, re-verified directly
  rather than assumed: `agent-agnostic/AGENTS.md:260` still reads "machine-audited by the scope
  scripts" (while `SKILL.md:172` now correctly says "machine-*auditable*, not machine-audited", so
  the two files contradict each other), and `tests/validate-plan.test.sh:394` still asserts
  `[ ! -e "$d/.artifacts/the-ask.md" ]` on a path its fixture never creates. Round 1's non-blocking
  item 2 (`resolve-scratch.sh`'s in-repo marker location) is likewise unchanged.

- [non-blocking] **Two of the "re-pinned" `parent-tree-guard.test.sh` cases were outcome-inverted,
  not re-pinned.** Cases 04 and 05 changed from `-> exit 0` to `-> exit 2` ("modified file under the
  resolved plans dir (non-matching name) -> exit 2", "modified file under the resolved docs dir ->
  exit 2 (docs root never clean for orchestrator)"). That inversion is **correct** — no role makes
  a docs path clean any more — and the new labels state the new reason honestly rather than hiding
  it, so this is not a test bent until it passed. But it is a more substantive change than "re-pinned
  to explicit roles" describes, and it is the tripwire that would have caught the docs-root blocking
  finding above had anyone asked *why* a docs write could no longer be clean for anybody. Related
  coverage gap: no lane-child case asserts the docs half — `tests/scope-writes.test.sh` case 16
  (`:766-798`) asserts only the plans half, and `:363` notes "no positive control possible for docs".

- [non-blocking] **The disclosed DP-1 residual (orchestrator ↔ planner forgery) is confirmed live,
  and recorded here rather than counted as blocking.** `orchestrator` and `planner` are honored from
  the marker unconditionally, with no topology check and no tamper check, so `printf 'planner' >
  .artifacts/dae-role` promotes an orchestrator to full plans-dir write access — I reproduced it
  (`proposals/p.md`: exit 2 before, exit 0 after). The brief for this round lists this as a known,
  disclosed limit awaiting a user decision, so it is not scored as a new blocking defect; lane 6
  raised it as DP-1 anticipated. It nevertheless belongs in the same decision as the two blocking
  findings above, and `plan.md`'s DP-1 section was never amended to record it, unlike the 2.1
  criterion and the Phase 5/DP-2 collision note. `sync.md`'s missing planner bracket
  (`grep -c -- --set-role sync.md` = 0, control: `planner` = 15 hits in `SKILL.md`) is genuinely
  still open and benign in practice — the one write it makes, `sync-report.md`, is on the
  orchestrator allow-list, which I confirmed (exit 0).

### Open questions

None. Both blocking findings were reproduced first-hand against a fixture built with the real
`workflow-setup.sh`, with raw exit codes recorded above and positive controls behind every negative
result. What remains is a decision for the user, not an unverified fact: the role policy needs a
docs writer (a new role, a widened orchestrator at Record, or an explicit bracket to a role that
may write docs), and run-detection needs to be tamper-evident against marker deletion rather than
merely against a forged token.

## Round 3 — 09-17-26

```
verdict: tentative
next: proceed
blocking: 0
non-blocking: 3
```

Cold review. Every negative result below carries a positive control, and every claim was checked
against the artifact rather than against an exit report or the progress log. Two of my own checks
produced false cleans and were caught by their controls; both are recorded rather than hidden.

### Round 2's two blocking findings — adjudicated

**R2-1 — no role could write the docs root. FIXED.** Verified by execution, not by reading tests.
I drove the real `scope-writes.sh` with crafted payloads against two fixture shapes.

On a marked main-checkout parent (role resolves to `scratch`):

```
exit 0  agent_type=documenter -> <root>/docs/architecture.md
exit 0  agent_type=documenter -> <root>/docs/apps/x.md          (nested)
exit 0  agent_type=documenter -> <plans>/someplan-09-01-26/plan.md
exit 2  agent_type=documenter -> <root>/src/app.js
exit 2  agent_type=documenter -> <plans>/someplan-09-01-26/notes.md
exit 2  NO agent_type        -> <root>/docs/architecture.md     <- same target
exit 2  agent_type=coder     -> <root>/docs/architecture.md     <- same target
exit 2  agent_type=planner   -> <root>/docs/architecture.md     <- same target
exit 2  agent_type=builder   -> <root>/docs/architecture.md     <- same target
```

On a genuine linked worktree (role resolves to `orchestrator`, the real dae parent shape):

```
exit 0  agent_type=documenter -> <wt>/docs/architecture.md
exit 0  agent_type=documenter -> <wt>/<plans>/p-09-01-26/plan.md
exit 2  NO agent_type        -> <wt>/docs/architecture.md
exit 0  NO agent_type        -> <wt>/<plans>/p-09-01-26/code-review.md   (its own gate report)
exit 2  NO agent_type        -> <wt>/src/app.js
exit 2  agent_type=coder     -> <wt>/docs/architecture.md
```

The four non-documenter rows target the *identical path* as the allowed documenter row, so the
allowance is gated on `agent_type`, not on path shape. `resolve_role` short-circuits on
`agent_type=documenter` **before** reading the `dae-role` marker, so the documenter role cannot be
forged by writing a file. Record is no longer structurally blocked.

*A false clean of my own, recorded:* my first payload set omitted `tool_name`, so all nine calls hit
the wrong-tool short-circuit and returned exit 0 — including the rows I had predicted would deny.
Read as "documenter works", that run would have passed a broken guard. The mismatches against my
expected-value column exposed it. The table above is the corrected run.

**R2-2 — deleting `.artifacts/progress-log.md` disables both guards. NOT fixed, deliberately.**
Accepted as a disclosed limitation per the user's decision to land and close it in the follow-up
that replaces the marker with `agent_type` outright. I confirmed it is honestly recorded rather
than quietly dropped: it stands in this committed report at Round 2 (`Deleting the run-dir marker
is a total, permanently undetectable bypass of both guards`), and the progress log carries the
reasoning and the consequence. Not counted as a finding.

### Verification of the round-2 fixes

**`workflow-diff-check.sh` — genuinely wired, and genuinely inert elsewhere.** Both halves proven.
It is present in `agent-specific/claude/settings.json`'s `Stop` array alongside `ntfy-notifier.sh`
and `parent-tree-guard.sh`. For inertness I ran a twin experiment: two identical git repos, each
with an untracked `test_x.py` containing `assert False`, differing only by the presence of
`.artifacts/progress-log.md`.

```
marked repo   -> exit 2, stderr names pytest/assert   (positive control: the check IS reachable)
unmarked repo -> exit 0, no output whatsoever         (inert)
```

Without the marked twin, the unmarked exit 0 would have proven nothing. The self-scope is
`find_parent_worktree "$cwd" || exit 0`, ahead of every check. The user's constraint — gates only
where needed — holds: a Stop hook wired globally does not run the project's checks in unrelated
sessions.

**The repeated-claim sweep — enumerated, not spot-checked.** 17 files mention
`workflow-diff-check`; 5 are archived plans under `completed/` (historical records, correctly left
alone) and 12 are live. I read the actual claim in all six live prose locations —
`AGENTS.md` (x2), `README.md` (x2), `agent-agnostic/AGENTS.md`, `docs/architecture.md`,
`docs/pipeline.md`, `dae/SKILL.md` — plus the script's own header. Every one now describes it as
globally wired via `settings.json` and self-scoped by the marker walk. That matches the behavior I
measured above. No instance of the stale "declared in the skill's frontmatter" claim survives.

The underlying teaching defect is also gone: zero `SKILL.md` files carry a `hooks:` frontmatter key
(file filter positive-controlled at 24 matching files; the `^hooks:` pattern positive-controlled
against synthetic input). `docs/conventions.md`, round 2's worst instance, now teaches the opposite
of the defect: *"A skill has no `hooks:` frontmatter of its own — Claude Code has no such feature."*

**`record-changed.sh` / `test-changed.sh`.** Both scripts still present, referenced by no settings
or hooks file in `agent-specific/`, and `agent-agnostic/AGENTS.md` now describes them accurately as
unwired dead code and flags it as a finding. Only the false claim was removed; removal of the
scripts correctly left to the user.

**Tests: 605 cases, 0 failures — confirmed exactly.** All 20 files run, all exit 0. Exit status
alone is not evidence, so I asserted on content: 605 `PASS` lines and 0 `FAIL` lines across the
logs, with the FAIL pattern positive-controlled against synthetic input to prove it could match.
(`sync-install-settings-merge.test.sh` uses a different summary format and indented `PASS` labels —
an anchored `^FAIL` sweep would have silently skipped it. 593 + 12 = 605.)

**Fail-open holds.** With no marker anywhere above the target, every write exits 0 — checked for
`scope-writes.sh` (documenter, no agent_type, coder) and for `parent-tree-guard.sh` (same three, on
a dirty tree). Each is backed by a positive control on the same fixture with the marker added,
which returns exit 2. The guards are not fail-closed; work outside a dae run is not blocked.

**The four shared helpers are byte-identical.** Extracted from both scripts and diffed, not
eyeballed. Non-empty extraction was asserted so a broken extractor could not masquerade as a clean
diff:

```
find_parent_worktree  13 lines  md5 f7c466b99061  IDENTICAL
resolve_root_dir       7 lines  md5 7c4dea1cd3f1  IDENTICAL
find_lane_root        16 lines  md5 bad61220d33a  IDENTICAL
resolve_role          33 lines  md5 680a78a949bd  IDENTICAL
```

**Ask vs. implementation.** The ask says *"orchestrators dont make writes PERIOD"*; the
implementation allows the orchestrator `*-review.md` and `sync-report.md` under the plans root.
This is a documented, reasoned narrowing, not a silent deviation — plan §4.2 records that the gates
run in the orchestrator's own context and `review-code` appends findings with Write/Edit, so zero
would be unimplementable. The planner and builder rules match the ask literally. Subphase 9.1's
known-wrong criterion was not treated as a defect, per instruction.

### Findings

- [non-blocking] **The ownership ledger is red, and I come down on landing anyway — but only
  because I reviewed the two files myself.** `verify-run-scope.sh . main .artifacts` exits 1 with
  exactly `tests/report-middle-contract.test.sh` and `tool-based/confluence/AGENTS.md` unclaimed
  (7 exit reports read). I confirmed the provenance against git rather than the report: both come
  from `57d2a3e`, which is the **first commit on the branch**, authored 09-01 15:55, about seven
  hours before `01d8903` promoted the plan (`git merge-base --is-ancestor` confirms the ordering).
  No builder could legitimately own them.

  This is a real violation of "every product change is claimed by an exit report", and the
  disclosure does not by itself excuse it — a gate that accepts "it's disclosed" as a reason to
  ignore its own red check teaches the run that the check is advisory. What actually resolves it is
  that the ledger's *purpose* is review coverage, and the coverage gap was the only concrete harm.
  So I supplied the coverage: I read both files in full. `tool-based/confluence/AGENTS.md` is 28
  lines describing one-way repo→Confluence publication, the CI-on-merge sync, and the
  `CLAUDE_DOCS_PUBLISH` / `CLAUDE_DOCS_DIR` split — consistent with the `artifact-locations` and
  `doc-format` rules, no defect. `report-middle-contract.test.sh` is test-only, adds 12 passing
  cases, and fills an oracle that `dae-axes-restructure-08-23-26` §6.1 declared and never shipped.
  Both are benign; neither changes shipped behavior.

  Manufacturing an exit report to clear the check would have been strictly worse — it would launder
  an orchestrator product write into a fake builder claim and destroy the ledger's meaning. Not
  doing that was the right call. **Acceptable for landing, with the PR gate needing an explicit,
  recorded user decision, since `verify-run-scope.sh` will fail there too and must not be waved
  through silently.** The underlying defect — the ledger cannot express a legitimate pre-plan
  orchestrator commit, so its only outcomes are "lie" or "stay red" — belongs in the follow-up.

- [non-blocking] **The follow-up plan's entire rationale lives only in a file that
  `cleanup-merged` will destroy.** The mechanism is safely committed (`agent_type` appears in 7
  tracked files: both hooks, `documenter.md`, `dae/SKILL.md`, `agent-agnostic/AGENTS.md`, and two
  test files). What is *not* committed is the reasoning that justifies the next plan: the probe
  showing `session_id` is identical between parent and subagent while `agent_type`/`agent_id` are
  harness-supplied and unforgeable, the conclusion that the `dae-role` marker mechanism is
  superseded, and the note that DP-4 becomes solvable because `coder`/`contract-tester` are
  distinct agent types. `git grep` finds zero mentions of `agent_type` in the committed plan dir
  and zero in `docs/`; all of it sits in `.artifacts/progress-log.md`, which `.gitignore:6` confirms
  is ignored and which dies with the worktree at closeout. `plan-format`'s supersession rule exists
  precisely so a successor plan's reasoning is not lost. **Capture the probe evidence and the
  superseded-mechanism decision in a committed artifact — the follow-up proposal, or this plan's
  records — before the worktree is torn down.**

- [non-blocking] **The ledger's accuracy silently depends on exit-report formatting.** Confirmed as
  already recorded, not rediscovered. `claims_from_report()` takes the first backticked token per
  bullet (`head -n1`) and `read -r line` sees a single *physical* line, so a wrapped bullet's
  continuation is dropped without warning. It does emit a stderr `NOTE` for multi-backtick bullets,
  which is a partial mitigation. The six reformatted reports worked: zero `NOTE`s fire on the real
  reports today, and I positive-controlled that a `NOTE` does fire on a synthetic multi-backtick
  bullet, so the zero is real. Nothing enforces the format, so it will drift again. Correctly
  logged for the follow-up.

### Open questions

- The PR gate will hit the same red `verify-run-scope.sh`. The user should decide there, explicitly
  and on the record, whether the two pre-plan files land unclaimed — this gate's position is that
  they may, on the reviewed-and-benign grounds above, but that is a decision to ratify rather than
  inherit.

### Verdict rationale

`tentative`, not `ready`. Both of round 2's blocking findings are resolved or consciously accepted,
every fix claimed since round 2 was verified by execution against the artifacts, and the test suite
is genuinely green at 605/0 — nothing here should stop the run, hence `proceed` with zero blocking
findings. It is not `ready` because real caveats ship with this branch: the ownership ledger exits
non-zero and needs a human decision at the PR gate, several mechanisms (the marker-deletion bypass,
DP-4) land disclosed-but-open, and the reasoning that justifies the follow-up is currently one
`cleanup-merged` away from being lost.

## Round 4 — 09-17-26

```
verdict: rejected
next: impl-wrong
blocking: 2
non-blocking: 3
```

### Method

Cold review — no prior-round reasoning read before forming my own view; rounds 1-3 read afterward,
for cross-checking only. Read `plan.md` in full, `git diff main..HEAD` (60 files, +7307/-891), and
every file lane 7 touched. Ran the whole suite myself (20 files, 605 cases, 0 failures — confirmed
by content: `grep -c '^PASS' `/`FAIL` per file, not exit status), `bash -n` on every changed script,
and `verify-run-scope.sh` directly. Went beyond round 3 in two directions it didn't cover: whether
this BRANCH is current with `main` (it diffs against `main`, but never checked whether `main` moved
since the merge-base), and whether the `documenter` role's actual write-time identity is real or
only proven at the hook-payload level. For the second, I dispatched `claude-code-guide` to get a
sourced answer from Claude Code's own docs on how `context: fork` and `agent_type` interact, since
I could not safely drive a live multi-hop dispatch (documenter agent -> Skill fork -> real write)
from inside this sandboxed review session to capture a real payload — a probe attempt (mirroring
the technique `progress-log.md`'s 09-15-26 entry used to prove agent identity in the first place)
was blocked by the environment's own command classifier before it could run.

### Findings

- [blocking] **This branch is stale against `main` by two commits it never merged, and squashing it
  as-is will silently regress `main`.** `git log main --not HEAD` shows `0cf8a8a` (universal
  no-attribution + minimal-comments enforcement) and `303a661` (scope smart-lint/smart-test to the
  edited file), both landed on `main` at `2026-09-17 12:11`, over an hour before lane 7's merge
  (`c6c3da2`, `13:27`) and same-day as round 3's own review — round 3 diffed against `main` but
  never checked whether `main` itself had moved. Confirmed structurally, not just from the stat
  line: `git show main:agent-agnostic/hooks/check-diff-hygiene.sh` exists, `git show
  HEAD:agent-agnostic/hooks/check-diff-hygiene.sh` does not, and `git log --oneline main..HEAD --
  agent-agnostic/hooks/check-diff-hygiene.sh` is empty — this branch never touched the file; it
  simply never merged the commit that added it. Five files are affected the same way
  (`check-diff-hygiene.sh`, `no-attribution-guard.sh`, `pr-ready-hygiene-guard.sh`,
  `minimal-code-comments.md`, `no-attribution-trailers.md`), and `agent-specific/claude/settings.json`
  is a sixth: this branch's copy is missing the `no-attribution-guard.sh` / `pr-ready-hygiene-guard.sh`
  Bash-hook entries `303a661`'s sibling commit added, and now also ends with no trailing newline
  (confirmed by diff) — a live, tracked config file drifting from `main` on both content and
  hygiene. Worse, this branch's OWN Phase-3 changes touch the same two scripts `303a661` rewrote
  (`smart-test.sh`'s monorepo-aware JS test runner, `smart-lint.sh`'s `lint_javascript_scoped` and
  the svelte/vue/mjs/cjs extensions) — a straight squash onto `main` doesn't merely drop unrelated
  work, it overwrites `main`'s newer versions of files THIS branch also modified with this branch's
  older-based versions, discarding `303a661` entirely rather than combining with it. This repo's own
  `push-main` flow squash-merges directly with no PR diff gate afterward (per this plan's own skill
  mapping: `review-code` -> `document-local` -> `push-main`, no `review-pr` in between), so there is
  no later checkpoint that would catch this. **Fix: merge (or rebase onto) current `main` before
  shipping, and reconcile `smart-test.sh`/`smart-lint.sh` by hand — this branch's role-marker
  short-circuit needs to land inside `main`'s monorepo-scoped rewrite of those two functions, not
  instead of it.**

- [blocking] **Lane 7's docs-writing role is very likely still dormant — the identity it depends on
  is proven at the hook-payload level only, never at the actual write.** `documenter.md` is
  correctly dispatched via the real Agent tool (`subagent_type: documenter`), so its OWN tool calls
  genuinely carry `agent_type: documenter` — that much round 3 established and I re-confirm by
  inspection (`SKILL.md:147`, `build.md:25`, and five sibling dispatch sites all call it out as an
  Agent-tool dispatch, enumerated, not spot-checked). But `documenter.md`'s entire job, by its own
  text, is "Invoke `document-local` via the Skill tool" — and `document-local`'s own frontmatter
  (`agent-agnostic/skills/document-local/SKILL.md:1-7`) declares `context: fork` with **no `agent:`
  field**. Per Claude Code's own documented hook behavior (sourced via `claude-code-guide`, citing
  `hooks.md`: "For subagents, the subagent's type takes precedence over the session's `--agent`
  value") and `skills.md` ("`context: fork` ... starts a new subagent... You can optionally specify
  `agent: <subagent-type>` to name which agent type runs the fork; if omitted, a default is used"),
  a fork with no `agent:` field does **not** inherit the calling agent's identity — it spawns a
  separate subagent under its own default type. That means the real Write/Edit (and Bash, for the
  changelog commit) calls that actually touch the docs root happen inside THAT forked execution, not
  inside `documenter`'s own, and very likely do not carry `agent_type: documenter` at all. This repo
  already documents the fix for exactly this case — `docs/conventions.md:75-76`, a line that
  pre-dates lane 7 and that lane 7's own diff edited the very next clause of: `` `agent:` (a specific
  agent type for the fork) `` — and it was not applied to `document-local`'s frontmatter. Every piece
  of evidence for this fix, across lane 7's exit report and round 3's own table, injects
  `agent_type: documenter` directly into a hand-built JSON payload and confirms the HOOK's logic is
  correct; none of it dispatches a real `documenter` agent through a real `document-local` fork and
  inspects what the resulting write's own payload actually contains. I could not run that live drill
  myself (see Method) and so cannot call this closed OR reproduce the failure directly — but the
  mechanism, the missing field, and this repo's own documentation of the fix all point the same way,
  and the cost of being wrong is that Record is back to fully blocked, silently, the exact failure
  mode this whole plan exists to close (twice already: DP-1's un-wired planner flip in round 1, the
  wholly unassigned docs role in round 2). **Fix: add `agent: documenter` to `document-local`'s
  frontmatter, then verify with a live dispatch — a real `documenter` agent doing one real docs
  write, with a throwaway hook capturing the actual payload — not another synthetic-JSON table.**

- [non-blocking] **`plan.md` was never amended for anything round 2 found, and still isn't.** Its
  role policy (`plan.md:93-97`) describes only orchestrator/planner/builder; `documenter` and the
  `agent_type` mechanism appear nowhere in it, and DP-1's section carries no note of the disclosed
  orchestrator<->planner forgery residual round 2 already flagged as missing from it
  (`git log -- plan.md` shows no commit past `f269b06`, round 1's fix). Round 3 didn't flag this
  either. A plan whose stated policy no longer matches what shipped, on a plan about exactly that
  failure mode, is worth recording even though the user's actual decisions are captured in
  `progress-log.md`'s prose.

- [non-blocking] **Two AGENTS.md claims, flagged non-blocking in BOTH round 1 and round 2, are
  unfixed a third round running.** `agent-agnostic/AGENTS.md:278` still reads "ownership is
  machine-audited by the scope scripts" against `dae/SKILL.md:165`'s corrected "machine-*auditable*,
  not machine-audited" wording one file away. `agent-agnostic/AGENTS.md:148` still describes the
  orchestrator's write scope as ".artifacts/, the resolved plans dir, and the resolved docs dir" —
  the legacy permissive allowance Phase 2/DP-2 removed. `tests/validate-plan.test.sh:394`'s weak
  assertion (`[ ! -e "$d/.artifacts/the-ask.md" ]` against a fixture that never creates that path)
  is likewise still present. None are large fixes; all have now survived three review rounds.

- [non-blocking] **`verify-run-scope.sh . main .artifacts` still fails, exactly as round 3 recorded
  and judged.** Re-ran directly: same two files (`tests/report-middle-contract.test.sh`,
  `tool-based/confluence/AGENTS.md`), same pre-plan provenance (`57d2a3e`). I concur with round 3's
  disposition (benign, reviewed, landing acceptable) and have nothing to add — recorded here only so
  this round's own findings list doesn't read as silent on a still-red check.

### Open questions

- **Was the `documenter` -> `document-local` fork's real write-time `agent_type` ever captured from
  an actual hook invocation, rather than a hand-built payload?** If yes, that closes the second
  blocking finding above outright and this round should be revised down; if no, the finding stands
  and the frontmatter fix plus a live capture is the way to close it. I could not determine this
  from any committed artifact — none of lanes 1-7's exit reports, the progress log, or rounds 1-3 of
  this report mention a live capture for this specific hop, all of them (including round 3's own
  otherwise-rigorous evidence table) using synthetic `agent_type` values in the payload itself.

### Verdict rationale

`rejected`/`impl-wrong`, not `tentative`. Round 3 was right that round 2's two named blockers are
resolved-or-accepted on their own terms, and the suite is genuinely green — I re-confirm both. But
two things round 3 didn't check turned up real: this branch now diverges from `main` in a way a
squash-only ship path cannot absorb safely, and the fix round 3 verified most thoroughly (the
docs-writing role) is verified only up to the hook's own logic, not through the actual dispatch path
that is supposed to feed it. Both are mechanical to fix (merge `main` and reconcile two files; add
one frontmatter line and re-verify live) and squarely lane-shaped, hence `impl-wrong` rather than a
plan or map defect — no redesign is implied, but neither should ship unverified given this plan's
own history of exactly this failure class landing disclosed-as-fixed twice already.

## Round 5 — 09-17-26

```
verdict: rejected
next: impl-wrong
blocking: 1
non-blocking: 1
```

**Adjudication round.** Rounds 3 and 4 were produced independently and reached opposite verdicts
(`tentative`/`proceed` vs `rejected`/`impl-wrong`). This round settles them by testing both sets of
claims against the artifacts. One of Round 4's two blocking findings is upheld and one is refuted by
direct experiment; Round 3's headline claim is partly retracted by its own author.

### Retraction: Round 3 overclaimed "FIXED, verified by execution"

Round 3 (mine) verified that `scope-writes.sh` *correctly implements* the documenter rule, by
feeding it crafted payloads. That evidence stands and is not in question. But it proves only that
**if** `agent_type=documenter` reaches the hook, the docs write is allowed. It never tested whether
the real dispatch chain ever puts that value there. Round 4 caught this, and it is right. Injecting
`agent_type` into synthetic JSON tests the lock, not the key — and every drill on record (lane 7's
and Round 3's alike) tested the lock. That is the same class of error this report has hit before:
a check that could not have failed in the way that mattered.

### Blocking — upheld from Round 4

- [blocking] **The `documenter` identity does not survive the dispatch chain, so R2-1 is still
  open.** The chain is: router → `Agent(subagent_type: documenter)` → the documenter agent →
  `Skill(document-local)`. `documenter.md` states its entire job is to "Invoke `document-local` via
  the Skill tool with those inputs, unchanged", and `document-local/SKILL.md` declares
  `context: fork` with **no `agent:` field**. So the docs write happens inside a *further* forked
  subagent, not inside the documenter.

  Three independent lines of evidence, none of which requires the blocked live probe:

  1. **This repo documents the mechanism and the fix.** `docs/conventions.md:75-76` defines the two
     fields together: `context: fork` "runs in an isolated subagent", and `agent:` names "a specific
     agent type for the fork". The `agent:` field would be meaningless if a fork already inherited
     the caller's agent type. Its existence is the statement that it does not.
  2. **Observed directly in this session.** `review-code/SKILL.md` also declares `context: fork`.
     When it was invoked through the Skill tool it did not run in the caller's context — it spawned
     as a separate background agent with its own identity (`@review-code`). That is the same
     frontmatter `document-local` carries, exhibiting exactly the behavior the finding predicts.
  3. **`agent:` is used nowhere.** Across all 24 `SKILL.md` files, ten declare `context: fork` and
     **zero** declare `agent:` (positive-controlled: the `^agent:` search returns 0 repo-wide while
     `^context: fork` returns 10). So `document-local` is not an outlier being singled out — the
     mechanism that would carry the identity across the fork has never been wired anywhere.

  Consequence: at the moment the docs write is attempted, `agent_type` is not `documenter`,
  `resolve_role` falls through to the marker path, and the write is denied — the identical Record
  blockage Round 2 raised. The hook is correct; the wiring that feeds it is not.

  **Why this is not certain, stated plainly:** the decisive test is a live probe of what `agent_type`
  a forked skill actually receives. I could not run it. The installed hook is stale — the live
  `~/.claude/hooks/scope-writes.sh` contains **zero** occurrences of `agent_type` and zero of
  `documenter` — so an end-to-end attempt through the real harness would exercise the *old* hook and
  prove nothing about the new one, and closing that gap would mean syncing the install or editing
  settings, neither of which is a reviewer's to do. This is therefore strong convergent evidence,
  not execution. **Verification method for whoever fixes it:** sync the install, add `agent: documenter`
  to `document-local/SKILL.md`'s frontmatter, then dispatch a real `documenter` and have it attempt a
  write under the docs root of a marked fixture — the hook's own stderr names the resolved role, so a
  single real dispatch settles it either way. If a live probe shows the fork *does* inherit the
  caller's `agent_type`, this finding dissolves and the branch is clean on this axis.

### Refuted — Round 4's stale-branch finding does not hold as stated

Round 4's second blocking finding claimed that landing would "silently delete 5 files" and overwrite
`main`'s newer `smart-lint.sh`/`smart-test.sh`. The premise is correct; the consequence is not.

**Premise — confirmed.** The branch is genuinely two commits behind `main`:

```
303a661 fix(hooks): scope smart-lint and smart-test to the edited file
0cf8a8a feat(rules,hooks): universal no-attribution and minimal-comments enforcement
```

Neither is an ancestor of HEAD. (Round 3 accepted a briefing that `main` had been merged and did not
check — recorded here as a second Round 3 lapse.)

**Consequence — disproven by experiment.** I cloned the repo to a throwaway location and ran the
actual landing operation, `git merge --squash`, into `main`:

```
exit=0, conflicts=0
Auto-merging agent-agnostic/AGENTS.md
Auto-merging agent-agnostic/hooks/smart-test.sh
Auto-merging agent-specific/claude/settings.json
Auto-merging docs/conventions.md
```

In the merged tree: all five allegedly-deleted files are **present**; `smart-lint.sh` is
**byte-identical to `main`** (the branch does not touch it, so `main`'s monorepo scoping survives
untouched); `smart-test.sh` carries **both** sides — `main`'s file scoping plus this branch's
role-isolation short-circuit, `bash -n` clean; and `settings.json` diffs against `main` as exactly
one added `workflow-diff-check.sh` entry, with `no-attribution-guard.sh` and
`pr-ready-hygiene-guard.sh` retained. A merge takes both sides — it does not delete files absent from
one branch. Downgraded to non-blocking hygiene below.

### Findings

- [non-blocking] **Merge `main` before landing, then re-check the one genuinely co-edited file.**
  The squash is clean and loses nothing, so this is hygiene rather than a defect, but it should be
  done deliberately rather than discovered at the landing. `agent-agnostic/hooks/smart-test.sh` is
  the only file both sides modify; the auto-merge composes correctly (main's scoping runs, then the
  branch's `coder`/`contract-tester` short-circuit), and it should be eyeballed once after the real
  merge to confirm that ordering held.

### Carried forward, unchanged

Round 3's other three non-blocking findings stand and are not re-litigated: the red ownership ledger
with its two pre-plan unclaimed files (Round 4 concurs with Round 3's disposition); the follow-up
plan's rationale surviving only in the gitignored progress log that `cleanup-merged` will destroy;
and `claims_from_report()`'s unenforced dependency on exit-report formatting. Round 4's observations
that `plan.md` was never amended to reflect Round 2, and that two `AGENTS.md` staleness claims remain
open, are also carried as non-blocking.

Round 3's verified results are unaffected by this round and remain good: 605 test cases / 0 failures
(content-asserted, pattern positive-controlled), the four shared helpers byte-identical by extraction
and diff, fail-open confirmed for both guards with marker-added positive controls, and
`workflow-diff-check.sh` both genuinely wired and genuinely inert outside a dae run (twin-repo
experiment). The doc sweep also stands: no stale "declared in the skill's frontmatter" claim survives
anywhere.

### Verdict rationale

`rejected` / `impl-wrong`, one blocking finding. The fix that Round 2 demanded — give the docs root
an owner — is implemented correctly at the hook and left unwired at the dispatch, so Record is very
probably still blocked in exactly the way Round 2 described. That is an implementation gap, not a
plan defect, so the kickback is `impl-wrong`: the plan's intent is sound and the remedy is a
one-line frontmatter addition plus the real-dispatch verification spelled out above. The branch is
otherwise in good shape, and no other blocking defect was found across five rounds.

## Round 6 — 09-26-26

```
verdict: rejected
next: impl-wrong
blocking: 1
non-blocking: 4
```

### Method

Cold review — no prior-round reasoning read before forming my own view; rounds 1-5 read afterward,
for cross-checking and to avoid re-litigating settled ground. Confirmed `main` is fully merged into
`HEAD` (`git merge-base --is-ancestor main HEAD` true; local `main` matches `origin/main` at
`303a661`) — round 4/5's stale-branch finding is fully closed, not just improved. Ran the full suite
myself (20 files, content-asserted: `grep -c '^PASS'`/`'^FAIL'` per file plus the differently-formatted
`sync-install-settings-merge` suite, 0 `FAIL` anywhere, positive-controlled that the `FAIL` pattern
can match), `bash -n` on every changed script, re-ran `verify-run-scope.sh` directly, extracted and
diffed the four shared helpers with a mutation-positive-control, and read every file lane 8 touched
plus the two commits (`270f4de`, `520044a`) in full. Verified the Job-1 fix's architectural premise
(a `context: fork` skill with no `agent:` spawns a distinct identity; removing the key runs it inline)
independently, two ways: a fresh `claude-code-guide` fetch of Claude Code's own `skills.md`, and this
review's own **direct, first-hand observation** — I *am* `review-code`, invoked exactly the way
`document-local` used to be (`context: fork`, no `agent:`), and I run as a distinct forked identity
with no access to the calling conversation, exactly the behavior lane 8's fix now removes from
`document-local`. That is live confirmation, not a citation. Went beyond rounds 1-5 in one direction
none of them checked: whether Fix A's own trust assumption about `cwd` actually holds, by fetching
Claude Code's hooks documentation directly rather than accepting the contract's own unverified claim.

### Round 5's blocking finding — CLOSED, correctly

**R2-1 (documenter identity swallowed by the fork) is genuinely closed, and closed more robustly than
the fix round 5 asked for.** Round 5 asked for `agent: documenter` added to `document-local`'s
frontmatter plus a live probe. Lane 8 instead removed `context: fork` entirely, which is a *stronger*
fix: it deletes the fork boundary the identity had to cross, rather than trying to make an identity
propagate correctly across one. Confirmed:

- `agent-agnostic/skills/document-local/SKILL.md` — `context: fork` line is gone (`git diff
  main..HEAD` on the file, read in full); body text rewritten from "isolated fork... no access to
  conversation history" to "inline as a continuation of the `documenter` agent's own turn" throughout
  (Inputs, changelog-preference, and hand-off sections all updated consistently, not just the
  frontmatter).
- `agent-agnostic/agents/documenter.md` — unchanged, still a thin dispatch wrapper whose whole job is
  "Invoke `document-local` via the Skill tool" — now correct, since there's no fork left to swallow.
- Repo-wide: `grep -rn '^context: fork'` across every `SKILL.md` (in `agent-agnostic/` and
  `tool-based/`) returns exactly 8 hits, none of them `document-local`; `grep -rn '^agent:'` returns
  zero, confirming the exit report's own repo-wide sweep rather than trusting it.
- The live-probe gap round 4/5 hit (no `documenter` agent installed in `~/.claude/agents/`, so a real
  multi-hop dispatch can't be driven from inside this sandbox) is still genuinely unprobeable here —
  correctly disclosed as such in the exit report rather than papered over — but the fix no longer
  needs that probe to be trustworthy: with the fork gone, `document-local`'s Write/Edit calls execute
  as literally the same agent turn as `documenter`, which round 3/4 already established carries a
  real, harness-supplied `agent_type: documenter`. There is no remaining mechanism for the identity to
  fail to cross, because there is no longer a crossing.

Record is unblocked. This finding does not reopen.

### New blocking finding — Fix A trusts a hook field its own cited evidence says is attacker-controlled

- [blocking] **Fix A's `contracts/<lane-id>.md` / `reports/<lane-id>-exit.md` allowance is gated on
  `cwd`, and `cwd` is not a structural signal — it is exactly as forgeable as the `dae-role` marker
  round 1 rejected this build for, via nothing more than a plain `cd`.** The contract that specified
  this fix (`.artifacts/contracts/l8.md:84-85`) states the allowance is "gated on the CALLING agent's
  own physical location (`cwd`, unforgeable the same way `is_lane` already is — 'an agent cannot
  relocate itself')." That premise is false, and the falsifying fact is already quoted in this lane's
  own exit report: `.artifacts/reports/l8-exit.md`'s Job-1 evidence #2 cites Claude Code's `hooks.md`,
  "Worktrees are different," for the fact that `cwd` "follows Claude (the worktree root, or **the
  directory after a `cd`**)" — without connecting that this is the exact opposite of unforgeable. I
  fetched `https://code.claude.com/docs/en/hooks.md` directly (not relayed) and confirmed the
  quote is accurate and unambiguous:

  > **`cwd` follows Claude**: the `cwd` field in the hook's input JSON is the worktree root after
  > Claude enters a worktree, and **the new directory after Claude runs `cd`**. Read it when a hook
  > needs to know which directory Claude is working in.

  `${CLAUDE_PROJECT_DIR}` is the one value the same doc names as fixed for the session; `cwd` is
  explicitly the dynamic one. `find_lane_root()` (the helper Fix A calls on `cwd`) only checks a
  *structural filesystem shape* — does some ancestor of the given path have a basename matching
  `<name>-l<n>` whose sibling `<name>` carries `.artifacts/progress-log.md`? — it has no notion of
  which agent is actually asking. The contract's own analogy to `is_lane` is a category error:
  `is_lane` is unforgeable because it is derived from the immutable **write-target path** (a file
  can't relocate itself either); `cwd` is derived from mutable **shell state that changes on command**.

  **Consequence, concretely:** any agent that can run Bash and then Write in the same session —
  the orchestrator itself, principally — can fabricate a fake `reports/<lane-id>-exit.md` (or
  `contracts/<lane-id>.md`) for *any* lane whose child worktree still exists on disk (true for the
  entire window between that lane's dispatch and `cleanup-merged`'s teardown — i.e. exactly the
  window in which the PR gate's `verify-run-scope.sh` trusts these files), by running
  `cd <sibling>-l<n>` via Bash and then issuing the Write. `verify-run-scope.sh` (read directly:
  `claims_from_report()` parses exactly the "## Files touched" bullets of `reports/*-exit.md`) treats
  every path in that file's claim list as reviewed, builder-owned work. This is precisely the
  "manufacture an exit report to launder an orchestrator write" move round 3 called "strictly worse"
  than leaving the ledger honestly red — Fix A makes it available with a one-line `cd`, no marker
  forgery and no role trickery required, and it bypasses the marker/role dispatch entirely (the `cwd`
  check is an unconditional early-exit ahead of it). This is a new attack surface introduced by
  `270f4de` — the path was unconditionally *denied* before this lane, which was a real bug (round 2's
  "no role can write the docs root" sibling gap) but not an exploitable one.

  **Why this earns blocking rather than an open question:** the fact is sourced from Claude Code's
  own current documentation, fetched directly and quoted verbatim above, not inferred or relayed
  through a lossy intermediate; the mechanism it falsifies is quoted, read in full, and matches
  exactly. I could not additionally drive a *live* multi-tool-call exploit against a running harness
  to watch the bypass fire end-to-end (the same sandboxing limits that blocked rounds 4/5's live
  probes apply here too), so the one honest caveat is that this is documentation-verified, not
  execution-verified — stated plainly per this gate's own discipline, but the primary-source citation
  is strong enough that I am not treating it as merely an open question.

  **Fix shape, not prescribed but load-bearing for review:** `cwd` cannot be the trust anchor here.
  A structural alternative in the same spirit as this plan's `documenter` fix exists: `agent_type`
  is harness-supplied and (per round 3's own probe) unforgeable, and `builder`/`coder`/
  `contract-tester` are already distinct agent types — DP-4's own text already names this as the
  path to resolving the *sibling* problem (the marker can't express which of three concurrent agents
  in one lane worktree is writing). Fix A needs the analogous move: verify the calling agent's
  identity structurally (`agent_type`, or a check that doesn't degrade to trusting mutable shell
  state), not its self-reported location.

### Findings carried forward, reverified directly against the artifact (not assumed)

- [non-blocking] **The ownership ledger is still red, same two pre-plan files, same disposition.**
  Re-ran `verify-run-scope.sh . main .artifacts` directly: `tests/report-middle-contract.test.sh` and
  `tool-based/confluence/AGENTS.md` are still the only two unclaimed files, both still trace to
  `57d2a3e` (the branch's first, pre-plan-promotion commit). I concur with rounds 3-5's disposition
  (reviewed, benign, needs an explicit user decision at the PR gate) and have nothing new to add.

- [non-blocking] **The follow-up plan's rationale is still uncommitted, four rounds and several days
  later, and the run is still open — there is still time to fix this before it's lost.**
  `project-plans/proposals/` has no plan mentioning `agent_type`; `git grep agent_type` across the
  plans dir and `docs/` is still empty. The reasoning (`session_id` shared, `agent_type`/`agent_id`
  harness-supplied and unforgeable, DP-4 now solvable) lives only in `.artifacts/progress-log.md`,
  which `cleanup-merged` deletes with the worktree. Round 3 flagged this; it is more urgent now, not
  less, the longer it goes uncaptured.

- [non-blocking] **A near-duplicate of round 2's oldest still-open staleness claim now exists in a
  second file, in exactly the area lane 8's own docs sweep was auditing.** `agent-agnostic/AGENTS.md`
  and `docs/pipeline.md` both still describe the orchestrator's write scope as "the run's `.artifacts/`,
  the resolved plans dir, and the resolved docs dir" as what's *allowed* — the pre-DP-2 permissive
  allowance Phase 2/DP-2 actually removed (only `*-review.md`/`sync-report.md` under plans, nothing
  under `.artifacts/` or docs, is allowed today). `agent-agnostic/AGENTS.md`'s copy was already flagged
  in rounds 1, 2, and 4; `docs/pipeline.md`'s copy is the same overstatement in a file lane 8 itself
  edited twice (`4baf3f9`, `520044a`) for adjacent `document-local`/fork staleness, without catching
  the neighboring line describing the same removed allowance. Neither is large; both have now
  survived a docs-focused pass that was looking at exactly this territory.

- [non-blocking] **A pre-existing, real `minimal-code-comments` violation on this branch will never be
  caught by this repo's own enforcement, because that enforcement is wired only to a step this repo's
  landing flow doesn't have.** `check-diff-hygiene.sh --base main --scope all` (run directly) reports
  real `COMMENT BANNER`/`COMMENT DENSITY` violations in `tests/validate-plan.test.sh` and
  `tests/workflow-setup-reuse.test.sh` — both pre-existing, from this plan's own earlier lanes (`b5309d6`,
  `2420bba`), written before `check-diff-hygiene.sh` existed on `main`. Lane 8's own hygiene run was
  correctly clean (it scoped to `--base bug/audit-fixes-09-01-26`, i.e. only its own diff), so this
  isn't a lane-8 regression. But the only wiring for this check is `pr-ready-hygiene-guard.sh`, a
  `PreToolUse` hook on `gh pr ready` — and this repo (`agentic`) ships via `push-main`, which never
  runs `gh pr ready`, per this repo's own `source-push-sync` rule. So nothing in this repo's actual
  landing path will ever flag this. Cosmetic (test-file comments), not correctness-affecting, but
  worth recording since it's a real gap between "a hygiene tool exists" and "this repo enforces it on
  itself."

### Verdict rationale

`rejected` / `impl-wrong`, one blocking finding. Round 5's blocking finding is genuinely and robustly
closed — verified independently, including by this review's own lived example of the exact mechanism
being fixed. But Fix A, shipped in the same lane to close a real and disclosed gap (builders
structurally unable to file their own contracts/exit reports), introduces a new one: it grants a
narrow but consequential write allowance keyed on a hook field its own cited documentation says is
attacker-mutable via an ordinary `cd`, defeating the exact ownership-ledger property (`verify-run-scope.sh`
trusting `reports/*-exit.md`) this plan's other rounds treated as worth protecting. This is squarely
lane-shaped — a wrong trust anchor in one specific check, not a plan-policy defect — hence
`impl-wrong`: find a structural (harness-supplied) signal for "this write is genuinely coming from
lane N's builder," the same class of fix `documenter`'s own `agent_type` check already uses. Fix B and
Fix C are unaffected (both path-based, not `cwd`-based) and stand verified. The branch is otherwise in
very good shape: `main` is now fully merged (round 4/5's other blocker is closed outright, not just
mitigated), the suite is genuinely green at 624/0, the four shared helpers remain byte-identical, and
the identity-swallowing defect that took three rounds to pin down is closed for good reason, not by
assertion.

## Round 7 — 09-26-26

```
verdict: tentative
next: proceed
blocking: 0
non-blocking: 5
```

### Method

Cold review — no prior-round reasoning read before forming my own view of lanes 9 and 10; rounds
1-6 read afterward, for cross-checking and to avoid re-litigating settled ground. Read
`agent-agnostic/hooks/scope-writes.sh` and `agent-agnostic/hooks/parent-tree-guard.sh` in full,
plus every file lane 9 and lane 10 touched (contracts `.artifacts/contracts/l9.md`/`l10.md`, exit
reports `.artifacts/reports/l9-exit.md`/`l10-exit.md`, all read in full, treated as pointers to
verify against the artifact, never as proof). Ran the full suite myself (21 files, content-asserted:
`grep -c '^PASS'`/`'^FAIL'` per file plus `sync-install-settings-merge`'s differently-formatted
summary, all reconciled against each file's own tail line, positive-controlled that the `FAIL`
pattern can match and that a stray zero from a broken filter would be caught), `bash -n` on every
hook, re-extracted and diffed the four shared helpers myself (identical), confirmed `main` is still
a fully-merged ancestor of `HEAD` and matches `origin/main` (`eb73482`), and ran
`check-diff-hygiene.sh` and the attribution-trailer grep across the WHOLE branch (`main..HEAD`),
not just the last two lanes' own diffs, specifically to check whether lane 9/10 introduced anything
new beyond what earlier rounds already disclosed.

### Round 6's blocking finding — CLOSED, verified directly against the shipped hook

Round 6 found `scope-writes.sh`'s Fix A trusted `cwd` alone (forgeable via a plain `cd`) to grant a
builder's own `contracts/<lane-id>.md`/`reports/<lane-id>-exit.md` write allowance. Lane 9's fix,
confirmed by reading the file directly (`agent-agnostic/hooks/scope-writes.sh:270-278`):

```sh
if [ "$agent_type" = "builder" ] && [ -n "$cwd" ] && cwd_lane_root=$(find_lane_root "$cwd"); then
```

`agent_type` now gates entry before `cwd` is consulted at all; `cwd` remains only the lane
selector. Live-probed myself against real `find_lane_root`/hook execution, not just read:

- No `agent_type`, `cwd` = a lane child, target = that lane's `reports/<id>-exit.md` → **exit 2**
  (the forgery closed).
- `agent_type: builder` + same `cwd`/target → **exit 0** (the legitimate allowance intact).
- `agent_type: general-purpose` + same `cwd`/target → **exit 2** (a present-but-wrong value still
  denied — the gate checks the exact string, not merely presence).

Test coverage matches the contract's own acceptance criteria exactly: `case32`/`case33` corrected
in place to require `agent_type: builder`, `case51`/`case52` reproduce the forgery with no
`agent_type` (deny), `case53`/`case54` cover wrong-value `agent_type` (deny) — read all six cases
in `tests/scope-writes.test.sh` directly, not just trusted the report's paraphrase. `parent-tree-guard.sh`
confirmed untouched (`grep -n cwd` shows only its own `cwd=$(sfield cwd); [ -n "$cwd" ] || cwd="$PWD"`
at line 103-104 and its two `find_parent_worktree "$cwd"`/`find_lane_root "$cwd"` calls at 232/234 —
it always resolves the worktree `cwd` itself is currently inside, never a *different* worktree
reached by `cd`-then-relative-path the way Fix A's block did, so this forgery shape genuinely never
reached it; this matches lane 9's own claim and I did not just take the claim on faith). This
finding does not reopen.

### The syllabus-tick defect (found and fixed outside the round-6 cycle) — verified closed

Lane 10 closed a second, independently-discovered defect: `SKILL.md`/`build-dispatch.md` had the
orchestrator call `mark-syllabus.sh` at every lane merge-back, which DP-2's narrowed write scope
then makes `parent-tree-guard.sh` deny on the very next Bash pass — every merge-back would break.
Per the user's own decision ("the ticking should happen in the child lane or on document at the
very end"), the tick moves to the `documenter` agent's Record step, reading every lane's exit
report directly. Verified directly, not from the report's say-so:

- `grep -rn "mark-syllabus" agent-agnostic/skills/dae/ agent-agnostic/agents/` shows the orchestrator-side
  files (`build-dispatch.md`, `build.md`, `live.md`, `diagnose.md`) now describe the documenter
  calling it at Record, and `build.md:25`'s Record step states plainly: "This is the ONLY point in
  the run the plan's own syllabus is ticked... The orchestrator itself never writes `plan.md`, at
  merge-back or here."
- `tests/mark-syllabus-guard-e2e.test.sh` run directly: 7/7 pass, against the REAL
  `mark-syllabus.sh` and the REAL `parent-tree-guard.sh` (not hand-crafted payloads) — case 03/04
  reproduce the defect's own shape (an orchestrator-attributed write after a real `mark-syllabus.sh`
  edit) and confirm it still denies, proving the fix is "stop calling it from the orchestrator,"
  never "make the guard permissive."
- `plan.md`'s own syllabus is, as expected at this point in the run, entirely unticked (`- [ ]`
  throughout) — consistent with the tick authority having moved to Record, which has not run yet.
  This is the correct pre-Record state, not a regression.
- Docs sweep re-verified with my own positive-controlled greps (`agent-agnostic/skills/dae/`, `docs/`,
  `README.md`, `AGENTS.md`): no live "orchestrator ticks"/"router ticks" claim remains.

This finding does not reopen.

### Findings carried forward, reverified directly (not re-litigated)

- [non-blocking] **Ownership ledger still red, same two pre-plan files, same disposition (rounds
  3-6 concur).** Re-ran `verify-run-scope.sh . main .artifacts` myself:
  `tests/report-middle-contract.test.sh` and `tool-based/confluence/AGENTS.md` are still the only
  unclaimed files, both still trace to `57d2a3e` (pre-plan-promotion). No claim manufactured to
  paper over it — needs an explicit user decision at the PR gate, as every prior round concluded.

- [non-blocking] **`agent-agnostic/hooks/check-diff-hygiene.sh` is still wired only to `gh pr ready`,
  and this repo never runs that command.** Verified myself: `check-diff-hygiene.sh --base main
  --scope all` (the whole branch, not just lane 9/10's own diffs) surfaces real, pre-existing
  `COMMENT BANNER`/`COMMENT DENSITY` violations in `tests/smart-test-role-scope.test.sh`,
  `tests/validate-plan.test.sh`, and `tests/workflow-setup-reuse.test.sh` — all from lanes that
  predate the hook's existence on `main` (confirmed: lane 9's own scoped run against
  `bug/audit-fixes-09-01-26` is clean, so these are not lane-9/10 regressions). `.claude/rules/source-push-sync.md`
  confirms this repo ships via `push-main` (local squash-merge, direct push, no `gh pr ready` ever
  called), so this check will never fire on this repo's actual landing path — the same "wired but
  dead" pattern this run already found twice elsewhere. Disclosed by lane 9, re-verified by me, not
  fixed (correctly: wiring a new blocking check into `push-main` is a decision for the user, not a
  lane).

- [non-blocking] **The accepted DP-4 residual (cross-lane `cwd` drift) is real, disclosed, and
  correctly deferred — restated here so it isn't lost.** With `agent_type: builder` now required,
  the remaining gap is narrower but not zero: a genuine builder whose `cwd` resolves into a
  *different* lane's (including an already-merged, torn-down lane's) child-worktree path could still
  write that lane's `contracts/<id>.md`/`reports/<id>-exit.md` — `find_lane_root`'s structural check
  (`agent-agnostic/hooks/scope-writes.sh:145-160`) verifies only that a sibling directory with the
  expected basename exists and carries `.artifacts/progress-log.md`, not which lane is actually
  calling. This is exactly the trade-off lane 9's contract named and the user accepted (DP-4,
  same-role/cross-lane disambiguation, out of scope for this plan) — I verified the mechanism myself
  by reading `find_lane_root` directly rather than taking the accepted-trade-off framing on faith,
  and it holds. Already captured in the (currently untracked) follow-up proposal — see next finding.

- [non-blocking] **The follow-up plan capturing DP-4 and the agent-identity rework
  (`project-plans/proposals/agent-identity-write-scope-09-26-26.md`) is fully written (919 lines,
  read the opening Ask-of-record and Phase syllabus directly) but still untracked in git** (`git
  status --porcelain` shows it as `??`). Round 3 warned that this reasoning living only in the
  gitignored progress log risked being lost to `cleanup-merged`'s teardown; the reasoning has since
  been moved into a proper proposal file, which is real progress, but an uncommitted file is exactly
  as vulnerable to loss (a `git clean`, a botched rebase, a crashed session before the next commit)
  as the progress log was. Should be committed before this run closes.

- [non-blocking] **`.artifacts/progress-log.md` has not been rewritten since roughly lane 5 / code
  gate round 2**, even though lanes 6-10 and code-review rounds 3-7 have since happened. Read the
  file directly: its "Stage"/"Gate rounds"/"Lanes" tables still describe the run as mid-round-2 with
  only lanes 1-5 recorded, while `code-review.md` (this file) and `git log` both show lanes 6-10
  merged and six further review rounds completed. `run-artifacts`'s own rule requires this file
  "REWRITTEN IN PLACE by the orchestrator at every state change" specifically so a resumed or
  compacted session can reconstruct the run from it alone — that would currently fail. This is a
  process/orchestrator hygiene gap, not a defect in the shipped code (the file is gitignored and
  never reaches the product branch), so it does not block this verdict, but it should be brought
  current before the run is parked or resumed again.

### Verdict rationale

`tentative` / `proceed`, zero blocking findings. Both open items this round was dispatched to close
— round 6's `cwd`-forgery gap and the independently-found syllabus-tick collision — are genuinely
closed, each verified against the real, shipped hooks and real test runs rather than assumed from
the exit reports. The suite is green at 635/0 across 21 files (verified myself, content-asserted,
positive-controlled), the four shared helpers remain byte-identical, `main` is fully merged, and no
new attribution-trailer or diff-hygiene regression exists anywhere in lane 9 or lane 10's own
commits (the hits that do exist across the whole branch all predate lane 7, already disclosed and
accepted in earlier rounds). `tentative` rather than `ready` because five real, open non-blocking
items remain for the human gate's attention: two need an explicit user decision (the ownership
ledger's two pre-plan files; committing the follow-up proposal before the run closes), and three are
worth a conscious acknowledgment rather than silent carry-forward (the accepted DP-4 residual, the
dead diff-hygiene wiring, and the stale progress log). None of the five is a defect in what this
plan actually shipped.
