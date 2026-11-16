# Vitest — stack instructions

Conventions for projects whose test runner is Vitest.

## Rules
- **vitest-changed-tests** — iterate with affected-only runs
  (`vitest --run --changed <base>`, `vitest related --run <files>`); the full
  suite runs once, at integration, before a PR goes ready.
