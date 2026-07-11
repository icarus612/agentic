---
name: write-component-test
description: Use when writing a Vitest + Testing Library test for a Svelte 5 component, store, or load function — render, user interaction, store assertions, and mocking at boundaries.
type: stack
domain: svelte
rules: [component-testing, accessibility]
model: sonnet
model-fallback: [gemini-pro]
---

# write-component-test

Write behavioural tests with Vitest and `@testing-library/svelte`. See `component-testing` for the contract; this is the procedure.

## Placement

Tests sit beside the source file: `card.svelte → card.test.ts`, `cart.ts → cart.test.ts`.

## Render + assert

```typescript
import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import CardViewer from './card-viewer.svelte';

describe('CardViewer', () => {
  it('renders with required props', () => {
    render(CardViewer, { props: { title: 'Example', imageUrl: '/example.png' } });

    expect(screen.getByText('Example')).toBeInTheDocument();
    expect(screen.getByRole('img')).toHaveAttribute('src', '/example.png');
  });

  it('applies defaults for optional props', () => {
    render(CardViewer, { props: { title: 'Example', imageUrl: '/example.png' } });
    expect(screen.queryByText('Featured')).not.toBeInTheDocument();
  });
});
```

## User interaction

Drive the UI through `@testing-library/user-event`; query by role.

```typescript
import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import Counter from './counter.svelte';

describe('Counter', () => {
  it('increments on click', async () => {
    const user = userEvent.setup();
    render(Counter, { props: { initial: 0 } });

    await user.click(screen.getByRole('button', { name: /increment/i }));
    expect(screen.getByText('1')).toBeInTheDocument();
  });

  it('calls the onchange callback', async () => {
    const user = userEvent.setup();
    const onchange = vi.fn();
    render(Counter, { props: { initial: 0, onchange } });

    await user.click(screen.getByRole('button', { name: /increment/i }));
    expect(onchange).toHaveBeenCalledWith(1);
  });
});
```

## Store tests

Reset state between cases, mutate through the public API, assert the resulting state.

```typescript
import { get } from 'svelte/store';
import { describe, it, expect, beforeEach } from 'vitest';
import { cartStore, addToCart, removeFromCart } from './cart';

describe('cart store', () => {
  beforeEach(() => cartStore.set({ items: [], total: 0 }));

  it('adds an item', () => {
    addToCart({ id: '1', name: 'Widget', price: 499 });
    expect(get(cartStore).items).toHaveLength(1);
  });

  it('removes an item', () => {
    addToCart({ id: '1', name: 'Widget', price: 499 });
    removeFromCart('1');
    expect(get(cartStore).items).toHaveLength(0);
  });
});
```

## Mocking at boundaries

Mock the API/service module, never internal functions. No real network in unit tests.

```typescript
import { vi } from 'vitest';

vi.mock('$lib/api/client', () => ({
  fetchItems: vi.fn().mockResolvedValue({ items: [{ id: '1', name: 'Widget' }] }),
}));
```

Test `load` functions the same way — mock the injected `fetch`, call `load`, assert the returned data shape and the error paths.

## Guidelines

- Assert what the user sees, not internal reactive state.
- `getByRole` / `getByText` / `getByLabelText` before `getByTestId`.
- One behaviour per `it()`; cover happy path, empty/null, and error states.
