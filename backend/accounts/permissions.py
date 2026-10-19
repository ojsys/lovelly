from rest_framework.permissions import BasePermission

from .models import Profile


class IsVerified(BasePermission):
    """SF-1: only users with phone, age and selfie checks done may match."""

    message = "Finish verification first."

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and user.status == user.Status.ACTIVE
            and Profile.objects.filter(user=user, is_verified=True).exists()
        )
