import uuid

from django.db import models


class UUIDModel(models.Model):
    """Base for every Lovelly table: UUID primary key (PRD: Data model)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    class Meta:
        abstract = True
