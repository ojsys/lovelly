"""Phone codes (FR-1): 6 digits, 5 min expiry, 3 per hour, 60 s between sends.

The 60 s gap is per channel, so "get a call instead" works while the text countdown runs
(Verify screen); the 3-per-hour limit covers both channels.
"""

import hashlib
import hmac
import secrets
import time

from django.conf import settings
from django.core.cache import cache
from rest_framework import status

from accounts.models import DeniedPhone
from core.exceptions import ApiError
from core.providers import get_provider

from .phones import phone_hash


def _code_key(phone):
    return f"otp:code:{phone}"


def _sends_key(phone):
    return f"otp:sends:{phone}"


def _digest(phone: str, code: str) -> str:
    return hmac.new(
        settings.SECRET_KEY.encode(), f"{phone}:{code}".encode(), hashlib.sha256
    ).hexdigest()


def ensure_not_denied(phone: str) -> None:
    if DeniedPhone.objects.filter(phone_hash=phone_hash(phone)).exists():
        raise ApiError(
            "phone_denied", "This number can't be used on Lovelly.", status.HTTP_403_FORBIDDEN
        )


def request_code(phone: str, channel: str) -> int:
    """Send a new code. Returns seconds until another code may be requested."""
    ensure_not_denied(phone)
    now = time.time()
    sends = [(t, c) for t, c in cache.get(_sends_key(phone), []) if now - t < 3600]
    last_on_channel = max((t for t, c in sends if c == channel), default=None)
    if last_on_channel and now - last_on_channel < settings.OTP_RESEND_SECONDS:
        wait = int(settings.OTP_RESEND_SECONDS - (now - last_on_channel)) + 1
        raise ApiError(
            "otp_too_soon", "Wait before asking for another code.", 429, retry_after=wait
        )
    if len(sends) >= settings.OTP_MAX_PER_HOUR:
        wait = int(3600 - (now - sends[0][0])) + 1
        raise ApiError(
            "otp_limit", "Too many codes requested. Try again later.", 429, retry_after=wait
        )

    code = f"{secrets.randbelow(10**settings.OTP_LENGTH):0{settings.OTP_LENGTH}d}"
    entry = {
        "digest": _digest(phone, code),
        "attempts": 0,
        "expires_at": now + settings.OTP_TTL_SECONDS,
    }
    cache.set(_code_key(phone), entry, settings.OTP_TTL_SECONDS)
    cache.set(_sends_key(phone), [*sends, (now, channel)], 3600)
    get_provider("sms").send_code(phone, code, channel)
    return settings.OTP_RESEND_SECONDS


def check_code(phone: str, code: str) -> None:
    """Consume the code for `phone`, or raise. Codes burn after OTP_MAX_ATTEMPTS wrong tries."""
    entry = cache.get(_code_key(phone))
    remaining = int(entry["expires_at"] - time.time()) if entry else 0
    if entry is None or remaining <= 0:
        raise ApiError("otp_expired", "That code has expired. Ask for a new one.")
    if not hmac.compare_digest(entry["digest"], _digest(phone, code)):
        entry["attempts"] += 1
        if entry["attempts"] >= settings.OTP_MAX_ATTEMPTS:
            cache.delete(_code_key(phone))
            raise ApiError("otp_expired", "Too many wrong tries. Ask for a new code.")
        cache.set(_code_key(phone), entry, remaining)
        raise ApiError("otp_invalid", "That code isn't right.")
    cache.delete(_code_key(phone))
