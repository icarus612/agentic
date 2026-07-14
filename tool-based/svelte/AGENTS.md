# JavaScript · Svelte — stack instructions

Conventions, patterns, and defaults for Svelte 5 / SvelteKit 2 apps. Components use
the runes API exclusively (`$state`, `$derived`, `$effect`, `$props`, `$bindable`) with
snippets in place of slots and callback props in place of event dispatchers. Routing is
filesystem-based: `load` functions fetch data (server vs universal by whether secrets are
involved), `+server.ts` exposes endpoints, and form actions handle mutations. Every
component ships with a Vitest + Testing Library test, and accessibility is a baseline, not
an add-on.

## Rules
- **use-runes** — Svelte 5 runes required; Svelte 4 reactivity, lifecycle, slots, and
  `on:`/dispatcher event patterns are banned (with a banned→required table).
- **component-testing** — the testing contract: every component, store, and load function
  ships with a behavioural Vitest + Testing Library test, queried by accessible role, mocked
  only at boundaries.
- **accessibility** — musts: semantic HTML first, keyboard operability, ARIA only when
  needed, reduced motion, AA contrast, and alt text.

## Skills
- **write-svelte-component** — build a component with the runes API: script ordering,
  `$props`/`$state`/`$derived`/`$effect`, snippets, event forwarding, `$bindable`, and
  polymorphic tags.
- **create-sveltekit-route** — add a route: route tree, server vs universal `load`,
  `+server.ts` endpoints, form actions, hooks, route groups, layouts, and error pages.
- **write-component-test** — the Vitest + Testing Library procedure: render, user
  interaction, store assertions, and mocking `fetch`/API modules at the boundary.
- **add-seo-metadata** — `<svelte:head>` meta/OG/Twitter, canonical URLs, JSON-LD structured
  data, and a Core Web Vitals checklist.
