from drf_spectacular.utils import extend_schema
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsVerified
from chat.services import serialize
from core.exceptions import ApiError

from . import service
from .models import MatchSession
from .serializers import OnlineCountSerializer, SessionDetailSerializer


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
