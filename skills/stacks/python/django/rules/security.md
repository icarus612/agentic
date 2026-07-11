---
name: security
description: Web/Django security musts — parameterized ORM only, no eval/exec, secrets in env, auth tokens in httpOnly cookies, encrypt sensitive-at-rest, validate all inputs.
type: rule
domain: django
---

# Django security

- **Parameterized queries only.** Use the Django ORM, which parameterizes
  automatically. Never build SQL with string formatting/concatenation. If raw
  SQL is unavoidable, use parameter binding (`params=[...]`), never f-strings or
  `%`-interpolation of user input.
- **Never `eval()`/`exec()`/`pickle` untrusted input.** Do not execute or
  deserialize user-controlled data.
- **Validate all input through serializers.** Never trust raw `request.data`;
  run it through a DRF serializer. Strip null bytes, trim whitespace, and enforce
  length bounds. Use URL converters (`<uuid:id>`, `<int:page>`) for path params
  and coerce/validate query params defensively.
- **Secrets live in the environment, never in source.** `SECRET_KEY`, signing
  keys, encryption keys, and third-party credentials come from env/`.env` (never
  committed). Never hardcode secrets and never log them, even in debug.
- **Auth tokens in httpOnly cookies.** Store session/JWT tokens in `HttpOnly`,
  `Secure`, `SameSite=Lax` cookies — never in `localStorage`, `sessionStorage`,
  JS-readable variables, or URL parameters. Enable HSTS in production.
- **Encrypt sensitive data at rest.** Hash passwords with Django's hashers
  (`make_password`/`check_password`). Encrypt API keys, third-party credentials,
  and regulated PII at rest (e.g. Fernet with a key from settings/env).
- **Enforce permissions server-side.** Authorization is always checked in
  `permission_classes` / `has_object_permission` on the server — never rely on
  the client to hide or gate access.
