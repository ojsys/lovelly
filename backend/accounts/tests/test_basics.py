from datetime import date

import pytest
from django.utils import timezone

from accounts.models import DeniedPhone, User

from .conftest import basics, sign_in

pytestmark = pytest.mark.django_db


def _years_ago(years, days=0):
    today = timezone.now().date()
    return (
        date(today.year - years, today.month, today.day)
        if not days
        else date.fromordinal(date(today.year - years, today.month, today.day).toordinal() + days)
    )


def test_basics_moves_to_selfie(api):
    sign_in(api)
    res = basics(api)
    assert res.status_code == 200
    assert res.json()["next_step"] == "selfie"


def test_fr3_under_18_is_banned_and_phone_denied(api):
    session = sign_in(api)
    res = basics(api, dob=_years_ago(18, days=1).isoformat())  # 18 tomorrow
    assert res.status_code == 403
    assert res.json()["code"] == "underage"

    user = User.objects.get(phone="+2348031234542")
    assert user.status == User.Status.BANNED and not user.is_active
    assert DeniedPhone.objects.count() == 1
    assert not DeniedPhone.objects.filter(phone_hash__contains="803").exists()

    # Tokens no longer work, and the number can't sign up again.
    assert api.get("/api/v1/me/verification").status_code == 401
    refresh = api.post("/api/v1/auth/refresh", {"refresh": session["refresh"]}, format="json")
    assert refresh.status_code == 401
    api.credentials()
    again = api.post("/api/v1/auth/otp/request", {"phone": "08031234542"}, format="json")
    assert again.status_code == 403
    assert again.json()["code"] == "phone_denied"


def test_fr3_18_today_is_allowed(api):
    sign_in(api)
    assert basics(api, dob=_years_ago(18).isoformat()).status_code == 200


def test_fr3_date_of_birth_is_never_returned(api):
    sign_in(api)
    body = basics(api).json()
    assert "dob" not in str(body) and "1999" not in str(body)


def test_must_confirm_18_plus(api):
    sign_in(api)
    res = api.put(
        "/api/v1/me/basics",
        {"first_name": "Ada", "dob": "1999-03-14", "gender": "woman", "adult_confirmed": False},
        format="json",
    )
    assert res.status_code == 400
    assert "adult_confirmed" in res.json()["fields"]


def test_basics_needs_sign_in(api):
    assert basics(api).status_code == 401


def test_accepts_dart_style_midnight_datetime_for_dob(api):
    sign_in(api)
    res = api.put(
        "/api/v1/me/basics",
        {
            "first_name": "Ada",
            "dob": "1999-03-14T00:00:00.000",
            "gender": "woman",
            "adult_confirmed": True,
        },
        format="json",
    )
    assert res.status_code == 200
