---
name: server-boundaries
description: SvelteKit server-only code stays server-only — $lib/server is importable solely from server files; secrets never cross into the client bundle.
domain: svelte
---

# Server boundaries
Anything under `$lib/server/` (and `$env/static/private`, `$env/dynamic/private`) may be imported ONLY from server-only files: `+page.server.ts`, `+layout.server.ts`, `+server.ts`, hooks, or another `$lib/server/` module. Importing it from a component, a universal `+page.ts`, or any client-reachable module leaks secrets into the browser bundle — SvelteKit will fail the build, and working around that failure is never the fix.

Corollary: data reaches components through `load` return values and props, never by importing a server module. Keep API keys, database clients, and third-party secrets behind that line.
