---
name: create-django-resource
description: Scaffold a new DRF resource end-to-end — model, serializer, viewset, URL wiring, and migration — following the standard Django app layering. Use when adding a new CRUD entity to a Django/DRF app.
type: stack
domain: django
rules: [django-conventions, security]
model: sonnet
model-fallback: [gemini-pro]
---

# create-django-resource

Add a new REST resource to a Django app by building the four layers in order —
model → serializer → viewset → urls — then generating and applying its
migration. Substitute your names for `MyModel` / `items` below.

## 1. Model (`models.py`)

UUID PK, timestamps, soft-delete, capped fields, explicit ordering.

```python
import uuid
from django.db import models
from django.utils import timezone


class MyModel(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    name = models.CharField(max_length=255)
    description = models.TextField(max_length=10000, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    archived_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def soft_delete(self):
        self.archived_at = timezone.now()
        self.save(update_fields=['archived_at'])

    def restore(self):
        self.archived_at = None
        self.save(update_fields=['archived_at'])

    @property
    def is_archived(self):
        return self.archived_at is not None
```

Add relations with `on_delete` and a `related_name`; index fields you filter on.

## 2. Serializer (`serializers.py`)

Explicit `fields`, read-only server-managed fields, per-field validation.

```python
from rest_framework import serializers

from .models import MyModel


class MyModelSerializer(serializers.ModelSerializer):
    class Meta:
        model = MyModel
        fields = ['id', 'name', 'description', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']

    def validate_name(self, value):
        value = value.strip().replace('\x00', '')
        if not value:
            raise serializers.ValidationError('Name cannot be empty.')
        return value
```

## 3. ViewSet (`views.py`)

Permissions, a queryset that hides archived rows and avoids N+1, soft-delete.

```python
from rest_framework import permissions, viewsets

from .models import MyModel
from .serializers import MyModelSerializer


class MyModelViewSet(viewsets.ModelViewSet):
    serializer_class = MyModelSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return (
            MyModel.objects
            .filter(archived_at__isnull=True)
            # .select_related('owner')  # add for FK/O2O the serializer reads
            # .prefetch_related('tags') # add for reverse/M2M relations
        )

    def perform_destroy(self, instance):
        instance.soft_delete()
```

## 4. URL wiring (`urls.py`)

Register the viewset on a router, then include the app under the API root.

```python
# <app>/urls.py
from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register(r'items', views.MyModelViewSet, basename='item')

urlpatterns = [
    path('', include(router.urls)),
]
```

```python
# project urls.py — mount the app under a versioned prefix
urlpatterns = [
    path('api/v1/my-app/', include('my_app.urls')),
]
```

## 5. Migration

```bash
python manage.py makemigrations
python manage.py migrate
python manage.py showmigrations   # confirm the new migration is applied
```

Commit the generated migration file with the model change.

## Checklist

- [ ] UUID PK, `created_at`/`updated_at`, `archived_at` present
- [ ] `CharField`/`TextField` have `max_length`; `Meta.ordering` set
- [ ] Serializer lists `fields` explicitly (never `'__all__'`), server fields read-only
- [ ] ViewSet declares `permission_classes`, filters out archived, soft-deletes
- [ ] `select_related`/`prefetch_related` added for related fields the serializer reads
- [ ] Router registered and app included under a versioned API prefix
- [ ] Migration generated, applied, and committed
