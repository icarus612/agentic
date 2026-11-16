---
name: vitest-changed-tests
description: In any project whose manifest uses Vitest, iterate with affected-only runs (`vitest --run --changed <base>` / `vitest related --run <files>`); the full suite runs once, at integration, before a PR goes ready.
domain: vitest
---

# Vitest: run changed tests, not the whole suite

This applies only when the project actually uses Vitest. Check the manifest; don't assume (`tech-agnostic`).

- **While iterating** (coders, contract-testers, builder lanes, ad-hoc fixes), run only the affected tests:
  - `vitest --run --changed <base-branch>`, which runs every test file that imports a changed file, directly or indirectly;
  - or `vitest related --run <file…>` for a specific packet.
  Call it through the project's package-manager runner (e.g. `pnpm exec vitest …`).
- **Following the import graph** is what keeps this safe: a change to a shared component still runs every consumer's tests.
- **The full suite runs once:** on the integrated branch, before the PR is marked ready. That run is the orchestrator's integration gate, never a per-iteration step.
- **Dispatches say so explicitly.** Any prompt that hands work to a builder or sub-agent names the `--changed` command as its test gate, not the bare full-suite script.
- `lint` and type checks are unaffected by this rule.
