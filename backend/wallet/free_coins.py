"""Free coins (MN-3): the daily check-in and invite rewards."""

import logging
import secrets
from datetime import date, timedelta

from django.conf import settings
from django.db import IntegrityError, transaction

from accounts.models import User, UserDevice
from core.exceptions import ApiError

from .models import CoinLedger, InviteCode, Referral
from .services import lagos_today, post_entry

logger = logging.getLogger(__name__)
R = CoinLedger.Reason

CHECKIN_COINS = 10
STREAK_DAYS = 7
INVITE_COINS = 50


# --- Daily check-in ---------------------------------------------------------------------


def _last_checkin(user_id) -> tuple[date, int] | None:
    """(Lagos date, streak day) of the latest check-in; ref_id is "YYYY-MM-DD:day"."""
    last = (
        CoinLedger.objects.filter(user_id=user_id, reason=R.DAILY_CHECKIN)
        .order_by("-created_at")
        .values_list("ref_id", flat=True)
        .first()
    )
    if not last:
        return None
    day, _, n = last.partition(":")
    return date.fromisoformat(day), int(n)


def checkin_state(user_id, today: date | None = None) -> dict:
    """Day N of 7: today's if claimed, else the one a claim now would give (M6 decision 2)."""
    today = today or lagos_today()
    last = _last_checkin(user_id)
    if last and last[0] == today:
        return {"claimed_today": True, "day": last[1], "coins": CHECKIN_COINS}
    if last and last[0] == today - timedelta(days=1):
        day = last[1] % STREAK_DAYS + 1
    else:
        day = 1  # first ever, or a missed day resets the streak
    return {"claimed_today": False, "day": day, "coins": CHECKIN_COINS}


def claim_daily(user: User, today: date | None = None) -> dict:
    """+10 once per Lagos day. A repeat (double tap, retry) changes nothing."""
    today = today or lagos_today()
    with transaction.atomic():
        state = checkin_state(user.id, today)
        if not state["claimed_today"]:
            post_entry(
                user.id,
                CHECKIN_COINS,
                R.DAILY_CHECKIN,
                key=f"checkin:{user.id}:{today.isoformat()}",
                ref_type="checkin",
                ref_id=f"{today.isoformat()}:{state['day']}",
            )
    return checkin_state(user.id, today)


# --- Invites ----------------------------------------------------------------------------

_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # no 0/O, 1/I


def invite(user: User) -> dict:
    code = InviteCode.objects.filter(user=user).values_list("code", flat=True).first()
    while code is None:
        try:
            code = InviteCode.objects.create(
                user=user, code="".join(secrets.choice(_ALPHABET) for _ in range(8))
            ).code
        except IntegrityError:  # a clash with someone's code: draw again
            code = None
    rewarded = Referral.objects.filter(inviter=user, status=Referral.Status.REWARDED).count()
    return {
        "code": code,
        "link": f"{settings.INVITE_BASE_URL.rstrip('/')}/{code}",
        "coins": INVITE_COINS,
        "rewarded": rewarded,
    }


def redeem(user: User, code: str) -> None:
    """The new user's app passes on the code it was installed or opened with."""
    profile = getattr(user, "profile", None)
    if profile and profile.is_verified:
        raise ApiError("too_late", "Invite codes are for new accounts.", 409)
    owner = InviteCode.objects.filter(code=code.strip().upper()).select_related("user").first()
    if owner is None:
        raise ApiError("not_found", "That invite code doesn’t exist.", 404)
    if owner.user_id == user.id:
        raise ApiError("own_code", "That’s your own invite code.", 409)
    Referral.objects.get_or_create(invited=user, defaults={"inviter": owner.user})


def reward_inviter(invited: User) -> None:
    """Called once the invited person is verified (MN-3)."""
    with transaction.atomic():
        ref = (
            Referral.objects.select_for_update()
            .filter(invited=invited, status=Referral.Status.PENDING)
            .select_related("inviter")
            .first()
        )
        if ref is None:
            return
        refusal = _refusal(ref)
        if refusal:
            ref.status, ref.note = Referral.Status.REFUSED, refusal
            ref.save(update_fields=["status", "note"])
            logger.info("invite reward refused for %s: %s", invited.id, refusal)
            return
        post_entry(
            ref.inviter_id,
            INVITE_COINS,
            R.INVITE_REWARD,
            key=f"invite:{invited.id}",
            ref_type="referral",
            ref_id=ref.id,
        )
        ref.status = Referral.Status.REWARDED
        ref.save(update_fields=["status"])


def _refusal(ref: Referral) -> str:
    if ref.inviter.status != User.Status.ACTIVE:
        return "inviter_not_active"
    devices = UserDevice.objects.filter(user=ref.invited).values_list("device_hash", flat=True)
    if UserDevice.objects.filter(device_hash__in=list(devices)).exclude(user=ref.invited).exists():
        return "device_seen"  # the same phone made another account before
    return ""
