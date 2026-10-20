from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsVerified

from . import services
from .models import Purchase


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
