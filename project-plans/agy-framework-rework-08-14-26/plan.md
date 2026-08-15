# agy-framework-rework-08-14-26

Rework plan — Fix context-burn in smart hooks for Antigravity, reorganize repo into agent-specific and agent-agnostic directories, and verify AGY tools.

## Phase syllabus

- [ ] Phase 1: Fix context-burn in smart-lint and smart-test
  - [ ] 1.1: Extract TargetFile robustly in smart-lint.sh and fail-open    (lane 1)
  - [ ] 1.2: Match AGY write tools and extract TargetFile in smart-test.sh   (lane 1, after: 1.1)
- [ ] Phase 2: Restructure into agent-specific and agent-agnostic dirs
  - [ ] 2.1: Rename generic to agent-agnostic and move agent-specific/claude/antigravity    (lane 1, after: 1.2)
  - [ ] 2.2: Update docs and install paths to reflect new directories        (lane 1, after: 2.1)
- [ ] Phase 3: Verify and update Antigravity/Agent-Agnostic tools
  - [ ] 3.1: Update rules/skills to use AGY tool names (run_command)         (lane 1, after: 2.2)

---

## Goal & scope

### The Defect

**Defect 1: `smart-lint.sh` context burn in Antigravity.** The script parses `.tool_input.file_path` from the hook payload to scope its linting. Antigravity's `agy-hook-adapter.sh` translates the tool payload to flat JSON, but the file path resides under `arguments.TargetFile` (for `write_to_file` and `replace_file_content`). Since `file_path` is empty, `smart-lint.sh` falls back to its CLI mode: a full, repo-wide lint sweep. This destroys the orchestrator's context by flooding it with unrelated project lint errors on every file edit.

**Defect 2: `smart-test.sh` silently skips all tests in Antigravity.** It expects `tool_name` to be `Edit`, `Write`, or `MultiEdit`. Antigravity's tools are `default_api:write_to_file`, `default_api:replace_file_content`, etc. The regex match fails, and the script silently exits 0 without running any scoped tests.

**Workspace Organization:** The project currently has `claude`, `antigravity`, and `generic` top-level directories. These need to be properly categorized into `agent-specific/` (containing `agent-specific/claude/` and `agent-specific/antigravity/`) and `agent-agnostic/` (renamed from `agent-agnostic/`), with all documentation and installation scripts updated.

### In scope
1. Update `smart-lint.sh` to extract the file path using the robust flat `grep` extraction used in `branch-squash-guard.sh`, looking for `file_path`, `TargetFile`, `target_file`, etc. Change the fallback behavior so that if invoked via a hook (stdin present) but no target file is found, it exits 0 (fail-open) rather than running a repo-wide sweep.
2. Update `smart-test.sh` to match AGY's write tool names and extract the file path properly using the same method.
3. Rename `agent-agnostic/` to `agent-agnostic/`. Create `agent-specific/` and move `agent-specific/claude/` and `agent-specific/antigravity/` into it.
4. Update `sync-install.sh`, `claude-install-drift.sh`, `hooks.json`, `AGENTS.md`, `README.md`, and other docs to reflect the new paths.
5. Review AGY-specific skills and rules (like `agent-specific/antigravity/rules/clean-code.md`) to ensure they use correct Antigravity tool names (e.g., `run_command` instead of `Bash`, `invoke_subagent` instead of `Agent`).

### Merge Strategies (Report)
As requested, here is how the merge strategies currently work:
- **Generic strategy (`cleanup-merged` skill):** The ship stage publishes the branch and tears down the worktree but keeps the local branch and touches nothing remote. Once the PR merges, the skill is invoked to prove the merge, delete the branches, prune worktree remnants, confirm the run dir is gone, and archive the plan.
- **Agentic & Daedalus Mono strategy (`branch-squash-guard.sh` Mode B):** These repos have no `dev` branch. `main` is the integration branch. The policy enforces branching from `main`, squash-merging locally, and pushing `main` up. Direct commits or edits on `main` are denied, and `gh pr merge` must be `--squash`.

---

## Stack & MAJOR versions

- **Bash:** 3.2 (portability floor)
- **Git:** 2.34.1

---

## Conventions to enforce

1. **bash 3.2 / BSD-safe:** Use `while IFS= read -r` loops and parameter expansion. No associative arrays.
2. **No jq dependency:** Use flat grep/sed for JSON field extraction as done in `branch-squash-guard.sh` to avoid jq dependency and handle flat/nested shapes agnostically.
3. **Tech-agnostic:** Hook gates must work identically for all supported languages.
4. **Delete the old path:** Remove replaced structures. No dual compatibility shims surviving the run.

---

## Phased subphases

### Phase 1: Fix context-burn in smart-lint and smart-test

#### 1.1: Extract TargetFile robustly in smart-lint.sh and fail-open
**File scope:** `agent-agnostic/hooks/smart-lint.sh` (or `agent-agnostic/hooks/smart-lint.sh` after move).
**Pattern to follow:** The `field()` extraction function from `branch-squash-guard.sh:102-106` and the fallback logic.
**Acceptance criteria:**
- Script uses flat `grep` to extract `file_path`, `TargetFile`, `target_file`, `path`, or `notebook_path`.
- If stdin has JSON data (hook mode) but no target file could be extracted, it exits 0 and logs an info message instead of falling back to the repo-wide `CLI mode` lint.
**Test approach:** `existing suite` (verify existing tests pass, and manually test with AGY payload).

#### 1.2: Match AGY write tools and extract TargetFile in smart-test.sh
**File scope:** `agent-agnostic/hooks/smart-test.sh`.
**Pattern to follow:** The same `field()` extraction function and tool matching logic from `branch-squash-guard.sh`.
**Acceptance criteria:**
- Matches `write_to_file`, `replace_file_content`, `multi_replace_file_content`, and their `*:*` variants alongside `Write`, `Edit`, `MultiEdit`.
- Extracts the file path using the robust method.
**Test approach:** `existing suite`.

### Phase 2: Restructure into agent-specific and agent-agnostic dirs

#### 2.1: Rename generic to agent-agnostic and move agent-specific/claude/antigravity
**File scope:** Workspace directories.
**Acceptance criteria:**
- `agent-agnostic/` is renamed to `agent-agnostic/`.
- `agent-specific/agent-specific/claude/` and `agent-specific/agent-specific/antigravity/` exist.
**Test approach:** `equivalence check`.

#### 2.2: Update docs and install paths to reflect new directories
**File scope:** `agent-agnostic/hooks/sync-install.sh`, `agent-agnostic/hooks/claude-install-drift.sh`, `agent-specific/agent-specific/antigravity/hooks.json`, `README.md`, `AGENTS.md`, `docs/*`, `tests/*.test.sh`.
**Acceptance criteria:**
- Installation scripts copy from `agent-agnostic/hooks` and `agent-specific/agent-specific/claude/rules`.
- Documentation and tests reference the new paths correctly.
**Test approach:** `equivalence check` (ensure installation scripts run without error).

### Phase 3: Verify and update Antigravity/Agent-Agnostic tools

#### 3.1: Update rules/skills to use AGY tool names (run_command)
**File scope:** `agent-specific/agent-specific/antigravity/**/*.md`, `agent-agnostic/**/*.md`.
**Acceptance criteria:**
- References to `Bash` or `Agent` tools in Antigravity rules/skills are updated to `run_command` and `invoke_subagent`/`define_subagent` to match the AGY capability set.
**Test approach:** `equivalence check`.

---

## Risks, open questions, decision points
- **Decision:** Do we keep `agy-hook-adapter.sh` after updating the hook scripts?
  - *Option A:* Yes, it still translates the JSON format and handles context injection, which is valuable. The hook scripts will just be robust enough to find the `TargetFile` directly. (Recommended)
  - *Option B:* Remove it and make all hooks fully aware of AGY's nested structure.
- **Risk:** Existing tests in `tests/*.test.sh` might have hardcoded paths to `agent-agnostic/`. They must be updated during Phase 2.

## Skill mapping
- `planner` creates this plan.
- `builder` executes the subphases sequentially.
- `contract-tester` validates the hook script behavior.
