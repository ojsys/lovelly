"""Store purchase checks (MN-4): Google Play and the App Store, behind one interface."""

import base64
import json
import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from decimal import Decimal
from pathlib import Path

from django.conf import settings

logger = logging.getLogger(__name__)


class InvalidReceipt(Exception):
    """The store says no, or the data isn't genuinely from the store."""


@dataclass(frozen=True)
class StoreTransaction:
    store: str  # "google" | "apple"
    txn_id: str  # Google order id / Apple transaction id
    product_id: str
    state: str  # "purchased" | "pending" | "cancelled" | "refunded"
    account_id: str | None = None  # the user id the app attached to the purchase
    token: str = ""  # Google purchase token
    amount_ngn: Decimal | None = None
    raw: dict = field(default_factory=dict)


@dataclass(frozen=True)
class StoreEvent:
    """One thing a store webhook told us."""

    kind: str  # "purchased" | "refunded" | "test"
    transaction: StoreTransaction | None = None
    store: str = ""
    txn_id: str = ""


class StoreReceiptsProvider(ABC):
    @abstractmethod
    def verify(self, store: str, product_id: str, token: str) -> StoreTransaction:
        """Checks a purchase with the store. Raises InvalidReceipt."""

    @abstractmethod
    def acknowledge(self, store: str, product_id: str, token: str) -> None:
        """Tells the store we delivered (Google refunds unacknowledged purchases)."""

    @abstractmethod
    def parse_webhook(self, store: str, body: dict, query: dict) -> list[StoreEvent]:
        """Reads and authenticates a store notification. Raises InvalidReceipt."""


class FakeStoreReceiptsProvider(StoreReceiptsProvider):
    """Tokens look like `fake:<product>:<txn>[:pending|:refunded]`.

    Webhooks: `{"type": "purchased" | "refunded", "token": ..., "account_id": ...}`.
    """

    acknowledged: list[str] = []

    def verify(self, store, product_id, token, account_id=None):
        parts = token.split(":")
        if len(parts) < 3 or parts[0] != "fake":
            raise InvalidReceipt("not a fake store token")
        state = parts[3] if len(parts) > 3 else "purchased"
        return StoreTransaction(
            store=store,
            txn_id=f"{store.upper()}.{parts[2]}",
            product_id=parts[1],
            state=state,
            account_id=account_id,
            token=token,
            raw={"token": token},
        )

    def acknowledge(self, store, product_id, token):
        self.acknowledged.append(token)

    def parse_webhook(self, store, body, query):
        kind, token = body.get("type"), body.get("token", "")
        txn = self.verify(store, "", token, account_id=body.get("account_id"))
        if kind == "purchased":
            return [StoreEvent("purchased", transaction=txn)]
        if kind == "refunded":
            return [StoreEvent("refunded", store=store, txn_id=txn.txn_id)]
        return [StoreEvent("test")]


class RealStoreReceiptsProvider(StoreReceiptsProvider):
    def __init__(self):
        self.google, self.apple = GooglePlay(), AppStore()

    def _store(self, store):
        return {"google": self.google, "apple": self.apple}[store]

    def verify(self, store, product_id, token):
        return self._store(store).verify(product_id, token)

    def acknowledge(self, store, product_id, token):
        if store == "google":
            self.google.acknowledge(product_id, token)

    def parse_webhook(self, store, body, query):
        return self._store(store).parse_webhook(body, query)


class GooglePlay:
    """Play Developer API + real-time developer notifications (Pub/Sub push).

    Settings: PLAY_PACKAGE_NAME, PLAY_CREDENTIALS_JSON (service account with Play access),
    PLAY_RTDN_SECRET (the `?secret=` on the Pub/Sub push URL).
    """

    API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
    _credentials = None
    STATES = {0: "purchased", 1: "cancelled", 2: "pending"}

    def _auth(self) -> dict:
        from google.auth.transport.requests import Request
        from google.oauth2 import service_account

        if GooglePlay._credentials is None:
            GooglePlay._credentials = service_account.Credentials.from_service_account_info(
                json.loads(settings.PLAY_CREDENTIALS_JSON),
                scopes=["https://www.googleapis.com/auth/androidpublisher"],
            )
        if not self._credentials.valid:
            self._credentials.refresh(Request())
        return {"Authorization": f"Bearer {self._credentials.token}"}

    def _url(self, product_id, token):
        app = f"{self.API}/{settings.PLAY_PACKAGE_NAME}"
        return f"{app}/purchases/products/{product_id}/tokens/{token}"

    def verify(self, product_id, token) -> StoreTransaction:
        import requests

        res = requests.get(self._url(product_id, token), headers=self._auth(), timeout=10)
        if res.status_code in (400, 404, 410):
            raise InvalidReceipt(f"Google: {res.status_code}")
        res.raise_for_status()
        p = res.json()
        return StoreTransaction(
            store="google",
            txn_id=p.get("orderId") or f"token:{token[:60]}",
            product_id=product_id,
            state=self.STATES.get(p.get("purchaseState"), "cancelled"),
            account_id=p.get("obfuscatedExternalAccountId"),
            token=token,
            raw=p,
        )

    def acknowledge(self, product_id, token) -> None:
        import requests

        res = requests.post(
            f"{self._url(product_id, token)}:acknowledge", headers=self._auth(), timeout=10
        )
        if res.status_code >= 400:
            logger.warning("Play acknowledge %s: %s", res.status_code, res.text[:200])

    def parse_webhook(self, body, query) -> list[StoreEvent]:
        if not settings.PLAY_RTDN_SECRET or query.get("secret") != settings.PLAY_RTDN_SECRET:
            raise InvalidReceipt("bad RTDN secret")
        try:
            data = json.loads(base64.b64decode(body["message"]["data"]))
        except (KeyError, ValueError) as e:
            raise InvalidReceipt("not a Pub/Sub message") from e
        if data.get("packageName") != settings.PLAY_PACKAGE_NAME:
            raise InvalidReceipt("another app's notification")
        if "testNotification" in data:
            return [StoreEvent("test")]
        if one := data.get("oneTimeProductNotification"):
            if one.get("notificationType") == 1:  # ONE_TIME_PRODUCT_PURCHASED
                return [
                    StoreEvent(
                        "purchased", transaction=self.verify(one["sku"], one["purchaseToken"])
                    )
                ]
            return []
        if voided := data.get("voidedPurchaseNotification"):
            if voided.get("productType") == 2:  # one-time product
                return [StoreEvent("refunded", store="google", txn_id=voided["orderId"])]
        return []


class AppStore:
    """StoreKit 2 signed transactions + App Store Server Notifications v2.

    Settings: APPLE_BUNDLE_ID, APPLE_APP_ID, APPLE_ENVIRONMENT ("Sandbox" | "Production"),
    APPLE_ROOT_CERTS_DIR (Apple's root certificates as .cer files, from
    apple.com/certificateauthority).
    """

    _verifier = None

    def _decoder(self):
        from appstoreserverlibrary.models.Environment import Environment
        from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier

        if AppStore._verifier is None:
            certs = [p.read_bytes() for p in Path(settings.APPLE_ROOT_CERTS_DIR).glob("*.cer")]
            AppStore._verifier = SignedDataVerifier(
                certs,
                True,
                Environment(settings.APPLE_ENVIRONMENT),
                settings.APPLE_BUNDLE_ID,
                int(settings.APPLE_APP_ID) if settings.APPLE_APP_ID else None,
            )
        return AppStore._verifier

    def _transaction(self, signed: str) -> StoreTransaction:
        from appstoreserverlibrary.signed_data_verifier import VerificationException

        try:
            t = self._decoder().verify_and_decode_signed_transaction(signed)
        except VerificationException as e:
            raise InvalidReceipt(f"Apple: {e}") from e
        amount = None
        if t.currency == "NGN" and t.price is not None:
            amount = Decimal(t.price) / 1000  # milliunits
        return StoreTransaction(
            store="apple",
            txn_id=t.transactionId,
            product_id=t.productId,
            state="refunded" if t.revocationDate else "purchased",
            account_id=t.appAccountToken,
            amount_ngn=amount,
            raw={"transactionId": t.transactionId, "productId": t.productId},
        )

    def verify(self, product_id, token) -> StoreTransaction:
        return self._transaction(token)

    def parse_webhook(self, body, query) -> list[StoreEvent]:
        from appstoreserverlibrary.models.NotificationTypeV2 import NotificationTypeV2 as T
        from appstoreserverlibrary.signed_data_verifier import VerificationException

        try:
            n = self._decoder().verify_and_decode_notification(body.get("signedPayload", ""))
        except VerificationException as e:
            raise InvalidReceipt(f"Apple: {e}") from e
        if n.notificationType == T.TEST:
            return [StoreEvent("test")]
        if not (n.data and n.data.signedTransactionInfo):
            return []
        txn = self._transaction(n.data.signedTransactionInfo)
        if n.notificationType == T.ONE_TIME_CHARGE:
            return [StoreEvent("purchased", transaction=txn)]
        if n.notificationType in (T.REFUND, T.REVOKE):
            return [StoreEvent("refunded", store="apple", txn_id=txn.txn_id)]
        return []
