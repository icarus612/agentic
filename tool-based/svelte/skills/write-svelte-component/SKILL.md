---
name: write-svelte-component
description: Use when creating or modifying a Svelte 5 component — runes API, props/state/derived/effect, snippets, event forwarding, and $bindable two-way binding.
domain: svelte
rules: [use-runes, accessibility, component-testing]
model: sonnet
model-fallback: [gemini-pro]
---

# write-svelte-component

Build a Svelte 5 component with the runes API. Follow `use-runes` for the laws; this is the how-to.

## Component structure

Keep the script in this order: types, then props, then state, then derived, then effects, then template, then scoped styles.

```svelte
<script lang="ts">
  // 1. Types
  interface Props {
    title: string;
    count?: number;
    onAction?: (id: string) => void;
  }

  // 2. Props with defaults
  let { title, count = 0, onAction }: Props = $props();

  // 3. Local state
  let isExpanded = $state(false);

  // 4. Derived values (NOT $effect)
  let displayCount = $derived(`${count} items`);

  // 5. Effects with cleanup
  $effect(() => {
    const handler = () => {/* … */};
    window.addEventListener('resize', handler);
    return () => window.removeEventListener('resize', handler);
  });
</script>

<!-- 6. Template -->
<section>
  <h2>{title}</h2>
  <span>{displayCount}</span>
</section>

<!-- 7. Scoped styles, only if utility classes are insufficient -->
<style>
</style>
```

## Runes reference

```typescript
// Inputs
let { label, value = 0 }: Props = $props();

// Reactive local state
let count = $state(0);
let items = $state<string[]>([]);

// Computed — replaces `$:`
let doubled = $derived(count * 2);
let summary = $derived.by(() => (items.length ? items.join(', ') : 'empty'));

// Side effects with cleanup — replaces onMount/onDestroy
$effect(() => {
  const observer = new IntersectionObserver(callback);
  observer.observe(element);
  return () => observer.disconnect();
});

// Two-way binding
let { value = $bindable('') }: Props = $props();
```

## Snippets (replace slots)

Accept `Snippet` props and render them; callers supply `{#snippet}` blocks.

```svelte
<!-- Card.svelte -->
<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    header?: Snippet;
    children?: Snippet;
  }
  let { header, children }: Props = $props();
</script>

<div class="card">
  {#if header}{@render header()}{/if}
  {@render children?.()}
</div>
```

```svelte
<!-- Caller -->
<Card>
  {#snippet header()}<h2>Title</h2>{/snippet}
  <p>Default content (children)</p>
</Card>
```

Named snippets can take arguments: `header?: Snippet<[string]>` rendered with `{@render header(value)}`.

## Event forwarding

Events are callback props plus lowercase DOM attributes — no `on:` directives, no dispatchers.

```svelte
<script lang="ts">
  interface Props {
    onclick?: (e: MouseEvent) => void;
  }
  let { onclick }: Props = $props();
</script>

<button {onclick}>Click me</button>
```

## Polymorphic component (dynamic tag)

```svelte
<script lang="ts">
  import type { Snippet } from 'svelte';
  import type { SvelteHTMLElements } from 'svelte/elements';

  type Tag = keyof SvelteHTMLElements;

  interface Props {
    as?: Tag;
    children?: Snippet;
    class?: string;
  }
  let { as: Element = 'div', children, class: className = '' }: Props = $props();
</script>

<svelte:element this={Element} class={className}>
  {@render children?.()}
</svelte:element>
```

## Finishing

- Reach for semantic HTML and accessible markup per the `accessibility` rule.
- Write the companion test immediately (per `component-testing`): renders with required props, applies defaults, responds to interaction, cleans up effects on unmount, handles empty/null edge cases.
