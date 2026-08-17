# plan-diagnosis: Config Write Perms

## Scope & Sources
- **Issue**: "figure out which non write commands you can add to the config so that things like find, locate and whatever else are allowed and so that you allow all write/touch/move operations inside ~/repos/***/.worktrees/***"
- **Plan Path**: `project-plans/proposals/diagnose-config-write-perms-08-16-26.md`
- **Base**: `main`
- **Suspect Reference**: `agent-agnostic/hooks/agy-permissions.sh`

## Reproduction
N/A - This is a configuration policy update request, not a runtime bug.

## Ranked Candidates

- [x] **C1: Add missing read-only tools, restrict file mutations to worktrees, and fix JSON parsing**
  - **Likelihood**: High
  - **Ease**: High
  - **Evidence**: `agent-agnostic/hooks/agy-permissions.sh` currently auto-allows `find` but is missing other common read-only commands (`locate`, `fd`, `xargs`, `less`, `more`, `bat`). For file modifications, `cp`, `mkdir`, and `touch` are allowed globally without path restrictions, while `mv` and `rm` fall through to the "ask" list. In addition, `~/.gemini/config/hooks/*` currently prompts instead of being auto-allowed, and the JSON parsing for Antigravity only checks `.toolCall` instead of also falling back to `.tool_name` / `.tool_arguments.CommandLine`. To safely fulfill the request, we must add path validation for mutations and update these fields.
  - **Proposed Fix**:
    1. Update JSON parsing to extract `tool` from `.tool_name // .toolCall.name // empty` and `cmd` from `.tool_arguments.CommandLine // .toolCall.arguments.CommandLine // empty`.
    2. Update the "Allow list (broad prefixes)" in `agy-permissions.sh` to include `locate`, `fd`, `xargs`, `less`, `more`, `bat`, and explicitly allow `$HOME/.gemini/config/hooks/*` and `~/.gemini/config/hooks/*` to run without asking.
    3. Remove `cp`, `mkdir`, and `touch` from the global allow list to prevent unrestricted mutations.
    4. Add a dedicated conditional block before the global allow list for modifying commands (`rm`, `mv`, `cp`, `mkdir`, `touch`). This block will auto-allow the commands ONLY IF:
       - `$cwd` matches `$HOME/repos/*/.worktrees/*` or `$HOME/repos/*/.workflows/*`
       - The `$cmd` string does not contain absolute paths (` /`), home paths (`~/`), or directory traversal (`../`), preventing trivial escapes.
       - Otherwise, it falls through to the ask list.
  - **Files**: `agent-agnostic/hooks/agy-permissions.sh`
  - **Oracle**: equivalence check (verify script syntax and behavior under different cwd/cmd scenarios).

## Diff Summary
- `agent-agnostic/hooks/agy-permissions.sh` will have its global allow list expanded for read commands and hook scripts, JSON parsing robustly updated, and a new scope-checking block added for `rm`/`mv`/`cp`/`mkdir`/`touch`.

## Open Questions / Unverified
- The path check uses string matching on the `$cmd` variable to block ` /`, `~/`, and `../`. This is a heuristic and cannot reliably catch all edge cases of bash parsing (like variables `rm $HOME/...`), but it covers standard literal usage. 
- Are there any other specific "non write commands" intended by "whatever else"? (e.g. `zcat`, `grep -r`, `tar -tf`). Added a standard set of common safe viewers.
