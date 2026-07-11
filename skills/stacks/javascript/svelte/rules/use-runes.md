---
name: use-runes
description: Svelte 5 runes are required; Svelte 4 reactivity, lifecycle, slots, and event patterns are banned.
type: rule
domain: svelte
---

# Use Svelte 5 runes

Svelte 5 is used exclusively. Svelte 4 patterns are banned — treat each as a lint-level error.

- **State via `$state`.** `let count = $state(0)` — never a bare `let count = 0` for reactive values, and never `writable()`/`readable()` stores for local state.
- **Computed via `$derived`.** `let doubled = $derived(count * 2)`; use `$derived.by(() => …)` for multi-statement derivations. Never `$: doubled = …`.
- **Side effects via `$effect`.** `$effect` replaces both `onMount` and reactive-statement side effects; return a cleanup function to replace `onDestroy`. Never import `onMount`/`onDestroy`. Do NOT use `$effect` to compute values — that is `$derived`'s job.
- **Props via `$props`.** `let { name, value = 'default' }: Props = $props()` — never `export let`. Type props with an `interface`/type at the top of the script.
- **Two-way binding via `$bindable`.** `let { value = $bindable('') }: Props = $props()`.
- **Content via snippets, not slots.** Accept `children`/named `Snippet` props and render with `{@render children?.()}`; callers pass `{#snippet name()}…{/snippet}`. Never `<slot>` / `<slot name="…">`.
- **Events are plain callback props and lowercase DOM attributes.** `onclick={handler}`, `oninput={…}`. Never `on:click`, never `createEventDispatcher()`.

## Banned → required quick reference

| Svelte 4 (banned) | Svelte 5 (required) |
|---|---|
| `export let prop` | `let { prop } = $props()` |
| `$: derived = x * 2` | `let derived = $derived(x * 2)` |
| `$: { sideEffect() }` | `$effect(() => { sideEffect() })` |
| `onMount(() => {})` | `$effect(() => {})` |
| `onDestroy(() => {})` | `$effect(() => () => cleanup())` |
| `<slot />` | `{@render children?.()}` |
| `<slot name="x" />` | `{@render x?.()}` + `{#snippet x()}` |
| `on:click={handler}` | `onclick={handler}` |
| `createEventDispatcher()` | callback props |
| `import { writable }` (local state) | `let x = $state(value)` |
