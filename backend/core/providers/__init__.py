"""Outside providers, each behind an interface with a fake for tests (CLAUDE.md).

Pick an implementation per provider with settings.PROVIDERS, e.g. PROVIDER_SMS=fake.
Real implementations are added in the milestone that needs them.
"""

from django.conf import settings
from django.utils.module_loading import import_string

_REGISTRY = {
    "sms": {"fake": "core.providers.sms.FakeSMSProvider"},
    "identity": {
        "fake": "core.providers.identity.FakeIdentityProvider",
        "oidc": "core.providers.identity.OIDCIdentityProvider",
    },
    "liveness": {"fake": "core.providers.liveness.FakeLivenessProvider"},
    "moderation": {"fake": "core.providers.moderation.FakeModerationProvider"},
    "media": {
        "fake": "core.providers.media.FakeMediaProvider",
        "livekit": "core.providers.media.LiveKitMediaProvider",
    },
    "store_receipts": {"fake": "core.providers.store_receipts.FakeStoreReceiptsProvider"},
    "paystack": {"fake": "core.providers.paystack.FakePaystackProvider"},
    "push": {
        "fake": "core.providers.push.FakePushProvider",
        "fcm": "core.providers.push.FCMPushProvider",
    },
}


def get_provider(kind: str):
    name = settings.PROVIDERS[kind]
    return import_string(_REGISTRY[kind][name])()
