# Source, push, sync (this repo only)

This repo is the single source of truth for agent skills, rules, and hooks — `~/.claude/` is an install of it, never an editing target. Every change follows this flow, in order:

1. **Edit here.** Make all changes in this repo's source dirs (`agent-agnostic/`, `tool-based/`) — never directly in `~/.claude/`.
2. **Push up.** Land the change by branching off `main` into a workflow worktree via `workflow-setup.sh` (standard scheme, same as every other project) and working there, then squash-merging that branch into `main` locally and pushing, via the `push-main` skill — this repo still uses NO PRs, ever. The only thing this overrides in the global `push-policy` rule is the PR route: integration is by **squash here too**, exactly as everywhere else (the former `--no-ff` exception for this repo is retired), and every other clause still holds — ask before every push, never force-push, never commit directly on `main`.
3. **Sync the install.** Immediately after the push, run `agent-agnostic/hooks/sync-install.sh <pushed-range>` — it copies the changed files to their `~/.claude/` install locations (`skills/<name>/` as whole directories, `rules/<name>.md`, `hooks/<file>`, `agents/<file>`, and `agent-specific/claude/settings.json` → `~/.claude/settings.json`), propagates deletions, and `diff`-verifies — but ONLY universal-domain content (`domain: universal`, i.e. everything under `agent-agnostic/`). Tool-specific content (`domain: <tech>`, under `tool-based/`) installs into the projects that use that tech, never into `~/.claude/`. Project-scoped content (like this rule and the `push-main` skill, which live only in this repo's `.claude/`) is never synced anywhere. Syncing is not optional and needs no extra confirmation — a push that lands without the install sync is an incomplete change.

One unit is special: `agent-specific/claude/settings.json` (the versioned source of the user-level `~/.claude/settings.json`). Unlike skills/rules/hooks, the INSTALL side of this file also mutates legitimately — Claude Code writes to it during normal use: `/model` persists into `model`, and "always allow" appends to `permissions.allow`. It is therefore **merged, never copied**:

- a key the SOURCE defines is authoritative (the repo wins);
- a key only the INSTALL has is PRESERVED, at any depth;
- `permissions.allow` is UNIONED — source entries first, then live-only grants, deduped — so "always allow" survives a sync;
- `--check` reports drift as "merging the source would change the install", not "the two files differ" (they differ by design).

**Dropping a key from the repo copy hands it to the install permanently.** That is why `model` is deliberately absent from the source: the running model is a per-user, per-session choice and the repo has no business pinning it. The corollary is that this merge cannot express a DELETION — remove a key from the source and the installed value stays; delete it from the install by hand if that is what you meant. If `python3` is unavailable the sync REFUSES this one unit rather than falling back to a clobbering copy.
