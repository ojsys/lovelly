from django.conf import settings
from django.db import models
from django.db.models.functions import Greatest, Least

from core.models import UUIDModel


class Friendship(UUIDModel):
    """PRD: Data model / Friendship. Unique per pair, whoever asked first (FR-16)."""

    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        ACCEPTED = "accepted", "Accepted"
        DECLINED = "declined", "Declined"

    requester = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+"
    )
    addressee = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+"
    )
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    # Where they met; its messages move here when accepted (FR-15).
    met_in = models.ForeignKey(
        "matching.MatchSession", on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    accepted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            # One friendship per pair, whichever direction it was asked in.
            models.UniqueConstraint(
                Least("requester", "addressee"),
                Greatest("requester", "addressee"),
                name="unique_friendship_pair",
            ),
            models.CheckConstraint(
                condition=~models.Q(requester=models.F("addressee")), name="no_self_friendship"
            ),
        ]

    def has(self, user_id):
        return str(user_id) in (str(self.requester_id), str(self.addressee_id))

    def other(self, user_id):
        return self.addressee_id if str(self.requester_id) == str(user_id) else self.requester_id

    def __str__(self):
        return f"{self.requester_id} → {self.addressee_id} ({self.status})"


class Message(UUIDModel):
    """Chat message (PRD: Data model / Message): in a stranger session or a friendship."""

    class Kind(models.TextChoices):
        TEXT = "text", "Text"
        GIFT = "gift", "Gift"
        SYSTEM = "system", "System"

    session = models.ForeignKey(
        "matching.MatchSession",
        on_delete=models.CASCADE,
        related_name="messages",
        null=True,
        blank=True,
    )
    friendship = models.ForeignKey(
        Friendship, on_delete=models.CASCADE, related_name="messages", null=True, blank=True
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
        indexes = [models.Index(fields=["friendship", "-sent_at"])]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(session__isnull=False) | models.Q(friendship__isnull=False),
                name="message_has_a_conversation",
            )
        ]

    def __str__(self):
        return f"{self.sender_id}: {self.body[:30]}"
