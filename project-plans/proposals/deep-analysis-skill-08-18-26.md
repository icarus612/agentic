# deep-analysis skill + dae `--type analyze` workflow

## Phase syllabus

- [ ] Phase 1: The portable `deep-analysis` skill
  - [ ] 1.1: `SKILL.md` — frontmatter, protocol, bucketing table, report structure   (lane 1)
  - [ ] 1.2: `analyst-brief.md` sibling — the blind analyst contract               (lane 1)
  - [ ] 1.3: `arbiter-brief.md` sibling — the fourth-agent contract                (lane 1)
- [ ] Phase 2: The dae `analyze` workflow
  - [ ] 2.1: `analyze.md` workflow file                                            (lane 2)
  - [ ] 2.2: `dae/SKILL.md` router edits — selection table + spec-of-record         (lane 2)
  - [ ] 2.3: Documenting-skill carve-outs for `<docs>/analysis/`                    (lane 2)
- [ ] Phase 3: Integration — index & catalogue reconciliation
  - [ ] 3.1: Payload guides (root + both layer `AGENTS.md`, `README.md`)  (lane 3, after: 1.1, 2.1, 2.2, 2.3)
  - [ ] 3.2: Meta-docs (`docs/architecture.md`, `docs/pipeline.md`)        (lane 3, after: 3.1)
- [ ] Phase 4: Verify
  - [ ] 4.1: Convention-conformance sweep + tests green                            (lane 3, after: 3.2)

---

## Goal & scope

Add a **consensus analysis** capability to the library: a portable skill that runs three
mutually blind analyses of one scope, buckets their claims by agreement, arbitrates the
split ones with a fresh fourth agent, and reports genuine disagreement up rather than
resolving it silently. Then wire it into `dae` as a first-class workflow, the way
`document` and `sync` are wired.

**In scope**

1. A new universal skill `deep-analysis` (`agent-agnostic/skills/deep-analysis/`), with two
   sibling brief files. It is **portable**: it takes a scope, a question, a report path, and
   a working dir, and writes one consensus report. It knows nothing about plans dirs, docs
   roots, worktrees, branches, or the `CLAUDE_*` config chain.
2. A new dae workflow `--type analyze` — a row in the router's selection table plus a sibling
   workflow file `orchestrators/skills/dae/analyze.md`. **This** file, and only this file, binds
   an analysis run to `artifact-locations` / `run-artifacts` / branching conventions, and it is
   also what resolves the **docs root** the consensus report publishes into.
3. Two one-line carve-outs in the documenting skills so the analyze run's published report
   survives a later docs pass (`document-local`) and has a defined Confluence-mode route
   (`document-confluence`). No other behaviour change to either.
4. Reconciliation of every index and catalogue surface that enumerates skills or workflows.

**Explicitly out of scope**

- Any change to the `explore` skill. `deep-analysis` is a sibling, not a wrapper or a
  replacement; `explore` keeps its single-pass mapping job unchanged.
- Any change to the `planner` agent or its `plan-*` modules. The analyze workflow has **no
  planner** (like `document`).
- Any change to the builder/coder/contract-tester packet model. An analyze run dispatches no
  builders and writes no product code.
- Configurable agent counts. Fixed at **3 analysts + 1 arbiter**, per the request.
- Multi-round arbitration (a second arbiter over a contested arbitration). One arbiter pass;
  anything it cannot settle is reported up.
- **Any branch-type change.** D1 is decided: an analyze run reuses the existing `docs/` branch
  type. No `workflow-setup.sh` / `allow-workflow-cleanup.sh` enum edit, no `artifact-locations`
  rule edit, no new test — the whole run's diff is markdown. The branch-type enum lines the plan
  gate flagged as incomplete (`orchestrators/AGENTS.md:79`, `docs/pipeline.md:112`) are therefore
  deliberately **left untouched**; see 3.1/3.2's no-touch criteria.
- Any new committed record kind under a plan dir, and any plan record at all: the consensus
  report is a **docs** artifact, not a plans-dir record (see C7). An analyze run is **plan-less**.
- A general docs reconciliation pass at Record (D4). Publishing the consensus report into
  `<docs>/analysis/` IS the analyze run's record output; folding its findings into the rest of
  `/docs` is a `--type document` run's job.

**Supersedes:** nothing.

---

## Stack & MAJOR versions

This repo is a **library of markdown and shell**, not a runnable project — verified: a
`find -maxdepth 2` for `package.json`, `go.mod`, `pyproject.toml`, `Makefile`, `flake.nix`,
and `*.lock` across the worktree returns **nothing**, and `docs/architecture.md:135` records
"No CI, build system, test suite, license, `CONTRIBUTING.md`, or `CHANGELOG`."

| Thing | Version / form | Verified from |
|---|---|---|
| Skill + rule payload | Markdown with YAML frontmatter | `docs/conventions.md:35-77` (the format spec) |
| Hook / helper scripts | Bash, `#!/usr/bin/env bash` + `set -uo pipefail` | `orchestrators/hooks/workflow-setup.sh:1`, `tests/plan-lifecycle.test.sh:22` |
| Host bash | GNU bash 5.1.16(1) | `bash --version` on this host |
| Tests | Standalone blind contract tests, run as `bash tests/<name>.test.sh`, no runner, no CI | `tests/` (3 files); `tests/plan-lifecycle.test.sh:4-20` |
| Install sync | Path-derived, no registry | `orchestrators/hooks/sync-install.sh:112` — `agent-agnostic/skills/*/*` → `skills/…` |

**Consequence for this plan:** adding `agent-agnostic/skills/deep-analysis/` requires **no**
edit to `sync-install.sh` and **no** entry in `agent-specific/claude/settings.json` — that
file grants the bare `"Skill"` permission plus `Read(~/.claude/skills/**)`
(`agent-specific/claude/settings.json:42-43`), which already covers a new skill and its
siblings. Every remaining registration surface is prose.

---

## Conventions to enforce

Hard constraints, each with its source.

**C1 — `domain:` is the only classifier, and no skill may name this repo's layout.**
`docs/conventions.md:30-33` and `docs/architecture.md:26-34`. `deep-analysis` is
`domain: universal`; nothing in its body may say "agent-agnostic/" or "orchestrators/".

**C2 — Skill file format and fixed section order.** `docs/conventions.md:35-58`: frontmatter
`name`, `description`, `domain`, `rules`, `model`, `model-fallback`; body
`# <name>` → intro → `## When to use` → `## Inputs` (fork skills only) → `## How it works` →
`## Hand-off / next` → `## Notes`. Optional `context: fork`, `agent:`, `hooks:`. Sibling
detail files and a `scripts/` dir are permitted alongside `SKILL.md`
(`docs/conventions.md:77`) — the `dae` router's workflow files are the precedent.

**C3 — Description guard.** A universal phase skill's `description` must name the pipeline it
belongs to and who invokes it, because the install namespace is flat and a generic name would
auto-fire on a stray keyword (`docs/conventions.md:64-70`; `agent-agnostic/AGENTS.md:33-36`).
`deep-analysis` is generic enough to need this guard explicitly.

**C4 — Model policy.** `agent-agnostic/rules/model-policy.md` and `docs/conventions.md:149-157`:
orchestration/planning → `opus → sonnet → gemini-pro`; everything else → `sonnet → gemini-pro`.
Every skill declares `model:` plus an ordered `model-fallback:` ending in `gemini-pro`. See
decision point D2.

**C5 — Worker return envelope, artifact-on-disk / pointer-in-envelope.**
`docs/conventions.md:101-121`: `status` / `artifacts[]` / `next` / `blockers[]`, followed by a
short body that is a digest, never the artifact's content. "A worker inventing its own report
shape instead of this envelope is a convention violation."

**C6 — Structural anti-cheating, never prompt discipline.** `orchestrators/AGENTS.md:31-33`:
"the artifact an agent would cheat off does not exist in any context it can see." This is the
load-bearing constraint of the whole feature — isolation between the three analysts must be
architectural (separate agents, separate output paths, one simultaneous dispatch, no relay),
not a sentence asking them not to peek.

**C7 — The consensus report is a DOCS artifact; an analyze run is plan-less.** (User decision at
the plan gate.) Two independent reasons this is the only coherent placement:
1. `orchestrators/hooks/plan-lifecycle.sh:241-248` refuses `archive` if a plan dir contains any
   entry outside `plan.md | story.md | plan-review.md | code-review.md | pr-review.md | sync-report.md`
   — so an `analysis.md` record kind is not available, and the only way to put the report in a
   plan dir would be to make it `plan.md`, which it is not: it is a finished document for humans
   to read, not a spec anything executes.
2. `run-artifacts` already defines the plan-less shape: "A run with no plan (a `document` run; a
   ticket-only `sync` run) still gets a dir under the plans dir for its records; having no
   `plan.md`, it archives nothing and the dir is removed at closeout"
   (`agent-agnostic/rules/run-artifacts.md:13`), and `cleanup-merged/SKILL.md:48-49` implements
   exactly that ("A run with no `plan.md` archives nothing; its record dir is simply removed").

Consequently: the report publishes to **`<docs-location>/analysis/`** (docs root resolved per
`artifact-locations`; local default `/docs/analysis/`); the records-only dir under the plans dir
holds only the run's `pr-review.md` (the plan-less path the router already specifies,
`dae/SKILL.md:58`) and is removed at closeout; nothing is archived; there is **no promotion**.
The three analyst ledgers and the arbitration file stay ephemeral in the gitignored run dir,
like an `explore` map (`run-artifacts`, run-dir section).

**C8 — `<docs>/analysis/` is a dated, append-style subdir, and a docs pass must not prune it.**
`doc-format` says docs mirror the source layout and are kept current, "one page per topic,"
deleting pages for code that was removed — and `document-local/SKILL.md:39,72` is the agent that
acts on that ("reconcile the existing `/docs` tree against it and add, update, or delete
accordingly"; "remove what no longer applies"). A consensus report is dated evidence of one run,
not a living topic page: it is never updated in place and never consolidated. This is a
deliberate, user-chosen exception, and it is recorded where the pruning agent will actually read
it (2.3), not only in `analyze.md`.

**C9 — Portability of the base skill (the user's binding constraint).** The `deep-analysis`
`rules:` list must **exclude** `artifact-locations`, `plan-format`, `run-artifacts`, and
`doc-format`. Its body must contain no `CLAUDE_*` variable, no reference to a plans dir, docs
root, worktree, run dir, branch, or PR. This is mechanically checkable and is an acceptance
criterion in 1.1. Contrast: `explore` *does* carry `artifact-locations`
(`agent-agnostic/skills/explore/SKILL.md:7,27`) — `deep-analysis` is deliberately looser-coupled.

**C10 — A skill earns a roster slot with ≥2 consumers or a user-facing surface**
(`orchestrators/AGENTS.md:18-21`, the "Absorb single-consumer skills" bullet; the phrase itself is
at line 21). `deep-analysis` has both (the dae analyze workflow, and
direct invocation), so it is a skill rather than being absorbed into a worker.

**C11 — Never a time estimate anywhere** (`plan-format`).

---

## Phase 1: The portable `deep-analysis` skill

**Home: `agent-agnostic/skills/deep-analysis/`.** Evidence for the placement, not assumption:
`orchestrators/` is "ENTRY POINTS and WORKERS" and its skills dir holds exactly `dae` and
`orchestrate` (`AGENTS.md:9-10`, `docs/architecture.md:46-48`); `agent-agnostic/skills/` is
"the tech-agnostic forks and gates … All are cold forks: isolated context, inputs via args,
one envelope back" (`agent-agnostic/AGENTS.md:31-40`), and the tier table at
`orchestrators/AGENTS.md:7-11` puts `explore` and every `review-*` in the cold-fork row.
`deep-analysis` returns one envelope pointing at one on-disk artifact — the fork shape
(`orchestrators/AGENTS.md:24-25`, "Fork when a summary is the deliverable").

### 1.1: `SKILL.md` — frontmatter, protocol, bucketing table, report structure

**File scope:** `agent-agnostic/skills/deep-analysis/SKILL.md` (new).

**Pattern to follow:** `agent-agnostic/skills/explore/SKILL.md` — the closest sibling. Mirror
its shape: frontmatter → intro → `## When to use` → `## Inputs` → `## How it works` (numbered)
→ an output-structure section (explore's "The map file: structure": header at line 73, bullets
through line 82, with `## Hand-off / next` starting at line 84) → `## Hand-off / next` (its
return-contract paragraph, line 86) → `## Notes`.

**Frontmatter** (per C2/C3/C4/C9):

```yaml
name: deep-analysis
description: >-
  Consensus analysis fork — three independent, mutually blind analyses of one scope, then
  claims bucketed by agreement: unanimous claims accepted, split claims arbitrated against the
  code by a fresh fourth agent, genuine disagreement reported up unresolved. Writes one
  consensus report to disk and returns an envelope pointing at it. Invoked by the dae analyze
  workflow, or directly with a scope, a question, and an output path; not for ordinary
  single-pass exploration — use explore for that.
domain: universal
context: fork
rules: [verify-dont-assume, tech-agnostic, respect-versions-and-conventions]
model: sonnet
model-fallback: [gemini-pro]
```

Note the deliberate omissions: **no `agent:` pin** (unlike `explore`, which pins
`agent: Explore` and therefore cannot spawn subagents — `deep-analysis` must spawn four, so it
takes the default agent, matching every other `agent-agnostic` fork), and **no
location-bearing rules** (C9).

**Body content — the load-bearing parts:**

*`## Inputs`* — four, all plain paths/strings, no config resolution:
- **scope** — what to analyze (a repo, a directory, a subsystem, a set of files).
- **question** — what the analysis must answer. Optional; when absent, default to a general
  structural analysis and say so in the report.
- **aspects** — the fixed list of claim slots (see below). Optional; the skill derives them
  from the scope+question when the caller doesn't supply them, and records the derived list.
- **report path** — where the consensus report goes (the deliverable).
- **working dir** — where the three ledgers and the arbitration file go.

Defaults when the caller gives neither path: create
`./deep-analysis-<scope-slug>-<MM-DD-YY>/` under the current working directory, with
`consensus.md` as the report and the ledgers beside it. State the chosen paths in the envelope.
The skill never gitignores, commits, or moves anything — disposition is the caller's job
(see decision point D3).

*The aspect list — why it exists.* Three free-form prose reports cannot be compared
mechanically. Before any analyst is spawned, the skill fixes an **aspect list**: 5-12 named
claim slots derived from the scope and question (e.g. "data flow", "error handling",
"external dependencies" — examples only, per `tech-agnostic`). All three analysts receive the
**same** list and must file every claim under one aspect. Comparison is then slot-by-slot
rather than fuzzy-matching across whole documents. The aspect list is recorded verbatim in the
consensus report so a reader can see what the analysts were asked to cover.

*The claim ledger line format* (specified here, restated in the analyst brief):

```
- [C<n>] <aspect> — <one falsifiable assertion> | evidence: <path>[:<lines>] | confidence: high|medium|low
```

One assertion per claim, never compound: a compound claim can be half-agreed, which breaks
bucketing. A claim with no evidence path is filed as `confidence: low` and flagged.

*`## How it works`* — numbered steps:

1. **Settle inputs.** Scope, question, aspect list, report path, working dir. State any
   defaulted value; a fork cannot ask mid-run.
2. **Dispatch three analysts in ONE batch.** Three fresh subagents, identical self-contained
   briefs (the `analyst-brief.md` sibling, filled in with scope/question/aspects), differing
   only in output path: `<working-dir>/analysis-1.md`, `-2`, `-3`. Identical prompts, not
   varied lenses — the protocol measures agreement, and deliberately different lenses would
   manufacture disagreement the buckets would then misread. **Isolation is architectural**
   (C6): each analyst is told only its own output path; no analyst is given a peer's path or
   content; the batch is simultaneous so no peer ledger exists when they start; the skill never
   relays one analyst's text to another. If an analyst fails, respawn a **fresh** one — never
   hand a replacement a peer's ledger.
3. **Bucket the claims.** Read the three ledgers. Within each aspect, match claims that make
   the same assertion (record each merge, so a reader can audit the matching). Apply the vote
   table below to every matched claim.
4. **Arbitrate.** If the arbitration list is non-empty, spawn **one** fresh fourth agent with
   the `arbiter-brief.md` sibling and the list. **Attribution is stripped**: each item is a
   neutral question, with no indication of how many analysts asserted it or which ones — the
   arbiter must not be able to count votes, or it will ratify the majority instead of checking
   the code. It writes `<working-dir>/arbitration.md`.
5. **Write the consensus report** to the report path, in the structure below.
6. **Return the envelope** (C5) pointing at the report.

*The vote table* — exhaustive over the three analysts' positions on a claim, each being
`assert` (A), `contradict` (an incompatible assertion, B/C), or `omit` (—):

| Pattern | Bucket | Rationale |
|---|---|---|
| A, A, A | **Confirmed** | Unanimous; accepted as fact |
| A, A, — | **Arbitrated** | Two assert, one omits |
| A, A, B | **Arbitrated** | Two assert, one disagrees |
| A, B, — | **Unresolved** | Not a majority; report up |
| A, B, C | **Unresolved** | Three-way disagreement; report up |
| A, —, — | **Unresolved** | One asserts, two omit; report up |

Arbiter verdicts route as: `confirmed` → the Confirmed section, marked *arbitrated* (never
silently merged with the unanimous ones); `refuted` → stays in the Arbitrated section, recorded
as refuted with the arbiter's evidence (a decided finding, not a deletion); `indeterminate` →
moves to Unresolved and is reported up.

*The consensus report structure* (its own section, mirroring explore's "The map file:
structure"):

- **Scope, question & aspects** — what was analyzed, what was asked, the aspect list used, and
  whether any input was defaulted.
- **Method** — three blind analysts + one arbiter; the isolation guarantees actually applied;
  any analyst that failed and was respawned.
- **Confirmed (unanimous)** — each claim with the evidence all three cited; arbiter-confirmed
  claims listed separately and labelled.
- **Arbitrated** — one row per item: the claim, the split (how many asserted / contradicted /
  omitted, with which analyst took which position), the arbiter's verdict, and its evidence.
- **Unresolved — reported up** — every claim that reached this bucket, **with attribution**
  (which analyst asserted what) and the reason it could not be settled. Never editorialised
  into a conclusion.
- **Coverage & limits** — what none of the analysts read; anything the aspect list did not cover.
- **Source ledgers** — the paths to `analysis-1/2/3.md` and `arbitration.md`.

*`## Hand-off / next`* — the shared envelope (C5): `status`; `artifacts[]` = the consensus
report path first, then the ledger paths; `next` = whatever the caller said it does with the
report (or "consume the consensus report" when unstated); `blockers[]`. Body: a digest —
counts per bucket, and a one-line headline of the unresolved items. **Never inline the report.**
`status: needs-input` when the scope is too vague for an aspect list to be derived.

**Acceptance criteria**
1. File exists at `agent-agnostic/skills/deep-analysis/SKILL.md` with the frontmatter above,
   fields in the C2 order.
2. Body carries exactly the C2 sections, in order, plus the report-structure section between
   `## How it works` and `## Hand-off / next` (explore's placement).
3. The vote table is present with all six rows and produces exactly the three buckets.
4. Isolation is described as a property of the dispatch (separate agents, separate paths, one
   batch, no relay, fresh respawn), not as an instruction to the analysts.
5. Arbiter input is stated to be attribution-stripped.
6. **C9 check, mechanical:** `grep -nE 'CLAUDE_[A-Z_]+|project-plans|\.workflows|plans dir|docs root|worktree|branch|pull request|\bPR\b' SKILL.md` returns nothing; and `grep -nE 'agent-agnostic|orchestrators/|tool-based' SKILL.md` returns nothing (C1).
7. `rules:` contains exactly `[verify-dont-assume, tech-agnostic, respect-versions-and-conventions]`.
8. Description names its invoker and disclaims the `explore` overlap (C3).

**Test approach — oracle: `equivalence check`.** No test harness covers prose. Verification is
a structural diff against `agent-agnostic/skills/explore/SKILL.md`: same frontmatter field set
(minus `agent:`, plus nothing), same section order, plus the grep assertions in criteria 6-7,
which are executable as written.

### 1.2: `analyst-brief.md` sibling — the blind analyst contract

**File scope:** `agent-agnostic/skills/deep-analysis/analyst-brief.md` (new).

**Pattern to follow:** `orchestrators/skills/dae/document.md` — a sibling detail file: plain
markdown, no frontmatter, opened by a title line naming what it is, loaded only when the parent
skill activates it (`docs/conventions.md:77`).

**Content.** The verbatim, self-contained brief handed to each of the three analysts, with
placeholders the skill fills: scope, question, aspect list, and **this analyst's own output
path**. It must state:
- The analyst is one of several independent passes and will not be told the others' findings —
  and that agreeing with an imagined consensus is worthless; only evidence counts.
- Ground every claim in a real path (and line range where it exists); prefer source over prose,
  per `verify-dont-assume`.
- File every claim under one of the given aspects; one assertion per claim, never compound.
- The exact ledger line format from 1.1, with a worked example.
- An explicit **omission is meaningful** instruction: file a claim only when there is evidence
  for it; do not pad the ledger to cover every aspect. (An omission is a distinct vote in the
  table — padding corrupts the protocol more than a short ledger does.)
- Report what it did NOT read, in a closing coverage section.
- Write to the given output path and return only a short envelope-shaped summary.

**Acceptance criteria**
1. Placeholders are unambiguous and cover scope, question, aspects, output path.
2. The ledger line format matches 1.1 character-for-character.
3. Contains the "omission is meaningful — do not pad" instruction.
4. Contains no reference to peers' paths, counts, or content.
5. Self-contained: readable and actionable by an agent with zero conversation context.

**Test approach — oracle: `equivalence check`.** Diff the ledger format block against 1.1's
(must be identical); grep for peer-referencing terms (`analysis-1`, `other analyst`,
`consensus`, `peer`) which must return nothing.

### 1.3: `arbiter-brief.md` sibling — the fourth-agent contract

**File scope:** `agent-agnostic/skills/deep-analysis/arbiter-brief.md` (new).

**Pattern to follow:** same as 1.2.

**Content.** The brief for the single fresh fourth agent:
- It receives a list of neutral questions about the codebase; it is **not** told how many
  analysts asserted each, or which — and it must not speculate. Its job is to check each
  against the code, not to referee a vote.
- Per item, a verdict of exactly `confirmed | refuted | indeterminate`, each with cited
  evidence. `indeterminate` is a legitimate, expected answer — the brief must say so, so the
  agent does not force a verdict to look decisive.
- Verdicts are independent: it must not let one item's answer sway another's.
- Write `arbitration.md` at the given path in a fixed per-item block, and return a short
  envelope-shaped summary with the verdict tally.

**Acceptance criteria**
1. Verdict vocabulary is exactly the three values, stated as a closed set.
2. States explicitly that `indeterminate` is acceptable and not a failure.
3. Contains no vote counts, attribution, or the word "majority".
4. Per-item output block is fully specified (item id, verdict, evidence, note).

**Test approach — oracle: `equivalence check`.** Grep for `majority|vote|two of|2/3|analyst 1`
which must return nothing; assert the three verdict values appear as a closed enumeration.

---

## Phase 2: The dae `analyze` workflow

The one place where this feature is allowed to know about plans dirs, run dirs, branches, and
PRs (C9's other half).

### 2.1: `analyze.md` workflow file

**File scope:** `orchestrators/skills/dae/analyze.md` (new).

**Pattern to follow:** `orchestrators/skills/dae/document.md` — the closest analogue: an
activity workflow with **no planner and no builders**, structured as a title line, a framing
paragraph, `## Stages` (numbered, each naming shared-vs-own), and `## Notes`. `document.md` is
also the precedent for the plan-less shape (no promotion step anywhere in its stages) and for
the `docs/` branch type this workflow now shares with it.

**Stages to specify:**

1. **Setup** (shared — router). Branch type **`docs/`** (D1, decided: reuse, no new branch type).
   The router's shared setup already resolves the docs target here
   (`resolve-config.sh CLAUDE_DOCS_DIR --default /docs`, `dae/SKILL.md:55`) — an analyze run
   **keeps that resolved value**, because it is the destination of its deliverable, not just its
   Record target. Additionally capture conversationally, before setup completes: the **scope**
   and the **question** — at least one required, never invented. For a monorepo, decide with the
   user whether to analyze the whole repo or one app + dependencies, exactly as `document.md:7`
   does. Confluence mode: technical-only, no story file and no Jira keys unless the user supplies
   them (the `document.md:7` precedent).
2. **Analyze.** Invoke the **`deep-analysis`** skill via the Skill tool with the scope, the
   question, the **working dir** = the run dir (so the three ledgers and the arbitration file are
   ephemeral and die with the worktree, exactly like an `explore` map per `run-artifacts`), and
   the **report path**:
   - **Local docs mode:** `<docs-root>/analysis/<slug>-MM-DD-YY.md` — the fork writes the
     deliverable straight into the docs tree. Deliberate: the orchestrator's own writes are
     harness-scoped to the plan file and run artifacts (`dae/SKILL.md:72`), so it may not copy a
     file into `/docs` itself; the fork that produces the report is what writes it. A re-run at
     the findings gate reuses the SAME path, so a gate round overwrites rather than accumulating,
     and an abandoned run simply never merges its branch.
   - **Confluence mode:** `<run-dir>/consensus.md` — nothing lands in a local docs tree; the
     report publishes as a Confluence page at Record (stage 4).

   Carry the report **path** forward, not its content. `init-workspace` may run in parallel (the
   findings gate may need to run commands to check a claim).
3. **Read-the-findings gate (human).** Present the bucket counts, the Arbitrated table, and
   **every Unresolved item** — the unresolved bucket is the point of the workflow and is never
   summarised away. The user's options: **accept** → proceed to Record; **re-run** with a
   narrowed or widened scope → note that `deep-analysis` is a **cold fork with no warm context**,
   so a correction is a fresh invocation, not a `SendMessage` (this is the structural difference
   from the planner-driven workflows and must be stated); or **hand off** anything actionable to
   a build or diagnose run. Capped at 3 rounds like every other gate, then escalate. There is
   **no promotion step** — an analyze run is plan-less (C7); `plan-lifecycle.sh` is never invoked.
4. **Record** (shared — router, analysis variant). **Local mode: already done** — the report is
   at its docs path from stage 2; the only Record work is to confirm it is there and that no
   OTHER doc page was touched. `document-local` is **not** invoked, and no general docs
   reconciliation runs (D4). **Confluence mode:** invoke `document-confluence` in its
   **map-driven** shape with the consensus report as the technical document (no story sections,
   no Jira key unless the user supplied one), targeting an `Analysis` parent page under the
   configured space/parent; 2.3 widens that shape's wording so this is a stated contract rather
   than a stretch of it.
5. **Ship** (shared — router). The PR gate's spec of record is the **consensus report at its
   docs path** (Confluence mode: the published page plus the run-dir report the gate reads).
   The branch diff must contain that report and nothing else — **no source change may appear in
   an analyze run's diff**, which is the gate's primary check. The gate's own report goes to the
   plan-less path `<plans-dir>/<run-slug>-MM-DD-YY/pr-review.md` (`dae/SKILL.md:58`). Then
   `push-pr` publishes the `docs/` parent branch.

**Notes to include:**
- This workflow never writes product code, and the only doc file it writes is its own consensus
  report. If the analysis surfaces work the user wants done, that is a hand-off to a build or
  diagnose run — the same posture as `sync.md:3` and `document.md:17`.
- The report is the deliverable even when everything lands in Unresolved. A run that resolves
  nothing but names the disagreements precisely has succeeded; never pad the Confirmed bucket
  to make a run look conclusive.
- **`<docs>/analysis/` is a dated, append-style subdir** — one file per analyze run, named for
  the run and its date, never updated in place and never consolidated. This is an intentional
  exception to `doc-format`'s "one page per topic, kept current"; a later docs pass must not
  prune or merge it (C8, enforced where it matters in 2.3).
- The run is **plan-less**: it creates no `plan.md`, promotes nothing, archives nothing. Its
  records-only dir under the plans dir holds `pr-review.md` and is removed at closeout
  (`run-artifacts:13`; `cleanup-merged/SKILL.md:48-49`). Do not invent an `analysis` record kind
  — `plan-lifecycle.sh archive`'s whitelist has no slot for one (C7).

**Acceptance criteria**
1. File exists, matching `document.md`'s structure (title line, framing paragraph,
   `## Stages` numbered, `## Notes`).
2. Every stage marked shared-vs-own, matching the router's vocabulary in `dae/SKILL.md:51-58`.
3. Branch type is stated as `docs/`; the file contains no `analyze/` branch reference.
4. Names the report path as `<docs-root>/analysis/<slug>-MM-DD-YY.md` (local) and the working dir
   as the run dir, and states the Confluence-mode variant.
5. States the cold-fork/no-SendMessage correction path explicitly.
6. States that unresolved items are presented in full at the gate.
7. States the no-source-change PR-gate check and names the plan-less `pr-review.md` path.
8. States that the run is plan-less: no promotion, no `plan.md`, nothing archived — and contains
   **no** `plan-lifecycle.sh` invocation.
9. States the append-style `<docs>/analysis/` convention in Notes.

**Test approach — oracle: `equivalence check`.** Section-by-section diff against `document.md`
and `sync.md`; assert each of criteria 3-7 by grep for its distinguishing phrase.

### 2.2: `dae/SKILL.md` router edits — selection table + spec-of-record

**File scope:** `orchestrators/skills/dae/SKILL.md` (edit only; no other file).

**Changes, each at a located line:**

1. **`description`** (line 3): the workflow enumeration reads "(build, diagnose, document,
   sync)" — add `analyze`. Also extend the trailing invocation-surface list ("…a docs pass, or
   reconciliation") with an analysis pass.
2. **Workflow selection table** (lines 38-48): add one row, in activity-block position after
   `document` and before `sync` — or alphabetically among the activities; match whatever the
   surrounding rows do:

   | `--type` | Kind | Workflow file | Planner module | Branch type |
   |---|---|---|---|---|
   | `analyze` (alias `deep-analysis`, `consensus`) | activity | `analyze.md` | — (no planner) | `docs/` |

   The `— (no planner)` cell and the `docs/` branch-type cell both match the `document` row
   (line 46) verbatim — D1, decided: reuse, no new branch type.
3. **PR-gate spec-of-record enumeration** (line 58): the parenthetical "or for a plan-less run
   the document its workflow file names (diagnose: the diagnosis report; sync: the plan +
   confirmed sync report; document: the explore map)" — add "analyze: the consensus report at
   its docs path". An analyze run is plan-less for its whole lifetime (C7), so this enumeration
   is the ONLY place the router learns what its spec of record is.
4. Leave the **Flags** table (lines 25-33) unchanged: `--explore` has no meaning for this
   workflow (`deep-analysis` has no deep/shallow modes), and no new flag is introduced.

**Acceptance criteria**
1. Exactly one new row in the selection table, with all five columns filled and **`docs/`** as
   the branch type.
2. `description` names `analyze` in the workflow list.
3. The PR-gate spec-of-record enumeration names the consensus report at its docs path.
4. **No other section of `dae/SKILL.md` is modified** — in particular the Invariants block
   (lines 66-77) is untouched: an analyze run needs no new invariant.
5. `git diff --stat` for this subphase shows exactly one file.
6. `grep -n 'analyze/' orchestrators/skills/dae/SKILL.md` returns nothing — no new branch type
   leaks in anywhere.

**Test approach — oracle: `equivalence check`.** Diff-bounded: the diff must touch only the
three located regions, verified by reading the diff hunk headers.

### 2.3: Documenting-skill carve-outs for `<docs>/analysis/`

**File scope:** `agent-agnostic/skills/document-local/SKILL.md`,
`tool-based/confluence/skills/document-confluence/SKILL.md` (edits only; two lines total).

**Why this subphase exists.** 2.1 puts the consensus report inside the docs tree. The agent that
later reconciles that tree is `document-local`, whose job explicitly includes deletion
(`document-local/SKILL.md:39` — "reconcile the existing `/docs` tree against it and add, update,
or delete accordingly"; `:72` — "remove what no longer applies"). A note in `analyze.md` is
invisible to it: `analyze.md` is a `dae` sibling, loaded by the router, never by the documenting
fork. The carve-out therefore has to live in the fork's own file (C8). Same shape on the
Confluence side: `document-confluence/SKILL.md:24` enumerates its input shapes and the
map-driven one is worded as "the explore skill's full structured map"; 2.1 routes an analysis
report through that shape, so the wording is widened by one clause to actually cover it.

**Located edits:**

| File:line | Current content | Change |
|---|---|---|
| `agent-agnostic/skills/document-local/SKILL.md` — `## Notes`, next to the `:72` "remove what no longer applies" bullet | the Notes bullet list | Add ONE bullet: `<docs>/analysis/` holds dated consensus-analysis reports, one per analyze run — append-style, never updated in place, never consolidated, and **never pruned** by a docs pass; it is a deliberate exception to `doc-format`'s "one page per topic, kept current" |
| `tool-based/confluence/skills/document-confluence/SKILL.md:24` | the map-driven `## Inputs` bullet — "**Map-driven** (from the `map` orchestrator): the explore skill's full structured map instead of plan/story/diff — publish the technical map only; skip the story sections." | Widen to also name a consensus analysis report from an analyze run as a valid technical document for this shape; publish it as a page under an `Analysis` parent. No other change to the skill |

**Pattern to follow:** both files' existing bullet density and voice — one sentence each, no new
section, no frontmatter change. `document-local`'s Notes bullets are the model for the first;
the sibling `## Inputs` bullets are the model for the second.

**Acceptance criteria**
1. `document-local/SKILL.md` gains exactly one Notes bullet naming `analysis/` and the words
   "never prune"; `git diff --numstat` shows a 1-line addition for that file.
2. `document-confluence/SKILL.md`'s map-driven Inputs bullet names the analysis report; no other
   line of that file changes.
3. Neither file's frontmatter changes — in particular `document-confluence` stays
   `domain: confluence` and is NOT moved into `agent-agnostic/` (tool-based content installs
   per-project, never into `~/.claude/`, per `.claude/rules/source-push-sync.md`).
4. Neither edit mentions `deep-analysis` internals, the run dir, or the arbitration protocol —
   they describe a docs location and an input shape, nothing else.

**Test approach — oracle: `equivalence check`.** Two `git diff --numstat` assertions (1 line each
file) plus a grep that `analysis/` and "never prune" appear in `document-local/SKILL.md` and that
`document-confluence/SKILL.md`'s frontmatter block is byte-identical to its pre-edit state.

---

## Phase 3: Integration — index & catalogue reconciliation

These files are this repo's equivalent of barrel exports and route registries: six documents
that each enumerate the skill roster and/or the workflow list. `plan-format` requires shared
touchpoints to be a **serialized integration subphase** rather than being touched from two
lanes, and coherent wording across all six matters more than parallelism — so this is one lane,
after Phases 1-2.

**What is deliberately NOT edited here.** Two of these files also carry the branch-type enum
`feature|bug|hotfix|docs|sync` — `orchestrators/AGENTS.md:79` (the `workflow-setup.sh --type`
line) and `docs/pipeline.md:112` (the Hooks reference block). D1 reuses `docs/`, so those lines
are already correct and must stay byte-identical. The plan gate's Round 1 flagged them as a
missing enum extension under the old "new `analyze/` branch type" design; that finding is moot
under D1 and is now an explicit no-touch criterion instead (3.1 criterion 6, 3.2 criterion 5).

### 3.1: Payload guides

**File scope:** `AGENTS.md` (root), `README.md`, `orchestrators/AGENTS.md`,
`agent-agnostic/AGENTS.md`.

**Located edits:**

| File:line | Current content | Change |
|---|---|---|
| `agent-agnostic/AGENTS.md:42-52` | the `skills/` role table | Add a `deep-analysis` row, in the table's existing style (one dense sentence naming the role and the invoker), placed next to `explore` |
| `AGENTS.md:17` (root — verified: this content is at root `AGENTS.md:17`, NOT in `agent-agnostic/AGENTS.md`) | `skills/  explore, init-workspace, review-*, document-local, push-pr` | Add `deep-analysis` |
| `AGENTS.md:10` | `skills/  dae (/dae — router + workflow siblings), orchestrate` | No change — the new sibling is covered by "workflow siblings" |
| `README.md:34` | `skills/ #  explore, init-workspace, review-*, document-local, push-pr` | Add `deep-analysis` |
| `README.md:48` | `build (feature\|bugfix\|rework\|migration\|hotfix), diagnose, document, sync` | Add `analyze` |
| `orchestrators/AGENTS.md:11` | the cold-fork tier row listing `explore, review-plan, …` | Add `deep-analysis` |
| `orchestrators/AGENTS.md:39` | the `dae` entry-point row's workflow enumeration | Add `analyze` |
| `orchestrators/AGENTS.md:73-74` | "The other workflows swap the middle: `diagnose` …, `document` …, `sync` …" | Add `analyze` (three blind analyses → consensus → findings gate) |

**Pattern to follow:** each table/list already has a house style — match the density and the
verb form of the neighbouring rows rather than inventing a longer entry.

**Acceptance criteria**
1. Every located edit above is made; no other line in these four files changes.
2. `grep -rn "deep-analysis" AGENTS.md README.md orchestrators/AGENTS.md agent-agnostic/AGENTS.md`
   returns at least one hit per file except root `AGENTS.md`, where the layout block hit suffices.
3. `grep -rn "analyze" README.md orchestrators/AGENTS.md` shows the workflow in both enumerations.
4. No new section is added to any of the four — rows only.
5. The `orchestrators/AGENTS.md` "Considered and rejected" list (lines 108-113) is **not**
   modified.
6. **No-touch (D1):** `orchestrators/AGENTS.md:79` still reads
   `--type feature|bug|hotfix|docs|sync` — verified by
   `git diff orchestrators/AGENTS.md | grep -c 'hotfix'` → `0`. The branch-type enum gains no
   `analyze`, here or anywhere.

**Test approach — oracle: `equivalence check`.** The grep assertions in criteria 2-3 and 6 are
executable; criteria 1/4/5 are verified from `git diff --stat` and the hunk headers.

### 3.2: Meta-docs

**File scope:** `docs/architecture.md`, `docs/pipeline.md`.

**Located edits:**

| File:line | Current content | Change |
|---|---|---|
| `docs/architecture.md:57` | `skills/  #   the 7 tech-agnostic forks/gates` | The count is already **stale** — `agent-agnostic/skills/` holds 9 today (`cleanup-merged`, `comment-pr`, `document-local`, `explore`, `init-workspace`, `push-pr`, `review-code`, `review-plan`, `review-pr`) and becomes 10. Correct it to 10 rather than incrementing a wrong number |
| `docs/architecture.md:109-117` | the `dae` dependency/hand-off bullet listing `build.md / diagnose.md / document.md / sync.md` | Add `analyze.md` |
| `docs/pipeline.md:32-37` | the Workflows (`--type`) table | Add an `analyze` row: workflow file `analyze.md`, middle stages "three blind `deep-analysis` passes → consensus report into `<docs>/analysis/` → findings gate; no planner" |
| `docs/pipeline.md:49` | the Cold forks tier row | Add `deep-analysis` |
| `docs/pipeline.md:121-126` | the `## Naming` paragraph on guarded generic names (the phrase "guarded generic names (`explore`)" is at line 125) | Optional: `deep-analysis` is hyphenated and self-guarding; add only if the sentence reads better for it |

**Acceptance criteria**
1. The `docs/architecture.md:57` count is **10**, i.e. the pre-existing off-by-two is fixed,
   not propagated.
2. Both located tables carry the new entries.
3. `docs/architecture.md:128-135` "Open items" is not modified.
4. Per `doc-format`, these edits are made in `/docs` in place; no new topic file is created —
   `deep-analysis` is a roster entry, not a new topic. (`<docs>/analysis/` is created by an
   actual analyze RUN, never by this plan.)
5. **No-touch (D1):** `docs/pipeline.md:112`'s `workflow-setup.sh` line still reads
   `feature|bug|hotfix|docs|sync` — verified by `git diff docs/pipeline.md | grep -c 'hotfix'`
   → `0`.

**Test approach — oracle: `equivalence check`.** Criterion 1 verified by counting
`agent-agnostic/skills/*/SKILL.md` and comparing to the number written; criteria 2-5 by diff
inspection plus the criterion-5 grep.

---

## Phase 4: Verify

### 4.1: Convention-conformance sweep + tests green

**File scope:** no file changes — a verification pass over everything Phases 1-3 produced. Any
defect found is fixed in the subphase that owns the file, not here.

**Checks:**
1. **C9 portability (the user's binding constraint), mechanical:**
   `grep -rnE 'CLAUDE_[A-Z_]+|project-plans|\.workflows|plans dir|docs root|worktree|branch|pull request' agent-agnostic/skills/deep-analysis/` → **no hits**.
2. **C1 layout leak:** `grep -rnE 'agent-agnostic|orchestrators/|tool-based' agent-agnostic/skills/deep-analysis/` → **no hits**.
3. **C2 format:** `deep-analysis/SKILL.md` frontmatter carries `name`, `description`, `domain`,
   `context`, `rules`, `model`, `model-fallback` in the house order; body section order matches
   `explore/SKILL.md`.
4. **C4 model policy:** `model-fallback` ends in `gemini-pro`.
5. **No branch-type change anywhere (D1):** `git diff --name-only` against the base contains
   **no** `.sh` file and no file under `agent-agnostic/rules/`; and
   `git diff | grep -n 'hotfix'` returns nothing (the enum is untouched in every file that
   carries it). `grep -rn 'analyze/' orchestrators/ agent-agnostic/ docs/ AGENTS.md README.md`
   shows no new branch type introduced anywhere in the payload (the plan file itself is excluded —
   it discusses `analyze/` only to forbid it).
6. **Docs-destination coherence:** `analyze.md`, `dae/SKILL.md`, and
   `document-local/SKILL.md` all name `analysis/` consistently — one grep,
   `grep -rn 'analysis/' orchestrators/skills/dae/ agent-agnostic/skills/document-local/`, and
   the three hits agree on the path shape `<docs>/analysis/<slug>-MM-DD-YY.md`.
7. **Tests:** `bash tests/plan-lifecycle.test.sh`, `bash tests/resolve-config-precedence.test.sh`,
   `bash tests/verify-scope-parsing.test.sh` — all exit 0. All three must be **unaffected**: this
   run adds no test and touches no script, so any regression means something out of scope changed.
8. **No product code and no script changed:** the run's whole diff is markdown, and every changed
   path is one named in a Phase 1-3 file scope.

**Acceptance criteria:** every check above passes, with the command output as evidence.

**Test approach — oracle: `existing suite`** (the three standing test scripts, as an unaffected-
regression check) **plus** the greps above.

---

## Risks, open questions, decision points

### Decision points — ALL DECIDED at the plan gate (Round 1), recorded here

**D1 — Branch type for an analyze run. DECIDED: reuse `docs/`; no new branch type.**
Consequences, all applied in this revision: the former Phase 3 (`analyze/` branch-type plumbing:
hook-script enums, the `artifact-locations` rule edit, the new contract test) is **deleted**, not
deferred; lanes drop from four to three and phases from five to four, renumbered with no gaps;
2.1 and 2.2 name `docs/`; and the branch-type enum sites the gate flagged (`orchestrators/AGENTS.md:79`,
`docs/pipeline.md:112`) are **no-touch** criteria in 3.1/3.2 rather than pending edits. Net effect:
the run's whole diff is markdown, no always-on rule changes, no script changes, no new test.
Accepted cost: `git branch` no longer distinguishes an analyze run from a document run — both sit
on `docs/<name>`; the run's identity lives in its name and its report instead.

**D2 — `model:` for `deep-analysis`. DECIDED: `sonnet`** (with `model-fallback: [gemini-pro]`),
matching every `agent-agnostic` fork and keeping the closed opus list (`dae`, `orchestrate`,
`planner`) closed. Already reflected in 1.1's frontmatter block. The three analysts and the
arbiter remain unpinned subagents inheriting the caller's default; no `model-policy` widening is
made or needed.

**D3 — Standalone default output location. DECIDED:**
`./deep-analysis-<scope-slug>-<MM-DD-YY>/` at the invocation cwd, with `consensus.md` as the
report and the ledgers beside it, the chosen paths stated in the envelope, and a Notes line that
the skill never gitignores, commits, or moves the output — disposition is the caller's. Already
reflected in 1.1's `## Inputs`. (This is the STANDALONE default only; inside a dae analyze run the
caller always passes an explicit path — 2.1 stage 2.)

**D4 — Does an analyze run's Record stage update docs? DECIDED: no general docs reconciliation —
and the consensus report itself IS the record output**, published into `<docs-location>/analysis/`
(docs root per `artifact-locations`; local default `/docs/analysis/`). This is the one decision
that reshapes more than a token: it moves the report out of the plans dir entirely, makes an
analyze run plan-less with no promotion (C7), and adds 2.3's two carve-outs so a later docs pass
neither prunes the report (`document-local`) nor lacks a route for it in Confluence mode
(`document-confluence`). `document-local` is NOT invoked at Record in local mode; there is nothing
left to do there because the report was written to its docs path by the `deep-analysis` fork
itself in stage 2.

**Confluence mode (planner's call, per the gate's instruction to pick and state one).** Chosen:
route the report through `document-confluence`'s existing **map-driven** shape — technical
document only, no story sections, no Jira key unless the user supplies one — published as a page
under an `Analysis` parent, with 2.3 widening that shape's one-line wording so the contract
actually names an analysis report instead of only "the explore skill's full structured map"
(`document-confluence/SKILL.md:24`). *Why not the alternative (declare Confluence unsupported and
leave the report in the run dir):* the run dir dies with the worktree (`run-artifacts`), so an
unsupported mode would silently destroy the deliverable — worse than a one-line contract widening.
**Stated limitation:** the published page carries no analysis-specific structure (it is a
technical page like a map page), and `document-confluence` is `domain: confluence` tool-based
content, so this widening installs per-project and is NOT synced to `~/.claude/`
(`.claude/rules/source-push-sync.md`) — a project without the confluence payload installed simply
never reaches that branch.

### Risks

- **R1 — Claim matching is the protocol's weak joint.** Bucketing depends on the parent
  correctly recognising that analyst 1's claim and analyst 3's claim assert the same thing. Too
  loose and real disagreements get buried in Confirmed; too strict and everything falls into
  Unresolved. *Mitigations in the plan:* the fixed aspect list narrows matching to within-slot
  comparison; the one-assertion-per-claim rule prevents half-agreement; and the report records
  each merge so a reader can audit the matching. Residual risk is real and should be watched on
  the first live run.
- **R2 — Three analysts may share a blind spot.** Unanimity is not truth: three agents reading
  the same misleading doc agree confidently and wrongly. The protocol upgrades 3/3 to "fact",
  which is exactly where this bites. *Mitigation:* the analyst brief requires source-over-prose
  grounding and per-claim evidence paths, so a unanimous claim is at least traceable and a
  reader can spot when all three cite the same one stale document.
- **R3 — Cost.** Four agents per run, three of them doing a full pass over the same scope. This
  is inherent to the request and is the reason the workflow is opt-in (`--type analyze`) rather
  than a default stage anywhere.
- **R4 — Cold-fork correction ergonomics.** Unlike the planner-driven workflows, a correction at
  the findings gate cannot be a `SendMessage` — `deep-analysis` is a cold fork with no warm
  context, so a re-run means four fresh agents. 2.1 states this so the router does not attempt
  a `SendMessage` and quietly no-op. Users should expect gate rounds here to be expensive and
  should narrow the scope rather than re-run the same one.
- **R5 — The install sync is a required follow-up, not part of the build.** Per
  `.claude/rules/source-push-sync.md`, universal content must be synced to `~/.claude/` via
  `sync-install.sh` immediately after the push. That is the `push-main` skill's job at ship
  time; no plan subphase should touch `~/.claude/` directly. Called out because this feature adds
  a new skill directory plus edits to `dae` and `document-local` — the sync is what makes them
  live. Note the asymmetry after D1/D4: `document-confluence` is tool-based (`domain: confluence`)
  and is deliberately **not** synced to `~/.claude/`, so its 2.3 edit lands only in projects that
  install the confluence payload.
- **R6 — `<docs>/analysis/` is an exception to `doc-format`, defended in only one place.** The
  "never prune, never consolidate" carve-out lives in `document-local/SKILL.md` (2.3), because
  that is the fork that actually deletes doc pages today. If a second local documenting skill is
  ever added, or if `doc-format` itself grows a pruning clause, the carve-out must move up into
  the rule — otherwise a future docs pass can delete a shipped analysis report. This is a stated
  assumption, not a verified guarantee: no test enforces it (this repo has no CI), so it rests on
  the carve-out sentence being read.
- **R7 — Sharing the `docs/` branch type costs branch-level distinguishability (accepted, D1).**
  `git branch` shows `docs/<name>` for both document and analyze runs, and any future tooling that
  keys behaviour off branch type alone cannot tell them apart. Nothing in the current payload does
  that (`allow-workflow-cleanup.sh:90` and `workflow-setup.sh:65` treat `docs/` as one bucket, which
  is exactly why no script change is needed) — but a future consumer that wants the distinction
  would have to read the run's name or its report, not its branch.

### Open questions (surfaced, not assumed)

- **Q1 — Should the aspect list be caller-supplied, derived, or both?** The plan specifies
  "optional input, derived when absent, recorded either way" as the safe default. If dae's
  analyze workflow should always derive it conversationally from the user instead, 2.1 stage 1
  needs a capture step.
- **Q2 — Is `analyze` the right `--type` name given the skill is `deep-analysis`?** The plan
  adds aliases `deep-analysis` and `consensus` so all three invocations work; confirm the
  primary should be the short `analyze`, matching `document`/`sync`. Still open.
- **Q3 — Should the branch-type contract test exist? MOOT, closed by D1.** There is no branch-type
  change, so there is no enum to test and no new test file. The three standing test scripts are
  now purely an unaffected-regression check (4.1 check 7).
- **Q4 (new, from D4) — Should the report file name carry the question as well as the slug?**
  2.1 specifies `<docs>/analysis/<slug>-MM-DD-YY.md`, matching the plans-dir naming shape the repo
  already uses everywhere. Two analyze runs on the same slug on the same day would collide (the
  second overwrites) — which is exactly the behaviour a gate re-run wants, and a plausible
  annoyance for two genuinely different questions about the same scope. Left as-is deliberately;
  say so if a question-derived suffix is wanted instead.

---

## Skill mapping

| Work | Executed by |
|---|---|
| All three lanes | `builder` (per lane, per `build-dispatch.md`), with `coder` sub-agents; every packet is markdown, so **no `contract-tester` is dispatched anywhere in this run** (D1 removed the only test) |
| Plan gate | `review-plan` (+ its `scripts/validate-plan.sh`) |
| Code gate | `review-code` |
| Record | `document-local` (this repo's `CLAUDE_DOCS_DIR` is unset → local `/docs`, per `docs/conventions.md:176-178`). NB: this is THIS build run's own Record stage; it is unrelated to the analyze workflow's Record stage that 2.1 defines |
| PR gate | `review-pr` — spec of record is this plan; the diff must be markdown only (no `.sh`, no `agent-agnostic/rules/` file, no new test) and nothing else |
| Ship | **`push-main`** (this repo only — squash-merge to `main` locally, no PR), then `sync-install.sh`, per `.claude/rules/source-push-sync.md`. **Not** `push-pr` |
| Closeout | `cleanup-merged` — archives `plan.md` to `completed/` via `plan-lifecycle.sh` |
