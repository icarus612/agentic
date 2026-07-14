---
name: component-testing
description: The testing contract — every component, store, and load function ships with a behavioural test using Vitest + Testing Library.
domain: svelte
---

# Component testing contract

Testing is part of the implementation, not a later step. Every new component, store, action, utility, and load function ships with an accompanying test.

- **Tooling.** Vitest as the runner, `@testing-library/svelte` for rendering, `@testing-library/user-event` for interaction. Tests are `*.test.ts` (or `*.spec.ts`) living beside the source file.
- **Test behaviour, not implementation.** Assert what the user observes, never internal reactive state.
- **Query by accessible role/text.** Prefer `getByRole`, `getByText`, `getByLabelText`. Do not reach for `getByTestId` unless nothing accessible exists.
- **One behaviour per `it()`.** Keep each case focused on a single observable outcome.
- **Cover the edges.** Happy path, then empty/null/undefined inputs, then error and loading states.
- **Mock only at boundaries.** Mock network/API modules and external services — never internal functions. No real network calls in unit tests.
- **No snapshot-only tests.** Snapshots supplement behavioural assertions, they do not replace them.

A component is not complete until its test exists and the full suite passes.
