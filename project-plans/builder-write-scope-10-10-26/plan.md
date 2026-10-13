# Builders write their own lane files with the Write tool, bound to their lane

### Ask of record

**10-10-26** — We need to fix this, they should be using read and write tools and not going around it like this

**10-10-26 — appended, clarification at setup** — Q: How should the hook confirm a builder is writing its *own* lane's contract/exit report? A: "Bind to lane" — the dispatcher records which builder belongs to which lane, so the hook verifies the exact lane (not just any builder writing any lane's file).

Context (orchestrator's summary of the defect the user is reacting to, not the user's words): during a treehouse-vineyards `/dae` feature run, builder lane l1 was denied by `scope-writes.sh` when it wrote its contract `<run-dir>/contracts/l1.md` with the Write tool. The hook's builder allowance (scope-writes.sh, the `agent_type = builder` block requiring `find_lane_root "$cwd"`) needs the hook-input `cwd` to be inside the lane's child worktree, but a Claude Code subagent's cwd is always its spawn directory (a `cd` in one Bash call does not persist into the next call or into hook input) — so the allowance is unreachable in practice. It went unnoticed because builders have been writing contracts and exit reports via Bash heredocs (`cat > ../<parent>/.artifacts/contracts/l<n>.md <<'EOF'`), which scope-writes.sh never sees. The user wants builders to use Read/Write tools and the shell route closed.

**10-11-26 — appended, plan gate, DP-1 switched to an automatic hook** — "Why not an auto hook for no. 3" / "yes"

## Phase syllabus

- [ ] Phase 1: Reproduce and measure
  - [x] 1.1: Regression cases 32–34 rewritten to the real payload shape, observed red
  - [x] 1.2: Live-capture the background `builder` launch's PostToolUse payload and the builder's Write `agent_id` — orchestrator, before dispatch
- [ ] Phase 2: Bind the lane-file allowance to a dispatcher-recorded agent
  - [x] 2.1: `lane-bind.sh`, the PostToolUse Agent hook that calls it, and its wiring   (after: 1.1, 1.2)
  - [x] 2.2: `scope-writes.sh` — allowance keyed on `agent_type` + bound `agent_id`, not `cwd`   (after: 2.1)
  - [x] 2.3: Contract cases — cross-lane, unbound, foreign agent, missing `agent_id`, none-mode untouched   (after: 2.2)
- [ ] Phase 3: Close the shell route
  - [x] 3.1: `lane-artifact-shell-guard.sh` and its suite   (after: 2.1)
  - [x] 3.2: Wire the guard into `agent-specific/claude/settings.json`   (after: 3.1)
- [ ] Phase 4: Agents and dispatcher use the tools at absolute paths
  - [x] 4.1: `builder.md` — Write tool at the handed paths, no `cd` assumption   (after: 2.2, 3.1)
  - [x] 4.2: `build-dispatch.md` — fixed `lane-id:`/`run-dir:` lines in every builder dispatch prompt   (after: 2.1)
  - [x] 4.3: `coder.md` / `contract-tester.md` — absolute paths only
  - [x] 4.4: `run-artifacts.md` — contract and exit report are tool writes   (after: 3.1)
- [ ] Phase 5: Verify
  - [x] 5.1: Whole suite, `bash -n`, shared-helper diff   (after: 2.3, 3.2, 4.1, 4.2, 4.3, 4.4)
  - [ ] 5.2: Post-install live drill through a real builder dispatch — orchestrator, after `push-main` + `sync-install.sh`   (after: 5.1)

## Goal & scope

**In.** Make the builder's own-lane allowance in `scope-writes.sh` reachable and lane-exact: a `builder` may Write exactly `<run-dir>/contracts/l<n>.md` and `<run-dir>/reports/l<n>-exit.md` for the one lane the dispatcher bound it to, keyed on harness-supplied identity (`agent_type` + `agent_id`) and a binding recorded at dispatch — automatically, by a PostToolUse hook on the builder's Agent launch (DP-1, decided) — never on `cwd`. Close the Bash route builders have been using to write those files. Rewrite `builder.md`/`build-dispatch.md` (and the relevant lines of `coder.md`, `contract-tester.md`, `run-artifacts.md`) so agents use the Write tool at absolute paths and stop assuming `cd` persists. Replace test cases 32–34, whose payloads fake an impossible `cwd`.

**Out.** Every other write-scope rule (which roots each role may write) is unchanged. Role resolution from `dae-role`, marker-deletion detection, the gate skills' identity, and the rest of the agent-identity rework are out. So is Antigravity enforcement (DP-4). Docs-root pages (`docs/conventions.md:142`, any hooks inventory) are updated by the `documenter` at Record, not by this lane.

**Relationship to `project-plans/proposals/agent-identity-write-scope-09-26-26.md` (unapproved).** **Disjoint, not superseding, not depending.** That proposal replaces `dae-role` with `agent_type` for every role. This plan changes one allowance and adds one Bash hook and one PostToolUse Agent hook. The two plans touch the same files (`scope-writes.sh`, `tests/scope-writes.test.sh`, `builder.md`, `build-dispatch.md`), but this plan leaves the four shared helpers byte-identical and does not touch `resolve_role`. **One overlap gets absorbed:** that proposal's subphase 1.4 item 1 and its DP-1 note plan to re-key "`scope-writes.sh:281`'s `cwd`-keyed allowance" onto `agent_type`. This plan does that, with lane binding added. When the proposal is next amended, 1.4.1 should record the allowance as already re-keyed and must not re-implement it. **Flagged for the orchestrator.** This planner has not edited that proposal, because it is a different plan's file.

## Evidence (observed, with sources)

1. **The defect, in code.** `agent-agnostic/hooks/scope-writes.sh:270-284` allows the two lane files only when `agent_type = builder` **and** `find_lane_root "$cwd"` succeeds. Otherwise the target path falls through to `find_parent_worktree` (`:287`). The path is under the marked parent, so `is_lane=0`, and `resolve_role` reads `dae-role` (or no file) and returns `orchestrator`. The orchestrator arm (`:366-393`) denies. The installed copy `~/.claude/hooks/scope-writes.sh` is byte-identical to the source (`diff -q`, 10-10-26), so the bug is live.
2. **A subagent's `cwd` is its spawn dir, not a lane child.** The caller verified this live (`pwd` → `cd <lane>` → `pwd` in a later call returns the spawn dir). I corroborated it independently on 10-10-26: a background `general-purpose` probe spawned from this planner recorded `"cwd":"/home/icarus64/repos/agentic"` in its transcript (`~/.claude/projects/-home-icarus64-repos-money-makers-treehouse-vineyards/11f488df-…/subagents/agent-a8287e8b4b789f188.jsonl`). That is the session's primary dir, not even the run's parent worktree. A relative path written by any subagent can therefore land in an unrelated checkout.
3. **Why the test suite stayed green.** `tests/scope-writes.test.sh:1337-1395` (cases 32–34) set `cwd="$child"`, the lane child. The harness never produces that.
4. **What identifies a subagent in hook input.** From `code.claude.com/docs/en/hooks`, fetched 10-10-26: `agent_id` is "Unique identifier for the subagent or in-process teammate the hook fires in". `agent_type` is "Present when the session uses `--agent` or the hook fires inside a subagent". `session_id` is shared with the parent (the predecessor probe of 09-15-26, quoted in the agent-identity proposal, saw an identical `session_id` and distinct `agent_id`/`agent_type` on a subagent's hook). `SubagentStart` carries `agent_id`/`agent_type` but no `tool_use_id`, prompt or description, so a binding cannot be joined at spawn. It also cannot block ("Context only"). On a foreground Agent call, PostToolUse `tool_response` carries `agentId` ("Identifier for the subagent run").
5. **The dispatcher learns the id at launch.** A background Agent launch from this planner returned `agentId: a8287e8b4b789f188` in the tool result immediately (10-10-26). The subagent's transcript records `"agentId":"a8287e8b4b789f188"` and is named `agent-a8287e8b4b789f188.jsonl`. The hooks doc's SubagentStop example pairs `agent_id: "def456"` with `subagents/agent-def456.jsonl`. **Assumption (unverified until 1.2):** the PreToolUse `agent_id` a builder's Write carries equals the `agentId` its dispatcher received at launch. Everything in Phase 2 rests on this. That is why 1.2 gates it. **Second assumption (also 1.2):** a PostToolUse payload for a *background* Agent launch fires at launch and carries the launched agent's id. The docs list `tool_response.agentId` only for foreground calls (Evidence 4), and the shape of a background launch's `tool_response` (an object field, or text containing `agentId: <id>` as this planner's launch result showed) is not documented.
6. **The Bash route.** `scope-writes.sh:61-63` states that Bash is not intercepted. The Bash-side `parent-tree-guard.sh` is PostToolUse and inspects `git status` (`parent-tree-guard.sh:1-20`). `.artifacts/` is gitignored, so heredoc writes there are invisible to it.
7. **Existing Bash PreToolUse hooks** (`agent-specific/claude/settings.json:127-154`): `no-attribution-guard.sh`, `pr-ready-hygiene-guard.sh`, `allow-workflow-cleanup.sh`, `branch-squash-guard.sh`. None of them concerns run artifacts. `no-attribution-guard.sh:8-40` is the pattern to copy: a `python3` JSON parse of `tool_input.command` that strips heredoc bodies first and fails open on parse errors.
8. **Scratch-dir collision to avoid.** `artifact-locations` puts a `ship: chat` scratch dir at `<repo-root>/.artifacts/reports/<slug>-<runid>/`. So a guard on `.artifacts/reports/` broadly would hit report runs. Only the exact lane-file shapes may be gated.
9. **`--worktree none`.** The builder role comes from a main-checkout `dae-role=builder` (`scope-writes.sh:217-219`), whose deny-list already allows `.artifacts/`. Today a none-mode builder can Write its contract. The change must not regress that.

## Stack & MAJOR versions

| Thing | Version / constraint | Verified from |
|---|---|---|
| Language | bash (`set -uo pipefail`), markdown; no package manifest exists | `scope-writes.sh:108`; agent-identity proposal's stack table (`find` for package.json/pyproject/go.mod empty) |
| Payload parsing in write hooks | flat `grep -oE` + `sed -E`, no `jq` | `scope-writes.sh:250-273` |
| Payload parsing in Bash guards | `python3 -c` with `json`, fail-open | `no-attribution-guard.sh:11-17` |
| Tests | plain bash suites under `tests/`, `pass`/`fail` helpers, `run_hook`, mktemp fixtures | `tests/scope-writes.test.sh:28-99` |
| `grep` / `awk` | ugrep / mawk (silent mis-parses) | `shell-discipline` rule; agent-identity proposal's stack table |
| Hook wiring (Claude) | `agent-specific/claude/settings.json`, merged into `~/.claude/settings.json` by `sync-install.sh` | `.claude/rules/source-push-sync.md` |
| Hook wiring (Antigravity) | `agent-specific/antigravity/hooks.json` via `agy-hook-adapter.sh`, which forwards only `{tool_name, arguments}` | `agy-hook-adapter.sh:63-66` |

## Conventions to enforce

- **The source of truth is `agent-agnostic/`.** Never edit `~/.claude/`. Land through `push-main` and then `sync-install.sh` (`.claude/rules/source-push-sync.md`). No PRs. Never `git add -A`; name the paths.
- **The four shared helpers stay byte-identical** across `scope-writes.sh` and `parent-tree-guard.sh` (`find_parent_worktree`, `find_lane_root`, `resolve_role`, `resolve_root_dir`; header note `scope-writes.sh:74-86`, test `tests/parent-tree-guard.test.sh` case 19). This plan changes none of them. New logic lives outside them.
- **Fail-open where no run is detected; least privilege inside one.** No marker above the target means the hook is inert, unchanged. Inside a detected run, a missing, unreadable or mismatched binding means no allowance. The call then falls through to the existing role logic, which may still allow it (none-mode). Parse failures in the new Bash guard exit 0.
- **Positive controls in every test and search.** Assert on stderr CONTENT, never on exit code alone (ugrep/mawk). Every deny case pairs with an allow case at the identical path that differs only in identity or binding.
- **Test the key, not the lock.** Synthetic payloads prove only that the hook reads a field. 1.2 and 5.2 prove that the real dispatch produces it.
- **Minimal code comments.** Rationale goes in the docs root at Record, not in the hook. The existing long headers are not the model for new code.
- **No attribution trailers** in any commit — no `Co-Authored-By`, no `Claude-Session`, no session URL.
- **No time estimates.**

## Phase 1: Reproduce and measure

### 1.1 — Regression cases 32–34 rewritten to the real payload shape, observed red

- **File scope:** `tests/scope-writes.test.sh`
- **Pattern:** the existing cases 32–34 (`:1337-1395`) and the `new_lane_root_pair` fixture (`:229-237`). Keep the case numbers and the `run_hook`/`pass`/`fail` helpers.
- **Reproduction (exact):** fixture `new_lane_root_pair` → `<base>/run` (marked) and `<base>/run-l1`. Write the binding file `<base>/run/.artifacts/lanes/l1.agent` containing `a1111111111111111`.
  - **32:** payload `{"tool_name":"Write","file_path":"<base>/run/.artifacts/contracts/l1.md","agent_type":"builder","agent_id":"a1111111111111111","cwd":"<base>/run"}`. Expected exit 0. **Observed today: exit 2**, stderr contains `orchestrator write-scope guard`, because `find_lane_root "<base>/run"` fails.
  - **33:** the same with `reports/l1-exit.md`. Expected exit 0. Observed today: exit 2.
  - **34:** the same identity (bound to l1), target `contracts/l2.md`, with an `l2.agent` binding to `a2222222222222222`. Expected exit 2, with stderr naming the target. Today this passes for the wrong reason, because everything is denied. Give it a paired positive control: the `a2222222222222222` identity on the same `l2` target → exit 0 (red today).
  - Also add a `cwd` = an unrelated dir (a fresh `new_scratch`) variant of 32, modelling Evidence 2. Expected exit 0; red today.
- **Acceptance:** the suite runs and these cases are recorded **red** against the unmodified `scope-writes.sh`, with the observed stderr quoted in the exit report. Every other case in the file still passes, so only the rewritten and new cases are red.
- **Test oracle:** `new contract tests` (the regression oracle for 2.2).

### 1.2 — Live-capture the background `builder` launch's PostToolUse payload and the builder's Write `agent_id` — orchestrator, before dispatch

- **File scope:** none in the product tree. The probe is two throwaway hooks that append the raw payload to a scratch log:
  - a PostToolUse hook with matcher `Agent`, logging the whole payload, including `tool_input.subagent_type`, `tool_input.prompt` and `tool_response` verbatim;
  - a PreToolUse hook with matcher `Write`, logging `agent_type`, `agent_id`, `cwd` and `tool_input.file_path`.
  
  Both go in a gitignored `.claude/settings.local.json` that this session actually loads, in an **unmarked** location so `scope-writes.sh` is inert there. Confirm the location with the user before writing, and remove both probes before this subphase closes. The predecessor's 09-15-26 probe is the worked example (agent-identity proposal, "Evidence inherited").
- **Procedure:** dispatch one real `builder`-typed agent **in the background**. Its prompt carries the fixed lines `lane-id: l1` and `run-dir: <abs scratch path>`, and its only task is to Write one scratch file at an absolute path. Note the `agentId` the Agent tool returns, then read the probe log. As a control, also launch one background non-builder agent (for example `Explore`) through the same probe.
- **Acceptance:** recorded rows showing all of the following:
  - (i) a PostToolUse `Agent` payload for the background builder launch fired **at launch**, before the builder finished, with `tool_input.subagent_type = builder` and the prompt carrying both fixed lines;
  - (ii) the exact location and shape of the launched agent's id inside that payload (`tool_response.agentId`, or the text form `agentId: <id>`), recorded verbatim;
  - (iii) that id equals the launch `agentId` the dispatcher saw;
  - (iv) the builder's later Write PreToolUse payload has `agent_type=builder` and an `agent_id` **equal** to (iii), plus the observed `cwd`.
  
  Positive controls:
  - a main-session Write through the same probe logs `agent_id` ABSENT;
  - the non-builder launch's PostToolUse row shows a `subagent_type` other than `builder`, proving the hook can tell the two apart.
  
  The orchestrator records the redacted PostToolUse payload in the progress log, and hands it to lane 1 as the fixture shape for 2.1's tests.
- **If it fails:**
  - If (i)–(iii) fail (no PostToolUse at background launch, or no id in it), the automatic hook is dropped. DP-1 falls back to the orchestrator running `lane-bind.sh` manually right after each launch, and 2.1/4.2 shrink accordingly (the hook script and its wiring are not built; the dispatch prompt lines stay).
  - If (iv) fails (the Write `agent_id` is absent or unequal), Phase 2's binding key is wrong. Stop and return `plan-wrong` with the captured rows.
  - **Never fall back to first-write-claims** (DP-1, decided).
- **Test oracle:** `existing implementation`.

## Phase 2: Bind the lane-file allowance to a dispatcher-recorded agent

### 2.1 — `lane-bind.sh`, the PostToolUse Agent hook that calls it, and its wiring

- **File scope:**
  - `agent-agnostic/hooks/lane-bind.sh` *(new)*
  - `agent-agnostic/hooks/lane-bind-on-launch.sh` *(new)*
  - `tests/lane-bind.test.sh` *(new)*
  - `tests/lane-bind-on-launch.test.sh` *(new)*
  - `agent-specific/claude/settings.json` (the PostToolUse `Agent` entry only; 3.2 later edits the Bash array in the same file, serially, in the same lane)
- **Pattern:**
  - `lane-bind.sh` follows `agent-agnostic/hooks/progress-log.sh`: a small CLI that mutates run-dir state no agent may Write directly, with `set -uo pipefail` and usage on stderr.
  - `lane-bind-on-launch.sh` follows `no-attribution-guard.sh:8-40`'s `python3` JSON parse, with fail-open on any parse error.
- **`lane-bind.sh` interface:** `lane-bind.sh <run-dir> <lane-id> <agent-id>`.
  - It validates that `<run-dir>/progress-log.md` exists (a real run dir), that `<lane-id>` matches `^l[0-9]+$` and that `<agent-id>` matches `^[A-Za-z0-9_-]+$`.
  - It then writes `<run-dir>/lanes/<lane-id>.agent` (creating `lanes/` if needed) atomically: temp file plus `mv` in the same dir.
  - It overwrites any prior binding, because a crash-resume respawn is a new launch with a new id (`build-dispatch.md` "Builder dies mid-lane").
  - Exit 0 on success. On invalid input it exits 1 with a message and writes nothing.
  - It stays a standalone CLI so the manual fallback (1.2) and tests can drive it directly.
- **`lane-bind-on-launch.sh` behavior** (PostToolUse, matcher `Agent`):
  - **Inert** (exit 0, no output, nothing written) unless **all** of these hold:
    - `tool_input.subagent_type` is exactly `builder`;
    - the payload carries **no** `agent_type`, so the launch came from the main session (the orchestrator), not a subagent spawning a builder;
    - `tool_input.prompt` has a line matching `^lane-id:\s*(l[0-9]+)\s*$` and a line matching `^run-dir:\s*(/\S+)\s*$` (first match of each; the run dir must be absolute);
    - the launched agent's id can be extracted from `tool_response`, at the location 1.2 recorded (`agentId` as an object field, else the text form `agentId: <id>`).
  - When all hold, it runs `"$hookdir/lane-bind.sh" <run-dir> <lane-id> <id>`.
  - If `lane-bind.sh` fails on a builder launch that **did** carry both lines, the hook exits 2. Its stderr names the lane and says to run `lane-bind.sh` manually, so a broken binding is loud to the orchestrator. PostToolUse cannot block a tool that has already run; exit 2 only surfaces the message.
  - Malformed JSON or a missing field: exit 0.
- **Wiring:** in `agent-specific/claude/settings.json`'s `PostToolUse` array, add `{"matcher":"Agent","hooks":[{"type":"command","command":"~/.claude/hooks/lane-bind-on-launch.sh"}]}`.
- **Acceptance:**
  - `lane-bind.sh`: each validation failure leaves no file behind (asserted by content). A rebind replaces the old id. The file holds exactly the id and a trailing newline.
  - The hook, against the payload shape captured in 1.2:
    - a main-session background `builder` launch with both lines → the binding file holds the launched id;
    - each inert case writes nothing: `subagent_type` `coder`/`Explore`, a missing `lane-id:` line, a missing `run-dir:` line, a relative `run-dir`, a payload carrying `agent_type`, no id in `tool_response`, a non-run-dir `run-dir`, and malformed JSON;
    - a `run-dir` without `progress-log.md` is inert, while the same payload with the marker present binds (positive control);
    - the `lane-bind.sh`-failure case exits 2 with the manual-fallback message, asserted by content;
    - a second launch for the same lane rebinds.
  - The JSON parses (`python3 -m json.tool`), and `tests/sync-install-settings-merge.test.sh` is green.
- **Test oracle:** `new contract tests`.

### 2.2 — `scope-writes.sh` — allowance keyed on `agent_type` + bound `agent_id`, not `cwd`

- **File scope:** `agent-agnostic/hooks/scope-writes.sh`
- **Pattern:** replace the block at `:270-284` in place. Extract `agent_id` with the same flat `grep -oE`/`sed -E` idiom used for `agent_type` at `:267-268`. Do not touch the four shared helpers or `resolve_role`.
- **Behavior:**
  - If the target path's basename/parent shape is `<P>/.artifacts/contracts/l<n>.md` or `<P>/.artifacts/reports/l<n>-exit.md`, `<P>` carries `.artifacts/progress-log.md`, `agent_type = builder`, `agent_id` is non-empty, and the trimmed contents of `<P>/.artifacts/lanes/l<n>.agent` equal `agent_id` → exit 0.
  - Any other case falls through to the existing role logic **unchanged**. In particular a none-mode main-checkout `builder` role still gets its existing allowance (Evidence 9).
  - When the fall-through ends in a deny, the target is a lane file, and `agent_type = builder`, the stderr adds one specific reason: `no agent_id in hook input` | `lane l<n> has no binding (not recorded yet — retry after your next step)` | `lane l<n> is bound to a different agent`. The existing role message and the offending path stay in stderr.
  - `cwd` is no longer read by this hook. Delete its extraction.
  - The allowance applies to every write-shaped tool the hook already handles (`:253-258`), Write **and** Edit included (OQ8, decided).
- **Acceptance:** 1.1's red cases go green. Cases 35–37 and 51–54 still pass: they carry no `agent_id`, so they hit the no-identity path and are still denied. `bash -n` is clean. A diff of the four helpers against `parent-tree-guard.sh` is empty.
- **Test oracle:** the 1.1 regression cases plus `existing suite`.

### 2.3 — Contract cases — cross-lane, unbound, foreign agent, missing `agent_id`, none-mode untouched

- **File scope:** `tests/scope-writes.test.sh` (new cases from 55 upward; the file ends at case 54 today)
- **Pattern:** case 30's paired-control style (`:1293`). The same target is allowed with one identity and denied with another.
- **Cases:** (a) no `lanes/l1.agent` file → deny, stderr contains `has no binding`. Control: the same payload after the binding is written → allow. (b) bound to `a1…`, payload `agent_id` `a9…` → deny, stderr `bound to a different agent`. (c) `agent_type=coder` with the correct bound id → deny. (d) `agent_type=builder`, no `agent_id` field → deny, stderr `no agent_id`. (e) a lane file under an **unmarked** dir → exit 0 (inert, fail-open preserved). (f) none-mode: a main-checkout marker with `dae-role=builder` (fixture `new_marked_worktree_main_checkout_with_role`), no binding, no `agent_id` → still exit 0. (g) a binding file with trailing whitespace/newline still matches. (h) a path that only resembles a lane file (`contracts/l1.md.bak`, `reports/l1-exit.md/x`, `contracts/lx.md`) never takes the allowance. (i) Write-tool attempts on `lanes/l1.agent` itself, by `builder` and by the orchestrator role → deny. (j) an `Edit` payload on the bound lane's own contract → allow, with a control: the same Edit from a foreign `agent_id` → deny (OQ8).
- **Test oracle:** `new contract tests`.

## Phase 3: Close the shell route

### 3.1 — `lane-artifact-shell-guard.sh` and its suite

- **File scope:** `agent-agnostic/hooks/lane-artifact-shell-guard.sh` *(new)*, `tests/lane-artifact-shell-guard.test.sh` *(new)*
- **Pattern:** `no-attribution-guard.sh` in full: a `python3` JSON parse of `tool_input.command`, heredoc bodies stripped before inspection, exit 0 on any parse failure, exit 2 with a stderr reason.
- **What it gates.** Only these targets: `T` = `…/.artifacts/contracts/l<n>.md`, `…/.artifacts/reports/l<n>-exit.md`, and anything under `…/.artifacts/lanes/`. It denies when a command would **write** a `T`:
  - output redirection whose target is a `T` (`>`, `>>`, `>|`, `&>`, quoted or unquoted);
  - `tee` with a `T` argument;
  - `cp`/`mv`/`install`/`ln`/`rsync` whose **destination** (the last non-option argument) is a `T`;
  - `sed -i`/`perl -i`/`truncate`/`dd of=` naming a `T`.
  - It also denies `lane-bind.sh` invoked from any payload carrying `agent_type` (any subagent). Only the main session (the orchestrator, which has no `agent_type`) records bindings.
- **What it must not gate.** Reads (`cat`, `validate-report.sh --kind exit`, `verify-scope.sh`); `cp <T> /tmp/x` (`T` as the source); a heredoc body or a quoted grep pattern that merely mentions a `T`; scratch-dir report paths `.artifacts/reports/<slug>-<runid>/…` (Evidence 8); `mkdir -p <run-dir>/contracts`.
- **Message:** names the target and says: write the contract/exit report with the Write tool at the absolute path you were handed.
- **Acceptance:** every deny shape above has a case asserting exit 2 and stderr content. Every allow shape has a case asserting exit 0. The original heredoc form from the incident (`cd …-l5 && cat > ../about-us-page/.artifacts/contracts/l5.md <<'EOF' … EOF`) is denied. An empty payload, malformed JSON and a missing `command` all exit 0. The hook is documented, in this plan and later in the docs root, as closing the **habitual** route, not as a sandbox: `python -c open(...)` and similar are a known, accepted limitation, consistent with `scope-writes.sh:61-63`.
- **Test oracle:** `new contract tests`.

### 3.2 — Wire the guard into `agent-specific/claude/settings.json`

- **File scope:** `agent-specific/claude/settings.json`
- **Pattern:** the existing `PreToolUse` → `matcher: "Bash"` array (`:127-154`). Append `{"type":"command","command":"~/.claude/hooks/lane-artifact-shell-guard.sh"}`.
- **Acceptance:** the JSON parses (`python3 -m json.tool`). `tests/sync-install-settings-merge.test.sh` is green. `sync-install.sh --check` from the worktree reports exactly two settings changes: 2.1's PostToolUse `Agent` entry and this Bash entry.
- **Test oracle:** `existing suite`.

## Phase 4: Agents and dispatcher use the tools at absolute paths

### 4.1 — `builder.md` — Write tool at the handed paths, no `cd` assumption

- **File scope:** `agent-agnostic/agents/builder.md`
- **Changes:**
  - Phase 0 (`:23`): remove "`cd` into it … Every subsequent phase runs inside this worktree". Replace it with: the child worktree's absolute path is your working root. Pass absolute paths to every file tool. Use `git -C <child>` for git. For other commands that must run in the child, `cd <child>` within the same Bash call, never chained with git (`shell-discipline`), because the working directory does not carry into hook input or reliably across calls.
  - Phase 1 (`:25`) and the Exit report (`:46`): write the contract and the exit report **with the Write tool** at `<run-dir>/contracts/<lane-id>.md` and `<run-dir>/reports/<lane-id>-exit.md`, never by shell redirection, `tee` or `cp`. A shell write is denied by `lane-artifact-shell-guard.sh`.
  - Your lane id and run dir arrive as the fixed dispatch-prompt lines `lane-id: l<n>` and `run-dir: <abs path>` (4.2). Take the two lane-file paths from them.
  - Name the one retryable denial: `lane l<n> has no binding`. The binding is recorded automatically at your launch, so this should be rare. Retry the Write after your next step. If it is still denied, report a blocker naming the lane, never a workaround.
  - Phase 2: pass coders and testers absolute paths.
- **Acceptance:** a positive-controlled grep finds zero remaining `cd` into it / `runs inside this worktree` phrasing. The control is the same grep against the pre-change file, which returns non-zero. The Write-tool instruction appears in both Phase 1 and the Exit report. The `lane-id:`/`run-dir:` lines are named as the source of the lane-file paths.
- **Test oracle:** `existing suite`.

### 4.2 — `build-dispatch.md` — fixed `lane-id:`/`run-dir:` lines in every builder dispatch prompt

- **File scope:** `agent-agnostic/skills/dae/build-dispatch.md`
- **Changes:**
  - **The dispatch prompt.** In `## Builder dispatch prompt`, every builder dispatch prompt **always** carries two lines, each on its own line with nothing else on it, in exactly this form: `lane-id: l<n>` and `run-dir: <absolute run dir>`. This includes first dispatch, crash-resume respawn and rework redispatch. State that `lane-bind-on-launch.sh` reads them to record the lane binding automatically when the launch returns. A prompt without them leaves the builder unbound and therefore denied its lane files.
  - **Lane-file paths.** The prompt also gives the two lane-file absolute paths and says to write them with the Write tool.
  - **Background launches, from the orchestrator itself.** Builders are launched in the background by the orchestrator (the main session), since the hook only binds main-session launches.
  - **Manual fallback.** If the hook's stderr reports a binding failure after a launch, or if 1.2 dropped the automatic hook, run `lane-bind.sh <run-dir> l<n> <agentId>` with the `agentId` from that launch result.
  - **Respawn.** The "Builder dies mid-lane" respawn rebinds automatically, as a new launch with the same lines.
  - **Progress log.** Note the lane's bound agent id in the progress log's lane row.
  - **Structural-role paragraph.** Correct the "role is inferred structurally" paragraph: the structure still scopes product writes, and the lane files are bound by identity.
- **Acceptance:**
  - A positive-controlled grep finds the literal `lane-id: l<n>` and `run-dir:` line spec in `## Builder dispatch prompt`, and finds the manual `lane-bind.sh` fallback.
  - The respawn and rework paths both say the lines are carried.
- **Test oracle:** `existing suite`.

### 4.3 — `coder.md` / `contract-tester.md` — absolute paths only

- **File scope:** `agent-agnostic/agents/coder.md`, `agent-agnostic/agents/contract-tester.md`
- **Changes:** one line each, beside `coder.md:13` and `contract-tester.md:12`. Use absolute paths under the worktree you were given for every file tool. Your cwd is not that worktree (Evidence 2), so a relative path lands elsewhere.
- **Acceptance:** both lines present; nothing else in either file changes.
- **Test oracle:** `existing suite`.

### 4.4 — `run-artifacts.md` — contract and exit report are tool writes

- **File scope:** `agent-agnostic/rules/run-artifacts.md`
- **Changes:** in the `contracts/<lane-id>.md` and `reports/<lane-id>-exit.md` bullets (`:30-31`), add one sentence each. The builder writes the file with the Write tool. The write is allowed only for the agent bound to that lane at its launch (`lanes/<lane-id>.agent`, written by `lane-bind.sh` from the `lane-bind-on-launch.sh` PostToolUse hook), and shell writes are denied. Add `lanes/` to the run-dir contents list.
- **Acceptance:** the sentences are present. The rule's frontmatter is unchanged.
- **Test oracle:** `existing suite`.

## Phase 5: Verify

### 5.1 — Whole suite, `bash -n`, shared-helper diff

- **File scope:** none written.
- **Acceptance:** every `tests/*.test.sh` passes. Check by counting `PASS`/`FAIL` lines per file, with the FAIL pattern positive-controlled on synthetic input. `tests/sync-install-settings-merge.test.sh` uses indented labels and a different summary (agent-identity proposal 6.1), so include it explicitly. Run `bash -n` on every new or changed script, with a control showing that `bash -n` rejects a deliberately broken file. Extract the four shared helpers from both guards: each extract non-empty, diff empty.
- **Test oracle:** `existing suite`.

### 5.2 — Post-install live drill through a real builder dispatch — orchestrator, after `push-main` + `sync-install.sh`

> Status: pending until after landing (runs after `push-main` + `sync-install.sh`); intentionally unticked in the syllabus.

- **File scope:** none in the product tree; a throwaway repo and run created by the real `workflow-setup.sh`.
- **Why after landing:** nothing binds until the installed copies under `~/.claude/hooks/` change (agent-identity proposal Risk 10).
- **Acceptance:** with the installed hooks, all of the following:
  - a real `builder` launched in the background to lane l1, whose prompt carries the `lane-id:`/`run-dir:` lines, is bound by `lane-bind-on-launch.sh` with **no manual step**. Confirm that `lanes/l1.agent` holds the launch `agentId`;
  - that builder Writes `contracts/l1.md` → allowed, and Edits it → allowed;
  - the same builder Writes `contracts/l2.md` → denied, with the bound-to-different-agent reason;
  - the same builder runs `cat > <run-dir>/reports/l1-exit.md <<'EOF' …` → denied by the shell guard;
  - a background non-builder launch (for example `Explore`) whose prompt carries the same lines writes no binding;
  - the main session's manual `lane-bind.sh` → allowed, and the same command from the builder's Bash → denied by the shell guard.
  
  Record the results as a before/after table in the plan's dir. A contradiction is investigated, not waved through. If the drill fails, the fix goes forward as a new plan-less fix branch (`plan-format`, "Completed").
- **Test oracle:** `existing implementation`.

## Risks, open questions, decision points

1. **DP-1: how the binding is recorded. DECIDED (plan gate, 10-11-26): (b), an automatic PostToolUse hook.** The user asked "Why not an auto hook for no. 3", then said "yes" to switching.
   - **Design.** `lane-bind-on-launch.sh`, wired as PostToolUse on `Agent` (2.1), handles main-session `builder` launches only. It reads the launched agent's id from `tool_response` and reads the `lane-id: l<n>` / `run-dir: <abs>` lines from the dispatch prompt (4.2), then calls `lane-bind.sh`. It is inert for any other launch, or when the lines are absent.
   - **1.2 gates it.** 1.2 must show three things: a background builder launch fires PostToolUse at launch, the payload carries the id, and that id equals the builder's later Write `agent_id`.
   - **Fallback if 1.2 fails on the hook side:** the orchestrator runs `lane-bind.sh` manually right after each launch (the former option (a)).
   - **First-write-claims (former (c)) is rejected outright**, including as a fallback.
2. **DP-2: the gap between spawn and binding. DECIDED: keep the specific retryable deny.** `SubagentStart` has no join key (Evidence 4), so the binding exists only once the launch returns. With PostToolUse on a background launch, the gap should be close to zero. Builders also reach Phase 1 only after Phase 0. Still, 2.2 keeps the `has no binding … retry after your next step` reason, and `builder.md` names the retry (4.1). There is no `pending` marker and no first-write binding.
3. **DP-3: shell guard. DECIDED: a new standalone `lane-artifact-shell-guard.sh`.**
   - `parent-tree-guard.sh` is PostToolUse, so it runs after the write.
   - `branch-squash-guard.sh` and `no-attribution-guard.sh` own unrelated concerns, and the repo keeps hooks standalone (`scope-writes.sh:74-86`).
   - The guard matches only exact lane-file shapes, `lanes/` and `lane-bind.sh`, per "gate only what needs a gate".
4. **DP-4: Antigravity. DECIDED: no mirror.**
   - `agy-hook-adapter.sh:63-66` forwards no `agent_type`/`agent_id`, and Antigravity has no known launch hook that returns an id, so neither the binding nor the lane check can work there.
   - Builders under Antigravity are already denied Write-tool access to these files, because they resolve to `orchestrator`.
   - The documenter records it as a known gap in `docs/known-issues.md` at Record. It also belongs with the agent-identity proposal's DP-7.
5. **Risk: this run's own builder hits the bug being fixed. DECIDED (plan gate): (a).** The installed `~/.claude/hooks/scope-writes.sh` stays the old one until `push-main` + `sync-install.sh`, and neither new hook is installed yet. So **for this run only**, lane l1's builder may write `contracts/l1.md` and `reports/l1-exit.md` with a shell heredoc. The orchestrator logs this exception in the progress log and states it in the builder's dispatch. This is also why the plan keeps a single lane.
6. **Risk: two harness assumptions remain until 1.2** (Evidence 5):
   - a background Agent launch's PostToolUse payload carries the launched id;
   - that id equals the builder's PreToolUse `agent_id`.
   
   The evidence is strong: the same id appears in the launch result, in the transcript's `agentId` and in the transcript filename, and the docs pair SubagentStop `agent_id` with that filename. But none of this has been observed on a hook payload. 1.2 is a hard gate, and its fallbacks are fixed in DP-1.
7. **Risk: the Bash guard matches text, not effect.** This is the class the agent-identity proposal's open question 13 flags. Mitigation: strip heredoc bodies, match only destination positions, use exact lane-file shapes, and test allow-cases for mentions. Accepted limitation: interpreter one-liners.
8. **OQ8: Edit as well as Write. DECIDED: yes.** The bound-lane allowance covers every write-shaped tool `scope-writes.sh` already handles (`:253-258`), Write and Edit included (2.2, 2.3 case (j)).
9. **Follow-up candidates (out of scope, minimal-fix rule).** `smart-test.sh` reads `cwd` from the payload (`smart-test.sh:150`). For a builder, that is the spawn dir, not the lane, so its test-scoping may be wrong for every subagent. It belongs with the agent-identity proposal's 2.4.

## Lanes

**Serial, one lane.** The bugfix module's default applies. Three things make parallelism a net loss here:
- 2.2, 2.3 and 1.1 share `tests/scope-writes.test.sh`.
- 3.1 and 4.x reference the shipped interfaces of `lane-bind.sh` and `lane-bind-on-launch.sh` (2.1).
- 2.1 and 3.2 both edit `agent-specific/claude/settings.json`.
- Every extra lane adds another builder that needs Risk 5's exception.

1.2 and 5.2 are orchestrator-executed and sit outside the builder lane: 1.2 runs **before** the lane is dispatched, and 5.2 runs after landing.

## Skill mapping

| Work | Agent / skill |
|---|---|
| 1.2 live capture | orchestrator, directly (probe wiring in an unmarked, user-confirmed settings file) |
| 1.1, 2.1–2.3, 3.1–3.2, 4.1–4.4 | `builder` (lane l1) → `coder` + `contract-tester` (2.1, 2.3, 3.1 oracles are `new contract tests`; 1.1 is a tests-only deliverable → contract-tester only) |
| 5.1 | builder's e2e tail, then re-checked at `review-code` |
| Plan gate / code gate | `review-plan` / `review-code` |
| Record (docs root: `docs/conventions.md:142`, hooks inventory, `docs/known-issues.md` for DP-4) | `documenter` → `document-local` |
| Ship | `push-main` (squash to `main`, no PR), then `sync-install.sh` |
| 5.2 live drill | orchestrator, after sync |
