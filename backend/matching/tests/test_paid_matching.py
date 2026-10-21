import time
from datetime import timedelta

import pytest
from django.utils import timezone

from accounts.models import Profile, User
from billing.models import SpendSettings, Subscription
from conftest import api_client
from core.exceptions import ApiError
from matching import friend_calls, pricing, service
from matching.models import MatchSession
from wallet import gifts, holds
from wallet.models import CoinLedger
from wallet.services import balance, post_entry
from wallet.tests.conftest import gift_catalogue  # noqa: F401 (autouse)

pytestmark = pytest.mark.django_db(transaction=True)
WOMEN = {"gender": "women"}
BOTH = {"gender": "women", "region": "nigeria"}


def payg(user, coins=100, cap=100):
    SpendSettings.objects.update_or_create(
        user=user, defaults={"payg_enabled": True, "daily_cap": cap}
    )
    if coins:
        post_entry(user.id, coins, CoinLedger.Reason.PURCHASE, key=f"fund:{user.id}:{coins}")


def subscribe(user, plan="month"):
    Subscription.objects.create(
        user=user,
        plan=plan,
        store="google",
        status="active",
        current_period_end=timezone.now() + timedelta(days=30),
        original_txn_id=f"sub-{user.id}",
    )


@pytest.fixture
def seeker_and_woman(make_user, redis_db, events):
    seeker = make_user("Kwame")
    User.objects.filter(id=seeker.id).update(gender="man")
    seeker.refresh_from_db()
    woman = make_user("Ada")
    return seeker, woman


def match(seeker, other, filters=WOMEN):
    service.join(seeker, "text", filters, accept_charge=True)
    service.join(other, "text")
    (session,) = service.run_tick()
    return session


def ran_for(session, seconds):
    MatchSession.objects.filter(id=session.id).update(
        started_at=timezone.now() - timedelta(seconds=seconds)
    )


def paid_rows(user):
    return list(
        CoinLedger.objects.filter(
            user=user, reason__in=[CoinLedger.Reason.FILTERED_MATCH, CoinLedger.Reason.REMATCH]
        ).values_list("delta", flat=True)
    )


# --- Quotes (MN-7, MN-12) ----------------------------------------------------------------


def test_mn7_filters_add_up(seeker_and_woman):
    seeker, _ = seeker_and_woman
    payg(seeker)
    q = pricing.quote(seeker, BOTH)
    assert [(line["kind"], line["cost"]) for line in q["lines"]] == [("gender", 8), ("region", 5)]
    assert q["cost"] == 13 and q["can_pay"] and q["cap_left"] == 100


def test_mn7_no_filters_is_free(seeker_and_woman):
    q = pricing.quote(seeker_and_woman[0], {"gender": "everyone", "region": "global"})
    assert q["cost"] == 0 and q["free_reason"] == "no_filters"


def test_mn12_subscribers_pay_nothing_even_with_payg_on(seeker_and_woman):
    seeker, _ = seeker_and_woman
    payg(seeker)
    subscribe(seeker)
    q = pricing.quote(seeker, BOTH)
    assert q["cost"] == 0 and q["free_reason"] == "plus"


@pytest.mark.parametrize(
    ("setup", "reason"),
    [
        (lambda u: None, "payg_off"),
        (lambda u: payg(u, coins=10), "low_balance"),
        (
            lambda u: payg(u, coins=100, cap=50) or post_entry(u.id, -45, "gift", key="spent"),
            "cap_reached",
        ),
    ],
)
def test_mn9_mn11_when_a_paid_filter_cant_be_used(seeker_and_woman, setup, reason):
    seeker, _ = seeker_and_woman
    setup(seeker)
    assert pricing.quote(seeker, BOTH)["reason"] == reason


def test_quote_endpoint(seeker_and_woman):
    seeker, _ = seeker_and_woman
    payg(seeker)
    res = api_client(seeker).post(
        "/api/v1/match/quote", {"mode": "video", "filters": WOMEN}, format="json"
    )
    assert res.json()["cost"] == 8 and res.json()["available"] == 100


# --- Joining ------------------------------------------------------------------------------


def test_mn7_a_paid_join_needs_the_charge_accepted(seeker_and_woman):
    seeker, _ = seeker_and_woman
    payg(seeker)
    with pytest.raises(ApiError) as e:
        service.join(seeker, "text", WOMEN)
    assert e.value.error_code == "charge_not_accepted"
    assert e.value.extra["quote"]["cost"] == 8
    assert not service.is_queued(seeker.id)


def test_fr8_filters_are_locked_without_plus_or_payg(seeker_and_woman):
    with pytest.raises(ApiError) as e:
        service.join(seeker_and_woman[0], "text", WOMEN, accept_charge=True)
    assert e.value.error_code == "filters_locked"


def test_fr8_nearby_needs_a_state(seeker_and_woman):
    seeker, _ = seeker_and_woman
    payg(seeker)
    with pytest.raises(ApiError) as e:
        service.join(seeker, "text", {"region": "nearby"}, accept_charge=True)
    assert e.value.error_code == "state_needed"


def test_mn8_joining_holds_the_coins_and_leaving_releases_them(seeker_and_woman):
    seeker, _ = seeker_and_woman
    payg(seeker)
    service.join(seeker, "text", BOTH, accept_charge=True)
    assert holds.held(seeker.id) == 13 and holds.available(seeker.id) == 87
    assert balance(seeker.id) == 100  # nothing taken yet
    service.leave(seeker.id)
    assert holds.held(seeker.id) == 0 and paid_rows(seeker) == []


def test_mn8_held_coins_cant_be_spent_on_gifts(seeker_and_woman):
    seeker, _ = seeker_and_woman
    payg(seeker, coins=20)
    service.join(seeker, "text", WOMEN, accept_charge=True)  # 8 held, 12 available
    with pytest.raises(ApiError) as e:
        post_entry(seeker.id, -15, CoinLedger.Reason.GIFT, key="too-much")
    assert e.value.error_code == "insufficient_coins"
    assert balance(seeker.id) == 20


def test_mn9_the_cap_stops_paid_filters_but_not_free_matching(seeker_and_woman):
    seeker, woman = seeker_and_woman
    payg(seeker, coins=100, cap=50)
    post_entry(seeker.id, -45, CoinLedger.Reason.GIFT, key="spent-today")
    with pytest.raises(ApiError) as e:
        service.join(seeker, "text", WOMEN, accept_charge=True)
    assert e.value.error_code == "cap_reached"
    service.join(seeker, "text")  # free still works
    service.join(woman, "text")
    assert len(service.run_tick()) == 1


def test_mn9_no_cap(seeker_and_woman):
    seeker, _ = seeker_and_woman
    payg(seeker, coins=300, cap=0)
    post_entry(seeker.id, -250, CoinLedger.Reason.GIFT, key="spent-a-lot")
    assert pricing.quote(seeker, WOMEN)["can_pay"]


# --- The 5-second rule (MN-8) ----------------------------------------------------------------


def test_mn8_skipped_within_5s_costs_nothing(seeker_and_woman):
    seeker, woman = seeker_and_woman
    payg(seeker)
    s = match(seeker, woman)
    assert holds.amount(seeker.id, str(s.id)) == 8
    ran_for(s, 3)
    service.end_session(s.id, woman, "next")  # either person skipping counts
    assert paid_rows(seeker) == [] and holds.amount(seeker.id, str(s.id)) == 0
    assert balance(seeker.id) == 100


def test_mn8_a_match_that_runs_5s_is_charged_once(seeker_and_woman):
    seeker, woman = seeker_and_woman
    payg(seeker)
    s = match(seeker, woman)
    pricing.sweep_charges(now=time.time() + 6)
    pricing.sweep_charges(now=time.time() + 7)  # a second sweep changes nothing
    ran_for(s, 30)
    service.end_session(s.id, seeker, "end")
    assert paid_rows(seeker) == [-8]
    assert balance(seeker.id) == 92 and holds.held(seeker.id) == 0


def test_mn8_ended_after_5s_before_the_sweep_is_still_charged(seeker_and_woman):
    seeker, woman = seeker_and_woman
    payg(seeker)
    s = match(seeker, woman)
    ran_for(s, 5.5)
    service.end_session(s.id, woman, "end")
    assert paid_rows(seeker) == [-8]


def test_mn8_ended_for_safety_within_5s_costs_nothing(seeker_and_woman):
    seeker, woman = seeker_and_woman
    payg(seeker)
    s = match(seeker, woman)
    service.end_session(s.id, woman, "moderation")
    assert paid_rows(seeker) == []


def test_mn8_disconnect_before_the_match_releases(seeker_and_woman):
    seeker, _ = seeker_and_woman
    payg(seeker)
    service.join(seeker, "text", WOMEN, accept_charge=True)
    service.on_disconnect(seeker.id)
    assert holds.held(seeker.id) == 0


def test_mn8_the_other_person_pays_nothing(seeker_and_woman):
    seeker, woman = seeker_and_woman
    payg(seeker)
    payg(woman)
    s = match(seeker, woman)
    ran_for(s, 30)
    service.end_session(s.id, woman, "end")
    assert paid_rows(woman) == [] and paid_rows(seeker) == [-8]


def test_mn7_next_keeps_the_filters_and_holds_again(seeker_and_woman, make_user):
    seeker, woman = seeker_and_woman
    payg(seeker)
    s = match(seeker, woman)
    ran_for(s, 30)
    service.end_session(s.id, seeker, "next")
    assert paid_rows(seeker) == [-8]
    assert service.is_queued(seeker.id) and holds.amount(seeker.id, "queue") == 8


def test_match_free_instead_drops_the_filters_for_next_too(seeker_and_woman):
    seeker, woman = seeker_and_woman
    payg(seeker)
    service.join(seeker, "text", WOMEN, accept_charge=True)
    service.join(seeker, "text")  # "Match free instead"
    assert holds.held(seeker.id) == 0
    service.join(woman, "text")
    (s,) = service.run_tick()
    service.end_session(s.id, seeker, "next")
    assert holds.held(seeker.id) == 0 and pricing.last_filters(seeker.id) is None


def test_fr8_subscribers_keep_their_filters_after_next(seeker_and_woman, make_user):
    """Load-test find: Plus joins hold nothing, and Next used to drop their filters."""
    seeker, woman = seeker_and_woman
    subscribe(seeker)
    s = match(seeker, woman)
    service.end_session(s.id, seeker, "next")
    man = make_user("Tobi")
    User.objects.filter(id=man.id).update(gender="man")
    man.refresh_from_db()
    service.join(man, "text")
    assert service.run_tick() == []  # still filtering for women
    assert pricing.last_filters(seeker.id) == {"gender": "women", "region": None}


def test_mn12_subscribers_are_never_charged(seeker_and_woman):
    seeker, woman = seeker_and_woman
    subscribe(seeker)
    s = match(seeker, woman, BOTH)
    assert holds.held(seeker.id) == 0
    pricing.sweep_charges(now=time.time() + 6)
    ran_for(s, 60)
    service.end_session(s.id, seeker, "end")
    assert CoinLedger.objects.filter(user=seeker).count() == 0


# --- Rematch (FR-7) -------------------------------------------------------------------------


@pytest.fixture
def skipped(seeker_and_woman):
    """Kwame skipped Ada a minute ago; both are online."""
    kwame, ada = seeker_and_woman
    service.join(kwame, "video")
    service.join(ada, "video")
    (s,) = service.run_tick()
    service.end_session(s.id, kwame, "next")
    service.leave(kwame.id)
    for u in (kwame, ada):
        service.touch_presence(u.id)
    s.refresh_from_db()
    return s, kwame, ada


def test_fr7_rematch_rings_holds_20_and_charges_after_5s(skipped, events):
    s, kwame, ada = skipped
    payg(kwame)
    invite = friend_calls.rematch(kwame, s.id)
    assert holds.held(kwame.id) == 20
    (incoming,) = events.of(ada, "call.incoming")
    assert incoming["rematch"] is True and incoming["from"]["first_name"] == "Kwame"
    session = friend_calls.accept(ada, invite)
    assert session.rematch_of_id == s.id and session.mode == "video"
    ran_for(session, 10)
    service.end_session(session.id, ada, "end")
    assert paid_rows(kwame) == [-20]


def test_fr7_a_declined_rematch_costs_nothing(skipped, events):
    s, kwame, ada = skipped
    payg(kwame)
    invite = friend_calls.rematch(kwame, s.id)
    friend_calls.decline(ada, invite)
    assert holds.held(kwame.id) == 0 and paid_rows(kwame) == []
    assert events.of(kwame, "call.declined")


def test_fr7_an_unanswered_rematch_costs_nothing(skipped, events):
    s, kwame, _ = skipped
    payg(kwame)
    friend_calls.rematch(kwame, s.id)
    friend_calls.sweep_missed(now=time.time() + 60)
    assert holds.held(kwame.id) == 0


def test_fr7_rematch_is_free_with_plus(skipped, events):
    s, kwame, ada = skipped
    subscribe(kwame)
    invite = friend_calls.rematch(kwame, s.id)
    session = friend_calls.accept(ada, invite)
    ran_for(session, 10)
    service.end_session(session.id, ada, "end")
    assert CoinLedger.objects.filter(user=kwame).count() == 0


def test_fr7_only_who_skipped_can_rematch_and_only_today(skipped, events):
    s, kwame, ada = skipped
    payg(kwame)
    payg(ada)
    with pytest.raises(ApiError) as e:
        friend_calls.rematch(ada, s.id)  # she was skipped; she can't ring him
    assert e.value.error_code == "cant_rematch"
    MatchSession.objects.filter(id=s.id).update(ended_at=timezone.now() - timedelta(hours=25))
    with pytest.raises(ApiError):
        friend_calls.rematch(kwame, s.id)


def test_fr7_no_rematch_when_blocked_or_offline(skipped, events):
    from safety.models import Block

    s, kwame, ada = skipped
    payg(kwame)
    service.on_disconnect(ada.id)
    with pytest.raises(ApiError) as e:
        friend_calls.rematch(kwame, s.id)
    assert e.value.error_code == "busy"
    service.touch_presence(ada.id)
    Block.objects.create(blocker=ada, blocked=kwame)
    with pytest.raises(ApiError) as e:
        friend_calls.rematch(kwame, s.id)
    assert e.value.error_code == "not_found"
    assert holds.held(kwame.id) == 0


def test_rematch_endpoint(skipped, events):
    s, kwame, _ = skipped
    payg(kwame)
    res = api_client(kwame).post(f"/api/v1/sessions/{s.id}/rematch")
    assert res.status_code == 201 and res.json()["invite_id"]


# --- Profile state (FR-8 nearby) ------------------------------------------------------------


def test_state_on_the_profile(seeker_and_woman):
    seeker, _ = seeker_and_woman
    c = api_client(seeker)
    assert (
        c.patch("/api/v1/me/profile", {"state": "lagos"}, format="json").json()["state"] == "lagos"
    )
    assert Profile.objects.get(user=seeker).region == "lagos"
    bad = c.patch("/api/v1/me/profile", {"state": "atlantis"}, format="json")
    assert bad.json()["code"] == "invalid_state"


def test_gifts_still_work_with_nothing_held(video_session):
    s, a, _ = video_session
    post_entry(a.id, 20, CoinLedger.Reason.PURCHASE, key="g")
    assert gifts.send(a, "jollof", "t", session_id=s.id)["balance"] == 0
