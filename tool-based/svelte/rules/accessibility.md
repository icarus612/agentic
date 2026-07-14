---
name: accessibility
description: Accessibility musts — semantic HTML first, keyboard operability, ARIA only when needed, reduced motion, contrast, and alt text.
domain: svelte
---

# Accessibility musts

- **Semantic HTML first.** Use `<button>` for actions, `<a>` for navigation, and landmark elements (`<nav>`, `<main>`, `<section>`, `<article>`, `<aside>`). Never `<div onclick>` for an interactive control.
- **One `<h1>` per page, sequential headings.** Never skip levels; size visually with CSS, not by choosing the wrong tag.
- **Keyboard operable.** Every interactive element is reachable and usable via Tab/Enter/Space; dialogs and dropdowns close on Escape and manage focus. Use `tabindex="0"` only to make a genuinely-interactive non-standard element focusable, `tabindex="-1"` for programmatic focus.
- **ARIA only when semantics are insufficient.** Prefer native elements; add `aria-*` (e.g. `aria-expanded`, `aria-controls`, `aria-label`, `aria-modal`) only to fill gaps native HTML cannot. Never override correct native roles.
- **Respect reduced motion.** Honour `prefers-reduced-motion`, both in CSS and when conditionally rendering animation (`matchMedia('(prefers-reduced-motion: reduce)')`).
- **Colour contrast.** Meet WCAG AA — 4.5:1 for body text, 3:1 for large/bold text. Never signal state by colour alone.
- **Alt text.** Informative images get descriptive `alt`; decorative images get `alt=""` (plus `aria-hidden="true"`).
- **Verify via roles.** Accessibility is testable — assert roles with `getByRole` and exercise keyboard flows in tests.
