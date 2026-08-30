# `-w none`: treat the current checkout as the run's parent

**Status:** parked on purpose (08-28-26). Not stale. Do not delete or supersede without asking the
user.

This was Phase 2 of `dae-live-type-08-26-26` until 2026-08-28, when the user split it out: the
`live` type does not need it — `live` uses the standard parent/child worktree scheme like every
other type — and the `-w none` redesign deserves to be designed on its own terms rather than
carried along as a rider on an unrelated feature. Splitting it kept that plan's scope honest and
left this idea somewhere it can be picked up deliberately. It is therefore NOT abandoned work and
NOT a stale leftover: `plan-format` says an abandoned plan is deleted, but this one is waiting, and
the difference matters. Ask the user before removing it, superseding it, or folding it back into
another plan.

## Phase syllabus

- [ ] Phase 1: Design the in-place parent mode
  - [ ] 1.1: Design `-w none` as a parent-location flag and specify the setup-script mode it needs

---

## Goal & scope

**Ask of record:** none — no durable ask exists yet. This is a PARKED IDEA, not a
requirements-backed plan: it was carved out of `dae-live-type-08-26-26` on 2026-08-28 when the
user decided that plan should ship without it. Nothing here has been settled with anyone, so the
ask-vs-plan check at the gate cannot run and must be reported as NOT PERFORMED. The first real
work on this plan is capturing an ask.

**The idea being parked.** Today `orchestrators/skills/dae/worktree-modes.md` defines `none` as
"no worktree: every stage runs in the repo on the current branch", and
`orchestrators/skills/dae/build.md` draws the consequence: "single-lane plans only (there is
nowhere to isolate parallel builders)". The proposal is to narrow what the flag means:

- `-w` would locate the **parent** only — `new` | `resume <name>` | `none` — and never say
  anything about child lanes.
- In `none` mode the current checkout would BE the parent. Builder lanes would still get their
  own child worktrees under the workflows dir, cut off the current branch and merged back into
  the user's checkout, so parallel lanes become legal in all three modes.
- `orchestrators/hooks/workflow-setup.sh` would need a mode that creates ONLY the run dir — no
  worktree, no branch — so `.artifacts/` and its `.gitignore` entries keep a single owner and the
  router's `RUNDIR:` parsing stays mode-independent.

**Explicitly out of scope until an ask exists.** Everything. This plan is a placeholder with one
design subphase; it must not be dispatched to a builder as written.

**Relationship to other plans.** `dae-live-type-08-26-26` originally carried this as its Phase 2
and dropped it on 2026-08-28. That plan supersedes nothing here and this supersedes nothing
there; the two are independent, and `live` uses the standard parent/child worktree scheme like
every other type.

---

## Stack & MAJOR versions

Verified from the environment; this repo carries no package manifest, so the stack is the shell
toolchain its hooks bind to.

| Component | Version / flavor | Verified from |
|---|---|---|
| Bash | 5.1.16(1) | `bash --version`; `orchestrators/hooks/workflow-setup.sh:1` |
| Test framework | none — hand-rolled `tests/*.test.sh`, run as `bash tests/<name>.test.sh` | `ls tests/*.test.sh` |

---

## Conventions to enforce

1. **This repo is the SOURCE; `~/.claude/` is an install** — edit `orchestrators/`, never the
   install (`.claude/rules/source-push-sync.md:1-3`).
2. **The run dir is derived from the parent, not configured** (`run-artifacts`): it is
   `.artifacts/` at the root of the run's parent worktree, whatever that turns out to be.
3. **`workflow-setup.sh` owns the run dir and the `.gitignore` entries.** Any design that has the
   router create them itself needs to justify splitting that ownership.

---

## Phase 1 — Design the in-place parent mode

### 1.1: Design `-w none` as a parent-location flag and specify the setup-script mode it needs

**File scope:** none yet — this subphase produces a design, not an edit. When it lands, the
files it would touch are `orchestrators/skills/dae/worktree-modes.md`,
`orchestrators/skills/dae/build.md`, `orchestrators/skills/dae/build-dispatch.md`,
`orchestrators/hooks/workflow-setup.sh`, and `tests/workflow-setup-reuse.test.sh`.

**Pattern to follow:** `worktree-modes.md`'s `new` section, and `workflow-setup.sh`'s existing
`--parent` path.

**What to design.** Answer, with evidence, the questions that were open when this was carved out:

- **Where does the run dir live, and who creates it?** A new setup-script mode (`--here` /
  `--in-place` / `--rundir-only` — the name is undecided) that creates only
  `<repo-root>/.artifacts/{contracts,reports}`, ensures the `.gitignore` entries, and prints the
  same field set every other invocation prints. Confirm the alternative — the router doing it in
  prose — is genuinely worse before rejecting it.
- **Does `workflow-setup.sh --parent` already work against a parent branch that has no worktree?**
  Verify against the script and `tests/workflow-setup-reuse.test.sh` rather than assuming; if it
  does, the child-lane half of this idea costs nothing.
- **What happens on a branch that is not `<type>/<name>`?** `agent-agnostic/skills/push-pr/SKILL.md`
  verifies the branch shape and refuses anything else, and in `none` mode the current branch is
  whatever the user is standing on. Options include guarding at setup and offering `-w new`, or
  relaxing the `push-pr` check to "never the base, never main". Pick one, with reasoning.
- **Does the base-branch guard still hold?** It must: `push-policy` never pushes the base, so a
  run started on the base branch dead-ends at `push-pr --stage open-draft`.

**Acceptance criteria.** A written design that names the setup-script mode and its stdout
contract, settles the non-conformant-branch question, and states which existing files change and
how. It must NOT be a code change: this subphase's deliverable is the amended plan itself, at
which point this file gets re-planned properly against a real ask.

**Test approach.** None — nothing executable is produced. The design is verified by review
against `worktree-modes.md`, `workflow-setup.sh`, and `push-pr/SKILL.md` as they actually stand.

**Test oracle:** `existing suite` (no new tests; the existing suites must stay green when the
design is eventually implemented).

---

## Risks, open questions, decision points

- **This plan has no ask.** It must not be promoted or dispatched until someone states the
  requirement. A plan with no ask has nothing for the gate to diff against.
- **It may never be worth doing.** The motivation was convenience for ad-hoc runs; the standard
  `-w new` parent/child scheme already serves every type, `live` included. If nobody misses
  `-w none`, deleting this proposal is the correct outcome — `plan-format` is explicit that an
  abandoned plan is deleted, never archived to `completed/`.
- **Open: the setup-script mode's flag name** — `--here`, `--in-place`, or `--rundir-only`.
- **Open: the non-conformant-branch policy** — guard at setup, or relax `push-pr`.

---

## Skill mapping

| Work | Executor |
|---|---|
| Capturing the ask | the user, conversationally, before any planner runs |
| This plan | `planner` agent, module `plan-feature` |
| The plan gate | `review-plan` (+ `validate-plan.sh`, `plan-lifecycle.sh check`) |
| Implementation, once designed | `builder` agents per `build-dispatch.md` |
