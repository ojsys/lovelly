import time

import pytest

from accounts.models import User, Verification
from conftest import CYAN, MAGENTA, solid_jpeg
from core.providers.media import FakeMediaProvider
from core.providers.moderation import FakeModerationProvider
from safety import evidence
from safety.models import ModerationAction, Report
from safety.moderation import handle_frame, sample_interval

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def media_log():
    FakeMediaProvider.log.clear()
    return FakeMediaProvider.log


def test_sampling_is_1s_for_the_first_30s_then_2s():
    assert [sample_interval(t) for t in (0, 29.9, 30, 300)] == [1.0, 1.0, 2.0, 2.0]


def test_fake_provider_markers():
    p = FakeModerationProvider()
    assert p.scan_frame(solid_jpeg(MAGENTA)).nudity > 0.9
    assert p.scan_frame(solid_jpeg(CYAN)).estimated_age == 15
    assert p.scan_frame(solid_jpeg()).nudity == 0


def test_clean_frames_are_kept_as_evidence(video_session):
    s, a, _ = video_session
    assert handle_frame(s.id, a.id, "TR_a", solid_jpeg(), time.time()).action == "ok"
    assert len(evidence.recent_frames(s.id, a.id)) == 1


def test_sf2_nudity_mutes_the_stream_blurs_both_ends_the_call_and_reports(
    video_session, events, media_log
):
    s, a, b = video_session
    out = handle_frame(s.id, b.id, "TR_b", solid_jpeg(MAGENTA), time.time())
    assert out.action == "blocked"
    assert ("mute", s.room_name, str(b.id), "TR_b") in media_log
    for user in (a, b):
        assert events.of(user, "moderation.blur")[-1]["reason"] == "nudity"
        assert events.of(user, "session.ended")[-1]["reason"] == "moderation"
    s.refresh_from_db()
    assert s.end_reason == "moderation"
    report = Report.objects.get()
    assert (report.reported, report.reason, report.automatic, report.reporter) == (
        b,
        "nudity",
        True,
        None,
    )
    frames = evidence.load(report)["frames"]
    assert [f["role"] for f in frames] == ["reported"]  # the triggering frame is in the evidence
    assert ModerationAction.objects.filter(action="auto_block", target_user=b).exists()


def test_sf3_looking_under_18_suspends_until_review(video_session, events):
    s, a, b = video_session
    assert handle_frame(s.id, b.id, "TR_b", solid_jpeg(CYAN), time.time()).action == "suspended"
    b.refresh_from_db()
    assert b.status == User.Status.SUSPENDED and b.suspended_until is None
    assert Verification.objects.get(user=b, kind="manual").reason == "age_estimate"
    assert Report.objects.get().reason == "minor"


def test_frames_after_the_call_ended_are_ignored(video_session, events):
    s, a, _ = video_session
    from matching import service

    service.end_session(s.id, a, "end")
    assert handle_frame(s.id, a.id, "TR", solid_jpeg(MAGENTA), time.time()).action == "ended"
    assert not Report.objects.exists()


def test_video_sessions_are_handed_to_the_agent(make_user, redis_db, events, monkeypatch):
    from matching import calls, service

    watched = []
    monkeypatch.setattr(calls, "watch", lambda s: watched.append(s.mode))
    a, b, c, d = (make_user(n) for n in "ABCD")
    for u, mode in ((a, "video"), (b, "video"), (c, "text"), (d, "text")):
        service.join(u, mode)
    service.run_tick()
    assert watched == ["video"]
