"""Shared fixtures for M2+ tests."""

import itertools
from datetime import date

import pytest
from django.utils import timezone

_phones = itertools.count(1000)


@pytest.fixture
def redis_db():
    """A clean Redis (database 15 in tests, see settings.test)."""
    from core.redis import get_redis

    r = get_redis()
    r.flushdb()
    yield r
    r.flushdb()


@pytest.fixture
def make_user(db):
    """Creates a fully verified, active user (SF-1)."""
    from accounts.models import Interest, Profile, User, UserInterest

    def make(name="Ada", interests=(), languages=(), city="", verified=True, created_days_ago=3):
        user = User.objects.create_user(phone=f"+234803555{next(_phones):04d}")
        user.dob, user.gender = date(1999, 3, 14), "woman"
        user.save()
        User.objects.filter(id=user.id).update(
            created_at=timezone.now() - timezone.timedelta(days=created_days_ago)
        )
        user.refresh_from_db()
        Profile.objects.create(
            user=user,
            first_name=name,
            city=city,
            languages=list(languages),
            is_verified=verified,
            verified_at=timezone.now() if verified else None,
        )
        for slug in interests:
            interest, _ = Interest.objects.get_or_create(
                slug=slug, defaults={"label": slug.title()}
            )
            UserInterest.objects.create(user=user, interest=interest)
        return user

    return make


@pytest.fixture
def events(monkeypatch):
    """Records server events instead of sending them over the channel layer."""
    sent = []

    def record(user_id, event_type, payload):
        sent.append((str(user_id), event_type, payload))

    monkeypatch.setattr("matching.service.send_to_user", record)
    monkeypatch.setattr("chat.services.send_to_user", record)
    monkeypatch.setattr("matching.calls.send_to_user", record)
    monkeypatch.setattr("safety.services.send_to_user", record)
    monkeypatch.setattr("safety.moderation.send_to_user", record)

    class Events(list):
        def of(self, user, event_type=None):
            return [p for u, t, p in sent if u == str(user.id) and (event_type in (None, t))]

        def types(self, user):
            return [t for u, t, _ in sent if u == str(user.id)]

    out = Events()
    out.sent = sent
    return out


def solid_jpeg(rgb=(40, 90, 60)) -> bytes:
    """A plain JPEG frame. Magenta = fake 'explicit', cyan = fake 'under 18'."""
    import io

    from PIL import Image

    out = io.BytesIO()
    Image.new("RGB", (64, 48), rgb).save(out, "JPEG")
    return out.getvalue()


MAGENTA, CYAN = (255, 0, 255), (0, 255, 255)


@pytest.fixture
def video_session(make_user, redis_db, events):
    from matching import service

    a, b = make_user("Ada"), make_user("Tobi")
    service.join(a, "video")
    service.join(b, "video")
    (s,) = service.run_tick()
    s.refresh_from_db()
    return s, a, b


@pytest.fixture
def moderator(db):
    from django.contrib.auth.models import Group

    from accounts.models import User

    user = User.objects.create_user(phone="+2348099990000", password="console-pass")
    user.is_staff = True
    user.save()
    user.groups.add(Group.objects.get_or_create(name="Moderators")[0])
    return user
