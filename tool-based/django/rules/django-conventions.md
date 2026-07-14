---
name: django-conventions
description: Django 5 / DRF conventions — model→serializer→viewset→urls layering, UUID PKs, soft-delete, timestamps, N+1 avoidance, migration discipline.
domain: django
---

# Django 5 & DRF conventions

- **Layer every resource the same way.** A resource is defined across four files
  in a fixed order: `models.py` (data) → `serializers.py` (validation/shape) →
  `views.py` (viewset + permissions + queryset) → `urls.py` (router
  registration). Do not collapse layers or put business logic in views that
  belongs in models/serializers.
- **UUID primary keys, never auto-increment.** Every model declares
  `id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)`.
  Sequential integer PKs leak record counts and are enumerable.
- **Timestamps on every model.** Include `created_at = DateTimeField(auto_now_add=True)`
  and `updated_at = DateTimeField(auto_now=True)`.
- **Soft-delete, never hard-delete user data.** Add
  `archived_at = DateTimeField(null=True, blank=True)` with `soft_delete()` /
  `restore()` helpers and an `is_archived` property. ViewSets override
  `perform_destroy` to soft-delete, and querysets filter `archived_at__isnull=True`
  by default.
- **Cap and validate stored user input.** `CharField` always sets `max_length`;
  large text uses `TextField` with a capped `max_length`. Use built-in field
  types (`EmailField`, `SlugField`) and `django.core.validators` rather than
  hand-rolled checks.
- **Never trigger N+1 queries.** Use `select_related()` for forward FK/O2O and
  `prefetch_related()` for reverse/M2M relations whenever the serializer touches
  related objects. Use `only()`/`defer()` on hot paths.
- **Serializers own field exposure.** Set `fields` explicitly (never
  `fields = '__all__'`) and mark `id`, `created_at`, `updated_at` as
  `read_only_fields`. Validation lives in `validate_<field>`/`validate` methods.
- **Permissions on every ViewSet.** Always declare `permission_classes`; default
  to `IsAuthenticated` and add object-level permissions where ownership matters.
- **Migration discipline.** After any model change run `makemigrations` then
  `migrate`; commit the generated migration files alongside the model change.
  Never edit applied migrations — add a new one.
- **`Meta.ordering` is explicit.** Set a deterministic default ordering
  (typically `['-created_at']`) so pagination is stable.
