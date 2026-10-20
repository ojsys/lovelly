import pytest
from django.utils import timezone

from chat import filters, services
from chat.models import Message
from core.exceptions import ApiError
from matching import service as matching

pytestmark = pytest.mark.django_db


@pytest.fixture
def session(make_user, redis_db, events):
    a, b = make_user("Ada"), make_user("Kwame")
    matching.join(a, "text")
    matching.join(b, "text")
    (s,) = matching.run_tick()
    return s, a, b


def test_fr17_message_reaches_both_sides(session, events):
    s, a, b = session
    message = services.send_message(s.id, a, "  Arsenal or Chelsea?  ")
    assert message.body == "Arsenal or Chelsea?"
    for user in (a, b):
        payload = events.of(user, "chat.message")[-1]
        assert payload["message"]["body"] == "Arsenal or Chelsea?"
        assert payload["message"]["sender_id"] == str(a.id)


def test_fr17_seen_status_goes_back_to_the_sender(session, events):
    s, a, b = session
    m1 = services.send_message(s.id, a, "hi")
    m2 = services.send_message(s.id, a, "you there?")
    services.mark_seen(s.id, b, m2.id)
    assert all(m.seen_at for m in Message.objects.filter(id__in=[m1.id, m2.id]))
    assert events.of(a, "chat.seen")[-1]["message_id"] == str(m2.id)


def test_own_messages_are_not_marked_seen_by_self(session, events):
    s, a, b = session
    m = services.send_message(s.id, a, "hi")
    services.mark_seen(s.id, a, m.id)
    m.refresh_from_db()
    assert m.seen_at is None


def test_typing_is_relayed_to_the_peer_only(session, events):
    s, a, b = session
    services.typing(s.id, a)
    assert events.of(b, "chat.typing") and not events.of(a, "chat.typing")


@pytest.mark.parametrize(
    ("body", "reason"),
    [
        ("call me on 0803 123 4567", "phone"),
        ("+2348031234567", "phone"),
        ("my acct is 0123456789", "account"),
        ("please send me money for transport", "payment"),
        ("what's the OTP they sent you?", "payment"),
        ("Arsenal, obviously. You?", ""),
        ("I was born in 1999 and have 2 cats", ""),
    ],
)
def test_fr18_sf8_filter(body, reason):
    assert filters.check(body) == reason


def test_sf8_flagged_message_warns_receiver_and_raises_sender_risk(session, events):
    s, a, b = session
    services.send_message(s.id, a, "send me money abeg")
    assert events.of(b, "chat.message")[-1]["message"]["flagged"] is True
    a.refresh_from_db()
    assert a.risk_score == 1


def test_cannot_chat_in_someone_elses_session(session, make_user):
    s, _, _ = session
    with pytest.raises(ApiError) as e:
        services.send_message(s.id, make_user("Eve"), "hi")
    assert e.value.error_code == "not_found"


def test_fr15_cannot_chat_after_the_session_ends(session, events):
    s, a, _ = session
    matching.end_session(s.id, a, "end")
    with pytest.raises(ApiError) as e:
        services.send_message(s.id, a, "hello?")
    assert e.value.error_code == "session_ended"


def test_messages_are_rate_limited(session, events):
    s, a, _ = session
    for _ in range(services.RATE_LIMIT):
        services.send_message(s.id, a, "spam")
    with pytest.raises(ApiError) as e:
        services.send_message(s.id, a, "spam")
    assert e.value.error_code == "throttled"


def test_stranger_messages_are_deleted_after_7_days(session, events):
    s, a, _ = session
    services.send_message(s.id, a, "hi")
    matching.end_session(s.id, a, "end")
    assert matching.purge_stranger_messages(timezone.now() + timezone.timedelta(days=6)) == 0
    assert matching.purge_stranger_messages(timezone.now() + timezone.timedelta(days=8)) == 1
