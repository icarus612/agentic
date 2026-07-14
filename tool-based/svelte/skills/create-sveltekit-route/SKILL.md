---
name: create-sveltekit-route
description: Use when adding or changing a SvelteKit route — route tree, server vs universal load, +server.ts endpoints, form actions, hooks, route groups, layouts, and error pages.
domain: svelte
rules: [use-runes]
model: sonnet
model-fallback: [gemini-pro]
---

# create-sveltekit-route

Add routes to a SvelteKit 2 app. The filesystem is the router; each special file has one job.

## Route tree

```
src/routes/
├── +layout.svelte          # Root layout (nav, footer)
├── +page.svelte            # Homepage
├── +error.svelte           # Error boundary
├── (public)/               # Route group — no URL segment
│   ├── +layout.svelte      # Shared layout for the group
│   ├── about/+page.svelte           → /about
│   └── contact/
│       ├── +page.svelte
│       └── +page.server.ts # Form actions / server data
└── api/
    └── health/+server.ts   # JSON endpoint
```

## Load functions — server vs universal

- **`+page.server.ts` / `+layout.server.ts`** run only on the server. Use for secrets, cookies, database access, and internal URLs.
- **`+page.ts` / `+layout.ts`** (universal) run on server and client. Use for public data safe to fetch on client navigation.

```typescript
// +page.server.ts — server-only
import type { PageServerLoad } from './$types';
import { error } from '@sveltejs/kit';

export const load: PageServerLoad = async ({ params, cookies, fetch }) => {
  const res = await fetch(`/internal/items/${params.id}`);
  if (!res.ok) throw error(404, 'Not found');
  return { item: await res.json() };
};
```

```typescript
// +page.ts — universal
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ fetch, params }) => {
  const res = await fetch(`/api/items/${params.slug}`);
  return { item: await res.json() };
};
```

**Choose:** needs secrets/cookies/internal URLs → `.server`; public and navigable → universal.

**Data flow:** `+layout.server.ts` (guards) → `+layout.ts` (shared) → `+page.ts` (page) → `+page.svelte` (render). Load data in `load`, never in a `$effect` inside `+page.svelte`.

## API endpoints (`+server.ts`)

```typescript
import { json, error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ url, locals }) => {
  if (!locals.user) throw error(401, 'Unauthorized');
  return json({ data: [] });
};

export const POST: RequestHandler = async ({ request }) => {
  const body = await request.json();
  if (!body.name) throw error(400, 'Name required');
  return json({ success: true }, { status: 201 });
};
```

## Form actions

```typescript
// +page.server.ts
import type { Actions } from './$types';
import { fail } from '@sveltejs/kit';

export const actions: Actions = {
  create: async ({ request }) => {
    const data = await request.formData();
    const name = data.get('name')?.toString().trim();
    if (!name) return fail(400, { error: 'Name is required', name });
    return { success: true };
  }
};
```

```svelte
<!-- +page.svelte -->
<script lang="ts">
  import { enhance } from '$app/forms';
</script>

<form method="POST" action="?/create" use:enhance>
  <input name="name" required />
  <button type="submit">Create</button>
</form>
```

## Hooks

- **`hooks.server.ts`** — per-request server processing (auth from cookies into `event.locals`, headers).
- **`hooks.client.ts`** — client-side initialisation of libraries.

```typescript
// src/hooks.server.ts
import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  const token = event.cookies.get('access_token');
  if (token) event.locals.user = await validateToken(token);
  return resolve(event);
};
```

## Route groups & layouts

`(name)/` groups routes without adding a URL segment — use them to share a layout or apply an auth guard to a subtree. Put group-wide guards in the group's `+layout.server.ts`.

```svelte
<!-- +layout.svelte -->
<script lang="ts">
  import type { Snippet } from 'svelte';
  let { children }: { children: Snippet } = $props();
</script>

<nav><!-- … --></nav>
<main>{@render children()}</main>
```

## Per-route metadata

Set page metadata with `<svelte:head>` in `+page.svelte`. For full meta/OG/JSON-LD, use `add-seo-metadata`.

```svelte
<svelte:head>
  <title>About</title>
  <meta name="description" content="…" />
</svelte:head>
```

## Error pages

```svelte
<!-- +error.svelte -->
<script lang="ts">
  import { page } from '$app/state';
</script>

<h1>{page.status}</h1>
<p>{page.error?.message ?? 'Something went wrong'}</p>
<a href="/">Go home</a>
```

## Testing routes

Test `load` by mocking `fetch` and asserting the returned data shape; test endpoints with mocked request objects; cover error paths (404, 500) and auth guards.
