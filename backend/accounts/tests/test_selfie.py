from datetime import timedelta

import pytest
from django.core.files.storage import default_storage
from django.test import override_settings
from django.utils import timezone
from rest_framework.test import APIRequestFactory, force_authenticate

from accounts.models import Profile, User, Verification
from accounts.permissions import IsVerified
from accounts.services import onboarding

from .conftest import basics, selfie, sign_in

pytestmark = pytest.mark.django_db


@pytest.fixture
def ready(api):
    sign_in(api)
    basics(api)
    return User.objects.get(phone="+2348031234542")


def _is_verified(user):
    request = APIRequestFactory().get("/")
    force_authenticate(request, user)
    request.user = user
    return IsVerified().has_permission(request, None)


def test_sf1_passing_selfie_completes_verification(api, ready):
    assert not _is_verified(ready)
    res = selfie(api)
    assert res.status_code == 200
    assert res.json()["next_step"] == "done"
    assert res.json()["is_verified"] is True
    assert _is_verified(ready)


def test_fr4_selfie_images_are_stored_privately_with_consent(api, ready):
    selfie(api)
    v = Verification.objects.get(user=ready, kind="selfie")
    assert v.consented_at is not None
    assert len(v.images) == 2
    assert all(key.startswith(f"selfies/{ready.id}/") for key in v.images)


@override_settings(FAKE_LIVENESS="fail")
def test_fr4_third_failed_selfie_goes_to_manual_review(api, ready):
    assert selfie(api).json()["attempts_left"] == 2
    assert selfie(api).json()["attempts_left"] == 1
    body = selfie(api).json()
    assert body["selfie"] == "manual_review"
    assert body["next_step"] == "review"
    manual = Verification.objects.get(user=ready, kind="manual")
    assert (manual.status, manual.reason) == ("pending", "selfie_failed")
    assert selfie(api).status_code == 409


@override_settings(FAKE_LIVENESS="fail")
def test_fr4_manual_approval_verifies_the_user(api, ready):
    for _ in range(3):
        selfie(api)
    moderator = User.objects.create_superuser("+2348000000000", "pw")
    onboarding.review(Verification.objects.get(kind="manual"), moderator, approve=True)
    body = api.get("/api/v1/me/verification").json()
    assert body["next_step"] == "done" and body["is_verified"] is True


@override_settings(FAKE_LIVENESS="fail")
def test_fr4_manual_rejection_keeps_the_user_unverified(api, ready):
    for _ in range(3):
        selfie(api)
    moderator = User.objects.create_superuser("+2348000000000", "pw")
    onboarding.review(Verification.objects.get(kind="manual"), moderator, approve=False)
    body = api.get("/api/v1/me/verification").json()
    assert (body["selfie"], body["next_step"], body["is_verified"]) == ("rejected", "review", False)


@override_settings(FAKE_LIVENESS="underage")
def test_sf3_selfie_that_looks_under_18_suspends_until_review(api, ready):
    body = selfie(api).json()
    assert body["next_step"] == "review"
    ready.refresh_from_db()
    assert ready.status == User.Status.SUSPENDED
    assert Verification.objects.get(kind="manual").reason == "age_estimate"
    assert not _is_verified(ready)


def test_selfie_must_be_an_image(api, ready):
    from django.core.files.uploadedfile import SimpleUploadedFile

    res = api.post(
        "/api/v1/me/selfie",
        {
            "pose_front": SimpleUploadedFile("a.txt", b"hello", "text/plain"),
            "pose_left": SimpleUploadedFile("b.txt", b"hello", "text/plain"),
        },
        format="multipart",
    )
    assert res.status_code == 400
    assert res.json()["code"] == "selfie_invalid"


def test_selfie_before_basics_is_refused(api):
    sign_in(api)
    assert selfie(api).status_code == 409


def test_privacy_raw_selfies_deleted_30_days_after_pass(api, ready):
    selfie(api)
    v = Verification.objects.get(kind="selfie")
    keys = list(v.images)
    assert onboarding.purge_verified_selfies(timezone.now() + timedelta(days=29)) == 0
    assert onboarding.purge_verified_selfies(timezone.now() + timedelta(days=31)) == 1
    v.refresh_from_db()
    assert v.images == [] and not any(default_storage.exists(k) for k in keys)
    assert Profile.objects.get(user=ready).is_verified


def test_fr4_passing_selfie_enrolls_the_face_for_main_photos(api, ready):
    selfie(api)
    assert Profile.objects.get(user=ready).face_template.startswith("fake-template:")
