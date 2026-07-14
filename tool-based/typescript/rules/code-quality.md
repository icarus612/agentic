---
name: code-quality
description: JS/TS code-quality laws — naming conventions, constants over magic numbers, errors at boundaries, no dead code/stray logs, import order.
domain: typescript
---

# Code quality

## Naming

| Entity | Convention | Example |
|--------|-----------|---------|
| Variables / functions | camelCase | `getUserProfile`, `isVisible` |
| Types / interfaces | PascalCase | `CartItem`, `UserResponse` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT`, `API_BASE_URL` |
| Files | kebab-case | `format-price.ts`, `user-store.ts` |

- Use meaningful names: `userId` not `id`, `itemCount` not `n`, `isVisible` not
  `flag`.

## Constants over magic numbers

- Define a named constant for every numeric or string literal that carries
  meaning (durations, sizes, thresholds, counts, URLs). No bare literals in
  logic: `const DEBOUNCE_DELAY_MS = 200` then use the name.

## Errors at boundaries

- Handle errors explicitly — never swallow a promise or empty-`catch`.
- Wrap `try/catch` at boundary points (network calls, file I/O, parsing), not
  deep inside business logic.
- Prefer returning typed error states from utility functions over throwing.
- Log meaningful context alongside the error.

## Code hygiene

- No commented-out code — delete it; version control is the history.
- No stray debugging `console.log` in committed code (deliberate structured or
  conditional logging is fine).
- No placeholder or half-implemented functions — implement fully or omit.
- Every `TODO` names an owner or ticket: `// TODO(owner): reason`.
- No secrets in code — read them from environment variables only.

## Import order

1. Node built-ins and external packages.
2. Internal path aliases (e.g. `@/`, `$lib/`).
3. Relative imports (`./`, `../`).

Separate each group with a blank line.
