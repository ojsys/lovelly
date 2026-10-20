from datetime import timedelta

import pytest
from django.db import DatabaseError, transaction
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import DeniedDevice, DeniedPhone, User, UserDevice
from accounts.services.devices import device_hash
from accounts.services.phones import phone_hash
from core.exceptions import ApiError
from matching import service as matching
from safety import services
from safety.models import ModerationAction, Report

from .test_reports import client, report

pytestmark = pytest.mark.django_db


@pytest.fixture
def open_report(video_session, events):
    s, a, b = video_session
    report(a, s, "harassment", block=False)
    return Report.objects.get(), a, b


def test_sf6_warn_shows_a_notice_once(open_report, moderator):
    r, _, b = open_report
    services.act(moderator, r, "warn", "Be respectful.")
    body = client(b).get("/api/v1/me/status").json()
    assert body["status"] == "active" and body["notices"][0]["body"] == "Be respectful."
    client(b).post(f"/api/v1/me/notices/{body['notices'][0]['id']}/seen")
    assert client(b).get("/api/v1/me/status").json()["notices"] == []
    r.refresh_from_db()
    assert r.status == "actioned"


@pytest.mark.django_db(transaction=True)
def test_sf6_suspension_cuts_the_user_off_and_lifts_itself(make_user, redis_db, events, moderator):
    a, b = make_user("A"), make_user("B")
    matching.join(a, "text")
    matching.join(b, "text")
    (s,) = matching.run_tick()
    r = services.create_report(a, s.id, "harassment", False)
    # b is in a new live session when the moderator acts
    c = make_user("C")
    matching.join(b, "text")
    matching.join(c, "text")
    (live,) = matching.run_tick()

    services.act(moderator, r, "suspend_24h")
    b.refresh_from_db()
    assert b.status == "suspended" and b.suspended_until > timezone.now() + timedelta(hours=23)
    live.refresh_from_db()
    assert live.end_reason == "moderation"
    assert events.of(b, "account.closed")[-1]["reason"] == "suspended"
    with pytest.raises(ApiError):
        matching.join(b, "text")

    User.objects.filter(id=b.id).update(suspended_until=timezone.now() - timedelta(seconds=1))
    b.refresh_from_db()
    assert services.effective_status(b) == "active"


@pytest.mark.django_db(transaction=True)
def test_sf6_ban_denies_phone_and_devices(make_user, redis_db, events, moderator):
    a, b = make_user("A"), make_user("B")
    UserDevice.objects.create(user=b, device_hash=device_hash("android-id-123456"))
    matching.join(a, "text")
    matching.join(b, "text")
    (s,) = matching.run_tick()
    r = services.create_report(a, s.id, "harassment", False)
    services.act(moderator, r, "ban")
    b.refresh_from_db()
    assert b.status == "banned" and not b.is_active
    assert DeniedPhone.objects.filter(phone_hash=phone_hash(b.phone)).exists()
    assert DeniedDevice.objects.filter(device_hash=device_hash("android-id-123456")).exists()
    # A new number from the same device is refused.
    res = APIClient().post(
        "/api/v1/auth/otp/request",
        {"phone": "08031119999"},
        format="json",
        HTTP_X_DEVICE_ID="android-id-123456",
    )
    assert res.status_code == 403 and res.json()["code"] == "device_denied"


def test_devices_are_recorded_at_sign_in(redis_db):
    from core.providers.sms import FakeSMSProvider

    c = APIClient()
    c.post("/api/v1/auth/otp/request", {"phone": "08031117777"}, format="json")
    c.post(
        "/api/v1/auth/otp/verify",
        {"phone": "08031117777", "code": FakeSMSProvider.outbox[-1][1]},
        format="json",
        HTTP_X_DEVICE_ID="ios-vendor-abcdef",
    )
    assert UserDevice.objects.filter(device_hash=device_hash("ios-vendor-abcdef")).exists()


def test_dismiss_and_escalate(open_report, moderator):
    r, _, _ = open_report
    services.act(moderator, r, "escalate")
    r.refresh_from_db()
    assert r.status == "escalated"
    services.act(moderator, r, "dismiss")
    r.refresh_from_db()
    assert r.status == "dismissed" and r.closed_at


def test_sf6_audit_log_is_append_only(open_report, moderator):
    r, _, _ = open_report
    action = services.act(moderator, r, "warn")
    with pytest.raises(DatabaseError), transaction.atomic():
        ModerationAction.objects.filter(id=action.id).update(note="edited")
    with pytest.raises(DatabaseError), transaction.atomic():
        ModerationAction.objects.filter(id=action.id).delete()


def test_sf9_legal_hold_cannot_be_deleted_or_lifted(open_report, moderator):
    r, _, _ = open_report
    with pytest.raises(ApiError):
        services.act(moderator, r, "referral", referral={"agency": "X", "reference": "1"})
    services.act(moderator, r, "legal_hold")
    services.act(moderator, r, "referral", referral={"agency": "NAPTIP", "reference": "REF-1"})
    r.refresh_from_db()
    assert r.legal_hold and r.referral["reference"] == "REF-1"
    with pytest.raises(DatabaseError), transaction.atomic():
        Report.objects.filter(id=r.id).update(legal_hold=False)
    with pytest.raises(DatabaseError), transaction.atomic():
        Report.objects.filter(id=r.id).delete()


def test_sf4_evidence_is_purged_30_days_after_closing_unless_held(
    open_report, moderator, video_session
):
    r, _, _ = open_report
    services.act(moderator, r, "dismiss")
    assert services.purge_evidence(timezone.now() + timedelta(days=29)) == 0
    assert services.purge_evidence(timezone.now() + timedelta(days=31)) == 1
    r.refresh_from_db()
    assert r.evidence_uri == ""


def test_open_reports_hold_stranger_messages(make_user, redis_db, events):
    from chat.models import Message
    from chat.services import send_message

    a, b = make_user("A"), make_user("B")
    matching.join(a, "text")
    matching.join(b, "text")
    (s,) = matching.run_tick()
    send_message(s.id, b, "rude")
    services.create_report(a, s.id, "harassment", False)
    assert matching.purge_stranger_messages(timezone.now() + timedelta(days=8)) == 0
    assert Message.objects.count() == 1
