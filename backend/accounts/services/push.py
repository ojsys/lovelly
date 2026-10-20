"""Who gets a push, and when (FR-17): only people whose app isn't connected."""

from accounts.models import DeviceToken, User
from core.providers import get_provider
from core.providers.push import Push
from matching import service as matching


def register(user: User, platform: str, token: str) -> None:
    # A token belongs to one install; if it moved to another account, it moves here.
    DeviceToken.objects.update_or_create(
        fcm_token=token, defaults={"user": user, "platform": platform}
    )


def unregister(user: User, token: str) -> None:
    DeviceToken.objects.filter(user=user, fcm_token=token).delete()


def notify(user_id, push: Push, *, only_if_offline: bool = True) -> int:
    """Sends to every device of the user. Returns how many pushes were sent."""
    if only_if_offline and matching.is_online(user_id):
        return 0
    provider = get_provider("push")
    sent = 0
    for device in DeviceToken.objects.filter(user_id=user_id):
        if provider.send(device.fcm_token, push):
            sent += 1
        else:
            device.delete()  # FCM says the install is gone
    return sent
