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
