from django.contrib import admin

from .models import CoinLedger, Gift, GiftSend, Referral


@admin.register(Gift)
class GiftAdmin(admin.ModelAdmin):
    """The gift catalogue (PRD: managed in the admin). Prices apply to new gifts only."""

    list_display = ["name", "slug", "cost", "sort", "active"]
    list_editable = ["cost", "sort", "active"]


class ReadOnly(admin.ModelAdmin):
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(CoinLedger)
class CoinLedgerAdmin(ReadOnly):
    """Append-only (MN-2): corrections are new entries, never edits."""

    list_display = ["created_at", "user", "delta", "reason", "ref_type", "ref_id"]
    list_filter = ["reason"]
    search_fields = ["user__phone", "idempotency_key", "ref_id"]


@admin.register(GiftSend)
class GiftSendAdmin(ReadOnly):
    list_display = ["created_at", "sender", "receiver", "gift", "cost"]


@admin.register(Referral)
class ReferralAdmin(ReadOnly):
    list_display = ["created_at", "inviter", "invited", "status", "note"]
