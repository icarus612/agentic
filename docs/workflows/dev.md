# `dev` workflow

Canonical guide: [`skills/workflows/dev/AGENTS.md`](../../skills/workflows/dev/AGENTS.md).
This page is the meta-summary; edit the pipeline behavior in the payload file
above, not here.

The core build pipeline: 14 skills, 1 sub-agent definition, 2 hook scripts,
and 1 workflow-scoped rule (`external-storage-cap`, used by
`document-confluence`).

```
dev (/dev) ─orchestrates─▶  explore → init-workspace → plan → review-plan ─(repeat)─┐
                                              │ approved                             │
                                              ▼                                      │
                       code ⇄ debug ⇄ test ──▶ review-code ─(loop to ANY phase)
                                              │ clean                                │
                                              ▼                                      │
                    document-local | document-confluence (& log) ◀───────────────────┘
                                              │
                                              ▼
                                   push-pr  (⇢ optional review-pr)
```

`(repeat)` and the review loop mean any phase can jump back to an earlier one
when something is off, then resume forward.

## Skills

| Skill | Model | Context | Role |
|---|---|---|---|
| `dev` | opus → sonnet → gemini-pro | inline (orchestrator) | `/dev` — drives the whole pipeline; reads the docs target from `CLAUDE_DOCS_DIR` and captures story/requirements up front when it names Confluence; creates the workflow worktree (via `workflow-setup.sh`); tracks phase state; surfaces only blockers/summaries. Has a `Stop` hook wired to `workflow-diff-check.sh`. |
| `explore` | sonnet → gemini-pro | fork | Read-only codebase mapping. Shallow (docs/`AGENTS.md`/READMEs) or deep (full source); monorepo-aware. Outputs tech stack, patterns, conventions, dependency graph. |
| `init-workspace` | sonnet → gemini-pro | fork | Sets up toolchain/dependencies inside the worktree so plan verification, the build loop, and tests all work. (Named verbosely — `init` collides with Claude Code's built-in `/init`.) |
| `plan` | opus → sonnet → gemini-pro | fork | Turns explore's findings into an ordered plan saved to `/project-plans/`. Requires at least a shallow explore first; pins MAJOR versions; enforces conventions as hard constraints. |
| `review-plan` | sonnet → gemini-pro | fork | **Human gate** before any code. Verifies every claim, asks when unsure, returns a structured verdict (it cannot talk to the user itself). Loops back to `explore` or `plan`. |
| `code` | sonnet → gemini-pro | inline (shared loop context) | Implements the plan. **Never exits on its own** — always hands off to `debug` or `test`. |
| `debug` | sonnet → gemini-pro | inline (shared loop context) | Diagnoses and fixes issues. May exit, but prefers handing back to `code` or `test`. |
| `test` | sonnet → gemini-pro | inline (shared loop context) | Verifies the implementation against the plan. **The only skill that can break the loop** with a terminal success exit. |
| `review-code` | sonnet → gemini-pro | fork | **Human gate.** Same no-assumptions discipline as `review-plan`; may loop back to **any** earlier phase. (Named noun-last — `code-review` collides with Claude Code's built-in `/code-review`.) |
| `document-local` | sonnet → gemini-pro | fork | Documentation phase in **local mode**: writes technical docs into root `/docs` (mirroring project structure); optional changelog via `git add`+`git commit` (never push) and/or `docs/changelog`. This page and the rest of `agentic`'s own `/docs` tree were produced by this skill, in map-driven mode. |
| `document-confluence` | sonnet → gemini-pro | fork | Documentation phase in **Confluence mode** (see dispatch below): connect preflight (Atlassian + Drive MCP), publishes the story + technical page and the changelog page, links Jira bidirectionally, offloads large artifacts to Google Drive per `external-storage-cap`. Returns a needs-input report instead of guessing at spaces/keys/folders. |
| `push-pr` | sonnet → gemini-pro | fork | Terminal phase: commits stragglers, pushes the workflow branch and opens a PR against the base branch (always asks first, never force-pushes, never pushes main), tears down the worktree. |
| `review-pr` | sonnet → gemini-pro | fork | Reviews a GitHub PR (the one `push-pr` opened, or any PR the user points at): fetches the real diff, verifies against plan/conventions, returns a structured verdict; posts comments only on explicit instruction. |
| `map` | opus → sonnet → gemini-pro | inline (small orchestrator) | `/map` — side-orchestrator for **doc-only** runs: worktree on the fixed branch `feature/map-repo` (bootstrap) or `feature/remap-repo` (refresh) via `workflow-setup.sh --reuse` off a user-chosen base, forces `explore` to DEEP mode, runs `init-workspace`, invokes the document phase in map-driven mode (no plan, no diff — the map is ground truth; Confluence mode is technical-only), then `push-pr`. Not for documenting a change already built through the pipeline. |

The `code`/`debug`/`test` triad runs **inline inside one shared context** —
the `builder` sub-agent (`skills/workflows/dev/agents/builder.md`) preloads
all three skills so the handoff rules are in context before the first handoff.
It carries the same `Stop` hook as the `dev` skill.

### Naming convention

The two orchestrators are user-facing entry points and get the shortest names
(`/dev`, `/map`). Phase skills are invoked by name by the orchestrator, so
they keep generic single-word names where safe (`explore`, `plan`, `code`,
`debug`, `test`) — with **description guards** ("Part of the dev workflow,
invoked by the dev orchestrator…") so they never auto-fire on incidental
keyword matches — and verbose names where a single word would collide with a
Claude Code built-in (`init-workspace`, `review-code`) or be ambiguous
(`document-local`/`document-confluence`, `push-pr`, `review-pr`).

## Documentation dispatch (`CLAUDE_DOCS_DIR`)

Defined in `rules/artifact-locations.md`; the orchestrators read the var once
via Bash (`echo "${CLAUDE_DOCS_DIR:-/docs}"`) and dispatch by the value's
shape:

- **Filesystem path or unset** (default `/docs`) → **local mode**:
  `document-local`; the local docs root is the single source of truth
  (`doc-format` mirror/symlink rules apply).
- **Confluence location** — an Atlassian wiki URL
  (`https://<site>.atlassian.net/wiki/spaces/<SPACE>[/pages/...]`) or the
  shorthand `confluence:<SPACE>[/<Parent Page>]` → **Confluence mode**:
  `document-confluence`; Confluence is the docs source of truth and no local
  `/docs` is maintained. The `dev` orchestrator additionally captures
  requirements up front (verbatim ask, narrative, acceptance criteria, Jira
  keys, Drive folder — in conversation, since forks can't converse) and
  persists them as `<slug>-MM-DD-YY.story.md` next to the plan; the published
  page carries the story, not just the technical detail.
- **Extensible**: a future `<target>:` scheme dispatches to the skill named
  `document-<target>`.

Note: Claude Code selects skills by description or explicit name — never by
env var — so the dispatch is the orchestrator's job: it reads the var and
invokes the matching skill by name. Projects switching modes later need a
migration pass (moving `/docs` content into Confluence or vice versa); nothing
automates that today.

This absorbs the former `delivery` workflow: its connect preflight, Confluence
story/changelog publishing, Jira linking, and Drive offload live in
`document-confluence`; its requirements capture lives in the `dev`
orchestrator; its `external-storage-cap` rule moved to
`skills/workflows/dev/rules/`.

## Hooks

Both are POSIX-ish Bash (`set -uo pipefail`), no dependency beyond common
Unix tools, and apply to a **consuming** project, not to `agentic` itself:

- **`workflow-setup.sh`** — invoked by orchestrator skills (`dev` step 3,
  `map`), not a hook itself. Creates a git worktree in `.workflows/` (or
  `CLAUDE_WORKFLOWS_DIR`), ensures that dir is gitignored, and creates it on
  branch `<type>/<name>` (`type` ∈ `feature|bug|hotfix`, default `feature`)
  off the base branch (`--base`, else `main`, else `origin/HEAD`). With
  `--reuse`, an existing branch is picked up instead of erroring and the base
  is merged into it (conflicts abort the setup cleanly). Prints
  machine-readable `WORKTREE`/`BRANCH`/`BASE`/`REUSED` lines.
- **`workflow-diff-check.sh`** — wired via frontmatter `hooks:` on the `dev`
  skill (`Stop`) and the `builder` agent (`Stop`/`SubagentStop`). Diffs the
  workflow branch against its merge-base (committed + staged + unstaged +
  untracked), buckets changed files by extension, and conditionally runs
  `node_modules/.bin/vitest related`, `go test`, or `pytest`/`python -m
  pytest` if present in the consuming project. No `jq` dependency — JSON
  fields are grepped from the flat hook payload. Exits 0 (never blocks) when
  nothing changed or nothing is runnable; exits 2 with a report on stderr when
  changed-file tests fail, which blocks the stop until fixed. Both hook
  wirings point at a global install path (`~/.claude/hooks/...`) with an
  inline comment noting to swap it for a project-local `.claude/hooks/` copy.

## Loop-breaking invariant

This phrasing is repeated across the `dev` skill, the `builder` agent, and the
three loop skill files — treat it as load-bearing:

> The `code` skill never exits on its own. The `debug` skill may exit but
> prefers handing off. Only the `test` skill can break the loop with a
> terminal success.

## Notes

- The `dev` orchestrator defaults itself to Opus and protects its own context:
  forked skills self-manage their model via frontmatter; it passes pointers
  (file paths, summaries), never raw payload dumps, into and out of forks.
- Story/narrative documentation and Jira/Confluence ticket linking are part of
  **Confluence mode** (requirements capture in `dev`, publishing in
  `document-confluence`) — the standalone `delivery` workflow that used to
  bracket `dev` was folded in and deleted.
