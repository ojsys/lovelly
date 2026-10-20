import pytest

from core.exceptions import ApiError
from core.providers.media import FakeMediaProvider
from matching import calls, service
from matching.models import MatchSession

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def media_log():
    FakeMediaProvider.log.clear()
    return FakeMediaProvider.log


def start(make_user, mode, **kw):
    a, b = make_user("Ada", **kw), make_user("Tobi", **kw)
    service.join(a, mode)
    service.join(b, mode)
    (s,) = service.run_tick()
    s.refresh_from_db()
    return s, a, b


def test_fr10_video_tokens_allow_camera_and_mic(make_user, redis_db, events, media_log):
    s, a, _ = start(make_user, "video")
    found = events.of(a, "match.found")[-1]
    assert found["media_url"] == "ws://media.test"
    assert found["media_token"].endswith(":camera,microphone")
    assert ("token", s.room_name, str(a.id), ("camera", "microphone")) in media_log


def test_fr14_voice_tokens_are_microphone_only(make_user, redis_db, events):
    _, a, _ = start(make_user, "voice")
    assert events.of(a, "match.found")[-1]["media_token"].endswith(":microphone")


def test_text_matches_have_no_media(make_user, redis_db, events):
    _, a, _ = start(make_user, "text")
    found = events.of(a, "match.found")[-1]
    assert found["media_token"] is None and found["media_url"] is None


def test_shared_languages_are_in_the_peer_summary(make_user, redis_db, events):
    _, a, _ = start(make_user, "video", languages=["English", "Pidgin"])
    assert events.of(a, "match.found")[-1]["peer"]["shared_languages"] == ["english", "pidgin"]


@pytest.mark.parametrize("reason", ["next", "end"])
def test_room_is_closed_when_a_call_ends(make_user, redis_db, events, media_log, reason):
    s, a, _ = start(make_user, "voice")
    service.end_session(s.id, a, reason)
    assert ("close", s.room_name) in media_log


def test_room_is_closed_on_disconnect(make_user, redis_db, events, media_log):
    import time

    s, a, _ = start(make_user, "video")
    now = time.time()
    service.on_disconnect(a.id, now=now)
    service.sweep_disconnects(now=now + 11)
    assert ("close", s.room_name) in media_log


def test_text_sessions_have_no_room_to_close(make_user, redis_db, events, media_log):
    s, a, _ = start(make_user, "text")
    service.end_session(s.id, a, "end")
    assert not [e for e in media_log if e[0] == "close"]


def test_fr13_reveal_needs_both(make_user, redis_db, events):
    s, a, b = start(make_user, "voice")
    assert calls.request_reveal(s.id, a) is False
    assert events.of(b, "reveal.request")
    assert not events.of(a, "reveal.accept")
    assert calls.request_reveal(s.id, b) is True
    assert events.of(a, "reveal.accept") and events.of(b, "reveal.accept")


def test_fr13_reveal_twice_by_one_person_is_not_agreement(make_user, redis_db, events):
    s, a, _ = start(make_user, "voice")
    calls.request_reveal(s.id, a)
    assert calls.request_reveal(s.id, a) is False


def test_fr13_reveal_is_voice_only(make_user, redis_db, events):
    s, a, _ = start(make_user, "video")
    with pytest.raises(ApiError) as e:
        calls.request_reveal(s.id, a)
    assert e.value.error_code == "not_voice"


def test_fr14_upgrade_needs_the_other_person_to_accept(make_user, redis_db, events, media_log):
    s, a, b = start(make_user, "voice")
    calls.request_upgrade(s.id, a)
    assert events.of(b, "upgrade.request")
    with pytest.raises(ApiError) as e:
        calls.accept_upgrade(s.id, a)  # can't accept your own request
    assert e.value.error_code == "no_request"

    calls.accept_upgrade(s.id, b)
    s.refresh_from_db()
    assert s.upgraded_at is not None
    assert ("grant", s.room_name, (str(a.id), str(b.id)), ("camera", "microphone")) in media_log
    assert events.of(a, "upgrade.accept") and events.of(b, "upgrade.accept")
    assert calls.sources_for(s) == ["camera", "microphone"]


def test_fr14_declined_upgrade_tells_the_requester(make_user, redis_db, events):
    s, a, b = start(make_user, "voice")
    calls.request_upgrade(s.id, a)
    calls.decline_upgrade(s.id, b)
    assert events.of(a, "upgrade.decline")
    s.refresh_from_db()
    assert s.upgraded_at is None


def test_fresh_media_token_only_for_participants_of_open_calls(make_user, redis_db, events):
    s, a, _ = start(make_user, "voice")
    assert calls.fresh_token(s.id, a)["media_token"].endswith(":microphone")
    with pytest.raises(ApiError):
        calls.fresh_token(s.id, make_user("Eve"))
    service.end_session(s.id, a, "end")
    with pytest.raises(ApiError) as e:
        calls.fresh_token(s.id, a)
    assert e.value.error_code == "session_ended"


def test_media_token_endpoint(make_user, redis_db, events):
    from rest_framework.test import APIClient
    from rest_framework_simplejwt.tokens import AccessToken

    s, a, _ = start(make_user, "video")
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {AccessToken.for_user(a)}")
    res = client.post(f"/api/v1/sessions/{s.id}/media-token")
    assert res.status_code == 200 and res.json()["media_url"] == "ws://media.test"
    assert MatchSession.objects.count() == 1
