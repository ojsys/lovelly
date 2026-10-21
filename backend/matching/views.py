from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsVerified
from chat.services import serialize
from core.exceptions import ApiError
from core.ratelimit import limit

from . import friend_calls, pricing, service
from .calls import fresh_token
from .models import MatchSession
from .serializers import MediaTokenSerializer, OnlineCountSerializer, SessionDetailSerializer


class OnlineCountView(APIView):
    """FR-9: live count of people online."""

    @extend_schema(responses=OnlineCountSerializer)
    def get(self, request):
        return Response({"count": service.online_count()})


class SessionDetailView(APIView):
    """A session the user took part in, with its messages (to resume after a reconnect)."""

    permission_classes = [IsVerified]

    @extend_schema(responses=SessionDetailSerializer)
    def get(self, request, session_id):
        session = MatchSession.objects.filter(id=session_id).first()
        if session is None or not session.has(request.user.id):
            raise ApiError("not_found", "Session not found.", 404)
        return Response(
            {
                "id": session.id,
                "mode": session.mode,
                "peer": service.peer_summary(request.user.id, session.peer_of(request.user.id)),
                "started_at": session.started_at,
                "ended_at": session.ended_at,
                "end_reason": session.end_reason,
                "messages": [serialize(m) for m in session.messages.all()],
            }
        )


class MediaTokenView(APIView):
    """A fresh LiveKit join token to rejoin a call after a drop."""

    permission_classes = [IsVerified]

    @extend_schema(request=None, responses=MediaTokenSerializer)
    def post(self, request, session_id):
        limit(f"mediatoken:{request.user.id}", 30, 3600)
        return Response(fresh_token(session_id, request.user))


# --- Paid matching (FR-7, FR-8, MN-7..MN-9) ------------------------------------------------


class FiltersSerializer(serializers.Serializer):
    gender = serializers.ChoiceField(choices=["everyone", "women", "men"], required=False)
    region = serializers.ChoiceField(
        choices=["global", "nearby", "nigeria", "africa"], required=False
    )


class QuoteRequestSerializer(serializers.Serializer):
    mode = serializers.ChoiceField(choices=MatchSession.Mode.choices)
    filters = FiltersSerializer()


class QuoteLineSerializer(serializers.Serializer):
    kind = serializers.CharField(help_text="gender | region | rematch")
    cost = serializers.IntegerField()


class QuoteSerializer(serializers.Serializer):
    lines = QuoteLineSerializer(many=True)
    cost = serializers.IntegerField(help_text="Coins taken when the match has run 5 s")
    free_reason = serializers.CharField(allow_null=True, help_text="plus | no_filters")
    balance = serializers.IntegerField()
    available = serializers.IntegerField(help_text="Balance minus coins on hold")
    spent_today = serializers.IntegerField()
    daily_cap = serializers.IntegerField(help_text="0 = no cap")
    cap_left = serializers.IntegerField(allow_null=True)
    can_pay = serializers.BooleanField()
    reason = serializers.CharField(
        allow_null=True, help_text="payg_off | cap_reached | low_balance"
    )
    auto_topup = serializers.BooleanField()


class QuoteView(APIView):
    """MN-7: the price of a filtered match, before the charge sheet (13)."""

    permission_classes = [IsVerified]

    @extend_schema(request=QuoteRequestSerializer, responses=QuoteSerializer)
    def post(self, request):
        data = QuoteRequestSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        q = pricing.quote(request.user, data.validated_data["filters"])
        return Response(QuoteSerializer(q).data)


class RematchSerializer(serializers.Serializer):
    invite_id = serializers.CharField()


class RematchView(APIView):
    """FR-7: ring someone you skipped today (20 coins, free with Plus)."""

    permission_classes = [IsVerified]

    @extend_schema(request=None, responses={201: RematchSerializer})
    def post(self, request, session_id):
        invite_id = friend_calls.rematch(request.user, session_id)
        return Response({"invite_id": invite_id}, status=201)
