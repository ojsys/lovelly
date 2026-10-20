import time

import pytest
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import AccessToken

from chat.services import send_message
from conftest import solid_jpeg
from matching import service as matching
from safety import evidence
from safety.models import Block, Report

pytestmark = pytest.mark.django_db


def client(user, device=None):
    c = APIClient()
    c.credentials(HTTP_AUTHORIZATION=f"Bearer {AccessToken.for_user(user)}")
    if device:
        c.credentials(
            HTTP_AUTHORIZATION=f"Bearer {AccessToken.for_user(user)}", HTTP_X_DEVICE_ID=device
        )
    return c


def report(user, session, reason="harassment", block=True):
    return client(user).post(
        "/api/v1/reports",
        {"session_id": str(session.id), "reason": reason, "block": block},
        format="json",
    )


def test_sf4_report_saves_frames_and_transcript_and_ends_the_call(video_session, events):
    s, a, b = video_session
    now = time.time()
    evidence.push_frame(s.id, b.id, solid_jpeg(), at=now - 5)
    evidence.push_frame(s.id, b.id, solid_jpeg(), at=now - 45)  # older than 30 s: dropped
    evidence.push_frame(s.id, a.id, solid_jpeg(), at=now - 3)
    send_message(s.id, b.id and b, "send me your OTP")

    res = report(a, s, "scam")
    assert res.status_code == 201
    r = Report.objects.get()
    assert (r.reporter, r.reported, r.reason, r.severity) == (a, b, "scam", 2)
    loaded = evidence.load(r)
    assert sorted(f["role"] for f in loaded["frames"]) == ["reported", "reporter"]
    assert all(f["url"] for f in loaded["frames"])
    assert loaded["transcript"][0] == {
        "sender": "reported",
        "body": "send me your OTP",
        "sent_at": loaded["transcript"][0]["sent_at"],
        "flagged": True,
    }
    s.refresh_from_db()
    assert s.end_reason == "blocked" and Block.objects.filter(blocker=a, blocked=b).exists()


def test_sf4_the_reported_person_is_not_told_who_reported(video_session, events):
    s, a, b = video_session
    before = len(events.sent)
    report(a, s)
    told = [t for u, t, _ in events.sent[before:] if u == str(b.id)]
    assert told == ["session.ended"]
    assert events.of(b, "session.ended")[-1]["reason"] == "peer_left"


def test_report_without_block(video_session, events):
    s, a, _ = video_session
    report(a, s, block=False)
    s.refresh_from_db()
    assert s.end_reason == "end" and not Block.objects.exists()


def test_text_chat_report_has_transcript_only(make_user, redis_db, events):
    a, b = make_user("A"), make_user("B")
    matching.join(a, "text")
    matching.join(b, "text")
    (s,) = matching.run_tick()
    send_message(s.id, b, "hi")
    report(a, s, "other")
    loaded = evidence.load(Report.objects.get())
    assert loaded["frames"] == [] and loaded["transcript"][0]["body"] == "hi"


def test_sf6_severity_order(video_session):
    assert [Report.SEVERITY[r] for r in ("minor", "nudity", "harassment", "scam", "other")] == [
        5,
        4,
        3,
        2,
        1,
    ]


def test_reports_are_rate_limited(video_session, events):
    s, a, _ = video_session
    for _ in range(10):
        assert report(a, s, block=False).status_code == 201
    res = report(a, s, block=False)
    assert res.status_code == 429 and res.json()["retry_after"] > 0


def test_cannot_report_someone_elses_session(video_session, make_user):
    s, _, _ = video_session
    assert report(make_user("Eve"), s).status_code == 404


@pytest.mark.django_db(transaction=True)
def test_friends_can_be_reported_from_their_chat(friends_pair, events):
    f, a, b, _ = friends_pair
    send_message(None, b, "send me your bank details", chat_id=f.id)
    res = client(a).post(
        "/api/v1/reports", {"chat_id": str(f.id), "reason": "scam", "block": True}, format="json"
    )
    assert res.status_code == 201
    loaded = evidence.load(Report.objects.get())
    assert loaded["transcript"][-1]["body"] == "send me your bank details"
    f.refresh_from_db()
    assert f.status == "declined"  # blocked: friendship over (SF-5)
