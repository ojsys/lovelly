from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsVerified
from billing.services import PACKS

from . import free_coins, gifts
from .models import CoinLedger
from .services import balance, ledger, spent_today


class CheckinSerializer(serializers.Serializer):
    claimed_today = serializers.BooleanField()
    day = serializers.IntegerField(help_text="Day N of 7 (today's, or the one a claim gives)")
    coins = serializers.IntegerField()


class WalletSerializer(serializers.Serializer):
    balance = serializers.IntegerField()
    spent_today = serializers.IntegerField()
    checkin = CheckinSerializer()


class LedgerEntrySerializer(serializers.Serializer):
    id = serializers.UUIDField()
    delta = serializers.IntegerField()
    reason = serializers.ChoiceField(choices=CoinLedger.Reason.choices)
    ref_id = serializers.CharField(help_text="For gifts: the gift slug")
    created_at = serializers.DateTimeField()


class LedgerSerializer(serializers.Serializer):
    entries = LedgerEntrySerializer(many=True)
    more = serializers.BooleanField()


class PackSerializer(serializers.Serializer):
    product_id = serializers.CharField(
        help_text="The store product id; the price comes from the store"
    )
    coins = serializers.IntegerField(help_text="Total coins, bonus included")
    bonus = serializers.IntegerField()
    label = serializers.CharField()
    tag = serializers.CharField(allow_blank=True)


class InviteSerializer(serializers.Serializer):
    code = serializers.CharField()
    link = serializers.CharField()
    coins = serializers.IntegerField()
    rewarded = serializers.IntegerField(help_text="Friends who joined and earned you coins")


class InviteRedeemSerializer(serializers.Serializer):
    code = serializers.CharField(max_length=12)


class GiftSerializer(serializers.Serializer):
    slug = serializers.CharField()
    name = serializers.CharField()
    cost = serializers.IntegerField()


class GiftSendRequestSerializer(serializers.Serializer):
    gift = serializers.CharField(help_text="Gift slug")
    idempotency_key = serializers.CharField(
        max_length=64, help_text="Made once per tap, so a retry never charges twice"
    )


class GiftSentSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    gift = GiftSerializer()
    balance = serializers.IntegerField()


def _wallet(user) -> dict:
    return {
        "balance": balance(user.id),
        "spent_today": spent_today(user.id),
        "checkin": free_coins.checkin_state(user.id),
    }


class WalletView(APIView):
    permission_classes = [IsVerified]

    @extend_schema(responses=WalletSerializer)
    def get(self, request):
        return Response(_wallet(request.user))


class LedgerView(APIView):
    permission_classes = [IsVerified]

    @extend_schema(
        parameters=[OpenApiParameter("before", str, description="ISO time: older than this")],
        responses=LedgerSerializer,
    )
    def get(self, request):
        page = ledger(request.user.id, request.query_params.get("before"))
        return Response(LedgerSerializer(page).data)


class ClaimDailyView(APIView):
    permission_classes = [IsVerified]

    @extend_schema(request=None, responses=WalletSerializer)
    def post(self, request):
        free_coins.claim_daily(request.user)
        return Response(_wallet(request.user))


class PacksView(APIView):
    permission_classes = [IsVerified]

    @extend_schema(responses=PackSerializer(many=True))
    def get(self, request):
        return Response(
            [
                {
                    "product_id": p.product_id,
                    "coins": p.coins,
                    "bonus": p.bonus,
                    "label": p.label,
                    "tag": p.tag,
                }
                for p in PACKS
            ]
        )


class InviteView(APIView):
    permission_classes = [IsVerified]

    @extend_schema(responses=InviteSerializer)
    def get(self, request):
        return Response(free_coins.invite(request.user))


class InviteRedeemView(APIView):
    """Before verification: the code the app was installed or opened with (MN-3)."""

    @extend_schema(request=InviteRedeemSerializer, responses={204: None})
    def post(self, request):
        data = InviteRedeemSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        free_coins.redeem(request.user, data.validated_data["code"])
        return Response(status=status.HTTP_204_NO_CONTENT)


class GiftsView(APIView):
    permission_classes = [IsVerified]

    @extend_schema(responses=GiftSerializer(many=True))
    def get(self, request):
        return Response([gifts.gift_dict(g) for g in gifts.catalogue()])


def _send(request, **conversation):
    data = GiftSendRequestSerializer(data=request.data)
    data.is_valid(raise_exception=True)
    sent = gifts.send(
        request.user,
        data.validated_data["gift"],
        data.validated_data["idempotency_key"],
        **conversation,
    )
    return Response(GiftSentSerializer(sent).data, status=status.HTTP_201_CREATED)


class SessionGiftView(APIView):
    permission_classes = [IsVerified]

    @extend_schema(request=GiftSendRequestSerializer, responses={201: GiftSentSerializer})
    def post(self, request, session_id):
        return _send(request, session_id=session_id)


class ChatGiftView(APIView):
    permission_classes = [IsVerified]

    @extend_schema(request=GiftSendRequestSerializer, responses={201: GiftSentSerializer})
    def post(self, request, chat_id):
        return _send(request, chat_id=chat_id)
