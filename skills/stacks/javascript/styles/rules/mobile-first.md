---
name: mobile-first
description: Design mobile-first — base styles target the smallest viewport, breakpoints only escalate upward, and interactive targets are at least 44×44px.
type: rule
domain: styles
---

# Mobile-first responsive design

- **Base styles are the mobile layout.** Write unprefixed utilities for the
  smallest viewport first (single column, stacked). Never write a desktop layout
  and then shrink it down with `max-*` overrides.
- **Breakpoints only escalate upward.** Layer complexity with min-width prefixes
  in ascending order (`sm:` → `md:` → `lg:` → `xl:` → `2xl:`). Each prefix adds
  to the base; it never resets it. A responsive class list reads
  `grid-cols-1 sm:grid-cols-2 lg:grid-cols-4`, small to large.
- **Interactive targets are at least 44×44px.** Buttons, links, and any tappable
  control must meet the WCAG 2.5.5 minimum touch size (`min-h-11 min-w-11` or
  equivalent). Do not ship tap targets sized only for a mouse cursor.
- **No horizontal scroll on mobile.** The smallest viewport must never overflow
  its width. Constrain wide content (tables, code, media) inside its own
  scroll container rather than letting the page body scroll sideways.
- **Fluid by default.** Prefer relative widths (`w-full`, `max-w-*`, percentage
  or `fr` grid tracks) over fixed pixel widths so layouts adapt between
  breakpoints instead of jumping.
- **Images never cause layout shift.** Always set intrinsic `width`/`height` (or
  an `aspect-ratio` container) and `max-w-full`; use `srcset`/`sizes` so each
  viewport downloads an appropriately sized asset.
