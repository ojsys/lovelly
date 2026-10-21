"""Device identifiers (X-Device-Id) for bans that outlive a new phone number (SF-6)."""

import hashlib
import hmac

from django.conf import settings
from rest_framework import status

from accounts.models import DeniedDevice, UserDevice
from core.exceptions import ApiError


def device_hash(raw: str) -> str:
    return hmac.new(settings.SECRET_KEY.encode(), raw.encode(), hashlib.sha256).hexdigest()


def from_request(request) -> str | None:
    raw = (request.headers.get("X-Device-Id") or "").strip()
    return device_hash(raw) if 8 <= len(raw) <= 128 else None


def ensure_not_denied(request) -> None:
    h = from_request(request)
    if h and DeniedDevice.objects.filter(device_hash=h).exists():
        raise ApiError(
            "device_denied", "This device can't be used on Lovelly.", status.HTTP_403_FORBIDDEN
        )


def record(user, request) -> None:
    h = from_request(request)
    if h:
        UserDevice.objects.update_or_create(user=user, device_hash=h)
