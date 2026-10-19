from abc import ABC, abstractmethod
from dataclasses import dataclass

import jwt
from django.conf import settings


class InvalidIdentityToken(Exception):
    pass


@dataclass(frozen=True)
class Identity:
    provider: str
    subject: str


class IdentityProvider(ABC):
    """Verifies Google / Apple sign-in ID tokens (FR-2)."""

    @abstractmethod
    def verify(self, provider: str, id_token: str) -> Identity: ...


class FakeIdentityProvider(IdentityProvider):
    """Accepts tokens of the form `fake:<subject>`."""

    def verify(self, provider: str, id_token: str) -> Identity:
        prefix, _, subject = id_token.partition(":")
        if prefix != "fake" or not subject:
            raise InvalidIdentityToken("not a fake token")
        return Identity(provider=provider, subject=subject)


class OIDCIdentityProvider(IdentityProvider):
    """Checks ID token signatures against Google's and Apple's published keys."""

    _issuers = {
        "google": (
            "https://www.googleapis.com/oauth2/v3/certs",
            ["https://accounts.google.com", "accounts.google.com"],
        ),
        "apple": ("https://appleid.apple.com/auth/keys", ["https://appleid.apple.com"]),
    }
    _clients: dict[str, jwt.PyJWKClient] = {}

    def verify(self, provider: str, id_token: str) -> Identity:
        jwks_url, issuers = self._issuers[provider]
        audiences = (
            settings.GOOGLE_CLIENT_IDS if provider == "google" else settings.APPLE_CLIENT_IDS
        )
        client = self._clients.setdefault(provider, jwt.PyJWKClient(jwks_url))
        try:
            key = client.get_signing_key_from_jwt(id_token)
            claims = jwt.decode(
                id_token, key.key, algorithms=["RS256"], audience=audiences, issuer=issuers
            )
        except jwt.PyJWTError as e:
            raise InvalidIdentityToken(str(e)) from e
        return Identity(provider=provider, subject=claims["sub"])
