import pytest
from rest_framework.test import APIClient

from accounts.models import Verification
from conftest import MAGENTA, solid_jpeg
from safety.models import Report

from .test_reports import report

pytestmark = pytest.mark.django_db


def console(moderator):
    c = APIClient()
    tokens = c.post(
        "/admin-api/auth/login",
        {"phone": moderator.phone, "password": "console-pass"},
        format="json",
    ).json()
    c.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
    return c


def test_console_login_is_moderators_only(moderator, make_user):
    assert (
        APIClient()
        .post(
            "/admin-api/auth/login", {"phone": moderator.phone, "password": "wrong"}, format="json"
        )
        .status_code
        == 401
    )
    user = make_user("Normal")
    user.set_password("pw12345678")
    user.save()
    assert (
        APIClient()
        .post(
            "/admin-api/auth/login", {"phone": user.phone, "password": "pw12345678"}, format="json"
        )
        .status_code
        == 401
    )
    c = APIClient()
    from rest_framework_simplejwt.tokens import AccessToken

    c.credentials(HTTP_AUTHORIZATION=f"Bearer {AccessToken.for_user(user)}")
    assert c.get("/admin-api/reports").status_code == 403


def test_sf6_queue_is_sorted_by_severity_then_age(
    video_session, make_user, moderator, events, redis_db
):
    from matching import service

    s, a, b = video_session
    report(a, s, "scam", block=False)
    c, d = make_user("C"), make_user("D")
    service.join(c, "text")
    service.join(d, "text")
    (s2,) = service.run_tick()
    report(c, s2, "minor", block=False)
    rows = console(moderator).get("/admin-api/reports").json()
    assert [r["reason"] for r in rows["results"]] == ["minor", "scam"]
    assert rows["open_by_reason"] == {"minor": 1, "scam": 1}


def test_m4_accept_automatic_report_shows_in_console_with_evidence(
    video_session, moderator, events
):
    import time

    from safety.moderation import handle_frame

    s, _, b = video_session
    handle_frame(s.id, b.id, "TR_b", solid_jpeg(MAGENTA), time.time())
    c = console(moderator)
    row = c.get("/admin-api/reports?automatic=true").json()["results"][0]
    detail = c.get(f"/admin-api/reports/{row['id']}").json()
    assert detail["reason"] == "nudity" and detail["automatic"] is True
    assert detail["evidence"]["frames"][0]["url"]
    assert detail["reported"]["first_name"] == "Tobi" and "dob" not in detail["reported"]
    assert detail["history"][0]["moderator"] == "automatic"


def test_console_actions(video_session, moderator, events):
    s, a, b = video_session
    report(a, s, "harassment", block=False)
    rid = Report.objects.get().id
    c = console(moderator)
    assert (
        c.post(
            f"/admin-api/reports/{rid}/actions", {"action": "warn", "note": "x"}, format="json"
        ).status_code
        == 201
    )
    audit = c.get("/admin-api/audit").json()["results"]
    assert audit[0]["action"] == "warn" and audit[0]["moderator"] == moderator.phone
    assert c.get("/admin-api/reports/00000000-0000-0000-0000-000000000000").status_code == 404


def test_selfie_review_moved_to_console(make_user, moderator):
    user = make_user("Pending", verified=False)
    v = Verification.objects.create(
        user=user, kind="manual", status="pending", reason="selfie_failed"
    )
    c = console(moderator)
    rows = c.get("/admin-api/verifications").json()["results"]
    assert rows[0]["id"] == str(v.id)
    assert c.post(f"/admin-api/verifications/{v.id}", {"approve": True}, format="json").json() == {
        "status": "approved"
    }
    v.refresh_from_db()
    assert v.status == "passed"
