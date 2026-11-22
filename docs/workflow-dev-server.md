# workflow-dev-server hook

`agent-agnostic/hooks/workflow-dev-server.sh` starts a project's dev server when a
build worktree is created and stops it when the worktree goes away. It is
stack-neutral: the start command comes from project config, and **with no
`CLAUDE_DEV_SERVER_CMD` set it does nothing** (no process, no tab, no output, no
files). Wiring, config table and CLI modes are in the payload's
[`hooks/README.md`](../agent-agnostic/hooks/README.md); this page holds the lifecycle
and the rationale.

It reaches projects through the normal install path: `sync-install.sh` copies the
script to `~/.claude/hooks/` and merges the two `settings.json` entries. There is no
per-project hook copy; each project opts in through `env` config.

## Lifecycle

1. **Setup.** A `PostToolUse` Bash call whose output is a `workflow-setup.sh` run
   (no `--parent`, branch `feature|bug|hotfix/…`, an existing `WORKTREE:` path)
   triggers a start. `docs/` and `sync/` runs, and `--parent` children, never do.
2. **Queue.** If any `CLAUDE_DEV_SERVER_READY_PATHS` entry is missing (dependencies
   not installed yet), a `.pending` registry entry is written instead. Every later
   `PostToolUse` call checks the entries and starts the server once all paths exist.
   The entry stores the paths, so the check needs no config read.
3. **Start.** A deterministic port is derived from the worktree name, probed upward
   40 ports; the command runs under `setsid nohup bash -c` with cwd = the worktree,
   `{port}` substituted and `PORT` exported. The hook waits for the port to bind
   (timeout clamped to 80s, under the 90s hook timeout), then writes
   `.artifacts/dev-server.{pid,url,log,opened}` and a `.server` registry entry.
   `additionalContext` tells the agent the URL, port, pid and log, and to watch the
   log before claiming a change works.
4. **Tab.** One browser tab per worktree, tracked by the `opened` marker, which is
   written only after the opener launched successfully. `--reopen` forces another;
   `CLAUDE_DEV_SERVER_BROWSER=none` or no display disables it.
5. **Remove.** The `PreToolUse` (`--hook-pre-remove`) branch parses the removal
   command and stops that worktree's server before the removal runs.
6. **Sweep.** On every `PostToolUse` the hook also checks the registry and stops any
   server whose worktree no longer exists. This catches removals no command string
   shows (a script, a manual `rm -rf`, a path the parser declines).

## Config

Keys are resolved with `resolve-config.sh --root <main checkout of the worktree>`, so a
`settings.local.json` in the main checkout is honoured even though worktrees do not
carry one. Never read the inherited process `$VAR`: the `env`-block gotcha in
`artifact-locations` applies. Key table: see the payload README.

## Stops need no config (D5)

Stop paths act on pids the hook itself recorded, so they work with no
`CLAUDE_DEV_SERVER_CMD`. That is what lets this hook stop a server started by another
tool that wrote the same `.artifacts/dev-server.pid` file (see Coexistence).

## Pid-reuse guard

A recorded pid is killed only if (i) its recorded start time (pid-file line 2, or the
registry entry) equals `ps -o lstart=` now, or (ii) no start time was recorded (a bare
one-line pid file) and the process cwd is the worktree or inside it. The worktree path
is `realpath`-normalised first; the cwd is read from `/proc` or `lsof`, and if neither
is available the check fails closed. A failed guard kills nothing: the stale record is
removed and the message says the pid could not be verified. Kill is process-group
`TERM`, 10s grace, then `KILL`.

## Why there is no `if`

Both handlers carry an explicit `timeout` and no `if`. An `if: "Bash(git worktree
remove:*)"` is permission-rule prefix matching and would not match
`git -C <dir> worktree remove`, the exact command whose miss orphaned servers before
this hook. Removal detection is therefore done inside the hook: `-C` (repeated,
relative), global git options before `worktree`, `-f`/`--force` (also twice), relative
paths resolved against `-C` or the payload `cwd`, quoted paths, compound commands.

The idle path (unconfigured project, empty registry) execs no external program: stdin
is read with a builtin, the hook dir derived by parameter expansion, the payload
prefiltered with `case`, the registry checked by glob.

## Why `workflow-setup.sh:237` needs nothing

That line removes a worktree the same invocation created, after a failed `--reuse`
merge, then exits 1 before the run dir exists. A failing Bash call does not fire
`PostToolUse`, so no hook ever saw that worktree and no server, pending entry or
registry entry can point at it. Nothing can be orphaned there; that, not the sweep, is
why it is safe.

## Registry

`${XDG_STATE_HOME:-$HOME/.local/state}/dae/dev-servers/`, entries keyed
`<basename>-<cksum of abs path>`: `.server` (`pid`, start time, worktree, port) and
`.pending` (worktree, ready paths). It outlives the worktree, which a run-dir file
cannot; that is what makes the sweep possible. The sweep is global: it stops orphans
from any repo, but only servers this hook started.

## CLI

`--start <wt> [--no-open|--reopen]`, `--stop <wt>`, `--status <wt>`, `--stop-all`,
`--sweep`. `--start` refuses a directory that is not a git worktree root (exit 1, no
files, no registry entry) and exits 1 when unconfigured. Hook modes always exit 0.

## resolve-config.sh env parsing

The hook needs values containing `{port}`. `resolve-config.sh` used to cut the `env`
block at the first `}`, so such a value, and every later key in the block, failed to
resolve. `env_value_from` is now a string- and brace-aware POSIX-awk scanner (no jq,
mawk-safe), reading only the top-level `env` object. It unescapes `\"`, `\\`, `\/`,
`\n`, `\t`; other escapes pass through verbatim. Regression cases are in
`tests/resolve-config-precedence.test.sh`.

## Coexistence and follow-up

mythic-made still has its own project hook. Until it is removed, both are wired
there: the generic start stays inert (no `CLAUDE_DEV_SERVER_CMD`), and the generic
stop works from mythic-made's pid files under guard (ii), which fixes its `git -C`
orphaning on sync.

**F1 (separate run in the mythic-made repo):** delete its local hook and the two
`settings.json` entries, add the `CLAUDE_DEV_SERVER_*` env config, and trim its
`workflow-dev-server` rule to the project-specific residue, all in one commit so the
two hooks never race to start a server.

Not done here: Antigravity wiring (F2), the mythic-made admin URL probe (dropped), a
new always-on rule (the hook's `additionalContext` carries the guidance).

Limits are tracked in [`known-issues.md`](known-issues.md).
