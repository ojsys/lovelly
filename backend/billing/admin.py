from django.contrib import admin

from wallet.admin import ReadOnly

from .models import Purchase, SpendSettings, Subscription


@admin.register(Purchase)
class PurchaseAdmin(ReadOnly):
    list_display = ["created_at", "user", "store", "product_id", "txn_id", "status"]
    list_filter = ["store", "status"]
    search_fields = ["txn_id", "user__phone"]


@admin.register(Subscription)
class SubscriptionAdmin(ReadOnly):
    """Kept in step with the stores; never edited by hand."""

    list_display = ["user", "plan", "store", "status", "current_period_end", "auto_renews"]
    list_filter = ["store", "status", "plan"]


@admin.register(SpendSettings)
class SpendSettingsAdmin(ReadOnly):
    list_display = ["user", "payg_enabled", "daily_cap", "auto_topup"]
