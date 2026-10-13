# builder-write-scope-10-10-26.plan-review

## Round 1 — 10-10-26

```
verdict: tentative
next: proceed
blocking: 0
non-blocking: 5
```

### Findings

- [non-blocking] Structural: `validate-plan.sh` OK (13 subphases); `plan-lifecycle.sh check` on the plans dir: "plans dir layout is conformant" (it rejects a file path argument; run against the dir).
- [non-blocking] Verified: scope-writes.sh:270-284 is the cwd-keyed allowance exactly as described; falls to `find_parent_worktree` at :287; installed copy is byte-identical (`diff -q` exit 0). Cases 32-34 at :1337-1395 use `cwd="$child"`; the file ends at case 54 (:1777); case30 at :1295; `new_lane_root_pair`, `new_scratch`, `new_marked_worktree_main_checkout_with_role` exist. settings.json Bash PreToolUse array at :127-154 matches. scope-writes.sh:61-63 states Bash is not intercepted. no-attribution-guard.sh strips heredocs and fails open on parse error. agy-hook-adapter forwards only tool name/arguments; smart-test.sh:150 reads cwd.
- [non-blocking] UNCERTAIN, correctly gated: PreToolUse `agent_id` == launch `agentId` is unobserved; 1.2 is a hard gate with a positive control and a fallback (DP-1c). Phase 2 must not start before 1.2 passes. Also unverified: that `agent_id` is present on hook input for Write inside a background subagent.
- [non-blocking] Ask diff: no omissions, additions or inversions. Tool-based writes (2.2, 4.1), shell route closed (3.1/3.2), lane binding by dispatcher record (2.1/4.2). Documented limitation (interpreter one-liners; Antigravity gap DP-4) is recorded with reasoning. Minor: subphase 4.3 (absolute paths for coder/tester) goes slightly beyond the ask but is justified by Evidence 2.
- [non-blocking] Process note: Risk 5 means this run's own builder hits the bug (old hook installed); the orchestrator must put the heredoc exception to the user and log it. Single lane is consistent with that. DP-1/DP-2/DP-3 are decisions for the human at the gate; recommendations are sound.

### Open questions

- DP-1: confirm option (a) (orchestrator runs `lane-bind.sh` after each launch).
- Risk 5: which exception route for this run (a/b/c)? Recommend (a).
- Risk 8: should Edit be covered by the bound-lane allowance, or Write only?

## Round 2 — 10-11-26

```
verdict: tentative
next: proceed
blocking: 0
non-blocking: 6
```

### Findings

- [non-blocking] Structural: `validate-plan.sh` OK (13 subphases); `plan-lifecycle.sh check project-plans` conformant. Light re-gate scoped to the d317b9a amendment (diff vs 3c440a5 read in full).
- [non-blocking] Verified against the Claude Code hooks doc (code.claude.com/docs/en/hooks, fetched 10-11-26): `Agent` is a valid PostToolUse matcher (same values as PreToolUse); a background launch returns immediately with `tool_response` carrying `status: "async_launched"`, `agentId`, `description`, `prompt`, `outputFile`, `resolvedModel`; subagents run in the background by default; PostToolUse exit 2 shows stderr to Claude, tool already ran (matches 2.1's "surfaces only" wording). So 2.1's primary extraction path (`tool_response.agentId` object field) is documented, and the plan's Evidence 4/5 statement that the field is "documented only for foreground calls" and the "text form" doubt are stale and over-cautious. 1.2 still correctly gates the unobserved parts (PostToolUse actually fires at launch for the hook, id equals the later Write `agent_id`).
- [non-blocking] Verified wiring facts: `agent-specific/claude/settings.json` PostToolUse array today has only `Write|Edit|MultiEdit` (:171) and `Bash` (:188) matchers, no `Agent` entry, so 2.1's added entry does not collide. 3.2 edits the PreToolUse Bash array in the same file; the plan serializes them in one lane. `tests/sync-install-settings-merge.test.sh` exists. `lane-bind-on-launch.sh`/`lane-bind.sh` do not yet exist in `agent-agnostic/hooks/` (correct, both marked new).
- [non-blocking] Design note on 2.1's "no `agent_type` means main session" inertness test: the doc says `agent_type` is also present when the session runs with `--agent`. If the orchestrator is ever run as an `--agent` session, every launch is silently inert and builders are denied (the loud `has no binding` deny and manual fallback cover it). Suggest 2.1/4.2 mention this, or key on `agent_id` absence instead. Not blocking.
- [non-blocking] Ask diff including the 10-11-26 entry ("Why not an auto hook for no. 3" / "yes"): the entry is verbatim-quoted and the plan delivers it (DP-1 decided (b), automatic PostToolUse Agent hook, 2.1/4.2/1.2/5.2). No omission, addition or inversion; original asks (Write tool, shell route closed, lane-exact binding recorded by the dispatcher) unchanged and still delivered; recording is now by hook rather than orchestrator call, which is what the user chose. Rejection of first-write-claims is recorded with reasoning.
- [non-blocking] Mechanical follow-ons (2.2, 2.3 case j, 2.3, 3.2, 4.1, 4.4, 5.2) are consistent with 2.1/4.2: lane-id/run-dir fixed lines are named in 4.1 and 4.2; 3.2 drift expectation of exactly two settings changes matches 2.1 plus 3.2; 5.2 adds no-manual-step and non-builder-control checks. Single-lane rationale still holds (2.1 and 3.2 share settings.json).

### Open questions

- None blocking. Optional: should 2.1 key main-session detection on `agent_id` absence rather than `agent_type` absence (see design note)?
