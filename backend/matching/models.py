from django.conf import settings
from django.db import models

from core.models import UUIDModel


class MatchSession(UUIDModel):
    """One row per conversation (PRD: Data model / MatchSession, FR-12)."""

    class Mode(models.TextChoices):
        VIDEO = "video", "Video"
        VOICE = "voice", "Voice"
        TEXT = "text", "Text"

    class EndReason(models.TextChoices):
        NEXT = "next", "Next"
        END = "end", "End"
        PEER_LEFT = "peer_left", "Disconnected"
        BLOCKED = "blocked", "Blocked"
        MODERATION = "moderation", "Moderation"

    mode = models.CharField(max_length=5, choices=Mode.choices)
    user_a = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+")
    user_b = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+")
    filters = models.JSONField(default=dict, blank=True)
    started_at = models.DateTimeField(auto_now_add=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    end_reason = models.CharField(max_length=10, choices=EndReason.choices, blank=True)
    # Who pressed Next / End (null for disconnects and moderation).
    ended_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    room_name = models.CharField(max_length=64, unique=True)
    # Voice call switched to video by agreement (FR-14).
    upgraded_at = models.DateTimeField(null=True, blank=True)
    # Direct call between friends (FR-16); empty for random matches.
    friendship = models.ForeignKey(
        "chat.Friendship", on_delete=models.SET_NULL, null=True, blank=True, related_name="calls"
    )

    # FR-7: a paid rematch of an earlier session (charged like a filtered match, MN-8).
    rematch_of = models.ForeignKey(
        "self", null=True, blank=True, on_delete=models.SET_NULL, related_name="rematches"
    )

    class Meta:
        indexes = [
            models.Index(fields=["user_a", "started_at"]),
            models.Index(fields=["user_b", "started_at"]),
        ]

    def peer_of(self, user_id):
        return self.user_b_id if str(self.user_a_id) == str(user_id) else self.user_a_id

    def has(self, user_id):
        return str(user_id) in (str(self.user_a_id), str(self.user_b_id))

    def __str__(self):
        return f"{self.mode} {self.user_a_id}↔{self.user_b_id}"
