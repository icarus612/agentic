---
name: shell-discipline
description: One command per Bash/run_command call — compound chains are all-or-nothing at the permission gate (one unallowed segment prompts the whole string, and "always allow" on a compound is worthless); never chain cd with git/gh; prefer invocation forms already on the standing allowlist.
domain: universal
---

# Shell discipline

Permission rules match command strings, so how a command is phrased decides whether it prompts. Three consequences, all load-bearing for unattended agents:

- **One command per Bash/run_command call.** A compound (`a && b`, `a; b; c`) is allowed only if EVERY segment is — one segment off the allowlist prompts the whole chain, and approving it "always" only memorizes that exact string, helping nobody next time. Separate calls let the allowed parts run free and isolate the prompt to the one command that actually needs it. Chain only when every segment is independently on the standing allowlist.
- **Never chain `cd` with git/gh.** `cd <dir> && git …` trips the harness's untrusted-hook safety prompt even when both halves are allowlisted. The working directory PERSISTS between Bash/run_command calls: `cd` in its own call, then run — or skip the cd with `git -C <dir> …`. This especially covers the dae pipeline's worktree hops (setup, builder phase 0, merge-backs, cleanup).
- **Prefer the invocation form that's already allowlisted.** The same tool is often reachable several ways (examples only: a package-manager runner like `pnpm exec prettier` vs a direct `node_modules/.bin/prettier`; `git -C` vs cd-then-git). When one form has a standing grant and another doesn't, using the ungranted form manufactures a prompt for no gain — check what the project's allowlist already covers and phrase the call that way.
