# Agent Skills Architecture — Open Items

> **Implementation plan:** the workers-and-gates redesign (planner/builder workers, dev
> stage table, map/sync-status/diagnose consolidation) is planned in
> [`../workers-and-gates-redesign-07-26-26.md`](../workers-and-gates-redesign-07-26-26.md),
> which adopts items 2 (partially), 4, and 9 (for `dev`) below and re-scopes item 1.
> Item 8 remains a separate migration.

Gap analysis of the original skills-architecture conversation against the repo as of 2026-07-22. Items the repo already implements (role-based grouping, forked review gates, hook enforcement, `--worktree resume` resumability, conditional debug, orchestrated-use trigger phrasing, parallel builder lanes) have been dropped; external-marketplace material is out of scope. What remains is every item with a real gap, each stated as **current** (verified against the actual files) vs **proposed**. Items 8 and 9 are **decided** (adopt): item 8 carries a full repo-sweep catalog of scriptable prose (2026-07-22), item 9 the target skill-directory structure; the two share one migration.

---

## 1. `orchestrate` vs `dev` description overlap

**Current.** `orchestrate/SKILL.md`'s description triggers on "any multi-part task — … parallel implementation," and `dev`'s on "run the whole workflow on a feature, fix, or project." Both plausibly answer "build me X," so dispatch between them is nondeterministic. (An earlier note claimed `orchestrate` already required a caller-supplied step list — verified false against the file.)

**Proposed.** Rewrite `orchestrate`'s description as a trigger spec that requires a **caller-supplied step list**: it wins only when the user names the phases/subtasks themselves; anything shaped like "build/fix/implement X" with no step list falls through to `dev`.

Cheapest high-value edit on this list — one description field.

---

## 2. Artifacts on disk, not relayed prose

**Current.** `explore` (a `context: fork` skill) returns a prose summary; `dev` holds it in context and re-relays it as args to `plan` — a lossy second-hand copy. Only the plan file itself lives on disk. `dev` already preaches "pass pointers, not payloads" (Context management section), but explore output has no pointer to pass.

**Proposed.** A run-dir contract: each forked worker writes its full output to a run dir (e.g. `.claude/runs/<id>/explore.md`) and returns the *path* plus a short abstract. `dev` passes paths between phases; `plan` reads explore's artifact first-hand. Single biggest correctness lever in a forked pipeline. Also fixes the tail end: `document-local` sits at the position with the least context — pointed at the run dir it reads exploration and plan, not just the diff.

---

## 3. Structured return envelope

**Current.** The review gates return "a structured verdict report," but there is no shared shape across workers — each fork's return format is described ad hoc in its own SKILL.md, and `dev` branches on prose it must re-parse.

**Proposed.** Every worker returns the same envelope: `status`, `artifacts[]` (paths into the run dir), `next`, `blockers[]`. The orchestrator branches on fields, not prose. Pairs naturally with item 2 — same files, one change.

---

## 4. Loop termination: who owns the exit decision

**Current.** `dev` step 7 ("Repeat until the user approves"), step 9 ("Repeat until the review is clean"), and the builders' code/debug/test loop are all written with the same shape: unbounded iteration, model-judged exit. The repo's one genuine machine oracle — the `dev`-scoped Stop hook running `workflow-diff-check.sh`, which diffs the worktree and blocks the stop until the project's checks pass — backstops only the build loop.

**Proposed.** The rule is not "caps good, loops bad" — it is **who owns the termination decision**:

- **Oracle-checked loops run loose.** Where a machine-checkable exit condition exists (tests green, checks pass, exit 0), the harness owns termination: the model just keeps working and the harness notices when the oracle flips. The build loop qualifies — the test suite is the oracle, and `workflow-diff-check.sh` already half-enforces it at the stop boundary. Keep it loose; a generous iteration/respawn backstop is enough.
- **Judgment loops get capped.** Where the exit condition is a model judgment ("plan looks good," "review is clean"), the model is grading its own homework with no floor. The review-plan and review-code loops qualify: each gets a `max_iterations` plus an explicit escalate-to-human branch.

Same architecture, opposite settings — the current config applies one setting (uncapped, self-judged) to both kinds.

---

## 5. Kickback re-entry point

**Current.** `review-code` may loop back "to ANY earlier phase" with corrections passed as args — so the reason-code half roughly exists — but nothing steers the kickback toward the cheapest sufficient re-entry. A full re-explore discards working code and re-pays exploration.

**Proposed.** Kickback carries a reason code and defaults to re-entering at **plan amendment** (re-invoke `plan` with corrections against the existing plan), escalating to re-explore only when the reason is a wrong map of the codebase, not a wrong plan.

---

## 6. Scope the orchestrator's writes — don't remove them

**Current.** `dev`'s frontmatter has no tool restriction — nothing stops it from quietly doing a disappointing worker's job itself, destroying the isolation the architecture exists for. But a blanket Edit/Write lockout conflicts with two legitimate needs: ticking the plan syllabus between waves (step 8) and persisting run state for resumability (item 2's run dir).

**Proposed.** Scoped writes, enforced by the harness rather than by omitting the tool: a **PreToolUse hook** checks the path on every Edit/Write while `dev` is active and denies anything outside the run dir — plus, until item 8's `mark-syllabus.sh` lands, the plan file. Once syllabus ticking is scripted, the allowlist shrinks to the run dir alone. Hooks enforce, skills judge — the same principle the repo already applies at the stop boundary with `workflow-diff-check.sh`.

---

## 7. Extract the shared dispatch policy

**Current.** `dev`, `map`, and `orchestrate` each restate the same dispatch reasoning inline: pass pointers not payloads, parallel where independent, waves by dependency, surface only blockers/summaries. Three copies drift independently. No countable fork criteria exist anywhere — forking is "when it feels heavy," a judgment the model is poor at because it can't observe its own context pressure.

**Proposed.**

```
shared/dispatch-policy.md    ← the actual criteria
orchestrate/SKILL.md         ← thin: reads policy, applies to caller's steps
dev/SKILL.md                 ← reads policy, applies to its fixed pipeline
map/SKILL.md                 ← reads policy, applies to its graph
```

One file, three consumers; change fork heuristics once. The policy uses **countable criteria**, and the primary one is **file-set disjointness**: fork (and parallelize) when the work partitions cleanly on disk into non-overlapping file sets; inline when it doesn't — parallel workers touching the same file produce a merge neither worker saw. The older "fork read-heavy, inline write-heavy" framing was a special case of this: exploration always partitions cleanly, which made a read/write rule look right. Secondary countables: number of independent subtasks, expected file-read volume. Never anything that reduces to "feels heavy."

The repo already encodes the disjointness rule in exactly one place — `plan-format` requires disjoint file scopes across parallel lanes, with shared touchpoints forced into serialized integration subphases. The policy file generalizes that from the build phase to all dispatch.

---

## 8. Scripts over prose — full catalog (DECIDED: adopt)

**Current.** The principle is adopted at the edges (`workflow-setup.sh`, `resolve-config.sh`, `workflow-diff-check.sh`, the `generic/hooks/` quality suite), but a full sweep of every SKILL.md and agent file (2026-07-22) found ~20 deterministic procedures still living as prose the model can flub or skip on a long run. Tool-based skills yielded nothing — they teach code the model writes with judgment; everything scriptable concentrates in the orchestrators (`dev`, `map`, `sync-status`, `diagnose`), the generic workflow skills, and `push-main`. `diagnose` copies several of `dev`'s prose procedures verbatim, so the shared scripts pay off multiply.

**Proposed.** Every finding below becomes a script that gets *run*, not described. Placement follows item 9's structure: multi-consumer scripts live in `orchestrators/hooks/` (installed to `~/.claude/hooks/` like the existing ones); single-skill scripts live in that skill's own `scripts/` sibling dir.

### Tier 1 — shared scripts, multiple consumers (highest leverage)

| Script | What it does | Prose sites it replaces |
|---|---|---|
| `mark-syllabus.sh <file> <id> <state>` | Flip `- [ ]` → `- [x]` / `- [dropped]` for a subphase/candidate ID | `dev` L71, `diagnose` L62, `document-local` L39, `document-confluence` L38 |
| `classify-docs-target.sh` | Classify `CLAUDE_DOCS_DIR` by shape (path vs Atlassian URL vs `confluence:` shorthand); emit `mode`/`space`/`parent` | `dev` L57, `map` L22, `sync-status` L28 |
| `verify-scope.sh <reported-files…>` | Compare a builder's reported files against `git diff --name-only`; report violations | `dev` L71, `diagnose` L62 |
| `shipped-diff.sh <base> <ref>` | Compute the reconciliation/diagnosis diff (`git diff base...ref`, commit-range and `git log --grep` variants) | `sync-status` L35, `diagnose` L43 |
| `pick-run-name.sh` | Slug derivation + branch-existence check to pick `sync-`/`resync-`, `diagnose-`/`rediagnose-`, `map-`/`remap-` prefixes; feeds `workflow-setup.sh` | `sync-status` L33, `diagnose` L41, `map` L23 |
| `parse-flags.sh` | Parse `--explore`/`--worktree`/`--ref` (+ aliases) from invocation text into normalized values, incl. stripping `feature/`/`bug/`/`hotfix/` prefixes | `dev` L31/L33/L36/L61, `diagnose` L32 |
| `scaffold-report.sh <type> <slug>` | Emit the fixed section skeleton for the story file, sync-report, or diagnosis report (content stays judgment; filename + sections are mechanical) | `dev` L63, `sync-status` L44, `diagnose` L50 |
| `safe-push.sh` | Push wrapper: refuses `--force` in any form and refuses main/base (main allowed only under `push-main`'s flag) | `push-pr` step 2, `push-main` step 3 |

### Tier 2 — single-file scripts

**`push-main`** (highest-value single file — its mechanical core is safety-critical and pure prose today):
- `sync-install.sh` — all of step 4: compute changed universal-domain files from `git diff`, map each to its fixed `~/.claude/` path, copy, `diff` to verify. A drift here silently desyncs the install.
- Precheck: assert on `main`, repo root, not a worktree; hard-exclude `.claude/settings.local.json` from staging.

**`dev`:**
- `list-resumable.sh` — enumerate worktrees in the workflows dir plus orphaned `<type>/*` branches whose worktree is gone (L61).
- Resume-point detection — count ticked vs unticked syllabus boxes to pick re-enter-build vs review-plan vs explore (L61).
- Base-branch guard for `--worktree none` — branch-equality check (L62).
- Borderline: lane/wave grouping (L69) — parsing declared `(lane X)`/`(after:)` annotations and topo-sorting into waves is mechanical; script only if builders get mis-grouped in practice.

**`review-plan`:**
- `validate-plan.sh` — the entire structural half of step 2 is schema validation: syllabus first, every phase has subphases, entries title-only, checkbox↔detail-block 1:1 both ways, contiguous numbering, every `(after:)` targets a real ID, dependency graph acyclic, declared lane file-scopes disjoint (set intersection). The reviewer fork then spends its whole budget on the judgment half — verifying claims against reality.

**`push-pr`:**
- Precheck: clean tree + branch matches `^(feature|bug|hotfix)/`.
- PR-template detection (`.github/pull_request_template.md` / `PULL_REQUEST_TEMPLATE/`).
- Teardown + verify: `git worktree remove` → `prune` → confirm absent from `git worktree list`.

**`document-local`:**
- `check-doc-symlinks.sh` — walk in-project doc paths, verify each is a symlink resolving into `/docs`, repair (`ln -s`) or flag real-files-where-symlinks-belong; covers both the maintenance step (L51) and the final verify (L59), and mechanically enforces the `doc-format` rule.
- Changelog commit wrapper (`git add` + `git commit`, never push).

**`document-confluence`** (partial): artifact classifier — binary / large-text (>~1 MB) → Drive-bound vs inline is a size+extension check; the "when unsure, err toward Drive" tail stays judgment.

### Tier 3 — noted, probably not worth scripting

- `init-workspace`: wrong-lockfile detection (`package-lock.json`/`yarn.lock` without `pnpm-lock.yaml`) is a file test, but the fork's real work is the install itself.
- `explore`: monorepo detection (`apps/`, `packages/`, workspace manifests) is half-mechanical but immediately feeds judgment.

### Already scripted — do not duplicate

`resolve-config.sh` (config chain + base-branch heuristic), `workflow-setup.sh` (worktree creation — it **already slugifies** `--name`, so `dev` L60's "derive a short slug" prose partially re-describes it), `workflow-diff-check.sh` (stop-gate diff + tests), and the `generic/hooks/` suite (`smart-lint`, `smart-test`, `worktree-reminder`, `record-changed`, `ntfy-notifier`, helpers).

### Build order

1. `sync-install.sh` — safety-critical, single consumer, zero design questions.
2. `mark-syllabus.sh` + `verify-scope.sh` — four and two call sites; together they unblock the Edit/Write lockout (item 6), since syllabus ticking is `dev`'s only legitimate write.
3. `validate-plan.sh` — big quality lever on the review gate.
4. `classify-docs-target.sh`, `parse-flags.sh`, `pick-run-name.sh` — three-consumer dedup; kills the drift between `dev`/`map`/`sync-status`/`diagnose`.
5. The rest opportunistically as their files get touched.

---

## 9. Progressive disclosure in skill bodies (DECIDED: adopt)

**Current.** Every skill is a single monolithic SKILL.md — `dev` is ~110 dense lines, all loaded whenever the skill triggers, though large chunks are conditional (Confluence-mode capture, `--worktree resume` mechanics, build-dispatch detail) and are dead weight on most runs. No sibling detail files anywhere in the repo.

**Proposed.** Exploit all three of Claude Code's skill-loading tiers instead of two:

1. **Name + description** — always in context, every session (~tens of tokens; why descriptions are trigger specs).
2. **SKILL.md body** — loaded in full on trigger. Becomes a thin router: trigger conditions, the invariant procedure skeleton, and "read `<file>` when `<condition>`" pointers.
3. **Sibling files** — loaded only when the body's pointer fires; the model Reads them on demand, so a branch never taken costs zero tokens.

Target shape, using `dev` as the model case:

```
orchestrators/skills/dev/
  SKILL.md              ← pipeline table, loop rules, gates, pointers
  worktree-modes.md     ← new/resume/none mechanics (read when parsing --worktree)
  confluence-mode.md    ← requirements capture + story file (read only in Confluence mode)
  build-dispatch.md     ← lane/wave grouping, builder prompts, per-wave checks (read at step 8)
  scripts/              ← item 8's single-skill scripts (the extreme disclosure tier: never
                           loaded, only run)
```

**What must stay in the body — the load-bearing rule.** A sibling file adds a second skippable step (the Read itself), and "anything load-bearing that lives only in prose is a step the model can skip." So invariants never move out: only `test` breaks the loop, never skip the human gate, builders never edit the plan, push-policy constraints. Only bulky, cleanly-conditional detail moves to siblings.

**Accepted repo-mechanics consequences** (decided — apply as part of the migration, not as open questions):

- `docs/conventions.md` changes from "one self-contained SKILL.md" to "SKILL.md + optional sibling detail files + optional `scripts/`," with the body-section order applying to the thin body.
- `source-push-sync` / `push-main` step 4 (and its `sync-install.sh` from item 8) copy the **whole skill directory**, not just `skills/<name>/SKILL.md`.
- Items 8 and 9 share this directory structure — migrate a skill to both at once when touching it.

**Migration order.** `dev` first (largest body, most conditional branches), then `diagnose`/`sync-status`/`map` (same shape), then generic skills only where a genuine conditional chunk exists — a skill whose body is already short and unconditional stays a single file; thinness is the goal, not sibling files for their own sake.

---

## 10. Self-improvement skill

**Current.** Doesn't exist. The equivalent is hand-maintained: memory files capturing corrections (e.g. "editing skills minimally," "ask before editing") are written manually per incident.

**Proposed.** A `generic/` skill (`domain: universal`) that formalizes the promotion pipeline between the two current manual paths — session memory files on one end, skill-payload commits (e.g. `d446227`, itself a captured correction) on the other. On a correction or repeated error it: (1) captures the correction verbatim plus the why; (2) classifies it — one-off vs recurring, project-scoped vs universal, and which layer it belongs to (memory file, `generic/` rule, edit to an existing skill body, or `tool-based/<tech>` rule); (3) dedupes against existing rules and memories so the same lesson isn't recorded twice in different words; (4) for anything repo-worthy, drafts the actual edit to this repo as a proposal — never applies it silently. Unusual output shape: for recurring lessons, the deliverable is a diff against the skill library itself.

---

## 11. Orchestrator backlog

**Current.** None of these exist as skills. Fan-out/parallel dispatch is covered (`orchestrate` + `dev`'s builder lanes). Since the original conversation, `/diagnose` landed and materially changes two entries below. On Ralph loops specifically: the repo has all the ingredients — externalized state (the plan syllabus as dispatch table and checklist), resumability (`--worktree resume`), a done-condition (all boxes ticked, checks green) — but never closes the loop automatically; resume is hand-cranked, and the builder's build loop is one continuous context, not fresh-context iteration.

**Proposed.** Candidates in ROI order, all `orchestrators/` citizens except where noted:

| Candidate | Shape | Note |
|---|---|---|
| Triage/router | Read an issue/stack trace/request, classify, dispatch | Thin; highest ROI per line. Stronger now that the targets exist with disjoint mandates — build → `/dev`, root-cause → `/diagnose`, reconcile → `/sync-status`, docs → `/map` — and one front door for ambiguous requests also mitigates item 1's description overlap. |
| Builder crash-resume (the Ralph mechanism) | `dev` respawns a fresh builder on a dead or context-exhausted lane; it reads the syllabus state and continues | Not a standalone skill — a feature of `dev`'s dispatch loop. Legitimate under item 4's rule: the exit is machine-checkable (all subphases ticked + Stop-hook checks green), so it runs loose with a bounded respawn backstop. State is already externalized; resume-point detection is an item 8 script. |
| Adversarial review board | Same diff to N forked reviewers with different mandates (correctness, error handling, simplification, security); merge + dedupe | Mostly existing machinery: forked `review-code` × N mandates + a merge step. |
| Refactor/migration sweep | One declared transform, N files, one worker per file, orchestrator aggregates failures | The wide-and-shallow shape `dev` doesn't cover — its lanes assume few, deep, interdependent workstreams; a sweep is many independent identical tasks where per-file failure isolation is the point. File-set disjointness (item 7) holds trivially. |
| Release | Changelog, version bump, tag, deploy, verify | Heavily mechanical — mostly item 8-style scripts with judgment only at changelog writing and go/no-go. |
| Reproduce/bisect front-end (was: incident loop) | Automated reproduction + `git bisect` feeding `/diagnose` | The original incident-loop entry is largely superseded: `/diagnose` already covers ranked root-cause analysis and the gated fix loop. Only the front half — reproducing and locating the culprit commit — remains unbuilt. |

Each wants its own proposal before building; this is a ranked backlog, not a plan.

---

## 12. Tech-skill gaps (your call)

- **`django-migration`** — the `tool-based/django` layer has real content; verify whether a migration-specific skill exists in it before writing one. Stateful, subtly wrong easily, high blast radius — the strongest candidate if absent.
- **`monorepo-nav`** — does *not* fit this repo's taxonomy: it's project-bound, not tech-bound or universal. If wanted, it belongs in the consuming monorepo's own `.claude/`, not here. Recorded only so it isn't re-proposed.

---

## 13. Self-hosted plugin packaging (your call)

**Current.** Distribution is manual: `push-main` commits to main, then universal content is copied into `~/.claude/` per `.claude/rules/source-push-sync.md`. Tech-bound content is pasted into consuming projects by hand.

**Proposed.** A `.claude-plugin/marketplace.json` in this repo turns it into a self-hosted Claude Code plugin (`/plugin marketplace add <repo>`): the skills/rules/hooks become one versioned plugin installed identically across machines and projects, replacing the copy-sync flow. Not an external marketplace — but it competes with an existing mechanism you maintain, so it's a deliberate migration decision, not an add-on.
