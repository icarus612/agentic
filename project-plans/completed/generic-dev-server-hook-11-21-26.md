# generic-dev-server-hook: a stack-neutral per-worktree dev-server hook in agentic, with a teardown that cannot miss

### Ask of record (source: /home/icarus64/repos/agentic/.workflows/generic-dev-server-hook/.artifacts/progress-log.md)

**11-21-26** — fix it in agentic then

**11-21-26 — appended, direction chosen (AskUserQuestion: where should the fix go?)** — "Move into agentic" — Make the dev-server hook a generic agentic hook (the start command comes from project config) and sync it to projects.

**11-22-26 — appended, code gate round 1 (AskUserQuestion)** — "Fix 1 and 2 first" — Rebuild lane 1: --start refuses a non-git directory, and the opened-marker is written only after the opener succeeds. Then code review round 2.

## Phase syllabus
- [ ] Phase 1: Config resolver fix
  - [x] 1.1: String- and brace-aware env-block parsing in resolve-config.sh   (lane 1)
- [ ] Phase 2: Generic hook script
  - [x] 2.1: Config resolution, inert gating, and the post-setup start   (lane 1, after: 1.1)
  - [x] 2.2: Queued start until the project's readiness paths exist      (lane 1, after: 2.1)
  - [x] 2.3: One browser tab per worktree                                 (lane 1, after: 2.1)
  - [x] 2.4: Removal detection and guarded process-group stop             (lane 1, after: 2.1)
  - [x] 2.5: Server registry, orphan sweep, and CLI modes                 (lane 1, after: 2.2, 2.3, 2.4)
  - [x] 2.6: Start refuses non-worktree dirs; opened-marker only after a successful launch   (lane 1, after: 2.5)
- [ ] Phase 3: Payload docs
  - [x] 3.1: hooks/README.md section and agent-agnostic/AGENTS.md entry   (lane 2)
- [ ] Phase 4: Integration
  - [x] 4.1: Wire the hook in settings.json and pin it in the registration test   (after: 2.5)
  - [x] 4.2: Full suite and hook-level end-to-end check                           (after: 2.6, 3.1, 4.1)
- [ ] Phase 5: Record
  - [x] 5.1: docs root page, map row, pipeline bullet, known-issues entries        (after: 4.2)

## Goal & scope

The dev-server hook exists only in mythic-made today (`mythic-made/.claude/hooks/workflow-dev-server.sh`). It starts a dev server for a build run's parent worktree. Its teardown has a gap. The pre-remove branch matches only the literal substring `git worktree remove` (`workflow-dev-server.sh:414-421`). cleanup-merged ran `git -C <repo> worktree remove <wt>`, so the hook exited without acting and the server was left orphaned on its port (progress log, "Decisions").

This plan ports the hook into agentic as one **generic, stack-neutral** hook: `agent-agnostic/hooks/workflow-dev-server.sh`. It reaches projects through agentic's existing install path:
- `sync-install.sh` copies `agent-agnostic/hooks/*` to `~/.claude/hooks/` (`sync-install.sh:14,128`).
- It merges the wiring into `~/.claude/settings.json` (`:18,131`).

That is how agentic "syncs a hook to projects": install and wire it once, globally, and each project opts in through config. There is no per-project hook-copy mechanism. `tool-based/` holds no hooks (`find tool-based -path '*hooks*'` returns nothing), and a universal hook would not belong there anyway.

**In scope**
- **A resolver fix.** The resolver is `resolve-config.sh`'s `env_value_from`. Today it cuts the `env` block at the first `}` (`resolve-config.sh:90`, `awk 'BEGIN{RS="}"} …'`). So a value like `serve --port {port}` fails to resolve, and so does every later key in the same block (gate round 1 reproduced this). The fix ships with a regression test (1.1).
- **The generic hook.** It keeps every mythic-made behaviour, generalised only where that behaviour was stack-specific:
  - queued start after install
  - one browser tab per worktree
  - process-group kill
  - build-type gating (`feature|bug|hotfix` only)
  - parent-only gating (`--parent` is skipped)
  - the `--start/--stop/--status/--stop-all` CLI modes
  - pid/url/log/opened files in the run dir
- **Per-project config** through the existing `resolve-config.sh` chain. That chain reads `env.<VAR>` from `.agents|.claude/settings[.local].json`, then the global settings (`resolve-config.sh:16-19,107-112`). **With no `CLAUDE_DEV_SERVER_CMD` set, nothing starts, no tab opens and nothing is printed.**
- **The teardown fix.** Removal detection covers:
  - `git -C <dir> worktree remove <path>`, including repeated and relative `-C`
  - git global options given before `worktree`
  - `-f`/`--force`, including twice
  - a relative `<path>`, resolved against `-C` or else the payload `cwd`
  - quoted paths
  - compound commands
- **A registry and orphan-sweep backstop.** It catches removals that no Bash command string shows. Examples: a `git worktree remove` run inside a script, a manual `rm -rf`, or a quoted path with spaces that the parser declines.
- **Wiring** in `agent-specific/claude/settings.json`, pinned in `tests/hook-registrations.test.sh`.
- **A new contract test**, `tests/workflow-dev-server.test.sh`.
- **Docs.** Payload docs (`agent-agnostic/hooks/README.md`, `agent-agnostic/AGENTS.md`) and docs-root pages (written at Record).

**Out of scope**
- **Any edit to mythic-made.** Moving mythic-made onto this hook is a separate follow-up run in the mythic-made repo (Risks R1, follow-up F1).
- **The mythic-made admin (Medusa) URL probe** (`workflow-dev-server.sh:142-155,308`). Decided D3.
- **An always-on rule file.** Decided D4.
- **Antigravity wiring** (`agent-specific/antigravity/hooks.json`). The adapter's payload and tool names differ (`agy-hook-adapter.sh`). The precedent plan `hook-timeouts-and-if-scoping-11-05-26.md:34` excluded Antigravity hook changes for the same reason. Follow-up F2.
- **Widening `allow-workflow-cleanup.sh`**, which is a different concern.
- **Any change to `workflow-setup.sh`.** Decided D2.

**Why `workflow-setup.sh:237` needs no handling.** That line removes a worktree that the **same invocation** created at `:234`, after a failed `--reuse` merge. It then calls `err`, which exits 1 (`:238`). All of that happens before the run dir exists (`:249-272`). Because the command fails, `PostToolUse` does not fire for it (A3). No hook therefore ever saw that worktree, so no server, pending entry or registry entry can point at it. **Nothing can be orphaned there, and that — not the sweep — is why it is safe.** The sweep in 2.5 is a general backstop for removals the parser cannot see. It acts on the next successful Bash call, and does not claim to act on the failing `workflow-setup.sh` call itself.

## Stack & MAJOR versions

| Item | Version | Verified from |
|---|---|---|
| Manifests/lockfiles | none, so no stack to pin | `docs/README.md` "At a glance": "No manifest, lockfile, or build system"; `ls` of the repo root |
| Bash | system bash; hooks use `#!/usr/bin/env bash` + `set -uo pipefail` | every `agent-agnostic/hooks/*.sh` header, e.g. `resolve-config.sh:54`, `allow-workflow-cleanup.sh:44` |
| awk | **mawk 1.3.4** on this host, so only POSIX awk may be used (no gawk extensions) | `awk -W version` → `mawk 1.3.4 20200120`; `readlink -f $(command -v awk)` → `/usr/bin/mawk`; `shell-discipline` warns about mawk |
| Claude Code (hook semantics) | 2.1.330 | `claude --version`, 11-21-26 |
| Runtime tools the hook relies on | `setsid`, `realpath`, `cksum`, `ps` present on this host; `python3` present (tests only) | `which setsid python3 realpath`, 11-21-26 |
| Test framework | none: hand-rolled `tests/*.test.sh`, run as `bash tests/<name>.test.sh` | `ls tests/`; `tests/workflow-diff-check.test.sh:1-50` |
| `jq` | allowed in **tests** only; **never** in `resolve-config.sh` or this hook | `resolve-config.sh:23-26,86` ("No jq dependency"); `tests/resolve-config-precedence.test.sh:532-569` (case set 15 pins "a shadowed fake jq … is never invoked"); `tests/hook-registrations.test.sh:62,71` (tests use jq) |

## Conventions to enforce

These are hard constraints.

- **Tech-agnostic** (`tech-agnostic`, `respect-versions-and-conventions`).
  - The hook names no package manager, framework or bundler: no `pnpm`, `node_modules`, `vite`, `apps/website`, `--strictPort`, `enhanced-img` or `Medusa`.
  - Everything stack-specific comes from config.
  - Docs examples are labelled as examples.
- **Config through `resolve-config.sh` only.** Never read the inherited process `$VAR` for project config; that is the env-block gotcha described at `resolve-config.sh:8-15`. Call it with `--root <main checkout>`, plus `--default` where a default exists, as `allow-workflow-cleanup.sh:77` and `workflow-setup.sh:128` do.
- **No jq and no python in `resolve-config.sh`.** It must keep its contract that jq is never invoked (case set 15). It is called by every hook that reads config, including the per-write `scope-writes.sh` (`:240-245`), so it must not gain a runtime dependency.
- **No jq in the hook.**
  - For `tool_name`, `command` and `cwd`, use the flat JSON field extraction in `allow-workflow-cleanup.sh:50-54`.
  - For the setup output, use the raw-envelope `WORKTREE:`/`BRANCH:` grep from mythic-made `workflow-dev-server.sh:453-467`.
- **Never blocks.** Every hook mode exits 0. Messages go out as `systemMessage` / `hookSpecificOutput.additionalContext` JSON, built with the pure-parameter-expansion `json_escape` (mythic-made `:95-101`, no sed).
- **No external command on the idle path.**
  - When a project is unconfigured and nothing is queued or registered, the hook must not exec any external program.
  - Read stdin with the builtin `IFS= read -r -d '' payload`, never `$(cat)`.
  - Derive the hook's own dir with parameter expansion (`${BASH_SOURCE[0]%/*}`), never `dirname`.
  - Prefilter with `case` and check the registry with a glob.
  - `resolve-config.sh`, `git`, `ps` and friends run only on a setup trigger, a ripe queue entry, a removal match, or a registry entry whose worktree is gone.
- **Explicit `timeout` on every handler, and no `if`.** An `if: "Bash(git worktree remove:*)"` uses permission-rule prefix matching (`hook-timeouts-and-if-scoping-11-05-26.md:50-55`). It would not match `git -C … worktree remove`, which is exactly the defect being fixed.
- **Minimal code comments** (`minimal-code-comments`).
  - No banner header like mythic-made's 60-line one.
  - Rationale goes to `docs/workflow-dev-server.md`.
  - `check-diff-hygiene.sh` enforces this at builder teardown.
- **Shell discipline in tests.**
  - Kill only by recorded pid or pgid, never with a broad `pkill -f`. It is machine-wide and has killed other runs' servers (user memory).
  - Put every scratch dir and process in a cleanup trap, following the `tests/workflow-diff-check.test.sh:12-20` pattern.
- **Hermetic tests.**
  - `HOME` and `XDG_STATE_HOME` point at scratch dirs, so the user's real `~/.claude/settings.json` and registry are never touched.
  - Ports come from a random high base.
  - The browser is a stub script.
- **Builders never write the docs root.** `scope-writes.sh:311-319` denies them. `docs/**` is written only at Record (5.1), by `documenter`.

## Decided at the plan gate (round 1, 11-21-26)

Source: the last bullet of the progress log's "## Decisions" section ("Gate round 1 decisions (user, AskUserQuestion 11-21-26)"). These are settled. They are not open questions.

- **D0 — The `{port}` / `resolve-config.sh` defect gets fixed in `resolve-config.sh` itself, with a regression test.** The user's note says "jq parse". As the coordinator directed, I checked whether a jq parser fits before choosing the mechanism:
  - `resolve-config.sh` deliberately avoids jq (`:23-26`, `:86`).
  - Its test suite pins that as a contract: case set 15 (`tests/resolve-config-precedence.test.sh:532-569`) shadows `jq` and fails if it is ever called.
  - Several hooks use jq, but only optionally: `claude-install-drift.sh:48` exits if jq is absent, and `agy-hook-adapter.sh:48` degrades gracefully. None of them depends on it for correctness.
  - **Mechanism chosen:** a string- and brace-aware POSIX-awk scanner. It is a single awk process, so it adds no dependency, keeps case set 15 green, and runs under mawk.
  - The user's actual requirement is met in full: the block is parsed properly, without cutting at the first `}`, and a regression test covers `{}` in a value plus a later key in the same block.
  - **Confirmed by the user at gate round 2 (11-21-26): awk, not jq.**
- **D1 (was DP-1, chose A):** the registry lives at `${XDG_STATE_HOME:-$HOME/.local/state}/dae/dev-servers/`.
- **D2 (was DP-2, chose A):** no change to `workflow-setup.sh`. The reason is restated above: nothing can be orphaned at `:237`.
- **D3 (was DP-3, chose A):** the admin/secondary URL probe is dropped.
- **D4 (was DP-4, chose A):** no new universal rule. The hook's `additionalContext` carries the guidance.
- **D5 (was DP-5, chose A):** the stop paths act without config, on pids the hook's own files recorded. The pid-reuse guard in 2.4 now protects those stops.

## Design (shared by all Phase 2 subphases)

**Config keys.** Each key is resolved with `resolve-config.sh <KEY> --root <main checkout of the worktree>`. The main checkout is `dirname "$(git -C <wt> rev-parse --path-format=absolute --git-common-dir)"`. Resolving from the main checkout means a `settings.local.json` there is honoured even though worktrees do not carry one, matching `workflow-setup.sh:117-123`.

| Key | Default | Meaning |
|---|---|---|
| `CLAUDE_DEV_SERVER_CMD` | *(unset = inert)* | Shell command run in the worktree root. `{port}` is substituted and `PORT=<port>` is exported. After 1.1, values may contain `{}` and JSON-escaped `\"`. |
| `CLAUDE_DEV_SERVER_READY_PATHS` | *(unset = start immediately)* | Space-separated worktree-relative paths. All must exist before the start; otherwise the start is queued. |
| `CLAUDE_DEV_SERVER_URL` | `http://localhost:{port}` | URL that is reported and opened. |
| `CLAUDE_DEV_SERVER_PORT_BASE` / `_PORT_SPAN` | `5180` / `300` | A deterministic per-worktree port from a hash of the name, then a probe of 40 ports upward (mythic-made `:63-65,131-140`). |
| `CLAUDE_DEV_SERVER_READY_TIMEOUT` | `45`, clamped to `80` | Seconds to wait for the port to bind. The clamp keeps a start under the 90s `PostToolUse` timeout. |
| `CLAUDE_DEV_SERVER_BROWSER` | *(unset = `google-chrome` → `google-chrome-stable` → `chromium`, only with `DISPLAY`/`WAYLAND_DISPLAY`)* | Opener command. The value `none` disables opening. |

**State.**
- **Per-worktree files** stay in the run dir: `<wt>/.artifacts/dev-server.{pid,url,log,opened}`. The names are kept identical to mythic-made's on purpose (R1).
  - The generic pid file holds `pid` on line 1 and the start time on line 2. The start time is `ps -o lstart= -p <pid>`.
  - mythic-made's pid files have line 1 only.
- **Cross-worktree registry** (D1): `${XDG_STATE_HOME:-$HOME/.local/state}/dae/dev-servers/`.
  - Each entry is keyed `<basename>-<cksum of abs path>`.
  - A `.server` entry holds `pid<TAB>start-time<TAB>worktree<TAB>port`.
  - A `.pending` entry holds `worktree<TAB>ready-paths`.
  - The registry outlives the worktree, which a run-dir file cannot do, and that is what makes the sweep possible.

**Process identity guard.** This is the pid-reuse rule for every kill. A recorded pid is treated as ours only if one of these holds:
- (i) a recorded start time exists and equals `ps -o lstart= -p <pid>` now; or
- (ii) no start time is recorded (a bare one-line pid file, as mythic-made writes), and the process's cwd is the worktree path or inside it. Before comparing, the worktree path is `realpath`-normalised (with the `realpath -m` → printf fallback from `allow-workflow-cleanup.sh:121`). The cwd read from `/proc` or `lsof` is already a resolved path, so without this a symlinked parent dir would make a genuine server fail the guard.

The cwd check reads `/proc/<pid>/cwd` where `/proc` exists. Elsewhere it reads `lsof -a -p <pid> -d cwd -Fn`. If neither is available, the check fails.

This works because both the mythic-made start (`workflow-dev-server.sh:271-276`, `cd "$wt"` then `setsid nohup …`) and the generic start launch the group leader with its cwd set to the worktree. On a failed guard, nothing is killed. The stale pid file or registry entry is removed, and the message says the pid could not be verified.

**Kill.** Group `TERM`, wait up to 10s, then group `KILL`, following mythic-made `:187-206`. The negative-pid signal is sent only after the guard passes.

**Modes.**
- **`--hook-pre-remove`** (`PreToolUse` Bash): parse a removal and stop that worktree's server.
- **Default** (`PostToolUse` Bash):
  1. sweep
  2. ripe pending entries
  3. setup trigger
- **CLI:** `--start <wt> [--no-open|--reopen]`, `--stop <wt>`, `--status <wt>`, `--stop-all`, `--sweep`.

**Stop paths do not require config** (D5).

## Phase 1: Config resolver fix

### 1.1 — String- and brace-aware env-block parsing in resolve-config.sh
- **File scope:**
  - `agent-agnostic/hooks/resolve-config.sh`: `env_value_from` at `:86-94`, plus its header note at `:23-26`.
  - `tests/resolve-config-precedence.test.sh`: new case sets appended after the last existing set, using the existing `run_resolve`/`new_home`/`new_root` helpers at `:74-115`.
- **Pattern to follow:**
  - Keep the function signature `env_value_from <file> <key>` and its contract: print the value, return non-zero when absent. The caller loop at `:107-112` stays unchanged.
  - Replace the `RS="}"` record split with a single POSIX-awk pass over the whole file. It reads the file in, scans character by character with `substr`, and tracks string state (inside a `"…"`, a backslash escapes the next character) and brace and bracket depth.
  - The scan locates the key `"env"` **at depth 1 only**, so an `"env"` inside a nested object or a string never matches. It takes the object value that follows, up to the brace that closes it at matching depth.
  - Inside that object it reads flat `"KEY": "VALUE"` string pairs. It unescapes `\"`, `\\`, `\/`, `\n` and `\t`. Every other escape is kept verbatim with its backslash, and is never dropped. That covers `\uXXXX`, plus any other `\x`, such as a hand-written `C:\Users`, which the old parser also returned verbatim. It prints the value for the requested key.
  - Non-string values (numbers, booleans, nested objects) are skipped without breaking the scan.
  - Must run on mawk: no `gensub`, `RT`, `match(s, re, arr)` or `FPAT`.
- **Acceptance (contract)**, each a new case set in the precedence suite:
  - (a) **The regression.** `{"env":{"CLAUDE_DEV_SERVER_CMD":"serve --port {port}","OTHER":"x"}}`. Both keys resolve: `serve --port {port}` and `x`.
  - (b) Nested braces in one value plus several later keys: `"A":"a {b {c}} d","B":"2","C":"3"`. All three resolve exactly.
  - (c) A JSON-escaped quote and backslash: `"Q":"say \"hi\" \\ ok"` resolves to `say "hi" \ ok`.
  - (d) An `env` block that is not the first object, preceded by `"permissions":{"allow":["Bash(x:*)"]}` and a `"hooks"` object whose command string contains `}` and `"env"`. The value still resolves from the top-level `env`.
  - (e) A nested `"env"` key, in an object other than the top level, is never matched. With no top-level `env`, the result is "cannot resolve", exit 1.
  - (f) Number and boolean siblings in `env`, such as `"N": 1, "T": true`, do not break the resolution of a string key after them.
  - (g) Every existing case set (00–20+) still passes unchanged, including case set 15: the shadowed `jq` is never invoked.
  - (c2) Escapes outside the handled set are kept verbatim. The JSON text `"W":"C:\Users\x \u00e9 \q"` resolves to exactly `C:\Users\x \u00e9 \q`, with every backslash present, and a later key in the same block still resolves.
  - (h) The real file `agent-specific/claude/settings.json` (it has `permissions` and `hooks` blocks) resolves a key injected by copying it into a fixture with an `env` block added. Use jq in the test only, to build the fixture.
- **Test approach:**
  - Oracle: new contract tests, plus the existing suite.
  - All the other suites that call `resolve-config.sh` must stay green (`scope-writes.test.sh`, `resolve-scratch.test.sh`, `parent-tree-guard.test.sh`, `verify-scope-parsing.test.sh`, `mark-syllabus-guard-e2e.test.sh`). The builder runs those five, plus the precedence suite, at the lane exit.

## Phase 2: Generic hook script

### 2.1 — Config resolution, inert gating, and the post-setup start
- **File scope:** `agent-agnostic/hooks/workflow-dev-server.sh` (new); `tests/workflow-dev-server.test.sh` (new, written by the contract-tester).
- **Pattern to follow:**
  - mythic-made `workflow-dev-server.sh`: `start_server` (`:213-342`), the entry point (`:431-470`), and the helpers `emit`, `json_escape`, `port_busy`, `server_pid` and `pick_port` (`:95-140`).
  - Field extraction from `allow-workflow-cleanup.sh:50-63`.
  - `resolve-config.sh` call style from `allow-workflow-cleanup.sh:73-82`.
- **Behaviour:**
  1. On `PostToolUse`, act only when all of these hold:
     - the payload contains `workflow-setup.sh`
     - it does not contain `--parent`
     - it has `BRANCH: feature|bug|hotfix/…`
     - it has a `WORKTREE:` path that exists
  2. Resolve `CLAUDE_DEV_SERVER_CMD` against that worktree's main checkout. If it is unset, exit 0 with **empty stdout**.
  3. If a live server is already recorded for this worktree, report it and do not start a second one.
  4. Otherwise start one:
     - Pick a port.
     - Launch `setsid nohup bash -c "<cmd with {port} substituted>"` with cwd set to the worktree, `PORT` exported, and stdout and stderr sent to `.artifacts/dev-server.log`.
     - Write the pid file: the pid, then its start time on line 2.
     - Wait up to the ready timeout for the port to bind. A bound port counts as ready (mythic-made `:281-296`).
     - Write the url file and emit the PostToolUse JSON. Its `additionalContext` names the URL, port, pid and log path, tells the agent to monitor the log before claiming a change works, and gives the `--stop` command.
  5. On a bind failure, emit a failure message that names the log. Emit a message too when no port is free.
  6. If `setsid` is missing, emit one message and do not start.
- **Acceptance (contract):**
  - (a) Unconfigured fixture repo with a setup payload: exit 0, empty stdout, and no `.artifacts/dev-server.*` files.
  - (b) Configured repo:
    - a server starts on a port in `[base, base+span+40)`
    - the pid file's line 1 is a group leader (pgid == pid) and line 2 equals `ps -o lstart= -p` of it
    - the url file equals the substituted `CLAUDE_DEV_SERVER_URL`
    - the stdout JSON parses and its `systemMessage` contains the URL
  - (c) `{port}` and `$PORT` both reach the command. The `CLAUDE_DEV_SERVER_CMD` value in the fixture contains `{port}` and is **followed in the same `env` block** by `CLAUDE_DEV_SERVER_URL` and `CLAUDE_DEV_SERVER_READY_TIMEOUT`, and all three take effect. This is the hook-level guard for the 1.1 defect.
  - (d) No server starts for a `docs/…` or `sync/…` branch, a `--parent` setup, or a payload with no `workflow-setup.sh`.
  - (e) A second setup payload for the same worktree reports "already running" and starts no second process.
  - (f) The same worktree name yields the same port across restarts.
  - (g) The hook script contains none of `pnpm|node_modules|vite|apps/website|strictPort|medusa`. Check with a case-insensitive grep, with a positive control: the same grep run on an inline fixture string containing `pnpm` must hit.
- **Test approach:**
  - Oracle: new contract tests.
  - `HOME` and `XDG_STATE_HOME` point at scratch dirs.
  - The fixture repo has a `.claude/settings.json` `env` block and a real `git worktree add` under `.workflows/`.
  - The fake server is `python3 -m http.server {port} --bind 127.0.0.1`.
  - Payloads are crafted JSON on stdin.
  - The port base is random in 40000–49999.
  - The cleanup trap kills by recorded pgid.

### 2.2 — Queued start until the project's readiness paths exist
- **File scope:** `agent-agnostic/hooks/workflow-dev-server.sh`; `tests/workflow-dev-server.test.sh`.
- **Pattern to follow:** mythic-made's queue (`:236-257`) and `check_pending` (`:362-373`), with two generalisations:
  - The `node_modules` checks become `CLAUDE_DEV_SERVER_READY_PATHS`.
  - The marker moves from the run dir to a registry `.pending` entry that stores the ready paths, so checking whether it is ripe needs no config read.
- **Behaviour:**
  - If a ready path is missing at start time, write the `.pending` entry and emit a "queued" message that tells the agent it does not need to do anything.
  - On every `PostToolUse` call:
    - Glob the `.pending` entries using builtins only.
    - Drop entries whose worktree is gone.
    - When every ready path of an entry exists, remove the entry, re-resolve the config and start the server. If the config is now unset, drop the entry silently.
    - Start at most one queued server per call (mythic-made `:359-361`).
  - `--stop` also deletes the worktree's `.pending` entry.
- **Acceptance:**
  - (a) Ready path absent: a `.pending` entry exists, no server is running, and the queued message is emitted.
  - (b) After the path is created, an **unrelated** Bash payload (`ls`) starts the server.
  - (c) An entry whose worktree was deleted is removed, and nothing starts.
  - (d) With two ripe entries, it takes two calls to start both.
  - (e) `READY_PATHS` unset: the server starts immediately and no entry is written.
  - (f) **The idle path runs no external command.** Harness:
    - Copy the hook into a scratch dir next to a stub `resolve-config.sh` that appends to a log.
    - Run it as `/bin/bash <copy>` with `PATH` set to an **empty** scratch dir.
    - Use a fresh empty `XDG_STATE_HOME`, and feed `{"tool_name":"Bash","cwd":"<dir>","tool_input":{"command":"ls"}}` on stdin.
    - Assert: exit 0, empty stdout, stderr has no `command not found`, and the stub log is empty.
    - **Positive control:** in the same harness, a setup payload for a configured fixture worktree must produce either a stub-log line or a `command not found` on stderr. That proves the harness can detect an exec.
    - The same assertion runs for `--hook-pre-remove` with a command that does not mention a worktree.
- **Test approach:** Oracle: new contract tests; the same harness as 2.1.

### 2.3 — One browser tab per worktree
- **File scope:** `agent-agnostic/hooks/workflow-dev-server.sh`; `tests/workflow-dev-server.test.sh`.
- **Pattern to follow:** mythic-made `open_in_chrome` (`:157-183`): the `.artifacts/dev-server.opened` marker, return codes 0/1/2, and the "(tab already open)" message branch (`:310-315`). Three things are generalised:
  - the opener, via `CLAUDE_DEV_SERVER_BROWSER`
  - `MM_DEV_SERVER_*`, replaced by the `--no-open`/`--reopen` CLI flags
  - the `none` config value, which disables opening
- **Acceptance:**
  - (a) With a stub opener that appends its argv to a log, two starts of the same worktree (with a stop in between) produce exactly one log line, and the second message says "tab already open".
  - (b) `--reopen` opens again.
  - (c) `--no-open` and `CLAUDE_DEV_SERVER_BROWSER=none` call no opener.
  - (d) With the default chain and neither `DISPLAY` nor `WAYLAND_DISPLAY` set, nothing opens, and the message says the browser was not opened.
  - (e) A different worktree gets its own single tab.
- **Test approach:** Oracle: new contract tests. The stub opener is used throughout, so no real browser ever starts.

### 2.4 — Removal detection and guarded process-group stop
- **File scope:** `agent-agnostic/hooks/workflow-dev-server.sh`; `tests/workflow-dev-server.test.sh`.
- **Pattern to follow:**
  - The Design's process identity guard plus mythic-made `stop_server` (`:187-211`).
  - Path normalisation from `allow-workflow-cleanup.sh:117-121` (`realpath -m`, falling back to printf).
  - This replaces the substring match at mythic-made `:413-429`.
- **Behaviour (`--hook-pre-remove`):**
  1. **Prefilter with builtins:** the `command` must contain both `worktree` and `remove`. Otherwise exit 0.
  2. **Split** the command into segments on `&&`, `||`, `;`, `|` and newlines, and tokenise each with `read -ra`. **Never use `eval`.**
  3. **Track a running cwd.** It starts at the payload `cwd`, and `cd <dir>` segments update it.
  4. **Walk git's global options.** In each segment, skip leading `VAR=val` tokens. At `git`, walk the global options:
     - `-C <dir>` is cumulative, and a relative value resolves against the current effective dir.
     - `-c <kv>` skips its value.
     - `--git-dir=…`, `--work-tree=…` and other `-*` tokens are skipped.
  5. **Find the path.** Require the tokens `worktree` and `remove`. Skip every `-*` token (`-f`, `--force`, `-ff`). Take the first non-flag token as the path, and strip one layer of matching quotes.
  6. **Resolve it.** A relative path resolves against the effective `-C`, or else the running cwd. Normalise the result.
  7. **Stop.** For each path found that has a pid file or registry entry, apply the identity guard and kill only on a pass. Remove the matching pid/url files and the registry `.server` and `.pending` entries.
  8. **Report.** Emit `{"systemMessage": "dev-server cleanup: …"}` only when something was stopped or refused.
- **Acceptance.** Table-driven. Each case starts a fake server for a fixture worktree, feeds the PreToolUse payload, and asserts the whole group is gone (`kill -0 -<pgid>` fails). Positive cases:
  - (a) `git worktree remove <abs>`
  - (b) `git -C <repo> worktree remove <abs>` (the trigger defect)
  - (c) `git -C <repo> worktree remove .workflows/<name>`
  - (d) `git worktree remove .workflows/<name>` with payload `cwd` = repo
  - (e) `git -C <repo> worktree remove --force <abs>`, and `-f -f <abs>`
  - (f) `git -C <a> -C <b-relative> worktree remove <rel>`
  - (g) `git -c core.x=y worktree remove '<abs>'`
  - (h) `cd <repo> && git worktree remove .workflows/<name>`
  - (i) A wrapper whose child holds the port, using `bash -c 'python3 -m http.server … & wait'`. The grandchild must also be dead.

  Negative cases — nothing stops:
  - (j) `git worktree list`
  - (k) `echo "worktree remove"`
  - (l) `git worktree remove <other-path>` leaves the fixture server running.

  Pid-reuse guard cases:
  - (m) **Bare pid file, guard passes.** A one-line `.artifacts/dev-server.pid` (mythic-made shape) whose process was started with cwd = the worktree is stopped.
  - (n) **Bare pid file, guard fails.** A one-line pid file naming a test-owned `sleep <unique-token>` process started with cwd = a different scratch dir: the `sleep` survives, the pid file is removed, and the message says the pid could not be verified.
  - (o) **Two-line pid file with a mismatching start time:** the process survives.
  - (p) **Bare pid file, symlinked path, guard passes.** The fixture worktree is reached through a symlinked parent dir: `ln -s <real-workflows-dir> <scratch>/link`, and the removal payload names `<scratch>/link/<name>`. A one-line pid file whose process was started with cwd = the worktree is still stopped.
- **Test approach:** Oracle: new contract tests. Each case uses its own worktree and port. The trap kills survivors by pgid or recorded pid.

### 2.5 — Server registry, orphan sweep, and CLI modes
- **File scope:** `agent-agnostic/hooks/workflow-dev-server.sh`; `tests/workflow-dev-server.test.sh`.
- **Pattern to follow:** mythic-made `status_server`, `stop_all_servers` and the entry-point `case` (`:344-404`). `--stop-all` now iterates the registry's `.server` entries instead of globbing `.workflows/*/` (`:375-386`).
- **Behaviour:**
  - A successful start writes a `.server` entry, and every stop removes it.
  - **Sweep.** It runs first on every `PostToolUse` call, and via `--sweep`.
    - Glob the `.server` entries with builtins.
    - For each entry whose `<worktree>/.git` is gone, apply guard (i) — the recorded start time. A worktree that no longer exists cannot be checked by cwd.
    - Kill the group on a pass, and remove the entry either way.
  - **CLI.**
    - `--start <wt>` without config prints `dev server not configured (CLAUDE_DEV_SERVER_CMD unset)` to stderr and exits 1.
    - `--status <wt>` prints one line.
    - `--stop <wt>` also works when the worktree dir is already gone, via the registry.
  - Every hook mode still exits 0.
- **Acceptance:**
  - (a) **A removal no command string shows.** Start a fake server for a worktree. Remove that worktree by running `git worktree remove --force` from the test script, not through a payload. Feed a `PostToolUse` payload with an unrelated command (`ls`). The group is dead and the entry is gone.
  - (b) The same, with `rm -rf` of the worktree.
  - (c) A forged entry whose recorded start time does not match the live pid (pointing at a test-owned `sleep <unique-token>`): the `sleep` survives and the entry is removed.
  - (d) `--stop-all` stops two servers in two worktrees, one of them already deleted.
  - (e) `--status` output differs between running and not running.
  - (f) `--start` without config exits 1 with the message.
  - (g) Every hook-mode invocation in the suite exits 0, asserted per call.
- **Test approach:** Oracle: new contract tests.

### 2.6 — Start refuses non-worktree dirs; opened-marker only after a successful launch
- **Origin:** a mid-build amendment from the 11-22-26 Ask of record entry. It fixes findings 1 and 2 of code gate round 1 (`project-plans/generic-dev-server-hook-11-21-26/code-review.md`, Round 1).
- **File scope:** `agent-agnostic/hooks/workflow-dev-server.sh`; `tests/workflow-dev-server.test.sh`.
- **Pattern to follow:** the built hook itself. Two places change:
  - `start_server` (around `:259-271`). Today, when `git rev-parse` fails, it falls back to `MAIN=$wt`.
  - `open_browser` (around `:235-257`). Today it writes `: > "$marker"` right after backgrounding the opener, before knowing whether the launch worked.
- **Item 1: refuse a directory that is not a git worktree root.**
  - **Shared check in `start_server`.** It runs before any config read, file write or registry write. The directory passes only when both of these hold:
    - `git -C "$wt" rev-parse --path-format=absolute --git-common-dir` succeeds.
    - `[ -e "$wt/.git" ]` holds.
  - **Why `.git` matters.** The second condition is the sweep's own liveness test (`:226`), so a server is never started for a path the sweep would immediately treat as removed. A subdirectory of a worktree fails this test, and so does a plain non-git directory. A main checkout passes, because its `.git` is a directory.
  - **Remove the old fallback.** The `MAIN=$wt` fallback is deleted.
  - **`--start <dir>` on failure:**
    - Print `workflow-dev-server: <dir> is not a git worktree root (no .git here, or not inside a git repository)` to stderr.
    - Exit 1.
    - Write nothing anywhere: no `.artifacts/`, no `.server`/`.pending` entry, no log, no opener call.
  - **Do the hook's own start paths need it?**
    - **Post-setup start:** cannot normally fail the check. It acts only on the `WORKTREE:` line that `workflow-setup.sh` prints at `:274`, and that line is printed only after `git worktree add` succeeded at `:234`/`:242`.
    - **Ripe-pending start:** reaches only worktrees that the post-setup path queued.
    - **Decision:** because the check lives in the shared `start_server`, all three paths get it. The hook paths refuse **silently**: exit 0, empty stdout, nothing registered, and any `.pending` entry for that path is dropped. The hook still never blocks.
    - **Why keep it on the hook paths:** it costs nothing extra (`git rev-parse` already runs there), and it closes the same register-then-sweep loop if a worktree is gone between the trigger and the start.
- **Item 2: write the opened-marker only after a successful launch.**
  - **Before launching:**
    - A configured `CLAUDE_DEV_SERVER_BROWSER` opener must resolve via `command -v`. Otherwise the launch has failed.
    - The default chain already returns 1 when no opener is found.
  - **Launching:** keep `setsid nohup "$opener" "$url" … &`, and record `$!`. After the existing short grace (`sleep 0.2`):
    - If the opener process is still alive (`kill -0 "$!"`), the launch succeeded.
    - If it has exited, `wait "$!"` reports its status. Status 0 means success: real browsers often hand the URL to a running instance and exit 0. Non-zero means failure.
  - **Writing the marker:** only on success. On failure the function returns 1. The existing message branch then reports "browser not opened", and no marker exists, so the next start retries the opener.
  - **Unchanged:** `--reopen`, `--no-open` and `none` behave exactly as in 2.3.
- **Acceptance (contract):**
  - (a) **Plain non-git dir.** `--start <non-git scratch dir>` with a configured env:
    - exit status 1
    - stderr contains `is not a git worktree root`
    - stdout is empty
    - no `<dir>/.artifacts` is created
    - the registry dir has no `.server` or `.pending` entry
    - the stub opener log is empty
    - no process is listening on any port in the configured range
  - (b) **Subdirectory of a real worktree.** `--start <worktree>/sub` is refused the same way as (a).
  - (c) **No sweep kill.** A real worktree started with `--start` stays running after one unrelated `PostToolUse` payload (`ls`). This proves the start check and the sweep agree. It is the scenario from finding 1.
  - (d) **Hook path refuses silently.** A post-setup payload whose `WORKTREE:` names an existing non-git dir gives exit 0, empty stdout, and no registry entry.
  - (e) **Opener exits non-zero** (a stub that logs its argv and exits 1):
    - the start succeeds
    - the message says the browser was not opened
    - there is no `dev-server.opened` marker
    - a second start of the same worktree calls the stub **again** (two log lines)
  - (f) **Opener not found.** `CLAUDE_DEV_SERVER_BROWSER` names a command that does not exist: no marker, and the message says not opened.
  - (g) **Opener succeeds** (a stub that exits 0, and a stub that stays alive as `sleep`, killed in the trap): the marker is written, and a second start does not call the opener again. This keeps 2.3(a) intact.
  - (h) **No regressions.** Every earlier case in `tests/workflow-dev-server.test.sh` (2.1–2.5) still passes.
- **Test approach:**
  - Oracle: new contract tests, plus the existing suite.
  - Same harness as 2.1–2.5: hermetic `HOME`/`XDG_STATE_HOME`, random high port base, stub openers, kill by recorded pgid/pid.
  - While iterating, the builder runs only `tests/workflow-dev-server.test.sh`.
  - 4.2 re-runs the full suite after this subphase merges (its `after:` now includes 2.6).

## Phase 3: Payload docs

### 3.1 — hooks/README.md section and agent-agnostic/AGENTS.md entry
- **File scope:** `agent-agnostic/hooks/README.md`, `agent-agnostic/AGENTS.md`.
- **Pattern to follow:**
  - In `agent-agnostic/hooks/README.md`: the `worktree-reminder.sh` section (a heading, what it does, and a JSON wiring snippet).
  - In `agent-agnostic/AGENTS.md`: the "Wired" paragraph of `## hooks/`, which gives each hook a parenthetical with its event, matcher and scope.
- **Acceptance:**
  - The README gains a `### workflow-dev-server.sh` section. It covers:
    - both events
    - the config keys table from this plan's Design section, with examples explicitly labelled as examples
    - the inert-when-unset guarantee
    - the registry location
    - the pid-reuse guard
    - the CLI modes
    - a pointer to `docs/workflow-dev-server.md`
  - AGENTS.md's Wired list gains one parenthetical entry: `PreToolUse` and `PostToolUse` on `Bash`, unscoped, inert without `CLAUDE_DEV_SERVER_CMD`.
  - Neither file names `pnpm`, `vite` or SvelteKit as a default.
- **Test approach:** Oracle: existing suite. This is docs only: review against the Design table, and `grep -n workflow-dev-server` must hit in both files.

## Phase 4: Integration

### 4.1 — Wire the hook in settings.json and pin it in the registration test
- **File scope:** `agent-specific/claude/settings.json`, `tests/hook-registrations.test.sh`.
- **Pattern to follow:** the existing `PreToolUse`/`Bash` and `PostToolUse`/`Bash` groups (`settings.json:127-164,207-216`), and the test's `TABLE`, `COUNTS` and `unscoped` sections (`hook-registrations.test.sh:26-51,127-147`).
- **Changes:**
  - Append `{"type":"command","command":"~/.claude/hooks/workflow-dev-server.sh --hook-pre-remove","timeout":30}` to the `PreToolUse`/`Bash` group.
  - Append `{"type":"command","command":"~/.claude/hooks/workflow-dev-server.sh","timeout":90}` to the `PostToolUse`/`Bash` group.
  - Neither entry has an `if` or a `|| true` wrapper.
  - In the test:
    - add two `TABLE` rows
    - set `COUNTS` to `PRE_BASH` 7 and `POST_BASH` 2
    - add two `unscoped` lines
    - leave the section 7 `if` inventory unchanged
- **Acceptance:**
  - `bash tests/hook-registrations.test.sh` has 0 failures, including section 8.
  - `jq . agent-specific/claude/settings.json` parses.
  - `git diff` of `settings.json` shows only the two added objects.
- **Test approach:** Oracle: existing suite, with the registration contract extended in place.

### 4.2 — Full suite and hook-level end-to-end check
- **File scope:** none. Evidence goes in the exit report.
- **Pattern to follow:** "P5 — The suite is green" (`docs/reports/last-5-plans-landed-09-01-26.md:99`): `for t in tests/*.test.sh; do bash "$t"; done`.
- **Acceptance:**
  - (a) Every `tests/*.test.sh` passes on the parent branch after both lanes merge.
  - (b) **Hook-level end to end, not a live Claude Code session.**
    - Set up a scratch `HOME`. Run `sync-install.sh --full --home <scratch>/.claude` from a scratch clone of this branch, since the script refuses linked worktrees and non-`main` branches (`sync-install.sh:105-107`). Use a local `main` branch in the clone.
    - Read the two `workflow-dev-server.sh` `command` strings from the **synced** `<scratch>/.claude/settings.json` with jq. Run each one exactly as written, with `~` expanded to the scratch home.
    - Feed them payloads shaped like Claude Code's: a `PostToolUse` carrying `workflow-setup.sh --type feature --name e2e`'s real stdout, then a `PreToolUse` for `git -C <repo> worktree remove <wt>`.
    - The scratch repo has `env.CLAUDE_DEV_SERVER_CMD` = the python fake server, and the stub opener.
    - Assert the server is up after the setup payload and its group is dead after the remove payload.
    - Repeat with an unconfigured scratch repo: no server and no hook output.
    - **Coverage limit:** this proves the installed script and the exact wired command lines. It does not prove that Claude Code dispatches `Bash` events to those entries. That part is covered only by 4.1's registration contract and by the precedent that the same matcher groups already work for the existing hooks.
  - (c) `sync-install.sh --check --home <scratch>/.claude` is clean after that sync.
- **Test approach:** Oracle: existing suite plus the hook-level e2e above.

## Phase 5: Record

### 5.1 — docs root page, map row, pipeline bullet, known-issues entries
- **File scope:** `docs/workflow-dev-server.md` (new), `docs/README.md` (Map row), `docs/pipeline.md` ("Hooks & scripts" bullet; one clause about `resolve-config.sh` now parsing the env block string-aware), `docs/known-issues.md` (new entries).
- **Who:** `documenter`, via `document-local`, at Record. Builders are denied the docs root (`scope-writes.sh:311-319`).
- **Pattern to follow:**
  - `doc-format`: one page per topic, kebab-case.
  - `docs/README.md` Map table.
  - The `docs/pipeline.md:177-260` bullets.
  - The known-issues shape (Limitation / Source / Status, `docs/known-issues.md:9-10`).
- **Acceptance:**
  - The page covers:
    - the lifecycle (setup → queue → start → tab → remove → sweep)
    - each config key
    - D5 and the pid-reuse guard
    - why there is no `if`
    - why `workflow-setup.sh:237` needs nothing
  - It also carries the rationale cut from code comments.
  - Known-issues entries cover four limits:
    - Paths with spaces in a removal command are left to the sweep.
    - `\uXXXX` escapes in config values are passed through verbatim.
    - `setsid`, `ps -o lstart` and the `lsof` cwd fallback are unverified on macOS.
    - `PostToolUse` does not fire after a failing Bash command, so the sweep acts on the next successful call (A3).
- **Test approach:** Oracle: existing suite. Docs only, checked by review.

## Risks, open questions, decision points

**Risks and follow-ups**
- **R1 — mythic-made coexistence until its follow-up run.** After this ships and syncs, mythic-made has both hooks wired: its project copy, and this one globally.
  - **Start:** the generic start stays inert there until mythic-made adds `CLAUDE_DEV_SERVER_CMD`.
  - **Stop:** the generic stop needs no config (D5). It reads the same `.artifacts/dev-server.pid` name and accepts mythic-made's one-line pid files, under the cwd guard (ii). mythic-made's start runs with cwd = the worktree (`:271-276`), so the guard passes for a genuine server. That means the change **fixes mythic-made's `git -C` orphaning as soon as it syncs**, without risking a reused pid.
  - **F1, a separate run in the mythic-made repo:**
    - Delete `.claude/hooks/workflow-dev-server.sh` and its two `settings.json` entries.
    - Add the env config. Illustrative values: `CLAUDE_DEV_SERVER_CMD` = `pnpm --filter website dev --port {port} --strictPort`, and `CLAUDE_DEV_SERVER_READY_PATHS` = `node_modules apps/website/node_modules`.
    - Trim `.agent/rules/workflow-dev-server.md` to its project-specific residue.
    - F1 must do the deletion and the config in **one commit**. Otherwise both hooks race to start a server.
- **R2 — A pre-remove stop happens even if the remove is then denied at the permission prompt.** The server can be restarted with `--start`. Accepted.
- **R3 — The sweep is global**, so it stops orphans from any repo. That is intended: entries exist only for servers this hook started.
- **R4 — `resolve-config.sh` is shared by every config-reading hook.** A parser regression would break `scope-writes.sh`, `workflow-setup.sh` and others at once. Mitigations:
  - 1.1(g) runs every existing case.
  - 1.1(h) parses the real `settings.json`.
  - The lane exit runs all five other suites that call it.
- **F2 — Antigravity wiring:** follow-up (see Out of scope).

**Assumptions not verified** (the review gate should challenge these)
- **A1.** `PostToolUse` Bash payloads carry `cwd` and the command's stdout as raw text containing `WORKTREE: …\n`. Gate round 1 found this supported by `parent-tree-guard.sh:106`, `lane-bind-on-launch.sh:30` and mythic-made's working parser. It was not re-probed live.
- **A2.** `ps -o lstart= -p`, `setsid` and `lsof -a -p <pid> -d cwd -Fn` behave the same on macOS. Verified only on this Linux host.
- **A3.** `PostToolUse` does not fire for a failing Bash command; `PostToolUseFailure` is a separate event (`docs/reports/last-5-plans-landed-09-01-26.md:282`, per gate round 1).

**Decision points:** none open. All of DP-1 to DP-5 and the `{port}` decision were settled at gate round 1. See "Decided at the plan gate". At gate round 2 (11-21-26), the user confirmed the awk parser over jq (D0) and approved the plan.

## Skill mapping

| Work | Skill / agent |
|---|---|
| 1.1 (resolver fix + its regression cases), lane 1 first | `builder` → `coder` (`resolve-config.sh`) + `contract-tester` (new case sets, from 1.1's criteria alone) |
| Phase 2 (hook + its contract tests), lane 1 after 1.1 | `builder` → `coder` (hook) + `contract-tester` (`tests/workflow-dev-server.test.sh`) |
| Phase 3 (payload docs), lane 2 | `builder` |
| 4.1 (shared touchpoint), serialized after lane 1 | `builder`, single-subphase dispatch on the parent |
| 4.2 (verification) | `builder` e2e tail on the parent after all merges |
| Phase 5 (docs root) | `documenter` → `document-local` at Record |
| Gates | `review-plan`, `review-code`, `review-pr` |

**Lanes:** 2 concurrent lanes with disjoint file scopes.
- **Lane 1** owns `agent-agnostic/hooks/resolve-config.sh`, `tests/resolve-config-precedence.test.sh`, `agent-agnostic/hooks/workflow-dev-server.sh` and `tests/workflow-dev-server.test.sh`. It runs the resolver fix (1.1) **first**, because 2.1(c) needs `{port}` and later keys to resolve. Keeping the fix and the hook in one lane means the dependency holds inside the lane's own child worktree, with no cross-lane merge wait.
- **Lane 2** owns `agent-agnostic/hooks/README.md` and `agent-agnostic/AGENTS.md`.
- **Serialized:** `settings.json` and its registration test are the shared touchpoint, hoisted into 4.1.
