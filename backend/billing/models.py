"""In-app purchases of coin packs (MN-1, MN-4)."""

from django.conf import settings
from django.db import models

from core.models import UUIDModel


class Purchase(UUIDModel):
    """PRD: Data model / Purchase. One row per store transaction."""

    class Store(models.TextChoices):
        APPLE = "apple", "App Store"
        GOOGLE = "google", "Google Play"

    class Status(models.TextChoices):
        PENDING = "pending", "Pending payment"
        CREDITED = "credited", "Credited"
        REFUNDED = "refunded", "Refunded"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="purchases"
    )
    store = models.CharField(max_length=6, choices=Store.choices)
    product_id = models.CharField(max_length=60)
    txn_id = models.CharField(max_length=120, help_text="Google order id / Apple transaction id")
    token = models.TextField(blank=True, help_text="Google purchase token")
    amount_ngn = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    status = models.CharField(max_length=8, choices=Status.choices)
    raw_receipt = models.JSONField(default=dict)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["store", "txn_id"], name="unique_store_txn")]

    def __str__(self):
        return f"{self.store} {self.txn_id}: {self.status}"


class SpendSettings(UUIDModel):
    """PRD: SpendSettings. Pay as you go, the daily cap and auto top-up (MN-9, MN-10)."""

    CAPS = (50, 100, 200, 0)  # 0 = no cap

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="spend_settings"
    )
    payg_enabled = models.BooleanField(default=False)
    daily_cap = models.PositiveIntegerField(default=100, help_text="Coins per Lagos day; 0 = none")
    auto_topup = models.BooleanField(default=False)
    topup_pack = models.CharField(max_length=60, default="coins_550")
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user_id}: payg={self.payg_enabled} cap={self.daily_cap}"


class Subscription(UUIDModel):
    """PRD: Subscription (Lovelly Plus, MN-6). Kept in step with the stores' notifications."""

    class Plan(models.TextChoices):
        WEEK = "week", "1 week"
        MONTH = "month", "1 month"
        YEAR = "year", "12 months"

    class Status(models.TextChoices):
        ACTIVE = "active", "Active"
        GRACE = "grace", "Billing retry (still active)"
        ON_HOLD = "on_hold", "On hold (payment failed)"
        CANCELLED = "cancelled", "Cancelled (active until period end)"
        EXPIRED = "expired", "Expired"
        REVOKED = "revoked", "Refunded or revoked"

    ACTIVE_STATUSES = (Status.ACTIVE, Status.GRACE, Status.CANCELLED)

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="subscriptions"
    )
    plan = models.CharField(max_length=6, choices=Plan.choices)
    store = models.CharField(max_length=6, choices=Purchase.Store.choices)
    status = models.CharField(max_length=10, choices=Status.choices)
    current_period_end = models.DateTimeField()
    original_txn_id = models.CharField(
        max_length=200, help_text="Apple original transaction id / Google purchase token"
    )
    auto_renews = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["store", "original_txn_id"], name="unique_store_sub")
        ]

    def __str__(self):
        return f"{self.user_id} {self.plan} {self.status} until {self.current_period_end:%Y-%m-%d}"
