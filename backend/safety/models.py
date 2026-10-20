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

    def __str__(self):
        return f"{self.blocker_id} blocked {self.blocked_id}"


class Report(UUIDModel):
    """A user or automatic report (SF-4). Feeds the moderator queue (SF-6)."""

    class Reason(models.TextChoices):
        MINOR = "minor", "May be under 18"
        NUDITY = "nudity", "Nudity or sexual content"
        HARASSMENT = "harassment", "Harassment or hate"
        SCAM = "scam", "Scam or asking for money"
        FAKE = "fake", "Fake profile or impersonation"
        OTHER = "other", "Something else"

    class Status(models.TextChoices):
        OPEN = "open", "Open"
        ESCALATED = "escalated", "Escalated"
        ACTIONED = "actioned", "Actioned"
        DISMISSED = "dismissed", "Dismissed"

    # SF-6 queue order: possible minor > nudity > harassment > scam > other.
    SEVERITY = {
        Reason.MINOR: 5,
        Reason.NUDITY: 4,
        Reason.HARASSMENT: 3,
        Reason.SCAM: 2,
        Reason.FAKE: 1,
        Reason.OTHER: 1,
    }

    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reports_made",
        help_text="Empty for automatic reports from the moderation agent",
    )
    reported = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="reports_received"
    )
    session = models.ForeignKey(
        "matching.MatchSession", on_delete=models.SET_NULL, null=True, related_name="reports"
    )
    reason = models.CharField(max_length=12, choices=Reason.choices)
    severity = models.PositiveSmallIntegerField()
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.OPEN)
    automatic = models.BooleanField(default=False)
    evidence_uri = models.CharField(max_length=255, blank=True)
    # SF-9: suspected child sexual abuse material. Evidence can never be deleted.
    legal_hold = models.BooleanField(default=False)
    referral = models.JSONField(default=dict, blank=True, help_text="Authority, date, reference")
    created_at = models.DateTimeField(auto_now_add=True)
    closed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes = [models.Index(fields=["status", "-severity", "created_at"])]

    def __str__(self):
        return f"{self.reason} report on {self.reported_id}"


class ModerationAction(UUIDModel):
    """Audit log of moderator and automatic actions (SF-6). Append-only: a database
    trigger rejects UPDATE and DELETE (migration 0003)."""

    class Action(models.TextChoices):
        WARN = "warn", "Warn"
        SUSPEND = "suspend", "Suspend"
        BAN = "ban", "Ban"
        DISMISS = "dismiss", "Dismiss report"
        ESCALATE = "escalate", "Escalate"
        LEGAL_HOLD = "legal_hold", "Legal hold (SF-9)"
        REFERRAL = "referral", "Referred to authorities"
        AUTO_BLOCK = "auto_block", "Automatic: stream blocked"
        AUTO_SUSPEND = "auto_suspend", "Automatic: suspended for review"
        APPROVE_SELFIE = "approve_selfie", "Selfie approved"
        REJECT_SELFIE = "reject_selfie", "Selfie rejected"

    target_user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="moderation_actions"
    )
    moderator = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="+",
        help_text="Empty for automatic actions",
    )
    report = models.ForeignKey(Report, on_delete=models.PROTECT, null=True, blank=True)
    action = models.CharField(max_length=16, choices=Action.choices)
    duration = models.DurationField(null=True, blank=True)
    note = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.action} {self.target_user_id}"


class Notice(UUIDModel):
    """Something a user must see once in the app (e.g. a moderator warning)."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notices"
    )
    kind = models.CharField(max_length=20)
    title = models.CharField(max_length=80)
    body = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    seen_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.kind} for {self.user_id}"
