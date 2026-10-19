from django.contrib import admin, messages

from .models import DeniedPhone, Profile, SocialAccount, User, Verification
from .services import onboarding


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ("phone", "status", "risk_score", "created_at")
    list_filter = ("status",)
    search_fields = ("phone",)
    readonly_fields = ("created_at",)
    exclude = ("password", "dob")  # only the age is ever shown (FR-3)


@admin.register(Profile)
class ProfileAdmin(admin.ModelAdmin):
    list_display = ("user", "first_name", "is_verified", "verified_at")
    list_filter = ("is_verified",)
    search_fields = ("user__phone", "first_name")


@admin.register(Verification)
class VerificationAdmin(admin.ModelAdmin):
    """Manual review queue for FR-4 / SF-3 until the moderator console (M4)."""

    list_display = ("user", "kind", "status", "reason", "score", "estimated_age", "created_at")
    list_filter = ("kind", "status", "reason")
    search_fields = ("user__phone",)
    readonly_fields = [f.name for f in Verification._meta.fields]
    actions = ["approve", "reject"]

    def _decide(self, request, queryset, approve):
        pending = queryset.filter(kind=Verification.Kind.MANUAL, status=Verification.Status.PENDING)
        for manual in pending:
            onboarding.review(manual, request.user, approve)
        skipped = queryset.count() - pending.count()
        self.message_user(
            request,
            f"{pending.count()} decided, {skipped} skipped (not pending manual reviews).",
            messages.SUCCESS if not skipped else messages.WARNING,
        )

    @admin.action(description="Approve selected manual reviews")
    def approve(self, request, queryset):
        self._decide(request, queryset, approve=True)

    @admin.action(description="Reject selected manual reviews")
    def reject(self, request, queryset):
        self._decide(request, queryset, approve=False)


@admin.register(SocialAccount)
class SocialAccountAdmin(admin.ModelAdmin):
    list_display = ("user", "provider", "created_at")
    readonly_fields = ("user", "provider", "subject", "created_at")


@admin.register(DeniedPhone)
class DeniedPhoneAdmin(admin.ModelAdmin):
    list_display = ("phone_hash", "reason", "created_at")
    readonly_fields = ("phone_hash", "reason", "created_at")

    def has_delete_permission(self, request, obj=None):
        return False
