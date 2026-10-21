"""The coin ledger (MN-2). `post_entry` is the only code that writes coins."""

from dataclasses import dataclass
from datetime import date, datetime, time
from zoneinfo import ZoneInfo

from django.db import connection, transaction
from django.db.models import Sum
from django.db.models.functions import Coalesce
from django.utils import timezone

from core.exceptions import ApiError
from core.realtime import send_to_user

from .models import CoinLedger

LAGOS = ZoneInfo("Africa/Lagos")
R = CoinLedger.Reason

# Coins the user chose to spend (MN-9's "today's spend"). Refunds are not spending.
SPENDING = [R.GIFT, R.FILTERED_MATCH, R.REMATCH]


def lagos_today(now: datetime | None = None) -> date:
    return (now or timezone.now()).astimezone(LAGOS).date()


def lagos_day_start(day: date) -> datetime:
    return datetime.combine(day, time.min, tzinfo=LAGOS)


def balance(user_id) -> int:
    return CoinLedger.objects.filter(user_id=user_id).aggregate(b=Coalesce(Sum("delta"), 0))["b"]


def spent_today(user_id, now: datetime | None = None) -> int:
    start = lagos_day_start(lagos_today(now))
    spent = CoinLedger.objects.filter(
        user_id=user_id, reason__in=SPENDING, created_at__gte=start
    ).aggregate(s=Coalesce(Sum("delta"), 0))["s"]
    return -spent


@dataclass(frozen=True)
class Posted:
    entry: CoinLedger
    created: bool  # False: this key was posted before, nothing new was written


def _lock(user_id) -> None:
    """Serialises one user's coin writes until the transaction ends (no overdraft races)."""
    with connection.cursor() as c:
        c.execute("SELECT pg_advisory_xact_lock(hashtextextended(%s, 0))", [f"wallet:{user_id}"])


def post_entry(
    user_id,
    delta: int,
    reason: str,
    *,
    key: str,
    ref_type: str = "",
    ref_id: str = "",
    allow_negative: bool = False,
    from_hold: int = 0,
) -> Posted:
    """Adds one ledger row, once per `key` (MN-2).

    A debit that would take the available coins (balance − holds, MN-8) below zero fails
    with `insufficient_coins`, unless `allow_negative` (refunds of coins already spent, M6
    decision 5). `from_hold` is the hold this debit uses up, so it isn't counted twice.
    """
    if delta == 0:
        raise ValueError("a ledger entry moves coins")
    with transaction.atomic():
        _lock(user_id)
        existing = CoinLedger.objects.filter(idempotency_key=key).first()
        if existing:
            if (str(existing.user_id), existing.delta, existing.reason) != (
                str(user_id),
                delta,
                reason,
            ):
                raise ApiError(
                    "key_reused", "This request was already used for something else.", 409
                )
            return Posted(existing, created=False)
        if delta < 0 and not allow_negative and _available(user_id, from_hold) + delta < 0:
            raise ApiError("insufficient_coins", "You don’t have enough coins.", 402)
        entry = CoinLedger.objects.create(
            user_id=user_id,
            delta=delta,
            reason=reason,
            ref_type=ref_type,
            ref_id=str(ref_id),
            idempotency_key=key,
        )
        transaction.on_commit(lambda: announce(user_id))
    return Posted(entry, created=True)


def _available(user_id, from_hold: int) -> int:
    from .holds import held

    return balance(user_id) - held(user_id) + from_hold


def announce(user_id) -> None:
    send_to_user(
        user_id,
        "wallet.updated",
        {"balance": balance(user_id), "spent_today": spent_today(user_id)},
    )


def ledger(user_id, before=None, limit: int = 30) -> dict:
    qs = CoinLedger.objects.filter(user_id=user_id).order_by("-created_at")
    if before:
        qs = qs.filter(created_at__lt=before)
    page = list(qs[: limit + 1])
    return {"entries": page[:limit], "more": len(page) > limit}
