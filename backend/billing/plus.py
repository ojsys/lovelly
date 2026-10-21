"""Korram Plus (MN-6) and spend settings (MN-9, MN-10)."""

import logging
from dataclasses import dataclass

from django.db import transaction
from django.utils import timezone

from core.exceptions import ApiError
from core.providers.store_receipts import StoreSubscription

from .models import SpendSettings, Subscription

logger = logging.getLogger(__name__)
S = Subscription.Status


@dataclass(frozen=True)
class Plan:
    plan: str
    label: str
    sub: str
    apple_product: str
    google_product: str
    google_base_plan: str


# M7 decision 6: one Google subscription with three base plans; three Apple products.
PLANS = [
    Plan("week", "1 week", "Try it out", "plus_week", "korram_plus", "week"),
    Plan("month", "1 month", "Most popular", "plus_month", "korram_plus", "month"),
    Plan("year", "12 months", "Best value", "plus_year", "korram_plus", "year"),
]
PLUS_PRODUCTS = {p.apple_product for p in PLANS} | {p.google_product for p in PLANS}


def active_subscription(user_id) -> Subscription | None:
    return (
        Subscription.objects.filter(
            user_id=user_id,
            status__in=Subscription.ACTIVE_STATUSES,
            current_period_end__gt=timezone.now(),
        )
        .order_by("-current_period_end")
        .first()
    )


def is_plus(user_id) -> bool:
    return active_subscription(user_id) is not None


def plus_status(user_id) -> dict:
    sub = active_subscription(user_id)
    return {
        "active": sub is not None,
        "plan": sub.plan if sub else None,
        "store": sub.store if sub else None,
        "period_end": sub.current_period_end if sub else None,
        "auto_renews": sub.auto_renews if sub else False,
    }


@transaction.atomic
def apply(user_id, s: StoreSubscription) -> Subscription:
    """The store's view of a subscription wins; replays and reorderings change nothing new."""
    sub = (
        Subscription.objects.select_for_update()
        .filter(store=s.store, original_txn_id=s.original_txn_id)
        .first()
    )
    if sub and str(sub.user_id) != str(user_id):
        raise ApiError("not_yours", "This subscription belongs to another account.", 403)
    values = {
        "plan": s.plan,
        "status": s.state,
        "current_period_end": s.period_end,
        "auto_renews": s.auto_renews,
    }
    if sub is None:
        sub = Subscription.objects.create(
            user_id=user_id, store=s.store, original_txn_id=s.original_txn_id, **values
        )
    elif sub.status != S.REVOKED or s.state == S.REVOKED:  # a revoke is final
        for k, v in values.items():
            setattr(sub, k, v)
        sub.save(update_fields=[*values, "updated_at"])
    logger.info("subscription %s for %s: %s", s.original_txn_id[:12], user_id, sub.status)
    return sub


# --- Spend settings ----------------------------------------------------------------------


def spend_settings(user_id) -> SpendSettings:
    obj, _ = SpendSettings.objects.get_or_create(user_id=user_id)
    return obj


def update_spend_settings(user_id, data: dict) -> SpendSettings:
    obj = spend_settings(user_id)
    if "daily_cap" in data and data["daily_cap"] not in SpendSettings.CAPS:
        raise ApiError("invalid_cap", "Pick 50, 100, 200 or no cap.")
    for field in ("payg_enabled", "daily_cap", "auto_topup"):
        if field in data:
            setattr(obj, field, data[field])
    obj.save()
    return obj
