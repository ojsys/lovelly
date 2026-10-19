import pytest

from accounts.models import User
from core.providers.sms import FakeSMSProvider

from .conftest import last_code

pytestmark = pytest.mark.django_db

REQUEST = "/api/v1/auth/otp/request"
VERIFY = "/api/v1/auth/otp/verify"


def test_fr1_sends_a_6_digit_code_by_text(api, clock):
    res = api.post(REQUEST, {"phone": "0803 123 4542"}, format="json")
    assert res.status_code == 200
    assert res.json() == {"phone": "+2348031234542", "masked": "+234 803 ••• ••42", "resend_in": 60}
    phone, code, channel = FakeSMSProvider.outbox[-1]
    assert (phone, channel) == ("+2348031234542", "sms")
    assert len(code) == 6 and code.isdigit()


def test_fr1_get_a_call_instead_sends_by_voice(api, clock):
    api.post(REQUEST, {"phone": "08031234542", "channel": "voice"}, format="json")
    assert FakeSMSProvider.outbox[-1][2] == "voice"


def test_rejects_an_invalid_phone(api):
    res = api.post(REQUEST, {"phone": "12345"}, format="json")
    assert res.status_code == 400
    assert res.json()["code"] == "phone_invalid"


def test_fr1_resend_waits_60_seconds(api, clock):
    api.post(REQUEST, {"phone": "08031234542"}, format="json")
    clock.advance(30)
    res = api.post(REQUEST, {"phone": "08031234542"}, format="json")
    assert res.status_code == 429
    assert res.json()["code"] == "otp_too_soon"
    assert res.json()["retry_after"] == 31
    clock.advance(31)
    assert api.post(REQUEST, {"phone": "08031234542"}, format="json").status_code == 200


def test_get_a_call_instead_works_during_the_text_countdown(api, clock):
    api.post(REQUEST, {"phone": "08031234542"}, format="json")
    clock.advance(10)
    res = api.post(REQUEST, {"phone": "08031234542", "channel": "voice"}, format="json")
    assert res.status_code == 200
    assert FakeSMSProvider.outbox[-1][2] == "voice"


def test_fr1_at_most_3_codes_an_hour_across_channels(api, clock):
    for channel in ("sms", "voice", "sms"):
        assert (
            api.post(
                REQUEST, {"phone": "08031234542", "channel": channel}, format="json"
            ).status_code
            == 200
        )
        clock.advance(61)
    res = api.post(REQUEST, {"phone": "08031234542"}, format="json")
    assert res.status_code == 429
    assert res.json()["code"] == "otp_limit"
    clock.advance(3600)
    assert api.post(REQUEST, {"phone": "08031234542"}, format="json").status_code == 200


def test_fr1_code_expires_after_5_minutes(api, clock):
    api.post(REQUEST, {"phone": "08031234542"}, format="json")
    code = last_code()
    clock.advance(5 * 60 + 1)
    res = api.post(VERIFY, {"phone": "08031234542", "code": code}, format="json")
    assert res.json()["code"] == "otp_expired"


def test_fr1_wrong_code_then_burned_after_5_tries(api, clock):
    api.post(REQUEST, {"phone": "08031234542"}, format="json")
    code = last_code()
    wrong = "000000" if code != "000000" else "111111"
    for _ in range(4):
        assert (
            api.post(VERIFY, {"phone": "08031234542", "code": wrong}, format="json").json()["code"]
            == "otp_invalid"
        )
    assert (
        api.post(VERIFY, {"phone": "08031234542", "code": wrong}, format="json").json()["code"]
        == "otp_expired"
    )
    assert (
        api.post(VERIFY, {"phone": "08031234542", "code": code}, format="json").json()["code"]
        == "otp_expired"
    )


def test_fr1_correct_code_signs_in_and_is_single_use(api, clock):
    api.post(REQUEST, {"phone": "08031234542"}, format="json")
    code = last_code()
    res = api.post(VERIFY, {"phone": "+234 803 123 4542", "code": code}, format="json")
    assert res.status_code == 200
    assert res.json()["next_step"] == "basics"
    assert {"access", "refresh"} <= res.json().keys()
    again = api.post(VERIFY, {"phone": "08031234542", "code": code}, format="json")
    assert again.json()["code"] == "otp_expired"


def test_fr1_one_account_per_phone_number(api, clock):
    for _ in range(2):
        api.post(REQUEST, {"phone": "08031234542"}, format="json")
        api.post(VERIFY, {"phone": "08031234542", "code": last_code()}, format="json")
        clock.advance(61)
    assert User.objects.filter(phone="+2348031234542").count() == 1
