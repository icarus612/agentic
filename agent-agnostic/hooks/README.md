# Claude Code Hooks

Automated code quality checks that run after Claude Code modifies files, enforcing project standards with zero tolerance for errors.

## Hooks

### `smart-lint.sh`
Intelligent project-aware linting that automatically detects language and runs appropriate checks:
- **Go**: `gofmt`, `golangci-lint` (enforces forbidden patterns like `time.Sleep`, `panic()`, `interface{}`)
- **Python**: `black`, `ruff` or `flake8`
- **JavaScript/TypeScript**: `eslint`, `prettier`
- **Rust**: `cargo fmt`, `cargo clippy`
- **Nix**: `nixpkgs-fmt`/`alejandra`, `statix`

Features:
- Detects project type automatically
- Respects project-specific Makefiles (`make lint`)
- Smart file filtering (only checks modified files)
- Fast mode available (`--fast` to skip slow checks)
- Exit code 2 means issues found - ALL must be fixed

#### Failure

```
> Edit operation feedback:
  - [~/.claude/hooks/smart-lint.sh]:
  🔍 Style Check - Validating code formatting...
  ────────────────────────────────────────────
  [INFO] Project type: go
  [INFO] Running Go formatting and linting...
  [INFO] Using Makefile targets

  ═══ Summary ═══
  ❌ Go linting failed (make lint)

  Found 1 issue(s) that MUST be fixed!
  ════════════════════════════════════════════
  ❌ ALL ISSUES ARE BLOCKING ❌
  ════════════════════════════════════════════
  Fix EVERYTHING above until all checks are ✅ GREEN

  🛑 FAILED - Fix all issues above! 🛑
  📋 NEXT STEPS:
    1. Fix the issues listed above
    2. Verify the fix by running the lint command again
    3. Continue with your original task
```
```

#### Success

```
> Task operation feedback:
  - [~/.claude/hooks/smart-lint.sh]:
  🔍 Style Check - Validating code formatting...
  ────────────────────────────────────────────
  [INFO] Project type: go
  [INFO] Running Go formatting and linting...
  [INFO] Using Makefile targets

  👉 Style clean. Continue with your task.
```
```

By `exit 2` on success and telling it to continue, we prevent Claude from stopping after it has corrected
the style issues.

### `ntfy-notifier.sh`
Push notifications via ntfy service for Claude Code events:
- Sends alerts when Claude finishes tasks
- Includes terminal context (tmux/Terminal window name) for identification
- Requires `~/.config/.claude-ntfy/config.yaml` with topic configuration

### `worktree-reminder.sh`
`SessionStart` hook (fires once per fresh session, not on `--resume`/`/clear`/compaction) that makes the worktree-isolation and push/PR conventions apply to EVERY session, not just ones driven by the `dae` orchestrator:
- If the session starts on the repo's main working tree (not an isolated `git worktree`), injects a reminder to run `workflow-setup.sh` before any file changes.
- Always reminds that `git push`/PR review should go through the `push-pr`/`review-pr` skills, not raw `git`/`gh` commands.
- Non-blocking (`SessionStart` hooks can't block session start anyway) — it only injects `additionalContext`, which Claude reads and must voluntarily act on. No jq dependency.

Wire it via `settings.json` (unlike the other hooks above, this is a `SessionStart` hook, not a post-edit one):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/worktree-reminder.sh" }
        ]
      }
    ]
  }
}
```

### `workflow-dev-server.sh`
Stack-neutral per-worktree dev server for a build run. It starts the project's own dev server when a build worktree is created, and stops it when the worktree goes away. Wire it on two events, both on `Bash`, unscoped:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [
        { "type": "command", "command": "~/.claude/hooks/workflow-dev-server.sh --hook-pre-remove", "timeout": 30 }
      ] }
    ],
    "PostToolUse": [
      { "matcher": "Bash", "hooks": [
        { "type": "command", "command": "~/.claude/hooks/workflow-dev-server.sh", "timeout": 90 }
      ] }
    ]
  }
}
```

- **`PostToolUse`** (default mode): sweeps orphans, starts any queued server whose ready paths now exist, then, when the Bash call was a `workflow-setup.sh` run (no `--parent`) that created a `feature|bug|hotfix/…` worktree, starts that worktree's server and injects its URL, port, pid and log path as `additionalContext`.
- **`PreToolUse`** (`--hook-pre-remove`): parses a `git worktree remove` (including `git -C <dir>`, `-c`, `cd … &&`, relative paths, `--force`) and stops that worktree's server before the removal runs.

**Inert when unset.** With `CLAUDE_DEV_SERVER_CMD` unset the hook starts nothing, writes nothing and prints nothing. Stop paths need no config: they act only on pids the hook itself recorded.

Config keys, resolved through `resolve-config.sh` from the worktree's main checkout (project `settings.local.json`, project `settings.json`, then global). Values in the Example column are illustrations, not defaults:

| Key | Default | Meaning | Example |
|---|---|---|---|
| `CLAUDE_DEV_SERVER_CMD` | unset (hook inert) | Shell command run in the worktree root; `{port}` is substituted and `PORT=<port>` is exported | `serve --port {port}` |
| `CLAUDE_DEV_SERVER_READY_PATHS` | unset (start immediately) | Space-separated worktree-relative paths that must all exist before the start; otherwise the start is queued | `vendor/ build/.ready` |
| `CLAUDE_DEV_SERVER_URL` | `http://localhost:{port}` | URL reported and opened | `http://localhost:{port}/app` |
| `CLAUDE_DEV_SERVER_PORT_BASE` / `_PORT_SPAN` | `5180` / `300` | Deterministic per-worktree port from a hash of the name, then a probe of 40 ports upward | |
| `CLAUDE_DEV_SERVER_READY_TIMEOUT` | `45`, clamped to `80` | Seconds to wait for the port to bind | |
| `CLAUDE_DEV_SERVER_BROWSER` | unset: `google-chrome`, `google-chrome-stable`, `chromium` (only with `DISPLAY` or `WAYLAND_DISPLAY`) | Opener command; `none` disables opening. One tab per worktree | `firefox` |

**State.** Per worktree, in the run dir: `<wt>/.artifacts/dev-server.{pid,url,log,opened}`. The pid file holds the pid on line 1 and its start time (`ps -o lstart=`) on line 2. Across worktrees, a registry at `${XDG_STATE_HOME:-$HOME/.local/state}/dae/dev-servers/` holds `.server` entries (running servers) and `.pending` entries (queued starts). It outlives the worktree, which is what lets the sweep stop a server whose worktree was removed by a command no hook could parse.

**Pid-reuse guard.** A recorded pid is killed only if its recorded start time still matches `ps -o lstart=`, or, for a bare one-line pid file with no start time, its cwd is the worktree or inside it. A failed guard kills nothing; the stale record is removed and the message says the pid could not be verified. The kill is process-group `TERM`, up to 10s of grace, then `KILL`.

**CLI modes:** `--start <wt> [--no-open|--reopen]`, `--stop <wt>`, `--status <wt>`, `--stop-all`, `--sweep`. `--start` without `CLAUDE_DEV_SERVER_CMD` exits 1. Every hook mode exits 0.

Rationale and known limits: [`docs/workflow-dev-server.md`](../../docs/workflow-dev-server.md).

## Installation

Automatically installed by Nix home-manager to `~/.claude/hooks/`

## Configuration

### Global Settings
Set environment variables or create project-specific `.claude-hooks-config.sh`:

```bash
CLAUDE_HOOKS_ENABLED=false      # Disable all hooks
CLAUDE_HOOKS_DEBUG=1            # Enable debug output
```

### Per-Project Settings
Create `.claude-hooks-config.sh` in your project root:

```bash
# Language-specific options
CLAUDE_HOOKS_GO_ENABLED=false
CLAUDE_HOOKS_GO_COMPLEXITY_THRESHOLD=30
CLAUDE_HOOKS_PYTHON_ENABLED=false

# See example-claude-hooks-config.sh for all options
```

### Excluding Files
Create `.claude-hooks-ignore` in your project root using gitignore syntax:

```
vendor/**
node_modules/**
*.pb.go
*_generated.go
```

Add `// claude-hooks-disable` to the top of any file to skip hooks.

## Usage

```bash
./smart-lint.sh           # Auto-runs after Claude edits
./smart-lint.sh --debug   # Debug mode
./smart-lint.sh --fast    # Skip slow checks
```

### Exit Codes
- `0`: All checks passed ✅
- `1`: General error (missing dependencies)
- `2`: Issues found - must fix ALL

## Dependencies

Hooks work best with these tools installed:
- **Go**: `golangci-lint`
- **Python**: `black`, `ruff`
- **JavaScript**: `eslint`, `prettier` 
- **Rust**: `cargo fmt`, `cargo clippy`
- **Nix**: `nixpkgs-fmt`, `alejandra`, `statix`

Hooks gracefully degrade if tools aren't installed.
