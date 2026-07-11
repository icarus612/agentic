# Python · Django — stack instructions

Conventions specific to Django 5 / Django REST Framework projects. Layers on top
of `python/generic`. Resources are built in a fixed layering (model → serializer
→ viewset → urls), with UUID primary keys, soft-delete over hard-delete, and
queries that avoid N+1 by eager-loading relations.

## Rules
- **django-conventions** — model→serializer→viewset→urls layering; UUID PKs;
  timestamps; soft-delete; `select_related`/`prefetch_related` to avoid N+1;
  explicit serializer fields; permissions on every viewset; migration discipline.
- **security** — parameterized ORM only (never string-built SQL); no
  `eval`/`exec`/unpickling untrusted input; secrets in env; auth tokens in
  httpOnly cookies; encrypt sensitive data at rest; validate all input via
  serializers; enforce permissions server-side.

## Skills
- **create-django-resource** — scaffold a new DRF resource end-to-end (model,
  serializer, viewset, URL wiring, migration) following the standard layering.
