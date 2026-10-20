"""Push notifications (FR-17): Firebase Cloud Messaging, behind an interface."""

import json
import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass, field

from django.conf import settings

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class Push:
    title: str
    body: str
    data: dict[str, str] = field(default_factory=dict)


class PushProvider(ABC):
    @abstractmethod
    def send(self, token: str, push: Push) -> bool:
        """Delivers to one device. False means the token is dead and should be dropped."""


class FakePushProvider(PushProvider):
    """Records pushes (tests and local dev without a Firebase project)."""

    outbox: list[tuple[str, Push]] = []

    def send(self, token: str, push: Push) -> bool:
        self.outbox.append((token, push))
        logger.info("fake push to %s…: %s | %s %s", token[:8], push.title, push.body, push.data)
        return True


class FCMPushProvider(PushProvider):
    """FCM HTTP v1, authenticated with a service account (FCM_CREDENTIALS_JSON)."""

    _credentials = None

    def _token(self) -> str:
        from google.auth.transport.requests import Request
        from google.oauth2 import service_account

        if self._credentials is None:
            info = json.loads(settings.FCM_CREDENTIALS_JSON)
            FCMPushProvider._credentials = service_account.Credentials.from_service_account_info(
                info, scopes=["https://www.googleapis.com/auth/firebase.messaging"]
            )
        if not self._credentials.valid:
            self._credentials.refresh(Request())
        return self._credentials.token

    def send(self, token: str, push: Push) -> bool:
        import requests

        res = requests.post(
            f"https://fcm.googleapis.com/v1/projects/{settings.FCM_PROJECT_ID}/messages:send",
            headers={"Authorization": f"Bearer {self._token()}"},
            json={
                "message": {
                    "token": token,
                    "notification": {"title": push.title, "body": push.body},
                    "data": push.data,
                    "android": {"priority": "high"},
                    "apns": {"payload": {"aps": {"sound": "default"}}},
                }
            },
            timeout=5,
        )
        if res.status_code in (404, 410) or "UNREGISTERED" in res.text:
            return False
        if res.status_code >= 400:
            logger.warning("FCM %s: %s", res.status_code, res.text[:200])
        return True
