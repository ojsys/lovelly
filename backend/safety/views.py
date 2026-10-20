from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from . import services
from .models import Notice, Report


class BlockRequestSerializer(serializers.Serializer):
    session_id = serializers.UUIDField(help_text="Blocks the other person in this session")


class BlockSerializer(serializers.Serializer):
    id = serializers.UUIDField()


class BlocksView(APIView):
    """SF-5: block the other person in a session."""

    @extend_schema(request=BlockRequestSerializer, responses={201: BlockSerializer})
    def post(self, request):
        data = BlockRequestSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        block = services.block_from_session(request.user, data.validated_data["session_id"])
        return Response({"id": block.id}, status=status.HTTP_201_CREATED)


class BlockDetailView(APIView):
    @extend_schema(responses={204: None})
    def delete(self, request, block_id):
        services.unblock(request.user, block_id)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ReportRequestSerializer(serializers.Serializer):
    session_id = serializers.UUIDField(required=False)
    chat_id = serializers.UUIDField(required=False, help_text="Report a friend from their chat")
    reason = serializers.ChoiceField(choices=Report.Reason.choices)
    block = serializers.BooleanField(default=True)


class ReportSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    blocked = serializers.BooleanField()


class ReportsView(APIView):
    """SF-4: report the other person in a session (screen 08)."""

    @extend_schema(request=ReportRequestSerializer, responses={201: ReportSerializer})
    def post(self, request):
        data = ReportRequestSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        v = data.validated_data
        if not (v.get("session_id") or v.get("chat_id")):
            raise serializers.ValidationError({"session_id": "Give a session_id or chat_id."})
        report = services.create_report(
            request.user, v.get("session_id"), v["reason"], v["block"], chat_id=v.get("chat_id")
        )
        return Response(
            {"id": report.id, "blocked": data.validated_data["block"]},
            status=status.HTTP_201_CREATED,
        )


class NoticeSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    kind = serializers.CharField()
    title = serializers.CharField()
    body = serializers.CharField()


class AccountStatusSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=["active", "suspended", "banned"])
    suspended_until = serializers.DateTimeField(allow_null=True)
    notices = NoticeSerializer(many=True)


class MyStatusView(APIView):
    """Suspension and unseen notices (warnings) for the app (SF-6)."""

    @extend_schema(responses=AccountStatusSerializer)
    def get(self, request):
        user = request.user
        notices = Notice.objects.filter(user=user, seen_at=None).order_by("created_at")
        return Response(
            {
                "status": services.effective_status(user),
                "suspended_until": user.suspended_until,
                "notices": [
                    {"id": n.id, "kind": n.kind, "title": n.title, "body": n.body} for n in notices
                ],
            }
        )


class NoticeSeenView(APIView):
    @extend_schema(request=None, responses={204: None})
    def post(self, request, notice_id):
        Notice.objects.filter(id=notice_id, user=request.user, seen_at=None).update(
            seen_at=timezone.now()
        )
        return Response(status=status.HTTP_204_NO_CONTENT)
