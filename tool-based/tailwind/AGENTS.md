# JavaScript · Styles — stack instructions

Conventions for styling web UIs with Tailwind CSS 4 and DaisyUI 5. Tailwind 4 is
CSS-first (`@theme`/`@plugin`/`@source`, no `tailwind.config.js`); themed elements
use DaisyUI semantic tokens so they follow the active theme; layouts are authored
mobile-first; and animation is restricted to GPU-composited properties with
mandatory cleanup. Design-token values (colors, fonts, radii) are always the
project's own — this stack covers the framework mechanics, not any one palette.

## Rules
- **mobile-first** — base styles target the smallest viewport; breakpoints only
  escalate upward (`sm:`→`2xl:`); interactive targets are ≥ 44×44px; no
  horizontal scroll on mobile.
- **animation-performance** — animate only `transform`/`opacity`; always tear
  down observers/listeners/timers; keep `will-change` transient; reduce work on
  mobile; honor `prefers-reduced-motion`.

## Skills
- **style-with-tailwind** — style a component with Tailwind 4 CSS-first config
  (`@theme`/`@source`/`@plugin`), DaisyUI 5 component classes, semantic theme
  colors, and theme-driven dark mode (mechanics only).
- **build-responsive-layout** — compose mobile-first page layouts (hero, card
  grid, mobile-drawer/desktop-bar nav) plus responsive images.
