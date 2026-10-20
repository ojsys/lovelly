"""Onboarding rules: FR-1..FR-4, SF-1, SF-3 and the selfie privacy NFR."""

from dataclasses import dataclass
from datetime import date, timedelta

from django.conf import settings
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.db import transaction
from django.utils import timezone
from rest_framework import status
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import DeniedPhone, Profile, SocialAccount, User, Verification
from core.exceptions import ApiError
from core.providers import get_provider

from .phones import phone_hash

V = Verification


# --- State -------------------------------------------------------------------------------


@dataclass(frozen=True)
class OnboardingState:
    phone_verified: bool
    basics_done: bool
    selfie: str  # none | failed | manual_review | rejected | passed
    attempts_left: int
    is_verified: bool

    @property
    def next_step(self) -> str:
        if not self.phone_verified:
            return "phone"
        if not self.basics_done:
            return "basics"
        if self.selfie == "passed":
            return "done"
        if self.selfie in ("manual_review", "rejected"):
            return "review"
        return "selfie"


def _profile(user: User) -> Profile:
    return Profile.objects.get_or_create(user=user)[0]


def _selfie_status(user: User) -> tuple[str, int]:
    rows = list(user.verifications.filter(kind__in=[V.Kind.SELFIE, V.Kind.MANUAL]))
    failed = sum(1 for v in rows if v.kind == V.Kind.SELFIE and v.status == V.Status.FAILED)
    attempts_left = max(0, settings.SELFIE_MAX_ATTEMPTS - failed)
    if any(v.status == V.Status.PASSED for v in rows):
        return "passed", attempts_left
    manual = next((v for v in rows if v.kind == V.Kind.MANUAL), None)  # newest first
    if manual and manual.status == V.Status.PENDING:
        return "manual_review", attempts_left
    if manual and manual.status == V.Status.REJECTED:
        return "rejected", attempts_left
    return ("failed" if failed else "none"), attempts_left


def state(user: User) -> OnboardingState:
    profile = _profile(user)
    selfie, attempts_left = _selfie_status(user)
    return OnboardingState(
        phone_verified=bool(user.phone),
        basics_done=bool(profile.first_name and user.dob and user.gender),
        selfie=selfie,
        attempts_left=attempts_left,
        is_verified=profile.is_verified,
    )


def _refresh_verified(user: User) -> None:
    """SF-1: verified means phone, age and selfie are all done."""
    profile = _profile(user)
    s = state(user)
    verified = s.phone_verified and s.basics_done and s.selfie == "passed"
    if verified and not profile.is_verified:
        profile.is_verified, profile.verified_at = True, timezone.now()
        profile.save(update_fields=["is_verified", "verified_at"])


def tokens_for(user: User) -> dict:
    refresh = RefreshToken.for_user(user)
    return {"access": str(refresh.access_token), "refresh": str(refresh)}


# --- Sign-in (FR-1, FR-2) ----------------------------------------------------------------


@transaction.atomic
def sign_in_with_phone(phone: str, current: User | None) -> User:
    """Called after the code checks out. One account per phone number (FR-1).

    `current` is a signed-in Google/Apple user who still needs a phone (FR-2). If the phone
    already has an account, the social identity moves to that account.
    """
    existing = User.objects.filter(phone=phone).first()
    if current is None or current.phone == phone:
        user = existing or User.objects.create_user(phone=phone)
    elif current.phone:
        raise ApiError("phone_already_set", "This account already has a phone number.")
    elif existing:
        SocialAccount.objects.filter(user=current).update(user=existing)
        current.delete()
        user = existing
    else:
        current.phone = phone
        current.save(update_fields=["phone"])
        user = current
    _ensure_can_sign_in(user)
    user.verifications.create(kind=V.Kind.OTP, status=V.Status.PASSED)
    _profile(user)
    return user


@transaction.atomic
def sign_in_social(provider: str, id_token: str) -> User:
    from core.providers.identity import InvalidIdentityToken

    try:
        identity = get_provider("identity").verify(provider, id_token)
    except InvalidIdentityToken as e:
        raise ApiError(
            "social_invalid", "Sign-in failed. Try again.", status.HTTP_401_UNAUTHORIZED
        ) from e
    account = SocialAccount.objects.filter(provider=provider, subject=identity.subject).first()
    if account:
        user = account.user
    else:
        user = User.objects.create_user()
        SocialAccount.objects.create(user=user, provider=provider, subject=identity.subject)
        _profile(user)
    _ensure_can_sign_in(user)
    return user


def _ensure_can_sign_in(user: User) -> None:
    if user.status == User.Status.BANNED or not user.is_active:
        raise ApiError("account_removed", "This account was removed.", status.HTTP_403_FORBIDDEN)


# --- Basics and age gate (FR-3) ----------------------------------------------------------


def age_on(dob: date, today: date) -> int:
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


def set_basics(user: User, *, first_name: str, dob: date, gender: str) -> None:
    # Not atomic as a whole: the removal must commit even though we then raise.
    if age_on(dob, timezone.now().date()) < settings.MIN_AGE:
        remove_underage(user, reason="dob_under_18")
        raise ApiError("underage", "Korram is for people 18 and over.", status.HTTP_403_FORBIDDEN)
    with transaction.atomic():
        _save_basics(user, first_name=first_name, dob=dob, gender=gender)


def _save_basics(user: User, *, first_name: str, dob: date, gender: str) -> None:
    user.dob, user.gender = dob, gender
    user.save(update_fields=["dob", "gender"])
    profile = _profile(user)
    profile.first_name = first_name
    profile.save(update_fields=["first_name"])
    _refresh_verified(user)


@transaction.atomic
def remove_underage(user: User, reason: str) -> None:
    """FR-3: block the account and deny-list its phone so it can't sign up again."""
    if user.phone:
        DeniedPhone.objects.get_or_create(
            phone_hash=phone_hash(user.phone), defaults={"reason": reason}
        )
    user.status, user.is_active = User.Status.BANNED, False
    user.save(update_fields=["status", "is_active"])
    # is_active=False already rejects access tokens; also revoke refresh tokens.
    for token in OutstandingToken.objects.filter(user=user):
        BlacklistedToken.objects.get_or_create(token=token)


# --- Selfie (FR-4, SF-3) -----------------------------------------------------------------


_IMAGE_MAGIC = (b"\xff\xd8\xff", b"\x89PNG\r\n\x1a\n")
MAX_SELFIE_BYTES = 5 * 1024 * 1024


def _read_image(upload) -> bytes:
    data = upload.read()
    if len(data) > MAX_SELFIE_BYTES or not data.startswith(_IMAGE_MAGIC):
        raise ApiError("selfie_invalid", "Upload a JPEG or PNG photo under 5 MB.")
    return data


@transaction.atomic
def submit_selfie(user: User, front, left) -> OnboardingState:
    current = state(user)
    if current.next_step != "selfie":
        raise ApiError(
            "selfie_not_expected", "Selfie isn't the next step.", status.HTTP_409_CONFLICT
        )
    poses = [_read_image(front), _read_image(left)]
    result = get_provider("liveness").check(poses)
    attempt = settings.SELFIE_MAX_ATTEMPTS - current.attempts_left + 1
    underage = result.estimated_age is not None and result.estimated_age < settings.MIN_AGE

    verification = user.verifications.create(
        kind=V.Kind.SELFIE,
        status=V.Status.PASSED if result.passed and not underage else V.Status.FAILED,
        score=result.score,
        attempts=attempt,
        estimated_age=result.estimated_age,
        reason="age_estimate" if underage else "",
        consented_at=timezone.now(),
    )
    verification.images = [
        default_storage.save(f"selfies/{user.id}/{verification.id}-{pose}.jpg", ContentFile(data))
        for pose, data in zip(("front", "left"), poses, strict=True)
    ]
    verification.save(update_fields=["images"])

    if result.passed and not underage:
        # Face template for matching main photos later (FR-4; raw selfies go after 30 days).
        Profile.objects.filter(user=user).update(
            face_template=get_provider("liveness").enroll(poses[0])
        )

    if underage:
        # SF-3: looks under 18 -> suspend until a human reviews it.
        user.status = User.Status.SUSPENDED
        user.save(update_fields=["status"])
        user.verifications.create(
            kind=V.Kind.MANUAL, status=V.Status.PENDING, reason="age_estimate"
        )
    elif not result.passed and attempt >= settings.SELFIE_MAX_ATTEMPTS:
        user.verifications.create(
            kind=V.Kind.MANUAL, status=V.Status.PENDING, reason="selfie_failed"
        )

    _refresh_verified(user)
    return state(user)


@transaction.atomic
def review(manual: Verification, reviewer: User, approve: bool) -> None:
    """Decide a manual review (Django admin in M1, moderator console from M4)."""
    if manual.kind != V.Kind.MANUAL or manual.status != V.Status.PENDING:
        raise ValueError("only pending manual reviews can be decided")
    manual.status = V.Status.PASSED if approve else V.Status.REJECTED
    manual.reviewer, manual.reviewed_at = reviewer, timezone.now()
    manual.save(update_fields=["status", "reviewer", "reviewed_at"])
    user = manual.user
    if approve and user.status == User.Status.SUSPENDED:
        user.status = User.Status.ACTIVE
        user.save(update_fields=["status"])
    _refresh_verified(user)


def purge_verified_selfies(now=None) -> int:
    """NFR Privacy: delete raw selfie images 30 days after the user passed verification."""
    cutoff = (now or timezone.now()) - timedelta(days=settings.SELFIE_RETENTION_DAYS)
    purged = 0
    rows = Verification.objects.filter(
        kind=V.Kind.SELFIE, user__profile__verified_at__lte=cutoff
    ).exclude(images=[])
    for v in rows:
        for key in v.images:
            default_storage.delete(key)
        v.images = []
        v.save(update_fields=["images"])
        purged += 1
    return purged
