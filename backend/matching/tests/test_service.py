import time

import pytest

from core.exceptions import ApiError
from matching import service
from matching.models import MatchSession
from safety.models import Block

pytestmark = pytest.mark.django_db


@pytest.fixture
def pair(make_user, redis_db):
    return make_user("Ada"), make_user("Kwame")


def test_sf1_unverified_users_cannot_join(make_user, redis_db):
    user = make_user(verified=False)
    with pytest.raises(ApiError) as e:
        service.join(user, "text")
    assert e.value.error_code == "not_verified"


def test_fr8_filters_are_locked_without_plus_or_pay_as_you_go(pair):
    with pytest.raises(ApiError) as e:
        service.join(pair[0], "video", {"gender": "women"})
    assert e.value.error_code == "filters_locked"


def test_fr6_two_users_in_a_mode_are_matched(pair, events):
    a, b = pair
    service.join(a, "text")
    service.join(b, "text")
    (session,) = service.run_tick()
    assert session.mode == "text" and {session.user_a, session.user_b} == {a, b}
    found = events.of(a, "match.found")[0]
    assert found["peer"]["first_name"] == "Kwame"
    assert found["peer"]["verified"] is True
    assert found["media_token"] is None
    assert not service.is_queued(a.id) and not service.is_queued(b.id)


def test_voice_and_video_matches_carry_a_media_token(pair, events):
    a, b = pair
    service.join(a, "video")
    service.join(b, "video")
    service.run_tick()
    assert events.of(a, "match.found")[0]["media_token"]


def test_match_found_lists_shared_interests(make_user, redis_db, events):
    a = make_user("Ada", interests=["football", "tech", "poetry"])
    b = make_user("Kwame", interests=["football", "tech"])
    service.join(a, "text")
    service.join(b, "text")
    service.run_tick()
    assert sorted(events.of(a, "match.found")[0]["peer"]["shared_interests"]) == [
        "Football",
        "Tech",
    ]


def test_different_modes_are_not_matched(pair):
    service.join(pair[0], "video")
    service.join(pair[1], "voice")
    assert service.run_tick() == []


def test_fr7_sf5_blocked_pairs_are_never_matched_either_way(pair, events):
    a, b = pair
    Block.objects.create(blocker=b, blocked=a)
    service.join(a, "text", now=time.time() - 120)  # long past widening
    service.join(b, "text", now=time.time() - 120)
    assert service.run_tick() == []
    assert service.is_queued(a.id) and service.is_queued(b.id)


def test_fr7_not_rematched_within_24h(pair, events):
    a, b = pair
    service.join(a, "text")
    service.join(b, "text")
    (s,) = service.run_tick()
    service.end_session(s.id, a, "end")
    service.join(a, "text", now=time.time() - 120)
    service.join(b, "text", now=time.time() - 120)
    assert service.run_tick() == []
    assert service.run_tick(now=time.time() + 24 * 3600 + 5) != []


def test_fr9_match_widened_is_sent_once_after_30s(make_user, redis_db, events):
    a = make_user(interests=["football"])
    service.join(a, "text", now=time.time() - 31)
    service.run_tick()
    service.run_tick()
    assert events.types(a).count("match.widened") == 1


def test_claim_is_atomic_across_matchers(make_user, redis_db, events):
    """Two matcher workers ticking at once never put a user in two sessions."""
    users = [make_user(str(i)) for i in range(6)]
    for u in users:
        service.join(u, "text")
    first = service.run_tick()
    second = service.run_tick()  # sees an empty queue
    assert len(first) == 3 and second == []
    counts = {}
    for s in MatchSession.objects.all():
        for uid in (s.user_a_id, s.user_b_id):
            counts[uid] = counts.get(uid, 0) + 1
    assert set(counts.values()) == {1}


def test_fr12_next_ends_the_session_and_requeues_the_sender(pair, events):
    a, b = pair
    service.join(a, "voice")
    service.join(b, "voice")
    (s,) = service.run_tick()
    service.end_session(s.id, a, "next")
    s.refresh_from_db()
    assert s.ended_at and s.end_reason == "next" and s.ended_by == a
    assert service.is_queued(a.id) and not service.is_queued(b.id)
    assert events.of(b, "session.ended")[-1]["reason"] == "peer_next"


def test_fr12_end_goes_home_and_tells_the_peer(pair, events):
    a, b = pair
    service.join(a, "text")
    service.join(b, "text")
    (s,) = service.run_tick()
    service.end_session(s.id, a, "end")
    assert not service.is_queued(a.id)
    assert events.of(b, "session.ended")[-1]["reason"] == "peer_left"
    assert service.end_session(s.id, a, "end") is None  # idempotent


def test_cannot_queue_while_in_a_session(pair, events):
    a, b = pair
    service.join(a, "text")
    service.join(b, "text")
    service.run_tick()
    with pytest.raises(ApiError) as e:
        service.join(a, "text")
    assert e.value.error_code == "in_session"


def test_disconnect_leaves_the_queue_at_once(pair):
    service.join(pair[0], "text")
    service.on_disconnect(pair[0].id)
    assert not service.is_queued(pair[0].id)


def test_reconnect_within_10s_keeps_the_session(pair, events):
    a, b = pair
    service.join(a, "text")
    service.join(b, "text")
    (s,) = service.run_tick()
    now = time.time()
    service.on_disconnect(a.id, now=now)
    service.on_connect(a.id)
    assert service.sweep_disconnects(now=now + 11) == 0
    s.refresh_from_db()
    assert s.ended_at is None


def test_no_reconnect_within_10s_ends_the_session(pair, events):
    a, b = pair
    service.join(a, "text")
    service.join(b, "text")
    (s,) = service.run_tick()
    now = time.time()
    service.on_disconnect(a.id, now=now)
    assert service.sweep_disconnects(now=now + 5) == 0
    assert service.sweep_disconnects(now=now + 11) == 1
    s.refresh_from_db()
    assert s.end_reason == "peer_left"
    assert events.of(b, "session.ended")[-1]["reason"] == "peer_left"


def test_sf7_three_quick_skips_in_a_row_cool_down_for_2_minutes(make_user, redis_db, events):
    victim = make_user("Victim")
    for i in range(3):
        other = make_user(f"Skipper{i}")
        service.join(victim, "video")
        service.join(other, "video")
        (s,) = service.run_tick()
        service.end_session(s.id, other, "next")  # within 5 s
        service.leave(other.id)
    with pytest.raises(ApiError) as e:
        service.join(victim, "video")
    assert e.value.error_code == "cooldown"
    assert 0 < e.value.extra["retry_after"] <= 120


def test_sf7_a_normal_chat_resets_the_skip_streak(make_user, redis_db, events):
    victim = make_user("Victim")
    for i in range(3):
        other = make_user(f"Other{i}")
        service.join(victim, "text")
        service.join(other, "text")
        (s,) = service.run_tick()
        later = time.time() + 30 if i == 1 else None  # the middle chat lasts 30 s
        service.end_session(s.id, other, "next", now=later)
        service.leave(other.id)
    service.join(victim, "text")  # no cooldown


def test_sf7_new_accounts_get_30_matches_in_their_first_day(make_user, redis_db):
    new = make_user("New", created_days_ago=0)
    for i in range(30):
        other = make_user(f"P{i}")
        MatchSession.objects.create(mode="text", user_a=new, user_b=other, room_name=f"r{i}")
    MatchSession.objects.filter(user_a=new).update(ended_at=MatchSession.objects.first().started_at)
    with pytest.raises(ApiError) as e:
        service.join(new, "text")
    assert e.value.error_code == "match_limit"


def test_online_count_counts_recent_presence(pair):
    now = time.time()
    service.touch_presence(pair[0].id, now=now - 120)
    service.touch_presence(pair[1].id, now=now)
    assert service.online_count(now=now) == 1


def test_deleted_or_suspended_users_are_dropped_without_breaking_the_tick(
    make_user, redis_db, events
):
    a, b, gone, banned = (make_user(n) for n in ("A", "B", "Gone", "Banned"))
    for u in (gone, banned, a, b):
        service.join(u, "text")
    gone_id = gone.id
    gone.delete()
    banned.status = "suspended"
    banned.save()
    (s,) = service.run_tick()
    s.refresh_from_db()
    assert {s.user_a_id, s.user_b_id} == {a.id, b.id}
    assert not service.is_queued(gone_id) and not service.is_queued(banned.id)


def test_sessions_nobody_is_in_any_more_are_ended(pair, events):
    """Load-test find: a user who disconnects in the instant they're matched leaves a
    session nobody ends. The orphan sweep ends it once neither person is online."""
    import time as _time

    from django.utils import timezone as tz

    from matching.models import MatchSession

    a, b = pair
    service.join(a, "video")
    service.join(b, "video")
    (s,) = service.run_tick()
    MatchSession.objects.filter(id=s.id).update(started_at=tz.now() - tz.timedelta(minutes=2))
    service.touch_presence(a.id)  # one of them is still here: keep it
    assert service.sweep_orphans() == 0
    later = _time.time() + 120  # both gone quiet
    assert service.sweep_orphans(now=later) == 1
    s.refresh_from_db()
    assert s.ended_at is not None and s.end_reason == "peer_left"
