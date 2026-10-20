"""Profile editing (FR-19): photos, bio, city, languages, interests."""

import io
import uuid

from django.conf import settings
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.db import transaction
from django.utils import timezone
from rest_framework import status

from accounts.models import Interest, Profile, User, UserInterest, Verification
from core.exceptions import ApiError
from core.providers import get_provider
from core.storage_urls import signed_url

from .onboarding import age_on

MAX_PHOTOS = 6
MAX_INTERESTS = 5
MAX_BIO = 150
MAX_PHOTO_BYTES = 8 * 1024 * 1024
PHOTO_SIZE = 1080
LANGUAGES = ["english", "pidgin", "yoruba", "hausa", "igbo", "french", "arabic"]


def _photo_id(key: str) -> str:
    return key.rsplit("/", 1)[-1].removesuffix(".jpg")


def as_dict(user: User) -> dict:
    profile = Profile.objects.get(user=user)
    interests = [
        {"slug": ui.interest.slug, "label": ui.interest.label}
        for ui in user.interests.select_related("interest")
    ]
    return {
        "first_name": profile.first_name,
        "age": age_on(user.dob, timezone.now().date()) if user.dob else None,
        "city": profile.city,
        "bio": profile.bio,
        "interests": interests,
        "languages": profile.languages,
        "photos": [
            {"id": _photo_id(key), "url": signed_url(default_storage, key, 3600)}
            for key in profile.photos
        ],
        "is_verified": profile.is_verified,
    }


# --- Face match (FR-4) -------------------------------------------------------------------


def _template(user: User, profile: Profile) -> str:
    """The verified face; enrolled lazily from a still-stored selfie for older accounts."""
    if profile.face_template:
        return profile.face_template
    selfie = (
        Verification.objects.filter(user=user, kind=Verification.Kind.SELFIE, status="passed")
        .exclude(images=[])
        .first()
    )
    if selfie is None:
        raise ApiError(
            "selfie_needed", "Take a new selfie check before changing your main photo.", 409
        )
    with default_storage.open(selfie.images[0]) as f:
        profile.face_template = get_provider("liveness").enroll(f.read())
    profile.save(update_fields=["face_template"])
    return profile.face_template


def _require_face_match(user: User, profile: Profile, key: str) -> None:
    with default_storage.open(key) as f:
        data = f.read()
    if not get_provider("liveness").matches(_template(user, profile), data):
        raise ApiError(
            "main_photo_mismatch",
            "Your main photo has to show your face, matching your selfie check.",
            status.HTTP_422_UNPROCESSABLE_ENTITY,
        )


# --- Photos ------------------------------------------------------------------------------


def _clean_image(upload) -> bytes:
    """JPEG, at most 1080 px, no EXIF (location!)."""
    from PIL import Image, ImageOps, UnidentifiedImageError

    raw = upload.read()
    if len(raw) > MAX_PHOTO_BYTES:
        raise ApiError("photo_too_big", "Photos can be up to 8 MB.")
    try:
        img = Image.open(io.BytesIO(raw))
        img = ImageOps.exif_transpose(img).convert("RGB")
    except (UnidentifiedImageError, OSError) as e:
        raise ApiError("photo_invalid", "That file isn't a photo we can use.") from e
    img.thumbnail((PHOTO_SIZE, PHOTO_SIZE))
    out = io.BytesIO()
    img.save(out, "JPEG", quality=85)  # a fresh file: no EXIF copied over
    return out.getvalue()


@transaction.atomic
def add_photo(user: User, upload) -> dict:
    profile = Profile.objects.select_for_update().get(user=user)
    if len(profile.photos) >= MAX_PHOTOS:
        raise ApiError("too_many_photos", f"You can have up to {MAX_PHOTOS} photos.")
    data = _clean_image(upload)
    verdict = get_provider("moderation").scan_frame(data)
    if verdict.nudity >= settings.MODERATION_NUDITY_THRESHOLD or (
        verdict.estimated_age is not None and verdict.estimated_age < settings.MIN_AGE
    ):
        raise ApiError("photo_rejected", "This photo breaks our Community Guidelines.")
    key = default_storage.save(f"photos/{user.id}/{uuid.uuid4().hex}.jpg", ContentFile(data))
    if not profile.photos:
        try:
            _require_face_match(user, profile, key)
        except ApiError:
            default_storage.delete(key)
            raise
    profile.photos = [*profile.photos, key]
    profile.save(update_fields=["photos"])
    return as_dict(user)


@transaction.atomic
def delete_photo(user: User, photo_id: str) -> dict:
    profile = Profile.objects.select_for_update().get(user=user)
    keys = [k for k in profile.photos if _photo_id(k) == photo_id]
    if not keys:
        raise ApiError("not_found", "Photo not found.", 404)
    remaining = [k for k in profile.photos if k != keys[0]]
    if profile.photos[0] == keys[0] and remaining:
        _require_face_match(user, profile, remaining[0])  # the next one becomes main
    profile.photos = remaining
    profile.save(update_fields=["photos"])
    default_storage.delete(keys[0])
    return as_dict(user)


# --- Fields ------------------------------------------------------------------------------


@transaction.atomic
def update(user: User, data: dict) -> dict:
    profile = Profile.objects.select_for_update().get(user=user)
    fields = []
    if "first_name" in data:
        name = data["first_name"].strip()
        if not name:
            raise ApiError("invalid", "Add your first name.")
        profile.first_name = name[:40]
        fields.append("first_name")
    if "bio" in data:
        if len(data["bio"]) > MAX_BIO:
            raise ApiError("bio_too_long", f"Keep it under {MAX_BIO} characters.")
        profile.bio = data["bio"].strip()
        fields.append("bio")
    if "city" in data:
        profile.city = data["city"].strip()[:80]
        fields.append("city")
    if "languages" in data:
        langs = [lang.lower() for lang in data["languages"]]
        if any(lang not in LANGUAGES for lang in langs):
            raise ApiError("invalid_language", "Pick languages from the list.")
        profile.languages = list(dict.fromkeys(langs))
        fields.append("languages")
    if "photo_order" in data:
        by_id = {_photo_id(k): k for k in profile.photos}
        order = data["photo_order"]
        if sorted(order) != sorted(by_id):
            raise ApiError("invalid_order", "Send every photo once.")
        new = [by_id[i] for i in order]
        if new and new[0] != profile.photos[0]:
            _require_face_match(user, profile, new[0])
        profile.photos = new
        fields.append("photos")
    if fields:
        profile.save(update_fields=fields)
    if "interests" in data:
        slugs = list(dict.fromkeys(data["interests"]))
        if len(slugs) > MAX_INTERESTS:
            raise ApiError("too_many_interests", f"Pick up to {MAX_INTERESTS} interests.")
        known = set(Interest.objects.filter(slug__in=slugs).values_list("slug", flat=True))
        if known != set(slugs):
            raise ApiError("invalid_interest", "Pick interests from the list.")
        UserInterest.objects.filter(user=user).delete()
        UserInterest.objects.bulk_create([UserInterest(user=user, interest_id=s) for s in slugs])
    return as_dict(user)


def main_photo_url(user_id) -> str | None:
    profile = Profile.objects.filter(user_id=user_id).first()
    return (
        signed_url(default_storage, profile.photos[0], 3600) if profile and profile.photos else None
    )
