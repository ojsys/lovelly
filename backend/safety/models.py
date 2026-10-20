from django.conf import settings
from django.db import models

from core.models import UUIDModel


class Block(UUIDModel):
    """Two-way, permanent block (SF-5). Checked by the matcher (FR-7)."""

    blocker = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="blocks_made"
    )
    blocked = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="blocks_received"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["blocker", "blocked"], name="unique_block")]
