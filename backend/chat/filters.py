"""FR-18 / SF-8 message check: phone numbers, account numbers, payment/OTP requests, slurs."""

import re

from django.conf import settings

# Nigerian phone numbers (+234 / 0 prefix) and generic 10+ digit runs (NUBAN accounts are 10).
_PHONE = re.compile(r"(?:\+?234|\b0)[\s-]?[789][01]\d(?:[\s-]?\d){7}\b")
_ACCOUNT = re.compile(r"\b\d(?:[\s-]?\d){9,}\b")
_PAYMENT = re.compile(
    r"\b(?:send (?:me )?(?:money|cash|airtime)|transfer(?: to)?|account (?:number|no)|"
    r"acct|bank details|otp|pin|bvn|recharge card|pay (?:me|for)|momo|opay|palmpay)\b",
    re.IGNORECASE,
)


def check(body: str) -> str:
    """Returns the flag reason ("" if clean): phone | account | payment | slur."""
    if _PHONE.search(body):
        return "phone"
    if _ACCOUNT.search(body):
        return "account"
    if _PAYMENT.search(body):
        return "payment"
    words = set(re.findall(r"[\w']+", body.lower()))
    if words & set(settings.CHAT_SLUR_LIST):
        return "slur"
    return ""
