# code-review

## Round 1 — 10-11-26

```
verdict: tentative
next: proceed
blocking: 0
non-blocking: 5
```

### Findings

- [non-blocking] agent-agnostic/hooks/lane-bind-on-launch.sh (python block, `"agent_id" in d or "agent_type" in d`): the plan and plan-review round 2 asked for agent_id-absent only. Adding agent_type-absent is redundant for the stated purpose, because any subagent launch carries agent_id. It is harmful in a `--agent` main session, where the docs say agent_type is present with no agent_id: the orchestrator's builder launch would be silently inert, with no binding and no stderr, so the manual-fallback trigger in build-dispatch.md never fires. The builder then gets "has no binding" denials with no obvious cause. Nothing in the repo launches dae via `--agent` (grep clean), and the 1.2 capture showed main-session agent_type absent only for a plain session, so it is not blocking. Recommend dropping the agent_type clause (and case 06a, which asserts it) or logging it as an accepted limitation. The deviation is disclosed in the exit report.
- [non-blocking] lane-artifact-shell-guard.sh: relative-path false negative. `cd <run>/.artifacts && echo x > contracts/l1.md` exits 0 (TARGET needs a literal `.artifacts/` segment). `cp -t <dir> src`, `rm lanes/l1.agent`, and `$VAR`-based paths are also not caught. Consistent with the plan's "habitual route, not a sandbox" stance; the Write route is still the only one scope-writes sanctions, so worth a line in the docs Record.
- [non-blocking] Shell-guard false positives against ship:chat scratch reports: none found. `> /r/.artifacts/reports/<slug>-<runid>/report.md` (incl. heredoc), `.../reports/slug-1/l1-exit.md`, `l1-exit.md.bak`, reads (`cp <T> /tmp/x`, `ls lanes/`) and quoted mentions in `git commit -m` all exit 0. Deny shapes verified exit 2: `>`, `>>`-style with and without space, quoted target, `tee`, `dd of=`, `cd && >`, `2>&1 >`, `lanes/foo`, `l12-exit.md`.
- [non-blocking] Tests: scope-writes.test.sh and lane-binding-e2e.test.sh payloads use cwd = parent/base or an unrelated scratch dir (never the lane child), matching the captured shape (cwd = session/parent worktree). lane-bind-on-launch.test.sh uses `"cwd": "/tmp"`, harmless since the hook ignores it. The tests build payloads synthetically rather than loading the captured fixtures; the captured field layout (tool_response.agentId, tool_input.prompt, subagent_type) matches what the tests build.
- [non-blocking] The 5.2 post-install drill and `sync-install.sh --check` remain with the orchestrator, as planned. Until `push-main` plus sync, nothing binds.

### Verified

- Plan coverage: all 4.x/3.x/2.x subphases present in the 15-file diff; scope-writes.sh no longer reads cwd; allowance keyed on agent_type=builder plus lanes/l<n>.agent equals agent_id, with the three specific deny reasons appended to the orchestrator message; none-mode falls through unchanged.
- All 26 `tests/*.test.sh` run green here (my own run; includes sync-install-settings-merge 12/0).
- Shared helpers: the four functions hash identically in scope-writes.sh and parent-tree-guard.sh, and parent-tree-guard.sh has no diff vs main.
- Comments: new hooks carry 2 comment lines each; tests 2-12 header/section lines; no narrating essays. Compliant.
- Commits: no Claude, Co-Authored-By or session text in any branch commit message; author is icarus64.
- Working tree clean; no stray files.

### Open questions

- Is dae ever run as a `--agent` main session? If so, drop the agent_type clause (first finding).
