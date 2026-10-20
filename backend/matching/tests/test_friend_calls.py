import time

import pytest

from accounts.services.push import register
from chat.models import Message
from core.exceptions import ApiError
from matching import friend_calls, service
from matching.models import MatchSession

pytestmark = pytest.mark.django_db(transaction=True)


def test_fr16_friend_call_rings_and_connects(friends_pair, events, pushes):
    f, a, b, s = friends_pair
    service.end_session(s.id, a, "end")
    register(b, "android", "tok-b")
    recent_before = service._r().zscore(f"mq:recent:{a.id}", str(b.id))
    invite = friend_calls.invite(a, f.id, "video")
    incoming = events.of(b, "call.incoming")[-1]
    assert incoming["mode"] == "video" and incoming["from"]["first_name"] == "Ada"
    assert pushes[-1][1].data == {
        "type": "call",
        "invite_id": invite,
        "chat_id": str(f.id),
        "mode": "video",
    }

    session = friend_calls.accept(b, invite)
    assert session.friendship_id == f.id and session.mode == "video"
    found = events.of(a, "match.found")[-1]
    assert found["chat_id"] == str(f.id) and found["media_token"]
    # A friend call doesn't touch FR-7's 24 h random re-pair record.
    assert service._r().zscore(f"mq:recent:{a.id}", str(b.id)) == recent_before
    with pytest.raises(ApiError):
        friend_calls.accept(b, invite)  # already answered


def test_declined_call_tells_the_caller(friends_pair, events):
    f, a, b, s = friends_pair
    service.end_session(s.id, a, "end")
    invite = friend_calls.invite(a, f.id, "voice")
    friend_calls.decline(b, invite)
    assert events.of(a, "call.declined")
    assert not Message.objects.filter(kind="system").exists()


def test_unanswered_call_becomes_a_missed_call(friends_pair, events):
    f, a, b, s = friends_pair
    service.end_session(s.id, a, "end")
    now = time.time()
    friend_calls.invite(a, f.id, "video", now=now)
    assert friend_calls.sweep_missed(now + 10) == 0
    assert friend_calls.sweep_missed(now + 31) == 1
    assert events.of(b, "call.missed")
    assert Message.objects.get(kind="system").body == "Missed video call"


def test_caller_hanging_up_is_a_missed_call(friends_pair, events):
    f, a, b, s = friends_pair
    service.end_session(s.id, a, "end")
    invite = friend_calls.invite(a, f.id, "voice")
    friend_calls.decline(a, invite, cancel=True)
    assert events.of(b, "call.cancelled")
    assert Message.objects.get(kind="system").body == "Missed voice call"


def test_cant_call_someone_in_another_chat(friends_pair, make_user, events):
    f, a, b, s = friends_pair  # s is still live: b is busy
    with pytest.raises(ApiError) as e:
        friend_calls.invite(make_user("C"), f.id, "video")
    assert e.value.error_code == "not_found"  # not their friendship
    service.end_session(s.id, a, "end")
    c = make_user("C")
    service.join(b, "text")
    service.join(c, "text")
    service.run_tick()
    with pytest.raises(ApiError) as e:
        friend_calls.invite(a, f.id, "video")
    assert e.value.error_code == "busy"
    assert MatchSession.objects.filter(friendship=f).count() == 0
