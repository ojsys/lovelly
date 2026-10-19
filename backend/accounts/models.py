import uuid

from django.conf import settings
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.contrib.postgres.fields import ArrayField
from django.db import models

from core.models import UUIDModel


class UserManager(BaseUserManager):
    def create_user(self, phone=None, password=None, **extra):
        # Google/Apple users have no phone until they verify one (FR-2).
        user = self.model(phone=phone, **extra)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, phone, password, **extra):
        if not phone:
            raise ValueError("phone is required")
        extra.setdefault("is_staff", True)
        extra.setdefault("is_superuser", True)
        return self.create_user(phone, password, **extra)


class User(AbstractBaseUser, PermissionsMixin):
    """Custom user, login by phone (PRD: Data model / User)."""

    class Gender(models.TextChoices):
        WOMAN = "woman", "Woman"
        MAN = "man", "Man"
        OTHER = "other", "Other"

    class Status(models.TextChoices):
        ACTIVE = "active", "Active"
        SUSPENDED = "suspended", "Suspended"
        BANNED = "banned", "Banned"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone = models.CharField(
        max_length=20, unique=True, null=True, blank=True, help_text="E.164, e.g. +2348031234567"
    )
    dob = models.DateField(null=True, blank=True)
    gender = models.CharField(max_length=10, choices=Gender.choices, blank=True)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.ACTIVE)
    risk_score = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    # Django admin access (staff/moderators); app users never get a usable password.
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)

    USERNAME_FIELD = "phone"
    REQUIRED_FIELDS = []

    objects = UserManager()

    def __str__(self):
        return self.phone or f"user {self.id}"


class Profile(models.Model):
    """PRD: Data model / Profile. Photos are storage keys; the first is the main photo."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, primary_key=True
    )
    first_name = models.CharField(max_length=40, blank=True)
    bio = models.CharField(max_length=150, blank=True)
    city = models.CharField(max_length=80, blank=True)
    region = models.CharField(max_length=80, blank=True)
    languages = ArrayField(models.CharField(max_length=40), default=list, blank=True)
    photos = ArrayField(models.CharField(max_length=255), default=list, blank=True)
    is_verified = models.BooleanField(default=False)
    verified_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return self.first_name or str(self.user)


class Verification(UUIDModel):
    """One row per verification attempt (PRD: Data model / Verification)."""

    class Kind(models.TextChoices):
        OTP = "otp", "Phone code"
        SELFIE = "selfie", "Selfie"
        MANUAL = "manual", "Manual review"

    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        PASSED = "passed", "Passed"
        FAILED = "failed", "Failed"
        REJECTED = "rejected", "Rejected"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="verifications"
    )
    kind = models.CharField(max_length=10, choices=Kind.choices)
    status = models.CharField(max_length=10, choices=Status.choices)
    score = models.FloatField(null=True, blank=True)
    attempts = models.PositiveSmallIntegerField(default=1, help_text="Attempt number of this kind")
    estimated_age = models.PositiveSmallIntegerField(null=True, blank=True)
    reason = models.CharField(max_length=40, blank=True)
    # Storage keys of the raw selfie poses; cleared when purged (NFR Privacy).
    images = ArrayField(models.CharField(max_length=255), default=list, blank=True)
    consented_at = models.DateTimeField(null=True, blank=True)
    reviewer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="+",
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.kind} {self.status} ({self.user})"


class SocialAccount(UUIDModel):
    """Google / Apple identity linked to a user (FR-2)."""

    class Provider(models.TextChoices):
        GOOGLE = "google", "Google"
        APPLE = "apple", "Apple"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="social_accounts"
    )
    provider = models.CharField(max_length=10, choices=Provider.choices)
    subject = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["provider", "subject"], name="unique_social_identity")
        ]


class DeniedPhone(UUIDModel):
    """Phones that may never register again (FR-3). Stores a hash, not the number."""

    phone_hash = models.CharField(max_length=64, unique=True)
    reason = models.CharField(max_length=40)
    created_at = models.DateTimeField(auto_now_add=True)
