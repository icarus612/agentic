# hook-timeouts-and-if-scoping: explicit timeouts and `if` narrowing on the tool-use and Stop hooks

### Ask of record (source: /tmp/claude-1000/-home-icarus64-repos-money-makers-mythic-made/1fd39a8a-64fb-4758-aaa6-5e08ac3a6d7f/scratchpad/ask-of-record-hook-timeouts.md)

**11-05-26** — in th eagentic hooks pree/post tool use and stop hooks add timouts, and if statements to narrow the scope of its size

## Phase syllabus
- [ ] Phase 1: Prove `if` semantics on the installed Claude Code
  - [x] 1.1: Scratch-project probe of the candidate `if` rules
- [ ] Phase 2: Registration changes
  - [x] 2.1: Explicit `timeout` on every PreToolUse, PostToolUse and Stop handler
  - [x] 2.2: `if` narrowing per the decision table, gated on the probe   (after: 1.1, 2.1)
- [ ] Phase 3: Verify and record
  - [x] 3.1: Whole suite, JSON validity, live replay of the final hooks block   (after: 2.2)
  - [x] 3.2: Docs-root pages and changelog at Record   (after: 3.1)

Serial, one lane. Every product change lands in one file (`agent-specific/claude/settings.json`), plus one new test file and one-line header notes in the four narrowed scripts. The `if` decisions in 2.2 depend on what the probe in 1.1 finds. Nothing here is separable without two lanes touching the same JSON file.

## Goal & scope

The user wants the agentic repo's PreToolUse, PostToolUse and Stop hook registrations to get explicit `timeout` values. They also want `if` conditions on those registrations, so that fewer hook processes start on each tool call.

**In scope**
- `agent-specific/claude/settings.json`, the `hooks.PreToolUse`, `hooks.PostToolUse` and `hooks.Stop` arrays: 16 handler entries today (settings.json:127-228). PreToolUse has 6 on Bash and 2 on the write tools; PostToolUse has 3 on the write tools, 1 on Bash and 1 on Agent; Stop has 3.
  - Every handler gets an explicit `timeout`, sized from what its script actually does (table T below).
  - Each handler gets an `if` only when the decision table (table D below) shows that the filter is exactly as wide as the script's own trigger set, or wider. **Narrowing must never weaken a guard.**
- A new registration contract test, `tests/hook-registrations.test.sh`. It locks the timeouts and `if` sets, and it checks each narrowed `if` set against its script's trigger set.
- One-line SYNOPSIS notes in each narrowed script, naming the `if` filter it is wired under. This follows the precedent at `allow-workflow-cleanup.sh:5-7`.
- Record: docs and changelog.

**Out of scope, with evidence**
- **`SessionStart` hooks** (settings.json:112-126). The ask names only "pree/post tool use and stop hooks". They stay unchanged.
- **`.claude/settings.json`** (project-scoped). It holds only `{"env":{"CLAUDE_BASE_BRANCH":"main"}}` and has no `hooks` key (read 11-05-26). There is nothing to change.
- **`agent-specific/antigravity/hooks.json`.** Nothing in this repo or its history documents `timeout` or `if` as Antigravity hook fields. Checked: `grep -rniE 'timeout|"if"'` over `agent-specific/antigravity/` and `docs/`, plus the two Antigravity plans in `project-plans/completed/`, finds only an unrelated clean-code rule. The adapter contract (`agy-hook-adapter.sh:1-40`) also shows a different payload shape and different tool names (`run_command`, `write_to_file`). An `if` written in Claude permission-rule syntax such as `Bash(...)` would therefore be meaningless there. Adding fields an engine does not document risks breaking its schema for no benefit. It stays out, and DP-5 tracks a possible follow-up.
- **`onFailure: "block"`** (make a guard fail closed on timeout or crash). The ask does not request it. It changes failure semantics rather than scope or size, so it is recorded as DP-4 and not built.
- **`if` on the Bash guards** `no-attribution-guard.sh`, `pr-ready-hygiene-guard.sh` and `branch-squash-guard.sh` (table D rows 1, 2 and 4). The human gate decided these get timeouts only; see DP-1.
- **Changes to how any hook script behaves.** Only comments change in scripts: one SYNOPSIS line each, and only in the scripts narrowed in 2.2.

**Installed copy.** `~/.claude/settings.json` gets the change through `sync-install.sh`. Its `merge_settings` (sync-install.sh:157-197) recurses into dicts and lets the source win on lists. `hooks.PreToolUse`, `hooks.PostToolUse` and `hooks.Stop` are lists, so the repo's arrays replace the installed ones wholesale. `push-main` step 7 (`.claude/skills/push-main/SKILL.md:52`) runs `sync-install.sh <old>..HEAD` after landing. No separate install subphase is needed. On 11-05-26, `jq -S .hooks` showed the installed hooks block identical to both `main` and this worktree, so there is no pre-existing drift to reconcile.

## Verified Claude Code semantics (load-bearing)

Source: https://code.claude.com/docs/en/hooks.md and https://code.claude.com/docs/en/permissions.md, fetched raw with `curl` on 11-05-26. Line numbers refer to those fetched files. Installed version: `claude --version` → `2.1.317 (Claude Code)`.

- **`timeout`** is in seconds. Defaults are 600 for `command` hooks, 30 on `UserPromptSubmit`/`PreModelSwitch`/`PostModelSwitch`, and 10 on `MessageDisplay`. Stop and the tool events are not lowered, so **today every hook in scope effectively has a 600s timeout** (hooks.md:414). No maximum is documented.
- **On expiry**, Claude Code "cancels a `command` … hook that reaches its `timeout`, discarding the hook's output, so on most events a timed-out hook renders no decision" (hooks.md:877). On PreToolUse, "a timed-out `command` … hook doesn't block the tool call … so don't count on a stalled hook to act as a gate. To block the call … set `onFailure: "block"`" (hooks.md:879). The docs do not name the kill signal.
- **`onFailure`** requires v2.1.295 or later (hooks.md:447). It has **no effect on Stop hooks** (hooks.md, section "Block the action when a hook fails").
- **`if`**: "Only evaluated on tool events: `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, and `PermissionDenied`. **On other events, a hook with `if` set never runs**" (hooks.md:413). **Consequence: no Stop handler may carry `if`, or it silently stops running.**
- **One rule per `if`.** "There is no `&&`, `||`, or list syntax … define a separate hook handler for each" (hooks.md:418).
- **How Bash `if` matching works** (hooks.md:422-434):
  - It checks each subcommand of a compound command.
  - It strips leading `VAR=value`.
  - It checks the commands inside `$()` and backticks.
  - "When Claude Code can't determine which commands the Bash input runs, it runs your hook regardless of the pattern. Because the `if` filter is best-effort, use the permission system rather than a hook to enforce a hard allow or deny."
- **Wrappers** stripped before Bash matching: `timeout`, `time`, `nice`, `nohup`, `stdbuf`, `command`, `builtin`, `noglob`, and flagless `xargs`. **`sudo` and `env` are not stripped** (permissions.md:229-233). A trailing ` *` also matches the bare command (permissions.md:184).
- **Path patterns** use gitignore syntax with anchors (permissions.md:364-375):
  - `//path` is absolute.
  - `~/path` is home-relative.
  - `/path` is relative to the settings source.
  - A bare relative pattern matches only at or under the current directory (permissions.md:404-412).
  - **Consequence:** a relative `Edit(**/*.ts)` would miss edits to files outside the session cwd. Any extension filter must use `//**/*.ext`.
- **`Edit` vs other tools.** "`Edit` rules apply to all built-in tools that edit files" (permissions.md:341), but hooks.md:119 says "A single `if` rule matches only one tool's calls". **Whether `Edit(...)` in an `if` also matches Write and MultiEdit calls is UNVERIFIED.** The probe in 1.1 settles it.
- **`Agent(name)`** matches the subagent of that name (permissions.md:591-595). Whether it does so inside an `if` on PostToolUse is unverified; the probe settles it.
- **Parallelism and dedup.** Matching hooks run in parallel (hooks.md:398). The same handler defined in more than one settings file runs once (hooks.md:400). Dedup within one file is not documented; the probe measures it.

## Stack & MAJOR versions

- Bash, python3, jq: the hook scripts' own runtime. This repo has no package manifest; it is a library of shell, markdown and JSON. The tool set was verified from the scripts' shebangs and their `command -v` guards (for example `claude-install-drift.sh:47`).
- Claude Code **2.1.317**, from `claude --version` on 11-05-26. This version is at least v2.1.295, so `onFailure` is available should DP-4 choose it. The docs state no minimum version for `if` or `timeout`, and the existing `if` entries (settings.json:142,147) already work on the installed version.
- The test harness is plain `bash tests/<name>.test.sh` with PASS/FAIL counters. Pattern: `tests/sync-install-settings-merge.test.sh:1-40`.

## Conventions to enforce

- Repo AGENTS.md: hooks are "deterministic mechanical enforcement". Global hooks wire through `settings.json`, and the repo copy is the versioned source of `~/.claude/settings.json`, merged rather than copied (AGENTS.md index; sync-install.sh:22-41).
- **Narrowing never weakens a guard.** An `if` is allowed only when it is exactly as wide as, or wider than, the set of inputs on which the script can act (deny, allow, bind, or report). When in doubt, leave it unscoped.
- **No `if` on any Stop handler** (hooks.md:413).
- **Path `if` patterns use the `//` or `~/` anchor**, never a bare relative pattern (permissions.md:404-412).
- `minimal-code-comments`: each script gets at most one SYNOPSIS line. No banners.
- Shell discipline: one command per Bash call, `git -C` instead of `cd && git`, and stage only named paths.
- No attribution trailers of any kind in any commit: no `Co-Authored-By`, no `Claude-Session`, no session URL.
- Builders never push. This repo lands through the repo-local `push-main` skill (`.claude/skills/push-main/`), not `push-pr`.
- Docs and changelog belong to Record (`documenter`). Builders are denied `docs/` and the plans dir by `scope-writes.sh`.

## Decision tables

### Table D: per-hook `if` decision

"Trigger set" means the inputs on which the script can do anything other than a silent `exit 0`. "Probe-gated" means the row ships only if the named 1.1 checks pass; otherwise the row falls back to **unscoped**.

| # | Event / matcher | Hook | Script trigger set (evidence) | Decision | `if` handler(s) | Probe-gated on |
|---|---|---|---|---|---|---|
| 1 | Pre / Bash | `no-attribution-guard.sh` | A `git commit\|tag\|notes\|merge\|revert\|cherry-pick` or `gh pr\|issue\|release <create\|edit\|comment\|review\|ready\|close\|reopen>` in command position, optionally after `sudo`, matched against the raw text (no-attribution-guard.sh:31-37). Every hit's text contains `git` or `gh`. | **Unscoped (DP-1 decided)** | none | — |
| 2 | Pre / Bash | `pr-ready-hygiene-guard.sh` | `gh\s+pr\s+ready` in command position (pr-ready-hygiene-guard.sh:24). Every real invocation's subcommand text contains `gh`, then `ready`. | **Unscoped (DP-1 decided)** | none | — |
| 3 | Pre / Bash | `allow-workflow-cleanup.sh` (×2) | Already narrowed, and the script refuses chained input (allow-workflow-cleanup.sh:66-68). | **Keep existing** | `Bash(git branch:*)`, `Bash(git worktree remove:*)` | none |
| 4 | Pre / Bash | `branch-squash-guard.sh` | Every deny branch requires a segment whose first token is `git` or `gh`. Segments come from the script's own plain-text split on `&&`, `||`, `;` and `|`, so a `;`-split segment inside a quoted `bash -c '…; git push'` body is checked. `sh -c "git …"` as a single segment is not, because its `toks[0]` is `sh` (branch-squash-guard.sh:302-438). The `cd`/`pushd` handling only re-resolves context and never denies. | **Unscoped (DP-1 decided)** | none | — |
| 5 | Pre / Bash | `lane-artifact-shell-guard.sh` | Any write whose destination resolves to a lane artifact. Relative destinations are resolved through the payload `cwd` and a tracked `cd` (lane-artifact-shell-guard.sh:56-76), so the command text need not contain `.artifacts`, `contracts` or `lanes`. `lanes/.+` is any filename. Permission rules have only `*` and no character classes. | **Unscoped** | none | — |
| 6 | Pre / Write\|Edit\|MultiEdit\|NotebookEdit | `branch-squash-guard.sh` | Any write target whose repo HEAD is the integration branch (branch-squash-guard.sh:176-196). The answer depends on git state, not on the path's shape. | **Unscoped** | none | — |
| 7 | Pre / Write\|Edit\|MultiEdit\|NotebookEdit | `scope-writes.sh` | Any path with a run marker among its ancestors (scope-writes.sh:8-22). This cannot be expressed as a path rule. | **Unscoped** | none | — |
| 8 | Post / Write\|Edit\|MultiEdit | `smart-lint.sh` | Hook mode exits early unless the extension is one of `py go js jsx ts tsx rs nix svelte vue mjs cjs` (`target_lintable_ext`, smart-lint.sh; dispatch at `main()` :1012-1025). | **Narrow** | `Edit(//**/*.<ext>)` for each of the 12 extensions | P5, P6 |
| 9 | Post / Write\|Edit\|MultiEdit | `smart-test.sh` | It runs only when the path matches `\.go$`, `\.py$` or `\.[jt]sx?$`, which is `go py js jsx ts tsx`. Anything else gets "No applicable tests" and `exit 0` (smart-test.sh:897-912). | **Narrow** | `Edit(//**/*.<ext>)` for each of the 6 extensions | P5, P6 |
| 10 | Post / Write\|Edit\|MultiEdit | `claude-install-drift.sh` | It acts only on `$CLAUDE_HOME/{hooks,rules,skills,agents}/*` or `$AGENTIC_REPO/agent-agnostic/*` (claude-install-drift.sh:69-131). The defaults are `~/.claude` and `~/repos/agentic`. It is advisory and always exits 0. | **Narrow** | `Edit(~/.claude/hooks/**)`, `Edit(~/.claude/rules/**)`, `Edit(~/.claude/skills/**)`, `Edit(~/.claude/agents/**)`, `Edit(~/repos/agentic/agent-agnostic/**)` | P5, P7 |
| 11 | Post / Bash | `parent-tree-guard.sh` | It inspects the parent worktree's `git status` after **any** Bash call (parent-tree-guard.sh:9-18). The command text cannot predict what changed. | **Unscoped** | none | — |
| 12 | Post / Agent | `lane-bind-on-launch.sh` | It exits unless `tool_input.subagent_type == "builder"` (lane-bind-on-launch.sh:18-21). | **Narrow** | `Agent(builder)` | P8 (PreToolUse), then 3.1(e) (PostToolUse, the shipped event) |
| 13–15 | Stop | `ntfy-notifier.sh`, `parent-tree-guard.sh`, `workflow-diff-check.sh` | — | **No `if` (forbidden)**: on Stop, an `if` makes the hook never run (hooks.md:413). | none | — |

Notes on table D:
- **Rows 1, 2 and 4 are unscoped by decision (DP-1).** Substring `if` rules that are at least as wide as these scripts' raw-text triggers would be possible today. The human gate rejected them because a hand-copied filter can silently drift narrower than the script as the script evolves, nothing would detect that, and the saving is small.
- **Row 10's override caveat.** If `AGENTIC_REPO` or `CLAUDE_HOME` is overridden in the process env, the `if` paths stop matching and the advisory goes quiet. Neither variable is set in `~/.claude/settings.json` (`jq .env` → `null`, 11-05-26). The hook is advisory, so this is acceptable. Record documents it in known-issues.
- **Fallback when P5 fails** (`Edit(...)` does not match Write or MultiEdit calls). Rows 8, 9 and 10 stay **unscoped**. This was decided at the gate (DP-2). One handler per tool per pattern was rejected.

### Table T: per-hook `timeout` (seconds)

| Hook (event) | Timeout | Sizing evidence | What expiry does (hooks.md:877-879) | Acceptable? |
|---|---|---|---|---|
| `no-attribution-guard.sh` (Pre Bash) | 30 | One python3 regex pass. | Output discarded, so the tool call proceeds: **fail-open**. | Yes. This is the same failure class as today's 600s default, with a shorter hang. A hang this long means python3 is broken. DP-4 offers fail-closed. |
| `pr-ready-hygiene-guard.sh` (Pre Bash) | 120 | grep, then for `gh pr ready` only, `check-diff-hygiene.sh --base` over the branch diff (pr-ready-hygiene-guard.sh:26-35). | Fail-open: the flip proceeds. | Yes, as above. Large branch diffs justify the headroom. |
| `allow-workflow-cleanup.sh` ×2 (Pre Bash) | 30 | `git worktree list` plus `resolve-config.sh`. | No allow decision, so the normal permission prompt appears. | Yes, and harmless. |
| `branch-squash-guard.sh` (Pre Bash, Pre Write…) | 30 | A few `git rev-parse` calls plus two `resolve-config.sh` calls (branch-squash-guard.sh:125-140). | Fail-open. The settings.json deny list still blocks force-push (settings.json:74-76). | Yes. |
| `lane-artifact-shell-guard.sh` (Pre Bash) | 30 | One python3 tokenizer pass. | Fail-open. | Yes. The parent-tree-guard backstop does not cover this case (run-dir files are gitignored), so DP-4 matters most here. |
| `scope-writes.sh` (Pre Write…) | 30 | Ancestor marker walk plus root resolution. | Fail-open. | Yes. DP-4 applies. |
| `smart-lint.sh` (Post Write…) | 300 | Single-file prettier/eslint/ruff. golangci-lint has its own `--timeout=2m` (smart-lint.sh:406,453). `cargo clippy` on a cold crate is the long tail (:751,794). | Lint feedback for that edit is lost. Nothing blocks. | Recommended. DP-3 covers it, because 300 is below today's 600 default. |
| `smart-test.sh` (Post Write…) | **660** | Per-run watchdog `CLAUDE_HOOKS_TEST_TIMEOUT` (default 300) plus `CLAUDE_HOOKS_TEST_KILL_GRACE` (default 3) (smart-test.sh:119-120,304-372). It does one `run_contained` per mode, and the default modes are `focused,package` (smart-test.sh:116,433,598,814): **at most 2 sequential runs, so 2 × 303 = 606s worst case before overhead.** The hook timeout must exceed modes × (TIMEOUT + GRACE). 660 leaves 54s of overhead. | Test feedback is lost. The kill signal is undocumented. smart-test traps TERM, INT and HUP (smart-test.sh:334-337), but a SIGKILL from the harness would orphan the contained process group. | **Required.** Today's 600s default is already below the 606s worst case, so the harness can kill smart-test before its own watchdog finishes. Record documents the coupling formula. |
| `claude-install-drift.sh` (Post Write…) | 30 | jq plus one `diff -q`. | Advisory lost. | Yes. |
| `parent-tree-guard.sh` (Post Bash) | 60 | `git status --porcelain -uall` on the parent worktree (parent-tree-guard.sh:255). `-uall` walks untracked trees. | That call's denial is lost. The Stop pass re-checks. | Yes, as defense in depth through Stop. |
| `lane-bind-on-launch.sh` (Post Agent) | 30 | One python3 pass plus `lane-bind.sh`. | The binding is not recorded and its exit-2 message is lost. The builder's own contract write is then denied by `scope-writes.sh`, so the failure is loud and fails closed downstream. | Yes. |
| `ntfy-notifier.sh notification` (Stop) | 30 | `curl --max-time 5` × 2 retries + `sleep 1` (ntfy-notifier.sh:167-185), plus terminal-title probes. | Notification lost. | Yes. |
| `parent-tree-guard.sh` (Stop) | 60 | Same as the Post Bash row. | Fail-open: the stop proceeds. `onFailure` has no effect on Stop. | Yes, and unchanged in class from today. |
| `workflow-diff-check.sh` (Stop) | 600 | Runs `vitest related`, `go test` and `pytest` sequentially over the branch's changed files, with no internal bound (workflow-diff-check.sh:93-175). | Fail-open: the stop proceeds with no test gate. | Recommended. This keeps today's effective default but makes it explicit. DP-3 covers it. |

## Phase 1: Prove `if` semantics on the installed Claude Code

### 1.1 — Scratch-project probe of the candidate `if` rules

- **File scope:** none in the repo. All probe material goes in a `mktemp -d` scratch directory outside the repo (a throwaway git repo plus `.claude/settings.json`), deleted afterwards. **Findings are recorded as per-criterion evidence in the lane's exit report.** Nothing is committed.
- **Pattern:** the hooks.md:922-939 test recipe. A PreToolUse hook that logs and then exits 2 blocks the call, so nothing the probe "runs" has side effects.
- **Method:**
  - In the scratch project's `.claude/settings.json`, register:
    - (a) a positive-control logger with **no** `if` on each matcher. This proves every call reached hooks.
    - (b) one logger per candidate `if` rule from table D rows 8, 9, 10 and 12, each appending `<rule-id>\t<raw command or file_path or subagent_type>` to a log file. Every PreToolUse logger exits 2 to block.
  - Run `claude -p --setting-sources project --debug-file <scratch>/debug.log` from the scratch dir, with the user's hooks excluded. Ask it to make exactly the listed tool calls, one at a time.
  - Judge only from the log and debug file, never from the model's reply (`verify-dont-assume`).
- **Probe hazards the contract must handle.** Each one would otherwise show up as a missing control line and read as a false FAIL.
  - **Unread-file validation.** Claude Code may reject a Write over an existing unread file, or an Edit of an unread file, during tool validation and before PreToolUse runs. Use a fresh path for every Write. For every Edit or MultiEdit, Read the file first in the same session.
  - **`builder` agent type.** `~/.claude/agents/builder.md` is a user-scope agent, and `--setting-sources project` probably hides it, so `subagent_type: "builder"` could be invalid in the scratch project. Define a stub `builder` agent at `<scratch>/.claude/agents/builder.md` (name, description and a one-line body), plus a stub `Explore` agent if the built-in one is unavailable.
  - **Probe scope.** There are no Bash candidate rules. DP-1 removed rows 1, 2 and 4, so the former checks P1–P4 and P9 are gone. The remaining checks keep their original labels, P5–P8.
  - **Missing control line.** A check whose control line is missing counts as INCONCLUSIVE, not FAIL. Re-run it once. If it is still missing, the row falls back to unscoped.
- **Checks.** Each is PASS or FAIL against the logs. For each check, the evidence also records a positive control that does hit.
  - **P5:** `Edit(//**/*.ts)` fires for an **Edit**, a **Write** and (if the tool still exists) a **MultiEdit** to `<scratch>/a/b.ts`. It also fires for a Write to an absolute `.ts` path **outside** the session cwd (a second `mktemp -d`). It does not fire for a `.md` write.
  - **P6:** `Edit(//**/*.ts)` does **not** fire for `x.tsx`, and `Edit(//**/*.tsx)` does. In other words, extensions do not bleed into one another.
  - **P7:** `Edit(~/.claude/hooks/**)` fires for an edit to a scratch path under a fake HOME (`HOME=<scratch-home>` exported for the `claude` process) and does not fire for a sibling path.
  - **P8:** `Agent(builder)` fires for an Agent call with `subagent_type: "builder"` and does not fire for `subagent_type: "Explore"`. Probe this on **PreToolUse** with exit 2 to block the launch. The shipped hook is **PostToolUse**, so P8 alone does not license row 12. Row 12 ships narrowed only if P8 passes **and** 3.1(e) then passes on PostToolUse. If 3.1(e) fails, the `impl-wrong` bounce to 2.2 reverts row 12 to unscoped.
- **Acceptance:** each of P5–P8 has a verdict with a log excerpt plus a positive control that hit. The exit report states for each row of table D whether it ships narrowed or falls back to unscoped, using the "Probe-gated on" column. If `claude -p` cannot be driven non-interactively in this environment (auth, trust, flags), return `needs-input` with the exact error and do not guess. 2.2 then ships with every probe-gated row unscoped.
- **Test oracle:** existing implementation. The installed Claude Code 2.1.317's observed behavior is the truth source, and the checks above are contracts derived from it.

## Phase 2: Registration changes

### 2.1 — Explicit `timeout` on every PreToolUse, PostToolUse and Stop handler

- **File scope:** `agent-specific/claude/settings.json` (the `hooks.PreToolUse`/`PostToolUse`/`Stop` arrays only, :127-228); `tests/hook-registrations.test.sh` (new).
- **Pattern:** the existing handler shape (settings.json:139-148). Add `"timeout": <int>` as a sibling of `command`. Leave `SessionStart` (:112-126) untouched.
- **Change:** set each handler's `timeout` to its table T value.
- **Acceptance (contract):**
  - `jq` parses the file.
  - Every object under `.hooks.PreToolUse[].hooks[]`, `.hooks.PostToolUse[].hooks[]` and `.hooks.Stop[].hooks[]` has an integer `timeout` equal to its table T value, keyed by `command`. The two `allow-workflow-cleanup.sh` entries both get 30.
  - smart-test's `timeout` is **>** 2 × (300 + 3). The test derives 300 and 3 by grepping the defaults out of `smart-test.sh` (`CLAUDE_HOOKS_TEST_TIMEOUT:-300`, `CLAUDE_HOOKS_TEST_KILL_GRACE:-3`, and the `focused,package` modes default). The grep has a positive control, and the test fails loudly if any of the three defaults can't be found. The inequality then holds automatically if someone later raises a default.
  - The committed test pins **durable contracts only**: the timeout table, `if` sets, no `if` on Stop, extension parity and anchors. It never compares against `main` or any other ref, because those comparisons stop holding once the branch lands. The change-relative checks (`SessionStart` unchanged, non-hook keys unchanged, per-script numstat) are one-off 3.1 checks against the pinned pre-change SHA `4dca934`.
- **Test approach:** create `tests/hook-registrations.test.sh` in the `tests/sync-install-settings-merge.test.sh` style (`ok`/`bad`/`check`, a `N passed, M failed` line, exit 1 on any failure). It reads only `REPO_ROOT/agent-specific/claude/settings.json` (with `jq`) and the hook scripts under `REPO_ROOT/agent-agnostic/hooks/`, with no git refs. Write it red first, against the pre-change file.
- **Test oracle:** new contract tests.

### 2.2 — `if` narrowing per the decision table, gated on the probe

> **Shipped differently:** the 1.1 probe on Claude Code 2.1.318 failed P5 (`Edit(...)` does not match Write) and P8 (`Agent(builder)` never matches a builder launch), so rows 8, 9, 10 and 12 fell back to unscoped per DP-2. No `if` was added and no script SYNOPSIS line was written; the shipped change is timeouts plus `tests/hook-registrations.test.sh`.

- **File scope:**
  - `agent-specific/claude/settings.json` (same arrays).
  - `tests/hook-registrations.test.sh` (extend).
  - One SYNOPSIS line in each **narrowed** script only: `smart-lint.sh`, `smart-test.sh`, `claude-install-drift.sh` and `lane-bind-on-launch.sh`, all in `agent-agnostic/hooks/`. `no-attribution-guard.sh`, `pr-ready-hygiene-guard.sh` and `branch-squash-guard.sh` are not touched (DP-1).
  - A script whose row fell back to unscoped is not touched.
- **Pattern:**
  - The duplicated-handler-per-rule shape already used for `allow-workflow-cleanup.sh` (settings.json:139-148): one handler object per `if` rule, the same `command`, and the 2.1 `timeout` on each copy.
  - Header note pattern: `allow-workflow-cleanup.sh:5-7`, in the form "wired … if-filtered to …; widen the filter when widening the trigger set". One line.
- **Change:** for every table D row whose probe checks all passed in 1.1, replace the single handler with one handler per listed rule. For every row that failed, or was never probe-gated as Narrow, leave one handler with no `if`.
- **Acceptance (contract):**
  - **Stop:** no handler has an `if` key.
  - **Unscoped rows:** each of these is exactly one handler, with no `if`:
    - `no-attribution-guard.sh`, `pr-ready-hygiene-guard.sh`, `branch-squash-guard.sh` and `lane-artifact-shell-guard.sh` under the PreToolUse `Bash` matcher;
    - `scope-writes.sh` and `branch-squash-guard.sh` under the `Write|Edit|MultiEdit|NotebookEdit` matcher;
    - `parent-tree-guard.sh` under PostToolUse `Bash` and under Stop.
  - **Narrowed rows:** for each shipped row, the set of `if` values for that `command` under that matcher equals the table D set exactly.
  - **Extension parity:**
    - For smart-lint, the test extracts the extension list from `target_lintable_ext` in `smart-lint.sh` and asserts it equals the set of `//**/*.<ext>` rules. The test fails if the function can't be found (positive control).
    - For smart-test, it asserts that `smart-test.sh` still contains the three `main()` dispatch regexes (`\.go$`, `\.py$`, `\.[jt]sx?$`) and that the rule set is `{go,py,js,jsx,ts,tsx}`.
  - **Path anchors:** every `Edit(...)` rule starts with `//` or `~/`. No bare relative patterns.
  - **Unchanged entries:** the `allow-workflow-cleanup.sh` `if` values are unchanged.
  - **Timeouts preserved:** every 2.1 timeout survives on every duplicated handler.
  - **Scripts:** `bash -n` passes on every touched script. This is a test assertion, and it is durable. The one-comment-line-per-script check is a one-off in 3.1, against `4dca934`.
- **Test approach:** extend `tests/hook-registrations.test.sh`. The probe-gated rows are table-driven from a small in-test map that names the expected `if` set or `none`. That map is filled from the 1.1 findings, so the test pins what actually shipped.
- **Test oracle:** new contract tests.

## Phase 3: Verify and record

### 3.1 — Whole suite, JSON validity, live replay of the final hooks block

- **File scope:** none. Read-only, plus a `mktemp -d` scratch directory.
- **Steps:**
  - `jq . agent-specific/claude/settings.json`.
  - `bash -n` on every touched script.
  - Run every `tests/*.test.sh` with one `bash tests/<x>.test.sh` call per file, asserting on each `N passed, M failed` line with M = 0.
  - **One-off change-relative checks against the pinned pre-change SHA `4dca934`.** These are deliberately not in the committed test. Record their output in the exit report.
    - `jq -S .hooks.SessionStart`: the worktree file equals `git show 4dca934:agent-specific/claude/settings.json`.
    - `jq -S 'del(.hooks)'`: the worktree file equals `4dca934`, so `permissions` and the other keys are untouched.
    - `git diff --numstat 4dca934 -- <each touched script>`: shows `1 0` per script.
  - The timeout values themselves are verified by the contract test, not by the replay.
  - Live replay:
    - Build a scratch project whose `.claude/settings.json` hooks block is the final repo block, with `~/.claude/hooks/` rewritten to the **worktree's** `agent-agnostic/hooks/`.
    - Wrap every replayed `command` in a **logging shim**: a tiny script that first buffers all of stdin (for example `payload=$(cat)`), then appends `<hook-name>\t<event>\t<tool_name>` to `<scratch>/replay.log`, then passes the buffered payload through to the real worktree script on its stdin (`printf '%s' "$payload" | <real-hook> "$@"`), and exits with the real hook's exit code. The payload is read once and handed on intact, so the hooks behave exactly as they would unwrapped. Leave each `if`, matcher and timeout exactly as shipped. The `--debug-file` format is unverified, so verdicts come from the shim log, which the hooks write themselves.
    - Use the 1.1 hazard handling: fresh paths, Read before Edit, and the stub `builder` agent in `<scratch>/.claude/agents/`.
    - Run `claude -p --setting-sources project` in a throwaway git repo on a non-integration branch.
    - Confirm, from `replay.log`:
      - (a) `ls` starts every unscoped PreToolUse Bash guard (`no-attribution-guard.sh`, `pr-ready-hygiene-guard.sh`, `branch-squash-guard.sh`, `lane-artifact-shell-guard.sh`) and PostToolUse `parent-tree-guard.sh`. It does not start `allow-workflow-cleanup.sh`.
      - (b) a `.md` Write starts no smart-lint, smart-test or drift process. It still starts `scope-writes.sh` and the write-tool `branch-squash-guard.sh`.
      - (c) a Write under the fake-HOME `~/.claude/hooks/` path starts `claude-install-drift.sh`.
      - (d) a `.ts` Write starts smart-lint and smart-test.
      - (e) an Agent call with `subagent_type: builder` starts `lane-bind-on-launch.sh` on PostToolUse. This confirms the P8 assumption.
      - (f) all three Stop hooks run at session end.
    - If any shipped narrowing fails the replay, it goes back to 2.2 as `impl-wrong`, with the row reverted to unscoped.
- **Acceptance:**
  - Every suite reports 0 failed.
  - Each replay item has a `replay.log` excerpt.
  - The three one-off `4dca934` checks are recorded.
  - A failing suite outside this plan's scope is compared against the pinned SHA `4dca934` before it is attributed to this run.
- **Test oracle:** existing suite.

### 3.2 — Docs-root pages and changelog at Record

- **Executed by:** `documenter` (`document-local`). Builders are denied `docs/`.
- **File scope:**
  - `docs/pipeline.md`:
    - The hooks paragraph (:180-240): state that every PreToolUse, PostToolUse and Stop handler carries an explicit timeout.
    - Name which hooks are `if`-narrowed and which stay unscoped by design (guards that must see every call).
    - Add the smart-test coupling rule: the hook `timeout` must exceed modes × (`CLAUDE_HOOKS_TEST_TIMEOUT` + `CLAUDE_HOOKS_TEST_KILL_GRACE`), so raising either default or adding modes requires raising the hook timeout. Place it next to the existing `CLAUDE_HOOKS_TEST_TIMEOUT` sentence at :207.
  - `docs/known-issues.md`: one new section covering four things:
    - (a) A PreToolUse guard that times out fails open (hooks.md:879). This is the same class as before, now bounded. DP-4 is the open follow-up.
    - (b) `if` is best-effort by Claude Code's own statement (hooks.md:434). The guards that must see every call are deliberately left unscoped.
    - (c) `claude-install-drift.sh`'s `if` paths assume the default `AGENTIC_REPO` and `CLAUDE_HOME`.
    - (d) The Bash guards are deliberately unfiltered (DP-1): a hand-copied `if` could drift narrower than the script without anything detecting it.
  - `agent-agnostic/hooks/README.md` is in the source tree, not the docs root. Update it only if it states a hook's wiring that is now false; it currently mentions wiring only at :80, for a `SessionStart` hook.
  - Changelog: through the commit message, per `document-local` step 6.
- **Acceptance:**
  - Every added statement matches the shipped `settings.json`, verified by `jq` against the file, not the exit report.
  - No page carries a now-false claim. Run `git grep -n 'timeout' docs/pipeline.md docs/known-issues.md`, with a positive control on the existing `CLAUDE_HOOKS_TEST_TIMEOUT` line.
- **Test oracle:** existing implementation.

## Risks, open questions, decision points

**Decision points (human gate)**
- **DP-1, DECIDED at the human gate: timeouts only on the Bash guards.** `no-attribution-guard.sh`, `pr-ready-hygiene-guard.sh` and `branch-squash-guard.sh` (rows 1, 2 and 4) get no `if`.
  - The user's concern, in their words: "Substring filters sounds like it would not scale well."
  - The reason accepted: a hand-copied filter can silently drift narrower than the script's trigger set as the script evolves, nothing would detect that, and the saving is small.
  - The options considered were substring rules (`Bash(*git*)` and the like), timeouts only, and prefix rules. Prefix rules were already rejected because they miss `sudo` forms.
- **DP-2, DECIDED: if P5 fails, leave the extension and path filters off.** If `Edit(...)` in an `if` does not match Write and MultiEdit, smart-lint, smart-test and `claude-install-drift.sh` stay unfiltered. Their scripts already exit early on the same filter. One handler per tool per pattern was rejected.
- **DP-3, DECIDED (accepted as written): timeouts on the long-running hooks.**
  - smart-lint at 300 (default today: 600) bounds the per-edit wait, at the cost of losing feedback on a cold `cargo clippy` that runs past 300s.
  - workflow-diff-check at 600 just makes today's default explicit.
  - Alternatives: smart-lint 600, or workflow-diff-check 900 for large Go or Python suites.
  - smart-test at 660 is **not** optional: anything at or below 606 lets the harness kill it before its own watchdog finishes.
- **DP-4 (out of scope, follow-up): `onFailure: "block"` on PreToolUse guards.** This covers `lane-artifact-shell-guard`, `scope-writes`, `branch-squash-guard`, `no-attribution-guard` and `pr-ready-hygiene-guard`. Today, and after this plan, a guard that times out or crashes lets the call through (hooks.md:879, 904). `onFailure: "block"` makes those cases fail closed. Under it, though, any exit code other than 0 or 2 also blocks (hooks.md, "Each of these counts as a failure"), including a stray bash error. That needs its own audit of every exit path. It has no effect on Stop.
- **DP-6, DECIDED (accepted as written): the parts of the ask that are deliberately declined.**
  - **`if` on Stop hooks is declined.** The ask names Stop hooks for both timeouts and `if` statements. hooks.md:413 says `if` is "Only evaluated on tool events: `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, and `PermissionDenied`. On other events, a hook with `if` set never runs." An `if` on any of the three Stop handlers (`ntfy-notifier.sh`, `parent-tree-guard.sh`, `workflow-diff-check.sh`) would therefore silently disable it. **Stop still gets the timeouts** (table T), so the Stop half of the ask is delivered for timeouts and declined for `if`. Recommended: accept the decline. The alternative is to attempt it anyway, which turns off the Stop test gate, the parent-tree backstop and the notifier.
  - **Rows 5, 6, 7 and 11 stay unscoped on safety grounds.** These are tool-event guards, where `if` would work mechanically, but each must see every call. Narrowing any of them would let some real offense through:
    - `lane-artifact-shell-guard.sh` resolves relative destinations through cwd and `cd` tracking, so the command text need not name the artifact.
    - The write-tool `branch-squash-guard.sh` judges by git state, not by the path's shape.
    - `scope-writes.sh` judges by a marker walk over ancestors, which no path rule can express.
    - The PostToolUse `parent-tree-guard.sh` inspects `git status` after any Bash call.
    - Recommended: accept. They still get explicit timeouts.
- **DP-5 (out of scope, follow-up): Antigravity.** If Antigravity documents a timeout field later, add it to `hooks.json` then. Claude permission-rule `if` will never apply there.

**Risks**
- **R1: `if` is best-effort** (hooks.md:434). The probe proves today's behavior on 2.1.317, but a Claude Code update could change parsing. Mitigation: the scripts' own filters stay in place (narrowing is additive, never a replacement), and the contract test pins the shipped rules. A future regression would make a guard fire **less** often, so `push-main`'s post-landing `sync-install --check` plus the 3.1 replay recipe (recorded in the exit report) are the re-check path.
- **R2: the harness kill signal is undocumented.** If it is SIGKILL, smart-test's TERM trap (smart-test.sh:334-337) never runs, and the contained process group can be orphaned. 660 makes that path reachable only if smart-test's own watchdog has already failed.
- **R3: the probe relies on `claude -p` making the exact tool calls requested.** Mitigation: verdicts come from the hook logs and debug file, never from the model's reply. A call that never happened shows up as a missing positive-control line, not as a silent PASS.
- **R5: sequencing against `project-plans/proposals/agent-identity-write-scope-09-26-26.md`.** That proposal is not yet approved, and its Phase 5 serialized integration also edits `agent-specific/claude/settings.json` (5.1, lines 642-650). Its lanes also edit hook scripts this plan touches with one comment line each, such as `smart-test.sh` (its 2.4). Whichever plan lands second must rebase onto the first plan's settings layout and re-run `tests/hook-registrations.test.sh`. If that plan adds or renames handlers, update this test's pinned map. Flagged to the orchestrator for sequencing. There is no clash within this plan, which is a single lane.
- **R4: MultiEdit may no longer exist** in 2.1.317. If P5 cannot produce a MultiEdit call, record that, keep `MultiEdit` in the matchers unchanged (harmless), and judge P5 on Edit and Write.

**Unverified assumptions (for the review gate)**
- U1: `if` on PostToolUse matches the same way as on PreToolUse. P5–P8 probe PreToolUse; 3.1(c), (d) and (e) check PostToolUse.
- U2: `--setting-sources project` keeps the user's `~/.claude/settings.json` hooks out of the probe. 1.1 confirms this from the debug log by checking that no `~/.claude/hooks/` command appears.
- U3: the hooks.md quotes reflect the docs as of 11-05-26 (raw `curl` of the `.md` source). The URLs are cited so the gate can re-fetch them.

## Skill mapping

- 1.1, 2.1, 2.2: one `builder` lane (lane 1, serial). Its `coder` handles the settings.json and header-note edits. A `contract-tester` writes `tests/hook-registrations.test.sh` from the 2.1/2.2 acceptance text. The builder itself runs 1.1, since the probe is investigation, not code.
- Gate: `review-plan`, then `review-code`.
- 3.1: the builder's own e2e phase, re-run by the orchestrator after merge-back.
- 3.2: `documenter` (`document-local`).
- Landing: the repo-local `push-main` skill, which also runs `sync-install.sh` (step 7) to carry the change into `~/.claude/settings.json`. No attribution trailers in any commit.
