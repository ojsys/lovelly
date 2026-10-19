import hashlib
import hmac

import phonenumbers
from django.conf import settings

from core.exceptions import ApiError


def normalize(raw: str) -> str:
    """Return the E.164 form of a phone number, defaulting to Nigeria (+234)."""
    try:
        number = phonenumbers.parse(raw, settings.DEFAULT_PHONE_REGION)
    except phonenumbers.NumberParseException as e:
        raise ApiError("phone_invalid", "Enter a valid phone number.") from e
    if not phonenumbers.is_valid_number(number):
        raise ApiError("phone_invalid", "Enter a valid phone number.")
    return phonenumbers.format_number(number, phonenumbers.PhoneNumberFormat.E164)


def phone_hash(phone: str) -> str:
    """Keyed hash used for the deny list, so minors' numbers are not stored (FR-3)."""
    return hmac.new(settings.SECRET_KEY.encode(), phone.encode(), hashlib.sha256).hexdigest()


def masked(phone: str) -> str:
    """+2348031234542 -> '+234 803 ••• ••42' (Verify screen copy)."""
    number = phonenumbers.parse(phone)
    national = str(number.national_number)
    return f"+{number.country_code} {national[:3]} ••• ••{national[-2:]}"
