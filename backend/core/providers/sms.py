import logging
from abc import ABC, abstractmethod
from typing import Literal

logger = logging.getLogger(__name__)

Channel = Literal["sms", "voice"]


class SMSProvider(ABC):
    """Delivers one-time codes by text message or voice call."""

    @abstractmethod
    def send_code(self, phone: str, code: str, channel: Channel) -> None: ...


class FakeSMSProvider(SMSProvider):
    """Records codes instead of sending them, and logs them for local testing."""

    outbox: list[tuple[str, str, Channel]] = []

    def send_code(self, phone: str, code: str, channel: Channel) -> None:
        self.outbox.append((phone, code, channel))
        logger.info("fake %s code for %s: %s", channel, phone, code)
