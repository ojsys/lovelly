from datetime import timedelta

import pytest
from django.utils import timezone

from accounts.models import DeviceToken
from accounts.services.push import register
from chat import friends
from chat.models import Friendship, Message
from chat.services import send_message
from core.exceptions import ApiError
from matching import service
from matching.models import MatchSession
from safety.models import Block

pytestmark = pytest.mark.django_db(transaction=True)


@pytest.fixture
def met(make_user, redis_db, events):
    a, b = make_user("Ada"), make_user("Kwame")
    service.join(a, "text")
    service.join(b, "text")
    (s,) = service.run_tick()
    return s, a, b


def test_fr16_request_round_trip(met, events, pushes):
    s, a, b = met
    register(b, "android", "tok-b")
    f = friends.request(a, s.id)
    assert f.status == "pending"
    req = events.of(b, "friend.request")[-1]["request"]
    assert req["sender"]["first_name"] == "Ada" and req["met_on"] == "text"
    assert friends.friends(b)["requests"][0]["id"] == str(f.id)

    friends.accept(b, f.id)
    f.refresh_from_db()
    assert f.status == "accepted"
    for user in (a, b):
        assert events.of(user, "friend.accepted")
    assert friends.friends(a)["friends"][0]["friend"]["first_name"] == "Kwame"


def test_fr16_asking_each_other_accepts_at_once(met, events):
    s, a, b = met
    friends.request(a, s.id)
    f = friends.request(b, s.id)
    assert f.status == "accepted"


def test_asking_twice_is_one_request(met, events):
    s, a, _ = met
    assert friends.request(a, s.id).id == friends.request(a, s.id).id
    assert Friendship.objects.count() == 1


def test_decline_is_silent(met, events):
    s, a, b = met
    f = friends.request(a, s.id)
    friends.decline(b, f.id)
    assert not events.of(a, "friend.accepted")
    assert friends.friends(a)["friends"] == [] and friends.friends(b)["requests"] == []


def test_only_the_addressee_can_accept(met, events):
    s, a, _ = met
    f = friends.request(a, s.id)
    with pytest.raises(ApiError):
        friends.accept(a, f.id)


def test_fr14_requests_close_an_hour_after_the_chat(met, events):
    s, a, _ = met
    service.end_session(s.id, a, "end")
    MatchSession.objects.filter(id=s.id).update(ended_at=timezone.now() - timedelta(minutes=59))
    friends.request(a, s.id)  # still fine
    Friendship.objects.all().delete()
    MatchSession.objects.filter(id=s.id).update(ended_at=timezone.now() - timedelta(minutes=61))
    with pytest.raises(ApiError) as e:
        friends.request(a, s.id)
    assert e.value.error_code == "too_late"


def test_sf5_blocked_people_cant_befriend(met, events):
    s, a, b = met
    Block.objects.create(blocker=b, blocked=a)
    with pytest.raises(ApiError):
        friends.request(a, s.id)


def test_fr15_history_moves_to_the_friendship_and_survives_the_purge(met, events):
    s, a, b = met
    send_message(s.id, a, "Arsenal or Chelsea?")
    send_message(s.id, b, "Arsenal!")
    friends.accept(b, friends.request(a, s.id).id)
    service.end_session(s.id, a, "end")
    assert service.purge_stranger_messages(timezone.now() + timedelta(days=8)) == 0
    page = friends.history(a, Friendship.objects.get().id)
    assert [m.body for m in page["messages"]] == ["Arsenal!", "Arsenal or Chelsea?"]


def test_stranger_chats_still_purge(met, events):
    s, a, _ = met
    send_message(s.id, a, "hi")
    service.end_session(s.id, a, "end")
    assert service.purge_stranger_messages(timezone.now() + timedelta(days=8)) == 1


def test_fr16_friend_chat_in_real_time_with_unread(friends_pair, events):
    f, a, b, _ = friends_pair
    send_message(None, a, "Hey!", chat_id=f.id)
    payload = events.of(b, "chat.message")[-1]
    assert payload["chat_id"] == str(f.id) and payload["message"]["body"] == "Hey!"
    row = friends.friends(b)["friends"][0]
    assert row["unread"] == 1 and row["last_message"]["body"] == "Hey!"
    from chat.services import mark_seen

    mark_seen(None, b, payload["message"]["id"], chat_id=f.id)
    assert friends.friends(b)["friends"][0]["unread"] == 0
    assert events.of(a, "chat.seen")[-1]["chat_id"] == str(f.id)


def test_fr17_push_only_when_the_friends_app_is_closed(friends_pair, pushes):
    f, a, b, _ = friends_pair
    register(b, "android", "tok-b")
    service.touch_presence(b.id)  # B's app is open
    send_message(None, a, "online?", chat_id=f.id)
    assert pushes == []
    service.on_disconnect(b.id)  # B closed the app
    send_message(None, a, "you there?", chat_id=f.id)
    token, push = pushes[-1]
    assert token == "tok-b"
    assert push.body == "Ada sent you a message"  # no message text on the lock screen
    assert push.data == {"type": "chat", "chat_id": str(f.id)}


def test_dead_push_tokens_are_dropped(friends_pair, monkeypatch):
    from core.providers.push import FakePushProvider

    f, a, b, _ = friends_pair
    register(b, "ios", "dead-token")
    monkeypatch.setattr(FakePushProvider, "send", lambda self, token, push: False)
    send_message(None, a, "hello", chat_id=f.id)
    assert not DeviceToken.objects.filter(fcm_token="dead-token").exists()


def test_push_tokens_move_with_the_install(friends_pair):
    _, a, b, _ = friends_pair
    register(a, "android", "shared")
    register(b, "android", "shared")
    assert DeviceToken.objects.get(fcm_token="shared").user == b


def test_sf5_blocking_a_friend_ends_the_chat(friends_pair, events):
    from safety.services import block_from_session

    f, a, b, s = friends_pair
    block_from_session(a, s.id)
    assert friends.friends(a)["friends"] == [] and friends.friends(b)["friends"] == []
    with pytest.raises(ApiError):
        send_message(None, b, "why?", chat_id=f.id)


def test_strangers_cant_use_a_chat_id(friends_pair, make_user):
    f, _, _, _ = friends_pair
    with pytest.raises(ApiError):
        send_message(None, make_user("Eve"), "hi", chat_id=f.id)


def test_history_pages(friends_pair, events):
    f, a, _, _ = friends_pair
    for i in range(35):
        Message.objects.create(friendship=f, sender=a, body=str(i))
    page = friends.history(a, f.id)
    assert len(page["messages"]) == 30 and page["more"]
    older = friends.history(a, f.id, before=page["messages"][-1].sent_at)
    assert len(older["messages"]) == 5 and not older["more"]
