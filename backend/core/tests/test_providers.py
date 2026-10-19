import pytest

from core.providers import get_provider
from core.providers.identity import IdentityProvider
from core.providers.liveness import LivenessProvider
from core.providers.media import MediaProvider
from core.providers.moderation import ModerationProvider
from core.providers.paystack import PaystackProvider
from core.providers.sms import SMSProvider
from core.providers.store_receipts import StoreReceiptsProvider


@pytest.mark.parametrize(
    ("kind", "interface"),
    [
        ("sms", SMSProvider),
        ("identity", IdentityProvider),
        ("liveness", LivenessProvider),
        ("moderation", ModerationProvider),
        ("media", MediaProvider),
        ("store_receipts", StoreReceiptsProvider),
        ("paystack", PaystackProvider),
    ],
)
def test_every_provider_has_a_fake_behind_its_interface(kind, interface):
    assert isinstance(get_provider(kind), interface)
