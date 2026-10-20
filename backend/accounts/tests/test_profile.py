import io

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import AccessToken

from accounts.models import Profile
from conftest import MAGENTA

pytestmark = pytest.mark.django_db

YELLOW = (255, 230, 0)


def jpeg(rgb=(90, 120, 150), size=(2000, 1500), exif=False):
    out = io.BytesIO()
    img = Image.new("RGB", size, rgb)
    if exif:
        e = Image.Exif()
        e[0x8825] = {2: (6, 27, 0)}  # GPS
        img.save(out, "JPEG", exif=e)
    else:
        img.save(out, "JPEG")
    return SimpleUploadedFile("p.jpg", out.getvalue(), "image/jpeg")


@pytest.fixture
def me(make_user):
    user = make_user("Ada")
    Profile.objects.filter(user=user).update(face_template="fake-template:ada")
    c = APIClient()
    c.credentials(HTTP_AUTHORIZATION=f"Bearer {AccessToken.for_user(user)}")
    return user, c


def upload(c, **kw):
    return c.post("/api/v1/me/photos", {"photo": jpeg(**kw)}, format="multipart")


def test_fr19_photos_are_resized_and_stripped(me):
    from django.core.files.storage import default_storage

    user, c = me
    res = upload(c, exif=True)
    assert res.status_code == 201
    key = Profile.objects.get(user=user).photos[0]
    with default_storage.open(key) as f:
        img = Image.open(f)
        assert max(img.size) == 1080 and not img.getexif()


def test_fr19_at_most_6_photos(me):
    _, c = me
    for _ in range(6):
        assert upload(c).status_code == 201
    res = upload(c)
    assert res.status_code == 400 and res.json()["code"] == "too_many_photos"


def test_explicit_photos_are_rejected(me):
    _, c = me
    res = upload(c, rgb=MAGENTA)
    assert res.json()["code"] == "photo_rejected"


def test_fr4_main_photo_must_match_the_selfie(me):
    user, c = me
    res = upload(c, rgb=YELLOW)  # fake: someone else's face
    assert res.status_code == 422 and res.json()["code"] == "main_photo_mismatch"
    assert upload(c).status_code == 201
    assert upload(c, rgb=YELLOW).status_code == 201  # fine as photo 2
    photos = c.get("/api/v1/me/profile").json()["photos"]
    res = c.patch(
        "/api/v1/me/profile", {"photo_order": [photos[1]["id"], photos[0]["id"]]}, format="json"
    )
    assert res.json()["code"] == "main_photo_mismatch"
    res = c.delete(f"/api/v1/me/photos/{photos[0]['id']}")
    assert res.json()["code"] == "main_photo_mismatch"  # would promote the mismatched one


def test_older_accounts_need_a_selfie_for_a_main_photo(make_user):
    user = make_user("Old")
    c = APIClient()
    c.credentials(HTTP_AUTHORIZATION=f"Bearer {AccessToken.for_user(user)}")
    assert upload(c).json()["code"] == "selfie_needed"


def test_fr19_fields_and_limits(me):
    _, c = me
    ok = c.patch(
        "/api/v1/me/profile",
        {
            "first_name": "Ada",
            "city": "Enugu",
            "bio": "Builder by day, amateur chef by night.",
            "languages": ["English", "Igbo", "pidgin"],
            "interests": ["afrobeats", "football", "tech"],
        },
        format="json",
    )
    assert ok.status_code == 200
    body = ok.json()
    assert body["languages"] == ["english", "igbo", "pidgin"]
    assert [i["label"] for i in body["interests"]] == ["Afrobeats", "Football", "Tech"]
    too_many = ["afrobeats", "football", "tech", "poetry", "food", "movies"]
    assert (
        c.patch("/api/v1/me/profile", {"interests": too_many}, format="json").json()["code"]
        == "too_many_interests"
    )
    assert (
        c.patch("/api/v1/me/profile", {"bio": "x" * 151}, format="json").json()["code"]
        == "bio_too_long"
    )
    assert (
        c.patch("/api/v1/me/profile", {"languages": ["klingon"]}, format="json").json()["code"]
        == "invalid_language"
    )
    assert (
        c.patch("/api/v1/me/profile", {"interests": ["nope"]}, format="json").json()["code"]
        == "invalid_interest"
    )


def test_interest_catalogue(me):
    _, c = me
    labels = [i["label"] for i in c.get("/api/v1/interests").json()]
    assert "Afrobeats" in labels and len(labels) >= 20


def test_fr13_reveal_sends_the_other_persons_main_photo(make_user, redis_db, events):
    from matching import calls, service

    a, b = make_user("Ada"), make_user("Zainab")
    Profile.objects.filter(user=b).update(photos=["photos/zainab/main.jpg"])
    service.join(a, "voice")
    service.join(b, "voice")
    (s,) = service.run_tick()
    calls.request_reveal(s.id, a)
    calls.request_reveal(s.id, b)
    assert "zainab/main.jpg" in events.of(a, "reveal.accept")[-1]["photo_url"]
    assert events.of(b, "reveal.accept")[-1]["photo_url"] is None  # Ada has no photo
