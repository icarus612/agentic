# worktree-modes — `--worktree new|resume [<name>]|none`

How a `dae` run gets its working directory. One flag, three mutually exclusive modes; the default is `new`. In `new` and `resume` modes, `cd` into the parent worktree after setup: ALL subsequent stages run inside it, and every path passed to workers and forks lives there.

## `new` (default)

Run `~/.claude/hooks/workflow-setup.sh --type <branch-type> --name <name>` (or the project's `.claude/hooks/` copy), deriving `<name>` as a short slug of the task — unique per run so parallel runs don't collide; `<branch-type>` comes from the router's selection table. The script resolves the workflows dir (`CLAUDE_WORKFLOWS_DIR` chain, default `.workflows/`, gitignored) and the base branch (`CLAUDE_BASE_BRANCH` chain) itself — pass `--base` only on explicit user override; NEVER ask the base conversationally. This creates the run's **parent** worktree on `<branch-type>/<name>` (no suffix — this is the branch the PR publishes); builder lanes later cut children off it as `<branch-type>/<name>-l<n>` (`build-dispatch.md`).

## `resume [<name>]`

Re-enter an existing run and continue where it left off. Resolve the workflows dir via `resolve-config.sh CLAUDE_WORKFLOWS_DIR --default .workflows`; normalize `<name>` (strip any `<type>/` prefix and any `-l<n>` lane suffix). If `<workflows-dir>/<name>` exists on disk, `cd` into it; if only the branch survives, recreate with `workflow-setup.sh --type <branch-type> --name <name> --reuse`. With no `<name>`, list resumable candidates and ask — never guess: worktrees on disk in the workflows dir, plus `<type>/*` branches WITHOUT a `-l<n>` suffix whose worktree is gone (a surviving `<name>-artifacts` run dir is the tell that a branch was a dae run and not an ordinary feature branch). If nothing is resumable, say so and offer `new`. Then **resume the pipeline, not just the directory**: a plan with a partially-ticked syllabus → re-enter dispatch at the unfinished subphases (surviving child worktrees are crash-resume material — see `build-dispatch.md`); a plan not yet approved → the plan gate; no plan → the workflow's first middle stage. Setup's docs-target/requirements steps still run first — cheap and idempotent; an existing story file counts as captured requirements.

## `none`

No worktree: every stage runs in the repo on the current branch, and all paths live there. **Guard the base branch first**: resolve it (`resolve-config.sh CLAUDE_BASE_BRANCH --base-branch-default`) and if the current branch IS the base, STOP and ask — per `push-policy` the base branch is never pushed, so proceeding dead-ends at ship. Builder dispatch is limited to ONE lane at a time (no child worktrees, so no physical isolation for parallel builders); `push-pr` pushes the current branch and skips teardown.
