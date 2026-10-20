import pytest

from chat.models import Message
from conftest import api_client
from core.exceptions import ApiError
from matching import service
from safety.models import Block
from wallet import gifts
from wallet.models import CoinLedger, Gift, GiftSend
from wallet.services import balance, post_entry

pytestmark = pytest.mark.django_db(transaction=True)


def fund(user, coins=100):
    post_entry(user.id, coins, CoinLedger.Reason.PURCHASE, key=f"fund:{user.id}:{coins}")


def test_mn5_the_eight_gifts_are_in_the_catalogue(db):
    assert [(g.name, g.cost) for g in gifts.catalogue()] == [
        ("Heart", 5),
        ("Coffee", 10),
        ("Jollof", 20),
        ("Star", 30),
        ("Talking drum", 50),
        ("Vibes", 80),
        ("Crown", 150),
        ("Diamond", 300),
    ]


def test_mn5_sending_debits_the_sender_at_the_catalogue_price(video_session, events):
    s, a, b = video_session
    fund(a)
    sent = gifts.send(a, "jollof", "tap-1", session_id=s.id)
    assert sent["balance"] == 80 and sent["gift"] == {
        "slug": "jollof",
        "name": "Jollof",
        "cost": 20,
    }
    assert balance(b.id) == 0  # the receiver gets nothing back (MN-5)
    g = GiftSend.objects.get()
    assert (g.sender, g.receiver, g.session, g.cost) == (a, b, s, 20)


def test_mn5_the_gift_shows_in_the_chat_and_both_hear_about_it(video_session, events):
    s, a, b = video_session
    fund(a, 200)
    gifts.send(a, "crown", "tap-1", session_id=s.id)
    m = Message.objects.get(session=s)
    assert (m.kind, m.body, m.sender) == ("gift", "crown", a)
    for user in (a, b):
        assert events.of(user, "gift.received") == [
            {
                "session_id": str(s.id),
                "gift": {"slug": "crown", "name": "Crown", "cost": 150},
                "sender_id": str(a.id),
            }
        ]
        assert events.of(user, "chat.message")[-1]["message"]["kind"] == "gift"


def test_mn5_a_retried_tap_charges_once(video_session, events):
    s, a, b = video_session
    fund(a)
    first = gifts.send(a, "star", "tap-1", session_id=s.id)
    again = gifts.send(a, "star", "tap-1", session_id=s.id)
    assert first["id"] == again["id"]
    assert balance(a.id) == 70 and GiftSend.objects.count() == 1
    assert Message.objects.filter(kind="gift").count() == 1


def test_mn5_the_price_change_applies_to_new_gifts_only(video_session, events):
    s, a, b = video_session
    fund(a)
    Gift.objects.filter(slug="heart").update(cost=7)
    gifts.send(a, "heart", "tap-1", session_id=s.id)
    assert balance(a.id) == 93


def test_mn5_not_enough_coins(video_session, events):
    s, a, b = video_session
    fund(a, 10)
    with pytest.raises(ApiError) as e:
        gifts.send(a, "jollof", "tap-1", session_id=s.id)
    assert e.value.error_code == "insufficient_coins"
    assert not GiftSend.objects.exists() and not Message.objects.filter(kind="gift").exists()


def test_mn5_no_gifts_after_the_session_ends(video_session, events):
    s, a, b = video_session
    fund(a)
    service.end_session(s.id, a, "left")
    with pytest.raises(ApiError) as e:
        gifts.send(a, "heart", "tap-1", session_id=s.id)
    assert e.value.error_code == "session_ended"
    assert balance(a.id) == 100


def test_mn5_no_gifts_between_blocked_people(friends_pair, events):
    f, a, b, _ = friends_pair
    fund(a)
    Block.objects.create(blocker=b, blocked=a)
    with pytest.raises(ApiError):
        gifts.send(a, "heart", "tap-1", chat_id=f.id)
    assert balance(a.id) == 100


def test_mn5_gifts_in_a_friend_chat_push_when_offline(friends_pair, events, pushes):
    from accounts.services import push

    f, a, b, _ = friends_pair
    push.register(b, "android", "tok-kwame")
    fund(a)
    gifts.send(a, "coffee", "tap-1", chat_id=f.id)
    assert Message.objects.get(kind="gift").friendship == f
    assert events.of(b, "gift.received")[0]["chat_id"] == str(f.id)
    (token, p) = pushes[-1]
    assert token == "tok-kwame" and p.body == "Ada sent you a gift"


def test_mn5_gift_endpoints(video_session, events):
    s, a, b = video_session
    fund(a)
    c = api_client(a)
    assert len(c.get("/api/v1/gifts").json()) == 8
    body = {"gift": "vibes", "idempotency_key": "k1"}
    res = c.post(f"/api/v1/sessions/{s.id}/gifts", body, format="json")
    assert res.status_code == 201 and res.json()["balance"] == 20
    short = c.post(
        f"/api/v1/sessions/{s.id}/gifts", {**body, "idempotency_key": "k2"}, format="json"
    )
    assert short.status_code == 402 and short.json()["code"] == "insufficient_coins"
    other = api_client(b).post(f"/api/v1/sessions/{s.id}/gifts", body, format="json")
    assert other.status_code == 402  # Tobi's own key space: no coins, not Ada's gift
