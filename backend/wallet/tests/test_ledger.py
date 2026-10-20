import threading
from datetime import datetime, timedelta

import pytest
from django.db import DatabaseError, connection, transaction

from conftest import api_client
from core.exceptions import ApiError
from wallet.models import CoinLedger
from wallet.services import LAGOS, balance, post_entry, spent_today

pytestmark = pytest.mark.django_db(transaction=True)
R = CoinLedger.Reason


def test_mn2_the_balance_is_the_sum_of_the_ledger(make_user, events):
    u = make_user()
    post_entry(u.id, 100, R.PURCHASE, key="k1")
    post_entry(u.id, 50, R.PURCHASE_BONUS, key="k2")
    post_entry(u.id, -20, R.GIFT, key="k3")
    assert (
        balance(u.id)
        == 130
        == sum(CoinLedger.objects.filter(user=u).values_list("delta", flat=True))
    )


def test_mn2_a_key_writes_once(make_user, events):
    u = make_user()
    first = post_entry(u.id, 10, R.DAILY_CHECKIN, key="same")
    again = post_entry(u.id, 10, R.DAILY_CHECKIN, key="same")
    assert first.created and not again.created
    assert again.entry.id == first.entry.id
    assert balance(u.id) == 10


def test_mn2_a_key_reused_for_something_else_is_refused(make_user, events):
    u = make_user()
    post_entry(u.id, 10, R.DAILY_CHECKIN, key="same")
    with pytest.raises(ApiError) as e:
        post_entry(u.id, 50, R.INVITE_REWARD, key="same")
    assert e.value.error_code == "key_reused"
    assert balance(u.id) == 10


def test_mn2_no_overdraft(make_user, events):
    u = make_user()
    post_entry(u.id, 10, R.DAILY_CHECKIN, key="c")
    with pytest.raises(ApiError) as e:
        post_entry(u.id, -20, R.GIFT, key="g")
    assert e.value.error_code == "insufficient_coins"
    assert balance(u.id) == 10


def test_mn2_refunds_may_go_below_zero(make_user, events):
    u = make_user()
    post_entry(u.id, -20, R.REFUND, key="r", allow_negative=True)
    assert balance(u.id) == -20


def test_mn2_concurrent_debits_never_spend_the_same_coins(make_user, events):
    u = make_user()
    post_entry(u.id, 30, R.PURCHASE, key="p")
    results = []

    def spend(i):
        try:
            post_entry(u.id, -10, R.GIFT, key=f"gift-{i}")
            results.append("ok")
        except ApiError as e:
            results.append(e.error_code)
        finally:
            connection.close()

    threads = [threading.Thread(target=spend, args=(i,)) for i in range(6)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert sorted(results) == ["insufficient_coins"] * 3 + ["ok"] * 3
    assert balance(u.id) == 0


def test_mn2_the_ledger_is_append_only(make_user, events):
    u = make_user()
    entry = post_entry(u.id, 10, R.DAILY_CHECKIN, key="c").entry
    for change in (
        lambda: CoinLedger.objects.filter(id=entry.id).update(delta=1000),
        lambda: CoinLedger.objects.filter(id=entry.id).delete(),
    ):
        with pytest.raises(DatabaseError, match="append-only"), transaction.atomic():
            change()
    assert balance(u.id) == 10


def test_every_change_tells_the_apps_the_new_balance(make_user, events):
    u = make_user()
    post_entry(u.id, 100, R.PURCHASE, key="p")
    post_entry(u.id, -20, R.GIFT, key="g")
    assert events.of(u, "wallet.updated")[-1] == {"balance": 80, "spent_today": 20}


def test_spent_today_counts_gifts_since_lagos_midnight(make_user, events):
    u = make_user()
    post_entry(u.id, 100, R.PURCHASE, key="p")
    post_entry(u.id, -20, R.GIFT, key="g1")
    post_entry(u.id, -5, R.REFUND, key="r", allow_negative=True)  # not spending
    now = datetime.now(LAGOS)
    assert spent_today(u.id, now) == 20
    tomorrow = now.replace(hour=0, minute=1) + timedelta(days=1)
    assert spent_today(u.id, tomorrow) == 0


def test_wallet_and_ledger_endpoints(make_user, events):
    u = make_user()
    post_entry(u.id, 500, R.PURCHASE, key="p")
    post_entry(u.id, 50, R.PURCHASE_BONUS, key="b")
    post_entry(u.id, -20, R.GIFT, key="g", ref_type="gift", ref_id="jollof")
    c = api_client(u)
    wallet = c.get("/api/v1/wallet").json()
    assert wallet["balance"] == 530 and wallet["spent_today"] == 20
    assert wallet["checkin"] == {"claimed_today": False, "day": 1, "coins": 10}
    rows = c.get("/api/v1/wallet/ledger").json()
    assert [r["delta"] for r in rows["entries"]] == [-20, 50, 500]
    assert rows["entries"][0]["ref_id"] == "jollof" and rows["more"] is False
    older = c.get("/api/v1/wallet/ledger", {"before": rows["entries"][0]["created_at"]}).json()
    assert [r["delta"] for r in older["entries"]] == [50, 500]


def test_unverified_users_have_no_wallet(make_user):
    assert api_client(make_user(verified=False)).get("/api/v1/wallet").status_code == 403
