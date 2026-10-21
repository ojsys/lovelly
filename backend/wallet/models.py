"""Coins (MN-2, MN-3, MN-5). The ledger is the only record of a balance."""

from django.conf import settings
from django.db import models

from core.models import UUIDModel


class CoinLedger(UUIDModel):
    """PRD: Data model / CoinLedger. Append-only (Postgres trigger); balance = SUM(delta).

    Written only by `wallet.services.post_entry`.
    """

    class Reason(models.TextChoices):
        PURCHASE = "purchase", "Coin pack"
        PURCHASE_BONUS = "purchase_bonus", "Pack bonus"
        GIFT = "gift", "Gift sent"
        DAILY_CHECKIN = "daily_checkin", "Daily check-in"
        INVITE_REWARD = "invite_reward", "Invite reward"
        REFUND = "refund", "Refund"
        FILTERED_MATCH = "filtered_match", "Filtered match"
        REMATCH = "rematch", "Rematch"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="coin_entries"
    )
    delta = models.IntegerField()
    reason = models.CharField(max_length=20, choices=Reason.choices)
    ref_type = models.CharField(max_length=20, blank=True)
    ref_id = models.CharField(max_length=80, blank=True)
    idempotency_key = models.CharField(max_length=160, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=["user", "-created_at"], name="ledger_user_time")]
        constraints = [models.CheckConstraint(condition=~models.Q(delta=0), name="ledger_nonzero")]

    def __str__(self):
        return f"{self.delta:+} {self.reason} for {self.user_id}"


class Gift(UUIDModel):
    """PRD: Gift. The catalogue is edited in Django admin; seeded with the 8 MN-5 gifts."""

    slug = models.SlugField(max_length=30, unique=True)
    name = models.CharField(max_length=40)
    cost = models.PositiveIntegerField()
    sort = models.PositiveSmallIntegerField(default=0)
    active = models.BooleanField(default=True)

    class Meta:
        ordering = ["sort", "cost"]

    def __str__(self):
        return f"{self.name} ({self.cost})"


class GiftSend(UUIDModel):
    """PRD: GiftSend. The receiver gets nothing back in the MVP (MN-5)."""

    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="gifts_sent"
    )
    receiver = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="gifts_received"
    )
    session = models.ForeignKey(
        "matching.MatchSession", null=True, blank=True, on_delete=models.SET_NULL
    )
    friendship = models.ForeignKey(
        "chat.Friendship", null=True, blank=True, on_delete=models.SET_NULL
    )
    gift = models.ForeignKey(Gift, on_delete=models.PROTECT)
    cost = models.PositiveIntegerField(help_text="Price when sent")
    ledger_entry = models.OneToOneField(CoinLedger, on_delete=models.PROTECT)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.gift.slug} from {self.sender_id}"


class InviteCode(UUIDModel):
    """Each user's code for "Invite a friend" (MN-3)."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="invite_code"
    )
    code = models.CharField(max_length=12, unique=True)

    def __str__(self):
        return self.code


class Referral(UUIDModel):
    """Who invited whom. The inviter gets +50 when the invited person is verified (MN-3)."""

    class Status(models.TextChoices):
        PENDING = "pending", "Waiting for verification"
        REWARDED = "rewarded", "Rewarded"
        REFUSED = "refused", "Not rewarded"

    inviter = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="referrals"
    )
    invited = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="referred_by"
    )
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    note = models.CharField(max_length=40, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.inviter_id} → {self.invited_id}: {self.status}"
