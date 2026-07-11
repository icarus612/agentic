---
name: build-responsive-layout
description: Build a mobile-first responsive layout with Tailwind 4 + DaisyUI — hero, card grid, and mobile-drawer/desktop-bar navigation patterns, plus responsive images. Use when composing page structure across breakpoints.
type: stack
domain: styles
rules: [mobile-first]
model: sonnet
model-fallback: [gemini-pro]
---

# build-responsive-layout

Compose page-level layouts that work from the smallest phone up. Always author
the base (mobile) layout first, then escalate with min-width breakpoint prefixes
(`sm:` 640 · `md:` 768 · `lg:` 1024 · `xl:` 1280 · `2xl:` 1536).

## Card grid — density scales with viewport

Start at one column; add columns as width allows. Let the same markup grow
denser instead of restructuring per breakpoint.

```html
<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 md:gap-6 p-4">
  <!-- cards -->
  <div class="card bg-base-200 shadow">…</div>
</div>
```

## Hero — fluid height and type

Scale the section's min-height and the heading type ramp across breakpoints;
keep content centered and width-capped.

```html
<section class="hero min-h-[60vh] md:min-h-[80vh]">
  <div class="hero-content text-center max-w-4xl mx-auto px-4">
    <h1 class="text-3xl sm:text-4xl lg:text-6xl font-bold">Headline</h1>
    <p class="text-base sm:text-lg mt-4">Supporting copy.</p>
  </div>
</section>
```

## Navigation — mobile drawer, desktop bar

Use DaisyUI's `drawer` with `lg:drawer-open`: a slide-out drawer on small
screens, a persistent sidebar on large. Toggle visibility of the hamburger with
`lg:hidden`.

```html
<div class="drawer lg:drawer-open">
  <input id="nav-drawer" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">
    <!-- Hamburger only below lg -->
    <label for="nav-drawer" class="btn btn-ghost lg:hidden min-h-11 min-w-11">☰</label>
    <!-- main content -->
  </div>
  <div class="drawer-side">
    <label for="nav-drawer" class="drawer-overlay"></label>
    <nav class="menu bg-base-200 w-64 min-h-full p-4">
      <!-- nav links -->
    </nav>
  </div>
</div>
```

For a top bar instead, DaisyUI `navbar` splits into `navbar-start` /
`navbar-center` / `navbar-end`; collapse the center links behind the hamburger
below `lg`.

## Responsive images

Serve a right-sized asset per viewport and reserve space to prevent layout shift.
Set intrinsic `width`/`height`, `max-w-full` (via `w-full h-auto`), and
`loading="lazy"` for below-the-fold images (`eager` + `fetchpriority="high"` for
the above-the-fold hero image).

```html
<img
  src="/img/hero-800.webp"
  srcset="/img/hero-400.webp 400w, /img/hero-800.webp 800w, /img/hero-1200.webp 1200w"
  sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw"
  width="1200" height="800"
  alt="…"
  loading="lazy"
  class="w-full h-auto object-cover rounded-box"
/>
```

## Touch targets

Every tappable control meets the 44×44px minimum (`min-h-11 min-w-11` or a
sufficiently padded `btn`). This is non-negotiable on the mobile base layout.

## Verify

- Resize through each breakpoint and confirm the layout escalates cleanly.
- Confirm no horizontal scroll appears at the smallest width.
- Confirm interactive targets are ≥ 44×44px.
- Test on a real device where possible, not just a resized desktop window.
