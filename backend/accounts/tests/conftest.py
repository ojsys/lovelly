import pytest
from django.core.cache import cache
from rest_framework.test import APIClient

from accounts.services import onboarding
from core.providers.sms import FakeSMSProvider

JPEG = b"\xff\xd8\xff\xe0" + b"0" * 64


@pytest.fixture(autouse=True)
def _clean():
    cache.clear()
    FakeSMSProvider.outbox.clear()
    yield
    cache.clear()


@pytest.fixture
def api():
    return APIClient()


@pytest.fixture
def clock(monkeypatch):
    """Controls time.time() inside the OTP service."""

    class Clock:
        now = 1_800_000_000.0

        def advance(self, seconds):
            self.now += seconds

    c = Clock()
    monkeypatch.setattr("accounts.services.otp.time.time", lambda: c.now)
    return c


def last_code():
    return FakeSMSProvider.outbox[-1][1]


def sign_in(api, phone="08031234542"):
    """Request + verify a code; returns the session body and leaves `api` authenticated."""
    api.post("/api/v1/auth/otp/request", {"phone": phone}, format="json")
    body = api.post(
        "/api/v1/auth/otp/verify", {"phone": phone, "code": last_code()}, format="json"
    ).json()
    api.credentials(HTTP_AUTHORIZATION=f"Bearer {body['access']}")
    return body


def basics(api, dob="1999-03-14"):
    return api.put(
        "/api/v1/me/basics",
        {"first_name": "Ada", "dob": dob, "gender": "woman", "adult_confirmed": True},
        format="json",
    )


def selfie(api):
    from django.core.files.uploadedfile import SimpleUploadedFile

    return api.post(
        "/api/v1/me/selfie",
        {
            "pose_front": SimpleUploadedFile("front.jpg", JPEG, "image/jpeg"),
            "pose_left": SimpleUploadedFile("left.jpg", JPEG, "image/jpeg"),
        },
        format="multipart",
    )


__all__ = ["onboarding", "sign_in", "basics", "selfie", "last_code", "JPEG"]
