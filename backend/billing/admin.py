from django.contrib import admin

from wallet.admin import ReadOnly

from .models import Purchase


@admin.register(Purchase)
class PurchaseAdmin(ReadOnly):
    list_display = ["created_at", "user", "store", "product_id", "txn_id", "status"]
    list_filter = ["store", "status"]
    search_fields = ["txn_id", "user__phone"]
