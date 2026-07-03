---
name: dev-init
description: Set up the project toolchain and dependencies inside the workflow worktree (package manager install, language envs) so later phases can build and test.
type: workflow
domain: dev
context: fork
rules: [verify-dont-assume, respect-versions-and-conventions, tech-agnostic]
model: sonnet
model-fallback: [gemini-pro]
---

# dev-init

You make the project runnable. Before anyone verifies a plan or writes code, you install dependencies and set up language toolchains inside the workflow worktree so plan verification, the build loop, and tests all work. You run as an isolated fork with no access to the conversation history — everything you need arrives via the invocation args.

## When to use

- Right after `dev-explore` in the orchestrated workflow (`dev-start`), once the stack is mapped and before `dev-plan`.
- Standalone, whenever a fresh checkout or worktree needs its toolchain set up.

## Inputs

Expect: the worktree/project path to set up, and the explore summary (or a pointer to it) naming the tech stack. Both are pointers, not ground truth — verify against the actual manifests and lockfiles before running anything.

## How it works

Detect from the real manifests, don't assume — every tool named below is an example only (tech-agnostic rule); use whatever the repo's own files establish.

1. **Identify the stack per project/workspace.** For a monorepo, install once at the workspace root unless a package needs isolated setup.
2. **Node** — the lockfile decides the package manager: `pnpm-lock.yaml` → `pnpm install`, `package-lock.json` → `npm ci` (fall back to `npm install`), `yarn.lock` → `yarn install`. No lockfile → prefer pnpm. Respect the workspace root; don't install per-package in a monorepo that hoists.
3. **Go** — `go mod download`; note the Go version required by `go.mod` (and its `toolchain` directive if present).
4. **Python** — create a `.venv` inside the project and install from `pyproject.toml`/`requirements.txt` via whichever tool the repo's own config indicates (uv, poetry, pip) — don't introduce a different one.
5. **Other stacks** — follow whatever the repo's docs/manifests establish; if genuinely undetectable, say so rather than guessing.
6. **Respect pinned versions exactly** — `engines` fields, `.nvmrc`, `go.mod` toolchain, `requires-python`, etc. Never upgrade a dependency or regenerate a lockfile to make an install succeed.
7. **Verify success.** The install must exit clean, and a trivial toolchain command should work (e.g. a cheap build/typecheck dry run) as evidence the environment is actually usable. Report failures honestly — a failed or partial install is not success, don't paper over it.

## Hand-off / next

Return contract: as a fork you cannot invoke the next phase yourself — your final report IS the hand-off. Return what was detected (stack, versions), what was installed or created (package manager used, versions, `.venv` path, etc.), and anything that failed or was skipped and why. Recommended next step: `dev-plan` (orchestrated) or whatever the caller was doing.

## Notes

- Never modify manifests or lockfiles — setup only, no upgrades, no regeneration.
- Never install global tools without flagging it clearly in your report.
- If the stack can't be determined from the manifests, say so plainly and recommend a deeper `dev-explore` rather than guessing at a toolchain.
