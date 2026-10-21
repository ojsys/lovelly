from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsVerified
from matching import pricing

from . import plus, services
from .models import Purchase, SpendSettings, Subscription


class PurchaseVerifyRequestSerializer(serializers.Serializer):
    store = serializers.ChoiceField(choices=Purchase.Store.choices)
    product_id = serializers.CharField(max_length=60)
    token = serializers.CharField(
        help_text="Google: the purchase token. Apple: the StoreKit 2 signed transaction (JWS)."
    )


class PurchaseResultSerializer(serializers.Serializer):
    status = serializers.ChoiceField(
        choices=Purchase.Status.choices,
        help_text="credited: finish the purchase in the store. pending: wait for payment.",
    )
    balance = serializers.IntegerField()


class PurchaseVerifyView(APIView):
    permission_classes = [IsVerified]

    @extend_schema(request=PurchaseVerifyRequestSerializer, responses=PurchaseResultSerializer)
    def post(self, request):
        data = PurchaseVerifyRequestSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        return Response(services.verify(request.user, **data.validated_data))


class _Webhook(APIView):
    """Store notifications. Authenticated by the store's signature or a shared secret."""

    authentication_classes = []
    permission_classes = [AllowAny]
    store = ""

    @extend_schema(exclude=True)
    def post(self, request):
        services.handle_webhook(self.store, request.data, request.query_params)
        return Response({"ok": True})


class GoogleWebhookView(_Webhook):
    store = "google"


class AppleWebhookView(_Webhook):
    store = "apple"


# --- Korram Plus and spend settings (MN-6, MN-9, MN-10) ------------------------------------


class PlanSerializer(serializers.Serializer):
    plan = serializers.ChoiceField(choices=Subscription.Plan.choices)
    label = serializers.CharField()
    sub = serializers.CharField()
    apple_product = serializers.CharField()
    google_product = serializers.CharField()
    google_base_plan = serializers.CharField()


class PlusStatusSerializer(serializers.Serializer):
    active = serializers.BooleanField()
    plan = serializers.CharField(allow_null=True)
    store = serializers.CharField(allow_null=True)
    period_end = serializers.DateTimeField(allow_null=True)
    auto_renews = serializers.BooleanField()


class PlusVerifyRequestSerializer(serializers.Serializer):
    store = serializers.ChoiceField(choices=Purchase.Store.choices)
    product_id = serializers.CharField(max_length=60)
    token = serializers.CharField(
        help_text="Google: the purchase token. Apple: the StoreKit 2 signed transaction."
    )


class PricesSerializer(serializers.Serializer):
    """Coins per use (MN-7, 12's pay-as-you-go table). Never hard-coded in the app."""

    gender = serializers.IntegerField(help_text="per gender-filtered match that connects")
    region = serializers.IntegerField(help_text="per region-filtered match that connects")
    rematch = serializers.IntegerField(help_text="per rematch that connects")


class SpendSettingsSerializer(serializers.Serializer):
    payg_enabled = serializers.BooleanField()
    daily_cap = serializers.ChoiceField(choices=SpendSettings.CAPS, help_text="0 = no cap")
    auto_topup = serializers.BooleanField()
    topup_pack = serializers.CharField(read_only=True)
    plus = PlusStatusSerializer(read_only=True)
    prices = PricesSerializer(read_only=True)


class SpendSettingsUpdateSerializer(serializers.Serializer):
    payg_enabled = serializers.BooleanField(required=False)
    daily_cap = serializers.ChoiceField(choices=SpendSettings.CAPS, required=False)
    auto_topup = serializers.BooleanField(required=False)


class PlansView(APIView):
    permission_classes = [IsVerified]

    @extend_schema(responses=PlanSerializer(many=True))
    def get(self, request):
        return Response([PlanSerializer(p).data for p in plus.PLANS])


class PlusVerifyView(APIView):
    """A Korram Plus purchase or Restore (MN-6)."""

    permission_classes = [IsVerified]

    @extend_schema(request=PlusVerifyRequestSerializer, responses=PlusStatusSerializer)
    def post(self, request):
        data = PlusVerifyRequestSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        return Response(services.verify_plus(request.user, **data.validated_data))


def _settings(user) -> dict:
    s = plus.spend_settings(user.id)
    return {
        "payg_enabled": s.payg_enabled,
        "daily_cap": s.daily_cap,
        "auto_topup": s.auto_topup,
        "topup_pack": s.topup_pack,
        "plus": plus.plus_status(user.id),
        "prices": {**pricing.PRICES, "rematch": pricing.REMATCH_PRICE},
    }


class SpendSettingsView(APIView):
    permission_classes = [IsVerified]

    @extend_schema(responses=SpendSettingsSerializer)
    def get(self, request):
        return Response(SpendSettingsSerializer(_settings(request.user)).data)

    @extend_schema(request=SpendSettingsUpdateSerializer, responses=SpendSettingsSerializer)
    def patch(self, request):
        data = SpendSettingsUpdateSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        plus.update_spend_settings(request.user.id, data.validated_data)
        return Response(SpendSettingsSerializer(_settings(request.user)).data)
