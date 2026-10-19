import pytest

from accounts.models import SocialAccount, User

from .conftest import last_code

pytestmark = pytest.mark.django_db

SOCIAL = "/api/v1/auth/social"


def social(api, subject="g-123"):
    body = api.post(
        SOCIAL, {"provider": "google", "id_token": f"fake:{subject}"}, format="json"
    ).json()
    api.credentials(HTTP_AUTHORIZATION=f"Bearer {body['access']}")
    return body


def verify_phone(api, phone="08031234542"):
    api.post("/api/v1/auth/otp/request", {"phone": phone}, format="json")
    return api.post("/api/v1/auth/otp/verify", {"phone": phone, "code": last_code()}, format="json")


def test_fr2_social_sign_in_still_needs_a_phone(api):
    assert social(api)["next_step"] == "phone"
    assert api.get("/api/v1/me/verification").json()["phone_verified"] is False


def test_fr2_social_user_adds_a_phone(api):
    social(api)
    res = verify_phone(api)
    assert res.json()["next_step"] == "basics"
    account = SocialAccount.objects.get(subject="g-123")
    assert account.user.phone == "+2348031234542"


def test_fr2_social_identity_joins_the_existing_phone_account(api):
    owner = User.objects.create_user(phone="+2348031234542")
    social(api)
    res = verify_phone(api)
    assert res.status_code == 200
    assert SocialAccount.objects.get(subject="g-123").user == owner
    assert User.objects.count() == 1


def test_fr2_returning_social_user_gets_the_same_account(api):
    social(api)
    verify_phone(api)
    api.credentials()
    assert social(api)["next_step"] == "basics"
    assert User.objects.count() == 1


def test_invalid_social_token_is_refused(api):
    res = api.post(SOCIAL, {"provider": "apple", "id_token": "garbage"}, format="json")
    assert res.status_code == 401
    assert res.json()["code"] == "social_invalid"
