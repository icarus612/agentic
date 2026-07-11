---
name: type-safely
description: Procedures and examples for TypeScript type guards, discriminated unions, generic utility types, and typing external/API responses — use when modelling unknown data or variant state safely.
type: stack
domain: node
rules: [typescript-strict, code-quality]
model: sonnet
model-fallback: [gemini-pro]
---

# type-safely

How to build strong types without reaching for `any` or `as`. Pure TypeScript —
applies to any Node/TS project.

## Typing external API responses

Define an `interface` for the shape you expect, and a generic wrapper for
list/paged envelopes. Keep raw responses `unknown` until narrowed (see type
guards below).

```typescript
interface User {
  id: string;
  name: string;
  email: string | null;
}

// Reusable envelope for paginated list endpoints.
interface ListResponse<T> {
  data: T[];
  count: number;
  offset: number;
  limit: number;
}

async function fetchUsers(): Promise<ListResponse<User>> {
  const response = await fetch("/api/users");
  const body: unknown = await response.json();
  // narrow `body` with a guard before trusting it — see below
  return body as ListResponse<User>; // only after validation in real code
}
```

## Type guards

A guard is a function returning `value is T`. Use it to narrow `unknown` at the
boundary instead of asserting with `as`.

```typescript
function isUser(value: unknown): value is User {
  return (
    typeof value === "object" &&
    value !== null &&
    "id" in value &&
    "name" in value
  );
}

const data: unknown = await response.json();
if (isUser(data)) {
  console.log(data.name); // safe: narrowed to User
}
```

Prefer built-in narrowing where it applies — `typeof`, `Array.isArray`, and
`instanceof` — over a hand-written guard:

```typescript
const el = document.getElementById("target");
if (el instanceof HTMLInputElement) {
  el.value = ""; // narrowed, no `as HTMLInputElement`
}
```

## Discriminated unions

Give each variant a shared literal tag so the compiler forces exhaustive
handling and knows which fields exist in each branch.

```typescript
type AsyncState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; error: string };

function describe(state: AsyncState<User>): string {
  switch (state.status) {
    case "idle":
      return "Ready";
    case "loading":
      return "Loading…";
    case "success":
      return state.data.name; // `.data` known to exist here
    case "error":
      return state.error; // `.error` known to exist here
  }
}
```

For exhaustiveness, add a `default` branch that assigns to `never`; adding a new
variant then fails to compile until it is handled:

```typescript
default: {
  const _exhaustive: never = state;
  return _exhaustive;
}
```

## Generic utility types

Compose the built-ins (`Pick`, `Omit`, `Partial`, `Record`) and write small
reusable helpers rather than repeating shapes.

```typescript
// Make specific keys optional (e.g. for partial-update payloads).
type PartialBy<T, K extends keyof T> = Omit<T, K> & Partial<Pick<T, K>>;

type UserUpdate = PartialBy<User, "email">; // id, name required; email optional

// Extract the element type of an array.
type ElementOf<T> = T extends readonly (infer E)[] ? E : never;
```

## Verifying types

- Use `satisfies` to check a value conforms to a type without widening it:
  `const config = { retries: 3 } satisfies Config;`.
- For utility-type correctness, write type-level tests (e.g. `expectTypeOf` from
  Vitest).

> Framework-specific typing (e.g. Svelte component props, React props) belongs to
> that framework's stack, not here.
