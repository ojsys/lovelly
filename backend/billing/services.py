"""Coin packs bought in the stores (MN-1, MN-4). Each store transaction credits once."""

import logging
from dataclasses import dataclass

from django.db import connection, transaction
from django.db.models import F

from accounts.models import User
from core.exceptions import ApiError
from core.providers import get_provider
from core.providers.store_receipts import InvalidReceipt, StoreEvent, StoreTransaction
from wallet.models import CoinLedger
from wallet.services import balance, post_entry

from .models import Purchase

logger = logging.getLogger(__name__)
R = CoinLedger.Reason
S = Purchase.Status

# A refund of coins that were already spent (M6 decision 5).
REFUND_RISK = 10


@dataclass(frozen=True)
class Pack:
    product_id: str
    base: int
    bonus: int
    label: str  # screen 10's line under the number
    tag: str = ""

    @property
    def coins(self) -> int:
        return self.base + self.bonus


# MN-1 and M6 decision 1: the big number is the total; the bonus is part of it.
# Prices are set in the store consoles and shown from the store, never from here.
PACKS = [
    Pack("coins_100", 100, 0, "Starter"),
    Pack("coins_550", 500, 50, "+50 bonus", "Popular"),
    Pack("coins_1200", 1000, 200, "+200 bonus"),
    Pack("coins_3000", 2300, 700, "+700 bonus", "Best value"),
]
_BY_ID = {p.product_id: p for p in PACKS}


def pack(product_id: str) -> Pack:
    if product_id not in _BY_ID:
        raise ApiError("unknown_product", "That coin pack doesn’t exist.", 400)
    return _BY_ID[product_id]


def _lock(store: str, txn_id: str) -> None:
    with connection.cursor() as c:
        c.execute(
            "SELECT pg_advisory_xact_lock(hashtextextended(%s, 0))", [f"txn:{store}:{txn_id}"]
        )


def _key(store, txn_id, part) -> str:
    return f"purchase:{store}:{txn_id}:{part}"


def verify(user: User, store: str, product_id: str, token: str) -> dict:
    """The app's report of a purchase (POST purchases/verify)."""
    pack(product_id)
    try:
        txn = get_provider("store_receipts").verify(store, product_id, token)
    except InvalidReceipt as e:
        logger.warning("invalid %s receipt from %s: %s", store, user.id, e)
        raise ApiError("invalid_receipt", "The store couldn’t confirm this purchase.", 400) from e
    if txn.product_id != product_id:
        raise ApiError("invalid_receipt", "The store couldn’t confirm this purchase.", 400)
    if txn.account_id and txn.account_id != str(user.id):
        raise ApiError("not_yours", "This purchase belongs to another account.", 403)
    status = credit(user.id, txn)
    if status == S.CREDITED:
        get_provider("store_receipts").acknowledge(store, product_id, token)
    return {"status": status, "balance": balance(user.id)}


def credit(user_id, txn: StoreTransaction) -> str:
    """Credits a purchase once, whoever reports it first (app or webhook)."""
    p = pack(txn.product_id)
    with transaction.atomic():
        _lock(txn.store, txn.txn_id)
        purchase = Purchase.objects.filter(store=txn.store, txn_id=txn.txn_id).first()
        if purchase and str(purchase.user_id) != str(user_id):
            raise ApiError("not_yours", "This purchase belongs to another account.", 403)
        if purchase and purchase.status in (S.CREDITED, S.REFUNDED):
            return purchase.status
        if txn.state != "purchased":
            if txn.state == "pending":
                _save(purchase, user_id, txn, S.PENDING)
                return S.PENDING
            raise ApiError("not_paid", "This purchase wasn’t completed.", 409)
        purchase = _save(purchase, user_id, txn, S.CREDITED)
        post_entry(
            user_id,
            p.base,
            R.PURCHASE,
            key=_key(txn.store, txn.txn_id, "base"),
            ref_type="purchase",
            ref_id=purchase.id,
        )
        if p.bonus:
            post_entry(
                user_id,
                p.bonus,
                R.PURCHASE_BONUS,
                key=_key(txn.store, txn.txn_id, "bonus"),
                ref_type="purchase",
                ref_id=purchase.id,
            )
    logger.info("credited %s %s (%s) to %s", txn.store, txn.txn_id, txn.product_id, user_id)
    return S.CREDITED


def _save(purchase, user_id, txn: StoreTransaction, status) -> Purchase:
    if purchase is None:
        return Purchase.objects.create(
            user_id=user_id,
            store=txn.store,
            product_id=txn.product_id,
            txn_id=txn.txn_id,
            token=txn.token,
            amount_ngn=txn.amount_ngn,
            status=status,
            raw_receipt=txn.raw,
        )
    purchase.status, purchase.raw_receipt = status, txn.raw
    purchase.save(update_fields=["status", "raw_receipt", "updated_at"])
    return purchase


def refund(store: str, txn_id: str) -> None:
    """Takes back a refunded pack's coins, even below zero (M6 decision 5)."""
    with transaction.atomic():
        _lock(store, txn_id)
        purchase = Purchase.objects.filter(store=store, txn_id=txn_id).first()
        if purchase is None:
            logger.warning("refund for unknown %s transaction %s", store, txn_id)
            return
        if purchase.status == S.REFUNDED:
            return
        was_credited = purchase.status == S.CREDITED
        purchase.status = S.REFUNDED
        purchase.save(update_fields=["status", "updated_at"])
        if not was_credited:
            return
        p = pack(purchase.product_id)
        for part, amount in (("base", p.base), ("bonus", p.bonus)):
            if amount:
                post_entry(
                    purchase.user_id,
                    -amount,
                    R.REFUND,
                    key=f"refund:{store}:{txn_id}:{part}",
                    ref_type="purchase",
                    ref_id=purchase.id,
                    allow_negative=True,
                )
        if balance(purchase.user_id) < 0:
            User.objects.filter(id=purchase.user_id).update(
                risk_score=F("risk_score") + REFUND_RISK
            )
    logger.info("refunded %s %s", store, txn_id)


def handle_webhook(store: str, body: dict, query: dict) -> int:
    """Store notifications: purchases the app never reported, and refunds."""
    try:
        events: list[StoreEvent] = get_provider("store_receipts").parse_webhook(store, body, query)
    except InvalidReceipt as e:
        logger.warning("rejected %s webhook: %s", store, e)
        raise ApiError("invalid_notification", "Not a valid store notification.", 400) from e
    for event in events:
        if event.kind == "purchased":
            txn = event.transaction
            user = User.objects.filter(id=txn.account_id).first() if txn.account_id else None
            if user is None:
                existing = Purchase.objects.filter(store=txn.store, txn_id=txn.txn_id).first()
                if existing is None:
                    logger.error("%s purchase %s names no known account", store, txn.txn_id)
                    continue
                user = existing.user
            if credit(user.id, txn) == S.CREDITED and txn.token:
                get_provider("store_receipts").acknowledge(store, txn.product_id, txn.token)
        elif event.kind == "refunded":
            refund(event.store, event.txn_id)
    return len(events)
