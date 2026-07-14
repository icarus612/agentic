---
name: animation-performance
description: Animate only GPU-composited properties (transform/opacity), always tear down animation resources, manage will-change transiently, reduce work on mobile, and honor prefers-reduced-motion.
domain: tailwind
---

# Animation performance

- **Animate only `transform` and `opacity`.** These are GPU-composited and skip
  layout/paint. Never animate `top`/`left`/`width`/`height`/`margin`/`padding`
  (triggers layout) or `background-color`/`color` (triggers paint); express the
  same motion with `translate`/`scale`/`rotate` and fades instead.
- **Cleanup is mandatory.** Every animation resource created must be torn down in
  the same lifecycle scope: `IntersectionObserver.disconnect()`,
  `removeEventListener()`, `clearInterval`/`clearTimeout`,
  `cancelAnimationFrame()`. A setup without a matching teardown is a leak.
- **Detect visibility with `IntersectionObserver`, not scroll listeners.**
  Reserve scroll listeners for genuinely continuous tracking (e.g. parallax),
  and when one is unavoidable, throttle it with `requestAnimationFrame` (a single
  `ticking` guard) — never run work on every scroll event.
- **`will-change` is transient, never permanent.** It reserves GPU memory. Apply
  it when an animation starts (or on hover) and remove it on `transitionend` /
  `animationend`. Do not leave it declared statically in CSS.
- **Reduce work on mobile.** Cut particle counts and concurrent animations,
  simplify 3D transforms to 2D, and defer non-essential motion until after first
  paint. Mobile Safari/Firefox have strict GPU-memory limits and will reload
  tabs under pressure.
- **Honor `prefers-reduced-motion: reduce`.** Provide a static fallback that
  effectively disables non-essential animation for users who request it; never
  ship motion that ignores this query.
