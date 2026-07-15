---
name: dev
description: Entry-point orchestrator for the dev workflow — drives the full explore→plan→review-plan→code/debug/test→review-code→document→push-pr pipeline and manages context. Invoke as /dev to run the whole workflow on a feature, fix, or project.
domain: universal
rules: [verify-dont-assume, model-policy, artifact-locations]
model: opus
model-fallback: [sonnet, gemini-pro]
hooks:
  Stop:
    - matcher: ""
      hooks:
        - type: command
          # global install path; point at the project's .claude/hooks/ copy instead for a project-specific install
          command: "~/.claude/hooks/workflow-diff-check.sh"
---

# dev

You are the orchestrator. Drive the full development workflow from start to finish, delegate the real work to agents, track which step you are on, and keep your own context clean by surfacing only blockers and completion summaries. You are also the context manager for the whole run.

## When to use

- The user asks to start, drive, or "run the workflow" on a feature, fix, or project.
- Any non-trivial change that benefits from explore → plan → review → build → review → document.
- You need a single coordinator to track progress across multiple phases and loop back when things go wrong.

If the user wants only one phase (just an explore, just a plan), invoke that sibling skill directly instead of the full orchestration.

## Invocation args

`/dev` accepts an optional `--explore <deep|shallow>` flag (alias `--exp`) to force the `explore` skill's mode for this run instead of letting it pick automatically. Parse it out of the user's invocation text before starting the pipeline. If present, pass that mode (DEEP or SHALLOW) straight to `explore` in step 1/4 below instead of AUTO. If absent, default to the existing AUTO behavior unchanged.

## The pipeline

Drive these phases in order. "Repeat" means you may loop back to ANY earlier step at the listed gates, then resume forward.

0. **Workflow setup** — read the docs target, capture requirements when it's Confluence, and create an isolated worktree for this run before anything else (see steps 1–3 in "How it works" below).
1. **`explore`** — understand the codebase and patterns. Request AUTO mode so the `explore` skill picks DEEP or SHALLOW itself, unless the caller passed `--explore deep|shallow` (see "Invocation args" above), in which case request that mode explicitly. Handle monorepos.
2. **`init-workspace`** — set up toolchain and dependencies inside the worktree so later phases can build and test.
3. **`plan`** — turn findings into a concrete project plan saved under `/project-plans/` (or `CLAUDE_PROJECT_PLANS_DIR` if set).
4. **`review-plan`** — verify the plan, ask when unsure. HUMAN review gate. May loop back to **`explore`** or **`plan`**. Repeat until the user approves; then switch to auto mode.
5. **`code` / `debug` / `test`** — build the plan as a tight loop (see loop rules below).
6. **`review-code`** — verify the implementation, same verify-don't-assume discipline. May loop back to ANY earlier phase. Repeat until clean.
7. **`document-local`** or **`document-confluence`** — dispatched by the docs target (see step 1): a local `CLAUDE_DOCS_DIR` (or unset) means `document-local` writes into the ROOT `/docs` (mirror project structure, optional changelog — git commit only, never push); a Confluence location means `document-confluence` publishes the story + technical page, changelog page, and Jira links there instead.
8. **`push-pr`** — publish the workflow branch, open a pull request against the base branch, and tear down the worktree; ONLY runs when everything else is COMPLETELY done.

## How it works

1. **Confirm scope and read the docs target.** Read the user's request. For a monorepo, decide WITH the user whether to cover the entire repo or one app and its dependencies. Set the target before exploring. Then resolve the docs target once via Bash: `~/.claude/hooks/resolve-config.sh CLAUDE_DOCS_DIR --default /docs` (global install path; use the project's `.claude/hooks/` copy if installed project-specific). Classify it by shape — a filesystem path (the default `/docs`) means **local mode** (`document-local` is the documentation phase); an Atlassian wiki URL (`https://<site>.atlassian.net/wiki/spaces/<SPACE>[/pages/...]`) or the shorthand `confluence:<SPACE>[/<Parent Page>]` means **Confluence mode** (`document-confluence` is the documentation phase, and Confluence is the docs source of truth — no local `/docs` is maintained). Parse the space and parent page from the value.
2. **Capture requirements (Confluence mode only).** Before any exploration, capture — in conversation with the user, since forks can't converse — the story that will anchor the published docs: the original ask VERBATIM (their words, no paraphrasing), the story/narrative (who needs this and why, the journey today vs. after), acceptance criteria (propose, then confirm each — never invent), constraints and stakeholders, and the governing Jira issue key(s) (search via the Atlassian MCP; if none exists, create one WITH the user — never invent keys or open tickets unilaterally). Also resolve the publish targets now: confirm the Confluence space and parent page parsed from `CLAUDE_DOCS_DIR`, and the Google Drive folder for large-artifact offload — ask rather than assume; a wrong space, key, or folder corrupts everything downstream. Hold this until the worktree exists, then write it as the story file (see next step). Skip this step entirely in local mode.
3. **Set up the workflow worktree.** Run `~/.claude/hooks/workflow-setup.sh --name <name>` via Bash (global install path; use the project's `.claude/hooks/` copy if installed project-specific), deriving `<name>` as a short slug of the task — unique per run, so parallel runs don't collide. The script puts worktrees in the resolved workflows dir (`CLAUDE_WORKFLOWS_DIR` chain, per `artifact-locations`; default `.workflows/`), ensures that dir is gitignored, and creates the worktree on branch `feature/<name>` off the base branch — resolved by the script itself via the `CLAUDE_BASE_BRANCH` chain (per `artifact-locations`; NEVER read from CLAUDE.md prose). Pass `--base <branch>` yourself only to override for this one run; pass `--type bug|hotfix` when the task is a fix rather than a feature. Then `cd` into the printed WORKTREE path: ALL subsequent phases run inside the worktree, and every path passed to forked skills (plan path, project path) must be inside it. In Confluence mode, now write the captured requirements as the **story file**: `<slug>-MM-DD-YY.story.md` in the plans dir inside the worktree — resolve the plans dir via `~/.claude/hooks/resolve-config.sh CLAUDE_PROJECT_PLANS_DIR --default /project-plans/` (per `artifact-locations`) — using the same slug as the worktree name — sections: Original Ask (verbatim), Story / Narrative, Acceptance Criteria, Constraints, Stakeholders, Jira issue key(s), resolved Confluence/Drive targets. It sits next to the future plan file and anchors both the plan and the published docs.
4. **Explore.** Invoke the **`explore`** skill directly via the Skill tool — it is a `context: fork` skill that runs in its own subagent and returns a summary. Pass the scope as args, and pass the mode as AUTO so it picks DEEP or SHALLOW itself — unless the caller passed `--explore deep|shallow` (see "Invocation args" above), in which case pass that mode explicitly instead. Ensure AT LEAST a shallow explore happens before any planning. Collect the returned patterns/summary; do not pull the full file contents into your own context.
5. **Init.** Invoke the **`init-workspace`** skill directly via the Skill tool — it is a `context: fork` skill that runs in its own subagent and returns a summary. Pass as args the worktree path and the explore stack summary; it installs dependencies and sets up language toolchains so plan verification, the build loop, and tests all work. Surface only its summary.
6. **Plan.** Invoke the **`plan`** skill directly via the Skill tool — it is a `context: fork` skill that runs in its own subagent on Opus per its own frontmatter (planning is high-leverage) and returns a summary. Pass as args the explore summary, the user's request, any review corrections so the plan respects MAJOR versions and project conventions, and (Confluence mode) the story file path so acceptance criteria become plan constraints. Confirm the plan was written to `/project-plans/`.
7. **Plan review (gate).** Invoke the **`review-plan`** skill directly via the Skill tool — it is a `context: fork` skill that runs in its own subagent. Pass the plan path as args. The fork returns a structured verdict report (verified facts, corrections, open questions, recommendation); it cannot talk to the user itself. This is the human gate: present that report and the plan to the user and collect approve/revise. If the user dislikes it, loop back yourself by re-invoking **`explore`** or **`plan`** with the corrections as args, and repeat. Only proceed once approved, then switch to auto mode.
8. **Build (code/debug/test loop).** Spawn ONE **`builder`** subagent via the Agent tool — it preloads the three loop skills so the handoff rules are in context before the first handoff (fall back to a general-purpose subagent if `builder` isn't installed). Its prompt: invoke the **`code`** skill with the plan path and follow the handoff rules through **`debug`**/**`test`** until the `test` skill exits the loop, then report a completion summary. The three loop skills run inline INSIDE that one subagent, sharing its context. Respect the loop rules exactly:
   - The **`code`** skill NEVER exits on its own — it always hands off to **`debug`** or **`test`**.
   - The **`debug`** skill MAY exit, but PREFERABLY hands to **`code`** or **`test`** when finished.
   - The **`test`** skill is the ONLY skill that can break the loop.
   Let the subagent run the loop; only surface blockers or the completion summary back to yourself.
9. **Code review.** Invoke the **`review-code`** skill directly via the Skill tool — it is a `context: fork` skill that runs in its own subagent. Pass the plan path and the build summary as args. Same verify-don't-assume rigor as the plan review. The fork returns a structured verdict report; present it to the user, collect approve/revise, and from here you may loop back to ANY previous phase (code/debug/test, plan, or explore) if something feels off — re-invoke the earlier skill yourself with the corrections as args. Repeat until the review is clean.
10. **Document (& log).** Dispatch by the docs target from step 1 — both are `context: fork` skills invoked directly via the Skill tool:
   - **Local mode** → invoke **`document-local`**. Pass as args the plan path, the build/review summary, and the changelog preference. It writes into ROOT `/docs`, mirroring project structure (monorepo → `docs/apps/[project]`, etc.), keeping `/docs` as the single source of truth. Optionally record the changelog as a git commit (`git add` + `git commit` ONLY, NEVER push), in `docs/changelog`, or both.
   - **Confluence mode** → invoke **`document-confluence`**. Pass as args the parsed Confluence target (space, parent page), the Jira issue key(s) and Drive folder from step 2, the plan path, the story file path, the build/review summary, and the changelog preference. It publishes the story + technical page and changelog page to Confluence (the docs source of truth in this mode) and links the Jira ticket(s) bidirectionally. If it returns a needs-input report (missing target, dead connection), resolve that with the user and re-invoke — don't let it guess.
   - Extensible: a future `<target>:` scheme in `CLAUDE_DOCS_DIR` dispatches to the skill named `document-<target>`.
11. **Finish (& tear down).** Invoke the **`push-pr`** skill directly via the Skill tool — it is a `context: fork` skill that runs in its own subagent. Pass as args the worktree path, the branch name, the base branch, a short work summary for the PR, and confirmation the workflow is completely done. It commits any straggler artifacts, pushes the workflow branch and opens a pull request against the base branch (`git push` and PR creation may be permission-blocked or declined — a blocked push or declined PR is a valid reported outcome, never worked around), and removes the worktree. The `dev` orchestrator is NOT done until `push-pr` reports. If the user wants an independent review of the opened PR, invoke the **`review-pr`** skill with the PR URL afterwards.

## Context management

- **Default yourself to Opus.** You are the coordinator; protect your context window.
- **Forked skills self-manage their model** via their own frontmatter (`explore`, `plan`, `review-plan`, `review-code`, `document-local`) — the `plan` fork runs on **Opus** (planning and deep architectural reasoning are high-leverage); the rest run on Sonnet. Invoke them directly via the Skill tool; NEVER wrap a forked skill in an Agent-tool spawn. The code/debug/test loop is the exception: it runs inline inside ONE **`builder`** subagent you spawn via the Agent tool (general-purpose if `builder` isn't installed).
- **Pass pointers, not payloads.** Forks receive inputs only via invocation args — hand them file paths and concise summaries (plan path, explore summary), never raw file dumps.
- **Track the current step explicitly** (a TODO list or running status). Always know which phase you are in and which gate is next.
- **Let agents do the work.** Do not perform exploration, coding, or doc-writing yourself when an agent can.
- **Surface only what matters:** blockers, decisions needing the user, and concise completion summaries. Keep raw file dumps and verbose tool output OUT of your context.

## Hand-off / next

- The `dev` orchestrator runs workflow setup (docs target, requirements capture when Confluence, worktree), then invokes, in order: **`explore`** → **`init-workspace`** → **`plan`** → **`review-plan`** → **`code`** (which loops with **`debug`** and **`test`**) → **`review-code`** → **`document-local`** or **`document-confluence`** (dispatched by `CLAUDE_DOCS_DIR`) → **`push-pr`**.
- Loop-back points: `review-plan` → `explore`/`plan`; `review-code` → any earlier phase. Resume forward after each loop.
- The run ends after **`push-pr`** has published the workflow branch and opened the PR (or reported them blocked/declined) and torn down the worktree, following a clean code review and completed docs. An optional **`review-pr`** pass on the opened PR follows only when the user asks for one.

## Notes

- Tech-stack agnostic: any technology mentioned is an example only. Never hard-code a stack.
- Never skip the plan-review human gate. Confidently-incorrect plans are worse than slow ones.
- Enforce the code/debug/test loop rules without exception — only the **`test`** skill breaks the loop.
- Keep `/docs` (root) as the single source of truth in local mode; in-project doc folders and READMEs are symlinks into it. In Confluence mode the configured Confluence location is the docs source of truth instead, and no local `/docs` is maintained.
- If a phase reports an unrecoverable blocker, stop and bring it to the user rather than improvising around it.
- A skill-scoped Stop hook runs `workflow-diff-check.sh` while the `dev` orchestrator is active: it git-diffs the worktree and runs the project's checks on the changed files, blocking the stop until they pass. Hook failures are BLOCKING — fix them immediately, then continue where you left off.
