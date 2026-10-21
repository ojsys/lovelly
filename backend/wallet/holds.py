"""Coin holds (MN-8): coins set aside when a paid match starts, taken after 5 s connected or
released. Short-lived state in Redis (PRD: Data model); the ledger is only written on take.

  wallet:holds:{user}  HASH ref -> amount   (ref: "queue", "rematch:<invite>", "<session id>")
"""

from django.db import transaction

from core.exceptions import ApiError
from core.redis import get_redis

from .services import _lock, balance, post_entry

HOLD_TTL_SECONDS = 3600  # a safety net; holds normally end within minutes


def _key(user_id) -> str:
    return f"wallet:holds:{user_id}"


def held(user_id, except_ref: str | None = None) -> int:
    holds = get_redis().hgetall(_key(user_id))
    return sum(int(v) for ref, v in holds.items() if ref != except_ref)


def amount(user_id, ref: str) -> int:
    return int(get_redis().hget(_key(user_id), ref) or 0)


def available(user_id) -> int:
    return balance(user_id) - held(user_id)


def place(user_id, coins: int, ref: str) -> None:
    """Sets aside `coins` under `ref` (replacing an earlier hold with the same ref)."""
    with transaction.atomic():
        _lock(user_id)
        if balance(user_id) - held(user_id, except_ref=ref) < coins:
            raise ApiError("low_balance", "You don’t have enough coins.", 402)
        r = get_redis()
        pipe = r.pipeline()
        pipe.hset(_key(user_id), ref, coins)
        pipe.expire(_key(user_id), HOLD_TTL_SECONDS)
        pipe.execute()


def move(user_id, old_ref: str, new_ref: str) -> int:
    """Re-labels a hold (the queue's hold becomes the session's when matched)."""
    coins = amount(user_id, old_ref)
    if coins:
        pipe = get_redis().pipeline()
        pipe.hdel(_key(user_id), old_ref)
        pipe.hset(_key(user_id), new_ref, coins)
        pipe.expire(_key(user_id), HOLD_TTL_SECONDS)
        pipe.execute()
    return coins


def release(user_id, ref: str) -> int:
    coins = amount(user_id, ref)
    get_redis().hdel(_key(user_id), ref)
    return coins


def take(user_id, ref: str, reason: str, key: str, ref_type: str = "", ref_id: str = "") -> int:
    """Turns a hold into a ledger debit, once per `key`. Returns the coins taken."""
    coins = amount(user_id, ref)
    if not coins:
        return 0
    post_entry(user_id, -coins, reason, key=key, ref_type=ref_type, ref_id=ref_id, from_hold=coins)
    get_redis().hdel(_key(user_id), ref)
    return coins
