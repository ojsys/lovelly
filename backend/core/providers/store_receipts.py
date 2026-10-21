"""Store purchase checks (MN-4): Google Play and the App Store, behind one interface."""

import base64
import json
import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
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
class StoreSubscription:
    """Korram Plus as the store sees it now (MN-6)."""

    store: str
    original_txn_id: str  # Apple original transaction id / Google purchase token
    plan: str  # "week" | "month" | "year"
    state: str  # Subscription.Status values
    period_end: datetime
    account_id: str | None = None
    auto_renews: bool = True
    product_id: str = ""
    raw: dict = field(default_factory=dict)


@dataclass(frozen=True)
class StoreEvent:
    """One thing a store webhook told us."""

    kind: str  # "purchased" | "refunded" | "subscription" | "test"
    transaction: StoreTransaction | None = None
    store: str = ""
    txn_id: str = ""
    subscription: StoreSubscription | None = None


class StoreReceiptsProvider(ABC):
    @abstractmethod
    def verify(self, store: str, product_id: str, token: str) -> StoreTransaction:
        """Checks a purchase with the store. Raises InvalidReceipt."""

    @abstractmethod
    def verify_subscription(self, store: str, product_id: str, token: str) -> StoreSubscription:
        """Checks a Korram Plus subscription with the store. Raises InvalidReceipt."""

    @abstractmethod
    def acknowledge(self, store: str, product_id: str, token: str) -> None:
        """Tells the store we delivered (Google refunds unacknowledged purchases)."""

    @abstractmethod
    def acknowledge_subscription(self, store: str, product_id: str, token: str) -> None:
        """Google refunds subscriptions that aren't acknowledged within 3 days."""

    @abstractmethod
    def parse_webhook(self, store: str, body: dict, query: dict) -> list[StoreEvent]:
        """Reads and authenticates a store notification. Raises InvalidReceipt."""


class FakeStoreReceiptsProvider(StoreReceiptsProvider):
    """Tokens look like `fake:<product>:<txn>[:pending|:refunded]`.
    Subscriptions: `fakesub:<plan>:<id>[:<status>]`, running one plan period from now.

    Webhooks: `{"type": "purchased" | "refunded" | "subscription", "token", "account_id"}`.
    """

    PERIOD = {"week": timedelta(days=7), "month": timedelta(days=30), "year": timedelta(days=365)}

    def verify_subscription(self, store, product_id, token, account_id=None):
        parts = token.split(":")
        if len(parts) < 3 or parts[0] != "fakesub" or parts[1] not in self.PERIOD:
            raise InvalidReceipt("not a fake subscription token")
        state = parts[3] if len(parts) > 3 else "active"
        ends = datetime.now(UTC) + self.PERIOD[parts[1]]
        if state in ("expired", "revoked"):
            ends = datetime.now(UTC) - timedelta(minutes=1)
        return StoreSubscription(
            store=store,
            original_txn_id=f"{store}.{parts[2]}",
            plan=parts[1],
            state=state,
            period_end=ends,
            account_id=account_id,
            product_id=product_id,
            raw={"token": token},
        )

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

    def acknowledge_subscription(self, store, product_id, token):
        self.acknowledged.append(token)

    def parse_webhook(self, store, body, query):
        kind, token = body.get("type"), body.get("token", "")
        if kind == "subscription":
            sub = self.verify_subscription(store, "", token, account_id=body.get("account_id"))
            return [StoreEvent("subscription", subscription=sub)]
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

    def verify_subscription(self, store, product_id, token):
        return self._store(store).verify_subscription(product_id, token)

    def acknowledge(self, store, product_id, token):
        if store == "google":
            self.google.acknowledge(product_id, token)

    def acknowledge_subscription(self, store, product_id, token):
        if store == "google":
            self.google.acknowledge_subscription(product_id, token)

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

    SUB_STATES = {
        "SUBSCRIPTION_STATE_ACTIVE": "active",
        "SUBSCRIPTION_STATE_IN_GRACE_PERIOD": "grace",
        "SUBSCRIPTION_STATE_ON_HOLD": "on_hold",
        "SUBSCRIPTION_STATE_PAUSED": "on_hold",
        "SUBSCRIPTION_STATE_CANCELED": "cancelled",  # active until the period ends
        "SUBSCRIPTION_STATE_EXPIRED": "expired",
    }

    def verify_subscription(self, product_id, token, revoked=False) -> StoreSubscription:
        import requests

        url = f"{self.API}/{settings.PLAY_PACKAGE_NAME}/purchases/subscriptionsv2/tokens/{token}"
        res = requests.get(url, headers=self._auth(), timeout=10)
        if res.status_code in (400, 404, 410):
            raise InvalidReceipt(f"Google: {res.status_code}")
        res.raise_for_status()
        p = res.json()
        item = (p.get("lineItems") or [{}])[0]
        if not item.get("expiryTime"):
            raise InvalidReceipt("Google: no subscription line")
        return StoreSubscription(
            store="google",
            original_txn_id=token,
            plan=(item.get("offerDetails") or {}).get("basePlanId", ""),
            state="revoked"
            if revoked
            else self.SUB_STATES.get(p.get("subscriptionState"), "expired"),
            period_end=datetime.fromisoformat(item["expiryTime"].replace("Z", "+00:00")),
            account_id=(p.get("externalAccountIdentifiers") or {}).get(
                "obfuscatedExternalAccountId"
            ),
            auto_renews=bool(item.get("autoRenewingPlan", {}).get("autoRenewEnabled")),
            product_id=item.get("productId", product_id),
            raw=p,
        )

    def acknowledge_subscription(self, product_id, token) -> None:
        import requests

        app = f"{self.API}/{settings.PLAY_PACKAGE_NAME}"
        url = f"{app}/purchases/subscriptions/{product_id}/tokens/{token}:acknowledge"
        res = requests.post(url, headers=self._auth(), timeout=10)
        if res.status_code >= 400:
            logger.warning("Play subscription acknowledge %s: %s", res.status_code, res.text[:200])

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
        if sub := data.get("subscriptionNotification"):
            revoked = sub.get("notificationType") == 12  # SUBSCRIPTION_REVOKED
            s = self.verify_subscription(sub["subscriptionId"], sub["purchaseToken"], revoked)
            return [StoreEvent("subscription", subscription=s)]
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

    PLANS = {"plus_week": "week", "plus_month": "month", "plus_year": "year"}

    def _subscription(self, signed: str, state: str | None = None, auto_renews=True):
        from appstoreserverlibrary.signed_data_verifier import VerificationException

        try:
            t = self._decoder().verify_and_decode_signed_transaction(signed)
        except VerificationException as e:
            raise InvalidReceipt(f"Apple: {e}") from e
        if t.productId not in self.PLANS or not t.expiresDate:
            raise InvalidReceipt("Apple: not a Korram Plus transaction")
        ends = datetime.fromtimestamp(t.expiresDate / 1000, UTC)
        if state is None:
            state = (
                "revoked"
                if t.revocationDate
                else ("active" if ends > datetime.now(UTC) else "expired")
            )
        return StoreSubscription(
            store="apple",
            original_txn_id=t.originalTransactionId,
            plan=self.PLANS[t.productId],
            state=state,
            period_end=ends,
            account_id=t.appAccountToken,
            auto_renews=auto_renews,
            product_id=t.productId,
            raw={"transactionId": t.transactionId},
        )

    def verify_subscription(self, product_id, token) -> StoreSubscription:
        return self._subscription(token)

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
        sub_states = {
            T.SUBSCRIBED: "active",
            T.DID_RENEW: "active",
            T.OFFER_REDEEMED: "active",
            T.DID_FAIL_TO_RENEW: "grace"
            if n.subtype and n.subtype.value == "GRACE_PERIOD"
            else "on_hold",
            T.GRACE_PERIOD_EXPIRED: "on_hold",
            T.EXPIRED: "expired",
            T.DID_CHANGE_RENEWAL_STATUS: None,  # recomputed from the transaction
            T.REFUND: "revoked",
            T.REVOKE: "revoked",
        }
        try:
            info = self._decoder().verify_and_decode_signed_transaction(
                n.data.signedTransactionInfo
            )
        except VerificationException as e:
            raise InvalidReceipt(f"Apple: {e}") from e
        if info.productId in self.PLANS and n.notificationType in sub_states:
            auto = True
            if n.data.signedRenewalInfo:
                renewal = self._decoder().verify_and_decode_renewal_info(n.data.signedRenewalInfo)
                auto = bool(renewal.autoRenewStatus and renewal.autoRenewStatus.value == 1)
            s = self._subscription(
                n.data.signedTransactionInfo, sub_states[n.notificationType], auto_renews=auto
            )
            return [StoreEvent("subscription", subscription=s)]
        txn = self._transaction(n.data.signedTransactionInfo)
        if n.notificationType == T.ONE_TIME_CHARGE:
            return [StoreEvent("purchased", transaction=txn)]
        if n.notificationType in (T.REFUND, T.REVOKE):
            return [StoreEvent("refunded", store="apple", txn_id=txn.txn_id)]
        return []
