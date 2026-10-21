import pytest

from billing import plus, services
from billing.models import Subscription
from conftest import api_client
from core.exceptions import ApiError

pytestmark = pytest.mark.django_db(transaction=True)


def sub_webhook(user, token):
    return services.handle_webhook(
        "google", {"type": "subscription", "token": token, "account_id": str(user.id)}, {}
    )


def test_mn6_buying_plus_makes_you_a_subscriber(make_user, acknowledged):
    u = make_user()
    status = services.verify_plus(u, "google", "korram_plus", "fakesub:month:1")
    assert status["active"] and status["plan"] == "month" and status["auto_renews"]
    assert plus.is_plus(u.id)
    assert acknowledged == ["fakesub:month:1"]


def test_mn6_store_notifications_keep_it_in_step(make_user, acknowledged):
    u = make_user()
    services.verify_plus(u, "google", "korram_plus", "fakesub:month:2")
    sub_webhook(u, "fakesub:month:2:grace")  # payment retrying: still Plus
    assert plus.is_plus(u.id)
    sub_webhook(u, "fakesub:month:2:expired")
    assert not plus.is_plus(u.id)
    sub_webhook(u, "fakesub:month:2")  # renewed again
    assert plus.is_plus(u.id)
    assert Subscription.objects.count() == 1


def test_mn6_cancelled_stays_active_until_the_period_ends(make_user, acknowledged):
    u = make_user()
    services.verify_plus(u, "google", "korram_plus", "fakesub:year:3:cancelled")
    assert plus.is_plus(u.id)


def test_mn6_a_revoke_is_final(make_user, acknowledged):
    u = make_user()
    services.verify_plus(u, "google", "korram_plus", "fakesub:month:4")
    sub_webhook(u, "fakesub:month:4:revoked")
    sub_webhook(u, "fakesub:month:4")  # a late "active" replay
    assert not plus.is_plus(u.id)


def test_mn6_someone_elses_subscription(make_user, acknowledged):
    a, b = make_user("Ada"), make_user("Tobi")
    services.verify_plus(a, "google", "korram_plus", "fakesub:month:5")
    with pytest.raises(ApiError) as e:
        services.verify_plus(b, "google", "korram_plus", "fakesub:month:5")
    assert e.value.error_code == "not_yours"


def test_plans_and_spend_settings_endpoints(make_user, acknowledged):
    u = make_user()
    c = api_client(u)
    plans = c.get("/api/v1/plus/plans").json()
    assert [p["plan"] for p in plans] == ["week", "month", "year"]
    assert plans[1]["google_product"] == "korram_plus" and plans[1]["apple_product"] == "plus_month"
    settings = c.get("/api/v1/me/spend-settings").json()
    assert settings["daily_cap"] == 100 and not settings["payg_enabled"]  # MN-9 default
    assert settings["plus"]["active"] is False
    res = c.patch(
        "/api/v1/me/spend-settings", {"payg_enabled": True, "daily_cap": 0}, format="json"
    )
    assert res.json()["payg_enabled"] and res.json()["daily_cap"] == 0
    bad = c.patch("/api/v1/me/spend-settings", {"daily_cap": 75}, format="json")
    assert bad.status_code == 400
    body = {"store": "apple", "product_id": "plus_week", "token": "fakesub:week:6"}
    assert c.post("/api/v1/plus/verify", body, format="json").json()["active"]
    assert c.get("/api/v1/me/spend-settings").json()["plus"]["plan"] == "week"
