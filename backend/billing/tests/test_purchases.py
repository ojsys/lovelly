import base64
import json
import threading

import pytest
from django.db import connection
from django.test import override_settings

from accounts.models import User
from billing import services
from billing.models import Purchase
from conftest import api_client
from core.exceptions import ApiError
from core.providers.store_receipts import GooglePlay, InvalidReceipt
from wallet import gifts
from wallet.models import CoinLedger
from wallet.reconcile import check_ledger
from wallet.services import balance, post_entry
from wallet.tests.conftest import gift_catalogue  # noqa: F401 (autouse)

pytestmark = pytest.mark.django_db(transaction=True)


def webhook(user, token, kind="purchased", store="google"):
    return services.handle_webhook(
        store, {"type": kind, "token": token, "account_id": str(user.id)}, {}
    )


def test_mn1_packs_give_the_big_number_with_the_bonus_inside(make_user, events, acknowledged):
    u = make_user()
    res = services.verify(u, "google", "coins_550", "fake:coins_550:1")
    assert res == {"status": "credited", "balance": 550}
    rows = CoinLedger.objects.filter(user=u).order_by("reason")
    assert [(r.reason, r.delta) for r in rows] == [("purchase", 500), ("purchase_bonus", 50)]
    assert acknowledged == ["fake:coins_550:1"]  # told the store we delivered


def test_mn1_the_pack_list_is_the_prd_one(make_user):
    packs = api_client(make_user()).get("/api/v1/wallet/packs").json()
    assert [(p["product_id"], p["coins"], p["bonus"], p["tag"]) for p in packs] == [
        ("coins_100", 100, 0, ""),
        ("coins_550", 550, 50, "Popular"),
        ("coins_1200", 1200, 200, ""),
        ("coins_3000", 3000, 700, "Best value"),
    ]


def test_mn4_the_same_purchase_credits_once_from_app_and_webhook(make_user, events, acknowledged):
    u = make_user()
    token = "fake:coins_1200:2"
    services.verify(u, "google", "coins_1200", token)
    webhook(u, token)
    webhook(u, token)
    services.verify(u, "google", "coins_1200", token)
    assert balance(u.id) == 1200
    assert Purchase.objects.get().status == "credited"


def test_mn4_webhook_first_then_app(make_user, events, acknowledged):
    u = make_user()
    webhook(u, "fake:coins_100:3", store="apple")
    assert balance(u.id) == 100
    assert services.verify(u, "apple", "coins_100", "fake:coins_100:3")["status"] == "credited"
    assert balance(u.id) == 100


def test_mn4_replayed_webhooks_at_the_same_time_credit_once(make_user, events, acknowledged):
    u = make_user()
    errors = []

    def deliver():
        try:
            webhook(u, "fake:coins_3000:4")
        except Exception as e:  # noqa: BLE001
            errors.append(e)
        finally:
            connection.close()

    threads = [threading.Thread(target=deliver) for _ in range(5)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert errors == []
    assert balance(u.id) == 3000
    assert CoinLedger.objects.filter(user=u).count() == 2
    assert check_ledger() == []


def test_mn4_pending_payments_wait(make_user, events, acknowledged):
    u = make_user()
    res = services.verify(u, "google", "coins_100", "fake:coins_100:5:pending")
    assert res["status"] == "pending" and balance(u.id) == 0
    assert acknowledged == []
    webhook(u, "fake:coins_100:5")  # paid later (e.g. cash at a shop)
    assert balance(u.id) == 100


@pytest.mark.parametrize(
    ("product", "token", "code"),
    [
        ("coins_100", "fake:coins_550:6", "invalid_receipt"),  # says it's a different pack
        ("coins_999", "fake:coins_999:6", "unknown_product"),
        ("coins_100", "forged", "invalid_receipt"),
        ("coins_100", "fake:coins_100:6:cancelled", "not_paid"),
    ],
)
def test_mn4_purchases_the_store_doesnt_confirm(make_user, events, product, token, code):
    u = make_user()
    with pytest.raises(ApiError) as e:
        services.verify(u, "google", product, token)
    assert e.value.error_code == code
    assert balance(u.id) == 0


def test_mn4_someone_elses_purchase(make_user, events, acknowledged):
    a, b = make_user("Ada"), make_user("Tobi")
    services.verify(a, "google", "coins_100", "fake:coins_100:7")
    with pytest.raises(ApiError) as e:
        services.verify(b, "google", "coins_100", "fake:coins_100:7")
    assert e.value.error_code == "not_yours"
    assert (balance(a.id), balance(b.id)) == (100, 0)


def test_refunds_take_the_coins_back_even_after_spending(video_session, events, acknowledged):
    s, u, _ = video_session
    services.verify(u, "google", "coins_550", "fake:coins_550:8")
    for i, gift in enumerate(["diamond", "crown", "talking_drum"]):  # 500 coins of gifts
        gifts.send(u, gift, f"tap-{i}", session_id=s.id)
    webhook(u, "fake:coins_550:8", kind="refunded")
    webhook(u, "fake:coins_550:8", kind="refunded")  # replayed
    assert balance(u.id) == -500  # M6 decision 5
    assert User.objects.get(id=u.id).risk_score == services.REFUND_RISK
    with pytest.raises(ApiError) as e:  # can't spend until topped up
        post_entry(u.id, -5, CoinLedger.Reason.GIFT, key="more")
    assert e.value.error_code == "insufficient_coins"
    assert check_ledger() == []


def test_a_refund_before_the_credit_stops_the_credit(make_user, events, acknowledged):
    u = make_user()
    services.verify(u, "google", "coins_100", "fake:coins_100:9:pending")
    webhook(u, "fake:coins_100:9", kind="refunded")
    assert services.verify(u, "google", "coins_100", "fake:coins_100:9")["status"] == "refunded"
    assert balance(u.id) == 0


def test_mn2_reconciliation_finds_planted_mismatches(make_user, events, acknowledged):
    u = make_user()
    services.verify(u, "google", "coins_100", "fake:coins_100:10")
    assert check_ledger() == []
    Purchase.objects.create(
        user=u, store="google", product_id="coins_550", txn_id="GHOST", status="credited"
    )
    post_entry(u.id, -20, CoinLedger.Reason.GIFT, key="orphan-gift")
    findings = check_ledger()
    assert any("credited 0, expected 550" in f for f in findings)
    assert any("gift debits with no gift" in f for f in findings)


def test_purchase_endpoint(make_user, events, acknowledged):
    c = api_client(make_user())
    body = {"store": "google", "product_id": "coins_100", "token": "fake:coins_100:11"}
    assert c.post("/api/v1/purchases/verify", body, format="json").json()["balance"] == 100
    assert c.post("/api/v1/purchases/verify", body, format="json").json()["balance"] == 100


def test_webhook_endpoints_need_no_login_but_valid_data(make_user, events, acknowledged, client):
    u = make_user()
    body = {"type": "purchased", "token": "fake:coins_100:12", "account_id": str(u.id)}
    for _ in range(3):
        res = client.post("/api/v1/webhooks/google", body, content_type="application/json")
        assert res.status_code == 200
    assert balance(u.id) == 100
    bad = client.post(
        "/api/v1/webhooks/apple",
        {"type": "purchased", "token": "forged"},
        content_type="application/json",
    )
    assert bad.status_code == 400


def pubsub(data: dict) -> dict:
    return {"message": {"data": base64.b64encode(json.dumps(data).encode()).decode()}}


@override_settings(PLAY_PACKAGE_NAME="app.lovelly", PLAY_RTDN_SECRET="s3cret")
def test_google_notifications_are_authenticated_and_read():
    g = GooglePlay()
    voided = pubsub(
        {
            "packageName": "app.lovelly",
            "voidedPurchaseNotification": {
                "purchaseToken": "t",
                "orderId": "GPA.1",
                "productType": 2,
            },
        }
    )
    with pytest.raises(InvalidReceipt):
        g.parse_webhook(voided, {"secret": "wrong"})
    with pytest.raises(InvalidReceipt):
        g.parse_webhook(pubsub({"packageName": "other.app"}), {"secret": "s3cret"})
    (event,) = g.parse_webhook(voided, {"secret": "s3cret"})
    assert (event.kind, event.store, event.txn_id) == ("refunded", "google", "GPA.1")
    test = pubsub({"packageName": "app.lovelly", "testNotification": {"version": "1.0"}})
    assert g.parse_webhook(test, {"secret": "s3cret"})[0].kind == "test"
