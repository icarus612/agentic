# Agentic guard fixes: four false or missing flags in the dae hooks

### Ask of record — source: /tmp/claude-1000/-home-icarus64-repos-money-makers-mythic-made/1fd39a8a-64fb-4758-aaa6-5e08ac3a6d7f/scratchpad/ask-of-record-agentic-guard-fixes.md

Copied verbatim on 11-05-26:

**11-05-26** — fix agentic and get it pushed up

**11-05-26 — context (the open items the user was answering, as the orchestrator listed them; not the user's words)** — Agentic tooling fixes not yet started: the `parent-tree-guard` false denies; the `check-diff-hygiene` reworded-comment count; builder sub-agents that keep running after their lane closes; and confirming the guard doesn't fire when the session is in another repo.

## Phase syllabus

- [ ] Phase 1: Regression tests and confirmation, observed before any fix
  - [done] 1.1: parent-tree-guard regressions for the promote move and the documenter's docs writes, observed RED (lane 1)
  - [done] 1.2: check-diff-hygiene regression for a reworded comment block, observed RED (lane 2)
  - [done] 1.3: lane-artifact-shell-guard regression for a packet agent's shell write into the parent, observed RED (lane 3)
  - [done] 1.4: Confirm whether parent-tree-guard is inert when the session cwd is another repo (lane 1, after: 1.1)
- [ ] Phase 2: Fixes in the hook sources
  - [done] 2.1: parent-tree-guard credits moved plans content and agent-identity writes (lane 1, after: 1.1, 1.4)
  - [dropped] 2.2: parent-tree-guard resolves the run from paths named in the command, conditional on 1.4 (lane 1, after: 1.4, 2.1)
  - [done] 2.3: check-diff-hygiene pairs reworded comment lines within a hunk (lane 2, after: 1.2)
  - [done] 2.4: lane-artifact-shell-guard denies lane-agent shell writes into a marked parent (lane 3, after: 1.3)
  - [done] 2.5: Builder hand-back waits for its packet agents; merge-back re-checks the parent tree (lane 3, after: 2.4)
- [ ] Phase 3: Integration
  - [done] 3.1: Register parent-tree-guard's credit mode on PostToolUse Write-family hooks (after: 2.1)
- [ ] Phase 4: Verify
  - [done] 4.1: Whole suite, `bash -n`, helper-identity check, live replay of the 1.4 captures (after: 2.2, 2.3, 2.5, 3.1)

## Goal & scope

**Goal.** Fix four defects in the dae hook layer of the `agentic` repo, each written up in
`docs/known-issues.md` of this worktree. Each fix gets a regression test that is observed red first.

**In.**

1. `parent-tree-guard.sh` gives a sticky false `deny` in two cases. (a) `plan-lifecycle.sh promote`
   moves a planner-approved proposal to `<slug>/plan.md`, and the ledger's `(hash, path)` key loses
   the `ok`. (b) The documenter's Record-stage `docs/` edits are judged by the `dae-role` marker
   (`orchestrator`) on the orchestrator's next Bash call. Known-issues entry
   "`parent-tree-guard.sh`: a promoted plan gets a sticky `deny`" (`docs/known-issues.md:63-98`).
2. `check-diff-hygiene.sh` counts reworded existing comments as new comments. Known-issues entry
   at `docs/known-issues.md:100-115`.
3. Builder sub-agents keep running after the builder hands back, and they write into the parent
   worktree. Known-issues entry at `docs/known-issues.md:143-158`.
4. `parent-tree-guard.sh` is likely inert when the session cwd is a different repository. This is
   confirmed first (1.4); the fix (2.2) ships only if the guard does not fire. Known-issues entry at
   `docs/known-issues.md:160-174`.

**Out.**

- **The "false ATTRIBUTION on prose" class in `check-diff-hygiene.sh`.** It is already fixed in
  source. `ATTR_LINE` (`check-diff-hygiene.sh:66-77`) anchors the marker to the start of a line, and
  I verified this on 11-05-26 against the worktree copy. Prose naming both markers mid-sentence
  (including a "- the `<marker>:` marker" bullet) exited 0 under `--scope attribution`. The positive
  control, a real `<marker>: x <y@z>` line in an added file, exited 1 with `ATTRIBUTION in added
  code`. The installed `~/.claude/hooks/check-diff-hygiene.sh` is byte-identical to the source. The
  claim that it is "still unfixed" lives only in the orchestrator's auto-memory note, not in
  `docs/known-issues.md`. So there is nothing to fix, and that memory note is stale (see Risks).
- Replacing the `dae-role` marker with harness identity everywhere. That is the parked proposal
  `project-plans/proposals/agent-identity-write-scope-09-26-26.md`. This plan does not supersede it
  and leaves it parked. The fixes here are compatible with it, because they credit by content hash
  and `agent_type` and do not entrench the marker.
- Terminating a builder's background sub-agents at the harness level. The hook input carries no
  parent-agent id (see Stack), so nothing can mechanically tie a packet agent to its lane's closure.
  Defect 3 is mitigated by prevention (2.4), detection (2.2 and the existing guard) and prose (2.5).
- Docs and known-issues status updates. These belong to Record (the `documenter` agent), not to any
  builder lane. Builders are denied the docs root anyway (`scope-writes.sh:310-322`).
- Hook `timeout` fail-open and `if` narrowing. That is a separate known-issues entry, untouched here.

**Landing.** This repo lands through the repo-local `push-main` skill
(`.claude/skills/push-main/SKILL.md`), not `push-pr`. Step 7 of that skill runs
`agent-agnostic/hooks/sync-install.sh <old>..HEAD` to carry the fixes into `~/.claude`. The ask's
"get it pushed up" is satisfied by the orchestrator running `push-main` after `review-code` and
Record. It is an orchestrator stage, not a builder subphase, so it has no syllabus entry.

## Stack & MAJOR versions

- **Bash** hook scripts under `agent-agnostic/hooks/`, all `#!/usr/bin/env bash` with
  `set -uo pipefail`. Pattern source: the header of `parent-tree-guard.sh` and of `scope-writes.sh`.
- **python3**, used inline by the hooks through heredoc or `python3 -c`. See
  `check-diff-hygiene.sh:60-159` and `lane-artifact-shell-guard.sh:8-158`, which use only the stdlib
  (`json`, `shlex`, `re`, `posixpath`). The repo has no Python manifest, and none is needed: stdlib
  only.
- **git**, called with `git -C`, and **sha256sum** for ledger hashes (`parent-tree-guard.sh:331-337`).
- **Claude Code hook input.** The common fields are `session_id`, `cwd` ("Current working directory
  when the hook is invoked"), `tool_name` and `tool_input`. Inside a subagent the input adds
  `agent_id` and `agent_type`. No parent-agent id is documented. Source:
  `https://code.claude.com/docs/en/hooks` (common input fields), fetched 11-05-26. The repo has no
  package manifest for any of this. Hook wiring lives in `agent-specific/claude/settings.json`
  (`hooks`), and `tests/hook-registrations.test.sh` pins it.
- **Tests** are standalone `tests/*.test.sh` scripts that print `PASS:`/`FAIL:` lines and a summary,
  and exit non-zero on any failure. Baseline on 11-05-26 (worktree at `a5138bf`):
  `parent-tree-guard` 57/0, `scope-writes` 97/0, `lane-artifact-shell-guard` 94/0,
  `hook-registrations` 70/0. `tests/` has no `check-diff-hygiene` test today.

## Conventions to enforce

1. **Fix the source, never the install.** Edit `agent-agnostic/hooks/`. `~/.claude/hooks/` is
   updated only by `sync-install.sh` after landing (`push-main` step 7).
2. **Shared helpers stay byte-identical.** `find_parent_worktree`, `find_lane_root`, `resolve_role`
   and `resolve_root_dir` are duplicated verbatim between `scope-writes.sh` and
   `parent-tree-guard.sh` (`scope-writes.sh:74-86`), and `parent-tree-guard.test.sh` case 19 pins
   this. No subphase here changes those four functions. New logic goes outside them. If a change to
   one turns out to be unavoidable, it lands in both files in the same commit.
3. **Hooks fail open on their own errors** (missing marker, git failure, unparseable payload) and
   deny only on a confirmed violation (`parent-tree-guard.sh:58-61`).
4. **No false flags.** A user directive recorded in auto-memory says a false deny is a defect, never
   noise. Every fix carries both a must-pass control and a must-still-fail control.
5. **Minimal code comments** (`minimal-code-comments` rule, universal): no banners, no narration in
   tests. Rationale goes in the docs root at Record.
6. **`shell-discipline`**: one command per Bash call, no `cd && git`, assert on output content and
   not only on exit status, and watch for mawk/ugrep (`awk` must not take `--` after the program).
7. **`verify-dont-assume`**: every zero result needs a positive control. 1.4 and 4.1 exist
   specifically for this.
8. **No attribution trailers of any kind**: no co-author trailer, no session-id trailer, and no
   session URL in any commit or message. Builders do not push. `push-main` is the sole publisher.
9. **Delete old code; no compatibility layers** (global CLAUDE.md). Where 1.1 shows an existing
   test asserting the buggy behavior, that assertion is rewritten, not kept beside the new one.

## Phase 1: Regression tests and confirmation, observed before any fix

### 1.1 — parent-tree-guard regressions for the promote move and the documenter's docs writes, observed RED

- **File scope:** `tests/parent-tree-guard.test.sh`.
- **Pattern to follow:** cases 32-37 in the same file (`run_guard`, `new_parent_worktree_with_role`,
  `new_parent_worktree_linked_with_role`, `resolved_plans_dir`, and `WORKFLOW_SETUP --set-role`).
  Add a `resolved_docs_dir` helper alongside `resolved_plans_dir` if none exists.
- **Rewrite existing case 36.** It currently ASSERTS the bug: after the orchestrator's `promote`,
  `run_guard` must exit 2 (`tests/parent-tree-guard.test.sh:1504-1506`). Change that step to expect
  exit 0, because the moved, planner-approved content must pass. Keep the case's real intent, that a
  ledger deny sticks across a role flip, by making the denied artifact an orchestrator shell-edit of
  the promoted `plan.md` (new content, new hash). Then flip to `planner`, still expect exit 2, and
  expect stderr to name `plans-ledger` and not print the planner trailer.
- **New cases** (numbered after 37):
  - **Move passes.** Planner writes `proposals/x.md` and the guard records its credit. `--set-role
    orchestrator`, then `plan-lifecycle.sh promote`, then `run_guard` exits 0. Repeat with the
    proposal tracked (committed before promote, so `git mv` produces an `R` porcelain line) and
    untracked (plain `mv`).
  - **Launder control, Bash path (must FAIL against the round-1 design).** Under `orchestrator`,
    shell-write content X to `<plans>/x-01-02-26/foo-review.md`. `run_guard` exits 0, because a
    review file is allowed and is recorded `ok`. Then `cp` that file to `<plans>/x-01-02-26/plan.md`,
    and `run_guard` must exit 2. Under the round-1 design (inherit from any `ok` line under
    plans_root), the copy inherits `ok H <review path>` and exits 0, so this control fails there.
    That is the regression it pins.
  - **Launder control, credit-mode path.** Same as above, except the review file arrives as a
    PostToolUse Write payload with no `agent_type` and `dae-role=orchestrator`, so credit mode
    records it. After the `cp`, the Bash payload must exit 2.
  - **Documenter-sourced plan content does inherit.** A documenter Write to `<slug>/plan.md`, then
    an orchestrator `cp` of it to a second plans path, exits 0. A source credit written under the
    documenter role is inheritable.
  - **Fresh orchestrator plans file still denied.** Under `orchestrator`, write a new plans file whose
    hash has no `ok` anywhere: exit 2. Case 35 exists. Keep it, and add a variant where an `ok` for
    a DIFFERENT hash exists at the same path.
  - **Hash inheritance never crosses outside plans_root.** An `ok <hash> <path>` entry outside
    plans_root (hand-seeded into the ledger) does not clear a plans file with that hash.
  - **`absent` never inherits.** Seed `ok absent <plans path A>`, delete a tracked plans file B
    under the orchestrator, and expect exit 2.
  - **Documenter Write credit.** Under `dae-role=orchestrator`, write `docs/topic.md` and pipe a
    PostToolUse **Write** payload to the guard: `{"tool_name":"Write", "agent_type":"documenter",
    "agent_id":"a1", "cwd":"<some other dir>", "tool_input":{"file_path":"<abs docs/topic.md>"}}`.
    It exits 0 (credit mode never denies). Then a Bash payload with no `agent_type` and
    `cwd=<parent>` also exits 0. This second step is RED today, and it reproduces the
    home-countdown-mobile-taps observation.
  - **Documenter file symlink.** A symlink outside docs_root points into it
    (`apps/x/README.md -> ../../docs/apps/x/README.md`). It is created by a Bash payload with
    `agent_type: documenter`, the `ln -s` call itself, whose pass records `ok link:<sha> <abs>`.
    The docs file it targets is credited by a documenter Write payload. The next orchestrator Bash
    pass exits 0.
  - **Documenter credit is per content.** After the credit, an orchestrator shell edit of the same
    docs file (new hash) makes the next Bash payload exit 2.
  - **Fresh orchestrator docs file still denied.** A docs file written under `orchestrator` with no
    credit makes the Bash payload exit 2. Existing case 05 covers part of this. Assert the message
    names the path.
  - **Credit mode ignores non-crediting identities.** A Write payload with `agent_type` `coder`
    (role resolves from the marker to `orchestrator`) for a docs path records nothing. The next Bash
    payload exits 2.
  - **Credit mode is inert outside a run.** A Write payload whose target has no marker in its
    ancestry exits 0 and creates no ledger.
  - **Documenter deletion is credited at its exact path.** A tracked `docs/old.md` is deleted
    (`git rm`) by a Bash payload with `agent_type: documenter`. That pass exits 0 and records
    `ok absent <abs docs/old.md>`. The next orchestrator Bash pass exits 0.
  - **Deletion credit never inherits.** With `ok absent <docs/old.md>` in the ledger, an
    orchestrator deletion of a different tracked docs file exits 2.
  - **Orchestrator deletion is still denied.** An orchestrator `git rm` of a tracked docs file
    exits 2.
  - **Directory symlink is credited by its link text.** A documenter Bash pass creates
    `apps/x/docs -> ../../docs/apps/x`, a directory symlink that is untracked. That pass exits 0, and
    the ledger line's hash is the `link:` form, not `absent`. The next orchestrator pass exits 0.
  - **Directory symlink control.** The orchestrator creates a second, different directory symlink
    into docs: exit 2.
- **Reproduction (observed vs expected).** Run `bash tests/parent-tree-guard.test.sh`. Expect the
  rewritten case 36's promote step and the move and documenter-credit cases to FAIL against
  `a5138bf` (observed: exit 2, `DENIED — product file changed ... plan.md` or `... docs/topic.md`;
  expected: exit 0). The documenter deletion and directory-symlink credit cases also FAIL today.
  The controls must PASS already: fresh orchestrator file, both launder controls, per-content,
  non-crediting identity, deletion never inherits, orchestrator deletion, the second directory
  symlink, and no marker. A control that fails before the fix means the fixture is wrong. The two
  launder controls pass on `a5138bf` because the key is the exact (hash, path) pair. They exist to
  fail any design that inherits from orchestrator-recorded lines.
- **Acceptance:** the red/green split above, captured as command and output in the exit report.
- **Test oracle:** `new contract tests` (the regression) plus `existing suite`.

### 1.2 — check-diff-hygiene regression for a reworded comment block, observed RED

- **File scope:** `tests/check-diff-hygiene.test.sh` (new).
- **Pattern to follow:** the bookkeeping, `pass`/`fail`, scratch `mktemp -d` and `trap` cleanup of
  `tests/lane-artifact-shell-guard.test.sh:1-40` and `tests/parent-tree-guard.test.sh:34-80`. Build
  fixtures as throwaway git repos (`git init -b main`, commit a base, branch, commit a change), then
  run `check-diff-hygiene.sh --base main --repo-dir <tmp> --scope comments`.
- **Cases:**
  - **Pure reword passes (RED today).** The base has a 3-line `//` comment block in `f.ts`. The
    change rewords each line in place. Reproduced on 11-05-26 against `a5138bf`: exit 1, `COMMENT
    BANNER in f.ts: 3 consecutive added comment lines (limit 2) near added-line 2`. Expected: exit 0.
  - **Reword under density passes (RED today).** A file whose change rewords 10 or more existing
    comment lines plus a few code lines. Today it trips `COMMENT DENSITY`. Expected: exit 0.
  - **New banner in one hunk still fails.** Three or more new consecutive comment lines added with
    no removed comment lines in the hunk: exit 1, `COMMENT BANNER`.
  - **Reword plus net-new still fails.** A hunk that rewords 2 comment lines and adds 3 new ones,
    giving 3 unpaired consecutive lines: exit 1.
  - **Separate compliant comments across hunks pass.** Four 2-line comments in four hunks: exit 0.
    This pins the existing hunk-boundary fix (`check-diff-hygiene.sh:105-107`).
  - **Removed comments elsewhere do not pair.** Comments removed in hunk A and a new 3-line banner in
    hunk B: exit 1. Pairing is per hunk.
  - **`#` comments in `.sh`.** A reword of a `#` block in a `.sh` file passes, and a new `#` banner
    fails.
  - **Refusal is unchanged.** An uncommitted-only change exits 2 with `REFUSING`. This guards
    `check-diff-hygiene.sh:40-50`.
  - **A deleted file's lines never pair.** One commit deletes file `a.ts`, which held a 3-line
    comment block. The same commit adds a new 3-line banner in `b.ts` (the next file in the diff).
    Expect exit 1. `a.ts`'s `-` lines arrive after `--- a/a.ts` / `+++ /dev/null` and must not be
    attributed to another file.
  - **Replacement within one hunk passes (DP-6, accepted).** A hunk that removes a 3-line comment
    block and adds a DIFFERENT 3-line comment block in its place exits 0. Comment volume is
    unchanged. This case pins the accepted per-hunk design so a later change cannot silently flip
    it.
- **Fixture note.** Git's default diff context is 3 lines. Separate the changes in any multi-hunk
  fixture by at least 7 unchanged lines, so each change gets its own `@@` hunk. Assert the hunk
  count with `git diff main...HEAD | grep -c '^@@'` before trusting a case.
- **Reproduction:** `bash tests/check-diff-hygiene.test.sh`. The two reword cases FAIL before 2.3,
  and all others PASS.
- **Acceptance:** red/green split as stated, with evidence in the exit report.
- **Test oracle:** `new contract tests`.

### 1.3 — lane-artifact-shell-guard regression for a packet agent's shell write into the parent, observed RED

- **File scope:** `tests/lane-artifact-shell-guard.test.sh`.
- **Pattern to follow:** the existing `run_hook` payload cases in the same file. For the marker
  fixtures, follow `tests/parent-tree-guard.test.sh`'s `new_parent_worktree_linked_with_role` (a
  linked worktree with `.artifacts/progress-log.md`). Copy the fixture locally; do not source the
  other test.
- **The observed defect, from the subagent transcript** (session `1fd39a8a…`,
  `subagents/agent-a5a32a6b4e2fbb604.jsonl`, `agentType: contract-tester`,
  `parentAgentId: a255b5a1c04588e51`). At `2026-11-05T17:30:15Z`, with transcript `cwd`
  `/home/icarus64/repos/money-makers/mythic-made`, it ran
  `cd /home/icarus64/repos/agentic/.workflows/hook-timeouts-and-if-scoping && sed -i '/^# --- [0-9]/d' tests/hook-registrations.test.sh && …`.
  Its earlier, legitimate call at `17:24:11Z` targeted the `-l1` child. So the stray write was an
  explicit `cd` into the PARENT, not a relative path landing there by accident.
- **Cases:**
  - **Deny (RED today).** `agent_type: contract-tester`, `cwd` = an unrelated dir, command
    `cd <linked parent> && sed -i 's/a/b/' tests/x.sh`. Expect exit 2 with a message naming the
    parent and the lane-agent rule.
  - **Deny for `coder` and `builder`.** Same, with a redirect (`echo x > <parent>/src/y`), `tee`,
    and `cp a <parent>/z`.
  - **Allow: own child.** The same commands aimed at `<parent>-l1/…` (the sibling lane child) exit 0.
  - **Allow: the parent's `.artifacts/`** (non-lane-file paths, e.g. `.artifacts/tmp/probe`). This
    shell-write rule does not cover them. Lane-file shapes stay denied by the existing rule.
  - **Allow: main session.** No `agent_type` at all, so the orchestrator's own shell writes are not
    this hook's concern (parent-tree-guard covers them): exit 0.
  - **Allow: main-checkout marker.** A marked root that IS the main checkout (`--worktree none` or a
    scratch marker, where git-dir equals common-dir) with `agent_type: builder`: exit 0, because a
    `-w none` builder legitimately writes there (`scope-writes.sh` `resolve_role`).
  - **Allow: reads.** `cat <parent>/src/y`, `git -C <parent> log` and `ls <parent>` exit 0. Only
    writes are gated.
  - **Allow: a `sed` script token that looks like an absolute path.** Run
    `sed -i '/^# --- [0-9]/d' <child>/tests/x.sh` (the observed command shape) as `contract-tester`
    against its own child. `check()` sees the script token too, and that token walks to no marker,
    so the call exits 0. The same command aimed at `<parent>/tests/x.sh` exits 2.
  - **Allow: git failure fails open.** A marked root on which `git rev-parse` fails (e.g. a
    corrupted `.git` file) with `agent_type: builder` exits 0.
  - **Allow: other subagent types.** `agent_type: documenter`, `planner` or `Explore` writing into
    the parent are not lane agents and are out of this rule (exit 0 here; the other guards apply).
- **Reproduction:** `bash tests/lane-artifact-shell-guard.test.sh`. The deny cases FAIL (exit 0
  observed, exit 2 expected), and all allow cases PASS.
- **Acceptance:** red/green split, with evidence in the exit report.
- **Test oracle:** `new contract tests` plus `existing suite`.

### 1.4 — Confirm whether parent-tree-guard is inert when the session cwd is another repo

- **File scope:** no product files. The evidence goes in the exit report, plus throwaway fixtures
  under `/tmp` or the session scratchpad, removed afterwards. If the result is "inert", add a unit
  case to `tests/parent-tree-guard.test.sh` that encodes the captured payload shape (same file as
  1.1, same lane).
- **What is already known (planner evidence, 11-05-26).** It is strongly indicated, but not yet
  confirmed.
  - Direct replay, positive control: a scratch repo with a linked worktree marked
    `.artifacts/progress-log.md` and `dae-role=orchestrator`, with ` M product.sh`. Piping
    `{"cwd":"<that parent>","tool_name":"Bash"}` to `~/.claude/hooks/parent-tree-guard.sh` exits 2
    and names `product.sh`.
  - Live probe: from this subagent session (cwd `/home/icarus64/repos/money-makers/mythic-made`),
    `cd <that parent> && ls` produced no PostToolUse deny feedback. The next call's `pwd` printed
    the mythic-made root, so the cwd reset.
  - Caveat: the live probe has no positive control. No run could be made with the session cwd inside
    the fixture, so "no feedback" may also mean the feedback was not surfaced.
  - The stray contract-tester call's transcript `cwd` was the mythic-made root (1.3). The guard
    walks from the payload `cwd` (`parent-tree-guard.sh:103-104,231-238`), and mythic-made has no
    `.artifacts/progress-log.md` (only `.artifacts/reports/`). That checkout would therefore be
    inert there.
- **Procedure.**
  1. Build the dirty, marked, linked-worktree fixture described above. Replay a payload with `cwd`
     set to the fixture, expect exit 2. This is the positive control proving the fixture is dirty
     and the guard denies when it looks.
  2. Capture real payloads. Run a headless session `claude -p --settings <capture.json>` whose
     settings add extra PostToolUse hooks on `Bash` and on `Write`. Each copies its stdin to a
     file. Start it with cwd = a second, unrelated scratch git repo, and prompt it to:
     - (a) run `cd <fixture parent> && ls` in the main session;
     - (b) spawn one subagent that runs the same command (the contract-tester's shape);
     - (c) have that subagent Write one file under the fixture parent's docs root.
     The (c) capture is the positive check that a subagent's PostToolUse Write payload carries
     `agent_type` and `agent_id`, which 2.1's credit mode depends on.
  3. Positive control for the capture: the same headless run started with cwd = the fixture parent
     itself.
  4. Replay each captured payload into `agent-agnostic/hooks/parent-tree-guard.sh` and record the
     exit code and the captured `cwd` for each.
- **Decision rule.** The step 3 control must replay to exit 2.
  - If EITHER step 2 Bash capture, main session (a) or subagent (b), replays to exit 0, the defect
    is CONFIRMED and 2.2 proceeds. A main session that follows the `cd` while the subagent keeps the
    unrelated cwd is the contract-tester shape, and it counts as confirmed.
  - Only if BOTH replay to exit 2 (cwd follows the `cd` in both, as the hooks docs say "the new
    directory after Claude runs `cd`") does the guard fire. 2.2 is then marked `[dropped]` with
    that evidence as the recorded reason.
  - Separately, report whether capture (c) carries `agent_type`. That result gates 2.1 change 3.
- **Effect of a dropped 2.2.** A `[dropped]` 2.2 counts as closed for scheduling. It satisfies
  4.1's `after: 2.2` edge, and 4.1 then skips its 2.2-specific replays.
- **Assumption to verify:** that `claude -p` accepts `--settings <file>` to add a hook for one run.
  The flag appears in `claude --help` on this machine, but its hook-merging behavior is unverified.
  If it is unavailable, return `needs-input` rather than inferring from transcripts alone.
- **Acceptance:** the step 1 control exits 2; the (a), (b), (c) and step 3 captures exist; the
  verdict (confirmed or not) and the `agent_type` presence in (c) are stated with the replay
  outputs.
- **Test oracle:** `existing implementation`. The shipped guard's observed behavior on real payloads
  is the truth source. No coder; the builder runs the capture itself.

## Phase 2: Fixes in the hook sources

### 2.1 — parent-tree-guard credits moved plans content and agent-identity writes

- **File scope:** `agent-agnostic/hooks/parent-tree-guard.sh` (header doc-comment and the
  ledger/classification code after line 274). The four shared helpers are NOT touched (Convention 2).
- **Pattern to follow:** the existing ledger (`parent-tree-guard.sh:328-375`) and the payload
  field extraction (`sfield`, `:89-93`). For extracting `tool_input.file_path`/`notebook_path`,
  follow `scope-writes.sh:261-265`.
- **Changes.**
  1. **Move inheritance from role-tagged source credits (defect 1a; DP-5).**
     - **Writing source credits.** Whenever the guard records an `ok` for a ledgered path, in a
       scan or in credit mode, and the resolved role is `planner` or `documenter`, it also appends
       `src <hash> <abs>`. It never writes a `src` line under `orchestrator`, `builder`, `scratch`
       or any other role, and never for hash `absent`.
     - **Using them.** After the exact-path `deny` check (unchanged, still first) and the exact `ok`
       check, a plans-root path with a non-`absent` hash is clean when the ledger holds
       `src <same hash> <path under plans_root>`. On that match, append `ok <hash> <new abs>` so
       later lookups are exact. Do not append `src`: the copy is not a new source.
     - **What it closes.** Plain `ok` lines are never inherited. An orchestrator-recorded
       `ok H <foo-review.md>` therefore cannot clear a `cp` of that file to `plan.md`. That is the
       round-1 laundering hole (`plan-review.md` round 1, blocking finding), closed because the
       ledger records which role vouched for the content.
     - **Implementation constraints.** Implement the prefix test without `awk --` (mawk) and
       without a regex built from the path. A fixed-string field comparison is enough.
  2. **Ledger scope widened to the docs root (defect 1b, part 1).**
     - `in_plans` becomes "in a ledgered root": `plans_root/*` or `docs_root/*`, still only for
       `is_lane=0`. Docs paths get the same judge-once, stick-to-hash behavior. Move inheritance
       stays plans-root only, as the known-issues entry proposes. The deny message for a ledger hit
       keeps naming `plans-ledger` (file name unchanged).
     - **Deletions.** A documenter deletion can only happen through Bash, because no other tool
       deletes. The documenter's own PostToolUse Bash pass therefore judges it under the
       `documenter` role and records `ok absent <abs>` at that exact path. `absent` never inherits
       (change 1), so the credit cannot clear any other deletion.
     - **Symlinks.** `content_hash` hashes the UNRESOLVED status path `$marked/$path` when that path
       is a symlink: `link:<sha256 of readlink text>`. This replaces today's `absent` for a
       directory symlink. Regular files keep their content hash, and missing paths stay `absent`.
       A symlink credit is then keyed to the link text and not to a value every directory shares.
       The ledger key path is still the realpath'd `abs` that `role_allows` judges.
  3. **Credit mode (defect 1b, part 2).** When the payload's `tool_name` is
     `Write|Edit|MultiEdit|NotebookEdit`, the hook runs in a credit-only mode:
     - Take the target path from `tool_input` and `realpath -m` it.
     - Find the marker from the TARGET (`find_parent_worktree`, then `find_lane_root`), never from
       `cwd`. Exit 0 if there is no marker or it is a lane root.
     - Resolve the role with the existing `resolve_role` (so `agent_type=documenter` resolves to
       `documenter`).
     - If the target is under a ledgered root and `role_allows` it, append `ok <hash> <abs>` unless
       an exact `deny` or `ok` for that hash and path exists.
     - Always exit 0. `scope-writes.sh` is the PreToolUse gate for these tools, so credit mode only
       records and never denies, and it never scans the rest of `git status`.
     Bash and Stop payloads keep today's full-scan behavior.
- **Why this is the right identity signal (evidence).** Write and Edit payloads from a subagent
  carry `agent_type`, which the harness supplies and a marker file cannot forge (hooks docs;
  `scope-writes.sh:199-206` already trusts it for `documenter`). The guard's Bash-time scan cannot
  tell who wrote a path. Write-time crediting binds the identity to the exact content hash at the
  moment of the write. A later orchestrator shell edit changes the hash and is judged fresh.
  Alternatives considered are in DP-1.
- **Dependency on 1.4.** Credit mode assumes a subagent's PostToolUse Write payload carries
  `agent_type`. 1.4 captures one. If that capture shows no `agent_type`, stop and return
  `plan-wrong` instead of implementing change 3.
- **Acceptance:** every 1.1 case is green, including both launder controls and the deletion and
  symlink cases. `tests/parent-tree-guard.test.sh` and `tests/scope-writes.test.sh` are fully green,
  including case 19 (helpers byte-identical). `bash -n` passes.
- **Test oracle:** the 1.1 regression plus `existing suite`.

### 2.2 — parent-tree-guard resolves the run from paths named in the command, conditional on 1.4

- **Dropped.** 1.4 found that the hook payload `cwd` follows `cd` for the main session and for subagents, so the guard already fires cross-repo; the decision rule dropped 2.2.
- **Conditional:** runs only if 1.4 CONFIRMS the defect. Otherwise it is closed as `[dropped]` with
  1.4's evidence.
- **File scope:** `agent-agnostic/hooks/parent-tree-guard.sh` (run-resolution block at `:231-240`
  and the scan, restructured to loop over marked roots), and `tests/parent-tree-guard.test.sh` (new
  cases).
- **Pattern to follow:** `lane-artifact-shell-guard.sh:8-131`, the inline python3 `shlex` walker.
  It strips heredoc bodies and command substitutions, tracks `cd`/`pushd`/`popd` and subshells, and
  resolves relative tokens against a virtual cwd seeded from the payload `cwd`. Reuse that technique
  inline (a separate copy, not sourced; the standalone-hook rule is in `scope-writes.sh:74-86`).
- **Changes.**
  - **Bash payloads.** Collect start paths: the payload `cwd`, every `cd`/`pushd` target, every
    `git -C <dir>` argument, and every absolute-path token. Relative tokens are resolved against the
    tracked cwd. Run `find_parent_worktree`/`find_lane_root` on each, de-duplicate the marked roots,
    and run today's role, tamper and scan logic once per root. Aggregate offenders, and name each
    offender's root in the message.
  - **Stop payloads** carry no command. Record every marked root a Bash pass resolves in a
    per-session registry keyed on the payload `session_id`. A Stop pass scans those roots plus its
    `cwd`. The location is a decision point (DP-2); the recommendation is
    `${XDG_CACHE_HOME:-$HOME/.cache}/dae/sessions/<session_id>.runs`. Skip entries whose marker no
    longer exists. If the registry cannot be read, fall back to `cwd` only (fail open).
  - Interpreter one-liners and scripts that write to paths they do not name stay an accepted gap,
    the same one documented for `lane-artifact-shell-guard.sh` in `docs/pipeline.md:243-251`.
- **New test cases.**
  - A Bash payload with `cwd` = an unrelated dir and `cd <dirty parent> && ls` exits 2 (the 1.4
    shape, RED before this subphase).
  - The same with `git -C <dirty parent> status`.
  - An absolute-path token only (`cat <dirty parent>/product.sh`) exits 2.
  - A clean parent named in the command exits 0.
  - An unrelated dir with no marker named exits 0.
  - Two dirty parents named in one command produce both offenders, each with its root.
  - Stop with a registry entry for a dirty parent and an unrelated `cwd` exits 2.
  - Stop with a missing registry falls back to `cwd`, which is inert: exit 0.
  - Every existing cwd-based case is unchanged.
- **Acceptance:** all new and existing cases are green, and case 19 is green.
- **Test oracle:** `new contract tests` plus `existing suite`.

### 2.3 — check-diff-hygiene pairs reworded comment lines within a hunk

- **File scope:** `agent-agnostic/hooks/check-diff-hygiene.sh` (the python block `:103-145` only).
- **Pattern to follow:** the existing collector at `:104-114`, which already records hunk breaks as
  `None`.
- **Change.** Within each hunk, also count the REMOVED comment lines (`-` lines, excluding `---`,
  that satisfy `is_comment`). Walk the hunk's added lines in order. Each added comment line consumes
  one removed comment line from the same hunk while any remain, and a consumed line is treated as
  paired: not a new comment. Paired lines break neither code runs nor comment runs. Concretely, they
  are skipped for both the banner run and the density count. Unpaired added comment lines count as
  today. `tot` for density still counts every non-blank added line, so a reword cannot raise the
  percentage. Attribution scanning (`:93-101`) is untouched.
  - **File reset.** A `--- ` line sets `cur = None`. `+++ b/<path>` sets the file as today, and
    `+++ /dev/null` leaves `cur = None`. Lines of a deleted file are therefore dropped, never
    attributed to the previous file. Removed and added lines are recorded only while `cur` is set.
  - **Replacement pairing (DP-6).** Pairing is by count within a hunk, with no similarity test. A
    hunk that replaces one comment block with a different one of equal or smaller length passes,
    because it adds no net commentary. This is accepted and pinned by the 1.2 case.
- **Acceptance:** every 1.2 case is green, including the must-still-fail controls (new banner in one
  hunk, reword plus net-new, cross-hunk non-pairing). `bash -n` passes. A re-run of the
  11-05-26 reproduction (3-line reword) exits 0.
- **Test oracle:** the 1.2 regression.

### 2.4 — lane-artifact-shell-guard denies lane-agent shell writes into a marked parent

- **File scope:** `agent-agnostic/hooks/lane-artifact-shell-guard.sh`.
- **Pattern to follow:** the same file's `check()`/`write_deny()` and its tracked `vcwd`
  (`:46-77`). Every write-destination site already funnels through `check()`: redirects, `tee`,
  copier destinations, `sed -i`/`perl -i` operands, `truncate` and `dd of=`.
- **Change.**
  - Read `agent_type` from the payload.
  - When it is `builder`, `coder` or `contract-tester`, `check()` additionally resolves each write
    target to an absolute path. Absolute tokens are used as they are, relative ones are joined to
    `vcwd`, and tokens with `$`/`~` that cannot be resolved are skipped.
  - Walk the resolved path's ancestors for `.artifacts/progress-log.md`. If it finds a marked root
    M that is a LINKED worktree (`git -C M rev-parse --git-dir` differs from `--git-common-dir`)
    and the target is not under `M/.artifacts/`, deny. If either `rev-parse` fails, allow: fail
    OPEN, per Convention 3. A git hiccup in a `--worktree none` run must never block a legitimate
    builder. The detection backstop (2.2, 2.5) still sees any write that slips through.
  - The message names the target, M, and the rule: "a lane agent writes only inside its own child
    worktree; the parent is merged into, never written by, a lane".
  - Update the one-line header to describe both responsibilities.
  - The lane-file and `lane-bind.sh` rules are unchanged.
- **Why this location (evidence).** The stray write was a Bash `sed -i` (1.3). `scope-writes.sh`
  is not on Bash (`scope-writes.sh:61-63`), and the Write tool path is already covered for
  packet agents: a packet agent's Write into the parent resolves the role from the marker as
  `orchestrator` and is denied (`scope-writes.sh:299-307,379-405`). This hook is already the
  PreToolUse Bash walker with cwd tracking, so extending it adds prevention without a new
  registration. Alternatives are in DP-3.
- **Acceptance:** every 1.3 case is green, and the full `tests/lane-artifact-shell-guard.test.sh` is
  green (baseline 94). `bash -n` passes.
- **Test oracle:** the 1.3 regression plus `existing suite`.

### 2.5 — Builder hand-back waits for its packet agents; merge-back re-checks the parent tree

- **File scope:** `agent-agnostic/agents/builder.md`, `agent-agnostic/skills/dae/build-dispatch.md`.
- **Pattern to follow:** `builder.md`'s Exit report section (`:35-46`) and `build-dispatch.md`'s
  merge-back step 5 (`:19-24`).
- **Changes.**
  - `builder.md`: before writing the exit report, every coder and contract-tester you spawned must
    have delivered its completion notification. Stop any that is still running (TaskStop) and do not
    resume one after hand-back. A background packet agent alive past your envelope is a defect in
    your lane. This is prose backing the mechanical 2.4 deny.
  - `build-dispatch.md` step 5: after removing a lane's child worktree, run `git -C <parent> status
    --porcelain`. A non-empty result stops the schedule, and the paths are surfaced as an unclaimed
    write, the way step 1 treats UNREPORTED files. This is cheap and catches what 2.4 cannot, such
    as interpreter one-liners.
- **Assumption to verify:** that `TaskStop` is available to the `builder` agent (`tools: All
  tools`, `builder.md` frontmatter has no `tools:` line). The builder confirms it in its exit report.
  If it is not available, the sentence says to wait for the notification only.
- **Acceptance:** both prose changes are present. `grep` for the new step text in both files gives a
  positive hit, controlled by a grep for a known existing phrase in each. No other text in either
  file changes.
- **Test oracle:** `existing suite` (the prose has no executable oracle;
  `tests/build-dispatch-verify-scope.test.sh` must stay green).

## Phase 3: Integration

### 3.1 — Register parent-tree-guard's credit mode on PostToolUse Write-family hooks

- **File scope:** `agent-specific/claude/settings.json`, `tests/hook-registrations.test.sh`. These
  are shared touchpoints, which is why this is a serialized subphase and not part of lane 1.
- **Pattern to follow:** the existing `PostToolUse` `Write|Edit|MultiEdit` group (smart-lint,
  smart-test, claude-install-drift), and the `TABLE`/`COUNTS`/`unscoped` blocks in
  `tests/hook-registrations.test.sh:18-49,137-144`.
- **Change.** Add `~/.claude/hooks/parent-tree-guard.sh` with `timeout: 60` and no `if` to the
  `PostToolUse` `Write|Edit|MultiEdit` group. In the test, add the TABLE row, raise that group's
  count from 3 to 4, and add an `unscoped PostToolUse Write|Edit|MultiEdit` assertion. Note that
  this matcher lacks `NotebookEdit`, which matches today's group. Notebook writes are not a docs or
  plans path in practice; widening the matcher would also change smart-lint and smart-test, so it is
  out of scope.
- **Acceptance:** `bash tests/hook-registrations.test.sh` is green with the new row. `python3 -c
  'import json;json.load(open(...))'` parses the settings.
- **Test oracle:** `existing suite` (the registration contract test, extended).

## Phase 4: Verify

### 4.1 — Whole suite, `bash -n`, helper-identity check, live replay of the 1.4 captures

- **File scope:** none (verification only).
- **Steps.**
  - Run every `tests/*.test.sh` and confirm each prints `0 failed` (assert on the summary text).
  - Run `bash -n` on every changed hook.
  - Confirm `parent-tree-guard.test.sh` case 19 is green.
  - Re-run the 1.4 capture replays against the fixed guard. The step 2 payloads must now exit 2 if
    2.2 shipped.
  - Re-run the 1.2 reproduction against the fixed `check-diff-hygiene.sh`.
  - Run `check-diff-hygiene.sh --base main --scope all` over this branch as a positive end-to-end
    control. It must pass on this plan's own diff.
- **Note.** The 1.4 capture replays were not applicable because 2.2 was dropped.
- **Acceptance:** all of the above, quoted as command and output.
- **Test oracle:** `existing suite`.

## Risks, open questions, decision points

### Decision points (human)

- **DP-1: how the guard credits the documenter's writes.**
  - (a) *Recommended:* credit mode on PostToolUse Write-family (2.1 and 3.1). It records the exact
    path and hash under the writing agent's `agent_type`, and it is deterministic.
  - (b) Widen the ledger to docs only, with no new registration. This credits only if the documenter
    happens to make a Bash call after its writes, which is not guaranteed.
  - (c) Register the guard on `SubagentStop`. A full-tree scan at the documenter's stop would credit
    any docs change present at that moment, including another agent's. Blocking at `SubagentStop`
    would also hold every builder and coder stop hostage to unrelated dirt.
- **DP-2: where 2.2's per-session run registry lives** (only if 1.4 confirms).
  - (a) *Recommended:* `${XDG_CACHE_HOME:-$HOME/.cache}/dae/sessions/<session_id>.runs`. This is the
    same cache root `resolve-scratch.sh` uses for out-of-repo scratch (`artifact-locations`).
  - (b) No registry: the Stop pass stays cwd-only, and only Bash passes resolve from the command.
    The cost is that Stop's backstop stays inert in cross-repo sessions.
- **DP-3: defect 3's mechanism mix.**
  - (a) *Recommended:* all three: the 2.4 PreToolUse deny, the 2.2 detection, and the 2.5 prose
    plus the post-merge `git status`.
  - (b) Drop 2.4 and rely on detection plus prose. This is less gating, but the stray write still
    lands and has to be reverted by a corrective lane, as happened on hook-timeouts-and-if-scoping.
  - (c) Put 2.4 in a new hook instead of extending `lane-artifact-shell-guard.sh`. That gives a
    cleaner name, but needs another registration, test row and install.
- **DP-5: how move inheritance avoids laundering** (round-1 blocking finding).
  - (a) *Chosen:* role-tagged `src <hash> <path>` lines, written only under the `planner` and
    `documenter` roles. Inheritance consults only `src`.
  - (b) Inherit from any `ok` line except those whose path is `*-review.md` or `sync-report.md`.
  - **Evidence for (a).** Today the orchestrator's plans allowance is exactly those two basenames
    (`parent-tree-guard.sh` `role_allows`, orchestrator branch; mirrored in `scope-writes.sh:400-402`).
    `scope-writes.sh` has already grown beyond them, though, to `explore-map-*.md` and the committee
    files in `.artifacts/`. The two allowlists evolve independently.
  - **Why that matters.** With (b), any future widening of the orchestrator's plans allowance
    silently reopens the hole, unless someone remembers to widen a second exclusion list in the same
    commit. With (a), inheritability follows from WHO vouched for the content, so the hole stays
    closed whatever the orchestrator is later allowed to write.
  - **Cost of (a).** One extra ledger line kind. The launder controls in 1.1 fail against both the
    round-1 design and any (b) whose exclusion list misses a basename the orchestrator can write.
  - **Limit.** The `planner` role still comes from the forgeable `dae-role` marker. That gap belongs
    to the parked `agent-identity-write-scope-09-26-26` proposal and is unchanged here.
- **DP-4: known-issues outcome for defect 3.** The deny plus detection mitigates the damage, but
  nothing yet terminates a builder's sub-agents. The recommendation is that Record rewrites that
  entry's Status to "mitigated" with pointers to 2.4, 2.2 and 2.5, rather than removing it.
- **DP-6: comment-block replacement within one hunk** (check-diff-hygiene).
  - (a) *Recommended, accepted:* count-based pairing. Replacing a comment block with a different
    one of equal or smaller length passes, because net commentary is zero. A 1.2 case pins this.
  - (b) Pair only lines that are textually similar (for example a `difflib` ratio threshold). This
    is stricter, but adds a tunable threshold that can produce its own false flags on legitimate
    rewording.
- **DP-7: documenter deletions and directory symlinks.**
  - (a) *Chosen:* credit them safely (2.1 change 2). The reason is that both can only happen
    through Bash. The documenter's own PostToolUse Bash pass judges them under the `documenter`
    role and records an exact-path credit. Deletions are recorded as `ok absent <path>`, which is
    never inherited. Symlinks are hashed by their link text (`link:<sha>`), not `absent`.
  - (b) Accept and record the gap. Every documenter page removal would then false-deny on the next
    orchestrator Bash call: the same class this plan fixes.
  - **Residual.** The credit needs the documenter's Bash pass to FIND the run. In a cross-repo
    session (cwd elsewhere) that requires 2.2's command-path resolution. If 1.4 drops 2.2, the
    capture already showed that cwd follows the `cd`, so the pass finds it either way.

### Risks and open questions

- **Cross-run flags (2.2).** A command that merely names a path inside ANOTHER in-flight run's dirty
  parent will deny, on that run's state. Such a flag is true, because a product change in a marked
  parent is a violation whichever run owns it, but it can surprise. The message names the root.
- **Hash inheritance (2.1).** Any plans path whose content equals content vouched for by a planner
  or a documenter (a `src` line) passes, including a `cp` instead of an `mv`. This is accepted: the
  content is the approved content. Orchestrator-recorded `ok` lines never inherit (DP-5). A `deny`
  for the exact path and hash still wins, because it is checked first.
- **Existing in-flight runs.** Ledgers written before this fix keep their sticky `deny` lines.
  Commit through the owning stage as today, or delete the run's `plans-ledger` entry by hand. This
  plan adds no migration (Convention 9).
- **Stale memory note.** The orchestrator's auto-memory
  (`check-diff-hygiene-two-false-results.md`) says the prose ATTRIBUTION class is "still UNFIXED".
  The source shows it fixed (see Goal & scope, Out). The orchestrator should correct that note. It
  is not a repo file, so it is not in any lane.
- **1.4 tooling.** If `claude -p --settings` cannot add a capture hook, 1.4 returns `needs-input`.
  2.2 then waits on a human-run capture.
- **Builder sandbox.** 1.4 spawns a headless session, which costs a model run. If the builder is not
  permitted to spawn one, that is the same `needs-input`.

### Known-issues entries that flip at Record

These changes belong to the documenter at Record, not to a lane.

- "`parent-tree-guard.sh`: a promoted plan gets a sticky `deny`" becomes **resolved**, both the move
  class and the documenter class. Remove it, or mark it "fixed and awaiting removal" per the page's
  own status vocabulary.
- "`check-diff-hygiene.sh`: reworded comments count as new comments" becomes **resolved**.
- "Builder sub-agents keep running after the builder hands back" becomes **mitigated** (DP-4).
- "`parent-tree-guard.sh` likely inert when the run's repo is not the session's cwd" becomes
  **resolved** if 2.2 ships. If 1.4 shows the guard fires, the entry is removed and the 1.4
  evidence is recorded as the reason.
- `docs/pipeline.md:243-259` (the hook catalogue) gets updated for: the docs root in the ledger;
  credit mode on Write-family PostToolUse; command-path and registry run resolution if shipped; and
  the lane-agent parent-write deny.

## Skill mapping

- **planner** writes this plan, and amends it on gate findings.
- **review-plan** is the plan gate.
- **builder**, three lanes in parallel:
  - Lane 1 (`l1`): 1.1, 1.4, 2.1, 2.2. All of it touches `parent-tree-guard.sh` and its test, so it
    is serial within the lane.
  - Lane 2 (`l2`): 1.2, 2.3.
  - Lane 3 (`l3`): 1.3, 2.4, 2.5.
  - The lane file scopes are disjoint: lane 1 has `parent-tree-guard.sh` and
    `tests/parent-tree-guard.test.sh`; lane 2 has `check-diff-hygiene.sh` and
    `tests/check-diff-hygiene.test.sh`; lane 3 has `lane-artifact-shell-guard.sh`,
    `tests/lane-artifact-shell-guard.test.sh`, `builder.md` and `build-dispatch.md`.
  - Each builder spawns a `coder` for the fix subphases and a `contract-tester` for the regression
    subphases. 1.4 is builder-run, with no coder.
- **3.1** is a single serialized builder dispatch after lane 1 merges (it touches `settings.json`
  and `tests/hook-registrations.test.sh`).
- **4.1** is the verification pass, run by a builder or by `review-code`.
- **review-code** is the code gate.
- **documenter** (`document-local`) handles Record: the `docs/known-issues.md` flips,
  `docs/pipeline.md`, the changelog, and the syllabus ticks.
- **push-main** (repo-local, `.claude/skills/push-main`) lands the work on `main` and runs
  `sync-install.sh <old>..HEAD` to install into `~/.claude`. No `push-pr`.
