---
name: style-with-tailwind
description: Style a component with Tailwind CSS 4 (CSS-first @theme config, @source/@plugin) and DaisyUI 5 — semantic theme colors over raw colors, DaisyUI component classes, and dark mode. Use when adding or restyling UI with Tailwind 4 + DaisyUI.
type: stack
domain: styles
rules: [mobile-first]
model: sonnet
model-fallback: [gemini-pro]
---

# style-with-tailwind

Style components with Tailwind CSS 4 and DaisyUI 5 using CSS-first
configuration. This covers the framework mechanics only — derive actual colors,
fonts, and radii from the project's own theme.

## Tailwind 4 is CSS-first — no `tailwind.config.js`

Tailwind 4 is configured in your CSS entry file, not a JS config. There is no
`tailwind.config.js` and no `@tailwind base/components/utilities` directives.

```css
/* app.css */
@import "tailwindcss";

/* @source: tell Tailwind to scan class names in files it can't infer,
   e.g. classes that live inside dependencies/packages. */
@source "../node_modules/<pkg>/src/**/*.{html,js,ts,svelte}";

/* @plugin: load a plugin (DaisyUI) and configure which themes are active. */
@plugin "daisyui" {
  themes: light --default, dark --prefersdark;
}

/* @theme: define design tokens as CSS variables. They generate utilities:
   --color-brand → bg-brand / text-brand / border-brand, etc. */
@theme {
  --color-brand: oklch(60% 0.15 250);
  --font-display: "<Your Font>", sans-serif;
  --radius-box: 1rem;
}
```

- `@import "tailwindcss";` replaces the three v3 `@tailwind` directives.
- `@theme { … }` replaces `theme.extend` from the old JS config. Tokens become
  utilities automatically (`--color-brand` → `bg-brand`).
- `@source` registers extra scan paths — needed when class names only appear in
  code Tailwind wouldn't otherwise see (third-party packages, generated files).
- `@plugin "daisyui" { … }` loads DaisyUI and selects its active themes.

## Custom DaisyUI theme

Define a theme with `@plugin "daisyui/theme"`, overriding DaisyUI's semantic
tokens. Name and values come from the project's design system.

```css
@plugin "daisyui/theme" {
  name: "<theme-name>";
  color-scheme: dark;         /* or light */
  --color-base-100: oklch(20% 0.02 260);
  --color-base-200: oklch(24% 0.02 260);
  --color-base-300: oklch(28% 0.02 260);
  --color-primary:  oklch(70% 0.20 300);
  --color-secondary: oklch(65% 0.18 20);
}
```

## Prefer semantic colors over raw colors

DaisyUI's semantic tokens adapt to the active theme; raw Tailwind palette colors
do not. Use semantic tokens for any element that should follow the theme.

```html
<!-- Theme-aware — adapts to light/dark automatically -->
<div class="bg-base-200 text-base-content">…</div>
<button class="btn btn-primary">Save</button>

<!-- Avoid on themed elements — frozen to one look -->
<div class="bg-gray-800 text-white">…</div>
```

Semantic backgrounds/text: `base-100` (page), `base-200` (raised surface),
`base-300` (borders/dividers), `primary`/`secondary`/`accent`/`neutral`, and the
status colors `info`/`success`/`warning`/`error`. Text-on-color uses the
`*-content` pairs (`text-primary-content`, `text-base-content`). Fade with the
opacity slash syntax: `text-base-content/70`.

## Semantic classes vs raw utilities — division of labor

| Concern | Use |
|---------|-----|
| Buttons, cards, modals, inputs, alerts, badges, navbar, drawer, menu | DaisyUI component classes (`btn`, `card`, `modal`, `input`, `alert`, `badge`) |
| Layout (flex, grid, gap, positioning) | Raw Tailwind (`flex`, `grid`, `gap-4`) |
| Spacing | Raw Tailwind (`p-4`, `m-2`, `space-y-4`) |
| Typography | Raw Tailwind (`text-lg`, `font-bold`, `leading-relaxed`) |
| Themed backgrounds/text | DaisyUI semantic tokens (`bg-base-100`, `text-primary`) |
| Responsive variants | Raw Tailwind prefixes (`md:grid-cols-2`, `lg:hidden`) |

If the project ships its own component library, reach for those components before
raw DaisyUI classes — drop to DaisyUI classes only for custom, one-off markup.

## Common DaisyUI components

```html
<!-- Button variants + sizes -->
<button class="btn btn-primary">Primary</button>
<button class="btn btn-outline btn-sm">Small outline</button>
<button class="btn btn-ghost">Ghost</button>

<!-- Card -->
<div class="card bg-base-200 shadow-lg">
  <div class="card-body">
    <h2 class="card-title">Title</h2>
    <p>Content</p>
    <div class="card-actions justify-end">
      <button class="btn btn-primary">Action</button>
    </div>
  </div>
</div>

<!-- Modal (native <dialog>) -->
<dialog class="modal" id="my-modal">
  <div class="modal-box">
    <h3 class="text-lg font-bold">Title</h3>
    <div class="modal-action">
      <form method="dialog"><button class="btn">Close</button></form>
    </div>
  </div>
  <form method="dialog" class="modal-backdrop"><button>close</button></form>
</dialog>

<!-- Badges & alerts (status via semantic colors) -->
<span class="badge badge-primary">Active</span>
<div class="alert alert-success">Saved!</div>
<div class="alert alert-error">Something went wrong.</div>
```

## Dark mode

DaisyUI drives dark mode through the active theme, not Tailwind's `dark:` variant.
Register a light and a dark theme in the `@plugin "daisyui"` block:

```css
@plugin "daisyui" {
  themes: light --default, dark --prefersdark;
}
```

- `--default` is the fallback theme.
- `--prefersdark` is applied when the OS requests dark mode.
- Switch themes at runtime by setting `data-theme="<name>"` on `<html>`.

Because every surface uses semantic tokens, the same markup follows the active
theme with no per-element dark overrides.

## Rules of thumb

1. Component classes first, raw utilities for layout/spacing/typography.
2. Semantic theme colors, never hardcoded hex on themed elements.
3. Mobile-first responsive class ordering (see the `mobile-first` rule).
4. No inline `style=` except values computed at runtime.
5. Configure everything in CSS (`@theme`/`@plugin`/`@source`) — never a JS config.
