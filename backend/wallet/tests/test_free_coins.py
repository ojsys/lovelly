from datetime import UTC, date, datetime, timedelta

import pytest

from accounts.models import User, UserDevice
from conftest import api_client
from core.exceptions import ApiError
from wallet import free_coins
from wallet.models import Referral
from wallet.services import balance, lagos_today

pytestmark = pytest.mark.django_db(transaction=True)
D = date(2026, 10, 20)


def test_mn3_daily_checkin_pays_10_once_a_day(make_user, events):
    u = make_user()
    assert free_coins.claim_daily(u, D) == {"claimed_today": True, "day": 1, "coins": 10}
    assert free_coins.claim_daily(u, D)["claimed_today"]  # a double tap changes nothing
    assert balance(u.id) == 10


def test_mn3_the_streak_counts_days_in_a_row_and_restarts_after_7(make_user, events):
    u = make_user()
    days = [free_coins.claim_daily(u, D + timedelta(days=i))["day"] for i in range(9)]
    assert days == [1, 2, 3, 4, 5, 6, 7, 1, 2]
    assert balance(u.id) == 90  # +10 every day, no day-7 extra (M6 decision 2)


def test_mn3_a_missed_day_resets_the_streak(make_user, events):
    u = make_user()
    free_coins.claim_daily(u, D)
    free_coins.claim_daily(u, D + timedelta(days=1))
    assert free_coins.checkin_state(u.id, D + timedelta(days=2))["day"] == 3
    assert free_coins.checkin_state(u.id, D + timedelta(days=3))["day"] == 1
    assert free_coins.claim_daily(u, D + timedelta(days=3))["day"] == 1


def test_mn3_days_change_at_lagos_midnight():
    assert lagos_today(datetime(2026, 10, 20, 22, 59, tzinfo=UTC)) == D
    assert lagos_today(datetime(2026, 10, 20, 23, 0, tzinfo=UTC)) == D + timedelta(days=1)


def test_mn3_claim_endpoint(make_user, events):
    c = api_client(make_user())
    body = c.post("/api/v1/wallet/claim-daily").json()
    assert body["balance"] == 10 and body["checkin"]["claimed_today"]
    assert c.post("/api/v1/wallet/claim-daily").json()["balance"] == 10


def invited_pair(make_user, inviter_name="Ada"):
    inviter = make_user(inviter_name)
    code = free_coins.invite(inviter)["code"]
    new = make_user("Kwame", verified=False)
    free_coins.redeem(new, code.lower())
    return inviter, new


def test_mn3_invite_code_is_stable_and_linkable(make_user):
    u = make_user()
    first, again = free_coins.invite(u), free_coins.invite(u)
    assert first == again
    assert len(first["code"]) == 8 and first["link"].endswith("/" + first["code"])
    assert first["coins"] == 50 and first["rewarded"] == 0


def test_mn3_inviter_earns_50_when_the_friend_is_verified(make_user, events):
    inviter, new = invited_pair(make_user)
    assert balance(inviter.id) == 0  # not yet: they must pass the selfie check
    free_coins.reward_inviter(new)
    free_coins.reward_inviter(new)  # once only
    assert balance(inviter.id) == 50
    assert balance(new.id) == 0
    assert free_coins.invite(inviter)["rewarded"] == 1


def test_mn3_verification_triggers_the_reward(make_user, events, monkeypatch):
    from accounts.services import onboarding

    inviter, new = invited_pair(make_user)
    monkeypatch.setattr(
        onboarding,
        "state",
        lambda u: type("S", (), {"phone_verified": True, "basics_done": True, "selfie": "passed"}),
    )
    onboarding._refresh_verified(new)
    assert balance(inviter.id) == 50


def test_mn3_no_reward_when_the_phone_made_another_account(make_user, events):
    inviter, new = invited_pair(make_user)
    old = make_user("Old")
    UserDevice.objects.create(user=old, device_hash="same-phone")
    UserDevice.objects.create(user=new, device_hash="same-phone")
    free_coins.reward_inviter(new)
    assert balance(inviter.id) == 0
    assert Referral.objects.get(invited=new).note == "device_seen"


def test_mn3_no_reward_for_a_banned_inviter(make_user, events):
    inviter, new = invited_pair(make_user)
    User.objects.filter(id=inviter.id).update(status=User.Status.BANNED)
    free_coins.reward_inviter(new)
    assert balance(inviter.id) == 0


@pytest.mark.parametrize("case", ["own", "verified", "unknown"])
def test_mn3_codes_that_dont_count(make_user, case):
    u = make_user(verified=case == "verified")
    code = {"own": free_coins.invite(u)["code"], "unknown": "NOPE2345"}.get(case)
    if case == "verified":
        code = free_coins.invite(make_user("Other"))["code"]
    with pytest.raises(ApiError) as e:
        free_coins.redeem(u, code)
    assert (
        e.value.error_code
        == {"own": "own_code", "verified": "too_late", "unknown": "not_found"}[case]
    )


def test_mn3_invite_endpoints(make_user):
    inviter = make_user()
    code = api_client(inviter).get("/api/v1/me/invite").json()["code"]
    new = make_user("Kwame", verified=False)
    assert (
        api_client(new).post("/api/v1/me/invite/redeem", {"code": code}, format="json").status_code
        == 204
    )
    assert Referral.objects.get(invited=new).inviter == inviter
