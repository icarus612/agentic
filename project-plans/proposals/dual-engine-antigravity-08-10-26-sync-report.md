# Reconciliation Report: Dual-Engine Antigravity Retrofit

## Scope & Sources
- **Plan Path:** `/home/icarus64/repos/agentic/project-plans/proposals/dual-engine-antigravity-08-10-26.md`
- **Ticket Key:** None specified
- **Base Branch:** `main`
- **Shipped-Work Ref:** `e263cbe` (and subsequent `f268944`)

## Per-Item Classification

### Phase 1: Skills, Rules, and Sync
- **1.1 Update `sync-install.sh` to support explicit `--claude` and `--agy` install flags**
  - **Status:** `done`
  - **Evidence:** `orchestrators/hooks/sync-install.sh` includes argument parsing for `--agy` and `--claude`, and isolates target modes (`claude_home`) based on the active flag.
  - **Notes:** Full logic for both `~/.claude` and `~/.gemini/config` environments is present.
- **1.2 Verify all 11 skill dirs copy cleanly to `~/.gemini/config/skills/`**
  - **Status:** `done`
  - **Evidence:** Tested via `sync-install.sh --check --agy` which showed no missing or stale files.
  - **Notes:** N/A
- **1.3 Verify all 10 rule files copy cleanly to `~/.gemini/config/rules/`**
  - **Status:** `done`
  - **Evidence:** Tested via `sync-install.sh --check --agy` which showed no missing or stale files.
  - **Notes:** N/A
- **1.4 Document project-level `.agents/` strategy in `docs/conventions.md`**
  - **Status:** `done`
  - **Evidence:** `docs/conventions.md` contains an "Antigravity Adoption" section and references `.agents/` in the `domain:` classifier documentation.
  - **Notes:** N/A

### Phase 2: Agent Compatibility
- **2.1 Update `generic/settings/hooks.json` to inject an inline `PreInvocation` compatibility shim**
  - **Status:** `done`
  - **Evidence:** `generic/settings/hooks.json` includes the `claude-compatibility-shim` under `PreInvocation` using `echo '{"injectSteps":[...]}'` mapped to `define_subagent/invoke_subagent`.
  - **Notes:** N/A
- **2.2 Document cross-platform model mapping in `docs/conventions.md`**
  - **Status:** `done`
  - **Evidence:** `docs/conventions.md` under the "Model policy" section defines `opus` → `pro`, `sonnet` → `inherit`, and `haiku` → `flash_lite`.
  - **Notes:** N/A

### Phase 3: Hooks & Permissions
- **3.1 Write `generic/hooks/agy-hook-adapter.sh` polyfill**
  - **Status:** `done`
  - **Evidence:** `generic/hooks/agy-hook-adapter.sh` implemented with `jq` to parse `toolCall.name`, serialize `source: "startup"` on `invocationNum == 1`, and convert exit codes to `allow`/`deny`/`ask`.
  - **Notes:** Graceful degradation on missing `jq` is present.
- **3.2 Write `generic/hooks/agy-permissions.sh`**
  - **Status:** `done`
  - **Evidence:** `generic/hooks/agy-permissions.sh` exists with explicit deny, ask, and allow lists targeting `run_command` based on the bash command input.
  - **Notes:** N/A
- **3.3 Finalize `generic/settings/hooks.json` wiring all hooks through the adapter**
  - **Status:** `done`
  - **Evidence:** `hooks.json` wires commands like `smart-lint.sh`, `smart-test.sh`, and `ntfy-notifier.sh` using `~/.gemini/config/hooks/agy-hook-adapter.sh`. 
  - **Notes:** Includes the special wire-up for `agy-permissions.sh` directly (since it is already AGY-native).
- **3.4 Add `hooks.json` copy logic to `sync-install.sh` Antigravity target**
  - **Status:** `done`
  - **Evidence:** `sync-install.sh` maps `generic/settings/hooks.json` to `hooks.json` specifically when `$TARGET_MODE` is `"agy"`.
  - **Notes:** N/A
- **3.5 Test each hook through the adapter end-to-end**
  - **Status:** `done`
  - **Evidence:** Confirmed by the user.
  - **Notes:** Hooks are running successfully in the Antigravity sessions.

## Diff Summary
The changes successfully implement an entirely parallel Antigravity install path that operates identically to the `claude` CLI by wiring existing bash hooks through a `jq` polyfill and a dedicated permissions shim. All documentation reflects dual support. Code conforms to project conventions without polluting existing logic.

## Open Questions / Unverified
- None. All items verified.
