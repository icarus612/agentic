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

The 10 universal rules: `artifact-locations`, `cd-then-run`, `doc-format`,
`model-policy`, `plan-format`, `push-policy`,
`respect-versions-and-conventions`, `run-artifacts`, `tech-agnostic`,
`verify-dont-assume`. Tech-bound rules live with their layer
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

Defined by the `run-artifacts` rule. Two homes: **committed review records**
beside the plan (`<slug>-MM-DD-YY.{story,diagnosis,sync-report,plan-review,code-review,pr-review}.md`),
and the **gitignored run dir** `<workflows-dir>/<name>-artifacts/` holding
`progress-log.md` (the orchestrator's live run state, rewritten in place,
never committed), `contracts/<child-id>.md`, and `reports/<child-id>-exit.md`
(child ids are always `c1`, `c2`, … in dispatch order, naming each builder's
branch `<type>/<name>-c<n>`, worktree, contract, and exit report; the parent
branch is plain `<type>/<name>`).

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
single `model:` value and ignores `model-fallback:`.

## Artifact locations (for consuming projects)

Defined by `artifact-locations`, and load-bearing for how the documentation
phase behaves in any project that adopts this library:

| Artifact | Default | Config var |
|---|---|---|
| Docs | root `/docs` | `CLAUDE_DOCS_DIR` — a path keeps docs local (`document-local`); an Atlassian wiki URL or `confluence:SPACE[/Parent]` makes Confluence the docs source of truth (`document-confluence`) |
| Implementation plans | root `/project-plans/` | `CLAUDE_PROJECT_PLANS_DIR` |
| Workflow worktrees | root `.workflows/` (gitignored, branch `<type>/<name>`) | `CLAUDE_WORKFLOWS_DIR` |

Config vars are set in a project's own `.claude/settings.json` `env` block. This
repo has none, so this `/docs` tree uses the plain defaults.

## Plan format

Filename `<feature-slug>-MM-DD-YY.md`; phase syllabus first — title-only, one
nested checkbox per subphase under its phase header (every phase decomposes
into `<phase>.<subphase>` entries), with optional `(after: <ids>)` dependency
and `(lane <X>)` annotations that let the `dae` orchestrator dispatch parallel
builders; required sections — goal & scope, stack & MAJOR versions (with the
manifest each was verified from), conventions to enforce, subphase detail
blocks (each naming its file scope; independent lanes' scopes must be
disjoint), risks/open questions/decision points, skill mapping; a living
document (syllabus checked off per subphase); **never** time estimates.
In Confluence mode the `dae` orchestrator also writes a sibling story file
(`<feature-slug>-MM-DD-YY.story.md`) with the verbatim ask, narrative,
acceptance criteria, and Jira keys.

## Contribution convention

- Edit **in this repo first**, never in `~/.claude/` — that's an install, not
  the source.
- A skill is bound to nothing (`domain: universal` → `orchestrators/` or
  `generic/`) or to exactly one tech (`domain: <tech>` → `tool-based/<tech>/`).
  There is no third option.
- Every skill declares `description`, `domain`, `model` + `model-fallback`, and
  `rules:`.
- Keep rules short and frontmatter-light — they're always-on context.
- Never let a skill or rule name a directory in this repo.
- Distribution is deliberately copy-paste, not symlinks or a setup script, so it
  behaves identically across platforms. (Hooks are the one automated path: Nix
  home-manager installs them to `~/.claude/hooks/`.)
