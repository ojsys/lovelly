from abc import ABC, abstractmethod


class PaystackProvider(ABC):
    @abstractmethod
    def verify_webhook(self, payload: bytes, signature: str) -> bool: ...


class FakePaystackProvider(PaystackProvider):
    def verify_webhook(self, payload: bytes, signature: str) -> bool:
        return signature == "fake-valid"
