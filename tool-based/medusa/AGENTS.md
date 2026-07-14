# MedusaJS — stack instructions

Conventions and defaults for any project using **MedusaJS 2.x** as its commerce
backend.

- **Storefront talks to Medusa over HTTP only.** A storefront app imports the
  Medusa JS SDK and calls the Store API; it never imports backend source
  directly, and never reaches into Medusa's database.
- **Publishable API key is required** on every Store API request. It scopes the
  request to a sales channel. Keep it in the storefront's env, not hardcoded.
- **Custom backend logic lives in modules** (`src/modules/<name>/`), not in
  route handlers. Migrations are owned by the Medusa CLI — never hand-edit a
  generated migration.
- **Secrets stay server-side.** The admin/API key and any webhook secret are
  never exposed to the storefront bundle.

Skills: `medusa-api` (storefront integration — products, cart, checkout, auth).
