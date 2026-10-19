from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass(frozen=True)
class VerifiedReceipt:
    valid: bool
    product_id: str
    txn_id: str


class StoreReceiptsProvider(ABC):
    """Apple App Store / Google Play receipt checks."""

    @abstractmethod
    def verify(self, store: str, receipt: str) -> VerifiedReceipt: ...


class FakeStoreReceiptsProvider(StoreReceiptsProvider):
    def verify(self, store: str, receipt: str) -> VerifiedReceipt:
        product_id, _, txn_id = receipt.partition(":")
        return VerifiedReceipt(valid=True, product_id=product_id, txn_id=txn_id or receipt)
