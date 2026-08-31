# Conventions

The authoritative spec for the library's file formats, plus the
meta-conventions that apply to the repo itself. The root
[`AGENTS.md`](../AGENTS.md) carries the short index version that ships as
payload.

## `domain:` — the only classifier

Every skill and rule declares exactly one classifying field. Its value is what
the thing is bound to, and that decides where it installs:

- **`domain: universal`** — bound to nothing. Every orchestrator, every generic
  phase skill, every always-on rule. Installs at **user level** (`~/.claude/`
  or `.agent/`).
- **`domain: <tech>`** — bound to one technology or service (`svelte`,
  `tailwind`, `typescript`, `django`, `godot`, `medusa`, `confluence`, …).
  Installs at **project level**, with the project that uses that tech.
- **`domain: <project-name>`** — bound to one project (`mythic-made`, …). Its
  brand tokens, its own directory layout — content that can never be reused.
  **This repo never contains it**; it lives only in that project's `.agent/`.
  The value exists so project-local content is classified rather than
  unlabelled. If something carrying a project domain turns out to be a reusable
  pattern, promote it to a `<tech>` layer here and leave only the residue.

There is no `type:` field. It was removed because it could only ever restate
what the folder already said — and the folder does not survive the install,
which is flat (`skills/<name>/SKILL.md`). `domain:` is the one thing that does.

**Hard rule: no skill or rule may reference this repo's directory layout.**
They refer to each other by name and to bindings by `domain:`. Only the
`AGENTS.md` guides and this `/docs` tree describe the tree, because they never
leave the repo.

## Skill file format

One skill per directory: `skills/<name>/SKILL.md`, YAML frontmatter followed by
a body with a fixed section order.

```markdown
---
name: <kebab-name>
description: <when to use this — the agent matches the task against THIS line>
domain: <universal|svelte|django|…>      # what it's bound to; decides install target
rules: [<rule-name>, …]                  # the rules this skill depends on
model: <opus|sonnet|haiku>               # primary model the skill runs on
model-fallback: [<next>, …]              # ordered backups for tools that support them
---

# <name>
<intro paragraph>

## When to use
## Inputs            (fork skills only)
## How it works       (numbered steps)
## Hand-off / next
## Notes
```

A skill's body loads on demand — the model reads `description` to decide
whether to pull it in, so the description has to earn its tokens. Three
description conventions are load-bearing:

- **Orchestrators** say how to invoke them (`/dae`, `/orchestrate`) — the user-facing
  surface.
- **Universal phase skills** state the pipeline they belong to and who invokes
  them ("Part of the dae workflow, invoked by the dae orchestrator…"). Several
  are single words (`explore`); this guard is
  what keeps them from auto-firing on an incidental keyword match in the flat
  `~/.claude/skills/` namespace.
- **Tech skills** lead with the action (`write-svelte-component`,
  `run-godot-test`) — they *are* meant to match whenever their tech is in play,
  so they need no guard.

Optional frontmatter: `context: fork` (runs in an isolated subagent; inputs
arrive via invocation args only), `agent:` (a specific agent type for the fork),
`hooks:` (skill-scoped hook wiring, e.g. the `Stop` hook on `dae`). A skill may also carry sibling detail files and a `scripts/` dir next to its SKILL.md — siblings load only when the router activates them; scripts are run, never loaded.

## Rule file format

One rule per file: `rules/<name>.md`. Rules are always-on context, so they stay
short and frontmatter-light — no `model`, no selection step.

```markdown
---
name: <kebab-name>
description: <one-line summary>
domain: <universal|svelte|django|…>
---

# <Rule title>
<the rule, in a sentence or two>
```

The 10 universal rules: `artifact-locations`, `doc-format`, `model-policy`,
`plan-format`, `push-policy`, `respect-versions-and-conventions`,
`run-artifacts`, `shell-discipline`, `tech-agnostic`, `verify-dont-assume`. Tech-bound rules live with their layer
(`use-runes` → svelte, `typescript-strict` → typescript,
`external-storage-cap` → confluence, …).

## Worker return envelope

Every worker agent and fork skill that reports back to an orchestrator returns
the SAME envelope, defined once, here:

```
status:    success | blocked | needs-input | failed
artifacts: [<path>, …]        # what was written to disk — the real deliverable
next:      <recommended next step, or a kickback reason code at a gate>
blockers:  [<blocker>, …]     # empty when none
```

followed by a worker-specific body (a digest, never the artifact's content —
artifact-on-disk, pointer-in-envelope). Adopters: the `builder` exit report
(persisted to the run dir and validated by `validate-report.sh --kind exit`),
the `planner` return, the `explore` map summary, all three review-gate
verdicts (`review-plan`, `review-code`, `review-pr` — whose `next` carries the
kickback reason code `plan-wrong | map-wrong | impl-wrong | needs-input`), and
diagnosis investigation subagents (body fields: `root_cause`, `evidence`,
`likelihood`, `ease`, `proposed_fix`, `files`). A worker inventing its own
report shape instead of this envelope is a convention violation.

## Run artifacts & verdict reports

Defined by the `run-artifacts` rule. Three homes: **committed plan records**
inside the plan's own dir (`<plans-dir>/<slug>-MM-DD-YY/` — the spec of record
`plan.md` plus records named for their kind alone: `story.md`,
`plan-review.md`, `code-review.md`, `pr-review.md`, `sync-report.md`; there is
no `diagnosis` kind — a diagnose run's ranked report IS its `plan.md`), and
the **gitignored run dir** `<workflows-dir>/<name>/.artifacts/` — `.artifacts/`
at the root of the run's parent worktree, ignored via a committed `.artifacts/`
entry and removed with that worktree by post-merge cleanup — holding
`progress-log.md` (the orchestrator's live run state, rewritten in place,
never committed), `contracts/<lane-id>.md`, `reports/<lane-id>-exit.md`
(lane ids are always `l1`, `l2`, … — the plan's numbered lanes — naming each
builder's branch `<type>/<name>-l<n>`, worktree, contract, and exit report;
the parent branch is plain `<type>/<name>`), `committees/<skill>/` (the
`committee` agent's member files and consolidated artifact at `rigor:
med|high` — layout owned by the `run-artifacts` rule, not restated here), and
the `explore` fork's map (`explore-map-<scope-slug>-<MM-DD-YY>.md` — never the
plans dir); and the **scratch dir** `CLAUDE_SCRATCH_DIR`, where a `ship: chat`
report run's artifacts land in place of a run dir it has none of — layout and
resolution owned by `run-artifacts` and `artifact-locations`, not restated
here.

Review reports append one `## Round <n>` section per gate iteration. The
verdict vocabulary is enforced by scripts, not prose: `report-verdict.sh` is
the only writer of a round header (`verdict: ready | tentative | rejected`;
`next: proceed | impl-wrong | plan-wrong | map-wrong | needs-input`) and
`validate-report.sh` is the caller-side check (enums, cross-field rules,
finding-count consistency). A report that fails validation is not a report.
Kickbacks pass the report PATH — the findings file is the hand-off, never a
paraphrase of it.

## Model policy

Every skill declares `model:` plus an ordered `model-fallback:` ending in
`gemini-pro` (the cross-vendor backstop):

- **Orchestration/planning** (`dae`, `orchestrate`, the `planner` agent) → `opus →
  sonnet → gemini-pro`.
- **Everything else** → `sonnet → gemini-pro`.

Declarative intent — each tool honors what it can. Claude Code reads only the
single `model:` value and ignores `model-fallback:`. When executing on Antigravity, the cross-platform model mapping is:

- `opus` → `pro`
- `sonnet` → `inherit`
- `haiku` → `flash_lite`

## Artifact locations (for consuming projects)

Defined by `artifact-locations`, and load-bearing for how the documentation
phase behaves in any project that adopts this library:

| Artifact | Default | Config var |
|---|---|---|
| Docs | root `/docs` | `CLAUDE_DOCS_DIR` — always a local path; `document-local` records here, always |
| Docs publish target (optional) | unset | `CLAUDE_DOCS_PUBLISH` — an Atlassian wiki URL or `confluence:SPACE[/Parent]`; publishing is a CI job on merge, never a run stage |
| Implementation plans + their committed records | root `/project-plans/` — `proposals/` → `<slug>-MM-DD-YY/` → `completed/`, per `plan-format` | `CLAUDE_PROJECT_PLANS_DIR` |
| Workflow worktrees | root `.workflows/` (gitignored, branch `<type>/<name>`) | `CLAUDE_WORKFLOWS_DIR` |
| Scratch dir (a `ship: chat` report run's artifacts — no worktree, no run dir) | see `run-artifacts` / `artifact-locations` | `CLAUDE_SCRATCH_DIR` |

Config vars are set in a project's own `.claude/settings.json` `env` block. This
repo has none, so this `/docs` tree uses the plain defaults.

## Plan format

A plan is identified by `<feature-slug>-MM-DD-YY` and moves through a
lifecycle: an unapproved proposal is `proposals/<slug>-MM-DD-YY.md`, its
pre-approval records (`<slug>-MM-DD-YY.plan-review.md`, a
`confluence-mode.md` run's `<slug>-MM-DD-YY.story.md`) sitting beside it as
dotted siblings; at approval it is promoted to its own dir
`<slug>-MM-DD-YY/` as **`plan.md`**, the siblings moving in under bare kind
names; at post-merge closeout ONLY `plan.md` archives to
`completed/<slug>-MM-DD-YY.md` — the rest of the dir is removed, git history
keeps the records. A superseded or abandoned plan never
enters `completed/`: it is deleted, and the successor plan's Goal & scope
names what it supersedes and why. Every move goes through `plan-lifecycle.sh`
(`promote | archive | supersede | reopen | locate | check | adopt`), never by
hand — `archive` refuses a plan whose syllabus says it didn't ship.

Structure: phase syllabus first — title-only, one nested checkbox per
subphase under its phase header (every phase decomposes into
`<phase>.<subphase>` entries), with optional `(after: <ids>)` dependency
and numbered `(lane <n>)` annotations that let the `dae` orchestrator dispatch parallel
builders; required sections — goal & scope, stack & MAJOR versions (with the
manifest each was verified from), conventions to enforce, subphase detail
blocks (each naming its file scope; independent lanes' scopes must be
disjoint), risks/open questions/decision points, skill mapping; a living
document (syllabus checked off per subphase — `archive` reads those ticks);
**never** time estimates. When `CLAUDE_DOCS_PUBLISH` is set, the `dae`
orchestrator also captures the story as `proposals/<slug>-MM-DD-YY.story.md`
(verbatim ask, narrative, acceptance criteria, Jira keys), which becomes the
plan dir's `story.md` at promotion.

## Antigravity Adoption

Consuming projects adopting Antigravity should create an `.agents/GEMINI.md` file that references their existing `.claude/` tech layers. Do not attempt to sync or duplicate files between `.claude/` and `.agents/`; instead, reference the existing source of truth.

## Contribution convention

- Edit **in this repo first**, never in `~/.claude/` — that's an install, not
  the source.
- A skill is bound to nothing (`domain: universal` → `agent-agnostic/`) or to exactly
  one tech (`domain: <tech>` → `tool-based/<tech>/`). There is no third option.
- Every skill declares `description`, `domain`, `model` + `model-fallback`, and
  `rules:`.
- Keep rules short and frontmatter-light — they're always-on context.
- Never let a skill or rule name a directory in this repo.
- A new `--type` row is judged against the four standing review rules in
  [`agent-agnostic/AGENTS.md`](../agent-agnostic/AGENTS.md#review-rules-for-future-types)
  — loops attach to axis values, never to type names; the seam rule; the
  carried invariants; `pipeline` is not an array. Not repeated here.
- Distribution is deliberately copy-paste, not symlinks or a setup script, so it
  behaves identically across platforms. (Hooks are the one automated path: Nix
  home-manager installs them to `~/.claude/hooks/`.)
