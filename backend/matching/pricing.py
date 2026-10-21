"""Paid matching (FR-8, MN-7..MN-9, MN-12): quotes, the daily cap, and coin holds that are
taken once a match has run 5 s or released if it ends sooner.

  mq:charges        ZSET "<session>|<user>" -> when the hold may be taken
  mq:filters:{user} the filters of the user's last paid join (re-used on Next)
"""

import json
import time

from accounts.models import User
from billing import plus
from billing.models import SpendSettings
from core.exceptions import ApiError
from core.redis import get_redis
from wallet import holds
from wallet.models import CoinLedger
from wallet.services import balance, spent_today

GENDER_FILTERS = {"women": "woman", "men": "man"}
REGION_FILTERS = ("nearby", "nigeria", "africa")
PRICES = {"gender": 8, "region": 5}  # MN-7: per match that connects; they add up
REMATCH_PRICE = 20
CHARGE_AFTER_SECONDS = 5  # MN-8
CHARGES = "mq:charges"


def normalize(filters: dict | None) -> dict:
    """{"gender": "women"|"men"|None, "region": "nearby"|"nigeria"|"africa"|None}."""
    filters = filters or {}
    gender = filters.get("gender") or None
    region = filters.get("region") or None
    if gender in ("everyone",):
        gender = None
    if region in ("global",):
        region = None
    if gender is not None and gender not in GENDER_FILTERS:
        raise ApiError("invalid_filters", "Pick women, men or everyone.")
    if region is not None and region not in REGION_FILTERS:
        raise ApiError("invalid_filters", "Pick nearby, Nigeria, Africa or global.")
    return {"gender": gender, "region": region}


def _cap_left(settings: SpendSettings, user_id) -> int | None:
    if not settings.daily_cap:
        return None
    return max(0, settings.daily_cap - spent_today(user_id) - holds.held(user_id))


def quote(user: User, filters: dict | None, extra: int = 0, extra_kind: str = "") -> dict:
    """What a paid feature would cost this user now (POST match/quote). Never computed in
    the app (CLAUDE.md)."""
    f = normalize(filters)
    lines = [{"kind": k, "cost": PRICES[k]} for k in ("gender", "region") if f[k] is not None]
    if extra:
        lines.append({"kind": extra_kind, "cost": extra})
    settings = plus.spend_settings(user.id)
    subscribed = plus.is_plus(user.id)
    cost = 0 if subscribed else sum(line["cost"] for line in lines)
    bal, avail = balance(user.id), holds.available(user.id)
    cap_left = _cap_left(settings, user.id)
    reason = None
    if cost:
        if not settings.payg_enabled:
            reason = "payg_off"
        elif cap_left is not None and cost > cap_left:
            reason = "cap_reached"
        elif avail < cost:
            reason = "low_balance"
    return {
        "filters": f,
        "lines": lines,
        "cost": cost,
        "free_reason": "plus" if subscribed and lines else (None if lines else "no_filters"),
        "balance": bal,
        "available": avail,
        "spent_today": spent_today(user.id),
        "daily_cap": settings.daily_cap,
        "cap_left": cap_left,
        "can_pay": reason is None,
        "reason": reason,
        "auto_topup": settings.auto_topup,
    }


_REFUSALS = {
    "payg_off": ("filters_locked", "Filters are part of Lovelly Plus or pay as you go.", 402),
    "cap_reached": (
        "cap_reached",
        "You’ve reached today’s spend cap. Free matching still works.",
        402,
    ),
    "low_balance": ("low_balance", "You don’t have enough coins.", 402),
}


def refuse(q: dict) -> None:
    code, detail, status = _REFUSALS[q["reason"]]
    raise ApiError(code, detail, status, quote=_public(q))


def _public(q: dict) -> dict:
    return {k: v for k, v in q.items() if k != "filters"}


def require_state(user: User, filters: dict) -> None:
    if filters.get("region") == "nearby" and not user.profile.region:
        raise ApiError("state_needed", "Add your state to your profile to match nearby.", 409)


def hold_for_queue(user: User, filters: dict, accept_charge: bool) -> int:
    """Checks a paid join and sets its coins aside. Returns the coins held (0 if free)."""
    holds.release(user.id, "queue")
    remember_filters(user.id, filters)  # Next re-uses them, paid or free (Plus)
    q = quote(user, filters)
    if not q["cost"]:
        return 0
    if not q["can_pay"]:
        refuse(q)
    if not accept_charge:  # MN-7: the app shows the charge sheet first
        raise ApiError("charge_not_accepted", "Confirm the price first.", 402, quote=_public(q))
    holds.place(user.id, q["cost"], "queue")
    return q["cost"]


def hold_for_rematch(user: User, invite_id: str) -> int:
    q = quote(user, None, extra=REMATCH_PRICE, extra_kind="rematch")
    if not q["cost"]:
        return 0
    if not q["can_pay"]:
        refuse(q)
    holds.place(user.id, q["cost"], f"rematch:{invite_id}")
    return q["cost"]


def remember_filters(user_id, filters: dict) -> None:
    get_redis().set(f"mq:filters:{user_id}", json.dumps(normalize(filters)), ex=24 * 3600)


def last_filters(user_id) -> dict | None:
    raw = get_redis().get(f"mq:filters:{user_id}")
    return json.loads(raw) if raw else None


def forget_filters(user_id) -> None:
    get_redis().delete(f"mq:filters:{user_id}")


# --- Holds through a session --------------------------------------------------------------


def bind(session, user_ids, old_ref: str = "queue", started: float | None = None) -> None:
    """A match was found: each paying user's hold now belongs to the session (MN-8)."""
    due = (started or time.time()) + CHARGE_AFTER_SECONDS
    pipe = get_redis().pipeline()
    for uid in user_ids:
        if holds.move(uid, old_ref, str(session.id)):
            pipe.zadd(CHARGES, {f"{session.id}|{uid}": due})
    pipe.execute()


def _reason(session) -> str:
    return CoinLedger.Reason.REMATCH if session.rematch_of_id else CoinLedger.Reason.FILTERED_MATCH


def _take(session, user_id) -> int:
    return holds.take(
        user_id,
        str(session.id),
        _reason(session),
        key=f"match:{session.id}:{user_id}",
        ref_type="session",
        ref_id=str(session.id),
    )


def settle(session) -> None:
    """The session ended: take holds if it ran 5 s, release them otherwise (MN-8)."""
    ran = (session.ended_at - session.started_at).total_seconds()
    r = get_redis()
    for uid in (session.user_a_id, session.user_b_id):
        member = f"{session.id}|{uid}"
        if r.zscore(CHARGES, member) is None:
            continue
        if ran >= CHARGE_AFTER_SECONDS:
            _take(session, uid)
        else:
            holds.release(uid, str(session.id))
        r.zrem(CHARGES, member)


def sweep_charges(now=None) -> int:
    """Takes the holds of sessions that have now run 5 s (the matcher loop, every tick)."""
    from .models import MatchSession

    now = now or time.time()
    r = get_redis()
    due = r.zrangebyscore(CHARGES, 0, now)
    taken = 0
    for member in due:
        session_id, uid = member.split("|")
        session = MatchSession.objects.filter(id=session_id).first()
        if session is None:
            holds.release(uid, session_id)
        elif session.ended_at is None:
            taken += bool(_take(session, uid))
        else:
            settle(session)
            continue
        r.zrem(CHARGES, member)
    return taken
