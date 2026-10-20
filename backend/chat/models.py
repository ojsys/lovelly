from django.conf import settings
from django.db import models

from core.models import UUIDModel


class Message(UUIDModel):
    """Chat message (PRD: Data model / Message). Friend chats are added in M5."""

    class Kind(models.TextChoices):
        TEXT = "text", "Text"
        GIFT = "gift", "Gift"
        SYSTEM = "system", "System"

    session = models.ForeignKey(
        "matching.MatchSession", on_delete=models.CASCADE, related_name="messages"
    )
    sender = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+")
    body = models.TextField(max_length=1000)
    kind = models.CharField(max_length=6, choices=Kind.choices, default=Kind.TEXT)
    # FR-18 / SF-8: delivered, but the receiver sees a warning.
    flagged = models.BooleanField(default=False)
    flag_reason = models.CharField(max_length=20, blank=True)
    sent_at = models.DateTimeField(auto_now_add=True)
    seen_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["sent_at"]
