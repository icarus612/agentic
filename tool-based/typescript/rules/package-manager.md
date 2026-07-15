---
name: package-manager
description: pnpm is the only package manager for JS/Node projects — always use pnpm, never npm or yarn, even overriding an existing non-pnpm lockfile.
domain: typescript
---

# Package manager: pnpm only

- **Always use pnpm** for every JS/Node project: `pnpm install`, `pnpm add`,
  `pnpm remove`, `pnpm run`, `pnpm dlx`. Never invoke `npm` or `yarn` commands.
- **No lockfile is an exception.** This holds even when a project already has
  a `package-lock.json` or `yarn.lock` — those are the wrong package manager
  for this workflow, not a constraint to defer to. Convert: remove the
  non-pnpm lockfile and generate `pnpm-lock.yaml` in its place. Don't maintain
  two lockfiles side by side.
- **Confirm before converting an existing project.** Switching an established
  project's package manager touches every contributor's workflow and deletes
  a committed lockfile — flag it and get explicit confirmation before removing
  `package-lock.json`/`yarn.lock`, per the general rule on hard-to-reverse
  actions. A brand-new project with no lockfile needs no confirmation — pnpm
  is simply the default.
- Applies to plain JavaScript projects too, not just TypeScript — this rule
  loads for the whole JS/Node domain (see the domain's `AGENTS.md`).
